# LDG-3274: slice 5's close checks on the final code (Cut 26 decision 10),
# after Cut 21's recipe (evidence/cut21/ldg3248/COMMANDS.md). Every step is a
# fresh Rscript started from a directory outside any ledgr source package
# (LDG-3271); its output stays beside this file.
#
#   Rscript run_close.R --lib=<pin library> --dumps=<dir> --steps=<name,...>
#
# Batch one and inert run the workloads frozen in that mode (loop_freeze.csv
# with loop_freeze_changes.csv applied).
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (!length(hit)) return(default)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  p <- normalizePath(file.path(here, "..", ".."), winslash = "/")
  repo <- normalizePath(file.path(p, "..", "..", ".."), winslash = "/")
  lib <- normalizePath(arg("lib"), winslash = "/", mustWork = TRUE)
  freeze <- file.path(p, "loop_freeze.csv")
  wd <- tempfile("ldg3274_wd_")
  dir.create(wd)
  setwd(wd)
  rd <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = character())
  fz <- rd(freeze)
  ch <- rd(file.path(p, "loop_freeze_changes.csv"))
  listed <- function(mode) {
    w <- unique(c(fz$workload[fz$mode == mode], ch$workload[ch$mode == mode & ch$action == "add"]))
    paste(w, collapse = ",")
  }
  # pin dumps for the reach cross-checks: large, kept outside the tree
  dumps <- normalizePath(arg("dumps"), winslash = "/", mustWork = FALSE)
  lp <- function(...) c(file.path(p, "loop_parity.R"), paste0("--lib=", lib), paste0("--freeze=", freeze), ...)
  steps <- list(
    gate_debug0 = lp("--debug=0", paste0("--dump=", dumps), paste0("--out=", file.path(here, "gate_debug0.csv"))),
    gate_debug1 = lp("--debug=1", paste0("--out=", file.path(here, "gate_debug1.csv"))),
    batch1_debug0 = lp("--debug=0", "--batch-rows=1", paste0("--workloads=", listed("batch1")), paste0("--out=", file.path(here, "batch1_debug0.csv"))),
    batch1_debug1 = lp("--debug=1", "--batch-rows=1", paste0("--workloads=", listed("batch1")), paste0("--out=", file.path(here, "batch1_debug1.csv"))),
    inert_debug0 = lp("--debug=0", "--inert=1", paste0("--workloads=", listed("inert")), paste0("--out=", file.path(here, "inert_debug0.csv"))),
    inert_debug1 = lp("--debug=1", "--inert=1", paste0("--workloads=", listed("inert")), paste0("--out=", file.path(here, "inert_debug1.csv"))),
    variants_debug0 = c(file.path(p, "loop_variants.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "variants")), "--debug=0"),
    variants_debug1 = c(file.path(p, "loop_variants.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "variants")), "--debug=1"),
    witness = c(file.path(p, "hashed_frame_witness.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "witness"))),
    loop_dispatch = c(file.path(p, "loop_dispatch.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "loop_dispatch.csv"))),
    plan_parity_debug0 = c(file.path(p, "plan_parity.R"), paste0("--lib=", lib), "--debug=0", paste0("--out=", file.path(here, "plan_parity_debug0.csv"))),
    plan_parity_debug1 = c(file.path(p, "plan_parity.R"), paste0("--lib=", lib), "--debug=1", paste0("--out=", file.path(here, "plan_parity_debug1.csv"))),
    cut18_witness = c(file.path(p, "cut18_witness.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "cut18_witness.csv"))),
    slice2_reach_cross = c(file.path(p, "slice2_reach_cross.R"), paste0("--lib=", lib), paste0("--dump=", dumps), paste0("--out=", file.path(here, "slice2_reach_cross.csv"))),
    slice3_reach_cross = c(file.path(p, "slice3_reach_cross.R"), paste0("--lib=", lib), paste0("--dump=", dumps), paste0("--out=", file.path(here, "slice3_reach_cross.csv"))),
    slice4_reach_cross = c(file.path(p, "slice4_reach_cross.R"), paste0("--lib=", lib), paste0("--dump=", dumps), "--set=slice4", paste0("--out=", file.path(here, "slice4_reach_cross.csv"))))
  only <- strsplit(arg("steps", paste(names(steps), collapse = ",")), ",")[[1L]]
  if (length(bad <- setdiff(only, names(steps)))) stop("unknown step(s): ", paste(bad, collapse = ", "), call. = FALSE)
  if ("gate_debug0" %in% only) dir.create(dumps, showWarnings = FALSE)
  for (s in only) {
    t0 <- proc.time()[["elapsed"]]
    log <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript.exe"), steps[[s]], stdout = TRUE, stderr = TRUE))
    writeLines(log, file.path(here, paste0(s, ".log")))
    status <- attr(log, "status")
    cat(sprintf("%s: status %s, %.0f s; %s\n", s, if (is.null(status)) 0L else status, proc.time()[["elapsed"]] - t0,
                utils::tail(log, 1L)))
  }
})
