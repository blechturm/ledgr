insert_test_run <- function(con, run_id) {
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (
      run_id,
      created_at_utc,
      engine_version,
      config_json,
      config_hash,
      status,
      error_msg
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ",
    params = list(
      run_id,
      as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
      "0.1.0",
      "{}",
      "config-hash",
      "CREATED",
      NA_character_
    )
  )
}

parse_meta <- function(x) {
  ledgr:::ledgr_json_read_config(x)
}

fake_write_result <- function(run_id, i) {
  row <- data.frame(
    event_id = sprintf("%s_%08d", run_id, i),
    run_id = run_id,
    ts_utc = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + i,
    event_type = "FILL",
    instrument_id = "AAA",
    side = "BUY",
    qty = as.numeric(i),
    price = 100,
    fee = 0,
    meta_json = canonical_json(list(cash_delta = -100 * i, position_delta = i, realized_pnl = NULL)),
    event_seq = as.integer(i),
    stringsAsFactors = FALSE
  )
  structure(
    list(
      status = "WROTE",
      row = row,
      cash_delta = -100 * i,
      position_delta = i,
      meta = list(cash_delta = -100 * i, position_delta = i, realized_pnl = NULL)
    ),
    class = "ledgr_ledger_write_result"
  )
}

testthat::test_that("BUY fill writes a correct FILL ledger event", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-1"
  insert_test_run(con, run_id)

  fill <- ledgr_test_next_open_fill(
    desired_qty_delta = 2,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 100),
    spread_bps = 10,
    commission_fixed = 1.25
  )

  res <- ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 1L)
  testthat::expect_identical(res$status, "WROTE")
  testthat::expect_identical(res$event_id, "run-ledger-1_00000001")
  testthat::expect_identical(res$event_seq, 1L)
  testthat::expect_identical(res$next_event_seq, 2L)

  row <- DBI::dbGetQuery(
    con,
    "
    SELECT *
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
    ",
    params = list(run_id)
  )
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_identical(row$event_type[[1]], "FILL")
  testthat::expect_identical(row$instrument_id[[1]], "AAA")
  testthat::expect_identical(row$side[[1]], "BUY")
  testthat::expect_equal(row$qty[[1]], 2)
  testthat::expect_equal(row$price[[1]], round(100 * (1 + 10 / 20000), 8))
  testthat::expect_equal(row$fee[[1]], 1.25)

  meta <- parse_meta(row$meta_json[[1]])
  testthat::expect_equal(meta$fee, 1.25)
  testthat::expect_equal(meta$position_delta, 2)
  testthat::expect_equal(meta$cash_delta, -(2 * row$price[[1]] + 1.25))
})

testthat::test_that("persistent output handler preserves buffered fill writes", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-buffered-handler"
  insert_test_run(con, run_id)

  handler <- ledgr:::ledgr_persistent_output_handler(
    con = con,
    run_id = run_id,
    run_wall_start = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    execution_mode = "audit_log",
    persist_features = FALSE
  )
  handler$init_buffers(1L)

  fill <- ledgr_test_next_open_fill(
    desired_qty_delta = 2,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 100),
    spread_bps = 10,
    commission_fixed = 1.25
  )

  res <- handler$write_fill_events(fill, 1L, use_transaction = FALSE)
  testthat::expect_identical(res$status, "WROTE")
  testthat::expect_identical(handler$pending_event_count(), 1L)
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]],
    0
  )

  handler$flush_pending()
  testthat::expect_identical(handler$pending_event_count(), 0L)
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]],
    1
  )
})

testthat::test_that("persistent output handler grows event buffer without changing rows", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-buffered-grow"
  insert_test_run(con, run_id)

  handler <- ledgr:::ledgr_persistent_output_handler(
    con = con,
    run_id = run_id,
    run_wall_start = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    execution_mode = "audit_log",
    persist_features = FALSE
  )
  n_events <- 1025L
  handler$init_buffers(n_events)
  for (i in seq_len(n_events)) {
    handler$buffer_event(fake_write_result(run_id, i))
  }
  testthat::expect_identical(handler$pending_event_count(), n_events)
  handler$flush_pending()

  rows <- DBI::dbGetQuery(
    con,
    "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq",
    params = list(run_id)
  )
  testthat::expect_equal(nrow(rows), n_events)
  testthat::expect_identical(rows$event_id[[1]], "run-ledger-buffered-grow_00000001")
  testthat::expect_identical(rows$event_id[[n_events]], "run-ledger-buffered-grow_00001025")
  testthat::expect_s3_class(rows$ts_utc, "POSIXct")
  testthat::expect_identical(attr(rows$ts_utc, "tzone"), "UTC")
  testthat::expect_true(all(grepl("^\\{", rows$meta_json)))
})

testthat::test_that("persistent output handler preserves all pending event columns", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-buffered-columns"
  insert_test_run(con, run_id)

  handler <- ledgr:::ledgr_persistent_output_handler(
    con = con,
    run_id = run_id,
    run_wall_start = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    execution_mode = "audit_log",
    persist_features = FALSE
  )
  handler$init_buffers(3L)
  for (i in seq_len(3L)) {
    testthat::expect_true(handler$buffer_event(fake_write_result(run_id, i)))
  }
  handler$flush_pending()

  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT event_id, run_id, ts_utc, event_type, instrument_id, side,
           qty, price, fee, meta_json, event_seq
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
    ",
    params = list(run_id)
  )
  expected <- do.call(rbind, lapply(seq_len(3L), function(i) fake_write_result(run_id, i)$row))
  testthat::expect_identical(rows$event_id, expected$event_id)
  testthat::expect_identical(rows$run_id, expected$run_id)
  testthat::expect_equal(
    as.POSIXct(rows$ts_utc, tz = "UTC"),
    as.POSIXct(expected$ts_utc, tz = "UTC")
  )
  testthat::expect_identical(rows$event_type, expected$event_type)
  testthat::expect_identical(rows$instrument_id, expected$instrument_id)
  testthat::expect_identical(rows$side, expected$side)
  testthat::expect_equal(rows$qty, expected$qty)
  testthat::expect_equal(rows$price, expected$price)
  testthat::expect_equal(rows$fee, expected$fee)
  testthat::expect_identical(rows$meta_json, as.character(expected$meta_json))
  testthat::expect_identical(as.integer(rows$event_seq), expected$event_seq)
})

testthat::test_that("persistent output handler preserves full columns across growth", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-buffered-growth-columns"
  insert_test_run(con, run_id)

  handler <- ledgr:::ledgr_persistent_output_handler(
    con = con,
    run_id = run_id,
    run_wall_start = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    execution_mode = "audit_log",
    persist_features = FALSE
  )
  n_events <- 1025L
  handler$init_buffers(n_events)
  fills <- lapply(seq_len(n_events), function(i) {
    ledgr_test_next_open_fill(
      desired_qty_delta = i,
      next_bar = list(
        instrument_id = sprintf("inst-%04d", i),
        ts_utc = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + i,
        open = 100 + i
      ),
      spread_bps = 0,
      commission_fixed = i / 100
    )
  })
  expected <- vector("list", n_events)
  for (i in seq_len(n_events)) {
    write_res <- ledgr:::ledgr_fill_event_row(run_id, fills[[i]], i)
    expected[[i]] <- write_res$row
    testthat::expect_true(handler$buffer_event(write_res))
  }
  handler$flush_pending()

  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT event_id, run_id, ts_utc, event_type, instrument_id, side,
           qty, price, fee, meta_json, event_seq
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
    ",
    params = list(run_id)
  )
  expected <- do.call(rbind.data.frame, c(expected, list(stringsAsFactors = FALSE)))
  testthat::expect_identical(rows$event_id, expected$event_id)
  testthat::expect_identical(rows$run_id, expected$run_id)
  testthat::expect_equal(
    as.POSIXct(rows$ts_utc, tz = "UTC"),
    as.POSIXct(expected$ts_utc, tz = "UTC")
  )
  testthat::expect_identical(rows$event_type, expected$event_type)
  testthat::expect_identical(rows$instrument_id, expected$instrument_id)
  testthat::expect_identical(rows$side, expected$side)
  testthat::expect_equal(rows$qty, expected$qty)
  testthat::expect_equal(rows$price, expected$price)
  testthat::expect_equal(rows$fee, expected$fee)
  testthat::expect_identical(rows$meta_json, as.character(expected$meta_json))
  testthat::expect_identical(as.integer(rows$event_seq), expected$event_seq)
})

testthat::test_that("persistent output handler enforces hard event cap", {
  handler <- ledgr:::ledgr_persistent_output_handler(
    con = NULL,
    run_id = "run-ledger-buffered-cap",
    run_wall_start = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    execution_mode = "audit_log",
    persist_features = FALSE
  )
  handler$init_buffers(1L)
  testthat::expect_true(handler$buffer_event(fake_write_result("run-ledger-buffered-cap", 1L)))
  testthat::expect_error(
    handler$buffer_event(fake_write_result("run-ledger-buffered-cap", 2L)),
    class = "ledgr_event_buffer_capacity_exceeded"
  )
})

testthat::test_that("memory output handler grows event buffer and preserves event surface", {
  run_id <- "run-memory-buffered-grow"
  handler <- ledgr:::ledgr_memory_output_handler(run_id)
  n_events <- 1025L
  handler$init_buffers(n_events)
  for (i in seq_len(n_events)) {
    handler$buffer_event(fake_write_result(run_id, i))
  }

  events <- handler$events()
  testthat::expect_s3_class(events, "ledgr_memory_events")
  testthat::expect_equal(nrow(events), n_events)
  testthat::expect_identical(events$event_id[[1]], "run-memory-buffered-grow_00000001")
  testthat::expect_identical(events$event_id[[n_events]], "run-memory-buffered-grow_00001025")
  testthat::expect_s3_class(events$ts_utc, "POSIXct")
  testthat::expect_identical(attr(events$ts_utc, "tzone"), "UTC")
  testthat::expect_true(all(grepl("^\\{", events$meta_json)))
  testthat::expect_identical(attr(events, "ledgr_event_cash_delta")[[n_events]], -100 * n_events)
  testthat::expect_identical(attr(events, "ledgr_event_position_delta")[[n_events]], as.numeric(n_events))
})

testthat::test_that("collapse event writes survive allocation and forced garbage collection", {
  columns <- new.env(parent = emptyenv())
  n <- 2048L
  columns$label <- character(n)
  columns$meta <- vector("list", n)

  # Promote the live target before the first write so the test exercises the
  # old-generation target / young-value barrier that collapse 2.1.8 repairs.
  for (generation in seq_len(3L)) {
    invisible(gc(full = TRUE))
  }

  testthat::expect_warning({
    for (i in seq_len(n)) {
      ledgr:::ledgr_event_buffer_setv(columns, "label", i, sprintf("event-%04d", i))
      ledgr:::ledgr_event_buffer_setv(columns, "meta", i, list(list(i = i, text = sprintf("meta-%04d", i))))
      if (i %% 17L == 0L) {
        junk <- replicate(20L, raw(4096L), simplify = FALSE)
        invisible(junk)
        invisible(gc(full = TRUE))
      }
    }
  }, NA)

  testthat::expect_identical(columns$label, sprintf("event-%04d", seq_len(n)))
  testthat::expect_identical(vapply(columns$meta, `[[`, integer(1), "i"), seq_len(n))
  testthat::expect_identical(
    vapply(columns$meta, `[[`, character(1), "text"),
    sprintf("meta-%04d", seq_len(n))
  )
})

testthat::test_that("both event handlers preserve rows across two injected growth boundaries", {
  n_events <- 10L
  expected_writes <- lapply(seq_len(n_events), function(i) {
    fake_write_result("linear-memory", i)
  })
  expected <- do.call(rbind, lapply(expected_writes, `[[`, "row"))
  memory <- ledgr:::ledgr_memory_output_handler(
    "linear-memory",
    .event_initial_capacity = 2L
  )
  memory$init_buffers(n_events)
  for (i in seq_len(n_events)) {
    testthat::expect_true(memory$buffer_event(fake_write_result("linear-memory", i)))
  }
  memory_rows <- memory$events()
  expected$meta_json <- as.character(expected$meta_json)
  for (name in names(expected)) {
    testthat::expect_identical(memory_rows[[name]], expected[[name]])
  }
  testthat::expect_identical(
    attr(memory_rows, "ledgr_event_cash_delta"),
    vapply(expected_writes, `[[`, numeric(1), "cash_delta")
  )
  testthat::expect_identical(
    attr(memory_rows, "ledgr_event_position_delta"),
    vapply(expected_writes, `[[`, numeric(1), "position_delta")
  )
  testthat::expect_identical(
    attr(memory_rows, "ledgr_event_meta"),
    lapply(expected_writes, `[[`, "meta")
  )
  testthat::expect_identical(
    attr(memory_rows, "ledgr_event_realized"),
    rep(NA_real_, n_events)
  )
  testthat::expect_identical(
    attr(memory_rows, "ledgr_event_cost_basis"),
    rep(NA_real_, n_events)
  )

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)
  insert_test_run(con, "linear-durable")
  durable <- ledgr:::ledgr_persistent_output_handler(
    con = con,
    run_id = "linear-durable",
    run_wall_start = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    execution_mode = "audit_log",
    persist_features = FALSE,
    .event_initial_capacity = 2L
  )
  durable$init_buffers(n_events)
  for (i in seq_len(n_events)) {
    testthat::expect_true(durable$buffer_event(fake_write_result("linear-durable", i)))
  }
  durable$flush_pending()
  durable_rows <- DBI::dbGetQuery(
    con,
    "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq",
    params = list("linear-durable")
  )
  durable_expected <- do.call(rbind, lapply(seq_len(n_events), function(i) {
    fake_write_result("linear-durable", i)$row
  }))
  durable_expected$meta_json <- as.character(durable_expected$meta_json)
  for (name in names(durable_expected)) {
    testthat::expect_identical(durable_rows[[name]], durable_expected[[name]])
  }
})

testthat::test_that("failed event-buffer writes do not expose a partial active row", {
  original <- ledgr:::ledgr_event_buffer_setv
  calls <- 0L
  fail_once <- function(...) {
    calls <<- calls + 1L
    if (calls == 4L) {
      stop("injected event-buffer write failure", call. = FALSE)
    }
    original(...)
  }
  testthat::local_mocked_bindings(
    ledgr_event_buffer_setv = fail_once,
    .package = "ledgr"
  )

  memory <- ledgr:::ledgr_memory_output_handler("linear-failure-memory", .event_initial_capacity = 2L)
  memory$init_buffers(2L)
  write <- fake_write_result("linear-failure-memory", 1L)
  testthat::expect_error(memory$buffer_event(write), "injected event-buffer write failure", fixed = TRUE)
  testthat::expect_identical(nrow(memory$events()), 0L)
  testthat::expect_true(memory$buffer_event(write))
  testthat::expect_identical(memory$events()$event_id, write$row$event_id)

  calls <- 0L
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)
  insert_test_run(con, "linear-failure-durable")
  durable <- ledgr:::ledgr_persistent_output_handler(
    con = con,
    run_id = "linear-failure-durable",
    run_wall_start = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    execution_mode = "audit_log",
    persist_features = FALSE,
    .event_initial_capacity = 2L
  )
  durable$init_buffers(2L)
  write <- fake_write_result("linear-failure-durable", 1L)
  testthat::expect_error(durable$buffer_event(write), "injected event-buffer write failure", fixed = TRUE)
  testthat::expect_identical(durable$pending_event_count(), 0L)
  testthat::expect_true(durable$buffer_event(write))
  durable$flush_pending()
  rows <- DBI::dbGetQuery(con, "SELECT event_id FROM ledger_events WHERE run_id = ?", params = list("linear-failure-durable"))
  testthat::expect_identical(rows$event_id, write$row$event_id)
})

testthat::test_that("event-buffer source has one collapse 2.1.8 route and no fallback", {
  root <- testthat::test_path("..", "..")
  description <- read.dcf(file.path(root, "DESCRIPTION"))
  testthat::expect_match(description[[1L, "Imports"]], "collapse \\(>= 2[.]1[.]8\\)")

  helper_body <- paste(deparse(body(ledgr:::ledgr_event_buffer_setv)), collapse = "\n")
  memory_body <- paste(deparse(body(ledgr:::ledgr_memory_output_handler)), collapse = "\n")
  durable_body <- paste(deparse(body(ledgr:::ledgr_persistent_output_handler)), collapse = "\n")
  testthat::expect_match(helper_body, "collapse::setv", fixed = TRUE)
  testthat::expect_match(helper_body, "xlist = TRUE", fixed = TRUE)
  testthat::expect_false(grepl("getOption|Sys.getenv|packageVersion", helper_body))
  testthat::expect_false(grepl("col\\[\\[i\\]\\] <-|col\\[i\\] <-", memory_body))
  testthat::expect_false(grepl("col\\[\\[i\\]\\] <-|col\\[i\\] <-", durable_body))
  testthat::expect_false(grepl("state\\$event_cols\\[\\[name\\]\\] <- col", memory_body))
  testthat::expect_false(grepl("state\\$pending_cols\\[\\[name\\]\\] <- col", durable_body))
  testthat::expect_false(grepl("state\\$event_cols\\$[A-Za-z_]+\\[idx\\] <-", memory_body))
  testthat::expect_false(grepl("rm\\s*\\(", helper_body))
  testthat::expect_false(grepl("rm\\s*\\(", memory_body))
  testthat::expect_false(grepl("rm\\s*\\(", durable_body))
  testthat::expect_false(any(grepl("arm|route|fallback", names(formals(ledgr:::ledgr_memory_output_handler)))))
  testthat::expect_false(any(grepl("arm|route|fallback", names(formals(ledgr:::ledgr_persistent_output_handler)))))
  testthat::expect_error(
    ledgr:::ledgr_event_buffer_setv(list(label = character(1L)), "label", 1L, "lost"),
    class = "ledgr_invalid_state"
  )

  fake_lib <- tempfile("ledgr-under-floor-")
  dir.create(file.path(fake_lib, "collapse", "Meta"), recursive = TRUE)
  writeLines(
    c("Package: collapse", "Version: 2.1.7"),
    file.path(fake_lib, "collapse", "DESCRIPTION")
  )
  saveRDS(
    list(DESCRIPTION = c(Package = "collapse", Version = "2.1.7")),
    file.path(fake_lib, "collapse", "Meta", "package.rds")
  )
  imports <- trimws(unlist(strsplit(description[[1L, "Imports"]], ",", fixed = TRUE)))
  collapse_import <- imports[grepl("^collapse[[:space:]]*\\(", imports)]
  testthat::expect_length(collapse_import, 1L)
  collapse_floor <- sub(
    "^collapse[[:space:]]*\\(>=[[:space:]]*([^)]*)\\)$",
    "\\1",
    collapse_import
  )
  testthat::expect_identical(collapse_floor, "2.1.8")
  resolved_under_floor <- utils::packageVersion("collapse", lib.loc = fake_lib)
  testthat::expect_lt(resolved_under_floor, package_version(collapse_floor))
})

testthat::test_that("SELL fill writes correct deltas", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-2"
  insert_test_run(con, run_id)

  fill <- ledgr_test_next_open_fill(
    desired_qty_delta = -3,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 100),
    spread_bps = 10,
    commission_fixed = 2
  )

  ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 1L)

  row <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ?", params = list(run_id))
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_identical(row$side[[1]], "SELL")
  testthat::expect_equal(row$qty[[1]], 3)
  testthat::expect_equal(row$fee[[1]], 2)

  meta <- parse_meta(row$meta_json[[1]])
  testthat::expect_equal(meta$position_delta, -3)
  testthat::expect_equal(meta$cash_delta, +(3 * row$price[[1]] - 2))
})

testthat::test_that("event_seq increments across multiple writes", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-3"
  insert_test_run(con, run_id)

  fill1 <- ledgr_test_next_open_fill(
    desired_qty_delta = 1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 10),
    spread_bps = 0,
    commission_fixed = 0
  )
  fill2 <- ledgr_test_next_open_fill(
    desired_qty_delta = -1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-03T00:00:00Z", open = 12),
    spread_bps = 0,
    commission_fixed = 0
  )

  r1 <- ledgr:::ledgr_write_fill_events(con, run_id, fill1, event_seq_start = 1L)
  r2 <- ledgr:::ledgr_write_fill_events(con, run_id, fill2, event_seq_start = r1$next_event_seq)

  testthat::expect_identical(r2$event_seq, 2L)

  seqs <- DBI::dbGetQuery(con, "SELECT event_seq FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))$event_seq
  testthat::expect_identical(as.integer(seqs), c(1L, 2L))
})

testthat::test_that("fill_none is a no-op (no ledger rows written)", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-4"
  insert_test_run(con, run_id)

  before <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]

  none <- structure(list(status = "NO_FILL"), class = "ledgr_fill_none")
  res <- ledgr:::ledgr_write_fill_events(con, run_id, none, event_seq_start = 1L)
  testthat::expect_identical(res$status, "NO_OP")

  after <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_identical(before, after)
})

testthat::test_that("append-only: duplicate (run_id, event_seq) fails and does not add a row", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-5"
  insert_test_run(con, run_id)

  fill <- ledgr_test_next_open_fill(
    desired_qty_delta = 1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 10),
    spread_bps = 0,
    commission_fixed = 0
  )

  ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 1L)
  before <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]

  testthat::expect_error(
    ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 1L)
  )

  after <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_identical(before, after)
})

testthat::test_that("transactionality: failed insert leaves no partial row", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-ledger-6"
  insert_test_run(con, run_id)

  fill <- ledgr_test_next_open_fill(
    desired_qty_delta = 1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 10),
    spread_bps = 0,
    commission_fixed = 0
  )

  testthat::expect_error(
    ledgr:::ledgr_write_fill_events(con, run_id, fill, event_seq_start = 0L),
    "event_seq_start",
    fixed = TRUE
  )
  n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_identical(n, 0)
})

