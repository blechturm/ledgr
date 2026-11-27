# Workstream 46 close review round 1: the proofs for F1 and F2.
#
#   Rscript run_r1.R --lib=<pin library> --work=<scratch dir outside any source package>
#
# F1 changes the worker channel (loop_workers.R): code that runs only in
# sweep workers (the envelope wrapper, the task record) and, in the parent,
# only per worker record. So the parity steps rerun every workload that
# dispatches workers (the worker records of the committed final-code runs
# in ../*_workers.csv) plus the new witness, in each mode and debug setting
# with the approved freeze. The variant driver reruns every variant row on
# those workloads, the new one included, and the five negative controls.
# F2 changes recorder/run.R's argument handling: a relative --src control.
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  p <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")   # dev/lean_core/parity
  ev <- dirname(here)
  lib <- normalizePath(arg("lib"), winslash = "/", mustWork = TRUE)
  work <- normalizePath(arg("work"), winslash = "/", mustWork = TRUE)
  setwd(work)
  rs <- file.path(R.home("bin"), "Rscript.exe")
  workers <- function(mode) {
    w <- utils::read.csv(file.path(ev, paste0(mode, "_debug0_workers.csv")), stringsAsFactors = FALSE)
    c(sort(unique(w$workload)), "s5_workers_compiled_refused")
  }
  lp <- function(...) c(file.path(p, "loop_parity.R"), paste0("--lib=", lib), paste0("--freeze=", file.path(p, "loop_freeze.csv")), ...)
  step <- function(name, args) {
    log <- file.path(here, paste0(name, ".log"))
    st <- suppressWarnings(system2(rs, args, stdout = log, stderr = log))
    cat(format(Sys.time(), "%H:%M:%S"), name, "status", st, "\n")
  }
  for (d in 0:1) {
    step(sprintf("gate_debug%d", d), lp(paste0("--debug=", d), paste0("--workloads=", paste(workers("gate"), collapse = ",")),
                                        paste0("--out=", file.path(here, sprintf("gate_debug%d.csv", d)))))
    step(sprintf("batch1_debug%d", d), lp(paste0("--debug=", d), "--batch-rows=1", paste0("--workloads=", paste(workers("batch1"), collapse = ",")),
                                          paste0("--out=", file.path(here, sprintf("batch1_debug%d.csv", d)))))
    step(sprintf("inert_debug%d", d), lp(paste0("--debug=", d), "--inert=1", paste0("--workloads=", paste(workers("inert"), collapse = ",")),
                                         paste0("--out=", file.path(here, sprintf("inert_debug%d.csv", d)))))
  }
  # variant rows on the worker workloads (those that carry any)
  read <- function(f) utils::read.csv(file.path(p, f), stringsAsFactors = FALSE, na.strings = character())
  rows <- unique(c(read("loop_variants.csv")$workload, read("loop_variant_changes.csv")$workload))
  vw <- intersect(workers("gate"), rows)
  cat("variant workloads:", paste(vw, collapse = ","), "\n")
  for (d in 0:1) {
    step(sprintf("variants_debug%d", d), c(file.path(p, "loop_variants.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "variants")),
                                           paste0("--debug=", d), paste0("--workloads=", paste(vw, collapse = ","))))
  }
  # F2: the recorder with a relative --src (the pinned source archive beside
  # the work directory), every output outside the tree.
  rec <- file.path(work, "recorder")
  dir.create(rec, showWarnings = FALSE)
  step("recorder_relative_src", c(file.path(p, "..", "recorder", "run.R"), paste0("--lib=", lib),
       paste0("--captures=", file.path(rec, "captures")), paste0("--out=", file.path(rec, "out")),
       paste0("--manifests=", file.path(rec, "manifests")), "--workloads=avail_incomplete", "--src=../pin-archive"))
})
