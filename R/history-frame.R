# Public causal history (v12 Section 3 and the manifestation amendment).
# Ordinary frame and matrix results are direct sibling manifestations of the
# shared verified substrate; neither owns a separate cutoff, treatment rule,
# value seal or cell-evidence plane.

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
  memo$late_instruments <- as.integer(which(lengths(out) > 0L))
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

# Carry sources for one field over the whole prepared axis, through the
# treatment primitive, in bounded instrument blocks. The last barrier is a
# property of the masks, not of the field: it is kept once per mask
# (ledgr_history_mask_barrier(); audit F04).
ledgr_history_prepare_positions <- function(substrate, masks, instrument_idx, field,
                                            block = 128L) {
  n_axis <- length(substrate$axis)
  n_rows <- length(instrument_idx)
  source <- matrix(NA_integer_, nrow = n_rows, ncol = n_axis)
  if (n_rows == 0L || n_axis == 0L) {
    return(list(source = source))
  }
  all_columns <- seq_len(n_axis)
  for (start in seq.int(1L, n_rows, by = block)) {
    rows <- seq.int(start, min(n_rows, start + block - 1L))
    terminal <- outer(masks$terminal_first[rows], all_columns, "<=")
    dim(terminal) <- c(length(rows), n_axis)
    source[rows, ] <- ledgr_history_carry_source(
      is.finite(substrate$bars[[field]][instrument_idx[rows], , drop = FALSE]),
      masks$expected[rows, , drop = FALSE],
      terminal
    )
  }
  list(source = source)
}

# The terminal last-barrier plane of one mask, shared by every bar field. It
# is added to the mask's memo entry on the first bar-field read, so a
# feature-only reader never builds it.
ledgr_history_mask_barrier <- function(substrate, key, masks, block = 128L) {
  if (!is.null(masks$last_barrier)) return(masks$last_barrier)
  n_rows <- nrow(masks$expected)
  n_axis <- ncol(masks$expected)
  last_barrier <- matrix(NA_integer_, nrow = n_rows, ncol = n_axis)
  if (n_rows > 0L && n_axis > 0L) {
    all_columns <- seq_len(n_axis)
    for (start in seq.int(1L, n_rows, by = block)) {
      rows <- seq.int(start, min(n_rows, start + block - 1L))
      terminal <- outer(masks$terminal_first[rows], all_columns, "<=")
      dim(terminal) <- c(length(rows), n_axis)
      last_barrier[rows, ] <- ledgr_history_carry_last_barrier(
        masks$expected[rows, , drop = FALSE],
        terminal
      )
    }
  }
  masks$last_barrier <- last_barrier
  assign(key, masks, envir = ledgr_history_memo(substrate))
  last_barrier
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
ledgr_history_overlay_key <- function(instrument, epoch) {
  paste0("overlay_", instrument, "_", epoch)
}

ledgr_history_overlay_masks <- function(substrate, instrument, epoch, epochs) {
  key <- ledgr_history_overlay_key(instrument, epoch)
  ledgr_history_memo_value(ledgr_history_memo(substrate), key, function() {
    knowledge <- as.POSIXct(epochs[[epoch + 1L]] - 0.5, tz = "UTC")
    ledgr_history_prepare_masks(substrate, knowledge, instrument)
  })
}

ledgr_history_overlay_positions <- function(substrate, instrument, epoch, epochs, field) {
  key <- paste0(ledgr_history_overlay_key(instrument, epoch), "_", field)
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
    last_barrier <- ledgr_history_mask_barrier(
      substrate, "base_masks", masks
    )[rows, columns, drop = FALSE]
    source <- ledgr_history_base_positions(substrate, field)$source[
      rows, columns, drop = FALSE
    ]
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
      last_barrier[r, ] <- ledgr_history_mask_barrier(
        substrate, ledgr_history_overlay_key(instrument, epoch), overlay
      )[1L, columns]
      source[r, ] <- ledgr_history_overlay_positions(
        substrate, instrument, epoch, epochs, field
      )$source[1L, columns]
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

# Feature cells are a vintage view (Cut 16 decision 29): each cell carries the
# masks knowable at its own pulse, the knowledge its value was computed
# with, rather than the cutoff's. Columns of an instrument with late-known
# facts take the mask of the epoch their pulse falls in, from the same
# memoised base and overlay masks the bar reads use; nothing is recomputed per
# read. `reach_seen` counts, per cell, the expected sessions from the window
# start through the cell under that cell's own mask, for the bounded reach in
# ledgr_history_used_before_window().
ledgr_history_vintage_planes <- function(substrate, rows, columns) {
  late <- ledgr_history_late_epochs(substrate)
  masks <- ledgr_history_base_masks(substrate)
  n_rows <- length(rows)
  n_cols <- length(columns)
  expected <- masks$expected[rows, columns, drop = FALSE]
  terminal <- outer(masks$terminal_first[rows], columns, "<=")
  dim(terminal) <- c(n_rows, n_cols)
  reach_seen <- matrix(0L, nrow = n_rows, ncol = n_cols)
  if (n_rows > 0L && n_cols > 0L) {
    reach_seen <- t(collapse::fcumsum(t(matrix(as.integer(expected), n_rows, n_cols))))
    dim(reach_seen) <- c(n_rows, n_cols)
  }
  axis <- as.numeric(substrate$axis)[columns]
  for (r in which(lengths(late[rows]) > 0L)) {
    instrument <- rows[[r]]
    epochs <- late[[instrument]]
    column_epoch <- findInterval(axis, epochs)
    for (epoch in unique(column_epoch[column_epoch < length(epochs)])) {
      at <- which(column_epoch == epoch)
      overlay <- ledgr_history_overlay_masks(substrate, instrument, epoch, epochs)
      own <- overlay$expected[1L, columns]
      expected[r, at] <- own[at]
      terminal[r, at] <- overlay$terminal_first[[1L]] <= columns[at]
      reach_seen[r, at] <- cumsum(as.integer(own))[at]
    }
  }
  list(expected = expected, terminal = terminal, reach_seen = reach_seen)
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

# Feature cells read the shared feature projection and the sparse evidence
# planes its preparation retained (ledgr_feature_plane_records()), with the
# same column meanings as ledgr_history_feature_planes():
# - `calculated`: the required inputs were admitted (after treatment);
# - `ready`: an admitted cell at or after its segment's stable_after row;
# - `calculation_valid`: ready with a finite calculated value;
# - `output_carried`: the value is an earlier calculated value, with that
#   value's source time and age; `input_carried`: the cell's own required
#   input was policy-carried.
# `missing_reason` is not_expected, outside_calculation,
# required_input_missing, carried_input_excluded, not_ready,
# calculation_non_finite, output_carry_expired or output_carried, so every
# cell that is not calculation_valid carries a reason. Cells are located by binary search
# over the retained sorted keys; nothing is recomputed per read.
ledgr_history_plane_lookup <- function(table, key) {
  if (length(table) == 0L) return(integer(length(key)))
  position <- findInterval(key, table)
  hit <- position > 0L
  hit[hit] <- table[position[hit]] == key[hit]
  position[!hit] <- 0L
  position
}

ledgr_history_plane_run <- function(starts, ends, key) {
  if (length(starts) == 0L) return(integer(length(key)))
  position <- findInterval(key, starts)
  hit <- position > 0L
  hit[hit] <- key[hit] <= ends[position[hit]]
  position[!hit] <- 0L
  position
}

ledgr_history_feature_evidence <- function(substrate, feature_id, rows, columns, cutoff_col) {
  # A vintage view (Cut 16 decision 29): each cell's masks are those knowable
  # at its own pulse, matching the knowledge its value was computed with.
  planes <- ledgr_history_vintage_planes(substrate, rows, columns)
  projection <- substrate$feature_projection
  values <- projection$feature_values[[feature_id]]
  retained <- projection$feature_planes[[feature_id]]
  if (is.null(retained)) {
    rlang::abort(
      sprintf("Feature `%s` has no prepared evidence planes.", feature_id),
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_fold_execution")
    )
  }
  value <- values[rows, columns, drop = FALSE]
  dimnames(value) <- NULL
  n_rows <- length(rows)
  n_cols <- length(columns)
  shape <- function(x) matrix(x, nrow = n_rows, ncol = n_cols)
  column <- rep(as.integer(columns), each = n_rows)
  key <- as.numeric(rep(as.integer(rows), times = n_cols) - 1L) * retained$n_pulse + column
  expected <- planes$expected
  in_range <- shape(column >= retained$calc_from & column <= retained$calc_to)
  input_carried <- shape(ledgr_history_plane_lookup(retained$input_carried, key) > 0L)
  carried_at <- ledgr_history_plane_lookup(retained$output_carried, key)
  output_carried <- shape(carried_at > 0L)
  segment_at <- ledgr_history_plane_run(retained$segment_start, retained$segment_end, key)
  ready_col <- rep(NA_integer_, length(key))
  ready_col[segment_at > 0L] <- retained$segment_ready[segment_at[segment_at > 0L]]
  calculated <- shape(segment_at > 0L) & expected & in_range
  ready <- calculated & shape(!is.na(ready_col) & column >= ready_col)
  calculation_valid <- ready & is.finite(value) & !output_carried
  reason_at <- ledgr_history_plane_run(retained$reason_start, retained$reason_end, key)
  code <- integer(length(key))
  code[reason_at > 0L] <- retained$reason_code[reason_at[reason_at > 0L]]
  code <- shape(code)
  observed <- substrate$bars$observed[rows, columns, drop = FALSE]
  source_time <- shape(rep(as.numeric(substrate$axis)[columns], each = n_rows))
  source_time[!calculation_valid] <- NA_real_
  age <- shape(0L)
  age[!calculation_valid] <- NA_integer_
  carried_cells <- which(carried_at > 0L)
  source_time[carried_cells] <- retained$output_source_ts[carried_at[carried_cells]]
  age[carried_cells] <- retained$output_age[carried_at[carried_cells]]
  reason <- shape("")
  reason[!expected] <- "not_expected"
  reason[expected & in_range & code == 1L] <- "required_input_missing"
  reason[expected & in_range & code == 2L] <- "carried_input_excluded"
  reason[calculated & !ready] <- "not_ready"
  # Cut 16 decision (21): derived from the value, no stored plane.
  reason[ready & !is.finite(value)] <- "calculation_non_finite"
  reason[expected & in_range & code == 3L] <- "output_carry_expired"
  reason[output_carried] <- "output_carried"
  reason[expected & !in_range] <- "outside_calculation"
  barrier_reason <- shape("")
  barrier_reason[!expected] <- "lifetime_inactive"
  barrier_reason[planes$terminal] <- "terminal"
  list(
    value = value,
    expected = expected,
    observed = observed,
    is_missing = expected & !observed,
    input_carried = input_carried,
    calculated = calculated,
    output_carried = output_carried,
    source_ts_utc = source_time,
    carry_age_sessions = age,
    ready = ready,
    calculation_valid = calculation_valid,
    missing_reason = reason,
    barrier_reason = barrier_reason,
    source_index = NULL,
    reach_seen = planes$reach_seen
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
  # A bounded value depends on its last `requires_bars` expected sessions,
  # and it is valid only once its segment has reached `stable_after`
  # (>= `requires_bars`), so its reach is `stable_after` expected sessions
  # (close review S1). A history-dependent definition has no finite reach.
  declarations <- tryCatch(
    ledgr_feature_def_declarations(definition),
    error = function(e) NULL
  )
  if (is.null(declarations) || !identical(declarations$history_class, "bounded")) {
    return(NA_integer_)
  }
  reach <- suppressWarnings(as.integer(c(definition$requires_bars, definition$stable_after)))
  reach <- reach[!is.na(reach)]
  if (length(reach) == 0L) return(NA_integer_)
  max(reach)
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

# Ordinary matrix and wide reads need values plus row-level admission facts,
# not the twelve cell-evidence planes owned by the explicit long diagnostic
# layout. These compact readers derive that smaller result directly from the
# verified fold substrate. They do not seal, hash or authenticate a transient
# manifestation: snapshot verification and substrate ownership are the trust
# boundary.
ledgr_history_bar_mask_view <- function(substrate, rows, columns, cutoff_col,
                                        max_carry_sessions) {
  masks <- ledgr_history_base_masks(substrate)
  dependency_first <- if (length(columns) > 0L) {
    max(1L, columns[[1L]] - max_carry_sessions)
  } else {
    1L
  }
  dependency_columns <- if (length(columns) > 0L) {
    seq.int(dependency_first, columns[[length(columns)]])
  } else {
    integer()
  }
  late <- ledgr_history_late_epochs(substrate)
  late_rows <- match(
    ledgr_history_memo(substrate)$late_instruments, rows, nomatch = 0L
  )
  late_rows <- late_rows[late_rows > 0L]
  override_expected <- matrix(
    TRUE, nrow = length(late_rows), ncol = length(dependency_columns)
  )
  override_terminal <- rep.int(length(substrate$axis) + 1L, length(late_rows))
  keep <- logical(length(late_rows))
  cutoff <- if (length(late_rows) > 0L) {
    as.numeric(substrate$axis[[cutoff_col]])
  } else {
    NA_real_
  }
  for (at in seq_along(late_rows)) {
    local_row <- late_rows[[at]]
    instrument <- rows[[local_row]]
    epochs <- late[[instrument]]
    epoch <- findInterval(cutoff, epochs)
    if (epoch >= length(epochs)) next
    overlay <- ledgr_history_overlay_masks(substrate, instrument, epoch, epochs)
    keep[[at]] <- TRUE
    override_expected[at, ] <- overlay$expected[1L, dependency_columns]
    override_terminal[[at]] <- overlay$terminal_first[[1L]]
  }
  list(
    expected = masks$expected,
    terminal_first = masks$terminal_first,
    dependency_first = as.integer(dependency_first),
    override_row = as.integer(late_rows[keep]),
    override_expected = override_expected[keep, , drop = FALSE],
    override_terminal = as.integer(override_terminal[keep])
  )
}

ledgr_history_value_slice <- function(stored, rows, columns, masks,
                                      max_carry_sessions,
                                      axis_names, instrument_ids,
                                      manifestation = "matrix") {
  ledgr_cpp_history_bar_compact(
    stored, as.integer(rows), as.integer(columns),
    masks$expected, as.integer(masks$terminal_first),
    as.integer(masks$dependency_first), as.integer(masks$override_row),
    masks$override_expected, as.integer(masks$override_terminal),
    as.integer(max_carry_sessions),
    as.character(axis_names), as.character(instrument_ids),
    identical(manifestation, "wide")
  )
}

ledgr_history_bar_compact <- function(substrate, field, rows, columns, cutoff_col,
                                      min_observations,
                                      manifestation = "matrix") {
  stored <- substrate$bars[[field]]
  n_rows <- length(rows)
  n_cols <- length(columns)
  max_carry_sessions <- if (identical(field, "volume")) {
    0L
  } else {
    substrate$history_policy$price_carry %||% 0L
  }
  masks <- ledgr_history_bar_mask_view(
    substrate, rows, columns, cutoff_col, max_carry_sessions
  )
  # One fused bounded pass emits the returned sessions x instruments payload,
  # counts finite cells and applies only the prepared sparse treatment delta.
  # No opposite-orientation plane or count index is retained.
  compact <- ledgr_history_value_slice(
    stored, rows, columns, masks, max_carry_sessions,
    names(substrate$pulse_index)[columns], substrate$instrument_ids[rows],
    manifestation = manifestation
  )
  value <- compact$value
  finite_count <- compact$finite_observation_count

  # Structural and expiry reasons affect only excluded instruments. Derive
  # them from the diagnostic oracle for that bounded subset; the ordinary
  # hot path does not allocate evidence for included instruments.
  excluded <- finite_count < min_observations
  structural <- expired <- rep.int(FALSE, n_rows)
  if (any(excluded)) {
    evidence <- ledgr_history_bar_evidence(
      substrate, field, rows[excluded], columns, cutoff_col
    )
    structural[excluded] <- rowSums(
      !evidence$calculation_valid & nzchar(evidence$barrier_reason)
    ) > 0L
    expired[excluded] <- rowSums(
      !evidence$calculation_valid & evidence$missing_reason == "carry_expired"
    ) > 0L
  }

  list(
    value = value,
    calculation_valid = NULL,
    finite_observation_count = finite_count,
    required_input_count = rep.int(n_cols, n_rows),
    carried_input_count = compact$carried_input_count,
    structural = structural,
    expired = expired,
    used_before_row = compact$used_before_row
  )
}

ledgr_history_feature_compact <- function(substrate, feature_id, rows, columns,
                                          definition,
                                          manifestation = "matrix") {
  planes <- ledgr_history_vintage_planes(substrate, rows, columns)
  projection <- substrate$feature_projection
  retained <- projection$feature_planes[[feature_id]]
  if (is.null(retained)) {
    rlang::abort(
      sprintf("Feature `%s` has no prepared evidence planes.", feature_id),
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_fold_execution")
    )
  }
  value <- projection$feature_values[[feature_id]][rows, columns, drop = FALSE]
  dimnames(value) <- NULL
  n_rows <- length(rows)
  n_cols <- length(columns)
  if (n_rows == 0L || n_cols == 0L) {
    return(list(
      value = if (identical(manifestation, "wide")) {
        collapse::mrtl(value)
      } else {
        t(value)
      },
      calculation_valid = matrix(FALSE, n_rows, n_cols),
      finite_observation_count = rep.int(0L, n_rows),
      required_input_count = rep.int(n_cols, n_rows),
      carried_input_count = rep.int(0L, n_rows),
      structural = rep.int(FALSE, n_rows),
      expired = rep.int(FALSE, n_rows),
      used_before_row = rep.int(FALSE, n_rows)
    ))
  }

  shape <- function(x) matrix(x, nrow = n_rows, ncol = n_cols)
  column <- rep(as.integer(columns), each = n_rows)
  key <- as.numeric(rep(as.integer(rows), times = n_cols) - 1L) *
    retained$n_pulse + column
  in_range <- shape(column >= retained$calc_from & column <= retained$calc_to)
  input_carried <- shape(
    ledgr_history_plane_lookup(retained$input_carried, key) > 0L
  )
  carried_at <- ledgr_history_plane_lookup(retained$output_carried, key)
  output_carried <- shape(carried_at > 0L)
  segment_at <- ledgr_history_plane_run(
    retained$segment_start, retained$segment_end, key
  )
  ready_col <- rep(NA_integer_, length(key))
  ready_col[segment_at > 0L] <-
    retained$segment_ready[segment_at[segment_at > 0L]]
  calculated <- shape(segment_at > 0L) & planes$expected & in_range
  ready <- calculated & shape(!is.na(ready_col) & column >= ready_col)
  calculation_valid <- ready & is.finite(value) & !output_carried
  reason_at <- ledgr_history_plane_run(
    retained$reason_start, retained$reason_end, key
  )
  code <- integer(length(key))
  code[reason_at > 0L] <- retained$reason_code[reason_at[reason_at > 0L]]
  code <- shape(code)
  source_before <- matrix(FALSE, nrow = n_rows, ncol = n_cols)
  carried_cells <- which(carried_at > 0L)
  if (length(carried_cells) > 0L) {
    source <- retained$output_source_ts[carried_at[carried_cells]]
    source_before[carried_cells] <- !is.na(source) &
      source < as.numeric(substrate$axis[[columns[[1L]]]])
  }

  width <- ledgr_history_feature_width(definition)
  if (is.na(width)) {
    if (columns[[1L]] > 1L) {
      source_before <- source_before | calculation_valid | output_carried
    }
  } else if (any(calculation_valid)) {
    expected <- planes$expected
    stop_at <- expected & !input_carried
    first_stop <- ifelse(
      rowSums(stop_at) > 0L,
      max.col(stop_at, ties.method = "first"),
      n_cols + 1L
    )
    leading <- ifelse(
      first_stop > 1L,
      planes$reach_seen[cbind(seq_len(n_rows), pmax(first_stop - 1L, 1L))],
      0L
    )
    source_before <- source_before |
      (calculation_valid & (planes$reach_seen - width < leading))
  }

  list(
    value = if (identical(manifestation, "wide")) {
      collapse::mrtl(value)
    } else {
      t(value)
    },
    calculation_valid = calculation_valid,
    finite_observation_count = as.integer(rowSums(is.finite(value))),
    required_input_count = rep.int(n_cols, n_rows),
    carried_input_count = as.integer(rowSums(input_carried)),
    structural = rowSums(!calculation_valid &
      (!planes$expected | planes$terminal)) > 0L,
    expired = rowSums(!calculation_valid & code == 3L & !output_carried) > 0L,
    used_before_row = rowSums(source_before) > 0L
  )
}

ledgr_history_compact_admission <- function(compact, min_observations) {
  included <- compact$finite_observation_count >= min_observations
  exclusion_reason <- rep("", length(included))
  excluded <- !included
  exclusion_reason[excluded] <- "insufficient_observations"
  exclusion_reason[excluded & compact$expired] <- "carry_expired"
  exclusion_reason[excluded & compact$structural] <- "structural_exclusion"
  required <- as.integer(compact$required_input_count)
  carried <- as.integer(compact$carried_input_count)
  list(
    requested = rep(TRUE, length(included)),
    included = included,
    exclusion_reason = exclusion_reason,
    required_input_count = required,
    carried_input_count = carried,
    carried_input_share = ifelse(required > 0L, carried / required, 0),
    finite_observation_count = as.integer(compact$finite_observation_count)
  )
}

ledgr_history_validate_requirement <- function(value, argument) {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
      !is.finite(value) || value < 0 || value != floor(value) ||
      value > .Machine$integer.max) {
    ledgr_history_request_error(
      sprintf("`%s` must be one non-negative whole number.", argument)
    )
  }
  as.integer(value)
}

ledgr_history_requirements <- function(lookback,
                                       min_observations,
                                       min_instruments,
                                       available_lookback) {
  if (is.null(min_observations)) {
    min_observations <- if (is.finite(lookback)) {
      as.integer(lookback)
    } else {
      as.integer(available_lookback)
    }
  } else {
    min_observations <- ledgr_history_validate_requirement(
      min_observations, "min_observations"
    )
  }
  if (is.finite(lookback) && min_observations > lookback) {
    ledgr_history_request_error(
      "`min_observations` may not exceed a finite `lookback`."
    )
  }
  list(
    min_observations = as.integer(min_observations),
    min_instruments = ledgr_history_validate_requirement(
      min_instruments, "min_instruments"
    )
  )
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
#' `ledgr_history_frame()` returns one fresh `ledgr_history` result for one
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
#' Bar history is restated with the cutoff's knowledge. Feature history is a
#' vintage view: each cell keeps the value and the evidence it had at its own
#' pulse, so a fact that becomes known later changes feature cells only from
#' its knowledge pulse on. For example, if an inactive interval at sessions 5
#' and 6 becomes known at session 7, a read at session 7 shows the bar prints
#' of sessions 5 and 6 as inactive-interval prints, while their feature cells
#' keep the valid values computed at sessions 5 and 6; the session-7 feature
#' cell is computed with the interval known.
#'
#' Bar values follow the experiment's [ledgr_history_policy()]: open, high,
#' low and close carry forward within the declared expected-session horizon;
#' volume never carries. The ordinary wide result records compact carried
#' counts per instrument. The explicit long diagnostic layout adds cell
#' evidence from the feature preparation: `calculated`
#' means the required inputs were admitted, `ready` that the cell reached its
#' segment's first-valid row, and `calculation_valid` a ready, finite value.
#' A cell whose own required input was carried is `input_carried`; a value
#' carried from an earlier valid cell is `output_carried`, with that cell's
#' source time and age. `missing_reason` separates `not_ready` (warm-up or
#' re-warming), `calculation_non_finite` (ready, but the calculation is not
#' finite), `required_input_missing`, `carried_input_excluded`,
#' `output_carry_expired`, `output_carried`, `outside_calculation` and
#' `not_expected`, so every cell that is not `calculation_valid` has a
#' reason. `used_before_window` is `TRUE` when any returned value used an
#' observation or calculation state before the returned window, including
#' carried values and bounded values whose `stable_after` reach (window and
#' readiness) extends before the window, for example across inactive
#' sessions.
#'
#' `instruments = "admissible"` selects the decision-axis instruments that are
#' admissible at the cutoff, `"decision_axis"` adds held nonmembers and
#' restricted members, and a character vector requests known instrument IDs
#' explicitly; unknown IDs refuse and known IDs are never dropped for current
#' inadmissibility. `min_observations` excludes requested instruments with too
#' few finite values after treatment and records the count and reason. Input-
#' and output-carried finite values count. `min_instruments` records the panel
#' readiness requirement without filtering another instrument. Exclusion is
#' estimation only: it creates no target, zero target, liquidation or fill.
#' The strategy still returns a target for every instrument on its decision
#' axis.
#'
#' @param ctx A pulse context.
#' @param feature One active feature alias or registered feature ID.
#' @param bar One bar field: `"open"`, `"high"`, `"low"`, `"close"` or
#'   `"volume"`. Supply exactly one of `feature` and `bar`.
#' @param lookback Required. `Inf` for all history from the data start, or a
#'   non-negative whole number of expected venue sessions ending at the cutoff.
#' @param instruments `"admissible"`, `"decision_axis"`, or a character
#'   vector of known instrument IDs.
#' @param min_observations Minimum finite treated values required per
#'   instrument. `NULL` requires the finite `lookback`, or every returned
#'   session for `lookback = Inf`.
#' @param min_instruments Minimum included instruments required for
#'   [ledgr_passed_warmup()] to return `TRUE`. It does not filter columns.
#' @param layout `"wide"` (one row per session, `ts_utc` plus one column per
#'   included instrument) or `"long"` (one row per session and instrument with
#'   `ts_utc`, `instrument_id`, `source`, `value` and the cell evidence).
#' @return A `ledgr_history` data frame. Its `"ledgr_history"` attribute is
#'   structural provenance for the originating read, not authentication of
#'   the current numeric cells. It
#'   records the data start, returned-window start and cutoff, requested and
#'   available lookback, source, policy identity and recorded requirements,
#'   the selection table
#'   (requested, included and excluded instruments with reasons and carried
#'   input counts) and whether any value used observations before the window.
#'   Only the explicit long layout contains cell-aligned diagnostic evidence.
#' @seealso [ledgr_history_matrix()], [ledgr_passed_warmup()],
#'   [ledgr_history_policy()]
#' @examples
#' \dontrun{
#' strategy <- function(ctx, params) {
#'   returns <- ctx |>
#'     ledgr_history_frame(feature = "return_1", lookback = 20L,
#'                         min_instruments = 3L)
#'   x <- ledgr_history_matrix(returns)
#'   ctx$hold()
#' }
#' }
#' @section Articles:
#' Reading causal history:
#' `vignette("causal-history", package = "ledgr")`
#' `system.file("doc", "causal-history.html", package = "ledgr")`
#' @export
ledgr_history_frame <- function(ctx,
                                feature = NULL,
                                bar = NULL,
                                lookback,
                                instruments = "admissible",
                                min_observations = NULL,
                                min_instruments = 1L,
                                layout = c("wide", "long")) {
  if (missing(lookback)) {
    ledgr_history_request_error(
      "`lookback` is required; use `Inf` explicitly for all causal history."
    )
  }
  layout <- ledgr_history_choice(layout, c("wide", "long"), "layout")
  plan <- ledgr_history_request_plan(
    ctx, feature, bar, lookback, instruments, min_observations, min_instruments,
    diagnostic = identical(layout, "long"),
    manifestation = if (identical(layout, "long")) "long" else "wide"
  )
  ledgr_history_plan_frame(plan, layout)
}

ledgr_history_request_plan <- function(ctx,
                                       feature,
                                       bar,
                                       lookback,
                                       instruments,
                                       min_observations,
                                       min_instruments,
                                       diagnostic = FALSE,
                                       manifestation = if (diagnostic) "long" else "matrix") {
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
  ledgr_history_read_plan(
    view = view,
    kind = if (is.null(bar)) "feature" else "bar",
    name = name,
    lookback = lookback,
    instruments = instruments,
    min_observations = min_observations,
    min_instruments = min_instruments,
    decision_ids = as.character(ctx$universe),
    decision_planes = ctx$vec,
    diagnostic = diagnostic,
    manifestation = manifestation
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

ledgr_history_read_plan <- function(view,
                                    kind,
                                    name,
                                    lookback,
                                    instruments,
                                    min_observations,
                                    min_instruments,
                                    decision_ids,
                                    decision_planes,
                                    diagnostic = FALSE,
                                    manifestation = if (diagnostic) "long" else "matrix") {
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
  requirements <- ledgr_history_requirements(
    lookback, min_observations, min_instruments, length(columns)
  )
  result <- if (isTRUE(diagnostic) && identical(kind, "bar")) {
    ledgr_history_bar_evidence(substrate, source_id, rows, columns, cutoff_col)
  } else if (isTRUE(diagnostic)) {
    ledgr_history_feature_evidence(substrate, source_id, rows, columns, cutoff_col)
  } else if (identical(kind, "bar")) {
    ledgr_history_bar_compact(
      substrate, source_id, rows, columns, cutoff_col,
      requirements$min_observations, manifestation = manifestation
    )
  } else {
    ledgr_history_feature_compact(
      substrate, source_id, rows, columns, service$feature_defs[[source_id]],
      manifestation = manifestation
    )
  }
  admission <- if (isTRUE(diagnostic)) {
    ledgr_history_estimator_admission(
      list(
        value = result$value,
        calculation_valid = result$calculation_valid,
        input_carried = result$input_carried,
        output_carried = result$output_carried,
        barrier_reason = result$barrier_reason,
        missing_reason = result$missing_reason
      ),
      requested = rep(TRUE, length(rows)),
      min_observations = requirements$min_observations
    )
  } else {
    ledgr_history_compact_admission(result, requirements$min_observations)
  }
  included <- admission$included
  exclusion_reason <- admission$exclusion_reason

  window_start <- if (length(columns) > 0L) substrate$axis[[columns[[1L]]]] else
    as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
  keep <- which(included)
  used_before <- if (isTRUE(diagnostic)) {
    ledgr_history_used_before_window(
      kind, result, keep, columns, service$feature_defs[[source_id]],
      as.numeric(window_start)
    )
  } else {
    any(result$used_before_row[keep])
  }
  selection_table <- ledgr_history_selection_table(
    requested_ids = requested_ids,
    included = included,
    exclusion_reason = exclusion_reason,
    admission = admission,
    decision_ids = decision_ids,
    decision_planes = decision_planes
  )
  axis <- substrate$axis[columns]
  axis_names <- names(substrate$pulse_index)[columns]
  ids <- requested_ids[keep]
  all_kept <- length(keep) == length(rows)
  value_layout <- if (isTRUE(diagnostic)) "diagnostic" else manifestation
  value <- if (all_kept) {
    result$value
  } else if (identical(value_layout, "matrix")) {
    result$value[, keep, drop = FALSE]
  } else if (identical(value_layout, "wide")) {
    result$value[keep]
  } else {
    result$value[keep, , drop = FALSE]
  }
  cells <- if (isTRUE(diagnostic)) {
    lapply(
      stats::setNames(ledgr_history_cell_fields(), ledgr_history_cell_fields()),
      function(field) {
        if (all_kept) result[[field]] else result[[field]][keep, , drop = FALSE]
      }
    )
  } else {
    NULL
  }
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
    min_observations = requirements$min_observations,
    min_instruments = requirements$min_instruments,
    passed_warmup = isTRUE(sum(included) >= requirements$min_instruments),
    layout = NULL,
    axis = axis,
    axis_names = axis_names,
    instrument_ids = ids,
    selection = selection_table,
    used_before_window = used_before
  )
  list(
    value = value,
    cells = cells,
    axis = axis,
    ids = ids,
    source_label = source_label,
    value_layout = value_layout,
    meta = meta
  )
}

ledgr_history_plan_frame <- function(plan, layout) {
  meta <- plan$meta
  meta$layout <- layout
  if (identical(layout, "wide")) {
    ledgr_history_wide(plan$value, plan$cells, plan$axis, plan$ids, meta)
  } else {
    ledgr_history_long(
      plan$value, plan$cells, plan$axis, plan$ids, plan$source_label, meta
    )
  }
}

# Whether any returned value used an observation or calculation state before
# the returned window. For features (all derived by index from the frame's
# evidence; nothing is recomputed):
# - an output-carried value whose source time precedes the window;
# - a history-dependent value when the window does not start at the data
#   start (its segment state may reach back);
# - a bounded value whose reach of `stable_after` expected sessions (its
#   window and the readiness it depends on) does not fit inside the returned
#   window's expected sessions (a lookback that is too short, a segment that
#   began before the window, or one that spans a lifetime-inactive
#   interval), or whose
#   window reaches a leading run of input-carried sessions, whose source
#   precedes the window.
ledgr_history_used_before_window <- function(kind, evidence, keep, columns, definition,
                                             window_start = NA_real_) {
  if (length(keep) == 0L || length(columns) == 0L) return(FALSE)
  if (identical(kind, "bar")) {
    source <- evidence$source_index[keep, , drop = FALSE]
    carried <- evidence$input_carried[keep, , drop = FALSE]
    return(any(carried & !is.na(source) & source < columns[[1L]]))
  }
  valid <- evidence$calculation_valid[keep, , drop = FALSE]
  output_carried <- evidence$output_carried[keep, , drop = FALSE]
  source_ts <- evidence$source_ts_utc[keep, , drop = FALSE]
  if (any(output_carried & !is.na(source_ts) & source_ts < window_start)) {
    return(TRUE)
  }
  width <- ledgr_history_feature_width(definition)
  if (is.na(width)) {
    return(columns[[1L]] > 1L && any(valid | output_carried))
  }
  if (!any(valid)) return(FALSE)
  expected <- evidence$expected[keep, , drop = FALSE]
  carried <- evidence$input_carried[keep, , drop = FALSE]
  n_rows <- nrow(expected)
  n_cols <- ncol(expected)
  # Expected sessions from the window start through each column, under each
  # cell's own (vintage) mask.
  seen <- evidence$reach_seen[keep, , drop = FALSE]
  # Expected sessions in the leading input-carried run of each row.
  stop_at <- expected & !carried
  first_stop <- ifelse(rowSums(stop_at) > 0L, max.col(stop_at, ties.method = "first"), n_cols + 1L)
  leading <- ifelse(first_stop > 1L, seen[cbind(seq_len(n_rows), pmax(first_stop - 1L, 1L))], 0L)
  any(valid & (seen - width < leading))
}

ledgr_history_selection_table <- function(requested_ids,
                                          included,
                                          exclusion_reason,
                                          admission,
                                          decision_ids,
                                          decision_planes) {
  requested_pos <- match(requested_ids, decision_ids)
  requested_on_axis <- rep.int(FALSE, length(decision_ids))
  requested_on_axis[requested_pos[!is.na(requested_pos)]] <- TRUE
  other_pos <- which(!requested_on_axis)
  others <- decision_ids[other_pos]
  ids <- c(requested_ids, others)
  n_req <- length(requested_ids)
  n_other <- length(others)
  axis_pos <- c(requested_pos, other_pos)
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
  structure(
    list(
      instrument_id = ids,
      requested = c(rep(TRUE, n_req), rep(FALSE, n_other)),
      included = c(as.logical(included), rep(FALSE, n_other)),
      exclusion_reason = c(
        as.character(exclusion_reason), rep("not_requested", n_other)
      ),
      on_decision_axis = on_axis,
      admissible = admissible,
      admissibility_reason = reason,
      required_input_count = c(
        admission$required_input_count, rep(NA_integer_, n_other)
      ),
      carried_input_count = c(
        admission$carried_input_count, rep(NA_integer_, n_other)
      ),
      carried_input_share = c(
        as.numeric(admission$carried_input_share), rep(NA_real_, n_other)
      ),
      finite_observation_count = c(
        admission$finite_observation_count, rep(NA_integer_, n_other)
      )
    ),
    class = "data.frame",
    row.names = .set_row_names(length(ids))
  )
}

ledgr_history_time_names <- function(axis) {
  ledgr_projection_pulse_names(axis)
}

ledgr_history_wide <- function(value, cells, axis, ids, meta) {
  n_time <- length(axis)
  # The wide sibling is emitted as its final column list by the bounded
  # manifestation pass; it is not split from the matrix sibling.
  columns <- value
  names(columns) <- ids
  out <- c(list(ts_utc = as.POSIXct(axis, tz = "UTC")), columns)
  meta$evidence <- NULL
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
  frame <- inherits(x, "ledgr_history") && is.data.frame(x)
  matrix <- inherits(x, "ledgr_history_matrix") && is.matrix(x) && is.double(x)
  if ((!frame && !matrix) || !is.list(meta)) {
    rlang::abort(
      "`x` must be an intact ledgr history frame or matrix.",
      class = c("ledgr_invalid_history_result", "ledgr_invalid_args")
    )
  }
  meta
}

# The result's metadata after checking that its columns still match the
# recorded axis and instruments, as every adapter over a result does. For the
# long layout it also returns each row's session and instrument position.
ledgr_history_require_consistent <- function(x) {
  meta <- ledgr_history_require_result(x)
  axis <- meta$axis
  ids <- as.character(meta$instrument_ids)
  mismatch <- function() {
    rlang::abort(
      "`x` no longer matches its recorded history axis and instruments.",
      class = c("ledgr_invalid_history_result", "ledgr_invalid_args")
    )
  }
  if (inherits(x, "ledgr_history_matrix")) {
    if (!identical(meta$layout, "matrix") ||
        !identical(dim(x), c(length(axis), length(ids))) ||
        !identical(
          dimnames(x),
          ledgr_history_matrix_dimnames(axis, ids, meta$axis_names)
        )) {
      mismatch()
    }
    return(list(meta = meta, row = NULL, col = NULL))
  }
  if (identical(meta$layout, "wide")) {
    if (!identical(names(x), c("ts_utc", ids)) || nrow(x) != length(axis) ||
        !identical(as.numeric(x$ts_utc), as.numeric(axis))) {
      mismatch()
    }
    return(list(meta = meta, row = NULL, col = NULL))
  }
  row <- match(as.numeric(x$ts_utc), as.numeric(axis))
  col <- match(as.character(x$instrument_id), ids)
  if (anyNA(row) || anyNA(col) || nrow(x) != length(axis) * length(ids) ||
      anyDuplicated(row + (col - 1L) * length(axis))) {
    mismatch()
  }
  list(meta = meta, row = row, col = col)
}

#' Read or convert causal history as an identified matrix
#'
#' With a pulse context, `ledgr_history_matrix()` reads the same causal plan as
#' [ledgr_history_frame()] and manifests only a sessions-by-instruments double
#' matrix. With an existing history frame it is an adapter over that result and
#' reads no data. Both forms return an ordinary matrix with structural ledgr
#' provenance for [ledgr_history_info()], [ledgr_align_weights()] and
#' [ledgr_passed_warmup()]. Registered arithmetic, replacement or subsetting
#' methods drop that provenance. Base or third-party operations that preserve
#' attributes may preserve it; ledgr does not authenticate transformed values.
#'
#' @param x A pulse context or an existing `ledgr_history` frame.
#' @inheritParams ledgr_history_frame
#' @return A classed double matrix whose rows are expected sessions and whose
#'   columns are included instrument IDs.
#' @seealso [ledgr_history_frame()]
#' @section Articles:
#' Reading causal history:
#' `vignette("causal-history", package = "ledgr")`
#' `system.file("doc", "causal-history.html", package = "ledgr")`
#' @export
ledgr_history_matrix <- function(x,
                                 feature = NULL,
                                 bar = NULL,
                                 lookback,
                                 instruments = "admissible",
                                 min_observations = NULL,
                                 min_instruments = 1L) {
  if (inherits(x, "ledgr_history")) {
    extras <- !missing(feature) || !missing(bar) || !missing(lookback) ||
      !missing(instruments) || !missing(min_observations) || !missing(min_instruments)
    if (extras) {
      ledgr_history_request_error(
        "The history-frame adapter accepts only `x`; read options belong to the context form."
      )
    }
    return(ledgr_history_matrix_from_frame(x))
  }
  if (!inherits(x, "ledgr_pulse_context")) {
    rlang::abort(
      "`x` must be a pulse context or an intact ledgr history frame.",
      class = c("ledgr_invalid_history_result", "ledgr_invalid_args")
    )
  }
  if (missing(lookback)) {
    ledgr_history_request_error(
      "`lookback` is required; use `Inf` explicitly for all causal history."
    )
  }
  plan <- ledgr_history_request_plan(
    x, feature, bar, lookback, instruments, min_observations, min_instruments,
    diagnostic = FALSE, manifestation = "matrix"
  )
  ledgr_history_matrix_from_plan(plan)
}

ledgr_history_matrix_result <- function(out, meta) {
  # The direct manifestation is already double. Avoid duplicating its full
  # payload merely to re-assert the storage mode; adapters still normalize
  # a non-double input at this boundary.
  if (!is.double(out)) storage.mode(out) <- "double"
  meta$layout <- "matrix"
  meta$evidence <- NULL
  structure(
    out,
    class = c("ledgr_history_matrix", "matrix", "array"),
    ledgr_history = meta
  )
}

ledgr_history_matrix_dimnames <- function(axis, ids, axis_names = NULL) {
  list(
    if (length(axis) > 0L) axis_names %||% ledgr_history_time_names(axis) else NULL,
    if (length(ids) > 0L) ids else NULL
  )
}

ledgr_history_matrix_from_plan <- function(plan) {
  out <- if (identical(plan$value_layout, "matrix")) plan$value else t(plan$value)
  expected_dim <- c(length(plan$axis), length(plan$ids))
  expected_dimnames <- ledgr_history_matrix_dimnames(
    plan$axis, plan$ids, plan$meta$axis_names
  )
  if (!identical(dim(out), expected_dim)) dim(out) <- expected_dim
  if (!identical(dimnames(out), expected_dimnames)) dimnames(out) <- expected_dimnames
  ledgr_history_matrix_result(out, plan$meta)
}

ledgr_history_matrix_from_frame <- function(x) {
  checked <- ledgr_history_require_consistent(x)
  meta <- checked$meta
  axis <- meta$axis
  ids <- as.character(meta$instrument_ids)
  out <- matrix(
    NA_real_,
    nrow = length(axis),
    ncol = length(ids),
    dimnames = ledgr_history_matrix_dimnames(axis, ids, meta$axis_names)
  )
  if (identical(meta$layout, "wide")) {
    if (length(ids) > 0L && length(axis) > 0L) {
      out[] <- as.numeric(unlist(unclass(x)[ids], use.names = FALSE))
    }
    return(ledgr_history_matrix_result(out, meta))
  }
  out[checked$row + (checked$col - 1L) * length(axis)] <- as.numeric(x$value)
  ledgr_history_matrix_result(out, meta)
}

ledgr_history_matrix_drop_identity <- function(x) {
  attr(x, "ledgr_history") <- NULL
  class(x) <- c("matrix", "array")
  x
}

#' @export
`[.ledgr_history_matrix` <- function(x, i, j, ..., drop = TRUE) {
  out <- NextMethod("[")
  if (is.object(out)) attr(out, "ledgr_history") <- NULL
  if (is.matrix(out)) class(out) <- c("matrix", "array")
  out
}

#' @export
`[<-.ledgr_history_matrix` <- function(x, i, j, ..., value) {
  out <- NextMethod("[<-")
  ledgr_history_matrix_drop_identity(out)
}

#' @export
Ops.ledgr_history_matrix <- function(e1, e2) {
  out <- NextMethod()
  if (is.object(out)) attr(out, "ledgr_history") <- NULL
  if (is.matrix(out)) class(out) <- c("matrix", "array")
  out
}

#' @export
Math.ledgr_history_matrix <- function(x, ...) {
  out <- NextMethod()
  if (is.object(out)) attr(out, "ledgr_history") <- NULL
  if (is.matrix(out)) class(out) <- c("matrix", "array")
  out
}

#' @export
as.matrix.ledgr_history_matrix <- function(x, ...) {
  ledgr_history_matrix_drop_identity(x)
}

#' Read the metadata of a history result
#'
#' `ledgr_history_info()` returns what a [ledgr_history_frame()] result
#' recorded about itself, so a strategy or an inspection never reads the
#' `"ledgr_history"` attribute directly: its source, causal cutoff, data
#' start and returned-window start, requested and available lookback, the
#' selection table with every exclusion reason, the included and excluded
#' instrument IDs, and whether any returned value used observations or
#' calculation state before the returned window. Like [ledgr_history_matrix()]
#' it first checks that the result still matches its recorded axis and
#' instruments, and it reads no data.
#'
#' Excluded instruments are estimation evidence only. An instrument that
#' `min_observations` left out of the estimator sample still
#' needs a target: [ledgr_target_rebalance()] targets a held instrument that
#' is not in its weights to zero unless the strategy passes it in `keep`, and
#' `excluded_ids` is the list to consult for that choice.
#'
#' @param x A `ledgr_history` result.
#' @return A `ledgr_history_info` list with `source` (the `bar:<field>` or
#'   `feature:<id>` label), `source_kind`, `source_id`, `cutoff_utc`,
#'   `data_start_utc`, `window_start_utc`, `requested_lookback`,
#'   `available_lookback`, `instruments` (the selector: `"admissible"`,
#'   `"decision_axis"` or `"explicit"`), `min_observations`,
#'   `min_instruments`, `passed_warmup`, `layout`,
#'   `used_before_window`, `included_ids`, `excluded_ids` (requested but not
#'   included), `selection` (a tibble with one row per requested or
#'   decision-axis instrument: `requested`, `included`, `exclusion_reason`,
#'   `on_decision_axis`, `admissible`, `admissibility_reason`,
#'   `required_input_count`, `carried_input_count` and
#'   `carried_input_share`), `policy_identity` and `snapshot_hash`. Ordinary
#'   results contain no cell-aligned evidence; request `layout = "long"` when
#'   cell diagnostics are needed.
#' @seealso [ledgr_history_frame()], [ledgr_history_matrix()],
#'   [ledgr_align_weights()]
#' @examples
#' \dontrun{
#' strategy <- function(ctx, params) {
#'   returns <- ctx |>
#'     ledgr_history_frame(feature = "return_1", lookback = 20L,
#'                         min_instruments = 3L)
#'   info <- ledgr_history_info(returns)
#'   info$excluded_ids
#'   ctx$hold()
#' }
#' }
#' @section Articles:
#' Reading causal history:
#' `vignette("causal-history", package = "ledgr")`
#' `system.file("doc", "causal-history.html", package = "ledgr")`
#' @export
ledgr_history_info <- function(x) {
  meta <- ledgr_history_require_consistent(x)$meta
  selection <- meta$selection
  requested <- as.logical(selection$requested)
  included <- as.logical(selection$included)
  structure(
    list(
      source = meta$source$label,
      source_kind = meta$source$kind,
      source_id = meta$source$id,
      cutoff_utc = meta$cutoff_utc,
      data_start_utc = meta$data_start_utc,
      window_start_utc = meta$window_start_utc,
      requested_lookback = meta$requested_lookback,
      available_lookback = meta$available_lookback,
      instruments = meta$instruments,
      min_observations = meta$min_observations,
      min_instruments = meta$min_instruments,
      passed_warmup = meta$passed_warmup,
      layout = meta$layout,
      used_before_window = meta$used_before_window,
      included_ids = as.character(meta$instrument_ids),
      excluded_ids = as.character(selection$instrument_id[requested & !included]),
      selection = tibble::as_tibble(selection),
      policy_identity = meta$policy_identity,
      snapshot_hash = meta$snapshot_hash,
      evidence = meta$evidence
    ),
    class = c("ledgr_history_info", "list")
  )
}

#' @export
print.ledgr_history_info <- function(x, ...) {
  cat("ledgr_history_info\n")
  cat("Source:       ", x$source, "\n", sep = "")
  cat("Cutoff:       ", ledgr_history_time_names(x$cutoff_utc), "\n", sep = "")
  window <- if (length(x$window_start_utc) == 1L && !is.na(x$window_start_utc)) {
    ledgr_history_time_names(x$window_start_utc)
  } else {
    "empty"
  }
  cat("Window start: ", window, "\n", sep = "")
  cat("Sessions:     ", x$available_lookback, " of requested ",
      format(x$requested_lookback), "\n", sep = "")
  cat("Selector:     ", x$instruments, "\n", sep = "")
  cat("Requirements: ", x$min_observations, " finite observations, ",
      x$min_instruments, " instruments\n", sep = "")
  cat("Ready:        ", if (isTRUE(x$passed_warmup)) "yes" else "no", "\n", sep = "")
  cat("Included:     ", length(x$included_ids), " of ",
      sum(x$selection$requested), " requested\n", sep = "")
  if (length(x$excluded_ids) > 0L) {
    reasons <- x$selection$exclusion_reason[match(x$excluded_ids, x$selection$instrument_id)]
    cat("Excluded:     ", paste(sprintf("%s (%s)", x$excluded_ids, reasons), collapse = ", "),
        "\n", sep = "")
  }
  cat("Used before window: ", if (isTRUE(x$used_before_window)) "yes" else "no", "\n", sep = "")
  cat("# i Selection table: info$selection\n")
  invisible(x)
}

#' Align solver weights to a history result
#'
#' `ledgr_align_weights()` turns the numeric output of an estimator or
#' solver into [ledgr_weights()] identified by the instruments of the intact
#' history frame or matrix it was estimated from, so no column names
#' have to be rebuilt by hand. The solver output comes first, so it pipes:
#' `solution |> ledgr_align_weights(history) |> ledgr_target_rebalance(ctx)`.
#' An unnamed vector is read in the order of the result's included
#' instruments, which is the column order of [ledgr_history_matrix()]; a
#' vector named by those instruments, in any order, is matched by name. A
#' one-column or one-row matrix is read as a vector. A length that differs
#' from the number of included instruments, names that differ from them
#' (wrong, duplicated or missing names) or a wider matrix refuse with
#' `ledgr_weight_alignment_mismatch` rather than guessing.
#'
#' Only the included estimation sample receives a weight. Instruments the
#' result excluded are listed by [ledgr_history_info()]; see that page and
#' [ledgr_target_rebalance()] for what happens to a held excluded instrument.
#'
#' @param solution A finite numeric vector, or a one-column or one-row
#'   numeric matrix, with one weight per included instrument. A missing or
#'   non-finite weight refuses with `ledgr_invalid_strategy_type`, as
#'   [ledgr_weights()] does.
#' @param history The intact history frame or matrix the solution was estimated
#'   from.
#' @return A `ledgr_weights` object named by the included instrument IDs.
#' @seealso [ledgr_history_matrix()], [ledgr_history_info()],
#'   [ledgr_target_rebalance()]
#' @examples
#' \dontrun{
#' strategy <- function(ctx, params) {
#'   returns <- ctx |>
#'     ledgr_history_matrix(feature = "return_1", lookback = 60L,
#'                          min_instruments = 3L)
#'   x <- returns
#'   w <- 1 / apply(x, 2L, stats::sd)
#'   unname(w / sum(w)) |>
#'     ledgr_align_weights(returns) |>
#'     ledgr_target_rebalance(ctx, equity_fraction = 0.95)
#' }
#' }
#' @section Articles:
#' Reading causal history:
#' `vignette("causal-history", package = "ledgr")`
#' `system.file("doc", "causal-history.html", package = "ledgr")`
#' @export
ledgr_align_weights <- function(solution, history) {
  meta <- ledgr_history_require_consistent(history)$meta
  ids <- as.character(meta$instrument_ids)
  mismatch <- function(message) {
    rlang::abort(
      message,
      class = c("ledgr_weight_alignment_mismatch", "ledgr_invalid_args")
    )
  }
  if (!is.numeric(solution)) {
    mismatch("`solution` must be a numeric vector with one weight per included instrument.")
  }
  if (!is.null(dim(solution))) {
    if (length(dim(solution)) != 2L || min(dim(solution)) > 1L && length(solution) > 0L) {
      mismatch("`solution` must be a vector or a one-column or one-row matrix.")
    }
    dims <- dimnames(solution)
    labels <- if (is.null(dims)) NULL else dims[[which.max(dim(solution))]]
    solution <- as.numeric(solution)
    names(solution) <- labels
  }
  labels <- names(solution)
  if (length(solution) != length(ids)) {
    mismatch(sprintf(
      "`solution` has %d value%s but the history result includes %d instrument%s (%s).",
      length(solution), if (length(solution) == 1L) "" else "s",
      length(ids), if (length(ids) == 1L) "" else "s",
      if (length(ids) > 0L) paste(ids, collapse = ", ") else "none"
    ))
  }
  if (!is.null(labels) && any(nzchar(labels))) {
    if (anyNA(labels) || anyDuplicated(labels) || !setequal(labels, ids)) {
      mismatch(sprintf(
        "`solution` names must be the history result's included instruments: %s.",
        paste(ids, collapse = ", ")
      ))
    }
    solution <- solution[match(ids, labels)]
  }
  ledgr_weights(
    stats::setNames(as.numeric(solution), ids),
    origin = "ledgr_align_weights"
  )
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
  cat("Ready:     ", if (isTRUE(meta$passed_warmup)) "yes" else "no", "\n", sep = "")
  cat("Layout:    ", meta$layout, "\n", sep = "")
  frame <- x
  attr(frame, "ledgr_history") <- NULL
  class(frame) <- "data.frame"
  print(utils::head(frame, 10L), ...)
  cat("# i Selection, exclusions and window: ledgr_history_info(x)\n")
  invisible(x)
}
