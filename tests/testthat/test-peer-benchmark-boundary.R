peer_stage_l_harness_path <- testthat::test_path(
  "..", "..", "dev", "bench", "peer_benchmark", "peer_benchmark.R"
)
peer_stage_l_harness <- if (file.exists(peer_stage_l_harness_path)) {
  local({
    env <- new.env(parent = globalenv())
    sys.source(peer_stage_l_harness_path, envir = env)
    env
  })
} else {
  NULL
}

peer_stage_l_require_harness <- function() {
  testthat::skip_if(
    is.null(peer_stage_l_harness),
    "Peer benchmark sources are unavailable during installed-package tests."
  )
}

testthat::test_that("Stage L freezes prerequisite source hash", {
  root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  availability_path <- file.path(root, "R", "availability-ingest.R")
  testthat::skip_if_not(
    file.exists(availability_path),
    "Availability source is unavailable during installed-package tests."
  )
  testthat::expect_identical(
    ledgr_stage_l_normalized_source_sha256(availability_path),
    unname(ledgr_stage_l_source_sha256[["availability_ingest"]])
  )
})

testthat::test_that("Stage L freezes optimization oracles", {
  axis <- as.POSIXct(
    c("2020-01-01 00:00:00", "2020-01-02 00:00:00"),
    tz = "UTC"
  )
  bars <- list(
    A = data.frame(ts_utc = axis),
    B = data.frame(ts_utc = axis)
  )
  testthat::expect_identical(
    ledgr_precompute_ts_key(axis),
    as.numeric(axis)
  )
  testthat::expect_identical(
    ledgr_precompute_validate_static_coverage(bars, c("A", "B")),
    ledgr_stage_l_validate_static_coverage_oracle(bars, c("A", "B"))
  )
  testthat::expect_identical(
    ledgr_snapshot_hash_format_ts_utc(axis),
    ledgr_stage_l_snapshot_hash_ts_oracle(axis)
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0016] public sweep benchmark boundary is executable", {
  peer_stage_l_require_harness()
  testthat::skip_if_not_installed("TTR")
  bars <- as.data.frame(ledgr_sim_bars(
    n_instruments = 2L,
    n_days = 25L,
    seed = 2741L,
    instrument_prefix = "STAGE_L_"
  ))
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(bars, path, row.names = FALSE)
  features <- ledgr_feature_map(
    fast = peer_stage_l_harness$peer_sma_ttr("fast", 2L),
    slow = peer_stage_l_harness$peer_sma_ttr("slow", 4L)
  )
  result <- peer_stage_l_harness$peer_run_ledgr_sweep_with_oracle(
    engine = "ledgr_ttr_canonical_sweep",
    bars_path = path,
    features = features,
    strategy = peer_stage_l_harness$peer_strategy("fast", "slow"),
    seed = 2741L
  )
  testthat::expect_identical(result$status, "DONE")
  testthat::expect_identical(
    result$metadata$measurement_surface,
    "public_one_candidate_ledgr_sweep_v002"
  )
  testthat::expect_true(result$metadata$parity_oracle_outside_clock)
  testthat::expect_true(is.finite(result$wall_sec))
  testthat::expect_true(result$metadata$parity_oracle_wall_sec >= 0)
})

testthat::test_that("memory parity reference reports residuals and fails loudly", {
  peer_stage_l_require_harness()
  measured <- list(
    status = "DONE",
    equity = data.frame(
      engine = "public",
      ts_utc = c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"),
      equity = c(100, 101),
      cash = c(NA_real_, NA_real_),
      positions_value = c(NA_real_, NA_real_),
      position_proxy = c(NA_real_, NA_real_)
    ),
    trades = data.frame(
      engine = "public",
      trade_count = 1L,
      win_rate = 1,
      average_trade = 1,
      trade_level_status = "available_realized_pnl"
    ),
    metadata = list()
  )
  oracle <- list(
    status = "DONE",
    equity = data.frame(
      engine = "oracle",
      ts_utc = measured$equity$ts_utc,
      equity = c(100, 101 + 1e-7),
      cash = c(100, 101),
      positions_value = c(0, 0),
      position_proxy = c(0, 0)
    ),
    fills = data.frame(fill_id = "F1"),
    trades = transform(measured$trades, engine = "oracle"),
    wall_sec = 7
  )
  attached <- peer_stage_l_harness$peer_attach_sweep_oracle(measured, oracle)
  testthat::expect_equal(
    attached$metadata$public_vs_oracle_max_abs_equity_diff,
    (101 + 1e-7) - 101,
    tolerance = 1e-12
  )
  testthat::expect_equal(
    attached$metadata$public_vs_oracle_equity_affected_rows,
    2L
  )
  testthat::expect_identical(attached$equity$equity, measured$equity$equity)
  testthat::expect_identical(attached$fills, oracle$fills)

  durable <- attached
  durable$equity$engine <- "durable"
  durable$trades$engine <- "durable"
  parity <- peer_stage_l_harness$peer_compare_ledgr_surfaces(
    durable,
    attached
  )
  testthat::expect_equal(parity$max_abs, 0)
  bad_fill <- attached
  bad_fill$fills$fill_id <- "F2"
  testthat::expect_error(
    peer_stage_l_harness$peer_compare_ledgr_surfaces(durable, bad_fill),
    "exact identity"
  )

  bad_equity <- oracle
  bad_equity$equity$equity[[2L]] <- 102
  testthat::expect_error(
    peer_stage_l_harness$peer_attach_sweep_oracle(measured, bad_equity),
    "exceeds tolerance"
  )
  bad_trade <- oracle
  bad_trade$trades$trade_count <- 2L
  testthat::expect_error(
    peer_stage_l_harness$peer_attach_sweep_oracle(measured, bad_trade),
    "exact identity"
  )
})

testthat::test_that("compiled parity distinguishes tolerance from identity", {
  peer_stage_l_require_harness()
  reference <- list(
    public_returns = data.frame(
      candidate_id = "A",
      status = "DONE",
      ts_utc = "2020-01-01T00:00:00Z",
      equity = 100,
      period_return = 0
    ),
    public_trades = data.frame(
      candidate_id = "A",
      candidate_row = 1L,
      trade_seq = 1L,
      close_ts_utc = "2020-01-01T00:00:00Z",
      realized_pnl = 2,
      win_loss = "win"
    )
  )
  candidate <- reference
  candidate$public_returns$equity <- 100 + 1e-7
  report <- peer_stage_l_harness$peer_compare_public_sweep_surfaces(
    reference,
    candidate
  )
  testthat::expect_equal(
    report$max_abs,
    (100 + 1e-7) - 100,
    tolerance = 1e-12
  )
  testthat::expect_identical(report$affected_columns, "equity")

  candidate$public_trades$win_loss <- "loss"
  testthat::expect_error(
    peer_stage_l_harness$peer_compare_public_sweep_surfaces(reference, candidate),
    "exact identity"
  )
})

testthat::test_that("report data preserves order, missingness, and source totals", {
  peer_stage_l_require_harness()
  performance <- data.frame(
    engine = c("done", "missing"),
    status = c("DONE", "UNAVAILABLE"),
    full_row_sec = c(10, 3),
    snapshot_prepare_sec = c(1, NA),
    experiment_setup_sec = c(2, NA),
    engine_sec = c(3, NA),
    results_sec = c(4, NA),
    cold_end_to_end = c(10, NA),
    warm_research_iteration = c(9, NA),
    core_bars_per_sec = c(5, 99)
  )
  report <- peer_stage_l_harness$peer_prepare_report_performance(performance)
  testthat::expect_identical(
    levels(report$phase_plot$phase),
    c("Snapshot prepare", "Setup / orchestration", "Engine", "Results")
  )
  testthat::expect_true(is.na(report$display$full_row_sec[[2L]]))
  testthat::expect_identical(
    as.character(report$unavailable_labels$label),
    "NULL (unavailable)"
  )
  testthat::expect_equal(
    sum(report$phase_plot$seconds),
    report$phase_totals$seconds
  )

  broken <- performance
  broken$cold_end_to_end[[1L]] <- 11
  testthat::expect_error(
    peer_stage_l_harness$peer_prepare_report_performance(broken),
    "do not reconcile"
  )
})
