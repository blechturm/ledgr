# Schema validation clock (Cut 14 LDG-3027).
#
#   Rscript schema_validation_clock.R <repo> <label> <out_csv> [repetitions]
#
# One invocation records the three ticket-owned clocks in alternating A/A or
# candidate/pre-cut runs. The caller owns alternation and labels. Each timed
# operation uses a fresh durable store where construction is part of the
# named clock. The comparator clears the process-local validation cache so it
# measures ledgr_run_store_open() plus one full ledgr_validate_schema_once().
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
  rm(
    list = ls(ledgr:::.ledgr_schema_validation_cache, all.names = TRUE),
    envir = ledgr:::.ledgr_schema_validation_cache
  )
  comparator <- elapsed({
    opened <- ledgr:::ledgr_run_store_open(comparator_path)
    ledgr:::ledgr_validate_schema_once(opened$con)
    ledgr:::ledgr_run_store_close(opened)
  })
  unlink(store_files(comparator_path), force = TRUE)

  init_path <- tempfile(fileext = ".duckdb")
  init <- elapsed({
    con <- ledgr_db_init(init_path)
    DBI::dbDisconnect(con, shutdown = TRUE)
  })
  unlink(store_files(init_path), force = TRUE)

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
    clock = c("open_validate", "db_init", "small_snapshot"),
    elapsed_s = c(comparator, init, snapshot),
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
