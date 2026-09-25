args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop(
    paste(
      "usage: workstream14_fact_scaling.R",
      "<fixture> <variant> <rows> <repetition> <output>"
    ),
    call. = FALSE
  )
}

fixture_path <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
variant <- args[[2L]]
fact_rows <- as.integer(args[[3L]])
repetition <- as.integer(args[[4L]])
output_path <- args[[5L]]

pkgload::load_all(".", quiet = TRUE)
source(fixture_path, local = environment())

bars <- ws14_scale_bars()
instruments <- ws14_scale_instruments()
construct_seconds <- 0
facts <- NULL
if (fact_rows >= 0L) {
  construct_seconds <- system.time({
    facts <- ws14_scale_facts(fact_rows)
  })[["elapsed"]]
}

db_path <- tempfile(fileext = ".duckdb")
on.exit(unlink(c(db_path, paste0(db_path, ".wal")), force = TRUE), add = TRUE)
gc()
seal_seconds <- system.time({
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = instruments,
    db_path = db_path,
    facts = facts
  )
})[["elapsed"]]
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

experiment_args <- list(
  snapshot,
  function(ctx, params) ctx$flat(),
  universe = instruments$instrument_id,
  cost_model = ledgr_cost_zero()
)
if (!is.null(facts)) {
  experiment_args$valuation_policy <- ledgr_valuation_stale(2L)
}
experiment <- do.call(ledgr_experiment, experiment_args)
run_id <- sprintf("ws14-%s-%d-%d", variant, fact_rows, repetition)
gc()
run_seconds <- system.time({
  backtest <- ledgr_run(experiment, run_id = run_id)
})[["elapsed"]]
on.exit(close(backtest), add = TRUE)

record <- data.frame(
  variant = variant,
  fact_rows = fact_rows,
  repetition = repetition,
  constructor_seconds = construct_seconds,
  seal_seconds = seal_seconds,
  run_seconds = run_seconds,
  snapshot_hash = ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]],
  run_status = ledgr_run_info(snapshot, run_id)$status,
  stringsAsFactors = FALSE
)
write.table(
  record,
  file = output_path,
  append = file.exists(output_path),
  col.names = !file.exists(output_path),
  row.names = FALSE,
  quote = TRUE,
  sep = ","
)
print(record)
