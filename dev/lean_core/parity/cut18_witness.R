# Cut 18 (amendment lean_owned, items (b), A1 and A2): direct differential
# witnesses for each lean-owned replacement in dev/lean_core/checks.R
# against the named pinned callable, on the required cases of
# cut18_witness_cases.csv, with debug off and on.
#
#   Rscript dev/lean_core/parity/cut18_witness.R --lib=<pinned library> --out=<csv> [--mutation=<name>]
#
# Each case evaluates the lean call and the pin call on the same inputs. A
# value must be identical (types, names, attributes; doubles bit for bit,
# no tolerance); a refusal must match on the class vector, message, call
# (the called function's name) and every payload field (reason,
# instrument_ids and the rest), and its parent condition the same way,
# recursively; the backtrace is excluded.
# A case of the manifest the grid does not produce, or a grid case the
# manifest lacks, fails the run (exit 1). --mutation loads checks.R with
# one registered fault (cut18_witness_mutations) and requires that some
# case fails (the fault is caught), else exit 1.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
source(file.path(here, "..", "load.R"))
source(file.path(here, "loop_edits.R"))
lean <- lean_core_load(opt("lib"))
ns <- asNamespace("ledgr")

# Registered faults: each must make some case differ.
cut18_witness_mutations <- list(
  state_broadcast_accepted = lean_edit("checks.R", "lean_state_value",
    "  plain <- if (identical(field$scope, \"asset\")) identical(attributes(value), axis_attr) else",
    "  plain <- if (identical(field$scope, \"asset\")) (identical(attributes(value), axis_attr) || length(value) == 1L) else"),
  state_nan_accepted = lean_edit("checks.R", "lean_state_value",
    "  if (plain && typed && !(is.double(value) && any(is.nan(value) | is.infinite(value)))) return(value)",
    "  if (plain && typed) return(value)"),
  state_reset_skipped = lean_edit("checks.R", "lean_state_apply", "    if (any(reset)) value[reset] <- defaults[[name]]", "    NULL"),
  risk_cap_order = lean_edit("checks.R", "lean_risk_apply", "    cap <- (s$max_weight * equity) / close[nz]",
    "    cap <- s$max_weight * (equity / close[nz])"),
  risk_steps_reversed = lean_edit("checks.R", "lean_risk_apply", "  for (s in steps) {", "  for (s in rev(steps)) {"),
  risk_price_refusal_skipped = lean_edit("checks.R", "lean_risk_apply",
    "    if (any(nz & !(is.finite(close) & close > 0))) return(NULL)", "    NULL"),
  afford_generators_last = lean_edit("plan.R", "lean_plan_affordability", "    c(o[generator[o]], o[!generator[o]])",
    "    c(o[!generator[o]], o[generator[o]])"),
  afford_axis_order = lean_edit("plan.R", "lean_plan_affordability", "    o <- match(id_perm, axis_pos, 0L)   # each ID-ordered axis position's candidate, or 0", "    o <- match(seq_along(id_perm), axis_pos, 0L)"),
  risk_short_check_skipped = lean_edit("checks.R", "lean_risk_targets",
    "  if (any(tq < 0 & tq < pos)) ledgr_availability_validate_short_exposure(stats::setNames(tq, ids), held)", "  NULL"))
  # Pre-summing the fixed fees (A1's order-sensitive case): all fixed amounts
  # added at once by sum(), the per-step addition dropped.
cut18_witness_mutations$cost_fees_presummed <- list(
  lean_edit("checks.R", "lean_cost_resolve", "  fee <- numeric(length(price))",
    "  fee <- numeric(length(price)) + sum(vapply(Filter(function(s) s$kind == 2L, cost$steps), function(s) s$amount, 0))"),
  lean_edit("checks.R", "lean_cost_resolve", "      fee <- fee + s$amount", "      NULL"))
cut18_witness_mutations$cost_notional_reassociated <- lean_edit("checks.R", "lean_cost_resolve",
  "      fee <- fee + abs(as.numeric(qty) * price) * s$bps / 10000", "      fee <- fee + abs(as.numeric(qty) * price) * (s$bps / 10000)")
cut18_witness_mutations$cost_rounding_skipped <- lean_edit("checks.R", "lean_cost_resolve",
  "  list(price = round(price, digits = cost$digits), fee = fee)", "  list(price = price, fee = fee)")
cut18_witness_mutations$targets_helper_reorder_accepted <- lean_edit("checks.R", "lean_targets",
  "    if (is.numeric(u) && identical(names(u), ids) && all(is.finite(u))) return(u[ids])",
  "    if (is.numeric(u) && setequal(names(u), ids) && all(is.finite(u))) return(u)")
cut18_witness_mutations$targets_helper_attributes_kept <- lean_edit("checks.R", "lean_targets",
  "    if (is.numeric(u) && identical(names(u), ids) && all(is.finite(u))) return(u[ids])",
  "    if (is.numeric(u) && identical(names(u), ids) && all(is.finite(u))) return(u)")
cut18_witness_mutations$targets_axis_check_skipped <- lean_edit("checks.R", "lean_targets",
  "  if (ids_ok && length(ids) > 0L && identical(class(raw), c(\"ledgr_target\", \"numeric\"))) {",
  "  if (length(ids) > 0L && identical(class(raw), c(\"ledgr_target\", \"numeric\"))) {")
cut18_witness_mutations$sizing_stale_not_detected <- lean_edit("checks.R", "lean_sizing_evidence",
  "      return(if (stale) NULL else x)", "      return(x)")
cut18_witness_mutations$sizing_unavailable_on_plain_path <- lean_edit("checks.R", "lean_sizing_evidence",
  "    all(rc %in% .ledgr_sizing_reason_codes) && !any(rc == \"sizing_unavailable\")", "    all(rc %in% .ledgr_sizing_reason_codes)")
cut18_witness_mutations$targets_empty_helper_taken <- lean_edit("checks.R", "lean_targets",
  "  if (ids_ok && length(ids) > 0L && identical(class(raw), c(\"ledgr_target\", \"numeric\"))) {",
  "  if (ids_ok && identical(class(raw), c(\"ledgr_target\", \"numeric\"))) {")
cut18_witness_mutations$sizing_field_before_shape <- lean_edit("checks.R", "lean_sizing_evidence",
  "  id <- if (ok) x$instrument_id", "  id <- x$instrument_id")
cut18_witness_mutations$sizing_classed_column_taken <- lean_edit("checks.R", "lean_sizing_evidence",
  "    !is.object(x$instrument_id) && !is.object(x$requested_quantity) && !is.object(x$pre_floor_quantity) &&",
  "    TRUE &&")
cut18_witness_mutations$debug_payload_unchecked <- lean_edit("checks.R", "sig",
  "    list(class = class(e), message = conditionMessage(e), reason = e$reason, ids = e$instrument_ids,",
  "    list(class = class(e), message = conditionMessage(e), reason = e$reason, ids = NULL,")
cut18_witness_mutations$sizing_requested_unchecked <- lean_edit("checks.R", "lean_sizing_evidence",
  "    if (all(is.finite(x$rounded_quantity)) && all(is.finite(x$position_before)) && all(is.finite(x$requested_quantity)) &&",
  "    if (all(is.finite(x$rounded_quantity)) && all(is.finite(x$position_before)) &&")
mutation <- opt("mutation", "")
if (nzchar(mutation)) {
  m <- cut18_witness_mutations[[mutation]]
  if (is.null(m)) stop("unknown mutation: ", mutation)
  lean_load_edited(lean, lean$.lean_home, if (!is.null(m$file)) list(m) else m)
}

norm_cond <- function(e) {
  if (!inherits(e, "condition")) return(NULL)
  fields <- unclass(e); fields$trace <- NULL; fields$parent <- NULL
  # the called function, as an error message shows it (`Error in f()`); the
  # caller's argument expressions are internal variable names
  # (a witness's own `ns$f` or `ledgr:::f` access path is dropped)
  fields$call <- if (is.null(conditionCall(e))) NULL else sub(".*[$:]", "", paste(deparse(conditionCall(e)[[1L]]), collapse = " "))
  list(class = class(e), fields = fields[order(names(fields))], parent = norm_cond(e$parent))
}
outcome <- function(f) tryCatch(list(value = f()), error = function(e) list(error = norm_cond(e)))
cases <- list()
case <- function(replacement, id, lean_call, pin_call) cases[[length(cases) + 1L]] <<- list(replacement = replacement, id = id, lean = lean_call, pin = pin_call)

## R5: state field values and state patches ---------------------------------
ids <- c("CCC", "AAA", "BBB"); ids_attr <- list(names = ids)
decl <- ns$ledgr_strategy_state_normalize(asset_state = list(above = FALSE, w = 0.5, tag = "x"),
                                          portfolio_state = list(k = 0L, x = 1.5, on = TRUE))
fields <- decl$fields; names(fields) <- vapply(fields, function(f) f$name, "")
defaults <- ns$ledgr_strategy_state_default_scalars(decl)
state0 <- ns$ledgr_strategy_state_defaults(decl, ids, default_scalars = defaults)
nmd <- function(v, n = ids) stats::setNames(v, n)
values <- list(
  asset_logical_named = list("above", nmd(c(TRUE, FALSE, TRUE))),
  asset_logical_na = list("above", nmd(c(NA, FALSE, TRUE))),
  asset_double_named = list("w", nmd(c(0.1, 0.2, 0.3))),
  asset_double_na = list("w", nmd(c(NA, 0.2, 0.3))),
  asset_double_nan = list("w", nmd(c(NaN, 0.2, 0.3))),
  asset_double_inf = list("w", nmd(c(Inf, 0.2, 0.3))),
  asset_character = list("tag", nmd(c("a", "b", "c"))),
  asset_broadcast_scalar = list("above", TRUE),
  asset_reordered_names = list("above", nmd(c(TRUE, FALSE, TRUE), rev(ids))),
  asset_unnamed_full = list("above", c(TRUE, FALSE, TRUE)),
  asset_partial_names = list("above", nmd(c(TRUE, FALSE), ids[1:2])),
  asset_wrong_type = list("above", nmd(c(1, 0, 1))),
  asset_classed = list("above", structure(nmd(c(TRUE, FALSE, TRUE)), class = "myclass")),
  asset_extra_attribute = list("above", structure(nmd(c(TRUE, FALSE, TRUE)), note = 1)),
  asset_integer_for_double = list("w", nmd(1:3)),
  portfolio_integer = list("k", 3L),
  portfolio_integer_na = list("k", NA_integer_),
  portfolio_double = list("x", 2.5),
  portfolio_double_nan = list("x", NaN),
  portfolio_logical = list("on", FALSE),
  portfolio_named_scalar = list("k", c(a = 3L)),
  portfolio_length_two = list("k", c(1L, 2L)),
  portfolio_double_for_integer = list("k", 3),
  portfolio_attribute = list("k", structure(3L, note = 1)))
for (nm in names(values)) local({
  f <- fields[[values[[nm]][[1L]]]]; v <- values[[nm]][[2L]]
  case("R5", paste0("value_", nm), function() lean$lean_state_value(v, f, ids, ids_attr),
       function() ns$ledgr_strategy_state_validate_value(v, f, ids))
})
one_axis <- "AAA"
case("R5", "value_axis_one_named", function() lean$lean_state_value(c(AAA = TRUE), fields$above, one_axis, list(names = one_axis)),
     function() ns$ledgr_strategy_state_validate_value(c(AAA = TRUE), fields$above, one_axis))
case("R5", "value_axis_empty", function() lean$lean_state_value(stats::setNames(logical(), character()), fields$above, character(),
                                                                  list(names = character())),
     function() ns$ledgr_strategy_state_validate_value(stats::setNames(logical(), character()), fields$above, character()))
st_names <- names(state0); names_ok <- TRUE
# patches built by field name, then put in the state's own order
by_name <- function(...) { p <- list(...); p[st_names] }
full <- by_name(above = nmd(c(TRUE, TRUE, FALSE)), w = nmd(c(0.4, 0.5, 0.6)), tag = nmd(c("p", "q", "r")), k = 4L, x = 0.25, on = FALSE)
patches <- list(
  full_in_order = full,
  full_with_reset = by_name(above = nmd(c(NA, TRUE, FALSE)), w = nmd(c(0.4, NA, 0.6)), tag = nmd(c("p", NA, "r")), k = NA_integer_,
                            x = NA_real_, on = NA),
  subset = list(k = 7L),
  reordered = rev(full),
  broadcast = list(above = TRUE, w = 0.9),
  unknown_field = list(k = 1L, zzz = 2),
  duplicated_names = stats::setNames(list(1L, 2L), c("k", "k")),
  empty = list(),
  unnamed = list(1L),
  na_name = stats::setNames(list(1L), NA_character_),
  empty_name = stats::setNames(list(1L), ""),
  data_frame = data.frame(k = 1L),
  not_a_list = 5L,
  bad_value_type = list(k = "a"),
  bad_value_late = local({ p <- full; p$x <- "bad"; p }))
for (nm in names(patches)) local({
  u <- patches[[nm]]
  case("R5", paste0("patch_", nm), function() lean$lean_state_apply(u, state0, fields, defaults, decl, ids, ids_attr, st_names, names_ok),
       function() ns$ledgr_strategy_state_apply_values(state0, u, decl, ids, patch = TRUE, default_scalars = defaults))
})
renamed <- state0[rev(names(state0))]
case("R5", "patch_state_renamed", function() lean$lean_state_apply(patches$full_in_order, renamed, fields, defaults, decl, ids, ids_attr,
                                                                     st_names, names_ok),
     function() ns$ledgr_strategy_state_apply_values(renamed, patches$full_in_order, decl, ids, patch = TRUE, default_scalars = defaults))

## R1: the risk plan and its post-risk and short checks ----------------------
# The pin side is the loop's former code verbatim (lean_risk_pin): the pin's
# ledgr_apply_risk_plan() on a context whose reads give the equity and the
# decision close, then its admissibility and short-exposure checks.
risk_ctx <- function(equity, close, rid) {
  structure(list(equity = equity, close = stats::setNames(close, rid),
                 .pulse_lookup = list2env(list(availability = list(risk_mark = stats::setNames(close, rid))))),
            class = "ledgr_pulse_context")
}
plan_of <- function(...) ns$ledgr_risk_plan_compile(ledgr::ledgr_risk_chain(...), params = list())
risk_case <- function(id, plan, sq, held, equity, close, rid = ids) {
  targets <- stats::setNames(sq, rid); held_n <- stats::setNames(held, rid); ctx <- risk_ctx(equity, close, rid)
  steps <- lean$lean_risk_steps(plan)
  case("R1", id, function() lean$lean_risk_targets(sq, targets, held, held_n, steps, equity, close, rid, plan, ctx),
       function() lean$lean_risk_pin(targets, held_n, plan, ctx))
}
mw <- function(w) ledgr::ledgr_risk_max_weight(w)
lo <- ledgr::ledgr_risk_long_only()
cl3 <- c(37.13, 101.7, 9.83)
risk_case("max_weight_binding", plan_of(mw(0.05)), c(5000, 3000, 80000), c(0, 0, 0), 1e6, cl3)
risk_case("max_weight_nonbinding", plan_of(mw(0.5)), c(50, 30, 800), c(0, 0, 0), 1e6, cl3)
risk_case("max_weight_bits", plan_of(mw(0.0731)), c(12345.678, 9876.54321, 31415.9265), c(0, 0, 0), 1234567.891, c(17.31, 3.0007, 0.3333))
risk_case("max_weight_negative_reducing_short", plan_of(mw(0.05)), c(-100, 3000, 0), c(-500, 0, 0), 1e6, cl3)
risk_case("max_weight_tiny_targets", plan_of(mw(0.05)), c(1e-9, -1e-9, 1e5), c(0, 0, 0), 1e6, cl3)
risk_case("max_weight_all_zero", plan_of(mw(0.05)), c(0, 0, 0), c(10, 0, 0), 1e6, cl3)
risk_case("max_weight_equity_zero", plan_of(mw(0.05)), c(5000, 0, 3), c(0, 0, 0), 0, cl3)
risk_case("max_weight_equity_negative", plan_of(mw(0.05)), c(5000, 0, 3), c(0, 0, 0), -10, cl3)
risk_case("max_weight_equity_na", plan_of(mw(0.05)), c(5000, 0, 3), c(0, 0, 0), NA_real_, cl3)
risk_case("max_weight_price_zero_on_target", plan_of(mw(0.05)), c(5000, 10, 3), c(0, 0, 0), 1e6, c(37.13, 0, 9.83))
risk_case("max_weight_price_na_on_zero_target", plan_of(mw(0.05)), c(5000, 0, 3), c(0, 0, 0), 1e6, c(37.13, NA, 9.83))
risk_case("long_only_clips", plan_of(lo), c(-5, 10, -1), c(0, 0, 0), 1e6, cl3)
risk_case("long_only_then_max_weight", plan_of(lo, mw(0.05)), c(-5000, 3000, 80000), c(0, 0, 0), 1e6, cl3)
risk_case("max_weight_then_long_only", plan_of(mw(0.05), lo), c(-5000, 3000, 80000), c(0, 0, 0), 1e6, cl3)
# Step order is observable through admission: long_only first zeroes a
# negative target whose close is not positive, so max_weight does not refuse
# it; max_weight first refuses (the two steps commute in value otherwise).
risk_case("order_long_only_first_bad_price", plan_of(lo, mw(0.05)), c(-50, 3000, 80000), c(0, 0, 0), 1e6, c(0, 101.7, 9.83))
risk_case("order_max_weight_first_bad_price", plan_of(mw(0.05), lo), c(-50, 3000, 80000), c(0, 0, 0), 1e6, c(0, 101.7, 9.83))
risk_case("short_refused_after_risk", plan_of(mw(0.5)), c(-10, 30, 800), c(0, 0, 0), 1e6, cl3)
risk_case("short_refused_two_ids", plan_of(mw(0.5)), c(-10, -20, 800), c(0, -5, 0), 1e6, cl3)
risk_case("reordered_axis", plan_of(mw(0.05)), c(5000, 3000, 80000), c(0, 0, 0), 1e6, cl3, rid = c("ZZZ", "AAA", "MMM"))
risk_case("one_instrument", plan_of(mw(0.05)), 80000, 0, 1e6, 9.83, rid = "AAA")
case("R1", "steps_unsupported_type", function() lean$lean_risk_steps(list(steps = list(list(type_id = "other")))), function() NULL)
case("R1", "steps_param_reference",
     function() lean$lean_risk_steps(list(steps = list(list(type_id = "max_weight", args = list(max_weight = ledgr::ledgr_param("w")))))),
     function() NULL)

## W4: the affordability scan's priority without a sort ----------------------
# Pin side: ledgr_plan_affordability(), on the candidates' stable IDs.
afford_case <- function(id, axis, cand_pos, cash_delta, blocked, generator, cash) {
  case("W4", id, function() lean$lean_plan_affordability(cash_delta, blocked, generator, axis[cand_pos], cash,
                                                          order(enc2utf8(axis), method = "radix"), cand_pos),
       function() ns$ledgr_plan_affordability(cash_delta, blocked, generator, axis[cand_pos], cash))
}
ax <- c("ZETA", "alpha", "Beta", "B10", "B9", "caf\u00e9", "CAFE", "a")
afford_case("mixed_generators", ax, c(1L, 3L, 5L, 6L), c(500, -300, 200, -900), c(FALSE, FALSE, FALSE, FALSE), c(TRUE, FALSE, TRUE, FALSE), 400)
afford_case("insufficient_cash", ax, c(2L, 4L, 7L), c(-300, -200, -150), c(FALSE, FALSE, FALSE), c(FALSE, FALSE, FALSE), 400)
afford_case("blocked_generator", ax, c(8L, 2L, 6L), c(300, -500, -100), c(TRUE, FALSE, FALSE), c(TRUE, FALSE, FALSE), 200)
afford_case("all_generators", ax, c(6L, 1L, 4L), c(10, 20, 30), c(FALSE, FALSE, FALSE), c(TRUE, TRUE, TRUE), 0)
afford_case("no_generators", ax, 8:1, c(-10, -20, -30, -40, -50, -60, -70, -80), rep(FALSE, 8), rep(FALSE, 8), 250)
afford_case("tolerance_edge", ax, c(3L, 5L), c(-100, -1e-9), c(FALSE, FALSE), c(FALSE, FALSE), 100)
afford_case("one_candidate", ax, 7L, -50, FALSE, FALSE, 10)
afford_case("no_candidate", ax, integer(), numeric(), logical(), logical(), 10)
afford_case("missing_generator_flag", ax, c(1L, 2L, 3L), c(10, NA, -5), c(FALSE, FALSE, FALSE), c(TRUE, NA, FALSE), 100)
afford_case("large_axis_few_candidates", sprintf("I%04d", 1200:1), c(17L, 900L, 3L), c(-5, 7, -2), c(FALSE, FALSE, FALSE),
            c(FALSE, TRUE, FALSE), 6)

## R2: the cost steps -------------------------------------------------------------
# Pin side: ledgr_plan_resolve() with the pin's resolver for the same model.
cost_case <- function(id, model, side, qty, open) {
  res <- ns$ledgr_cost_resolver_from_model(model)
  case("R2", id, function() lean$lean_cost_resolve(lean$lean_cost_steps(res), side, qty, open),
       function() ns$ledgr_plan_resolve(res, side, qty, open))
}
sd <- c(1L, -1L, 1L, -1L); qt <- c(120, 35.5, 7, 1e4); op <- c(37.13, 101.7, 9.83, 0.012345)
chain <- ledgr::ledgr_cost_chain
cost_case("zero", ledgr::ledgr_cost_zero(), sd, qt, op)
cost_case("spread", ledgr::ledgr_cost_spread_bps(10), sd, qt, op)
cost_case("fixed", ledgr::ledgr_cost_fixed_fee(1), sd, qt, op)
cost_case("notional", ledgr::ledgr_cost_notional_bps_fee(5), sd, qt, op)
cost_case("chain_slice2", chain(ledgr::ledgr_cost_spread_bps(10), ledgr::ledgr_cost_fixed_fee(1), ledgr::ledgr_cost_notional_bps_fee(5)), sd, qt, op)
cost_case("notional_before_fixed", chain(ledgr::ledgr_cost_spread_bps(10), ledgr::ledgr_cost_notional_bps_fee(5), ledgr::ledgr_cost_fixed_fee(1)), sd, qt, op)
cost_case("repeated_spread", chain(ledgr::ledgr_cost_spread_bps(7), ledgr::ledgr_cost_spread_bps(13)), sd, qt, op)
cost_case("repeated_fixed_order_sensitive", chain(ledgr::ledgr_cost_fixed_fee(1), ledgr::ledgr_cost_fixed_fee(2^-53),
                                                  ledgr::ledgr_cost_fixed_fee(2^-53)), sd, qt, op)
cost_case("empty_batch", chain(ledgr::ledgr_cost_spread_bps(10), ledgr::ledgr_cost_fixed_fee(1)), integer(), numeric(), numeric())
cost_case("rounding_boundary", ledgr::ledgr_cost_spread_bps(3), c(1L, -1L), c(1, 1), c(12.345678905, 98.765432105))
cost_case("overflow_quantity", ledgr::ledgr_cost_notional_bps_fee(5), 1L, 1e308, 1e10)
cost_case("negative_price_spread", ledgr::ledgr_cost_spread_bps(30000), sd, qt, op)
case("R2", "steps_foreign_resolver", function() lean$lean_cost_steps(structure(function(side, qty, open) list(price = open, fee = 0 * open),
     class = c("ledgr_cost_resolver", "function"))), function() NULL)

## R3: the strategy's targets ---------------------------------------------------
# Pin side: ledgr_validate_strategy_targets(raw, ids, allow_empty = TRUE).
tgt_case <- function(id, raw, axis = ids) {
  case("R3", id, function() lean$lean_targets(raw, axis, list(names = axis), lean$lean_targets_axis_ok(axis)),
       function() ns$ledgr_validate_strategy_targets(raw, axis, allow_empty = TRUE))
}
hctx <- list(universe = ids, close = nmd(c(37.13, 101.7, 9.83)), equity = 1e6, position = nmd(c(10, 0, 0)),
             holding_value = nmd(c(371.3, 0, 0)), buyable = nmd(c(TRUE, TRUE, TRUE)), member = nmd(c(TRUE, TRUE, TRUE)))
helper <- ledgr::ledgr_target_rebalance(hctx, weights = nmd(c(0.2, 0.3, 0.1)), invest_fraction = 0.9)
retag <- function(x, f) { y <- x; f(y) }
tgt_case("plain_in_order", nmd(c(1, 2, 3)))
tgt_case("plain_integer_in_order", nmd(1:3))
tgt_case("plain_reordered", nmd(c(1, 2, 3))[c(2, 3, 1)])
tgt_case("plain_unnamed", c(1, 2, 3))
tgt_case("plain_nan", nmd(c(1, NaN, 3)))
tgt_case("plain_extra_attribute", structure(nmd(c(1, 2, 3)), note = 1))
tgt_case("helper_in_order", helper)
tgt_case("helper_reordered", retag(helper, function(y) { u <- unclass(y)[c(2, 3, 1)]; attributes(u) <- c(attributes(unclass(y))[setdiff(names(attributes(unclass(y))), "names")], list(names = ids[c(2, 3, 1)])); class(u) <- class(y); u }))
tgt_case("helper_nan", retag(helper, function(y) { y[[2L]] <- NaN; y }))
tgt_case("helper_extra_class", retag(helper, function(y) { class(y) <- c("mine", class(y)); y }))
tgt_case("helper_missing_instrument", retag(helper, function(y) y[1:2]))
tgt_case("helper_integer_payload", retag(helper, function(y) { u <- unclass(y); storage.mode(u) <- "integer"; class(u) <- c("ledgr_target", "integer"); u }))
tgt_case("signal_intermediate", structure(nmd(c(1, 0, 1)), class = c("ledgr_signal", "numeric")))
tgt_case("extra_instrument", c(nmd(c(1, 2, 3)), ZZZ = 4))
tgt_case("duplicate_names", stats::setNames(c(1, 2, 3), c("CCC", "AAA", "AAA")))
tgt_case("character_targets", nmd(c("1", "2", "3")))
tgt_case("list_targets", as.list(nmd(c(1, 2, 3))))
tgt_case("empty_axis_empty_targets", stats::setNames(numeric(), character()), axis = character())
tgt_case("axis_invalid_duplicates", stats::setNames(c(1, 2), c("A", "A")), axis = c("A", "A"))
tgt_case("helper_empty_axis", ledgr::ledgr_target(numeric(), universe = character(), origin = "review"), axis = character())
tgt_case("helper_axis_invalid", stats::setNames(structure(c(1, 2), class = c("ledgr_target", "numeric")), c("A", "A")), axis = c("A", "A"))

## R4: the sizing evidence --------------------------------------------------------
# Pin side: ledgr_validate_sizing_evidence(x, targets, ids, position, mark).
ev0 <- attr(helper, "sizing_evidence")
tg0 <- ns$ledgr_validate_strategy_targets(helper, ids, allow_empty = TRUE)
pos0 <- as.numeric(hctx$position); mk0 <- as.numeric(hctx$close)
ev_case <- function(id, x, targets = tg0, position = pos0, mark = mk0) {
  case("R4", id, function() lean$lean_sizing_evidence(x, targets, ids, position, mark),
       function() ns$ledgr_validate_sizing_evidence(x, targets = targets, context_ids = ids, position = position, mark = mark))
}
ev_mod <- function(f) { y <- ev0; f(y) }
ev_case("valid", ev0)
ev_case("null", NULL)
ev_case("stale_rounded", ev0, targets = local({ t <- tg0; t[[1L]] <- t[[1L]] + 1; t }))
ev_case("stale_position", ev0, position = pos0 + c(1, 0, 0))
ev_case("stale_price", ev0, mark = mk0 * 1.01)
ev_case("stale_unevidenced", ev_mod(function(y) { for (f in names(y)) y[[f]] <- y[[f]][1:2]; y }))
ev_case("zero_rows", ev_mod(function(y) { for (f in names(y)) y[[f]] <- y[[f]][0]; y }), targets = stats::setNames(pos0, ids))
ev_case("wrong_class", ev_mod(function(y) { class(y) <- "list"; y }))
ev_case("fields_reordered", ev_mod(function(y) y[rev(names(y))]))
ev_case("length_mismatch", ev_mod(function(y) { y$price <- y$price[1:2]; y }))
ev_case("id_na", ev_mod(function(y) { y$instrument_id[[2L]] <- NA_character_; y }))
ev_case("id_empty", ev_mod(function(y) { y$instrument_id[[2L]] <- ""; y }))
ev_case("id_duplicated", ev_mod(function(y) { y$instrument_id[[2L]] <- y$instrument_id[[1L]]; y }))
ev_case("id_outside_axis", ev_mod(function(y) { y$instrument_id[[2L]] <- "ZZZ"; y }))
ev_case("field_not_numeric", ev_mod(function(y) { y$price <- as.character(y$price); y }))
ev_case("reason_na", ev_mod(function(y) { y$reason_code[[1L]] <- NA_character_; y }))
ev_case("reason_unknown", ev_mod(function(y) { y$reason_code[[1L]] <- "made_up"; y }))
ev_case("requested_nan", ev_mod(function(y) { y$requested_quantity[[1L]] <- NaN; y }))
ev_case("rounded_infinite", ev_mod(function(y) { y$rounded_quantity[[1L]] <- Inf; y }))
ev_case("priced_row_without_price", ev_mod(function(y) { y$price[[1L]] <- 0; y }))
ev_case("unavailable_row_valid", ev_mod(function(y) { y$reason_code[[3L]] <- "sizing_unavailable"; y$requested_quantity[[3L]] <- NA;
  y$pre_floor_quantity[[3L]] <- NA; y$price[[3L]] <- NA; y }))
ev_case("unavailable_row_with_price", ev_mod(function(y) { y$reason_code[[3L]] <- "sizing_unavailable"; y$requested_quantity[[3L]] <- NA;
  y$pre_floor_quantity[[3L]] <- NA; y }))
ev_case("unavailable_row_with_quantities", ev_mod(function(y) { y$reason_code[[3L]] <- "sizing_unavailable"; y$price[[3L]] <- NA; y }))

ev_case("atomic_numeric", 1)
ev_case("atomic_character", "bad")
ev_case("atomic_logical", TRUE)
ev_case("zero_length_numeric", numeric())
ev_case("empty_list_classed", structure(list(), class = "ledgr_sizing_evidence"))
ev_case("container_extra_class", ev_mod(function(y) { class(y) <- c("mine", "ledgr_sizing_evidence"); y }))
# a column whose `[` method changes what the pin's subset sees (accepted only by a lean path that skips the subset)
`[.review_quantity` <- function(x, i) NA_real_
ev_one <- structure(list(instrument_id = "AAA", requested_quantity = structure(0, class = "review_quantity"),
  pre_floor_quantity = 0, rounded_quantity = 0, price = NA_real_, position_before = 0, reason_code = "sizing_zero_target"),
  class = "ledgr_sizing_evidence")
ev_case("column_subset_dispatch", ev_one, targets = c(0, 0, 0), position = c(0, 0, 0))
ev_case("column_classed_plain", ev_mod(function(y) { y$price <- structure(y$price, class = "plain_units"); y }))

## DBG: the debug outcome comparator (lean_debug_same) --------------------------
# Lean side: the comparator's outcome as class and message (and IDs when it re-signals);
# expected side: written independently. A refusal differing only in its
# instrument_ids must be detected by the payload comparison.
dbg_refusal <- function(ids, reason = "r") function() rlang::abort("m", class = "ledgr_review_refusal", reason = reason, instrument_ids = ids)
dbg_seen <- function(f) tryCatch({ v <- f(); list(value = v) }, error = function(e) list(class = class(e)[[1L]], message = conditionMessage(e), ids = e$instrument_ids))
dbg_case <- function(id, lean_f, pin_f, expected) case("DBG", id, function() dbg_seen(function() lean$lean_debug_same(lean_f, pin_f, "review", 1L)), function() expected)
dbg_differs <- list(class = "ledgr_internal_error", message = "Lean review differs from the pin's at pulse 1.", ids = NULL)
dbg_case("same_value", function() c(a = 1), function() c(a = 1), list(value = c(a = 1)))
dbg_case("different_value", function() c(a = 1), function() c(a = 2), dbg_differs)
dbg_case("same_refusal", dbg_refusal(c("A", "B")), dbg_refusal(c("A", "B")), list(class = "ledgr_review_refusal", message = "m", ids = c("A", "B")))
dbg_case("refusal_ids_only_differ", dbg_refusal(c("A", "B")), dbg_refusal(c("B", "A")), dbg_differs)
dbg_case("refusal_reason_only_differs", dbg_refusal("A", "r"), dbg_refusal("A", "s"), dbg_differs)
dbg_case("refusal_against_value", dbg_refusal("A"), function() 1, dbg_differs)

## run ---------------------------------------------------------------------------
manifest <- utils::read.csv(file.path(here, "cut18_witness_cases.csv"), stringsAsFactors = FALSE)
ids_grid <- vapply(cases, function(k) paste(k$replacement, k$id, sep = "|"), "")
rows <- list()
for (debug in c(FALSE, TRUE)) {
  lean$.lean_debug <- debug
  for (k in cases) {
    a <- outcome(k$lean); b <- outcome(k$pin)
    rows[[length(rows) + 1L]] <- data.frame(replacement = k$replacement, case = k$id, debug = as.integer(debug),
      outcome = if (is.null(b$error)) "value" else paste0("refusal: ", b$error$class[[1L]]), identical = identical(a, b))
  }
}
res <- do.call(rbind, rows)
utils::write.csv(res, opt("out"), row.names = FALSE)
missing <- setdiff(paste(manifest$replacement, manifest$case, sep = "|"), ids_grid)
extra <- setdiff(ids_grid, paste(manifest$replacement, manifest$case, sep = "|"))
cat(sprintf("%d cases x 2 debug settings, %d differ; manifest missing %d, unlisted %d\n", length(cases), sum(!res$identical),
            length(missing), length(extra)))
if (length(missing)) cat("missing:", missing, "\n")
if (length(extra)) cat("unlisted:", extra, "\n")
if (nzchar(mutation)) {
  caught <- any(!res$identical)
  cat(sprintf("mutation %s: %s\n", mutation, if (caught) "CAUGHT" else "MISSED"))
  quit(status = if (caught && !length(missing) && !length(extra)) 0L else 1L)
}
if (any(!res$identical)) print(res[!res$identical, ], row.names = FALSE)
quit(status = if (all(res$identical) && !length(missing) && !length(extra)) 0L else 1L)
