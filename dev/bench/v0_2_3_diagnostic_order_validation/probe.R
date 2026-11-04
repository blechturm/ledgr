args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args) > 0L) args[[1L]] else file.path(
  "dev", "bench", "v0_2_3_diagnostic_order_validation", "record.csv"
)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(".", quiet = TRUE)

n_instruments <- 500L
n_sessions <- 1260L
bars <- as.data.frame(ledgr_sim_bars(
  n_instruments = n_instruments,
  n_days = n_sessions,
  seed = 20261104L
))
first_instrument <- unique(as.character(bars$instrument_id))[[1L]]
snapshot <- ledgr_snapshot_from_df(bars)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
experiment <- ledgr_experiment(
  snapshot,
  function(ctx, params) ctx$hold(),
  opening = ledgr_opening(cash = 1e6),
  cost_model = ledgr_cost_zero()
)
bt <- ledgr_run(experiment, run_id = "diagnostic-order-shape")
on.exit(close(bt), add = TRUE)
opened <- ledgr:::ledgr_backtest_read_connection(bt)
on.exit(opened$close(), add = TRUE)

implicit_count <- DBI::dbGetQuery(
  opened$con,
  "SELECT COUNT(*) AS n FROM run_diagnostic_implicit WHERE run_id = ?",
  params = list(bt$run_id)
)$n[[1L]]
first_ts <- DBI::dbGetQuery(
  opened$con,
  paste(
    "SELECT MIN(ts_utc) AS ts_utc FROM run_diagnostic_implicit",
    "WHERE run_id = ?"
  ),
  params = list(bt$run_id)
)$ts_utc[[1L]]

measure <- function(label, instrument_id = NULL, explain_ts_utc = NULL) {
  gc()
  started <- proc.time()[["elapsed"]]
  result <- ledgr:::ledgr_diagnostic_decision_order_bad(
    opened$con,
    bt$run_id,
    instrument_id = instrument_id,
    explain_ts_utc = explain_ts_utc
  )
  data.frame(
    case = label,
    instruments = n_instruments,
    sessions = n_sessions,
    implicit_rows_in_store = as.numeric(implicit_count),
    result_rows_crossing_dbi = nrow(result),
    result_bytes = as.numeric(object.size(result)),
    elapsed_sec = proc.time()[["elapsed"]] - started,
    stringsAsFactors = FALSE
  )
}

record <- rbind(
  measure("full"),
  measure(
    "one_instrument_one_pulse",
    instrument_id = first_instrument,
    explain_ts_utc = first_ts
  )
)
if (!identical(as.numeric(implicit_count), 630000)) {
  stop("The registered shape did not produce 630,000 implicit rows.")
}
if (any(record$result_rows_crossing_dbi != 0L)) {
  stop("A clean run returned validation detail rows across DBI.")
}
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(record, output, row.names = FALSE, na = "")
print(record)

