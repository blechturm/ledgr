ledgr_history_evidence_fields <- function() {
  c(
    "expected", "observed", "is_missing", "input_carried", "calculated",
    "output_carried", "source_ts_utc", "carry_age_sessions", "ready",
    "calculation_valid", "missing_reason", "barrier_reason", "requested",
    "included", "exclusion_reason", "required_input_count",
    "carried_input_count", "carried_input_share"
  )
}

ledgr_history_input_carry <- function(value,
                                      expected,
                                      axis,
                                      max_sessions = NULL,
                                      carry_allowed = TRUE,
                                      terminal_barrier = rep(FALSE, length(value))) {
  value <- as.numeric(value)
  expected <- as.logical(expected)
  axis <- as.POSIXct(axis, tz = "UTC")
  n <- length(value)
  terminal_barrier <- as.logical(terminal_barrier)
  if (length(expected) != n || length(axis) != n || anyNA(expected) ||
      length(terminal_barrier) != n || anyNA(terminal_barrier)) {
    rlang::abort(
      "History carry inputs must align on one complete expected-session axis.",
      class = c("ledgr_invalid_history_treatment", "ledgr_invalid_config")
    )
  }
  observed <- is.finite(value)
  admissible_observation <- observed & expected & !terminal_barrier
  source <- rep(NA_integer_, n)
  if (n > 0L) {
    source <- as.integer(collapse::na_locf(ifelse(
      admissible_observation,
      seq_len(n),
      NA_integer_
    )))
  }
  barrier <- !expected | terminal_barrier
  last_barrier <- rep(NA_integer_, n)
  if (n > 0L && any(barrier)) {
    last_barrier <- as.integer(collapse::na_locf(ifelse(
      barrier,
      seq_len(n),
      NA_integer_
    )))
  }
  crossed_barrier <- !is.na(source) & !is.na(last_barrier) &
    source <= last_barrier
  source[crossed_barrier] <- NA_integer_
  age <- seq_len(n) - source
  age[is.na(source)] <- NA_integer_
  can_carry <- isTRUE(carry_allowed) && !is.null(max_sessions)
  carried <- rep(FALSE, n)
  if (can_carry) {
    carried <- expected & !observed & !is.na(source) &
      age <= as.integer(max_sessions)
  }
  treated <- value
  if (any(carried)) treated[carried] <- value[source[carried]]
  treated[!expected] <- NA_real_
  source_out <- source
  source_out[observed & expected] <- seq_len(n)[observed & expected]
  source_out[!observed & !carried] <- NA_integer_
  age_out <- age
  age_out[observed & expected] <- 0L
  age_out[!observed & !carried] <- NA_integer_
  reason <- rep("", n)
  reason[!expected & observed] <- "inactive_interval_print"
  reason[!expected & !observed] <- "not_expected"
  missing_expected <- expected & !observed
  reason[missing_expected & is.na(source)] <- "leading_or_barrier_missing"
  reason[missing_expected & !is.na(source) & !carried] <- if (can_carry) {
    "carry_expired"
  } else {
    "raw_missing"
  }
  reason[carried] <- "input_carried"
  barrier_reason <- rep("", n)
  barrier_reason[!expected] <- "lifetime_inactive"
  barrier_reason[missing_expected & is.na(source) & !is.na(last_barrier)] <-
    "lifetime_restart"
  barrier_reason[terminal_barrier] <- "terminal"
  list(
    value = treated,
    expected = expected,
    observed = observed,
    is_missing = expected & !observed,
    input_carried = carried,
    calculated = expected & (observed | carried),
    output_carried = rep(FALSE, n),
    source_index = source_out,
    source_ts_utc = .POSIXct(
      ifelse(is.na(source_out), NA_real_, as.numeric(axis)[pmax(source_out, 1L)]),
      tz = "UTC"
    ),
    carry_age_sessions = as.integer(age_out),
    ready = expected & (observed | carried),
    calculation_valid = expected & (observed | carried),
    missing_reason = reason,
    barrier_reason = barrier_reason
  )
}

ledgr_history_input_carry_matrix <- function(value,
                                              expected,
                                              axis,
                                              max_sessions = NULL,
                                              carry_allowed = TRUE,
                                              terminal_barrier = NULL) {
  value <- as.matrix(value)
  storage.mode(value) <- "double"
  expected <- as.matrix(expected)
  storage.mode(expected) <- "logical"
  n_instruments <- nrow(value)
  n_observations <- ncol(value)
  axis <- as.POSIXct(axis, tz = "UTC")
  if (is.null(terminal_barrier)) {
    terminal_barrier <- matrix(
      FALSE, nrow = n_instruments, ncol = n_observations
    )
  } else {
    terminal_barrier <- as.matrix(terminal_barrier)
    storage.mode(terminal_barrier) <- "logical"
  }
  if (!identical(dim(expected), dim(value)) ||
      !identical(dim(terminal_barrier), dim(value)) ||
      length(axis) != n_observations || anyNA(expected) ||
      anyNA(terminal_barrier)) {
    rlang::abort(
      "History carry matrices must share one complete instrument/session shape.",
      class = c("ledgr_invalid_history_treatment", "ledgr_invalid_config")
    )
  }
  if (n_instruments == 0L || n_observations == 0L) {
    empty_logical <- matrix(
      logical(), nrow = n_instruments, ncol = n_observations
    )
    empty_integer <- matrix(
      integer(), nrow = n_instruments, ncol = n_observations
    )
    empty_character <- matrix(
      character(), nrow = n_instruments, ncol = n_observations
    )
    return(list(
      value = value,
      expected = expected,
      observed = empty_logical,
      is_missing = empty_logical,
      input_carried = empty_logical,
      calculated = empty_logical,
      output_carried = empty_logical,
      source_ts_utc = matrix(
        numeric(), nrow = n_instruments, ncol = n_observations
      ),
      carry_age_sessions = empty_integer,
      ready = empty_logical,
      calculation_valid = empty_logical,
      missing_reason = empty_character,
      barrier_reason = empty_character
    ))
  }

  observed <- is.finite(value)
  barrier <- !expected | terminal_barrier
  column <- matrix(
    rep(seq_len(n_observations), each = n_instruments),
    nrow = n_instruments,
    ncol = n_observations
  )
  source_seed <- ifelse(observed & expected & !terminal_barrier, column, NA_integer_)
  source_seed[barrier] <- 0L
  reset <- !observed[, 1L]
  source_seed[reset, 1L] <- 0L
  source <- matrix(
    as.integer(collapse::na_locf(as.vector(t(source_seed)))),
    nrow = n_instruments,
    ncol = n_observations,
    byrow = TRUE
  )
  source[source == 0L] <- NA_integer_

  barrier_seed <- ifelse(barrier, column, NA_integer_)
  reset <- is.na(barrier_seed[, 1L])
  barrier_seed[reset, 1L] <- 0L
  last_barrier <- matrix(
    as.integer(collapse::na_locf(as.vector(t(barrier_seed)))),
    nrow = n_instruments,
    ncol = n_observations,
    byrow = TRUE
  )
  last_barrier[last_barrier == 0L] <- NA_integer_
  age <- column - source
  age[is.na(source)] <- NA_integer_
  can_carry <- isTRUE(carry_allowed) && !is.null(max_sessions)
  carried <- matrix(
    FALSE, nrow = n_instruments, ncol = n_observations
  )
  if (can_carry) {
    carried <- expected & !observed & !is.na(source) &
      age <= as.integer(max_sessions)
  }
  treated <- value
  if (any(carried)) {
    source_row <- matrix(
      rep(seq_len(n_instruments), n_observations),
      nrow = n_instruments,
      ncol = n_observations
    )
    source_cell <- source_row + (source - 1L) * n_instruments
    treated[carried] <- value[source_cell[carried]]
  }
  treated[!expected] <- NA_real_
  source_out <- source
  source_out[observed & expected] <- column[observed & expected]
  source_out[!observed & !carried] <- NA_integer_
  age_out <- age
  age_out[observed & expected] <- 0L
  age_out[!observed & !carried] <- NA_integer_

  reason <- matrix("", nrow = n_instruments, ncol = n_observations)
  reason[!expected & observed] <- "inactive_interval_print"
  reason[!expected & !observed] <- "not_expected"
  missing_expected <- expected & !observed
  reason[missing_expected & is.na(source)] <- "leading_or_barrier_missing"
  reason[missing_expected & !is.na(source) & !carried] <- if (can_carry) {
    "carry_expired"
  } else {
    "raw_missing"
  }
  reason[carried] <- "input_carried"
  barrier_reason <- matrix("", nrow = n_instruments, ncol = n_observations)
  barrier_reason[!expected] <- "lifetime_inactive"
  barrier_reason[
    missing_expected & is.na(source) & !is.na(last_barrier)
  ] <- "lifetime_restart"
  barrier_reason[terminal_barrier] <- "terminal"
  source_time <- matrix(
    as.numeric(axis)[pmax(source_out, 1L)],
    nrow = n_instruments,
    ncol = n_observations
  )
  source_time[is.na(source_out)] <- NA_real_
  available <- expected & (observed | carried)
  list(
    value = treated,
    expected = expected,
    observed = observed,
    is_missing = expected & !observed,
    input_carried = carried,
    calculated = available,
    output_carried = matrix(
      FALSE, nrow = n_instruments, ncol = n_observations
    ),
    source_ts_utc = source_time,
    carry_age_sessions = matrix(
      as.integer(age_out), nrow = n_instruments, ncol = n_observations
    ),
    ready = available,
    calculation_valid = available,
    missing_reason = reason,
    barrier_reason = barrier_reason
  )
}

ledgr_history_substrate_treated_field <- function(
    substrate,
    field,
    cutoff,
    observation_idx = seq_along(substrate$axis),
    instrument_idx = seq_along(substrate$instrument_ids),
    carry_allowed = field %in% c("open", "high", "low", "close")) {
  ledgr_history_substrate_require(substrate)
  if (!field %in% c("open", "high", "low", "close", "volume")) {
    rlang::abort(
      "History bar field must be one of open, high, low, close or volume.",
      class = c("ledgr_invalid_history_field", "ledgr_invalid_args")
    )
  }
  observation_idx <- as.integer(observation_idx)
  instrument_idx <- as.integer(instrument_idx)
  expected <- ledgr_history_substrate_expected_at(
    substrate,
    cutoff,
    observation_idx,
    instrument_idx
  )
  terminal_barrier <- ledgr_history_substrate_terminal_at(
    substrate,
    cutoff,
    observation_idx,
    instrument_idx
  )
  raw <- substrate$bars[[field]][instrument_idx, observation_idx, drop = FALSE]
  ledgr_history_input_carry_matrix(
    value = raw,
    expected = expected,
    axis = substrate$axis[observation_idx],
    max_sessions = substrate$history_policy$price_carry,
    carry_allowed = isTRUE(carry_allowed) && !identical(field, "volume"),
    terminal_barrier = terminal_barrier
  )
}

ledgr_history_output_carry <- function(value,
                                       eligible_gap,
                                       expected,
                                       axis,
                                       max_sessions = NULL,
                                       source_eligible = is.finite(value),
                                       terminal_barrier = rep(FALSE, length(value))) {
  source_eligible <- as.logical(source_eligible)
  if (length(source_eligible) != length(value) || anyNA(source_eligible)) {
    rlang::abort(
      "History output-carry eligibility must align with the output axis.",
      class = c("ledgr_invalid_history_treatment", "ledgr_invalid_config")
    )
  }
  source_value <- as.numeric(value)
  source_value[!source_eligible] <- NA_real_
  base <- ledgr_history_input_carry(
    value = source_value,
    expected = expected,
    axis = axis,
    max_sessions = max_sessions,
    carry_allowed = !is.null(max_sessions),
    terminal_barrier = terminal_barrier
  )
  permitted <- as.logical(eligible_gap) & base$input_carried
  base$value[base$input_carried & !permitted] <- NA_real_
  base$output_carried <- permitted
  base$input_carried[] <- FALSE
  base$calculated <- is.finite(value) & source_eligible
  base$calculation_valid <- is.finite(value) & source_eligible
  base$ready <- base$calculation_valid | permitted
  base$missing_reason[permitted] <- "output_carried"
  base$missing_reason[!is.finite(value) & !permitted & expected] <-
    "output_not_carry_eligible"
  base
}

ledgr_history_estimator_admission <- function(evidence,
                                              requested = TRUE) {
  calculation_valid <- evidence$calculation_valid
  input_carried <- evidence$input_carried
  if (is.null(dim(calculation_valid))) {
    calculation_valid <- matrix(as.logical(calculation_valid), nrow = 1L)
  }
  if (is.null(dim(input_carried))) {
    input_carried <- matrix(as.logical(input_carried), nrow = 1L)
  }
  if (!identical(dim(calculation_valid), dim(input_carried)) ||
      anyNA(calculation_valid) || anyNA(input_carried)) {
    rlang::abort(
      "History estimator evidence must be complete and shape-aligned.",
      class = c("ledgr_invalid_history_treatment", "ledgr_invalid_config")
    )
  }
  n_instruments <- nrow(calculation_valid)
  requested <- rep(as.logical(requested), length.out = n_instruments)
  if (length(requested) != n_instruments || anyNA(requested)) {
    rlang::abort(
      "History estimator requests must align with the instrument axis.",
      class = c("ledgr_invalid_history_treatment", "ledgr_invalid_config")
    )
  }
  required_input_count <- rowSums(matrix(
    TRUE,
    nrow = n_instruments,
    ncol = ncol(calculation_valid)
  ))
  carried_input_count <- rowSums(input_carried)
  included <- requested & rowSums(!calculation_valid) == 0L
  exclusion_reason <- rep("", n_instruments)
  exclusion_reason[!requested] <- "not_requested"
  exclusion_reason[requested & !included] <- "missing_required_input"
  list(
    requested = requested,
    included = included,
    exclusion_reason = exclusion_reason,
    required_input_count = as.integer(required_input_count),
    carried_input_count = as.integer(carried_input_count),
    carried_input_share = ifelse(
      required_input_count > 0L,
      carried_input_count / required_input_count,
      0
    )
  )
}
