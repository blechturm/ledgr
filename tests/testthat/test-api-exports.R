testthat::test_that("exported API surface is locked (v0.1.1)", {
  exports <- sort(getNamespaceExports("ledgr"))

  expected <- sort(c(
    "ledgr_backtest_run",
    "ledgr_create_schema",
    "ledgr_data_hash",
    "ledgr_db_init",
    "ledgr_snapshot_create",
    "ledgr_snapshot_import_bars_csv",
    "ledgr_snapshot_import_instruments_csv",
    "ledgr_snapshot_info",
    "ledgr_snapshot_list",
    "ledgr_snapshot_seal",
    "ledgr_state_reconstruct",
    "ledgr_validate_schema"
  ))

  testthat::expect_identical(exports, expected)
  testthat::expect_false("ledgr_snapshot_hash" %in% exports)
})

