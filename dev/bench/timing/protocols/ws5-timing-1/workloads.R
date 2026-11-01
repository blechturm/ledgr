source(file.path(
  "dev", "bench", "timing", "protocols", "ws4a-timing-1", "workloads.R"
), local = TRUE)

ws4a_strategy <- function(ctx, params) {
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

ws5_fixed_state <- function(args, work_dir) {
  reps <- ws4a_reps(args)
  changing <- identical(args$changing, "true")
  fx <- ws4a_fixture("dense", "wide", work_dir)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    tick <- ctx$state_prev$tick
    if (is.null(tick)) tick <- 0L
    list(
      targets = ctx$flat(),
      state_update = list(tick = if (params$changing) tick + 1L else 1L)
    )
  }
  exp <- ledgr_experiment(
    fx$snapshot, strategy,
    opening = ledgr_opening(cash = ws4a_cash),
    cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none()
  )
  close(suppressWarnings(ledgr_run(exp, params = list(changing = changing), run_id = "ws5-state-warm")))
  invisible(gc())
  t0 <- ws4a_now()
  for (r in seq_len(reps)) {
    close(suppressWarnings(ledgr_run(exp, params = list(changing = changing), run_id = paste0("ws5-state-", r))))
  }
  t1 <- ws4a_now()
  runs <- as.data.frame(ledgr_run_list(fx$snapshot))
  timed <- runs[startsWith(runs$run_id, "ws5-state-"), , drop = FALSE]
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
