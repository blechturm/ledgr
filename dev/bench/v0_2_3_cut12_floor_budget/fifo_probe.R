# Cut 12 R11 budget probe for the FIFO family (LDG-3213/3214).
#
# Floor v1 (dev/spikes/fold_plumbing/lean.R, fp_compact_fold at 2885596e)
# stubs every stage, so the FIFO stage's cost above floor v1 is the kernel's
# own cost at its call sites: the captured ledgr_lot_apply calls of one run,
# in order, divided by the run's pulses. This times the lean-FIFO spike
# kernel (dev/spikes/lean_fifo/kernel.R) and the pinned kernel on the same
# captured calls, alternating, after checking the spike reproduces every
# pinned result.
#
# Usage (host set up per benchmark_methodology: High performance plan,
# P-core affinity, no other R):
#   Rscript dev/bench/v0_2_3_cut12_floor_budget/fifo_probe.R <pinned lib> <captures dir> [rounds]
# where <captures dir> holds momentum_40x504.rds and fill_heavy_500x1260.rds
# from dev/lean_core/recorder/run.R --boundaries=lot.

args <- commandArgs(TRUE)
lib <- args[[1L]]
captures <- args[[2L]]
rounds <- if (length(args) >= 3L) as.integer(args[[3L]]) else 7L

source("dev/lean_core/load.R")
lean <- lean_core_load(lib)
lean_core_source(lean, c("dev/bench/v0_2_3_ws16_entry/common.R",
                         file.path("dev/lean_core/recorder", c("fields.R", "capture.R", "compare.R", "replay.R"))))
source("dev/spikes/lean_fifo/kernel.R")
# The pinned kernel is byte-compiled (installed package); compile the spike too.
r_lean_fifo_fill <- compiler::cmpfun(r_lean_fifo_fill)
ns <- asNamespace("ledgr")
invisible(compiler::enableJIT(0L))

workloads <- c(momentum_40x504 = 504L, fill_heavy_500x1260 = 1260L)
rows <- list()
for (w in names(workloads)) {
  cap <- lean$lc_read_capture(file.path(captures, paste0(w, ".rds")))
  calls <- lapply(cap$records, function(r) {
    x <- lean$lc_thaw(r$input, cap$store)
    list(book = x[["arg:book"]], input = x[["arg:input"]], expected = lean$lc_thaw(r$output, cap$store)$value)
  })
  stopifnot(all(vapply(calls, function(k) all(k$input$operation == 1L), logical(1))))
  pinned <- function() for (k in calls) ns$ledgr_lot_apply(k$book, k$input)
  spike <- function() for (k in calls) r_lean_fifo_fill(k$book, k$input$pos, k$input$side, k$input$qty, k$input$price, k$input$fee)
  # Parity first: the spike must reproduce every pinned result.
  r_lean_fifo_stats$fallbacks <- 0L
  same <- vapply(calls, function(k) {
    got <- r_lean_fifo_fill(k$book, k$input$pos, k$input$side, k$input$qty, k$input$price, k$input$fee)
    identical(got$book, k$expected$book)
  }, logical(1))
  stopifnot(all(same))
  fallbacks <- r_lean_fifo_stats$fallbacks
  # Repeat short runs so each timing spans at least 0.5 s (clock resolution).
  t0 <- proc.time()[["elapsed"]]; spike(); one <- max(proc.time()[["elapsed"]] - t0, 0.001)
  reps <- max(1L, as.integer(ceiling(0.5 / one)))
  pinned_r <- function() for (j in seq_len(reps)) pinned()
  spike_r <- function() for (j in seq_len(reps)) spike()
  t_pin <- t_spk <- numeric(rounds)
  for (i in seq_len(rounds)) {
    t0 <- proc.time()[["elapsed"]]; pinned_r(); t_pin[i] <- (proc.time()[["elapsed"]] - t0) / reps
    t0 <- proc.time()[["elapsed"]]; spike_r(); t_spk[i] <- (proc.time()[["elapsed"]] - t0) / reps
  }
  pulses <- workloads[[w]]
  rows[[w]] <- data.frame(
    workload = w, pulses = pulses, kernel_calls = length(calls),
    fills = sum(vapply(calls, function(k) length(k$input$pos), integer(1))),
    fallbacks = fallbacks, rounds = rounds, reps = reps,
    pinned_us_per_pulse = round(1e6 * stats::median(t_pin) / pulses, 1),
    spike_us_per_pulse = round(1e6 * stats::median(t_spk) / pulses, 1),
    spike_us_per_pulse_min = round(1e6 * min(t_spk) / pulses, 1),
    spike_us_per_pulse_max = round(1e6 * max(t_spk) / pulses, 1),
    budget_us_per_pulse = round(1.15 * 1e6 * stats::median(t_spk) / pulses, 1)
  )
}
out <- do.call(rbind, rows)
print(out, row.names = FALSE)
dir.create("dev/bench/v0_2_3_cut12_floor_budget/evidence", showWarnings = FALSE)
utils::write.csv(out, "dev/bench/v0_2_3_cut12_floor_budget/evidence/fifo_budget.csv", row.names = FALSE)
