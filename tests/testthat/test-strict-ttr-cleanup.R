workstream37_close <- function(n = 12L) {
  100 + seq_len(n) + sin(seq_len(n))
}

workstream37_clone_function <- function(fn, env) {
  out <- fn
  environment(out) <- env
  out
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0276] strict TTR cleanup is exact and provenance-bounded", {
  testthat::skip_if_not_installed("TTR")
  # V12 Section 6: every registered TTR catalogue row is computed with the
  # package constructor's functions once per contiguous segment and is
  # certified by package tests, not by runtime refutation. A TTR-labelled
  # definition that is not a catalogue row follows the custom rules.
  close <- workstream37_close()
  gapped_close <- replace(close, c(1L, 7L, 12L), NA_real_)
  strict <- ledgr_history_policy(price_carry = NULL)
  dense <- ws43_history_substrate(close, policy = strict)
  gapped <- ws43_history_substrate(gapped_close, policy = strict)
  ttr <- ledgr:::ledgr_precompute_feature_def_from_indicator(
    ledgr_ind_ttr("SMA", input = "close", n = 3L)
  )
  certified <- ledgr:::ledgr_feature_certify(ttr)
  testthat::expect_identical(certified$certification, "catalogue")
  testthat::expect_identical(certified$declarations$history_class, "bounded")

  segment_oracle <- function(x, segments) {
    out <- rep(NA_real_, length(x))
    for (segment in segments) out[segment] <- as.numeric(TTR::SMA(x[segment], n = 3L))
    out
  }
  testthat::expect_identical(ws43_feature_values(dense, ttr), segment_oracle(close, list(1:12)))
  testthat::expect_identical(
    ws43_feature_values(gapped, ttr),
    segment_oracle(gapped_close, list(2:6, 8:11))
  )

  # Catalogue rows call TTR once per segment, never once per window.
  original_ttr_call <- ledgr:::ledgr_ttr_call
  original_raw_call <- ledgr:::ledgr_ttr_raw_call
  ttr_calls <- 0L
  testthat::local_mocked_bindings(
    ledgr_ttr_raw_call = function(...) {
      ttr_calls <<- ttr_calls + 1L
      original_raw_call(...)
    },
    .package = "ledgr"
  )
  # Certification constructs the canonical row once (one TTR validation
  # call); each segment then costs exactly one call. The sampled causality
  # check (LDG-3067, v12 Section 6) adds a fixed cost, not a per-window
  # one: the probe recomputes each segment once and each sampled prefix
  # whose final segment is new costs one call (dense: 1 + 4 sampled
  # sessions 3, 5, 8 and 11; gapped: 2 + sessions 4, 5 and 10, while the
  # session-11 prefix reuses the full second segment).
  ws43_feature_values(dense, ttr)
  dense_calls <- ttr_calls
  ttr_calls <- 0L
  ws43_feature_values(gapped, ttr)
  testthat::expect_identical(c(dense_calls, ttr_calls), c(2L + 5L, 3L + 5L))
  # The outputs of one multi-output call share one TTR call per segment;
  # each certification still validates its own constructor once. The
  # causality probe shares its calls across the outputs too: 2 for its
  # segments and 1 for the only new sampled prefix (session 5; sessions 6
  # and 11 end where the full segments end).
  macd <- ledgr:::ledgr_indicator_bundle_indicators(ledgr_ind_ttr_outputs(
    "MACD", input = "close", nFast = 2L, nSlow = 3L, nSig = 2L
  ))
  ttr_calls <- 0L
  shared <- ledgr:::ledgr_history_compute_feature_series(gapped, macd)
  testthat::expect_identical(ttr_calls, 3L + 2L + 3L)
  for (output in seq_along(macd)) {
    testthat::expect_identical(
      as.numeric(shared[[output]][1L, ]),
      ws43_feature_values(gapped, macd[[output]])
    )
  }

  # A TTR-labelled custom definition is refuted against its own fn.
  hand_built <- ledgr_indicator(
    id = "hand_built_ttr_label",
    fn = function(window, params) mean(window$close) + 1,
    series_fn = function(bars, params) {
      as.numeric(stats::filter(bars$close, rep(1 / 3, 3), sides = 1))
    },
    requires_bars = 3L,
    params = ttr$params,
    source = "TTR",
    gap_contract = "strict_window"
  )
  hand_built <- ledgr:::ledgr_precompute_feature_def_from_indicator(hand_built)
  testthat::expect_identical(ledgr:::ledgr_feature_certify(hand_built)$certification, "custom")
  testthat::expect_error(
    ws43_feature_values(dense, hand_built),
    class = "ledgr_indicator_gap_parity"
  )

  # Definitions that claim the catalogue identity but carry a different body,
  # a different enclosing environment, distinct environments or a shadowed
  # call symbol are computed with the canonical functions: the replaced code
  # never runs and the values equal the catalogue row.
  canonical_values <- ws43_feature_values(dense, ttr)
  mismatched_body <- ttr
  mismatched_body_env <- new.env(parent = asNamespace("ledgr"))
  mismatched_body$fn <- workstream37_clone_function(ttr$fn, mismatched_body_env)
  body(mismatched_body$fn) <- quote(stop("replaced fn must not run"))
  mismatched_body$series_fn <- workstream37_clone_function(ttr$series_fn, mismatched_body_env)
  body(mismatched_body$series_fn) <- quote(stop("replaced series_fn must not run"))
  non_namespace_parent <- new.env(parent = asNamespace("ledgr"))
  wrong_parent_env <- new.env(parent = non_namespace_parent)
  wrong_parent <- ttr
  wrong_parent$fn <- workstream37_clone_function(ttr$fn, wrong_parent_env)
  wrong_parent$series_fn <- workstream37_clone_function(ttr$series_fn, wrong_parent_env)
  distinct <- ttr
  distinct$series_fn <- workstream37_clone_function(
    distinct$series_fn,
    new.env(parent = asNamespace("ledgr"))
  )
  shadow_calls <- 0L
  shadow_env <- new.env(parent = asNamespace("ledgr"))
  assign("ledgr_ttr_call", function(...) {
    shadow_calls <<- shadow_calls + 1L
    original_ttr_call(...)
  }, envir = shadow_env)
  shadowed <- ttr
  shadowed$fn <- workstream37_clone_function(ttr$fn, shadow_env)
  shadowed$series_fn <- workstream37_clone_function(ttr$series_fn, shadow_env)
  for (case in list(mismatched_body, wrong_parent, distinct, shadowed)) {
    testthat::expect_identical(ledgr:::ledgr_feature_certify(case)$certification, "catalogue")
    testthat::expect_identical(ws43_feature_values(dense, case), canonical_values)
  }
  testthat::expect_identical(shadow_calls, 0L)

  # Recomputing the claimed identity from the replaced functions removes the
  # catalogue claim, so the replaced code is then refuted as custom code.
  recomputed <- mismatched_body
  recomputed$fingerprint <- NULL
  body(recomputed$fn) <- quote(mean(window$close) + 1)
  body(recomputed$series_fn) <- quote(as.numeric(stats::filter(bars$close, rep(1 / 3, 3), sides = 1)))
  testthat::expect_identical(ledgr:::ledgr_feature_certify(recomputed)$certification, "custom")
  testthat::expect_error(
    ws43_feature_values(dense, recomputed),
    class = "ledgr_indicator_gap_parity"
  )

  for (indicator in list(
    ledgr_ind_ttr("EMA", input = "close", n = 3L),
    ledgr_ind_ttr("RSI", input = "close", n = 3L),
    ledgr_ind_ttr(
      "MACD",
      input = "close",
      output = "macd",
      nFast = 2L,
      nSlow = 3L,
      nSig = 2L
    )
  )) {
    testthat::expect_null(indicator$gap_contract)
    testthat::expect_identical(indicator$history_class, "history_dependent")
  }

  runtime_source <- paste(deparse(body(ledgr:::ledgr_run_fold_impl)), collapse = "\n")
  sweep_source <- paste(deparse(body(ledgr:::ledgr_sweep_impl)), collapse = "\n")
  payload_source <- paste(deparse(body(ledgr:::ledgr_history_precompute_payload)), collapse = "\n")
  testthat::expect_match(runtime_source, "ledgr_history_compute_feature_series", fixed = TRUE)
  testthat::expect_match(payload_source, "ledgr_history_compute_feature_series", fixed = TRUE)
  testthat::expect_match(sweep_source, "ledgr_history_precompute_payload", fixed = TRUE)
  testthat::expect_match(sweep_source, "feature_engine_version", fixed = TRUE)
  testthat::expect_no_match(
    paste(deparse(body(ledgr:::ledgr_precompute_payload)), collapse = "\n"),
    "availability",
    fixed = TRUE
  )

  under_covr <- requireNamespace("covr", quietly = TRUE) && covr::in_covr()
  if (!under_covr) {
    testthat::expect_identical(
      ledgr:::ledgr_feature_engine_version(FALSE),
      "80d1ae6d2165196044db3f0d1944d69f21b76e264d2df16df49e23f448a7c681"
    )
    testthat::expect_identical(
      ledgr:::ledgr_feature_engine_version(TRUE),
      "4b2bb8e6989d77ef7fdd4fd2c0738340e97786724826951af1ddb47cb2a005a9"
    )
  }
})
