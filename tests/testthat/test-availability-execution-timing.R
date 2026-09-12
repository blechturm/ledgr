availability_timing_experiment <- function(snapshot, calls = NULL) {
  strategy <- function(ctx, params) {
    if (!is.null(calls)) calls$n <- calls$n + 1L
    targets <- ctx$hold()
    targets[["AAA"]] <- 1
    targets
  }
  ledgr_experiment(
    snapshot,
    strategy,
    valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 10000)
  )
}

availability_timing_store_contents <- function(path, run_id) {
  opened <- ledgr_test_open_duckdb(path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  tables <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT DISTINCT table_name FROM information_schema.columns",
      "WHERE table_schema = 'main' AND column_name = 'run_id'",
      "ORDER BY table_name"
    )
  )$table_name
  stats::setNames(lapply(tables, function(table) {
    DBI::dbGetQuery(
      opened$con,
      sprintf("SELECT * FROM %s WHERE run_id = ? ORDER BY ALL", table),
      params = list(run_id)
    )
  }), tables)
}

availability_make_legacy_timing_run <- function(path, run_id) {
  opened <- ledgr_test_open_duckdb(path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  row <- DBI::dbGetQuery(
    opened$con,
    "SELECT config_json FROM runs WHERE run_id = ?",
    params = list(run_id)
  )
  config <- ledgr:::ledgr_json_read_config(row$config_json[[1L]])
  config$availability$execution_timing_version <- NULL
  config_json <- canonical_json(config)
  config_hash <- ledgr:::config_hash(config)
  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET config_json = ?, config_hash = ? WHERE run_id = ?",
    params = list(config_json, config_hash, run_id)
  )

  fills <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT event_seq, ts_utc FROM ledger_events",
      "WHERE run_id = ? AND event_type IN ('FILL', 'FILL_PARTIAL')",
      "ORDER BY event_seq"
    ),
    params = list(run_id)
  )
  sessions <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT session_open, session_close FROM snapshot_sessions",
      "WHERE snapshot_id = ? AND status = 'open' ORDER BY session_close"
    ),
    params = list(config$data$snapshot_id)
  )
  for (i in seq_len(nrow(fills))) {
    session_idx <- match(
      as.numeric(as.POSIXct(fills$ts_utc[[i]], tz = "UTC")),
      as.numeric(as.POSIXct(sessions$session_open, tz = "UTC"))
    )
    DBI::dbExecute(
      opened$con,
      "UPDATE ledger_events SET ts_utc = ? WHERE run_id = ? AND event_seq = ?",
      params = list(sessions$session_close[[session_idx]], run_id, fills$event_seq[[i]])
    )
  }
  last_fill <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT MAX(ts_utc) AS ts_utc FROM ledger_events",
      "WHERE run_id = ? AND event_type IN ('FILL', 'FILL_PARTIAL')"
    ),
    params = list(run_id)
  )$ts_utc[[1L]]
  DBI::dbExecute(
    opened$con,
    paste(
      "UPDATE run_diagnostics SET execution_ts_utc = ?, event_seq = NULL",
      "WHERE run_id = ? AND stage = 'execution' AND outcome = 'filled'"
    ),
    params = list(last_fill, run_id)
  )
  DBI::dbExecute(
    opened$con,
    "UPDATE run_completion SET last_executed_ts_utc = ? WHERE run_id = ?",
    params = list(last_fill, run_id)
  )
  list(config_json = config_json, config_hash = config_hash)
}

testthat::test_that("fill results expose derived recording-pulse alignment", {
  snapshot <- availability_runtime_fixture(days = 4L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  exp <- availability_timing_experiment(snapshot, calls)
  bt <- ledgr_run(exp, run_id = "timing-alignment")

  fills <- ledgr_run_fills(bt)
  equity <- ledgr_results(bt, "equity")
  testthat::expect_identical(nrow(fills), 1L)
  testthat::expect_identical(
    fills$ts_utc,
    as.POSIXct("2020-01-02 09:30:00", tz = "UTC")
  )
  testthat::expect_identical(
    fills$recording_pulse_ts_utc,
    as.POSIXct("2020-01-02 16:00:00", tz = "UTC")
  )
  testthat::expect_true(fills$recording_pulse_ts_utc %in% equity$ts_utc)
  testthat::expect_false(fills$ts_utc %in% equity$ts_utc)

  same_pulse_fills <- fills[c(1L, 1L), , drop = FALSE]
  same_pulse_fills$event_seq <- 1:2
  same_pulse_fills$instrument_id <- c("AAA", "BBB")
  grouped <- stats::aggregate(
    qty ~ recording_pulse_ts_utc,
    data = as.data.frame(same_pulse_fills),
    FUN = sum
  )
  testthat::expect_identical(nrow(grouped), 1L)
  names(grouped)[names(grouped) == "qty"] <- "fill_qty"
  aligned <- equity
  aligned$fill_qty <- grouped$fill_qty[match(
    as.numeric(aligned$ts_utc),
    as.numeric(grouped$recording_pulse_ts_utc)
  )]
  testthat::expect_identical(nrow(aligned), nrow(equity))
  testthat::expect_identical(
    sum(aligned$fill_qty, na.rm = TRUE),
    sum(same_pulse_fills$qty)
  )

  calls_after_run <- calls$n
  close(bt)
  opened <- ledgr_test_open_duckdb(snapshot$db_path)
  events <- DBI::dbGetQuery(
    opened$con,
    "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq",
    params = list("timing-alignment")
  )
  stored_columns <- DBI::dbGetQuery(
    opened$con,
    "SELECT column_name FROM information_schema.columns WHERE table_schema = 'main'"
  )$column_name
  testthat::expect_false("recording_pulse_ts_utc" %in% stored_columns)
  sessions <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT session_open, session_close FROM snapshot_sessions",
      "WHERE snapshot_id = ? AND status = 'open' ORDER BY session_close"
    ),
    params = list(snapshot$snapshot_id)
  )
  ledgr_test_close_duckdb(opened$con, opened$drv)
  pulses <- as.POSIXct(sessions$session_close, tz = "UTC")
  reconstructed <- ledgr:::ledgr_sweep_summary_from_ordered_events(
    events = events,
    pulses_posix = pulses,
    close_mat = matrix(101:104, nrow = 1L, dimnames = list("AAA", NULL)),
    initial_cash = 10000,
    instrument_ids = "AAA",
    run_id = "timing-alignment",
    metric_kernel = ledgr:::ledgr_metric_kernel(
      context = ledgr_metric_context(),
      pulses = pulses
    ),
    execution_opportunities_posix = as.POSIXct(sessions$session_open[-1L], tz = "UTC")
  )
  testthat::expect_identical(reconstructed$fills, fills)
  testthat::expect_identical(
    ledgr:::ledgr_fills_from_events(
      events,
      pulses,
      as.POSIXct(sessions$session_open[-1L], tz = "UTC")
    ),
    fills
  )
  equity_columns <- c("ts_utc", "cash", "positions_value", "equity")
  testthat::expect_equal(
    reconstructed$equity[, equity_columns],
    as.data.frame(equity)[, equity_columns]
  )

  reopened_snapshot <- ledgr_snapshot_open(
    snapshot$db_path,
    snapshot$snapshot_id,
    verify = TRUE
  )
  on.exit(ledgr_snapshot_close(reopened_snapshot), add = TRUE)
  reopened <- ledgr_run_open(reopened_snapshot, "timing-alignment")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(ledgr_run_fills(reopened), fills)
  testthat::expect_identical(calls$n, calls_after_run)
  testthat::expect_output(
    summary(reopened),
    "Fill Timing:         availability_open_v2",
    fixed = TRUE
  )
})

testthat::test_that("recording-pulse derivation fails closed on missing or ambiguous evidence", {
  fill_time <- as.POSIXct("2020-01-02 09:30:00", tz = "UTC")
  close_time <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC")
  fills <- tibble::tibble(
    event_seq = 1L,
    ts_utc = fill_time,
    instrument_id = "AAA"
  )
  sessions <- data.frame(
    status = c("open", "open"),
    session_open = as.POSIXct(c("2020-01-01 09:30:00", "2020-01-02 09:30:00"), tz = "UTC"),
    session_close = as.POSIXct(c("2020-01-01 16:00:00", "2020-01-02 16:00:00"), tz = "UTC")
  )
  timing <- ledgr:::ledgr_execution_timing_provenance(list(
    availability = list(
      active = TRUE,
      provider_version = ledgr:::ledgr_availability_provider_version(),
      execution_timing_version = 2L
    )
  ))
  missing <- ledgr:::ledgr_fill_recording_pulses_from_evidence(
    fills,
    data.frame(),
    sessions,
    timing
  )
  testthat::expect_true(is.na(missing[[1L]]))

  diagnostic <- data.frame(
    event_seq = NA_integer_,
    instrument_id = "AAA",
    stage = "execution",
    outcome = "filled",
    decision_ts_utc = close_time,
    execution_ts_utc = fill_time
  )
  ambiguous <- ledgr:::ledgr_fill_recording_pulses_from_evidence(
    fills,
    rbind(diagnostic, diagnostic),
    sessions,
    timing
  )
  testthat::expect_true(is.na(ambiguous[[1L]]))

  reconstructed <- ledgr:::ledgr_fill_recording_pulses_from_opportunities(
    fills,
    sessions$session_close,
    sessions$session_open[-1L]
  )
  testthat::expect_identical(
    reconstructed,
    as.POSIXct("2020-01-02 16:00:00", tz = "UTC")
  )
})

testthat::test_that("timing version enters active identity and stays absent from dense config", {
  snapshot <- availability_runtime_fixture(days = 4L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- availability_timing_experiment(snapshot)
  bt <- ledgr_run(exp, run_id = "timing-identity")
  on.exit(close(bt), add = TRUE)
  config <- availability_run_config(bt)
  testthat::expect_identical(config$availability$execution_timing_version, 2L)
  testthat::expect_identical(
    ledgr_run_info(snapshot, bt$run_id)$execution_timing_convention,
    "availability_open_v2"
  )
  legacy_config <- config
  legacy_config$availability$execution_timing_version <- NULL
  testthat::expect_false(identical(
    ledgr:::config_hash(config),
    ledgr:::config_hash(legacy_config)
  ))
  testthat::expect_error(
    ledgr:::ledgr_execution_timing_require_current(legacy_config),
    class = "ledgr_execution_timing_version_mismatch"
  )

  meta <- ledgr:::ledgr_precompute_snapshot_meta(snapshot)
  base_config <- ledgr:::ledgr_walk_forward_base_config(exp, meta)
  legacy_base <- base_config
  legacy_base$availability$execution_timing_version <- NULL
  class(legacy_base) <- class(base_config)
  testthat::expect_identical(base_config$availability$execution_timing_version, 2L)
  testthat::expect_false(identical(
    ledgr:::ledgr_walk_forward_experiment_hash(base_config),
    ledgr:::ledgr_walk_forward_experiment_hash(legacy_base)
  ))

  captured <- new.env(parent = emptyenv())
  retained_trades_from_fills <- ledgr:::ledgr_sweep_retained_trades_from_fills
  sweep <- local({
    testthat::local_mocked_bindings(
      ledgr_sweep_retained_trades_from_fills = function(fills, ...) {
        captured$fills <- fills
        retained_trades_from_fills(fills, ...)
      },
      .package = "ledgr"
    )
    ledgr_sweep(
      exp,
      ledgr_param_grid(one = list(qty = 1)),
      seed = 71L,
      retain = ledgr_sweep_retention(trades = "closed")
    )
  })
  testthat::expect_identical(
    captured$fills$recording_pulse_ts_utc,
    ledgr_run_fills(bt)$recording_pulse_ts_utc
  )
  testthat::expect_identical(
    attr(sweep, "execution_assumptions")$execution_timing_version,
    2L
  )
  candidate_key <- ledgr_candidate_reproduction_key(ledgr_candidate(sweep, "one"))
  testthat::expect_identical(
    candidate_key$execution_assumptions$execution_timing_version,
    2L
  )
  saved_sweep_id <- ledgr_sweep_save(sweep, snapshot, sweep_id = "timing-sweep")
  reopened_sweep <- ledgr_sweep_open(snapshot, saved_sweep_id)
  testthat::expect_identical(
    attr(reopened_sweep, "execution_assumptions")$execution_timing_version,
    2L
  )

  same_version <- ledgr_run_compare(snapshot, run_ids = bt$run_id)
  testthat::expect_true(attr(same_version, "fill_timing_comparable", exact = TRUE))
  testthat::expect_identical(
    attr(same_version, "fill_timing_comparability_reason", exact = TRUE),
    "same_timing_convention"
  )

  dense_bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
    instrument_id = "AAA",
    open = 100:102,
    high = 101:103,
    low = 99:101,
    close = 100:102,
    volume = 1000
  )
  dense_snapshot <- ledgr_snapshot_from_df(dense_bars)
  on.exit(ledgr_snapshot_close(dense_snapshot), add = TRUE)
  dense_exp <- ledgr_experiment(
    dense_snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  dense_bt <- ledgr_run(dense_exp, run_id = "dense-timing-identity")
  on.exit(close(dense_bt), add = TRUE)
  testthat::expect_null(dense_bt$config$availability)
  dense_info <- ledgr_run_info(dense_snapshot, dense_bt$run_id)
  testthat::expect_true(is.na(dense_info$execution_timing_version))
  testthat::expect_identical(
    dense_info$execution_timing_convention,
    "dense_bar_timestamp"
  )
})

testthat::test_that("legacy timing is read-only and mixed versions reject fill equivalence", {
  snapshot <- availability_runtime_fixture(days = 4L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  exp <- availability_timing_experiment(snapshot, calls)
  modern <- ledgr_run(exp, run_id = "timing-v2")
  legacy_source <- ledgr_run(exp, run_id = "timing-v1")
  close(modern)
  close(legacy_source)
  legacy_identity <- availability_make_legacy_timing_run(snapshot$db_path, "timing-v1")
  before <- availability_timing_store_contents(snapshot$db_path, "timing-v1")

  legacy_info <- ledgr_run_info(snapshot, "timing-v1")
  modern_info <- ledgr_run_info(snapshot, "timing-v2")
  testthat::expect_identical(legacy_info$execution_timing_version, 1L)
  testthat::expect_identical(legacy_info$execution_timing_convention, "availability_close_v1")
  testthat::expect_identical(legacy_info$execution_timing_source, "legacy_config_inference")
  testthat::expect_identical(modern_info$execution_timing_version, 2L)
  testthat::expect_identical(modern_info$execution_timing_convention, "availability_open_v2")

  legacy <- ledgr_run_open(snapshot, "timing-v1")
  on.exit(close(legacy), add = TRUE)
  legacy_fills <- ledgr_run_fills(legacy)
  testthat::expect_identical(
    legacy_fills$ts_utc,
    as.POSIXct("2020-01-02 16:00:00", tz = "UTC")
  )
  testthat::expect_identical(legacy_fills$ts_utc, legacy_fills$recording_pulse_ts_utc)
  testthat::expect_output(
    summary(legacy),
    "Fill Timing:         availability_close_v1",
    fixed = TRUE
  )

  comparison <- ledgr_run_compare(snapshot, run_ids = c("timing-v1", "timing-v2"))
  testthat::expect_identical(
    comparison$execution_timing_convention,
    c("availability_close_v1", "availability_open_v2")
  )
  testthat::expect_false(attr(comparison, "fill_timing_comparable", exact = TRUE))
  testthat::expect_identical(
    attr(comparison, "fill_timing_comparability_reason", exact = TRUE),
    "mixed_timing_conventions"
  )
  testthat::expect_true(all(is.finite(comparison$final_equity)))
  testthat::expect_error(
    ledgr:::ledgr_comparison_assert_fill_timing_comparable(comparison),
    class = "ledgr_fill_timing_not_comparable"
  )
  testthat::expect_output(print(comparison), "Fill timing comparable: no")

  testthat::expect_identical(
    availability_timing_store_contents(snapshot$db_path, "timing-v1"),
    before
  )
  testthat::expect_identical(
    legacy_info$config_json,
    as.character(legacy_identity$config_json)
  )
  testthat::expect_identical(legacy_info$config_hash, legacy_identity$config_hash)
  calls_before_resume <- calls$n
  testthat::expect_error(
    ledgr_run(exp, run_id = "timing-v1"),
    class = "ledgr_run_hash_mismatch"
  )
  testthat::expect_identical(calls$n, calls_before_resume)
  testthat::expect_identical(
    availability_timing_store_contents(snapshot$db_path, "timing-v1"),
    before
  )
})

testthat::test_that("unknown timing evidence is never promoted to version two", {
  provider <- ledgr:::ledgr_availability_provider_version()
  cases <- list(
    list(availability = list(active = TRUE, provider_version = "other")),
    list(availability = list(
      active = TRUE,
      provider_version = provider,
      execution_timing_version = 1L
    )),
    list(availability = list(active = TRUE, execution_timing_version = 2L)),
    list()
  )
  observed <- lapply(cases, ledgr:::ledgr_execution_timing_provenance)
  testthat::expect_true(all(vapply(
    observed,
    function(x) is.na(x$execution_timing_version),
    logical(1)
  )))
  testthat::expect_true(all(vapply(
    observed,
    function(x) identical(x$execution_timing_convention, "unknown"),
    logical(1)
  )))
  testthat::expect_error(
    ledgr:::ledgr_execution_timing_require_current(cases[[1L]]),
    class = "ledgr_execution_timing_version_mismatch"
  )
})
