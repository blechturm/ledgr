# Shared timing harness (LDG-3155): one slot in one fresh R process.
#
# Called by runner.R only. In order: probe the host (its own PID, creation
# time, affinity and ancestor chain, the power plan and, as an annotation,
# other R processes);
# load ledgr from the arm's library and verify the loaded namespace path and
# the arm's commit stamp; source the protocol's workloads.R; run the cell's
# workload, which times itself; write one raw row. Errors are written into the
# row and never retried.
#
# Usage: Rscript --no-init-file measure.R --protocol=<dir> --lib=<arm library>
#   --slot=<n> --pair=<k> --arm=base|candidate --cell=<cell> --work=<dir>
#   --out=<row csv> [--test-kill]
#
# --test-kill is the interruption demonstration's hook: the process kills
# itself after loading ledgr, before the workload, so no row is written. The
# runner records the hook in session.csv and the checker refuses that record.

here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/")
source(file.path(here, "host.R"))
source(file.path(here, "protocol.R"))
opt <- timing_args()

row <- as.list(stats::setNames(rep(NA_character_, length(timing_raw_fields)), timing_raw_fields))
row$slot <- opt("slot"); row$pair <- opt("pair"); row$arm <- opt("arm"); row$cell <- opt("cell")
row$outcome <- "error"
row$pid <- as.character(Sys.getpid())

measure <- function() {
  if (length(list.files(opt("work"), all.files = TRUE, no.. = TRUE))) stop("the slot work directory is not empty")
  probe <- timing_host_probe(here)
  me <- probe$procs[probe$procs$pid == Sys.getpid(), , drop = FALSE]
  if (nrow(me) != 1L) stop("the host probe did not list this process")
  row$created <<- sprintf("%.0f", me$created)
  row$affinity <<- sprintf("%.0f", me$affinity)
  row$chain <<- timing_chain(probe$procs, Sys.getpid())
  row$foreign_r <<- timing_foreign_r(probe$procs, row$chain)
  row$plan_guid <<- probe$plan_guid

  lib <- normalizePath(opt("lib"), winslash = "/")
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns_path <- normalizePath(getNamespaceInfo(asNamespace("ledgr"), "path"), winslash = "/")
  row$ledgr_path <<- ns_path
  if (!identical(tolower(dirname(ns_path)), tolower(lib))) stop("ledgr was not loaded from the arm library")
  row$ledgr_commit <<- readLines(file.path(dirname(ns_path), "timing_arm.txt"), warn = FALSE)[[1L]]

  if (isTRUE(opt("test-kill"))) tools::pskill(Sys.getpid())

  protocol <- timing_read_protocol(opt("protocol"))
  cell <- protocol$cells[protocol$cells$cell == row$cell, , drop = FALSE]
  if (nrow(cell) != 1L) stop("unknown cell ", row$cell)
  row$clock <<- cell$clock
  workloads <- new.env()
  sys.source(file.path(protocol$dir, "workloads.R"), envir = workloads)
  result <- get(cell$workload, envir = workloads, inherits = FALSE)(timing_parse_args(cell$args), opt("work"))
  seconds <- result$seconds[cell$clock]
  if (length(seconds) != 1L || is.na(names(seconds))) stop("workload did not report clock ", cell$clock)
  work <- as.character(result$work)
  if (length(work) != 1L || is.na(work) || !nzchar(trimws(work))) stop("workload did not report its work string")
  row$seconds <<- sprintf("%.17g", as.double(seconds))
  row$work <<- work
  row$outcome <<- "ok"
}

tryCatch(measure(), error = function(e) row$error <<- gsub("[\r\n]+", " ", conditionMessage(e)))
utils::write.csv(as.data.frame(row, stringsAsFactors = FALSE), opt("out"), row.names = FALSE, na = "NA",
  fileEncoding = "UTF-8")
