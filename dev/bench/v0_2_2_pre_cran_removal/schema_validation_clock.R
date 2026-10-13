# Schema validation clock (Cut 14 LDG-3027).
#
#   Rscript schema_validation_clock.R <repo> <label> <out_csv> [repetitions]
#
# One invocation records the five ticket-owned clocks in alternating A/A or
# candidate/pre-cut runs. The caller owns alternation and labels. Stores are
# created outside every clock except small_snapshot. The warm clocks prime the
# session catalogue before timing so they expose repeated-call overhead.
args <- commandArgs(trailingOnly = TRUE)
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(args[[1L]], quiet = TRUE, compile = FALSE)

label <- args[[2L]]
out <- args[[3L]]
repetitions <- if (length(args) >= 4L) as.integer(args[[4L]]) else 8L
pair_offset <- if (length(args) >= 5L) as.integer(args[[5L]]) - 1L else 0L
stopifnot(length(repetitions) == 1L, !is.na(repetitions), repetitions >= 1L)

bars <- data.frame(
  ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:4,
  instrument_id = "AAA",
  open = 10:14,
  high = 11:15,
  low = 9:13,
  close = 10:14,
  volume = 1000
)

store_files <- function(path) c(path, paste0(path, ".wal"))
elapsed <- function(code) {
  gc()
  before <- Sys.time()
  force(code)
  as.numeric(difftime(Sys.time(), before, units = "secs"))
}

rows <- list()
for (repetition in seq_len(repetitions)) {
  comparator_path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(comparator_path)
  DBI::dbDisconnect(con, shutdown = TRUE)

  cold_open_close <- elapsed({
    opened <- ledgr:::ledgr_run_store_open(comparator_path)
    ledgr:::ledgr_run_store_close(opened)
  })

  primed <- ledgr:::ledgr_run_store_open(comparator_path)
  ledgr:::ledgr_validate_schema_once(primed$con)
  ledgr:::ledgr_run_store_close(primed)
  warm_open_validate <- elapsed({
    opened <- ledgr:::ledgr_run_store_open(comparator_path)
    ledgr:::ledgr_validate_schema_once(opened$con)
    ledgr:::ledgr_run_store_close(opened)
  })

  opened <- ledgr:::ledgr_run_store_open(comparator_path)
  ledgr:::ledgr_validate_schema_once(opened$con)
  validate_once <- elapsed({
    ledgr:::ledgr_validate_schema_once(opened$con)
  })
  ledgr:::ledgr_run_store_close(opened)

  reinit <- elapsed({
    con <- ledgr_db_init(comparator_path)
    DBI::dbDisconnect(con, shutdown = TRUE)
  })
  unlink(store_files(comparator_path), force = TRUE)

  snapshot_path <- tempfile(fileext = ".duckdb")
  snapshot <- elapsed({
    value <- ledgr_snapshot_from_df(
      bars,
      db_path = snapshot_path,
      snapshot_id = paste0("small_", repetition)
    )
    ledgr_snapshot_close(value)
  })
  unlink(store_files(snapshot_path), force = TRUE)

  rows[[repetition]] <- data.frame(
    label = label,
    repetition = repetition + pair_offset,
    clock = c(
      "cold_open_close", "warm_open_validate", "validate_schema_once",
      "reinit", "small_snapshot"
    ),
    elapsed_s = c(
      cold_open_close, warm_open_validate, validate_once,
      reinit, snapshot
    ),
    stringsAsFactors = FALSE
  )
}

record <- do.call(rbind, rows)
utils::write.table(
  record,
  out,
  sep = ",",
  row.names = FALSE,
  append = file.exists(out),
  col.names = !file.exists(out)
)
print(record, row.names = FALSE)
