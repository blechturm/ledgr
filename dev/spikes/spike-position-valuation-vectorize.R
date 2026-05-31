# Spike: per-pulse position valuation loop vs vectorized replacement
#
# Context: R/fold-engine.R:164-170 has an O(n_inst) loop per pulse that marks
# positions to market for the pulse-context equity field. Hypothesis: replacing
# with a single sum(positions * close_col) is 10x-100x faster in isolation,
# recovering ~9s of 413s loop time on density_high_xlarge_durable.
#
# FAITHFULNESS: replicates state$positions as a named numeric vector aligned to
# instrument_ids; bars_mat$close as a matrix of shape [n_inst, n_pulses]. The
# current-loop body matches fold-engine.R exactly, including the qty == 0
# early-skip. The vec variant tests the suggested fix. The vec_ord variant tests
# the alignment-risk hedge: index by instrument_ids before passing through
# as.numeric().
#
# Variants:
#   current  : R loop with per-id [[ ]] lookup and qty == 0 early-skip
#   vec      : sum(as.numeric(state$positions) * bars_mat$close[, i])
#   vec_ord  : sum(as.numeric(state$positions[instrument_ids]) * bars_mat$close[, i])
#
# Density: position-vector sparsity (fraction of non-zero positions). The
# current loop benefits from early-skip on sparse positions. The vec variants
# do not skip and pay the full sum. So the spike should show whether the loop
# ever wins on extremely sparse cases.
#
# CAVEAT: isolated replica overestimates absolute cost vs the production
# handler. Trust the RELATIVE speedup and the mechanism, not the seconds. The
# real-run re-profile against density_high_xlarge_durable is the verdict.
#
# Usage:
#   Rscript dev/spikes/spike-position-valuation-vectorize.R

`%||%` <- function(x, y) if (is.null(x)) y else x

mk_state <- function(n_inst, density = 0.5, seed = 42L) {
  set.seed(seed)
  pos <- runif(n_inst, 1, 100)
  zero_n <- floor(n_inst * (1 - density))
  if (zero_n > 0L) pos[sample(seq_len(n_inst), zero_n)] <- 0
  ids <- sprintf("INST_%05d", seq_len(n_inst))
  names(pos) <- ids
  list(positions = pos, instrument_ids = ids)
}

mk_bars_mat <- function(n_inst, n_pulses, seed = 43L) {
  set.seed(seed)
  list(close = matrix(runif(n_inst * n_pulses, 50, 150),
                      nrow = n_inst, ncol = n_pulses))
}

current_loop <- function(state, instrument_ids, bars_mat, n_pulses) {
  acc <- 0
  for (i in seq_len(n_pulses)) {
    positions_value <- 0
    for (j in seq_along(instrument_ids)) {
      inst <- instrument_ids[[j]]
      qty <- as.numeric(state$positions[[inst]] %||% 0)
      if (qty == 0) next
      positions_value <- positions_value + qty * bars_mat$close[j, i]
    }
    acc <- acc + positions_value
  }
  acc
}

vec_replacement <- function(state, bars_mat, n_pulses) {
  acc <- 0
  positions <- as.numeric(state$positions)
  for (i in seq_len(n_pulses)) {
    positions_value <- sum(positions * bars_mat$close[, i])
    acc <- acc + positions_value
  }
  acc
}

vec_ord <- function(state, instrument_ids, bars_mat, n_pulses) {
  acc <- 0
  positions <- as.numeric(state$positions[instrument_ids])
  for (i in seq_len(n_pulses)) {
    positions_value <- sum(positions * bars_mat$close[, i])
    acc <- acc + positions_value
  }
  acc
}

# Parity check: at one pulse, all three return the same value
check_parity <- function(state, instrument_ids, bars_mat) {
  pulse <- 1L
  pv_current <- {
    pv <- 0
    for (j in seq_along(instrument_ids)) {
      inst <- instrument_ids[[j]]
      qty <- as.numeric(state$positions[[inst]] %||% 0)
      if (qty == 0) next
      pv <- pv + qty * bars_mat$close[j, pulse]
    }
    pv
  }
  pv_vec <- sum(as.numeric(state$positions) * bars_mat$close[, pulse])
  pv_vec_ord <- sum(as.numeric(state$positions[instrument_ids]) * bars_mat$close[, pulse])
  list(current = pv_current, vec = pv_vec, vec_ord = pv_vec_ord)
}

shapes <- list(
  list(n_inst = 100,  n_pulses = 1260, density = 0.5),
  list(n_inst = 500,  n_pulses = 1260, density = 0.5),
  list(n_inst = 1000, n_pulses = 1260, density = 0.5),
  list(n_inst = 1000, n_pulses = 1260, density = 0.1),
  list(n_inst = 1000, n_pulses = 1260, density = 0.9)
)

cat("=== parity check ===\n")
parity_state <- mk_state(100, 0.5)
parity_bars <- mk_bars_mat(100, 10)
par <- check_parity(parity_state, parity_state$instrument_ids, parity_bars)
parity_ok <- isTRUE(all.equal(par$current, par$vec)) && isTRUE(all.equal(par$current, par$vec_ord))
cat(sprintf("current=%.6f vec=%.6f vec_ord=%.6f  [%s]\n\n",
            par$current, par$vec, par$vec_ord,
            if (parity_ok) "OK" else "FAIL"))
if (!parity_ok) stop("Parity check failed; investigate before timing.")

cat("=== timing ===\n")
cat(sprintf("%-6s %-7s %-7s | %9s %9s %9s | %9s %9s\n",
            "inst", "pulses", "density", "current", "vec", "vec_ord",
            "cur/vec", "cur/ord"))

res <- list()
for (s in shapes) {
  state <- mk_state(s$n_inst, s$density)
  bars <- mk_bars_mat(s$n_inst, s$n_pulses)
  ids <- state$instrument_ids

  t_current <- system.time(current_loop(state, ids, bars, s$n_pulses))[["elapsed"]]
  t_vec <- system.time(vec_replacement(state, bars, s$n_pulses))[["elapsed"]]
  t_ord <- system.time(vec_ord(state, ids, bars, s$n_pulses))[["elapsed"]]

  cat(sprintf("%-6d %-7d %-7.2f | %8.3fs %8.3fs %8.3fs | %8.1fx %8.1fx\n",
              s$n_inst, s$n_pulses, s$density,
              t_current, t_vec, t_ord,
              t_current / t_vec, t_current / t_ord))

  res[[length(res) + 1L]] <- data.frame(
    n_inst = s$n_inst, n_pulses = s$n_pulses, density = s$density,
    current_s = t_current, vec_s = t_vec, vec_ord_s = t_ord,
    speedup_vec = t_current / t_vec, speedup_vec_ord = t_current / t_ord
  )
}

out <- "dev/bench/results/spike_position_valuation_vectorize.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, res), out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
