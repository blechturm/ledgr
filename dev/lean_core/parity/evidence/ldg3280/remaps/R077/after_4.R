  # At run time: one vector per seeded fold, none unseeded, and no
  # derived-seed hash; JSON work does not grow with pulses when a seed is
  # added. The per-pulse read is the context's index read (anchor above).
  calls <- new.env(parent = emptyenv())
  calls$vectors <- 0L
  calls$derive <- 0L
  calls$json <- 0L
  orig_seeds <- ns$ledgr_pulse_seeds
  orig_derive <- ns$ledgr_derive_seed
  orig_json <- ns$canonical_json
  testthat::local_mocked_bindings(
    ledgr_pulse_seeds = function(...) { calls$vectors <- calls$vectors + 1L; orig_seeds(...) },
    ledgr_derive_seed = function(...) { calls$derive <- calls$derive + 1L; orig_derive(...) },
    canonical_json = function(...) { calls$json <- calls$json + 1L; orig_json(...) },
    .package = "ledgr"
  )
  count_run <- function(n, seed, id) {
    fx <- ledgr_rng_test_experiment(ledgr_rng_test_flat_strategy, n = n, snapshot_id = paste0("ps2_cost_", id))
    on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
    for (field in c("vectors", "derive", "json")) calls[[field]] <- 0L
    bt <- suppressWarnings(ledgr_run(fx$exp, params = list(qty = 1), run_id = paste0("ps2-cost-", id), seed = seed))
    close(bt)
    c(vectors = calls$vectors, derive = calls$derive, json = calls$json)
  }
  s10 <- count_run(10L, 7L, "s10")
  u10 <- count_run(10L, NULL, "u10")
  s30 <- count_run(30L, 7L, "s30")
  u30 <- count_run(30L, NULL, "u30")
  testthat::expect_identical(unname(s10[c("vectors", "derive")]), c(1L, 0L))
  testthat::expect_identical(unname(s30[c("vectors", "derive")]), c(1L, 0L))
