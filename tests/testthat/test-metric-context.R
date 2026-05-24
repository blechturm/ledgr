testthat::test_that("calendar constructors validate annualization policy", {
  daily <- ledgr_calendar_us_equity()
  testthat::expect_s3_class(daily, "ledgr_calendar")
  testthat::expect_identical(daily$source, "us_equity")
  testthat::expect_equal(daily$trading_days_per_year, 252)
  testthat::expect_equal(daily$bars_per_day, 1)
  testthat::expect_equal(daily$bars_per_year, 252)

  minute <- ledgr_calendar_us_equity(bars_per_day = 390L)
  testthat::expect_equal(minute$bars_per_year, 252 * 390)
  testthat::expect_match(
    paste(capture.output(print(minute)), collapse = "\n"),
    "Bars/year:\\s+98,280"
  )

  crypto <- ledgr_calendar_crypto()
  testthat::expect_identical(crypto$source, "crypto")
  testthat::expect_equal(crypto$bars_per_year, 365)

  custom <- ledgr_calendar(260, bars_per_day = 2, label = "custom half-day", source = "manual")
  testthat::expect_equal(custom$bars_per_year, 520)
  testthat::expect_match(paste(capture.output(print(custom)), collapse = "\n"), "custom half-day", fixed = TRUE)

  testthat::expect_error(ledgr_calendar(0), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_calendar_us_equity(bars_per_day = NA_real_), class = "ledgr_invalid_args")
})

testthat::test_that("calendar mismatch warning explains intraday fix", {
  testthat::expect_warning(
    ledgr:::ledgr_calendar_warn_if_inconsistent(
      ledgr_calendar_us_equity(),
      observed_bars = 1000,
      context = "run"
    ),
    "ledgr_calendar_us_equity\\(bars_per_day = \\.\\.\\.\\)"
  )

  testthat::expect_no_warning(
    ledgr:::ledgr_calendar_warn_if_inconsistent(
      ledgr_calendar_us_equity(bars_per_day = 390L),
      observed_bars = 1000,
      context = "run"
    )
  )
})

testthat::test_that("risk-free-rate objects normalize manual scalar provenance", {
  rf <- ledgr_risk_free_rate(0.04, label = "T-bill", source = "manual", as_of = "2026-05-24")
  testthat::expect_s3_class(rf, "ledgr_risk_free_rate")
  testthat::expect_equal(rf$annual_rate, 0.04)
  testthat::expect_identical(rf$label, "T-bill")
  testthat::expect_identical(rf$source, "manual")
  testthat::expect_identical(rf$as_of, as.Date("2026-05-24"))
  testthat::expect_match(paste(capture.output(print(rf)), collapse = "\n"), "4.0000%")

  testthat::expect_error(ledgr_risk_free_rate(-1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_risk_free_rate(Inf), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_risk_free_rate(0, as_of = "not-a-date"), class = "ledgr_invalid_args")
})

testthat::test_that("metric contexts validate reserved fields and templates", {
  ctx <- ledgr_metric_context(
    risk_free_rate = ledgr_risk_free_rate(0.02, source = "manual"),
    calendar = ledgr_calendar_us_equity()
  )
  testthat::expect_s3_class(ctx, "ledgr_metric_context")
  testthat::expect_identical(ctx$metric_context_version, 1L)
  testthat::expect_equal(ctx$risk_free_rate$annual_rate, 0.02)
  testthat::expect_equal(ctx$calendar$bars_per_year, 252)
  testthat::expect_null(ctx$benchmark)
  testthat::expect_null(ctx$market_factor)
  testthat::expect_null(ctx$mar)

  us <- ledgr_metric_us_equity(risk_free_rate = 0.03)
  testthat::expect_equal(us$risk_free_rate$annual_rate, 0.03)
  testthat::expect_identical(us$calendar$source, "us_equity")

  crypto <- ledgr_metric_crypto(risk_free_rate = 0.01)
  testthat::expect_identical(crypto$calendar$source, "crypto")
  testthat::expect_equal(crypto$calendar$bars_per_year, 365)

  testthat::expect_error(
    ledgr_metric_context(benchmark = list(provider = "not-yet")),
    "`benchmark` is reserved",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_metric_context(calendar = list(bars_per_year = 252)),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("metric context resolve supports defaults and scalar shorthand", {
  default <- ledgr_metric_context_resolve(NULL)
  testthat::expect_s3_class(default, "ledgr_metric_context")
  testthat::expect_equal(default$risk_free_rate$annual_rate, 0)
  testthat::expect_identical(default$calendar$source, "us_equity")
  testthat::expect_identical(ledgr_metric_context(NULL), default)

  scalar <- ledgr_metric_context_resolve(0.05)
  testthat::expect_equal(scalar$risk_free_rate$annual_rate, 0.05)
  testthat::expect_equal(ledgr_metric_context(0.06)$risk_free_rate$annual_rate, 0.06)

  direct <- ledgr_metric_context(risk_free_rate = 0.01)
  testthat::expect_identical(ledgr_metric_context(direct), direct)

  testthat::expect_error(ledgr_metric_context_resolve("bad"), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_metric_context(structure(list(), class = "not_ledgr")), class = "ledgr_missing_metric_context")
})

testthat::test_that("metric context hashes are canonical and omit NULL reserved fields", {
  ctx <- ledgr_metric_context(
    risk_free_rate = ledgr_risk_free_rate(0.04, source = "manual", as_of = "2026-05-24"),
    calendar = ledgr_calendar_us_equity()
  )
  hash <- ledgr_metric_context_hash(ctx)
  testthat::expect_type(hash, "character")
  testthat::expect_match(hash, "^[0-9a-f]{64}$")

  reordered <- ctx[c("mar", "market_factor", "benchmark", "calendar", "risk_free_rate", "metric_context_version")]
  class(reordered) <- class(ctx)
  testthat::expect_identical(ledgr_metric_context_hash(reordered), hash)

  default_payload <- ledgr:::ledgr_metric_context_payload(ledgr_metric_context())
  testthat::expect_false("benchmark" %in% names(default_payload))
  testthat::expect_false("market_factor" %in% names(default_payload))
  testthat::expect_false("mar" %in% names(default_payload))

  changed_rate <- ledgr_metric_context(risk_free_rate = 0.041)
  changed_calendar <- ledgr_metric_context(calendar = ledgr_calendar_us_equity(bars_per_day = 390L))
  testthat::expect_false(identical(ledgr_metric_context_hash(changed_rate), ledgr_metric_context_hash(ledgr_metric_context())))
  testthat::expect_false(identical(ledgr_metric_context_hash(changed_calendar), ledgr_metric_context_hash(ledgr_metric_context())))

  renamed <- ledgr_metric_context(
    risk_free_rate = ledgr_risk_free_rate(0.04, label = "renamed rf", source = "manual", as_of = "2026-05-24"),
    calendar = ledgr_calendar(252, label = "renamed calendar", source = "us_equity")
  )
  testthat::expect_identical(ledgr_metric_context_hash(renamed), hash)

  changed_source <- ledgr_metric_context(
    risk_free_rate = ledgr_risk_free_rate(0.04, source = "alternate", as_of = "2026-05-24"),
    calendar = ledgr_calendar_us_equity()
  )
  testthat::expect_false(identical(ledgr_metric_context_hash(changed_source), hash))
})
