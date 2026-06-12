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

testthat::test_that("ledgr_feature_id exposes existing indicator IDs", {
  sma <- ledgr_ind_sma(20)
  returns <- ledgr_ind_returns(5)

  testthat::expect_identical(ledgr_feature_id(sma), "sma_20")
  testthat::expect_identical(
    ledgr_feature_id(list(sma, returns)),
    c("sma_20", "return_5")
  )
  named <- list(first = sma, second = returns)
  testthat::expect_null(names(ledgr_feature_id(named)))
  testthat::expect_error(
    ledgr_feature_id(list(sma, list(id = "not_an_indicator"))),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_feature_id(list(list(sma))),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_feature_id("sma_20"),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("ledgr_param creates stable parameter references", {
  ref <- ledgr_param("fast_n")

  testthat::expect_s3_class(ref, "ledgr_param_ref")
  testthat::expect_identical(ref$name, "fast_n")
  testthat::expect_true(any(grepl("fast_n", utils::capture.output(print(ref)), fixed = TRUE)))
  testthat::expect_error(ledgr_param(character()), class = "ledgr_invalid_param_reference")
  testthat::expect_error(ledgr_param(""), class = "ledgr_invalid_param_reference")
})

testthat::test_that("built-in constructors accept parameter references only in scalar tuning arguments", {
  sma <- ledgr_ind_sma(ledgr_param("fast_n"))
  ema <- ledgr_ind_ema(ledgr_param("ema_n"))
  rsi <- ledgr_ind_rsi(ledgr_param("rsi_n"))
  ret <- ledgr_ind_returns(ledgr_param("ret_n"))

  testthat::expect_s3_class(sma, "ledgr_parameterized_indicator")
  testthat::expect_s3_class(ema, "ledgr_parameterized_indicator")
  testthat::expect_s3_class(rsi, "ledgr_parameterized_indicator")
  testthat::expect_s3_class(ret, "ledgr_parameterized_indicator")
  testthat::expect_error(ledgr_feature_id(sma), class = "ledgr_unresolved_feature_id")
  testthat::expect_error(ledgr_feature_id(list(sma)), class = "ledgr_unresolved_feature_id")
  testthat::expect_error(
    ledgr_indicator(
      id = "custom_param",
      fn = function(window) tail(window$close, 1),
      requires_bars = 1L,
      params = list(n = ledgr_param("n"))
    ),
    class = "ledgr_unsupported_param_placement"
  )
})

testthat::test_that("built-in indicator windows reject values above R integer range", {
  too_large <- .Machine$integer.max + 1

  testthat::expect_error(ledgr_ind_sma(too_large), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_ind_ema(too_large), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_ind_rsi(too_large), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_ind_returns(too_large), class = "ledgr_invalid_args")
})

testthat::test_that("print.ledgr_indicator surfaces the feature ID", {
  out <- utils::capture.output(print(ledgr_ind_sma(20)))
  testthat::expect_true(any(grepl("ID:\\s*sma_20", out)))
  testthat::expect_true(any(grepl("Requires bars:\\s*20", out)))
})

testthat::test_that("indicator registry supports register/get/list", {
  ind <- ledgr_ind_sma(2)
  ledgr_indicator_register(ind, "test_sma_2", overwrite = TRUE)

  fetched <- ledgr_indicator_get("test_sma_2")
  testthat::expect_s3_class(fetched, "ledgr_indicator")
  testthat::expect_identical(fetched$id, "sma_2")
  testthat::expect_true("test_sma_2" %in% ledgr_indicator_list("^test_"))

  testthat::expect_error(
    ledgr_indicator_get("missing_indicator"),
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

  ledgr_indicator_register(ind_a, name, overwrite = TRUE)
  testthat::expect_silent(ledgr_indicator_register(ind_a, name))
  err <- testthat::capture_error(
    ledgr_indicator_register(ind_b, name),
  )
  testthat::expect_s3_class(err, "ledgr_invalid_args")
  testthat::expect_match(conditionMessage(err), "already registered", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "Existing registration is unchanged", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "overwrite = TRUE", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "distinct indicator id/name", fixed = TRUE)
  testthat::expect_silent(ledgr_indicator_register(ind_b, name, overwrite = TRUE))
})

testthat::test_that("indicator registry supports deregistration", {
  name <- "test_registry_remove"
  ledgr_indicator_remove(name, missing_ok = TRUE)
  on.exit(ledgr_indicator_remove(name, missing_ok = TRUE), add = TRUE)

  ind <- ledgr_indicator(
    id = name,
    fn = function(window) mean(window$close),
    requires_bars = 2L
  )

  ledgr_indicator_register(ind)
  testthat::expect_true(name %in% ledgr_indicator_list("^test_registry_remove$"))
  testthat::expect_true(ledgr_indicator_remove(name))
  testthat::expect_false(name %in% ledgr_indicator_list("^test_registry_remove$"))
  testthat::expect_error(
    ledgr_indicator_get(name),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("indicator deregistration handles missing and invalid names", {
  name <- "test_registry_missing"
  ledgr_indicator_remove(name, missing_ok = TRUE)

  testthat::expect_false(ledgr_indicator_remove(name, missing_ok = TRUE))
  testthat::expect_error(
    ledgr_indicator_remove(name, missing_ok = FALSE),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_indicator_remove(character()),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_indicator_remove(name, missing_ok = NA),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("indicator deregistration does not mutate persisted feature artifacts", {
  name <- "test_registry_persisted_artifact"
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  on.exit(ledgr_indicator_remove(name, missing_ok = TRUE), add = TRUE)

  ind <- ledgr_indicator(
    id = name,
    fn = function(window) tail(window$close, 1),
    series_fn = function(bars, params = list()) bars$close,
    requires_bars = 1L
  )

  strategy <- function(ctx, params) {
    ctx$flat()
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-10",
    initial_cash = 1000,
    features = list(ind),
    db_path = db_path,
  cost_model = ledgr_cost_zero()
  )
  on.exit(close(bt), add = TRUE)

  con <- ledgr:::get_connection(bt)
  before <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM features WHERE run_id = ? AND feature_name = ?",
    params = list(bt$run_id, name)
  )$n[[1]]

  testthat::expect_gt(before, 0L)
  ledgr_indicator_remove(name)

  after <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM features WHERE run_id = ? AND feature_name = ?",
    params = list(bt$run_id, name)
  )$n[[1]]

  testthat::expect_identical(after, before)
  testthat::expect_false(name %in% ledgr_indicator_list("^test_registry_persisted_artifact$"))
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
