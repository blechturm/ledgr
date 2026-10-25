args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("usage: run_record.R <package-root> <arm> <output.csv>")
}
package_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
arm <- args[[2L]]
output <- args[[3L]]

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(package_root, quiet = TRUE)

hash_object <- function(x) {
  digest::digest(serialize(x, NULL, version = 3L), algo = "sha256")
}

buy <- 0.89101464257119367
sell <- 0.89101464257119356
residue <- buy - sell
pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:4
bars <- data.frame(
  ts_utc = pulses,
  instrument_id = "AAA",
  open = 100,
  high = 101,
  low = 99,
  close = 100,
  volume = 1000,
  stringsAsFactors = FALSE
)
snapshot <- ledgr_snapshot_from_df(bars, price_basis = "split_adjusted")
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
strategy <- function(ctx, params) c(AAA = params$residue)
experiment <- ledgr_experiment(
  snapshot,
  strategy,
  opening = ledgr_opening(
    cash = 1000,
    positions = c(AAA = buy),
    cost_basis = c(AAA = 100)
  ),
  cost_model = ledgr_cost_zero()
)
run <- ledgr_run(
  experiment,
  params = list(residue = residue),
  run_id = "ws59-record"
)
on.exit(close(run), add = TRUE)
opened <- ledgr:::ledgr_store_open(run$db_path, mode = "open")
on.exit({
  DBI::dbDisconnect(opened$con, shutdown = TRUE)
  duckdb::duckdb_shutdown(opened$drv)
}, add = TRUE)
run_row <- DBI::dbGetQuery(
  opened$con,
  "SELECT config_hash, metric_context_hash FROM runs WHERE run_id = ?",
  params = list(run$run_id)
)
state <- ledgr_state_reconstruct(run$run_id, opened$con)
ledger <- as.data.frame(ledgr_results(run, "ledger"))
fills <- as.data.frame(ledgr_run_fills(run))
equity <- as.data.frame(ledgr_results(run, "equity"))
metrics <- ledgr_compute_metrics(run)
metric_values <- unclass(metrics)
attributes(metric_values) <- list(names = names(metrics))
default_context <- ledgr_metric_context()
explicit_context <- ledgr_metric_us_equity()
headline <- ledgr:::ledgr_corporate_action_headline(
  list(corporate_action_fidelity = "not_supplied")
)

record <- data.frame(
  arm = arm,
  field = c(
    "run_id", "config_hash", "metric_context_hash", "ledger_hash",
    "fills_hash", "equity_hash", "equity_final", "equity_cash_hash",
    "metrics_value_hash", "position_after",
    "default_calendar_label", "explicit_calendar_label",
    "default_metric_hash", "explicit_metric_hash", "headline"
  ),
  value = c(
    run$run_id,
    run_row$config_hash[[1L]],
    run_row$metric_context_hash[[1L]],
    hash_object(ledger),
    hash_object(fills),
    hash_object(equity),
    format(equity$equity[[nrow(equity)]], digits = 17L, scientific = TRUE),
    hash_object(equity$cash),
    hash_object(metric_values),
    format(state$positions$qty[[1L]], digits = 17L, scientific = TRUE),
    default_context$calendar$label,
    explicit_context$calendar$label,
    ledgr_metric_context_hash(default_context),
    ledgr_metric_context_hash(explicit_context),
    headline
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(record, output, row.names = FALSE, na = "")
