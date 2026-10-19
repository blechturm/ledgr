# LDG-3067 source-copy mutations (run with scripts/mutate.R).
f <- "indicator-causality"
check_call <- "  ledgr_history_feature_causality(substrate, certified, bounds, calculated_count, out)\n  out\n}"
mutations <- list(
  c1_remove_prefix_check = list(
    file = "R/history-features.R",
    old = check_call,
    new = "  out\n}",
    filter = f, blocks = c("LTB-0315", "LTB-0316", "LTB-0317")
  ),
  c2_move_check_after_artifacts = list(
    # The check leaves preparation and runs only when per-instrument evidence
    # is read after a run, sweep or precompute.
    edits = list(
      list(file = "R/history-features.R", old = check_call, new = "  out\n}"),
      list(
        file = "R/history-features.R",
        old = "    cert, inputs, bounds$from, substrate$history_policy$output_carry\n  )\n  declarations <- cert$declarations",
        new = paste0(
          "    cert, inputs, bounds$from, substrate$history_policy$output_carry\n  )\n",
          "  ledgr_history_feature_check_definition(cert, list(list(start = bounds$from, ",
          "end = prefix_end, inputs = inputs, cache = NULL)), bounds$from, calculated$raw)\n",
          "  declarations <- cert$declarations"
        )
      )
    ),
    filter = f, blocks = "LTB-0315"
  ),
  c3_weaken_to_missingness = list(
    file = "R/history-features.R",
    old = "    if (!identical(prefix$raw[[k]], prepared[[k]])) {",
    new = "    if (!identical(is.na(prefix$raw[[k]]), is.na(prepared[[k]]))) {",
    filter = f, blocks = "LTB-0315"
  ),
  c4_all_prefixes = list(
    file = "R/history-features.R",
    old = "  unique(c(1L, as.integer(ceiling(n * c(1, 2) / 3)), n))",
    new = "  seq_len(n)",
    filter = f, blocks = "LTB-0316"
  ),
  c5_remove_refutation = list(
    file = "R/history-features.R",
    old = "  if (!identical(cert$certification, \"custom\") ||",
    new = "  if (TRUE ||",
    filter = paste0(f, "|indicator-history-calculation"),
    blocks = c("LTB-0317", "LTB-0310", "LTB-0312")
  ),
  c6_refute_history_dependent = list(
    file = "R/history-features.R",
    old = "      !identical(declarations$history_class, \"bounded\") ||",
    new = "      FALSE ||",
    filter = f, blocks = "LTB-0317"
  ),
  c7_refute_catalogue_at_runtime = list(
    file = "R/history-features.R",
    old = "  if (!identical(cert$certification, \"custom\") ||",
    new = "  if (FALSE ||",
    filter = f, blocks = "LTB-0317"
  ),
  c8_ignore_tolerance = list(
    file = "R/history-features.R",
    old = "    } else if (tolerance > 0) {\n      abs(scalar - series)",
    new = "    } else if (FALSE) {\n      abs(scalar - series)",
    filter = f, blocks = "LTB-0317"
  ),
  c9_fn_window_not_exact = list(
    file = "R/history-features.R",
    old = "ledgr_history_feature_window(frame, seq.int(k - width + 1L, k)), params),",
    new = "ledgr_history_feature_window(frame, seq.int(max(1L, k - width), k)), params),",
    filter = f, blocks = "LTB-0315"
  ),
  c10_fn_handed_future_row = list(
    file = "R/history-features.R",
    old = "ledgr_history_feature_window(frame, seq.int(k - width + 1L, k)), params),",
    new = "ledgr_history_feature_window(frame, seq.int(k - width + 1L + (k < m), k + (k < m))), params),",
    filter = f, blocks = "LTB-0315"
  )
)
