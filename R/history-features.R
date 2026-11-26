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
# built-in or registered adapter catalogue row is computed with the package
# constructor's own functions, so a definition whose claimed identity is a
# catalogue row can never execute other code under that identity. Anything
# else is computed with its own functions under the custom rules. The
# candidates come from the feature adapters (R/feature-adapters.R) in their
# order, every candidate constructed before any is compared.
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
        identical(def$history_source, "catalogue") &&
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
      # The matched adapter computes the definition: its segment
      # calculation and whatever its calculator needs from certification.
      adapter <- ledgr_feature_adapters()[[candidate$adapter]]
      return(c(
        list(
          certification = candidate$certification,
          kind = candidate$kind,
          def = canonical,
          declarations = canonical_declarations,
          segment = adapter$segment
        ),
        adapter$certified(canonical, canonical_declarations)
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
  unlist(unname(lapply(ledgr_feature_adapters(), function(adapter) adapter$candidates(def))), recursive = FALSE)
}

# Start and end positions of each contiguous run of TRUE. `breaks` marks
# positions that start a new run even when the previous one is TRUE.
ledgr_history_feature_runs <- function(available, breaks = NULL) {
  available <- as.logical(available)
  n <- length(available)
  if (n == 0L) return(list(starts = integer(), ends = integer()))
  if (is.null(breaks)) breaks <- rep(FALSE, n)
  list(
    starts = which(available & (c(TRUE, !available[-n]) | breaks)),
    ends = which(available & (c(!available[-1L], TRUE) | c(breaks[-1L], FALSE)))
  )
}

# The bar fields one preparation treats: every field when any definition is
# custom, since custom callbacks see the complete frame; otherwise the union
# of the certified canonical definitions' required fields, which for
# built-ins and catalogue rows are the only fields their code reads.
ledgr_history_feature_fields <- function(certified) {
  fields <- c(ledgr_history_price_fields(), "volume")
  custom <- vapply(certified, function(cert) identical(cert$certification, "custom"), logical(1))
  if (any(custom)) return(fields)
  used <- unlist(lapply(certified, function(cert) cert$declarations$required_fields), use.names = FALSE)
  fields[fields %in% used]
}

# The expected-session mask and terminal planes of one instrument over the
# prefix 1..prefix_end, knowable at `cutoff`. Preparation computes them once
# per instrument and knowledge range for both the gate and the treatment.
ledgr_history_feature_masks <- function(substrate, instrument_idx, prefix_end, cutoff) {
  prefix <- seq_len(prefix_end)
  expected <- as.logical(ledgr_history_substrate_expected_at(
    substrate, cutoff, prefix, instrument_idx
  )[1L, ])
  terminal_planes <- ledgr_history_substrate_terminal_planes(
    substrate, cutoff, prefix, instrument_idx
  )
  list(
    expected = expected,
    terminal = as.logical(terminal_planes$sticky[1L, ]),
    # Columns inside a terminal interval; every relisting after one restarts
    # windows and segments (Cut 16 decision 20).
    terminal_asserted = as.logical(terminal_planes$asserted[1L, ])
  )
}

# Treated inputs for one instrument over the prefix 1..prefix_end, with the
# expected-session mask and terminal barrier knowable at `cutoff`. Price
# fields are carried by the shared calculation; volume is never carried.
# Only `fields` are treated (ledgr_history_feature_fields()).
ledgr_history_feature_inputs <- function(substrate, instrument_idx, prefix_end, cutoff,
                                         fields = c(ledgr_history_price_fields(), "volume"),
                                         masks = ledgr_history_feature_masks(
                                           substrate, instrument_idx, prefix_end, cutoff
                                         )) {
  prefix <- seq_len(prefix_end)
  expected <- masks$expected
  terminal <- masks$terminal
  terminal_asserted <- masks$terminal_asserted
  axis <- substrate$axis[prefix]
  policy <- substrate$history_policy
  raw <- list()
  treated <- list()
  carried <- list()
  for (field in fields) {
    value <- as.numeric(substrate$bars[[field]][instrument_idx, prefix])
    raw_value <- value
    raw_value[!expected] <- NA_real_
    raw[[field]] <- raw_value
    if (identical(field, "volume")) {
      treated[[field]] <- raw_value
      carried[[field]] <- rep(FALSE, prefix_end)
      next
    }
    # Only the treated value and the input-carried flag feed a calculation;
    # carry evidence is never manifested here (audit F02).
    treatment <- ledgr_history_input_carry_calculation(
      value = value,
      expected = expected,
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
    terminal_asserted = terminal_asserted,
    raw = raw,
    treated = treated,
    carried = carried
  )
}

# Positions k (of `rows`) where a terminal interval lies between rows[k - 1]
# and rows[k]: each starts a new run (Cut 16 decision 20).
ledgr_history_feature_terminal_breaks <- function(terminal_asserted, rows) {
  if (length(rows) < 2L) return(rep(FALSE, length(rows)))
  crossed <- cumsum(as.integer(terminal_asserted))[rows]
  c(FALSE, crossed[-1L] != crossed[-length(crossed)])
}

# Plain data frames built directly: these are constructed once per segment
# and once per fn window, so data.frame()'s name checks are avoided. The
# frame holds the treated fields, all five in this order for any custom
# definition (ledgr_history_feature_fields()).
ledgr_history_feature_frame <- function(inputs, fields, rows) {
  present <- c(ledgr_history_price_fields(), "volume")
  structure(
    c(
      list(instrument_id = rep(inputs$instrument_id, length(rows)), ts_utc = inputs$axis[rows]),
      lapply(fields[present[present %in% names(fields)]], `[`, rows)
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
# already known to be at least `stable_after` long. A certified definition is
# computed by its adapter's segment calculation (R/feature-adapters.R);
# `cache` is the preparation-local cache an adapter may share raw results in
# (the outputs of one multi-output call share a single call per segment).
ledgr_history_feature_segment <- function(cert, inputs, fields, rows, cache = NULL) {
  if (is.function(cert$segment)) {
    return(cert$segment(cert, inputs, fields, rows, cache))
  }
  ledgr_history_feature_segment_general(cert, inputs, fields, rows)
}

# The definition's own functions over the segment frame: series_fn, else the
# scalar fn over each bounded window.
ledgr_history_feature_segment_general <- function(cert, inputs, fields, rows) {
  def <- cert$def
  stable_after <- as.integer(def$stable_after)
  width <- as.integer(def$requires_bars)
  params <- def$params %||% list()
  m <- length(rows)
  frame <- ledgr_history_feature_frame(inputs, fields, rows)
  if (is.function(def$series_fn)) {
    return(ledgr_normalize_feature_series_output(
      ledgr_call_feature_series_fn(def$series_fn, frame, params),
      m,
      stable_after,
      def$id
    ))
  }
  value <- rep(NA_real_, m)
  for (k in which(seq_len(m) >= stable_after)) {
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
    return(list(value = value, raw = value, ready = ready, available = available_all,
                blocking_field = blocking, calculated = rep(FALSE, n), output_carry = NULL,
                segments = list(start = integer(), end = integer(), ready = integer())))
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
  # A terminal interval ends windows and segments as well as carry (Cut 16
  # decision 20): a run restarts at every row that follows a column inside a
  # terminal interval, so no window mixes prices from before and after any
  # delisting. The carry barrier itself stays sticky (WS41).
  runs <- ledgr_history_feature_runs(
    available_all[rows],
    breaks = ledgr_history_feature_terminal_breaks(inputs$terminal_asserted, rows)
  )
  stable_after <- as.integer(cert$def$stable_after)
  # Segment spans in prefix positions, with the first ready position (NA
  # when the segment never reaches stable_after).
  segments <- list(
    start = rows[runs$starts],
    end = rows[runs$ends],
    ready = rep(NA_integer_, length(runs$starts))
  )
  for (r in seq_along(runs$starts)) {
    segment <- rows[seq.int(runs$starts[[r]], runs$ends[[r]])]
    if (length(segment) < stable_after) next
    segments$ready[[r]] <- segment[[stable_after]]
    segment_value <- ledgr_history_feature_segment(cert, inputs, fields, segment, cache)
    take <- seq_along(segment) >= stable_after
    ready[segment[take]] <- TRUE
    value[segment[take]] <- segment_value[take]
  }
  calculated <- ready & is.finite(value)
  raw_value <- value
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
    raw = raw_value,
    ready = ready,
    available = available_all,
    blocking_field = blocking,
    calculated = calculated,
    output_carry = carried_output,
    calc = calc,
    segments = segments
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

# Stage 3 of the feature engine (feature-engine stages synthesis rules 5-8;
# Cut 24, LDG-3263). The conservative gate admits a built-in or catalogue
# definition on one instrument only when the preparation has exactly one
# knowledge range for it, every calculation column is expected at the
# range-end cutoff, every required raw field is finite there and no terminal
# is asserted anywhere in the prefix (so no sticky barrier either). Then
# treatment carries nothing, required-field admission is complete, the
# calculation slice is one segment and output carry has no eligible gap: the
# general path computes the adapter's segment calculation over the whole
# slice and records one segment and no carry or reason exception, which is
# what the direct path does without that machinery. Harmless second ranges
# and early terminals are rejected on purpose. One flag per definition.
ledgr_history_feature_gate <- function(substrate, certified, gated, gate_fields, masks, instrument_idx, calc) {
  admitted <- gated & FALSE
  if (!all(masks$expected[calc]) || any(masks$terminal_asserted)) return(admitted)
  finite <- vapply(gate_fields, function(field) {
    all(is.finite(substrate$bars[[field]][instrument_idx, calc]))
  }, logical(1))
  for (d in which(gated)) {
    admitted[[d]] <- all(finite[certified[[d]]$declarations$required_fields])
  }
  admitted
}

# Untreated inputs for an instrument whose cells are all admitted: the raw
# fields over the prefix, equal to the treated ones on the admitted slice.
ledgr_history_feature_direct_inputs <- function(substrate, instrument_idx, prefix_end, fields) {
  prefix <- seq_len(prefix_end)
  values <- lapply(stats::setNames(fields, fields), function(field) {
    as.numeric(substrate$bars[[field]][instrument_idx, prefix])
  })
  list(
    instrument_id = substrate$instrument_ids[[instrument_idx]],
    axis = substrate$axis[prefix],
    raw = values,
    treated = values
  )
}

# One admitted cell: the adapter's segment calculation over the whole slice
# calc_from..prefix end, values from its stable_after-th position on. A slice
# shorter than stable_after never becomes ready and makes no adapter call.
# Returns the value over the prefix, the calculated count (ready and finite)
# and the cell's plane exceptions, which are its one segment record.
ledgr_history_feature_direct <- function(cert, inputs, calc_from, output_carry = NULL, cache = NULL) {
  n <- length(inputs$axis)
  calc <- seq.int(calc_from, n)
  m <- length(calc)
  stable_after <- as.integer(cert$def$stable_after)
  value <- rep(NA_real_, n)
  ready <- NA_integer_
  if (m >= stable_after) {
    ready <- calc[[stable_after]]
    fields <- if (identical(cert$declarations$input_carry, "excluded")) inputs$raw else inputs$treated
    segment_value <- ledgr_history_feature_segment(cert, inputs, fields, calc, cache)
    take <- seq.int(stable_after, m)
    value[calc[take]] <- segment_value[take]
  }
  calculated <- is.finite(value)
  # Output carry finds no eligible gap here; it only clears non-finite values.
  if (!is.null(output_carry)) value[!calculated] <- NA_real_
  list(
    value = value,
    count = sum(calculated[calc]),
    exceptions = list(segment_start = calc_from, segment_ready = ready, segment_end = n)
  )
}

# Debug only (rule 8): the admitted cell is also computed by the general path
# with its own raw cache. Success must agree on the values, the calculated
# count and every plane record; a refusal on the class, the message and
# every identifying field (call, trace, parent and rlang's own fields
# excluded, as the parity runner does). Disagreement raises
# ledgr_feature_debug_mismatch and never falls back; an agreed refusal
# re-raises the product condition.
ledgr_history_feature_direct_checked <- function(cert, inputs, calc_from, output_carry, cache, shadow_cache, keep) {
  run <- function(f) tryCatch(list(value = f()), error = function(e) list(error = e))
  direct <- run(function() ledgr_history_feature_direct(cert, inputs, calc_from, output_carry, cache))
  general <- run(function() {
    calculated <- ledgr_history_feature_calculate(cert, inputs, calc_from, output_carry, shadow_cache)
    list(
      value = calculated$value,
      count = sum(calculated$calculated[keep]),
      exceptions = ledgr_feature_plane_exceptions(cert, inputs, calculated, calc_from, keep)
    )
  })
  outcome <- function(o) {
    if (is.null(o$error)) {
      return(list(value = o$value$value[keep], count = o$value$count, exceptions = o$value$exceptions))
    }
    fields <- unclass(o$error)
    fields <- fields[setdiff(names(fields), c("call", "trace", "parent", "rlang"))]
    list(
      class = class(o$error),
      message = conditionMessage(o$error),
      fields = fields[order(names(fields), method = "radix")]
    )
  }
  if (!identical(outcome(direct), outcome(general))) {
    rlang::abort(
      sprintf(
        "Internal: the direct calculation of feature `%s` for instrument `%s` disagrees with the general path.",
        cert$def$id, inputs$instrument_id
      ),
      class = c("ledgr_feature_debug_mismatch", "ledgr_internal_error"),
      feature_id = cert$def$id,
      instrument_id = inputs$instrument_id
    )
  }
  if (!is.null(direct$error)) stop(direct$error)
  direct$value
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
  planes <- lapply(certified, function(cert) ledgr_feature_plane_chunks(n_inst))
  if (length(definitions) == 0L || bounds$from > bounds$to) {
    attr(out, "ledgr_feature_planes") <- ledgr_feature_plane_records(
      planes, substrate$instrument_ids, bounds
    )
    return(out)
  }
  output_carry <- substrate$history_policy$output_carry
  fields <- ledgr_history_feature_fields(certified)
  # Calculated (not carried) cells per definition and instrument choose each
  # definition's causality probe.
  calculated_count <- matrix(0L, nrow = length(certified), ncol = n_inst)
  # Only built-in and catalogue definitions can take the direct path; a
  # custom-only preparation builds no gate.
  gated <- vapply(certified, function(cert) cert$certification %in% c("builtin", "catalogue"), logical(1))
  gate_fields <- unique(unlist(lapply(certified[gated], function(cert) cert$declarations$required_fields),
                               use.names = FALSE))
  debug <- ledgr_debug()
  # Instruments, knowledge ranges and definitions keep their order, direct and
  # general cells interleaved, so the first refusal and the adapter calls are
  # those of the general path.
  for (i in seq_len(n_inst)) {
    ranges <- ledgr_history_feature_ranges(substrate, i, bounds$from, bounds$to)
    for (r in seq_along(ranges$start)) {
      range_end <- ranges$end[[r]]
      cutoff <- substrate$axis[[range_end]]
      masks <- ledgr_history_feature_masks(substrate, i, range_end, cutoff)
      keep <- seq.int(ranges$start[[r]], range_end)
      admitted <- if (any(gated) && length(ranges$start) == 1L) {
        ledgr_history_feature_gate(substrate, certified, gated, gate_fields, masks, i, keep)
      } else {
        gated & FALSE
      }
      # Treatment only where a cell needs the general path (or debug compares
      # with it); admitted cells read their inputs untreated.
      inputs <- if (debug || !all(admitted)) {
        ledgr_history_feature_inputs(substrate, i, range_end, cutoff, fields, masks)
      } else {
        ledgr_history_feature_direct_inputs(substrate, i, range_end, fields)
      }
      cache <- new.env(hash = TRUE, parent = emptyenv())
      shadow_cache <- if (debug && any(admitted)) new.env(hash = TRUE, parent = emptyenv())
      for (d in seq_along(certified)) {
        if (admitted[[d]]) {
          cell <- if (debug) {
            ledgr_history_feature_direct_checked(
              certified[[d]], inputs, bounds$from, output_carry, cache, shadow_cache, keep
            )
          } else {
            ledgr_history_feature_direct(certified[[d]], inputs, bounds$from, output_carry, cache)
          }
          out[[d]][i, keep] <- cell$value[keep]
          calculated_count[d, i] <- calculated_count[d, i] + cell$count
          exceptions <- cell$exceptions
        } else {
          calculated <- ledgr_history_feature_calculate(
            certified[[d]], inputs, bounds$from, output_carry, cache
          )
          out[[d]][i, keep] <- calculated$value[keep]
          calculated_count[d, i] <- calculated_count[d, i] + sum(calculated$calculated[keep])
          exceptions <- ledgr_feature_plane_exceptions(
            certified[[d]], inputs, calculated, ranges$start[[r]], keep
          )
        }
        for (field in names(exceptions)) {
          if (length(exceptions[[field]]) > 0L) {
            planes[[d]][[field]][[i]] <- c(planes[[d]][[field]][[i]], exceptions[[field]])
          }
        }
      }
    }
  }
  ledgr_history_feature_causality(substrate, certified, bounds, calculated_count, out)
  attr(out, "ledgr_feature_planes") <- ledgr_feature_plane_records(
    planes, substrate$instrument_ids, bounds
  )
  out
}

# Sparse evidence planes retained by preparation for history reads (v12
# Sections 5 and 6). Preparation keeps only what a read cannot derive from
# the prepared values and the cutoff masks, in run-length or exception form:
# - segments: each admitted run's first and last column and the column where
#   it first reaches stable_after (warm-up and re-warming are the positions
#   before it, derived by index);
# - reason runs: expected columns whose required input is unavailable, coded
#   1 required input missing, 2 carried input excluded (return and volatility
#   families), 3 output carry expired;
# - input carry: columns whose own required input was policy-carried;
# - output carry: columns whose value is an earlier calculated value, with
#   that value's source time and age.
# Columns outside the calculation bounds are outside_calculation by index.
ledgr_feature_plane_fields <- function() {
  c(
    "input_col", "output_col", "output_source", "output_age",
    "segment_start", "segment_ready", "segment_end",
    "reason_start", "reason_end", "reason_code"
  )
}

ledgr_feature_plane_chunks <- function(n_inst) {
  # One slot per instrument, filled in place; an instrument with several
  # knowledge ranges appends to its own slot.
  stats::setNames(
    lapply(ledgr_feature_plane_fields(), function(field) vector("list", n_inst)),
    ledgr_feature_plane_fields()
  )
}

# The exceptions one definition produced for one instrument and knowledge
# range (columns range_start..range_end); the caller stores them by
# instrument index.
ledgr_feature_plane_exceptions <- function(cert, inputs, calculated, range_start, keep) {
  declarations <- cert$declarations
  excluded <- identical(declarations$input_carry, "excluded")
  carried_any <- Reduce(`|`, lapply(declarations$required_fields, function(field) {
    inputs$carried[[field]][keep]
  }))
  out <- list()
  if (!excluded && any(carried_any)) out$input_col <- keep[carried_any]
  carry <- calculated$output_carry
  expired <- rep(FALSE, length(keep))
  if (!is.null(carry)) {
    # The output-carry planes are aligned on calc, which starts at or before
    # range_start; keep's positions are calc's tail.
    at <- match(keep, calculated$calc)
    flagged <- carry$output_carried[at]
    if (any(flagged)) {
      out$output_col <- keep[flagged]
      out$output_source <- as.numeric(carry$source_ts_utc)[at][flagged]
      out$output_age <- as.integer(carry$carry_age_sessions)[at][flagged]
    }
    expired <- carry$missing_reason[at] == "output_carry_expired" &
      !calculated$available[keep]
  }
  segments <- calculated$segments
  inside <- segments$end >= range_start
  if (any(inside)) {
    out$segment_start <- pmax(segments$start[inside], range_start)
    out$segment_ready <- segments$ready[inside]
    out$segment_end <- segments$end[inside]
  }
  code <- integer(length(keep))
  unavailable <- inputs$expected[keep] & !calculated$available[keep]
  code[unavailable] <- 1L
  code[unavailable & excluded & carried_any] <- 2L
  code[expired] <- 3L
  if (any(code > 0L)) {
    changes <- c(TRUE, code[-1L] != code[-length(code)] | diff(keep) != 1L)
    starts <- which(changes)
    ends <- c(starts[-1L] - 1L, length(code))
    hit <- code[starts] > 0L
    out$reason_start <- keep[starts[hit]]
    out$reason_end <- keep[ends[hit]]
    out$reason_code <- code[starts[hit]]
  }
  out
}

ledgr_feature_plane_records <- function(planes, instrument_ids, bounds) {
  lapply(planes, function(chunks) {
    rows <- function(field) rep(seq_along(chunks[[field]]), lengths(chunks[[field]]))
    flat <- function(field) unlist(chunks[[field]], use.names = FALSE)
    list(
      instrument_ids = as.character(instrument_ids),
      calc_from = as.integer(bounds$from),
      calc_to = as.integer(bounds$to),
      input_row = rows("input_col"),
      input_col = as.integer(flat("input_col")),
      output_row = rows("output_col"),
      output_col = as.integer(flat("output_col")),
      output_source_ts = as.numeric(flat("output_source")),
      output_age = as.integer(flat("output_age")),
      segment_row = rows("segment_start"),
      segment_start = as.integer(flat("segment_start")),
      segment_ready = as.integer(flat("segment_ready")),
      segment_end = as.integer(flat("segment_end")),
      reason_row = rows("reason_start"),
      reason_start = as.integer(flat("reason_start")),
      reason_end = as.integer(flat("reason_end")),
      reason_code = as.integer(flat("reason_code"))
    )
  })
}

# Sampled causality checks (v12 Section 6). They run inside preparation, so
# a refusal precedes every candidate, fold and precompute payload. Each
# concrete definition is probed once, on the instrument with the most
# calculated cells, at no more than four fixed positions: the first, the
# last and the two interior thirds of its calculated cells that have later
# history in their calculation range. A position is recomputed on the
# history ending there and must reproduce the prepared value exactly, so a
# definition that reads later rows, or carries state between calls, refuses.
# Every definition with calculated cells gets this prefix check, built-ins
# and catalogue rows included. Only a custom bounded definition with both
# `fn` and `series_fn` is also refuted at the same positions: `fn` on its
# handed window must equal the `series_fn` value on the full causal prefix
# within the declared tolerance; package tests certify that parity for
# built-ins and catalogue rows. The cost is a fixed number of recomputations
# of one instrument per definition, linear in history length, never all
# prefixes.
ledgr_history_feature_causality_positions <- function(n) {
  if (n < 1L) return(integer())
  unique(c(1L, as.integer(ceiling(n * c(1, 2) / 3)), n))
}

ledgr_history_feature_inputs_prefix <- function(inputs, k) {
  rows <- seq_len(k)
  take <- function(x) lapply(x, `[`, rows)
  list(
    instrument_id = inputs$instrument_id,
    axis = inputs$axis[rows],
    expected = inputs$expected[rows],
    terminal = inputs$terminal[rows],
    terminal_asserted = inputs$terminal_asserted[rows],
    raw = take(inputs$raw),
    treated = take(inputs$treated),
    carried = take(inputs$carried)
  )
}

ledgr_history_feature_causality <- function(substrate, certified, bounds, calculated_count, values) {
  probes <- list()
  fields <- ledgr_history_feature_fields(certified)
  for (d in seq_along(certified)) {
    counts <- calculated_count[d, ]
    if (!any(counts > 0L)) next
    i <- which.max(counts)
    key <- as.character(i)
    if (is.null(probes[[key]])) {
      ranges <- ledgr_history_feature_ranges(substrate, i, bounds$from, bounds$to)
      probes[[key]] <- lapply(seq_along(ranges$start), function(r) {
        range_end <- ranges$end[[r]]
        list(
          start = ranges$start[[r]],
          end = range_end,
          inputs = ledgr_history_feature_inputs(
            substrate, i, range_end, substrate$axis[[range_end]], fields
          ),
          cache = new.env(hash = TRUE, parent = emptyenv())
        )
      })
    }
    ledgr_history_feature_check_definition(
      certified[[d]], probes[[key]], bounds$from, values[[d]][i, ]
    )
  }
  invisible(TRUE)
}

ledgr_history_feature_check_definition <- function(cert, probe, calc_from, prepared) {
  def <- cert$def
  full <- lapply(probe, function(p) {
    ledgr_history_feature_calculate(cert, p$inputs, calc_from, NULL, p$cache)
  })
  column <- integer()
  range <- integer()
  for (r in seq_along(probe)) {
    keep <- seq.int(probe[[r]]$start, probe[[r]]$end)
    keep <- keep[full[[r]]$calculated[keep] & keep < probe[[r]]$end]
    column <- c(column, keep)
    range <- c(range, rep(r, length(keep)))
  }
  sampled <- ledgr_history_feature_causality_positions(length(column))
  for (s in sampled) {
    k <- column[[s]]
    r <- range[[s]]
    prefix <- ledgr_history_feature_calculate(
      cert,
      ledgr_history_feature_inputs_prefix(probe[[r]]$inputs, k),
      calc_from,
      NULL,
      probe[[r]]$cache
    )
    if (!identical(prefix$raw[[k]], prepared[[k]])) {
      ledgr_history_feature_refuse_lookahead(
        def, probe[[r]]$inputs, k, prepared[[k]], prefix$raw[[k]]
      )
    }
  }
  declarations <- cert$declarations
  if (!identical(cert$certification, "custom") ||
      !identical(declarations$history_class, "bounded") ||
      !is.function(def$series_fn) || !is.function(def$fn)) {
    return(invisible(TRUE))
  }
  width <- as.integer(def$requires_bars)
  tolerance <- declarations$tolerance
  for (s in sampled) {
    k <- column[[s]]
    r <- range[[s]]
    inputs <- probe[[r]]$inputs
    fields <- if (identical(declarations$input_carry, "excluded")) inputs$raw else inputs$treated
    calc <- seq.int(calc_from, length(inputs$axis))
    rows <- calc[inputs$expected[calc]]
    p <- match(k, rows)
    scalar <- ledgr_normalize_feature_scalar_output(
      ledgr_call_feature_fn(
        def$fn,
        ledgr_history_feature_frame(inputs, fields, rows[seq.int(p - width + 1L, p)]),
        def$params %||% list()
      ),
      def$id
    )
    series <- prepared[[k]]
    agree <- if (is.na(scalar)) {
      FALSE
    } else if (tolerance > 0) {
      abs(scalar - series) / max(1, abs(series)) <= tolerance
    } else {
      identical(scalar, series)
    }
    if (!isTRUE(agree)) {
      ledgr_history_feature_refuse_parity(def, inputs, k, scalar, series, tolerance)
    }
  }
  invisible(TRUE)
}

ledgr_history_feature_refuse_lookahead <- function(def, inputs, row, full_value, prefix_value) {
  rlang::abort(
    sprintf(
      paste0(
        "Indicator '%s' is not prefix invariant for instrument '%s' at %s: ",
        "its value on the full history (%s) differs from its value on the ",
        "history ending there (%s)."
      ),
      def$id,
      inputs$instrument_id,
      format(inputs$axis[[row]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      format(full_value, digits = 17),
      format(prefix_value, digits = 17)
    ),
    class = c("ledgr_feature_lookahead_detected", "ledgr_invalid_feature_output"),
    feature_id = def$id,
    instrument_id = inputs$instrument_id,
    ts_utc = inputs$axis[[row]],
    full_value = full_value,
    prefix_value = prefix_value
  )
}

# Aligned evidence for one instrument and definition at a cutoff. It shares
# the calculation above; nothing here is retained by preparation.
ledgr_history_feature_planes <- function(substrate,
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
  input_carried <- input_carried & in_range
  # A genuinely calculated cell is its own source (age 0), with or without
  # an output-carry policy.
  valid <- calculated$calculated
  source_ts[valid] <- as.numeric(inputs$axis)[valid]
  carry_age[valid] <- 0L
  missing_reason <- rep("", prefix_end)
  missing_reason[!inputs$expected] <- "not_expected"
  missing_reason[inputs$expected & in_range & !calculated$available] <- "required_input_missing"
  missing_reason[inputs$expected & in_range & !calculated$available & excluded & carried_any] <-
    "carried_input_excluded"
  missing_reason[calculated$available & !calculated$ready] <- "not_ready"
  # Cut 16 decision (21): a ready cell whose calculation is not finite.
  missing_reason[calculated$ready & !calculated$calculated] <- "calculation_non_finite"
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
    # A window never spans a terminal interval (Cut 16 decision 20).
    crossed <- cumsum(as.integer(inputs$terminal_asserted))[expected_rows]
    has_window <- k >= width
    has_window[has_window] <- crossed[k[has_window]] ==
      crossed[k[has_window] - width + 1L]
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
