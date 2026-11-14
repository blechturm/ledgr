# Spike lean_fifo_cpp: the lean loop over an installed ledgr library (the
# cut16-loop-1 workload's loading: lean execution sources sourced over the
# namespace, byte-compiled, debug off) and one run of a workload descriptor.

spike_lean_env <- function(lib, repo) {
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  defs <- new.env(parent = ns)
  sys.source(file.path(repo, "dev/spikes/r_floor/fixture.R"), envir = defs, keep.source = FALSE)
  sys.source(file.path(repo, "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"), envir = defs, keep.source = FALSE)
  lean <- new.env(parent = ns)
  lean$.lean_debug <- FALSE
  for (f in c("fifo.R", "plan.R", "loop.R", "loop_harness.R")) {
    sys.source(file.path(repo, "dev/lean_core", f), envir = lean, keep.source = FALSE)
  }
  for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
  list(ns = ns, defs = defs, lean = lean)
}

# One committed run of `shape`; returns clocks and result tables.
spike_run <- function(env, shape, run_id = "spike") {
  desc <- env$defs$bench_descriptor(shape)
  store <- tempfile(fileext = ".duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "spike",
                                                            price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "spike", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- desc$experiment(snapshot)
  ns <- env$ns
  restore <- env$lean$lean_loop_install()
  on.exit(restore(), add = TRUE, after = FALSE)
  now <- function() as.numeric(Sys.time())
  clk <- new.env(); clk$fold <- 0
  inner <- get("ledgr_fold_envelope", envir = ns)
  unlockBinding("ledgr_fold_envelope", ns)
  assign("ledgr_fold_envelope", function(execution, output_handler) {
    t0 <- now(); on.exit(clk$fold <- clk$fold + (now() - t0)); inner(execution, output_handler)
  }, envir = ns)
  lockBinding("ledgr_fold_envelope", ns)
  on.exit({ unlockBinding("ledgr_fold_envelope", ns); assign("ledgr_fold_envelope", inner, envir = ns)
            lockBinding("ledgr_fold_envelope", ns) }, add = TRUE, after = FALSE)
  folds_before <- env$lean$lean_entry$lean_folds %||% 0L
  invisible(gc(FALSE))
  t0 <- now()
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = run_id, seed = 20260530L))
  run_s <- now() - t0
  if (env$lean$lean_entry$lean_folds - folds_before != 1L) stop("the lean loop did not run")
  tables <- lapply(stats::setNames(nm = c("fills", "equity", "ledger", "diagnostics")),
                   function(t) as.data.frame(ledgr::ledgr_results(bt, t)))
  close(bt)
  list(run_s = run_s, fold_s = clk$fold, pulses = nrow(tables$equity), fills = nrow(tables$fills), tables = tables)
}
