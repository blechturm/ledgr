# WS43 Correction 1 mutations (close review 43 findings F2, F3/decision 19,
# F4, F6 and decision 20); run with scripts/mutate.R.
f <- "indicator-evidence|indicator-causality|indicator-dispatch"
hf <- "R/history-frame.R"
fe <- "R/history-features.R"
mutations <- list(
  f2_ready_aliases_calculated = list(
    file = hf,
    old = "  ready <- calculated & shape(!is.na(ready_col) & column >= ready_col)",
    new = "  ready <- calculated",
    filter = f, blocks = "LTB-0319"
  ),
  f2_valid_aliases_calculated = list(
    file = hf,
    old = "  calculation_valid <- ready & is.finite(value) & !output_carried",
    new = "  calculation_valid <- calculated",
    filter = f, blocks = "LTB-0319"
  ),
  f2_not_ready_reason_dropped = list(
    file = hf,
    old = "  reason[calculated & !ready] <- \"not_ready\"\n",
    new = "",
    filter = f, blocks = "LTB-0319"
  ),
  f2_required_input_missing_placeholder = list(
    file = hf,
    old = "  reason[expected & in_range & code == 1L] <- \"required_input_missing\"",
    new = "  reason[expected & in_range & code == 1L] <- \"not_calculated\"",
    filter = f, blocks = "LTB-0319"
  ),
  f2_carried_input_excluded_not_retained = list(
    file = fe,
    old = "  code[unavailable & excluded & carried_any] <- 2L\n",
    new = "",
    filter = f, blocks = "LTB-0319"
  ),
  f2_expired_output_not_retained = list(
    file = fe,
    old = "  code[expired] <- 3L\n",
    new = "",
    filter = f, blocks = "LTB-0319"
  ),
  f2_outside_calculation_dropped = list(
    file = hf,
    old = "  reason[expected & !in_range] <- \"outside_calculation\"\n",
    new = "",
    filter = f, blocks = "LTB-0319"
  ),
  f2_segments_not_retained = list(
    file = fe,
    old = "  inside <- segments$end >= range_start\n  if (any(inside)) {",
    new = "  inside <- segments$end >= range_start\n  if (FALSE) {",
    filter = f, blocks = "LTB-0319"
  ),
  f6_input_carry_from_all_price_fields = list(
    file = fe,
    old = "  carried_any <- Reduce(`|`, lapply(declarations$required_fields, function(field) {\n    inputs$carried[[field]][keep]",
    new = "  carried_any <- Reduce(`|`, lapply(ledgr_history_price_fields(), function(field) {\n    inputs$carried[[field]][keep]",
    filter = f, blocks = "LTB-0319"
  ),
  f6_probe_first_instrument = list(
    file = fe,
    old = "    i <- which.max(counts)\n",
    new = "    i <- which(counts > 0L)[[1L]]\n",
    filter = f, blocks = "LTB-0316"
  ),
  f6_probe_every_instrument = list(
    edits = list(
      list(file = fe, old = "    i <- which.max(counts)\n", new = "    for (i in which(counts > 0L)) {\n"),
      list(
        file = fe,
        old = "      certified[[d]], probes[[key]], bounds$from, values[[d]][i, ]\n    )\n  }\n",
        new = "      certified[[d]], probes[[key]], bounds$from, values[[d]][i, ]\n    )\n  }}\n"
      )
    ),
    filter = f, blocks = "LTB-0316"
  ),
  f4_terminal_barrier_ignored_in_feature_carry = list(
    file = fe,
    old = "      terminal_barrier = terminal\n",
    new = "      terminal_barrier = rep(FALSE, prefix_end)\n",
    filter = f, blocks = "LTB-0320"
  ),
  d20_windows_cross_terminal_interval = list(
    file = fe,
    old = "    breaks = c(FALSE, terminal_rows[-1L] != terminal_rows[-length(terminal_rows)])",
    new = "    breaks = NULL",
    filter = f, blocks = "LTB-0320"
  ),
  d19_builtin_shadows_custom = list(
    file = "R/backtest-runner.R",
    old = "  shadowed <- function(d, builtin) {\n    !is.null(d$fingerprint) &&",
    new = "  shadowed <- function(d, builtin) {\n    FALSE &&",
    filter = f, blocks = "LTB-0321"
  )
)
