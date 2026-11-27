# LDG-3283: Cut 27's proof matrix on the final code and the new pin
# 7f65733f (decisions 2, 9 and 10), after Cut 26's run_close.R. Every step is
# a fresh Rscript started from a directory outside any ledgr source package;
# its output stays beside this file, large captures under --scratch.
#
#   Rscript run_close.R --lib=<pin library> --src=<pin source archive>
#     --records=<pin-outcomes dir> --scratch=<dir> --steps=<name,...>
#
# The debug-0 gate is LDG-3282's recording run (loop_parity.R --dump
# --dump-lean, the same final code and freeze); its CSV and log are copied
# here as gate_debug0.*. The reach cross-checks read its pin dumps
# (<records>/gate). Steps that load the pin source archive (the FIFO test
# captures) run alone: one process per source tree at a time.
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (!length(hit)) return(default)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  p <- normalizePath(file.path(here, "..", ".."), winslash = "/")
  lc <- normalizePath(file.path(p, ".."), winslash = "/")
  lib <- normalizePath(arg("lib"), winslash = "/", mustWork = TRUE)
  src <- normalizePath(arg("src"), winslash = "/", mustWork = TRUE)
  records <- normalizePath(arg("records"), winslash = "/", mustWork = TRUE)
  scratch <- normalizePath(arg("scratch"), winslash = "/", mustWork = FALSE)
  dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
  freeze <- file.path(p, "loop_freeze.csv")
  wd <- tempfile("ldg3283_wd_")
  dir.create(wd)
  setwd(wd)
  rd <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = character())
  fz <- rd(freeze)
  ch <- rd(file.path(p, "loop_freeze_changes.csv"))
  listed <- function(mode) {
    w <- unique(c(fz$workload[fz$mode == mode], ch$workload[ch$mode == mode & ch$action == "add"]))
    paste(w, collapse = ",")
  }
  dumps <- file.path(records, "gate")
  caps <- file.path(scratch, "caps")
  prep_caps <- file.path(scratch, "prep_caps")
  lp <- function(...) c(file.path(p, "loop_parity.R"), paste0("--lib=", lib), paste0("--freeze=", freeze), ...)
  steps <- list(
    gate_debug1 = lp("--debug=1", paste0("--out=", file.path(here, "gate_debug1.csv"))),
    batch1_debug0 = lp("--debug=0", "--batch-rows=1", paste0("--workloads=", listed("batch1")), paste0("--out=", file.path(here, "batch1_debug0.csv"))),
    batch1_debug1 = lp("--debug=1", "--batch-rows=1", paste0("--workloads=", listed("batch1")), paste0("--out=", file.path(here, "batch1_debug1.csv"))),
    inert_debug0 = lp("--debug=0", "--inert=1", paste0("--workloads=", listed("inert")), paste0("--out=", file.path(here, "inert_debug0.csv"))),
    inert_debug1 = lp("--debug=1", "--inert=1", paste0("--workloads=", listed("inert")), paste0("--out=", file.path(here, "inert_debug1.csv"))),
    integrated_debug0 = lp("--debug=0", "--prepare=1", paste0("--out=", file.path(here, "integrated_debug0.csv"))),
    variants_debug0 = c(file.path(p, "loop_variants.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "variants")), "--debug=0"),
    variants_debug1 = c(file.path(p, "loop_variants.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "variants")), "--debug=1"),
    witness = c(file.path(p, "hashed_frame_witness.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "witness"))),
    loop_dispatch = c(file.path(p, "loop_dispatch.R"), paste0("--lib=", lib), paste0("--out=", file.path(here, "loop_dispatch.csv"))),
    plan_parity_debug0 = c(file.path(p, "plan_parity.R"), paste0("--lib=", lib), "--debug=0", paste0("--out=", file.path(here, "plan_parity_debug0.csv"))),
    plan_parity_debug1 = c(file.path(p, "plan_parity.R"), paste0("--lib=", lib), "--debug=1", paste0("--out=", file.path(here, "plan_parity_debug1.csv"))),
    slice2_reach_cross = c(file.path(p, "slice2_reach_cross.R"), paste0("--lib=", lib), paste0("--dump=", dumps), paste0("--out=", file.path(here, "slice2_reach_cross.csv"))),
    slice3_reach_cross = c(file.path(p, "slice3_reach_cross.R"), paste0("--lib=", lib), paste0("--dump=", dumps), paste0("--out=", file.path(here, "slice3_reach_cross.csv"))),
    slice4_reach_cross = c(file.path(p, "slice4_reach_cross.R"), paste0("--lib=", lib), paste0("--dump=", dumps), "--set=slice4", paste0("--out=", file.path(here, "slice4_reach_cross.csv"))),
    # FIFO census (Cut 22's): recorder lot captures, two independent
    # test-suite captures, their population, then the checker.
    fifo_recorder = c(file.path(lc, "recorder", "run.R"), paste0("--lib=", lib), paste0("--captures=", caps),
                      paste0("--out=", file.path(scratch, "fifo_rec_out")), paste0("--manifests=", file.path(scratch, "fifo_rec_man")), "--boundaries=lot"),
    fifo_captureA = c(file.path(p, "fifo_capture_tests.R"), paste0("--src=", src), paste0("--out=", file.path(scratch, "testsA"))),
    fifo_captureB = c(file.path(p, "fifo_capture_tests.R"), paste0("--src=", src), paste0("--out=", file.path(scratch, "testsB"))),
    fifo_population = c(file.path(p, "fifo_population.R"), paste0("--a=", file.path(scratch, "testsA")), paste0("--b=", file.path(scratch, "testsB")),
                        paste0("--out=", file.path(here, "fifo_population.csv"))),
    fifo_check = c(file.path(p, "fifo_check.R"), paste0("--lib=", lib), paste0("--captures=", caps), paste0("--tests=", file.path(scratch, "testsA")),
                   paste0("--tests2=", file.path(scratch, "testsB")), paste0("--scratch=", file.path(scratch, "fifo_check"))),
    # Preparation on the new pin: captures regenerated, then the boundary,
    # chunk, mutation, edge and digest proofs.
    prep_capture = c(file.path(lc, "recorder", "run.R"), paste0("--lib=", lib), paste0("--captures=", prep_caps),
                     paste0("--out=", file.path(scratch, "prep_out")), paste0("--manifests=", file.path(here, "prep_manifests")),
                     "--workloads=prep_fixture,prep_500x1260,prep_500x2520,prep_500x5040",
                     "--boundaries=hydrate,substrate,features,reader,packet,history_read,history_frame,history_matrix"),
    prep_check_fixture = c(file.path(p, "prep_check.R"), paste0("--lib=", lib), paste0("--captures=", file.path(prep_caps, "prep_fixture.rds")),
                           "--chunks=8,12,run", paste0("--scratch=", file.path(scratch, "prep_check_fixture")), "--mutations",
                           paste0("--out=", file.path(here, "prep_check_fixture.csv"))),
    prep_check_portable = c(file.path(p, "prep_check.R"), paste0("--lib=", lib),
                            paste0("--captures=", paste(file.path(prep_caps, paste0("prep_500x", c(1260, 2520, 5040), ".rds")), collapse = ",")),
                            "--chunks=run", paste0("--scratch=", file.path(scratch, "prep_check_portable")),
                            paste0("--out=", file.path(here, "prep_check_portable.csv"))),
    prep_edges = c(file.path(p, "prep_edges.R"), paste0("--out=", file.path(here, "prep_edges.csv"))),
    prep_digests_pin = c(file.path(p, "prep_digests.R"), paste0("--lib=", lib), paste0("--out=", file.path(scratch, "digests_pin")),
                         paste0("--manifests=", file.path(here, "prep_digests"))),
    prep_digests_lean = c(file.path(p, "prep_digests.R"), paste0("--lib=", lib), paste0("--out=", file.path(scratch, "digests_lean")),
                          "--lean", paste0("--against=", file.path(scratch, "digests_pin"))))
  only <- strsplit(arg("steps", paste(names(steps), collapse = ",")), ",")[[1L]]
  if (length(bad <- setdiff(only, names(steps)))) stop("unknown step(s): ", paste(bad, collapse = ", "), call. = FALSE)
  for (s in only) {
    t0 <- proc.time()[["elapsed"]]
    log <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript.exe"), steps[[s]], stdout = TRUE, stderr = TRUE))
    writeLines(log, file.path(here, paste0(s, ".log")))
    status <- attr(log, "status")
    line <- sprintf("%s: status %s, %.0f s; %s", s, if (is.null(status)) 0L else status, proc.time()[["elapsed"]] - t0,
                    utils::tail(log, 1L))
    cat(line, "\n")
    cat(line, "\n", file = file.path(here, "run_close_status.txt"), append = TRUE)
  }
})
