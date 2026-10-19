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
  bars <- ledgr_precompute_fetch_bars_frame(
    exp$snapshot, exp$universe, meta$start, end
  )
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

# The instant from which every availability entry point calculates feature
# state: one rule shared by runs, sweeps, windows, explicit precompute and
# pulse inspection. History has a single start, the data start (the first
# session of the experiment's snapshot); the scoring start bounds decisions
# only (v12 Section 2).
ledgr_history_calculation_start <- function(substrate) {
  ledgr_history_substrate_require(substrate)
  substrate$data_start_utc
}

ledgr_history_precompute_payload <- function(unique_defs,
                                             substrate,
                                             calculation_start = NULL,
                                             calculation_end = NULL) {
  ledgr_history_substrate_require(substrate)
  values <- ledgr_history_compute_feature_series(
    substrate = substrate,
    definitions = unique_defs,
    calculation_start = calculation_start,
    calculation_end = calculation_end
  )
  fingerprints <- names(unique_defs)
  planes <- attr(values, "ledgr_feature_planes")
  out <- vector("list", length(fingerprints))
  for (d in seq_along(fingerprints)) {
    matrix_values <- values[[d]]
    # Release each matrix once it is split so the payload and the matrices
    # are never both held in full.
    values[d] <- list(NULL)
    out[[d]] <- list(
      feature_id = unique_defs[[d]]$id,
      fingerprint = fingerprints[[d]],
      values = stats::setNames(
        lapply(seq_along(substrate$instrument_ids), function(i) matrix_values[i, ]),
        substrate$instrument_ids
      ),
      planes = planes[[d]]
    )
  }
  names(out) <- fingerprints
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
  out$observed[linear] <- TRUE
  out
}

# One pulse column of the bar planes. P1 reads `close` for marks, P2 builds
# ctx$bars from the packet and P3/P4 fill at the next packet's OHLCV.
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
    observed = as.logical(bars$observed[, pulse_idx])
  )
}

# The ctx$bars frame of one packet. Every substrate bar comes from a sealed
# snapshot row and is never synthetic, so `gap_type` is "NONE" where a bar
# row filled the cell and "MISSING_EXPECTED_SESSION" elsewhere, and
# `is_synthetic` is FALSE; both are derived here rather than stored as planes.
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
    gap_type = c("MISSING_EXPECTED_SESSION", "NONE")[
      packet$observed[instrument_idx] + 1L
    ],
    is_synthetic = rep(FALSE, length(instrument_idx)),
    stringsAsFactors = FALSE
  )
}

ledgr_history_substrate_fold_reader <- function(substrate,
                                                pulses_posix,
                                                feature_defs = list(),
                                                active_alias_map = NULL) {
  ledgr_history_substrate_require(substrate)
  service <- ledgr_history_read_service(
    substrate,
    feature_defs = feature_defs,
    active_alias_map = active_alias_map
  )
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
      # The final pulse of a continued carry window executes at the next
      # prepared session's open, which lies beyond the fold's own pulses.
      next_column <- if (pulse_idx < length(pulse_columns)) {
        pulse_columns[[pulse_idx + 1L]]
      } else {
        pulse_columns[[pulse_idx]] + 1L
      }
      next_packet <- if (next_column <= length(substrate$axis)) {
        ledgr_history_substrate_bar_packet(substrate, next_column)
      } else {
        NULL
      }
      list(current = current, next_bar = next_packet)
    },
    # The cutoff-bound history view P2 places on the strategy context. It
    # records only the pulse column; values are read when a strategy asks.
    view = function(pulse_idx) {
      ledgr_history_view(service, pulse_columns[[as.integer(pulse_idx)]])
    },
    stats = function() list(reads = reads)
  )
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

ledgr_history_fact_segments_by_instrument <- function(rows,
                                                       instrument_ids,
                                                       axis,
                                                       initial,
                                                       family,
                                                       segment_limit,
                                                       resolve_one) {
  n_inst <- length(instrument_ids)
  row_instrument <- match(as.character(rows$instrument_id), instrument_ids)
  fact_count <- tabulate(row_instrument, nbins = n_inst)
  by_instrument <- split(
    seq_len(nrow(rows)),
    factor(row_instrument, levels = seq_len(n_inst)),
    drop = FALSE
  )
  dictionaries <- list(
    state = ledgr_history_segment_dictionary(),
    winner = ledgr_history_segment_dictionary(),
    reason = ledgr_history_segment_dictionary()
  )
  chunks <- vector("list", nrow(rows) + 1L)
  chunk_count <- 1L
  chunks[[chunk_count]] <- list(
    instrument = as.integer(seq_len(n_inst)),
    observation_from = rep(1L, n_inst),
    observation_to = rep(as.integer(length(axis) + 1L), n_inst),
    knowledge_from = rep(-Inf, n_inst),
    state = dictionaries$state$encode(rep(initial$state, n_inst)),
    winner = dictionaries$winner$encode(rep(initial$winner, n_inst)),
    reason = dictionaries$reason$encode(rep(initial$reason, n_inst))
  )
  if (length(axis) > 0L) {
    for (instrument in which(fact_count > 0L)) {
      indices <- by_instrument[[instrument]]
      knowledge <- as.numeric(as.POSIXct(
        rows$knowledge_time[indices], tz = "UTC"
      ))
      epochs <- sort(unique(knowledge[is.finite(knowledge)]))
      breaks <- ledgr_history_observation_breaks(
        axis,
        rows$effective_from[indices],
        rows$effective_to[indices]
      )
      ends <- c(breaks[-1L], length(axis) + 1L)
      current_state <- rep(initial$state, length(breaks))
      current_winner <- rep(initial$winner, length(breaks))
      current_reason <- rep(initial$reason, length(breaks))
      for (epoch in epochs) {
        newly_known <- indices[knowledge == epoch]
        start <- ledgr_history_epoch_start(
          axis, rows$effective_from[newly_known]
        )
        start_pos <- match(TRUE, breaks >= start, nomatch = length(breaks) + 1L)
        if (start_pos > length(breaks)) next
        changed_at <- integer(length(breaks))
        changed_state <- changed_winner <- changed_reason <-
          character(length(breaks))
        changed_count <- 0L
        for (break_pos in seq.int(start_pos, length(breaks))) {
          answer <- resolve_one(indices, axis[[breaks[[break_pos]]]], epoch)
          changed <- !identical(answer$state, current_state[[break_pos]]) ||
            !identical(answer$winner, current_winner[[break_pos]]) ||
            !identical(answer$reason, current_reason[[break_pos]])
          if (!changed) next
          changed_count <- changed_count + 1L
          changed_at[[changed_count]] <- break_pos
          changed_state[[changed_count]] <- answer$state
          changed_winner[[changed_count]] <- answer$winner
          changed_reason[[changed_count]] <- answer$reason
          current_state[[break_pos]] <- answer$state
          current_winner[[break_pos]] <- answer$winner
          current_reason[[break_pos]] <- answer$reason
        }
        if (changed_count == 0L) next
        selected <- seq_len(changed_count)
        chunk_count <- chunk_count + 1L
        chunks[[chunk_count]] <- ledgr_history_segment_epoch_cells(
          inst = rep.int(instrument, changed_count),
          obs = breaks[changed_at[selected]],
          obs_to = ends[changed_at[selected]],
          knowledge = epoch,
          state = dictionaries$state$encode(changed_state[selected]),
          winner = dictionaries$winner$encode(changed_winner[selected]),
          reason = dictionaries$reason$encode(changed_reason[selected])
        )
      }
    }
  }
  out <- ledgr_history_segment_bind(
    chunks[seq_len(chunk_count)], dictionaries, n_inst
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

# Cut 16 decision (22): membership and trading-status history segments are
# counted, not stored. The segment guard below receives each family's per-
# instrument fact and segment counts and refuses exactly as the stored
# compilers did; lifetime and terminal segments are still compiled and stored
# because history reads use them, and their compilers keep their own guard.
ledgr_history_segment_limit_check <- function(fact_count,
                                              segment_count,
                                              instrument_ids,
                                              family,
                                              segment_limit) {
  fact_count <- as.integer(fact_count)
  segment_count <- as.integer(segment_count)
  segment_ratio <- segment_count / pmax(fact_count, 1L)
  limit <- if (is.null(segment_limit)) {
    pmax(4L * fact_count, 16L)
  } else {
    rep(as.integer(segment_limit), length(instrument_ids))
  }
  exceeded <- which(segment_count > limit)
  if (length(exceeded) > 0L) {
    i <- exceeded[[1L]]
    rlang::abort(
      sprintf(
        "History segment limit exceeded for instrument `%s`, family `%s`: %d segments for %d facts (ratio %.3f; limit %d).",
        instrument_ids[[i]], family, segment_count[[i]], fact_count[[i]],
        segment_ratio[[i]], limit[[i]]
      ),
      class = c("ledgr_history_segment_limit_exceeded", "ledgr_invalid_config"),
      instrument_id = instrument_ids[[i]],
      family = family,
      fact_count = fact_count[[i]],
      segment_count = segment_count[[i]],
      segment_ratio = segment_ratio[[i]],
      segment_limit = limit[[i]]
    )
  }
  list(
    family = family,
    fact_count = fact_count,
    segment_count = segment_count,
    segment_ratio = segment_ratio,
    limit = as.integer(limit)
  )
}

# Number of maximal blocks of [a, z) (half-open axis positions) that no cover
# interval [cover_start, cover_end) reaches, for each region a[k], z[k].
ledgr_history_uncovered_pieces <- function(a, z, cover_start, cover_end) {
  keep <- cover_start < cover_end
  cover_start <- cover_start[keep]
  cover_end <- cover_end[keep]
  if (length(cover_start) == 0L) return(as.integer(a < z))
  ord <- order(cover_start, cover_end)
  cover_start <- cover_start[ord]
  cover_end <- cover_end[ord]
  # Merge overlapping or touching cover intervals.
  reach <- cummax(cover_end)
  opens <- c(TRUE, cover_start[-1L] > reach[-length(reach)])
  group <- cumsum(opens)
  merged_start <- cover_start[opens]
  merged_end <- as.numeric(tapply(reach, group, max))
  gap_start <- c(-Inf, merged_end)
  gap_end <- c(merged_start, Inf)
  pieces <- outer(z, gap_end, pmin) > outer(a, gap_start, pmax)
  as.integer(rowSums(pieces))
}

# Two-clock membership segment counts for the complete-set, interval-only and
# lagged (family-wide) cases. An instrument's answer at an observation break
# and knowledge cutoff is decided by one fact: the last applicable interval
# row, else the last eligible relevant header in canonical order (every
# complete header, and the incomplete headers that list the instrument), else
# none. Distinct facts give distinct (state, winner, reason) answers, so the
# segments the canonical epoch compilers produced are exactly one initial
# segment plus, for every fact, the number of contiguous axis blocks it wins
# when it becomes known (together with every fact known no later). A header
# wins from its own break until the next later-ranked relevant header known by
# then, minus the axis covered by intervals known by then; an interval wins
# its own span minus later-ordered intervals known by then.
ledgr_history_membership_fact_counts <- function(headers,
                                                 set_rows,
                                                 interval,
                                                 instrument_ids,
                                                 axis,
                                                 header_method) {
  n_inst <- length(instrument_ids)
  none <- length(axis) + 1L
  n_head <- nrow(headers)
  head_break <- if (n_head > 0L) {
    ledgr_history_axis_lower_bound(axis, headers$effective_from)
  } else {
    integer()
  }
  head_known <- as.numeric(as.POSIXct(headers$knowledge_time, tz = "UTC"))
  head_rank <- integer(n_head)
  if (n_head > 0L) {
    head_rank[order(
      headers$effective_from, headers$knowledge_time, headers$set_id,
      method = header_method
    )] <- seq_len(n_head)
  }
  head_valid <- is.finite(head_known) & !is.na(headers$effective_from)
  head_complete <- head_valid & !is.na(headers$complete) & as.logical(headers$complete)
  complete <- which(head_complete)
  # First break, per header, of a later-ranked complete header known by the
  # time that header is known.
  blocked_by_complete <- rep.int(none, n_head)
  for (y in complete) {
    later <- head_rank[[y]] > head_rank & head_known[[y]] <= head_known
    blocked_by_complete[later] <- pmin(blocked_by_complete[later], head_break[[y]])
  }
  complete_wins <- head_break[complete] < pmin(blocked_by_complete[complete], none)
  shared <- 1L + sum(complete_wins)
  counts <- rep.int(shared, n_inst)

  member_header <- match(as.character(set_rows$set_id), as.character(headers$set_id))
  member_inst <- match(as.character(set_rows$instrument_id), instrument_ids)
  incomplete_pair <- !is.na(member_header) & !is.na(member_inst) &
    head_valid[member_header] & !head_complete[member_header]
  incomplete_by_inst <- split(
    member_header[incomplete_pair],
    factor(member_inst[incomplete_pair], levels = seq_len(n_inst))
  )
  iv_inst <- match(as.character(interval$instrument_id), instrument_ids)
  iv_known <- as.numeric(as.POSIXct(interval$knowledge_time, tz = "UTC"))
  iv_valid <- !is.na(iv_inst) & is.finite(iv_known) & !is.na(interval$effective_from)
  iv_start <- if (nrow(interval) > 0L) {
    ledgr_history_axis_lower_bound(axis, interval$effective_from)
  } else {
    integer()
  }
  iv_end <- rep.int(none, nrow(interval))
  finite_end <- !is.na(interval$effective_to)
  iv_end[finite_end] <- ledgr_history_axis_lower_bound(axis, interval$effective_to[finite_end])
  iv_end <- pmin(iv_end, none)
  iv_order <- integer(nrow(interval))
  if (nrow(interval) > 0L) {
    iv_order[order(interval$effective_from, interval$knowledge_time, interval$fact_id)] <-
      seq_len(nrow(interval))
  }
  intervals_by_inst <- split(
    which(iv_valid), factor(iv_inst[iv_valid], levels = seq_len(n_inst))
  )
  # Instruments with no incomplete header and no interval share the count of
  # the complete headers; the others are counted from their own facts.
  touched <- which(lengths(incomplete_by_inst) > 0L | lengths(intervals_by_inst) > 0L)
  for (i in touched) {
    own <- sort(unique(incomplete_by_inst[[i]]))
    relevant <- c(complete, own)
    stop_at <- blocked_by_complete[relevant]
    for (y in own) {
      later <- head_rank[[y]] > head_rank[relevant] & head_known[[y]] <= head_known[relevant]
      stop_at[later] <- pmin(stop_at[later], head_break[[y]])
    }
    region_start <- head_break[relevant]
    region_end <- pmin(stop_at, none)
    rows <- intervals_by_inst[[i]]
    if (length(rows) == 0L) {
      counts[[i]] <- 1L + sum(region_start < region_end)
      next
    }
    # Header regions lose the axis covered by intervals known by then.
    header_pieces <- integer(length(relevant))
    known_levels <- sort(unique(iv_known[rows]))
    level <- findInterval(head_known[relevant], known_levels)
    for (lv in unique(level)) {
      at <- which(level == lv)
      cover <- rows[iv_known[rows] <= if (lv > 0L) known_levels[[lv]] else -Inf]
      header_pieces[at] <- ledgr_history_uncovered_pieces(
        region_start[at], region_end[at], iv_start[cover], iv_end[cover]
      )
    }
    interval_pieces <- vapply(rows, function(x) {
      cover <- rows[iv_known[rows] <= iv_known[[x]] & iv_order[rows] > iv_order[[x]]]
      ledgr_history_uncovered_pieces(iv_start[[x]], iv_end[[x]], iv_start[cover], iv_end[cover])
    }, integer(1))
    counts[[i]] <- 1L + sum(header_pieces) + sum(interval_pieces)
  }
  as.integer(counts)
}

# Same-clock membership (every knowledge time equal to its effective time):
# the counts the diagonal compiler produced, read from the provider plan's
# prepared resolver at each observation break. A segment is a run of
# consecutive breaks whose answer and selecting knowledge time agree.
ledgr_history_membership_diagonal_counts <- function(data,
                                                     universe_id,
                                                     instrument_ids,
                                                     axis,
                                                     headers,
                                                     interval) {
  breaks <- ledgr_history_observation_breaks(
    axis,
    headers$effective_from,
    interval$effective_from,
    interval$effective_to
  )
  n_inst <- length(instrument_ids)
  counts <- rep.int(1L, n_inst)
  if (length(breaks) == 0L) return(counts)
  resolve <- attr(
    ledgr_availability_prepared_membership(data, universe_id, instrument_ids),
    "resolve",
    exact = TRUE
  )
  previous_keep <- rep(FALSE, n_inst)
  previous <- NULL
  for (j in seq_along(breaks)) {
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
    current <- list(
      knowledge = as.numeric(answer$knowledge), state = state,
      winner = answer$winner, reason = reason
    )
    continues <- if (is.null(previous)) {
      rep(FALSE, n_inst)
    } else {
      previous_keep & keep &
        current$knowledge == previous$knowledge &
        current$state == previous$state &
        current$winner == previous$winner &
        current$reason == previous$reason
    }
    continues[is.na(continues)] <- FALSE
    counts <- counts + as.integer(keep & !continues)
    previous_keep <- keep
    previous <- current
  }
  counts
}

ledgr_history_membership_segment_counts <- function(data,
                                                    universe_id,
                                                    instrument_ids,
                                                    axis,
                                                    segment_limit) {
  headers <- data$membership_sets
  headers <- headers[as.character(headers$universe_id) == universe_id, , drop = FALSE]
  rows <- data$membership
  rows <- rows[as.character(rows$universe_id) == universe_id, , drop = FALSE]
  interval <- rows[is.na(rows$set_id), , drop = FALSE]
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
  all_complete <- nrow(interval) == 0L && nrow(headers) > 0L &&
    all(!is.na(headers$complete) & headers$complete)
  segment_count <- if (all_complete) {
    ledgr_history_membership_fact_counts(
      headers, set_rows, interval, instrument_ids, axis, header_method = "radix"
    )
  } else if (nrow(headers) == 0L && nrow(interval) > 0L) {
    ledgr_history_membership_fact_counts(
      headers, set_rows, interval, instrument_ids, axis, header_method = "auto"
    )
  } else if (ledgr_history_membership_is_diagonal(headers, interval)) {
    ledgr_history_membership_diagonal_counts(
      data, universe_id, instrument_ids, axis, headers, interval
    )
  } else if (length(axis) == 0L) {
    integer(length(instrument_ids))
  } else {
    ledgr_history_membership_fact_counts(
      headers, set_rows, interval, instrument_ids, axis, header_method = "auto"
    )
  }
  ledgr_history_segment_limit_check(
    fact_count, segment_count, instrument_ids, "membership", segment_limit
  )
}

# Trading-status segments are counted through the shared per-instrument (and
# one-fact) compilers the lifetime family also uses, without retaining them.
ledgr_history_status_segment_counts <- function(data,
                                                instrument_ids,
                                                axis,
                                                declared,
                                                segment_limit) {
  rows <- data$status
  if (!is.data.frame(rows)) rows <- data.frame()
  initial <- list(
    state = if (isTRUE(declared)) "unknown" else "active",
    winner = "",
    reason = if (isTRUE(declared)) "status_unknown" else "status_undeclared_active"
  )
  segments <- ledgr_history_sparse_fact_segments(
    rows = rows,
    instrument_ids = instrument_ids,
    axis = axis,
    state = as.character(rows$status),
    initial = initial,
    reason = "status_asserted",
    family = "trading_status",
    segment_limit = segment_limit
  )
  if (is.null(segments)) {
    knowledge <- as.numeric(as.POSIXct(rows$knowledge_time, tz = "UTC"))
    status <- as.character(rows$status)
    precedence <- as.integer(rows$precedence)
    fact_id <- as.character(rows$fact_id)
    lineage <- ledgr_status_lineage(rows)
    effective <- as.numeric(as.POSIXct(rows$effective_from, tz = "UTC"))
    end <- as.numeric(as.POSIXct(rows$effective_to, tz = "UTC"))
    end[is.na(end)] <- Inf
    segments <- ledgr_history_fact_segments_by_instrument(
      rows = rows,
      instrument_ids = instrument_ids,
      axis = axis,
      initial = initial,
      family = "trading_status",
      segment_limit = segment_limit,
      resolve_one = function(indices, observation, cutoff) {
        s <- as.numeric(observation)
        applicable <- indices[
          knowledge[indices] <= cutoff & effective[indices] <= s & s < end[indices]
        ]
        if (length(applicable) == 0L) return(initial)
        ledgr_history_status_resolve_applicable(
          applicable, status, precedence, fact_id, lineage
        )
      }
    )
  }
  list(
    family = "trading_status",
    fact_count = segments$fact_count,
    segment_count = segments$segment_count,
    segment_ratio = segments$segment_ratio,
    limit = segments$limit
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
  assertion <- as.character(rows$assertion)
  terminal <- as.character(rows$terminal_event)
  terminal[is.na(terminal)] <- ""
  fact_id <- as.character(rows$fact_id)
  effective <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$effective_from, tz = "UTC")) else numeric()
  end <- if (nrow(rows) > 0L) as.numeric(as.POSIXct(rows$effective_to, tz = "UTC")) else numeric()
  end[is.na(end)] <- Inf
  rank <- if (nrow(rows) > 0L) order(order(effective, knowledge, seq_len(nrow(rows)))) else integer()
  initial <- list(
    state = "unknown", winner = "", reason = "lifetime_unknown"
  )
  resolve_one <- function(indices, observation, cutoff) {
    s <- as.numeric(observation)
    applicable <- indices[
      knowledge[indices] <= cutoff & effective[indices] <= s & s < end[indices]
    ]
    if (length(applicable) == 0L) return(initial)
    ledgr_history_lifetime_resolve_applicable(
      applicable, assertion, terminal, fact_id, rank
    )
  }
  ledgr_history_fact_segments_by_instrument(
    rows = rows,
    instrument_ids = instrument_ids,
    axis = axis,
    initial = initial,
    family = "lifetime",
    segment_limit = segment_limit,
    resolve_one = resolve_one
  )
}

ledgr_history_terminal_segments <- function(data,
                                             instrument_ids,
                                             axis,
                                             segment_limit) {
  rows <- data$lifetime
  if (!is.data.frame(rows)) rows <- data.frame()
  knowledge <- if (nrow(rows) > 0L) {
    as.numeric(as.POSIXct(rows$knowledge_time, tz = "UTC"))
  } else {
    numeric()
  }
  effective <- if (nrow(rows) > 0L) {
    as.numeric(as.POSIXct(rows$effective_from, tz = "UTC"))
  } else {
    numeric()
  }
  end <- if (nrow(rows) > 0L) {
    as.numeric(as.POSIXct(rows$effective_to, tz = "UTC"))
  } else {
    numeric()
  }
  end[is.na(end)] <- Inf
  assertion <- as.character(rows$assertion)
  terminal <- as.character(rows$terminal_event)
  terminal[is.na(terminal)] <- ""
  fact_id <- as.character(rows$fact_id)
  rank <- if (nrow(rows) > 0L) {
    order(order(effective, knowledge, seq_len(nrow(rows))))
  } else {
    integer()
  }
  initial <- list(
    state = "", winner = "", reason = "terminal_not_asserted"
  )
  resolve_one <- function(indices, observation, cutoff) {
    observation <- as.numeric(observation)
    applicable <- indices[
      knowledge[indices] <= cutoff & effective[indices] <= observation &
        observation < end[indices]
    ]
    if (length(applicable) == 0L) return(initial)
    answer <- ledgr_history_lifetime_resolve_applicable(
      applicable, assertion, terminal, fact_id, rank
    )
    list(
      state = answer$terminal_event,
      winner = answer$winner,
      reason = if (nzchar(answer$terminal_event)) {
        "terminal_asserted"
      } else {
        "terminal_not_asserted"
      }
    )
  }
  ledgr_history_fact_segments_by_instrument(
    rows = rows,
    instrument_ids = instrument_ids,
    axis = axis,
    initial = initial,
    family = "lifetime_terminal",
    segment_limit = segment_limit,
    resolve_one = resolve_one
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
  ledgr_history_substrate_terminal_planes(
    substrate, cutoff, observation_idx, instrument_idx
  )$sticky
}

# The terminal fact plane at a cutoff, as both the per-column assertion (the
# columns inside a terminal interval) and the sticky carry barrier derived
# from it. The terminal state follows the shared lifetime resolver, but the
# carry barrier it implies is sticky (v12 Section 5): once a terminal
# assertion is knowable at the cutoff, every later column stays blocked,
# even after a relisting. Resolve over the whole prefix so a later window
# still sees an earlier terminal, then keep the requested columns.
ledgr_history_substrate_terminal_planes <- function(
    substrate,
    cutoff,
    observation_idx = seq_along(substrate$axis),
    instrument_idx = seq_along(substrate$instrument_ids)) {
  observation_idx <- as.integer(observation_idx)
  instrument_idx <- as.integer(instrument_idx)
  if (length(observation_idx) == 0L) {
    empty <- matrix(FALSE, nrow = length(instrument_idx), ncol = 0L)
    return(list(asserted = empty, sticky = empty))
  }
  prefix_idx <- seq_len(max(observation_idx))
  terminal <- ledgr_history_substrate_fact_plane(
    substrate,
    "lifetime_terminal",
    cutoff,
    prefix_idx,
    instrument_idx
  )
  asserted <- matrix(
    nzchar(terminal$state),
    nrow = nrow(terminal$state),
    ncol = ncol(terminal$state)
  )
  first <- rep.int(length(prefix_idx) + 1L, length(instrument_idx))
  hit <- which(asserted, arr.ind = TRUE)
  if (nrow(hit) > 0L) {
    hit <- hit[order(hit[, 1L], hit[, 2L]), , drop = FALSE]
    hit <- hit[!duplicated(hit[, 1L]), , drop = FALSE]
    first[hit[, 1L]] <- hit[, 2L]
  }
  list(
    asserted = asserted[, observation_idx, drop = FALSE],
    sticky = outer(first, observation_idx, "<=")
  )
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
  if (!family %in% names(substrate$segments)) {
    rlang::abort("Unknown history fact family.", class = "ledgr_invalid_args")
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
    ledgr_history_membership_segment_counts(
      availability_data,
      as.character(universe_rule$universe_id),
      instrument_ids,
      axis,
      policy$segment_limit
    )
  }
  status <- ledgr_history_status_segment_counts(
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
  # Membership and trading-status facts are held once, in the provider plan;
  # their segments are counted for the guard and not stored (Cut 16 decision
  # 22). Lifetime and terminal segments are stored for history reads.
  segments <- list(lifetime = lifetime, lifetime_terminal = terminal)
  segment_counts <- list(trading_status = status)
  if (!is.null(membership)) segment_counts$membership <- membership
  bars_matrix <- ledgr_history_substrate_bar_matrices(
    bars, instrument_ids, axis
  )
  # The fold reads facts through this diagonal plan. Its declared families
  # and membership headers (with completeness) are the substrate's family
  # metadata; the session calendar is held once, as `sessions` below.
  provider_plan <- ledgr_availability_provider_prepare(
    availability_data,
    availability_config
  )
  provider_plan$sessions <- NULL
  structure(
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
      segment_counts = segment_counts,
      sessions = availability_data$sessions,
      provider_plan = provider_plan,
      # Derived treatment planes are prepared lazily, once per substrate, by
      # the public history reader. The memo holds only values derived from
      # this immutable substrate and its policy and is never staged.
      history_memo = new.env(parent = emptyenv())
    ),
    class = c("ledgr_history_substrate", "list")
  )
}

ledgr_availability_provider_from_substrate <- function(substrate,
                                                       config,
                                                       snapshot_hash) {
  ledgr_history_substrate_require(substrate)
  ledgr_availability_provider_from_plan(
    substrate$provider_plan,
    config,
    snapshot_hash,
    sessions = substrate$sessions,
    history_substrate_version = substrate$substrate_version
  )
}

ledgr_history_substrate_census <- function(substrate) {
  ledgr_history_substrate_require(substrate)
  families <- c("trading_status", "lifetime", "lifetime_terminal", "membership")
  counted <- c(substrate$segment_counts, substrate$segments)
  families <- families[families %in% names(counted)]
  rows <- lapply(families, function(family) {
    x <- counted[[family]]
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
