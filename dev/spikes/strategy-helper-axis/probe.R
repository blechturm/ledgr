# Strategy-helper axis probe (Cut 22 audit record).
#
# Runs every strategy helper and context surface against one dense and four
# ragged (availability-aware) pulse contexts and writes one observation row per
# context and probe. Usage, from the repository root:
#
#   Rscript dev/spikes/strategy-helper-axis/probe.R [output.csv]
#
# check.R reruns it and diffs the result against observations.csv, so a fix
# shows exactly which observations it changed.

args <- commandArgs(trailingOnly = TRUE)
out_path <- if (length(args) >= 1L) args[[1L]] else "dev/spikes/strategy-helper-axis/observations.csv"
suppressMessages(pkgload::load_all(".", quiet = TRUE, compile = FALSE))

make_ctx <- function(availability = FALSE, members = NULL, positions = NULL,
                     restricted = NULL, feature = c(0.2, 0.9), equity = 300) {
  ids <- if (isTRUE(availability)) c("AAA", "OLD") else c("AAA", "BBB")
  ts <- as.POSIXct("2026-01-02 21:00:00", tz = "UTC")
  bars <- data.frame(instrument_id = ids, ts_utc = rep(ts, 2), open = c(10, 20), high = c(10, 20),
    low = c(10, 20), close = c(10, 20), volume = c(100, 100), stringsAsFactors = FALSE)
  features <- data.frame(instrument_id = ids, ts_utc = rep(ts, 2),
    feature_name = rep("return_5", 2), feature_value = feature, stringsAsFactors = FALSE)
  if (is.null(positions)) positions <- stats::setNames(numeric(), character())
  ctx <- ledgr:::ledgr_pulse_context(run_id = "audit", ts_utc = ts, universe = ids, bars = bars,
    features = features, positions = positions, cash = equity, equity = equity)
  if (!isTRUE(availability)) return(ctx)
  if (is.null(members)) members <- "AAA"
  if (is.null(restricted)) restricted <- !(ids %in% members)
  view <- list(
    member = stats::setNames(ids %in% members, ids),
    held = stats::setNames(ctx$vec$position != 0, ids),
    target_restricted = stats::setNames(restricted, ids),
    target_restriction_reason = stats::setNames(ifelse(restricted, "nonmember", ""), ids),
    priced = stats::setNames(c(TRUE, TRUE), ids),
    mark_age = stats::setNames(c(0L, 0L), ids),
    risk_mark = stats::setNames(c(10, 20), ids),
    mark_source = stats::setNames(c("current_close", "current_close"), ids))
  ctx <- ledgr:::ledgr_update_pulse_context_helpers(ctx, bars = bars, features = features,
    positions = ctx$.positions, universe = ids, availability = view)
  ctx$availability_active <- TRUE
  ctx$members <- members
  ctx
}

contexts <- list(
  dense           = function(f = c(0.2, 0.9)) make_ctx(feature = f),
  ragged_all      = function(f = c(0.2, 0.9)) make_ctx(TRUE, members = c("AAA", "OLD"), feature = f),
  ragged_held     = function(f = c(0.2, 0.9)) make_ctx(TRUE, members = "AAA", positions = c(OLD = 2), feature = f),
  ragged_restrict = function(f = c(0.2, 0.9)) make_ctx(TRUE, members = c("AAA", "OLD"), restricted = c(TRUE, FALSE), feature = f),
  ragged_empty    = function(f = c(0.2, 0.9)) make_ctx(TRUE, members = character(), positions = c(OLD = 2), feature = f)
)

try_run <- function(expr) tryCatch(expr,
  error = function(e) structure(list(msg = conditionMessage(e), class = class(e)[[1]]), class = "probe_error"),
  warning = function(w) structure(list(msg = conditionMessage(w), class = class(w)[[1]]), class = "probe_warning"))
show <- function(x) {
  if (inherits(x, "probe_error")) return(paste0("ERROR <", x$class, ">"))
  if (inherits(x, "probe_warning")) return(paste0("WARN <", x$class, ">"))
  if (is.data.frame(x)) return(paste0("rows=", nrow(x)))
  v <- unclass(x); attributes(v) <- list(names = names(v))
  nm <- if (is.null(names(v))) rep("?", length(v)) else names(v)
  paste0("len=", length(v), " [", paste(sprintf("%s=%s", nm, trimws(format(v))), collapse = " "), "]")
}

rows <- list()
add <- function(context, probe, value) {
  rows[[length(rows) + 1L]] <<- data.frame(context = context, probe = probe, result = value)
}
member_only_signals <- ledgr_signal_strategy(function(ctx) {
  m <- ctx$members %||% ctx$universe
  stats::setNames(rep("LONG", length(m)), m)
}, long_qty = 10)
axis_signals <- ledgr_signal_strategy(function(ctx) {
  stats::setNames(rep("LONG", length(ctx$universe)), ctx$universe)
}, long_qty = 10)

for (cn in names(contexts)) {
  ctx <- contexts[[cn]]()
  sig <- try_run(ledgr_signal_feature(ctx, "return_5"))
  add(cn, "context: universe", paste(ctx$universe, collapse = ","))
  add(cn, "context: ctx$members", if (is.null(ctx$members)) "NULL" else paste(ctx$members, collapse = ","))
  add(cn, "context: eligibility planes in ctx$vec", paste(intersect(c("member", "admissible", "target_restricted"), names(ctx$vec)), collapse = ","))
  add(cn, "read: ctx$vec$feature", show(ctx$vec$feature("return_5")))
  add(cn, "read: ctx$flat()", show(ctx$flat()))
  add(cn, "read: ctx$hold()", show(ctx$hold()))
  add(cn, "read: ctx$tradable()", show(try_run(ctx$tradable())))
  add(cn, "signal: ledgr_signal_feature", show(sig))
  add(cn, "signal: ledgr_signal_return", show(try_run(ledgr_signal_return(ctx, lookback = 5))))
  add(cn, "signal: ledgr_signal(ctx, values)", show(try_run(ledgr_signal(ctx, values = ctx$vec$feature("return_5")))))
  add(cn, "hand-built: flat()[signal > 0.1] <- 10", show(try_run({ t <- ctx$flat(); t[sig > 0.1] <- 10; t })))
  add(cn, "hand-built: flat()[vec$feature > 0.1] <- 10", show(try_run({ t <- ctx$flat(); t[ctx$vec$feature("return_5") > 0.1] <- 10; t })))
  add(cn, "hand-built: flat()[vec$member & vec$feature > 0.1] <- 10", show(try_run({ t <- ctx$flat(); t[ctx$vec$member & ctx$vec$feature("return_5") > 0.1] <- 10; t })))
  add(cn, "selection: ledgr_selection(ctx)", show(try_run(ledgr_selection(ctx))))
  add(cn, "selection: where = vec$feature > 0.1", show(try_run(ledgr_selection(ctx, where = ctx$vec$feature("return_5") > 0.1))))
  add(cn, "selection: where = signal > 0.1", show(try_run(ledgr_selection(ctx, where = sig > 0.1))))
  add(cn, "selection: select_top_n(signal, 1)", show(try_run(ledgr_select_top_n(sig, 1))))
  add(cn, "pipeline: top_n -> equal -> rebalance", show(try_run(
    ledgr_signal_feature(ctx, "return_5") |> ledgr_select_top_n(1) |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx))))
  add(cn, "pipeline: selection(where, exclude) -> target_quantity", show(try_run(
    ctx |> ledgr_selection(where = ledgr_signal_feature(ctx, "return_5") > 0.1, missing = "exclude") |> ledgr_target_quantity(ctx, 10))))
  add(cn, "pipeline: selection(ctx) -> equal -> rebalance", show(try_run(
    ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx))))
  add(cn, "wrapper: signal_strategy(member-only signals)", show(try_run(member_only_signals(ctx, list()))))
  add(cn, "wrapper: signal_strategy(axis signals)", show(try_run(axis_signals(ctx, list()))))
  add(cn, "constructor: ledgr_target(member-only values)", show(try_run(ledgr_target(
    stats::setNames(rep(1, length(ctx$members %||% ctx$universe)), ctx$members %||% ctx$universe), universe = ctx$universe))))
  add(cn, "constructor: ledgr_weights(member-only values)", show(try_run(ledgr_weights(
    stats::setNames(rep(0.5, length(ctx$members %||% ctx$universe)), ctx$members %||% ctx$universe), universe = ctx$universe))))
  add(cn, "view: ctx$features_wide", show(ctx$features_wide))

  first_na <- contexts[[cn]](c(NA, 0.9))
  sig_na <- try_run(ledgr_signal_feature(first_na, "return_5"))
  add(cn, "missing(first): ledgr_signal_feature", show(sig_na))
  add(cn, "missing(first): selection(where = signal > 0.1)", show(try_run(ledgr_selection(first_na, where = sig_na > 0.1))))
  add(cn, "missing(first): selection(where = signal > 0.1, exclude)", show(try_run(ledgr_selection(first_na, where = sig_na > 0.1, missing = "exclude"))))
  add(cn, "missing(first): select_top_n(signal, 2)", show(try_run(ledgr_select_top_n(sig_na, 2))))

  second_na <- contexts[[cn]](c(0.2, NA))
  sig_second <- try_run(ledgr_signal_feature(second_na, "return_5"))
  add(cn, "missing(second): passed_warmup(ctx$vec$feature)", show(try_run(ledgr_passed_warmup(second_na$vec$feature("return_5")))))
  add(cn, "missing(second): passed_warmup(signal)", show(try_run(ledgr_passed_warmup(unclass(sig_second)))))
}

observations <- do.call(rbind, rows)
write.csv(observations, out_path, row.names = FALSE)
cat("wrote", nrow(observations), "observations to", out_path, "\n")
