# Runner (LDG-3278): the lean parity gate with the explicit-state fork
# installed through loop_parity.R --witness=, one phase at a time; writes the
# evidence CSVs.
#   Rscript run.R --lib=<pinned library> --phase=prereq|gut|extend|large
#     [--evidence=<dir>] [--scratch=<dir>]
# Phases:
#   prereq  install_commit.R, debug 0 and 1, the prerequisite set
#   gut     install_gut.R, debug 0, crossover_3x40 and s2_cost_chain (must differ)
#   extend  install_all.R, debug 0 and 1, the prerequisite set + crossover_10x300
#   large   install_all.R, debug 0, crossover_10x7200, crossover_20x23400, crossover_500x1260
# Writes <evidence>/<phase>_summary.csv (one row per gate run: tables,
# differences, verdicts, exit status, the fork's install line, forked
# workers) and <evidence>/<phase>_d<debug>_tables.csv (workload, table,
# identical, verdict). Logs go to <scratch>.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
lib <- normalizePath(arg("lib"), winslash = "/")
phase <- arg("phase")
evidence <- normalizePath(arg("evidence", file.path(here, "evidence")), winslash = "/", mustWork = FALSE)
scratch <- normalizePath(arg("scratch", "C:/Users/maxth/ledgr-wt/cut27-scratch/spike"), winslash = "/", mustWork = FALSE)
rundir <- "C:/Users/maxth/ledgr-wt/cut27-scratch/run"
dir.create(evidence, recursive = TRUE, showWarnings = FALSE)
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
parity <- normalizePath(file.path(here, "..", "..", "lean_core", "parity", "loop_parity.R"), winslash = "/")
freeze <- normalizePath(file.path(here, "..", "..", "lean_core", "parity", "loop_freeze.csv"), winslash = "/")
small <- c("crossover_3x40", "s2_cost_chain", "s3_freeze_held", "s4_dividend", "s5_workers_sizing", "ovf_delta_then_lot")
plan <- switch(phase,
  prereq = list(witness = "install_commit.R", debug = c(0L, 1L), workloads = small),
  gut = list(witness = "install_gut.R", debug = 0L, workloads = c("crossover_3x40", "s2_cost_chain")),
  extend = list(witness = "install_all.R", debug = c(0L, 1L), workloads = c(small, "crossover_10x300")),
  large = list(witness = "install_all.R", debug = 0L, workloads = c("crossover_10x7200", "crossover_20x23400", "crossover_500x1260")),
  stop("unknown --phase: ", phase, call. = FALSE))

old <- setwd(rundir)
on.exit(setwd(old))
rows <- list()
for (d in plan$debug) {
  tag <- sprintf("%s_d%d", phase, d)
  log <- file.path(scratch, paste0(tag, ".log"))
  csv <- file.path(scratch, paste0(tag, ".csv"))
  marks <- file.path(scratch, "worker_marks", tag)
  if (dir.exists(marks)) unlink(marks, recursive = TRUE)
  Sys.setenv(ES_WORKER_MARKS = marks)
  t0 <- proc.time()[["elapsed"]]
  status <- system2(rscript, c(parity, paste0("--lib=", lib), paste0("--out=", csv),
    paste0("--workloads=", paste(plan$workloads, collapse = ",")), paste0("--debug=", d),
    paste0("--witness=", file.path(here, plan$witness)), paste0("--freeze=", freeze)), stdout = log, stderr = log)
  secs <- proc.time()[["elapsed"]] - t0
  lines <- readLines(log, warn = FALSE)
  last <- grep("^[0-9]+ tables, [0-9]+ different", lines, value = TRUE)
  last <- if (length(last)) last[[length(last)]] else NA_character_
  fork <- grep("^explicit-state fork installed", lines, value = TRUE)
  wm <- if (dir.exists(marks)) list.files(marks) else character()
  rows[[length(rows) + 1L]] <- data.frame(phase = phase, witness = plan$witness, debug = d,
    workloads = paste(plan$workloads, collapse = " "),
    tables = if (is.na(last)) NA_integer_ else as.integer(sub(" tables.*", "", last)),
    different = if (is.na(last)) NA_integer_ else as.integer(sub("^[0-9]+ tables, ([0-9]+) different.*", "\\1", last)),
    verdicts = if (is.na(last)) NA_character_ else sub(".*verdicts: ", "", last),
    exit_status = as.integer(status), fork_installed = length(fork) > 0L,
    fork_line = if (length(fork)) sub("^explicit-state fork installed: ", "", fork[[1L]]) else "",
    forked_workers = length(wm), stringsAsFactors = FALSE)
  cat(sprintf("%s: %s  exit %d  forked workers %d  (%.0f s)\n", tag, last, status, length(wm), secs))
  if (file.exists(csv)) {
    t <- utils::read.csv(csv, stringsAsFactors = FALSE)
    keep <- intersect(c("workload", "id", "table", "identical", "verdict"), names(t))
    utils::write.csv(t[keep], file.path(evidence, paste0(tag, "_tables.csv")), row.names = FALSE)
  }
}
utils::write.csv(do.call(rbind, rows), file.path(evidence, paste0(phase, "_summary.csv")), row.names = FALSE)
