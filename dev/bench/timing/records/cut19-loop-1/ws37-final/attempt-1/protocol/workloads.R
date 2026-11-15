# Cut 19 (LDG-3240, decision 10): the slice-3 lean loop timed against the pin
# on Cut 16's five descriptors (cut16-loop-1's method, as Cut 18), plus one
# marked shape, descriptive only: marked_10x7200 is the 10 x 7,200 crossover
# on a declared session calendar with gaps (each instrument misses three
# sessions every 600) under ledgr_valuation_stale(5, "freeze").
# Base and candidate are the pin (d5b3a151); the runner is launched with
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
# by a cut (Cut 18's checks.R, Cut 19's marks.R) cannot be missed.
cut19_lean_sources <- c("checks.R", "fifo.R", "plan.R", "loop.R", "loop_harness.R", "marks.R")

cut19_loop <- function(args, work_dir) {
  ns <- asNamespace("ledgr")
  if (!is.character(args$.overlay)) stop("cut19-loop-1: run with --candidate-overlay (the shared descriptors)")
  arm <- args$.arm
  if (!isTRUE(arm %in% c("base", "candidate"))) stop("cut19-loop-1: unknown arm ", arm)
  defs <- new.env(parent = ns)
  sys.source(file.path(args$.overlay, "dev", "spikes", "r_floor", "fixture.R"), envir = defs, keep.source = FALSE)
  sys.source(file.path(args$.overlay, "dev", "bench", "v0_2_3_lean_tuning_profile", "descriptors.R"), envir = defs,
             keep.source = FALSE)
  marked <- identical(args$shape, "marked_10x7200")
  desc <- defs$bench_descriptor(if (marked) "10x7200" else args$shape)
  store <- file.path(work_dir, "store.duckdb")
  id <- "cut19_loop"
  if (marked) {
    bars <- desc$bars()
    k <- match(bars$ts_utc, sort(unique(bars$ts_utc)))
    j <- match(bars$instrument_id, sort(unique(bars$instrument_id)))
    bars <- bars[!((k - 50L * j) %% 600L %in% 0:2 & k > 20L), ]
    # Every civil date in the window is declared: the bar dates open, the
    # rest (the weekends) closed.
    open_days <- unique(as.Date(desc$bars()$ts_utc))
    days <- seq(min(open_days), max(open_days), by = "day")
    open <- days %in% open_days
    sessions <- ledgr::ledgr_facts_sessions(data.frame(session_date = days, status = ifelse(open, "open", "closed"),
      session_open = ifelse(open, "14:30:00", NA_character_), session_close = ifelse(open, "21:00:00", NA_character_),
      knowledge_time = as.POSIXct(days, tz = "UTC") - 1, stringsAsFactors = FALSE), venue_id = "XNYS")
    ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = sort(unique(bars$instrument_id))),
      facts = ledgr::ledgr_facts(sessions), db_path = store, snapshot_id = id, price_basis = "split_adjusted"))
  } else {
    ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = id,
      price_basis = "split_adjusted"))
  }
  snapshot <- ledgr::ledgr_snapshot_open(store, id, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- if (!marked) desc$experiment(snapshot) else {
    strategy <- defs$r_floor_transition
    environment(strategy) <- ns
    ledgr::ledgr_experiment(snapshot, strategy,
      features = ledgr::ledgr_feature_map(
        fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
        slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
      opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
      risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE),
      valuation_policy = ledgr::ledgr_valuation_stale(5L, "freeze"))
  }

  # The candidate arm sources the lean core from the exported overlay,
  # byte-compiled like the installed pin, and installs the lean loop.
  restore_lean <- function() NULL
  lean <- NULL
  if (identical(arm, "candidate")) {
    present <- setdiff(list.files(file.path(args$.overlay, "dev", "lean_core"), pattern = "[.]R$"), c("load.R", "prepare.R"))
    if (!setequal(present, cut19_lean_sources)) {
      stop("cut19-loop-1: lean execution sources changed: ", paste(sort(present), collapse = ", "))
    }
    lean <- new.env(parent = ns)
    lean$.lean_debug <- FALSE
    for (f in cut19_lean_sources) {
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
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "cut19-loop", seed = 20260530L))
  run_s <- now() - t0
  fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
  eq <- ledgr::ledgr_results(bt, "equity")
  close(bt)
  if (!is.null(lean) && lean$lean_entry$lean_folds != 1L) stop("cut19-loop-1: the lean loop did not run")
  sha <- function(x) digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE)
  work <- paste(args$shape, nrow(fills), format(eq$equity[nrow(eq)], digits = 17), substr(sha(fills), 1L, 12L), sep = "|")
  list(seconds = c(run = run_s, fold = clk$fold), work = work, overlay_arm = arm)
}
