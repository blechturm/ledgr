# LDG-3273 (and LDG-3272's variant witnesses): runs each proof in a fresh
# loop_parity.R subprocess from a directory outside any source package and
# keeps its output beside this file.
#
#   Rscript run_proofs.R --lib=<pin library> [--steps=<name,...>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (!length(hit)) return(default)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  lp <- normalizePath(file.path(here, "..", "..", "loop_parity.R"), winslash = "/")
  lib <- normalizePath(arg("lib"), winslash = "/", mustWork = TRUE)
  wd <- tempfile("ldg3273_wd_")
  dir.create(wd)
  setwd(wd)
  workers <- c("dense_cost", "dense_risk_features", "avail_terminal_resume", "avail_incomplete", "failures",
               "witness_sweep_workers", "walk_forward", "witness_walk_forward", "s5_workers_sizing", "s5_workers_missing",
               "s5_workers_facts", "s5_workers_dividend", "s5_workers_consecutive", "s5_workers_failing",
               "s5_workers_backstop", "s5_workers_backstop_escape", "s5_walk_forward_workers")
  steps <- list(
    workers_gate_debug0 = c("--debug=0"),
    workers_gate_debug1 = c("--debug=1"),
    workers_inert_debug0 = c("--debug=0", "--inert=1"),
    workers_inert_debug1 = c("--debug=1", "--inert=1"),
    workers_batch1_debug0 = c("--debug=0", "--batch-rows=1"),
    workers_batch1_debug1 = c("--debug=1", "--batch-rows=1"),
    compiled_dispatch_skipped_debug0 = c("--debug=0", "--mutation=compiled_dispatch_skipped", "--workloads=s5_compiled_missing_native"),
    compiled_dispatch_skipped_debug1 = c("--debug=1", "--mutation=compiled_dispatch_skipped", "--workloads=s5_compiled_missing_native"),
    compiled_event_kinds_skipped_debug0 = c("--debug=0", "--mutation=compiled_event_kinds_skipped", "--workloads=s5_compiled_event_kinds"),
    compiled_event_kinds_skipped_debug1 = c("--debug=1", "--mutation=compiled_event_kinds_skipped", "--workloads=s5_compiled_event_kinds"),
    capacity_late_debug0 = c("--debug=0", "--mutation=capacity_late", "--workloads=s5_compiled_capacity_over"),
    capacity_late_debug1 = c("--debug=1", "--mutation=capacity_late", "--workloads=s5_compiled_capacity_over"),
    capacity_late_batch1_debug0 = c("--debug=0", "--batch-rows=1", "--mutation=capacity_late", "--workloads=s5_compiled_capacity_over"),
    capacity_late_batch1_debug1 = c("--debug=1", "--batch-rows=1", "--mutation=capacity_late", "--workloads=s5_compiled_capacity_over"))
  # The worker variants (loop_variant_changes.csv, Cut 26 decision 5), each
  # on its workload, debug off and on (cost_columns_short: debug on only).
  wv <- list(c("worker_lean_not_installed", "witness_sweep_workers", "65536"),
             c("worker_record_dropped", "witness_sweep_workers", "65536"),
             c("worker_record_duplicated", "witness_sweep_workers", "65536"),
             c("worker_wrong_build", "witness_sweep_workers", "65536"),
             c("worker_backstop_rerun_skipped", "s5_workers_backstop,s5_workers_backstop_escape", "65536"),
             c("worker_rng_restore_skipped", "s5_workers_backstop,s5_workers_backstop_escape", "65536"),
             c("worker_terminal_write", "witness_sweep_workers", "65536"),
             c("worker_capacity_lowered", "s5_workers_consecutive", "65536"),
             c("worker_hold_signal", "witness_sweep_workers", "65536"),
             c("store_execute", "witness_sweep_workers", "65536"),
             c("write_in_loop", "witness_sweep_workers", "65536"),
             c("expand_whole", "witness_sweep_workers", "1"),
             c("cost_columns_short", "s5_workers_sizing", "65536"))
  for (v in wv) for (d in 0:1) {
    if (v[[1L]] == "cost_columns_short" && d == 0L) next
    steps[[sprintf("variant_%s_debug%d", v[[1L]], d)]] <- c(paste0("--debug=", d), paste0("--mutation=", v[[1L]]),
      paste0("--workloads=", v[[2L]]), paste0("--batch-rows=", v[[3L]]))
  }
  # The debug-only check with debug off: the production result (no
  # assertion; recorded, not a CAUGHT row).
  steps$variant_cost_columns_short_debug0_production <- c("--debug=0", "--mutation=cost_columns_short",
    "--workloads=s5_workers_sizing")
  only <- arg("steps")
  if (!is.null(only)) steps <- steps[strsplit(only, ",")[[1L]]]
  for (s in names(steps)) {
    a <- steps[[s]]
    if (!any(startsWith(a, "--workloads="))) a <- c(a, paste0("--workloads=", paste(workers, collapse = ",")))
    out <- file.path(here, paste0(s, ".csv"))
    log <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript.exe"),
      c(lp, paste0("--lib=", lib), paste0("--out=", out), a), stdout = TRUE, stderr = TRUE))
    writeLines(log, file.path(here, paste0(s, ".txt")))
    status <- attr(log, "status")
    cat(sprintf("%s: status %s; %s\n", s, if (is.null(status)) 0L else status, utils::tail(log, 1L)))
  }
})
