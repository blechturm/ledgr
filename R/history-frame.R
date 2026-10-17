# Public causal history (v12 Section 3). One immutable `ledgr_history` result
# is built from the shared substrate; the matrix adapter and the structural
# sufficiency query read that result and own no cutoff, axis, treatment or
# missingness logic of their own.

ledgr_history_bar_fields <- function() {
  c("open", "high", "low", "close", "volume")
}

ledgr_history_memo <- function(substrate) {
  memo <- substrate$history_memo
  if (!is.environment(memo)) {
    rlang::abort(
      "History reads require a substrate with its prepared-plane memo.",
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_fold_execution")
    )
  }
  memo
}

# Late-known lifetime or terminal segments (knowledge after the first column
# they describe) are the only source of cutoff dependence in the treatment
# masks. For each instrument, return the sorted distinct knowledge instants of
# such segments; an instrument without one has a cutoff-invariant mask.
ledgr_history_late_epochs <- function(substrate) {
  memo <- ledgr_history_memo(substrate)
  if (!is.null(memo$late_epochs)) return(memo$late_epochs)
  n_inst <- length(substrate$instrument_ids)
  axis <- as.numeric(substrate$axis)
  n_axis <- length(axis)
  instrument <- integer()
  knowledge <- numeric()
  for (family in c("lifetime", "lifetime_terminal")) {
    segments <- substrate$segments[[family]]
    if (is.null(segments) || length(segments$instrument) == 0L) next
    from <- segments$observation_from
    covers <- from >= 1L & from <= n_axis & segments$observation_to > from
    late <- covers & is.finite(segments$knowledge_from)
    late[late] <- segments$knowledge_from[late] > axis[from[late]]
    instrument <- c(instrument, segments$instrument[late])
    knowledge <- c(knowledge, segments$knowledge_from[late])
  }
  out <- vector("list", n_inst)
  if (length(instrument) > 0L) {
    keep <- !duplicated(data.frame(instrument, knowledge))
    grouped <- split(knowledge[keep], factor(instrument[keep], levels = seq_len(n_inst)))
    out <- lapply(grouped, function(x) sort(unique(x), method = "radix"))
    names(out) <- NULL
  }
  memo$late_epochs <- out
  out
}

# Masks at one knowledge instant over the whole prepared axis, through the
# shared lifetime and terminal resolvers. Only instruments with a segment that
# can change the default (a known_inactive lifetime state or an asserted
# terminal state) are resolved; every other instrument is expected throughout
# and has no terminal column.
ledgr_history_prepare_masks <- function(substrate, knowledge, instrument_idx, block = 64L) {
  n_axis <- length(substrate$axis)
  n_rows <- length(instrument_idx)
  all_columns <- seq_len(n_axis)
  expected <- matrix(TRUE, nrow = n_rows, ncol = n_axis)
  terminal_first <- rep.int(n_axis + 1L, n_rows)
  if (n_rows == 0L || n_axis == 0L) {
    return(list(expected = expected, terminal_first = terminal_first))
  }
  candidates <- function(family, test) {
    segments <- substrate$segments[[family]]
    if (is.null(segments) || length(segments$instrument) == 0L) return(integer())
    states <- segments$state_levels[segments$state]
    which(instrument_idx %in% unique(segments$instrument[test(states)]))
  }
  blocks <- function(rows) split(rows, ceiling(seq_along(rows) / block))
  for (rows in blocks(candidates("lifetime", function(x) x == "known_inactive"))) {
    expected[rows, ] <- ledgr_history_substrate_expected_at(
      substrate, knowledge, all_columns, instrument_idx[rows]
    )
  }
  for (rows in blocks(candidates("lifetime_terminal", nzchar))) {
    terminal <- ledgr_history_substrate_terminal_at(
      substrate, knowledge, all_columns, instrument_idx[rows]
    )
    terminal_first[rows] <- as.integer(n_axis + 1L - rowSums(terminal))
  }
  list(expected = expected, terminal_first = terminal_first)
}

# Carry positions for one field over the whole prepared axis, through the
# treatment primitive, in bounded instrument blocks.
ledgr_history_prepare_positions <- function(substrate, masks, instrument_idx, field,
                                            block = 128L) {
  n_axis <- length(substrate$axis)
  n_rows <- length(instrument_idx)
  source <- matrix(NA_integer_, nrow = n_rows, ncol = n_axis)
  last_barrier <- matrix(NA_integer_, nrow = n_rows, ncol = n_axis)
  if (n_rows == 0L || n_axis == 0L) {
    return(list(source = source, last_barrier = last_barrier))
  }
  all_columns <- seq_len(n_axis)
  for (start in seq.int(1L, n_rows, by = block)) {
    rows <- seq.int(start, min(n_rows, start + block - 1L))
    terminal <- outer(masks$terminal_first[rows], all_columns, "<=")
    dim(terminal) <- c(length(rows), n_axis)
    positions <- ledgr_history_carry_positions(
      is.finite(substrate$bars[[field]][instrument_idx[rows], , drop = FALSE]),
      masks$expected[rows, , drop = FALSE],
      terminal
    )
    source[rows, ] <- positions$source
    last_barrier[rows, ] <- positions$last_barrier
  }
  list(source = source, last_barrier = last_barrier)
}

# Cutoff-invariant masks and per-field carry positions for every instrument,
# prepared once per substrate on first use. Instruments with late-known
# lifetime or terminal facts are answered from per-epoch overlays.
ledgr_history_memo_value <- function(memo, key, build) {
  value <- memo[[key]]
  if (is.null(value)) {
    value <- build()
    assign(key, value, envir = memo)
    counter <- paste0("builds_", sub("_.*$", "", key))
    assign(counter, (memo[[counter]] %||% 0L) + 1L, envir = memo)
  }
  value
}

ledgr_history_base_masks <- function(substrate) {
  ledgr_history_memo_value(ledgr_history_memo(substrate), "base_masks", function() {
    ledgr_history_prepare_masks(
      substrate, as.POSIXct(Inf, tz = "UTC"), seq_along(substrate$instrument_ids)
    )
  })
}

ledgr_history_base_positions <- function(substrate, field) {
  ledgr_history_memo_value(ledgr_history_memo(substrate), paste0("base_", field), function() {
    ledgr_history_prepare_positions(
      substrate, ledgr_history_base_masks(substrate),
      seq_along(substrate$instrument_ids), field
    )
  })
}

# Epoch j of an instrument holds every fact known before its next late
# knowledge instant. Whole-second clocks put half a second strictly between
# two instants.
ledgr_history_overlay_masks <- function(substrate, instrument, epoch, epochs) {
  key <- paste0("overlay_", instrument, "_", epoch)
  ledgr_history_memo_value(ledgr_history_memo(substrate), key, function() {
    knowledge <- as.POSIXct(epochs[[epoch + 1L]] - 0.5, tz = "UTC")
    ledgr_history_prepare_masks(substrate, knowledge, instrument)
  })
}

ledgr_history_overlay_positions <- function(substrate, instrument, epoch, epochs, field) {
  key <- paste0("overlay_", instrument, "_", epoch, "_", field)
  ledgr_history_memo_value(ledgr_history_memo(substrate), key, function() {
    ledgr_history_prepare_positions(
      substrate,
      ledgr_history_overlay_masks(substrate, instrument, epoch, epochs),
      instrument,
      field
    )
  })
}

# Masks and carry positions for `rows` x `columns` at the cutoff column.
ledgr_history_cutoff_planes <- function(substrate, field, rows, columns, cutoff_col) {
  late <- ledgr_history_late_epochs(substrate)
  cutoff <- as.numeric(substrate$axis[[cutoff_col]])
  masks <- ledgr_history_base_masks(substrate)
  expected <- masks$expected[rows, columns, drop = FALSE]
  terminal_first <- masks$terminal_first[rows]
  last_barrier <- source <- NULL
  if (!is.null(field)) {
    positions <- ledgr_history_base_positions(substrate, field)
    last_barrier <- positions$last_barrier[rows, columns, drop = FALSE]
    source <- positions$source[rows, columns, drop = FALSE]
  }
  for (r in which(lengths(late[rows]) > 0L)) {
    instrument <- rows[[r]]
    epochs <- late[[instrument]]
    epoch <- findInterval(cutoff, epochs)
    if (epoch >= length(epochs)) next
    overlay <- ledgr_history_overlay_masks(substrate, instrument, epoch, epochs)
    expected[r, ] <- overlay$expected[1L, columns]
    terminal_first[[r]] <- overlay$terminal_first[[1L]]
    if (!is.null(field)) {
      overlay <- ledgr_history_overlay_positions(substrate, instrument, epoch, epochs, field)
      last_barrier[r, ] <- overlay$last_barrier[1L, columns]
      source[r, ] <- overlay$source[1L, columns]
    }
  }
  terminal <- outer(terminal_first, columns, "<=")
  dim(terminal) <- c(length(rows), length(columns))
  list(
    expected = expected,
    terminal = terminal,
    last_barrier = last_barrier,
    source = source
  )
}

ledgr_history_bar_evidence <- function(substrate, field, rows, columns, cutoff_col) {
  planes <- ledgr_history_cutoff_planes(substrate, field, rows, columns, cutoff_col)
  stored <- substrate$bars[[field]]
  raw <- stored[rows, columns, drop = FALSE]
  column <- matrix(
    rep(as.integer(columns), each = length(rows)),
    nrow = length(rows),
    ncol = length(columns)
  )
  # Carried values are read by linear index from the stored plane; no
  # instrument's whole prefix is copied per read.
  source_value <- matrix(NA_real_, nrow = length(rows), ncol = length(columns))
  hit <- !is.na(planes$source)
  if (any(hit)) {
    stored_row <- matrix(rows, nrow = length(rows), ncol = length(columns))
    source_value[hit] <- stored[
      stored_row[hit] + (planes$source[hit] - 1L) * nrow(stored)
    ]
  }
  evidence <- ledgr_history_carry_evidence(
    value = raw,
    observed = is.finite(raw),
    expected = planes$expected,
    terminal_barrier = planes$terminal,
    source = planes$source,
    last_barrier = planes$last_barrier,
    source_value = source_value,
    column = column,
    axis = substrate$axis,
    max_sessions = substrate$history_policy$price_carry,
    carry_allowed = !identical(field, "volume")
  )
  # v12 Section 4: a print inside a knowable inactive interval stays readable
  # through bar history, flagged as structural and never calculation-valid.
  inactive_print <- !evidence$expected & evidence$observed
  evidence$value[inactive_print] <- raw[inactive_print]
  evidence$source_index <- planes$source
  evidence
}

# Feature cells read the shared feature projection. Until the indicator
# history semantics land (Workstream 43), feature values carry no input or
# output carry and readiness equals calculation; masks still come from the
# cutoff-resolved lifetime and terminal planes.
ledgr_history_feature_evidence <- function(substrate, feature_id, rows, columns, cutoff_col) {
  planes <- ledgr_history_cutoff_planes(substrate, NULL, rows, columns, cutoff_col)
  values <- substrate$feature_projection$feature_values[[feature_id]]
  value <- values[rows, columns, drop = FALSE]
  dimnames(value) <- NULL
  n_rows <- length(rows)
  n_cols <- length(columns)
  calculated <- is.finite(value)
  observed <- substrate$bars$observed[rows, columns, drop = FALSE]
  expected <- planes$expected
  axis_value <- matrix(
    rep(as.numeric(substrate$axis)[columns], each = n_rows),
    nrow = n_rows,
    ncol = n_cols
  )
  source_time <- axis_value
  source_time[!calculated] <- NA_real_
  age <- matrix(0L, nrow = n_rows, ncol = n_cols)
  age[!calculated] <- NA_integer_
  reason <- matrix("", nrow = n_rows, ncol = n_cols)
  reason[!calculated & expected] <- "not_calculated"
  reason[!calculated & !expected] <- "not_expected"
  barrier_reason <- matrix("", nrow = n_rows, ncol = n_cols)
  barrier_reason[!expected] <- "lifetime_inactive"
  barrier_reason[planes$terminal] <- "terminal"
  no <- matrix(FALSE, nrow = n_rows, ncol = n_cols)
  list(
    value = value,
    expected = expected,
    observed = observed,
    is_missing = expected & !observed,
    input_carried = no,
    calculated = calculated,
    output_carried = no,
    source_ts_utc = source_time,
    carry_age_sessions = age,
    ready = calculated,
    calculation_valid = calculated,
    missing_reason = reason,
    barrier_reason = barrier_reason,
    source_index = NULL
  )
}

ledgr_history_cell_fields <- function() {
  c(
    "expected", "observed", "is_missing", "input_carried", "calculated",
    "output_carried", "source_ts_utc", "carry_age_sessions", "ready",
    "calculation_valid", "missing_reason", "barrier_reason"
  )
}

# A read service over one substrate, prepared once per fold (or inspection)
# with that consumer's registered features and active aliases.
ledgr_history_read_service <- function(substrate,
                                       feature_defs = list(),
                                       active_alias_map = NULL) {
  ledgr_history_substrate_require(substrate)
  feature_ids <- if (length(feature_defs) > 0L) {
    vapply(feature_defs, function(def) def$id, character(1))
  } else {
    character()
  }
  structure(
    list(
      substrate = substrate,
      feature_defs = stats::setNames(feature_defs, feature_ids),
      feature_names = ledgr_feature_name_lookup_state(
        feature_ids,
        active_alias_map = active_alias_map
      )
    ),
    class = "ledgr_history_read_service"
  )
}

ledgr_history_view <- function(service, cutoff_col) {
  structure(
    list(service = service, cutoff_col = as.integer(cutoff_col)),
    class = "ledgr_history_view"
  )
}

ledgr_history_feature_width <- function(definition) {
  # Strict availability windows hand each calculation `stable_after` rows.
  if (identical(definition$gap_contract, "strict_window") &&
      is.numeric(definition$stable_after) && length(definition$stable_after) == 1L &&
      is.finite(definition$stable_after)) {
    return(as.integer(definition$stable_after))
  }
  NA_integer_
}

ledgr_history_request_error <- function(message) {
  rlang::abort(
    message,
    class = c("ledgr_invalid_history_request", "ledgr_invalid_args")
  )
}

ledgr_history_validate_lookback <- function(lookback) {
  if (!is.numeric(lookback) || length(lookback) != 1L || is.na(lookback) ||
      lookback < 0 || (is.finite(lookback) &&
        (lookback != floor(lookback) || lookback > .Machine$integer.max))) {
    ledgr_history_request_error(
      "`lookback` must be Inf or a non-negative whole number of expected sessions."
    )
  }
  if (is.finite(lookback)) as.integer(lookback) else Inf
}

ledgr_history_choice <- function(value, choices, argument) {
  if (!is.character(value) || length(value) < 1L || anyNA(value)) {
    ledgr_history_request_error(sprintf("`%s` must be one of %s.", argument,
      paste(sprintf("\"%s\"", choices), collapse = ", ")))
  }
  if (length(value) > 1L) {
    if (identical(value, choices)) return(choices[[1L]])
    ledgr_history_request_error(sprintf("`%s` must be one of %s.", argument,
      paste(sprintf("\"%s\"", choices), collapse = ", ")))
  }
  if (!value %in% choices) {
    ledgr_history_request_error(sprintf("`%s` must be one of %s.", argument,
      paste(sprintf("\"%s\"", choices), collapse = ", ")))
  }
  value
}

ledgr_history_context_view <- function(ctx) {
  view <- if (is.environment(ctx) || is.list(ctx)) ctx[[".history"]] else NULL
  if (!inherits(ctx, "ledgr_pulse_context") || !inherits(view, "ledgr_history_view")) {
    rlang::abort(
      paste(
        "Causal history is available only in an availability-aware pulse",
        "context: a run, sweep or walk-forward strategy context, or",
        "ledgr_pulse_snapshot() called with a ledgr_experiment. Dense",
        "contexts and the snapshot-and-universe pulse form have no history."
      ),
      class = c("ledgr_history_unavailable", "ledgr_invalid_args")
    )
  }
  view
}

#' Read causal history from a strategy context
#'
#' `ledgr_history_frame()` returns one immutable `ledgr_history` result for one
#' bar field or one registered feature, read causally at the context's pulse.
#' Every returned value is observed at or before that cutoff, with facts known
#' by it. History is available in availability-aware contexts only: strategy
#' contexts of availability-aware runs, sweeps and walk-forward windows, and
#' [ledgr_pulse_snapshot()] called with a `ledgr_experiment`.
#'
#' The time axis is the declared venue's expected sessions from the data start
#' (the first session of the experiment's snapshot) through the cutoff. A
#' finite `lookback` keeps the last `lookback` sessions of that axis and is an
#' exact suffix of the full (`Inf`) result, including carried values whose
#' source lies before the window. Each instrument has its own expected-session
#' mask on the common axis: a lifetime-inactive session is structural, not a
#' missing observation, and a print inside such an interval stays readable
#' with that structural flag.
#'
#' Bar values follow the experiment's [ledgr_history_policy()]: open, high,
#' low and close carry forward within the declared expected-session horizon;
#' volume never carries. Carried cells are disclosed in the evidence.
#'
#' `instruments = "admissible"` selects the decision-axis instruments that are
#' admissible at the cutoff, `"decision_axis"` adds held nonmembers and
#' restricted members, and a character vector requests known instrument IDs
#' explicitly; unknown IDs refuse and known IDs are never dropped for current
#' inadmissibility. `na_action = "drop_instruments"` excludes requested
#' instruments whose window is incomplete after treatment from the estimator
#' sample and records the reason. Exclusion is estimation only: it creates no
#' target, zero target, liquidation or fill. The strategy still returns a
#' target for every instrument on its decision axis.
#'
#' @param ctx A pulse context.
#' @param feature One active feature alias or registered feature ID.
#' @param bar One bar field: `"open"`, `"high"`, `"low"`, `"close"` or
#'   `"volume"`. Supply exactly one of `feature` and `bar`.
#' @param lookback `Inf` for all history from the data start, or a
#'   non-negative whole number of expected venue sessions ending at the cutoff.
#' @param instruments `"admissible"`, `"decision_axis"`, or a character
#'   vector of known instrument IDs.
#' @param na_action `"keep"` keeps every requested instrument;
#'   `"drop_instruments"` excludes requested instruments with incomplete
#'   values in the window.
#' @param layout `"wide"` (one row per session, `ts_utc` plus one column per
#'   included instrument) or `"long"` (one row per session and instrument with
#'   `ts_utc`, `instrument_id`, `source`, `value` and the cell evidence).
#' @return A `ledgr_history` data frame. Its `"ledgr_history"` attribute
#'   records the data start, returned-window start and cutoff, requested and
#'   available lookback, source and policy identity, the selection table
#'   (requested, included and excluded instruments with reasons and carried
#'   input counts), whether any value used observations before the window,
#'   and, for the wide layout, the aligned cell evidence matrices.
#' @seealso [ledgr_history_matrix()], [ledgr_history_sufficient()],
#'   [ledgr_history_policy()]
#' @examples
#' \dontrun{
#' strategy <- function(ctx, params) {
#'   returns <- ctx |>
#'     ledgr_history_frame(feature = "return_1", lookback = 20L,
#'                         na_action = "drop_instruments")
#'   x <- ledgr_history_matrix(returns)
#'   ctx$hold()
#' }
#' }
#' @export
ledgr_history_frame <- function(ctx,
                                feature = NULL,
                                bar = NULL,
                                lookback = Inf,
                                instruments = "admissible",
                                na_action = c("keep", "drop_instruments"),
                                layout = c("wide", "long")) {
  view <- ledgr_history_context_view(ctx)
  if (is.null(feature) == is.null(bar)) {
    ledgr_history_request_error("Supply exactly one of `feature` and `bar`.")
  }
  name <- if (is.null(feature)) bar else feature
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) {
    ledgr_history_request_error("`feature` or `bar` must be one non-empty name.")
  }
  if (!is.null(bar) && !bar %in% ledgr_history_bar_fields()) {
    rlang::abort(
      "History bar field must be one of open, high, low, close or volume.",
      class = c("ledgr_invalid_history_field", "ledgr_invalid_args")
    )
  }
  lookback <- ledgr_history_validate_lookback(lookback)
  na_action <- ledgr_history_choice(na_action, c("keep", "drop_instruments"), "na_action")
  layout <- ledgr_history_choice(layout, c("wide", "long"), "layout")
  ledgr_history_read(
    view = view,
    kind = if (is.null(bar)) "feature" else "bar",
    name = name,
    lookback = lookback,
    instruments = instruments,
    na_action = na_action,
    layout = layout,
    decision_ids = as.character(ctx$universe),
    decision_planes = ctx$vec
  )
}

ledgr_history_selection_ids <- function(instruments, substrate, decision_ids, admissible) {
  if (is.character(instruments) && length(instruments) == 1L && !is.na(instruments) &&
      instruments %in% c("admissible", "decision_axis")) {
    ids <- if (identical(instruments, "admissible")) decision_ids[admissible] else decision_ids
    return(list(mode = instruments, ids = ids))
  }
  if (!is.character(instruments) || anyNA(instruments) || any(!nzchar(instruments)) ||
      anyDuplicated(instruments)) {
    ledgr_history_request_error(
      "`instruments` must be \"admissible\", \"decision_axis\" or unique known instrument IDs."
    )
  }
  unknown <- instruments[is.na(match(instruments, substrate$instrument_ids))]
  if (length(unknown) > 0L) {
    rlang::abort(
      sprintf(
        "Unknown history instrument_id(s): %s.",
        paste(unknown, collapse = ", ")
      ),
      class = c("ledgr_history_unknown_instrument", "ledgr_invalid_args"),
      instrument_ids = unknown
    )
  }
  list(mode = "explicit", ids = instruments)
}

ledgr_history_read <- function(view,
                               kind,
                               name,
                               lookback,
                               instruments,
                               na_action,
                               layout,
                               decision_ids,
                               decision_planes) {
  service <- view$service
  substrate <- service$substrate
  cutoff_col <- view$cutoff_col
  n_axis <- length(substrate$axis)
  if (length(cutoff_col) != 1L || is.na(cutoff_col) || cutoff_col < 1L ||
      cutoff_col > n_axis) {
    rlang::abort(
      "The history cutoff is outside the prepared venue axis.",
      class = c("ledgr_history_outside_axis", "ledgr_invalid_args")
    )
  }
  source_id <- if (identical(kind, "bar")) {
    name
  } else {
    ledgr_resolve_feature_name(name, service$feature_names)
  }
  if (identical(kind, "feature") &&
      is.null(substrate$feature_projection$feature_values[[source_id]])) {
    rlang::abort(
      sprintf("Feature `%s` has no prepared history.", source_id),
      class = "ledgr_unknown_feature_id"
    )
  }
  admissible <- as.logical(decision_planes$admissible)
  if (length(admissible) != length(decision_ids) || anyNA(admissible)) {
    rlang::abort(
      "History selection requires the context's admissible plane.",
      class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
    )
  }
  selection <- ledgr_history_selection_ids(instruments, substrate, decision_ids, admissible)
  requested_ids <- selection$ids
  rows <- unname(substrate$instrument_index[requested_ids])
  if (length(rows) == 0L) rows <- integer()
  first_col <- if (is.finite(lookback)) cutoff_col - lookback + 1L else 1L
  first_col <- max(1L, first_col)
  columns <- if (first_col <= cutoff_col) seq.int(first_col, cutoff_col) else integer()
  evidence <- if (identical(kind, "bar")) {
    ledgr_history_bar_evidence(substrate, source_id, rows, columns, cutoff_col)
  } else {
    ledgr_history_feature_evidence(substrate, source_id, rows, columns, cutoff_col)
  }
  admission <- ledgr_history_estimator_admission(
    list(
      calculation_valid = evidence$calculation_valid,
      input_carried = evidence$input_carried,
      barrier_reason = evidence$barrier_reason,
      missing_reason = evidence$missing_reason
    ),
    requested = rep(TRUE, length(rows))
  )
  included <- if (identical(na_action, "drop_instruments")) {
    admission$included
  } else {
    rep(TRUE, length(rows))
  }
  exclusion_reason <- if (identical(na_action, "drop_instruments")) {
    admission$exclusion_reason
  } else {
    rep("", length(rows))
  }

  window_start <- if (length(columns) > 0L) substrate$axis[[columns[[1L]]]] else
    as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
  keep <- which(included)
  used_before <- ledgr_history_used_before_window(
    kind, evidence, keep, columns, service$feature_defs[[source_id]]
  )
  selection_table <- ledgr_history_selection_table(
    requested_ids = requested_ids,
    included = included,
    exclusion_reason = exclusion_reason,
    admission = admission,
    decision_ids = decision_ids,
    decision_planes = decision_planes
  )
  axis <- substrate$axis[columns]
  ids <- requested_ids[keep]
  all_kept <- length(keep) == length(rows)
  value <- if (all_kept) evidence$value else evidence$value[keep, , drop = FALSE]
  cells <- lapply(
    stats::setNames(ledgr_history_cell_fields(), ledgr_history_cell_fields()),
    function(field) {
      if (all_kept) evidence[[field]] else evidence[[field]][keep, , drop = FALSE]
    }
  )
  source_label <- paste0(kind, ":", source_id)
  meta <- list(
    source = list(kind = kind, name = name, id = source_id, label = source_label),
    snapshot_hash = substrate$snapshot_hash,
    policy_identity = substrate$policy_identity,
    data_start_utc = substrate$data_start_utc,
    window_start_utc = window_start,
    cutoff_utc = substrate$axis[[cutoff_col]],
    requested_lookback = lookback,
    available_lookback = length(columns),
    instruments = selection$mode,
    na_action = na_action,
    layout = layout,
    axis = axis,
    instrument_ids = ids,
    selection = selection_table,
    used_before_window = used_before
  )
  if (identical(layout, "wide")) {
    ledgr_history_wide(value, cells, axis, ids, meta)
  } else {
    ledgr_history_long(value, cells, axis, ids, source_label, meta)
  }
}

ledgr_history_used_before_window <- function(kind, evidence, keep, columns, definition) {
  if (length(keep) == 0L || length(columns) == 0L) return(FALSE)
  if (identical(kind, "bar")) {
    source <- evidence$source_index[keep, , drop = FALSE]
    carried <- evidence$input_carried[keep, , drop = FALSE]
    return(any(carried & !is.na(source) & source < columns[[1L]]))
  }
  calculated <- evidence$calculated[keep, , drop = FALSE]
  width <- ledgr_history_feature_width(definition)
  if (is.na(width)) {
    return(columns[[1L]] > 1L && any(calculated))
  }
  dependent <- columns - width + 1L < columns[[1L]]
  any(calculated[, dependent, drop = FALSE])
}

ledgr_history_selection_table <- function(requested_ids,
                                          included,
                                          exclusion_reason,
                                          admission,
                                          decision_ids,
                                          decision_planes) {
  others <- decision_ids[!decision_ids %in% requested_ids]
  ids <- c(requested_ids, others)
  n_req <- length(requested_ids)
  n_other <- length(others)
  axis_pos <- match(ids, decision_ids)
  on_axis <- !is.na(axis_pos)
  member <- rep(FALSE, length(ids))
  member[on_axis] <- as.logical(decision_planes$member[axis_pos[on_axis]])
  admissible <- rep(FALSE, length(ids))
  admissible[on_axis] <- as.logical(decision_planes$admissible[axis_pos[on_axis]])
  restriction <- rep("", length(ids))
  restriction[on_axis] <- as.character(
    decision_planes$target_restriction_reason[axis_pos[on_axis]]
  )
  reason <- rep("", length(ids))
  reason[!on_axis] <- "not_on_decision_axis"
  reason[on_axis & !member] <- "not_member"
  restricted <- on_axis & member & !admissible
  reason[restricted] <- ifelse(
    nzchar(restriction[restricted]),
    restriction[restricted],
    "target_restricted"
  )
  data.frame(
    instrument_id = ids,
    requested = c(rep(TRUE, n_req), rep(FALSE, n_other)),
    included = c(as.logical(included), rep(FALSE, n_other)),
    exclusion_reason = c(as.character(exclusion_reason), rep("not_requested", n_other)),
    on_decision_axis = on_axis,
    admissible = admissible,
    admissibility_reason = reason,
    required_input_count = c(admission$required_input_count, rep(NA_integer_, n_other)),
    carried_input_count = c(admission$carried_input_count, rep(NA_integer_, n_other)),
    carried_input_share = c(as.numeric(admission$carried_input_share), rep(NA_real_, n_other)),
    stringsAsFactors = FALSE
  )
}

ledgr_history_time_names <- function(axis) {
  ledgr_projection_pulse_names(axis)
}

ledgr_history_wide <- function(value, cells, axis, ids, meta) {
  n_time <- length(axis)
  # Columns are instruments; the stored planes are instrument x session.
  value_t <- t(value)
  dim(value_t) <- c(n_time, length(ids))
  columns <- if (length(ids) > 0L) collapse::mctl(value_t) else list()
  names(columns) <- ids
  out <- c(list(ts_utc = as.POSIXct(axis, tz = "UTC")), columns)
  time_names <- ledgr_history_time_names(axis)
  meta$evidence <- lapply(cells, function(plane) {
    plane_t <- t(plane)
    dim(plane_t) <- c(n_time, length(ids))
    dimnames(plane_t) <- list(time_names, ids)
    plane_t
  })
  structure(
    out,
    names = c("ts_utc", ids),
    row.names = .set_row_names(n_time),
    class = c("ledgr_history", "data.frame"),
    ledgr_history = meta
  )
}

ledgr_history_long <- function(value, cells, axis, ids, source_label, meta) {
  n_time <- length(axis)
  n_ids <- length(ids)
  n <- n_time * n_ids
  flatten <- function(plane) as.vector(plane)
  out <- list(
    ts_utc = as.POSIXct(rep(as.numeric(axis), each = n_ids), origin = "1970-01-01", tz = "UTC"),
    instrument_id = rep(as.character(ids), times = n_time),
    source = rep(source_label, n),
    value = as.numeric(flatten(value))
  )
  for (field in names(cells)) {
    plane <- flatten(cells[[field]])
    if (identical(field, "source_ts_utc")) {
      plane <- as.POSIXct(as.numeric(plane), origin = "1970-01-01", tz = "UTC")
    } else if (identical(field, "carry_age_sessions")) {
      plane <- as.integer(plane)
    } else if (field %in% c("missing_reason", "barrier_reason")) {
      plane <- as.character(plane)
    } else {
      plane <- as.logical(plane)
    }
    out[[field]] <- plane
  }
  structure(
    out,
    row.names = .set_row_names(n),
    class = c("ledgr_history", "data.frame"),
    ledgr_history = meta
  )
}

ledgr_history_require_result <- function(x) {
  meta <- attr(x, "ledgr_history", exact = TRUE)
  if (!inherits(x, "ledgr_history") || !is.data.frame(x) || !is.list(meta)) {
    rlang::abort(
      "`x` must be a ledgr_history result from ledgr_history_frame().",
      class = c("ledgr_invalid_history_result", "ledgr_invalid_args")
    )
  }
  meta
}

#' Convert a history result to an identified matrix
#'
#' `ledgr_history_matrix()` is an adapter over an existing [ledgr_history_frame()]
#' result. It returns the values as a sessions-by-instruments numeric matrix
#' whose row names are the result's session timestamps (ISO 8601 UTC) and whose
#' column names are its included instrument IDs, ready for an ordinary R
#' estimator. It reads no data and owns no cutoff, axis, treatment or
#' missingness logic.
#'
#' @param x A `ledgr_history` result.
#' @return A numeric matrix with `dimnames` equal to the result's session
#'   timestamps and included instrument IDs.
#' @seealso [ledgr_history_frame()]
#' @export
ledgr_history_matrix <- function(x) {
  meta <- ledgr_history_require_result(x)
  axis <- meta$axis
  ids <- as.character(meta$instrument_ids)
  time_names <- ledgr_history_time_names(axis)
  out <- matrix(
    NA_real_,
    nrow = length(axis),
    ncol = length(ids),
    dimnames = list(time_names, ids)
  )
  if (identical(meta$layout, "wide")) {
    if (!identical(names(x), c("ts_utc", ids)) || nrow(x) != length(axis) ||
        !identical(as.numeric(x$ts_utc), as.numeric(axis))) {
      rlang::abort(
        "`x` no longer matches its recorded history axis and instruments.",
        class = c("ledgr_invalid_history_result", "ledgr_invalid_args")
      )
    }
    if (length(ids) > 0L && length(axis) > 0L) {
      out[] <- as.numeric(unlist(unclass(x)[ids], use.names = FALSE))
    }
    return(out)
  }
  row <- match(as.numeric(x$ts_utc), as.numeric(axis))
  col <- match(as.character(x$instrument_id), ids)
  if (anyNA(row) || anyNA(col) || nrow(x) != length(axis) * length(ids) ||
      anyDuplicated(row + (col - 1L) * length(axis))) {
    rlang::abort(
      "`x` no longer matches its recorded history axis and instruments.",
      class = c("ledgr_invalid_history_result", "ledgr_invalid_args")
    )
  }
  out[row + (col - 1L) * length(axis)] <- as.numeric(x$value)
  out
}

#' Check structural sufficiency of a history result
#'
#' `ledgr_history_sufficient()` answers whether a [ledgr_history_frame()]
#' result has at least `lookback` expected sessions and at least
#' `min_instruments` included instruments. It is a structural completeness
#' query on the returned axis and selection only. It is not indicator
#' readiness, warm-up or convergence and does not inspect values.
#'
#' @param x A `ledgr_history` result.
#' @param lookback Required number of expected sessions.
#' @param min_instruments Required number of included instruments.
#' @return `TRUE` or `FALSE`.
#' @seealso [ledgr_history_frame()]
#' @export
ledgr_history_sufficient <- function(x, lookback, min_instruments = 1L) {
  meta <- ledgr_history_require_result(x)
  whole <- function(value, argument) {
    if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
        !is.finite(value) || value < 0 || value != floor(value)) {
      ledgr_history_request_error(
        sprintf("`%s` must be one non-negative whole number.", argument)
      )
    }
    as.integer(value)
  }
  lookback <- whole(lookback, "lookback")
  min_instruments <- whole(min_instruments, "min_instruments")
  isTRUE(as.integer(meta$available_lookback) >= lookback) &&
    isTRUE(length(meta$instrument_ids) >= min_instruments)
}

#' @export
print.ledgr_history <- function(x, ...) {
  meta <- ledgr_history_require_result(x)
  cat("ledgr_history\n")
  cat("Source:    ", meta$source$label, "\n", sep = "")
  cat("Cutoff:    ", ledgr_history_time_names(meta$cutoff_utc), "\n", sep = "")
  cat("Sessions:  ", meta$available_lookback, " of requested ",
      format(meta$requested_lookback), "\n", sep = "")
  selection <- meta$selection
  cat("Included:  ", length(meta$instrument_ids), " of ",
      sum(selection$requested), " requested\n", sep = "")
  cat("Layout:    ", meta$layout, "\n", sep = "")
  frame <- x
  attr(frame, "ledgr_history") <- NULL
  class(frame) <- "data.frame"
  print(utils::head(frame, 10L), ...)
  invisible(x)
}
