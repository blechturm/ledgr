# Cut 17 (LDG-3232): deliberate changes the oracle must catch, one per
# comparison surface of decision (5). Each edits one function's deparsed
# text (fixed-string replacement; a pattern that is not found refuses) and
# is applied by oracle_run.R --mutation=<id> to the arm's loaded namespace
# and to its source copy alike. `signal` is the comparator signal the
# mutation must produce (oracle_compare.R); `case` names a case on which it
# shows.

oracle_mutation_table <- data.frame(stringsAsFactors = FALSE, rbind(
  c("numeric", "ledgr_target_size", "numeric", "reb_subset_nonlexical"),
  c("target_names", "ledgr_target", "names", "tgt_full"),
  c("nested_evidence", "ledgr_target_size", "evidence", "reb_subset_nonlexical"),
  c("derived_names", "ledgr_target_size", "names", "reb_subset_nonlexical"),
  c("attribute_order", "ledgr_target_size", "attr_order", "reb_subset_nonlexical"),
  c("encoding", "ledgr_target_size", "encoding", "reb_latin1_universe"),
  c("notes_order", "ledgr_target_size", "notes", "reb_multi_skip_notes_overlap"),
  c("condition_class", "ledgr_target_sizing_abort", "cond_class", "reb_skip_held_unmarked"),
  c("message", "ledgr_target_size", "message", "reb_refuse_w_sum_over_one"),
  c("instrument_id", "ledgr_target_sizing_abort", "field", "reb_skip_held_unmarked"),
  c("call", "ledgr_target_named_amount", "call", "reb_refuse_w_unknown"),
  c("precedence", "ledgr_target_size", "precedence", "prec_add_then_sum"),
  c("added_warning", "ledgr_target_size", "warning", "reb_subset_nonlexical")))
names(oracle_mutation_table) <- c("id", "fn", "signal", "case")

oracle_mutation_edits <- list(
  numeric = list(c("target[valid_ids] <- floor(pre_floor_quantity)",
                   "target[valid_ids] <- floor(pre_floor_quantity) + (pre_floor_quantity > 1)")),
  target_names = list(c("stats::setNames(as.numeric(x), names(x))", "stats::setNames(as.numeric(x), rev(names(x)))")),
  nested_evidence = list(c("sizing_reason[valid_pos] <- \"sizing_rounded\"", "sizing_reason[valid_pos] <- \"sizing_rounded \"")),
  derived_names = list(c("requested_quantity = sizing_requested[sizing_used]",
                         "requested_quantity = stats::setNames(sizing_requested[sizing_used], universe[sizing_used])")),
  attribute_order = list(c("attr(out, \"sizing_evidence\") <- ",
                           "class(out) <- NULL\n    class(out) <- c(\"ledgr_target\", \"numeric\")\n    attr(out, \"sizing_evidence\") <- ")),
  encoding = list(c("out <- ledgr_target(target,", "names(target) <- enc2utf8(names(target))\n    out <- ledgr_target(target,")),
  notes_order = list(c("out <- ledgr_target(target,",
    "if (is.environment(notes) && length(notes$sizing_skipped) > 1L) notes$sizing_skipped <- rev(notes$sizing_skipped)\n    out <- ledgr_target(target,")),
  condition_class = list(c("class = c(\"ledgr_target_sizing_unavailable\", ", "class = c(\"ledgr_target_sizing_unavailable_x\", ")),
  message = list(c("`weights` must sum to at most one.", "`weights` must sum to one or less.")),
  instrument_id = list(c("instrument_id = instrument_id)", "instrument_ids = instrument_id)")),
  call = list(c("class = \"ledgr_invalid_strategy_type\")", "class = \"ledgr_invalid_strategy_type\", call = NULL)")),
  precedence = list(c("add_value <- ledgr_target_named_amount(add_value, \"add_value\",", "if (FALSE) ledgr_target_named_amount(add_value, \"add_value\","),
                    c("buyable <- ledgr_strategy_eligible(ctx, universe)",
                      "add_value <- ledgr_target_named_amount(add_value, \"add_value\", universe, allow_null = TRUE)\n    buyable <- ledgr_strategy_eligible(ctx, universe)")),
  added_warning = list(c("universe <- ledgr_validate_strategy_helper_ctx(ctx,", "warning(\"oracle mutation\")\n    universe <- ledgr_validate_strategy_helper_ctx(ctx,")))

oracle_apply_mutation <- function(id, ns, src_env) {
  row <- oracle_mutation_table[oracle_mutation_table$id == id, ]
  if (nrow(row) != 1L) stop("unknown mutation: ", id, call. = FALSE)
  fn_name <- row$fn
  text <- paste(deparse(get(fn_name, envir = ns)), collapse = "\n")
  for (e in oracle_mutation_edits[[id]]) {
    if (!grepl(e[[1L]], text, fixed = TRUE)) stop(sprintf("mutation %s: pattern not found in %s: %s", id, fn_name, e[[1L]]), call. = FALSE)
    text <- if (id == "call") gsub(e[[1L]], e[[2L]], text, fixed = TRUE) else sub(e[[1L]], e[[2L]], text, fixed = TRUE)
  }
  fn <- eval(parse(text = text, keep.source = FALSE)[[1L]])
  environment(fn) <- ns
  unlockBinding(fn_name, ns)
  assign(fn_name, fn, envir = ns)
  lockBinding(fn_name, ns)
  if (exists(fn_name, envir = src_env, inherits = FALSE)) assign(fn_name, fn, envir = src_env)
  invisible(fn_name)
}
