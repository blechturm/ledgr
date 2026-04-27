testthat::test_that("exported API surface is locked (v0.1.2)", {
  exports <- sort(getNamespaceExports("ledgr"))

  expected <- sort(c(
    "iso_utc",
    "ledgr_adapter_csv",
    "ledgr_adapter_r",
    "ledgr_backtest",
    "ledgr_backtest_bench",
    "ledgr_backtest_run",
    "ledgr_clear_feature_cache",
    "ledgr_compute_equity_curve",
    "ledgr_compute_metrics",
    "ledgr_create_schema",
    "ledgr_data_hash",
    "ledgr_db_init",
    "ledgr_deregister_indicator",
    "ledgr_extract_fills",
    "ledgr_get_indicator",
    "ledgr_ind_ema",
    "ledgr_ind_returns",
    "ledgr_ind_rsi",
    "ledgr_ind_sma",
    "ledgr_ind_ttr",
    "ledgr_indicator",
    "ledgr_indicator_dev",
    "ledgr_list_indicators",
    "ledgr_pulse_snapshot",
    "ledgr_register_indicator",
    "ledgr_signal_strategy",
    "ledgr_snapshot_close",
    "ledgr_snapshot_create",
    "ledgr_snapshot_from_csv",
    "ledgr_snapshot_from_df",
    "ledgr_snapshot_from_yahoo",
    "ledgr_snapshot_import_bars_csv",
    "ledgr_snapshot_import_instruments_csv",
    "ledgr_snapshot_info",
    "ledgr_snapshot_list",
    "ledgr_snapshot_load",
    "ledgr_snapshot_seal",
    "ledgr_state_reconstruct",
    "ledgr_ttr_warmup_rules",
    "ledgr_validate_schema"
  ))

  testthat::expect_identical(exports, expected)
  testthat::expect_false("ledgr_snapshot_hash" %in% exports)
})

