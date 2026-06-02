## Spike 8 (LDG-2512) - Cheap Deterministic pulse_seed Mixer
##
## Question: measure per-pulse cost of `ledgr_derive_pulse_seed` (current
## SHA-256 + canonical_json) vs cheap deterministic mixers (xoshiro128,
## splitmix64). Decide whether inventory A4 candidate clears the v0.1.8.10
## threshold (> 1s at 1260 pulses).
##
## Mechanism: SHA-256 + canonical_json per pulse adds ~200us per pulse per
## the spike spec hypothesis. At 1260 pulses on xlarge that's ~0.25s.
## Cheap deterministic mixers should be 10-100x faster while preserving
## deterministic replay.

suppressPackageStartupMessages({
  pkgload::load_all("c:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE)
})

set.seed(20260601L)

bench_repeated <- function(expr_fn, n_reps = 5L) {
  reps <- replicate(n_reps, {
    gc(FALSE)
    t0 <- proc.time()[["elapsed"]]
    expr_fn()
    proc.time()[["elapsed"]] - t0
  })
  list(median = median(reps), min = min(reps), max = max(reps), reps = reps)
}

## ---- Variant A: production ledgr_derive_pulse_seed ----
##
## Calls into ledgr_derive_seed which does:
##   payload <- list(seed = execution_seed, ...scope)
##   payload_json <- canonical_json(payload)
##   hash <- digest::digest(payload_json, algo = "sha256", serialize = FALSE)
##   ...truncate/strtoi/sum to integer

variant_a_production <- function(execution_seed, n_pulses) {
  out <- integer(n_pulses)
  for (i in seq_len(n_pulses)) {
    out[[i]] <- ledgr_derive_pulse_seed(execution_seed, i)
  }
  out
}

## ---- Variant B: splitmix64 mixer ----
##
## Standard splitmix64 stepper. Pure integer ops; constant cost per pulse.
## SplitMix64 reference: https://prng.di.unimi.it/splitmix64.c
##
## R caveat: R integer is 32-bit signed; need bitwAnd/bitwShiftR with care.
## For deterministic positive-int output: use bit64::as.integer64 if
## available, or implement via numeric() with modular arithmetic. For the
## spike we use a simple 32-bit linear-congruential variant which is still
## a cheap deterministic mixer and avoids R's 32-bit int trap.

variant_b_splitmix32 <- function(execution_seed, n_pulses) {
  ## Each call: x = seed; x = x XOR (x >> 16); x *= 0x21f0aaad; x = x XOR
  ##           (x >> 15); x *= 0x735a2d97; x = x XOR (x >> 15); return x
  ## Use bitwXor and bitwShiftR; multiplication modulo 2^32.
  state <- execution_seed
  out <- integer(n_pulses)
  m1 <- 0x21f0aaad
  m2 <- 0x735a2d97
  mask32 <- 4294967295  # 2^32 - 1
  for (i in seq_len(n_pulses)) {
    x <- bitwXor(state + i, bitwShiftR(state + i, 16L))
    x <- bitwAnd(as.integer((x * m1) %% mask32), 2147483647L)
    x <- bitwXor(x, bitwShiftR(x, 15L))
    x <- bitwAnd(as.integer((x * m2) %% mask32), 2147483647L)
    x <- bitwXor(x, bitwShiftR(x, 15L))
    out[[i]] <- bitwAnd(x, 2147483647L)
  }
  out
}

## ---- Variant C: xorshift32 mixer ----
##
## Marsaglia's xorshift32: x ^= x << 13; x ^= x >> 17; x ^= x << 5;
## Same complexity class as splitmix; tested as an independent mixer
## for cross-platform deterministic replay.

variant_c_xorshift32 <- function(execution_seed, n_pulses) {
  out <- integer(n_pulses)
  for (i in seq_len(n_pulses)) {
    x <- bitwXor(execution_seed, i)
    x <- bitwXor(x, bitwAnd(bitwShiftL(x, 13L), 2147483647L))
    x <- bitwXor(x, bitwShiftR(x, 17L))
    x <- bitwXor(x, bitwAnd(bitwShiftL(x, 5L), 2147483647L))
    out[[i]] <- bitwAnd(x, 2147483647L)
  }
  out
}

## ---- Variant D: pre-computed seed vector at fold setup ----
##
## Compute ALL pulse seeds once at fold setup (vector op), then look up
## in O(1) per pulse. This is the natural production shape if the win
## materialises: pre-compute n_pulses seeds before the loop, read by
## index at pulse boundary.

variant_d_precomputed <- function(execution_seed, n_pulses) {
  ## Vectorised production-equivalent: each seed deterministic on
  ## (execution_seed, i). For the simulation we use the same SHA-256
  ## payload shape per index, but in production this would be done
  ## once as a single canonical_json call over a list of n_pulses
  ## payloads — collapse the per-pulse work into a single
  ## canonical_json + n_pulses chunk reads.
  ##
  ## For the spike's timing budget, we approximate the post-precompute
  ## cost as zero per pulse (vector lookup is below proc.time
  ## resolution). The pre-compute cost is the one-time call below.
  precomputed <- vapply(seq_len(n_pulses),
                        function(i) ledgr_derive_pulse_seed(execution_seed, i),
                        integer(1))
  out <- integer(n_pulses)
  for (i in seq_len(n_pulses)) {
    out[[i]] <- precomputed[[i]]
  }
  out
}

## ---- Cross-platform determinism check ----
##
## Verify that each mixer produces the same output for the same input
## across reps (within this process). The cross-platform claim for
## splitmix and xorshift relies on well-specified bit ops being
## identical across architectures — verified by the algorithms'
## specifications; we assert determinism within a single R session here.

verify_determinism <- function(execution_seed, n_pulses) {
  a1 <- variant_a_production(execution_seed, n_pulses)
  a2 <- variant_a_production(execution_seed, n_pulses)
  b1 <- variant_b_splitmix32(execution_seed, n_pulses)
  b2 <- variant_b_splitmix32(execution_seed, n_pulses)
  c1 <- variant_c_xorshift32(execution_seed, n_pulses)
  c2 <- variant_c_xorshift32(execution_seed, n_pulses)
  list(
    a_deterministic = identical(a1, a2),
    b_deterministic = identical(b1, b2),
    c_deterministic = identical(c1, c2)
  )
}

## ---- Sweep ----

scales <- list(
  list(n_pulses = 1260L, label = "1260p"),
  list(n_pulses = 5000L, label = "5000p")
)

execution_seed <- 42L
det <- verify_determinism(execution_seed, 100L)
cat(sprintf("Determinism: A=%s B=%s C=%s\n",
            if (det$a_deterministic) "PASS" else "FAIL",
            if (det$b_deterministic) "PASS" else "FAIL",
            if (det$c_deterministic) "PASS" else "FAIL"))

results <- vector("list", length(scales))
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  cat(sprintf("\n[%s] n_pulses=%d\n", sc$label, sc$n_pulses))

  a <- bench_repeated(function() variant_a_production(execution_seed, sc$n_pulses))
  b <- bench_repeated(function() variant_b_splitmix32(execution_seed, sc$n_pulses))
  c <- bench_repeated(function() variant_c_xorshift32(execution_seed, sc$n_pulses))
  d <- bench_repeated(function() variant_d_precomputed(execution_seed, sc$n_pulses))

  cat(sprintf("  VarA (SHA-256 + canon)  : %.4fs (%.2f us/pulse)\n",
              a$median, a$median * 1e6 / sc$n_pulses))
  cat(sprintf("  VarB (splitmix32)       : %.4fs (%.2fx, %.2f us/pulse)\n",
              b$median, a$median / max(b$median, 1e-6),
              b$median * 1e6 / sc$n_pulses))
  cat(sprintf("  VarC (xorshift32)       : %.4fs (%.2fx, %.2f us/pulse)\n",
              c$median, a$median / max(c$median, 1e-6),
              c$median * 1e6 / sc$n_pulses))
  cat(sprintf("  VarD (precomputed)      : %.4fs (%.2fx, %.2f us/pulse)\n",
              d$median, a$median / max(d$median, 1e-6),
              d$median * 1e6 / sc$n_pulses))

  results[[k]] <- list(
    scale = sc$label, n_pulses = sc$n_pulses,
    a_median = a$median, b_median = b$median,
    c_median = c$median, d_median = d$median,
    a_us_per_pulse = a$median * 1e6 / sc$n_pulses
  )
}

cat("\n========== SPIKE 8 SUMMARY ==========\n")
cat(sprintf("%-10s %10s %10s %10s %10s %10s\n",
            "scale", "n_pulses", "VarA_s", "VarB_s", "VarC_s", "VarD_s"))
for (r in results) {
  cat(sprintf("%-10s %10d %10.4f %10.4f %10.4f %10.4f\n",
              r$scale, r$n_pulses, r$a_median, r$b_median, r$c_median, r$d_median))
}

cat(sprintf("\nProduction (VarA) per-pulse cost: %.1f us/pulse\n",
            results[[1]]$a_us_per_pulse))
cat(sprintf("Decision rule: if VarA total < 1s at 1260 pulses => park\n"))
cat(sprintf("VarA at 1260 pulses: %.4fs => %s\n",
            results[[1]]$a_median,
            if (results[[1]]$a_median < 1.0) "PARK (below threshold)"
            else "TICKET (above threshold)"))

res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  scale = r$scale, n_pulses = r$n_pulses,
  variant_a_s = r$a_median, variant_b_s = r$b_median,
  variant_c_s = r$c_median, variant_d_s = r$d_median,
  a_us_per_pulse = r$a_us_per_pulse,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_pulse_seed_mixer.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
