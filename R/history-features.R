# Availability-aware feature calculation over the shared causal substrate
# (historical projection synthesis v12, Sections 5 and 6).
#
# Each instrument's price fields are treated once per preparation by the
# shared carry primitive and then serve every definition. Bounded definitions
# use the last `requires_bars` expected sessions on the instrument's mask;
# history-dependent definitions run once per contiguous segment of available
# input and restart after a gap. Raw missingness, calculation validity,
# readiness and output carry remain separate planes. Return- and
# volatility-family definitions never consume a carried price.

ledgr_history_price_fields <- function() c("open", "high", "low", "close")

# Certification decides only which functions compute a definition: a package
# built-in or registered TTR catalogue row is computed with the package
# constructor's own functions, so a definition whose claimed identity is a
# catalogue row can never execute other code under that identity. Anything
# else is computed with its own functions under the custom rules.
ledgr_feature_certify <- function(def) {
  if (inherits(def, "ledgr_indicator")) {
    def <- ledgr_precompute_feature_def_from_indicator(def)
  }
  declarations <- ledgr_feature_def_declarations(def)
  claimed <- ledgr_feature_def_fingerprint(def)
  content <- if (is.function(def$fn)) {
    ledgr_feature_def_fingerprint(def[setdiff(names(def), "fingerprint")])
  } else {
    NULL
  }
  for (candidate in ledgr_feature_catalogue_candidates(def)) {
    indicator <- candidate$indicator
    indicator$id <- def$id
    canonical <- ledgr_precompute_feature_def_from_indicator(indicator)
    identities <- c(
      canonical$fingerprint,
      ledgr_active_feature_fingerprint(canonical)
    )
    # A built-in or catalogue row takes its input-carry family from the
    # catalogue (Cut 16 decision 13); a copy of its functions that declares
    # another family refuses instead of silently running either way.
    same_functions <- identical(claimed, canonical$fingerprint) ||
      (!is.null(content) && identical(content, canonical$fingerprint))
    if (same_functions &&
        !identical(declarations$input_carry, canonical$input_carry)) {
      ledgr_indicator_abort_declaration(
        sprintf(
          paste0(
            "Indicator `%s` is a package catalogue row; its input-carry ",
            "family is `%s` and cannot be declared `%s`."
          ),
          def$id,
          canonical$input_carry,
          declarations$input_carry
        ),
        contradiction = TRUE
      )
    }
    if (claimed %in% identities) {
      canonical$fingerprint <- claimed
      canonical_declarations <- ledgr_feature_def_declarations(canonical)
      # Outputs of one TTR call share inputs, segments and the raw result.
      call_params <- canonical$params
      call_params$output <- NULL
      return(list(
        certification = candidate$certification,
        kind = candidate$kind,
        def = canonical,
        declarations = canonical_declarations,
        ttr_call_key = if (identical(candidate$kind, "ttr")) {
          paste(
            canonical_json(call_params),
            paste(canonical_declarations$required_fields, collapse = ","),
            canonical_declarations$input_carry,
            canonical_declarations$history_class,
            sep = "|"
          )
        } else {
          NULL
        }
      ))
    }
  }
  def[names(declarations)] <- declarations
  list(
    certification = "custom",
    kind = NULL,
    def = def,
    declarations = declarations
  )
}

ledgr_feature_catalogue_candidates <- function(def) {
  out <- list()
  widths <- integer()
  n <- if (is.list(def$params)) def$params$n else NULL
  if (is.numeric(n) && length(n) == 1L && !is.na(n) && is.finite(n) &&
      n >= 1 && n %% 1 == 0 && n <= .Machine$integer.max) {
    widths <- as.integer(n)
  }
  id_width <- regmatches(def$id, regexec("^(sma|ema|rsi|return)_([0-9]+)$", def$id))[[1L]]
  if (length(id_width) == 3L) {
    widths <- unique(c(widths, as.integer(id_width[[3L]])))
  }
  constructors <- list(
    sma = ledgr_ind_sma,
    ema = ledgr_ind_ema,
    rsi = ledgr_ind_rsi,
    returns = ledgr_ind_returns
  )
  for (width in widths[!is.na(widths)]) {
    for (kind in names(constructors)) {
      out[[length(out) + 1L]] <- list(
        certification = "builtin",
        kind = kind,
        indicator = constructors[[kind]](width)
      )
    }
  }
  params <- def$params
  if (is.list(params) && is.character(params$ttr_fn) &&
      length(params$ttr_fn) == 1L && is.list(params$args %||% list()) &&
      requireNamespace("TTR", quietly = TRUE)) {
    indicator <- tryCatch(
      do.call(
        ledgr_ind_ttr,
        c(
          list(
            ttr_fn = params$ttr_fn,
            input = params$input,
            output = params$output,
            id = def$id,
            requires_bars = def$requires_bars,
            stable_after = def$stable_after
          ),
          params$args %||% list()
        )
      ),
      error = function(e) NULL
    )
    if (inherits(indicator, "ledgr_indicator") &&
        identical(indicator$history_source, "catalogue")) {
      out[[length(out) + 1L]] <- list(
        certification = "catalogue",
        kind = "ttr",
        indicator = indicator
      )
    }
  }
  out
}

# Start and end positions of each contiguous run of TRUE.
ledgr_history_feature_runs <- function(available) {
  available <- as.logical(available)
  n <- length(available)
  if (n == 0L) return(list(starts = integer(), ends = integer()))
  list(
    starts = which(available & c(TRUE, !available[-n])),
    ends = which(available & c(!available[-1L], TRUE))
  )
}

# Treated inputs for one instrument over the prefix 1..prefix_end, with the
# expected-session mask and terminal barrier knowable at `cutoff`. Price
# fields are carried by the shared primitive; volume is never carried.
ledgr_history_feature_inputs <- function(substrate, instrument_idx, prefix_end, cutoff) {
  prefix <- seq_len(prefix_end)
  expected <- as.logical(ledgr_history_substrate_expected_at(
    substrate, cutoff, prefix, instrument_idx
  )[1L, ])
  terminal <- as.logical(ledgr_history_substrate_terminal_at(
    substrate, cutoff, prefix, instrument_idx
  )[1L, ])
  axis <- substrate$axis[prefix]
  policy <- substrate$history_policy
  raw <- list()
  treated <- list()
  carried <- list()
  for (field in c(ledgr_history_price_fields(), "volume")) {
    value <- as.numeric(substrate$bars[[field]][instrument_idx, prefix])
    raw_value <- value
    raw_value[!expected] <- NA_real_
    raw[[field]] <- raw_value
    if (identical(field, "volume")) {
      treated[[field]] <- raw_value
      carried[[field]] <- rep(FALSE, prefix_end)
      next
    }
    treatment <- ledgr_history_input_carry(
      value = value,
      expected = expected,
      axis = axis,
      max_sessions = policy$price_carry,
      carry_allowed = !is.null(policy$price_carry),
      terminal_barrier = terminal
    )
    treated[[field]] <- treatment$value
    carried[[field]] <- treatment$input_carried
  }
  list(
    instrument_id = substrate$instrument_ids[[instrument_idx]],
    axis = axis,
    expected = expected,
    terminal = terminal,
    raw = raw,
    treated = treated,
    carried = carried
  )
}

# Plain data frames built directly: these are constructed once per segment
# and once per fn window, so data.frame()'s name checks are avoided.
ledgr_history_feature_frame <- function(inputs, fields, rows) {
  structure(
    list(
      instrument_id = rep(inputs$instrument_id, length(rows)),
      ts_utc = inputs$axis[rows],
      open = fields$open[rows],
      high = fields$high[rows],
      low = fields$low[rows],
      close = fields$close[rows],
      volume = fields$volume[rows]
    ),
    class = "data.frame",
    row.names = c(NA_integer_, -length(rows))
  )
}

ledgr_history_feature_window <- function(frame, rows) {
  structure(
    lapply(frame, `[`, rows),
    class = "data.frame",
    row.names = c(NA_integer_, -length(rows))
  )
}

ledgr_history_feature_refuse_parity <- function(def, inputs, row, fn_value, series_value, tolerance) {
  rlang::abort(
    sprintf(
      paste0(
        "Indicator '%s' fn and series_fn disagree for instrument '%s' at %s ",
        "(fn %s, series_fn %s, tolerance %s)."
      ),
      def$id,
      inputs$instrument_id,
      format(inputs$axis[[row]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      format(fn_value, digits = 17),
      format(series_value, digits = 17),
      format(tolerance)
    ),
    class = c("ledgr_indicator_gap_parity", "ledgr_invalid_feature_output"),
    feature_id = def$id,
    instrument_id = inputs$instrument_id,
    ts_utc = inputs$axis[[row]],
    fn_value = fn_value,
    series_value = series_value,
    tolerance = tolerance
  )
}

# Values for one contiguous segment. `rows` index the prefix; the segment is
# already known to be at least `stable_after` long. `cache` holds raw TTR
# results so the outputs of one multi-output call share a single TTR call
# per segment.
ledgr_history_feature_segment <- function(cert, inputs, fields, rows, cache = NULL) {
  def <- cert$def
  declarations <- cert$declarations
  stable_after <- as.integer(def$stable_after)
  width <- as.integer(def$requires_bars)
  params <- def$params %||% list()
  m <- length(rows)
  if (identical(cert$kind, "sma")) {
    # Exact parity with the scalar mean(window$close) oracle.
    return(ledgr_strict_sma_series(fields$close[rows], width))
  }
  frame <- ledgr_history_feature_frame(inputs, fields, rows)
  ready <- seq_len(m) >= stable_after
  if (identical(cert$kind, "ttr") && is.environment(cache)) {
    key <- paste(cert$ttr_call_key, rows[[1L]], rows[[m]], sep = "|")
    raw <- cache[[key]]
    if (is.null(raw)) {
      raw <- ledgr_ttr_raw_call(frame, params)
      cache[[key]] <- raw
    }
    return(ledgr_normalize_feature_series_output(
      ledgr_ttr_select_output(raw, params$output, params$ttr_fn),
      m,
      stable_after,
      def$id
    ))
  }
  if (is.function(def$series_fn)) {
    value <- ledgr_normalize_feature_series_output(
      ledgr_call_feature_series_fn(def$series_fn, frame, params),
      m,
      stable_after,
      def$id
    )
    if (identical(cert$certification, "custom") &&
        identical(declarations$history_class, "bounded")) {
      tolerance <- declarations$tolerance
      for (k in which(ready)) {
        scalar <- ledgr_normalize_feature_scalar_output(
          ledgr_call_feature_fn(def$fn, ledgr_history_feature_window(frame, seq.int(k - width + 1L, k)), params),
          def$id
        )
        agree <- if (is.na(scalar)) {
          is.na(value[[k]])
        } else if (tolerance > 0) {
          abs(scalar - value[[k]]) / max(1, abs(value[[k]])) <= tolerance
        } else {
          identical(scalar, value[[k]])
        }
        if (!isTRUE(agree)) {
          ledgr_history_feature_refuse_parity(
            def, inputs, rows[[k]], scalar, value[[k]], tolerance
          )
        }
      }
    }
    return(value)
  }
  value <- rep(NA_real_, m)
  for (k in which(ready)) {
    value[[k]] <- ledgr_normalize_feature_scalar_output(
      ledgr_call_feature_fn(def$fn, ledgr_history_feature_window(frame, seq.int(k - width + 1L, k)), params),
      def$id
    )
  }
  value
}

# One definition over the calculation rows calc_from..prefix_end of the
# treated inputs. Returns the value vector over the prefix plus the planes the
# evidence reader exposes.
ledgr_history_feature_calculate <- function(cert, inputs, calc_from, output_carry = NULL, cache = NULL) {
  declarations <- cert$declarations
  n <- length(inputs$axis)
  value <- rep(NA_real_, n)
  ready <- rep(FALSE, n)
  available_all <- rep(FALSE, n)
  blocking <- rep("", n)
  if (calc_from > n) {
    return(list(value = value, ready = ready, available = available_all, blocking_field = blocking,
                calculated = rep(FALSE, n), output_carry = NULL))
  }
  calc <- seq.int(calc_from, n)
  fields <- if (identical(declarations$input_carry, "excluded")) inputs$raw else inputs$treated
  admission <- ledgr_history_required_field_admission(
    lapply(fields, function(x) x[calc]),
    declarations$required_fields
  )
  available_all[calc] <- admission$available & inputs$expected[calc]
  blocking[calc] <- admission$blocking_field
  # Bounded windows count expected sessions on the instrument's mask;
  # history-dependent segments also split at structural (inactive) columns.
  rows <- if (identical(declarations$history_class, "bounded")) {
    calc[inputs$expected[calc]]
  } else {
    calc
  }
  runs <- ledgr_history_feature_runs(available_all[rows])
  stable_after <- as.integer(cert$def$stable_after)
  for (r in seq_along(runs$starts)) {
    segment <- rows[seq.int(runs$starts[[r]], runs$ends[[r]])]
    if (length(segment) < stable_after) next
    segment_value <- ledgr_history_feature_segment(cert, inputs, fields, segment, cache)
    take <- seq_along(segment) >= stable_after
    ready[segment[take]] <- TRUE
    value[segment[take]] <- segment_value[take]
  }
  calculated <- ready & is.finite(value)
  carried_output <- NULL
  if (!is.null(output_carry)) {
    carried_output <- ledgr_history_output_carry(
      value = value[calc],
      eligible_gap = inputs$expected[calc] & !available_all[calc],
      expected = inputs$expected[calc],
      axis = inputs$axis[calc],
      max_sessions = output_carry,
      source_eligible = calculated[calc],
      terminal_barrier = inputs$terminal[calc]
    )
    value[calc] <- carried_output$value
  }
  list(
    value = value,
    ready = ready,
    available = available_all,
    blocking_field = blocking,
    calculated = calculated,
    output_carry = carried_output,
    calc = calc
  )
}

# Pulse ranges whose knowable lifetime state is constant for every column at
# or before the range end. A lifetime or terminal fact learned after the
# column it changes splits the calculation range at its knowledge pulse.
ledgr_history_feature_ranges <- function(substrate, instrument_idx, calc_from, calc_to) {
  starts <- calc_from
  for (family in c("lifetime", "lifetime_terminal")) {
    segments <- substrate$segments[[family]]
    if (is.null(segments) || segments$count[[instrument_idx]] == 0L) next
    idx <- seq.int(segments$off[[instrument_idx]], length.out = segments$count[[instrument_idx]])
    knowledge <- segments$knowledge_from[idx]
    known <- is.finite(knowledge)
    if (!any(known)) next
    position <- ledgr_history_axis_lower_bound(substrate$axis, knowledge[known])
    lagged <- position > segments$observation_from[idx][known] &
      position > calc_from & position <= calc_to
    starts <- c(starts, position[lagged])
  }
  starts <- sort(unique(starts))
  list(start = starts, end = c(starts[-1L] - 1L, calc_to))
}

ledgr_history_feature_bounds <- function(substrate, calculation_start, calculation_end) {
  axis <- as.numeric(substrate$axis)
  calc_from <- 1L
  calc_to <- length(axis)
  if (!is.null(calculation_start)) {
    calc_from <- ledgr_history_axis_lower_bound(
      substrate$axis, ledgr_history_utc(calculation_start)
    )
  }
  if (!is.null(calculation_end)) {
    calc_to <- findInterval(as.numeric(ledgr_history_utc(calculation_end)), axis)
  }
  list(from = as.integer(calc_from), to = as.integer(calc_to))
}

# Feature values for every definition and instrument on the substrate axis.
# Bounds arrive as ISO strings or POSIXct and are parsed as exact instants.
ledgr_history_compute_feature_series <- function(substrate,
                                                 definitions,
                                                 calculation_start = NULL,
                                                 calculation_end = NULL) {
  ledgr_history_substrate_require(substrate)
  definitions <- lapply(definitions, function(def) {
    if (inherits(def, "ledgr_indicator")) ledgr_precompute_feature_def_from_indicator(def) else def
  })
  certified <- lapply(definitions, ledgr_feature_certify)
  n_inst <- length(substrate$instrument_ids)
  n_axis <- length(substrate$axis)
  out <- lapply(certified, function(cert) {
    matrix(NA_real_, nrow = n_inst, ncol = n_axis)
  })
  names(out) <- names(definitions)
  bounds <- ledgr_history_feature_bounds(substrate, calculation_start, calculation_end)
  if (length(definitions) == 0L || bounds$from > bounds$to) return(out)
  output_carry <- substrate$history_policy$output_carry
  for (i in seq_len(n_inst)) {
    ranges <- ledgr_history_feature_ranges(substrate, i, bounds$from, bounds$to)
    for (r in seq_along(ranges$start)) {
      range_end <- ranges$end[[r]]
      inputs <- ledgr_history_feature_inputs(
        substrate, i, range_end, substrate$axis[[range_end]]
      )
      keep <- seq.int(ranges$start[[r]], range_end)
      cache <- new.env(hash = TRUE, parent = emptyenv())
      for (d in seq_along(certified)) {
        calculated <- ledgr_history_feature_calculate(
          certified[[d]], inputs, bounds$from, output_carry, cache
        )
        out[[d]][i, keep] <- calculated$value[keep]
      }
    }
  }
  out
}

# Aligned evidence for one instrument and definition at a cutoff. It shares
# the calculation above; nothing here is retained by preparation.
ledgr_history_feature_evidence <- function(substrate,
                                           instrument_id,
                                           definition,
                                           cutoff = NULL,
                                           calculation_start = NULL) {
  ledgr_history_substrate_require(substrate)
  instrument_idx <- unname(substrate$instrument_index[as.character(instrument_id)])
  if (length(instrument_idx) != 1L || is.na(instrument_idx)) {
    rlang::abort(
      sprintf("Unknown history instrument_id `%s`.", as.character(instrument_id)),
      class = c("ledgr_history_unknown_instrument", "ledgr_invalid_args")
    )
  }
  if (is.null(cutoff)) cutoff <- substrate$axis[[length(substrate$axis)]]
  bounds <- ledgr_history_feature_bounds(substrate, calculation_start, cutoff)
  prefix_end <- bounds$to
  inputs <- ledgr_history_feature_inputs(substrate, instrument_idx, prefix_end, cutoff)
  cert <- ledgr_feature_certify(definition)
  calculated <- ledgr_history_feature_calculate(
    cert, inputs, bounds$from, substrate$history_policy$output_carry
  )
  declarations <- cert$declarations
  required <- declarations$required_fields
  raw_observed <- Reduce(`&`, lapply(required, function(f) is.finite(inputs$raw[[f]])))
  carried_any <- Reduce(`|`, lapply(required, function(f) inputs$carried[[f]]))
  excluded <- identical(declarations$input_carry, "excluded")
  input_carried <- if (excluded) rep(FALSE, prefix_end) else carried_any
  carried_cells <- Reduce(`+`, lapply(required, function(f) {
    if (excluded) integer(prefix_end) else as.integer(inputs$carried[[f]])
  }))
  output_carried <- rep(FALSE, prefix_end)
  output_expired <- rep(FALSE, prefix_end)
  source_ts <- rep(NA_real_, prefix_end)
  carry_age <- rep(NA_integer_, prefix_end)
  if (!is.null(calculated$output_carry)) {
    output_carried[calculated$calc] <- calculated$output_carry$output_carried
    source_ts[calculated$calc] <- as.numeric(calculated$output_carry$source_ts_utc)
    carry_age[calculated$calc] <- calculated$output_carry$carry_age_sessions
    output_expired[calculated$calc] <- calculated$output_carry$missing_reason == "output_carry_expired" &
      !calculated$available[calculated$calc]
  }
  in_range <- seq_len(prefix_end) >= bounds$from
  missing_reason <- rep("", prefix_end)
  missing_reason[!inputs$expected] <- "not_expected"
  missing_reason[inputs$expected & in_range & !calculated$available] <- "required_input_missing"
  missing_reason[inputs$expected & in_range & !calculated$available & excluded & carried_any] <-
    "carried_input_excluded"
  missing_reason[calculated$available & !calculated$ready] <- "not_ready"
  missing_reason[output_expired] <- "output_carry_expired"
  missing_reason[output_carried] <- "output_carried"
  missing_reason[!in_range & inputs$expected] <- "outside_calculation"
  barrier_reason <- rep("", prefix_end)
  barrier_reason[!inputs$expected] <- "lifetime_inactive"
  barrier_reason[inputs$terminal] <- "terminal"
  # Finite bounded windows disclose the count and share of carried inputs.
  required_count <- rep(NA_integer_, prefix_end)
  carried_count <- rep(NA_integer_, prefix_end)
  if (identical(declarations$history_class, "bounded")) {
    width <- as.integer(cert$def$requires_bars)
    expected_rows <- which(inputs$expected)
    cumulative <- c(0L, cumsum(carried_cells[expected_rows]))
    k <- seq_along(expected_rows)
    has_window <- k >= width
    rows <- expected_rows[has_window]
    required_count[rows] <- width * length(required)
    carried_count[rows] <- as.integer(
      cumulative[k[has_window] + 1L] - cumulative[k[has_window] - width + 1L]
    )
  }
  data.frame(
    instrument_id = inputs$instrument_id,
    ts_utc = inputs$axis,
    value = calculated$value,
    expected = inputs$expected,
    observed = raw_observed,
    is_missing = inputs$expected & !raw_observed,
    input_carried = input_carried,
    blocking_field = calculated$blocking_field,
    calculated = calculated$available,
    ready = calculated$ready,
    calculation_valid = calculated$calculated,
    output_carried = output_carried,
    source_ts_utc = .POSIXct(source_ts, tz = "UTC"),
    carry_age_sessions = carry_age,
    missing_reason = missing_reason,
    barrier_reason = barrier_reason,
    required_input_count = required_count,
    carried_input_count = carried_count,
    carried_input_share = carried_count / required_count,
    stringsAsFactors = FALSE
  )
}
