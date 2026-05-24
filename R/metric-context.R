#' Create a ledgr calendar
#'
#' `ledgr_calendar()` creates the explicit annualization calendar used by metric
#' contexts. It represents a uniform session model as
#' `trading_days_per_year * bars_per_day`.
#' `ledgr_calendar_us_equity()` defaults to daily bars and can represent common
#' minute bars with `ledgr_calendar_us_equity(bars_per_day = 390L)`.
#' `ledgr_calendar_crypto()` is explicit crypto calendar support; ledgr does not
#' infer crypto annualization from ticker symbols.
#'
#' @param trading_days_per_year Finite positive scalar number of trading days or
#'   market days per year.
#' @param bars_per_day Finite positive scalar number of bars per trading day.
#' @param label Optional non-empty label shown in print and metric disclosures.
#' @param source Non-empty source label for the calendar convention.
#'
#' @return A `ledgr_calendar` object.
#'
#' @section Articles:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
#'
#' @export
ledgr_calendar <- function(trading_days_per_year,
                           bars_per_day = 1L,
                           label = NULL,
                           source = "custom") {
  trading_days_per_year <- ledgr_validate_positive_scalar(
    trading_days_per_year,
    "trading_days_per_year"
  )
  bars_per_day <- ledgr_validate_positive_scalar(bars_per_day, "bars_per_day")
  label <- ledgr_validate_optional_character_scalar(label, "label")
  source <- ledgr_validate_character_scalar(source, "source")

  structure(
    list(
      trading_days_per_year = trading_days_per_year,
      bars_per_day = bars_per_day,
      bars_per_year = trading_days_per_year * bars_per_day,
      label = label,
      source = source
    ),
    class = "ledgr_calendar"
  )
}

#' @rdname ledgr_calendar
#' @export
ledgr_calendar_us_equity <- function(bars_per_day = 1L) {
  bars_per_day <- ledgr_validate_positive_scalar(bars_per_day, "bars_per_day")
  ledgr_calendar(
    trading_days_per_year = 252,
    bars_per_day = bars_per_day,
    label = if (identical(bars_per_day, 1)) "US equity daily" else "US equity custom bars",
    source = "us_equity"
  )
}

#' @rdname ledgr_calendar
#' @export
ledgr_calendar_crypto <- function(bars_per_day = 1L) {
  bars_per_day <- ledgr_validate_positive_scalar(bars_per_day, "bars_per_day")
  ledgr_calendar(
    trading_days_per_year = 365,
    bars_per_day = bars_per_day,
    label = if (identical(bars_per_day, 1)) "crypto daily" else "crypto custom bars",
    source = "crypto"
  )
}

#' @export
print.ledgr_calendar <- function(x, ...) {
  ledgr_validate_calendar_object(x)
  cat("ledgr_calendar\n")
  cat("==============\n")
  if (!is.null(x$label)) {
    cat("Label:          ", x$label, "\n", sep = "")
  }
  cat("Source:         ", x$source, "\n", sep = "")
  cat("Days/year:      ", ledgr_format_number(x$trading_days_per_year), "\n", sep = "")
  cat("Bars/day:       ", ledgr_format_number(x$bars_per_day), "\n", sep = "")
  cat("Bars/year:      ", ledgr_format_number(x$bars_per_year), "\n", sep = "")
  invisible(x)
}

#' Create a scalar risk-free-rate assumption
#'
#' `ledgr_risk_free_rate()` records a scalar annual risk-free rate with optional
#' manual provenance. It is a subordinate value inside `ledgr_metric_context()`,
#' not a provider adapter.
#'
#' @param annual_rate Finite scalar annual rate as a decimal, greater than `-1`.
#' @param label Optional non-empty display label.
#' @param source Non-empty source label. The default is `"manual"`.
#' @param as_of Optional date for the manual rate. Values are normalized to
#'   `Date`.
#'
#' @return A `ledgr_risk_free_rate` object.
#'
#' @section Articles:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
#'
#' @export
ledgr_risk_free_rate <- function(annual_rate,
                                 label = NULL,
                                 source = "manual",
                                 as_of = NULL) {
  annual_rate <- ledgr_validate_annual_rate(annual_rate, "annual_rate")
  label <- ledgr_validate_optional_character_scalar(label, "label")
  source <- ledgr_validate_character_scalar(source, "source")
  as_of <- ledgr_normalize_optional_date(as_of, "as_of")

  structure(
    list(
      annual_rate = annual_rate,
      label = label,
      source = source,
      as_of = as_of
    ),
    class = "ledgr_risk_free_rate"
  )
}

#' @export
print.ledgr_risk_free_rate <- function(x, ...) {
  ledgr_validate_risk_free_rate_object(x)
  cat("ledgr_risk_free_rate\n")
  cat("=====================\n")
  if (!is.null(x$label)) {
    cat("Label:       ", x$label, "\n", sep = "")
  }
  cat("Source:      ", x$source, "\n", sep = "")
  cat("Annual rate: ", ledgr_metric_format_percent(x$annual_rate), "\n", sep = "")
  if (!is.null(x$as_of)) {
    cat("As of:       ", format(x$as_of, "%Y-%m-%d"), "\n", sep = "")
  }
  invisible(x)
}

#' Create or access metric context
#'
#' With no object as the first argument, `ledgr_metric_context()` constructs the
#' metric-assumption object used for risk-free-rate and annualization policy.
#' With a ledgr object as the first argument, it dispatches as an accessor.
#'
#' @param x Optional object to inspect. Omit for constructor behavior. A numeric
#'   scalar first argument is treated as `risk_free_rate` for convenience.
#' @param ... Constructor fields or S3 method arguments.
#' @param risk_free_rate Scalar annual rate or `ledgr_risk_free_rate` used by
#'   the market-template helpers.
#' @param bars_per_day Finite positive scalar number of bars per day used by
#'   the market-template helpers.
#'
#' @return A `ledgr_metric_context` object.
#'
#' @section Articles:
#' `vignette("metrics-and-accounting", package = "ledgr")`
#' `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
#'
#' @export
ledgr_metric_context <- function(x, ...) {
  if (missing(x)) {
    return(ledgr_new_metric_context(...))
  }
  if (is.null(x)) {
    return(ledgr_new_metric_context(...))
  }
  if (is.numeric(x) || inherits(x, "ledgr_risk_free_rate")) {
    return(ledgr_new_metric_context(risk_free_rate = x, ...))
  }
  UseMethod("ledgr_metric_context")
}

#' @export
ledgr_metric_context.ledgr_metric_context <- function(x, ...) {
  ledgr_validate_metric_context_object(x)
  x
}

#' @export
ledgr_metric_context.default <- function(x, ...) {
  rlang::abort(
    "`x` does not carry a ledgr metric context.",
    class = c("ledgr_missing_metric_context", "ledgr_invalid_args")
  )
}

#' @export
print.ledgr_metric_context <- function(x, ...) {
  ledgr_validate_metric_context_object(x)
  cat("ledgr_metric_context\n")
  cat("====================\n")
  cat("Version:        ", x$metric_context_version, "\n", sep = "")
  cat("Risk-free rate: ", ledgr_metric_format_percent(x$risk_free_rate$annual_rate), "\n", sep = "")
  cat("Calendar:       ", ledgr_calendar_display(x$calendar), "\n", sep = "")
  cat("Hash:           ", ledgr_metric_context_hash(x), "\n", sep = "")
  invisible(x)
}

#' Resolve metric context inputs
#'
#' `ledgr_metric_context_resolve()` normalizes constructor shortcuts used by
#' later run, comparison, and sweep paths.
#'
#' @param x `NULL`, a scalar annual risk-free rate, a `ledgr_risk_free_rate`, or
#'   a `ledgr_metric_context`.
#'
#' @return A validated `ledgr_metric_context` object.
#' @export
ledgr_metric_context_resolve <- function(x = NULL) {
  if (is.null(x)) {
    return(ledgr_new_metric_context())
  }
  if (inherits(x, "ledgr_metric_context")) {
    ledgr_validate_metric_context_object(x)
    return(x)
  }
  if (is.numeric(x) || inherits(x, "ledgr_risk_free_rate")) {
    return(ledgr_new_metric_context(risk_free_rate = x))
  }
  rlang::abort(
    "`metric_context` must be NULL, a scalar annual risk-free rate, a ledgr_risk_free_rate, or a ledgr_metric_context.",
    class = "ledgr_invalid_args"
  )
}

#' Hash a metric context
#'
#' Hashes use ledgr's canonical JSON representation of the normalized metric
#' context. Reserved provider fields that are `NULL` are omitted from the hash
#' input.
#'
#' @param x A metric-context shortcut accepted by `ledgr_metric_context_resolve()`.
#'
#' @return A SHA-256 hash string.
#' @export
ledgr_metric_context_hash <- function(x) {
  context <- ledgr_metric_context_resolve(x)
  digest::digest(canonical_json(ledgr_metric_context_payload(context)), algo = "sha256")
}

#' @rdname ledgr_metric_context
#' @export
ledgr_metric_us_equity <- function(risk_free_rate = 0, bars_per_day = 1L) {
  ledgr_new_metric_context(
    risk_free_rate = risk_free_rate,
    calendar = ledgr_calendar_us_equity(bars_per_day = bars_per_day)
  )
}

#' @rdname ledgr_metric_context
#' @export
ledgr_metric_crypto <- function(risk_free_rate = 0, bars_per_day = 1L) {
  ledgr_new_metric_context(
    risk_free_rate = risk_free_rate,
    calendar = ledgr_calendar_crypto(bars_per_day = bars_per_day)
  )
}

ledgr_metric_context_version <- function() 1L

ledgr_new_metric_context <- function(risk_free_rate = 0,
                                     calendar = ledgr_calendar_us_equity(),
                                     benchmark = NULL,
                                     market_factor = NULL,
                                     mar = NULL) {
  risk_free_rate <- ledgr_normalize_risk_free_rate(risk_free_rate)
  ledgr_validate_calendar_object(calendar)
  ledgr_validate_reserved_metric_provider(benchmark, "benchmark")
  ledgr_validate_reserved_metric_provider(market_factor, "market_factor")
  ledgr_validate_reserved_metric_provider(mar, "mar")

  structure(
    list(
      risk_free_rate = risk_free_rate,
      calendar = calendar,
      benchmark = benchmark,
      market_factor = market_factor,
      mar = mar,
      metric_context_version = ledgr_metric_context_version()
    ),
    class = "ledgr_metric_context"
  )
}

ledgr_validate_metric_context_object <- function(x) {
  if (!inherits(x, "ledgr_metric_context")) {
    rlang::abort("`x` must be a ledgr_metric_context object.", class = "ledgr_invalid_args")
  }
  if (!is.list(x)) {
    rlang::abort("`x` must be a list-backed ledgr_metric_context object.", class = "ledgr_invalid_args")
  }
  ledgr_validate_risk_free_rate_object(x$risk_free_rate)
  ledgr_validate_calendar_object(x$calendar)
  ledgr_validate_reserved_metric_provider(x$benchmark, "benchmark")
  ledgr_validate_reserved_metric_provider(x$market_factor, "market_factor")
  ledgr_validate_reserved_metric_provider(x$mar, "mar")
  if (!identical(x$metric_context_version, ledgr_metric_context_version())) {
    rlang::abort("Unsupported `metric_context_version`.", class = "ledgr_invalid_args")
  }
  invisible(TRUE)
}

ledgr_validate_calendar_object <- function(x) {
  if (!inherits(x, "ledgr_calendar")) {
    rlang::abort("`calendar` must be a ledgr_calendar object.", class = "ledgr_invalid_args")
  }
  ledgr_validate_positive_scalar(x$trading_days_per_year, "calendar$trading_days_per_year")
  ledgr_validate_positive_scalar(x$bars_per_day, "calendar$bars_per_day")
  expected <- x$trading_days_per_year * x$bars_per_day
  actual <- ledgr_validate_positive_scalar(x$bars_per_year, "calendar$bars_per_year")
  if (!isTRUE(all.equal(actual, expected, tolerance = 1e-12))) {
    rlang::abort("`calendar$bars_per_year` must equal trading_days_per_year * bars_per_day.", class = "ledgr_invalid_args")
  }
  ledgr_validate_optional_character_scalar(x$label, "calendar$label")
  ledgr_validate_character_scalar(x$source, "calendar$source")
  invisible(TRUE)
}

ledgr_validate_risk_free_rate_object <- function(x) {
  if (!inherits(x, "ledgr_risk_free_rate")) {
    rlang::abort("`risk_free_rate` must be a scalar annual rate or a ledgr_risk_free_rate object.", class = "ledgr_invalid_args")
  }
  ledgr_validate_annual_rate(x$annual_rate, "risk_free_rate$annual_rate")
  ledgr_validate_optional_character_scalar(x$label, "risk_free_rate$label")
  ledgr_validate_character_scalar(x$source, "risk_free_rate$source")
  ledgr_normalize_optional_date(x$as_of, "risk_free_rate$as_of")
  invisible(TRUE)
}

ledgr_normalize_risk_free_rate <- function(x) {
  if (inherits(x, "ledgr_risk_free_rate")) {
    ledgr_validate_risk_free_rate_object(x)
    return(x)
  }
  ledgr_risk_free_rate(x)
}

ledgr_validate_reserved_metric_provider <- function(x, arg) {
  if (!is.null(x)) {
    rlang::abort(
      sprintf("`%s` is reserved for a future metric provider and must be NULL in v0.1.8.2.", arg),
      class = "ledgr_invalid_args"
    )
  }
  invisible(TRUE)
}

ledgr_metric_context_payload <- function(context) {
  ledgr_validate_metric_context_object(context)
  out <- list(
    metric_context_version = as.integer(context$metric_context_version),
    risk_free_rate = ledgr_risk_free_rate_payload(context$risk_free_rate),
    calendar = ledgr_calendar_payload(context$calendar)
  )
  for (field in c("benchmark", "market_factor", "mar")) {
    value <- context[[field]]
    if (!is.null(value)) out[[field]] <- value
  }
  out
}

ledgr_risk_free_rate_payload <- function(x) {
  ledgr_validate_risk_free_rate_object(x)
  out <- list(
    annual_rate = x$annual_rate,
    source = x$source
  )
  if (!is.null(x$as_of)) out$as_of <- format(x$as_of, "%Y-%m-%d")
  out
}

ledgr_calendar_payload <- function(x) {
  ledgr_validate_calendar_object(x)
  out <- list(
    trading_days_per_year = x$trading_days_per_year,
    bars_per_day = x$bars_per_day,
    bars_per_year = x$bars_per_year,
    source = x$source
  )
  out
}

ledgr_calendar_bars_per_year <- function(calendar) {
  ledgr_validate_calendar_object(calendar)
  calendar$bars_per_year
}

ledgr_metric_context_bars_per_year <- function(context) {
  context <- ledgr_metric_context_resolve(context)
  ledgr_calendar_bars_per_year(context$calendar)
}

ledgr_metric_context_annual_risk_free_rate <- function(context) {
  context <- ledgr_metric_context_resolve(context)
  context$risk_free_rate$annual_rate
}

ledgr_calendar_warn_if_inconsistent <- function(calendar,
                                                observed_bars,
                                                context = "metric context",
                                                tolerance = 1.2) {
  ledgr_validate_calendar_object(calendar)
  observed_bars <- ledgr_validate_positive_scalar(observed_bars, "observed_bars")
  tolerance <- ledgr_validate_positive_scalar(tolerance, "tolerance")
  if (observed_bars > calendar$bars_per_year * tolerance) {
    warning(
      sprintf(
        "The supplied %s calendar has bars_per_year=%s, but the observed data has %s bars. The calendar may not match the data frequency; for intraday US equity data use ledgr_calendar_us_equity(bars_per_day = ...).",
        context,
        ledgr_format_number(calendar$bars_per_year),
        ledgr_format_number(observed_bars)
      ),
      call. = FALSE
    )
  }
  invisible(calendar)
}

ledgr_validate_annual_rate <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= -1) {
    rlang::abort(
      sprintf("`%s` must be a finite scalar annual rate greater than -1.", arg),
      class = "ledgr_invalid_args"
    )
  }
  as.numeric(x)
}

ledgr_validate_positive_scalar <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0) {
    rlang::abort(
      sprintf("`%s` must be a finite positive numeric scalar.", arg),
      class = "ledgr_invalid_args"
    )
  }
  as.numeric(x)
}

ledgr_validate_character_scalar <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    rlang::abort(
      sprintf("`%s` must be a non-empty character scalar.", arg),
      class = "ledgr_invalid_args"
    )
  }
  x
}

ledgr_validate_optional_character_scalar <- function(x, arg) {
  if (is.null(x)) return(NULL)
  ledgr_validate_character_scalar(x, arg)
}

ledgr_normalize_optional_date <- function(x, arg) {
  if (is.null(x)) return(NULL)
  out <- tryCatch(
    as.Date(x),
    error = function(e) NA
  )
  if (length(out) != 1L || is.na(out)) {
    rlang::abort(
      sprintf("`%s` must be NULL or coercible to a single Date.", arg),
      class = "ledgr_invalid_args"
    )
  }
  out
}

ledgr_format_number <- function(x) {
  if (isTRUE(all.equal(x, round(x), tolerance = 1e-12))) {
    return(format(as.integer(round(x)), big.mark = ",", scientific = FALSE))
  }
  format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
}

ledgr_metric_format_percent <- function(x) {
  sprintf("%.4f%%", x * 100)
}

ledgr_calendar_display <- function(calendar) {
  ledgr_validate_calendar_object(calendar)
  label <- calendar$label
  if (is.null(label)) label <- calendar$source
  sprintf(
    "%s (%s days/year * %s bars/day = %s bars/year)",
    label,
    ledgr_format_number(calendar$trading_days_per_year),
    ledgr_format_number(calendar$bars_per_day),
    ledgr_format_number(calendar$bars_per_year)
  )
}
