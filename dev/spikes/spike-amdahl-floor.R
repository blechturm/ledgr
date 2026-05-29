# Spike: estimate ledgr's Amdahl (irreducible) loop component.
#
# Question: of the per-pulse fold loop, how much is the IRREDUCIBLE
# strategy-callback + user logic (which no engine optimization can remove for an
# event-driven, path-dependent backtest), vs OPTIMIZABLE ledgr machinery (ctx
# build, feature access, fill emission)? That decides whether ledgr's single-run
# ceiling is callback-bound (~backtrader) or machinery-bound (room to beat it).
#
# Part A (standalone): the irreducible floor -- the minimum per-pulse work an
#   event-driven R strategy must do (build an n_inst target vector + vectorized
#   decision), with NO engine around it. The pulse loop itself is sequential
#   (positions evolve), so the callback cannot be vectorized away.
# Part B (fold differential, via the bench): empty -> read/score -> turnover
#   t_loop, splitting ctx-build / feature-access / fill-emission machinery.
#
# Relates to: inst/design/collapse_optimization_map.md, the buffer/reconstruction
# spikes. Usage: Rscript dev/spikes/spike-amdahl-floor.R

NI <- 200L; NP <- 504L
universe <- sprintf("S%03d", seq_len(NI))
set.seed(20260529L)
fast <- matrix(rnorm(NI * NP), NI, NP); slow <- matrix(rnorm(NI * NP), NI, NP)
flat <- stats::setNames(rep(0, NI), universe)

cat(sprintf("shape: %d inst x %d pulses\n\n", NI, NP))

# --- Part A: irreducible floor -----------------------------------------------
# The floor is sub-millisecond per run, below system.time resolution, so repeat
# REPS times and divide to get a real number.
REPS <- 2000L
t_floor <- system.time(for (rep in seq_len(REPS)) for (i in seq_len(NP)) {
  tg <- flat                      # the strategy must return an n_inst target vector
  long <- fast[, i] > slow[, i]   # vectorized per-pulse decision (user logic)
  tg[long] <- 1
})[["elapsed"]] / REPS
cat("== Part A: irreducible floor (no engine) ==\n")
cat(sprintf("  flat-target build + vec decision : %.5fs/run  (%.2f us/pulse)\n\n",
            t_floor, 1e6 * t_floor / NP))

# --- Part B: fold differential (machinery) -----------------------------------
suppressWarnings(suppressMessages(source(file.path("dev", "bench", "run_benchmarks.R"))))
bench_load_ledgr_source()
mk <- function(nf, tr) list(kind = "run", n_inst = NI, n_pulses = NP, n_feat = nf, trade = tr)
tloop <- function(name, spec) {
  invisible(bench_run_scenario_once(paste0(name, "_w"), spec, 1L, 7L, TRUE))   # warmup
  bench_run_scenario_once(name, spec, 2L, 7L, FALSE)$t_loop_sec
}
e <- tloop("amdahl_empty", mk(0L, FALSE))     # ctx-build + scaffold (no features, no trade)
r <- tloop("amdahl_read",  mk(2L, FALSE))     # + feature access (reads features_wide, no trade)
t <- tloop("amdahl_turn",  mk(2L, TRUE))      # + fill emission (incl current buffer)

cat("== Part B: fold loop decomposition (t_loop, differential) ==\n")
cat(sprintf("  empty (ctx-build + scaffold)        : %.3fs\n", e))
cat(sprintf("  feature access (read - empty)       : %.3fs\n", r - e))
cat(sprintf("  fill emission (turnover - read)     : %.3fs   (incl current buffer)\n", t - r))
cat(sprintf("  total loop (turnover)               : %.3fs\n\n", t))

cat("== Amdahl estimate ==\n")
cat(sprintf("  irreducible floor (Part A)          : %.4fs  (%.2f%% of current loop)\n", t_floor, 100 * t_floor / t))
cat(sprintf("  optimizable machinery (loop - floor): %.3fs  (%.2f%%)\n", t - t_floor, 100 * (t - t_floor) / t))

out <- "dev/bench/results/spike_amdahl_floor.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(data.frame(
  component = c("irreducible_floor", "ctx_build_scaffold", "feature_access", "fill_emission_incl_buffer", "total_loop"),
  seconds = c(t_floor, e, r - e, t - r, t)), out, row.names = FALSE)
cat("\nWROTE", out, "\n")
