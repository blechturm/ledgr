## Spike 5 (LDG-2509) - Integer-Indexed Strategy Callback Accessors
##
## Question: per-pulse strategy callback cost across the current named-list
## ctx access pattern, integer-indexed atomic-vector access, and integer-
## indexed env-slot access. Feasibility check for the strategy callback
## contract addendum (`ctx$vec$close[idx]`, `ctx$idx()`) bound by the
## 2026-06-01 RFC synthesis.
##
## Note: per the helpers RFC v2 synthesis the contract addendum is the
## `ctx$vec` namespace surface, NOT a flat `ctx$close[idx]` shape. This
## spike measures both flavours so the implementation ticket has clean
## cost evidence either way.

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

## A representative cross-sectional strategy: read close prices for the
## full universe, pick top-3 by ratio, return target qty for those.
##
## Variant A: current data.frame access shape — read bars rows by
##   instrument_id char vector.
## Variant B: integer-indexed atomic-vector access — ctx$close[seq_along(ids)].
## Variant C: ctx$vec$close namespace (universe-aligned vector at top level).
## Variant D: integer-indexed env-slot reads.

strategy_var_a <- function(ctx) {
  univ <- ctx$universe
  ## Variant A pattern: build a per-instrument vector via char lookup
  cl <- vapply(univ, function(id) ctx$bars$close[ctx$bars$instrument_id == id],
               numeric(1))
  picks <- order(cl, decreasing = TRUE)[1:3]
  out <- stats::setNames(numeric(length(univ)), univ)
  out[picks] <- 100
  out
}

strategy_var_b <- function(ctx) {
  univ <- ctx$universe
  cl <- ctx$close  # already universe-aligned atomic numeric
  picks <- order(cl, decreasing = TRUE)[1:3]
  out <- stats::setNames(numeric(length(univ)), univ)
  out[picks] <- 100
  out
}

strategy_var_c <- function(ctx) {
  univ <- ctx$universe
  cl <- ctx$vec$close  # universe-aligned via vec namespace
  picks <- order(cl, decreasing = TRUE)[1:3]
  out <- stats::setNames(numeric(length(univ)), univ)
  out[picks] <- 100
  out
}

strategy_var_d <- function(ctx) {
  univ <- ctx$universe
  cl <- ctx$env$close  # universe-aligned via env slot
  picks <- order(cl, decreasing = TRUE)[1:3]
  out <- stats::setNames(numeric(length(univ)), univ)
  out[picks] <- 100
  out
}

## ---- per-pulse callback driver ----

run_pulses_a <- function(n_pulses, universe, close_per_pulse) {
  n_inst <- length(universe)
  results <- vector("list", n_pulses)
  for (i in seq_len(n_pulses)) {
    bars_df <- data.frame(
      instrument_id = universe,
      close = close_per_pulse[, i],
      stringsAsFactors = FALSE
    )
    ctx <- list(universe = universe, bars = bars_df)
    results[[i]] <- strategy_var_a(ctx)
  }
  results
}

run_pulses_b <- function(n_pulses, universe, close_per_pulse) {
  n_inst <- length(universe)
  results <- vector("list", n_pulses)
  for (i in seq_len(n_pulses)) {
    ctx <- list(
      universe = universe,
      close = close_per_pulse[, i]  # universe-aligned atomic numeric
    )
    results[[i]] <- strategy_var_b(ctx)
  }
  results
}

run_pulses_c <- function(n_pulses, universe, close_per_pulse) {
  n_inst <- length(universe)
  results <- vector("list", n_pulses)
  for (i in seq_len(n_pulses)) {
    vec_ns <- list(close = close_per_pulse[, i], id = universe)
    ctx <- list(universe = universe, vec = vec_ns)
    results[[i]] <- strategy_var_c(ctx)
  }
  results
}

run_pulses_d <- function(n_pulses, universe, close_per_pulse) {
  n_inst <- length(universe)
  results <- vector("list", n_pulses)
  env_slot <- new.env(parent = emptyenv())
  env_slot$close <- numeric(n_inst)
  for (i in seq_len(n_pulses)) {
    env_slot$close <- close_per_pulse[, i]
    ctx <- list(universe = universe, env = env_slot)
    results[[i]] <- strategy_var_d(ctx)
  }
  results
}

## ---- Sweep ----

scales <- list(
  list(n_inst = 100L,  n_pulses = 1260L, label = "100inst"),
  list(n_inst = 500L,  n_pulses = 1260L, label = "500inst"),
  list(n_inst = 1000L, n_pulses = 1260L, label = "1000inst")
)

results <- vector("list", length(scales))
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  universe <- sprintf("INST%04d", seq_len(sc$n_inst))
  close_per_pulse <- matrix(
    100 + rnorm(sc$n_inst * sc$n_pulses, sd = 0.5),
    nrow = sc$n_inst, ncol = sc$n_pulses
  )
  cat(sprintf("\n[%s] n_inst=%d n_pulses=%d\n", sc$label, sc$n_inst, sc$n_pulses))

  a <- bench_repeated(function() run_pulses_a(sc$n_pulses, universe, close_per_pulse))
  b <- bench_repeated(function() run_pulses_b(sc$n_pulses, universe, close_per_pulse))
  c <- bench_repeated(function() run_pulses_c(sc$n_pulses, universe, close_per_pulse))
  d <- bench_repeated(function() run_pulses_d(sc$n_pulses, universe, close_per_pulse))

  ## Parity: all variants must return identical target vectors
  ra <- run_pulses_a(sc$n_pulses, universe, close_per_pulse)
  rb <- run_pulses_b(sc$n_pulses, universe, close_per_pulse)
  rc <- run_pulses_c(sc$n_pulses, universe, close_per_pulse)
  rd <- run_pulses_d(sc$n_pulses, universe, close_per_pulse)
  parity_ab <- identical(ra, rb)
  parity_ac <- identical(ra, rc)
  parity_ad <- identical(ra, rd)

  cat(sprintf("  VarA (df char access)  : %.4fs (%.2f us/pulse)\n",
              a$median, a$median * 1e6 / sc$n_pulses))
  cat(sprintf("  VarB (flat atomic vec) : %.4fs (%.2fx, %.2f us/pulse)\n",
              b$median, a$median / max(b$median, 1e-6),
              b$median * 1e6 / sc$n_pulses))
  cat(sprintf("  VarC (ctx$vec namespace): %.4fs (%.2fx, %.2f us/pulse)\n",
              c$median, a$median / max(c$median, 1e-6),
              c$median * 1e6 / sc$n_pulses))
  cat(sprintf("  VarD (env slot reads)  : %.4fs (%.2fx, %.2f us/pulse)\n",
              d$median, a$median / max(d$median, 1e-6),
              d$median * 1e6 / sc$n_pulses))
  cat(sprintf("  Parity A==B: %s, A==C: %s, A==D: %s\n",
              if (parity_ab) "PASS" else "FAIL",
              if (parity_ac) "PASS" else "FAIL",
              if (parity_ad) "PASS" else "FAIL"))

  results[[k]] <- list(
    scale = sc$label, n_inst = sc$n_inst, n_pulses = sc$n_pulses,
    a_median = a$median, b_median = b$median,
    c_median = c$median, d_median = d$median,
    speedup_b = a$median / max(b$median, 1e-6),
    speedup_c = a$median / max(c$median, 1e-6),
    speedup_d = a$median / max(d$median, 1e-6),
    parity_ab = parity_ab, parity_ac = parity_ac, parity_ad = parity_ad
  )
}

cat("\n========== SPIKE 5 SUMMARY ==========\n")
cat(sprintf("%-10s %8s %10s %10s %10s %10s %8s %8s %8s\n",
            "scale", "n_inst",
            "VarA_s", "VarB_s", "VarC_s", "VarD_s",
            "B_sp", "C_sp", "D_sp"))
for (r in results) {
  cat(sprintf("%-10s %8d %10.4f %10.4f %10.4f %10.4f %7.2fx %7.2fx %7.2fx\n",
              r$scale, r$n_inst,
              r$a_median, r$b_median, r$c_median, r$d_median,
              r$speedup_b, r$speedup_c, r$speedup_d))
}

res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  scale = r$scale, n_inst = r$n_inst, n_pulses = r$n_pulses,
  variant_a_s = r$a_median, variant_b_s = r$b_median,
  variant_c_s = r$c_median, variant_d_s = r$d_median,
  speedup_b = r$speedup_b, speedup_c = r$speedup_c, speedup_d = r$speedup_d,
  parity_ab = r$parity_ab, parity_ac = r$parity_ac, parity_ad = r$parity_ad,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_integer_indexed_accessors.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
