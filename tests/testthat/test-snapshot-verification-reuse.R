verification_test_bars <- function(n = 12L) {
  data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (seq_len(n) - 1L),
    open = 100 + seq_len(n),
    high = 101 + seq_len(n),
    low = 99 + seq_len(n),
    close = 100 + seq_len(n),
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

verification_count_hashes <- function(code) {
  count <- 0L
  original <- ledgr:::ledgr_snapshot_hash
  value <- testthat::with_mocked_bindings(
    ledgr_snapshot_hash = function(...) {
      count <<- count + 1L
      original(...)
    },
    force(code),
    .package = "ledgr"
  )
  list(value = value, count = count)
}

testthat::test_that("[LTB-0252] complete verification is PID-bound and truthful", {
  path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(verification_test_bars(), db_path = path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  id <- snapshot$snapshot_id
  root <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]

  testthat::expect_true(ledgr_snapshot_info(snapshot)$verified_in_process[[1L]])
  ledgr:::ledgr_snapshot_verified_reset()
  testthat::expect_false(ledgr_snapshot_info(snapshot)$verified_in_process[[1L]])
  cold <- ledgr_snapshot_open(path, id, verify = FALSE)
  on.exit(ledgr_snapshot_close(cold), add = TRUE)
  testthat::expect_false(ledgr_snapshot_info(cold)$verified_in_process[[1L]])
  testthat::expect_match(
    paste(capture.output(print(cold)), collapse = "\n"),
    "not verified in this process",
    fixed = TRUE
  )

  counted <- verification_count_hashes({
    ledgr:::ledgr_snapshot_ensure_handle(snapshot)
    reopened <- ledgr_snapshot_open(path, id, verify = FALSE)
    on.exit(ledgr_snapshot_close(reopened), add = TRUE)
    ledgr:::ledgr_snapshot_ensure_handle(reopened)
    testthat::expect_true(
      ledgr_snapshot_info(reopened)$verified_in_process[[1L]]
    )
    ledgr_snapshot_validate(reopened)
    eager <- ledgr_snapshot_open(path, id, verify = TRUE)
    on.exit(ledgr_snapshot_close(eager), add = TRUE)
  })
  testthat::expect_identical(counted$count, 3L)
  testthat::expect_match(
    paste(capture.output(print(snapshot)), collapse = "\n"),
    "verified in this process",
    fixed = TRUE
  )

  ledgr_snapshot_close(snapshot)
  second_path <- tempfile(fileext = ".duckdb")
  testthat::expect_true(file.copy(path, second_path))
  first <- ledgr_snapshot_open(path, id, verify = FALSE)
  second <- ledgr_snapshot_open(second_path, id, verify = FALSE)
  on.exit(ledgr_snapshot_close(first), add = TRUE)
  on.exit(ledgr_snapshot_close(second), add = TRUE)
  ledgr:::ledgr_snapshot_verified_reset()
  ledgr:::ledgr_snapshot_ensure_handle(first)
  testthat::expect_true(ledgr_snapshot_info(first)$verified_in_process[[1L]])
  testthat::expect_false(ledgr_snapshot_info(second)$verified_in_process[[1L]])
  ledgr:::ledgr_snapshot_ensure_handle(second)
  testthat::expect_true(ledgr_snapshot_info(second)$verified_in_process[[1L]])

  run_path <- tempfile(fileext = ".duckdb")
  run_con <- ledgr_db_init(run_path)
  on.exit({
    if (!is.null(run_con) && DBI::dbIsValid(run_con)) {
      DBI::dbDisconnect(run_con, shutdown = TRUE)
    }
  }, add = TRUE)
  ledgr:::ledgr_prepare_snapshot_source_tables(run_con, path, run_path)
  ledgr:::ledgr_snapshot_verified_reset()
  ledgr:::ledgr_snapshot_ensure_verified(
    run_con,
    id,
    snapshot_db_path = path
  )
  testthat::expect_true(ledgr:::ledgr_snapshot_verified_contains(
    ledgr:::ledgr_store_key(path), id, root, 3L
  ))
  testthat::expect_false(ledgr:::ledgr_snapshot_verified_contains(
    ledgr:::ledgr_store_key(second_path), id, root, 3L
  ))
  testthat::expect_false(identical(
    ledgr:::ledgr_snapshot_verified_key(
      ledgr:::ledgr_store_key(path), id, root, 3L
    ),
    ledgr:::ledgr_snapshot_verified_key(
      ledgr:::ledgr_store_key(path), paste0(id, "-other"), root, 3L
    )
  ))
  DBI::dbDisconnect(run_con, shutdown = TRUE)
  run_con <- NULL

  ledgr:::ledgr_snapshot_verified_reset()
  unresolved <- verification_count_hashes({
    testthat::with_mocked_bindings(
      ledgr_snapshot_connection_store_key = function(con) NULL,
      {
        ledgr:::ledgr_snapshot_ensure_verified(
          ledgr:::get_connection(first),
          id,
          connection_is_snapshot_store = TRUE
        )
        ledgr:::ledgr_snapshot_ensure_verified(
          ledgr:::get_connection(first),
          id,
          connection_is_snapshot_store = TRUE
        )
      },
      .package = "ledgr"
    )
  })
  testthat::expect_identical(unresolved$count, 2L)
  testthat::expect_false(ledgr_snapshot_info(first)$verified_in_process[[1L]])
  ledgr:::ledgr_snapshot_ensure_handle(first)

  state <- ledgr:::.ledgr_snapshot_verified
  state$pid <- -1L
  testthat::expect_false(ledgr_snapshot_info(snapshot)$verified_in_process[[1L]])

  memory_con <- ledgr_db_init(":memory:")
  on.exit(DBI::dbDisconnect(memory_con, shutdown = TRUE), add = TRUE)
  memory_id <- ledgr_snapshot_create(memory_con, "memory-verification")
  DBI::dbAppendTable(
    memory_con,
    "snapshot_instruments",
    data.frame(
      snapshot_id = memory_id,
      instrument_id = "AAA",
      symbol = "AAA",
      currency = "USD",
      asset_class = "equity",
      multiplier = 1,
      tick_size = 0.01,
      meta_json = "{}",
      stringsAsFactors = FALSE
    )
  )
  DBI::dbAppendTable(
    memory_con,
    "snapshot_bars",
    cbind(
      snapshot_id = memory_id,
      verification_test_bars(3L),
      stringsAsFactors = FALSE
    )
  )
  ledgr_snapshot_seal(memory_con, memory_id)
  testthat::expect_false(
    ledgr_snapshot_info(memory_con, memory_id)$verified_in_process[[1L]]
  )
  counted_memory <- verification_count_hashes({
    ledgr:::ledgr_snapshot_ensure_verified(
      memory_con,
      memory_id,
      connection_is_snapshot_store = TRUE
    )
    ledgr:::ledgr_snapshot_ensure_verified(
      memory_con,
      memory_id,
      connection_is_snapshot_store = TRUE
    )
  })
  testthat::expect_identical(counted_memory$count, 2L)

  empty_path <- tempfile(fileext = ".duckdb")
  empty_con <- ledgr_db_init(empty_path)
  on.exit(DBI::dbDisconnect(empty_con, shutdown = TRUE), add = TRUE)
  empty_id <- ledgr_snapshot_create(empty_con, "aborted-seal")
  testthat::expect_error(
    ledgr_snapshot_seal(empty_con, empty_id),
    class = "LEDGR_SNAPSHOT_EMPTY"
  )
  testthat::expect_false(
    ledgr_snapshot_info(empty_con, empty_id)$verified_in_process[[1L]]
  )

  failed_path <- tempfile(fileext = ".duckdb")
  failed_con <- ledgr_db_init(failed_path)
  on.exit(DBI::dbDisconnect(failed_con, shutdown = TRUE), add = TRUE)
  failed_id <- ledgr_snapshot_create(failed_con, "failed-commit")
  DBI::dbAppendTable(
    failed_con,
    "snapshot_instruments",
    data.frame(
      snapshot_id = failed_id,
      instrument_id = "AAA",
      symbol = "AAA",
      currency = "USD",
      asset_class = "equity",
      multiplier = 1,
      tick_size = 0.01,
      meta_json = "{}",
      stringsAsFactors = FALSE
    )
  )
  DBI::dbAppendTable(
    failed_con,
    "snapshot_bars",
    cbind(
      snapshot_id = failed_id,
      verification_test_bars(3L),
      stringsAsFactors = FALSE
    )
  )
  failed_hash <- ledgr:::ledgr_snapshot_hash(failed_con, failed_id)
  original_execute <- DBI::dbExecute
  testthat::expect_error(
    testthat::with_mocked_bindings(
      dbExecute = function(conn, statement, ...) {
        if (identical(statement, "COMMIT")) stop("injected commit failure")
        original_execute(conn, statement, ...)
      },
      ledgr_snapshot_seal(failed_con, failed_id),
      .package = "DBI"
    ),
    "injected commit failure",
    fixed = TRUE
  )
  testthat::expect_false(ledgr:::ledgr_snapshot_verified_contains(
    ledgr:::ledgr_store_key(failed_path), failed_id, failed_hash, 3L
  ))
})

testthat::test_that("[LTB-0253] failure removes every stale proof for a snapshot", {
  path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(verification_test_bars(), db_path = path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  id <- snapshot$snapshot_id
  root <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  testthat::expect_true(ledgr_snapshot_info(snapshot)$verified_in_process[[1L]])

  DBI::dbExecute(
    con,
    "UPDATE snapshots SET snapshot_hash = ? WHERE snapshot_id = ?",
    params = list(strrep("0", 64L), id)
  )
  DBI::dbExecute(
    con,
    "UPDATE snapshot_bars SET close = close + 1 WHERE snapshot_id = ?",
    params = list(id)
  )
  testthat::expect_error(
    ledgr:::ledgr_snapshot_ensure_handle(snapshot),
    class = "LEDGR_SNAPSHOT_CORRUPTED"
  )
  DBI::dbExecute(
    con,
    "UPDATE snapshots SET snapshot_hash = ? WHERE snapshot_id = ?",
    params = list(root, id)
  )
  testthat::expect_error(
    ledgr:::ledgr_snapshot_ensure_handle(snapshot),
    class = "LEDGR_SNAPSHOT_CORRUPTED"
  )
  DBI::dbExecute(
    con,
    "UPDATE snapshot_bars SET close = close - 1 WHERE snapshot_id = ?",
    params = list(id)
  )
  ledgr_snapshot_validate(snapshot)

  DBI::dbExecute(
    con,
    "UPDATE snapshot_bars SET close = close + 1 WHERE snapshot_id = ?",
    params = list(id)
  )
  testthat::expect_error(
    ledgr_snapshot_validate(snapshot),
    class = "ledgr_invalid_snapshot"
  )
  testthat::expect_false(ledgr_snapshot_info(snapshot)$verified_in_process[[1L]])
  testthat::expect_match(
    paste(capture.output(print(snapshot)), collapse = "\n"),
    "not verified in this process",
    fixed = TRUE
  )
  testthat::expect_error(
    ledgr:::ledgr_snapshot_ensure_handle(snapshot),
    class = "LEDGR_SNAPSHOT_CORRUPTED"
  )

  DBI::dbExecute(
    con,
    "UPDATE snapshot_bars SET close = close - 1 WHERE snapshot_id = ?",
    params = list(id)
  )
  ledgr_snapshot_validate(snapshot)
  testthat::expect_true(ledgr_snapshot_info(snapshot)$verified_in_process[[1L]])
  DBI::dbExecute(
    con,
    "UPDATE snapshots SET status = 'FAILED' WHERE snapshot_id = ?",
    params = list(id)
  )
  testthat::expect_error(
    ledgr:::ledgr_snapshot_ensure_handle(snapshot),
    class = "LEDGR_SNAPSHOT_NOT_SEALED"
  )
  testthat::expect_false(ledgr_snapshot_info(snapshot)$verified_in_process[[1L]])
  testthat::expect_match(
    paste(capture.output(print(snapshot)), collapse = "\n"),
    "not verified in this process",
    fixed = TRUE
  )
})

testthat::test_that("[LTB-0255] every snapshot-table source file is classified", {
  root <- testthat::test_path("..", "..")
  r_files <- list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)
  pattern <- paste0(
    "snapshot_(instruments|bars|fact_families|membership|membership_sets|",
    "trading_status|lifetime|sessions|equity_corporate_actions|",
    "observation_quarantine)|FROM snapshots|JOIN snapshots"
  )
  source_files <- basename(r_files[vapply(
    r_files,
    function(path) grepl(
      pattern,
      paste(readLines(path, warn = FALSE), collapse = "\n"),
      perl = TRUE
    ),
    logical(1)
  )])
  census <- utils::read.csv(
    file.path(
      root,
      "inst", "design", "ledgr_v0_2_2_spec_packet",
      "snapshot_verification_consumer_census.csv"
    ),
    stringsAsFactors = FALSE,
    na.strings = character()
  )
  testthat::expect_setequal(census$source_file, source_files)
  testthat::expect_false(anyDuplicated(census$source_file) > 0L)
  testthat::expect_true(all(nzchar(census$role)))
  testthat::expect_true(all(nzchar(census$enclosing_entries)))
  testthat::expect_true(all(nzchar(census$guard)))
  required <- paste(census$enclosing_entries, collapse = "|")
  testthat::expect_match(required, "summary.ledgr_snapshot", fixed = TRUE)
  testthat::expect_match(required, "ledgr_facts_history", fixed = TRUE)
  testthat::expect_match(required, "ledgr_snapshot_quarantine", fixed = TRUE)
  testthat::expect_match(required, "ledgr_run_open", fixed = TRUE)
  testthat::expect_match(required, "ledgr_sweep_open", fixed = TRUE)
  testthat::expect_match(required, "ledgr_pulse_snapshot", fixed = TRUE)
  testthat::expect_match(required, "ledgr_indicator_dev", fixed = TRUE)
  testthat::expect_match(required, "ledgr_feature_contract_check", fixed = TRUE)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0256] serialized research objects start cold in a fresh worker", {
  testthat::skip_on_covr()
  testthat::skip_if_not_installed("pkgload")
  snapshot <- ledgr_snapshot_from_df(
    verification_test_bars(3L),
    db_path = tempfile(fileext = ".duckdb")
  )
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  result <- ledgr_run(experiment, run_id = "serialized-verification")
  close(result)
  ledgr_snapshot_close(snapshot)
  object_path <- tempfile(fileext = ".rds")
  saveRDS(
    list(snapshot = snapshot, experiment = experiment, result = result),
    object_path
  )
  script <- tempfile(fileext = ".R")
  root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  writeLines(c(
    ".libPaths(c(Sys.getenv('R_LIBS_USER'), .libPaths()))",
    "pkgload::load_all(commandArgs(TRUE)[[1L]], quiet = TRUE)",
    "objects <- readRDS(commandArgs(TRUE)[[2L]])",
    "cat(ledgr_snapshot_info(objects$snapshot)$verified_in_process[[1L]], '\\n')",
    "cat(ledgr_snapshot_info(objects$experiment$snapshot)$verified_in_process[[1L]], '\\n')",
    "ledgr:::ledgr_backtest_ensure_snapshot(objects$result)",
    "cat(ledgr_snapshot_info(objects$snapshot)$verified_in_process[[1L]], '\\n')",
    "close(objects$result)",
    "ledgr_snapshot_close(objects$snapshot)"
  ), script, useBytes = TRUE)
  output <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(script), shQuote(root), shQuote(object_path)),
    stdout = TRUE,
    stderr = TRUE
  )
  testthat::expect_null(attr(output, "status"))
  truth <- trimws(output[output %in% c("FALSE ", "TRUE ", "FALSE", "TRUE")])
  testthat::expect_identical(truth, c("FALSE", "FALSE", "TRUE"))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0254] outer execution and reader calls verify once", {
  facts <- ledgr_facts(ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = "AAA",
      effective_from = as.POSIXct("2020-01-01", tz = "UTC"),
      knowledge_time = as.POSIXct("2019-12-31", tz = "UTC"),
      member = TRUE,
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "research"
  ))
  snapshot <- ledgr_snapshot_from_df(
    verification_test_bars(),
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    target <- ctx$flat()
    target["AAA"] <- if (is.null(params$qty)) 0 else params$qty
    target
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    universe = "AAA",
    cost_model = ledgr_cost_zero()
  )

  ledgr:::ledgr_snapshot_verified_reset()
  run_count <- verification_count_hashes({
    bt <- ledgr_run(exp, run_id = "verification-run")
    on.exit(close(bt), add = TRUE)
  })
  testthat::expect_identical(run_count$count, 1L)

  ledgr:::ledgr_snapshot_verified_reset()
  sweep_count <- verification_count_hashes({
    sweep <- ledgr_sweep(
      exp,
      ledgr_param_grid(
        a = list(qty = 0),
        b = list(qty = 1),
        c = list(qty = 2)
      )
    )
    testthat::expect_equal(nrow(sweep), 3L)
  })
  testthat::expect_identical(sweep_count$count, 1L)

  fact_snapshot <- ledgr_snapshot_from_df(
    verification_test_bars(),
    facts = facts,
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(fact_snapshot), add = TRUE)
  ledgr:::ledgr_snapshot_verified_reset()
  facts_count <- verification_count_hashes({
    history <- ledgr_facts_history(
      fact_snapshot,
      "membership",
      "research"
    )
    testthat::expect_identical(history$rows$instrument_id, "AAA")
  })
  testthat::expect_identical(facts_count$count, 1L)

  incomplete_snapshot <- availability_runtime_fixture(
    days = 4L,
    bar_days = c(1L, 2L, 4L)
  )
  on.exit(ledgr_snapshot_close(incomplete_snapshot), add = TRUE)
  incomplete_exp <- ledgr_experiment(
    incomplete_snapshot,
    function(ctx, params) {
      target <- ctx$hold()
      target[["AAA"]] <- 1
      target
    },
    valuation_policy = ledgr_valuation_stale(0L, exhausted = "refuse"),
    cost_model = ledgr_cost_zero()
  )
  incomplete <- ledgr_run(incomplete_exp, run_id = "verification-incomplete")
  close(incomplete)
  testthat::expect_identical(
    ledgr_run_info(incomplete_snapshot, "verification-incomplete")$status,
    "INCOMPLETE"
  )
  ledgr:::ledgr_snapshot_verified_reset()
  incomplete_count <- verification_count_hashes({
    reopened <- ledgr_run_open(
      incomplete_snapshot,
      "verification-incomplete"
    )
    close(reopened)
  })
  testthat::expect_identical(incomplete_count$count, 1L)

  ledgr:::ledgr_snapshot_verified_reset()
  reconstruction_count <- verification_count_hashes({
    con <- ledgr_db_init(snapshot$db_path)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    ledgr:::ledgr_rebuild_derived_state(
      con,
      "verification-run",
      initial_cash = 100000
    )
  })
  testthat::expect_identical(reconstruction_count$count, 1L)

  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(
      "2020-01-01", "2020-01-04",
      "2020-01-05", "2020-01-07",
      fold_seq = 1L
    )),
    constructor = list(type_id = "explicit")
  )
  ledgr:::ledgr_snapshot_verified_reset()
  walk_count <- verification_count_hashes({
    wf <- suppressWarnings(ledgr_walk_forward(
      exp,
      grid = ledgr_param_grid(a = list(qty = 0), b = list(qty = 1)),
      folds = folds,
      selection_rule = ledgr_rule_argmax("sharpe_ratio"),
      opening_state_policy = "flat_test_state",
      seed = 1L
    ))
    on.exit(lapply(wf$test_runs, close), add = TRUE)
  })
  testthat::expect_identical(walk_count$count, 1L)

  split_snapshot_path <- tempfile(fileext = ".duckdb")
  split_run_path <- tempfile(fileext = ".duckdb")
  split_snapshot <- ledgr_snapshot_from_df(
    verification_test_bars(3L),
    db_path = split_snapshot_path
  )
  on.exit(ledgr_snapshot_close(split_snapshot), add = TRUE)
  split_root <- ledgr_snapshot_info(split_snapshot)$snapshot_hash[[1L]]
  ledgr:::ledgr_snapshot_verified_reset()
  split_result <- ledgr_backtest(
    snapshot = split_snapshot,
    strategy = function(ctx, params) ctx$flat(),
    universe = "AAA",
    start = "2020-01-01",
    end = "2020-01-03",
    initial_cash = 1000,
    db_path = split_run_path,
    cost_model = ledgr_cost_zero()
  )
  on.exit(close(split_result), add = TRUE)
  snapshot_key <- ledgr:::ledgr_store_key(split_snapshot_path)
  run_key <- ledgr:::ledgr_store_key(split_run_path)
  testthat::expect_true(ledgr:::ledgr_snapshot_verified_contains(
    snapshot_key, split_snapshot$snapshot_id, split_root, 3L
  ))
  testthat::expect_false(ledgr:::ledgr_snapshot_verified_contains(
    run_key, split_snapshot$snapshot_id, split_root, 3L
  ))

  ledgr:::ledgr_snapshot_verified_reset()
  split_con <- ledgr_db_init(split_run_path)
  on.exit(DBI::dbDisconnect(split_con, shutdown = TRUE), add = TRUE)
  ledgr_state_reconstruct(split_result$run_id, split_con)
  testthat::expect_true(ledgr:::ledgr_snapshot_verified_contains(
    snapshot_key, split_snapshot$snapshot_id, split_root, 3L
  ))
  testthat::expect_false(ledgr:::ledgr_snapshot_verified_contains(
    run_key, split_snapshot$snapshot_id, split_root, 3L
  ))

  testthat::expect_output(print(split_result), "ledgr Backtest", fixed = TRUE)
  testthat::expect_no_error(summary(split_result))

  ledgr:::ledgr_snapshot_verified_reset()
  ledgr:::ledgr_backtest_ensure_snapshot(split_result)
  testthat::expect_true(ledgr:::ledgr_snapshot_verified_contains(
    snapshot_key, split_snapshot$snapshot_id, split_root, 3L
  ))
  testthat::expect_false(ledgr:::ledgr_snapshot_verified_contains(
    run_key, split_snapshot$snapshot_id, split_root, 3L
  ))
})
