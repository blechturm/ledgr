source(file.path(
  "dev", "bench", "timing", "protocols", "ws4a-timing-1", "workloads.R"
), local = TRUE)

ws5_legacy_strategy <- function(ctx, params) {
  legacy <- "vec" %in% names(ctx)
  if (identical(params$shape, "sparse")) {
    ret <- if (legacy) ctx$vec$feature("ret") else ctx$ret
    month <- substr(as.character(ctx$ts_utc), 1L, 7L)
    targets <- ctx$hold()
    if (!identical(month, ctx$state_prev$month) && all(is.finite(ret))) {
      targets[] <- 0
      targets[order(-ret, ctx$universe, method = "radix")[seq_len(20L)]] <- params$qty
    }
    return(list(targets = targets, state_update = list(month = month)))
  }
  fast <- if (legacy) ctx$vec$feature("fast") else ctx$fast
  slow <- if (legacy) ctx$vec$feature("slow") else ctx$slow
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

# The integrated candidate reaches this branch after LDG-3185. Keeping it in
# the preregistered adapter means the declared-state implementation does not
# require a post-registration workload edit.
ws5_declared_strategy <- function(ctx, params) {
  if (identical(params$shape, "sparse")) {
    ret <- ctx$ret
    month <- substr(as.character(ctx$ts_utc), 1L, 7L)
    targets <- ctx$hold()
    if (!identical(month, ctx$state$month) && all(is.finite(ret))) {
      targets[] <- 0
      targets[order(-ret, ctx$universe, method = "radix")[seq_len(20L)]] <- params$qty
    }
    return(ledgr::ledgr_strategy_result(targets, month = month))
  }
  fast <- ctx$fast
  slow <- ctx$slow
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  targets <- ctx$hold()
  targets[ctx$state$usable & usable & above & !ctx$state$above] <- 1
  targets[ctx$state$usable & usable & !above & ctx$state$above] <- 0
  if (identical(params$shape, "nofill")) targets <- ctx$flat()
  ledgr::ledgr_strategy_result(targets, above = above, usable = usable)
}

ws5_declared_state_available <- function() {
  "portfolio_state" %in% names(formals(ledgr_experiment))
}

ws4a_strategy <- if (ws5_declared_state_available()) {
  ws5_declared_strategy
} else {
  ws5_legacy_strategy
}

# Preserve the inherited fixture exactly except for the preregistered state
# declaration required by the integrated candidate.
ws4a_fixture <- function(producer, shape, work_dir) {
  if (!producer %in% c("availability", "dense") || !shape %in% c("wide", "nofill", "sparse")) stop("bad cell args")
  bars <- ledgr_sim_bars(500L, 1260L, seed = 20260530L)
  bars$ts_utc <- bars$ts_utc + 21 * 3600
  avail <- identical(producer, "availability")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = file.path(work_dir, "ws4a.duckdb"), snapshot_id = "ws4a",
    price_basis = "split_adjusted", facts = if (avail) ws4a_facts(bars))
  features <- if (identical(shape, "sparse")) ledgr_feature_map(ret = ledgr_ind_returns(63L)) else
    ledgr_feature_map(fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L))
  args <- list(snapshot = snapshot, strategy = ws4a_strategy, features = features,
    opening = ledgr_opening(cash = ws4a_cash),
    universe = if (avail) ledgr_universe_members("u"), cost_model = ledgr_cost_zero(),
    risk_chain = ledgr_risk_none())
  if (ws5_declared_state_available()) {
    if (identical(shape, "sparse")) args$portfolio_state <- list(month = "") else
      args$asset_state <- list(above = FALSE, usable = FALSE)
  }
  exp <- do.call(ledgr_experiment, args)
  options(ledgr.interrupt = FALSE)
  list(snapshot = snapshot, exp = exp)
}

ws5_fixed_state <- function(args, work_dir) {
  reps <- ws4a_reps(args)
  changing <- identical(args$changing, "true")
  fx <- ws4a_fixture("dense", "wide", work_dir)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  legacy_strategy <- function(ctx, params) {
    tick <- ctx$state_prev$tick
    if (is.null(tick)) tick <- 0L
    list(
      targets = ctx$flat(),
      state_update = list(tick = if (params$changing) tick + 1L else 1L)
    )
  }
  declared_strategy <- function(ctx, params) {
    tick <- ctx$state$tick
    ledgr::ledgr_strategy_result(
      ctx$flat(), tick = if (params$changing) tick + 1L else 1L
    )
  }
  declared <- ws5_declared_state_available()
  exp_args <- list(
    snapshot = fx$snapshot,
    strategy = if (declared) declared_strategy else legacy_strategy,
    opening = ledgr_opening(cash = ws4a_cash),
    cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none()
  )
  if (declared) exp_args$portfolio_state <- list(tick = 0L)
  exp <- do.call(ledgr_experiment, exp_args)
  close(suppressWarnings(ledgr_run(exp, params = list(changing = changing), run_id = "ws5-state-warm")))
  invisible(gc())
  t0 <- ws4a_now()
  for (r in seq_len(reps)) {
    close(suppressWarnings(ledgr_run(exp, params = list(changing = changing), run_id = paste0("ws5-state-", r))))
  }
  t1 <- ws4a_now()
  runs <- as.data.frame(ledgr_run_list(fx$snapshot))
  timed <- runs[grepl("^ws5-state-[0-9]+$", runs$run_id), , drop = FALSE]
  if (nrow(timed) != reps || any(timed$status != "DONE") || any(timed$n_trades != 0L)) stop("state workload economic control failed")
  list(seconds = c(run = t1 - t0), work = sprintf("fixed wide state changing=%s; DONE, zero trades x%d", changing, reps))
}

ws5_experiment_construction <- function(args, work_dir) {
  reps <- ws4a_reps(args)
  fx <- ws4a_fixture("dense", "nofill", work_dir)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  invisible(gc())
  t0 <- ws4a_now()
  out <- vector("list", reps)
  for (r in seq_len(reps)) {
    out[[r]] <- ledgr_experiment(
      fx$snapshot, strategy,
      opening = ledgr_opening(cash = ws4a_cash),
      cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none()
    )
  }
  t1 <- ws4a_now()
  if (length(out) != reps) stop("construction workload did not complete")
  list(seconds = c(construct = t1 - t0), work = sprintf("ledgr_experiment construction x%d; no execution", reps))
}
