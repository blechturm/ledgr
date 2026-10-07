# Recursive-indicator history spike runner.
#
# Rscript dev/spikes/recursive-indicator-history/spike_runner.R <ledgr_repo> <out_dir> [--gut]
#
# Charter: inst/design/spikes/recursive_indicator_history_spike/charter.md.
# Classifies each indicator by history sensitivity (series computed from three
# history starts, compared on common days after warmup) and flags an indicator
# that is not bounded but declares `strict_window`. `--gut` replaces history
# sensitivity with the shipped window-local certification (fn against
# series_fn over the same window). Writes prerequisite.csv and
# classification.csv. Binds nothing; changes no package file.
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
gut <- "--gut" %in% args
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
engine <- ledgr:::ledgr_compute_feature_series

n_bars <- 120L
day <- function(d) as.POSIXct(paste(as.Date("2020-01-01") + d - 1L, "00:00:00"), tz = "UTC")
iso <- function(d) format(day(d), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
paths <- list(
  sine = round(100 + 10 * sin(seq_len(n_bars) / 5) + 0.1 * seq_len(n_bars), 6),
  walk = local({
    set.seed(20261008L)
    round(100 + cumsum(stats::rnorm(n_bars)), 6)
  })
)
bars_for <- function(closes) {
  data.frame(instrument_id = "AAA", ts_utc = day(seq_along(closes)), open = closes,
             high = closes + 1, low = closes - 1, close = closes, volume = 1000)
}

rolling_max <- function(x, n) {
  out <- rep(NA_real_, length(x))
  if (length(x) >= n) out[n:length(x)] <- apply(stats::embed(x, n), 1L, max)
  out
}
running_max <- function(id, gap_contract = NULL) {
  ledgr_indicator(id = id, fn = function(window) max(window$close),
                  series_fn = function(bars, params) cummax(bars$close),
                  requires_bars = 1L, stable_after = 1L, gap_contract = gap_contract)
}
indicators <- list(
  sma5 = ledgr_ind_sma(5L),
  sma20 = ledgr_ind_sma(20L),
  ledgr_ema5 = ledgr_ind_ema(5L),
  rolling_max5 = ledgr_indicator(
    id = "rolling_max5", fn = function(window) max(window$close),
    series_fn = function(bars, params) rolling_max(bars$close, 5L),
    requires_bars = 5L, stable_after = 5L
  ),
  ttr_ema5 = ledgr_ind_ttr("EMA", input = "close", n = 5L),
  ttr_rsi14 = ledgr_ind_ttr("RSI", input = "close", n = 14L),
  running_max = running_max("running_max"),
  running_max_strict = running_max("running_max_strict", "strict_window")
)

# Prerequisite: the engine reproduces what a public dense run sees.
strategy <- function(ctx, params) {
  # 17 significant digits round-trip a double exactly; JSON state refuses NA.
  values <- vapply(params$ids, function(id) sprintf("%.17g", ctx$feature("AAA", id)), character(1))
  list(targets = ctx$flat(),
       state_update = list(seen = c(ctx$state_prev$seen, list(stats::setNames(as.list(values), params$ids)))))
}
prerequisite <- list()
for (path in names(paths)) {
  bars <- bars_for(paths[[path]])
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  exp <- ledgr_experiment(snapshot, strategy, features = unname(indicators),
                          opening = ledgr_opening(cash = 1000), cost_model = ledgr_cost_zero())
  ids <- vapply(indicators, function(x) x$id, character(1))
  bt <- ledgr_run(exp, params = list(ids = unname(ids)), run_id = paste0("prerequisite-", path))
  json <- DBI::dbGetQuery(ledgr:::get_connection(snapshot),
                          "SELECT state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc DESC LIMIT 1",
                          params = list(bt$run_id))$state_json[[1L]]
  close(bt)
  seen <- ledgr:::ledgr_json_read_nested(json)$seen
  for (name in names(indicators)) {
    run_values <- vapply(seen, function(x) suppressWarnings(as.numeric(x[[ids[[name]]]])), numeric(1))
    engine_values <- engine(bars, indicators[[name]])
    same_na <- identical(is.na(run_values), is.na(engine_values))
    exact <- same_na && identical(run_values[!is.na(run_values)], engine_values[!is.na(engine_values)])
    prerequisite[[length(prerequisite) + 1L]] <- data.frame(
      path = path, indicator = name, bars = length(run_values), na_pattern_equal = same_na,
      values_identical = exact, stringsAsFactors = FALSE)
  }
  ledgr_snapshot_close(snapshot)
}
prerequisite <- do.call(rbind, prerequisite)

# History sensitivity: gaps between the full-history series and series started
# at later bars, on common days after the later series' warmup.
starts <- c(31L, 61L)
gaps_from <- function(indicator, bars, start) {
  full <- engine(bars, indicator)
  later <- rep(NA_real_, nrow(bars))
  later[start:nrow(bars)] <- engine(bars[start:nrow(bars), , drop = FALSE], indicator)
  ok <- !is.na(full) & !is.na(later)
  list(gap = abs(full - later)[ok], scale = pmax(1, abs(full[ok])))
}
# Gut: the shipped window-local certification, fn against series_fn over the
# same declared window, at every position with a full window.
window_gaps <- function(indicator, bars) {
  width <- as.integer(indicator$requires_bars)
  positions <- seq.int(width, nrow(bars))
  gap <- vapply(positions, function(i) {
    window <- bars[(i - width + 1L):i, , drop = FALSE]
    series <- engine(window, indicator)
    value <- ledgr:::ledgr_call_feature_fn(indicator$fn, window, indicator$params %||% list())
    abs(as.numeric(value) - series[[width]])
  }, numeric(1))
  list(gap = gap[!is.na(gap)], scale = rep(1, sum(!is.na(gap))))
}

tolerance <- 1e-9
classify <- function(indicator, bars) {
  if (gut) {
    g <- window_gaps(indicator, bars)
    sensitive <- any(g$gap > tolerance * g$scale)
    return(list(max_gap_31 = max(g$gap), max_gap_61 = NA_real_, final_gap_61 = NA_real_,
                nondecreasing_steps_61 = NA_integer_, class = if (sensitive) "history_dependent" else "bounded"))
  }
  g31 <- gaps_from(indicator, bars, starts[[1L]])
  g61 <- gaps_from(indicator, bars, starts[[2L]])
  sensitive <- any(g31$gap > tolerance * g31$scale) || any(g61$gap > tolerance * g61$scale)
  above <- g61$gap[g61$gap > tolerance * g61$scale]
  nondecreasing <- if (length(above) > 1L) sum(diff(above) >= 0) else 0L
  class <- if (!sensitive) "bounded" else if (nondecreasing == 0L) "decaying" else "path_dependent"
  list(max_gap_31 = max(g31$gap), max_gap_61 = max(g61$gap), final_gap_61 = g61$gap[[length(g61$gap)]],
       nondecreasing_steps_61 = nondecreasing, class = class)
}

classification <- list()
for (path in names(paths)) {
  bars <- bars_for(paths[[path]])
  for (name in names(indicators)) {
    ind <- indicators[[name]]
    result <- classify(ind, bars)
    contract <- ind$gap_contract %||% "none"
    classification[[length(classification) + 1L]] <- data.frame(
      path = path, indicator = name, requires_bars = ind$requires_bars, stable_after = ind$stable_after,
      gap_contract = contract, tolerance = tolerance,
      max_gap_31 = signif(result$max_gap_31, 6), max_gap_61 = signif(result$max_gap_61, 6),
      final_gap_61 = signif(result$final_gap_61, 6), nondecreasing_steps_61 = result$nondecreasing_steps_61,
      class = result$class,
      p3b_flag = result$class != "bounded" && identical(contract, "strict_window"),
      mode = if (gut) "gut_window_local" else "history_sensitivity",
      stringsAsFactors = FALSE)
  }
}
classification <- do.call(rbind, classification)

utils::write.csv(prerequisite, file.path(out_dir, "prerequisite.csv"), row.names = FALSE)
utils::write.csv(classification, file.path(out_dir, "classification.csv"), row.names = FALSE)
print(prerequisite, row.names = FALSE)
print(classification[, c("path", "indicator", "gap_contract", "max_gap_31", "max_gap_61", "final_gap_61",
                         "nondecreasing_steps_61", "class", "p3b_flag")], row.names = FALSE)
