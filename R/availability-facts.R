ledgr_fact_schema_version <- 1L

#' Point-in-time availability facts
#'
#' These constructors normalize point-in-time membership, trading-status,
#' session-calendar, lifetime, and equity corporate-action evidence before
#' snapshot creation. Effective intervals are half-open: `effective_from` is
#' included and `effective_to` is excluded. A membership, trading-status or
#' lifetime row without a knowledge time is accepted and kept in sealed
#' evidence, but every run, sweep, feature precompute, walk-forward session or
#' pulse inspection that prepares availability from that snapshot refuses with
#' `ledgr_fact_knowledge_missing` until the row has a knowledge time.
#' `knowledge = "assume_effective"` supplies one by using the effective time.
#' Date-backed fact clocks are civil labels: [ledgr_facts()] resolves each to exactly one
#' declared open session and retains the civil date, UTC instant, venue zone
#' and calendar identity in sealed evidence. Corporate-action entitlement,
#' effective, and payment dates resolve to session close; their knowledge
#' dates resolve to session open. POSIXct values remain exact.
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
#' Equity corporate-action rows require `subtype`, `parent_instrument_id`,
#' `complete`, and `provenance_tier`. The optional clocks are
#' `entitlement_time`, `effective_time`, `knowledge_time`, and `payment_time`.
#' Optional normalized terms are `gross_cash_per_parent_unit`,
#' `recipient_instrument_id`, and `recipient_quantity_per_parent_unit`; each
#' supplied term requires its matching `*_validated` flag. Incomplete rows
#' require one lower-snake-case `refusal_reason`. Provenance is either
#' `snapshot_bound`, with no upstream identifiers, or
#' `upstream_vintage_bound`, with both `upstream_build_id` and
#' `bar_vintage_id`.
#' A row with an event clock (the effective time, else the entitlement time)
#' and no `knowledge_time` is known when that event becomes effective: a
#' POSIXct event at its instant, a Date event at the declared open of its venue
#' session, while the event itself stays at that session's close. A supplied
#' `knowledge_time` is never replaced. A row with no event or knowledge clock is
#' audit-only. A knowable row with neither an entitlement nor effective clock
#' refuses only once its knowledge cutoff is reached during execution. A
#' complete `cash_acquisition`, `stock_acquisition`, `mixed_acquisition` or
#' `spin_off` row with an effective clock but no entitlement clock refuses with
#' `ledgr_corporate_action_entitlement_missing` at the pulse it would act on.
#' Clock order and interval bounds are checked on resolved instants, so a Date
#' field is compared only after it resolves to its session.
#'
#' Session rows require `session_date`, `status`, `session_open`, and
#' `session_close`; `knowledge_time` is required under evidenced knowledge and
#' may be omitted only with `knowledge = "assume_effective"`. Every civil date
#' in the declared range appears exactly once. Open-session times may be
#' POSIXct timestamps or local `HH:MM:SS` strings; closed rows have missing open
#' and close times. A POSIXct open or close must fall on its `session_date` in
#' the venue zone (`ledgr_session_instant_off_date`), and no two open sessions
#' may share an open or a close instant (`ledgr_session_instant_duplicate`).
#'
#' @section Errors:
#' Structural input failures inherit from `ledgr_invalid_args`. The primary
#' classes are `ledgr_fact_invalid_shape`, `ledgr_fact_invalid_interval`,
#' `ledgr_fact_identity_conflict`, `ledgr_fact_structural_conflict`,
#' `ledgr_fact_invalid_supersession`, `ledgr_fact_invalid_completeness`,
#' `ledgr_fact_unvalidated_term`, `ledgr_session_invalid`,
#' `ledgr_session_time_ambiguous`, and `ledgr_session_time_nonexistent`.
#' Civil dates that do not match exactly one declared open session use
#' `ledgr_fact_civil_date_unresolved`.
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
  labels <- ledgr_fact_civil_labels(
    df,
    c("effective_from", "effective_to", "knowledge_time")
  )
  ledgr_fact_check_exact_intervals(labels, effective_from, effective_to, "membership intervals")
  member <- ledgr_fact_logical(df$member, "member")
  knowledge_time <- ledgr_fact_knowledge_time(df, effective_from, knowledge)
  civil_time_json <- ledgr_fact_civil_json(labels, knowledge)
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
    civil_time_json = civil_time_json,
    provenance_json = provenance_json,
    source = source,
    stringsAsFactors = FALSE
  )
  rows$fact_id <- ledgr_fact_ids("membership", rows, supplied_id)
  rows <- ledgr_fact_deduplicate(rows, "membership")

  ledgr_fact_family_build(
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
  civil_time_json <- ledgr_fact_civil_json(
    ledgr_fact_civil_labels(df, c("effective_from", "knowledge_time")),
    knowledge
  )
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
    civil_time_json = civil_time_json[first],
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
    civil_time_json = civil_time_json[rows_keep],
    provenance_json = provenance_json[rows_keep],
    source = source[rows_keep],
    stringsAsFactors = FALSE
  )
  if (nrow(rows) > 0L) {
    rows$fact_id <- ledgr_fact_ids("membership", rows, rep(NA_character_, nrow(rows)))
    rows <- ledgr_fact_deduplicate(rows, "membership")
  }

  ledgr_fact_family_build(
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
  labels <- ledgr_fact_civil_labels(
    df,
    c("effective_from", "effective_to", "knowledge_time")
  )
  ledgr_fact_check_exact_intervals(labels, effective_from, effective_to, "trading status")
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
  civil_time_json <- ledgr_fact_civil_json(labels, knowledge)
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
    civil_time_json = civil_time_json,
    provenance_json = provenance_json,
    stringsAsFactors = FALSE
  )
  rows$fact_id <- ledgr_fact_ids("trading_status", rows, supplied_id)
  rows$supersedes_fact_id <- ledgr_fact_status_link_ids(
    rows$supersedes_fact_id,
    supplied_id,
    source,
    rows$fact_id
  )
  rows <- ledgr_fact_deduplicate(rows, "trading_status")

  ledgr_fact_family_build(
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
  labels <- ledgr_fact_civil_labels(
    df,
    c("effective_from", "effective_to", "knowledge_time")
  )
  ledgr_fact_check_exact_intervals(labels, effective_from, effective_to, "lifetime")
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
  civil_time_json <- ledgr_fact_civil_json(labels, knowledge)
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
    civil_time_json = civil_time_json,
    provenance_json = provenance_json,
    stringsAsFactors = FALSE
  )
  rows$fact_id <- ledgr_fact_ids("lifetime", rows, supplied_id)
  rows <- ledgr_fact_deduplicate(rows, "lifetime")

  ledgr_fact_family_build(
    "lifetime",
    "instrument",
    rows,
    metadata = ledgr_fact_knowledge_metadata(knowledge)
  )
}

ledgr_equity_corporate_action_abort <- function(message,
                                                 subclass,
                                                 state = FALSE) {
  rlang::abort(
    message,
    class = c(
      subclass,
      if (isTRUE(state)) "ledgr_invalid_state" else "ledgr_invalid_args"
    )
  )
}

ledgr_validate_equity_corporate_action_rows <- function(rows,
                                                         state = FALSE,
                                                         clocks = TRUE) {
  required <- c(
    "fact_id", "subtype", "parent_instrument_id", "entitlement_time",
    "effective_time", "knowledge_time", "payment_time", "complete",
    "refusal_reason", "provenance_tier", "upstream_build_id",
    "bar_vintage_id", "gross_cash_per_parent_unit",
    "gross_cash_validated", "recipient_instrument_id",
    "recipient_identity_validated", "recipient_quantity_per_parent_unit",
    "recipient_quantity_validated"
  )
  missing <- setdiff(required, names(rows))
  if (length(missing) > 0L) {
    ledgr_equity_corporate_action_abort(
      sprintf(
        "Equity corporate-action rows are missing required field(s): %s.",
        paste(missing, collapse = ", ")
      ),
      "ledgr_fact_invalid_shape",
      state
    )
  }

  valid_code <- function(x) {
    !is.na(x) & grepl("^[a-z][a-z0-9_]*$", x)
  }
  if (anyNA(rows$fact_id) || any(!nzchar(rows$fact_id)) ||
      anyDuplicated(rows$fact_id)) {
    ledgr_equity_corporate_action_abort(
      "Equity corporate-action `fact_id` values must be non-empty and unique.",
      "ledgr_fact_identity_conflict",
      state
    )
  }
  if (any(!valid_code(rows$subtype))) {
    ledgr_equity_corporate_action_abort(
      "Equity corporate-action `subtype` must be a stable lower-snake-case code.",
      "ledgr_fact_invalid_subtype",
      state
    )
  }
  if (anyNA(rows$parent_instrument_id) ||
      any(!nzchar(rows$parent_instrument_id))) {
    ledgr_equity_corporate_action_abort(
      "Equity corporate-action parent identities must be non-empty strings.",
      "ledgr_fact_invalid_instrument",
      state
    )
  }

  logical_fields <- c(
    "complete", "gross_cash_validated", "recipient_identity_validated",
    "recipient_quantity_validated"
  )
  logical_ok <- vapply(logical_fields, function(field) {
    is.logical(rows[[field]]) && !anyNA(rows[[field]])
  }, logical(1))
  if (!all(logical_ok)) {
    ledgr_equity_corporate_action_abort(
      "Equity corporate-action completeness and validation flags must be logical.",
      "ledgr_fact_invalid_logical",
      state
    )
  }

  refusal <- as.character(rows$refusal_reason)
  has_refusal <- !is.na(refusal) & nzchar(refusal)
  invalid_reason <- has_refusal & !valid_code(refusal)
  if (any(rows$complete & has_refusal) ||
      any(!rows$complete & !has_refusal) || any(invalid_reason)) {
    ledgr_equity_corporate_action_abort(
      paste(
        "Complete corporate-action facts must have no refusal reason;",
        "incomplete facts require one stable lower-snake-case reason."
      ),
      "ledgr_fact_invalid_completeness",
      state
    )
  }

  allowed_tiers <- c("snapshot_bound", "upstream_vintage_bound")
  tier <- as.character(rows$provenance_tier)
  build <- as.character(rows$upstream_build_id)
  vintage <- as.character(rows$bar_vintage_id)
  has_build <- !is.na(build) & nzchar(build)
  has_vintage <- !is.na(vintage) & nzchar(vintage)
  weak <- tier == "snapshot_bound"
  strong <- tier == "upstream_vintage_bound"
  invalid_tier <- is.na(tier) | !tier %in% allowed_tiers |
    (weak & (has_build | has_vintage)) |
    (strong & (!has_build | !has_vintage))
  if (any(invalid_tier)) {
    ledgr_equity_corporate_action_abort(
      paste(
        "`snapshot_bound` facts omit upstream build and bar vintage;",
        "`upstream_vintage_bound` facts require both."
      ),
      "ledgr_fact_invalid_provenance_tier",
      state
    )
  }

  if (isTRUE(clocks)) ledgr_validate_equity_corporate_action_clocks(rows, state)

  check_term <- function(value, validated, label, valid_value) {
    present <- !is.na(value)
    if (any(present != validated) || any(present & !valid_value(value))) {
      ledgr_equity_corporate_action_abort(
        sprintf("Corporate-action term `%s` must be valid and independently validated.", label),
        "ledgr_fact_unvalidated_term",
        state
      )
    }
  }
  check_term(
    rows$gross_cash_per_parent_unit,
    rows$gross_cash_validated,
    "gross_cash_per_parent_unit",
    function(x) is.finite(x) & x >= 0
  )
  check_term(
    rows$recipient_instrument_id,
    rows$recipient_identity_validated,
    "recipient_instrument_id",
    function(x) nzchar(x)
  )
  check_term(
    rows$recipient_quantity_per_parent_unit,
    rows$recipient_quantity_validated,
    "recipient_quantity_per_parent_unit",
    function(x) is.finite(x) & x > 0
  )
  invisible(TRUE)
}

# Clock order on resolved instants. A constructor defers it to
# ledgr_fact_family_settle() so a civil date is never compared through a
# UTC-midnight stand-in.
ledgr_validate_equity_corporate_action_clocks <- function(rows, state = FALSE) {
  entitlement <- rows$entitlement_time
  effective <- rows$effective_time
  payment <- rows$payment_time
  bad_order <- (!is.na(entitlement) & !is.na(effective) &
    entitlement > effective) |
    (!is.na(effective) & !is.na(payment) & effective > payment) |
    (!is.na(entitlement) & !is.na(payment) & entitlement > payment)
  if (any(bad_order)) {
    ledgr_equity_corporate_action_abort(
      "Corporate-action clocks must preserve entitlement <= effective <= payment when supplied.",
      "ledgr_fact_invalid_clock_order",
      state
    )
  }
  invisible(TRUE)
}

# Cut 16 decisions (11) and (27), the one known-when-effective rule. A
# corporate-action row with an event clock and no knowledge clock is known
# when its event becomes effective; the event clock is the effective time,
# else the entitlement time. A POSIXct event is known at that instant. A
# Date event is a civil session label whose event edge is the session close
# (decision 12); its knowledge label is the same civil date, which civil
# resolution places at that session's declared open (decision 27). A
# supplied knowledge time, Date or POSIXct, is never replaced.
ledgr_corporate_action_assumed_knowledge <- function(rows, labels) {
  event <- rows$effective_time
  event_label <- labels$effective_time
  from_entitlement <- is.na(event) & !is.na(rows$entitlement_time)
  event[from_entitlement] <- rows$entitlement_time[from_entitlement]
  event_label[from_entitlement] <- labels$entitlement_time[from_entitlement]
  assume <- is.na(rows$knowledge_time) & !is.na(event)
  knowledge_time <- rows$knowledge_time
  knowledge_time[assume] <- event[assume]
  knowledge_label <- labels$knowledge_time
  knowledge_label[assume] <- event_label[assume]
  list(knowledge_time = knowledge_time, knowledge_label = knowledge_label)
}

ledgr_equity_corporate_action_optional_numeric <- function(df, field) {
  if (!field %in% names(df)) return(rep(NA_real_, nrow(df)))
  raw <- df[[field]]
  out <- suppressWarnings(as.numeric(raw))
  invalid <- !is.na(raw) & is.na(out)
  if (any(invalid)) {
    ledgr_equity_corporate_action_abort(
      sprintf("Corporate-action term `%s` must be numeric when supplied.", field),
      "ledgr_fact_unvalidated_term"
    )
  }
  out
}

ledgr_equity_corporate_action_validation_flag <- function(df, field) {
  if (!field %in% names(df)) return(rep(FALSE, nrow(df)))
  ledgr_fact_logical(df[[field]], field)
}

#' @rdname ledgr_facts
#' @export
ledgr_facts_equity_corporate_actions <- function(df) {
  df <- ledgr_fact_data_frame(df, "equity corporate actions")
  ledgr_fact_require_columns(
    df,
    c("subtype", "parent_instrument_id", "complete", "provenance_tier"),
    "equity corporate actions"
  )
  source <- ledgr_fact_source(df)
  labels <- ledgr_fact_civil_labels(
    df,
    c(
      "entitlement_time", "effective_time", "knowledge_time",
      "payment_time"
    )
  )
  rows <- data.frame(
    fact_id = rep("", nrow(df)),
    subtype = tolower(enc2utf8(as.character(df$subtype))),
    parent_instrument_id = ledgr_fact_instrument_ids(
      df$parent_instrument_id,
      allow_missing = FALSE
    ),
    entitlement_time = ledgr_fact_optional_time(df, "entitlement_time"),
    effective_time = ledgr_fact_optional_time(df, "effective_time"),
    knowledge_time = ledgr_fact_optional_time(df, "knowledge_time"),
    payment_time = ledgr_fact_optional_time(df, "payment_time"),
    complete = ledgr_fact_logical(df$complete, "complete"),
    refusal_reason = ledgr_fact_optional_character(df, "refusal_reason"),
    provenance_tier = tolower(enc2utf8(as.character(df$provenance_tier))),
    upstream_build_id = ledgr_fact_optional_character(df, "upstream_build_id"),
    bar_vintage_id = ledgr_fact_optional_character(df, "bar_vintage_id"),
    gross_cash_per_parent_unit =
      ledgr_equity_corporate_action_optional_numeric(
        df,
        "gross_cash_per_parent_unit"
      ),
    gross_cash_validated = ledgr_equity_corporate_action_validation_flag(
      df,
      "gross_cash_validated"
    ),
    recipient_instrument_id = ledgr_fact_optional_character(
      df,
      "recipient_instrument_id"
    ),
    recipient_identity_validated =
      ledgr_equity_corporate_action_validation_flag(
        df,
        "recipient_identity_validated"
      ),
    recipient_quantity_per_parent_unit =
      ledgr_equity_corporate_action_optional_numeric(
        df,
        "recipient_quantity_per_parent_unit"
      ),
    recipient_quantity_validated =
      ledgr_equity_corporate_action_validation_flag(
        df,
        "recipient_quantity_validated"
      ),
    source = source,
    civil_time_json = "",
    provenance_json = ledgr_fact_provenance(df, source, "evidenced"),
    stringsAsFactors = FALSE
  )
  known <- ledgr_corporate_action_assumed_knowledge(rows, labels)
  rows$knowledge_time <- known$knowledge_time
  labels$knowledge_time <- known$knowledge_label
  rows$civil_time_json <- ledgr_fact_civil_encode(labels)
  supplied_id <- ledgr_fact_optional_character(df, "fact_id")
  rows$fact_id <- ledgr_fact_ids(
    "equity_corporate_actions",
    rows,
    supplied_id
  )
  ledgr_validate_equity_corporate_action_rows(rows, clocks = FALSE)
  rows <- ledgr_fact_deduplicate(rows, "equity corporate actions")

  ledgr_fact_family_build(
    "equity_corporate_actions",
    "equity",
    rows,
    metadata = list(
      contract = "vendor_neutral_normalized_terms_v1",
      provenance_tiers = sort(unique(rows$provenance_tier), method = "radix")
    )
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
  # POSIXct instants are taken as given, so they are checked against their
  # session_date in the venue zone; two sessions sharing an instant (a shifted
  # vendor row) would make one pulse two sessions.
  if (anyDuplicated(session_open[is_open]) || anyDuplicated(session_close[is_open])) {
    rlang::abort(
      "Open sessions must not share a session open or close instant.",
      class = c("ledgr_session_instant_duplicate", "ledgr_session_invalid", "ledgr_invalid_args")
    )
  }
  local_date <- function(x) format(x[is_open], "%Y-%m-%d", tz = timezone)
  off_date <- local_date(session_open) != as.character(session_date[is_open]) |
    local_date(session_close) != as.character(session_date[is_open])
  if (any(off_date)) {
    rlang::abort(
      sprintf(
        "Session open and close must fall on their session_date in %s; off-date session(s): %s.",
        timezone,
        paste(utils::head(as.character(session_date[is_open][off_date]), 5L), collapse = ", ")
      ),
      class = c("ledgr_session_instant_off_date", "ledgr_session_invalid", "ledgr_invalid_args")
    )
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
      calendar_id = venue_id,
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
    calendar_name = as.character(qlcal::getName(xp = calendar)),
    adapter_normalization_version = 1L,
    declared_session_open = session_open,
    declared_session_close = session_close,
    overrides = ledgr_session_adapter_override_payload(normalized_overrides),
    provenance = provenance
  ))
  metadata$calendar_id <- as.character(qlcal::getId(xp = calendar))
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
  ord <- order(keys, method = "radix")
  families <- unname(families[ord])
  families <- ledgr_fact_resolve_civil_families(families)
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

# Civil labels of the Date-valued `fields` of `df`: one character vector per
# field, NA where the field is absent or not a Date. Each distinct date is
# formatted once.
ledgr_fact_civil_labels <- function(df, fields) {
  count <- nrow(df)
  # Iterates the fixed clock-field vocabulary, not rows.
  labels <- lapply(fields, function(field) {
    value <- if (field %in% names(df)) df[[field]] else NULL
    if (is.null(value) || !inherits(value, "Date") || inherits(value, "POSIXt")) {
      return(rep(NA_character_, count))
    }
    distinct <- unique(value)
    as.character(distinct)[match(value, distinct)]
  })
  names(labels) <- fields
  labels
}

ledgr_fact_civil_json <- function(labels, knowledge = NULL) {
  if (identical(knowledge, "assume_effective") &&
      all(c("knowledge_time", "effective_from") %in% names(labels))) {
    # The assume-effective label follows the effective label wherever the
    # knowledge field carries no civil label of its own. Retained unchanged
    # from the accepted WS40 tree: with a POSIXct knowledge column and a Date
    # effective_from it also relabels supplied knowledge times, which is
    # routed to the maintainer in the WS45 closeout rather than changed here.
    missing <- is.na(labels$knowledge_time)
    labels$knowledge_time[missing] <- labels$effective_from[missing]
  }
  ledgr_fact_civil_encode(labels)
}

# Unresolved civil evidence, one JSON object per row:
# {"<field>":{"civil_date":"YYYY-MM-DD"},...} with fields in name order.
# Each distinct date is encoded once per field and indexed back to rows.
ledgr_fact_civil_encode <- function(labels) {
  if (length(labels) == 0L) return(character())
  count <- length(labels[[1L]])
  # Iterates the fixed clock-field vocabulary, not rows.
  fragments <- lapply(labels, function(civil) {
    civil <- as.character(civil)
    has <- !is.na(civil) & nzchar(civil)
    out <- rep(NA_character_, count)
    if (!any(has)) return(out)
    distinct <- unique(civil[has])
    encoded <- ledgr_fact_civil_ndjson(
      data.frame(civil_date = distinct, stringsAsFactors = FALSE)
    )
    out[has] <- encoded[match(civil[has], distinct)]
    out
  })
  ledgr_fact_civil_assemble(fragments)
}

ledgr_fact_civil_ndjson <- function(frame) {
  encoded <- strsplit(
    ledgr_json_write_canonical_ndjson(frame),
    "\n",
    fixed = TRUE
  )[[1L]]
  encoded[nzchar(encoded)]
}

# Joins per-field evidence fragments (NA where a row has none for that field)
# into one JSON object per row, fields in name order.
ledgr_fact_civil_assemble <- function(fragments) {
  count <- length(fragments[[1L]])
  out <- rep("{", count)
  populated <- rep(FALSE, count)
  # Iterates the fixed clock-field vocabulary, not rows.
  for (field in sort(names(fragments), method = "radix")) {
    fragment <- fragments[[field]]
    has <- !is.na(fragment)
    if (!any(has)) next
    field_json <- as.character(ledgr_json_write_canonical_v2(field))
    separator <- ifelse(populated[has], ",", "")
    out[has] <- paste0(out[has], separator, field_json, ":", fragment[has])
    populated[has] <- TRUE
  }
  paste0(out, "}")
}

# TRUE when a frame holds civil labels that no session has resolved yet.
ledgr_fact_frame_pending_civil <- function(frame) {
  if (is.null(frame) || nrow(frame) == 0L ||
      !"civil_time_json" %in% names(frame)) return(FALSE)
  json <- frame$civil_time_json
  populated <- !is.na(json) & json != "{}"
  any(populated & !grepl('"resolved_ts_utc"', json, fixed = TRUE))
}

# Resolves every family that still holds civil labels against the bundle's
# declared open sessions, then validates and orders that family on the
# resolved instants and rehashes it. A family without pending labels,
# including one resolved by an earlier bundle, is returned untouched with its
# own hash, so an edit to it is refused by ledgr_facts_assert() whatever else
# the bundle holds. A family about to be rehashed is checked first, so
# resolution never launders an edit made after construction.
ledgr_fact_resolve_civil_families <- function(families) {
  # Iterates the bundle's fact families, not rows.
  pending <- vapply(families, function(family) {
    ledgr_fact_frame_pending_civil(family$rows) ||
      ledgr_fact_frame_pending_civil(family$headers)
  }, logical(1))
  if (!any(pending)) return(families)
  if (!all(vapply(families[pending], ledgr_fact_family_intact, logical(1)))) {
    rlang::abort(
      "`facts` must be an untampered ledgr_facts object.",
      class = c("ledgr_invalid_facts", "ledgr_invalid_args")
    )
  }
  sessions <- ledgr_fact_civil_sessions(families)
  for (i in which(pending)) {
    family <- families[[i]]
    rows <- ledgr_fact_resolve_civil_frame(family$rows, sessions)
    headers <- ledgr_fact_resolve_civil_frame(family$headers, sessions)
    settled <- ledgr_fact_family_settle(
      family$family,
      rows,
      headers,
      family$metadata,
      intervals = TRUE
    )
    families[[i]] <- ledgr_new_fact_family(
      family$family,
      family$scope_id,
      settled$rows,
      settled$headers,
      family$metadata
    )
  }
  families
}

# Every declared open session in the bundle, prepared once: its civil date,
# open and close instants, how many open sessions share that date, and the
# resolved evidence for each edge (calendar, civil date, instant, zone and
# venue) encoded once per session. Rows read it by session index.
ledgr_fact_civil_sessions <- function(families) {
  # Iterates the bundle's session families (one per venue), not rows.
  frames <- lapply(families, function(family) {
    if (!identical(family$family, "sessions")) return(NULL)
    rows <- family$rows[family$rows$status == "open", , drop = FALSE]
    count <- nrow(rows)
    data.frame(
      civil_date = as.character(rows$session_date),
      session_open = rows$session_open,
      session_close = rows$session_close,
      venue_id = as.character(rows$venue_id),
      timezone = rep(family$metadata$timezone %||% "UTC", count),
      calendar_id = rep(
        family$metadata$calendar_id %||% family$scope_id,
        count
      ),
      stringsAsFactors = FALSE
    )
  })
  frames <- Filter(Negate(is.null), frames)
  table <- if (length(frames) == 0L) NULL else do.call(rbind, frames)
  if (is.null(table) || nrow(table) == 0L) {
    return(list(civil_date = character(), date_count = integer()))
  }
  key <- match(table$civil_date, unique(table$civil_date))
  evidence <- function(instant) {
    ledgr_fact_civil_ndjson(data.frame(
      calendar_id = as.character(table$calendar_id),
      civil_date = table$civil_date,
      resolved_ts_utc = ledgr_fact_time_token(instant),
      timezone = as.character(table$timezone),
      venue_id = table$venue_id,
      stringsAsFactors = FALSE
    ))
  }
  list(
    civil_date = table$civil_date,
    date_count = tabulate(key)[key],
    session_open = table$session_open,
    session_close = table$session_close,
    open_evidence = evidence(table$session_open),
    close_evidence = evidence(table$session_close)
  )
}

ledgr_fact_resolve_civil_frame <- function(frame, sessions) {
  if (is.null(frame) || nrow(frame) == 0L ||
      !"civil_time_json" %in% names(frame)) return(frame)
  populated <- !is.na(frame$civil_time_json) & frame$civil_time_json != "{}"
  resolved <- populated & grepl(
    '"resolved_ts_utc"', frame$civil_time_json, fixed = TRUE
  )
  if (any(resolved)) {
    if (any(populated & !resolved)) {
      rlang::abort(
        "Civil-time evidence cannot mix resolved and unresolved rows in one fact frame.",
        class = c("ledgr_invalid_facts", "ledgr_invalid_args")
      )
    }
    return(frame)
  }
  candidate_fields <- intersect(
    c(
      "effective_from", "effective_to", "knowledge_time",
      "entitlement_time", "effective_time", "payment_time"
    ),
    names(frame)
  )
  count <- nrow(frame)
  fragments <- stats::setNames(
    vector("list", length(candidate_fields)),
    candidate_fields
  )
  # Iterates the fixed clock-field vocabulary, not rows.
  for (field in candidate_fields) {
    token <- paste0(
      as.character(ledgr_json_write_canonical_v2(field)),
      ":{\"civil_date\":\""
    )
    starts <- regexpr(token, frame$civil_time_json, fixed = TRUE)
    has <- starts > 0L
    fragment <- rep(NA_character_, count)
    if (any(has)) {
      remainder <- substring(
        frame$civil_time_json[has],
        starts[has] + attr(starts, "match.length")[has]
      )
      civil <- substring(remainder, 1L, regexpr('"', remainder, fixed = TRUE) - 1L)
      session <- match(civil, sessions$civil_date)
      match_count <- sessions$date_count[session]
      match_count[is.na(match_count)] <- 0L
      invalid <- which(match_count != 1L)
      if (length(invalid) > 0L) {
        first <- invalid[[1L]]
        rlang::abort(
          sprintf(
            "Fact `%s` Date %s must resolve to exactly one declared open session; found %d.",
            field, civil[[first]], match_count[[first]]
          ),
          class = c(
            "ledgr_fact_civil_date_unresolved",
            "ledgr_invalid_facts",
            "ledgr_invalid_args"
          ),
          field = field,
          civil_date = civil[[first]],
          match_count = match_count[[first]]
        )
      }
      row_index <- which(has)
      # Event clocks name the session close (Cut 16 decision 12); starts,
      # ends and knowledge name the session open.
      if (field %in% c("entitlement_time", "effective_time", "payment_time")) {
        frame[[field]][row_index] <- sessions$session_close[session]
        fragment[row_index] <- sessions$close_evidence[session]
      } else {
        frame[[field]][row_index] <- sessions$session_open[session]
        fragment[row_index] <- sessions$open_evidence[session]
      }
    }
    fragments[[field]] <- fragment
  }
  frame$civil_time_json <- if (length(fragments) == 0L) {
    rep("{}", count)
  } else {
    ledgr_fact_civil_assemble(fragments)
  }
  frame
}

# Validates and orders one fact family on resolved instants. A constructor
# calls it when no civil label awaits resolution (POSIXct input is already
# exact); ledgr_facts() calls it once the bundle's sessions have resolved the
# family's labels. It is the only place a family's time comparisons run and
# its row order is fixed, so neither ever reads a UTC-midnight stand-in for a
# civil date.
ledgr_fact_family_settle <- function(family,
                                     rows,
                                     headers,
                                     metadata,
                                     intervals = TRUE) {
  if (identical(family, "membership")) {
    if (identical(metadata$shape, "snapshots")) {
      # Snapshot rows are open, member-only assertions: interval and
      # opposing-state validation cannot fire on them.
      if (!is.null(headers) && nrow(headers) > 0L) {
        headers <- headers[order(
          headers$effective_from,
          headers$knowledge_time,
          headers$set_id,
          na.last = TRUE,
          method = "radix"
        ), , drop = FALSE]
      }
      rows <- rows[order(
        rows$effective_from,
        rows$set_id,
        rows$instrument_id,
        method = "radix"
      ), , drop = FALSE]
    } else {
      if (isTRUE(intervals)) {
        ledgr_fact_validate_intervals(
          rows$effective_from,
          rows$effective_to,
          "membership intervals"
        )
      }
      ledgr_fact_validate_membership_conflicts(rows)
      rows <- rows[order(
        rows$universe_id,
        rows$instrument_id,
        rows$effective_from,
        rows$fact_id,
        method = "radix"
      ), , drop = FALSE]
    }
  } else if (identical(family, "trading_status")) {
    ledgr_fact_validate_status_rows(rows, intervals = intervals)
    rows <- rows[order(
      rows$instrument_id,
      rows$effective_from,
      -rows$precedence,
      rows$source,
      rows$fact_id,
      method = "radix"
    ), , drop = FALSE]
  } else if (identical(family, "lifetime")) {
    if (isTRUE(intervals)) {
      ledgr_fact_validate_intervals(
        rows$effective_from,
        rows$effective_to,
        "lifetime"
      )
    }
    ledgr_fact_validate_lifetime_conflicts(rows)
    rows <- rows[order(
      rows$instrument_id,
      rows$effective_from,
      rows$source,
      rows$fact_id,
      method = "radix"
    ), , drop = FALSE]
  } else if (identical(family, "equity_corporate_actions")) {
    ledgr_validate_equity_corporate_action_clocks(rows)
    rows <- rows[order(
      rows$parent_instrument_id,
      rows$entitlement_time,
      rows$effective_time,
      rows$fact_id
    ), , drop = FALSE]
  }
  rownames(rows) <- NULL
  if (!is.null(headers)) rownames(headers) <- NULL
  list(rows = rows, headers = headers)
}

# A constructor's last step: settle the family now when nothing awaits civil
# resolution, otherwise leave validation and order to ledgr_facts(). Such a
# family has exact interval bounds, which the constructor already checked
# (ledgr_fact_check_exact_intervals()) where the accepted refusal order puts
# that check, ahead of identity conflicts.
ledgr_fact_family_build <- function(family,
                                    scope_id,
                                    rows,
                                    headers = NULL,
                                    metadata = list()) {
  if (!ledgr_fact_frame_pending_civil(rows) &&
      !ledgr_fact_frame_pending_civil(headers)) {
    settled <- ledgr_fact_family_settle(
      family,
      rows,
      headers,
      metadata,
      intervals = FALSE
    )
    rows <- settled$rows
    headers <- settled$headers
  }
  ledgr_new_fact_family(family, scope_id, rows, headers, metadata)
}

#' Validate point-in-time facts without writing
#'
#' Produces a source-aware dry-run report. Accepted rows, retained runtime
#' conflicts, rejected rows, quarantine candidates, and audit-only facts stay
#' distinct. This function never creates or modifies a snapshot. A membership,
#' trading-status or lifetime row reported `audit_only` with reason
#' `knowledge_time_missing` is sealed, but availability preparation then
#' refuses it with `ledgr_fact_knowledge_missing`.
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
  report$off_session_rows <- NULL
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
  family_valid <- vapply(x$families, ledgr_fact_family_intact, logical(1))
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

# One integrity rule for a fact family: its recorded hash equals the hash of
# its current family, scope, rows, headers and metadata.
ledgr_fact_family_intact <- function(family) {
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
}

ledgr_facts_validated <- function(x) {
  structure(
    list(facts = ledgr_facts_assert(x)),
    class = "ledgr_validated_facts"
  )
}

ledgr_facts_unwrap_validated <- function(x) {
  if (inherits(x, "ledgr_validated_facts")) return(x$facts)
  ledgr_facts_assert(x)
}

ledgr_fact_family_hash <- function(family, scope_id, rows, headers, metadata) {
  digest::digest(
    ledgr_fact_family_payload_json(
      family = family,
      scope_id = scope_id,
      metadata = metadata,
      rows = rows,
      headers = headers
    ),
    algo = "sha256"
  )
}

ledgr_fact_json_verbatim <- function(x) {
  structure(as.character(x), class = "json")
}

ledgr_fact_canonical_frame <- function(df) {
  if (is.null(df) || nrow(df) == 0L) return(data.frame())
  out <- as.data.frame(df, stringsAsFactors = FALSE)
  out <- out[order(names(out), method = "radix")]
  for (name in names(out)) {
    column <- out[[name]]
    if (inherits(column, "POSIXt")) {
      out[[name]] <- ledgr_fact_time_tokens_distinct(column)
    } else if (inherits(column, "Date")) {
      out[[name]] <- as.character(column)
    } else if (is.factor(column)) {
      out[[name]] <- as.character(column)
    } else {
      out[[name]] <- unname(column)
    }
  }
  out
}

ledgr_fact_time_tokens_distinct <- function(x) {
  out <- rep(NA_character_, length(x))
  keep <- !is.na(x)
  if (!any(keep)) return(out)
  values <- x[keep]
  distinct <- unique(values)
  tokens <- ledgr_fact_time_token(distinct)
  out[keep] <- tokens[match(values, distinct)]
  out
}

ledgr_fact_frame_payload_json <- function(df) {
  if (is.null(df) || nrow(df) == 0L) return("[]")
  as.character(ledgr_json_write_canonical_v2_verbatim(
    ledgr_fact_canonical_frame(df)
  ))
}

ledgr_fact_family_payload_json <- function(
  family,
  scope_id,
  rows,
  headers,
  metadata
) {
  # Field order is the canonical name order used by ledgr_fact_family_v1.
  payload <- list(
    family = family,
    headers = ledgr_fact_json_verbatim(ledgr_fact_frame_payload_json(headers)),
    metadata = ledgr_fact_json_verbatim(canonical_json(metadata)),
    rows = ledgr_fact_json_verbatim(ledgr_fact_frame_payload_json(rows)),
    schema = "ledgr_fact_family_v1",
    scope_id = scope_id
  )
  as.character(ledgr_json_write_canonical_v2_verbatim(payload))
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
  # DuckDB rejects valid POSIXct vectors backed by integer epoch seconds.
  # Preserve the validated instants while canonicalizing their storage once.
  storage.mode(out) <- "double"
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

# Interval bounds that carry no civil label are exact instants, so the
# constructor checks them where the accepted refusal order expects it. A
# civil bound is checked only after resolution, in ledgr_fact_family_settle().
ledgr_fact_check_exact_intervals <- function(labels, from, to, label) {
  if (all(is.na(labels$effective_from)) && all(is.na(labels$effective_to))) {
    ledgr_fact_validate_intervals(from, to, label)
  }
  invisible(TRUE)
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
    payload_json <- if (!is.na(source_id) && nzchar(source_id)) {
      # These names are already in canonical order. Avoid populating and
      # probing the general config cache for identities used exactly once.
      as.character(ledgr_json_write_canonical_v2(list(
        family = family,
        source = rows$source[[i]],
        source_id = source_id
      )))
    } else {
      one <- rows[i, setdiff(names(rows), "fact_id"), drop = FALSE]
      as.character(canonical_json(list(
        family = family,
        assertion = ledgr_fact_row_payload(one)
      )))
    }
    paste0(
      "fact_",
      substr(digest::digest(payload_json, algo = "sha256"), 1L, 32L)
    )
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
  prepared <- ledgr_fact_canonical_frame(rows)
  distinct_payload <- !duplicated(prepared)
  distinct_ids <- rows$fact_id[distinct_payload]
  incompatible <- sort(
    unique(distinct_ids[duplicated(distinct_ids)]),
    method = "radix"
  )
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
    resolved <- ledgr_local_times_resolve(labels, timezone)
    counts <- resolved$counts
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
    out[keep] <- resolved$values
  }
  as.POSIXct(out, tz = "UTC")
}

ledgr_local_times_resolve <- function(labels, timezone) {
  wall <- as.POSIXct(
    labels,
    tz = "UTC",
    format = "%Y-%m-%d %H:%M:%S"
  )
  shifts <- seq.int(-2L, 2L) * 86400
  probes <- as.POSIXct(
    rep(as.numeric(wall), times = length(shifts)) +
      rep(shifts, each = length(wall)),
    origin = "1970-01-01",
    tz = "UTC"
  )
  offsets <- unique(format(probes, "%z", tz = timezone))
  offset_seconds <- vapply(offsets, ledgr_utc_offset_seconds, numeric(1))
  candidates <- outer(as.numeric(wall), offset_seconds, `-`)
  roundtrip <- matrix(
    format(
      as.POSIXct(as.vector(candidates), origin = "1970-01-01", tz = "UTC"),
      "%Y-%m-%d %H:%M:%S",
      tz = timezone
    ),
    nrow = length(labels),
    ncol = length(offsets)
  )
  matches <- roundtrip == labels
  counts <- as.integer(rowSums(matches))
  values <- as.POSIXct(
    rep(NA_real_, length(labels)),
    origin = "1970-01-01",
    tz = "UTC"
  )
  unique_match <- counts == 1L
  if (any(unique_match)) {
    columns <- max.col(matches[unique_match, , drop = FALSE], ties.method = "first")
    values[unique_match] <- as.POSIXct(
      candidates[cbind(which(unique_match), columns)],
      origin = "1970-01-01",
      tz = "UTC"
    )
  }
  list(values = values, counts = counts)
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
    civil_time_json = character(),
    provenance_json = character(),
    source = character(),
    stringsAsFactors = FALSE
  )
}

# A supplied `supersedes_fact_id` names a supplied `fact_id` of the same
# source. When exactly one row carries that supplied id and source, the
# link is rewritten to that row's canonical fact id; otherwise it is kept as
# supplied (and later refused as unknown if it names no fact). One keyed
# match replaces a scan of every row per link.
ledgr_fact_status_link_ids <- function(links, supplied_id, source, fact_id) {
  linked <- which(!is.na(links))
  if (length(linked) == 0L) return(links)
  key <- function(id, src) {
    paste0(nchar(id, type = "bytes"), ":", id, "\r", src)
  }
  supplied_key <- key(supplied_id, source)
  supplied_key[is.na(supplied_id)] <- NA_character_
  repeated <- supplied_key[!is.na(supplied_key) & duplicated(supplied_key)]
  target <- match(key(links[linked], source[linked]), supplied_key)
  unique_target <- !is.na(target) & !supplied_key[target] %in% repeated
  links[linked[unique_target]] <- fact_id[target[unique_target]]
  links
}

# The one trading-status validator: half-open intervals, the correction
# graph and tied-source conflicts, on resolved instants. The correction
# lineage is built once here and shared by both graph checks; a family
# without supersession builds none.
ledgr_fact_validate_status_rows <- function(rows, intervals = TRUE) {
  if (isTRUE(intervals)) {
    ledgr_fact_validate_intervals(
      rows$effective_from,
      rows$effective_to,
      "trading status"
    )
  }
  lineage <- ledgr_fact_validate_status_supersession(rows)
  ledgr_fact_validate_source_conflicts(rows, lineage)
  invisible(TRUE)
}

# Validates every supersession link at once and returns the correction
# lineage, or NULL when no row supersedes another.
ledgr_fact_validate_status_supersession <- function(rows) {
  superseded <- rows$supersedes_fact_id
  supplied <- !is.na(superseded)
  if (!any(supplied)) return(invisible(NULL))
  successor <- which(supplied)
  target <- match(superseded[successor], rows$fact_id)
  if (anyNA(target)) {
    rlang::abort("Trading-status supersession references an unknown fact.", class = c("ledgr_fact_invalid_supersession", "ledgr_invalid_args"))
  }
  if (any(rows$source[successor] != rows$source[target]) ||
      any(rows$instrument_id[successor] != rows$instrument_id[target])) {
    rlang::abort(
      "Trading-status supersession must stay within one source and instrument.",
      class = c("ledgr_fact_invalid_supersession", "ledgr_invalid_args")
    )
  }
  successor_known <- as.numeric(rows$knowledge_time[successor])
  predecessor_known <- as.numeric(rows$knowledge_time[target])
  if (anyNA(successor_known) || anyNA(predecessor_known) ||
      any(successor_known < predecessor_known)) {
    rlang::abort(
      "A trading-status successor cannot be knowable before its predecessor.",
      class = c("ledgr_fact_invalid_supersession", "ledgr_invalid_args")
    )
  }
  predecessor_end <- as.numeric(rows$effective_to[target])
  successor_end <- as.numeric(rows$effective_to[successor])
  open_predecessor <- is.na(predecessor_end)
  begins_in_time <- open_predecessor |
    as.numeric(rows$effective_from[successor]) <= predecessor_end
  covers_end <- is.na(successor_end) |
    (!open_predecessor & successor_end >= predecessor_end)
  if (!all(begins_in_time & covers_end)) {
    rlang::abort(
      paste(
        "A trading-status successor must start no later than its",
        "predecessor ends and cover the predecessor through that end."
      ),
      class = c("ledgr_fact_invalid_supersession", "ledgr_invalid_args")
    )
  }
  ledgr_status_lineage(rows)
}

# Correction-chain lineage: the parent row of each fact and preorder
# entry/exit numbers, so `a` is an ancestor of `d` when a's interval
# encloses d's (ledgr_status_is_ancestor()). Children are held in CSR form
# (`child`, offsets `child_start`, counts `child_count`) and read by integer
# index. Roots and children are visited in increasing row order. A family
# without supersession returns its trivial numbering without a walk.
ledgr_status_lineage <- function(rows) {
  count <- nrow(rows)
  parent <- match(rows$supersedes_fact_id, rows$fact_id)
  if (count == 0L) {
    return(list(parent = parent, entry = integer(), exit = integer()))
  }
  has_parent <- !is.na(parent)
  if (!any(has_parent)) {
    trivial <- seq_len(count)
    return(list(parent = parent, entry = trivial, exit = trivial))
  }
  child <- which(has_parent)
  child <- child[order(parent[child], method = "radix")]
  child_count <- tabulate(parent[has_parent], nbins = count)
  child_start <- cumsum(c(1L, child_count[-count]))

  # Breadth-first levels from the roots. The loop runs once per level of
  # the deepest correction chain, not per row; each level is one vectorised
  # step. Every level holds its nodes grouped by parent in row order.
  levels <- list()
  level <- which(!has_parent)
  reached <- logical(count)
  while (length(level) > 0L) {
    reached[level] <- TRUE
    levels[[length(levels) + 1L]] <- level
    parents <- level[child_count[level] > 0L]
    level <- child[sequence(child_count[parents], from = child_start[parents])]
  }
  if (!all(reached)) {
    rlang::abort(
      "Trading-status supersession must be acyclic.",
      class = c("ledgr_fact_invalid_supersession", "ledgr_invalid_args")
    )
  }

  # Subtree sizes bottom-up, then preorder entry numbers top-down; both
  # read each level as runs of siblings that share a parent.
  size <- rep(1L, count)
  for (depth in rev(seq_along(levels))[-length(levels)]) {
    nodes <- levels[[depth]]
    run_end <- c(parent[nodes][-1L] != parent[nodes][-length(nodes)], TRUE)
    total <- cumsum(size[nodes])[run_end]
    size[parent[nodes][run_end]] <- size[parent[nodes][run_end]] +
      diff(c(0L, total))
  }
  entry <- integer(count)
  roots <- levels[[1L]]
  entry[roots] <- cumsum(size[roots]) - size[roots] + 1L
  for (depth in seq_along(levels)[-1L]) {
    nodes <- levels[[depth]]
    owner <- parent[nodes]
    run_start <- c(TRUE, owner[-1L] != owner[-length(owner)])
    before <- cumsum(size[nodes]) - size[nodes]
    sibling_offset <- before - before[run_start][cumsum(run_start)]
    entry[nodes] <- entry[owner] + 1L + sibling_offset
  }
  list(parent = parent, entry = entry, exit = entry + size - 1L)
}

ledgr_status_is_ancestor <- function(lineage, ancestor, descendant) {
  ancestor != descendant &
    lineage$entry[ancestor] <= lineage$entry[descendant] &
    lineage$exit[ancestor] >= lineage$exit[descendant]
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
  state_levels <- sort(unique(states), method = "radix")
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

# One source may not assert different statuses over overlapping intervals at
# one precedence unless one row supersedes the other. Rows outside every
# correction chain take the grouped opposing-state sweep. When chains exist,
# all rows are checked by counting instead of pairing:
# ledgr_fact_status_unrelated_overlap(). `lineage` is
# ledgr_status_lineage(rows) when the caller already built it.
ledgr_fact_validate_source_conflicts <- function(rows, lineage = NULL) {
  states <- ledgr_fact_nonmissing_states(rows, "status")
  if (nrow(rows) < 2L) return(invisible(TRUE))
  superseded <- as.character(rows$supersedes_fact_id)
  supplied <- !is.na(superseded) & nzchar(superseded)
  involved <- supplied | rows$fact_id %in% superseded[supplied]
  scope_columns <- c("instrument_id", "source", "precedence")
  conflict <- ledgr_fact_opposing_state_overlap(
    rows[!involved, , drop = FALSE],
    scope_columns,
    "status"
  )
  if (!conflict && any(involved)) {
    if (is.null(lineage)) lineage <- ledgr_status_lineage(rows)
    conflict <- ledgr_fact_status_unrelated_overlap(
      rows,
      states,
      scope_columns,
      lineage
    )
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

# TRUE when two rows of one (instrument, source, precedence) scope assert
# different statuses over overlapping intervals without either superseding
# the other. Every ordered pair with different statuses that overlaps is
# counted by binary search over sorted interval bounds; the ordered pairs in
# which one row is an ancestor of the other are counted by walking each
# correction chain once; an unrelated pair exists exactly when the first
# count exceeds the second. Intervals must already be valid half-open
# intervals.
ledgr_fact_status_unrelated_overlap <- function(rows,
                                               states,
                                               scope_columns,
                                               lineage) {
  count <- nrow(rows)
  scope <- ledgr_fact_scope_group(rows, scope_columns)
  starts <- as.numeric(rows$effective_from)
  ends <- as.numeric(rows$effective_to)
  ends[is.na(ends)] <- Inf
  levels <- sort(unique(states), method = "radix")
  state <- match(states, levels)

  # Interval bounds become integer ranks so a (scope, state, bound) key is
  # one exactly representable number: key = group * width + rank.
  bounds <- sort(unique(c(starts, ends)), method = "radix")
  start_rank <- match(starts, bounds)
  end_rank <- match(ends, bounds)
  width <- length(bounds) + 1
  group <- (scope - 1) * length(levels) + state
  start_key <- sort(group * width + start_rank, method = "radix")
  end_key <- sort(group * width + end_rank, method = "radix")

  # Ordered pairs (i, j) in one scope with different states that overlap:
  # j starts before i ends, minus those j that end at or before i starts.
  # The loop runs over the fixed status vocabulary, not over rows.
  opposing <- 0
  for (other in seq_along(levels)) {
    query <- which(state != other)
    if (length(query) == 0L) next
    base <- ((scope[query] - 1) * length(levels) + other) * width
    begun <- findInterval(base + end_rank[query] - 0.5, start_key) -
      findInterval(base + 0.5, start_key)
    ended <- findInterval(base + start_rank[query], end_key) -
      findInterval(base + 0.5, end_key)
    opposing <- opposing + sum(as.numeric(begun - ended))
  }
  if (opposing == 0) return(FALSE)

  # Ordered pairs related by supersession with the same properties. Each
  # step moves every row one link up its correction chain, so the loop runs
  # once per level of the deepest chain and visits each ancestor pair once.
  related <- 0
  descendant <- which(!is.na(lineage$parent))
  ancestor <- lineage$parent[descendant]
  while (length(descendant) > 0L) {
    counted <- scope[ancestor] == scope[descendant] &
      state[ancestor] != state[descendant] &
      starts[ancestor] < ends[descendant] &
      starts[descendant] < ends[ancestor]
    related <- related + 2 * sum(counted)
    ancestor <- lineage$parent[ancestor]
    keep <- !is.na(ancestor)
    descendant <- descendant[keep]
    ancestor <- ancestor[keep]
  }
  opposing > related
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

  effective_start <- as.numeric(rows$effective_from)
  knowledge_start <- as.numeric(rows$knowledge_time)
  ends <- as.numeric(rows$effective_to)
  ends[is.na(ends)] <- Inf
  usable <- is.finite(effective_start) & is.finite(knowledge_start) &
    effective_start < ends
  if (sum(usable) < 2L) return(character())

  lineage <- ledgr_status_lineage(rows)
  conflicting <- logical(nrow(rows))
  for (instrument_id in unique(rows$instrument_id[usable])) {
    candidates <- which(usable & rows$instrument_id == instrument_id)
    boundaries <- sort(unique(c(
      effective_start[candidates],
      knowledge_start[candidates],
      ends[candidates][is.finite(ends[candidates])]
    )))
    for (boundary in boundaries) {
      active <- candidates[
        effective_start[candidates] <= boundary &
          knowledge_start[candidates] <= boundary &
          boundary < ends[candidates]
      ]
      if (length(active) < 2L) next
      superseded <- vapply(active, function(candidate) {
        any(ledgr_status_is_ancestor(lineage, candidate, active))
      }, logical(1))
      active <- active[!superseded]
      if (length(active) < 2L) next
      top <- active[rows$precedence[active] == max(rows$precedence[active])]
      if (length(unique(rows$status[top])) > 1L) {
        conflicting[top] <- TRUE
      }
    }
  }
  unique(rows$fact_id[conflicting])
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
