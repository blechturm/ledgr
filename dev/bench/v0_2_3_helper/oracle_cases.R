# Cut 17 (LDG-3232): the differential oracle's case grid.
#
# Every case is evaluated by oracle_run.R in each arm's process with the same
# invocation expression. A case is
#   list(id, sites, expect, tag, expr, data, notes, reach)
# - sites: the rewrite sites it exercises (sites.csv), ";"-separated
# - expect: "value" or "error:<class>", asserted on the pin arm
# - tag: "precedence" for multi-invalid cases (several checks would fail)
# - expr: the invocation, evaluated in an environment holding `data`
# - data: a function returning the case's inputs (built fresh per arm)
# - notes: NULL (ctx has no .notes), or a list of bindings for a fresh
#   .notes environment created before each evaluation
# - reach: optional predicate on the pin's value (TRUE when the case reaches
#   the branch its id names), asserted by the checker
#
# Captured pulse views (genuine contexts from a run) are added by
# oracle_run.R through `views`, keyed "v10", "v500", "v1166".

oracle_u8 <- paste0("Z", intToUtf8(0xFCL), "rich")
oracle_l1 <- iconv(oracle_u8, "UTF-8", "latin1")

# Classed operands with their own methods (registered in each arm the same
# way): numeric amounts whose names() returns classed IDs, IDs whose `[`
# reverses the selection (legal, if odd), and a universe class whose `[`
# keeps the class. Base set operations strip these classes first; a shortcut
# that dispatches on them would not.
registerS3method("names", "oracle_wts", function(x) structure(attr(x, "names"), class = "oracle_ids"), envir = globalenv())
registerS3method("[", "oracle_ids", function(x, i) structure(rev(unclass(x)[i]), class = "oracle_ids"), envir = globalenv())
registerS3method("[", "oracle_univ", function(x, i) structure(unclass(x)[i], class = "oracle_univ"), envir = globalenv())
oracle_wts <- function(...) { v <- c(...); structure(unname(v), names = names(v), class = "oracle_wts") }
# An amount class that survives normalisation: as.double() returns the object
# itself, so stats::setNames(as.numeric(x), x_names) keeps the class and its
# names() method still returns classed IDs (close review round 2, finding 1).
registerS3method("as.double", "oracle_amt", function(x, ...) x, envir = globalenv())
registerS3method("names", "oracle_amt", function(x) structure(attr(x, "names"), class = "oracle_ids"), envir = globalenv())
oracle_amt <- function(...) { v <- c(...); structure(unname(v), names = names(v), class = "oracle_amt") }
oracle_ids40 <- sprintf("P%02d", 40:1)
# A names() method returning an unclassed list (close review round 3, finding
# 1): attribute-free but not character, accepted by the validators.
registerS3method("as.double", "oracle_lnames", function(x, ...) x, envir = globalenv())
registerS3method("names", "oracle_lnames", function(x) as.list(attr(x, "names")), envir = globalenv())
registerS3method("names", "oracle_lmask", function(x) as.list(attr(x, "names")), envir = globalenv())
oracle_lnames <- function(...) { v <- c(...); structure(unname(v), names = names(v), class = "oracle_lnames") }
oracle_lmask <- function(v) structure(unname(v), names = names(v), class = "oracle_lmask")

oracle_ctx <- function(ids = c("CCC", "AAA", "BBB", "DDD"), close = NULL, position = NULL, holding_value = NULL,
                       member = NULL, buyable = NULL, equity = 1e6) {
  n <- length(ids)
  if (is.null(close)) close <- seq(40, by = 15, length.out = n)
  if (is.null(position)) position <- rep(0, n)
  if (is.null(member)) member <- rep(TRUE, n)
  if (is.null(buyable)) buyable <- rep(TRUE, n)
  nm <- if (is.null(dim(ids))) ids else as.vector(ids)
  if (is.null(holding_value)) holding_value <- position * close
  list(universe = ids, equity = equity, close = stats::setNames(close, nm), member = stats::setNames(member, nm),
       buyable = stats::setNames(buyable, nm), position = stats::setNames(position, nm),
       holding_value = stats::setNames(holding_value, nm))
}

# The standard four-instrument context: non-lexical axis, CCC and BBB held.
oracle_ctx4 <- function(...) {
  base <- list(position = c(10, 0, 5, 0))
  a <- utils::modifyList(base, list(...))
  do.call(oracle_ctx, a)
}

oracle_case <- function(id, sites, expect, expr, data, notes = list(), tag = "", reach = NULL) {
  list(id = id, sites = sites, expect = expect, tag = tag, expr = substitute(expr), data = data, notes = notes,
       reach = reach)
}

oracle_has_reason <- function(code) {
  force(code)
  function(v) code %in% attr(v, "sizing_evidence")$reason_code
}

oracle_cases <- function() {
  C <- list()
  add <- function(x) C[[length(C) + 1L]] <<- x
  R <- function(...) ledgr::ledgr_target_rebalance(...)
  # ---- rebalance: values -----------------------------------------------------
  add(oracle_case("reb_subset_nonlexical", "S01;S04;S05;S08;S12;S15;S17;S18", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(DDD = 0.3, AAA = 0.2)), function() list(ctx = oracle_ctx4()),
    reach = oracle_has_reason("sizing_liquidation")))
  add(oracle_case("reb_weights_omitted", "S01;S04;S05;S08;S15;S17", "value",
    ledgr::ledgr_target_rebalance(ctx), function() list(ctx = oracle_ctx4()), reach = oracle_has_reason("sizing_liquidation")))
  add(oracle_case("reb_zero_weights", "S01;S12;S18", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(CCC = 0, AAA = 0, BBB = 0.4)), function() list(ctx = oracle_ctx4()),
    reach = function(v) all(c("sizing_liquidation", "sizing_zero_target") %in% attr(v, "sizing_evidence")$reason_code)))
  add(oracle_case("reb_round_to_zero", "S01;S12", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(CCC = 1e-6, AAA = 1e-6, BBB = 0.5)),
    function() list(ctx = oracle_ctx4(close = c(400, 500, 60, 70))),
    reach = function(v) all(c("sizing_rounded_to_zero_liquidation", "sizing_rounded_to_zero_addition") %in%
                              attr(v, "sizing_evidence")$reason_code)))
  add(oracle_case("reb_keep_ids_total", "S03;S04;S05;S06;S08;S13", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.4), keep = "BBB", capital_base = "total_equity"),
    function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_keep_ids_remaining", "S03;S04;S05;S06;S08;S13", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.4), keep = c("BBB", "CCC"), capital_base = "remaining_equity"),
    function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_keep_mask_unnamed", "S04;S05;S08;S14", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), keep = c(TRUE, FALSE, FALSE, FALSE),
                                  capital_base = "total_equity"), function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_keep_mask_named_permuted", "S04;S05;S08;S14", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), keep = c(DDD = FALSE, BBB = TRUE, AAA = FALSE, CCC = TRUE),
                                  capital_base = "remaining_equity"), function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_leaver_sell", "S03;S05;S08;S18", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3), index_leavers = "sell"),
    function() list(ctx = oracle_ctx4(member = c(TRUE, TRUE, FALSE, TRUE)))))
  add(oracle_case("reb_leaver_keep", "S03;S05;S08", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3), index_leavers = "keep", capital_base = "total_equity"),
    function() list(ctx = oracle_ctx4(member = c(TRUE, TRUE, FALSE, TRUE)))))
  add(oracle_case("reb_leaver_explicit_keep", "S03;S05;S13", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3), keep = "BBB", capital_base = "total_equity"),
    function() list(ctx = oracle_ctx4(member = c(TRUE, TRUE, FALSE, TRUE)))))
  add(oracle_case("reb_leaver_mask_sell", "S03;S05;S14", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3), keep = c(FALSE, FALSE, TRUE, FALSE), index_leavers = "sell"),
    function() list(ctx = oracle_ctx4(member = c(TRUE, TRUE, FALSE, TRUE)))))
  add(oracle_case("reb_restricted_member_flat", "S03;S04", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3)),
    function() list(ctx = oracle_ctx4(member = c(TRUE, TRUE, TRUE, FALSE)))))
  add(oracle_case("reb_skip_flat", "S09;S11;S18", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3, DDD = 0.3)),
    function() list(ctx = oracle_ctx4(close = c(40, NA, 70, 85))), notes = list(),
    reach = oracle_has_reason("sizing_unavailable")))
  add(oracle_case("reb_skip_held_marked", "S08;S09;S11", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(BBB = 0.5, AAA = 0.5)),
    function() list(ctx = oracle_ctx4(close = c(40, 55, NA, 85), holding_value = c(400, 0, 300000, 0))),
    notes = list(), reach = function(v) any(attr(v, "sizing_evidence")$reason_code == "sizing_unavailable")))
  add(oracle_case("reb_guard_scaling", "S09", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(BBB = 0.4, AAA = 0.3, DDD = 0.3)),
    function() list(ctx = oracle_ctx4(close = c(40, 55, NA, 85), holding_value = c(400, 0, 500000, 0))),
    notes = list(), reach = function(v) {
      e <- attr(v, "sizing_evidence"); ok <- e$reason_code == "sizing_rounded"
      any(e$pre_floor_quantity[ok] < e$requested_quantity[ok])
    }))
  add(oracle_case("reb_skip_held_unmarked", "S09", "error:ledgr_target_sizing_unavailable",
    ledgr::ledgr_target_rebalance(ctx, weights = c(BBB = 0.5)),
    function() list(ctx = oracle_ctx4(close = c(40, 55, NA, 85), holding_value = c(400, 0, NA, 0))), notes = list()))
  add(oracle_case("reb_preserve_unmarked", "S08", "error:ledgr_target_sizing_unavailable",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), keep = "BBB", capital_base = "total_equity"),
    function() list(ctx = oracle_ctx4(holding_value = c(400, 0, NA, 0)))))
  add(oracle_case("reb_multi_skip_notes_overlap", "S09;S11", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(DDD = 0.2, AAA = 0.2, CCC = 0.2)),
    function() list(ctx = oracle_ctx4(close = c(NA, NA, 70, NA), holding_value = c(400, 0, 350, 0))),
    notes = list(sizing_skipped = c("ZZZ", "AAA"))))
  add(oracle_case("reb_notes_empty_prior", "S09;S11", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2)),
    function() list(ctx = oracle_ctx4(close = c(40, NA, 70, 85))), notes = list(sizing_skipped = character())))
  add(oracle_case("reb_no_notes_env", "S09", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2)),
    function() list(ctx = oracle_ctx4(close = c(40, NA, 70, 85))), notes = NULL))
  add(oracle_case("reb_skip_then_overflow", "S09;S11;S17", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2, BBB = 0.2)),
    function() list(ctx = oracle_ctx4(close = c(40, NA, 1e-320, 85))), notes = list()))
  add(oracle_case("reb_matrix_universe_dup", "S15;S16;S17", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_rebalance(ctx, weights = c(BBB = 0.2)),
    function() list(ctx = oracle_ctx(ids = matrix(c("AAA", "BBB", "AAA", "CCC"), nrow = 2L)))))
  add(oracle_case("reb_matrix_universe_unique", "S15;S16;S17", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(BBB = 0.2)),
    function() list(ctx = oracle_ctx(ids = matrix(c("AAA", "BBB", "DDD", "CCC"), nrow = 2L)))))
  # cut review: close review 1, finding 1 (duplicate flattened IDs and classed names)
  add(oracle_case("reb_matrix_held_leavers", "S03;S15", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_rebalance(ctx, weights = c(BBB = 0.2)),
    function() list(ctx = oracle_ctx(ids = matrix(c("AAA", "BBB", "AAA", "CCC"), nrow = 2L), position = c(1, 0, 1, 0),
                                      member = c(FALSE, TRUE, FALSE, TRUE)))))
  add(oracle_case("reb_classed_names_weights", "S12", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_rebalance(ctx, weights = oracle_wts(EEE = 0.1, AAA = 0.1, FFF = 0.1)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_classed_names_add", "S12", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, add_value = oracle_wts(EEE = 10, AAA = 10, FFF = 10)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("sig_classed_names", "S15;S16", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_signal(oracle_wts(EEE = 1, AAA = 2, FFF = 3), universe = c("AAA", "BBB")), function() list()))
  add(oracle_case("tgt_classed_names_missing", "S15;S16;S17", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target(oracle_wts(EEE = 1, AAA = 2, FFF = 3), universe = c("DDD", "AAA", "BBB", "CCC")), function() list()))
  # close review round 2, finding 1: amounts whose class survives normalisation
  add(oracle_case("reb_amt_class_kept", "S01;S05;S06", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_rebalance(ctx, weights = oracle_amt(BBB = 0.2, CCC = 0.1), keep = c("BBB", "CCC"),
                                  capital_base = "total_equity"), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_amt_class_exited", "S01;S07", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_adjust(ctx, weights = oracle_amt(BBB = 0.2, CCC = 0.1), exit = c(TRUE, FALSE, TRUE, FALSE)),
    function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_amt_class_kept_40", "S01;S05;S06;S18", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_rebalance(ctx, weights = oracle_amt(P07 = 0.2, P03 = 0.1), keep = c("P07", "P03"),
                                  capital_base = "total_equity"), function() list(ctx = oracle_ctx(ids = oracle_ids40))))
  add(oracle_case("adj_amt_class_exited_40", "S01;S07;S18", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_adjust(ctx, weights = oracle_amt(P07 = 0.2, P03 = 0.1), exit = oracle_ids40 %in% c("P07", "P03")),
    function() list(ctx = oracle_ctx(ids = oracle_ids40))))
  add(oracle_case("reb_amt_class_value_40", "S01;S04;S05;S08;S18", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = oracle_amt(P07 = 0.2, P03 = 0.1, P31 = 0.3)),
    function() list(ctx = oracle_ctx(ids = oracle_ids40, position = rep(c(4, 0), 20)))))
  add(oracle_case("reb_plain_value_40", "S01;S04;S05;S08;S18", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(P07 = 0.2, P03 = 0.1, P31 = 0.3), keep = "P12", capital_base = "total_equity"),
    function() list(ctx = oracle_ctx(ids = oracle_ids40, position = rep(c(4, 0), 20)))))
  # close review round 3, finding 1: names() returning an unclassed list
  add(oracle_case("reb_list_names_kept", "S01;S06;S12", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_rebalance(ctx, weights = oracle_lnames(BBB = 0.2, CCC = 0.1), keep = c("BBB", "CCC"),
                                  capital_base = "total_equity"), function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_list_names_kept_40", "S01;S06;S12;S18", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_rebalance(ctx, weights = oracle_lnames(P07 = 0.2, P03 = 0.1), keep = c("P07", "P03"),
                                  capital_base = "total_equity"), function() list(ctx = oracle_ctx(ids = oracle_ids40))))
  add(oracle_case("adj_list_names_exited_40", "S01;S07;S12;S18", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_adjust(ctx, weights = oracle_lnames(P07 = 0.2, P03 = 0.1), exit = oracle_ids40 %in% c("P07", "P03")),
    function() list(ctx = oracle_ctx(ids = oracle_ids40))))
  add(oracle_case("reb_list_names_value_40", "S01;S08;S12;S18", "error:error",
    ledgr::ledgr_target_rebalance(ctx, weights = oracle_lnames(P07 = 0.2, P03 = 0.1)),
    function() list(ctx = oracle_ctx(ids = oracle_ids40, position = rep(c(4, 0), 20)))))
  add(oracle_case("adj_list_names_exit_mask_40", "S14;S18", "value",
    ledgr::ledgr_target_adjust(ctx, exit = oracle_lmask(stats::setNames(rev(oracle_ids40) %in% c("P07", "P03"), rev(oracle_ids40)))),
    function() list(ctx = oracle_ctx(ids = oracle_ids40, position = rep(c(4, 0), 20)))))
  add(oracle_case("sig_list_names_40", "S15;S16", "value",
    ledgr::ledgr_signal(oracle_lnames(P07 = 1, P03 = 2), universe = oracle_ids40), function() list()))
  add(oracle_case("sig_list_names", "S15;S16", "value",
    ledgr::ledgr_signal(oracle_lnames(BBB = 1, AAA = 2), universe = c("CCC", "AAA", "BBB")), function() list()))
  add(oracle_case("reb_keep_named_character","S03;S05;S06;S13", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3), keep = c(k = "BBB"), capital_base = "total_equity"),
    function() list(ctx = oracle_ctx4(member = c(TRUE, TRUE, FALSE, TRUE)))))
  add(oracle_case("reb_keep_classed", "S03;S05;S06;S13", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3), keep = structure(c("BBB", "CCC"), class = "oracle_ids"),
                                  capital_base = "total_equity"),
    function() list(ctx = oracle_ctx4(member = c(TRUE, TRUE, FALSE, TRUE)))))
  add(oracle_case("reb_keep_matrix", "S03;S05;S06;S13", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3), keep = matrix(c("BBB", "CCC"), nrow = 1L), capital_base = "total_equity"),
    function() list(ctx = oracle_ctx4(member = c(TRUE, TRUE, FALSE, TRUE)))))
  add(oracle_case("reb_keep_classed_overlap", "S06", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_rebalance(ctx, weights = c(BBB = 0.3, CCC = 0.1), keep = structure(c("CCC", "BBB"), class = "oracle_ids"),
                                  capital_base = "total_equity"), function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_classed_universe_methods", "S03;S04;S05;S08;S15;S16;S18", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.3), keep = "BBB", index_leavers = "sell", capital_base = "total_equity"),
    function() list(ctx = oracle_ctx(ids = structure(c("CCC", "AAA", "BBB", "DDD"), class = "oracle_univ"),
                                      position = c(10, 0, 5, 3), member = c(TRUE, TRUE, TRUE, FALSE)))))
  add(oracle_case("adj_classed_universe_methods", "S07;S14;S18", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_adjust(ctx, weights = c(AAA = 0.1), add_value = c(DDD = 50), exit = c(FALSE, TRUE, FALSE, TRUE)),
    function() list(ctx = oracle_ctx(ids = structure(c("CCC", "AAA", "BBB", "DDD"), class = "oracle_univ"),
                                      position = c(10, 0, 5, 3)))))
  add(oracle_case("adj_zero_weights", "S01;S12;S18", "value",
    ledgr::ledgr_target_adjust(ctx, weights = c(CCC = 0, AAA = 0, BBB = 0.2)), function() list(ctx = oracle_ctx4()),
    reach = function(v) all(c("sizing_liquidation", "sizing_zero_target") %in% attr(v, "sizing_evidence")$reason_code)))
  add(oracle_case("adj_guard_scaling", "S09;S18", "value",
    ledgr::ledgr_target_adjust(ctx, weights = c(BBB = 0.4, AAA = 0.3, DDD = 0.3)),
    function() list(ctx = oracle_ctx4(close = c(40, 55, NA, 85), holding_value = c(400, 0, 500000, 0))),
    notes = list(), reach = function(v) {
      e <- attr(v, "sizing_evidence"); ok <- e$reason_code == "sizing_rounded"
      any(e$pre_floor_quantity[ok] < e$requested_quantity[ok])
    }))
  add(oracle_case("reb_classed_universe", "S04;S15;S16", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(BBB = 0.2)),
    function() list(ctx = oracle_ctx(ids = structure(c("CCC", "AAA", "BBB"), class = "oracle_ids")))))
  add(oracle_case("reb_empty_universe", "S01;S15;S17", "value",
    ledgr::ledgr_target_rebalance(ctx), function() list(ctx = oracle_ctx(ids = character()))))
  add(oracle_case("reb_empty_named_weights", "S01;S12", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = stats::setNames(numeric(), character())), function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_latin1_universe", "S01;S04;S08;S12;S15;S16", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = stats::setNames(0.3, oracle_u8)),
    function() list(ctx = oracle_ctx(ids = c("BBB", oracle_l1, "AAA"), position = c(3, 2, 0)))))
  add(oracle_case("reb_base_default", "S01", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.5)), function() list(ctx = oracle_ctx(ids = c("BBB", "AAA"))),
    reach = function(v) identical(attr(v, "origin")$capital_base_origin, "default")))
  add(oracle_case("reb_base_not_required", "S01", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0)), function() list(ctx = oracle_ctx4()),
    reach = function(v) identical(attr(v, "origin")$capital_base_origin, "not_required")))
  add(oracle_case("reb_invest_zero", "S01", "value",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.5), invest_fraction = 0), function() list(ctx = oracle_ctx4())))
  # ---- rebalance and shared refusals -----------------------------------------
  bad_weights <- list(
    w_char = quote(c(AAA = "a")), w_factor = quote(factor(c(AAA = "a"))), w_matrix = quote(matrix(0.1, 1, 1, dimnames = list("AAA", NULL))),
    w_na = quote(c(AAA = NA_real_)), w_nan = quote(c(AAA = NaN)), w_inf = quote(c(AAA = Inf)), w_negative = quote(c(AAA = -0.1)),
    w_dup = quote(c(AAA = 0.1, AAA = 0.1)), w_unknown = quote(c(EEE = 0.1, AAA = 0.1, FFF = 0.1)),
    w_unnamed = quote(c(0.1, 0.2)), w_na_name = quote(stats::setNames(0.1, NA_character_)),
    w_empty_name = quote(stats::setNames(0.1, "")), w_unnamed_empty = quote(numeric()),
    w_cross_encoding_dup = quote(stats::setNames(c(0.1, 0.1), c(oracle_u8, oracle_l1))),
    w_sum_over_one = quote(c(AAA = 0.6, BBB = 0.6)))
  for (n in names(bad_weights)) {
    e <- bquote(ledgr::ledgr_target_rebalance(ctx, weights = .(bad_weights[[n]])))
    cls <- if (n == "w_cross_encoding_dup") "error:ledgr_invalid_strategy_type" else "error:ledgr_invalid_strategy_type"
    x <- oracle_case("x", "S12", cls, NULL, function() list(ctx = oracle_ctx4(ids = c("CCC", "AAA", "BBB", oracle_u8))))
    x$id <- paste0("reb_refuse_", n); x$expr <- e
    if (n != "w_cross_encoding_dup") x$data <- function() list(ctx = oracle_ctx4())
    add(x)
  }
  add(oracle_case("reb_refuse_unbuyable", "S01", "error:ledgr_invalid_strategy_helper",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2, DDD = 0.2)),
    function() list(ctx = oracle_ctx4(buyable = c(TRUE, FALSE, TRUE, FALSE)))))
  add(oracle_case("reb_refuse_weighted_kept", "S05;S06", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_rebalance(ctx, weights = c(BBB = 0.2, AAA = 0.1), keep = c("AAA", "BBB"), capital_base = "total_equity"),
    function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_refuse_leaver_undecided", "S03", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2)),
    function() list(ctx = oracle_ctx4(member = c(FALSE, TRUE, FALSE, TRUE)))))
  add(oracle_case("reb_refuse_base_choice", "S08", "error:ledgr_invalid_strategy_helper",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), keep = "BBB"), function() list(ctx = oracle_ctx4())))
  bad_keep <- list(k_na = quote(c("AAA", NA)), k_empty = quote(c("AAA", "")), k_dup = quote(c("AAA", "AAA")),
    k_unknown = quote(c("EEE", "AAA", "FFF")), k_mask_short = quote(c(TRUE, FALSE)),
    k_mask_names = quote(c(AAA = TRUE, BBB = FALSE, CCC = TRUE, EEE = FALSE)), k_mask_na = quote(c(TRUE, NA, FALSE, FALSE)),
    k_factor = quote(factor("AAA")))
  for (n in names(bad_keep)) {
    x <- oracle_case("x", "S13;S14", "error:ledgr_invalid_strategy_type", NULL, function() list(ctx = oracle_ctx4()))
    x$id <- paste0("reb_refuse_", n)
    x$expr <- bquote(ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), keep = .(bad_keep[[n]])))
    add(x)
  }
  add(oracle_case("reb_refuse_index_leavers", "S03", "error:ledgr_invalid_strategy_helper",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), index_leavers = "drop"), function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_refuse_capital_base", "S08", "error:ledgr_invalid_strategy_helper",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), capital_base = "cash"), function() list(ctx = oracle_ctx4())))
  add(oracle_case("reb_refuse_invest_fraction", "", "error:ledgr_invalid_strategy_helper",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), invest_fraction = 2), function() list(ctx = oracle_ctx4())))
  bad_ctx <- list(c_universe_dup = quote({ ctx$universe <- c("AAA", "AAA") ; ctx }),
    c_equity = quote({ ctx$equity <- -1; ctx }), c_member = quote({ ctx$member <- ctx$member[1:2]; ctx }),
    c_position = quote({ ctx$position[2] <- NA; ctx }), c_holding = quote({ ctx$holding_value <- 1; ctx }),
    c_close = quote({ ctx$close <- 1; ctx }), c_buyable = quote({ ctx$buyable[1] <- NA; ctx }))
  for (n in names(bad_ctx)) {
    x <- oracle_case("x", "", "error:ledgr_invalid_strategy_helper", NULL, NULL)
    x$id <- paste0("reb_refuse_", n)
    x$data <- local({ q <- bad_ctx[[n]]; function() { ctx <- oracle_ctx4(); list(ctx = eval(q)) } })
    x$expr <- quote(ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2)))
    add(x)
  }
  # ---- multi-invalid precedence ------------------------------------------------
  add(oracle_case("prec_unknown_and_sum", "S12", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_rebalance(ctx, weights = c(EEE = 0.6, AAA = 0.6)), function() list(ctx = oracle_ctx4()), tag = "precedence"))
  add(oracle_case("prec_unbuyable_and_kept", "S01;S06", "error:ledgr_invalid_strategy_helper",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), keep = "AAA", capital_base = "total_equity"),
    function() list(ctx = oracle_ctx4(buyable = c(TRUE, FALSE, TRUE, TRUE))), tag = "precedence"))
  add(oracle_case("prec_keep_and_leavers", "S13", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2), keep = c("EEE"), index_leavers = "drop"),
    function() list(ctx = oracle_ctx4()), tag = "precedence"))
  add(oracle_case("prec_weights_then_add", "S12", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, weights = c(EEE = 0.2), add_value = c(FFF = 10)), function() list(ctx = oracle_ctx4()),
    tag = "precedence"))
  add(oracle_case("prec_add_then_sum", "S12", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, weights = c(AAA = 0.7, BBB = 0.7), add_value = c(FFF = 10)),
    function() list(ctx = oracle_ctx4()), tag = "precedence"))
  add(oracle_case("prec_weighted_added_and_exit", "S02;S07", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_adjust(ctx, weights = c(AAA = 0.1), add_value = c(AAA = 10), exit = c(TRUE, FALSE, FALSE, FALSE)),
    function() list(ctx = oracle_ctx4()), tag = "precedence"))
  add(oracle_case("prec_skip_then_unmarked", "S09", "error:ledgr_target_sizing_unavailable",
    ledgr::ledgr_target_rebalance(ctx, weights = c(AAA = 0.2, BBB = 0.2)),
    function() list(ctx = oracle_ctx4(close = c(40, NA, NA, 85), holding_value = c(400, 0, NA, 0))), notes = list(),
    tag = "precedence"))
  # ---- adjust ------------------------------------------------------------------
  add(oracle_case("adj_weights", "S01;S08;S12;S18", "value",
    ledgr::ledgr_target_adjust(ctx, weights = c(DDD = 0.2, AAA = 0.1)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_add_held_and_flat", "S01;S02;S08;S12", "value",
    ledgr::ledgr_target_adjust(ctx, add_value = c(CCC = 500, AAA = 300)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_exit_held_flat_unnamed", "S07;S08;S14", "value",
    ledgr::ledgr_target_adjust(ctx, exit = c(TRUE, TRUE, FALSE, FALSE)), function() list(ctx = oracle_ctx4()),
    reach = oracle_has_reason("sizing_liquidation")))
  add(oracle_case("adj_exit_named_permuted", "S07;S14", "value",
    ledgr::ledgr_target_adjust(ctx, exit = c(DDD = FALSE, BBB = TRUE, AAA = FALSE, CCC = FALSE)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_combo", "S01;S02;S07;S08;S12", "value",
    ledgr::ledgr_target_adjust(ctx, weights = c(DDD = 0.1), add_value = c(AAA = 200), exit = c(CCC = TRUE, AAA = FALSE, BBB = FALSE, DDD = FALSE),
                               capital_base = "remaining_equity"), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_add_round_to_zero", "S02", "value",
    ledgr::ledgr_target_adjust(ctx, add_value = c(CCC = 1, AAA = 1)), function() list(ctx = oracle_ctx4()),
    reach = function(v) all(c("sizing_rounded_to_zero_liquidation", "sizing_rounded_to_zero_addition") %in%
                              attr(v, "sizing_evidence")$reason_code) ||
                          any(grepl("rounded_to_zero", attr(v, "sizing_evidence")$reason_code))))
  add(oracle_case("adj_add_skipped", "S10;S11;S18", "value",
    ledgr::ledgr_target_adjust(ctx, add_value = c(AAA = 300, DDD = 100)),
    function() list(ctx = oracle_ctx4(close = c(40, NA, 70, NA))), notes = list(sizing_skipped = "DDD"),
    reach = oracle_has_reason("sizing_unavailable")))
  add(oracle_case("adj_weight_and_add_skips", "S09;S10;S11", "value",
    ledgr::ledgr_target_adjust(ctx, weights = c(BBB = 0.1), add_value = c(AAA = 300)),
    function() list(ctx = oracle_ctx4(close = c(40, NA, NA, 85), holding_value = c(400, 0, 300, 0))), notes = list()))
  add(oracle_case("adj_skip_then_overflow", "S10;S11;S17", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, add_value = c(AAA = 300, BBB = 1e300)),
    function() list(ctx = oracle_ctx4(close = c(40, NA, 1e-300, 85))), notes = list()))
  add(oracle_case("adj_matrix_universe_dup", "S15;S16;S17", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, add_value = c(BBB = 10)),
    function() list(ctx = oracle_ctx(ids = matrix(c("AAA", "BBB", "AAA", "CCC"), nrow = 2L)))))
  add(oracle_case("adj_empty_universe", "S15;S17", "value",
    ledgr::ledgr_target_adjust(ctx), function() list(ctx = oracle_ctx(ids = character()))))
  add(oracle_case("adj_base_supplied", "S01", "value",
    ledgr::ledgr_target_adjust(ctx, weights = c(AAA = 0.1), capital_base = "total_equity"), function() list(ctx = oracle_ctx4()),
    reach = function(v) identical(attr(v, "origin")$capital_base_origin, "supplied")))
  add(oracle_case("adj_refuse_sized_exited", "S07", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_adjust(ctx, add_value = c(BBB = 10, AAA = 5), exit = c(FALSE, TRUE, TRUE, FALSE)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_refuse_weighted_added", "S02", "error:ledgr_invalid_strategy_result",
    ledgr::ledgr_target_adjust(ctx, weights = c(AAA = 0.1, BBB = 0.1), add_value = c(BBB = 10, AAA = 5)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_refuse_exit_short", "S14", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, exit = c(TRUE, FALSE)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_refuse_add_unknown", "S12", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, add_value = c(EEE = 10, GGG = 1)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_refuse_add_negative", "S12", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, add_value = c(AAA = -10)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_refuse_exit_na", "S14", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, exit = c(TRUE, NA, FALSE, FALSE)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_refuse_exit_names", "S14", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target_adjust(ctx, exit = c(AAA = TRUE, BBB = FALSE, CCC = FALSE, EEE = FALSE)), function() list(ctx = oracle_ctx4())))
  add(oracle_case("adj_refuse_unbuyable_add", "S01", "error:ledgr_invalid_strategy_helper",
    ledgr::ledgr_target_adjust(ctx, add_value = c(AAA = 10)),
    function() list(ctx = oracle_ctx4(buyable = c(TRUE, FALSE, TRUE, TRUE)))))
  # ---- shared check_names callers ---------------------------------------------
  add(oracle_case("sig_value", "S15;S16", "value", ledgr::ledgr_signal(c(BBB = 1, AAA = NA), universe = c("CCC", "AAA", "BBB")), function() list()))
  add(oracle_case("sig_value_origin", "S16", "value", ledgr::ledgr_signal(c(BBB = 1), origin = "o"), function() list()))
  add(oracle_case("sig_empty_named", "S15;S16", "value", ledgr::ledgr_signal(stats::setNames(numeric(), character()), universe = "AAA"), function() list()))
  add(oracle_case("sig_empty_unnamed", "S15;S16", "value", ledgr::ledgr_signal(numeric(), universe = "AAA"), function() list()))
  add(oracle_case("sig_refuse_extra", "S16", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_signal(c(EEE = 1, AAA = 2, FFF = 3), universe = c("AAA", "BBB")), function() list()))
  add(oracle_case("sig_refuse_infinite", "", "error:ledgr_invalid_strategy_type", ledgr::ledgr_signal(c(AAA = Inf)), function() list()))
  add(oracle_case("sig_refuse_origin", "", "error:ledgr_invalid_strategy_type", ledgr::ledgr_signal(c(AAA = 1), origin = 2), function() list()))
  add(oracle_case("sig_refuse_dup", "", "error:ledgr_invalid_strategy_type", ledgr::ledgr_signal(c(AAA = 1, AAA = 2)), function() list()))
  add(oracle_case("sig_refuse_bad_universe", "", "error:ledgr_invalid_strategy_type", ledgr::ledgr_signal(c(AAA = 1), universe = c("AAA", NA)), function() list()))
  add(oracle_case("sig_cross_encoding", "S16", "value",
    ledgr::ledgr_signal(stats::setNames(1, oracle_l1), universe = c("AAA", oracle_u8)), function() list()))
  add(oracle_case("sel_value", "S16", "value", ledgr::ledgr_selection(c(BBB = TRUE, AAA = FALSE), universe = c("CCC", "AAA", "BBB")), function() list()))
  add(oracle_case("sel_empty_universe_attr", "S15;S16", "value",
    ledgr::ledgr_selection(stats::setNames(logical(), character()), universe = c("AAA", "BBB")), function() list()))
  add(oracle_case("sel_refuse_extra", "S16", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_selection(c(EEE = TRUE), universe = "AAA"), function() list()))
  add(oracle_case("sel_refuse_na", "", "error:ledgr_invalid_strategy_type", ledgr::ledgr_selection(c(AAA = NA)), function() list()))
  add(oracle_case("wts_value", "S16", "value", ledgr::ledgr_weights(c(BBB = 0.5, AAA = 0.25), universe = c("CCC", "AAA", "BBB")), function() list()))
  add(oracle_case("wts_empty_universe_attr", "S15;S16", "value", ledgr::ledgr_weights(numeric(), universe = c("AAA")), function() list()))
  add(oracle_case("wts_refuse_nonfinite", "", "error:ledgr_invalid_strategy_type", ledgr::ledgr_weights(c(AAA = NA_real_)), function() list()))
  add(oracle_case("wts_refuse_extra", "S16", "error:ledgr_invalid_strategy_type", ledgr::ledgr_weights(c(EEE = 1), universe = "AAA"), function() list()))
  add(oracle_case("tgt_full", "S15;S16;S17", "value", ledgr::ledgr_target(c(BBB = 1, AAA = 0, CCC = 2), universe = c("CCC", "AAA", "BBB")), function() list()))
  add(oracle_case("tgt_no_universe", "S17", "value", ledgr::ledgr_target(c(BBB = 1, AAA = -0)), function() list()))
  add(oracle_case("tgt_empty", "S17", "value", ledgr::ledgr_target(numeric()), function() list()))
  add(oracle_case("tgt_refuse_missing_extra", "S15;S16;S17", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target(c(EEE = 1, AAA = 0, FFF = 2), universe = c("DDD", "AAA", "BBB", "CCC")), function() list()))
  add(oracle_case("tgt_refuse_missing_only", "S15;S17", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target(c(AAA = 0), universe = c("DDD", "AAA", "BBB")), function() list()))
  add(oracle_case("tgt_refuse_empty_with_universe", "S15;S17", "error:ledgr_invalid_strategy_type",
    ledgr::ledgr_target(numeric(), universe = "AAA"), function() list()))
  add(oracle_case("tgt_refuse_nonfinite", "S17", "error:ledgr_invalid_strategy_type", ledgr::ledgr_target(c(AAA = NaN)), function() list()))
  add(oracle_case("tgt_refuse_origin", "S17", "error:ledgr_invalid_strategy_type", ledgr::ledgr_target(c(AAA = 1), origin = ""), function() list()))
  add(oracle_case("tgt_cross_encoding", "S15;S16;S17", "value",
    ledgr::ledgr_target(stats::setNames(c(1, 2), c(oracle_l1, "AAA")), universe = c("AAA", oracle_u8)), function() list()))
  add(oracle_case("tq_value", "S15;S16;S17", "value",
    ledgr::ledgr_target_quantity(ledgr::ledgr_selection(c(AAA = TRUE, BBB = FALSE)), ctx, 5), function() list(ctx = oracle_ctx4())))
  add(oracle_case("tq_refuse_unknown", "", "error:ledgr_invalid_strategy_helper",
    ledgr::ledgr_target_quantity(ledgr::ledgr_selection(c(EEE = TRUE, FFF = FALSE)), ctx, 5), function() list(ctx = oracle_ctx4())))
  add(oracle_case("tq_refuse_ineligible", "", "error:ledgr_invalid_strategy_helper",
    ledgr::ledgr_target_quantity(ledgr::ledgr_selection(c(AAA = TRUE)), ctx, 5),
    function() list(ctx = oracle_ctx4(buyable = c(TRUE, FALSE, TRUE, TRUE)))))
  add(oracle_case("sigret_value", "S15;S16", "value", ledgr::ledgr_signal_return(ctx, 20L),
    function() { ctx <- oracle_ctx4(); ctx$return_20 <- c(0.1, NA, -0.2, 0.3); list(ctx = ctx) }))
  # ---- captured pulse views (added by oracle_run.R) ----------------------------
  for (v in c("v10", "v500", "v1166")) {
    x <- oracle_case("x", "S01;S04;S05;S08;S09;S12;S15;S16;S17", "value", NULL, NULL)
    x$id <- paste0("view_reb_", v)
    x$expr <- quote(ledgr::ledgr_target_rebalance(ctx, weights = w, keep = k, capital_base = "total_equity"))
    x$data <- local({ vv <- v; function() oracle_view_args(vv, "rebalance") })
    x$view <- v
    add(x)
    y <- oracle_case("y", "S01;S02;S07;S08;S10;S12;S14;S15;S16;S17", "value", NULL, NULL)
    y$id <- paste0("view_adj_", v)
    y$expr <- quote(ledgr::ledgr_target_adjust(ctx, weights = w, add_value = a, exit = ex))
    y$data <- local({ vv <- v; function() oracle_view_args(vv, "adjust") })
    y$view <- v
    add(y)
  }
  add(local({ z <- oracle_case("view_sig_context_v10", "S15;S16", "value", ledgr::ledgr_signal(ctx, values = vals), NULL)
    z$data <- function() { a <- oracle_view_args("v10", "plain"); a$vals <- stats::setNames(seq_along(a$ctx$universe) / 10, a$ctx$universe); a }
    z$view <- "v10"; z }))
  add(local({ z <- oracle_case("view_sel_context_ids_v10", "S15;S16", "value", ledgr::ledgr_selection(ctx, ids = ids), NULL)
    z$data <- function() { a <- oracle_view_args("v10", "plain"); a$ids <- rev(a$ctx$universe)[1:3]; a }
    z$view <- "v10"; z }))
  add(local({ z <- oracle_case("view_reb_repeat_v10", "S01;S09;S11;S12", "value",
    list(ledgr::ledgr_target_rebalance(ctx, weights = w, keep = k, capital_base = "total_equity"),
         ledgr::ledgr_target_rebalance(ctx, weights = w, keep = k, capital_base = "total_equity")), NULL)
    z$data <- function() oracle_view_args("v10", "rebalance"); z$view <- "v10"; z }))
  C
}

# Representative arguments on a captured view: helper_view_args() of views.R.
oracle_view_args <- function(v, verb) helper_view_args(oracle_views[[v]], verb)
