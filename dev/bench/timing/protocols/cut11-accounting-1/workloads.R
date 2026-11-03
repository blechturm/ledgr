cut11_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  if (identical(params$shape, "fill_heavy")) {
    pulse <- as.integer(as.Date(ctx$ts_utc))
    targets[[1L]] <- if (pulse %% 2L) params$qty else 0
  }
  targets
}

cut11_fixture <- function(work_dir) {
  bars <- ledgr_sim_bars(20L, 80L, seed = 20261103L)
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = file.path(work_dir, "cut11.duckdb"),
    snapshot_id = "cut11_accounting",
    price_basis = "split_adjusted"
  )
  experiment <- ledgr_experiment(
    snapshot,
    cut11_strategy,
    opening = ledgr_opening(cash = 1e6),
    cost_model = ledgr_cost_zero(),
    risk_chain = ledgr_risk_none()
  )
  list(snapshot = snapshot, experiment = experiment)
}

typed_accounting <- function(args, work_dir) {
  if (!args$shape %in% c("fill_heavy", "quiet", "sweep")) stop("bad Cut 11 shape")
  fx <- cut11_fixture(work_dir)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  shape <- if (identical(args$shape, "sweep")) "fill_heavy" else args$shape
  if (identical(args$shape, "sweep")) {
    t0 <- as.numeric(Sys.time())
    out <- ledgr_sweep(
      fx$experiment,
      ledgr_grid_named(
        q1 = list(strategy = list(shape = shape, qty = 1)),
        q2 = list(strategy = list(shape = shape, qty = 2))
      ),
      workers = 1L,
      stop_on_error = TRUE
    )
    elapsed <- as.numeric(Sys.time()) - t0
    work <- paste(out$status, format(out$final_equity, digits = 17), collapse = "|")
    return(list(seconds = c(sweep = elapsed), work = work))
  }
  t0 <- as.numeric(Sys.time())
  run <- ledgr_run(
    fx$experiment,
    params = list(shape = shape, qty = 1),
    run_id = paste0("cut11-", shape)
  )
  elapsed <- as.numeric(Sys.time()) - t0
  on.exit(close(run), add = TRUE)
  info <- ledgr_run_info(run)
  work <- paste(info$status, info$n_fills, format(info$final_equity, digits = 17), sep = "|")
  list(seconds = c(run = elapsed), work = work)
}
