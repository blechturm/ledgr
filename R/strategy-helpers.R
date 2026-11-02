ledgr_validate_strategy_helper_ctx <- function(ctx, helper) {
  if (!is.list(ctx) && !is.environment(ctx)) {
    rlang::abort(sprintf("`ctx` must be a ledgr strategy context for `%s()`.", helper), class = "ledgr_invalid_strategy_helper")
  }
  universe <- ctx$universe
  if (!is.character(universe) ||
      anyNA(universe) || any(!nzchar(universe)) || anyDuplicated(universe)) {
    rlang::abort(sprintf("`ctx$universe` must be a unique character vector for `%s()`.", helper), class = "ledgr_invalid_strategy_helper")
  }
  universe
}

ledgr_strategy_helper_validate_lookback <- function(lookback) {
  if (!is.numeric(lookback) || length(lookback) != 1L || is.na(lookback) || !is.finite(lookback) || lookback < 1L || lookback != as.integer(lookback)) {
    rlang::abort("`lookback` must be a positive integer scalar.", class = "ledgr_invalid_strategy_helper")
  }
  as.integer(lookback)
}

ledgr_strategy_helper_validate_invest_fraction <- function(invest_fraction) {
  if (!is.numeric(invest_fraction) || length(invest_fraction) != 1L || is.na(invest_fraction) || !is.finite(invest_fraction) || invest_fraction < 0 || invest_fraction > 1) {
    rlang::abort("`invest_fraction` must be a finite numeric scalar between 0 and 1.", class = "ledgr_invalid_strategy_helper")
  }
  as.numeric(invest_fraction)
}

ledgr_strategy_helper_context_equity <- function(ctx) {
  equity <- ctx$equity
  if (!is.numeric(equity) || length(equity) != 1L || is.na(equity) || !is.finite(equity) || equity < 0) {
    rlang::abort("`ctx$equity` must be a finite non-negative numeric scalar.", class = "ledgr_invalid_strategy_helper")
  }
  as.numeric(equity)
}

ledgr_signal_values <- function(ctx, feature_id, universe) {
  values <- if (length(universe) == 0L) numeric() else as.numeric(ctx[[feature_id]])
  signal <- ledgr_signal(stats::setNames(values, universe), universe = universe, origin = feature_id)
  attr(signal, "eligible") <- ledgr_strategy_eligible(ctx, universe)
  signal
}

#' Build a return signal from registered return features
#'
#' `ledgr_signal_return()` reads the `return_<lookback>` feature for every instrument
#' in `ctx$universe` and returns a `ledgr_signal`. The required indicator must
#' already be registered on the experiment, for example with
#' `features = list(ledgr_ind_returns(20))`; this helper never auto-registers
#' indicators. It returns raw scores over the whole decision axis and marks
#' eligibility in the `eligible` attribute.
#'
#' For a fixed concrete lookback, register the matching return indicator. For
#' a parameterized sweep, put `ledgr_ind_returns(ledgr_param("lookback"))` in a
#' feature map and read its stable active alias directly from the flat context.
#'
#' @param ctx ledgr strategy context.
#' @param lookback Positive integer return lookback.
#' @return A `ledgr_signal` object.
#' @examples
#' ctx <- list(
#'   universe = c("AAA", "BBB"),
#'   return_5 = c(AAA = 0.03, BBB = NA_real_),
#'   buyable = c(AAA = TRUE, BBB = TRUE)
#' )
#' ledgr_signal_return(ctx, lookback = 5)
#'
#' @seealso [ledgr_signal()]
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_signal_return <- function(ctx, lookback = 20L) {
  universe <- ledgr_validate_strategy_helper_ctx(ctx, "ledgr_signal_return")
  lookback <- ledgr_strategy_helper_validate_lookback(lookback)
  feature_id <- sprintf("return_%d", lookback)
  ledgr_signal_values(ctx, feature_id, universe)
}

#' Select instruments by ranked score
#'
#' These helpers rank an ordinary named numeric score vector. Missing scores
#' and unknown logical pool decisions are excluded. Ties use instrument-ID byte
#' order, independently of the process locale. Supply exactly one of `n` or
#' `fraction`; a fraction selects the floored share of the candidate pool, with
#' a minimum of one from a non-empty pool.
#'
#' @param score Named numeric scores.
#' @param n Non-negative whole number of instruments to request.
#' @param fraction Fraction in `(0, 1]` of the candidate pool to request.
#' @param within Candidate IDs or a logical vector aligned by name or exact
#'   position. `NULL` uses the whole score axis.
#' @return A plain character vector of instrument IDs.
#' @examples
#' score <- c(AAA = 0.03, BBB = NA_real_, CCC = 0.01)
#' ledgr_select_top(score, n = 1)
#' ledgr_select_lowest(score, fraction = 0.5)
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_select_top <- function(score, n = NULL, fraction = NULL, within = NULL) {
  ledgr_select_ranked(score, n, fraction, within, decreasing = TRUE)
}

#' @rdname ledgr_select_top
#' @export
ledgr_select_lowest <- function(score, n = NULL, fraction = NULL, within = NULL) {
  ledgr_select_ranked(score, n, fraction, within, decreasing = FALSE)
}

ledgr_select_ranked <- function(score, n, fraction, within, decreasing) {
  if (!is.numeric(score) || is.factor(score)) {
    rlang::abort("`score` must be a named numeric vector.", class = "ledgr_invalid_strategy_type")
  }
  ids <- names(score)
  if (is.null(ids) || length(ids) != length(score) || anyNA(ids) ||
      any(!nzchar(ids)) || anyDuplicated(ids)) {
    rlang::abort(
      "`score` must have unique, non-missing instrument names.",
      class = "ledgr_invalid_strategy_type"
    )
  }
  if (sum(!vapply(list(n, fraction), is.null, logical(1))) != 1L) {
    rlang::abort(
      "Supply exactly one of `n` or `fraction`.",
      class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
    )
  }
  pool <- ledgr_select_pool(within, ids)
  requested <- if (!is.null(n)) {
    if (!is.numeric(n) || length(n) != 1L || is.na(n) || !is.finite(n) ||
        n < 0 || n != floor(n) || n > .Machine$integer.max) {
      rlang::abort(
        "`n` must be one non-negative whole number.",
        class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
      )
    }
    as.integer(n)
  } else {
    if (!is.numeric(fraction) || length(fraction) != 1L || is.na(fraction) ||
        !is.finite(fraction) || fraction <= 0 || fraction > 1) {
      rlang::abort(
        "`fraction` must be one finite number in (0, 1].",
        class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
      )
    }
    if (length(pool) == 0L) 0L else max(1L, floor(length(pool) * fraction))
  }
  if (requested == 0L || length(pool) == 0L) return(character())
  index <- match(pool, ids)
  usable <- index[!is.na(score[index])]
  if (length(usable) == 0L) return(character())
  primary <- if (decreasing) -as.numeric(score[usable]) else as.numeric(score[usable])
  ranked <- usable[order(primary, ids[usable], method = "radix")]
  ids[ranked[seq_len(min(requested, length(ranked)))]]
}

ledgr_select_pool <- function(within, ids) {
  if (is.null(within)) return(ids)
  if (is.character(within) && !is.factor(within)) {
    if (anyNA(within) || any(!nzchar(within)) || anyDuplicated(within)) {
      rlang::abort(
        "Character `within` must contain unique, non-missing instrument IDs.",
        class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
      )
    }
    unknown <- setdiff(within, ids)
    if (length(unknown) > 0L) {
      rlang::abort(
        sprintf("`within` names instruments outside `score`: %s.", paste(unknown, collapse = ", ")),
        class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
      )
    }
    return(within)
  }
  if (!is.logical(within)) {
    rlang::abort(
      "`within` must be instrument IDs or a logical vector.",
      class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
    )
  }
  within_names <- names(within)
  if (is.null(within_names)) {
    if (length(within) != length(ids)) {
      rlang::abort(
        "Unnamed logical `within` must have one value per score.",
        class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
      )
    }
    return(ids[!is.na(within) & within])
  }
  if (length(within_names) != length(within) || anyNA(within_names) ||
      any(!nzchar(within_names)) || anyDuplicated(within_names) ||
      !setequal(within_names, ids)) {
    rlang::abort(
      "Named logical `within` must cover the score axis exactly once.",
      class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
    )
  }
  aligned <- within[match(ids, within_names)]
  ids[!is.na(aligned) & aligned]
}

#' Convert a selection to equal long-only weights
#'
#' `ledgr_weight_equal()` assigns equal non-negative weights to an ordinary
#' character selection. Empty selections produce a plain named `numeric(0)`.
#'
#' @param selection Unique instrument IDs.
#' @param each Optional finite non-negative weight assigned to every selected
#'   instrument. Without it, the selected instruments share weight one.
#' @return A plain named double vector.
#' @examples
#' selection <- c("AAA", "BBB")
#' ledgr_weight_equal(selection)
#' ledgr_weight_equal(selection, each = 0.2)
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_weight_equal <- function(selection, each = NULL) {
  if (!is.character(selection) || is.factor(selection) || anyNA(selection) ||
      any(!nzchar(selection)) || anyDuplicated(selection)) {
    rlang::abort(
      "`selection` must be a unique character vector of instrument IDs.",
      class = "ledgr_invalid_strategy_type"
    )
  }
  if (length(selection) == 0L) return(stats::setNames(numeric(), character()))
  if (is.null(each)) {
    each <- 1 / length(selection)
  } else if (!is.numeric(each) || length(each) != 1L || is.na(each) ||
             !is.finite(each) || each < 0) {
    rlang::abort(
      "`each` must be one finite non-negative number.",
      class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
    )
  }
  weights <- stats::setNames(rep(as.numeric(each), length(selection)), selection)
  if (sum(weights) > 1 + sqrt(.Machine$double.eps)) {
    rlang::abort(
      "Equal weights must sum to at most one.",
      class = "ledgr_invalid_strategy_type"
    )
  }
  weights
}

#' Size a full-axis portfolio target
#'
#' `ledgr_target_rebalance()` replaces the decided eligible allocation.
#' `ledgr_target_adjust()` changes only the named positions. Both use the same
#' sizing engine and return a complete `ledgr_target` over `ctx$universe`.
#'
#' ledgr reserves the absolute marked exposure of every preserved position
#' exactly once before sizing weighted requests. In availability-aware runs,
#' this includes ineligible holdings, held nonmembers and target-restricted
#' members; weights may name buyable instruments only. IDs named by a character
#' `keep` are also preserved. `invest_fraction` applies to the chosen capital
#' base; with `capital_base = "remaining_equity"`, that base is equity after
#' preserved and added exposure has been reserved.
#' Share quantities are floored to whole numbers with
#' `floor(weight * invest_fraction * allocation_equity / close_price)`. An
#' exact zero member weight targets zero without consulting that instrument's
#' sizing close.
#'
#' In an availability-aware run, an eligible member with a positive weight but
#' no positive current close is skipped for that rebalance: it keeps its
#' current quantity (zero if not held) and its weight is not redistributed.
#' Priced members keep their fully priced size, unless the skipped members'
#' held exposure at their risk marks plus the priced value would exceed
#' allocatable equity; then the priced quantities are scaled down, before
#' flooring, by `max(0, allocatable - held_exposure) / priced_value`. Each skip
#' is recorded as a `sizing_unavailable` decision row in
#' `ledgr_results(bt, "diagnostics")`.
#' The same typed diagnostic rows preserve requested, pre-floor and rounded
#' quantities for committed runs. `summary(bt)` and `print(bt)` report their
#' exposure-weighted coverage separately from final actual exposure. Raw named
#' quantity strategies have no helper sizing evidence and report that coverage
#' as unavailable; ledgr does not infer it from fills.
#'
#' Warning and error classes:
#' - `ledgr_target_sizing_unavailable` when an availability-aware rebalance
#'   must keep a held member, or reserve a preserved holding, that has no
#'   permissible valuation mark.
#'
#' @param ctx ledgr strategy context.
#' @param weights Optional ordinary named finite non-negative weights summing
#'   to at most one.
#' @param invest_fraction Fraction of the chosen capital base to invest.
#' @param capital_base Optional allocation base: `"total_equity"` or
#'   `"remaining_equity"`. Weighted rebalance requires a choice when preserved
#'   or added exposure makes the bases differ; weighted adjust defaults to
#'   `"total_equity"`.
#' @param keep Current decision-axis positions to preserve. Kept IDs must not
#'   also appear in `weights`, even at zero weight. A character keep decides
#'   named leavers first; `index_leavers` then decides all other held leavers;
#'   a logical keep has lowest precedence and cannot override a leaver sale.
#' @param index_leavers Required policy for held instruments outside current
#'   membership that are not named by a character `keep`: `"sell"` or
#'   `"keep"`. There is no implicit leaver policy.
#' @return A full-universe `ledgr_target` object.
#' @examples
#' weights <- c(AAA = 0.5, BBB = 0.5)
#' ctx <- list(
#'   universe = c("AAA", "BBB"),
#'   equity = 1000,
#'   close = c(AAA = 50, BBB = 100),
#'   member = c(AAA = TRUE, BBB = TRUE),
#'   buyable = c(AAA = TRUE, BBB = TRUE),
#'   position = c(AAA = 0, BBB = 0),
#'   holding_value = c(AAA = 0, BBB = 0)
#' )
#' ledgr_target_rebalance(ctx, weights = weights, invest_fraction = 0.5)
#'
#' ctx$position <- c(AAA = 2, BBB = 0)
#' weights <- c(BBB = 1)
#' ledgr_target_rebalance(ctx, weights = weights, keep = "AAA")
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_target_rebalance <- function(ctx,
                                   weights = NULL,
                                   keep = NULL,
                                   index_leavers = NULL,
                                   invest_fraction = 1,
                                   capital_base = NULL) {
  ledgr_target_size(
    ctx = ctx,
    verb = "rebalance",
    weights = weights,
    keep = keep,
    index_leavers = index_leavers,
    invest_fraction = invest_fraction,
    capital_base = capital_base
  )
}

#' Adjust named positions without replacing the rest of the portfolio
#'
#' `ledgr_target_adjust()` keeps every unmentioned position at its current
#' quantity. Named weights replace exposure for those IDs, `add_value` adds
#' decision-value exposure, and `exit` closes the selected positions.
#'
#' @inheritParams ledgr_target_rebalance
#' @param add_value Optional named finite non-negative currency exposure to add.
#' @param exit Optional logical mask over the decision axis.
#' @return A full-universe `ledgr_target` object.
#' @examples
#' ctx <- list(
#'   universe = c("AAA", "BBB"), equity = 1000,
#'   close = c(AAA = 50, BBB = 100),
#'   member = c(AAA = TRUE, BBB = TRUE),
#'   buyable = c(AAA = TRUE, BBB = TRUE),
#'   position = c(AAA = 2, BBB = 0),
#'   holding_value = c(AAA = 100, BBB = 0)
#' )
#' ledgr_target_adjust(ctx, add_value = c(BBB = 200))
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_target_adjust <- function(ctx,
                                weights = NULL,
                                add_value = NULL,
                                exit = NULL,
                                invest_fraction = 1,
                                capital_base = NULL) {
  ledgr_target_size(
    ctx = ctx,
    verb = "adjust",
    weights = weights,
    add_value = add_value,
    exit = exit,
    invest_fraction = invest_fraction,
    capital_base = capital_base
  )
}

ledgr_target_size <- function(ctx,
                              verb,
                              weights = NULL,
                              keep = NULL,
                              index_leavers = NULL,
                              add_value = NULL,
                              exit = NULL,
                              invest_fraction = 1,
                              capital_base = NULL) {
  universe <- ledgr_validate_strategy_helper_ctx(ctx, paste0("ledgr_target_", verb))
  equity <- ledgr_strategy_helper_context_equity(ctx)
  invest_fraction <- ledgr_strategy_helper_validate_invest_fraction(invest_fraction)
  weights <- ledgr_target_named_amount(weights, "weights", universe, allow_null = TRUE)
  add_value <- ledgr_target_named_amount(add_value, "add_value", universe, allow_null = TRUE)
  if (sum(weights) > 1 + sqrt(.Machine$double.eps)) {
    rlang::abort("`weights` must sum to at most one.", class = "ledgr_invalid_strategy_type")
  }
  buyable <- ledgr_strategy_eligible(ctx, universe)
  member <- as.logical(ctx$member)
  if (length(member) != length(universe) || anyNA(member)) {
    rlang::abort("`ctx$member` must cover the decision axis.", class = "ledgr_invalid_strategy_helper")
  }
  position <- as.numeric(ctx$position)
  if (length(position) != length(universe) || any(!is.finite(position))) {
    rlang::abort("`ctx$position` must provide one finite value per decision-axis instrument.", class = "ledgr_invalid_strategy_helper")
  }
  names(position) <- universe
  holding_value <- as.numeric(ctx$holding_value)
  if (length(holding_value) != length(universe)) {
    rlang::abort("`ctx$holding_value` must cover the decision axis.", class = "ledgr_invalid_strategy_helper")
  }
  names(holding_value) <- universe
  close <- as.numeric(ctx$close)
  if (length(close) != length(universe)) {
    rlang::abort("`ctx$close` must cover the decision axis.", class = "ledgr_invalid_strategy_helper")
  }
  names(close) <- universe

  # The sizing helper carries typed, per-instrument evidence to the fold. The
  # public target remains the ordinary complete quantity vector; these
  # columns are consumed once at the strategy-return boundary and never
  # encoded as JSON in the pulse loop.
  sizing_requested <- rep(NA_real_, length(universe))
  sizing_pre_floor <- rep(NA_real_, length(universe))
  sizing_price <- rep(NA_real_, length(universe))
  sizing_reason <- rep("", length(universe))
  sizing_used <- rep(FALSE, length(universe))

  weighted_ids <- names(weights)
  addition_ids <- names(add_value)
  requested_ids <- union(weighted_ids, addition_ids)
  ineligible <- requested_ids[!buyable[match(requested_ids, universe)]]
  if (length(ineligible) > 0L) {
    rlang::abort(
      sprintf("Sizing requests name instruments that are not buyable: %s.", paste(ineligible, collapse = ", ")),
      class = "ledgr_invalid_strategy_helper"
    )
  }
  if (length(intersect(weighted_ids, addition_ids)) > 0L) {
    rlang::abort("An instrument cannot be both weighted and added.", class = "ledgr_invalid_strategy_result")
  }

  target <- position
  preserve <- rep(TRUE, length(universe))
  explicit_keep <- character()
  logical_keep <- rep(FALSE, length(universe))
  exits <- rep(FALSE, length(universe))

  if (identical(verb, "rebalance")) {
    parsed_keep <- ledgr_target_keep(keep, universe)
    explicit_keep <- parsed_keep$ids
    logical_keep <- parsed_keep$mask
    if (!is.null(index_leavers) &&
        (!is.character(index_leavers) || length(index_leavers) != 1L ||
         is.na(index_leavers) || !index_leavers %in% c("sell", "keep"))) {
      rlang::abort(
        "`index_leavers` must be NULL, \"sell\", or \"keep\".",
        class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
      )
    }
    held_leavers <- universe[position != 0 & !member]
    undecided <- setdiff(held_leavers, explicit_keep)
    if (length(undecided) > 0L && is.null(index_leavers)) {
      rlang::abort(
        sprintf(
          paste0("Held index leavers need an explicit decision: %s. Name exceptions in `keep`, ",
                 "or set `index_leavers = \"sell\"` or `\"keep\"`."),
          paste(undecided, collapse = ", ")
        ),
        class = "ledgr_invalid_strategy_result"
      )
    }
    if (identical(index_leavers, "sell") && length(undecided) > 0L) {
      target[undecided] <- 0
      leaver_pos <- match(undecided, universe)
      preserve[leaver_pos] <- FALSE
      sizing_used[leaver_pos] <- TRUE
      sizing_requested[leaver_pos] <- 0
      sizing_pre_floor[leaver_pos] <- 0
      sizing_price[leaver_pos] <- close[undecided]
      sizing_reason[leaver_pos] <- "sizing_liquidation"
    }
    replaceable <- buyable & !logical_keep & !universe %in% explicit_keep
    target[replaceable] <- 0
    preserve[replaceable] <- FALSE
    liquidated <- replaceable & position != 0
    sizing_used[liquidated] <- TRUE
    sizing_requested[liquidated] <- 0
    sizing_pre_floor[liquidated] <- 0
    sizing_price[liquidated] <- close[liquidated]
    sizing_reason[liquidated] <- "sizing_liquidation"
    keep_ids <- union(explicit_keep, universe[logical_keep & (member | !identical(index_leavers, "sell"))])
    target[keep_ids] <- position[keep_ids]
    preserve[match(keep_ids, universe)] <- TRUE
    overlap <- intersect(weighted_ids, keep_ids)
    if (length(overlap) > 0L) {
      rlang::abort(
        sprintf("Instruments cannot be both weighted and kept: %s.", paste(overlap, collapse = ", ")),
        class = "ledgr_invalid_strategy_result"
      )
    }
  } else {
    if (!is.null(keep) || !is.null(index_leavers)) {
      rlang::abort("`keep` and `index_leavers` belong to `ledgr_target_rebalance()`.", class = "ledgr_invalid_strategy_helper")
    }
    exits <- ledgr_target_logical(exit, universe, "exit")
    conflict <- union(intersect(weighted_ids, universe[exits]), intersect(addition_ids, universe[exits]))
    if (length(conflict) > 0L) {
      rlang::abort(
        sprintf("Instruments cannot be both sized and exited: %s.", paste(conflict, collapse = ", ")),
        class = "ledgr_invalid_strategy_result"
      )
    }
    target[exits] <- 0
    preserve[exits] <- FALSE
    sizing_used[exits] <- TRUE
    sizing_requested[exits] <- 0
    sizing_pre_floor[exits] <- 0
    sizing_price[exits] <- close[exits]
    sizing_reason[exits] <- "sizing_liquidation"
  }

  preserved_ids <- universe[preserve & position != 0 & !universe %in% weighted_ids]
  # Existing quantities in addition IDs are preserved and therefore reserve
  # their marked exposure; the requested additions themselves enter A once.
  preserved_values <- holding_value[match(preserved_ids, universe)]
  if (any(!is.finite(preserved_values))) {
    bad <- preserved_ids[which(!is.finite(preserved_values))[[1L]]]
    ledgr_target_sizing_abort(sprintf("Cannot preserve `%s` without a permissible valuation mark.", bad), bad)
  }
  reserved <- sum(abs(preserved_values))
  additions <- sum(add_value)
  if (!is.finite(reserved) || !is.finite(additions)) {
    rlang::abort(
      "Preserved and added exposure must have finite totals.",
      class = "ledgr_invalid_strategy_type"
    )
  }
  positive_weights <- weights > 0
  needs_base <- any(positive_weights)
  bases_differ <- reserved + additions > 0
  base_origin <- "not_required"
  if (needs_base) {
    if (is.null(capital_base)) {
      if (identical(verb, "rebalance") && bases_differ) {
        rlang::abort(
          "Choose `capital_base = \"total_equity\"` or `\"remaining_equity\"` because preserved or added exposure makes them differ.",
          class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
        )
      }
      capital_base <- "total_equity"
      base_origin <- "default"
    } else {
      base_origin <- "supplied"
    }
  }
  if (!is.null(capital_base) &&
      (!is.character(capital_base) || length(capital_base) != 1L ||
       is.na(capital_base) || !capital_base %in% c("total_equity", "remaining_equity"))) {
    rlang::abort(
      "`capital_base` must be NULL, \"total_equity\", or \"remaining_equity\".",
      class = c("ledgr_invalid_strategy_helper", "ledgr_invalid_args")
    )
  }
  base <- if (identical(capital_base, "remaining_equity")) {
    max(0, equity - reserved - additions)
  } else {
    equity
  }

  skipped <- character()
  if (length(weighted_ids) > 0L) {
    zero <- weights == 0
    if (any(zero)) {
      zero_ids <- weighted_ids[zero]
      zero_pos <- match(zero_ids, universe)
      target[zero_ids] <- 0
      sizing_used[zero_pos] <- TRUE
      sizing_requested[zero_pos] <- 0
      sizing_pre_floor[zero_pos] <- 0
      sizing_price[zero_pos] <- close[zero_ids]
      sizing_reason[zero_pos] <- ifelse(
        position[zero_ids] != 0,
        "sizing_liquidation",
        "sizing_zero_target"
      )
    }
    positive_ids <- weighted_ids[positive_weights]
    if (length(positive_ids) > 0L) {
      price <- close[positive_ids]
      valid <- is.finite(price) & price > 0
      skipped_weight <- positive_ids[!valid]
      if (length(skipped_weight) > 0L) {
        target[skipped_weight] <- position[skipped_weight]
        skipped <- union(skipped, skipped_weight)
        skipped_pos <- match(skipped_weight, universe)
        sizing_used[skipped_pos] <- TRUE
        sizing_requested[skipped_pos] <- NA_real_
        sizing_pre_floor[skipped_pos] <- NA_real_
        sizing_price[skipped_pos] <- NA_real_
        sizing_reason[skipped_pos] <- "sizing_unavailable"
      }
      requested_value <- weights[positive_ids[valid]] * invest_fraction * base
      skipped_held <- skipped_weight[position[skipped_weight] != 0]
      unavailable_value <- if (length(skipped_held) == 0L) 0 else {
        value <- holding_value[skipped_held]
        if (any(!is.finite(value))) {
          bad <- skipped_held[which(!is.finite(value))[[1L]]]
          ledgr_target_sizing_abort(sprintf("Cannot keep skipped `%s` without a permissible valuation mark.", bad), bad)
        }
        total <- sum(abs(value))
        if (!is.finite(total)) {
          ledgr_target_sizing_abort("Skipped marked exposure must have a finite total.")
        }
        total
      }
      scale <- 1
      priced_value <- sum(requested_value)
      if (priced_value > 0 && priced_value + unavailable_value > base) {
        scale <- max(0, base - unavailable_value) / priced_value
      }
      if (length(requested_value) > 0L) {
        valid_ids <- positive_ids[valid]
        valid_pos <- match(valid_ids, universe)
        requested_quantity <- requested_value / price[valid]
        pre_floor_quantity <- requested_value * scale / price[valid]
        target[valid_ids] <- floor(pre_floor_quantity)
        sizing_used[valid_pos] <- TRUE
        sizing_requested[valid_pos] <- requested_quantity
        sizing_pre_floor[valid_pos] <- pre_floor_quantity
        sizing_price[valid_pos] <- price[valid]
        sizing_reason[valid_pos] <- "sizing_rounded"
        rounded_zero <- target[valid_ids] == 0 & pre_floor_quantity > 0
        if (any(rounded_zero)) {
          rounded_zero_pos <- valid_pos[rounded_zero]
          sizing_reason[rounded_zero_pos] <- ifelse(
            position[valid_ids[rounded_zero]] != 0,
            "sizing_rounded_to_zero_liquidation",
            "sizing_rounded_to_zero_addition"
          )
        }
      }
    }
  }
  if (length(addition_ids) > 0L) {
    price <- close[addition_ids]
    valid <- is.finite(price) & price > 0
    if (any(valid)) {
      valid_ids <- addition_ids[valid]
      valid_pos <- match(valid_ids, universe)
      requested_quantity <- position[valid_ids] + add_value[valid] / price[valid]
      target[valid_ids] <- position[valid_ids] + floor(add_value[valid] / price[valid])
      sizing_used[valid_pos] <- TRUE
      sizing_requested[valid_pos] <- requested_quantity
      sizing_pre_floor[valid_pos] <- requested_quantity
      sizing_price[valid_pos] <- price[valid]
      sizing_reason[valid_pos] <- "sizing_rounded"
      rounded_zero <- target[valid_ids] == 0 & requested_quantity > 0
      if (any(rounded_zero)) {
        rounded_zero_pos <- valid_pos[rounded_zero]
        sizing_reason[rounded_zero_pos] <- ifelse(
          position[valid_ids[rounded_zero]] != 0,
          "sizing_rounded_to_zero_liquidation",
          "sizing_rounded_to_zero_addition"
        )
      }
    }
    if (any(!valid)) {
      skipped_ids <- addition_ids[!valid]
      skipped_pos <- match(skipped_ids, universe)
      target[skipped_ids] <- position[skipped_ids]
      skipped <- union(skipped, skipped_ids)
      sizing_used[skipped_pos] <- TRUE
      sizing_requested[skipped_pos] <- NA_real_
      sizing_pre_floor[skipped_pos] <- NA_real_
      sizing_price[skipped_pos] <- NA_real_
      sizing_reason[skipped_pos] <- "sizing_unavailable"
    }
  }

  notes <- unclass(ctx)[[".notes"]]
  if (is.environment(notes) && length(skipped) > 0L) {
    notes$sizing_skipped <- union(notes$sizing_skipped %||% character(), skipped)
  }
  out <- ledgr_target(target, universe = universe, origin = paste0("ledgr_target_", verb))
  attr(out, "origin") <- list(
    helper = paste0("ledgr_target_", verb),
    capital_base = capital_base %||% "not_required",
    capital_base_origin = base_origin,
    invest_fraction = invest_fraction
  )
  attr(out, "sizing") <- list(
    equity = equity,
    preserved_value = reserved,
    addition_value = additions,
    capital_base_value = base,
    unavailable_ids = skipped
  )
  if (length(skipped) > 0L) attr(out, "sizing_skipped") <- skipped
  attr(out, "sizing_evidence") <- structure(
    list(
      instrument_id = universe[sizing_used],
      requested_quantity = sizing_requested[sizing_used],
      pre_floor_quantity = sizing_pre_floor[sizing_used],
      rounded_quantity = as.numeric(target[sizing_used]),
      price = sizing_price[sizing_used],
      position_before = as.numeric(position[sizing_used]),
      reason_code = sizing_reason[sizing_used]
    ),
    class = "ledgr_sizing_evidence"
  )
  out
}

ledgr_target_named_amount <- function(x, label, universe, allow_null = FALSE) {
  if (is.null(x) && allow_null) return(stats::setNames(numeric(), character()))
  if (!is.numeric(x) || is.factor(x) || !is.null(dim(x))) {
    rlang::abort(sprintf("`%s` must be a named numeric vector.", label), class = "ledgr_invalid_strategy_type")
  }
  x_names <- names(x)
  if (is.null(x_names) || length(x_names) != length(x) || anyNA(x_names) ||
      any(!nzchar(x_names)) || anyDuplicated(x_names) || any(!is.finite(x)) || any(x < 0)) {
    rlang::abort(
      sprintf("`%s` must contain finite non-negative values with unique instrument names.", label),
      class = "ledgr_invalid_strategy_type"
    )
  }
  unknown <- setdiff(x_names, universe)
  if (length(unknown) > 0L) {
    rlang::abort(
      sprintf("`%s` names instruments outside the decision axis: %s.", label, paste(unknown, collapse = ", ")),
      class = "ledgr_invalid_strategy_type"
    )
  }
  stats::setNames(as.numeric(x), x_names)
}

ledgr_target_logical <- function(x, universe, label) {
  if (is.null(x)) return(stats::setNames(rep(FALSE, length(universe)), universe))
  if (!is.logical(x) || is.factor(x) || anyNA(x)) {
    rlang::abort(sprintf("`%s` must be a non-missing logical vector.", label), class = "ledgr_invalid_strategy_type")
  }
  x_names <- names(x)
  if (is.null(x_names)) {
    if (length(x) != length(universe)) {
      rlang::abort(sprintf("Unnamed `%s` must cover the decision axis.", label), class = "ledgr_invalid_strategy_type")
    }
    return(stats::setNames(x, universe))
  }
  if (length(x_names) != length(x) || anyNA(x_names) || any(!nzchar(x_names)) ||
      anyDuplicated(x_names) || !setequal(x_names, universe)) {
    rlang::abort(sprintf("Named `%s` must cover the decision axis exactly once.", label), class = "ledgr_invalid_strategy_type")
  }
  stats::setNames(as.logical(x[match(universe, x_names)]), universe)
}

ledgr_target_keep <- function(keep, universe) {
  if (is.null(keep)) return(list(ids = character(), mask = rep(FALSE, length(universe))))
  if (is.character(keep) && !is.factor(keep)) {
    if (anyNA(keep) || any(!nzchar(keep)) || anyDuplicated(keep)) {
      rlang::abort("Character `keep` must contain unique instrument IDs.", class = "ledgr_invalid_strategy_type")
    }
    unknown <- setdiff(keep, universe)
    if (length(unknown) > 0L) {
      rlang::abort(sprintf("`keep` names instruments outside the decision axis: %s.", paste(unknown, collapse = ", ")), class = "ledgr_invalid_strategy_type")
    }
    return(list(ids = keep, mask = rep(FALSE, length(universe))))
  }
  list(ids = character(), mask = as.logical(ledgr_target_logical(keep, universe, "keep")))
}

ledgr_target_sizing_abort <- function(message, instrument_id = NULL) {
  rlang::abort(
    message,
    class = c("ledgr_target_sizing_unavailable", "ledgr_invalid_strategy_helper"),
    instrument_id = instrument_id
  )
}

#' Construct full target quantities from a selection
#'
#' `ledgr_target_quantity()` converts a selection into a full-universe
#' `ledgr_target` that holds the same fixed quantity of every selected
#' instrument. Selected eligible instruments get `qty`; every other eligible
#' instrument gets zero. Use it for rules such as "hold 10 shares of each instrument that
#' passes the condition"; use [ledgr_weight_equal()] and
#' [ledgr_target_rebalance()] instead when positions should be sized from
#' account equity.
#'
#' Missing decisions are settled by the selection, not here: build the
#' selection with `ledgr_selection(ctx, where = ..., missing = "exclude")` when
#' a missing value, such as a feature still in warmup, should mean "not
#' selected".
#'
#' In an availability-aware run, every ineligible instrument, a held nonmember
#' or a target-restricted member, keeps its current quantity, exactly as
#' [ledgr_target_rebalance()] preserves it. The selection may name any instrument
#' on the decision axis, but may select eligible instruments only.
#'
#' Error class: `ledgr_invalid_strategy_helper` when `selection` is not a
#' `ledgr_selection`, names an instrument outside the decision axis, selects
#' an ineligible instrument, or
#' when `qty` is not one finite, non-negative number. Negative quantities stay
#' refused until short-selling semantics are defined.
#'
#' @param selection A `ledgr_selection` object.
#' @param ctx ledgr strategy context.
#' @param qty One finite, non-negative target quantity for each selected
#'   instrument.
#' @return A full-universe `ledgr_target` object.
#' @examples
#' selection <- ledgr_selection(c(AAA = TRUE, BBB = FALSE),
#'                              universe = c("AAA", "BBB"))
#' ctx <- list(
#'   universe = c("AAA", "BBB"),
#'   buyable = c(TRUE, TRUE),
#'   position = c(AAA = 0, BBB = 0)
#' )
#' ledgr_target_quantity(selection, ctx, qty = 10)
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
ledgr_target_quantity <- function(selection, ctx, qty) {
  if (!inherits(selection, "ledgr_selection")) {
    rlang::abort("`selection` must be a ledgr_selection object.", class = "ledgr_invalid_strategy_helper")
  }
  universe <- ledgr_validate_strategy_helper_ctx(ctx, "ledgr_target_quantity")
  if (!is.numeric(qty) || length(qty) != 1L || is.na(qty) || !is.finite(qty) || qty < 0) {
    rlang::abort(
      "`qty` must be one finite, non-negative number; negative quantities are not supported until short-selling semantics are defined.",
      class = "ledgr_invalid_strategy_helper"
    )
  }

  eligible <- ledgr_strategy_eligible(ctx, universe)
  selection_ids <- names(selection)
  chosen <- as.logical(selection)
  unknown <- setdiff(selection_ids, universe)
  if (length(unknown) > 0L) {
    rlang::abort(
      sprintf("`selection` names instruments outside the decision axis: %s.", paste(unknown, collapse = ", ")),
      class = "ledgr_invalid_strategy_helper"
    )
  }
  selected_idx <- match(selection_ids[chosen], universe)
  if (any(!eligible[selected_idx])) {
    rlang::abort(
      sprintf("`selection` selects instruments that are not eligible: %s.",
              paste(universe[selected_idx[!eligible[selected_idx]]], collapse = ", ")),
      class = "ledgr_invalid_strategy_helper"
    )
  }

  position <- ctx$position
  if (is.null(position) || length(position) != length(universe)) {
    rlang::abort(
      "`ctx$position` must provide one value per decision-axis instrument.",
      class = "ledgr_invalid_strategy_helper"
    )
  }
  target <- stats::setNames(as.numeric(position), universe)
  target[eligible] <- 0
  target[selected_idx] <- as.numeric(qty)

  ledgr_target(target, universe = universe, origin = attr(selection, "origin"))
}
