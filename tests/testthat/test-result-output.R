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
