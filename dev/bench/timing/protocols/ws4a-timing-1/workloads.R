# Protocol ws4a-timing-1 (LDG-3163): workloads for the v0.2.3 cut 5 (WS4a)
# timing gate, decision (4). measure.R sources this file after loading the
# arm's ledgr, so it uses only ledgr's public API, identically in both arms.
# protocol.md explains every cell; ws4a_carrier_design.md Section 7 is the
# design these follow.
#
# Every fixture is built from ledgr_sim_bars(500, 1260, seed = 20260530) in
# the slot's fresh work directory. The bars are shifted to 21:00 UTC, the
# session close of the complete facts below; the dense producer uses the same
# shifted bars with no facts.

ws4a_cash <- 1e7

# Complete facts: every calendar day between the first and last bar is a
# session row (open on bar days, closed otherwise), and one complete
# membership snapshot, effective before the first session, lists every
# instrument, so every instrument is a member every session.
ws4a_facts <- function(bars) {
  days <- sort(unique(as.Date(bars$ts_utc)))
  calendar <- seq(min(days), max(days), by = "day")
  open <- calendar %in% days
  sessions <- data.frame(session_date = calendar, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA))
  prior <- as.POSIXct(paste(days[1] - 1, "21:00:00"), tz = "UTC")
  members <- data.frame(effective_from = prior, knowledge_time = prior, source = "ws4a")
  members$members <- I(list(sort(unique(bars$instrument_id), method = "radix")))
  ledgr_facts(
    ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(members, universe_id = "u", complete = TRUE, knowledge = "assume_effective"))
}

# One strategy, three shapes (params$shape):
# - wide: the carrier probe's SMA 5/10 transition, one unit. An instrument
#   enters on a fresh fast-above-slow crossing and exits on the reverse, both
#   only when the previous pulse was usable; state carries above/usable.
# - nofill: the same feature reads and state update, but flat targets, so no
#   fill ever happens (the probe's floor). It is the matched subtraction.
# - sparse: on the first pulse of each calendar month, when every
#   instrument's 63-session return is finite, hold the top 20 by that return,
#   ties by instrument ID in C-locale order (radix), params$qty units each;
#   otherwise hold. Before the return is warm nothing is held or traded.
ws4a_strategy <- function(ctx, params) {
  if (identical(params$shape, "sparse")) {
    ret <- ctx$vec$feature("ret")
    month <- substr(as.character(ctx$ts_utc), 1L, 7L)
    targets <- ctx$hold()
    if (!identical(month, ctx$state_prev$month) && all(is.finite(ret))) {
      targets[] <- 0
      targets[order(-ret, ctx$universe, method = "radix")[seq_len(20L)]] <- params$qty
    }
    return(list(targets = targets, state_update = list(month = month)))
  }
  fast <- ctx$vec$feature("fast")
  slow <- ctx$vec$feature("slow")
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  prev_above <- if (is.null(ctx$state_prev$above)) rep(FALSE, length(usable)) else as.logical(ctx$state_prev$above)
  prev_usable <- if (is.null(ctx$state_prev$usable)) rep(FALSE, length(usable)) else as.logical(ctx$state_prev$usable)
  targets <- ctx$hold()
  targets[prev_usable & usable & above & !prev_above] <- 1
  targets[prev_usable & usable & !above & prev_above] <- 0
  if (identical(params$shape, "nofill")) targets <- ctx$flat()
  list(targets = targets, state_update = list(above = above, usable = usable))
}

ws4a_params <- function(shape) list(shape = shape, qty = 10)

# A fresh sealed snapshot and experiment: zero cost, no risk, cash 1e7.
# wide and nofill share the SMA 5/10 feature map; sparse uses the 63-session
# return. Availability selects the membership universe of the facts.
ws4a_fixture <- function(producer, shape, work_dir) {
  if (!producer %in% c("availability", "dense") || !shape %in% c("wide", "nofill", "sparse")) stop("bad cell args")
  bars <- ledgr_sim_bars(500L, 1260L, seed = 20260530L)
  bars$ts_utc <- bars$ts_utc + 21 * 3600
  avail <- identical(producer, "availability")
  # The harness gives every slot a fresh, empty work directory.
  snapshot <- ledgr_snapshot_from_df(bars, db_path = file.path(work_dir, "ws4a.duckdb"), snapshot_id = "ws4a",
    price_basis = "split_adjusted", facts = if (avail) ws4a_facts(bars))
  features <- if (identical(shape, "sparse")) ledgr_feature_map(ret = ledgr_ind_returns(63L)) else
    ledgr_feature_map(fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L))
  exp <- ledgr_experiment(snapshot, ws4a_strategy, features = features, opening = ledgr_opening(cash = ws4a_cash),
    universe = if (avail) ledgr_universe_members("u"), cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none())
  options(ledgr.interrupt = FALSE)
  list(snapshot = snapshot, exp = exp)
}

ws4a_reps <- function(args) {
  reps <- suppressWarnings(as.integer(args$reps))
  if (!isTRUE(reps >= 1L)) stop("bad cell args: reps")
  reps
}

ws4a_now <- function() as.numeric(Sys.time())

# One in-memory sweep of one candidate, one worker, retaining completed
# returns and closed trades; not saved.
ws4a_sweep <- function(fx, shape) {
  suppressWarnings(ledgr_sweep(fx$exp, ledgr_grid_named(c1 = list(strategy = ws4a_params(shape))),
    retain = ledgr_sweep_retention(returns = "completed", trades = "closed"), workers = 1L, stop_on_error = TRUE))
}

# One durable committed run, persisted in the snapshot's store; the handle
# is closed and no reader is called.
ws4a_run <- function(fx, shape, run_id) {
  close(suppressWarnings(ledgr_run(fx$exp, params = ws4a_params(shape), run_id = run_id)))
}

# A completed execution's outcome as "status|closed trades|final equity".
ws4a_outcome <- function(status, n_trades, final_equity) sprintf("%s|%d|%.4f", status, as.integer(n_trades), final_equity)

ws4a_expect <- function(outcome, shape) {
  want <- if (identical(shape, "nofill")) sprintf("^DONE\\|0\\|%.4f$", ws4a_cash) else "^DONE\\|[1-9][0-9]*\\|"
  if (!grepl(want, outcome)) stop(sprintf("%s outcome %s is not the expected one", shape, outcome))
}

# Run and sweep cells: args producer, shape, path = run|sweep, reps.
# Untimed: the fixture, one warm-up execution of the same path and shape,
# gc(). Timed (clock `run` or `sweep`, as.numeric(Sys.time())): immediately
# before the first ledgr_run() or ledgr_sweep() call of the first rep to
# immediately after the last close() or ledgr_sweep() return of the last rep.
# Untimed after: each rep's outcome (runs from ledgr_run_list(), sweeps from
# the returned row); every rep must repeat the warm-up's outcome exactly.
ws4a_path <- function(args, work_dir) {
  reps <- ws4a_reps(args)
  if (!args$path %in% c("run", "sweep")) stop("bad cell args: path")
  fx <- ws4a_fixture(args$producer, args$shape, work_dir)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  run_outcome <- function(run_ids) {
    runs <- as.data.frame(ledgr_run_list(fx$snapshot))
    hit <- match(run_ids, runs$run_id)
    ws4a_outcome(runs$status[hit], runs$n_trades[hit], runs$final_equity[hit])
  }
  if (identical(args$path, "run")) {
    ws4a_run(fx, args$shape, "ws4a-warm")
    warm <- run_outcome("ws4a-warm")
    invisible(gc())
    t0 <- ws4a_now()
    for (r in seq_len(reps)) ws4a_run(fx, args$shape, paste0("ws4a-timed", r))
    t1 <- ws4a_now()
    outcomes <- run_outcome(paste0("ws4a-timed", seq_len(reps)))
    materialised <- "durable run persisted, handle closed, no reader"
  } else {
    sw <- ws4a_sweep(fx, args$shape)
    warm <- ws4a_outcome(sw$status, sw$n_trades, sw$final_equity)
    invisible(gc())
    timed <- vector("list", reps)
    t0 <- ws4a_now()
    for (r in seq_len(reps)) timed[[r]] <- ws4a_sweep(fx, args$shape)
    t1 <- ws4a_now()
    outcomes <- vapply(timed, function(s) ws4a_outcome(s$status, s$n_trades, s$final_equity), "")
    materialised <- "in-memory sweep retaining completed returns and closed trades, not saved"
  }
  ws4a_expect(warm, args$shape)
  if (any(outcomes != warm)) stop(sprintf("reps differ from the warm-up %s: %s", warm, paste(outcomes, collapse = " / ")))
  list(seconds = stats::setNames(t1 - t0, args$path),
    work = sprintf("%s %s %s: %s x%d; %s", args$producer, args$shape, args$path, warm, reps, materialised))
}

# Reader cells: args what = fills|trades|equity, reps. Untimed: the
# availability wide fixture, one durable ledgr_run() whose handle stays
# open, one warm ledgr_results(bt, what) call, gc(). Timed (clock `read`):
# immediately before the first of `reps` complete ledgr_results() calls to
# immediately after the last returns. Every call must return the warm
# call's row count; fills and trades must return rows (the replay witness).
ws4a_reader <- function(args, work_dir) {
  reps <- ws4a_reps(args)
  if (!args$what %in% c("fills", "trades", "equity")) stop("bad cell args: what")
  fx <- ws4a_fixture("availability", "wide", work_dir)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  bt <- suppressWarnings(ledgr_run(fx$exp, params = ws4a_params("wide"), run_id = "ws4a-read"))
  on.exit(close(bt), add = TRUE, after = FALSE)
  warm <- nrow(ledgr_results(bt, args$what))
  invisible(gc())
  out <- vector("list", reps)
  t0 <- ws4a_now()
  for (r in seq_len(reps)) out[[r]] <- ledgr_results(bt, args$what)
  t1 <- ws4a_now()
  rows <- vapply(out, nrow, 1L)
  if (warm < 1L || any(rows != warm)) {
    stop(sprintf("%s reads returned %s rows after a warm %d", args$what, paste(rows, collapse = ","), warm))
  }
  list(seconds = c(read = t1 - t0),
    work = sprintf("availability wide durable run: ledgr_results(bt, \"%s\") rows=%d complete_calls=%d", args$what, warm, reps))
}

# The absolute cell: args reps. Matched availability wide and nofill sweeps
# timed in this one process. Untimed first: the fixture; one durable wide
# ledgr_run() whose fills and closed trades (ledgr_results) and final
# equity fix the fill count, because a sweep row reports closed trades but
# not fills; one warm-up nofill sweep; gc(). Then per rep, a nofill sweep
# and a wide sweep, each timed from immediately before its ledgr_sweep()
# call to immediately after it returns. Each rep's wide fills are its closed
# trades plus the run's fills that closed nothing; a rep whose count or
# final equity differs from the run, or whose nofill sweep traded, is
# refused, as are unequal fill denominators across reps. The clock
# `marginal` is (wide_total - nofill_total) / reps / fills_per_repetition,
# never clamped: a nonpositive or nonfinite value is reported as measured.
ws4a_marginal <- function(args, work_dir) {
  reps <- ws4a_reps(args)
  fx <- ws4a_fixture("availability", "wide", work_dir)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  bt <- suppressWarnings(ledgr_run(fx$exp, params = ws4a_params("wide"), run_id = "ws4a-fills"))
  run_fills <- nrow(ledgr_results(bt, "fills"))
  run_closed <- nrow(ledgr_results(bt, "trades"))
  run_equity <- utils::tail(ledgr_results(bt, "equity")$equity, 1L)
  close(bt)
  nf <- ws4a_sweep(fx, "nofill")
  ws4a_expect(ws4a_outcome(nf$status, nf$n_trades, nf$final_equity), "nofill")
  invisible(gc())
  totals <- c(wide = 0, nofill = 0)
  fills <- integer(reps)
  wide_outcome <- nofill_outcome <- character(reps)
  for (r in seq_len(reps)) {
    t0 <- ws4a_now()
    nf <- ws4a_sweep(fx, "nofill")
    t1 <- ws4a_now()
    wd <- ws4a_sweep(fx, "wide")
    t2 <- ws4a_now()
    totals <- totals + c(wide = t2 - t1, nofill = t1 - t0)
    fills[r] <- as.integer(wd$n_trades) + (run_fills - run_closed)
    wide_outcome[r] <- ws4a_outcome(wd$status, wd$n_trades, wd$final_equity)
    nofill_outcome[r] <- ws4a_outcome(nf$status, nf$n_trades, nf$final_equity)
  }
  for (o in nofill_outcome) ws4a_expect(o, "nofill")
  want <- ws4a_outcome("DONE", run_closed, run_equity)
  if (any(wide_outcome != want) || any(fills != run_fills) || length(unique(fills)) != 1L || run_fills < 1L) {
    stop(sprintf("unequal fill denominators or outcomes: fills %s (run %d), wide %s (run %s)",
      paste(fills, collapse = ","), run_fills, paste(wide_outcome, collapse = " / "), want))
  }
  marginal <- (totals[["wide"]] - totals[["nofill"]]) / reps / fills[[1L]]
  list(seconds = c(marginal = marginal, wide_total = totals[["wide"]], nofill_total = totals[["nofill"]]),
    work = sprintf(paste0("availability wide-minus-nofill sweeps x%d; fills_per_repetition=%d (run fills %d,",
      " closed %d); wide %s; nofill %s; sweeps retain completed returns and closed trades, not saved"),
      reps, fills[[1L]], run_fills, run_closed, want, nofill_outcome[[1L]]))
}
