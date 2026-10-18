# WS43 Correction 3 mutations (re-review 2 findings S1 and S2); run with
# scripts/mutate.R.
f <- "indicator-dispatch|indicator-evidence"
mutations <- list(
  s1_reach_is_requires_bars = list(
    file = "R/history-frame.R",
    old = "  reach <- suppressWarnings(as.integer(c(definition$requires_bars, definition$stable_after)))",
    new = "  reach <- suppressWarnings(as.integer(definition$requires_bars))",
    filter = f, blocks = "LTB-0322"
  ),
  s2_run_writes_registry = list(
    file = "R/backtest-config.R",
    old = "  attr(config, \"ledgr_feature_indicators\") <- ledgr_feature_indicator_index(features)\n",
    new = paste0(
      "  attr(config, \"ledgr_feature_indicators\") <- ledgr_feature_indicator_index(features)\n",
      "  for (feat in features) if (inherits(feat, \"ledgr_indicator\")) ledgr_indicator_register(feat, overwrite = TRUE)\n"
    ),
    filter = f, blocks = "LTB-0321"
  ),
  s2_dispatch_ignores_own_definitions = list(
    file = "R/backtest-runner.R",
    old = "    own <- feature_indicators[[id]]\n",
    new = "    own <- NULL\n",
    filter = f, blocks = "LTB-0321"
  ),
  s2_conflicting_definitions_accepted = list(
    file = "R/indicator.R",
    old = "      if (!identical(logic(existing), logic(feat))) {",
    new = "      if (FALSE) {",
    filter = f, blocks = "LTB-0321"
  )
)
