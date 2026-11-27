# LDG-3279 targeted probe on the installed pin 7f65733f (read only; temp stores).
# Usage: Rscript ldg3279_probe.R
# Checks, each printed as PASS/FAIL with the observed values:
#   LR-06 buyable on a member session without a bar (BBB sessions 3-4)
#   LR-08 ctx$close NA there while the close history is carried
#   LR-07 default-admission history matrix before a full window, and an explicit lower requirement
#   LR-02 final-pulse no_fill row: target = post-risk request, quantity = holding
#   LR-03 reconciliation detail: recorded cash booked in event order, virtual cash
#         in the affordability priority order (generators, then the rest, each by C-locale ID)
.libPaths(c("C:/Users/maxth/ledgr-wt/pin-lib-7f65733f", .libPaths()))
suppressPackageStartupMessages(library(ledgr))
cat("ledgr", as.character(utils::packageVersion("ledgr")), "from", find.package("ledgr"), "\n")
source("C:/Users/maxth/ledgr-wt/pin-src-7f65733f/tests/testthat/helper-history-fixtures.R")
ok <- function(label, cond, ...) cat(if (isTRUE(cond)) "PASS" else "FAIL", label, ..., "\n")

# --- Scenario 1: the WS42 declared-session fixture (BBB has no bar on sessions 3 and 4).
seen <- new.env()
strategy <- function(ctx, params) {
  seen[[ctx$ts_utc]] <- list(
    universe = ctx$universe, buyable = ctx$buyable, member = ctx$member, close = ctx$close,
    hm3 = ledgr_history_matrix(ctx, bar = "close", lookback = 3L),
    hm3_min1 = ledgr_history_matrix(ctx, bar = "close", lookback = 3L, min_observations = 1L),
    hclose = ledgr_history_frame(ctx, bar = "close", lookback = Inf,
      instruments = "decision_axis", min_observations = 0L)
  )
  target <- ctx$hold()
  day <- substr(ctx$ts_utc, 1L, 10L)
  if (identical(day, "2021-01-04")) target[["AAA"]] <- 2
  if (identical(day, "2021-01-13")) target[["AAA"]] <- 5
  target
}
fx <- ws42_history_fixture(strategy = strategy)
bt <- ledgr_run(fx$exp, run_id = "ldg3279-probe-1")
iso <- function(i) format(fx$axis[[i]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
s1 <- seen[[iso(1L)]]; s3 <- seen[[iso(3L)]]; s4 <- seen[[iso(4L)]]
cat("session 3 universe:", s3$universe, "| buyable:", s3$buyable, "| close:", s3$close, "\n")
cat("session 4 buyable:", s4$buyable, "| close:", s4$close, "\n")
ok("LR-06 BBB buyable without a bar (sessions 3, 4)",
   isTRUE(unname(s3$buyable[["BBB"]])) && isTRUE(unname(s4$buyable[["BBB"]])))
ok("LR-08 ctx$close NA without a bar (sessions 3, 4)",
   is.na(s3$close[["BBB"]]) && is.na(s4$close[["BBB"]]))
cat("session 4 close history BBB:", s4$hclose$BBB, "\n")
ok("LR-08 bar history carries BBB's session-2 close", identical(s4$hclose$BBB, c(21, 22, 22, 22)))
cat("session 1 hm3 dim:", dim(s1$hm3), "| hm3_min1 dim:", dim(s1$hm3_min1), "\n")
s3m <- seen[[iso(3L)]]
cat("session 3 hm3 cols:", colnames(s3m$hm3), "\n")
ok("LR-07 default admission: no column before a 3-session window", identical(ncol(s1$hm3), 0L))
ok("LR-07 explicit min_observations = 1 admits at session 1", ncol(s1$hm3_min1) == 3L)
ok("LR-07 a full window admits (AAA, CCC at session 3; BBB has 2 finite carried? see cols)",
   all(c("AAA", "CCC") %in% colnames(s3m$hm3)))
d <- tibble::as_tibble(ledgr_results(bt, "diagnostics"))
final <- d[d$reason_code %in% "final_pulse_no_execution", c("instrument_id", "stage", "outcome",
  "target", "quantity", "target_before_risk", "target_after_risk", "position_before", "position_after",
  "execution_ts_utc")]
print(as.data.frame(final))
ok("LR-02 final-pulse row: execution/no_fill, target 5, quantity 2",
   nrow(final) == 1L && final$stage == "execution" && final$outcome == "no_fill" &&
     final$target == 5 && final$quantity == 2 && is.na(final$execution_ts_utc))
dec <- d[d$stage %in% "decision" & d$instrument_id %in% "AAA", c("ts_utc", "target", "quantity",
  "target_before_risk", "target_after_risk", "position_before", "position_after")]
print(as.data.frame(utils::tail(dec, 3L)))
ok("LR-01 decision row quantity is the holding (AAA held 2 after session 2)",
   all(dec$quantity[-1L] == 2) && dec$quantity[[1L]] == 0)
close(bt)
ledgr_snapshot_close(fx$snapshot)

# --- Scenario 2: a fixed basket with a busy pulse, for the reconciliation detail.
set.seed(3279)
ids <- c("ZED", "MID", "ALPHA", "beta", "KAPPA", "DELTA", "omega", "Q",
         paste0(c("x", "Y", "m", "B"), rep(1:6, each = 4L)))
n_days <- 40L
ts <- as.POSIXct("2021-01-04 21:00:00", tz = "UTC") + 86400 * (seq_len(n_days) - 1L)
bars <- do.call(rbind, lapply(seq_along(ids), function(j) {
  close <- round((7 + j / 3) * exp(cumsum(stats::rnorm(n_days, 0, 0.021))), 8)
  data.frame(instrument_id = ids[[j]], ts_utc = ts, open = close, high = close, low = close,
             close = close, volume = 1000)
}))
plan <- matrix(sample(0:60, n_days * length(ids), replace = TRUE), nrow = n_days,
               dimnames = list(format(ts, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), ids))
make_strategy <- function(plan) function(ctx, params) {
  target <- ctx$hold()
  target[colnames(plan)] <- as.numeric(plan[ctx$ts_utc, colnames(plan)])
  target
}
snap <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
exp2 <- ledgr_experiment(snap, make_strategy(plan), universe = ids,
  opening = ledgr_opening(cash = 16434),
  cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(7), ledgr_cost_notional_bps_fee(3)))
bt2 <- ledgr_run(exp2, run_id = "ldg3279-probe-2")
ev <- tibble::as_tibble(ledgr_results(bt2, "ledger"))
ev <- ev[order(ev$event_seq), ]
d2 <- tibble::as_tibble(ledgr_results(bt2, "diagnostics"))
rec <- d2[d2$stage %in% "reconciliation", c("ts_utc", "detail_json")]
num_json <- function(x) {
  s <- as.character(ledgr:::ledgr_json_write_canonical_v2(list(v = x)))
  sub('^\\{"v":(.*)\\}$', "\\1", s)
}
field <- function(json, name) sub(paste0('.*"', name, '":([^,}]*).*'), "\\1", json)
cash <- 16434
fill_ts <- as.numeric(ev$ts_utc)
axis_num <- as.numeric(ts)
dec_idx <- match(fill_ts, axis_num) - 1L
n_cumsum_miss <- 0L; n_before_sum <- 0L; n_before_start <- 0L
n_double_differ <- 0L; n_match_rec <- 0L; n_match_virt <- 0L; n_differ <- 0L; n_alt_virt <- 0L; n_pulses <- 0L
pos <- stats::setNames(numeric(length(ids)), ids)
for (t in seq_len(n_days - 1L)) {
  rows <- which(dec_idx == t)
  start <- cash
  recorded <- start
  for (r in rows) recorded <- recorded + ev$cash_delta[[r]]
  sell <- ev$side[rows] == "SELL"
  gen <- sell & pos[ev$instrument_id[rows]] > 0 & ev$cash_delta[rows] >= 0
  pri <- rows[order(!gen, enc2utf8(ev$instrument_id[rows]), method = "radix")]
  virtual <- start
  for (r in pri) virtual <- virtual + ev$cash_delta[[r]]
  alt <- start
  for (r in rows) alt <- alt + ev$cash_delta[[r]]
  if (t == 5L) {
    cat("pulse 5 event order:", paste0(ev$instrument_id[rows], ":", ev$side[rows]), "\n")
    cat("pulse 5 priority order:", paste0(ev$instrument_id[pri], ":", ev$side[pri]), "\n")
    cat("pulse 5 deltas:", sprintf("%.17g", ev$cash_delta[rows][1:4]), "\n")
    cat("sum orders: fwd", sprintf("%.17g", recorded), "rev", sprintf("%.17g", Reduce(`+`, rev(ev$cash_delta[rows]), start)), "\n")
  }
  j <- which(as.numeric(rec$ts_utc) == axis_num[[t]])
  stored <- rec$detail_json[[j]]
  n_pulses <- n_pulses + 1L
  if (identical(field(stored, "recorded_final_cash"), num_json(recorded))) n_match_rec <- n_match_rec + 1L
  if (identical(field(stored, "virtual_final_cash"), num_json(virtual))) n_match_virt <- n_match_virt + 1L
  if (!identical(field(stored, "virtual_final_cash"), field(stored, "recorded_final_cash"))) n_differ <- n_differ + 1L
  if (identical(field(stored, "virtual_final_cash"), num_json(alt))) n_alt_virt <- n_alt_virt + 1L
  via_cumsum <- utils::tail(cumsum(c(start, ev$cash_delta[rows])), 1L)
  if (!identical(field(stored, "recorded_final_cash"), num_json(via_cumsum))) n_cumsum_miss <- n_cumsum_miss + 1L
  if (identical(field(stored, "cash_before"), num_json(recorded - sum(ev$cash_delta[rows])))) n_before_sum <- n_before_sum + 1L
  if (identical(field(stored, "cash_before"), num_json(start))) n_before_start <- n_before_start + 1L
  if (!identical(virtual, recorded)) {
    n_double_differ <- n_double_differ + 1L
    if (n_double_differ == 1L) cat("example: virtual", sprintf("%.17g", virtual), "recorded",
      sprintf("%.17g", recorded), "| json:", stored, "\n")
  }
  for (r in rows) pos[[ev$instrument_id[[r]]]] <- pos[[ev$instrument_id[[r]]]] + ev$position_delta[[r]]
  cash <- recorded
}
cat("fills:", nrow(ev), "| decision pulses:", n_pulses, "| recorded matches event-order scan:", n_match_rec,
    "| virtual matches priority-order scan:", n_match_virt, "| virtual != recorded:", n_differ,
    "| virtual matches event-order scan:", n_alt_virt, "| doubles differ:", n_double_differ, "\n")
cat("example detail:", rec$detail_json[[5L]], "\n")
ok("LR-03 recorded cash = event-order plain scan on every pulse", n_match_rec == n_pulses)
ok("LR-03 virtual cash = priority-order plain scan on every pulse", n_match_virt == n_pulses)
ok("LR-03 the two differ in the last digits on some pulse (discriminating)", n_differ > 0L)
cat("LR-04: pulses where a cumsum() booking misses the stored recorded cash:", n_cumsum_miss,
    "| cash_before = recorded - sum(deltas):", n_before_sum, "of", n_pulses,
    "| cash_before = previous recorded cash:", n_before_start, "\n")
close(bt2)
ledgr_snapshot_close(snap)
