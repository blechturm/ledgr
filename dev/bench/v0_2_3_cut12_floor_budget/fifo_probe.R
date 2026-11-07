# Cut 12 R11 budget probe for the FIFO family (LDG-3213/3214).
#
# Floor v1 (dev/spikes/fold_plumbing/lean.R, fp_compact_fold at 2885596e)
# stubs every stage, so the FIFO stage's cost above floor v1 is the kernel's
# own cost at its call sites: the captured ledgr_lot_apply calls of one run,
# in order, divided by the run's pulses. This times one candidate kernel and
# the pinned kernel on the same captured calls, alternating, after checking
# the candidate reproduces every pinned result. Candidates:
#   spike  the lean-FIFO spike (dev/spikes/lean_fifo/kernel.R); it set the
#          budget (evidence/fifo_budget.csv, 2026-11-06)
#   lean   the lean kernel, lean_lot_apply(book, lean_lot_input(...)) from
#          dev/lean_core/fifo.R with debug off (LDG-3214's R11 check)
# Every candidate function is byte-compiled, as the installed pinned build
# is, and the JIT is off.
#
# Usage (host set up per benchmark_methodology: High performance plan,
# P-core affinity, no other R):
#   Rscript dev/bench/v0_2_3_cut12_floor_budget/fifo_probe.R <pinned lib> <captures dir> [rounds] [spike|lean] [out csv]
# where <captures dir> holds momentum_40x504.rds and fill_heavy_500x1260.rds
# from dev/lean_core/recorder/run.R --boundaries=lot. The default output is
# evidence/fifo_budget.csv (spike) or evidence/fifo_lean.csv (lean).

args <- commandArgs(TRUE)
lib <- args[[1L]]
captures <- args[[2L]]
rounds <- if (length(args) >= 3L) as.integer(args[[3L]]) else 7L
kernel <- if (length(args) >= 4L) args[[4L]] else "spike"
stopifnot(kernel %in% c("spike", "lean"))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
out_csv <- if (length(args) >= 5L) args[[5L]] else
  file.path(here, "evidence", if (kernel == "spike") "fifo_budget.csv" else "fifo_lean.csv")

source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(lib, debug = FALSE)
if (kernel == "lean") {
  for (f in ls(lean, all.names = TRUE)) {
    if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
  }
}
lean_core_source(lean, c(file.path(repo, "dev/bench/v0_2_3_ws16_entry/common.R"),
                         file.path(repo, "dev/lean_core/recorder", c("fields.R", "capture.R", "compare.R", "replay.R"))))
if (kernel == "spike") {
  source(file.path(repo, "dev/spikes/lean_fifo/kernel.R"))
  r_lean_fifo_fill <- compiler::cmpfun(r_lean_fifo_fill)
}
ns <- asNamespace("ledgr")
invisible(compiler::enableJIT(0L))

# The candidate's result for one captured call, and what parity compares:
# the spike's book (it returns no applied rows), the lean kernel's whole
# result.
candidate <- if (kernel == "spike") {
  function(k) r_lean_fifo_fill(k$book, k$input$pos, k$input$side, k$input$qty, k$input$price, k$input$fee)
} else {
  lean_input <- lean$lean_lot_input
  lean_apply <- lean$lean_lot_apply
  compiler::cmpfun(function(k) {
    i <- k$input
    lean_apply(k$book, lean_input(i$operation[[1L]], i$pos, i$side, i$qty, i$price, i$fee,
                                  i$position_before, i$realized_model_pnl))
  })
}
same_result <- if (kernel == "spike") {
  function(got, k) identical(got$book, k$expected$book)
} else {
  function(got, k) identical(got, k$expected)
}
# Budgets set by the spike run (README; R11, LDG-3214 acceptance).
budget <- c(momentum_40x504 = 4.2, fill_heavy_500x1260 = 113.2)

workloads <- c(momentum_40x504 = 504L, fill_heavy_500x1260 = 1260L)
rows <- list()
for (w in names(workloads)) {
  cap <- lean$lc_read_capture(file.path(captures, paste0(w, ".rds")))
  calls <- lapply(cap$records, function(r) {
    x <- lean$lc_thaw(r$input, cap$store)
    list(book = x[["arg:book"]], input = x[["arg:input"]], expected = lean$lc_thaw(r$output, cap$store)$value)
  })
  rm(cap)
  stopifnot(all(vapply(calls, function(k) all(k$input$operation == 1L), logical(1))))
  pinned <- function() for (k in calls) ns$ledgr_lot_apply(k$book, k$input)
  cand <- function() for (k in calls) candidate(k)
  # Parity first: the candidate must reproduce every pinned result.
  if (kernel == "spike") r_lean_fifo_stats$fallbacks <- 0L
  same <- vapply(calls, function(k) same_result(candidate(k), k), logical(1))
  stopifnot(all(same))
  fallbacks <- if (kernel == "spike") r_lean_fifo_stats$fallbacks else NA_integer_
  # Repeat short runs so each timing spans at least 0.5 s (clock resolution).
  t0 <- proc.time()[["elapsed"]]; cand(); one <- max(proc.time()[["elapsed"]] - t0, 0.001)
  reps <- max(1L, as.integer(ceiling(0.5 / one)))
  pinned_r <- function() for (j in seq_len(reps)) pinned()
  cand_r <- function() for (j in seq_len(reps)) cand()
  t_pin <- t_cand <- numeric(rounds)
  for (i in seq_len(rounds)) {
    t0 <- proc.time()[["elapsed"]]; pinned_r(); t_pin[i] <- (proc.time()[["elapsed"]] - t0) / reps
    t0 <- proc.time()[["elapsed"]]; cand_r(); t_cand[i] <- (proc.time()[["elapsed"]] - t0) / reps
  }
  pulses <- workloads[[w]]
  us <- function(t) round(1e6 * t / pulses, 1)
  row <- data.frame(
    workload = w, kernel = kernel, pulses = pulses, kernel_calls = length(calls),
    fills = sum(vapply(calls, function(k) length(k$input$pos), integer(1))),
    parity_calls = sum(same), fallbacks = fallbacks, rounds = rounds, reps = reps,
    pinned_us_per_pulse = us(stats::median(t_pin)),
    candidate_us_per_pulse = us(stats::median(t_cand)),
    candidate_us_per_pulse_min = us(min(t_cand)),
    candidate_us_per_pulse_max = us(max(t_cand))
  )
  if (kernel == "spike") {
    row$budget_us_per_pulse <- round(1.15 * 1e6 * stats::median(t_cand) / pulses, 1)
  } else {
    row$budget_us_per_pulse <- budget[[w]]
    row$within_budget <- row$candidate_us_per_pulse <= budget[[w]]
  }
  rows[[w]] <- row
}
out <- do.call(rbind, rows)
print(out, row.names = FALSE)
dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out, out_csv, row.names = FALSE)
