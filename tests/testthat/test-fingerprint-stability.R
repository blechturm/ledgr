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
    sma_20 = "b4ad728b2fc042225c7ba5d7423d4c1321c38c6d5300a0cf04098d610c13b9bc",
    ema_20 = "ed5d334c60ebec6e23d9b2572e71528b02d9657497cd3f84ca85ad173f07886c",
    rsi_14 = "486e61f755bc773dd751c29c34b1eee31d0a673c5e2d721bb205552c0b975357",
    return_5 = "9e59cad71da4e6ffd035b1783dcc98c38cc9c17318abb21aa21839ca235218ed",
    adapter_r = "ffee226bce01827ed2fe1bc1b33cba7d1f0d95e43198fc72b9be0165207d608f",
    strategy_fn = "bf2bef3c9c4540717f9165a987e62d35033f4af3c706f22014e5ae78ff6393c8",
    feature_engine = "0b51c145bdf4db5573bd14d647251f6c1d92e1752d6a4fb1de8a4e7140b92ef3"
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
    ttr_rsi_14 = "e0a6a07b0c09a68bbbd8d7dd781926a9a54eef1a9a3df51982ac7fbe2aa37d22",
    ttr_bbands_up_20 = "3f4d0d9d7f1de20584f4070fcbac6dce1ecf20bcfcab2458bc90aac74096c92a"
  )

  testthat::expect_identical(observed, pins)
})

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
    features = function(params) list(ledgr_ind_sma(params$n))
  )
  grid <- ledgr_param_grid(short = list(n = 10L), long = list(n = 20L))

  out <- ledgr_sweep(exp, grid, seed = 123L)
  feature_set_hashes <- vapply(out$provenance, `[[`, character(1), "feature_set_hash")

  testthat::expect_identical(out$status, c("DONE", "DONE"))
  testthat::expect_identical(
    unlist(out$feature_fingerprints, use.names = FALSE),
    c(
      "0a63e853ab6575ae4735f06d72943d177a19925573d3758f465a76dedd8de228",
      "b4ad728b2fc042225c7ba5d7423d4c1321c38c6d5300a0cf04098d610c13b9bc"
    )
  )
  testthat::expect_identical(
    feature_set_hashes,
    c(
      "3fca8f891000430d9acb774b9d0eeaf2d499c6d21e20b56efaca635ce3903f89",
      "7f66b2149bc31cb90d63fa3a985d214ebf16cc1d3a0c698b4013ee5a4798091e"
    )
  )
  testthat::expect_identical(
    attr(out, "feature_union"),
    c(
      "0a63e853ab6575ae4735f06d72943d177a19925573d3758f465a76dedd8de228",
      "b4ad728b2fc042225c7ba5d7423d4c1321c38c6d5300a0cf04098d610c13b9bc"
    )
  )
  testthat::expect_identical(
    attr(out, "feature_union_hash"),
    "e5fbf0013f67e30f4d6d4bb75e5fa7c056b3e93ea61f08076575a974da10ee70"
  )
})
