# WS43 Correction 2 mutations (re-review 1 findings R1-R4 and Cut 16
# decision 21); run with scripts/mutate.R.
f <- "indicator-evidence|indicator-causality|indicator-dispatch"
hf <- "R/history-frame.R"
fe <- "R/history-features.R"
br <- "R/backtest-runner.R"
mutations <- list(
  r1_breaks_on_sticky_plane = list(
    file = fe,
    old = "    breaks = ledgr_history_feature_terminal_breaks(inputs$terminal_asserted, rows)",
    new = "    breaks = c(FALSE, inputs$terminal[rows][-1L] != inputs$terminal[rows][-length(rows)])",
    filter = f, blocks = "LTB-0320"
  ),
  r1_no_terminal_breaks = list(
    file = fe,
    old = "    breaks = ledgr_history_feature_terminal_breaks(inputs$terminal_asserted, rows)",
    new = "    breaks = NULL",
    filter = f, blocks = "LTB-0320"
  ),
  r4_seam_window_rule_removed = list(
    file = fe,
    old = "    has_window[has_window] <- crossed[k[has_window]] ==\n      crossed[k[has_window] - width + 1L]\n",
    new = "",
    filter = f, blocks = "LTB-0320"
  ),
  r2_output_carry_ignored = list(
    file = hf,
    old = "  if (any(output_carried & !is.na(source_ts) & source_ts < window_start)) {",
    new = "  if (FALSE) {",
    filter = f, blocks = "LTB-0322"
  ),
  r2_leading_input_carry_ignored = list(
    file = hf,
    old = "  leading <- ifelse(first_stop > 1L, seen[cbind(seq_len(n_rows), pmax(first_stop - 1L, 1L))], 0L)",
    new = "  leading <- 0L",
    filter = f, blocks = "LTB-0322"
  ),
  r2_inactive_span_ignored = list(
    file = hf,
    # Window reach counted in columns, not expected sessions (the
    # pre-correction width rule), for the final comparison only.
    old = "  any(valid & (seen - width < leading))",
    new = "  any(valid & (matrix(seq_len(n_cols), n_rows, n_cols, byrow = TRUE) - width < leading))",
    filter = f, blocks = "LTB-0322"
  ),
  r3_unregistered_falls_back_to_builtin = list(
    file = br,
    old = "    if (is.null(registered(d$id))) {",
    new = "    if (is.null(registered(d$id))) return(FALSE)\n    if (FALSE) {",
    filter = f, blocks = "LTB-0321"
  ),
  r3_package_defaults_block_custom = list(
    file = "R/indicator.R",
    old = "  if (!is.null(default) && exists(name, envir = .ledgr_indicator_registry, inherits = FALSE)) {",
    new = "  if (FALSE) {",
    filter = f, blocks = "LTB-0321"
  ),
  r3_builtin_shadows_custom = list(
    file = br,
    old = "    if (is.null(d$fingerprint) || identical(d$fingerprint, stored_fingerprint(builtin))) {",
    new = "    if (TRUE) {",
    filter = f, blocks = "LTB-0321"
  ),
  r4_probe_last_instrument = list(
    file = fe,
    old = "    i <- which.max(counts)\n",
    new = "    i <- max(which(counts > 0L))\n",
    filter = f, blocks = "LTB-0316"
  ),
  d21_frame_reason_dropped = list(
    file = hf,
    old = "  reason[ready & !is.finite(value)] <- \"calculation_non_finite\"\n",
    new = "",
    filter = f, blocks = "LTB-0319"
  ),
  d21_seam_reason_dropped = list(
    file = fe,
    old = "  missing_reason[calculated$ready & !calculated$calculated] <- \"calculation_non_finite\"\n",
    new = "",
    filter = f, blocks = "LTB-0319"
  )
)
