args <- commandArgs(trailingOnly = TRUE)

.libPaths(c(
  "C:/Users/maxth/AppData/Local/R/win-library/4.6",
  .libPaths()
))

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]),
  winslash = "/"
)
repo <- normalizePath(file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/"
)
pkgload::load_all(repo, quiet = TRUE)

write_snapshot <- function(rows) {
  path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(path)
  DBI::dbExecute(con, "SET threads = 1")
  id <- ledgr_snapshot_create(con, meta = list())
  DBI::dbExecute(
    con,
    paste(
      "INSERT INTO snapshot_instruments",
      "SELECT ?, 'AAA', 'AAA', 'USD', 'equity', 1, 0.01, '{}'"
    ),
    params = list(id)
  )
  DBI::dbExecute(
    con,
    paste0(
      "INSERT INTO snapshot_bars ",
      "SELECT ?, 'AAA', TIMESTAMP '2000-01-01' + i * INTERVAL 1 SECOND, ",
      "100 + i / 100000.0, 101 + i / 100000.0, ",
      "99 + i / 100000.0, 100.25 + i / 100000.0, 1000 + i ",
      "FROM range(CAST(? AS BIGINT)) t(i)"
    ),
    params = list(id, rows)
  )
  list(path = path, con = con, id = id)
}

measure_hash <- function(rows, replicate) {
  snapshot <- write_snapshot(rows)
  on.exit({
    DBI::dbDisconnect(snapshot$con, shutdown = TRUE)
    unlink(snapshot$path)
  }, add = TRUE)
  gc(FALSE)
  started <- proc.time()[["elapsed"]]
  root <- ledgr:::ledgr_snapshot_hash(snapshot$con, snapshot$id)
  elapsed <- proc.time()[["elapsed"]] - started
  data.frame(
    rows = rows,
    replicate = replicate,
    elapsed_seconds = elapsed,
    microseconds_per_bar = elapsed * 1e6 / rows,
    root = root,
    stringsAsFactors = FALSE
  )
}

measure_encoder <- function(rows, replicate) {
  block_rows <- ledgr:::ledgr_snapshot_hash_rule3_block_rows
  sequence <- seq_len(block_rows)
  frame <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2000-01-01", tz = "UTC") + sequence,
    open = 100 + sequence / 100000,
    high = 101 + sequence / 100000,
    low = 99 + sequence / 100000,
    close = 100.25 + sequence / 100000,
    volume = 1000 + sequence,
    stringsAsFactors = FALSE
  )
  fields <- c(
    instrument_id = "text", ts_utc = "time", open = "number",
    high = "number", low = "number", close = "number", volume = "number"
  )
  blocks <- rows / block_rows
  gc(FALSE)
  started <- proc.time()[["elapsed"]]
  checksum <- raw(32L * blocks)
  for (index in seq_len(blocks)) {
    encoded <- ledgr:::ledgr_snapshot_hash_block(
      frame,
      2L,
      index - 1L,
      fields,
      c("instrument_id", "ts_utc")
    )$digest
    first <- (index - 1L) * 32L + 1L
    checksum[first:(first + 31L)] <- encoded
  }
  elapsed <- proc.time()[["elapsed"]] - started
  data.frame(
    rows = rows,
    replicate = replicate,
    elapsed_seconds = elapsed,
    microseconds_per_bar = elapsed * 1e6 / rows,
    checksum = digest::digest(checksum, algo = "sha256", serialize = FALSE),
    stringsAsFactors = FALSE
  )
}

write_fact_snapshot <- function(rows) {
  path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(path)
  id <- ledgr_snapshot_create(con, meta = list())
  DBI::dbExecute(
    con,
    paste(
      "INSERT INTO snapshot_fact_families",
      "VALUES (?, 'membership', 'memory', 1, '{}')"
    ),
    params = list(id)
  )
  DBI::dbExecute(
    con,
    paste0(
      "INSERT INTO snapshot_membership ",
      "SELECT ?, 'm-' || i::VARCHAR, 'I' || (i % 10000)::VARCHAR, ",
      "'memory', 's-' || floor(i / 500)::VARCHAR, ",
      "TIMESTAMP '2000-01-01' + i * INTERVAL 1 SECOND, NULL, ",
      "TIMESTAMP '2000-01-01' + i * INTERVAL 1 SECOND, ",
      "(i % 2) = 0, '{}' FROM range(CAST(? AS BIGINT)) t(i)"
    ),
    params = list(id, rows)
  )
  list(path = path, con = con, id = id)
}

memory_worker <- function(kind, path, id, rows, output) {
  con <- ledgr_db_init(path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  started <- proc.time()[["elapsed"]]
  result <- if (identical(kind, "bars")) {
    root <- ledgr:::ledgr_snapshot_hash(con, id)
    data.frame(
      kind = kind,
      rows = rows,
      elapsed_seconds = proc.time()[["elapsed"]] - started,
      output_bytes = nchar(root, type = "bytes"),
      stringsAsFactors = FALSE
    )
  } else {
    payload <- ledgr:::ledgr_snapshot_availability_hash_payload(con, id)
    data.frame(
      kind = kind,
      rows = rows,
      elapsed_seconds = proc.time()[["elapsed"]] - started,
      output_bytes = nchar(as.character(payload), type = "bytes"),
      stringsAsFactors = FALSE
    )
  }
  saveRDS(result, output)
}

rscript <- function() {
  file.path(R.home("bin"), if (.Platform$OS.type == "windows") {
    "Rscript.exe"
  } else {
    "Rscript"
  })
}

measure_worker <- function(kind, rows) {
  prepared <- if (identical(kind, "bars")) {
    write_snapshot(rows)
  } else {
    write_fact_snapshot(rows)
  }
  DBI::dbDisconnect(prepared$con, shutdown = TRUE)
  on.exit(unlink(prepared$path), add = TRUE)
  output <- tempfile(fileext = ".rds")
  on.exit(unlink(output), add = TRUE)
  process <- processx::process$new(
    rscript(),
    c(script_path, "--worker", kind, prepared$path, prepared$id, rows, output),
    stdout = "|",
    stderr = "|"
  )
  peak <- 0
  while (process$is_alive()) {
    resident <- tryCatch(
      unname(ps::ps_memory_info(ps::ps_handle(process$get_pid()))[["rss"]]),
      error = function(e) NA_real_
    )
    if (is.finite(resident)) peak <- max(peak, resident)
    Sys.sleep(0.02)
  }
  process$wait()
  if (!identical(process$get_exit_status(), 0L)) {
    stop(process$read_all_error(), call. = FALSE)
  }
  result <- readRDS(output)
  result$peak_rss_bytes <- peak
  result
}

if (length(args) == 6L && identical(args[[1L]], "--worker")) {
  memory_worker(
    args[[2L]],
    args[[3L]],
    args[[4L]],
    as.numeric(args[[5L]]),
    args[[6L]]
  )
  quit(save = "no", status = 0L)
}
if (length(args) == 2L && identical(args[[1L]], "--memory")) {
  output_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  memory <- rbind(
    measure_worker("bars", 5000000),
    measure_worker("facts", 300000)
  )
  utils::write.csv(
    memory,
    file.path(output_dir, "memory.csv"),
    row.names = FALSE
  )
  cat("RULE3_PRODUCTION_MEMORY_OK\n")
  quit(save = "no", status = 0L)
}
if (length(args) != 1L) {
  stop(
    "Usage: run_performance.R [--memory] <output-directory>",
    call. = FALSE
  )
}

output_dir <- normalizePath(args[[1L]], winslash = "/", mustWork = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
sizes <- c(500000L, 1000000L, 2000000L, 5000000L)
cost <- do.call(rbind, lapply(sizes, function(rows) {
  do.call(rbind, lapply(1:3, function(replicate) {
    measure_hash(rows, replicate)
  }))
}))
utils::write.csv(cost, file.path(output_dir, "cost.csv"), row.names = FALSE)
encoder <- do.call(rbind, lapply(sizes, function(rows) {
  do.call(rbind, lapply(1:3, function(replicate) {
    measure_encoder(rows, replicate)
  }))
}))
utils::write.csv(
  encoder,
  file.path(output_dir, "encoder.csv"),
  row.names = FALSE
)
memory <- rbind(
  measure_worker("bars", 5000000),
  measure_worker("facts", 300000)
)

utils::write.csv(memory, file.path(output_dir, "memory.csv"), row.names = FALSE)
cat("RULE3_PRODUCTION_PERFORMANCE_OK\n")
