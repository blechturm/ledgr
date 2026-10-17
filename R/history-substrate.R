ledgr_history_substrate_version <- 1L

.ledgr_history_worker_stage <- new.env(parent = emptyenv())

ledgr_history_utc <- function(x) {
  as.POSIXct(
    ledgr_normalize_ts_utc(x),
    tz = "UTC",
    format = "%Y-%m-%dT%H:%M:%SZ"
  )
}

ledgr_history_stage_identity <- function(substrate, owner_id) {
  ledgr_history_substrate_require(substrate)
  digest::digest(
    canonical_json(list(
      type = "ledgr_history_worker_stage_v1",
      owner_id = as.character(owner_id),
      snapshot_hash = substrate$snapshot_hash,
      policy_identity = substrate$policy_identity,
      substrate_version = substrate$substrate_version,
      source_start_utc = ledgr_normalize_ts_utc(substrate$source_start_utc),
      data_start_utc = ledgr_normalize_ts_utc(substrate$data_start_utc),
      instruments = substrate$instrument_ids,
      axis = ledgr_projection_pulse_names(substrate$axis),
      feature_engine_version = substrate$feature_projection$feature_engine_version,
      feature_ids = names(substrate$feature_projection$feature_values)
    )),
    algo = "sha256"
  )
}

ledgr_history_worker_stage <- function(invariant, identity) {
  if (!is.list(invariant) ||
      !ledgr_history_substrate_is(invariant$history_substrate) ||
      !is.character(invariant$staged_owner_id) ||
      length(invariant$staged_owner_id) != 1L ||
      is.na(invariant$staged_owner_id) ||
      !nzchar(invariant$staged_owner_id) ||
      !is.character(identity) || length(identity) != 1L || is.na(identity) ||
      !nzchar(identity) ||
      !identical(invariant$staged_invariant_identity, identity) ||
      !identical(
        ledgr_history_stage_identity(
          invariant$history_substrate,
          invariant$staged_owner_id
        ),
        identity
      )) {
    rlang::abort(
      "The staged causal-history invariant is missing or has a different identity.",
      class = c("ledgr_staged_history_mismatch", "ledgr_parallel_error")
    )
  }
  invariant$pulses_iso <- format(
    as.POSIXct(invariant$pulses_posix, tz = "UTC"),
    "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
  invariant$availability_provider <- ledgr_availability_provider_from_substrate(
    invariant$history_substrate,
    invariant$availability_config,
    invariant$snapshot_hash
  )
  .ledgr_history_worker_stage$identity <- identity
  .ledgr_history_worker_stage$invariant <- invariant
  invisible(TRUE)
}

ledgr_history_worker_take <- function(identity) {
  if (!exists("identity", envir = .ledgr_history_worker_stage, inherits = FALSE) ||
      !exists("invariant", envir = .ledgr_history_worker_stage, inherits = FALSE) ||
      !identical(.ledgr_history_worker_stage$identity, identity) ||
      !identical(
        .ledgr_history_worker_stage$invariant$staged_invariant_identity,
        identity
      )) {
    rlang::abort(
      "The staged causal-history invariant is missing or has a different identity.",
      class = c("ledgr_staged_history_mismatch", "ledgr_parallel_error")
    )
  }
  .ledgr_history_worker_stage$invariant
}

ledgr_history_worker_clear <- function() {
  remove(list = ls(.ledgr_history_worker_stage, all.names = TRUE),
         envir = .ledgr_history_worker_stage)
  invisible(TRUE)
}

ledgr_history_substrate_is <- function(x) {
  inherits(x, "ledgr_history_substrate") &&
    is.list(x) &&
    identical(x$substrate_version, ledgr_history_substrate_version)
}

ledgr_history_substrate_require <- function(x) {
  if (!ledgr_history_substrate_is(x)) {
    rlang::abort(
      "History execution requires one current ledgr history substrate.",
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_fold_execution")
    )
  }
  invisible(x)
}

ledgr_history_substrate_validate_owner <- function(substrate,
                                                    snapshot_hash,
                                                    history_policy,
                                                    instrument_ids,
                                                    required_start = NULL,
                                                    required_end = NULL) {
  ledgr_history_substrate_require(substrate)
  expected_policy <- ledgr_history_policy_identity(
    ledgr_history_policy_normalize(history_policy)
  )
  checks <- c(
    snapshot = identical(substrate$snapshot_hash, as.character(snapshot_hash)),
    policy = identical(substrate$policy_identity, expected_policy),
    instruments = identical(
      substrate$instrument_ids,
      as.character(instrument_ids)
    )
  )
  if (!is.null(required_start)) {
    required_start <- ledgr_history_utc(required_start)
    checks <- c(
      checks,
      start_present = length(substrate$axis) > 0L && !is.na(required_start),
      source_start = identical(
        as.numeric(substrate$source_start_utc),
        as.numeric(required_start)
      ),
      data_start = identical(
        as.numeric(substrate$data_start_utc),
        as.numeric(substrate$axis[[1L]])
      )
    )
  }
  if (!is.null(required_end)) {
    required_end <- ledgr_history_utc(required_end)
    required_axis <- if (all(checks) && length(substrate$axis) > 0L &&
        !is.na(required_end)) {
      ledgr_availability_calendar(
        list(sessions = substrate$sessions),
        substrate$data_start_utc,
        required_end
      )$pulses_posix
    } else {
      as.POSIXct(character(), tz = "UTC")
    }
    checks <- c(
      checks,
      end_present = length(substrate$axis) > 0L && !is.na(required_end),
      end_covered = length(required_axis) > 0L &&
        max(substrate$axis) >= max(required_axis)
    )
  }
  if (!all(checks)) {
    rlang::abort(
      "The supplied causal-history substrate belongs to a different snapshot, policy, universe or time range.",
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_config"),
      ownership_checks = checks,
      required_start_utc = required_start,
      required_end_utc = required_end,
      available_start_utc = substrate$source_start_utc,
      available_end_utc = if (length(substrate$axis) > 0L) {
        max(substrate$axis)
      } else {
        as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
      }
    )
  }
  invisible(substrate)
}

ledgr_history_substrate_for_experiment <- function(exp,
                                                   meta = NULL,
                                                   end = NULL) {
  if (!inherits(exp, "ledgr_experiment") || !isTRUE(exp$availability$active)) {
    rlang::abort(
      "Causal-history preparation requires one availability-aware experiment.",
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_experiment")
    )
  }
  ledgr_snapshot_ensure_handle(exp$snapshot)
  if (is.null(meta)) meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  if (is.null(end)) end <- meta$end
  con <- get_connection(exp$snapshot)
  data <- ledgr_availability_provider_data(con, exp$snapshot$snapshot_id)
  config <- ledgr_sweep_availability_config(exp)
  calendar <- ledgr_availability_calendar(
    list(sessions = data$sessions), meta$start, end
  )
  bars_by_id <- ledgr_precompute_fetch_bars(
    exp$snapshot, exp$universe, meta$start, end
  )
  bars <- do.call(rbind, unname(bars_by_id))
  rownames(bars) <- NULL
  ledgr_history_substrate(
    bars = bars,
    instrument_ids = exp$universe,
    axis = calendar$pulses_posix,
    availability_data = data,
    availability_config = config,
    snapshot_hash = meta$snapshot_hash,
    source_start_utc = meta$start
  )
}

ledgr_history_compute_feature_series <- function(substrate,
                                                 instrument_id,
                                                 definition,
                                                 kind = NULL,
                                                 calculation_start = NULL,
                                                 rows = NULL) {
  if (is.null(rows)) {
    rows <- ledgr_history_substrate_instrument_frame(substrate, instrument_id)
  }
  keep <- rep.int(TRUE, nrow(rows))
  if (!is.null(calculation_start)) {
    keep <- as.POSIXct(rows$ts_utc, tz = "UTC") >=
      as.POSIXct(calculation_start, tz = "UTC")
  }
  calculated <- ledgr_compute_feature_series_strict(
    rows[keep, , drop = FALSE], definition, kind = kind
  )
  if (all(keep)) return(as.numeric(calculated))
  out <- rep.int(NA_real_, nrow(rows))
  out[keep] <- as.numeric(calculated)
  out
}

ledgr_history_precompute_payload <- function(unique_defs,
                                             substrate,
                                             calculation_start = NULL) {
  ledgr_history_substrate_require(substrate)
  fingerprints <- names(unique_defs)
  out <- lapply(fingerprints, function(fingerprint) {
    list(
      feature_id = unique_defs[[fingerprint]]$id,
      fingerprint = fingerprint,
      values = stats::setNames(vector("list", length(substrate$instrument_ids)),
                               substrate$instrument_ids)
    )
  })
  names(out) <- fingerprints
  kinds <- lapply(unique_defs, ledgr_strict_builtin_kind)
  for (instrument_id in substrate$instrument_ids) {
    rows <- ledgr_history_substrate_instrument_frame(substrate, instrument_id)
    for (fingerprint in fingerprints) {
      def <- unique_defs[[fingerprint]]
      out[[fingerprint]]$values[[instrument_id]] <-
        ledgr_history_compute_feature_series(
        substrate = substrate,
        instrument_id = instrument_id,
        definition = def,
        kind = kinds[[fingerprint]],
        calculation_start = calculation_start,
        rows = rows
      )
    }
  }
  out
}

ledgr_history_substrate_bind_features <- function(substrate, projection) {
  ledgr_history_substrate_require(substrate)
  if (!inherits(projection, "ledgr_runtime_projection")) {
    rlang::abort(
      "History feature preparation requires one runtime projection.",
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_fold_execution")
    )
  }
  out <- substrate
  out$feature_projection <- projection
  out
}

ledgr_history_substrate_bar_matrices <- function(bars,
                                                 instrument_ids,
                                                 axis) {
  instrument_ids <- as.character(instrument_ids)
  axis <- as.POSIXct(axis, tz = "UTC")
  n_inst <- length(instrument_ids)
  n_axis <- length(axis)
  numeric_matrix <- function() matrix(NA_real_, nrow = n_inst, ncol = n_axis)
  out <- list(
    open = numeric_matrix(),
    high = numeric_matrix(),
    low = numeric_matrix(),
    close = numeric_matrix(),
    volume = numeric_matrix(),
    gap_type = matrix("MISSING_EXPECTED_SESSION", nrow = n_inst, ncol = n_axis),
    is_synthetic = matrix(FALSE, nrow = n_inst, ncol = n_axis),
    observed = matrix(FALSE, nrow = n_inst, ncol = n_axis)
  )
  if (!is.data.frame(bars) || nrow(bars) == 0L || n_axis == 0L) {
    return(out)
  }
  row <- match(as.character(bars$instrument_id), instrument_ids)
  col <- match(as.numeric(as.POSIXct(bars$ts_utc, tz = "UTC")), as.numeric(axis))
  keep <- !is.na(row) & !is.na(col)
  if (!any(keep)) return(out)
  row <- row[keep]
  col <- col[keep]
  linear <- row + (col - 1L) * n_inst
  if (anyDuplicated(linear)) {
    rlang::abort(
      "History preparation found duplicate instrument/session bars.",
      class = c("ledgr_history_duplicate_bar", "ledgr_invalid_snapshot")
    )
  }
  assign_numeric <- function(name) {
    value <- if (name %in% names(bars)) as.numeric(bars[[name]][keep]) else rep(NA_real_, length(row))
    out[[name]][linear] <<- value
  }
  for (name in c("open", "high", "low", "close", "volume")) assign_numeric(name)
  if ("gap_type" %in% names(bars)) {
    value <- as.character(bars$gap_type[keep])
    value[is.na(value) | !nzchar(value)] <- "NONE"
    out$gap_type[linear] <- value
  } else {
    out$gap_type[linear] <- "NONE"
  }
  if ("is_synthetic" %in% names(bars)) {
    value <- as.logical(bars$is_synthetic[keep])
    value[is.na(value)] <- FALSE
    out$is_synthetic[linear] <- value
  }
  out$observed[linear] <- TRUE
  out
}

ledgr_history_substrate_bar_frame <- function(substrate,
                                              pulse_idx,
                                              instrument_idx = NULL) {
  ledgr_history_substrate_require(substrate)
  pulse_idx <- as.integer(pulse_idx)
  if (length(pulse_idx) != 1L || is.na(pulse_idx) ||
      pulse_idx < 1L || pulse_idx > length(substrate$axis)) {
    rlang::abort(
      "History bar pulse is outside the prepared axis.",
      class = c("ledgr_history_outside_axis", "ledgr_invalid_args")
    )
  }
  if (is.null(instrument_idx)) instrument_idx <- seq_along(substrate$instrument_ids)
  instrument_idx <- as.integer(instrument_idx)
  if (anyNA(instrument_idx) || any(instrument_idx < 1L) ||
      any(instrument_idx > length(substrate$instrument_ids))) {
    rlang::abort(
      "History bar instruments are outside the prepared identity.",
      class = c("ledgr_history_unknown_instrument", "ledgr_invalid_args")
    )
  }
  bars <- substrate$bars
  data.frame(
    instrument_id = substrate$instrument_ids[instrument_idx],
    ts_utc = as.POSIXct(rep(substrate$axis[[pulse_idx]], length(instrument_idx)), tz = "UTC"),
    open = as.numeric(bars$open[instrument_idx, pulse_idx]),
    high = as.numeric(bars$high[instrument_idx, pulse_idx]),
    low = as.numeric(bars$low[instrument_idx, pulse_idx]),
    close = as.numeric(bars$close[instrument_idx, pulse_idx]),
    volume = as.numeric(bars$volume[instrument_idx, pulse_idx]),
    gap_type = as.character(bars$gap_type[instrument_idx, pulse_idx]),
    is_synthetic = as.logical(bars$is_synthetic[instrument_idx, pulse_idx]),
    stringsAsFactors = FALSE
  )
}

ledgr_history_substrate_bar_packet <- function(substrate, pulse_idx) {
  ledgr_history_substrate_require(substrate)
  pulse_idx <- as.integer(pulse_idx)
  if (length(pulse_idx) != 1L || is.na(pulse_idx) ||
      pulse_idx < 1L || pulse_idx > length(substrate$axis)) {
    rlang::abort(
      "History bar pulse is outside the prepared axis.",
      class = c("ledgr_history_outside_axis", "ledgr_invalid_args")
    )
  }
  bars <- substrate$bars
  list(
    ts_utc = substrate$axis[[pulse_idx]],
    instrument_id = substrate$instrument_ids,
    open = as.numeric(bars$open[, pulse_idx]),
    high = as.numeric(bars$high[, pulse_idx]),
    low = as.numeric(bars$low[, pulse_idx]),
    close = as.numeric(bars$close[, pulse_idx]),
    volume = as.numeric(bars$volume[, pulse_idx]),
    gap_type = as.character(bars$gap_type[, pulse_idx]),
    is_synthetic = as.logical(bars$is_synthetic[, pulse_idx]),
    observed = as.logical(bars$observed[, pulse_idx]),
    expected = as.logical(substrate$expected[, pulse_idx]),
    halted = as.logical(substrate$halted[, pulse_idx]),
    missing_expected_bar = as.logical(
      substrate$missing_expected_bar[, pulse_idx]
    ),
    inactive_print = as.logical(substrate$inactive_print[, pulse_idx])
  )
}

ledgr_history_bar_packet_frame <- function(packet, instrument_idx = NULL) {
  if (!is.list(packet) || !is.character(packet$instrument_id)) {
    rlang::abort(
      "History bar packet is invalid.",
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_fold_execution")
    )
  }
  if (is.null(instrument_idx)) instrument_idx <- seq_along(packet$instrument_id)
  instrument_idx <- as.integer(instrument_idx)
  data.frame(
    instrument_id = packet$instrument_id[instrument_idx],
    ts_utc = as.POSIXct(rep(packet$ts_utc, length(instrument_idx)), tz = "UTC"),
    open = packet$open[instrument_idx],
    high = packet$high[instrument_idx],
    low = packet$low[instrument_idx],
    close = packet$close[instrument_idx],
    volume = packet$volume[instrument_idx],
    gap_type = packet$gap_type[instrument_idx],
    is_synthetic = packet$is_synthetic[instrument_idx],
    stringsAsFactors = FALSE
  )
}

ledgr_history_substrate_fold_reader <- function(substrate, pulses_posix) {
  ledgr_history_substrate_require(substrate)
  pulse_columns <- unname(substrate$pulse_index[
    ledgr_projection_pulse_names(as.POSIXct(pulses_posix, tz = "UTC"))
  ])
  if (anyNA(pulse_columns)) {
    rlang::abort(
      "Fold pulses must be covered by the causal history substrate.",
      class = c("ledgr_history_outside_axis", "ledgr_invalid_fold_execution")
    )
  }
  reads <- 0L
  list(
    pulse_columns = as.integer(pulse_columns),
    bars = function(pulse_idx) {
      reads <<- reads + 1L
      pulse_idx <- as.integer(pulse_idx)
      current <- ledgr_history_substrate_bar_packet(
        substrate, pulse_columns[[pulse_idx]]
      )
      next_packet <- if (pulse_idx < length(pulse_columns)) {
        ledgr_history_substrate_bar_packet(
          substrate, pulse_columns[[pulse_idx + 1L]]
        )
      } else {
        NULL
      }
      list(current = current, next_bar = next_packet)
    },
    stats = function() list(reads = reads)
  )
}

ledgr_history_substrate_instrument_frame <- function(substrate, instrument_id) {
  ledgr_history_substrate_require(substrate)
  idx <- unname(substrate$instrument_index[as.character(instrument_id)])
  if (length(idx) != 1L || is.na(idx)) {
    rlang::abort(
      sprintf("Unknown history instrument_id `%s`.", as.character(instrument_id)),
      class = c("ledgr_history_unknown_instrument", "ledgr_invalid_args")
    )
  }
  bars <- substrate$bars
  data.frame(
    instrument_id = rep(substrate$instrument_ids[[idx]], length(substrate$axis)),
    ts_utc = substrate$axis,
    open = as.numeric(bars$open[idx, ]),
    high = as.numeric(bars$high[idx, ]),
    low = as.numeric(bars$low[idx, ]),
    close = as.numeric(bars$close[idx, ]),
    volume = as.numeric(bars$volume[idx, ]),
    gap_type = as.character(bars$gap_type[idx, ]),
    is_synthetic = as.logical(bars$is_synthetic[idx, ]),
    stringsAsFactors = FALSE
  )
}

ledgr_history_substrate_history_reader <- function(substrate) {
  force(substrate)
  function(instrument_id, cutoff, sessions = NULL) {
    rows <- ledgr_history_substrate_instrument_frame(substrate, instrument_id)
    keep <- rows$ts_utc <= ledgr_history_utc(cutoff)
    rows <- rows[keep, , drop = FALSE]
    if (!is.null(sessions)) rows <- utils::tail(rows, as.integer(sessions))
    rows
  }
}

ledgr_history_status_resolve_applicable <- function(applicable,
                                                    status,
                                                    precedence,
                                                    fact_id,
                                                    lineage) {
  if (length(applicable) == 0L) {
    return(list(state = "unknown", winner = "", reason = "status_unknown"))
  }
  superseded <- vapply(applicable, function(candidate) {
    any(ledgr_status_is_ancestor(lineage, candidate, applicable))
  }, logical(1))
  remaining <- applicable[!superseded]
  if (length(remaining) == 0L) {
    return(list(state = "conflicting", winner = "", reason = "status_conflicting"))
  }
  top <- max(precedence[remaining])
  selected <- remaining[precedence[remaining] == top]
  values <- unique(status[selected])
  winner <- paste(sort(unique(fact_id[selected]), method = "radix"), collapse = "|")
  if (length(values) != 1L) {
    return(list(state = "conflicting", winner = winner, reason = "status_conflicting"))
  }
  list(state = values[[1L]], winner = winner, reason = "status_asserted")
}

ledgr_history_lifetime_resolve_applicable <- function(applicable,
                                                      assertion,
                                                      terminal,
                                                      fact_id,
                                                      rank) {
  if (length(applicable) == 0L) {
    return(list(
      state = "unknown", winner = "", reason = "lifetime_unknown",
      terminal_event = ""
    ))
  }
  winner <- applicable[[which.max(rank[applicable])]]
  list(
    state = assertion[[winner]],
    winner = fact_id[[winner]],
    reason = "lifetime_asserted",
    terminal_event = terminal[[winner]]
  )
}

ledgr_history_segment_dictionary <- function() {
  lookup <- new.env(hash = TRUE, parent = emptyenv())
  value <- character(16L)
  size <- 0L
  encode <- function(x) {
    x <- as.character(x)
    key <- paste0("k:", enc2utf8(x))
    found <- unlist(mget(
      key,
      envir = lookup,
      inherits = FALSE,
      ifnotfound = as.list(rep(NA_integer_, length(key)))
    ), use.names = FALSE)
    missing <- is.na(found)
    if (any(missing)) {
      new_key <- unique(key[missing])
      new_value <- x[match(new_key, key)]
      required <- size + length(new_key)
      if (required > length(value)) {
        capacity <- max(required, max(16L, length(value) * 2L))
        length(value) <<- capacity
      }
      new_index <- seq.int(size + 1L, required)
      value[new_index] <<- new_value
      for (i in seq_along(new_key)) {
        assign(new_key[[i]], new_index[[i]], envir = lookup)
      }
      size <<- required
      found <- unlist(mget(
        key,
        envir = lookup,
        inherits = FALSE
      ), use.names = FALSE)
    }
    as.integer(found)
  }
  list(encode = encode, values = function() value[seq_len(size)])
}

ledgr_history_segment_epoch_cells <- function(inst,
                                              obs,
                                              obs_to,
                                              knowledge,
                                              state,
                                              winner,
                                              reason) {
  if (length(inst) == 0L) return(NULL)
  ord <- order(inst, obs, method = "radix")
  inst <- inst[ord]
  obs <- obs[ord]
  obs_to <- obs_to[ord]
  state <- state[ord]
  winner <- winner[ord]
  reason <- reason[ord]
  starts <- c(
    TRUE,
    inst[-1L] != inst[-length(inst)] |
      obs[-1L] != obs_to[-length(obs_to)] |
      state[-1L] != state[-length(state)] |
      winner[-1L] != winner[-length(winner)] |
      reason[-1L] != reason[-length(reason)]
  )
  group <- cumsum(starts)
  first <- !duplicated(group)
  last <- !duplicated(group, fromLast = TRUE)
  list(
    instrument = as.integer(inst[first]),
    observation_from = as.integer(obs[first]),
    observation_to = as.integer(obs_to[last]),
    knowledge_from = rep(as.numeric(knowledge), sum(first)),
    state = as.integer(state[first]),
    winner = as.integer(winner[first]),
    reason = as.integer(reason[first])
  )
}

ledgr_history_segment_bind <- function(chunks, dictionaries, n_instruments) {
  chunks <- chunks[!vapply(chunks, is.null, logical(1))]
  pull <- function(name, mode) {
    if (length(chunks) == 0L) return(vector(mode, 0L))
    unlist(lapply(chunks, `[[`, name), use.names = FALSE)
  }
  instrument <- as.integer(pull("instrument", "integer"))
  observation_from <- as.integer(pull("observation_from", "integer"))
  observation_to <- as.integer(pull("observation_to", "integer"))
  knowledge_from <- as.numeric(pull("knowledge_from", "double"))
  state <- as.integer(pull("state", "integer"))
  winner <- as.integer(pull("winner", "integer"))
  reason <- as.integer(pull("reason", "integer"))
  ord <- if (length(instrument) > 0L) {
    order(instrument, knowledge_from, observation_from, method = "radix")
  } else {
    integer()
  }
  instrument <- instrument[ord]
  observation_from <- observation_from[ord]
  observation_to <- observation_to[ord]
  knowledge_from <- knowledge_from[ord]
  state <- state[ord]
  winner <- winner[ord]
  reason <- reason[ord]
  if (length(instrument) > 1L) {
    starts <- c(
      TRUE,
      instrument[-1L] != instrument[-length(instrument)] |
        knowledge_from[-1L] != knowledge_from[-length(knowledge_from)] |
        observation_from[-1L] != observation_to[-length(observation_to)] |
        state[-1L] != state[-length(state)] |
        winner[-1L] != winner[-length(winner)] |
        reason[-1L] != reason[-length(reason)]
    )
    group <- cumsum(starts)
    first <- !duplicated(group)
    last <- !duplicated(group, fromLast = TRUE)
    instrument <- instrument[first]
    observation_from <- observation_from[first]
    observation_to <- observation_to[last]
    knowledge_from <- knowledge_from[first]
    state <- state[first]
    winner <- winner[first]
    reason <- reason[first]
  }
  count <- tabulate(instrument, nbins = n_instruments)
  list(
    off = as.integer(cumsum(c(1L, count[-n_instruments]))),
    count = as.integer(count),
    instrument = instrument,
    observation_from = observation_from,
    observation_to = observation_to,
    knowledge_from = knowledge_from,
    state = state,
    winner = winner,
    reason = reason,
    state_levels = dictionaries$state$values(),
    winner_levels = dictionaries$winner$values(),
    reason_levels = dictionaries$reason$values()
  )
}

ledgr_history_segments_build <- function(axis,
                                         instrument_ids,
                                         epochs,
                                         epoch_start,
                                         initial,
                                         resolve,
                                         fact_count,
                                         family,
                                         segment_limit = NULL,
                                         observation_breaks = seq_along(axis)) {
  n_inst <- length(instrument_ids)
  n_axis <- length(axis)
  dictionaries <- list(
    state = ledgr_history_segment_dictionary(),
    winner = ledgr_history_segment_dictionary(),
    reason = ledgr_history_segment_dictionary()
  )
  initial_state <- dictionaries$state$encode(rep(initial$state, n_inst))
  initial_winner <- dictionaries$winner$encode(rep(initial$winner, n_inst))
  initial_reason <- dictionaries$reason$encode(rep(initial$reason, n_inst))
  observation_breaks <- sort(unique(as.integer(observation_breaks)))
  observation_breaks <- observation_breaks[
    !is.na(observation_breaks) & observation_breaks >= 1L &
      observation_breaks <= n_axis
  ]
  if (n_axis > 0L && !1L %in% observation_breaks) {
    observation_breaks <- c(1L, observation_breaks)
  }
  observation_to <- c(observation_breaks[-1L], n_axis + 1L)
  n_breaks <- length(observation_breaks)
  current_state <- matrix(initial_state, nrow = n_inst, ncol = n_breaks)
  current_winner <- matrix(initial_winner, nrow = n_inst, ncol = n_breaks)
  current_reason <- matrix(initial_reason, nrow = n_inst, ncol = n_breaks)
  chunks <- vector("list", length(epochs) + 1L)
  if (n_axis > 0L) {
    chunks[[1L]] <- list(
      instrument = as.integer(seq_len(n_inst)),
      observation_from = rep(1L, n_inst),
      observation_to = rep(as.integer(n_axis + 1L), n_inst),
      knowledge_from = rep(-Inf, n_inst),
      state = initial_state,
      winner = initial_winner,
      reason = initial_reason
    )
  }
  for (epoch_idx in seq_along(epochs)) {
    start <- as.integer(epoch_start[[epoch_idx]])
    start_pos <- match(TRUE, observation_breaks >= start, nomatch = n_breaks + 1L)
    if (is.na(start) || start > n_axis || start_pos > n_breaks) next
    width <- n_breaks - start_pos + 1L
    cell_inst <- vector("list", width)
    cell_obs <- vector("list", width)
    cell_obs_to <- vector("list", width)
    cell_state <- vector("list", width)
    cell_winner <- vector("list", width)
    cell_reason <- vector("list", width)
    for (offset in seq_len(width)) {
      break_pos <- start_pos + offset - 1L
      pulse_idx <- observation_breaks[[break_pos]]
      answer <- resolve(axis[[pulse_idx]], epochs[[epoch_idx]])
      state <- dictionaries$state$encode(answer$state)
      winner <- dictionaries$winner$encode(answer$winner)
      reason <- dictionaries$reason$encode(answer$reason)
      changed <- state != current_state[, break_pos] |
        winner != current_winner[, break_pos] |
        reason != current_reason[, break_pos]
      if (any(changed)) {
        ids <- which(changed)
        cell_inst[[offset]] <- ids
        cell_obs[[offset]] <- rep.int(pulse_idx, length(ids))
        cell_obs_to[[offset]] <- rep.int(observation_to[[break_pos]], length(ids))
        cell_state[[offset]] <- state[ids]
        cell_winner[[offset]] <- winner[ids]
        cell_reason[[offset]] <- reason[ids]
        current_state[ids, break_pos] <- state[ids]
        current_winner[ids, break_pos] <- winner[ids]
        current_reason[ids, break_pos] <- reason[ids]
      }
    }
    chunks[[epoch_idx + 1L]] <- ledgr_history_segment_epoch_cells(
      inst = unlist(cell_inst, use.names = FALSE),
      obs = unlist(cell_obs, use.names = FALSE),
      obs_to = unlist(cell_obs_to, use.names = FALSE),
      knowledge = epochs[[epoch_idx]],
      state = unlist(cell_state, use.names = FALSE),
      winner = unlist(cell_winner, use.names = FALSE),
      reason = unlist(cell_reason, use.names = FALSE)
    )
  }
  out <- ledgr_history_segment_bind(chunks, dictionaries, n_inst)
  out$family <- family
  out$fact_count <- as.integer(fact_count)
  out$segment_count <- as.integer(out$count)
  out$segment_ratio <- out$segment_count / pmax(out$fact_count, 1L)
  limit <- if (is.null(segment_limit)) pmax(4L * out$fact_count, 16L) else rep(as.integer(segment_limit), n_inst)
  exceeded <- which(out$segment_count > limit)
  if (length(exceeded) > 0L) {
    i <- exceeded[[1L]]
    rlang::abort(
      sprintf(
        "History segment limit exceeded for instrument `%s`, family `%s`: %d segments for %d facts (ratio %.3f; limit %d).",
        instrument_ids[[i]], family, out$segment_count[[i]], out$fact_count[[i]],
        out$segment_ratio[[i]], limit[[i]]
      ),
      class = c("ledgr_history_segment_limit_exceeded", "ledgr_invalid_config"),
      instrument_id = instrument_ids[[i]],
      family = family,
      fact_count = out$fact_count[[i]],
      segment_count = out$segment_count[[i]],
      segment_ratio = out$segment_ratio[[i]],
      segment_limit = limit[[i]]
    )
  }
  out$limit <- as.integer(limit)
  out
}

ledgr_history_epoch_start <- function(axis, effective) {
  effective <- as.numeric(as.POSIXct(effective, tz = "UTC"))
  effective <- effective[is.finite(effective)]
  if (length(effective) == 0L) return(length(axis) + 1L)
  ledgr_history_axis_lower_bound(axis, min(effective))
}

ledgr_history_observation_breaks <- function(axis, ...) {
  clocks <- as.numeric(as.POSIXct(do.call(c, list(...)), tz = "UTC"))
  clocks <- sort(unique(clocks[is.finite(clocks)]))
  if (length(axis) == 0L) return(integer())
  index <- ledgr_history_axis_lower_bound(axis, clocks)
  sort(unique(c(1L, index[index <= length(axis)])))
}

ledgr_history_axis_lower_bound <- function(axis, clock) {
  axis <- as.numeric(as.POSIXct(axis, tz = "UTC"))
  clock <- as.numeric(as.POSIXct(clock, tz = "UTC"))
  if (length(clock) == 0L) return(integer())
  pos <- findInterval(clock, axis)
  exact <- pos > 0L
  exact[exact] <- axis[pos[exact]] == clock[exact]
  as.integer(pos + !exact)
}

ledgr_history_sparse_fact_segments <- function(rows,
                                               instrument_ids,
                                               axis,
                                               state,
                                               initial,
                                               reason,
                                               family,
                                               segment_limit) {
  n_inst <- length(instrument_ids)
  fact_instrument <- match(as.character(rows$instrument_id), instrument_ids)
  fact_count <- tabulate(fact_instrument, nbins = n_inst)
  if (any(fact_count > 1L)) return(NULL)

  dictionaries <- list(
    state = ledgr_history_segment_dictionary(),
    winner = ledgr_history_segment_dictionary(),
    reason = ledgr_history_segment_dictionary()
  )
  initial_chunk <- list(
    instrument = as.integer(seq_len(n_inst)),
    observation_from = rep(1L, n_inst),
    observation_to = rep(as.integer(length(axis) + 1L), n_inst),
    knowledge_from = rep(-Inf, n_inst),
    state = dictionaries$state$encode(rep(initial$state, n_inst)),
    winner = dictionaries$winner$encode(rep(initial$winner, n_inst)),
    reason = dictionaries$reason$encode(rep(initial$reason, n_inst))
  )
  if (nrow(rows) == 0L || length(axis) == 0L) {
    fact_chunk <- NULL
  } else {
    from <- ledgr_history_axis_lower_bound(axis, rows$effective_from)
    to <- rep.int(length(axis) + 1L, nrow(rows))
    finite_end <- !is.na(rows$effective_to)
    to[finite_end] <- ledgr_history_axis_lower_bound(
      axis, rows$effective_to[finite_end]
    )
    keep <- !is.na(fact_instrument) & from < to & from <= length(axis)
    fact_chunk <- if (!any(keep)) {
      NULL
    } else {
      list(
        instrument = as.integer(fact_instrument[keep]),
        observation_from = as.integer(from[keep]),
        observation_to = as.integer(to[keep]),
        knowledge_from = as.numeric(as.POSIXct(
          rows$knowledge_time[keep], tz = "UTC"
        )),
        state = dictionaries$state$encode(state[keep]),
        winner = dictionaries$winner$encode(
          as.character(rows$fact_id[keep])
        ),
        reason = dictionaries$reason$encode(rep(reason, sum(keep)))
      )
    }
  }
  out <- ledgr_history_segment_bind(
    list(initial_chunk, fact_chunk), dictionaries, n_inst
  )
  out$family <- family
  out$fact_count <- as.integer(fact_count)
  out$segment_count <- as.integer(out$count)
  out$segment_ratio <- out$segment_count / pmax(out$fact_count, 1L)
  limit <- if (is.null(segment_limit)) {
    pmax(4L * out$fact_count, 16L)
  } else {
    rep(as.integer(segment_limit), n_inst)
  }
  exceeded <- which(out$segment_count > limit)
  if (length(exceeded) > 0L) {
    i <- exceeded[[1L]]
    rlang::abort(
      sprintf(
        "History segment limit exceeded for instrument `%s`, family `%s`: %d segments for %d facts (ratio %.3f; limit %d).",
        instrument_ids[[i]], family, out$segment_count[[i]],
        out$fact_count[[i]], out$segment_ratio[[i]], limit[[i]]
      ),
      class = c("ledgr_history_segment_limit_exceeded", "ledgr_invalid_config"),
      instrument_id = instrument_ids[[i]],
      family = family,
      fact_count = out$fact_count[[i]],
      segment_count = out$segment_count[[i]],
      segment_ratio = out$segment_ratio[[i]],
      segment_limit = limit[[i]]
    )
  }
  out$limit <- as.integer(limit)
  out
}

ledgr_history_membership_is_diagonal <- function(headers, interval) {
  same_clock <- function(effective, knowledge) {
    if (length(effective) == 0L) return(TRUE)
    identical(
      as.numeric(as.POSIXct(effective, tz = "UTC")),
      as.numeric(as.POSIXct(knowledge, tz = "UTC"))
    )
  }
  same_clock(headers$effective_from, headers$knowledge_time) &&
    same_clock(interval$effective_from, interval$knowledge_time)
}

ledgr_history_membership_state <- function(member, reason) {
  member <- as.logical(member)
  reason <- as.character(reason)
  ifelse(
    !is.na(member),
    ifelse(member, "active", "inactive"),
    ifelse(grepl("conflict", reason, fixed = TRUE), "conflicting", "unknown")
  )
}

ledgr_history_membership_diagonal_segments <- function(data,
                                                        universe_id,
                                                        instrument_ids,
                                                        axis,
                                                        headers,
                                                        interval,
                                                        fact_count,
                                                        segment_limit) {
  breaks <- ledgr_history_observation_breaks(
    axis,
    headers$effective_from,
    interval$effective_from,
    interval$effective_to
  )
  ends <- c(breaks[-1L], length(axis) + 1L)
  members_at <- ledgr_availability_prepared_membership(
    data, universe_id, instrument_ids
  )
  resolve <- attr(members_at, "resolve", exact = TRUE)
  dictionaries <- list(
    state = ledgr_history_segment_dictionary(),
    winner = ledgr_history_segment_dictionary(),
    reason = ledgr_history_segment_dictionary()
  )
  initial_state <- dictionaries$state$encode(rep("unknown", length(instrument_ids)))
  initial_winner <- dictionaries$winner$encode(rep("", length(instrument_ids)))
  initial_reason <- dictionaries$reason$encode(
    rep("unknown_no_usable_evidence", length(instrument_ids))
  )
  initial <- list(
    instrument = as.integer(seq_along(instrument_ids)),
    observation_from = rep(1L, length(instrument_ids)),
    observation_to = rep(as.integer(length(axis) + 1L), length(instrument_ids)),
    knowledge_from = rep(-Inf, length(instrument_ids)),
    state = initial_state,
    winner = initial_winner,
    reason = initial_reason
  )
  cells <- lapply(seq_along(breaks), function(j) {
    answer <- resolve(as.numeric(axis[[breaks[[j]]]]))
    state <- ledgr_history_membership_state(
      ifelse(answer$known, answer$member, NA),
      answer$reason
    )
    reason <- answer$reason
    reason[!answer$known] <- "unknown_no_usable_evidence"
    keep <- is.finite(answer$knowledge) |
      state != "unknown" | answer$winner != "" |
      reason != "unknown_no_usable_evidence"
    if (!any(keep)) return(NULL)
    list(
      instrument = as.integer(which(keep)),
      observation_from = rep.int(breaks[[j]], sum(keep)),
      observation_to = rep.int(ends[[j]], sum(keep)),
      knowledge_from = as.numeric(answer$knowledge[keep]),
      state = dictionaries$state$encode(state[keep]),
      winner = dictionaries$winner$encode(answer$winner[keep]),
      reason = dictionaries$reason$encode(reason[keep])
    )
  })
  out <- ledgr_history_segment_bind(c(list(initial), cells), dictionaries, length(instrument_ids))
  out$family <- "membership"
  out$fact_count <- as.integer(fact_count)
  out$segment_count <- as.integer(out$count)
  out$segment_ratio <- out$segment_count / pmax(out$fact_count, 1L)
  limit <- if (is.null(segment_limit)) {
    pmax(4L * out$fact_count, 16L)
  } else {
    rep(as.integer(segment_limit), length(instrument_ids))
  }
  exceeded <- which(out$segment_count > limit)
  if (length(exceeded) > 0L) {
    i <- exceeded[[1L]]
    rlang::abort(
      sprintf(
        "History segment limit exceeded for instrument `%s`, family `membership`: %d segments for %d facts (ratio %.3f; limit %d).",
        instrument_ids[[i]], out$segment_count[[i]], out$fact_count[[i]],
        out$segment_ratio[[i]], limit[[i]]
      ),
      class = c("ledgr_history_segment_limit_exceeded", "ledgr_invalid_config"),
      instrument_id = instrument_ids[[i]],
      family = "membership",
      fact_count = out$fact_count[[i]],
      segment_count = out$segment_count[[i]],
      segment_ratio = out$segment_ratio[[i]],
      segment_limit = limit[[i]]
    )
  }
  out$limit <- as.integer(limit)
  out
}

ledgr_history_membership_complete_segments <- function(
    data,
    universe_id,
    instrument_ids,
    axis,
    headers,
    fact_count,
    segment_limit) {
  headers <- headers[order(
    headers$effective_from,
    headers$knowledge_time,
    headers$set_id,
    method = "radix"
  ), , drop = FALSE]
  set_index <- ledgr_membership_index_set_rows(
    data$membership,
    universe_id,
    headers$set_id
  )
  dictionaries <- list(
    state = ledgr_history_segment_dictionary(),
    winner = ledgr_history_segment_dictionary(),
    reason = ledgr_history_segment_dictionary()
  )
  n_inst <- length(instrument_ids)
  initial <- list(
    instrument = as.integer(seq_len(n_inst)),
    observation_from = rep(1L, n_inst),
    observation_to = rep(as.integer(length(axis) + 1L), n_inst),
    knowledge_from = rep(-Inf, n_inst),
    state = dictionaries$state$encode(rep("unknown", n_inst)),
    winner = dictionaries$winner$encode(rep("", n_inst)),
    reason = dictionaries$reason$encode(rep("unknown_no_usable_evidence", n_inst))
  )
  effective <- as.numeric(as.POSIXct(headers$effective_from, tz = "UTC"))
  observation_breaks <- sort(unique(c(
    1L,
    ledgr_history_axis_lower_bound(axis, headers$effective_from)
  )))
  observation_breaks <- observation_breaks[
    observation_breaks <= length(axis)
  ]
  observation_to <- c(observation_breaks[-1L], length(axis) + 1L)
  knowledge <- as.numeric(as.POSIXct(headers$knowledge_time, tz = "UTC"))
  header_rank <- seq_len(nrow(headers))
  header_from <- ledgr_history_axis_lower_bound(axis, headers$effective_from)
  header_break <- match(header_from, observation_breaks)
  epochs <- sort(unique(knowledge[is.finite(knowledge)]))
  selected <- integer(length(observation_breaks))
  chunks <- vector("list", length(epochs))
  for (epoch_idx in seq_along(epochs)) {
    epoch <- epochs[[epoch_idx]]
    before <- selected
    arriving <- which(knowledge == epoch)
    for (h in arriving) {
      from <- header_break[[h]]
      if (is.na(from) || from < 1L || from > length(selected)) next
      cells <- seq.int(from, length(selected))
      replace <- header_rank[[h]] > selected[cells]
      selected[cells[replace]] <- h
    }
    changed <- which(selected != before & selected > 0L)
    if (length(changed) == 0L) next
    run_start <- c(
      TRUE,
      diff(changed) != 1L | selected[changed[-1L]] != selected[changed[-length(changed)]]
    )
    run <- cumsum(run_start)
    first <- changed[!duplicated(run)]
    last <- changed[!duplicated(run, fromLast = TRUE)]
    parts <- vector("list", length(first))
    for (part_idx in seq_along(first)) {
      h <- selected[[first[[part_idx]]]]
      applied <- ledgr_membership_apply_prepared_header(
        known = logical(n_inst),
        state = logical(n_inst),
        reason = rep("", n_inst),
        winner = rep("", n_inst),
        selected_knowledge = rep(-Inf, n_inst),
        header = h,
        headers = headers,
        header_complete = rep(TRUE, nrow(headers)),
        header_knowledge = knowledge,
        set_index = set_index,
        key = instrument_ids
      )
      parts[[part_idx]] <- list(
        instrument = as.integer(seq_len(n_inst)),
        observation_from = rep.int(
          observation_breaks[[first[[part_idx]]]], n_inst
        ),
        observation_to = rep.int(
          observation_to[[last[[part_idx]]]], n_inst
        ),
        knowledge_from = rep(epoch, n_inst),
        state = dictionaries$state$encode(ifelse(
          applied$state, "active", "inactive"
        )),
        winner = dictionaries$winner$encode(applied$winner),
        reason = dictionaries$reason$encode(applied$reason)
      )
    }
    chunks[[epoch_idx]] <- list(
      instrument = unlist(lapply(parts, `[[`, "instrument"), use.names = FALSE),
      observation_from = unlist(lapply(parts, `[[`, "observation_from"), use.names = FALSE),
      observation_to = unlist(lapply(parts, `[[`, "observation_to"), use.names = FALSE),
      knowledge_from = unlist(lapply(parts, `[[`, "knowledge_from"), use.names = FALSE),
      state = unlist(lapply(parts, `[[`, "state"), use.names = FALSE),
      winner = unlist(lapply(parts, `[[`, "winner"), use.names = FALSE),
      reason = unlist(lapply(parts, `[[`, "reason"), use.names = FALSE)
    )
  }
  out <- ledgr_history_segment_bind(
    c(list(initial), chunks),
    dictionaries,
    n_inst
  )
  out$family <- "membership"
  out$fact_count <- as.integer(fact_count)
  out$segment_count <- as.integer(out$count)
  out$segment_ratio <- out$segment_count / pmax(out$fact_count, 1L)
  limit <- if (is.null(segment_limit)) {
    pmax(4L * out$fact_count, 16L)
  } else {
    rep(as.integer(segment_limit), n_inst)
  }
  exceeded <- which(out$segment_count > limit)
  if (length(exceeded) > 0L) {
    i <- exceeded[[1L]]
    rlang::abort(
      sprintf(
        "History segment limit exceeded for instrument `%s`, family `membership`: %d segments for %d facts (ratio %.3f; limit %d).",
        instrument_ids[[i]], out$segment_count[[i]], out$fact_count[[i]],
        out$segment_ratio[[i]], limit[[i]]
      ),
      class = c("ledgr_history_segment_limit_exceeded", "ledgr_invalid_config"),
      instrument_id = instrument_ids[[i]],
      family = "membership",
      fact_count = out$fact_count[[i]],
      segment_count = out$segment_count[[i]],
      segment_ratio = out$segment_ratio[[i]],
      segment_limit = limit[[i]]
    )
  }
  out$limit <- as.integer(limit)
  out
}

ledgr_history_membership_segments <- function(data,
                                              universe_id,
                                              instrument_ids,
                                              axis,
                                              segment_limit) {
  headers <- data$membership_sets
  headers <- headers[as.character(headers$universe_id) == universe_id, , drop = FALSE]
  rows <- data$membership
  rows <- rows[as.character(rows$universe_id) == universe_id, , drop = FALSE]
  interval <- rows[is.na(rows$set_id), , drop = FALSE]
  epoch_values <- c(
    as.numeric(as.POSIXct(headers$knowledge_time, tz = "UTC")),
    as.numeric(as.POSIXct(interval$knowledge_time, tz = "UTC"))
  )
  epochs <- sort(unique(epoch_values[is.finite(epoch_values)]))
  epoch_start <- vapply(epochs, function(epoch) {
    effective <- c(
      headers$effective_from[as.numeric(as.POSIXct(headers$knowledge_time, tz = "UTC")) == epoch],
      interval$effective_from[as.numeric(as.POSIXct(interval$knowledge_time, tz = "UTC")) == epoch]
    )
    ledgr_history_epoch_start(axis, effective)
  }, integer(1))
  resolver <- function(observation, knowledge) {
    answer <- ledgr_membership_resolve_prepared(
      data,
      universe_id,
      observation,
      instruments = instrument_ids,
      knowledge_cutoff = as.POSIXct(knowledge, origin = "1970-01-01", tz = "UTC")
    )$rows
    state <- ledgr_history_membership_state(answer$member, answer$reason)
    list(
      state = state,
      winner = as.character(answer$evidence_ids),
      reason = as.character(answer$reason)
    )
  }
  set_rows <- rows[!is.na(rows$set_id), , drop = FALSE]
  fact_count <- rep.int(as.integer(nrow(headers)), length(instrument_ids)) +
    tabulate(
      match(as.character(interval$instrument_id), instrument_ids),
      nbins = length(instrument_ids)
    ) +
    tabulate(
      match(as.character(set_rows$instrument_id), instrument_ids),
      nbins = length(instrument_ids)
    )
  if (nrow(interval) == 0L && nrow(headers) > 0L &&
      all(!is.na(headers$complete) & headers$complete)) {
    return(ledgr_history_membership_complete_segments(
      data,
      universe_id,
      instrument_ids,
      axis,
      headers,
      fact_count,
      segment_limit
    ))
  }
  if (ledgr_history_membership_is_diagonal(headers, interval)) {
    return(ledgr_history_membership_diagonal_segments(
      data,
      universe_id,
      instrument_ids,
      axis,
      headers,
      interval,
      fact_count,
      segment_limit
    ))
  }
  observation_breaks <- ledgr_history_observation_breaks(
    axis,
    headers$effective_from,
    interval$effective_from,
    interval$effective_to
  )
  ledgr_history_segments_build(
    axis, instrument_ids, epochs, epoch_start,
    initial = list(state = "unknown", winner = "", reason = "unknown_no_usable_evidence"),
    resolve = resolver,
    fact_count = fact_count,
    family = "membership",
    segment_limit = segment_limit,
    observation_breaks = observation_breaks
  )
}

ledgr_history_status_segments <- function(data,
                                          instrument_ids,
                                          axis,
                                          declared,
                                          segment_limit) {
  rows <- data$status
  if (!is.data.frame(rows)) rows <- data.frame()
  sparse <- ledgr_history_sparse_fact_segments(
    rows = rows,
    instrument_ids = instrument_ids,
    axis = axis,
    state = as.character(rows$status),
    initial = list(
      state = if (isTRUE(declared)) "unknown" else "active",
      winner = "",
      reason = if (isTRUE(declared)) {
        "status_unknown"
      } else {
        "status_undeclared_active"
      }
    ),
    reason = "status_asserted",
    family = "trading_status",
    segment_limit = segment_limit
  )
  if (!is.null(sparse)) return(sparse)
  knowledge <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$knowledge_time, tz = "UTC")) else numeric()
  epochs <- sort(unique(knowledge[is.finite(knowledge)]))
  epoch_start <- vapply(epochs, function(epoch) {
    ledgr_history_epoch_start(axis, rows$effective_from[knowledge == epoch])
  }, integer(1))
  status <- as.character(rows$status)
  precedence <- as.integer(rows$precedence)
  fact_id <- as.character(rows$fact_id)
  lineage <- if (nrow(rows) > 0L) ledgr_status_lineage(rows) else list()
  inst <- as.character(rows$instrument_id)
  by_instrument <- split(
    seq_len(nrow(rows)),
    factor(match(inst, instrument_ids), levels = seq_along(instrument_ids))
  )
  active_instrument <- which(lengths(by_instrument) > 0L)
  effective <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$effective_from, tz = "UTC")) else numeric()
  end <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$effective_to, tz = "UTC")) else numeric()
  end[is.na(end)] <- Inf
  resolver <- function(observation, cutoff) {
    s <- as.numeric(observation)
    out_state <- rep(if (isTRUE(declared)) "unknown" else "active", length(instrument_ids))
    out_winner <- rep("", length(instrument_ids))
    out_reason <- rep(if (isTRUE(declared)) "status_unknown" else "status_undeclared_active", length(instrument_ids))
    known <- knowledge <= cutoff & effective <= s & s < end
    for (i in active_instrument) {
      candidate <- by_instrument[[i]]
      applicable <- candidate[known[candidate]]
      if (length(applicable) == 0L) next
      answer <- ledgr_history_status_resolve_applicable(
        applicable, status, precedence, fact_id, lineage
      )
      out_state[[i]] <- answer$state
      out_winner[[i]] <- answer$winner
      out_reason[[i]] <- answer$reason
    }
    list(state = out_state, winner = out_winner, reason = out_reason)
  }
  fact_count <- tabulate(match(inst, instrument_ids), nbins = length(instrument_ids))
  observation_breaks <- ledgr_history_observation_breaks(
    axis, rows$effective_from, rows$effective_to
  )
  ledgr_history_segments_build(
    axis, instrument_ids, epochs, epoch_start,
    initial = list(
      state = if (isTRUE(declared)) "unknown" else "active",
      winner = "",
      reason = if (isTRUE(declared)) "status_unknown" else "status_undeclared_active"
    ),
    resolve = resolver,
    fact_count = fact_count,
    family = "trading_status",
    segment_limit = segment_limit,
    observation_breaks = observation_breaks
  )
}

ledgr_history_lifetime_segments <- function(data,
                                            instrument_ids,
                                            axis,
                                            segment_limit) {
  rows <- data$lifetime
  if (!is.data.frame(rows)) rows <- data.frame()
  sparse <- ledgr_history_sparse_fact_segments(
    rows = rows,
    instrument_ids = instrument_ids,
    axis = axis,
    state = as.character(rows$assertion),
    initial = list(
      state = "unknown", winner = "", reason = "lifetime_unknown"
    ),
    reason = "lifetime_asserted",
    family = "lifetime",
    segment_limit = segment_limit
  )
  if (!is.null(sparse)) return(sparse)
  knowledge <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$knowledge_time, tz = "UTC")) else numeric()
  epochs <- sort(unique(knowledge[is.finite(knowledge)]))
  epoch_start <- vapply(epochs, function(epoch) {
    ledgr_history_epoch_start(axis, rows$effective_from[knowledge == epoch])
  }, integer(1))
  assertion <- as.character(rows$assertion)
  terminal <- as.character(rows$terminal_event)
  terminal[is.na(terminal)] <- ""
  fact_id <- as.character(rows$fact_id)
  inst <- as.character(rows$instrument_id)
  by_instrument <- split(
    seq_len(nrow(rows)),
    factor(match(inst, instrument_ids), levels = seq_along(instrument_ids))
  )
  active_instrument <- which(lengths(by_instrument) > 0L)
  effective <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$effective_from, tz = "UTC")) else numeric()
  end <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$effective_to, tz = "UTC")) else numeric()
  end[is.na(end)] <- Inf
  rank <- if (nrow(rows) > 0L) order(order(effective, knowledge, seq_len(nrow(rows)))) else integer()
  resolver <- function(observation, cutoff) {
    s <- as.numeric(observation)
    out_state <- rep("unknown", length(instrument_ids))
    out_winner <- rep("", length(instrument_ids))
    out_reason <- rep("lifetime_unknown", length(instrument_ids))
    known <- knowledge <= cutoff & effective <= s & s < end
    for (i in active_instrument) {
      candidate <- by_instrument[[i]]
      applicable <- candidate[known[candidate]]
      if (length(applicable) == 0L) next
      answer <- ledgr_history_lifetime_resolve_applicable(
        applicable, assertion, terminal, fact_id, rank
      )
      out_state[[i]] <- answer$state
      out_winner[[i]] <- answer$winner
      out_reason[[i]] <- answer$reason
    }
    list(state = out_state, winner = out_winner, reason = out_reason)
  }
  fact_count <- tabulate(match(inst, instrument_ids), nbins = length(instrument_ids))
  observation_breaks <- ledgr_history_observation_breaks(
    axis, rows$effective_from, rows$effective_to
  )
  ledgr_history_segments_build(
    axis, instrument_ids, epochs, epoch_start,
    initial = list(state = "unknown", winner = "", reason = "lifetime_unknown"),
    resolve = resolver,
    fact_count = fact_count,
    family = "lifetime",
    segment_limit = segment_limit,
    observation_breaks = observation_breaks
  )
}

ledgr_history_terminal_segments <- function(data,
                                             instrument_ids,
                                             axis,
                                             segment_limit) {
  rows <- data$lifetime
  if (!is.data.frame(rows)) rows <- data.frame()
  terminal <- if (nrow(rows) > 0L) {
    as.character(rows$terminal_event)
  } else {
    character()
  }
  keep <- !is.na(terminal) & nzchar(terminal)
  rows <- rows[keep, , drop = FALSE]
  terminal <- terminal[keep]
  if (nrow(rows) > 0L) {
    rows$effective_to <- as.POSIXct(
      rep(NA_real_, nrow(rows)), origin = "1970-01-01", tz = "UTC"
    )
  }
  sparse <- ledgr_history_sparse_fact_segments(
    rows = rows,
    instrument_ids = instrument_ids,
    axis = axis,
    state = terminal,
    initial = list(
      state = "", winner = "", reason = "terminal_not_asserted"
    ),
    reason = "terminal_asserted",
    family = "lifetime_terminal",
    segment_limit = segment_limit
  )
  if (!is.null(sparse)) return(sparse)

  knowledge <- as.numeric(as.POSIXct(rows$knowledge_time, tz = "UTC"))
  epochs <- sort(unique(knowledge[is.finite(knowledge)]))
  epoch_start <- vapply(epochs, function(epoch) {
    ledgr_history_epoch_start(axis, rows$effective_from[knowledge == epoch])
  }, integer(1))
  effective <- as.numeric(as.POSIXct(rows$effective_from, tz = "UTC"))
  fact_id <- as.character(rows$fact_id)
  instrument <- as.character(rows$instrument_id)
  by_instrument <- split(
    seq_len(nrow(rows)),
    factor(match(instrument, instrument_ids), levels = seq_along(instrument_ids))
  )
  active_instrument <- which(lengths(by_instrument) > 0L)
  rank <- order(order(effective, knowledge, seq_len(nrow(rows))))
  resolve <- function(observation, cutoff) {
    observation <- as.numeric(observation)
    out_state <- rep("", length(instrument_ids))
    out_winner <- rep("", length(instrument_ids))
    out_reason <- rep("terminal_not_asserted", length(instrument_ids))
    known <- knowledge <= cutoff & effective <= observation
    for (i in active_instrument) {
      candidate <- by_instrument[[i]]
      applicable <- candidate[known[candidate]]
      if (length(applicable) == 0L) next
      winner <- applicable[[which.max(rank[applicable])]]
      out_state[[i]] <- terminal[[winner]]
      out_winner[[i]] <- fact_id[[winner]]
      out_reason[[i]] <- "terminal_asserted"
    }
    list(state = out_state, winner = out_winner, reason = out_reason)
  }
  fact_count <- tabulate(
    match(instrument, instrument_ids), nbins = length(instrument_ids)
  )
  ledgr_history_segments_build(
    axis, instrument_ids, epochs, epoch_start,
    initial = list(
      state = "", winner = "", reason = "terminal_not_asserted"
    ),
    resolve = resolve,
    fact_count = fact_count,
    family = "lifetime_terminal",
    segment_limit = segment_limit,
    observation_breaks = ledgr_history_observation_breaks(
      axis, rows$effective_from
    )
  )
}

ledgr_history_segments_query <- function(segments,
                                         observation_idx,
                                         knowledge,
                                         instrument_idx) {
  observation_idx <- as.integer(observation_idx)
  knowledge <- as.numeric(as.POSIXct(knowledge, tz = "UTC"))
  instrument_idx <- as.integer(instrument_idx)
  state <- winner <- reason <- integer(length(instrument_idx))
  for (j in seq_along(instrument_idx)) {
    i <- instrument_idx[[j]]
    idx <- seq.int(segments$off[[i]], length.out = segments$count[[i]])
    hit <- idx[
      segments$observation_from[idx] <= observation_idx &
        observation_idx < segments$observation_to[idx] &
        segments$knowledge_from[idx] <= knowledge
    ]
    if (length(hit) == 0L) {
      rlang::abort(
        "History segments do not cover the requested observation.",
        class = c("ledgr_history_segment_missing", "ledgr_invalid_history_substrate")
      )
    }
    selected <- hit[[which.max(segments$knowledge_from[hit])]]
    state[[j]] <- segments$state[[selected]]
    winner[[j]] <- segments$winner[[selected]]
    reason[[j]] <- segments$reason[[selected]]
  }
  list(
    state = segments$state_levels[state],
    winner = segments$winner_levels[winner],
    reason = segments$reason_levels[reason]
  )
}

ledgr_history_segments_materialize <- function(segments,
                                                cutoff,
                                                observation_idx,
                                                instrument_idx) {
  cutoff <- as.numeric(as.POSIXct(cutoff, tz = "UTC"))
  observation_idx <- as.integer(observation_idx)
  instrument_idx <- as.integer(instrument_idx)
  n_inst <- length(instrument_idx)
  n_obs <- length(observation_idx)
  state <- winner <- reason <- matrix(NA_integer_, nrow = n_inst, ncol = n_obs)
  for (j in seq_along(instrument_idx)) {
    i <- instrument_idx[[j]]
    rows <- seq.int(segments$off[[i]], length.out = segments$count[[i]])
    rows <- rows[segments$knowledge_from[rows] <= cutoff]
    rows <- rows[order(
      segments$knowledge_from[rows],
      segments$observation_from[rows],
      method = "radix"
    )]
    for (row in rows) {
      hit <- observation_idx >= segments$observation_from[[row]] &
        observation_idx < segments$observation_to[[row]]
      if (!any(hit)) next
      state[j, hit] <- segments$state[[row]]
      winner[j, hit] <- segments$winner[[row]]
      reason[j, hit] <- segments$reason[[row]]
    }
  }
  if (anyNA(state) || anyNA(winner) || anyNA(reason)) {
    rlang::abort(
      "History segments do not cover the requested observation plane.",
      class = c("ledgr_history_segment_missing", "ledgr_invalid_history_substrate")
    )
  }
  list(
    state = matrix(segments$state_levels[state], nrow = n_inst, ncol = n_obs),
    winner = matrix(segments$winner_levels[winner], nrow = n_inst, ncol = n_obs),
    reason = matrix(segments$reason_levels[reason], nrow = n_inst, ncol = n_obs)
  )
}

ledgr_history_substrate_fact_plane <- function(substrate,
                                               family,
                                               cutoff,
                                               observation_idx = seq_along(substrate$axis),
                                               instrument_idx = seq_along(substrate$instrument_ids)) {
  ledgr_history_substrate_require(substrate)
  if (!family %in% names(substrate$segments)) {
    rlang::abort("Unknown history fact family.", class = "ledgr_invalid_args")
  }
  ledgr_history_segments_materialize(
    substrate$segments[[family]], cutoff, observation_idx, instrument_idx
  )
}

ledgr_history_substrate_expected_at <- function(substrate,
                                                cutoff,
                                                observation_idx = seq_along(substrate$axis),
                                                instrument_idx = seq_along(substrate$instrument_ids)) {
  lifetime <- ledgr_history_substrate_fact_plane(
    substrate,
    "lifetime",
    cutoff,
    observation_idx,
    instrument_idx
  )
  lifetime$state != "known_inactive"
}

ledgr_history_substrate_terminal_at <- function(
    substrate,
    cutoff,
    observation_idx = seq_along(substrate$axis),
    instrument_idx = seq_along(substrate$instrument_ids)) {
  terminal <- ledgr_history_substrate_fact_plane(
    substrate,
    "lifetime_terminal",
    cutoff,
    observation_idx,
    instrument_idx
  )
  matrix(
    nzchar(terminal$state),
    nrow = nrow(terminal$state),
    ncol = ncol(terminal$state)
  )
}

ledgr_history_segments_diagonal_state <- function(segments, axis) {
  n_inst <- length(segments$count)
  n_axis <- length(axis)
  out <- matrix("unknown", nrow = n_inst, ncol = n_axis)
  for (i in seq_len(n_inst)) {
    rows <- seq.int(segments$off[[i]], length.out = segments$count[[i]])
    rows <- rows[order(
      segments$knowledge_from[rows],
      segments$observation_from[rows],
      method = "radix"
    )]
    knowledge_start <- ledgr_history_axis_lower_bound(
      axis, segments$knowledge_from[rows]
    )
    for (j in seq_along(rows)) {
      row <- rows[[j]]
      from <- max(segments$observation_from[[row]], knowledge_start[[j]])
      to <- min(segments$observation_to[[row]] - 1L, n_axis)
      if (from <= to) {
        out[i, from:to] <- segments$state_levels[segments$state[[row]]]
      }
    }
  }
  out
}

ledgr_history_substrate_query_facts <- function(substrate,
                                                family,
                                                observation,
                                                cutoff,
                                                ids = substrate$instrument_ids) {
  ledgr_history_substrate_require(substrate)
  observation_idx <- match(
    as.numeric(as.POSIXct(observation, tz = "UTC")),
    as.numeric(substrate$axis)
  )
  if (length(observation_idx) != 1L || is.na(observation_idx)) {
    rlang::abort(
      "History fact observation must name one prepared venue session.",
      class = c("ledgr_history_outside_axis", "ledgr_invalid_args")
    )
  }
  ids <- as.character(ids)
  instrument_idx <- unname(substrate$instrument_index[ids])
  if (anyNA(instrument_idx)) {
    rlang::abort(
      sprintf("Unknown history instrument_id(s): %s.", paste(ids[is.na(instrument_idx)], collapse = ", ")),
      class = c("ledgr_history_unknown_instrument", "ledgr_invalid_args")
    )
  }
  answer <- ledgr_history_segments_query(
    substrate$segments[[family]], observation_idx, cutoff, instrument_idx
  )
  answer$state <- stats::setNames(answer$state, ids)
  answer$winner <- stats::setNames(answer$winner, ids)
  answer$reason <- stats::setNames(answer$reason, ids)
  answer
}

ledgr_history_substrate <- function(bars,
                                    instrument_ids,
                                    axis,
                                    availability_data,
                                    availability_config,
                                    snapshot_hash,
                                    source_start_utc = NULL) {
  instrument_ids <- as.character(instrument_ids)
  axis <- as.POSIXct(axis, tz = "UTC")
  if (anyNA(instrument_ids) || any(!nzchar(instrument_ids)) ||
      anyDuplicated(instrument_ids) || anyNA(axis) || is.unsorted(axis, strictly = TRUE)) {
    rlang::abort(
      "History substrate identity and venue axis must be unique, complete and strictly ordered.",
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_config")
    )
  }
  if (is.null(source_start_utc)) {
    source_start_utc <- if (length(axis) > 0L) {
      axis[[1L]]
    } else {
      as.POSIXct(NA, tz = "UTC")
    }
  }
  source_start_utc <- ledgr_history_utc(source_start_utc)
  if (length(source_start_utc) != 1L || is.na(source_start_utc)) {
    rlang::abort(
      "History substrate source_start_utc must be one finite UTC instant.",
      class = c("ledgr_invalid_history_substrate", "ledgr_invalid_config")
    )
  }
  policy <- ledgr_history_policy_normalize(availability_config$history_policy)
  families <- as.character(availability_data$families$family)
  universe_rule <- availability_config$availability$universe_rule
  if (!is.null(universe_rule)) class(universe_rule) <- c("ledgr_universe_rule", "list")
  membership <- if (is.null(universe_rule)) {
    NULL
  } else {
    ledgr_history_membership_segments(
      availability_data,
      as.character(universe_rule$universe_id),
      instrument_ids,
      axis,
      policy$segment_limit
    )
  }
  status <- ledgr_history_status_segments(
    availability_data,
    instrument_ids,
    axis,
    declared = "trading_status" %in% families,
    segment_limit = policy$segment_limit
  )
  lifetime <- ledgr_history_lifetime_segments(
    availability_data,
    instrument_ids,
    axis,
    segment_limit = policy$segment_limit
  )
  terminal <- ledgr_history_terminal_segments(
    availability_data,
    instrument_ids,
    axis,
    segment_limit = policy$segment_limit
  )
  segments <- list(
    trading_status = status,
    lifetime = lifetime,
    lifetime_terminal = terminal
  )
  if (!is.null(membership)) segments$membership <- membership
  bars_matrix <- ledgr_history_substrate_bar_matrices(
    bars, instrument_ids, axis
  )
  out <- structure(
    list(
      substrate_version = ledgr_history_substrate_version,
      snapshot_hash = as.character(snapshot_hash),
      policy_identity = ledgr_history_policy_identity(policy),
      history_policy = policy,
      source_start_utc = source_start_utc,
      data_start_utc = if (length(axis) > 0L) axis[[1L]] else as.POSIXct(NA, tz = "UTC"),
      instrument_ids = instrument_ids,
      instrument_index = stats::setNames(seq_along(instrument_ids), instrument_ids),
      axis = axis,
      pulse_index = stats::setNames(seq_along(axis), ledgr_projection_pulse_names(axis)),
      bars = bars_matrix,
      segments = segments,
      families = list(
        declared = sort(unique(families), method = "radix"),
        membership_complete = if (is.data.frame(availability_data$membership_sets)) {
          availability_data$membership_sets[, c("universe_id", "set_id", "complete"), drop = FALSE]
        } else {
          data.frame()
        }
      ),
      sessions = availability_data$sessions,
      valuation_policy = availability_config$availability$valuation_policy,
      universe_rule = universe_rule,
      provider_plan = ledgr_availability_provider_prepare(
        availability_data,
        availability_config
      )
    ),
    class = c("ledgr_history_substrate", "list")
  )
  lifetime_diagonal <- ledgr_history_segments_diagonal_state(
    out$segments$lifetime,
    axis
  ) != "known_inactive"
  out$expected <- lifetime_diagonal
  status_diagonal <- ledgr_history_segments_diagonal_state(
    out$segments$trading_status,
    axis
  )
  out$halted <- matrix(
    status_diagonal %in% c("halted", "quotation_only"),
    nrow = nrow(status_diagonal),
    ncol = ncol(status_diagonal)
  )
  out$missing_expected_bar <- lifetime_diagonal & !bars_matrix$observed
  out$inactive_print <- !lifetime_diagonal & bars_matrix$observed
  out
}

ledgr_availability_provider_from_substrate <- function(substrate,
                                                       config,
                                                       snapshot_hash) {
  ledgr_history_substrate_require(substrate)
  history <- ledgr_history_substrate_history_reader(substrate)
  ledgr_availability_provider_from_plan(
    substrate$provider_plan,
    config,
    snapshot_hash,
    history,
    history_substrate_version = substrate$substrate_version
  )
}

ledgr_history_substrate_census <- function(substrate) {
  ledgr_history_substrate_require(substrate)
  rows <- lapply(names(substrate$segments), function(family) {
    x <- substrate$segments[[family]]
    data.frame(
      instrument_id = substrate$instrument_ids,
      family = family,
      fact_count = as.integer(x$fact_count),
      segment_count = as.integer(x$segment_count),
      segment_ratio = as.numeric(x$segment_ratio),
      segment_limit = as.integer(x$limit),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
