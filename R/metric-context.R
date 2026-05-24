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
  ledgr_check_empty_dots(list(...), "ledgr_metric_context() accessor")
  ledgr_validate_metric_context_object(x)
  x
}

#' @export
ledgr_metric_context.ledgr_experiment <- function(x, ...) {
  ledgr_check_empty_dots(list(...), "ledgr_metric_context() accessor")
  if (!is.null(x$metric_context)) {
    return(ledgr_metric_context_resolve(x$metric_context))
  }
  ledgr_metric_context_resolve(NULL)
}

#' @export
ledgr_metric_context.ledgr_backtest <- function(x, ...) {
  ledgr_check_empty_dots(list(...), "ledgr_metric_context() accessor")
  ledgr_backtest_metric_context(x)
}

#' @export
ledgr_metric_context.ledgr_metrics <- function(x, ...) {
  ledgr_check_empty_dots(list(...), "ledgr_metric_context() accessor")
  context <- attr(x, "metric_context", exact = TRUE)
  if (inherits(context, "ledgr_metric_context")) {
    return(context)
  }
  rlang::abort(
    "`x` does not carry a ledgr metric context.",
    class = c("ledgr_missing_metric_context", "ledgr_invalid_args")
  )
}

#' @export
ledgr_metric_context.default <- function(x, ...) {
  ledgr_check_empty_dots(list(...), "ledgr_metric_context() accessor")
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
  ledgr_metric_context_hash_from_context(context)
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

ledgr_metric_kernel <- function(context = NULL,
                                pulses = NULL,
                                bars_per_year = NULL) {
  if (is.null(context) && !is.null(bars_per_year)) {
    bars_per_year <- ledgr_validate_positive_scalar(bars_per_year, "bars_per_year")
    # Legacy fallback preserves the annualization product only; the
    # trading_days_per_year/bars_per_day decomposition is synthetic.
    context <- ledgr_new_metric_context(
      calendar = ledgr_calendar(
        trading_days_per_year = bars_per_year,
        bars_per_day = 1,
        label = "legacy inferred cadence",
        source = "legacy_inference"
      )
    )
  } else if (is.null(context) && !is.null(pulses)) {
    inferred <- ledgr_bars_per_year_from_pulses(as.POSIXct(pulses, tz = "UTC"))
    # Legacy fallback preserves the annualization product only; the
    # trading_days_per_year/bars_per_day decomposition is synthetic.
    context <- ledgr_new_metric_context(
      calendar = ledgr_calendar(
        trading_days_per_year = inferred,
        bars_per_day = 1,
        label = "legacy inferred cadence",
        source = "legacy_inference"
      )
    )
  } else {
    context <- ledgr_metric_context_resolve(context)
  }

  bars_per_year <- ledgr_metric_context_bars_per_year(context)
  rf_period_return <- ledgr_metric_context_rf_period_return(context, bars_per_year)

  list(
    metric_context = ledgr_metric_context_record(context),
    metric_context_hash = ledgr_metric_context_hash(context),
    metric_context_version = as.integer(context$metric_context_version),
    bars_per_year = bars_per_year,
    rf_period_return = rf_period_return,
    calendar = ledgr_calendar_record(context$calendar)
  )
}

ledgr_metric_context_rf_period_return <- function(context, bars_per_year = NULL) {
  context <- ledgr_metric_context_resolve(context)
  if (is.null(bars_per_year)) {
    bars_per_year <- ledgr_metric_context_bars_per_year(context)
  }
  compute_rf_period_return(
    context$risk_free_rate$annual_rate,
    bars_per_year = bars_per_year
  )
}

ledgr_metric_context_hash_from_context <- function(context) {
  digest::digest(canonical_json(ledgr_metric_context_payload(context)), algo = "sha256")
}

ledgr_metric_context_json <- function(context) {
  context <- ledgr_metric_context_resolve(context)
  unname(canonical_json(ledgr_metric_context_record(context)))
}

ledgr_metric_context_storage <- function(context) {
  context <- ledgr_metric_context_resolve(context)
  list(
    json = ledgr_metric_context_json(context),
    hash = ledgr_metric_context_hash_from_context(context),
    version = as.integer(context$metric_context_version)
  )
}

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

# Hash payloads intentionally omit human display labels; storage records keep
# them so labels remain inspectable without changing metric-context identity.
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

ledgr_metric_context_record <- function(context) {
  ledgr_validate_metric_context_object(context)
  out <- list(
    metric_context_version = as.integer(context$metric_context_version),
    risk_free_rate = ledgr_risk_free_rate_record(context$risk_free_rate),
    calendar = ledgr_calendar_record(context$calendar)
  )
  for (field in c("benchmark", "market_factor", "mar")) {
    value <- context[[field]]
    if (!is.null(value)) out[[field]] <- value
  }
  out
}

ledgr_metric_context_from_json <- function(json) {
  if (!is.character(json) || length(json) != 1L || is.na(json) || !nzchar(json)) {
    return(ledgr_metric_context_resolve(NULL))
  }
  payload <- tryCatch(
    jsonlite::fromJSON(json, simplifyVector = FALSE),
    error = function(e) {
      rlang::abort("Stored metric_context_json is not valid JSON.", class = "ledgr_invalid_metric_context", parent = e)
    }
  )
  ledgr_metric_context_from_record(payload)
}

ledgr_metric_context_from_record <- function(payload) {
  if (!is.list(payload)) {
    rlang::abort("Stored metric context must be a JSON object.", class = "ledgr_invalid_metric_context")
  }
  version <- suppressWarnings(as.integer(payload$metric_context_version))
  if (!identical(version, ledgr_metric_context_version())) {
    rlang::abort("Unsupported stored metric_context_version.", class = "ledgr_invalid_metric_context")
  }
  # benchmark, market_factor, and mar must be NULL in metric_context_version 1L;
  # extend reconstruction when external-provider RFCs make these fields real.
  ledgr_new_metric_context(
    risk_free_rate = ledgr_risk_free_rate_from_record(payload$risk_free_rate),
    calendar = ledgr_calendar_from_record(payload$calendar),
    benchmark = NULL,
    market_factor = NULL,
    mar = NULL
  )
}

ledgr_metric_context_from_kernel <- function(kernel) {
  if (!is.list(kernel) || !is.list(kernel$metric_context)) {
    rlang::abort("`metric_kernel` must contain a metric_context record.", class = "ledgr_invalid_metric_context")
  }
  ledgr_metric_context_from_record(kernel$metric_context)
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

ledgr_risk_free_rate_record <- function(x) {
  ledgr_validate_risk_free_rate_object(x)
  out <- ledgr_risk_free_rate_payload(x)
  if (!is.null(x$label)) out$label <- x$label
  out
}

ledgr_risk_free_rate_from_record <- function(x) {
  if (!is.list(x)) {
    rlang::abort("Stored risk_free_rate must be a JSON object.", class = "ledgr_invalid_metric_context")
  }
  ledgr_risk_free_rate(
    annual_rate = x$annual_rate,
    label = if (is.null(x$label)) NULL else x$label,
    source = if (is.null(x$source)) "manual" else x$source,
    as_of = if (is.null(x$as_of)) NULL else x$as_of
  )
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

ledgr_calendar_record <- function(x) {
  ledgr_validate_calendar_object(x)
  out <- ledgr_calendar_payload(x)
  if (!is.null(x$label)) out$label <- x$label
  out
}

ledgr_calendar_from_record <- function(x) {
  if (!is.list(x)) {
    rlang::abort("Stored calendar must be a JSON object.", class = "ledgr_invalid_metric_context")
  }
  ledgr_calendar(
    trading_days_per_year = x$trading_days_per_year,
    bars_per_day = x$bars_per_day,
    label = if (is.null(x$label)) NULL else x$label,
    source = if (is.null(x$source)) "custom" else x$source
  )
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

ledgr_backtest_metric_context <- function(bt) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_args")
  }
  opened <- ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  ledgr_run_metric_context_from_db(opened$con, bt$run_id)
}

ledgr_run_metric_context_from_db <- function(con, run_id) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_args")
  }
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  cols <- DBI::dbGetQuery(
    con,
    "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'main'
      AND table_name = 'runs'
    "
  )$column_name
  if (!("metric_context_json" %in% cols)) {
    return(ledgr_metric_context_resolve(NULL))
  }
  row <- DBI::dbGetQuery(
    con,
    "SELECT metric_context_json, metric_context_hash, metric_context_version FROM runs WHERE run_id = ?",
    params = list(run_id)
  )
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Run not found: %s", run_id), class = "ledgr_run_not_found")
  }
  json <- row$metric_context_json[[1]]
  if (is.null(json) || is.na(json) || !nzchar(json)) {
    return(ledgr_metric_context_resolve(NULL))
  }
  context <- ledgr_metric_context_from_json(json)
  stored_version <- suppressWarnings(as.integer(row$metric_context_version[[1]]))
  if (!is.na(stored_version) && !identical(stored_version, as.integer(context$metric_context_version))) {
    rlang::abort("Stored metric_context_version does not match metric_context_json.", class = "ledgr_invalid_metric_context")
  }
  stored_hash <- row$metric_context_hash[[1]]
  if (is.character(stored_hash) && length(stored_hash) == 1L && !is.na(stored_hash) && nzchar(stored_hash) &&
    !identical(stored_hash, ledgr_metric_context_hash(context))) {
    rlang::abort("Stored metric_context_hash does not match metric_context_json.", class = "ledgr_invalid_metric_context")
  }
  context
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

ledgr_check_empty_dots <- function(dots, context) {
  if (length(dots) > 0L) {
    rlang::abort(
      sprintf("%s does not accept additional arguments.", context),
      class = "ledgr_invalid_args"
    )
  }
  invisible(TRUE)
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

ledgr_metric_summary_risk_free_display <- function(context) {
  context <- ledgr_metric_context_resolve(context)
  label <- context$risk_free_rate$label
  suffix <- if (!is.null(label)) sprintf(" (%s)", label) else ""
  sprintf("%.2f%% annual%s", context$risk_free_rate$annual_rate * 100, suffix)
}

ledgr_metric_summary_annualization_display <- function(context) {
  context <- ledgr_metric_context_resolve(context)
  calendar <- context$calendar
  label <- calendar$label
  if (is.null(label)) label <- calendar$source
  sprintf("%s periods/year (%s)", ledgr_format_number(calendar$bars_per_year), label)
}
