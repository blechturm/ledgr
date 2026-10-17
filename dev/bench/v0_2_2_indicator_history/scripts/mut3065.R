f <- "indicator-history"
mutations <- list(
  m01_default_bounded = list(
    file = "R/indicator-history.R",
    old = "      \"bounded\"\n    } else {\n      \"history_dependent\"\n    }\n  }\n  if (is.null(history_source)) {",
    new = "      \"bounded\"\n    } else {\n      \"bounded\"\n    }\n  }\n  if (is.null(history_source)) {",
    filter = f, blocks = "LTB-0297"
  ),
  m02_no_contradiction = list(
    file = "R/indicator-history.R",
    old = "  if (identical(gap_contract, \"strict_window\") &&\n      identical(history_class, \"history_dependent\")) {",
    new = "  if (FALSE) {",
    filter = f, blocks = "LTB-0297"
  ),
  m03_admission_all_fields = list(
    file = "R/indicator-history.R",
    old = "  for (field in required_fields) {\n    value <- as.numeric(fields[[field]])",
    new = "  for (field in intersect(ledgr_indicator_bar_fields(), names(fields))) {\n    value <- as.numeric(fields[[field]])",
    filter = f, blocks = "LTB-0297"
  ),
  m04_unregistered_inherits = list(
    file = "R/indicator-ttr.R",
    old = "      return(variant)\n    }\n  }\n  NULL\n}",
    new = "      return(variant)\n    }\n  }\n  \"default\"\n}",
    filter = f, blocks = "LTB-0297"
  ),
  m05_tolerance_unchecked = list(
    file = "R/indicator-history.R",
    old = "  if (tolerance > 0 &&\n      (!identical(history_class, \"bounded\") || !isTRUE(has_series_fn))) {",
    new = "  if (FALSE) {",
    filter = f, blocks = "LTB-0297"
  ),
  m06_aroon_width_n = list(
    file = "R/indicator-ttr.R",
    old = "    aroon = integer_arg(\"n\") + 1L,",
    new = "    aroon = integer_arg(\"n\"),",
    filter = f, blocks = "LTB-0298"
  ),
  m07_ema_declared_bounded = list(
    file = "R/indicator-history.R",
    old = "    row(\"TTR\", \"EMA\", \"value\", \"default\", \"history_dependent\", close, \"eligible\", \"n\"),",
    new = "    row(\"TTR\", \"EMA\", \"value\", \"default\", \"bounded\", close, \"eligible\", \"n\"),",
    filter = f, blocks = "LTB-0298"
  ),
  m08_sma_declared_history = list(
    file = "R/indicator-history.R",
    old = "    row(\"TTR\", \"SMA\", \"value\", \"default\", \"bounded\", close, \"eligible\", \"n\"),",
    new = "    row(\"TTR\", \"SMA\", \"value\", \"default\", \"history_dependent\", close, \"eligible\", \"n\"),",
    filter = f, blocks = "LTB-0298"
  ),
  m09_fp_drop_required = list(
    file = "R/features-engine.R",
    old = "      required_fields = declarations$required_fields,\n      input_carry = declarations$input_carry,",
    new = "      input_carry = declarations$input_carry,",
    filter = f, blocks = "LTB-0299"
  ),
  m10_fp_drop_tolerance = list(
    file = "R/features-engine.R",
    old = "      tolerance = declarations$tolerance,\n      history_semantics",
    new = "      history_semantics",
    filter = f, blocks = "LTB-0299"
  ),
  m11_fp_drop_carry = list(
    file = "R/features-engine.R",
    old = "      input_carry = declarations$input_carry,\n      tolerance",
    new = "      tolerance",
    filter = f, blocks = "LTB-0299"
  ),
  m12_fp_drop_class = list(
    file = "R/features-engine.R",
    old = "      history_class = declarations$history_class,\n      gap_behavior = declarations$gap_behavior,",
    new = "",
    filter = f, blocks = "LTB-0299"
  ),
  m13_fp_display_source = list(
    file = "R/features-engine.R",
    old = "      history_semantics = \"expected_sessions_cutoff_causal\"\n    )),",
    new = "      history_semantics = \"expected_sessions_cutoff_causal\",\n      history_source = declarations$history_source\n    )),",
    filter = f, blocks = "LTB-0299"
  ),
  m14_config_drop_declarations = list(
    file = "R/backtest-config.R",
    old = "            def$required_fields <- declarations$required_fields\n",
    new = "",
    filter = f, blocks = "LTB-0299"
  )
)
