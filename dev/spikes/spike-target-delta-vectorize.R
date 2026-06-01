# Spike: per-target early-skip loop vs vectorized delta + which()
#
# Context: R/fold-engine.R:277-359 iterates names(targets) per pulse, doing
# [[id]] lookups against both `targets` and `state$positions`, a subtraction,
# and an abs check on EVERY instrument — even instruments where no fill will
# fire. At 1000 inst x 1260 pulses with ~133k real fills, the loop body runs
# 1.26M times to do 133k real work (~10:1 skip-to-fill ratio).
#
# Hypothesis: computing delta_vec once per pulse and iterating only over
# which(abs(delta_vec) > tol) drops total loop iterations from 1.26M to ~133k
# and recovers ~12s of 413s loop on the xlarge cell.
#
# FAITHFULNESS: replicates targets as length-n_inst named numeric vector
# (because ctx$flat() returns a zero-vector of length n_inst). Replicates
# state$positions as named numeric. Spike measures ONLY the skip-or-not
# overhead — the heavy fill work after the skip check is unchanged between
# variants. We replace heavy work with a `fills <- fills + 1L` counter so the
# spike measures the cost difference, not the absolute fill cost.
#
# Variants:
#   current  : R loop with per-id [[ ]] lookups
#   vec      : compute delta_vec once, iterate which(abs(delta_vec) > tol)
#
# Skip ratio: per pulse, only fills_per_pulse instruments fire. At
# fills_per_inst = 135 across 1260 pulses, fills_per_pulse ~= 0.107 * n_inst.
# So ~90% of iterations are pure skip.
#
# CAVEAT: isolated replica overestimates absolute cost. Trust the RELATIVE
# speedup and the iteration-count math.

`%||%` <- function(x, y) if (is.null(x)) y else x

mk_setup <- function(n_inst, fills_per_inst, n_pulses, seed = 42L) {
  set.seed(seed)
  ids <- sprintf("INST_%05d", seq_len(n_inst))
  positions <- stats::setNames(rep(0, n_inst), ids)
  fills_per_pulse <- (fills_per_inst * n_inst) / n_pulses
  list(positions = positions,
       instrument_ids = ids,
       fills_per_pulse = fills_per_pulse,
       n_pulses = n_pulses,
       n_inst = n_inst)
}

mk_targets_for_pulse <- function(setup) {
  fpp <- setup$fills_per_pulse
  targets <- rep(0, setup$n_inst)
  fpp_int <- ceiling(fpp)
  if (fpp_int > 0L) {
    fill_idx <- sample.int(setup$n_inst, size = min(setup$n_inst, fpp_int))
    targets[fill_idx] <- runif(length(fill_idx), -10, 10)
  }
  names(targets) <- setup$instrument_ids
  targets
}

current_loop <- function(targets, positions) {
  fills <- 0L
  for (id in names(targets)) {
    desired <- as.numeric(targets[[id]])
    cur_qty <- as.numeric(positions[[id]] %||% 0)
    delta <- desired - cur_qty
    if (abs(delta) <= sqrt(.Machine$double.eps)) next
    fills <- fills + 1L
  }
  fills
}

vec_loop <- function(targets, positions) {
  desired_vec <- as.numeric(targets)
  positions_vec <- as.numeric(positions[names(targets)])
  delta_vec <- desired_vec - positions_vec
  fill_idx <- which(abs(delta_vec) > sqrt(.Machine$double.eps))
  fills <- length(fill_idx)
  for (j in fill_idx) {
    invisible(j)
  }
  fills
}

run_variant <- function(setup, variant_fn) {
  set.seed(99L)
  total_fills <- 0L
  for (p in seq_len(setup$n_pulses)) {
    targets <- mk_targets_for_pulse(setup)
    total_fills <- total_fills + variant_fn(targets, setup$positions)
  }
  total_fills
}

# Parity check
cat("=== parity check ===\n")
set.seed(99L)
parity_setup <- mk_setup(100, 135, 1260)
parity_targets <- mk_targets_for_pulse(parity_setup)
fills_c <- current_loop(parity_targets, parity_setup$positions)
fills_v <- vec_loop(parity_targets, parity_setup$positions)
parity_ok <- fills_c == fills_v
cat(sprintf("current=%d  vec=%d  [%s]\n\n",
            fills_c, fills_v, if (parity_ok) "OK" else "FAIL"))
if (!parity_ok) stop("Parity check failed.")

shapes <- list(
  list(n_inst = 100,  n_pulses = 1260, fills_per_inst = 135),
  list(n_inst = 500,  n_pulses = 1260, fills_per_inst = 135),
  list(n_inst = 1000, n_pulses = 1260, fills_per_inst = 135)
)

cat("=== timing ===\n")
cat(sprintf("%-6s %-7s %-7s %-10s | %9s %9s | %9s\n",
            "inst", "pulses", "fpi", "skip_ratio", "current", "vec", "cur/vec"))

res <- list()
for (s in shapes) {
  setup <- mk_setup(s$n_inst, s$fills_per_inst, s$n_pulses)
  skip_ratio <- 1 - min(1, setup$fills_per_pulse / s$n_inst)

  t_current <- system.time(run_variant(setup, current_loop))[["elapsed"]]
  t_vec <- system.time(run_variant(setup, vec_loop))[["elapsed"]]

  cat(sprintf("%-6d %-7d %-7d %-10.3f | %8.3fs %8.3fs | %8.1fx\n",
              s$n_inst, s$n_pulses, s$fills_per_inst, skip_ratio,
              t_current, t_vec, t_current / t_vec))

  res[[length(res) + 1L]] <- data.frame(
    n_inst = s$n_inst, n_pulses = s$n_pulses,
    fills_per_inst = s$fills_per_inst, skip_ratio = skip_ratio,
    current_s = t_current, vec_s = t_vec,
    speedup = t_current / t_vec
  )
}

out <- "dev/bench/results/spike_target_delta_vectorize.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, res), out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
