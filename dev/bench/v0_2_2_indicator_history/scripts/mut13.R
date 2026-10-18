f <- "indicator-history-calculation"
mutations <- list(
  d1_ignore_declared_input_carry = list(
    file = "R/indicator.R",
    old = "    input_carry = input_carry,\n    has_series_fn",
    new = "    has_series_fn",
    filter = f, blocks = "LTB-0304"
  ),
  d2_fingerprint_drops_input_carry = list(
    file = "R/features-engine.R",
    old = "      input_carry = declarations$input_carry,\n      tolerance",
    new = "      tolerance",
    filter = f, blocks = "LTB-0304"
  ),
  d3_registered_ttr_accepts_declaration = list(
    file = "R/indicator-ttr.R",
    old = "    if (!is.null(input_carry)) {\n      ledgr_indicator_abort_declaration(",
    new = "    if (FALSE) {\n      ledgr_indicator_abort_declaration(",
    filter = f, blocks = "LTB-0304"
  ),
  d4_redeclared_builtin_certified = list(
    file = "R/history-features.R",
    old = "    if (same_functions &&",
    new = "    if (FALSE &&",
    filter = f, blocks = "LTB-0304"
  )
)
