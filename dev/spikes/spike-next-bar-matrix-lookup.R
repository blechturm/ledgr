## Spike 6 (LDG-2510) - Next-Bar Matrix Lookup Re-Spike
##
## Re-confirm the per-fill matrix-lookup recovery at post-v0.1.8.9 baseline.
## v0.1.8.9 Spike 5 confirmed 166x in isolation, ~5s wall recovery; deferred
## from LDG-2502 because the contract surface change (row-shaped next_bar to
## scalar next_open_price) didn't clear the v0.1.8.9 threshold.
##
## Two questions for v0.1.8.10:
##   1. Does the per-fill speedup hold at production-fill counts (68k, 133k)
##      post-v0.1.8.9 (Batches 4-7 changed surrounding hot frames)?
##   2. What is the exact fill-proposal contract surface change cost --
##      which downstream consumers care, what cost/liquidity-model work this
##      enables or blocks?

suppressPackageStartupMessages({
  pkgload::load_all("c:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE)
})

set.seed(20260601L)

bench_repeated <- function(expr_fn, n_reps = 3L) {
  reps <- replicate(n_reps, {
    gc(FALSE)
    t0 <- proc.time()[["elapsed"]]
    expr_fn()
    proc.time()[["elapsed"]] - t0
  })
  list(median = median(reps), min = min(reps), max = max(reps), reps = reps)
}

## ---- Fixture: synthetic bars_by_id + bars_mat at xlarge shape ----

make_fixture <- function(n_inst, n_pulses) {
  pulses_posix <- as.POSIXct("2020-01-01", tz = "UTC") +
    as.difftime(seq_len(n_pulses) - 1L, units = "days")
  instrument_ids <- sprintf("INST%04d", seq_len(n_inst))
  ## per-instrument data.frame (production bars_by_id shape)
  bars_by_id <- stats::setNames(lapply(seq_len(n_inst), function(j) {
    p <- cumsum(c(100, rnorm(n_pulses - 1L, 0, 0.5)))
    data.frame(
      instrument_id = instrument_ids[[j]],
      ts_utc = pulses_posix,
      open = p,
      high = p + 0.1,
      low = p - 0.1,
      close = p,
      volume = 1e6,
      stringsAsFactors = FALSE
    )
  }), instrument_ids)
  ## matrix shape (already built per fold-engine.R:55 in production)
  bars_mat <- list(
    open = matrix(0, nrow = n_inst, ncol = n_pulses,
                  dimnames = list(instrument_ids, NULL))
  )
  for (j in seq_len(n_inst)) {
    bars_mat$open[j, ] <- bars_by_id[[j]]$open
  }
  ## tibble variant
  bars_by_id_tbl <- stats::setNames(lapply(bars_by_id, tibble::as_tibble),
                                    instrument_ids)
  list(
    bars_by_id = bars_by_id,
    bars_by_id_tbl = bars_by_id_tbl,
    bars_mat = bars_mat,
    instrument_ids = instrument_ids,
    n_inst = n_inst, n_pulses = n_pulses
  )
}

make_fills <- function(fixture, n_fills) {
  ## n_fills random (instrument_id, pulse_idx) tuples; pulse_idx < n_pulses
  ## so next-bar lookup at i+1 is in range.
  data.frame(
    instrument_id = fixture$instrument_ids[
      sample.int(fixture$n_inst, n_fills, replace = TRUE)],
    inst_idx = sample.int(fixture$n_inst, n_fills, replace = TRUE),
    pulse_idx = sample.int(fixture$n_pulses - 1L, n_fills, replace = TRUE),
    stringsAsFactors = FALSE
  )
}

## ---- Variant A: production data.frame row subset ----
variant_a_df_row <- function(fills, bars_by_id) {
  out <- numeric(nrow(fills))
  for (k in seq_len(nrow(fills))) {
    id <- fills$instrument_id[[k]]
    i <- fills$pulse_idx[[k]]
    b <- bars_by_id[[id]]
    next_bar <- if (!is.null(b) && i < nrow(b)) b[i + 1L, , drop = FALSE] else NULL
    if (!is.null(next_bar)) out[[k]] <- next_bar$open
  }
  out
}

## ---- Variant B: tibble row subset (current bars_by_id type post-v0.1.8.9) ----
variant_b_tibble_row <- function(fills, bars_by_id_tbl) {
  out <- numeric(nrow(fills))
  for (k in seq_len(nrow(fills))) {
    id <- fills$instrument_id[[k]]
    i <- fills$pulse_idx[[k]]
    b <- bars_by_id_tbl[[id]]
    next_bar <- if (!is.null(b) && i < nrow(b)) b[i + 1L, , drop = FALSE] else NULL
    if (!is.null(next_bar)) out[[k]] <- next_bar$open
  }
  out
}

## ---- Variant C: matrix scalar lookup (target) ----
variant_c_matrix <- function(fills, bars_mat) {
  out <- numeric(nrow(fills))
  for (k in seq_len(nrow(fills))) {
    inst_idx <- fills$inst_idx[[k]]
    i <- fills$pulse_idx[[k]]
    out[[k]] <- bars_mat$open[inst_idx, i + 1L]
  }
  out
}

## ---- Variant D: vectorized matrix lookup ----
##
## Fully vectorise: one matrix-index gather call per batch. Approximates
## what a batched-fill-proposal contract would enable (Spike 1's inline-
## equity-capture path could batch fill emission too).

variant_d_vec_matrix <- function(fills, bars_mat) {
  idx <- cbind(fills$inst_idx, fills$pulse_idx + 1L)
  bars_mat$open[idx]
}

## ---- Sweep ----

scales <- list(
  list(n_inst = 500L,  n_pulses = 1260L, n_fills = 68324L,  label = "68k"),
  list(n_inst = 1000L, n_pulses = 1260L, n_fills = 133000L, label = "133k")
)

results <- vector("list", length(scales))
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  cat(sprintf("\n[%s] n_inst=%d n_pulses=%d n_fills=%d\n",
              sc$label, sc$n_inst, sc$n_pulses, sc$n_fills))

  fx <- make_fixture(sc$n_inst, sc$n_pulses)
  fills <- make_fills(fx, sc$n_fills)
  ## inst_idx must match instrument_id positionally
  fills$inst_idx <- match(fills$instrument_id, fx$instrument_ids)

  a <- bench_repeated(function() variant_a_df_row(fills, fx$bars_by_id))
  b <- bench_repeated(function() variant_b_tibble_row(fills, fx$bars_by_id_tbl))
  c <- bench_repeated(function() variant_c_matrix(fills, fx$bars_mat))
  d <- bench_repeated(function() variant_d_vec_matrix(fills, fx$bars_mat))

  ## Parity: matrix-lookup variants produce identical scalar prices
  pa <- variant_a_df_row(fills, fx$bars_by_id)
  pb <- variant_b_tibble_row(fills, fx$bars_by_id_tbl)
  pc <- variant_c_matrix(fills, fx$bars_mat)
  pd <- variant_d_vec_matrix(fills, fx$bars_mat)
  parity_ab <- identical(pa, pb)
  parity_ac <- identical(pa, pc)
  parity_ad <- identical(pa, pd)

  cat(sprintf("  VarA (df row subset)        : %.3fs (%.2f us/fill)\n",
              a$median, a$median * 1e6 / sc$n_fills))
  cat(sprintf("  VarB (tibble row subset)    : %.3fs (%.2fx, %.2f us/fill)\n",
              b$median, a$median / max(b$median, 1e-6),
              b$median * 1e6 / sc$n_fills))
  cat(sprintf("  VarC (matrix scalar)        : %.4fs (%.2fx, %.2f us/fill)\n",
              c$median, a$median / max(c$median, 1e-6),
              c$median * 1e6 / sc$n_fills))
  cat(sprintf("  VarD (vectorised matrix)    : %.4fs (%.2fx, %.4f us/fill)\n",
              d$median, a$median / max(d$median, 1e-6),
              d$median * 1e6 / sc$n_fills))
  cat(sprintf("  Parity A==B: %s, A==C: %s, A==D: %s\n",
              if (parity_ab) "PASS" else "FAIL",
              if (parity_ac) "PASS" else "FAIL",
              if (parity_ad) "PASS" else "FAIL"))

  results[[k]] <- list(
    scale = sc$label, n_inst = sc$n_inst, n_pulses = sc$n_pulses,
    n_fills = sc$n_fills,
    a_median = a$median, b_median = b$median,
    c_median = c$median, d_median = d$median,
    speedup_c = a$median / max(c$median, 1e-6),
    speedup_d = a$median / max(d$median, 1e-6),
    parity_ab = parity_ab, parity_ac = parity_ac, parity_ad = parity_ad
  )
  rm(fx, fills); gc(FALSE)
}

cat("\n========== SPIKE 6 SUMMARY ==========\n")
cat(sprintf("%-6s %8s %10s %10s %10s %10s %10s\n",
            "scale", "n_fills",
            "VarA_s", "VarB_s", "VarC_s", "VarD_s", "C_sp"))
for (r in results) {
  cat(sprintf("%-6s %8d %10.3f %10.3f %10.4f %10.4f %8.1fx\n",
              r$scale, r$n_fills,
              r$a_median, r$b_median, r$c_median, r$d_median,
              r$speedup_c))
}

cat("\nv0.1.8.9 Spike 5 anchor: 166x speedup df_row -> matrix at 133k fills, ~5s wall.\n")
cat("v0.1.8.10 re-spike: post-v0.1.8.9 baseline should still show the same mechanism.\n")

res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  scale = r$scale, n_inst = r$n_inst, n_pulses = r$n_pulses,
  n_fills = r$n_fills,
  variant_a_s = r$a_median, variant_b_s = r$b_median,
  variant_c_s = r$c_median, variant_d_s = r$d_median,
  speedup_c = r$speedup_c, speedup_d = r$speedup_d,
  parity_ab = r$parity_ab, parity_ac = r$parity_ac, parity_ad = r$parity_ad,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_next_bar_matrix_lookup.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
