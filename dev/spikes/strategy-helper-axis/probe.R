# Strategy-helper axis probe (Cut 22 audit record, LDG-2905).
#
# Runs every strategy helper and context surface against constructed pulse
# contexts and against contexts captured inside real `ledgr_run()` folds, and
# writes one observation row per context and probe. Usage, from the
# repository root:
#
#   Rscript dev/spikes/strategy-helper-axis/probe.R [output.csv]
#
# check.R reruns it and compares the result with observations.csv and the
# frozen expected-delta manifest, so a fix shows exactly which observations it
# changed and cannot change any other.

args <- commandArgs(trailingOnly = TRUE)
out_path <- if (length(args) >= 1L) args[[1L]] else "dev/spikes/strategy-helper-axis/observations.csv"
suppressMessages(pkgload::load_all(".", quiet = TRUE, compile = FALSE))
utc <- function(x) as.POSIXct(x, tz = "UTC")

try_run <- function(expr) tryCatch(expr,
  error = function(e) structure(list(class = class(e)[[1]]), class = "probe_error"),
  warning = function(w) structure(list(class = class(w)[[1]]), class = "probe_warning"))
show <- function(x) {
  if (inherits(x, "probe_error")) return(paste0("ERROR <", x$class, ">"))
  if (inherits(x, "probe_warning")) return(paste0("WARN <", x$class, ">"))
  if (is.null(x)) return("NULL")
  if (is.data.frame(x)) return(paste0("rows=", nrow(x)))
  v <- unclass(x); attributes(v) <- list(names = names(v))
  if (is.list(v)) v <- vapply(v, function(e) paste(format(e), collapse = ","), character(1))
  nm <- if (is.null(names(v))) rep("?", length(v)) else names(v)
  paste0("len=", length(v), " [", paste(sprintf("%s=%s", nm, trimws(format(v))), collapse = " "), "]")
}
ids_text <- function(x) if (is.null(x)) "NULL" else if (length(x) == 0L) "<none>" else paste(x, collapse = ",")

# ---------------------------------------------------------------------------
# Helper table. Every probe calls the helpers through `H`, and every context
# passes through `adapt()`. With AXIS_PROBE_MODEL set to model.R, the model
# replaces the helpers LDG-2906 changes with executable statements of the
# decided semantics, and states the runtime outcomes; expected.R uses that to
# write expected_delta.csv. Without it, the probe measures the package.
# ---------------------------------------------------------------------------

H <- mget(c("ledgr_signal_strategy", "ledgr_signal_return", "ledgr_signal_feature", "ledgr_signal", "ledgr_selection", "ledgr_select_top_n", "ledgr_weight_equal", "ledgr_target_rebalance", "ledgr_target_quantity", "ledgr_target", "ledgr_weights", "ledgr_passed_warmup"), envir = asNamespace("ledgr"))
adapt <- function(ctx) ctx
runtime_expected <- NULL
model_path <- Sys.getenv("AXIS_PROBE_MODEL")
if (nzchar(model_path)) source(model_path, local = TRUE)

# ---------------------------------------------------------------------------
# The probes. Each returns one result string; the same probes run on every
# context, constructed or captured inside a real fold. `threshold` sits
# between the context's feature values so every mask selects some but not all.
# ---------------------------------------------------------------------------

member_only_signals <- H$ledgr_signal_strategy(function(ctx) {
  m <- ctx$members %||% ctx$universe
  stats::setNames(rep("LONG", length(m)), m)
}, long_qty = 10)
axis_signals <- H$ledgr_signal_strategy(function(ctx) {
  stats::setNames(rep("LONG", length(ctx$universe)), ctx$universe)
}, long_qty = 10)

probe_ctx <- function(ctx, lookback, threshold) {
  ctx <- adapt(ctx)
  fid <- sprintf("return_%d", lookback)
  u <- ctx$universe
  m <- ctx$members %||% u
  first <- if (length(u) > 0L) u[[1L]] else NA_character_
  held_nonmembers <- u[ctx$vec$position != 0 & !(u %in% m)]
  feat <- ctx$vec$feature(fid)
  sig <- try_run(H$ledgr_signal_return(ctx, lookback = lookback))
  on_first <- function(expr) if (is.na(first)) "n/a (empty axis)" else show(try_run(expr))
  out <- c(
    "context: universe" = ids_text(u),
    "context: ctx$members" = ids_text(ctx$members),
    "context: eligibility planes in ctx$vec" = ids_text(intersect(c("member", "admissible", "target_restricted"), names(ctx$vec))),
    "context: ctx$vec$admissible" = show(ctx$vec$admissible),
    "context: ctx$state_prev$asset_state names" = ids_text(names(ctx$state_prev$asset_state)),
    "read: ctx$vec$feature" = show(feat),
    "read: ctx$flat()" = show(ctx$flat()),
    "read: ctx$hold()" = show(ctx$hold()),
    "read: ctx$tradable()" = show(try_run(ctx$tradable())),
    "read: ctx$position(first)" = on_first(ctx$position(first)),
    "read: ctx$features(first, explicit map)" = on_first(ctx$features(first, c(ret = fid))),
    "read: ctx$features(first) via active alias" = on_first(ctx$features(first)),
    "signal: ledgr_signal_feature" = show(try_run(H$ledgr_signal_feature(ctx, fid))),
    "signal: ledgr_signal_return" = show(sig),
    "signal: ledgr_signal(ctx, values = vec$feature)" = show(try_run(H$ledgr_signal(ctx, values = feat))),
    "signal: ledgr_signal(ctx, values = named axis)" = show(try_run(H$ledgr_signal(ctx, values = stats::setNames(feat, u)))),
    "signal: ledgr_signal(ctx, values = named member-only)" = show(try_run(H$ledgr_signal(ctx, values = stats::setNames(feat[match(m, u)], m)))),
    "signal: ledgr_signal(ctx, values = unnamed member-only)" = show(try_run(H$ledgr_signal(ctx, values = feat[match(m, u)]))),
    "hand-built: flat()[signal > threshold] <- 10" = show(try_run({ t <- ctx$flat(); t[sig > threshold] <- 10; t })),
    "hand-built: flat()[vec$feature > threshold] <- 10" = show(try_run({ t <- ctx$flat(); t[feat > threshold] <- 10; t })),
    "hand-built: flat()[vec$member & vec$feature > threshold] <- 10" = show(try_run({ t <- ctx$flat(); t[ctx$vec$member & feat > threshold] <- 10; t })),
    "hand-built: flat()[vec$admissible & vec$feature > threshold] <- 10" = show(try_run({ t <- ctx$flat(); t[ctx$vec$admissible & feat > threshold] <- 10; t })),
    "selection: ledgr_selection(ctx)" = show(try_run(H$ledgr_selection(ctx))),
    "selection: ledgr_selection(ctx, ids = first)" = on_first(H$ledgr_selection(ctx, ids = first)),
    "selection: where = vec$feature > threshold" = show(try_run(H$ledgr_selection(ctx, where = feat > threshold))),
    "selection: where = signal > threshold" = show(try_run(H$ledgr_selection(ctx, where = sig > threshold))),
    "selection: select_top_n(signal, 1)" = show(try_run(H$ledgr_select_top_n(sig, 1))),
    "selection: select_top_n(signal, 2)" = show(try_run(H$ledgr_select_top_n(sig, 2))),
    "pipeline: top_n -> equal -> rebalance" = show(try_run(
      H$ledgr_signal_return(ctx, lookback = lookback) |> H$ledgr_select_top_n(1) |> H$ledgr_weight_equal() |> H$ledgr_target_rebalance(ctx))),
    "pipeline: selection(where, exclude) -> target_quantity" = show(try_run(
      ctx |> H$ledgr_selection(where = H$ledgr_signal_return(ctx, lookback = lookback) > threshold, missing = "exclude") |> H$ledgr_target_quantity(ctx, 10))),
    "pipeline: selection(ctx) -> target_quantity" = show(try_run(ctx |> H$ledgr_selection() |> H$ledgr_target_quantity(ctx, 10))),
    "pipeline: selection(ids = first) -> target_quantity" = on_first(H$ledgr_selection(ctx, ids = first) |> H$ledgr_target_quantity(ctx, 10)),
    "pipeline: selection(ctx) -> equal -> rebalance" = show(try_run(ctx |> H$ledgr_selection() |> H$ledgr_weight_equal() |> H$ledgr_target_rebalance(ctx))),
    "pipeline: selection(ctx) -> equal -> rebalance(keep = held nonmembers)" = show(try_run(
      ctx |> H$ledgr_selection() |> H$ledgr_weight_equal() |> H$ledgr_target_rebalance(ctx, keep = held_nonmembers))),
    "wrapper: signal_strategy(member-only signals)" = show(try_run(member_only_signals(ctx, list()))),
    "wrapper: signal_strategy(axis signals)" = show(try_run(axis_signals(ctx, list()))),
    "constructor: ledgr_target(member-only values)" = show(try_run(H$ledgr_target(stats::setNames(rep(1, length(m)), m), universe = u))),
    "constructor: ledgr_weights(member-only values)" = show(try_run(H$ledgr_weights(stats::setNames(rep(0.5, length(m)), m), universe = u))),
    "view: ctx$features_wide" = show(ctx$features_wide),
    "warmup: passed_warmup(ctx$vec$feature)" = show(try_run(H$ledgr_passed_warmup(feat))),
    "warmup: passed_warmup(signal)" = show(try_run(H$ledgr_passed_warmup(unclass(sig)))),
    "warmup: passed_warmup(ctx, ctx$vec$feature)" = show(try_run(H$ledgr_passed_warmup(ctx, feat))),
    "warmup: passed_warmup(ctx, signal)" = show(try_run(H$ledgr_passed_warmup(ctx, sig)))
  )
  out
}

rows <- list()
add_rows <- function(context, results) {
  rows[[length(rows) + 1L]] <<- data.frame(context = context, probe = names(results), result = unname(results))
}

# ---------------------------------------------------------------------------
# Constructed contexts. Target restriction is set independently of
# membership, as the production provider derives it from status and lifetime
# evidence (R/availability-provider-prepared.R).
# ---------------------------------------------------------------------------

make_ctx <- function(ids, availability = FALSE, members = ids, positions = NULL,
                     restricted = rep(FALSE, length(ids)), feature = NULL) {
  n <- length(ids)
  ts <- utc("2026-01-02 21:00:00")
  px <- 10 * seq_len(n)
  if (is.null(feature)) feature <- c(0.2, 0.9)[seq_len(n)]
  bars <- data.frame(instrument_id = ids, ts_utc = rep(ts, n), open = px, high = px,
    low = px, close = px, volume = rep(100, n), stringsAsFactors = FALSE)
  features <- data.frame(instrument_id = ids, ts_utc = rep(ts, n),
    feature_name = rep("return_5", n), feature_value = as.numeric(feature), stringsAsFactors = FALSE)
  if (is.null(positions)) positions <- stats::setNames(numeric(), character())
  ctx <- ledgr:::ledgr_pulse_context(run_id = "audit", ts_utc = ts, universe = ids, bars = bars,
    features = features, positions = positions, cash = 300, equity = 300)
  if (!isTRUE(availability)) return(ctx)
  view <- list(
    member = stats::setNames(ids %in% members, ids),
    held = stats::setNames(ctx$vec$position != 0, ids),
    target_restricted = stats::setNames(restricted, ids),
    target_restriction_reason = stats::setNames(ifelse(restricted, "halted", ""), ids),
    priced = stats::setNames(rep(TRUE, n), ids),
    mark_age = stats::setNames(rep(0L, n), ids),
    risk_mark = stats::setNames(px, ids),
    mark_source = stats::setNames(rep("current_close", n), ids))
  ctx <- ledgr:::ledgr_update_pulse_context_helpers(ctx, bars = bars, features = features,
    positions = ctx$.positions, universe = ids, availability = view)
  ctx$availability_active <- TRUE
  ctx$members <- members
  ctx
}

constructed <- list(
  dense                = function(f = NULL) make_ctx(c("AAA", "BBB"), feature = f),
  ragged_all           = function(f = NULL) make_ctx(c("AAA", "OLD"), TRUE, feature = f),
  ragged_held          = function(f = NULL) make_ctx(c("AAA", "OLD"), TRUE, members = "AAA", positions = c(OLD = 2), feature = f),
  ragged_restrict      = function(f = NULL) make_ctx(c("AAA", "OLD"), TRUE, restricted = c(TRUE, FALSE), feature = f),
  ragged_holdings_only = function(f = NULL) make_ctx("OLD", TRUE, members = character(), positions = c(OLD = 2), feature = f)
)

for (cn in names(constructed)) {
  n <- length(constructed[[cn]]()$universe)
  add_rows(cn, probe_ctx(constructed[[cn]](), lookback = 5, threshold = 0.1))
  if (n >= 1L) {
    f <- c(0.2, 0.9)[seq_len(n)]; f[[1L]] <- NA
    add_rows(paste0(cn, "+missing_first"), probe_ctx(constructed[[cn]](f), lookback = 5, threshold = 0.1))
  }
  if (n >= 2L) add_rows(paste0(cn, "+missing_second"), probe_ctx(constructed[[cn]](c(0.2, NA)), lookback = 5, threshold = 0.1))
}
add_rows("input-only", c(
  "warmup: passed_warmup(numeric(0))" = show(try_run(ledgr_passed_warmup(numeric(0)))),
  "warmup: passed_warmup(c(0.2, NA))" = show(try_run(ledgr_passed_warmup(c(0.2, NA))))
))

# ---------------------------------------------------------------------------
# Real folds. Two small point-in-time fixtures, run through ledgr_run(); the
# recording strategy captures the probes at named pulses.
#
#   departure: AAA member days 1-3 and held after it leaves on day 4;
#              BBB member throughout, halted (target-restricted) from day 6;
#              CCC joins on day 3.
#   ended:     AAA member days 1-2 only; CCC is never a member. With AAA
#              bought, the axis becomes AAA alone (holdings only); without
#              it, the axis is empty.
#   plain:     the same bars without facts, run dense.
# ---------------------------------------------------------------------------

days <- utc("2020-01-01 16:00:00") + 86400 * 0:7
day <- function(i) days[[i]]

fixture <- function(kind) {
  ids <- c("AAA", "BBB", "CCC")
  grid <- expand.grid(instrument_id = ids, ts_utc = days, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  step <- rep(seq_along(days), each = length(ids))
  drift <- rep(c(0.01, 0.02, -0.01), times = length(days))
  grid$close <- 100 * (1 + drift)^step
  grid$open <- grid$close; grid$high <- grid$close + 1; grid$low <- grid$close - 1; grid$volume <- 1000
  sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(days), status = "open",
    session_open = "09:30:00", session_close = "16:00:00", knowledge_time = utc("2019-12-31 00:00:00"),
    source = "axis_probe", stringsAsFactors = FALSE), venue_id = "PROBE", timezone = "UTC")
  if (identical(kind, "plain")) {
    return(ledgr_snapshot_from_df(grid, instruments_df = data.frame(instrument_id = ids),
      db_path = tempfile(fileext = ".duckdb")))
  }
  if (identical(kind, "departure")) {
    membership <- data.frame(instrument_id = c("AAA", "BBB", "CCC"),
      effective_from = c(day(1), day(1), day(3)), effective_to = c(day(4), NA, NA), member = TRUE,
      source = "axis_probe", stringsAsFactors = FALSE)
    status <- ledgr_facts_trading_status(data.frame(
      instrument_id = c("AAA", "BBB", "CCC", "BBB"),
      effective_from = c(day(1), day(1), day(1), day(6)), effective_to = c(NA, NA, NA, NA),
      knowledge_time = c(rep(utc("2019-12-31 00:00:00"), 3), day(6) - 3600),
      status = c("active", "active", "active", "halted"), precedence = c(0L, 0L, 0L, 1L),
      source = "axis_probe", stringsAsFactors = FALSE))
  } else {
    membership <- data.frame(instrument_id = "AAA", effective_from = day(1), effective_to = day(3),
      member = TRUE, source = "axis_probe", stringsAsFactors = FALSE)
    status <- NULL
  }
  membership <- ledgr_facts_membership_intervals(membership, universe_id = "probe", knowledge = "assume_effective")
  facts <- if (is.null(status)) ledgr_facts(sessions, membership) else ledgr_facts(sessions, membership, status)
  ledgr_snapshot_from_df(grid, instruments_df = data.frame(instrument_id = ids), facts = facts,
    db_path = tempfile(fileext = ".duckdb"))
}

snapshots <- list(departure = fixture("departure"), ended = fixture("ended"), plain = fixture("plain"))

capture <- new.env()
real_preflight <- ledgr_strategy_preflight
recording_strategy <- function(ctx, params) {
  label <- params$record[[substr(format(ctx$ts_utc), 1, 10)]]
  if (!is.null(label)) capture[[label]] <- probe_ctx(ctx, lookback = 1, threshold = 0)
  if (isTRUE(params$buy) && substr(format(ctx$ts_utc), 1, 10) == "2020-01-01") {
    buy <- if (isTRUE(ctx$availability_active)) ctx$members else ctx$universe
    t <- ctx$flat(); t[buy] <- 5; return(t)
  }
  ctx$hold()
}

run_fixture <- function(snapshot_name, strategy, params = list(), opening = ledgr_opening(cash = 10000),
                        capture_only = FALSE, dense = FALSE) {
  exp <- if (isTRUE(dense)) {
    ledgr_experiment(snapshots[[snapshot_name]], strategy,
      features = ledgr_feature_map(ret = ledgr_ind_returns(1)),
      cost_model = ledgr_cost_zero(), opening = opening)
  } else {
    ledgr_experiment(snapshots[[snapshot_name]], strategy,
      features = ledgr_feature_map(ret = ledgr_ind_returns(1)),
      universe = ledgr_universe_members("probe"), valuation_policy = ledgr_valuation_stale(2L),
      cost_model = ledgr_cost_zero(), opening = opening)
  }
  run <- function() close(suppressWarnings(ledgr_run(exp, params = params)))
  # The recording strategy calls probe_ctx(), a user helper that preflight
  # rightly classifies Tier 3. Capture runs therefore skip preflight; every
  # "runtime" row below runs a self-contained strategy through the real one.
  if (isTRUE(capture_only)) {
    run <- function() testthat::with_mocked_bindings(
      close(suppressWarnings(ledgr_run(exp, params = params))),
      ledgr_strategy_preflight = function(strategy) real_preflight(function(ctx, params) ctx$flat()),
      .package = "ledgr")
  }
  outcome <- tryCatch({ run(); "completed" },
    error = function(e) { if (nzchar(Sys.getenv("PROBE_DEBUG"))) message(conditionMessage(e)); paste0("ERROR <", grep("^ledgr_", class(e), value = TRUE)[[1L]], ">") })
  outcome
}

invisible(run_fixture("departure", recording_strategy, list(buy = TRUE, record = list(
  "2020-01-02" = "real_members", "2020-01-04" = "real_departed", "2020-01-06" = "real_departed_restricted")), capture_only = TRUE))
invisible(run_fixture("ended", recording_strategy, list(buy = TRUE, record = list("2020-01-04" = "real_holdings_only")), capture_only = TRUE))
invisible(run_fixture("ended", recording_strategy, list(buy = FALSE, record = list("2020-01-04" = "real_zero_axis")), capture_only = TRUE))
invisible(run_fixture("plain", recording_strategy, list(buy = TRUE, record = list("2020-01-04" = "real_dense")),
  capture_only = TRUE, dense = TRUE))
for (label in sort(ls(capture))) add_rows(label, get(label, envir = capture))

runtime_rows <- if (!is.null(runtime_expected)) runtime_expected else c(
  "run: signal_strategy(member-only signals), held nonmember" =
    run_fixture("departure", member_only_signals),
  "run: signal_strategy(axis signals LONG 10), opening nonmember CCC = 2" =
    run_fixture("ended", axis_signals, opening = ledgr_opening(cash = 10000, positions = c(CCC = 2), cost_basis = c(CCC = 100))),
  "run: signal_strategy(axis signals), empty axis" =
    run_fixture("ended", ledgr_signal_strategy(function(ctx) stats::setNames(rep("LONG", length(ctx$universe)), ctx$universe), long_qty = 0)),
  "run: selection(ctx) -> target_quantity, quantity changes while halted" =
    run_fixture("departure", function(ctx, params) {
      qty <- if (substr(format(ctx$ts_utc), 1, 10) >= "2020-01-06") 7 else 5
      ctx |> ledgr_selection() |> ledgr_target_quantity(ctx, qty)
    }),
  "run: selection(ids = BBB) -> target_quantity, quantity changes while halted" =
    run_fixture("departure", function(ctx, params) {
      qty <- if (substr(format(ctx$ts_utc), 1, 10) >= "2020-01-06") 7 else 5
      ledgr_selection(ctx, ids = "BBB") |> ledgr_target_quantity(ctx, qty)
    }),
  "run: hand-built flat()[signal > -1] <- 5 after departure" =
    run_fixture("departure", function(ctx, params) { t <- ctx$flat(); t[ledgr_signal_return(ctx, 1) > -1] <- 5; t })
)
add_rows("runtime", runtime_rows)

# Public pulse snapshot of the availability-bearing fixture.
pulse <- try_run(adapt(ledgr_pulse_snapshot(snapshots$departure, universe = c("AAA", "BBB", "CCC"),
  ts_utc = day(4), features = list(ledgr_ind_returns(1)))))
add_rows("pulse_snapshot", c(
  "context: ctx$members" = if (inherits(pulse, "probe_error")) show(pulse) else ids_text(pulse$members),
  "context: eligibility planes in ctx$vec" = if (inherits(pulse, "probe_error")) show(pulse) else
    ids_text(intersect(c("member", "admissible", "target_restricted"), names(pulse$vec)))
))

observations <- do.call(rbind, rows)
key <- paste(observations$context, observations$probe, sep = " | ")
if (anyDuplicated(key)) stop("duplicate observation keys: ", paste(unique(key[duplicated(key)]), collapse = "; "))
write.csv(observations, out_path, row.names = FALSE)
cat("wrote", nrow(observations), "observations to", out_path, "\n")
