# LDG-3067 follow-up mutations after Cut 16 decision (18) and the feature
# evidence fix (run with scripts/mutate.R).
f <- "indicator-causality"
check_call <- "  ledgr_history_feature_causality(substrate, certified, bounds, calculated_count, out)\n"
mutations <- list(
  c1_remove_prefix_check = list(
    file = "R/history-features.R", old = check_call, new = "",
    filter = f, blocks = c("LTB-0315", "LTB-0316", "LTB-0317")
  ),
  d18_refused_run_not_failed = list(
    file = "R/backtest-runner.R",
    old = "\"UPDATE runs SET status = 'FAILED', error_msg = ? WHERE run_id = ?",
    new = "\"UPDATE runs SET status = 'RUNNING', error_msg = ? WHERE run_id = ?",
    filter = f, blocks = "LTB-0315"
  ),
  e1_input_carry_constant_false = list(
    file = "R/history-frame.R",
    old = "  input_carried <- shape(ledgr_history_plane_lookup(retained$input_carried, linear) > 0L)",
    new = "  input_carried <- shape(FALSE)",
    filter = f, blocks = "LTB-0318"
  ),
  e2_output_carry_constant_false = list(
    file = "R/history-frame.R",
    old = "  output_carried <- shape(carried_at > 0L)",
    new = "  output_carried <- shape(FALSE)",
    filter = f, blocks = "LTB-0318"
  ),
  e3_output_carried_counts_as_calculated = list(
    file = "R/history-frame.R",
    old = "  calculated <- is.finite(value) & !output_carried",
    new = "  calculated <- is.finite(value)",
    filter = f, blocks = "LTB-0318"
  ),
  e4_preparation_drops_input_carry = list(
    file = "R/history-features.R",
    old = "    if (any(carried)) input <- keep[carried]",
    new = "    if (FALSE) input <- keep[carried]",
    filter = f, blocks = "LTB-0318"
  ),
  e5_preparation_drops_output_carry = list(
    file = "R/history-features.R",
    old = "    if (any(take)) {\n      output <- list(",
    new = "    if (FALSE) {\n      output <- list(",
    filter = f, blocks = "LTB-0318"
  ),
  e6_slice_drops_planes = list(
    file = "R/runtime-projection.R",
    old = "  feature_planes <- projection$feature_planes\n",
    new = "  feature_planes <- NULL\n",
    filter = f, blocks = "LTB-0318"
  )
)
