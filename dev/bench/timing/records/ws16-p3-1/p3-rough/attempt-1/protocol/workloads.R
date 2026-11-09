# WS16 family method, P3 family (macro WS16 point 3): the quick timing run
# of lean P3 swapped into the pinned run. Base and candidate are the pin
# (d5b3a151); the candidate arm also binds lean P3 from the overlay
# (runner.R --candidate-overlay=dev/lean_core).
#
# One slot builds a sealed store in its work directory, outside both clocks,
# opens it with verification and runs one committed run:
#   run  wall time of the ledgr_run() call
#   p3   wall time inside ledgr_fold_stage_plan (pinned or lean), which the
#        wrapper adds about 2 us per call to in both arms
# The work string pins P3 calls, fills, final equity and a digest of the
# fills table, so both arms of a record return the same results.

# The published peer-benchmark rule (dev/spikes/r_floor/fixture.R): SMA 5/10
# transitions, quantities 0 or 1, cash 1e7, zero cost, no risk.
ws16_p3_crossover_bars <- function(n_inst, n_pulse) {
  bars <- ledgr::ledgr_sim_bars(n_inst, n_pulse, seed = 20260530L, start = "2020-01-01", instrument_prefix = "P")
  bars$ts_utc <- bars$ts_utc + 21 * 3600
  for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
  bars <- bars[order(bars$instrument_id, bars$ts_utc, method = "radix"), ]
  rownames(bars) <- NULL
  bars
}

ws16_p3_transition <- function(ctx, params) {
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

# Monthly top-10 momentum on one returns feature (dev/bench/v0_2_3_ws16_entry/workloads.R).
ws16_p3_momentum_strategy <- function(ctx, params) {
  score <- ledgr::ledgr_signal_return(ctx, params$lookback)
  selected <- ledgr::ledgr_select_top(score, n = params$n, within = ctx$buyable)
  weights <- ledgr::ledgr_weight_equal(selected)
  target <- ledgr::ledgr_target_rebalance(ctx, weights = weights, invest_fraction = 0.95,
                                          index_leavers = "keep", capital_base = "remaining_equity")
  list(targets = target)
}

ws16_p3_momentum_snapshot <- function(n_inst, n_days, db_path, snapshot_id, seed = 20260530L) {
  bars <- ledgr::ledgr_sim_bars(n_inst, n_days, seed = seed, start = "2000-01-03", instrument_prefix = "P")
  dates <- as.Date(bars$ts_utc)
  bars$ts_utc <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
  days <- seq(min(dates), max(dates), by = "day")
  open <- days %in% dates
  sessions <- ledgr::ledgr_facts_sessions(data.frame(
    session_date = days, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "09:30:00", NA_character_),
    session_close = ifelse(open, "16:00:00", NA_character_),
    knowledge_time = as.POSIXct(days, tz = "UTC") - 1, stringsAsFactors = FALSE
  ), venue_id = "XNYS")
  ledgr::ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = snapshot_id,
                                facts = ledgr::ledgr_facts(sessions), price_basis = "split_adjusted")
}

ws16_p3_shapes <- list(crossover_10x7200 = c(10L, 7200L), crossover_500x1260 = c(500L, 1260L))

ws16_p3 <- function(args, work_dir) {
  ns <- asNamespace("ledgr")
  store <- file.path(work_dir, "store.duckdb")
  id <- "ws16_p3"
  crossover <- ws16_p3_shapes[[args$shape]]
  if (!is.null(crossover)) {
    ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(ws16_p3_crossover_bars(crossover[[1L]], crossover[[2L]]),
      db_path = store, snapshot_id = id, price_basis = "split_adjusted"))
  } else if (identical(args$shape, "momentum_40x504")) {
    ledgr::ledgr_snapshot_close(ws16_p3_momentum_snapshot(40L, 504L, store, id))
  } else {
    stop("unknown shape ", args$shape)
  }
  snapshot <- ledgr::ledgr_snapshot_open(store, id, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  if (!is.null(crossover)) {
    strategy <- ws16_p3_transition
    environment(strategy) <- ns
    exp <- ledgr::ledgr_experiment(snapshot, strategy,
      features = ledgr::ledgr_feature_map(
        fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
        slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
      opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
      risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
    run_args <- list(seed = 20260530L)
  } else {
    exp <- ledgr::ledgr_experiment(snapshot, ws16_p3_momentum_strategy,
      features = list(ledgr::ledgr_ind_returns(63L)), schedule = ledgr::ledgr_schedule_month_start(),
      opening = ledgr::ledgr_opening(cash = 1e6), cost_model = ledgr::ledgr_cost_zero())
    run_args <- list(params = list(lookback = 63L, n = 10L), seed = 1L)
  }

  # The candidate arm binds lean P3 from the exported overlay before the
  # clock wrapper, byte-compiled like the installed pin (as cut12-prep-1).
  arm <- args$.arm
  restore_lean <- function() NULL
  if (is.character(args$.overlay)) {
    if (!isTRUE(arm %in% c("base", "candidate"))) stop("ws16-p3-1: unknown arm ", arm)
    if (identical(arm, "candidate")) {
      lean <- new.env(parent = ns)
      lean$.lean_debug <- FALSE
      sys.source(file.path(args$.overlay, "dev", "lean_core", "plan.R"), envir = lean, keep.source = FALSE)
      for (f in ls(lean, all.names = TRUE)) {
        if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
      }
      restore_lean <- lean$lean_plan_install()
    }
  }
  on.exit(restore_lean(), add = TRUE)

  now <- function() as.numeric(Sys.time())
  clk <- new.env()
  clk$p3 <- 0
  clk$calls <- 0L
  name <- "ledgr_fold_stage_plan"
  inner <- get(name, envir = ns)
  unlockBinding(name, ns)
  assign(name, function(...) {
    t0 <- now()
    on.exit({ clk$p3 <- clk$p3 + (now() - t0); clk$calls <- clk$calls + 1L })
    inner(...)
  }, envir = ns)
  lockBinding(name, ns)
  # Runs before restore_lean (on.exit order), so the lean binding is restored
  # to the pin last.
  on.exit({
    unlockBinding(name, ns)
    assign(name, inner, envir = ns)
    lockBinding(name, ns)
  }, add = TRUE, after = FALSE)

  t0 <- now()
  bt <- suppressWarnings(do.call(ledgr::ledgr_run, c(list(exp, run_id = "ws16-p3"), run_args)))
  run_s <- now() - t0
  fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
  eq <- ledgr::ledgr_results(bt, "equity")
  close(bt)
  sha <- function(x) digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE)
  work <- paste(args$shape, clk$calls, nrow(fills), format(eq$equity[nrow(eq)], digits = 17),
                substr(sha(fills), 1L, 12L), sep = "|")
  out <- list(seconds = c(run = run_s, p3 = clk$p3), work = work)
  if (is.character(args$.overlay)) out$overlay_arm <- arm
  out
}
