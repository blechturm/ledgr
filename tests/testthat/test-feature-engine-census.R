# Cut 22 decision 5: the feature engine version binds every semantic helper of
# the census (dev/feature_parity/census.csv proves each row by replacement);
# these blocks keep the representative proofs in the package suite.

feature_engine_version_with <- function(helper, replacement = function(...) stop("replaced")) {
  env <- new.env(parent = asNamespace("ledgr"))
  assign(helper, replacement, envir = env)
  version <- ledgr:::ledgr_feature_engine_version
  environment(version) <- env
  version()
}

# ledgr-test-profile: fast
testthat::test_that("feature engine version moves with value, evidence, refusal and representation code", {
  base <- ledgr:::ledgr_feature_engine_version()
  for (helper in c(
    "ledgr_strict_sma_series",               # a value
    "ledgr_feature_plane_exceptions",        # evidence planes
    "ledgr_history_feature_refuse_lookahead", # a refusal
    "ledgr_projection_from_payload",         # the prepared representation
    "ledgr_history_lifetime_segments"        # a shared history producer (cut review 22, R2)
  )) {
    testthat::expect_false(identical(feature_engine_version_with(helper), base), info = helper)
  }
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("a reader-only change leaves the engine version and an explicit precompute valid", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:7)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    opening = ledgr_opening(cash = 100000), snapshot = snapshot,
    strategy = function(ctx, params) ctx$flat(), universe = c("AAA", "BBB"),
    features = list(ledgr_ind_sma(3)), cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(a = list(strategy = list(qty = 1)))
  precomputed <- ledgr_precompute_features(exp, grid)
  base <- ledgr:::ledgr_feature_engine_version()
  # The evidence decoder reads prepared planes; it prepares nothing.
  for (helper in c("ledgr_history_feature_evidence", "ledgr_history_feature_compact",
                   "ledgr_history_plane_lookup", "ledgr_history_plane_run",
                   "ledgr_history_feature_planes", "ledgr_history_substrate_terminal_at")) {
    testthat::expect_identical(feature_engine_version_with(helper), base, info = helper)
  }
  testthat::local_mocked_bindings(
    ledgr_history_feature_evidence = function(...) stop("changed decoder"),
    # The bar-history reader of the terminal plane (close review round 1, F2).
    ledgr_history_substrate_terminal_at = function(...) stop("changed reader"),
    .package = "ledgr"
  )
  testthat::expect_identical(ledgr:::ledgr_feature_engine_version(), base)
  testthat::expect_silent(ledgr:::ledgr_validate_precomputed_features(precomputed, exp, grid))
})

# ledgr-test-profile: fast
testthat::test_that("a fingerprint-helper change that recertifies a catalogue claim moves the engine version", {
  testthat::skip_if_not_installed("TTR")
  # Close review round 1, F1: a supported TTR SMA claim with replaced
  # constant callbacks is certified as the catalogue row only through the
  # fingerprint helper; changing that helper changes prepared values under the
  # same active feature fingerprint, so the engine version must move.
  forged <- ledgr:::ledgr_precompute_feature_def_from_indicator(
    ledgr_ind_ttr("SMA", input = "close", n = 3L, id = "forged_sma")
  )
  forged$fn <- function(window, params) 0
  forged$series_fn <- function(bars, params) rep(0, nrow(bars))
  substrate <- ws43_history_substrate(100 + seq_len(12) + sin(seq_len(12)))
  base_version <- ledgr:::ledgr_feature_engine_version()
  base_fingerprint <- ledgr:::ledgr_active_feature_fingerprint(forged)
  testthat::expect_identical(ledgr:::ledgr_feature_certify(forged)$certification, "catalogue")
  before <- ws43_feature_values(substrate, forged)
  original <- ledgr:::ledgr_function_fingerprint
  testthat::local_mocked_bindings(
    ledgr_function_fingerprint = function(...) digest::digest(original(...), algo = "sha256"),
    .package = "ledgr"
  )
  testthat::expect_identical(ledgr:::ledgr_feature_certify(forged)$certification, "custom")
  testthat::expect_false(identical(ws43_feature_values(substrate, forged), before))
  testthat::expect_identical(ledgr:::ledgr_active_feature_fingerprint(forged), base_fingerprint)
  testthat::expect_false(identical(ledgr:::ledgr_feature_engine_version(), base_version))
})
