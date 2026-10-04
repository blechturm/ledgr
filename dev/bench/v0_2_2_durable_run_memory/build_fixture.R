bench_lib <- Sys.getenv("LEDGR_BENCH_LIB", "")
if (nzchar(bench_lib)) .libPaths(c(bench_lib, .libPaths()))

args <- commandArgs(TRUE)
if (length(args) != 2L) stop("Usage: build_fixture.R <repo> <out_dir>")
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
source(file.path(script, "helpers.R"), local = TRUE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
probe <- lwreg_build_fixture(memory_fixture_row(), out_dir)
availability_db <- file.path(out_dir, "snapshot.duckdb")
availability_snapshot <- ledgr_snapshot_open(availability_db)
availability_con <- ledgr:::ledgr_snapshot_connection(availability_snapshot)$con
bars <- DBI::dbGetQuery(
  availability_con,
  "SELECT ts_utc, instrument_id, open, high, low, close, volume
   FROM snapshot_bars WHERE snapshot_id = ?
   ORDER BY instrument_id, ts_utc",
  params = list(availability_snapshot$snapshot_id)
)
instruments <- DBI::dbGetQuery(
  availability_con,
  "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ?
   ORDER BY instrument_id",
  params = list(availability_snapshot$snapshot_id)
)
ledgr_snapshot_close(availability_snapshot)
dense_db <- file.path(out_dir, "dense.duckdb")
unlink(c(dense_db, paste0(dense_db, ".wal")))
dense_snapshot <- ledgr_snapshot_from_df(
  bars,
  instruments_df = instruments,
  db_path = dense_db,
  snapshot_id = "durable_memory_dense"
)
ledgr_snapshot_close(dense_snapshot)
cat("DURABLE_MEMORY_FIXTURE_OK", probe$bar_rows, "bars\n")
