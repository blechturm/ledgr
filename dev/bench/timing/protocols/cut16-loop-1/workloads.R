# Cut 16 (LDG-3231): the slice-2 lean loop timed against the pin on Cut 15's
# four crossover shapes and slice2_10x7200. Base and candidate are the pin
# (d5b3a151); the runner is launched with
#   --candidate-overlay=dev/lean_core,dev/bench/v0_2_3_lean_tuning_profile/descriptors.R,dev/spikes/r_floor/fixture.R
# so both arms read the workload definitions from the same exported files
# (descriptors.R, shared with the cost map and the paired comparisons;
# Cut 16 decision 6), and the candidate arm also sources the lean execution
# sources from the overlay and installs the lean loop.
#
# One slot builds a sealed store in its work directory, outside both clocks,
# opens it with verification and runs one committed run:
#   run   wall time of the ledgr_run() call
#   fold  wall time inside ledgr_fold_envelope (the pinned or lean binding)
# The work string pins fills, final equity and a digest of the fills table,
# so both arms of a record return the same results.

# The lean execution sources the candidate loads: every dev/lean_core/*.R
# except load.R (the loader) and prepare.R (preparation stays the pin's,
# Section 19.1). An unlisted file refuses the slot, so a file extracted
# under Cut 16 decision (8) cannot be missed.
cut16_lean_sources <- c("fifo.R", "plan.R", "loop.R", "loop_harness.R")

cut16_loop <- function(args, work_dir) {
  ns <- asNamespace("ledgr")
  if (!is.character(args$.overlay)) stop("cut16-loop-1: run with --candidate-overlay (the shared descriptors)")
  arm <- args$.arm
  if (!isTRUE(arm %in% c("base", "candidate"))) stop("cut16-loop-1: unknown arm ", arm)
  defs <- new.env(parent = ns)
  sys.source(file.path(args$.overlay, "dev", "spikes", "r_floor", "fixture.R"), envir = defs, keep.source = FALSE)
  sys.source(file.path(args$.overlay, "dev", "bench", "v0_2_3_lean_tuning_profile", "descriptors.R"), envir = defs,
             keep.source = FALSE)
  desc <- defs$bench_descriptor(args$shape)
  store <- file.path(work_dir, "store.duckdb")
  id <- "cut16_loop"
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = id,
    price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, id, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- desc$experiment(snapshot)

  # The candidate arm sources the lean core from the exported overlay,
  # byte-compiled like the installed pin, and installs the lean loop.
  restore_lean <- function() NULL
  lean <- NULL
  if (identical(arm, "candidate")) {
    present <- setdiff(list.files(file.path(args$.overlay, "dev", "lean_core"), pattern = "[.]R$"), c("load.R", "prepare.R"))
    if (!setequal(present, cut16_lean_sources)) {
      stop("cut16-loop-1: lean execution sources changed: ", paste(sort(present), collapse = ", "))
    }
    lean <- new.env(parent = ns)
    lean$.lean_debug <- FALSE
    for (f in cut16_lean_sources) {
      sys.source(file.path(args$.overlay, "dev", "lean_core", f), envir = lean, keep.source = FALSE)
    }
    for (f in ls(lean, all.names = TRUE)) {
      if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
    }
    restore_lean <- lean$lean_loop_install()
  }
  on.exit(restore_lean(), add = TRUE)

  now <- function() as.numeric(Sys.time())
  clk <- new.env()
  clk$fold <- 0
  name <- "ledgr_fold_envelope"
  inner <- get(name, envir = ns)
  unlockBinding(name, ns)
  assign(name, function(execution, output_handler) {
    t0 <- now()
    on.exit(clk$fold <- clk$fold + (now() - t0))
    inner(execution, output_handler)
  }, envir = ns)
  lockBinding(name, ns)
  # Runs before restore_lean (on.exit order), so the lean binding is
  # restored to the pin last.
  on.exit({
    unlockBinding(name, ns)
    assign(name, inner, envir = ns)
    lockBinding(name, ns)
  }, add = TRUE, after = FALSE)

  t0 <- now()
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "cut16-loop", seed = 20260530L))
  run_s <- now() - t0
  fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
  eq <- ledgr::ledgr_results(bt, "equity")
  close(bt)
  if (!is.null(lean) && lean$lean_entry$lean_folds != 1L) stop("cut16-loop-1: the lean loop did not run")
  sha <- function(x) digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE)
  work <- paste(args$shape, nrow(fills), format(eq$equity[nrow(eq)], digits = 17), substr(sha(fills), 1L, 12L), sep = "|")
  list(seconds = c(run = run_s, fold = clk$fold), work = work, overlay_arm = arm)
}
