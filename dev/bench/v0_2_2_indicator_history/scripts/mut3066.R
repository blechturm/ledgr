hf <- "R/history-features.R"
calc_filter <- "indicator-history-calculation"
mutations <- list(
  n01_history_as_bounded = list(
    file = hf,
    old = "  rows <- if (identical(declarations$history_class, \"bounded\")) {",
    new = "  rows <- if (TRUE) {",
    filter = calc_filter, blocks = "LTB-0300"
  ),
  n02_bounded_counts_inactive = list(
    file = hf,
    old = "    calc[inputs$expected[calc]]\n  } else {",
    new = "    calc\n  } else {",
    filter = "indicator-history-calculation|availability-features", blocks = "LTB-0300 LTB-0093"
  ),
  n03_fn_gets_stable_after = list(
    file = hf,
    old = "  value <- rep(NA_real_, m)\n  for (k in which(ready)) {\n    value[[k]] <- ledgr_normalize_feature_scalar_output(\n      ledgr_call_feature_fn(def$fn, ledgr_history_feature_window(frame, seq.int(k - width + 1L, k)), params),",
    new = "  value <- rep(NA_real_, m)\n  for (k in which(ready)) {\n    value[[k]] <- ledgr_normalize_feature_scalar_output(\n      ledgr_call_feature_fn(def$fn, ledgr_history_feature_window(frame, seq.int(k - stable_after + 1L, k)), params),",
    filter = calc_filter, blocks = "LTB-0300"
  ),
  n04_returns_consume_carry = list(
    file = hf,
    old = "  fields <- if (identical(declarations$input_carry, \"excluded\")) inputs$raw else inputs$treated",
    new = "  fields <- inputs$treated",
    filter = "indicator-history-calculation|strict-feature-acceleration", blocks = "LTB-0300 LTB-0142"
  ),
  n05_admit_all_fields = list(
    file = hf,
    old = "    lapply(fields, function(x) x[calc]),\n    declarations$required_fields\n  )",
    new = "    lapply(fields, function(x) x[calc]),\n    ledgr_indicator_default_required_fields()\n  )",
    filter = "indicator-history-calculation|strict-feature-acceleration", blocks = "LTB-0300 LTB-0142"
  ),
  n06_join_segments_across_gaps = list(
    file = hf,
    old = "  runs <- ledgr_history_feature_runs(available_all[rows])",
    new = "  runs <- ledgr_history_feature_runs(inputs$expected[rows])",
    filter = calc_filter, blocks = "LTB-0300"
  ),
  n07_drop_parity_check = list(
    file = hf,
    old = "    if (identical(cert$certification, \"custom\") &&\n        identical(declarations$history_class, \"bounded\")) {",
    new = "    if (FALSE) {",
    filter = calc_filter, blocks = "LTB-0300 LTB-0302"
  ),
  n08_parity_ignores_tolerance = list(
    file = hf,
    old = "        } else if (tolerance > 0) {",
    new = "        } else if (FALSE) {",
    filter = calc_filter, blocks = "LTB-0300"
  ),
  n09_refute_history_pair = list(
    file = hf,
    old = "    if (identical(cert$certification, \"custom\") &&\n        identical(declarations$history_class, \"bounded\")) {",
    new = "    if (identical(cert$certification, \"custom\") && is.function(def$fn)) {",
    filter = calc_filter, blocks = "LTB-0300"
  ),
  n10_final_cutoff_masks = list(
    file = hf,
    old = "    starts <- c(starts, position[lagged])",
    new = "    starts <- starts",
    filter = calc_filter, blocks = "LTB-0303"
  ),
  n11_ignore_lifetime_mask = list(
    file = hf,
    old = "  expected <- as.logical(ledgr_history_substrate_expected_at(\n    substrate, cutoff, prefix, instrument_idx\n  )[1L, ])",
    new = "  expected <- rep(TRUE, prefix_end)",
    filter = "indicator-history-calculation|availability-features", blocks = "LTB-0300 LTB-0093"
  ),
  n12_output_carry_on_not_ready = list(
    file = hf,
    old = "      eligible_gap = inputs$expected[calc] & !available_all[calc],",
    new = "      eligible_gap = inputs$expected[calc],",
    filter = calc_filter, blocks = "LTB-0301"
  ),
  n13_first_blocking_field_only = list(
    file = "R/indicator-history.R",
    old = "    blocking[blocked] <- ifelse(\n      nzchar(blocking[blocked]),\n      paste(blocking[blocked], field, sep = \",\"),\n      field\n    )",
    new = "    blocking[blocked & !nzchar(blocking)] <- field",
    filter = "indicator-history", blocks = "LTB-0301"
  ),
  n14_sweep_payload_mispaired = list(
    file = "R/history-substrate.R",
    old = "      feature_id = unique_defs[[d]]$id,",
    new = "      feature_id = unique_defs[[length(unique_defs) + 1L - d]]$id,",
    filter = calc_filter, blocks = "LTB-0302"
  ),
  n15_sma_rowmeans = list(
    file = "R/features-engine.R",
    old = "  out[ends] <- vapply(ends, function(i) {\n    mean(values[seq.int(i - width + 1L, i)])\n  }, numeric(1))",
    new = "  out[ends] <- rowMeans(embed(values, width))",
    filter = "strict-feature-acceleration", blocks = "LTB-0142"
  ),
  n16_certify_without_identity = list(
    file = hf,
    old = "    if (claimed %in% identities) {",
    new = "    if (TRUE) {",
    filter = "strict-feature-acceleration", blocks = "LTB-0143"
  ),
  n17_ttr_call_per_output = list(
    file = hf,
    old = "  if (identical(cert$kind, \"ttr\") && is.environment(cache)) {",
    new = "  if (FALSE) {",
    filter = "strict-ttr-cleanup", blocks = "LTB-0276"
  ),
  n18_certified_runs_own_functions = list(
    file = hf,
    old = "        def = canonical,\n        declarations = canonical_declarations,",
    new = "        def = utils::modifyList(canonical, list(fn = def$fn, series_fn = def$series_fn)),\n        declarations = canonical_declarations,",
    filter = "strict-feature-acceleration|strict-ttr-cleanup", blocks = "LTB-0143 LTB-0276"
  ),
  n19_ignore_history_policy = list(
    file = hf,
    old = "      max_sessions = policy$price_carry,\n      carry_allowed = !is.null(policy$price_carry),",
    new = "      max_sessions = 5L,\n      carry_allowed = TRUE,",
    filter = "indicator-history-calculation|availability-features", blocks = "LTB-0300 LTB-0073"
  ),
  n20_certify_per_instrument = list(
    file = hf,
    old = "    ranges <- ledgr_history_feature_ranges(substrate, i, bounds$from, bounds$to)",
    new = "    certified <- lapply(definitions, ledgr_feature_certify)\n    ranges <- ledgr_history_feature_ranges(substrate, i, bounds$from, bounds$to)",
    filter = "strict-dispatch-hoist", blocks = "LTB-0157"
  ),
  n21_duplicate_segment_pass = list(
    file = hf,
    old = "    segment_value <- ledgr_history_feature_segment(cert, inputs, fields, segment, cache)",
    new = "    segment_value <- ledgr_history_feature_segment(cert, inputs, fields, segment, cache)\n    segment_value <- ledgr_history_feature_segment(cert, inputs, fields, segment, cache)",
    filter = "long-window", blocks = "LTB-0153"
  ),
  n22_refuse_history_dependent = list(
    file = "R/availability-policy.R",
    old = "    ledgr_feature_def_declarations(indicator)",
    new = "    if (!identical(ledgr_feature_def_declarations(indicator)$history_class, \"bounded\")) stop(\"refused\")",
    filter = "availability-features", blocks = "LTB-0074"
  )
)
