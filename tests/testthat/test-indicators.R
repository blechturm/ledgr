testthat::test_that("ledgr_indicator enforces deterministic params", {
  good <- ledgr:::ledgr_indicator(
    id = "good_indicator",
    fn = function(window) mean(window$close),
    requires_bars = 2L,
    params = list(n = 2, label = "stable")
  )
  testthat::expect_s3_class(good, "ledgr_indicator")
  testthat::expect_identical(good$stable_after, good$requires_bars)

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

testthat::test_that("ledgr_indicator enforces stable_after >= requires_bars", {
  testthat::expect_error(
    ledgr:::ledgr_indicator(
      id = "bad_stable",
      fn = function(window) mean(window$close),
      requires_bars = 3L,
      stable_after = 2L
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

  testthat::expect_error(
    ledgr:::ledgr_indicator(
      id = "bad_series_fn",
      fn = function(window) mean(window$close),
      series_fn = function(bars, params) Sys.time(),
      requires_bars = 1L
    ),
    class = "ledgr_purity_violation"
  )
})

testthat::test_that("indicator fingerprint includes series_fn", {
  ind_a <- ledgr_indicator(
    id = "series_fingerprint",
    fn = function(window) tail(window$close, 1),
    series_fn = function(bars, params) bars$close,
    requires_bars = 1L
  )
  ind_b <- ledgr_indicator(
    id = "series_fingerprint",
    fn = function(window) tail(window$close, 1),
    series_fn = function(bars, params) bars$close * 2,
    requires_bars = 1L
  )

  testthat::expect_s3_class(ind_a, "ledgr_indicator")
  testthat::expect_true(is.function(ind_a$series_fn))
  testthat::expect_false(identical(
    ledgr:::ledgr_indicator_fingerprint(ind_a),
    ledgr:::ledgr_indicator_fingerprint(ind_b)
  ))
})

testthat::test_that("indicator registry supports register/get/list", {
  ind <- ledgr_ind_sma(2)
  ledgr_register_indicator(ind, "test_sma_2", overwrite = TRUE)

  fetched <- ledgr_get_indicator("test_sma_2")
  testthat::expect_s3_class(fetched, "ledgr_indicator")
  testthat::expect_identical(fetched$id, "sma_2")
  testthat::expect_true("test_sma_2" %in% ledgr_list_indicators("^test_"))

  testthat::expect_error(
    ledgr_get_indicator("missing_indicator"),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("indicator registry rejects silent overwrite", {
  name <- "test_registry_duplicate"
  ind_a <- ledgr_indicator(
    id = "registry_dup_a",
    fn = function(window) mean(window$close),
    requires_bars = 2L,
    params = list(kind = "a")
  )
  ind_b <- ledgr_indicator(
    id = "registry_dup_b",
    fn = function(window) sum(window$close),
    requires_bars = 2L,
    params = list(kind = "b")
  )

  ledgr_register_indicator(ind_a, name, overwrite = TRUE)
  testthat::expect_silent(ledgr_register_indicator(ind_a, name))
  testthat::expect_error(
    ledgr_register_indicator(ind_b, name),
    "already registered",
    class = "ledgr_invalid_args"
  )
  testthat::expect_silent(ledgr_register_indicator(ind_b, name, overwrite = TRUE))
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
    ledgr_ind_sma(5),
    ledgr_ind_ema(5),
    ledgr_ind_rsi(14),
    ledgr_ind_returns(1)
  )

  for (ind in indicators) {
    values <- ledgr:::ledgr_compute_feature_series(window, ind)
    latest_window <- utils::tail(window, ind$stable_after)
    result1 <- ind$fn(latest_window)
    result2 <- ind$fn(latest_window)
    testthat::expect_identical(result1, result2)
    testthat::expect_silent(ind$fn(window))
    testthat::expect_length(values, nrow(window))
    testthat::expect_equal(
      values[[nrow(window)]],
      result1,
      tolerance = 1e-12
    )
    for (i in seq_along(values)) {
      expected <- if (i < ind$stable_after) {
        NA_real_
      } else {
        ind$fn(utils::tail(window[seq_len(i), , drop = FALSE], ind$stable_after))
      }
      testthat::expect_equal(values[[i]], expected, tolerance = 1e-12)
    }

    fn_body <- deparse(ind$fn)
    testthat::expect_false(any(grepl("<<-", fn_body, fixed = TRUE)))
    testthat::expect_true(is.function(ind$series_fn))
  }
})
