# Recursive-indicator history probe (spike protocol section 1).
#
# Rscript dev/spikes/recursive-indicator-history/probe.R <ledgr_repo> <out_dir>
#
# Records, through public runs, how each indicator's values on common days
# depend on where its history starts, what each indicator declares about
# warmup, and which indicators an availability-aware experiment accepts.
# Binds nothing; changes no package file.
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))

n_days <- 80L
day <- function(d) as.POSIXct(paste(as.Date("2020-01-01") + d - 1L, "00:00:00"), tz = "UTC")
iso <- function(d) format(day(d), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
closes <- round(100 + 10 * sin(seq_len(n_days) / 5) + 0.1 * seq_len(n_days), 6)
snapshot <- ledgr_snapshot_from_df(
  data.frame(instrument_id = "AAA", ts_utc = day(seq_len(n_days)), open = closes, high = closes + 1,
             low = closes - 1, close = closes, volume = 1000),
  db_path = tempfile(fileext = ".duckdb")
)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
con <- ledgr:::get_connection(snapshot)

running_max <- ledgr_indicator(
  id = "running_max", fn = function(window) max(window$close),
  series_fn = function(bars, params) cummax(bars$close),
  requires_bars = 1L, stable_after = 1L
)
indicators <- list(
  bounded_sma = ledgr_ind_sma(5L),
  bounded_ema = ledgr_ind_ema(5L),
  recursive_ttr_ema = ledgr_ind_ttr("EMA", input = "close", n = 5L),
  recursive_custom = running_max
)
ids <- vapply(indicators, function(x) x$id, character(1))

rows <- list()
add <- function(probe, indicator, observable, value) {
  rows[[length(rows) + 1L]] <<- data.frame(probe = probe, indicator = indicator, observable = observable,
                                           value = as.character(value), stringsAsFactors = FALSE)
}
for (name in names(indicators)) {
  add("P1 declaration", name, "id", ids[[name]])
  add("P1 declaration", name, "requires_bars", indicators[[name]]$requires_bars)
  add("P1 declaration", name, "stable_after", indicators[[name]]$stable_after)
  add("P1 declaration", name, "gap_contract", indicators[[name]]$gap_contract %||% "none")
}

strategy <- function(ctx, params) {
  values <- vapply(params$ids, function(id) ctx$feature("AAA", id), numeric(1))
  seen <- ctx$state_prev$seen
  seen[[length(seen) + 1L]] <- c(ts = ctx$ts_utc, stats::setNames(format(values, digits = 15), params$ids))
  list(targets = ctx$flat(), state_update = list(seen = seen))
}
seen_from <- function(start_day) {
  exp <- ledgr_experiment(snapshot, strategy, features = unname(indicators),
                          opening = ledgr_opening(cash = 1000, date = iso(start_day)),
                          cost_model = ledgr_cost_zero())
  bt <- ledgr_run(exp, params = list(ids = unname(ids)), run_id = paste0("start-", start_day))
  on.exit(close(bt), add = TRUE)
  json <- DBI::dbGetQuery(con, "SELECT state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc DESC LIMIT 1",
                          params = list(bt$run_id))$state_json[[1L]]
  seen <- ledgr:::ledgr_json_read_nested(json)$seen
  out <- do.call(rbind, lapply(seen, function(x) as.data.frame(as.list(unlist(x)), stringsAsFactors = FALSE)))
  out$ts <- substr(out$ts, 1, 10)
  out
}
starts <- c(1L, 21L, 41L)
seen <- lapply(starts, seen_from)
names(seen) <- paste0("start_", starts)

# P2: values on the common days 41-80 by history start.
common <- seen$start_41$ts
for (name in names(indicators)) {
  id <- make.names(ids[[name]])
  series <- lapply(seen, function(s) suppressWarnings(as.numeric(s[[id]][match(common, s$ts)])))
  for (other in c("start_21", "start_41")) {
    diff <- abs(series$start_1 - series[[other]])
    first_within <- function(tol) {
      ok <- !is.na(diff) & diff < tol
      if (any(ok)) common[which(ok)[[1L]]] else "not by day 80"
    }
    add("P2 history start", name, paste0("max_abs_diff_vs_", other), format(max(diff, na.rm = TRUE), digits = 6))
    add("P2 history start", name, paste0("final_day_abs_diff_vs_", other), format(diff[[length(diff)]], digits = 6))
    add("P2 history start", name, paste0("first_day_within_1e-9_vs_", other), first_within(1e-9))
    add("P2 history start", name, paste0("first_day_within_1e-6_vs_", other), first_within(1e-6))
    add("P2 history start", name, paste0("na_days_", other), sum(is.na(series[[other]])))
  }
}

# P3: availability-aware experiments accept an indicator only if it declares
# `gap_contract = "strict_window"`. P3b then runs a recursive indicator that
# declares it and compares what the strategy sees with its own series_fn.
avail_snapshot <- ledgr_snapshot_from_df(
  data.frame(instrument_id = "AAA", ts_utc = day(seq_len(10)) + 16 * 3600, open = closes[1:10],
             high = closes[1:10] + 1, low = closes[1:10] - 1, close = closes[1:10], volume = 1000),
  facts = ledgr_facts(ledgr_facts_sessions(
    data.frame(session_date = as.Date(day(seq_len(10))), status = "open", session_open = "09:30:00",
               session_close = "16:00:00", knowledge_time = day(seq_len(10)) - 1),
    venue_id = "XNYS")),
  price_basis = "split_adjusted", db_path = tempfile(fileext = ".duckdb")
)
on.exit(ledgr_snapshot_close(avail_snapshot), add = TRUE)
for (name in names(indicators)) {
  outcome <- tryCatch({
    ledgr_experiment(avail_snapshot, function(ctx, params) ctx$flat(), features = list(indicators[[name]]),
                     valuation_policy = ledgr_valuation_stale(1L), cost_model = ledgr_cost_zero())
    "accepted"
  }, error = function(e) class(e)[[1L]])
  add("P3 availability", name, "experiment", outcome)
}
running_max_strict <- ledgr_indicator(
  id = "running_max_strict", fn = function(window) max(window$close),
  series_fn = function(bars, params) cummax(bars$close),
  requires_bars = 1L, stable_after = 1L, gap_contract = "strict_window"
)
strict_strategy <- function(ctx, params) {
  value <- ctx$feature("AAA", "running_max_strict")
  list(targets = ctx$flat(), state_update = list(seen = c(ctx$state_prev$seen, format(value, digits = 15))))
}
strict_outcome <- tryCatch({
  bt <- ledgr_run(ledgr_experiment(avail_snapshot, strict_strategy, features = list(running_max_strict),
                                   valuation_policy = ledgr_valuation_stale(1L), cost_model = ledgr_cost_zero()),
                  run_id = "strict-running-max")
  avail_con <- ledgr:::get_connection(avail_snapshot)
  json <- DBI::dbGetQuery(avail_con, "SELECT state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc DESC LIMIT 1",
                          params = list(bt$run_id))$state_json[[1L]]
  status <- ledgr_run_info(avail_snapshot, bt$run_id)$status
  close(bt)
  seen <- as.numeric(ledgr:::ledgr_json_read_nested(json)$seen)
  c(status = status, seen = paste(format(seen, digits = 10), collapse = ","),
    series_fn_cummax = paste(format(cummax(closes[1:10]), digits = 10), collapse = ","),
    fn_window_close = paste(format(closes[1:10], digits = 10), collapse = ","))
}, error = function(e) c(error = paste(class(e)[[1L]], conditionMessage(e))))
for (key in names(strict_outcome)) add("P3b declared strict recursion", "running_max_strict", key, strict_outcome[[key]])

out <- do.call(rbind, rows)
utils::write.csv(out, file.path(out_dir, "probe_evidence.csv"), row.names = FALSE)
print(out, row.names = FALSE, right = FALSE)
