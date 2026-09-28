ledgr_result_output_table <- function(class_name, data) {
  ledgr:::ledgr_classed_tibble(data, class_name)
}

testthat::test_that("[LTB-0106] curated result prints respect selected columns", {
  comparison <- ledgr_result_output_table(
    "ledgr_comparison",
    data.frame(
      run_id = "run-1",
      label = "demo",
      final_equity = 110,
      total_return = 0.1,
      sharpe_ratio = 1.2,
      max_drawdown = 0.05,
      n_trades = 3L,
      win_rate = 2 / 3,
      reproducibility_level = "full",
      strategy_source_hash = "source-hash",
      stringsAsFactors = FALSE
    )
  )
  attr(comparison, "fill_timing_comparable") <- TRUE
  attr(comparison, "fill_timing_comparability_reason") <- "same convention"

  selected <- dplyr::select(comparison, n_trades, run_id, final_equity)
  selected_output <- utils::capture.output(print(selected, width = Inf))
  selected_header <- selected_output[grepl("n_trades", selected_output, fixed = TRUE)][1]
  testthat::expect_match(
    selected_header,
    "n_trades\\s+run_id\\s+final_equity"
  )
  testthat::expect_false(any(grepl(
    "Full identity and telemetry columns",
    selected_output,
    fixed = TRUE
  )))

  curated <- c(
    "run_id", "label", "final_equity", "total_return", "sharpe_ratio",
    "max_drawdown", "n_trades", "win_rate", "reproducibility_level"
  )
  curated_only <- dplyr::select(comparison, dplyr::all_of(curated))
  curated_output <- utils::capture.output(print(curated_only, width = Inf))
  testthat::expect_false(any(grepl(
    "Full identity and telemetry columns",
    curated_output,
    fixed = TRUE
  )))
  full_output <- utils::capture.output(print(comparison, width = Inf))
  testthat::expect_true(any(grepl(
    "Full identity and telemetry columns",
    full_output,
    fixed = TRUE
  )))

  runs <- ledgr_result_output_table(
    "ledgr_run_list",
    data.frame(
      run_id = "run-1",
      label = "demo",
      tags = "example",
      status = "DONE",
      final_equity = 110,
      total_return = 0.1,
      complete_performance = TRUE,
      achieved_end_utc = as.POSIXct("2020-01-02", tz = "UTC"),
      execution_mode = "audit_log",
      reproducibility_level = "full",
      strategy_source_hash = "source-hash",
      stringsAsFactors = FALSE
    )
  )
  run_selected <- dplyr::select(runs, status, run_id)
  run_output <- utils::capture.output(print(run_selected, width = Inf))
  run_header <- run_output[grepl("status", run_output, fixed = TRUE)][1]
  testthat::expect_match(run_header, "status\\s+run_id")
  testthat::expect_false(any(grepl(
    "Full identity and telemetry columns",
    run_output,
    fixed = TRUE
  )))
})

ledgr_result_output_run <- function(ts_utc, run_id) {
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = ts_utc,
    open = seq_along(ts_utc) + 99,
    high = seq_along(ts_utc) + 100,
    low = seq_along(ts_utc) + 98,
    close = seq_along(ts_utc) + 99,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- 1
    targets
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  )
  list(snapshot = snapshot, bt = ledgr_run(exp, list(), run_id = run_id))
}

testthat::test_that("[LTB-0107] backtest print is a one-screen result", {
  daily <- ledgr_result_output_run(
    as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
    "daily-print"
  )
  on.exit(close(daily$bt), add = TRUE)
  on.exit(ledgr_snapshot_close(daily$snapshot), add = TRUE)
  metrics <- ledgr_compute_metrics(daily$bt)
  testthat::local_mocked_bindings(
    ledgr_compute_metrics = function(...) {
      rlang::abort("print(bt) must not replay fills", class = "ledgr_print_replayed_fills")
    },
    .package = "ledgr"
  )
  before <- unserialize(serialize(daily$bt, NULL))
  output <- utils::capture.output(print(daily$bt))
  blob <- paste(output, collapse = "\n")

  testthat::expect_lte(length(output), 15L)
  testthat::expect_match(blob, "Run ID:", fixed = TRUE)
  testthat::expect_match(blob, "Period:.*2020-01-01 to 2020-01-04")
  testthat::expect_match(blob, "Opening Cash:", fixed = TRUE)
  testthat::expect_match(blob, "Final Equity:", fixed = TRUE)
  testthat::expect_match(blob, sprintf("%.2f%%", metrics$total_return * 100), fixed = TRUE)
  testthat::expect_match(blob, sprintf("%.2f%%", metrics$max_drawdown * 100), fixed = TRUE)
  testthat::expect_match(blob, sprintf("Closed Trades:.*%d", metrics$n_trades))
  testthat::expect_false(grepl("Execution Mode:", blob, fixed = TRUE))
  testthat::expect_match(
    blob,
    "Corporate actions: NOT SUPPLIED - returns may omit distributions",
    fixed = TRUE
  )
  testthat::expect_match(
    blob,
    "Price basis: UNDECLARED - distribution double counting cannot be ruled out",
    fixed = TRUE
  )
  testthat::expect_identical(daily$bt, before)

  intraday_period <- ledgr:::ledgr_result_period_label(
    as.POSIXct("2020-01-01 09:30:00", tz = "UTC"),
    as.POSIXct("2020-01-01 12:30:00", tz = "UTC")
  )
  testthat::expect_identical(
    intraday_period,
    "2020-01-01T09:30:00Z to 2020-01-01T12:30:00Z"
  )

  completion <- ledgr:::ledgr_backtest_completion_info(daily$bt)
  completion$completion_evidence_available <- TRUE
  completion$complete_performance <- FALSE
  testthat::local_mocked_bindings(
    ledgr_run_completion_info = function(...) completion,
    .package = "ledgr"
  )
  prefix_output <- paste(utils::capture.output(print(daily$bt)), collapse = "\n")
  testthat::expect_match(prefix_output, "Total Return (achieved prefix):", fixed = TRUE)
  testthat::expect_match(prefix_output, "Max Drawdown (achieved prefix):", fixed = TRUE)

  opening_meta <- canonical_json(list(
    source = "opening_position",
    cash_delta = 0,
    position_delta = 4,
    cost_basis = 10,
    opening_position = TRUE
  ))
  events <- data.frame(
    event_id = paste0("headline_", 1:3),
    run_id = "headline",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 1:3,
    event_type = c("CASHFLOW", "FILL", "FILL"),
    instrument_id = "AAA",
    side = c(NA, "SELL", "BUY"),
    qty = c(4, 10, 9),
    price = c(10, 12, 11),
    fee = 0,
    meta_json = c(opening_meta, NA, NA),
    event_seq = 1:3,
    stringsAsFactors = FALSE
  )
  replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(events)
  )
  testthat::expect_identical(
    ledgr:::ledgr_headline_closed_trade_count(events),
    as.integer(sum(replay$close_qty > 0))
  )
})

testthat::test_that("[LTB-0108] summary answers before compact evidence", {
  context <- ledgr_metric_context()
  computed <- ledgr:::ledgr_new_metrics(
    list(
      total_return = 0.1,
      annualized_return = 0.2,
      volatility = 0.15,
      sharpe_ratio = 1.25,
      max_drawdown = -0.05,
      n_trades = 2L,
      win_rate = 0.5,
      avg_trade = 5,
      time_in_market = 0.75
    ),
    ledgr:::ledgr_metric_kernel(context = context)
  )
  completion <- list(
    completion_evidence_available = FALSE,
    complete_performance = TRUE,
    achieved_start_utc = as.POSIXct(NA, tz = "UTC"),
    achieved_end_utc = as.POSIXct(NA, tz = "UTC")
  )
  policy <- structure(
    list(
      corporate_action_fidelity = "not_supplied",
      price_basis = "undeclared"
    ),
    class = c("ledgr_corporate_action_summary", "list")
  )
  bt <- structure(
    list(run_id = "summary-order", config = list()),
    class = c("ledgr_backtest", "list")
  )
  testthat::local_mocked_bindings(
    ledgr_compute_metrics = function(...) computed,
    ledgr_backtest_completion_info = function(...) completion,
    ledgr_backtest_warmup_diagnostics = function(...) {
      ledgr:::ledgr_empty_warmup_diagnostics()
    },
    ledgr_execution_timing_provenance = function(...) {
      list(
        execution_timing_convention = "dense_bar_timestamp",
        execution_timing_version = NULL
      )
    },
    ledgr_corporate_action_summary = function(...) policy,
    .package = "ledgr"
  )

  output <- utils::capture.output(summary(bt))
  testthat::expect_lte(length(output), 30L)
  performance <- match("Performance Metrics:", output)
  execution <- match("Execution Evidence:", output)
  corporate <- match("Corporate-Action Evidence:", output)
  testthat::expect_true(performance < execution && execution < corporate)
  testthat::expect_false(any(grepl("Timing Version:      N/A", output, fixed = TRUE)))
  testthat::expect_identical(
    output[corporate + 1:3],
    c(
      "Corporate actions: NOT SUPPLIED - returns may omit distributions",
      "Price basis: UNDECLARED - distribution double counting cannot be ruled out",
      "  Full policy record: ledgr_corporate_action_summary(bt)"
    )
  )
  testthat::expect_false(any(grepl("  Setting ", output, fixed = TRUE)))

  completion$completion_evidence_available <- TRUE
  completion$complete_performance <- FALSE
  completion$achieved_start_utc <- as.POSIXct("2020-01-01", tz = "UTC")
  completion$achieved_end_utc <- as.POSIXct("2020-01-03", tz = "UTC")
  prefix <- utils::capture.output(summary(bt))
  testthat::expect_true(any(grepl("^Achieved-Prefix Metrics", prefix)))
  testthat::expect_true(any(grepl("Total Return (prefix)", prefix, fixed = TRUE)))
  testthat::expect_true(any(grepl("Max Drawdown (prefix)", prefix, fixed = TRUE)))
  testthat::expect_true(any(grepl(
    "Volatility (annual): withheld",
    prefix,
    fixed = TRUE
  )))
})

testthat::test_that("[LTB-0110] metrics print without dumping attributes", {
  context <- ledgr_metric_context()
  metrics <- ledgr:::ledgr_new_metrics(
    list(
      total_return = 0.1,
      annualized_return = 0.2,
      volatility = 0.15,
      sharpe_ratio = 1.25,
      max_drawdown = -0.05,
      n_trades = 2L,
      win_rate = 0.5,
      avg_trade = 5,
      time_in_market = 0.75
    ),
    ledgr:::ledgr_metric_kernel(context = context)
  )
  names_before <- names(metrics)
  values_before <- unclass(metrics)
  attributes_before <- attributes(metrics)
  context_before <- ledgr_metric_context(metrics)

  output <- utils::capture.output(returned <- print(metrics))
  testthat::expect_lte(length(output), 15L)
  testthat::expect_identical(output[1:2], c("ledgr Metrics", "============="))
  expected_labels <- c(
    "Total Return:", "Annualized Return:", "Volatility (annual):",
    "Sharpe Ratio:", "Max Drawdown:", "Closed Trades:", "Win Rate:",
    "Avg Trade:", "Time in Market:"
  )
  label_rows <- vapply(expected_labels, function(label) {
    which(grepl(label, output, fixed = TRUE))[[1]]
  }, integer(1))
  testthat::expect_identical(unname(label_rows), 3:11)
  context_row <- output[grepl("^Context: risk-free ", output)]
  testthat::expect_length(context_row, 1L)
  testthat::expect_match(context_row, "annualization|periods/year")
  testthat::expect_match(context_row, "hash [0-9a-f]{12}$")
  testthat::expect_true(
    "Scope: persisted equity prefix; use summary(bt) for completion-aware reporting" %in%
      output
  )
  testthat::expect_identical(returned, metrics)
  testthat::expect_identical(names(metrics), names_before)
  testthat::expect_identical(unclass(metrics), values_before)
  testthat::expect_identical(attributes(metrics), attributes_before)
  testthat::expect_identical(ledgr_metric_context(metrics), context_before)
  testthat::expect_type(unclass(metrics), "list")
})

testthat::test_that("[LTB-0111] metadata prints align and bound elapsed precision", {
  extracted <- structure(
    list(
      run_id = "run-1",
      reproducibility_level = "full",
      strategy_source_hash = "source-hash",
      strategy_params_hash = "params-hash",
      hash_verified = TRUE,
      trust = FALSE,
      strategy_source_text = "function(ctx, params) ctx$flat()",
      strategy_function = NULL,
      warnings = character()
    ),
    class = c("ledgr_extracted_strategy", "list")
  )
  extracted_output <- utils::capture.output(print(extracted))
  testthat::expect_true("Source Available: TRUE" %in% extracted_output)
  extracted_values <- sub("^[^:]+:[ ]*", "", extracted_output[4:10])
  extracted_columns <- regexpr("[^ ]+$", extracted_output[4:10])
  testthat::expect_identical(length(unique(extracted_columns)), 1L)
  testthat::expect_identical(extracted_values[[7]], "TRUE")

  info <- structure(
    list(
      run_id = "run-1",
      label = NA_character_,
      status = "DONE",
      archived = FALSE,
      tags = NA_character_,
      completion_evidence_available = FALSE,
      snapshot_id = "snapshot-1",
      snapshot_hash = "snapshot-hash",
      feature_set_hash = "feature-hash",
      risk_chain_hash = "risk-hash",
      config_hash = "config-hash",
      strategy_source_hash = "source-hash",
      strategy_params_hash = "params-hash",
      reproducibility_level = "full",
      execution_mode = "audit_log",
      execution_timing_convention = "dense_bar_timestamp",
      execution_timing_version = NA_character_,
      elapsed_sec = 0.430000000000001,
      persist_features = TRUE,
      feature_cache_hits = 0L,
      feature_cache_misses = 0L,
      legacy_pre_provenance = FALSE,
      error_msg = NA_character_
    ),
    class = c("ledgr_run_info", "list")
  )
  stored_elapsed <- info$elapsed_sec
  info_output <- utils::capture.output(print(info))
  testthat::expect_true("Elapsed Sec:      0.430" %in% info_output)
  testthat::expect_true("Persist Features: TRUE" %in% info_output)
  metadata_lines <- info_output[4:21]
  metadata_columns <- regexpr("[^ ]+$", metadata_lines)
  testthat::expect_identical(length(unique(metadata_columns)), 1L)
  testthat::expect_false(any(grepl("0.430000000000001", info_output, fixed = TRUE)))
  testthat::expect_identical(info$elapsed_sec, stored_elapsed)
})
