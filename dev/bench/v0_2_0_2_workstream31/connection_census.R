# Workstream 31 connection census (LDG-2915).
#
# Usage, from any directory:
#
#   Rscript dev/bench/v0_2_0_2_workstream31/connection_census.R <tree> <arm> <out.csv>
#
# Loads the ledgr source tree <tree>, runs one small pipeline against one
# store, and appends one row per public call to <out.csv>, labelled <arm>.
# Every DuckDB connection ledgr makes goes through `DBI::dbConnect()`, which
# the harness wraps to record the connection and the file it opens. Per call it
# reports the connections opened, the distinct files they opened, the most
# opens of any one file, and how many connections opened so far in the
# pipeline, by this call or any earlier one, are still live when it returns.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]; arm <- args[[2L]]; out_path <- args[[3L]]
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))

log <- new.env()
log$cons <- list()
log$files <- character()
log$all <- list()
real_connect <- DBI::dbConnect
testthat::local_mocked_bindings(
  dbConnect = function(drv, ...) {
    con <- real_connect(drv, ...)
    dbdir <- list(...)$dbdir
    log$cons[[length(log$cons) + 1L]] <- con
    log$all[[length(log$all) + 1L]] <- con
    log$files <- c(log$files, if (is.null(dbdir)) ":memory:" else normalizePath(dbdir, mustWork = FALSE))
    con
  },
  .package = "DBI"
)

rows <- list()
census <- function(call, expr) {
  log$cons <- list()
  log$files <- character()
  force(expr)
  per_file <- table(log$files)
  rows[[length(rows) + 1L]] <<- data.frame(
    arm = arm,
    call = call,
    opens = length(log$cons),
    files = length(per_file),
    max_opens_per_file = if (length(per_file)) max(per_file) else 0L,
    live_after = sum(vapply(log$all, DBI::dbIsValid, logical(1)))
  )
  invisible(NULL)
}

bars <- data.frame(
  ts_utc = rep(as.POSIXct(paste(as.Date("2026-02-02") + 0:3, "16:00:00"), tz = "UTC"), each = 2L),
  instrument_id = rep(c("AAA", "BBB"), 4L),
  open = 10, high = 10, low = 10, close = 10, volume = 1000
)
db_path <- tempfile(fileext = ".duckdb")
strategy <- function(ctx, params) ctx$flat()
s <- new.env()

census("ledgr_snapshot_from_df", s$snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "census"))
census("ledgr_snapshot_list", ledgr_snapshot_list(db_path))
census("ledgr_experiment", s$exp <- ledgr_experiment(
  s$snapshot, strategy, opening = ledgr_opening(cash = 1000), cost_model = ledgr_cost_zero()
))
census("ledgr_run", s$bt <- suppressWarnings(ledgr_run(s$exp, run_id = "census_1")))
census("ledgr_run (second)", s$bt2 <- suppressWarnings(ledgr_run(s$exp, run_id = "census_2")))
census("print", utils::capture.output(print(s$bt)))
census("summary", utils::capture.output(summary(s$bt)))
census("ledgr_results fills", ledgr_results(s$bt, "fills"))
census("ledgr_results equity", ledgr_results(s$bt, "equity"))
census("close", close(s$bt))
census("close (second)", close(s$bt2))
census("ledgr_run_list", ledgr_run_list(s$snapshot))
census("ledgr_run_info", ledgr_run_info(s$snapshot, "census_1"))
census("ledgr_run_open", s$reopened <- ledgr_run_open(s$snapshot, "census_1"))
census("close (reopened)", close(s$reopened))
census("ledgr_snapshot_info", ledgr_snapshot_info(s$snapshot))
census("ledgr_feature_contract_check", ledgr_feature_contract_check(s$snapshot, list(ledgr_ind_returns(1))))
s$grid <- ledgr_param_grid(a = list(), b = list())
census("ledgr_precompute_features", s$precomputed <- ledgr_precompute_features(s$exp, s$grid))
census("ledgr_sweep", suppressWarnings(ledgr_sweep(s$exp, s$grid)))
census("ledgr_sweep (precomputed)", suppressWarnings(ledgr_sweep(s$exp, s$grid, precomputed_features = s$precomputed)))
census("ledgr_backtest", s$bt3 <- suppressWarnings(ledgr_backtest(
  snapshot = s$snapshot, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero()
)))
census("close (backtest)", close(s$bt3))
census("ledgr_db_init", DBI::dbDisconnect(ledgr_db_init(db_path), shutdown = TRUE))
census("ledgr_snapshot_close", ledgr_snapshot_close(s$snapshot))

out <- do.call(rbind, rows)
utils::write.table(out, out_path, sep = ",", row.names = FALSE, col.names = !file.exists(out_path),
  append = file.exists(out_path))
print(out[, -1L], row.names = FALSE)
