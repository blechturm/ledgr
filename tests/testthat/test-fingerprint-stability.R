ledgr_fingerprint_test_bars <- function() {
  data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    instrument_id = "AAA",
    open = 100:105,
    high = 101:106,
    low = 99:104,
    close = 100:105,
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("core indicator fingerprints remain stable", {
  testthat::skip_if(
    requireNamespace("covr", quietly = TRUE) && covr::in_covr(),
    "Core fingerprint pins are normal-runtime invariants; covr instruments closures."
  )

  local_fn <- function(x) stats::median(x, na.rm = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }

  pins <- c(
    sma_20 = "722be865c97f7cc5d2aa85b95d7ceef74959da6c754d643cde2063ed5d0366a0",
    ema_20 = "74dfc14203e87304e4a819c47f4ae45cc743723b940e3f6022bd5dd33d655fe9",
    rsi_14 = "bc3a58bbd1657d24ebb73b2b8141e392a8989c0391677b0b0a9865773e72e092",
    return_5 = "d3feff6aeb660729888928583c4cf36150a66dba0053ab944783e064f090d9cb",
    adapter_r = "1db65a21158519f20fed668b45dcedf54cd076c94af7f3c8fb7789dadc675508",
    strategy_fn = "bf2bef3c9c4540717f9165a987e62d35033f4af3c706f22014e5ae78ff6393c8",
    feature_engine = "80d1ae6d2165196044db3f0d1944d69f21b76e264d2df16df49e23f448a7c681"
  )

  observed <- c(
    sma_20 = ledgr:::ledgr_indicator_fingerprint(ledgr_ind_sma(20)),
    ema_20 = ledgr:::ledgr_indicator_fingerprint(ledgr_ind_ema(20)),
    rsi_14 = ledgr:::ledgr_indicator_fingerprint(ledgr_ind_rsi(14)),
    return_5 = ledgr:::ledgr_indicator_fingerprint(ledgr_ind_returns(5)),
    adapter_r = ledgr:::ledgr_indicator_fingerprint(
      ledgr_adapter_r(local_fn, id = "median_close", requires_bars = 3)
    ),
    strategy_fn = ledgr:::ledgr_function_fingerprint(
      strategy,
      include_captures = FALSE,
      label = "`strategy`",
      allow_rng = TRUE
    ),
    feature_engine = ledgr:::ledgr_feature_engine_version()
  )

  testthat::expect_identical(observed, pins)
  testthat::expect_identical(ledgr_feature_id(list(
    ledgr_ind_sma(20),
    ledgr_ind_ema(20),
    ledgr_ind_rsi(14),
    ledgr_ind_returns(5)
  )), c("sma_20", "ema_20", "rsi_14", "return_5"))
})

testthat::test_that("[LTB-0105] scalar helpers enter feature-engine identity", {
  baseline <- ledgr:::ledgr_feature_engine_version()
  changed_window <- local({
    testthat::local_mocked_bindings(
      ledgr_compute_feature_scalar_at = function(...) -1,
      .package = "ledgr"
    )
    ledgr:::ledgr_feature_engine_version()
  })
  changed_normalizer <- local({
    testthat::local_mocked_bindings(
      ledgr_normalize_feature_scalar_output = function(...) -2,
      .package = "ledgr"
    )
    ledgr:::ledgr_feature_engine_version()
  })

  testthat::expect_false(identical(changed_window, baseline))
  testthat::expect_false(identical(changed_normalizer, baseline))
})

# ledgr-test-profile: review
testthat::test_that("TTR indicator fingerprints remain stable by TTR version", {
  testthat::skip_if(
    requireNamespace("covr", quietly = TRUE) && covr::in_covr(),
    "TTR fingerprint pins are normal-runtime invariants; covr instruments closures."
  )

  testthat::skip_if_not_installed("TTR")
  testthat::skip_if_not(
    identical(as.character(utils::packageVersion("TTR")), "0.24.4"),
    "TTR fingerprint pins are version-conditional and recorded for TTR 0.24.4."
  )

  observed <- c(
    ttr_rsi_14 = ledgr:::ledgr_indicator_fingerprint(
      ledgr_ind_ttr("RSI", input = "close", n = 14)
    ),
    ttr_bbands_up_20 = ledgr:::ledgr_indicator_fingerprint(
      ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
    )
  )
  pins <- c(
    ttr_rsi_14 = "8670b3cd92078b67319bda000591f3d8bc0c176d229fcc6310aadc590501eae6",
    ttr_bbands_up_20 = "fb7649a1cb8d1c2668d0a98ff637e8797367f8299c8ea0136c26301222324aae"
  )

  testthat::expect_identical(observed, pins)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("feature-factory sweep identity remains stable", {
  testthat::skip_if(
    requireNamespace("covr", quietly = TRUE) && covr::in_covr(),
    "Feature-factory fingerprint pins are normal-runtime invariants; covr instruments closures."
  )

  snapshot <- ledgr_snapshot_from_df(ledgr_fingerprint_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    value <- ctx$feature("AAA", paste0("sma_", params$n))
    if (!is.na(value) && value > 0) {
      targets["AAA"] <- params$n
    }
    targets
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    features = function(params) list(ledgr_ind_sma(params$n)),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_grid_named(short = list(strategy = list(n = 10L)), long = list(strategy = list(n = 20L)))

  out <- ledgr_sweep(exp, grid, seed = 123L)
  feature_set_hashes <- vapply(out$provenance, `[[`, character(1), "feature_set_hash")

  testthat::expect_identical(out$status, c("DONE", "DONE"))
  testthat::expect_identical(
    unlist(out$feature_fingerprints, use.names = FALSE),
    c(
      "638fc7be8fb9fa707dc42739a571e55dd4d06da3439c673efce25fe11bbb70d7",
      "722be865c97f7cc5d2aa85b95d7ceef74959da6c754d643cde2063ed5d0366a0"
    )
  )
  testthat::expect_identical(
    feature_set_hashes,
    c(
      "ec1b4b596232f550fef2354b08230dcbebd52dba16b618a15be28c4bcba34c1f",
      "790156753ee13f87911742cd1a70cfcf05124271e95c0f352b4ca10370601860"
    )
  )
  testthat::expect_identical(
    attr(out, "feature_union"),
    c(
      "638fc7be8fb9fa707dc42739a571e55dd4d06da3439c673efce25fe11bbb70d7",
      "722be865c97f7cc5d2aa85b95d7ceef74959da6c754d643cde2063ed5d0366a0"
    )
  )
  testthat::expect_identical(
    attr(out, "feature_union_hash"),
    "f7026cd02411bdc7b52beab150390fc3facb90a9dd7c5c0b419ac4ddee22ee69"
  )
})
