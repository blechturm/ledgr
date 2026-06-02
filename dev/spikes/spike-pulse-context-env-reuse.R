## Spike 4 (LDG-2508) - Reusable Pulse-Context Env Across Pulses
##
## Question: does converting the per-pulse pulse-context constructor at
## R/fold-engine.R:180-194 from fresh-list-per-pulse to reusable-env-with-
## slot-mutation save wall time?
##
## Mechanism: current constructor allocates a fresh list with 12+ slots per
## pulse. At 1260 pulses xlarge that's 1260 list allocations plus per-slot
## binding work. A reusable env mutated slot-by-slot removes the allocation
## cost while preserving strategy-observable shape.

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

## Realistic strategy callback shape: touch most ctx slots so the cost of
## env-slot access vs list-element access is measured fairly.
touch_ctx <- function(ctx) {
  ## simulate the strategy callback reading the ctx
  invisible(c(
    length(ctx$universe),
    length(ctx$bars),
    ctx$cash,
    ctx$equity,
    is.null(ctx$state_prev),
    nchar(ctx$ts_utc),
    is.null(ctx$safety_state)
  ))
}

## ---- Variant A: fresh list per pulse (production) ----
variant_a_fresh_list <- function(n_pulses, universe) {
  state <- list(positions = stats::setNames(numeric(length(universe)), universe),
                cash = 1e6)
  results <- numeric(n_pulses)
  for (i in seq_len(n_pulses)) {
    ctx <- list(
      run_id = "rid",
      ts_utc = sprintf("2020-01-%02dT00:00:00Z", (i %% 28L) + 1L),
      universe = universe,
      bars = list(close = numeric(length(universe))),
      feature_table = NULL,
      positions = state$positions,
      cash = state$cash,
      equity = state$cash,
      seed = 1L,
      pulse_seed = i,
      state_prev = NULL,
      safety_state = "GREEN"
    )
    class(ctx) <- "ledgr_pulse_context"
    results[[i]] <- length(touch_ctx(ctx))
  }
  results
}

## ---- Variant B: reusable env with named slots ----
variant_b_reusable_env <- function(n_pulses, universe) {
  state <- list(positions = stats::setNames(numeric(length(universe)), universe),
                cash = 1e6)
  ctx <- new.env(parent = emptyenv())
  ctx$run_id <- "rid"
  ctx$universe <- universe
  ctx$feature_table <- NULL
  ctx$seed <- 1L
  ctx$state_prev <- NULL
  ctx$safety_state <- "GREEN"
  ctx$bars <- list(close = numeric(length(universe)))

  results <- numeric(n_pulses)
  for (i in seq_len(n_pulses)) {
    ctx$ts_utc <- sprintf("2020-01-%02dT00:00:00Z", (i %% 28L) + 1L)
    ctx$positions <- state$positions
    ctx$cash <- state$cash
    ctx$equity <- state$cash
    ctx$pulse_seed <- i
    results[[i]] <- length(touch_ctx(ctx))
  }
  results
}

## ---- Variant C: reusable env with class attribute restored per pulse ----
variant_c_env_classed <- function(n_pulses, universe) {
  state <- list(positions = stats::setNames(numeric(length(universe)), universe),
                cash = 1e6)
  ctx <- new.env(parent = emptyenv())
  ctx$run_id <- "rid"
  ctx$universe <- universe
  ctx$feature_table <- NULL
  ctx$seed <- 1L
  ctx$state_prev <- NULL
  ctx$safety_state <- "GREEN"
  ctx$bars <- list(close = numeric(length(universe)))

  results <- numeric(n_pulses)
  for (i in seq_len(n_pulses)) {
    ctx$ts_utc <- sprintf("2020-01-%02dT00:00:00Z", (i %% 28L) + 1L)
    ctx$positions <- state$positions
    ctx$cash <- state$cash
    ctx$equity <- state$cash
    ctx$pulse_seed <- i
    class(ctx) <- "ledgr_pulse_context"
    results[[i]] <- length(touch_ctx(ctx))
  }
  results
}

## ---- Variant D: reusable env with full helper cache restored ----
variant_d_env_with_helpers <- function(n_pulses, universe) {
  state <- list(positions = stats::setNames(numeric(length(universe)), universe),
                cash = 1e6)
  helper_cache <- new.env(parent = emptyenv())
  helper_cache$close_fn <- function(id) state$positions[[id]] * 0.0
  helper_cache$feature_fn <- function(id, fid) NA_real_

  ctx <- new.env(parent = emptyenv())
  ctx$run_id <- "rid"
  ctx$universe <- universe
  ctx$feature_table <- NULL
  ctx$seed <- 1L
  ctx$state_prev <- NULL
  ctx$safety_state <- "GREEN"
  ctx$bars <- list(close = numeric(length(universe)))
  ctx$close <- helper_cache$close_fn
  ctx$feature <- helper_cache$feature_fn

  results <- numeric(n_pulses)
  for (i in seq_len(n_pulses)) {
    ctx$ts_utc <- sprintf("2020-01-%02dT00:00:00Z", (i %% 28L) + 1L)
    ctx$positions <- state$positions
    ctx$cash <- state$cash
    ctx$equity <- state$cash
    ctx$pulse_seed <- i
    class(ctx) <- "ledgr_pulse_context"
    results[[i]] <- length(touch_ctx(ctx))
  }
  results
}

## ---- Sweep ----

scales <- list(
  list(n_pulses = 1260L, n_inst = 100L,  label = "100inst_1260p"),
  list(n_pulses = 1260L, n_inst = 1000L, label = "1000inst_1260p"),
  list(n_pulses = 5000L, n_inst = 1000L, label = "1000inst_5000p")
)

results <- vector("list", length(scales))
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  universe <- sprintf("INST%04d", seq_len(sc$n_inst))
  cat(sprintf("\n[%s] n_pulses=%d n_inst=%d\n",
              sc$label, sc$n_pulses, sc$n_inst))

  a <- bench_repeated(function() variant_a_fresh_list(sc$n_pulses, universe))
  b <- bench_repeated(function() variant_b_reusable_env(sc$n_pulses, universe))
  c <- bench_repeated(function() variant_c_env_classed(sc$n_pulses, universe))
  d <- bench_repeated(function() variant_d_env_with_helpers(sc$n_pulses, universe))

  ## Parity gate: strategy observation is the same across variants (we
  ## return identical results vectors).
  ra <- variant_a_fresh_list(sc$n_pulses, universe)
  rb <- variant_b_reusable_env(sc$n_pulses, universe)
  rc <- variant_c_env_classed(sc$n_pulses, universe)
  rd <- variant_d_env_with_helpers(sc$n_pulses, universe)
  parity_ab <- identical(ra, rb)
  parity_ac <- identical(ra, rc)
  parity_ad <- identical(ra, rd)

  cat(sprintf("  VarA (fresh list)      : %.4fs (%.2f us/pulse)\n",
              a$median, a$median * 1e6 / sc$n_pulses))
  cat(sprintf("  VarB (reusable env)    : %.4fs (%.2fx, %.2f us/pulse)\n",
              b$median, a$median / max(b$median, 1e-6),
              b$median * 1e6 / sc$n_pulses))
  cat(sprintf("  VarC (env classed)     : %.4fs (%.2fx, %.2f us/pulse)\n",
              c$median, a$median / max(c$median, 1e-6),
              c$median * 1e6 / sc$n_pulses))
  cat(sprintf("  VarD (env + helpers)   : %.4fs (%.2fx, %.2f us/pulse)\n",
              d$median, a$median / max(d$median, 1e-6),
              d$median * 1e6 / sc$n_pulses))
  cat(sprintf("  Parity A==B: %s, A==C: %s, A==D: %s\n",
              if (parity_ab) "PASS" else "FAIL",
              if (parity_ac) "PASS" else "FAIL",
              if (parity_ad) "PASS" else "FAIL"))

  results[[k]] <- list(
    scale = sc$label, n_pulses = sc$n_pulses, n_inst = sc$n_inst,
    a_median = a$median, b_median = b$median,
    c_median = c$median, d_median = d$median,
    speedup_b = a$median / max(b$median, 1e-6),
    speedup_c = a$median / max(c$median, 1e-6),
    speedup_d = a$median / max(d$median, 1e-6),
    parity_ab = parity_ab, parity_ac = parity_ac, parity_ad = parity_ad
  )
}

cat("\n========== SPIKE 4 SUMMARY ==========\n")
cat(sprintf("%-18s %8s %10s %10s %10s %10s %8s %8s %8s\n",
            "scale", "n_inst",
            "VarA_s", "VarB_s", "VarC_s", "VarD_s",
            "B_sp", "C_sp", "D_sp"))
for (r in results) {
  cat(sprintf("%-18s %8d %10.4f %10.4f %10.4f %10.4f %7.2fx %7.2fx %7.2fx\n",
              r$scale, r$n_inst,
              r$a_median, r$b_median, r$c_median, r$d_median,
              r$speedup_b, r$speedup_c, r$speedup_d))
}

res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  scale = r$scale, n_pulses = r$n_pulses, n_inst = r$n_inst,
  variant_a_s = r$a_median, variant_b_s = r$b_median,
  variant_c_s = r$c_median, variant_d_s = r$d_median,
  speedup_b = r$speedup_b, speedup_c = r$speedup_c, speedup_d = r$speedup_d,
  parity_ab = r$parity_ab, parity_ac = r$parity_ac, parity_ad = r$parity_ad,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_pulse_context_env_reuse.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
