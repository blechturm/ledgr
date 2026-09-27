testthat::test_that("[LTB-0084] retired context names stay absent and rule hashes stay stable", {
  universe <- c("AAA", "BBB")
  bars <- data.frame(
    instrument_id = universe,
    ts_utc = as.POSIXct(rep("2026-01-02 21:00:00", 2L), tz = "UTC"),
    open = c(10, 20),
    high = c(11, 21),
    low = c(9, 19),
    close = c(10.5, 20.5),
    volume = c(100, 200),
    stringsAsFactors = FALSE
  )
  ctx <- ledgr:::ledgr_pulse_context(
    run_id = "surface",
    ts_utc = bars$ts_utc[[1L]],
    universe = universe,
    bars = bars,
    positions = c(AAA = 0, BBB = 3),
    cash = 100,
    equity = 161.5
  )

  testthat::expect_null(ctx$positions)
  testthat::expect_null(ctx$targets)
  testthat::expect_null(ctx$current_targets)
  testthat::expect_null(ctx$safety_state)
  testthat::expect_identical(ctx$vec$position, c(0, 3))
  testthat::expect_identical(
    vapply(universe, ctx$position, numeric(1)),
    stats::setNames(ctx$vec$position, universe)
  )
  intent <- ctx$hold()
  intent[["BBB"]] <- 0
  testthat::expect_identical(ctx$position("BBB"), 3)
  testthat::expect_identical(ctx$vec$position[[2L]], 3)

  exports <- getNamespaceExports("ledgr")
  testthat::expect_true(all(c("ledgr_rule_argmax", "ledgr_rule_argmin") %in% exports))
  testthat::expect_false(any(c("ledgr_select_argmax", "ledgr_select_argmin") %in% exports))
  rule <- ledgr_rule_argmax("sharpe_ratio")
  testthat::expect_identical(
    ledgr:::ledgr_selection_rule_payload(rule),
    list(
      type_id = "argmax",
      schema_version = "v1",
      metric = "sharpe_ratio",
      direction = "max"
    )
  )
  testthat::expect_identical(
    rule$selection_rule_hash,
    "cc82a9145ed03d08af24c05dbca0dadc824af9772131386868e335a2e28bbd57"
  )
})
