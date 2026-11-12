# Cut 15 (LDG-3225): the tuned compact-state lean loop timed against the pin on the
# published peer-benchmark shapes. Base and candidate are the pin
# (d5b3a151); the candidate arm also sources dev/lean_core from the overlay
# (runner.R --candidate-overlay=dev/lean_core) and installs the lean loop.
#
# One slot builds a sealed store in its work directory, outside both clocks,
# opens it with verification and runs one committed run:
#   run   wall time of the ledgr_run() call
#   fold  wall time inside ledgr_fold_envelope (the pinned or lean binding)
# The work string pins fills, final equity and a digest of the fills table,
# so both arms of a record return the same results.

# The published rule (dev/spikes/r_floor/fixture.R): SMA 5/10 transitions,
# quantities 0 or 1, cash 1e7, zero cost, no risk, fixed basket.
cut15_bars <- function(n_inst, n_pulse) {
  bars <- ledgr::ledgr_sim_bars(n_inst, n_pulse, seed = 20260530L, start = "2020-01-01", instrument_prefix = "P")
  bars$ts_utc <- bars$ts_utc + 21 * 3600
  for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
  bars <- bars[order(bars$instrument_id, bars$ts_utc, method = "radix"), ]
  rownames(bars) <- NULL
  bars
}

cut15_transition <- function(ctx, params) {
  fast <- ctx$fast
  slow <- ctx$slow
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  targets <- ctx$hold()
  enter <- ctx$state$usable & usable & above & !ctx$state$above
  exit <- ctx$state$usable & usable & !above & ctx$state$above
  targets[enter] <- 1
  targets[exit] <- 0
  ledgr_strategy_result(targets, above = above, usable = usable)
}

cut15_shapes <- list(crossover_10x7200 = c(10L, 7200L), crossover_20x23400 = c(20L, 23400L),
                     crossover_500x1260 = c(500L, 1260L),
                     crossover_1166x252 = c(1166L, 252L))

cut15_loop <- function(args, work_dir) {
  ns <- asNamespace("ledgr")
  store <- file.path(work_dir, "store.duckdb")
  id <- "cut15_loop"
  shape <- cut15_shapes[[args$shape]]
  if (is.null(shape)) stop("unknown shape ", args$shape)
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(cut15_bars(shape[[1L]], shape[[2L]]),
    db_path = store, snapshot_id = id, price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, id, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- cut15_transition
  environment(strategy) <- ns
  exp <- ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))

  # The candidate arm sources the lean core from the exported overlay,
  # byte-compiled like the installed pin, and installs the lean loop.
  arm <- args$.arm
  restore_lean <- function() NULL
  lean <- NULL
  if (is.character(args$.overlay)) {
    if (!isTRUE(arm %in% c("base", "candidate"))) stop("cut15-loop-1: unknown arm ", arm)
    if (identical(arm, "candidate")) {
      lean <- new.env(parent = ns)
      lean$.lean_debug <- FALSE
      for (f in c("fifo.R", "plan.R", "loop.R", "loop_harness.R")) {
        sys.source(file.path(args$.overlay, "dev", "lean_core", f), envir = lean, keep.source = FALSE)
      }
      for (f in ls(lean, all.names = TRUE)) {
        if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
      }
      restore_lean <- lean$lean_loop_install()
    }
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
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "cut15-loop", seed = 20260530L))
  run_s <- now() - t0
  fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
  eq <- ledgr::ledgr_results(bt, "equity")
  close(bt)
  if (!is.null(lean) && lean$lean_entry$lean_folds != 1L) stop("cut15-loop-1: the lean loop did not run")
  sha <- function(x) digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE)
  work <- paste(args$shape, nrow(fills), format(eq$equity[nrow(eq)], digits = 17),
                substr(sha(fills), 1L, 12L), sep = "|")
  out <- list(seconds = c(run = run_s, fold = clk$fold), work = work)
  if (is.character(args$.overlay)) out$overlay_arm <- arm
  out
}
