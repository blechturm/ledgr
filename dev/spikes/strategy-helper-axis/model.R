# Executable statement of the LDG-2906 decision (Cut 22).
#
# probe.R sources this file when AXIS_PROBE_MODEL points to it. It replaces
# the helpers the decision changes, in `H`, with the smallest statement of the
# decided semantics. expected.R runs the probe with it and writes
# expected_delta.csv. The probe also installs these functions into the ledgr
# namespace while it runs the runtime rows, so the real fold, target
# validators and fills judge the decided helpers.
#
# This is the specification oracle for the probe, not an implementation. Every
# rule the decision keeps is delegated to the production code that states it
# today: context and payload validation (`ledgr_strategy_context_*`), `n`,
# lookback and feature-ID validation, the value-mode constructors, weights and
# sizing. The new rules are the only new code.

real <- H
ns <- asNamespace("ledgr")
model_abort <- function(message, class) rlang::abort(message, class = class)

# Dense contexts expose the allocation membership and the eligibility planes,
# all eligible. Availability contexts are unchanged.
adapt <- function(ctx) {
  if (isTRUE(ctx$availability_active)) return(ctx)
  n <- length(ctx$universe)
  ctx$members <- ctx$universe
  ctx$vec$member <- rep(TRUE, n)
  ctx$vec$target_restricted <- rep(FALSE, n)
  ctx$vec$target_restriction_reason <- rep("", n)
  ctx$vec$admissible <- rep(TRUE, n)
  ctx
}
is_ctx <- function(x) inherits(x, "ledgr_pulse_context")
eligible_ids <- function(ctx) ctx$universe[as.logical(ctx$vec$admissible)]

# The production entrance, with the eligible IDs in the place of the members:
# coverage, missing decisions and every condition class stay as today.
context_entrance <- function(x, helper, allowed, required, universe_supplied) {
  if (universe_supplied) {
    ns$ledgr_strategy_context_abort("`universe` must not be supplied in context mode.")
  }
  ctx <- adapt(x)
  parts <- ns$ledgr_strategy_context_parts(ctx, helper)
  list(ctx = ctx, axis = parts$axis, eligible = eligible_ids(ctx))
}
# Expand an eligible-ID projection back to the axis. Signals keep a supplied
# raw value for every axis ID; uncovered IDs are NA.
axis_values <- function(payload, axis) {
  payload_names <- names(payload)
  if (is.null(payload_names)) return(stats::setNames(as.vector(payload), axis))
  out <- stats::setNames(rep(payload[NA_integer_], length(axis)), axis)
  out[payload_names] <- as.vector(payload)
  out
}
attach_eligibility <- function(sig, ctx) {
  attr(sig, "eligible") <- as.logical(ctx$vec$admissible)
  sig
}

# Signals: raw values over the axis, eligibility in the `eligible` attribute.
H$ledgr_signal <- function(x, universe = NULL, origin = NULL, ...) {
  if (!is_ctx(x)) return(real$ledgr_signal(x, universe = universe, origin = origin, ...))
  entry <- context_entrance(x, "ledgr_signal", "values", TRUE, !missing(universe))
  dots <- ns$ledgr_strategy_context_dots(list(...), "ledgr_signal", allowed = "values", required = TRUE)
  ns$ledgr_strategy_context_align(dots$values, "values", "numeric", entry$axis, entry$eligible)
  values <- axis_values(dots$values, entry$axis)
  attach_eligibility(real$ledgr_signal(values, origin = origin), entry$ctx)
}
H$ledgr_signal_feature <- function(ctx, feature_id) {
  axis <- ns$ledgr_validate_strategy_helper_ctx(ctx, "ledgr_signal_feature")
  if (!is.character(feature_id) || length(feature_id) != 1L || is.na(feature_id) || !nzchar(feature_id)) {
    model_abort("`feature_id` must be one non-empty character scalar.", "ledgr_invalid_strategy_helper")
  }
  ctx <- adapt(ctx)
  values <- stats::setNames(as.numeric(ctx$vec$feature(feature_id)), axis)
  attach_eligibility(real$ledgr_signal(values, universe = axis, origin = feature_id), ctx)
}
H$ledgr_signal_return <- function(ctx, lookback = 20L) {
  ns$ledgr_validate_strategy_helper_ctx(ctx, "ledgr_signal_return")
  lookback <- ns$ledgr_strategy_helper_validate_lookback(lookback)
  H$ledgr_signal_feature(ctx, sprintf("return_%d", lookback))
}

# Selections cover the axis; ineligible IDs are FALSE whatever the payload;
# `missing` covers eligible IDs only; `ids` naming an ineligible axis ID leave
# it unselected.
H$ledgr_selection <- function(x, universe = NULL, origin = NULL, ..., missing = c("error", "exclude")) {
  if (!is_ctx(x)) {
    args <- list(x, universe = universe, origin = origin, ...)
    if (!base::missing(missing)) args$missing <- missing
    return(do.call(real$ledgr_selection, args))
  }
  entry <- context_entrance(x, "ledgr_selection", c("ids", "where"), FALSE, !base::missing(universe))
  missing <- tryCatch(match.arg(missing), error = function(err) {
    ns$ledgr_strategy_context_abort("`missing` must be one of \"error\" or \"exclude\".")
  })
  dots <- ns$ledgr_strategy_context_dots(list(...), "ledgr_selection", allowed = c("ids", "where"))
  axis <- entry$axis
  selected <- if (length(dots) == 0L) {
    axis %in% entry$eligible
  } else if (identical(names(dots), "ids")) {
    ns$ledgr_strategy_context_ids(dots$ids, axis, axis)
    axis %in% intersect(dots$ids, entry$eligible)
  } else {
    decided <- ns$ledgr_strategy_context_align(dots$where, "where", "logical", axis, entry$eligible,
      missing_decisions = missing)
    axis %in% names(decided)[decided]
  }
  real$ledgr_selection(stats::setNames(selected, axis), origin = origin)
}

# Ranking uses eligible, non-missing scores only and returns a selection over
# the signal's axis; with nothing usable it is all FALSE.
H$ledgr_select_top_n <- function(signal, n, partial = c("warn", "allow")) {
  if (!inherits(signal, "ledgr_signal")) {
    model_abort("`signal` must be a ledgr_signal object.", "ledgr_invalid_strategy_helper")
  }
  n <- ns$ledgr_strategy_helper_validate_n(n)
  partial <- tryCatch(match.arg(partial), error = function(err) {
    model_abort("`partial` must be one of \"warn\" or \"allow\".", "ledgr_invalid_strategy_helper")
  })
  values <- as.numeric(signal)
  ids <- names(signal)
  eligible <- attr(signal, "eligible") %||% rep(TRUE, length(ids))
  usable <- which(eligible & !is.na(values))
  ranked <- usable[order(-values[usable], ids[usable])]
  pick <- ranked[seq_len(min(n, length(ranked)))]
  if (length(usable) > 0L && length(pick) < n && identical(partial, "warn")) {
    rlang::warn("short ranking", class = "ledgr_partial_selection")
  }
  selected <- stats::setNames(seq_along(ids) %in% pick, ids)
  out <- real$ledgr_selection(selected, universe = ids, origin = attr(signal, "origin"))
  if (length(usable) == 0L) class(out) <- c("ledgr_empty_selection", class(out))
  out
}

# Convenience target helpers keep every ineligible holding at its current
# quantity (rebalancing reserves its exposure once) and size or assign
# eligible IDs only; a selected or weighted ineligible ID fails. The package
# already does exactly this for nonmembers, so the model presents the
# ineligible IDs as nonmembers.
eligible_as_members <- function(ctx) {
  ctx <- adapt(ctx)
  if (isTRUE(ctx$availability_active)) ctx$members <- eligible_ids(ctx)
  ctx
}
H$ledgr_target_rebalance <- function(weights, ctx, equity_fraction = 1.0, keep = NULL) {
  real$ledgr_target_rebalance(weights, eligible_as_members(ctx), equity_fraction = equity_fraction, keep = keep)
}
H$ledgr_target_quantity <- function(selection, ctx, qty) {
  if (!inherits(selection, "ledgr_selection")) {
    model_abort("`selection` must be a ledgr_selection object.", "ledgr_invalid_strategy_helper")
  }
  ctx <- eligible_as_members(ctx)
  ids <- names(selection)
  chosen <- as.logical(selection)
  if (length(setdiff(ids, ctx$universe)) > 0L || any(chosen & !(ids %in% ctx$members))) {
    model_abort("`selection` selects an instrument that is not eligible.", "ledgr_invalid_strategy_helper")
  }
  keep <- ids %in% ctx$members
  sub <- real$ledgr_selection(stats::setNames(chosen[keep], ids[keep]), universe = ids[keep],
    origin = attr(selection, "origin"))
  real$ledgr_target_quantity(sub, ctx, qty)
}

# The signal wrapper maps eligible IDs only, holds ineligible ones at their
# current quantity, and accepts an empty axis; everything else is the
# package's wrapper validation.
H$ledgr_signal_strategy <- function(fn, long_qty = 1, flat_qty = 0, short_qty = -1) {
  real$ledgr_signal_strategy(fn, long_qty = long_qty, flat_qty = flat_qty, short_qty = short_qty)
  map <- c(LONG = long_qty, FLAT = flat_qty, SHORT = short_qty)
  force(fn)
  function(ctx, params) {
    fail <- function(message) model_abort(message, "ledgr_invalid_strategy_result")
    ctx <- adapt(ctx)
    axis <- ctx$universe
    eligible <- as.logical(ctx$vec$admissible)
    target <- stats::setNames(as.numeric(ctx$vec$position), axis)
    signals <- fn(ctx)
    if (!is.character(signals)) fail("Signal strategy functions must return character signals.")
    if (length(signals) == 0L) {
      if (any(eligible)) fail("Signal strategy output must cover every eligible instrument.")
      return(target)
    }
    signal_names <- names(signals)
    if (is.null(signal_names) && length(signals) == 1L && length(axis) == 1L) signal_names <- axis
    if (is.null(signal_names) || anyNA(signal_names) || any(!nzchar(signal_names)) ||
        anyDuplicated(signal_names) || length(setdiff(signal_names, axis)) > 0L) {
      fail("Signal strategy functions must return a named character vector with unique, non-empty instrument names.")
    }
    if (!all(axis[eligible] %in% signal_names)) fail("Signal strategy output must cover every eligible instrument.")
    code <- toupper(trimws(signals[match(axis[eligible], signal_names)]))
    if (anyNA(code) || any(!nzchar(code))) fail("Signal strategy output contains missing or empty signals.")
    if (!all(code %in% names(map))) fail("Unknown signal(s).")
    target[eligible] <- as.numeric(map[code])
    target
  }
}

# Context-aware warmup over eligible IDs, vacuously TRUE when none; a signal
# is accepted by its names. The one-argument form is the package's.
H$ledgr_passed_warmup <- function(x, values) {
  if (base::missing(values)) return(real$ledgr_passed_warmup(x))
  if (!is_ctx(x)) model_abort("`x` must be a ledgr pulse context when `values` is supplied.", "ledgr_invalid_warmup_input")
  if (inherits(values, "ledgr_signal")) values <- stats::setNames(as.numeric(values), names(values))
  if (!is.numeric(values)) model_abort("`values` must be numeric.", "ledgr_invalid_warmup_input")
  ctx <- adapt(x)
  parts <- ns$ledgr_strategy_context_parts(ctx, "ledgr_passed_warmup")
  eligible <- ns$ledgr_strategy_context_align(values, "values", "numeric", parts$axis, eligible_ids(ctx))
  isTRUE(all(!is.na(eligible)))
}
