testthat::test_that("ledgr_indicator enforces deterministic params", {
  good <- ledgr:::ledgr_indicator(
    id = "good_indicator",
    fn = function(window) mean(window$close),
    requires_bars = 2L,
    params = list(n = 2, label = "stable")
  )
  testthat::expect_s3_class(good, "ledgr_indicator")

  testthat::expect_error(
    ledgr:::ledgr_indicator(
      id = "bad_indicator",
      fn = function(window) mean(window$close),
      requires_bars = 2L,
      params = list(loaded_at = Sys.time())
    ),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("indicator purity scan blocks non-deterministic calls", {
  testthat::expect_error(
    ledgr:::ledgr_indicator(
      id = "bad_fn",
      fn = function(window) Sys.time(),
      requires_bars = 1L
    ),
    class = "ledgr_purity_violation"
  )
})

testthat::test_that("indicator registry supports register/get/list", {
  ind <- ledgr:::ledgr_ind_sma(2)
  ledgr:::ledgr_register_indicator(ind, "test_sma_2")

  fetched <- ledgr:::ledgr_get_indicator("test_sma_2")
  testthat::expect_s3_class(fetched, "ledgr_indicator")
  testthat::expect_identical(fetched$id, "sma_2")
  testthat::expect_true("test_sma_2" %in% ledgr:::ledgr_list_indicators("^test_"))

  testthat::expect_error(
    ledgr:::ledgr_get_indicator("missing_indicator"),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("built-in indicators are deterministic and silent", {
  n <- 20
  window <- data.frame(
    ts_utc = sprintf("2020-01-%02dT00:00:00Z", seq_len(n)),
    instrument_id = rep("TEST_A", n),
    open = 100 + seq_len(n),
    high = 101 + seq_len(n),
    low = 99 + seq_len(n),
    close = 100 + seq_len(n),
    volume = 1000 + seq_len(n),
    stringsAsFactors = FALSE
  )

  indicators <- list(
    ledgr:::ledgr_ind_sma(5),
    ledgr:::ledgr_ind_ema(5),
    ledgr:::ledgr_ind_rsi(14),
    ledgr:::ledgr_ind_returns(1)
  )

  for (ind in indicators) {
    result1 <- ind$fn(window)
    result2 <- ind$fn(window)
    testthat::expect_identical(result1, result2)
    testthat::expect_silent(ind$fn(window))

    fn_body <- deparse(ind$fn)
    testthat::expect_false(any(grepl("<<-", fn_body, fixed = TRUE)))
  }
})
