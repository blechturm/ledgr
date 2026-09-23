ledgr_fact_schema_version <- 1L

#' Point-in-time availability facts
#'
#' These constructors normalize point-in-time membership, trading-status,
#' session-calendar, and lifetime evidence before snapshot creation. Effective
#' intervals are half-open: `effective_from` is included and `effective_to` is
#' excluded. Missing knowledge time remains audit-only unless
#' `knowledge = "assume_effective"` is declared.
#'
#' @param df A data frame containing one fact row per assertion. See Details.
#' @param universe_id A non-empty identifier for the membership universe.
#' @param complete Logical scalar or one value per input row. Complete
#'   membership snapshots establish omitted instruments as non-members;
#'   partial snapshots leave omission unknown. Values must agree within each
#'   dated snapshot group.
#' @param venue_id A non-empty venue identifier.
#' @param knowledge Either `"evidenced"` or `"assume_effective"`.
#' @param timezone An IANA timezone used to interpret session dates and times.
#' @param ... Fact-family objects returned by these constructors.
#'
#' @details
#' Membership intervals require `instrument_id`, `effective_from`, and
#' `member`; `effective_to` and `knowledge_time` are optional. Membership
#' snapshots require `effective_from` plus either row-wise `instrument_id` or
#' a `members` list-column. `character(0)` records an empty set without a dummy
#' instrument; the two input shapes cannot be mixed. An `NA` row-wise
#' `instrument_id` records an empty set header. Trading-status rows require
#' `instrument_id`, `effective_from`, `status`, and `source`. Status is one of
#' `active`, `halted`, or `quotation_only`; optional columns are
#' `effective_to`, `knowledge_time`, `precedence`, `fact_id`, `revision_id`,
#' and `supersedes_fact_id`. Lifetime rows require `instrument_id`,
#' `effective_from`, and `assertion`, where assertion is `known_active`,
#' `known_inactive`, or `unknown`.
#'
#' Session rows require `session_date`, `status`, `session_open`, and
#' `session_close`; `knowledge_time` is required under evidenced knowledge and
#' may be omitted only with `knowledge = "assume_effective"`. Every civil date
#' in the declared range appears exactly once. Open-session times may be
#' POSIXct timestamps or local `HH:MM:SS` strings; closed rows have missing open
#' and close times.
#'
#' @section Errors:
#' Structural input failures inherit from `ledgr_invalid_args`. The primary
#' classes are `ledgr_fact_invalid_shape`, `ledgr_fact_invalid_interval`,
#' `ledgr_fact_identity_conflict`, `ledgr_fact_structural_conflict`,
#' `ledgr_fact_invalid_supersession`, `ledgr_session_invalid`,
#' `ledgr_session_time_ambiguous`, and `ledgr_session_time_nonexistent`.
#'
#' @return A classed fact-family object, or a `ledgr_facts` bundle.
#' @section Articles:
#' Point-in-time universe workflow:
#' `vignette("survivorship-bias", package = "ledgr")`
#' `system.file("doc", "survivorship-bias.html", package = "ledgr")`
#' @examples
#' membership <- ledgr_facts_membership_snapshots(
#'   data.frame(
#'     effective_from = as.POSIXct("2020-01-02", tz = "UTC"),
#'     knowledge_time = as.POSIXct("2020-01-01", tz = "UTC"),
#'     instrument_id = "AAA"
#'   ),
#'   universe_id = "example"
#' )
#' facts <- ledgr_facts(membership)
#' facts
#' @name ledgr_facts
NULL

#' @rdname ledgr_facts
#' @export
ledgr_facts_membership_intervals <- function(df,
                                             universe_id,
                                             knowledge = c("evidenced", "assume_effective")) {
  knowledge <- match.arg(knowledge)
  universe_id <- ledgr_fact_scalar_id(universe_id, "universe_id")
  df <- ledgr_fact_data_frame(df, "membership intervals")
  ledgr_fact_require_columns(df, c("instrument_id", "effective_from", "member"), "membership intervals")
  instrument_id <- ledgr_fact_instrument_ids(df$instrument_id, allow_missing = FALSE)
  effective_from <- ledgr_fact_time(df$effective_from, "effective_from", allow_missing = FALSE)
  effective_to <- ledgr_fact_optional_time(df, "effective_to")
  ledgr_fact_validate_intervals(effective_from, effective_to, "membership intervals")
  member <- ledgr_fact_logical(df$member, "member")
  knowledge_time <- ledgr_fact_knowledge_time(df, effective_from, knowledge)
  source <- ledgr_fact_source(df)
  provenance_json <- ledgr_fact_provenance(df, source, knowledge)
  supplied_id <- ledgr_fact_optional_character(df, "fact_id")

  rows <- data.frame(
    fact_id = character(nrow(df)),
    instrument_id = instrument_id,
    universe_id = rep(universe_id, nrow(df)),
    set_id = rep(NA_character_, nrow(df)),
    effective_from = effective_from,
    effective_to = effective_to,
    knowledge_time = knowledge_time,
    member = member,
    provenance_json = provenance_json,
    source = source,
    stringsAsFactors = FALSE
  )
  rows$fact_id <- ledgr_fact_ids("membership", rows, supplied_id)
  rows <- ledgr_fact_deduplicate(rows, "membership")
  ledgr_fact_validate_membership_conflicts(rows)
  rows <- rows[order(rows$universe_id, rows$instrument_id, rows$effective_from, rows$fact_id), , drop = FALSE]
  rownames(rows) <- NULL

  ledgr_new_fact_family(
    "membership",
    universe_id,
    rows,
    headers = ledgr_empty_membership_sets(),
    metadata = c(
      list(shape = "intervals", universe_id = universe_id),
      ledgr_fact_knowledge_metadata(knowledge)
    )
  )
}

#' @rdname ledgr_facts
#' @export
ledgr_facts_membership_snapshots <- function(df,
                                             universe_id,
                                             complete = TRUE,
                                             knowledge = c("evidenced", "assume_effective")) {
  knowledge <- match.arg(knowledge)
  universe_id <- ledgr_fact_scalar_id(universe_id, "universe_id")
  df <- ledgr_fact_data_frame(df, "membership snapshots")
  if (!is.logical(complete) || !length(complete) %in% c(1L, nrow(df)) || anyNA(complete)) {
    rlang::abort(
      "`complete` must be TRUE/FALSE or one logical value per input row.",
      class = c("ledgr_fact_invalid_complete", "ledgr_invalid_args")
    )
  }
  complete <- rep(complete, length.out = nrow(df))
  normalized <- ledgr_membership_snapshot_input(df, complete)
  df <- normalized$df
  complete <- normalized$complete
  ledgr_fact_require_columns(df, c("instrument_id", "effective_from"), "membership snapshots")
  effective_from <- ledgr_fact_time(df$effective_from, "effective_from", allow_missing = FALSE)
  knowledge_time <- ledgr_fact_knowledge_time(df, effective_from, knowledge)
  instrument_id <- ledgr_fact_instrument_ids(df$instrument_id, allow_missing = TRUE)
  source <- ledgr_fact_source(df)
  provenance_json <- ledgr_fact_provenance(df, source, knowledge)
  supplied_set_id <- ledgr_fact_optional_character(df, "set_id")

  group_key <- paste(
    ledgr_fact_time_token(effective_from),
    ledgr_fact_time_token(knowledge_time),
    source,
    sep = "\r"
  )
  set_id <- supplied_set_id
  missing_set <- is.na(set_id) | !nzchar(set_id)
  if (any(missing_set)) {
    generated <- vapply(
      group_key[missing_set],
      function(key) paste0("set_", substr(digest::digest(key, algo = "sha256"), 1L, 24L)),
      character(1)
    )
    set_id[missing_set] <- generated
  }
  if (any(vapply(split(set_id, group_key), function(x) length(unique(x)) != 1L, logical(1)))) {
    rlang::abort(
      "Each membership snapshot group must resolve to exactly one `set_id`.",
      class = c("ledgr_fact_invalid_membership_set", "ledgr_invalid_args")
    )
  }
  if (any(vapply(split(complete, group_key), function(x) length(unique(x)) != 1L, logical(1)))) {
    rlang::abort(
      "Membership snapshot `complete` values must agree within each dated group.",
      class = c("ledgr_fact_invalid_complete", "ledgr_invalid_args")
    )
  }

  first <- !duplicated(group_key)
  headers <- data.frame(
    universe_id = rep(universe_id, sum(first)),
    set_id = set_id[first],
    effective_from = effective_from[first],
    knowledge_time = knowledge_time[first],
    complete = complete[first],
    provenance_json = provenance_json[first],
    source = source[first],
    stringsAsFactors = FALSE
  )
  if (anyDuplicated(paste(headers$universe_id, headers$set_id, sep = "\r"))) {
    rlang::abort(
      "Membership snapshot `set_id` values must be unique within a universe.",
      class = c("ledgr_fact_invalid_membership_set", "ledgr_invalid_args")
    )
  }
  rows_keep <- !is.na(instrument_id)
  rows <- data.frame(
    fact_id = character(sum(rows_keep)),
    instrument_id = instrument_id[rows_keep],
    universe_id = rep(universe_id, sum(rows_keep)),
    set_id = set_id[rows_keep],
    effective_from = effective_from[rows_keep],
    effective_to = as.POSIXct(rep(NA_real_, sum(rows_keep)), origin = "1970-01-01", tz = "UTC"),
    knowledge_time = knowledge_time[rows_keep],
    member = rep(TRUE, sum(rows_keep)),
    provenance_json = provenance_json[rows_keep],
    source = source[rows_keep],
    stringsAsFactors = FALSE
  )
  if (nrow(rows) > 0L) {
    rows$fact_id <- ledgr_fact_ids("membership", rows, rep(NA_character_, nrow(rows)))
    rows <- ledgr_fact_deduplicate(rows, "membership")
  }
  headers <- headers[order(headers$effective_from, headers$knowledge_time, headers$set_id, na.last = TRUE), , drop = FALSE]
  rows <- rows[order(rows$effective_from, rows$set_id, rows$instrument_id), , drop = FALSE]
  rownames(headers) <- NULL
  rownames(rows) <- NULL

  ledgr_new_fact_family(
    "membership",
    universe_id,
    rows,
    headers = headers,
    metadata = c(
      list(shape = "snapshots", universe_id = universe_id),
      ledgr_fact_knowledge_metadata(knowledge)
    )
  )
}

#' @rdname ledgr_facts
#' @export
ledgr_facts_trading_status <- function(df,
                                       knowledge = c("evidenced", "assume_effective")) {
  knowledge <- match.arg(knowledge)
  df <- ledgr_fact_data_frame(df, "trading status")
  ledgr_fact_require_columns(df, c("instrument_id", "effective_from", "status", "source"), "trading status")
  instrument_id <- ledgr_fact_instrument_ids(df$instrument_id, allow_missing = FALSE)
  effective_from <- ledgr_fact_time(df$effective_from, "effective_from", allow_missing = FALSE)
  effective_to <- ledgr_fact_optional_time(df, "effective_to")
  ledgr_fact_validate_intervals(effective_from, effective_to, "trading status")
  status <- tolower(as.character(df$status))
  allowed <- c("active", "halted", "quotation_only")
  if (anyNA(status) || any(!status %in% allowed)) {
    rlang::abort(
      sprintf("Trading `status` must be one of: %s.", paste(allowed, collapse = ", ")),
      class = c("ledgr_fact_invalid_status", "ledgr_invalid_args")
    )
  }
  source <- ledgr_fact_source(df, required = TRUE)
  precedence <- if ("precedence" %in% names(df)) suppressWarnings(as.integer(df$precedence)) else rep(0L, nrow(df))
  if (anyNA(precedence) || any(as.numeric(precedence) != suppressWarnings(as.numeric(df$precedence %||% precedence)))) {
    rlang::abort("Trading-status `precedence` must contain whole numbers.", class = c("ledgr_fact_invalid_precedence", "ledgr_invalid_args"))
  }
  knowledge_time <- ledgr_fact_knowledge_time(df, effective_from, knowledge)
  provenance_json <- ledgr_fact_provenance(df, source, knowledge)
  supplied_id <- ledgr_fact_optional_character(df, "fact_id")
  supplied_supersedes <- ledgr_fact_optional_character(df, "supersedes_fact_id")

  rows <- data.frame(
    fact_id = character(nrow(df)),
    instrument_id = instrument_id,
    effective_from = effective_from,
    effective_to = effective_to,
    knowledge_time = knowledge_time,
    status = status,
    source = source,
    precedence = precedence,
    revision_id = ledgr_fact_optional_character(df, "revision_id"),
    supersedes_fact_id = supplied_supersedes,
    provenance_json = provenance_json,
    stringsAsFactors = FALSE
  )
  rows$fact_id <- ledgr_fact_ids("trading_status", rows, supplied_id)
  for (i in which(!is.na(rows$supersedes_fact_id))) {
    target <- which(
      supplied_id == rows$supersedes_fact_id[[i]] &
        source == rows$source[[i]]
    )
    if (length(target) == 1L) rows$supersedes_fact_id[[i]] <- rows$fact_id[[target]]
  }
  rows <- ledgr_fact_deduplicate(rows, "trading_status")
  ledgr_fact_validate_status_supersession(rows)
  ledgr_fact_validate_source_conflicts(rows)
  rows <- rows[order(rows$instrument_id, rows$effective_from, -rows$precedence, rows$source, rows$fact_id), , drop = FALSE]
  rownames(rows) <- NULL

  ledgr_new_fact_family(
    "trading_status",
    "instrument",
    rows,
    metadata = ledgr_fact_knowledge_metadata(knowledge)
  )
}

#' @rdname ledgr_facts
#' @export
ledgr_facts_lifetime <- function(df,
                                 knowledge = c("evidenced", "assume_effective")) {
  knowledge <- match.arg(knowledge)
  df <- ledgr_fact_data_frame(df, "lifetime")
  ledgr_fact_require_columns(df, c("instrument_id", "effective_from", "assertion"), "lifetime")
  instrument_id <- ledgr_fact_instrument_ids(df$instrument_id, allow_missing = FALSE)
  effective_from <- ledgr_fact_time(df$effective_from, "effective_from", allow_missing = FALSE)
  effective_to <- ledgr_fact_optional_time(df, "effective_to")
  ledgr_fact_validate_intervals(effective_from, effective_to, "lifetime")
  assertion <- tolower(as.character(df$assertion))
  allowed <- c("known_active", "known_inactive", "unknown")
  if (anyNA(assertion) || any(!assertion %in% allowed)) {
    rlang::abort(
      sprintf("Lifetime `assertion` must be one of: %s.", paste(allowed, collapse = ", ")),
      class = c("ledgr_fact_invalid_lifetime", "ledgr_invalid_args")
    )
  }
  source <- ledgr_fact_source(df)
  knowledge_time <- ledgr_fact_knowledge_time(df, effective_from, knowledge)
  provenance_json <- ledgr_fact_provenance(df, source, knowledge)
  supplied_id <- ledgr_fact_optional_character(df, "fact_id")
  terminal_event <- ledgr_fact_optional_character(df, "terminal_event")

  rows <- data.frame(
    fact_id = character(nrow(df)),
    instrument_id = instrument_id,
    effective_from = effective_from,
    effective_to = effective_to,
    knowledge_time = knowledge_time,
    assertion = assertion,
    terminal_event = terminal_event,
    source = source,
    provenance_json = provenance_json,
    stringsAsFactors = FALSE
  )
  rows$fact_id <- ledgr_fact_ids("lifetime", rows, supplied_id)
  rows <- ledgr_fact_deduplicate(rows, "lifetime")
  ledgr_fact_validate_lifetime_conflicts(rows)
  rows <- rows[order(rows$instrument_id, rows$effective_from, rows$source, rows$fact_id), , drop = FALSE]
  rownames(rows) <- NULL

  ledgr_new_fact_family(
    "lifetime",
    "instrument",
    rows,
    metadata = ledgr_fact_knowledge_metadata(knowledge)
  )
}

#' @rdname ledgr_facts
#' @export
ledgr_facts_sessions <- function(df,
                                 venue_id,
                                 knowledge = c("evidenced", "assume_effective"),
                                 timezone = "UTC") {
  knowledge <- match.arg(knowledge)
  venue_id <- ledgr_fact_scalar_id(venue_id, "venue_id")
  timezone <- ledgr_fact_timezone(timezone)
  df <- ledgr_fact_data_frame(df, "sessions")
  ledgr_fact_require_columns(
    df,
    c("session_date", "status", "session_open", "session_close"),
    "sessions"
  )
  session_date <- ledgr_fact_dates(df$session_date)
  if (anyDuplicated(session_date)) {
    rlang::abort("Session calendar contains duplicate `session_date` values.", class = c("ledgr_session_invalid", "ledgr_invalid_args"))
  }
  expected_dates <- seq(min(session_date), max(session_date), by = "day")
  missing_dates <- setdiff(as.character(expected_dates), as.character(session_date))
  if (length(missing_dates) > 0L) {
    rlang::abort(
      sprintf("Session calendar is incomplete; missing civil date(s): %s.", paste(missing_dates, collapse = ", ")),
      class = c("ledgr_session_coverage_incomplete", "ledgr_session_invalid", "ledgr_invalid_args"),
      missing_dates = missing_dates
    )
  }
  status <- tolower(as.character(df$status))
  if (anyNA(status) || any(!status %in% c("open", "closed"))) {
    rlang::abort("Session `status` must be `open` or `closed`.", class = c("ledgr_session_invalid", "ledgr_invalid_args"))
  }
  session_open <- ledgr_session_times(df$session_open, session_date, timezone, "session_open")
  session_close <- ledgr_session_times(df$session_close, session_date, timezone, "session_close")
  is_open <- status == "open"
  if (any(is_open & (is.na(session_open) | is.na(session_close))) ||
      any(!is_open & (!is.na(session_open) | !is.na(session_close)))) {
    rlang::abort(
      "Open sessions require open/close times and closed sessions require both times to be missing.",
      class = c("ledgr_session_invalid", "ledgr_invalid_args")
    )
  }
  if (any(is_open & session_open >= session_close, na.rm = TRUE)) {
    rlang::abort("Every session open must precede its close.", class = c("ledgr_session_invalid", "ledgr_invalid_args"))
  }
  effective_from <- ledgr_session_times(
    rep("00:00:00", length(session_date)),
    session_date,
    timezone,
    "session_date boundary"
  )
  effective_to <- ledgr_session_times(
    rep("00:00:00", length(session_date)),
    session_date + 1,
    timezone,
    "next session_date boundary"
  )
  knowledge_time <- ledgr_fact_knowledge_time(df, effective_from, knowledge)
  late <- ifelse(is_open, knowledge_time > session_open, knowledge_time > effective_from)
  late[is.na(late)] <- TRUE
  if (any(late)) {
    rlang::abort(
      "Session knowledge is late: open sessions must be knowable by open and closures before the civil day starts.",
      class = c("ledgr_session_knowledge_late", "ledgr_session_invalid", "ledgr_invalid_args")
    )
  }
  source <- ledgr_fact_source(df)
  provenance_json <- ledgr_fact_provenance(df, source, knowledge)
  rows <- data.frame(
    venue_id = rep(venue_id, nrow(df)),
    session_date = session_date,
    effective_from = effective_from,
    effective_to = effective_to,
    knowledge_time = knowledge_time,
    status = status,
    session_open = session_open,
    session_close = session_close,
    provenance_json = provenance_json,
    source = source,
    stringsAsFactors = FALSE
  )
  rows <- rows[order(rows$session_date), , drop = FALSE]
  rownames(rows) <- NULL
  ledgr_new_fact_family(
    "sessions",
    venue_id,
    rows,
    metadata = c(list(
      venue_id = venue_id,
      timezone = timezone,
      coverage_start = as.character(min(session_date)),
      coverage_end = as.character(max(session_date))
    ), ledgr_fact_knowledge_metadata(knowledge))
  )
}

#' Build session facts from an explicit qlcal calendar
#'
#' Materializes an inclusive civil-date schedule from an explicit qlcal
#' calendar object, then delegates normalization and local-time validation to
#' [ledgr_facts_sessions()]. The qlcal object is never retained.
#'
#' @param calendar An explicit calendar object returned by
#'   `qlcal::getCalendar()`.
#' @param from,to Inclusive civil `Date` bounds.
#' @param venue_id A non-empty venue identifier.
#' @param timezone An IANA timezone for the declared session hours.
#' @param session_open,session_close Local `HH:MM:SS` times used on business
#'   days.
#' @param knowledge Either `"evidenced"` or `"assume_effective"`.
#' @param knowledge_time An optional full UTC instant applied to generated
#'   rows. It is required with evidenced knowledge.
#' @param overrides Optional complete replacement rows with `session_date`,
#'   `status`, `session_open`, and `session_close`.
#' @param provenance Optional named list recorded in hashed family metadata and
#'   row provenance. Evidenced schedules require a non-empty `source` member.
#'
#' @return A `ledgr_facts_sessions` fact-family object whose materialized rows
#'   no longer depend on qlcal.
#' @section Errors:
#' Missing qlcal raises `ledgr_missing_package`. Invalid calendar objects or
#' overrides raise `ledgr_session_adapter_invalid`.
#' @export
ledgr_facts_sessions_qlcal <- function(calendar,
                                       from,
                                       to,
                                       venue_id,
                                       timezone,
                                       session_open,
                                       session_close,
                                       knowledge = c("assume_effective", "evidenced"),
                                       knowledge_time = NULL,
                                       overrides = NULL,
                                       provenance = NULL) {
  knowledge <- match.arg(knowledge)
  if (!requireNamespace("qlcal", quietly = TRUE)) {
    rlang::abort(
      "Package `qlcal` is required; install it with install.packages(\"qlcal\").",
      class = c("ledgr_missing_package", "ledgr_session_adapter_invalid", "ledgr_invalid_args")
    )
  }
  if (is.character(calendar) || !inherits(calendar, "qlcalendar")) {
    rlang::abort(
      "`calendar` must be an explicit object returned by `qlcal::getCalendar()`.",
      class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
    )
  }
  from <- ledgr_fact_date_scalar(from, "from")
  to <- ledgr_fact_date_scalar(to, "to")
  if (to < from) {
    rlang::abort(
      "`to` must be on or after `from`.",
      class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
    )
  }
  venue_id <- ledgr_fact_scalar_id(venue_id, "venue_id")
  timezone <- ledgr_fact_timezone(timezone)
  session_open <- ledgr_session_hour(session_open, "session_open")
  session_close <- ledgr_session_hour(session_close, "session_close")
  provenance <- ledgr_session_adapter_provenance(provenance)
  source <- provenance$source %||% "qlcal"
  if (!is.character(source) || length(source) != 1L || is.na(source) || !nzchar(source)) {
    rlang::abort(
      "`provenance$source` must be one non-empty string when supplied.",
      class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
    )
  }
  if (identical(knowledge, "evidenced") &&
      (is.null(provenance$source) || !nzchar(provenance$source))) {
    rlang::abort(
      "Evidenced generated schedules require `provenance$source`.",
      class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
    )
  }
  if (is.null(knowledge_time)) {
    if (identical(knowledge, "evidenced")) {
      rlang::abort(
        "Evidenced generated schedules require `knowledge_time`.",
        class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
      )
    }
    knowledge_value <- NULL
  } else {
    knowledge_value <- ledgr_fact_time(knowledge_time, "knowledge_time", allow_missing = FALSE)
    if (length(knowledge_value) != 1L) {
      rlang::abort(
        "`knowledge_time` must be NULL or one full UTC instant.",
        class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
      )
    }
  }

  dates <- seq(from, to, by = "day")
  business <- tryCatch(
    qlcal::isBusinessDay(dates, xp = calendar),
    error = function(error) {
      rlang::abort(
        "`calendar` is not a usable qlcal calendar object.",
        class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args"),
        parent = error
      )
    }
  )
  rows <- data.frame(
    session_date = dates,
    status = ifelse(business, "open", "closed"),
    session_open = ifelse(business, session_open, NA_character_),
    session_close = ifelse(business, session_close, NA_character_),
    knowledge_time = as.POSIXct(
      rep(if (is.null(knowledge_value)) NA_real_ else as.numeric(knowledge_value), length(dates)),
      origin = "1970-01-01",
      tz = "UTC"
    ),
    source = rep(source, length(dates)),
    stringsAsFactors = FALSE
  )
  rows$provenance <- rep(list(provenance), length(dates))

  normalized_overrides <- ledgr_session_adapter_overrides(
    overrides,
    dates,
    knowledge_value,
    source,
    provenance
  )
  if (nrow(normalized_overrides) > 0L) {
    replace_at <- match(normalized_overrides$session_date, rows$session_date)
    for (field in intersect(names(rows), names(normalized_overrides))) {
      rows[[field]][replace_at] <- normalized_overrides[[field]]
    }
  }

  family <- ledgr_facts_sessions(
    rows,
    venue_id = venue_id,
    knowledge = knowledge,
    timezone = timezone
  )
  metadata <- c(family$metadata, list(
    schedule_basis = "generated",
    provider = "qlcal",
    provider_version = as.character(utils::packageVersion("qlcal")),
    calendar_id = as.character(qlcal::getId(xp = calendar)),
    calendar_name = as.character(qlcal::getName(xp = calendar)),
    adapter_normalization_version = 1L,
    declared_session_open = session_open,
    declared_session_close = session_close,
    overrides = ledgr_session_adapter_override_payload(normalized_overrides),
    provenance = provenance
  ))
  ledgr_new_fact_family(
    family$family,
    family$scope_id,
    family$rows,
    family$headers,
    metadata
  )
}

#' @rdname ledgr_facts
#' @export
ledgr_facts <- function(...) {
  families <- list(...)
  if (length(families) == 0L) {
    rlang::abort("`ledgr_facts()` requires at least one fact family.", class = c("ledgr_invalid_facts", "ledgr_invalid_args"))
  }
  valid <- vapply(families, inherits, logical(1), "ledgr_fact_family")
  if (!all(valid)) {
    rlang::abort("Every input to `ledgr_facts()` must be a ledgr fact-family object.", class = c("ledgr_invalid_facts", "ledgr_invalid_args"))
  }
  keys <- vapply(families, function(x) paste(x$family, x$scope_id, sep = ":"), character(1))
  if (anyDuplicated(keys)) {
    rlang::abort(
      sprintf("Fact family scopes must be unique: %s.", paste(unique(keys[duplicated(keys)]), collapse = ", ")),
      class = c("ledgr_duplicate_fact_family", "ledgr_invalid_facts", "ledgr_invalid_args")
    )
  }
  ord <- order(keys)
  families <- unname(families[ord])
  bundle_hash <- digest::digest(
    as.character(canonical_json(list(
      schema = "ledgr_facts_v1",
      family_hashes = vapply(families, `[[`, character(1), "fact_hash")
    ))),
    algo = "sha256"
  )
  structure(
    list(
      schema_version = ledgr_fact_schema_version,
      families = families,
      bundle_hash = bundle_hash
    ),
    class = c("ledgr_facts", "list")
  )
}

#' Validate point-in-time facts without writing
#'
#' Produces a source-aware dry-run report. Accepted rows, retained runtime
#' conflicts, rejected rows, quarantine candidates, and audit-only facts stay
#' distinct. This function never creates or modifies a snapshot.
#'
#' @param facts A `ledgr_facts` bundle.
#' @param bars_df Bars intended for [ledgr_snapshot_from_df()].
#' @param instruments_df Optional instrument master intended for the snapshot.
#' @param invalid_observations Either `"error"` or `"quarantine"`.
#' @return A `ledgr_facts_report` object with `summary`, `facts`, and
#'   `observations` tibbles plus a logical `can_seal` field.
#' @section Articles:
#' Point-in-time universe workflow:
#' `vignette("survivorship-bias", package = "ledgr")`
#' `system.file("doc", "survivorship-bias.html", package = "ledgr")`
#' @section Errors:
#' Invalid or mutated bundles raise `ledgr_invalid_facts`. Snapshot creation
#' raises `ledgr_availability_validation_failed` with this report attached when
#' accepted input cannot be sealed.
#' @examples
#' sessions <- data.frame(
#'   session_date = as.Date("2020-01-01") + 0:1,
#'   status = c("closed", "open"),
#'   session_open = c(NA, "09:30:00"),
#'   session_close = c(NA, "16:00:00"),
#'   knowledge_time = as.POSIXct("2019-12-31", tz = "UTC")
#' )
#' facts <- ledgr_facts(ledgr_facts_sessions(sessions, "example", timezone = "UTC"))
#' bars <- data.frame(
#'   instrument_id = "AAA",
#'   ts_utc = as.Date("2020-01-02"),
#'   open = 10, high = 11, low = 9, close = 10
#' )
#' ledgr_facts_validate(facts, bars)
#' @export
ledgr_facts_validate <- function(facts,
                                 bars_df,
                                 instruments_df = NULL,
                                 invalid_observations = c("error", "quarantine")) {
  invalid_observations <- match.arg(invalid_observations)
  facts <- ledgr_facts_assert(facts)
  report <- ledgr_availability_validate_inputs(facts, bars_df, instruments_df, invalid_observations)
  report$prepared_bars <- NULL
  report$prepared_instruments <- NULL
  report$quarantine_rows <- NULL
  structure(report, class = c("ledgr_facts_report", "list"))
}

#' @export
print.ledgr_fact_family <- function(x, ...) {
  cat("ledgr fact family\n")
  cat("Family: ", x$family, "\n", sep = "")
  cat("Scope:  ", x$scope_id, "\n", sep = "")
  cat("Rows:   ", nrow(x$rows), "\n", sep = "")
  if (identical(x$family, "membership") && nrow(x$headers) > 0L) {
    composition <- if (all(x$headers$complete)) {
      "complete replacement lists"
    } else if (!any(x$headers$complete)) {
      "partial assertions"
    } else {
      "mixed complete replacements and partial assertions"
    }
    cat("Sets:   ", composition, "\n", sep = "")
  }
  invisible(x)
}

#' @export
print.ledgr_facts <- function(x, ...) {
  x <- ledgr_facts_assert(x)
  cat("ledgr facts\n")
  cat("Families: ", length(x$families), "\n", sep = "")
  for (family in x$families) {
    cat("- ", family$family, " [", family$scope_id, "]: ", nrow(family$rows), " row(s)\n", sep = "")
  }
  invisible(x)
}

#' @export
print.ledgr_facts_report <- function(x, ...) {
  cat("ledgr facts validation\n")
  cat("Can seal: ", if (isTRUE(x$can_seal)) "yes" else "no", "\n", sep = "")
  print(x$summary)
  invisible(x)
}

ledgr_new_fact_family <- function(family, scope_id, rows, headers = NULL, metadata = list()) {
  fact_hash <- ledgr_fact_family_hash(family, scope_id, rows, headers, metadata)
  structure(
    list(
      schema_version = ledgr_fact_schema_version,
      family = family,
      scope_id = scope_id,
      metadata = metadata,
      rows = rows,
      headers = headers,
      fact_hash = fact_hash
    ),
    class = c(paste0("ledgr_facts_", family), "ledgr_fact_family", "list")
  )
}

ledgr_facts_assert <- function(x) {
  if (!inherits(x, "ledgr_facts") || !is.list(x) ||
      !identical(as.integer(x$schema_version), ledgr_fact_schema_version) ||
      !is.list(x$families) || length(x$families) == 0L ||
      !all(vapply(x$families, inherits, logical(1), "ledgr_fact_family"))) {
    rlang::abort("`facts` must be an untampered ledgr_facts object.", class = c("ledgr_invalid_facts", "ledgr_invalid_args"))
  }
  family_valid <- vapply(x$families, function(family) {
    is.character(family$fact_hash) && length(family$fact_hash) == 1L &&
      identical(
        family$fact_hash,
        ledgr_fact_family_hash(
          family$family,
          family$scope_id,
          family$rows,
          family$headers,
          family$metadata
        )
      )
  }, logical(1))
  expected_bundle <- digest::digest(
    as.character(canonical_json(list(
      schema = "ledgr_facts_v1",
      family_hashes = vapply(x$families, `[[`, character(1), "fact_hash")
    ))),
    algo = "sha256"
  )
  if (!all(family_valid) || !identical(x$bundle_hash, expected_bundle)) {
    rlang::abort("`facts` must be an untampered ledgr_facts object.", class = c("ledgr_invalid_facts", "ledgr_invalid_args"))
  }
  x
}

ledgr_fact_family_hash <- function(family, scope_id, rows, headers, metadata) {
  frame_payload <- function(df) {
    if (is.null(df) || nrow(df) == 0L) return(list())
    lapply(seq_len(nrow(df)), function(i) ledgr_fact_row_payload(df[i, , drop = FALSE]))
  }
  digest::digest(
    as.character(canonical_json(list(
      schema = "ledgr_fact_family_v1",
      family = family,
      scope_id = scope_id,
      metadata = metadata,
      headers = frame_payload(headers),
      rows = frame_payload(rows)
    ))),
    algo = "sha256"
  )
}

ledgr_fact_data_frame <- function(df, label) {
  if (!is.data.frame(df) || nrow(df) == 0L) {
    rlang::abort(sprintf("%s input must be a non-empty data frame.", label), class = c("ledgr_fact_invalid_shape", "ledgr_invalid_args"))
  }
  as.data.frame(df, stringsAsFactors = FALSE)
}

ledgr_fact_require_columns <- function(df, required, label) {
  missing <- setdiff(required, names(df))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("%s input is missing required column(s): %s.", label, paste(missing, collapse = ", ")),
      class = c("ledgr_fact_invalid_shape", "ledgr_invalid_args"),
      missing_columns = missing
    )
  }
  invisible(TRUE)
}

ledgr_fact_scalar_id <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    rlang::abort(sprintf("`%s` must be a non-empty character scalar.", arg), class = c("ledgr_fact_invalid_id", "ledgr_invalid_args"))
  }
  enc2utf8(as.character(x))
}

ledgr_fact_instrument_ids <- function(x, allow_missing) {
  out <- enc2utf8(as.character(x))
  missing <- is.na(x) | is.na(out) | !nzchar(trimws(out))
  if (!isTRUE(allow_missing) && any(missing)) {
    rlang::abort("Fact `instrument_id` values must be non-empty strings.", class = c("ledgr_fact_invalid_instrument", "ledgr_invalid_args"))
  }
  out[missing] <- NA_character_
  out
}

ledgr_fact_time <- function(x, field, allow_missing = TRUE) {
  if (inherits(x, "Date") && !inherits(x, "POSIXt")) {
    out <- as.POSIXct(x, tz = "UTC")
  } else if (inherits(x, "POSIXt")) {
    out <- as.POSIXct(x, tz = "UTC")
  } else {
    raw <- as.character(x)
    raw[raw == ""] <- NA_character_
    out <- as.POSIXct(raw, tz = "UTC", tryFormats = c(
      "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"
    ))
  }
  if (!isTRUE(allow_missing) && anyNA(out)) {
    rlang::abort(sprintf("Fact `%s` must contain valid timestamps.", field), class = c("ledgr_fact_invalid_time", "ledgr_invalid_args"))
  }
  if (any(!is.na(out))) {
    out[!is.na(out)] <- ledgr_assert_whole_second_utc(
      out[!is.na(out)],
      label = paste0("fact `", field, "`"),
      class = c("ledgr_fact_invalid_time", "ledgr_invalid_args")
    )
  }
  out
}

ledgr_fact_optional_time <- function(df, field) {
  if (!field %in% names(df)) {
    return(as.POSIXct(rep(NA_real_, nrow(df)), origin = "1970-01-01", tz = "UTC"))
  }
  ledgr_fact_time(df[[field]], field, allow_missing = TRUE)
}

ledgr_fact_knowledge_time <- function(df, effective_from, knowledge) {
  out <- ledgr_fact_optional_time(df, "knowledge_time")
  if (identical(knowledge, "assume_effective")) {
    out[is.na(out)] <- effective_from[is.na(out)]
  }
  out
}

ledgr_fact_knowledge_metadata <- function(knowledge) {
  out <- list(knowledge = knowledge)
  if (identical(knowledge, "assume_effective")) {
    out$knowledge_assumption <- "effective"
  }
  out
}

ledgr_fact_validate_intervals <- function(from, to, label) {
  bad <- !is.na(to) & to <= from
  if (any(bad)) {
    rlang::abort(
      sprintf("%s effective intervals must be half-open with `effective_to > effective_from`.", label),
      class = c("ledgr_fact_invalid_interval", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_fact_logical <- function(x, field) {
  if (!is.logical(x) || anyNA(x)) {
    rlang::abort(sprintf("Fact `%s` must contain TRUE or FALSE.", field), class = c("ledgr_fact_invalid_logical", "ledgr_invalid_args"))
  }
  as.logical(x)
}

ledgr_fact_source <- function(df, required = FALSE) {
  out <- if ("source" %in% names(df)) enc2utf8(as.character(df$source)) else rep("user", nrow(df))
  bad <- is.na(out) | !nzchar(trimws(out))
  if (any(bad) || (isTRUE(required) && !"source" %in% names(df))) {
    rlang::abort("Fact `source` must contain non-empty strings.", class = c("ledgr_fact_invalid_source", "ledgr_invalid_args"))
  }
  out
}

ledgr_fact_optional_character <- function(df, field) {
  if (!field %in% names(df)) return(rep(NA_character_, nrow(df)))
  out <- enc2utf8(as.character(df[[field]]))
  out[is.na(df[[field]]) | !nzchar(out)] <- NA_character_
  out
}

ledgr_fact_provenance <- function(df, source, knowledge) {
  if ("provenance_json" %in% names(df)) {
    out <- as.character(df$provenance_json)
    bad <- is.na(out) | !nzchar(out)
    out[bad] <- as.character(canonical_json(list()))
    out <- vapply(out, function(x) {
      parsed <- tryCatch(ledgr_json_read_nested(x), error = function(e) NULL)
      if (is.null(parsed)) {
        rlang::abort(
          "Fact `provenance_json` must contain valid JSON.",
          class = c("ledgr_fact_invalid_provenance", "ledgr_invalid_args")
        )
      }
      as.character(canonical_json(parsed))
    }, character(1))
  } else if ("provenance" %in% names(df) && is.list(df$provenance)) {
    out <- vapply(df$provenance, function(x) as.character(canonical_json(x %||% list())), character(1))
  } else {
    out <- rep(as.character(canonical_json(list())), nrow(df))
  }
  vapply(seq_along(out), function(i) {
    payload <- list(source = source[[i]], knowledge = knowledge, payload = ledgr_json_read_nested(out[[i]]))
    as.character(canonical_json(payload))
  }, character(1))
}

ledgr_fact_ids <- function(family, rows, supplied_id) {
  vapply(seq_len(nrow(rows)), function(i) {
    source_id <- supplied_id[[i]]
    payload <- if (!is.na(source_id) && nzchar(source_id)) {
      list(family = family, source = rows$source[[i]], source_id = source_id)
    } else {
      one <- rows[i, setdiff(names(rows), "fact_id"), drop = FALSE]
      list(family = family, assertion = ledgr_fact_row_payload(one))
    }
    paste0("fact_", substr(digest::digest(as.character(canonical_json(payload)), algo = "sha256"), 1L, 32L))
  }, character(1))
}

ledgr_fact_row_payload <- function(row) {
  out <- lapply(row, function(x) {
    value <- x[[1L]]
    if (inherits(value, "POSIXt")) return(ledgr_fact_time_token(value))
    if (inherits(value, "Date")) return(as.character(value))
    if (length(value) == 0L || is.na(value)) return(NULL)
    unname(value)
  })
  out
}

ledgr_fact_deduplicate <- function(rows, family) {
  payload <- vapply(seq_len(nrow(rows)), function(i) {
    as.character(canonical_json(ledgr_fact_row_payload(rows[i, , drop = FALSE])))
  }, character(1))
  by_id <- split(seq_len(nrow(rows)), rows$fact_id)
  incompatible <- names(by_id)[vapply(by_id, function(idx) length(unique(payload[idx])) > 1L, logical(1))]
  if (length(incompatible) > 0L) {
    rlang::abort(
      sprintf("%s contains incompatible payloads for the same canonical fact identity.", family),
      class = c("ledgr_fact_identity_conflict", "ledgr_invalid_args"),
      fact_ids = incompatible
    )
  }
  rows[!duplicated(rows$fact_id), , drop = FALSE]
}

ledgr_fact_time_token <- function(x) {
  out <- rep(NA_character_, length(x))
  keep <- !is.na(x)
  out[keep] <- format(as.POSIXct(x[keep], tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  out
}

ledgr_fact_timezone <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x) || !x %in% OlsonNames()) {
    rlang::abort("`timezone` must be one IANA timezone name.", class = c("ledgr_session_invalid_timezone", "ledgr_invalid_args"))
  }
  x
}

ledgr_fact_dates <- function(x) {
  raw <- as.character(x)
  out <- as.Date(raw, format = "%Y-%m-%d")
  if (anyNA(out) || any(format(out, "%Y-%m-%d") != raw)) {
    rlang::abort("`session_date` must contain valid ISO civil dates.", class = c("ledgr_session_invalid", "ledgr_invalid_args"))
  }
  out
}

ledgr_session_times <- function(x, session_date, timezone, field) {
  if (inherits(x, "POSIXt")) return(ledgr_fact_time(x, field, allow_missing = TRUE))
  raw <- as.character(x)
  raw[is.na(x) | !nzchar(raw)] <- NA_character_
  out <- as.POSIXct(rep(NA_character_, length(raw)), tz = timezone)
  keep <- !is.na(raw)
  if (any(keep)) {
    valid <- grepl("^([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$", raw[keep])
    if (!all(valid)) {
      rlang::abort(sprintf("`%s` must use HH:MM:SS local times.", field), class = c("ledgr_session_invalid", "ledgr_invalid_args"))
    }
    labels <- paste(session_date[keep], raw[keep])
    resolved <- lapply(labels, ledgr_local_time_resolve, timezone = timezone)
    counts <- vapply(resolved, length, integer(1))
    if (any(counts == 0L)) {
      rlang::abort(
        sprintf("`%s` contains a nonexistent local wall time.", field),
        class = c("ledgr_session_time_nonexistent", "ledgr_session_invalid", "ledgr_invalid_args")
      )
    }
    if (any(counts > 1L)) {
      rlang::abort(
        sprintf(
          "`%s` contains an ambiguous local wall time; supply an explicit POSIXct instant.",
          field
        ),
        class = c("ledgr_session_time_ambiguous", "ledgr_session_invalid", "ledgr_invalid_args")
      )
    }
    out[keep] <- as.POSIXct(
      vapply(resolved, function(value) as.numeric(value[[1L]]), numeric(1)),
      origin = "1970-01-01",
      tz = "UTC"
    )
  }
  as.POSIXct(out, tz = "UTC")
}

ledgr_local_time_resolve <- function(label, timezone) {
  wall <- as.POSIXct(label, tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
  probes <- wall + seq.int(-2L, 2L) * 86400
  offsets <- unique(format(probes, "%z", tz = timezone))
  offset_seconds <- vapply(offsets, ledgr_utc_offset_seconds, numeric(1))
  candidates <- as.POSIXct(
    as.numeric(wall) - offset_seconds,
    origin = "1970-01-01",
    tz = "UTC"
  )
  roundtrip <- format(candidates, "%Y-%m-%d %H:%M:%S", tz = timezone)
  unique(candidates[roundtrip == label])
}

ledgr_utc_offset_seconds <- function(x) {
  normalized <- gsub(":", "", x, fixed = TRUE)
  if (!grepl("^[+-][0-9]{4}$", normalized)) {
    rlang::abort(
      "Timezone offset could not be normalized.",
      class = c("ledgr_session_invalid_timezone", "ledgr_invalid_args")
    )
  }
  sign <- if (substr(normalized, 1L, 1L) == "-") -1 else 1
  hours <- as.integer(substr(normalized, 2L, 3L))
  minutes <- as.integer(substr(normalized, 4L, 5L))
  sign * (hours * 3600 + minutes * 60)
}

ledgr_membership_snapshot_input <- function(df, complete) {
  has_rows <- "instrument_id" %in% names(df)
  has_lists <- "members" %in% names(df)
  if (has_rows && has_lists) {
    rlang::abort(
      paste(
        "Membership snapshots must use either `instrument_id` rows or a",
        "`members` list-column, not both."
      ),
      class = c(
        "ledgr_fact_ambiguous_membership_shape",
        "ledgr_fact_invalid_shape",
        "ledgr_invalid_args"
      )
    )
  }
  if (!has_lists) return(list(df = df, complete = complete))
  if (!is.list(df$members)) {
    rlang::abort(
      "Membership snapshot `members` must be a list-column of character vectors.",
      class = c(
        "ledgr_fact_invalid_membership_list",
        "ledgr_fact_invalid_shape",
        "ledgr_invalid_args"
      )
    )
  }
  valid <- vapply(df$members, function(ids) {
    is.character(ids) && !anyNA(ids) && all(nzchar(trimws(ids))) && !anyDuplicated(ids)
  }, logical(1))
  if (!all(valid)) {
    rlang::abort(
      paste(
        "Every `members` value must be a unique character vector without",
        "missing or empty identifiers."
      ),
      class = c(
        "ledgr_fact_invalid_membership_list",
        "ledgr_fact_invalid_shape",
        "ledgr_invalid_args"
      )
    )
  }
  counts <- pmax(lengths(df$members), 1L)
  index <- rep(seq_len(nrow(df)), counts)
  expanded <- df[index, setdiff(names(df), "members"), drop = FALSE]
  expanded$instrument_id <- unlist(lapply(df$members, function(ids) {
    if (length(ids) == 0L) NA_character_ else ids
  }), use.names = FALSE)
  rownames(expanded) <- NULL
  list(df = expanded, complete = complete[index])
}

ledgr_fact_date_scalar <- function(x, arg) {
  if (length(x) != 1L || inherits(x, "POSIXt")) {
    rlang::abort(
      sprintf("`%s` must be one ISO civil Date.", arg),
      class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
    )
  }
  raw <- as.character(x)
  value <- as.Date(raw, format = "%Y-%m-%d")
  if (is.na(value) || !identical(format(value, "%Y-%m-%d"), raw)) {
    rlang::abort(
      sprintf("`%s` must be one ISO civil Date.", arg),
      class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
    )
  }
  value
}

ledgr_session_hour <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) ||
      !grepl("^([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$", x)) {
    rlang::abort(
      sprintf("`%s` must be one local HH:MM:SS time.", arg),
      class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
    )
  }
  x
}

ledgr_session_adapter_provenance <- function(x) {
  if (is.null(x)) return(list())
  if (!is.list(x) || is.null(names(x)) || any(!nzchar(names(x)))) {
    rlang::abort(
      "`provenance` must be NULL or a named list.",
      class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args")
    )
  }
  tryCatch(
    ledgr_json_read_nested(as.character(canonical_json(x))),
    error = function(error) {
      rlang::abort(
        "`provenance` must contain canonically serializable values.",
        class = c("ledgr_session_adapter_invalid", "ledgr_invalid_args"),
        parent = error
      )
    }
  )
}

ledgr_session_adapter_overrides <- function(overrides,
                                            dates,
                                            knowledge_time,
                                            source,
                                            provenance) {
  if (is.null(overrides)) return(data.frame())
  overrides <- as.data.frame(overrides, stringsAsFactors = FALSE)
  required <- c("session_date", "status", "session_open", "session_close")
  missing <- setdiff(required, names(overrides))
  if (nrow(overrides) == 0L || length(missing) > 0L) {
    rlang::abort(
      sprintf(
        "`overrides` must contain complete replacement rows with: %s.",
        paste(required, collapse = ", ")
      ),
      class = c(
        "ledgr_session_override_invalid",
        "ledgr_session_adapter_invalid",
        "ledgr_invalid_args"
      ),
      missing_columns = missing
    )
  }
  overrides$session_date <- ledgr_fact_dates(overrides$session_date)
  if (anyDuplicated(overrides$session_date)) {
    rlang::abort(
      "`overrides` contains duplicate session dates.",
      class = c(
        "ledgr_session_override_invalid",
        "ledgr_session_adapter_invalid",
        "ledgr_invalid_args"
      )
    )
  }
  outside <- !overrides$session_date %in% dates
  if (any(outside)) {
    rlang::abort(
      "`overrides` contains a session date outside the requested range.",
      class = c(
        "ledgr_session_override_invalid",
        "ledgr_session_adapter_invalid",
        "ledgr_invalid_args"
      ),
      session_dates = as.character(overrides$session_date[outside])
    )
  }
  if (!"source" %in% names(overrides)) overrides$source <- source
  if ("knowledge_time" %in% names(overrides)) {
    overrides$knowledge_time <- ledgr_fact_time(
      overrides$knowledge_time,
      "knowledge_time",
      allow_missing = TRUE
    )
  }
  if (!"knowledge_time" %in% names(overrides) && !is.null(knowledge_time)) {
    overrides$knowledge_time <- rep(knowledge_time, nrow(overrides))
  }
  if (!"provenance" %in% names(overrides)) {
    overrides$provenance <- rep(list(provenance), nrow(overrides))
  } else if (!is.list(overrides$provenance)) {
    rlang::abort(
      "Override `provenance` must be a list-column.",
      class = c(
        "ledgr_session_override_invalid",
        "ledgr_session_adapter_invalid",
        "ledgr_invalid_args"
      )
    )
  }
  overrides
}

ledgr_session_adapter_override_payload <- function(overrides) {
  if (nrow(overrides) == 0L) return(list())
  lapply(seq_len(nrow(overrides)), function(i) {
    row <- overrides[i, , drop = FALSE]
    lapply(row, function(column) {
      value <- column[[1L]]
      if (inherits(value, "POSIXt")) return(ledgr_fact_time_token(value))
      if (inherits(value, "Date")) return(as.character(value))
      if (is.list(value)) return(value)
      if (length(value) == 0L || is.na(value)) return(NULL)
      unname(value)
    })
  })
}

ledgr_empty_membership_sets <- function() {
  data.frame(
    universe_id = character(),
    set_id = character(),
    effective_from = as.POSIXct(character(), tz = "UTC"),
    knowledge_time = as.POSIXct(character(), tz = "UTC"),
    complete = logical(),
    provenance_json = character(),
    source = character(),
    stringsAsFactors = FALSE
  )
}

ledgr_fact_validate_status_supersession <- function(rows) {
  superseded <- rows$supersedes_fact_id
  supplied <- !is.na(superseded)
  if (!any(supplied)) return(invisible(TRUE))
  missing <- setdiff(unique(superseded[supplied]), rows$fact_id)
  if (length(missing) > 0L) {
    rlang::abort("Trading-status supersession references an unknown fact.", class = c("ledgr_fact_invalid_supersession", "ledgr_invalid_args"))
  }
  for (i in which(supplied)) {
    target <- match(superseded[[i]], rows$fact_id)
    if (!identical(rows$source[[i]], rows$source[[target]])) {
      rlang::abort("Trading-status supersession must stay within one source.", class = c("ledgr_fact_invalid_supersession", "ledgr_invalid_args"))
    }
  }
  next_id <- stats::setNames(superseded, rows$fact_id)
  for (start in rows$fact_id) {
    seen <- character()
    current <- start
    while (!is.na(next_id[[current]] %||% NA_character_)) {
      current <- next_id[[current]]
      if (current %in% seen || identical(current, start)) {
        rlang::abort("Trading-status supersession must be acyclic.", class = c("ledgr_fact_invalid_supersession", "ledgr_invalid_args"))
      }
      seen <- c(seen, current)
    }
  }
  invisible(TRUE)
}

ledgr_fact_scope_group <- function(rows, columns, already_sorted = FALSE) {
  count <- nrow(rows)
  if (count == 0L) return(integer())
  order_index <- if (isTRUE(already_sorted)) {
    seq_len(count)
  } else {
    do.call(
      order,
      c(
        unname(as.list(rows[, columns, drop = FALSE])),
        list(na.last = TRUE, method = "radix")
      )
    )
  }
  ordered <- rows[order_index, columns, drop = FALSE]
  starts_group <- c(TRUE, rep(FALSE, count - 1L))
  if (count > 1L) {
    differs <- rep(FALSE, count - 1L)
    for (column in columns) {
      left <- ordered[[column]][-count]
      right <- ordered[[column]][-1L]
      equal <- (is.na(left) & is.na(right)) |
        (!is.na(left) & !is.na(right) & left == right)
      differs <- differs | !equal
    }
    starts_group[-1L] <- differs
  }
  ordered_group <- cumsum(starts_group)
  group <- integer(count)
  group[order_index] <- ordered_group
  group
}

ledgr_fact_nonmissing_states <- function(rows, state_column) {
  states <- as.character(rows[[state_column]])
  if (anyNA(states)) {
    rlang::abort(
      sprintf(
        "Fact conflict validation requires non-missing `%s` states.",
        state_column
      ),
      class = c("ledgr_fact_structural_conflict", "ledgr_invalid_args")
    )
  }
  states
}

ledgr_fact_opposing_state_overlap <- function(rows,
                                              scope_columns,
                                              state_column,
                                              stable_column = "fact_id") {
  states <- ledgr_fact_nonmissing_states(rows, state_column)
  if (nrow(rows) < 2L) return(FALSE)
  starts <- as.numeric(rows$effective_from)
  ends <- as.numeric(rows$effective_to)
  ends[is.na(ends)] <- Inf
  stable <- if (stable_column %in% names(rows)) {
    as.character(rows[[stable_column]])
  } else {
    sprintf("%012d", seq_len(nrow(rows)))
  }
  order_index <- do.call(
    order,
    c(
      unname(as.list(rows[, scope_columns, drop = FALSE])),
      list(
        starts, ends, states, stable,
        na.last = TRUE, method = "radix"
      )
    )
  )
  rows <- rows[order_index, , drop = FALSE]
  starts <- starts[order_index]
  ends <- ends[order_index]
  states <- states[order_index]
  group <- ledgr_fact_scope_group(
    rows,
    scope_columns,
    already_sorted = TRUE
  )
  state_levels <- sort(unique(states))
  previous_end <- matrix(
    -Inf,
    nrow = nrow(rows),
    ncol = length(state_levels)
  )
  for (index in seq_along(state_levels)) {
    state_end <- ifelse(states == state_levels[[index]], ends, -Inf)
    previous_end[, index] <- stats::ave(
      state_end,
      group,
      FUN = function(value) c(-Inf, utils::head(cummax(value), -1L))
    )
  }
  opposing_end <- rep(-Inf, nrow(rows))
  for (index in seq_along(state_levels)) {
    opposing <- states != state_levels[[index]]
    opposing_end[opposing] <- pmax(
      opposing_end[opposing],
      previous_end[opposing, index]
    )
  }
  any(starts < opposing_end)
}

ledgr_fact_validate_source_conflicts <- function(rows) {
  ledgr_fact_nonmissing_states(rows, "status")
  superseded <- as.character(rows$supersedes_fact_id)
  supplied <- !is.na(superseded) & nzchar(superseded)
  involved <- supplied | rows$fact_id %in% superseded[supplied]
  uninvolved <- rows[!involved, , drop = FALSE]
  conflict <- ledgr_fact_opposing_state_overlap(
    uninvolved,
    c("instrument_id", "source", "precedence"),
    "status"
  )

  involved_index <- which(involved)
  if (!conflict && length(involved_index) > 0L) {
    scope <- ledgr_fact_scope_group(
      rows,
      c("instrument_id", "source", "precedence")
    )
    pair_chunks <- lapply(involved_index, function(left) {
      right <- which(scope == scope[[left]] & seq_len(nrow(rows)) != left)
      if (length(right) == 0L) return(NULL)
      cbind(pmin(left, right), pmax(left, right))
    })
    pair_chunks <- Filter(Negate(is.null), pair_chunks)
    if (length(pair_chunks) > 0L) {
      pairs <- unique(do.call(rbind, pair_chunks))
      left <- pairs[, 1L]
      right <- pairs[, 2L]
      direct <-
        (!is.na(superseded[left]) & superseded[left] == rows$fact_id[right]) |
        (!is.na(superseded[right]) & superseded[right] == rows$fact_id[left])
      ends <- as.numeric(rows$effective_to)
      ends[is.na(ends)] <- Inf
      starts <- as.numeric(rows$effective_from)
      overlap <- starts[left] < ends[right] & starts[right] < ends[left]
      conflict <- any(
        !direct &
          rows$status[left] != rows$status[right] &
          overlap
      )
    }
  }
  if (conflict) {
    rlang::abort(
      paste(
        "One trading-status source cannot assert conflicting tied",
        "statuses over the same interval."
      ),
      class = c("ledgr_fact_structural_conflict", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_fact_validate_membership_conflicts <- function(rows) {
  if (ledgr_fact_opposing_state_overlap(
    rows,
    c("instrument_id", "universe_id"),
    "member"
  )) {
    rlang::abort(
      "Membership facts cannot assert incompatible overlapping states.",
      class = c("ledgr_fact_structural_conflict", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_fact_validate_lifetime_conflicts <- function(rows) {
  if (ledgr_fact_opposing_state_overlap(
    rows,
    "instrument_id",
    "assertion"
  )) {
    rlang::abort(
      "Lifetime facts cannot assert incompatible overlapping states.",
      class = c("ledgr_fact_structural_conflict", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_status_runtime_conflicts <- function(rows) {
  if (nrow(rows) < 2L) return(character())

  starts <- pmax(
    as.numeric(rows$effective_from),
    as.numeric(rows$knowledge_time)
  )
  ends <- as.numeric(rows$effective_to)
  ends[is.na(ends)] <- Inf

  # A source-local replacement removes its predecessor only once the
  # replacement is both effective and knowable.
  superseders <- which(!is.na(rows$supersedes_fact_id))
  for (i in superseders) {
    predecessor <- match(rows$supersedes_fact_id[[i]], rows$fact_id)
    if (!is.na(predecessor) && is.finite(starts[[i]]) && starts[[i]] < ends[[i]]) {
      ends[[predecessor]] <- min(ends[[predecessor]], starts[[i]])
    }
  }

  usable <- is.finite(starts) & starts < ends
  if (sum(usable) < 2L) return(character())

  conflicts <- character()
  for (instrument_id in unique(rows$instrument_id[usable])) {
    candidates <- which(usable & rows$instrument_id == instrument_id)
    boundaries <- sort(unique(c(starts[candidates], ends[candidates][is.finite(ends[candidates])])))
    for (boundary in boundaries) {
      active <- candidates[starts[candidates] <= boundary & boundary < ends[candidates]]
      if (length(active) < 2L) next
      top <- active[rows$precedence[active] == max(rows$precedence[active])]
      if (length(unique(rows$status[top])) > 1L) {
        conflicts <- c(conflicts, rows$fact_id[top])
      }
    }
  }
  unique(conflicts)
}

ledgr_facts_family <- function(facts, family) {
  Filter(function(x) identical(x$family, family), facts$families)
}

ledgr_session_family <- function(facts) {
  families <- ledgr_facts_family(facts, "sessions")
  if (length(families) == 0L) return(NULL)
  if (length(families) != 1L) {
    rlang::abort("v0.2.0.0 supports exactly one session venue per snapshot.", class = c("ledgr_session_multiple_venues", "ledgr_invalid_facts"))
  }
  families[[1L]]
}

ledgr_session_open_rows <- function(facts) {
  ledgr_session_open_rows_validated(ledgr_facts_assert(facts))
}

ledgr_session_open_rows_validated <- function(facts) {
  family <- ledgr_session_family(facts)
  if (is.null(family)) return(NULL)
  family$rows[family$rows$status == "open", , drop = FALSE]
}

ledgr_session_decision_pulses <- function(facts) {
  rows <- ledgr_session_open_rows(facts)
  if (is.null(rows)) return(as.POSIXct(character(), tz = "UTC"))
  as.POSIXct(rows$session_close, tz = "UTC")
}

ledgr_session_execution_opportunities <- function(session_rows) {
  if (is.null(session_rows) || nrow(session_rows) < 2L) {
    return(as.POSIXct(character(), tz = "UTC"))
  }
  as.POSIXct(session_rows$session_open[-1L], tz = "UTC")
}
