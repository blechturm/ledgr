# Runner for the fill-event block-write spike.
#
# Question: does staging each pulse's fill events and writing them with one
# collapse::setv() per column cut warm ledgr_run and ledgr_sweep wall time by
# more than 5% at 500 x 1,260 (SMA 5/10), with byte-identical ledger events,
# fills and equity? Two arms: production per-event writes ("base") and the
# in-memory block seam in seam.R ("block").
#
# Usage, from the repository root:
#   Rscript dev/spikes/fill-event-block-write/spike_runner.R \
#       [--phase parity|all] [--out <dir>] [--reps <n>] [--gut none|misorder]
# parity writes fixture.csv, parity.csv and environment.csv; all adds
# timing.csv, timing_summary.csv and attribution.csv.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
script_path <- local({
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  normalizePath(sub("^--file=", "", f[[1L]]), winslash = "/")
})
spike_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
phase <- arg_value("--phase", "all")
out_dir <- arg_value("--out", file.path(spike_dir, "evidence"))
reps <- as.integer(arg_value("--reps", "7"))
gut <- arg_value("--gut", "none")
stopifnot(phase %in% c("parity", "all"), gut %in% c("none", "misorder"), reps >= 3L)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (!file.exists(file.path(repo_root, "src", paste0("ledgr", .Platform$dynlib.ext)))) {
  stop("Build the package once first; the runner loads with compile = FALSE.")
}
suppressMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
source(file.path(spike_dir, "seam.R"))
source(file.path(spike_dir, "summarise_timing.R"))
arms <- list(base = NULL, block = bw_block_functions(ns, gut))
write_ev <- function(x, name) utils::write.csv(x, file.path(out_dir, name), row.names = FALSE)
log_line <- function(...) cat(sprintf("[%s] ", format(Sys.time(), "%H:%M:%S")), ..., "\n", sep = "")
quiet <- function(expr) suppressWarnings(suppressMessages(expr))

# ---- fixtures ---------------------------------------------------------------------
seal_pristine <- function(bars, id, sessions = FALSE) {
  path <- tempfile(fileext = ".duckdb")
  facts <- NULL
  if (sessions) {
    bars$ts_utc <- as.Date(bars$ts_utc, tz = "UTC")
    dates <- seq(min(bars$ts_utc), max(bars$ts_utc), by = "day")
    open <- !format(dates, "%u") %in% c("6", "7")
    facts <- ledgr_facts(ledgr_facts_sessions(data.frame(session_date = dates,
      status = ifelse(open, "open", "closed"), session_open = ifelse(open, "14:30:00", NA_character_),
      session_close = ifelse(open, "21:00:00", NA_character_),
      knowledge_time = as.POSIXct(min(dates) - 1L, tz = "UTC")), venue_id = "SPIKE", timezone = "UTC"))
  }
  snap <- ledgr_snapshot_from_df(bars, db_path = path, snapshot_id = id, facts = facts)
  ledgr_snapshot_close(snap)
  list(path = path, id = id, rows = nrow(bars), instruments = length(unique(bars$instrument_id)))
}
fresh_copy <- function(fx) { path <- tempfile(fileext = ".duckdb"); file.copy(fx$path, path); path }
sma_features <- function() ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n")))
pattern_strategy <- function(values) {
  force(values)
  function(ctx, params) {
    t <- ctx$flat()
    k <- as.integer(substr(ctx$ts_utc, 9L, 10L))
    t[] <- values[((k + seq_along(t)) %% length(values)) + 1L]
    t
  }
}
experiment <- function(snapshot, spec) {
  ledgr_experiment(snapshot, spec$strategy, features = spec$features, opening = ledgr_opening(cash = 1e7),
    cost_model = spec$cost, valuation_policy = spec$valuation, execution_mode = spec$mode %||% "audit_log")
}
spec_sma <- function(cost = ledgr_cost_zero(), valuation = NULL) list(strategy = ledgr_demo_sma_crossover_strategy(),
  features = sma_features(), cost = cost, valuation = valuation,
  params = list(qty = 1, threshold = 0), feature_params = list(fast_n = 5L, slow_n = 10L))
spec_pattern <- function() list(strategy = pattern_strategy(c(2, -1, 0, 3, -2, 1)), features = list(),
  cost = ledgr_cost_notional_bps_fee(10), valuation = NULL, params = list(), feature_params = list())

# ---- workflows under one arm --------------------------------------------------------
read_events <- function(path, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
}
run_workflow <- function(fx, spec, functions, run_id = "spike-run") {
  path <- fresh_copy(fx)
  snapshot <- ledgr_snapshot_open(path, fx$id)
  run <- bw_with(ns, functions, quiet(ledgr_run(experiment(snapshot, spec), params = spec$params,
    feature_params = spec$feature_params, run_id = run_id, seed = 1L)))
  out <- list(fills = ledgr_results(run, what = "fills"), equity = ledgr_results(run, what = "equity"),
    trades = ledgr_results(run, what = "trades"))
  close(run); ledgr_snapshot_close(snapshot)
  out$ledger_events <- read_events(path, run_id)
  unlink(path)
  out
}
backtest_workflow <- function(fx, spec, functions, run_id = "spike-backtest") {
  path <- fresh_copy(fx)
  snapshot <- ledgr_snapshot_open(path, fx$id)
  bt <- bw_with(ns, functions, quiet(ledgr_backtest(snapshot = snapshot, strategy = spec$strategy,
    strategy_params = spec$params, cost_model = spec$cost, initial_cash = 1e7,
    checkpoint_every = 2L, run_id = run_id)))
  out <- list(fills = ledgr_results(bt, what = "fills"), equity = ledgr_results(bt, what = "equity"))
  close(bt); ledgr_snapshot_close(snapshot)
  out$ledger_events <- read_events(path, run_id)
  unlink(path)
  out
}
sweep_grid <- function() ledgr_grid_cross(features = ledgr_feature_grid(fast_n = 5L, slow_n = 10L),
  strategy = ledgr_strategy_grid(qty = 1, threshold = c(0, 0.01)))
sweep_workflow <- function(fx, spec, functions, grid = sweep_grid(), retain = TRUE) {
  snapshot <- ledgr_snapshot_open(fx$path, fx$id)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  retention <- if (retain) ledgr_sweep_retention(returns = "completed", trades = "closed") else ledgr_sweep_retention()
  s <- bw_with(ns, functions, quiet(ledgr_sweep(experiment(snapshot, spec), grid, seed = 1L, retain = retention)))
  # sweep_id is a fresh random identifier per call; timing columns are clocks.
  drop_id <- function(x) if (is.data.frame(x)) x[setdiff(names(x), "sweep_id")] else x
  a <- attributes(s)
  list(columns = lapply(stats::setNames(names(s)[!grepl("^t_", names(s))], names(s)[!grepl("^t_", names(s))]), function(n) s[[n]]),
    returns = drop_id(a$sweep_returns), trades = drop_id(a$sweep_trades),
    attributes = a[setdiff(names(a), c("names", "row.names", "class", "sweep_id", "sweep_returns", "sweep_trades"))])
}
nrows <- function(x) if (is.data.frame(x)) nrow(x) else if (is.list(x) && length(x) && is.atomic(x[[1L]])) length(x[[1L]]) else length(x)
parity_rows <- function(case, workflow, base, block) {
  do.call(rbind, lapply(names(base), function(surface) data.frame(case = case, workflow = workflow, surface = surface,
    rows_base = nrows(base[[surface]]), rows_block = nrows(block[[surface]]),
    identical = identical(base[[surface]], block[[surface]]))))
}

# ---- parity phase -------------------------------------------------------------------
fixture <- list(); parity <- list()
add <- function(lst, row) c(lst, list(row))
log_line("small fixtures")
small_bars <- as.data.frame(ledgr_sim_bars(n_instruments = 20L, n_days = 150L, seed = 11L))
uneven <- local({
  ids <- unique(small_bars$instrument_id); ts <- sort(unique(small_bars$ts_utc))
  k <- match(small_bars$instrument_id, ids); d <- match(small_bars$ts_utc, ts)
  keep <- !((k %% 4L == 1L & d <= 20L + k) | (k %% 4L == 2L & d > 130L - k) | (k %% 4L == 3L & d %% 17L == k %% 17L))
  b <- small_bars[keep, , drop = FALSE]; rownames(b) <- NULL; b
})
fx_dense <- seal_pristine(small_bars, "dense")
fx_avail <- seal_pristine(uneven, "avail", sessions = TRUE)
cases <- list(
  list(case = "p1_sma_zero_cost", fx = fx_dense, spec = spec_sma()),
  list(case = "p2_reversals_with_fees", fx = fx_dense, spec = spec_pattern()),
  list(case = "p3_availability_uneven", fx = fx_avail, spec = spec_sma(valuation = ledgr_valuation_stale(2L)))
)
for (cs in cases) {
  fixture <- add(fixture, data.frame(case = cs$case, instruments = cs$fx$instruments, bars = cs$fx$rows))
  parity <- add(parity, parity_rows(cs$case, "ledgr_run", run_workflow(cs$fx, cs$spec, arms$base),
    run_workflow(cs$fx, cs$spec, arms$block)))
  if (cs$case != "p2_reversals_with_fees") {
    sb <- sweep_workflow(cs$fx, cs$spec, arms$base)
    parity <- add(parity, parity_rows(cs$case, "ledgr_sweep", sb, sweep_workflow(cs$fx, cs$spec, arms$block)))
    if (cs$case == "p1_sma_zero_cost") {
      parity <- add(parity, parity_rows(cs$case, "ledgr_sweep base vs base (comparator check)", sb,
        sweep_workflow(cs$fx, cs$spec, arms$base)))
    }
  }
}
live <- modifyList(spec_sma(), list(mode = "db_live"))
parity <- add(parity, parity_rows("p4_db_live_mode", "ledgr_run", run_workflow(fx_dense, live, arms$base),
  run_workflow(fx_dense, live, arms$block)))
parity <- add(parity, parity_rows("p5_checkpoint_every_2", "ledgr_backtest", backtest_workflow(fx_dense, spec_pattern(), arms$base),
  backtest_workflow(fx_dense, spec_pattern(), arms$block)))
fixture <- add(fixture, data.frame(case = c("p4_db_live_mode", "p5_checkpoint_every_2"), instruments = fx_dense$instruments, bars = fx_dense$rows))

log_line("release-shape fixture")
scale_bars <- as.data.frame(ledgr_sim_bars(n_instruments = 500L, n_days = 1260L, seed = 20260530L))
fx_scale <- seal_pristine(scale_bars, "scale")
rm(scale_bars)
fixture <- add(fixture, data.frame(case = "s1_release_shape", instruments = fx_scale$instruments, bars = fx_scale$rows))
spec_scale <- spec_sma()
run_base <- run_workflow(fx_scale, spec_scale, arms$base)
parity <- add(parity, parity_rows("s1_release_shape", "ledgr_run", run_base, run_workflow(fx_scale, spec_scale, arms$block)))
one <- ledgr_grid_cross(features = ledgr_feature_grid(fast_n = 5L, slow_n = 10L), strategy = ledgr_strategy_grid(qty = 1, threshold = 0))
parity <- add(parity, parity_rows("s1_release_shape", "ledgr_sweep", sweep_workflow(fx_scale, spec_scale, arms$base, one, retain = FALSE),
  sweep_workflow(fx_scale, spec_scale, arms$block, one, retain = FALSE)))
write_ev(do.call(rbind, fixture), "fixture.csv")
write_ev(do.call(rbind, parity), "parity.csv")

git1 <- function(...) {
  old <- Sys.getenv("HOME"); on.exit(Sys.setenv(HOME = old), add = TRUE)
  if (nzchar(Sys.getenv("USERPROFILE"))) Sys.setenv(HOME = Sys.getenv("USERPROFILE"))
  out <- suppressWarnings(system2("git", c("-C", shQuote(repo_root), ...), stdout = TRUE, stderr = FALSE))
  if (length(out)) out[[1L]] else NA_character_
}
write_ev(data.frame(key = c("r_version", "os", "collapse", "duckdb", "pkgload", "git_head",
  "blob_fold_engine", "blob_sweep", "blob_backtest_runner", "cpu", "gut", "fills_release_shape"),
  value = c(R.version.string, paste(Sys.info()[c("sysname", "release")], collapse = " "),
    as.character(packageVersion("collapse")), as.character(packageVersion("duckdb")), as.character(packageVersion("pkgload")),
    git1("rev-parse", "HEAD"), git1("rev-parse", "HEAD:R/fold-engine.R"), git1("rev-parse", "HEAD:R/sweep.R"),
    git1("rev-parse", "HEAD:R/backtest-runner.R"), Sys.getenv("PROCESSOR_IDENTIFIER"), gut,
    nrow(run_base$fills))), "environment.csv")
log_line("parity evidence written")

if (identical(phase, "all")) {
  # ---- warm clocks: reused sealed snapshot; experiment, execution and result surface timed ----
  invisible(gc.time(TRUE))
  run_once <- function(functions, run_id) {
    path <- fresh_copy(fx_scale)                      # untimed: pristine store per run
    snapshot <- ledgr_snapshot_open(path, fx_scale$id)
    invisible(gc())
    g0 <- gc.time()[[3L]]; t0 <- Sys.time()
    run <- bw_with(ns, functions, quiet(ledgr_run(experiment(snapshot, spec_scale), params = spec_scale$params,
      feature_params = spec_scale$feature_params, run_id = run_id, seed = 1L)))
    invisible(ledgr_results(run, what = "fills")); invisible(ledgr_results(run, what = "equity"))
    close(run)
    t1 <- Sys.time(); g1 <- gc.time()[[3L]]
    ledgr_snapshot_close(snapshot); unlink(path)
    c(as.numeric(t1 - t0, units = "secs"), g1 - g0)
  }
  sweep_path <- fresh_copy(fx_scale)
  sweep_once <- function(functions) {
    snapshot <- ledgr_snapshot_open(sweep_path, fx_scale$id)
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    invisible(gc())
    g0 <- gc.time()[[3L]]; t0 <- Sys.time()
    invisible(bw_with(ns, functions, quiet(ledgr_sweep(experiment(snapshot, spec_scale), one, seed = 1L))))
    t1 <- Sys.time(); g1 <- gc.time()[[3L]]
    c(as.numeric(t1 - t0, units = "secs"), g1 - g0)
  }
  timing <- list(); n_run <- 0L
  clock <- function(workflow, arm) {
    if (workflow == "ledgr_run") { n_run <<- n_run + 1L; run_once(arms[[arm]], sprintf("timed-%03d", n_run)) }
    else sweep_once(arms[[arm]])
  }
  for (workflow in c("ledgr_run", "ledgr_sweep")) {
    log_line("warm-up ", workflow)
    for (arm in c("base", "block")) invisible(clock(workflow, arm))
    for (r in seq_len(reps)) {
      order <- if (r %% 2L == 1L) c("base", "block") else c("block", "base")
      for (pos in 1:2) {
        v <- clock(workflow, order[[pos]])
        timing <- add(timing, data.frame(workflow = workflow, rep = r, position = pos, arm = order[[pos]],
          elapsed_s = v[[1L]], gc_s = v[[2L]]))
        log_line(workflow, " rep ", r, " ", order[[pos]], " ", round(v[[1L]], 2), " s")
      }
    }
  }
  write_ev(do.call(rbind, timing), "timing.csv")
  write_ev(summarise_timing(utils::read.csv(file.path(out_dir, "timing.csv"), stringsAsFactors = FALSE)), "timing_summary.csv")

  # ---- attribution: one sampled profile per arm and workflow (not a clock) -----------
  log_line("attribution profiles")
  focus <- c("output_handler$write_fill_events", "handler$buffer_event", "output_handler$flush_pulse_events",
    "output_handler$record_accounting_fact", "set_event_value", "set_pending_value", "ledgr_event_buffer_setv",
    "ledgr_fill_row_buffer_add", "ledgr_fill_event_payload", "ctx$features", "ledgr_lot_apply_fill")
  attribution <- list()
  for (workflow in c("ledgr_run", "ledgr_sweep")) for (arm in c("base", "block")) {
    prof <- tempfile(fileext = ".Rprof")
    utils::Rprof(prof, interval = 0.01)
    invisible(clock(workflow, arm))
    utils::Rprof(NULL)
    s <- utils::summaryRprof(prof); unlink(prof)
    tot <- s$by.total
    attribution <- add(attribution, data.frame(workflow = workflow, arm = arm, fn = focus,
      total_seconds = vapply(focus, function(f) { v <- tot[sprintf("\"%s\"", f), "total.time"]; if (is.na(v)) 0 else v }, 1),
      sampled_seconds = s$sampling.time))
  }
  write_ev(do.call(rbind, attribution), "attribution.csv")
  unlink(sweep_path)
  log_line("timing and attribution evidence written")
}
for (fx in list(fx_dense, fx_avail, fx_scale)) unlink(fx$path)
