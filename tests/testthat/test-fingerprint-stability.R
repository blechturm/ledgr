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
  local_fn <- function(x) stats::median(x, na.rm = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }

  pins <- c(
    sma_20 = "7acd8f973292bbb37a08d90e140b64e2f63aadc203aa565bd4b338a2a28b4fec",
    ema_20 = "ab844101bf706073282155ea6b34d2a19a9d253a92364e203a8be9abd4e24eb7",
    rsi_14 = "a45bceb58098c057ae645490983104754c2f6ae538c2e86dc32804b2a70c3273",
    return_5 = "4c20af36633f035ae1eae3de337e6cddd08f7951161251fd13daf8d2a8163a27",
    adapter_r = "29d69fb6245753308dc8100bb8f938a315e02c07c3d4616b2f4699c2944a7824",
    strategy_fn = "260a0f78904346c276fb0918c4ea91ef417b72ea707005a195e232a90585c873",
    feature_engine = "b11921954d7b959b385dd3101cbdac8d4896f3128c8b88bfbc0259c0325df2fa"
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
    ttr_rsi_14 = "8d6b1c7fdb965836a161586e2c9df4a72995ce9756a1fe62861bfa5502ebdbfd",
    ttr_bbands_up_20 = "372ab0f50b5950692a6640019e8a1d94f12c4e511c7eccf441e33a67c521b79c"
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
      "e95c45f270ee5a060034850cf37d947f5b8da74c6ce705af26364623b72747c5",
      "7acd8f973292bbb37a08d90e140b64e2f63aadc203aa565bd4b338a2a28b4fec"
    )
  )
  testthat::expect_identical(
    feature_set_hashes,
    c(
      "e6406699c2f5200b8e0af87474c13124db46965d2ab0fdb1be7edbe5def74b96",
      "7cf0ca39a0d9c5f168e7fae26c060bc4bafc57c1d379c3e3014bd89451744226"
    )
  )
  testthat::expect_identical(
    attr(out, "feature_union"),
    c(
      "7acd8f973292bbb37a08d90e140b64e2f63aadc203aa565bd4b338a2a28b4fec",
      "e95c45f270ee5a060034850cf37d947f5b8da74c6ce705af26364623b72747c5"
    )
  )
  testthat::expect_identical(
    attr(out, "feature_union_hash"),
    "d16cd0d4357c24bbf0f3015362fbd1ba1238938065f68a1c7cc449de1eafc949"
  )
})
