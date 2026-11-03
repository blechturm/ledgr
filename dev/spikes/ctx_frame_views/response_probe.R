# Current-tree evidence for the context-frame-retirement RFC response.
# Baseline for the response: e3bb4cec. Current after-arm: WS21 candidate.
# Environment: R 4.6.1, collapse 2.1.8, Windows, one host and one session.
# Run from any directory:
# Rscript dev/spikes/ctx_frame_views/response_probe.R <ledgr_repo>
# WS6 Type 2 response probe: current-tree behaviour of the frame fields and
# pulse inspection helpers. Rscript ws6_response_probe.R <ledgr_repo>
args <- commandArgs(TRUE)
repo <- normalizePath(args[[1L]], winslash = "/")
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE, export_all = TRUE))
ns <- asNamespace("ledgr")
say <- function(...) cat(sprintf(...), "\n", sep = "")
try_class <- function(expr) tryCatch({ force(expr); "ok" }, error = function(e) paste(class(e)[1:2], collapse = "/"))

say("== E0 old probe dependencies")
for (f in c("ledgr_bars_pulse_views", "ledgr_projection_pulse_views", "ledgr_projection_features_wide_columns", "ledgr_fast_data_frame"))
  say("  exists(%s) = %s", f, exists(f, envir = ns, inherits = FALSE))

# ---- declared-session fixture: AAA, BBB members; OLD held, leaves membership on day 4;
# BBB has no bar on day 6 (a missing expected session).
days <- 8L
dates <- as.Date("2020-01-01") + seq_len(days) - 1L
closes <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
sessions <- ledgr_facts_sessions(data.frame(session_date = dates, status = "open",
  session_open = "09:30:00", session_close = "16:00:00",
  knowledge_time = as.POSIXct(dates, tz = "UTC") - 1), venue_id = "XNYS")
membership <- ledgr_facts_membership_snapshots(data.frame(
  instrument_id = c("AAA", "BBB", "OLD", "AAA", "BBB"),
  effective_from = closes[c(1, 1, 1, 4, 4)] - 3600,
  knowledge_time = closes[c(1, 1, 1, 4, 4)] - 7200), universe_id = "u", complete = TRUE)
grid <- expand.grid(id = c("AAA", "BBB", "OLD"), d = seq_len(days), stringsAsFactors = FALSE)
grid <- grid[!(grid$id == "BBB" & grid$d == 6L), ]
bars <- data.frame(ts_utc = closes[grid$d], instrument_id = grid$id,
  open = 100 + grid$d, high = 101 + grid$d, low = 99 + grid$d, close = 100 + grid$d, volume = 1000)
snap <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB", "OLD")),
  facts = ledgr_facts(sessions, membership), price_basis = "split_adjusted")
fmap <- ledgr_feature_map(ret = ledgr_ind_returns(1), sma = ledgr_ind_sma(2))
seen <- new.env()
strategy <- function(ctx, params) {
  key <- ctx$ts_utc
  seen[[key]] <- list(ctx = ctx,
    names = names(ctx),
    close = ctx$close,
    pf = tryCatch(ledgr_pulse_features(ctx), error = function(e) e),
    pf_map = tryCatch(ledgr_pulse_features(ctx, c(ret = "return_1")), error = function(e) e),
    pw = tryCatch(ledgr_pulse_wide(ctx), error = function(e) e))
  ctx$hold()
}
exp <- ledgr_experiment(snap, strategy, features = fmap,
  opening = ledgr_opening(cash = 1000, positions = c(OLD = 2), cost_basis = c(OLD = 200)),
  universe = ledgr_universe_members("u"), valuation_policy = ledgr_valuation_stale(3),
  cost_model = ledgr_cost_zero())
bt <- ledgr_run(exp, run_id = "ws6_probe")
say("run status: %s", ledgr_run_info(snap, "ws6_probe")$status)
k6 <- "2020-01-06T16:00:00Z"
s <- seen[[k6]]
ctx <- s$ctx
say("== E1 runtime ctx at %s", k6)
say("  universe: %s | member: %s", paste(ctx$universe, collapse = ","), paste(ctx$member, collapse = ","))
say("  names include frames: %s", paste(intersect(s$names, c("bars", "bar", "feature_table", "features_wide")), collapse = ","))
say("  private names(ctx) not in contract asset list: %s", paste(setdiff(s$names, c(ns$ledgr_pulse_context_asset_fields(), "run_id","ts_utc","universe","members","cash","equity","seed","pulse_seed","state","flat","hold","ret","sma")), collapse = ","))
say("  close: %s", paste(names(s$close), s$close, sep = "=", collapse = ","))
for (name in c("bars", "bar", "feature_table", "features_wide"))
  say("  retired ctx$%s: %s", name, try_class(ctx[[name]]))
say("  missing bar is NA close: %s", is.na(unname(ctx$close[["BBB"]])))
say("== E2 inspection helpers inside the callback")
say("  active_alias_map stored on runtime ctx: %s", !is.null(unclass(ctx)[["active_alias_map"]]))
say("  prepared resolver alias map: %s", paste(names(ctx$.pulse_lookup$feature_lookup$name_lookup$alias_map), "=", ctx$.pulse_lookup$feature_lookup$name_lookup$alias_map, collapse = ","))
print(s$pf); say("  pf alias all NA: %s", if (inherits(s$pf, "error")) "ERR" else all(is.na(s$pf$alias)))
print(s$pf_map)
if (inherits(s$pw, "error")) say("  pulse_wide error: %s", conditionMessage(s$pw)) else say("  pulse_wide cols: %s", paste(names(s$pw), collapse = ","))
say("== E3 frozen saved context after the run")
again_pf <- ledgr_pulse_features(ctx); again_pw <- ledgr_pulse_wide(ctx)
say("  pf identical after run: %s ; pw identical: %s ; close identical: %s", identical(again_pf, s$pf), identical(again_pw, s$pw), identical(ctx$close, s$close))
say("== E4 experiment-form pulse snapshot vs first callback")
k1 <- "2020-01-01T16:00:00Z"
first <- seen[[k1]]
insp <- ledgr_pulse_snapshot(exp, ts_utc = k1)
say("  insp active_alias_map stored: %s", !is.null(unclass(insp)[["active_alias_map"]]))
say("  pf equal: %s ; pw equal: %s ; close identical: %s", isTRUE(all.equal(ledgr_pulse_features(insp), first$pf)), isTRUE(all.equal(ledgr_pulse_wide(insp), first$pw)), identical(insp$close, first$close))
say("== E5 snapshot-and-universe form")
dsnap <- ledgr_snapshot_from_df(bars[bars$instrument_id %in% c("AAA", "BBB") & bars$ts_utc <= closes[[5]], ])
p <- ledgr_pulse_snapshot(dsnap, universe = c("BBB", "AAA"), ts_utc = "2020-01-05T16:00:00Z", features = fmap)
say("  universe order: %s", paste(p$universe, collapse = ","))
say("  names(p) metadata: %s", paste(intersect(names(p), c("active_alias_map", "alias_map_json", "alias_map_hash", "alias_map_version", "feature_params")), collapse = ","))
pf <- ledgr_pulse_features(p); print(pf)
pf0 <- ledgr_pulse_features(p, c(return_1 = "return_1", sma_2 = "sma_2")); print(pf0)
say("  snapshot-form flat aliases: ret=%s sma=%s", paste(p$ret, collapse = ","), paste(p$sma, collapse = ","))
say("== E6 empty decision axis")
memb2 <- ledgr_facts_membership_snapshots(data.frame(
  instrument_id = c("AAA", "BBB", NA_character_),
  effective_from = closes[c(1, 1, 3)] - 3600, knowledge_time = closes[c(1, 1, 3)] - 7200), universe_id = "e", complete = TRUE)
snap2 <- ledgr_snapshot_from_df(bars[bars$instrument_id != "OLD", ], instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
  facts = ledgr_facts(sessions, memb2), price_basis = "split_adjusted")
seen2 <- new.env()
exp2 <- ledgr_experiment(snap2, function(ctx, params) {
  if (length(ctx$universe) == 0L && is.null(seen2$ctx)) seen2$ctx <- ctx
  ctx$hold() }, features = fmap, opening = ledgr_opening(cash = 1000),
  universe = ledgr_universe_members("e"), cost_model = ledgr_cost_zero())
bt2 <- ledgr_run(exp2, run_id = "ws6_empty")
e <- seen2$ctx
say("  empty runtime ctx captured: %s at %s", !is.null(e), if (is.null(e)) "-" else e$ts_utc)
if (!is.null(e)) {
  say("  flat close length %d", length(e$close))
  say("  pulse_features(empty): %s", try_class(ledgr_pulse_features(e)))
  say("  pulse_features(empty, map): %s", try_class(ledgr_pulse_features(e, c(ret = "return_1"))))
  say("  pulse_wide(empty): %s", try_class(ledgr_pulse_wide(e)))
  say("  pulse_wide(empty, map): %s", try_class(ledgr_pulse_wide(e, c(ret = "return_1"))))
}
close(bt2); ledgr_snapshot_close(snap2)
say("  print(ctx) names retired frame: %s", any(grepl("feature_table", deparse(print.ledgr_pulse_context), fixed = TRUE)))
close(bt); ledgr_snapshot_close(snap); ledgr_snapshot_close(dsnap)

say("== E7 600-instrument descriptive after-clocks (median us; no gate or whole-run claim)")
n <- 600L; D <- 60L
ids <- sprintf("I%03d", seq_len(n))
ts <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * (seq_len(D) - 1L)
set.seed(1)
big <- data.frame(ts_utc = rep(ts, each = n), instrument_id = rep(ids, D))
px <- 100 * exp(t(apply(matrix(rnorm(n * D, 0, 0.01), n, D), 1, cumsum)))
big$close <- as.vector(px); big$open <- big$close; big$high <- big$close * 1.01; big$low <- big$close * 0.99; big$volume <- 1000
bsnap <- ledgr_snapshot_from_df(big)
fmap3 <- ledgr_feature_map(r5 = ledgr_ind_returns(5), r10 = ledgr_ind_returns(10), r20 = ledgr_ind_returns(20))
cap <- new.env()
trace("ledgr_fold_stage_decide", where = ns, print = FALSE, tracer = quote(
  if (observation$pulse_idx == 40L) { assign("services", services, envir = cap); assign("observation", observation, envir = cap) }))
keep <- new.env()
target_iso <- ledgr_iso_utc(ts[[40]])
bexp <- ledgr_experiment(bsnap, function(ctx, params) { if (identical(ctx$ts_utc, target_iso)) keep$ctx <- ctx; ctx$flat() },
  features = fmap3, opening = ledgr_opening(cash = 1e6), cost_model = ledgr_cost_zero())
wall <- system.time(bbt <- ledgr_run(bexp, run_id = "ws6_big"))[["elapsed"]]
untrace("ledgr_fold_stage_decide", where = ns)
say("  run wall %.2f s over %d pulses = %.0f us/pulse", wall, D, 1e6 * wall / D)
services <- cap$services; observation <- cap$observation
ctxb <- keep$ctx
p2_primitive_bind <- function() {
  data <- observation$data
  list(open = data$open, high = data$high, low = data$low,
    close = data$close, volume = data$volume)
}
fids <- c("r5", "r10", "r20")
flat_matrix <- function() { assign("cache", new.env(parent = emptyenv()), envir = ctxb$.pulse_lookup)
  vapply(fids, function(f) ctxb[[f]], numeric(length(ctxb$universe))) }
mb <- microbenchmark::microbenchmark(
  p2_primitive_bind = p2_primitive_bind(), flat_feature_matrix = flat_matrix(),
  times = 200L, unit = "us")
print(summary(mb)[, c("expr", "median")], row.names = FALSE)
pb <- ledgr_pulse_snapshot(bsnap, universe = ids, ts_utc = ts[[40]], features = fmap3)
mh <- microbenchmark::microbenchmark(
  pulse_features_explicit_one = ledgr_pulse_features(pb, c(r5 = "return_5")),
  pulse_features_active_three = ledgr_pulse_features(pb),
  pulse_wide_active_three = ledgr_pulse_wide(pb),
  times = 30L, unit = "us"
)
print(summary(mh)[, c("expr", "median")], row.names = FALSE)
close(bbt); ledgr_snapshot_close(bsnap)
