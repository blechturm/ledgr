# Executable statement of the LDG-2906 decision (Cut 22).
#
# probe.R sources this file when AXIS_PROBE_MODEL points to it. It replaces
# the helpers the decision changes, in `H`, with the smallest vectorized
# statement of the decided semantics, and it states the decided runtime
# outcomes. expected.R runs the probe with it and writes expected_delta.csv.
#
# This is the specification oracle for the probe, not an implementation. It
# reuses the package wherever the decision keeps behaviour: value-mode
# constructors, weights, and sizing. Target helpers are called on a context
# whose allocation membership is its admissible IDs, which is exactly the
# decision: ineligible IDs are treated as held nonmembers are today.

real <- H
model_abort <- function(class, message = class) rlang::abort(message, class = class)

# Decision 1: one eligibility plane in every context. Dense contexts expose
# the allocation membership and the eligibility planes, all eligible.
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
eligible_of <- function(ctx) as.logical(ctx$vec$admissible)

# Context payloads: unnamed input has length(axis) and aligns by position;
# named input uses unique axis IDs and covers every eligible ID; uncovered
# ineligible IDs are NA.
align_axis <- function(values, u, adm) {
  values <- unclass(values)
  nm <- names(values)
  if (is.null(nm)) {
    if (length(values) != length(u)) model_abort("ledgr_invalid_strategy_type")
    return(unname(values))
  }
  if (anyNA(nm) || anyDuplicated(nm) || length(setdiff(nm, u)) > 0L || !all(u[adm] %in% nm)) {
    model_abort("ledgr_invalid_strategy_type")
  }
  out <- rep(values[NA_integer_], length(u))
  out[match(nm, u)] <- unname(values)
  unname(out)
}

# Decision 2: context-derived signals cover the axis with raw values and
# carry the eligibility plane as the `eligible` attribute.
axis_signal <- function(ctx, values, origin) {
  u <- ctx$universe
  sig <- real$ledgr_signal(stats::setNames(as.numeric(values), u), universe = u, origin = origin)
  attr(sig, "eligible") <- eligible_of(ctx)
  sig
}
H$ledgr_signal_feature <- function(ctx, feature_id) {
  ctx <- adapt(ctx)
  axis_signal(ctx, ctx$vec$feature(feature_id), feature_id)
}
H$ledgr_signal_return <- function(ctx, lookback = 20L) {
  H$ledgr_signal_feature(ctx, sprintf("return_%d", as.integer(lookback)))
}
H$ledgr_signal <- function(x, ...) {
  if (!is_ctx(x)) return(real$ledgr_signal(x, ...))
  ctx <- adapt(x)
  values <- list(...)$values
  if (!is.numeric(unclass(values))) model_abort("ledgr_invalid_strategy_type")
  axis_signal(ctx, align_axis(values, ctx$universe, eligible_of(ctx)), "values")
}

# Decision 3: context selections cover the axis; ineligible entries are
# FALSE whatever the payload; `missing` covers eligible entries only; `ids`
# naming an ineligible axis ID leave it unselected.
H$ledgr_selection <- function(x, ..., missing = c("error", "exclude")) {
  if (!is_ctx(x)) return(real$ledgr_selection(x, ...))
  missing <- match.arg(missing)
  args <- list(...)
  ctx <- adapt(x)
  u <- ctx$universe
  adm <- eligible_of(ctx)
  sel <- adm
  if (!is.null(args$ids)) {
    ids <- args$ids
    if (!is.character(ids) || anyNA(ids) || anyDuplicated(ids) || length(setdiff(ids, u)) > 0L) {
      model_abort("ledgr_invalid_strategy_type")
    }
    sel <- adm & u %in% ids
  } else if (!is.null(args$where)) {
    if (!is.logical(unclass(args$where))) model_abort("ledgr_invalid_strategy_type")
    where <- align_axis(args$where, u, adm)
    if (identical(missing, "error") && any(adm & is.na(where))) model_abort("ledgr_invalid_strategy_type")
    sel <- adm & !is.na(where) & where
  }
  real$ledgr_selection(stats::setNames(sel, u), universe = u, origin = "context")
}

# Decision 4: ranking uses only eligible, non-missing scores and returns a
# selection over the signal's axis; an empty ranking is all FALSE.
H$ledgr_select_top_n <- function(signal, n, partial = c("warn", "allow")) {
  if (!inherits(signal, "ledgr_signal")) model_abort("ledgr_invalid_strategy_helper")
  partial <- match.arg(partial)
  values <- as.numeric(signal)
  ids <- names(signal)
  eligible <- attr(signal, "eligible") %||% rep(TRUE, length(ids))
  usable <- which(eligible & !is.na(values))
  sel <- stats::setNames(rep(FALSE, length(ids)), ids)
  ranked <- usable[order(-values[usable], ids[usable])]
  pick <- ranked[seq_len(min(as.integer(n), length(ranked)))]
  if (length(usable) > 0L && length(pick) < n && identical(partial, "warn")) {
    rlang::warn("short ranking", class = "ledgr_partial_selection")
  }
  sel[pick] <- TRUE
  out <- real$ledgr_selection(sel, universe = ids, origin = attr(signal, "origin"))
  if (length(usable) == 0L) class(out) <- c("ledgr_empty_selection", class(out))
  out
}

# Decision 5: convenience target helpers keep every ineligible holding at
# its current quantity (and rebalance reserves its exposure once); they size
# or assign eligible IDs only; a selected or weighted ineligible ID fails.
admissible_members <- function(ctx) {
  ctx <- adapt(ctx)
  if (isTRUE(ctx$availability_active)) ctx$members <- ctx$universe[eligible_of(ctx)]
  ctx
}
H$ledgr_target_rebalance <- function(weights, ctx, equity_fraction = 1.0, keep = NULL) {
  real$ledgr_target_rebalance(weights, admissible_members(ctx), equity_fraction = equity_fraction, keep = keep)
}
H$ledgr_target_quantity <- function(selection, ctx, qty) {
  if (!inherits(selection, "ledgr_selection")) model_abort("ledgr_invalid_strategy_helper")
  ctx <- admissible_members(ctx)
  eligible_ids <- ctx$universe[eligible_of(ctx)]
  chosen <- as.logical(selection)
  ids <- names(selection)
  if (length(setdiff(ids, ctx$universe)) > 0L || any(chosen & !(ids %in% eligible_ids))) {
    model_abort("ledgr_invalid_strategy_helper")
  }
  keep <- ids %in% eligible_ids
  sub <- real$ledgr_selection(stats::setNames(chosen[keep], ids[keep]), universe = ids[keep])
  real$ledgr_target_quantity(sub, ctx, qty)
}

# Decision 6: the signal wrapper maps eligible IDs only, holds ineligible
# ones at their current quantity, and accepts an empty axis.
H$ledgr_signal_strategy <- function(fn, long_qty = 1, flat_qty = 0, short_qty = -1) {
  real$ledgr_signal_strategy(fn, long_qty = long_qty, flat_qty = flat_qty, short_qty = short_qty)
  map <- c(LONG = long_qty, FLAT = flat_qty, SHORT = short_qty)
  function(ctx, params) {
    ctx <- adapt(ctx)
    u <- ctx$universe
    adm <- eligible_of(ctx)
    target <- stats::setNames(as.numeric(ctx$vec$position), u)
    signals <- fn(ctx)
    if (!is.character(signals)) model_abort("ledgr_invalid_strategy_result")
    if (length(signals) == 0L) {
      if (any(adm)) model_abort("ledgr_invalid_strategy_result")
      return(target)
    }
    nm <- names(signals)
    if (is.null(nm) && length(signals) == 1L && length(u) == 1L) nm <- u
    if (is.null(nm) || anyNA(nm) || any(!nzchar(nm)) || anyDuplicated(nm) ||
        length(setdiff(nm, u)) > 0L || !all(u[adm] %in% nm)) {
      model_abort("ledgr_invalid_strategy_result")
    }
    code <- toupper(trimws(signals[match(u[adm], nm)]))
    if (anyNA(code) || !all(code %in% names(map))) model_abort("ledgr_invalid_strategy_result")
    target[adm] <- as.numeric(map[code])
    target
  }
}

# Decision 7: a context-aware warmup form over eligible IDs, vacuously TRUE
# when none; the one-argument form is unchanged.
H$ledgr_passed_warmup <- function(x, values) {
  if (missing(values)) return(real$ledgr_passed_warmup(x))
  if (!is_ctx(x) || !is.numeric(unclass(values))) model_abort("ledgr_invalid_warmup_input")
  ctx <- adapt(x)
  adm <- eligible_of(ctx)
  v <- align_axis(values, ctx$universe, adm)
  isTRUE(all(!is.na(v[adm])))
}

# The runtime rows under the decision: every run completes.
runtime_expected <- c(
  "run: signal_strategy(member-only signals), held nonmember" = "completed",
  "run: signal_strategy(axis signals LONG 10), opening nonmember CCC = 2" = "completed",
  "run: signal_strategy(axis signals), empty axis" = "completed",
  "run: selection(ctx) -> target_quantity, quantity changes while halted" = "completed",
  "run: selection(ids = BBB) -> target_quantity, quantity changes while halted" = "completed",
  "run: hand-built flat()[signal > -1] <- 5 after departure" = "completed"
)
