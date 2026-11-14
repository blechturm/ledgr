# Cut 18 (amendment lean_owned, item (e)): the part split of each package
# check or computation the lean loop calls per pulse, on representative
# slice2 inputs (10 instruments, a real ledgr_target_rebalance() result, the
# slice2 cost chain and max_weight plan). Each row is the median of
# microbenchmark repetitions of a compiled expression on the pinned build;
# parts are timed alone, so they need not sum to the whole. In the running
# loop the same calls cost about twice as much (statement_cost.csv).
#
#   Rscript dev/lean_core/parity/cut18_pkg_split.R --lib=<pinned library> --out=<csv>

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(opt("lib"), winslash = "/")))
ns <- asNamespace("ledgr")
mb <- function(e, times = 20000L) {
  f <- compiler::cmpfun(eval(call("function", as.pairlist(alist()), e), envir = list2env(as.list(globalenv()), parent = ns)))
  stats::median(microbenchmark::microbenchmark(f(), times = times, unit = "ns")$time) / 1e3
}

ids <- sprintf("P%02d", 1:10); n <- 10L
close <- stats::setNames(seq(50, 59), ids); pos <- stats::setNames(c(2000, 1500, rep(0, 8)), ids)
ctx0 <- list(universe = ids, close = close, equity = 1e7, position = pos, holding_value = pos * close,
             buyable = stats::setNames(rep(TRUE, n), ids), member = stats::setNames(rep(TRUE, n), ids))
raw <- ns$ledgr_target_rebalance(ctx0, weights = stats::setNames(rep(0.08, n), ids), invest_fraction = 0.9)
targets <- ns$ledgr_validate_strategy_targets(raw, ids, allow_empty = TRUE)
ev <- attr(raw, "sizing_evidence")
out <- list()
r <- function(fn, part, us) out[[length(out) + 1L]] <<- data.frame(fn = fn, part = part, us = round(us, 2))

## 1. target validator, on a helper's ledgr_target
r("validate_strategy_targets", "WHOLE", mb(quote(ledgr_validate_strategy_targets(raw, ids, allow_empty = TRUE))))
r("validate_strategy_targets", "universe checks (is.character, anyNA, nzchar, anyDuplicated)",
  mb(quote({ !is.character(ids) || anyNA(ids) || any(!nzchar(ids)); anyDuplicated(ids) })))
r("validate_strategy_targets", "unwrap: ledgr_is_strategy_intermediate + inherits + unclass", mb(quote(ledgr_unwrap_strategy_target(raw))))
u <- unclass(raw)
r("validate_strategy_targets", "name checks (names, anyNA, nzchar, anyDuplicated)",
  mb(quote({ tn <- names(u); is.null(tn) || length(tn) != length(u) || anyNA(tn) || any(!nzchar(tn)) || anyDuplicated(tn) })))
r("validate_strategy_targets", "finite check", mb(quote(any(!is.finite(u)))))
r("validate_strategy_targets", "setdiff(universe, names) + setdiff(names, universe)", mb(quote({ setdiff(ids, names(u)); setdiff(names(u), ids) })))
r("validate_strategy_targets", "targets[universe] (name lookup subset)", mb(quote(u[ids])))

## 2. sizing-evidence validator
r("validate_sizing_evidence", "WHOLE", mb(quote(ledgr_validate_sizing_evidence(ev, targets = targets, context_ids = ids, position = pos, mark = close))))
r("validate_sizing_evidence", "shape: inherits, is.list, identical(names)", mb(quote({ f <- c("instrument_id", "requested_quantity", "pre_floor_quantity", "rounded_quantity", "price", "position_before", "reason_code"); inherits(ev, "ledgr_sizing_evidence") && is.list(ev) && identical(names(ev), f) })))
r("validate_sizing_evidence", "lengths, character id checks, anyDuplicated", mb(quote({ m <- length(ev$instrument_id); any(lengths(ev) != m) || !is.character(ev$instrument_id) || anyNA(ev$instrument_id) || any(!nzchar(ev$instrument_id)) || anyDuplicated(ev$instrument_id) })))
r("validate_sizing_evidence", "match ids to axis", mb(quote(match(ev$instrument_id, ids))))
r("validate_sizing_evidence", "numeric columns via vapply(is.numeric)", mb(quote(any(!vapply(ev[c("requested_quantity", "pre_floor_quantity", "rounded_quantity", "price", "position_before")], is.numeric, logical(1))))))
r("validate_sizing_evidence", "reason codes %in% dictionary", mb(quote(!is.character(ev$reason_code) || anyNA(ev$reason_code) || any(!ev$reason_code %in% .ledgr_sizing_reason_codes))))
r("validate_sizing_evidence", "typed-value block (9 finiteness/NA tests)", mb(quote({ x <- ev; unavailable <- x$reason_code == "sizing_unavailable"; priced <- is.finite(x$price) & x$price > 0; needs_price <- x$reason_code %in% c("sizing_rounded", "sizing_rounded_to_zero_addition", "sizing_rounded_to_zero_liquidation"); any(!is.na(x$requested_quantity[unavailable])) || any(!is.na(x$pre_floor_quantity[unavailable])) || any(!is.na(x$price[unavailable])) || any(!is.finite(x$rounded_quantity)) || any(!is.finite(x$position_before)) || any(!is.finite(x$requested_quantity[!unavailable])) || any(!is.finite(x$pre_floor_quantity[!unavailable])) || any(!priced[needs_price]) || any(!is.na(x$price[!unavailable & !priced])) })))
k <- match(ev$instrument_id, ids); priced <- is.finite(ev$price) & ev$price > 0
r("validate_sizing_evidence", "staleness: 4 identical(as.numeric(...)) comparisons", mb(quote({ same_number <- function(a, b) identical(as.numeric(a), as.numeric(b)); une <- rep(TRUE, length(ids)); une[k] <- FALSE; !same_number(ev$rounded_quantity, targets[k]) || !same_number(ev$position_before, pos[k]) || !same_number(ev$price[priced], close[k[priced]]) || !same_number(targets[une], pos[une]) })))
r("validate_sizing_evidence", "a hold pulse: x is NULL", mb(quote(ledgr_validate_sizing_evidence(NULL, targets = targets, context_ids = ids, position = pos, mark = close))))

## 3. risk plan (max_weight) and its checks
plan <- ns$ledgr_risk_plan_compile(ledgr_risk_max_weight(0.05), params = list())
lookup <- list2env(list(availability = list(risk_mark = close)))
ctx <- structure(list(equity = 1e7, close = close, .pulse_lookup = lookup), class = "ledgr_pulse_context")
r("apply_risk_plan", "WHOLE (plain list context, pin $ method)", mb(quote(ledgr_apply_risk_plan(targets, plan, ctx))))
step <- plan$steps[[1L]]
r("apply_risk_plan", "switch dispatch + step call overhead", mb(quote(switch(step$type_id, long_only = 1, max_weight = 2, 3))))
r("apply_risk_plan", "ledgr_risk_validate_max_weight (incl. ledgr_is_param_ref) per pulse", mb(quote(ledgr_risk_validate_max_weight(step$args$max_weight))))
r("apply_risk_plan", "ledgr_risk_context_equity (ctx$equity via $ method + 5 checks)", mb(quote(ledgr_risk_context_equity(ctx))))
r("apply_risk_plan", "ledgr_risk_context_prices (unclass(ctx), lookup, [universe] by names, setNames)", mb(quote(ledgr_risk_context_prices(ctx, names(targets)))))
pr <- ns$ledgr_risk_context_prices(ctx, names(targets))
r("apply_risk_plan", "the cap arithmetic itself", mb(quote({ o <- as.numeric(targets); nz <- abs(o) > sqrt(.Machine$double.eps); m <- (0.05 * 1e7) / pr[nz]; o[nz] <- sign(o[nz]) * pmin(abs(o[nz]), m); stats::setNames(o, names(targets)) })))
risked <- ns$ledgr_apply_risk_plan(targets, plan, ctx)
r("post-risk checks", "ledgr_availability_validate_post_risk", mb(quote(ledgr_availability_validate_post_risk(risked, targets))))
r("post-risk checks", "as.numeric(risked) + short test", mb(quote({ tq <- as.numeric(risked); any(tq < 0 & tq < pos) })))

## 4. cost resolver
res <- ns$ledgr_cost_resolver_from_model(ledgr_cost_chain(ledgr_cost_spread_bps(10), ledgr_cost_fixed_fee(1), ledgr_cost_notional_bps_fee(5)))
side <- c(1L, 1L, -1L, 1L, -1L, 1L); qty <- c(100, 200, 50, 80, 30, 60); open <- c(51, 52, 53, 54, 55, 56)
r("cost resolver", "WHOLE ledgr_plan_resolve (wrapper + resolver + shape check)", mb(quote(ledgr_plan_resolve(res, side, qty, open))))
r("cost resolver", "resolver closure -> ledgr_cost_model_resolve", mb(quote(res(side, qty, open))))
st <- environment(res)$steps
r("cost resolver", "the step arithmetic alone (3 steps, rounding)", mb(quote({ p <- open; fee <- numeric(6); p <- p * ifelse(side > 0, 1 + 10/20000, 1 - 10/20000); fee <- fee + 1; fee <- fee + abs(qty * p) * 5/10000; list(price = round(p, 8L), fee = fee) })))
r("cost resolver", "per-step identical(type_id) tests + as.numeric(args) (3 steps)", mb(quote(for (s in st) { identical(s$type_id, "spread_bps"); identical(s$type_id, "fixed_fee"); identical(s$type_id, "notional_bps_fee"); as.numeric(s$args[[1L]]) })))

## 5. declared-state field validator
fld <- list(name = "k", scope = "portfolio", type = "integer")
r("state field validator", "WHOLE ledgr_strategy_state_validate_value(1L)", mb(quote(ledgr_strategy_state_validate_value(1L, fld, ids))))
afld <- list(name = "above", scope = "asset", type = "logical"); av <- stats::setNames(rep(TRUE, n), ids)
r("state field validator", "WHOLE, asset field (crossover)", mb(quote(ledgr_strategy_state_validate_value(av, afld, ids))))

x <- do.call(rbind, out)
utils::write.csv(x, opt("out"), row.names = FALSE)
options(width = 200); print(x, row.names = FALSE)
