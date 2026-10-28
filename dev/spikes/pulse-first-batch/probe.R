args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) > 0L) args[[1L]] else "."

pkgload::load_all(repo, quiet = TRUE)

sessions <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5
bars <- do.call(rbind, lapply(c("AAA", "BBB"), function(id) {
  offset <- if (identical(id, "AAA")) 0 else 10
  data.frame(
    ts_utc = sessions,
    instrument_id = id,
    open = 100 + offset + 0:5,
    high = 101 + offset + 0:5,
    low = 99 + offset + 0:5,
    close = 100.5 + offset + 0:5,
    volume = 1000,
    stringsAsFactors = FALSE
  )
}))

snapshot <- ledgr_snapshot_from_df(bars)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
strategy <- function(ctx, params) {
  stats::setNames(rep(params$qty, length(ctx$universe)), ctx$universe)
}
exp <- ledgr_experiment(
  snapshot,
  strategy,
  opening = ledgr_opening(cash = 1e6),
  cost_model = ledgr_cost_zero()
)
grid <- ledgr_grid_named(
  one = list(strategy = list(qty = 1)),
  two = list(strategy = list(qty = 2))
)

assign(".pfb_decide_calls", 0L, envir = .GlobalEnv)
trace(
  "ledgr_fold_stage_decide",
  where = asNamespace("ledgr"),
  tracer = quote(.GlobalEnv$.pfb_decide_calls <- .GlobalEnv$.pfb_decide_calls + 1L),
  print = FALSE
)
on.exit({
  untrace("ledgr_fold_stage_decide", where = asNamespace("ledgr"))
  rm(".pfb_decide_calls", envir = .GlobalEnv)
}, add = TRUE)

result <- ledgr_sweep(exp, grid, seed = 41L)
cat(sprintf("candidates=%d\n", nrow(result)))
cat(sprintf("pulses=%d\n", length(sessions)))
cat(sprintf("fold_decide_calls=%d\n", .GlobalEnv$.pfb_decide_calls))
cat(sprintf("expected_candidate_pulses=%d\n", nrow(result) * length(sessions)))
cat(sprintf("statuses=%s\n", paste(result$status, collapse = ",")))
