#' Declare when a strategy should make decisions
#'
#' A strategy schedule is a declarative calendar rule. It is compiled once,
#' before execution, against the snapshot's authoritative open-session axis.
#' The decorated strategy remains an ordinary `function(ctx, params)`; the
#' schedule does not wrap or call it.
#'
#' @param strategy A strategy function with signature `function(ctx, params)`.
#' @param schedule A schedule made by one of the `ledgr_schedule_*()` helpers.
#' @return `strategy`, with class `ledgr_scheduled_strategy` and a declarative
#'   `ledgr_schedule` attribute.
#' @export
ledgr_strategy_schedule <- function(strategy, schedule) {
  if (!is.function(strategy)) {
    ledgr_schedule_abort("`strategy` must be a function.")
  }
  if (!is.null(attr(strategy, "ledgr_schedule", exact = TRUE))) {
    ledgr_schedule_abort("A strategy may declare only one schedule.")
  }
  schedule <- ledgr_schedule_validate(schedule)
  attr(strategy, "ledgr_schedule") <- unclass(schedule)
  class(strategy) <- unique(c("ledgr_scheduled_strategy", class(strategy)))
  strategy
}

#' @rdname ledgr_strategy_schedule
#' @export
ledgr_schedule_month_start <- function() ledgr_schedule_rule("month_start")

#' @rdname ledgr_strategy_schedule
#' @export
ledgr_schedule_month_end <- function() ledgr_schedule_rule("month_end")

#' @rdname ledgr_strategy_schedule
#' @export
ledgr_schedule_week_start <- function() ledgr_schedule_rule("week_start")

#' @rdname ledgr_strategy_schedule
#' @export
ledgr_schedule_quarter_start <- function() ledgr_schedule_rule("quarter_start")

#' @rdname ledgr_strategy_schedule
#' @export
ledgr_schedule_year_start <- function() ledgr_schedule_rule("year_start")

#' @param dates Civil dates. Each date is snapped forward to the next open
#'   venue session; duplicates after snapping are removed.
#' @rdname ledgr_strategy_schedule
#' @export
ledgr_schedule_dates <- function(dates) {
  if (!inherits(dates, "Date") || inherits(dates, "POSIXt") ||
      length(dates) < 1L || anyNA(dates)) {
    ledgr_schedule_abort("`dates` must be a non-empty Date vector without missing values.")
  }
  ledgr_schedule_rule("dates", list(dates = sort(unique(format(dates, "%Y-%m-%d")))))
}

#' @param name Name of a scalar character strategy parameter resolving to one
#'   of the fixed schedule names.
#' @rdname ledgr_strategy_schedule
#' @export
ledgr_schedule_from_param <- function(name) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) {
    ledgr_schedule_abort("`name` must be a non-empty character scalar.")
  }
  ledgr_schedule_rule("param", list(name = name))
}

ledgr_schedule_version <- 1L

ledgr_schedule_fixed_types <- c(
  "month_start", "month_end", "week_start", "quarter_start", "year_start"
)

ledgr_schedule_abort <- function(message, child = NULL) {
  classes <- c(child, "ledgr_invalid_strategy_schedule")
  rlang::abort(message, class = classes[!is.na(classes) & nzchar(classes)])
}

ledgr_schedule_rule <- function(type_id, args = list()) {
  structure(
    list(type_id = type_id, version = ledgr_schedule_version, args = args),
    class = c("ledgr_strategy_schedule_rule", "list")
  )
}

ledgr_schedule_validate <- function(schedule) {
  if (!is.list(schedule) || is.data.frame(schedule)) {
    ledgr_schedule_abort("`schedule` must be made by a `ledgr_schedule_*()` helper.")
  }
  if (!identical(names(schedule), c("type_id", "version", "args"))) {
    ledgr_schedule_abort("`schedule` must contain exactly `type_id`, `version` and `args`.")
  }
  type_id <- schedule$type_id
  version <- schedule$version
  args <- schedule$args
  if (!is.character(type_id) || length(type_id) != 1L || is.na(type_id) ||
      !type_id %in% c(ledgr_schedule_fixed_types, "dates", "param") ||
      !is.numeric(version) || length(version) != 1L || is.na(version) ||
      !is.finite(version) || version != floor(version) ||
      as.integer(version) != ledgr_schedule_version || !is.list(args)) {
    ledgr_schedule_abort("`schedule` is not a supported schedule declaration.")
  }
  if (type_id %in% ledgr_schedule_fixed_types && length(args) != 0L) {
    ledgr_schedule_abort("A fixed schedule declaration must not contain arguments.")
  }
  if (identical(type_id, "dates")) {
    dates_are_text <- identical(names(args), "dates") &&
      is.character(args$dates) && length(args$dates) >= 1L &&
      !anyNA(args$dates) && all(nzchar(args$dates))
    parsed_dates <- if (dates_are_text) {
      suppressWarnings(as.Date(args$dates, format = "%Y-%m-%d"))
    } else {
      as.Date(character())
    }
    dates_are_canonical <- dates_are_text &&
      all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", args$dates)) &&
      !anyNA(parsed_dates) &&
      identical(format(parsed_dates, "%Y-%m-%d"), args$dates)
    if (!dates_are_canonical) {
      ledgr_schedule_abort("A dates schedule must contain canonical civil dates.")
    }
    args$dates <- sort(unique(format(parsed_dates, "%Y-%m-%d")))
  }
  if (identical(type_id, "param") &&
      (!identical(names(args), "name") || !is.character(args$name) ||
       length(args$name) != 1L || is.na(args$name) || !nzchar(args$name))) {
    ledgr_schedule_abort("A parameter schedule must name one strategy parameter.")
  }
  ledgr_schedule_rule(type_id, args)
}

ledgr_strategy_schedule_declaration <- function(strategy) {
  declaration <- attr(strategy, "ledgr_schedule", exact = TRUE)
  if (is.null(declaration)) NULL else unclass(ledgr_schedule_validate(declaration))
}

ledgr_strategy_schedule_hash <- function(declaration) {
  if (is.null(declaration)) return(NULL)
  declaration <- unclass(ledgr_schedule_validate(declaration))
  digest::digest(canonical_json(declaration), algo = "sha256")
}

ledgr_strategy_schedule_inner <- function(strategy) {
  if (!is.function(strategy)) return(strategy)
  if (is.null(attr(strategy, "ledgr_schedule", exact = TRUE)) &&
      !inherits(strategy, "ledgr_scheduled_strategy")) {
    return(strategy)
  }
  attr(strategy, "ledgr_schedule") <- NULL
  remaining_class <- setdiff(class(strategy), "ledgr_scheduled_strategy")
  if (identical(remaining_class, "function")) {
    attr(strategy, "class") <- NULL
  } else {
    class(strategy) <- remaining_class
  }
  strategy
}

ledgr_schedule_period_key <- function(dates, type_id) {
  if (identical(type_id, "week_start")) {
    return((as.integer(dates) - 4L) %/% 7L)
  }
  if (identical(type_id, "month_start") || identical(type_id, "month_end")) {
    return(format(dates, "%Y-%m"))
  }
  if (identical(type_id, "quarter_start")) {
    month <- as.integer(format(dates, "%m"))
    return(paste0(format(dates, "%Y"), "-Q", ((month - 1L) %/% 3L) + 1L))
  }
  if (identical(type_id, "year_start")) return(format(dates, "%Y"))
  ledgr_schedule_abort("The resolved schedule type is unsupported.")
}

ledgr_schedule_resolve_type <- function(declaration, strategy_params) {
  if (!identical(declaration$type_id, "param")) return(declaration$type_id)
  if (!is.list(strategy_params) || is.data.frame(strategy_params)) {
    ledgr_schedule_abort(
      "A parameterized schedule requires resolved strategy parameters.",
      "ledgr_schedule_param_unresolved"
    )
  }
  value <- strategy_params[[declaration$args$name]]
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !value %in% ledgr_schedule_fixed_types) {
    ledgr_schedule_abort(
      sprintf("Strategy parameter `%s` must resolve to one supported fixed schedule.", declaration$args$name),
      "ledgr_schedule_param_unresolved"
    )
  }
  value
}

ledgr_compile_strategy_schedule <- function(declaration,
                                            strategy_params,
                                            sessions,
                                            pulses_posix) {
  if (is.null(declaration)) {
    return(list(
      decision_due = NULL,
      decision_pulse_count = length(pulses_posix),
      scheduled_skip_count = 0L
    ))
  }
  declaration <- ledgr_schedule_validate(declaration)
  if (is.null(sessions)) {
    ledgr_schedule_abort(
      "A strategy schedule requires a declared venue-session axis.",
      "ledgr_schedule_sessions_required"
    )
  }
  required <- c("session_date", "status", "session_close")
  if (!is.data.frame(sessions) || !all(required %in% names(sessions))) {
    ledgr_schedule_abort("The venue-session axis is malformed.", "ledgr_schedule_axis_invalid")
  }
  if (!inherits(sessions$session_date, "Date") || inherits(sessions$session_date, "POSIXt") ||
      !is.character(sessions$status) || !inherits(sessions$session_close, "POSIXt") ||
      anyNA(sessions$session_date) || anyNA(sessions$status)) {
    ledgr_schedule_abort("The venue-session axis is malformed.", "ledgr_schedule_axis_invalid")
  }
  if (anyDuplicated(sessions$session_date)) {
    ledgr_schedule_abort("The venue-session axis contains duplicate session dates.", "ledgr_schedule_axis_invalid")
  }
  open <- sessions[sessions$status == "open", required, drop = FALSE]
  open$session_date <- as.Date(open$session_date)
  open$session_close <- as.POSIXct(open$session_close, tz = "UTC")
  if (nrow(open) < 1L || anyNA(open) || anyDuplicated(open$session_date) ||
      anyDuplicated(as.numeric(open$session_close))) {
    ledgr_schedule_abort("The open-session axis must be unique and complete.", "ledgr_schedule_axis_invalid")
  }
  open <- open[order(open$session_close, method = "radix"), , drop = FALSE]
  if (is.unsorted(open$session_date, strictly = TRUE)) {
    ledgr_schedule_abort("Session dates and closes must have the same strict order.", "ledgr_schedule_axis_invalid")
  }
  if (!inherits(pulses_posix, "POSIXt")) {
    ledgr_schedule_abort("Executable pulses must be timestamps.", "ledgr_schedule_axis_invalid")
  }
  pulses <- as.POSIXct(pulses_posix, tz = "UTC")
  if (anyDuplicated(as.numeric(pulses))) {
    ledgr_schedule_abort("Schedules currently support one pulse per session.", "ledgr_schedule_intraday_unsupported")
  }
  if (anyNA(pulses) || is.unsorted(pulses, strictly = TRUE)) {
    ledgr_schedule_abort("Executable pulses must be unique and increasing.", "ledgr_schedule_axis_invalid")
  }
  pulse_num <- as.numeric(pulses)
  close_num <- as.numeric(open$session_close)
  pulse_index <- match(pulse_num, close_num)
  # Classify multiple distinct timestamps that fall before the same session
  # close as intraday before enforcing today's exact-close pulse contract.
  pulse_session <- findInterval(pulse_num, close_num)
  pulse_session[is.na(pulse_index)] <- pulse_session[is.na(pulse_index)] + 1L
  pulse_session_valid <- pulse_session >= 1L & pulse_session <= length(close_num)
  if (anyDuplicated(pulse_session[pulse_session_valid])) {
    ledgr_schedule_abort("Schedules currently support one pulse per session.", "ledgr_schedule_intraday_unsupported")
  }
  if (anyNA(pulse_index)) {
    ledgr_schedule_abort("Every executable pulse must match one open session close.", "ledgr_schedule_axis_invalid")
  }

  type_id <- ledgr_schedule_resolve_type(declaration, strategy_params)
  due_parent <- rep(FALSE, nrow(open))
  if (identical(type_id, "dates")) {
    requested <- as.Date(declaration$args$dates)
    if (any(requested < min(open$session_date)) || any(requested > max(open$session_date))) {
      ledgr_schedule_abort(
        "Every scheduled date must fall within the closed parent session range.",
        "ledgr_schedule_date_out_of_range"
      )
    }
    requested_num <- as.numeric(requested)
    open_num <- as.numeric(open$session_date)
    snapped <- findInterval(requested_num, open_num)
    exact <- snapped > 0L & open_num[pmax.int(snapped, 1L)] == requested_num
    snapped[!exact] <- snapped[!exact] + 1L
    due_parent[unique(snapped)] <- TRUE
  } else {
    period <- ledgr_schedule_period_key(open$session_date, type_id)
    if (grepl("_start$", type_id)) {
      due_parent[-1L] <- period[-1L] != period[-length(period)]
    } else {
      due_parent[-length(period)] <- period[-length(period)] != period[-1L]
    }
  }
  decision_due <- unname(due_parent[pulse_index])
  list(
    decision_due = decision_due,
    decision_pulse_count = as.integer(sum(decision_due)),
    scheduled_skip_count = as.integer(length(decision_due) - sum(decision_due)),
    resolved_schedule = unclass(ledgr_schedule_rule(type_id, if (identical(type_id, "dates")) declaration$args else list()))
  )
}
