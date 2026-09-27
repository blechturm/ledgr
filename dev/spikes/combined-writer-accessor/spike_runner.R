# Runner for the combined writer + accessor measurement.
#
# Question: with both measured changes applied together (per-pulse block write of
# fill events from dev/spikes/fill-event-block-write/, and prepared fast-context
# feature accessors from dev/spikes/feature-accessor-lookup/), how much warm time
# do ledgr_run, ledgr_sweep and the compiled spot_fifo sweep save at 500 x 1,260
# (SMA 5/10), with byte-identical results, and do the separate savings add up?
# An additivity phase times each change alone beside base and combined in one session.
# Follow-up coverage: an eight-candidate sweep, a low-turnover monthly-rebalance
# strategy, and an exception raised inside the per-fill loop (what each workflow
# reports and what the store persists, under either arm).
# Two arms: production ("base") and both seams bound together ("combined").
#
# Usage, from the repository root:
#   Rscript dev/spikes/combined-writer-accessor/spike_runner.R \
#       [--phase parity|all] [--out <dir>] [--reps <n>] [--gut none|misorder]
# parity writes fixture.csv, parity.csv, failure.csv, compilation.csv and environment.csv; all adds
# timing.csv, timing_summary.csv, additivity.csv, additivity_summary.csv,
# width_scaling.csv and attribution.csv.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
spike_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
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
source(file.path(spike_dir, "..", "fill-event-block-write", "seam.R"))
source(file.path(spike_dir, "..", "feature-accessor-lookup", "seam.R"))
source(file.path(spike_dir, "summarise_timing.R"))
# R 4.6.1's JIT (level 3) byte-compiles a closure created in a local environment only for the
# first instance of its body; later instances with the same body stay interpreted. Seam
# functions are therefore compiled explicitly, so no arm depends on session history.
# compilation.csv records the result and the checker requires byte code throughout.
compiled <- function(fns) lapply(fns, compiler::cmpfun)
arms <- list(base = NULL, combined = compiled(c(bw_block_functions(ns, gut), fl_prepared_functions(ns))))
# Additivity phase only: each change alone, in the same session as base and combined.
single_arms <- list(block = compiled(bw_block_functions(ns, gut)), prepared = compiled(fl_prepared_functions(ns)))
bytecode <- function(f) any(grepl("<bytecode", utils::capture.output(print(f)), fixed = TRUE))
write_ev <- function(x, name) utils::write.csv(x, file.path(out_dir, name), row.names = FALSE)
log_line <- function(...) cat(sprintf("[%s] ", format(Sys.time(), "%H:%M:%S")), ..., "\n", sep = "")
quiet <- function(expr) suppressWarnings(suppressMessages(expr))
add <- function(lst, row) c(lst, list(row))

# ---- fixtures and strategies ---------------------------------------------------------------
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
alias_features <- function() ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n")))
explicit_map_strategy <- function(fmap) {
  force(fmap)
  function(ctx, params) {
    t <- ctx$flat()
    for (id in ctx$universe) {
      v <- ctx$features(id, fmap)
      if (all(is.finite(v)) && v[["fast"]] > v[["slow"]]) t[id] <- 1
    }
    t
  }
}
pattern_strategy <- function(values) {
  force(values)
  function(ctx, params) {
    t <- ctx$flat()
    k <- as.integer(substr(ctx$ts_utc, 9L, 10L))
    t[] <- values[((k + seq_along(t)) %% length(values)) + 1L]
    t
  }
}
spec_alias <- function(valuation = NULL, mode = "audit_log") list(strategy = ledgr_demo_sma_crossover_strategy(),
  features = alias_features(), cost = ledgr_cost_zero(), valuation = valuation, mode = mode,
  params = list(qty = 1, threshold = 0), feature_params = list(fast_n = 5L, slow_n = 10L))
spec_map <- function() { m <- ledgr_feature_map(fast = ledgr_ind_sma(5L), slow = ledgr_ind_sma(10L))
  list(strategy = explicit_map_strategy(m), features = m, cost = ledgr_cost_zero(), valuation = NULL, mode = "audit_log",
    params = list(), feature_params = list()) }
spec_pattern <- function() list(strategy = pattern_strategy(c(2, -1, 0, 3, -2, 1)), features = list(),
  cost = ledgr_cost_notional_bps_fee(10), valuation = NULL, mode = "audit_log", params = list(), feature_params = list())
# Low-turnover shape: rebalance on the first pulse of each month (features read only then),
# hold current positions on every other pulse. State is written on rebalance pulses only.
monthly_strategy <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  t <- ctx$flat()
  for (id in ctx$universe) {
    v <- ctx$features(id)
    if (all(is.finite(v)) && v[["fast"]] > v[["slow"]]) t[id] <- 1
  }
  list(targets = t, state_update = list(month = month))
}
spec_monthly <- function() list(strategy = monthly_strategy, features = alias_features(), cost = ledgr_cost_zero(),
  valuation = NULL, mode = "audit_log", params = list(qty = 1), feature_params = list(fast_n = 20L, slow_n = 60L))
grid_monthly <- function() ledgr_grid_cross(features = ledgr_feature_grid(fast_n = 20L, slow_n = 60L),
  strategy = ledgr_strategy_grid(qty = 1))
grid_eight <- function() ledgr_grid_cross(features = ledgr_feature_grid(fast_n = c(5L, 10L), slow_n = c(20L, 40L)),
  strategy = ledgr_strategy_grid(qty = 1, threshold = c(0, 0.01)))
experiment <- function(snapshot, spec) ledgr_experiment(snapshot, spec$strategy, features = spec$features,
  opening = ledgr_opening(cash = 1e7), cost_model = spec$cost, valuation_policy = spec$valuation, execution_mode = spec$mode)
grid_of <- function(spec, thresholds = c(0, 0.01)) {
  if (length(spec$feature_params)) {
    ledgr_grid_cross(features = ledgr_feature_grid(fast_n = 5L, slow_n = 10L), strategy = ledgr_strategy_grid(qty = 1, threshold = thresholds))
  } else {
    ledgr_param_grid(list(unused = 1), list(unused = 2))
  }
}

# ---- workflows under one arm ------------------------------------------------------------------
read_events <- function(path, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
}
run_workflow <- function(fx, spec, functions, run_id = "spike-run") {
  path <- fresh_copy(fx); snapshot <- ledgr_snapshot_open(path, fx$id)
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
  path <- fresh_copy(fx); snapshot <- ledgr_snapshot_open(path, fx$id)
  bt <- bw_with(ns, functions, quiet(ledgr_backtest(snapshot = snapshot, strategy = spec$strategy,
    strategy_params = spec$params, cost_model = spec$cost, initial_cash = 1e7, checkpoint_every = 2L, run_id = run_id)))
  out <- list(fills = ledgr_results(bt, what = "fills"), equity = ledgr_results(bt, what = "equity"))
  close(bt); ledgr_snapshot_close(snapshot)
  out$ledger_events <- read_events(path, run_id)
  unlink(path)
  out
}
sweep_workflow <- function(fx, spec, functions, grid = grid_of(spec), compiled = NULL, retain = TRUE) {
  snapshot <- ledgr_snapshot_open(fx$path, fx$id)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  retention <- if (retain) ledgr_sweep_retention(returns = "completed", trades = "closed") else ledgr_sweep_retention()
  s <- bw_with(ns, functions, quiet(ledgr_sweep(experiment(snapshot, spec), grid, seed = 1L, retain = retention,
    compiled_accounting_model = compiled)))
  drop_id <- function(x) if (is.data.frame(x)) x[setdiff(names(x), "sweep_id")] else x   # sweep_id is random per call
  a <- attributes(s)
  keep <- names(s)[!grepl("^t_", names(s))]
  list(columns = stats::setNames(lapply(keep, function(n) s[[n]]), keep),
    returns = drop_id(a$sweep_returns), trades = drop_id(a$sweep_trades),
    attributes = a[setdiff(names(a), c("names", "row.names", "class", "sweep_id", "sweep_returns", "sweep_trades"))])
}
# Failure path: an exception raised inside the per-fill loop, on the n-th fill of the process
# (mid-pulse under the reversal pattern, which fills about 20 instruments per pulse). Records
# what each workflow reports and what the store persists, under either arm.
failure_probe <- function(fx, functions, n_fail = 45L) {
  counter <- new.env(); counter$n <- 0L
  original <- get("ledgr_lot_apply_fill", envir = ns)
  failing <- function(...) {
    counter$n <- counter$n + 1L
    if (counter$n == n_fail) stop("spike-injected fill failure", call. = FALSE)
    original(...)
  }
  fns <- c(functions, list(ledgr_lot_apply_fill = failing))
  describe_error <- function(e) if (is.null(e)) c(NA_character_, NA) else
    c(paste(class(e), collapse = "|"), grepl("spike-injected fill failure", conditionMessage(e), fixed = TRUE))
  store_state <- function(path, run_id) {
    con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    status <- DBI::dbGetQuery(con, "SELECT status FROM runs WHERE run_id = ?", params = list(run_id))$status
    events <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n
    c(if (length(status)) status[[1L]] else "<no runs row>", as.integer(events))
  }
  # Where the n-th fill sits, from the same workflow's unfailed production run: the persisted
  # event count equals events_before_failing_pulse when the failing pulse left nothing behind,
  # and events_before_failing_fill when its earlier fills were persisted.
  locate <- function(events) {
    fills <- events[events$event_type == "FILL", ]; ts_k <- fills$ts_utc[[n_fail]]
    c(events_before_failing_pulse = sum(events$ts_utc < ts_k),
      events_before_failing_fill = sum(events$event_seq < fills$event_seq[[n_fail]]),
      failing_fill_rank_in_pulse = sum(fills$ts_utc[seq_len(n_fail)] == ts_k), fills_in_failing_pulse = sum(fills$ts_utc == ts_k))
  }
  durable <- function(label, call, ref) {
    counter$n <- 0L
    path <- fresh_copy(fx); snapshot <- ledgr_snapshot_open(path, fx$id)
    err <- tryCatch({ obj <- bw_with(ns, fns, quiet(call(snapshot))); close(obj); NULL }, error = identity)
    try(ledgr_snapshot_close(snapshot), silent = TRUE)
    st <- store_state(path, "fail-run"); unlink(path)
    e <- describe_error(err)
    cbind(data.frame(workflow = label, candidate = NA_integer_, error_class = e[[1L]], injected_message = e[[2L]],
      status = st[[1L]], persisted_ledger_events = as.integer(st[[2L]]), n_trades = NA_real_, final_equity = NA_real_),
      as.list(locate(ref)))
  }
  spec <- spec_pattern()
  spec_live <- spec; spec_live$mode <- "db_live"
  rows <- list(
    durable("ledgr_run", function(s) ledgr_run(experiment(s, spec), params = spec$params, run_id = "fail-run", seed = 1L),
      run_workflow(fx, spec, NULL)$ledger_events),
    durable("ledgr_run db_live", function(s) ledgr_run(experiment(s, spec_live), params = spec$params, run_id = "fail-run", seed = 1L),
      run_workflow(fx, spec_live, NULL)$ledger_events),
    durable("ledgr_backtest checkpoint_every = 2", function(s) ledgr_backtest(snapshot = s, strategy = spec$strategy,
      strategy_params = spec$params, cost_model = spec$cost, initial_cash = 1e7, checkpoint_every = 2L, run_id = "fail-run"),
      backtest_workflow(fx, spec, NULL)$ledger_events)
  )
  no_location <- data.frame(events_before_failing_pulse = NA_integer_, events_before_failing_fill = NA_integer_,
    failing_fill_rank_in_pulse = NA_integer_, fills_in_failing_pulse = NA_integer_)
  counter$n <- 0L
  snapshot <- ledgr_snapshot_open(fx$path, fx$id)
  sw <- tryCatch(bw_with(ns, fns, quiet(ledgr_sweep(experiment(snapshot, spec), grid_of(spec), seed = 1L))), error = identity)
  ledgr_snapshot_close(snapshot)
  if (inherits(sw, "error")) {
    e <- describe_error(sw)
    rows <- c(rows, list(data.frame(workflow = "ledgr_sweep", candidate = NA_integer_, error_class = e[[1L]],
      injected_message = e[[2L]], status = "<sweep raised>", persisted_ledger_events = NA_integer_, n_trades = NA_real_,
      final_equity = NA_real_, no_location)))
  } else {
    rows <- c(rows, list(data.frame(workflow = "ledgr_sweep", candidate = seq_len(nrow(sw)), error_class = as.character(sw$error_class),
      injected_message = grepl("spike-injected fill failure", as.character(sw$error_msg), fixed = TRUE),
      status = as.character(sw$status), persisted_ledger_events = NA_integer_, n_trades = sw$n_trades, final_equity = sw$final_equity,
      no_location)))
  }
  do.call(rbind, rows)
}
nrows <- function(x) if (is.data.frame(x)) nrow(x) else if (is.list(x) && length(x) && is.atomic(x[[1L]])) length(x[[1L]]) else length(x)
parity_rows <- function(case, workflow, base, other) {
  do.call(rbind, lapply(names(base), function(surface) data.frame(case = case, workflow = workflow, surface = surface,
    rows_base = nrows(base[[surface]]), rows_combined = nrows(other[[surface]]), identical = identical(base[[surface]], other[[surface]]))))
}
both <- function(case, workflow, f) parity_rows(case, workflow, f(arms$base), f(arms$combined))

# ---- parity phase -------------------------------------------------------------------------------
fixture <- list(); parity <- list()
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
fixture <- add(fixture, data.frame(case = c("dense_20x150", "availability_uneven_20x150"),
  instruments = c(fx_dense$instruments, fx_avail$instruments), bars = c(fx_dense$rows, fx_avail$rows)))
parity <- add(parity, both("c1_alias_sma", "ledgr_run", function(a) run_workflow(fx_dense, spec_alias(), a)))
parity <- add(parity, both("c1_alias_sma", "ledgr_sweep", function(a) sweep_workflow(fx_dense, spec_alias(), a)))
parity <- add(parity, both("c1_alias_sma", "ledgr_sweep spot_fifo", function(a) sweep_workflow(fx_dense, spec_alias(), a, compiled = "spot_fifo")))
parity <- add(parity, both("c2_reversals_with_fees", "ledgr_run", function(a) run_workflow(fx_dense, spec_pattern(), a)))
parity <- add(parity, both("c3_explicit_feature_map", "ledgr_run", function(a) run_workflow(fx_dense, spec_map(), a)))
parity <- add(parity, both("c3_explicit_feature_map", "ledgr_sweep", function(a) sweep_workflow(fx_dense, spec_map(), a)))
parity <- add(parity, both("c4_availability_uneven", "ledgr_run",
  function(a) run_workflow(fx_avail, spec_alias(valuation = ledgr_valuation_stale(2L)), a)))
parity <- add(parity, both("c4_availability_uneven", "ledgr_sweep",
  function(a) sweep_workflow(fx_avail, spec_alias(valuation = ledgr_valuation_stale(2L)), a)))
parity <- add(parity, both("c5_db_live_mode", "ledgr_run", function(a) run_workflow(fx_dense, spec_alias(mode = "db_live"), a)))
parity <- add(parity, both("c6_checkpoint_every_2", "ledgr_backtest", function(a) backtest_workflow(fx_dense, spec_pattern(), a)))
parity <- add(parity, both("c7_monthly_rebalance", "ledgr_run", function(a) run_workflow(fx_dense, spec_monthly(), a)))
parity <- add(parity, both("c7_monthly_rebalance", "ledgr_sweep", function(a) sweep_workflow(fx_dense, spec_monthly(), a, grid_monthly())))
parity <- add(parity, both("c8_eight_candidates", "ledgr_sweep", function(a) sweep_workflow(fx_dense, spec_alias(), a, grid_eight())))
failure <- rbind(cbind(arm = "base", failure_probe(fx_dense, arms$base)),
  cbind(arm = "combined", failure_probe(fx_dense, arms$combined)))
write_ev(failure, "failure.csv")

# Byte-code status of every bound seam function, and of the accessor closures the prepared
# factories return on inputs captured from a small run.
cap <- new.env()
capture_args <- function(projection, state, universe, feature_ids = NULL, active_alias_map = NULL) {
  cap$args <- list(projection = projection, universe = universe, feature_ids = feature_ids, active_alias_map = active_alias_map)
  stop(structure(class = c("spike_captured", "error", "condition"), list(message = "captured", call = NULL)))
}
local({
  snapshot <- ledgr_snapshot_open(fx_dense$path, fx_dense$id); on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  spec <- spec_alias()
  tryCatch(quiet(bw_with(ns, list(ledgr_projection_feature_bundle_accessor_state = capture_args), ledgr_run(experiment(snapshot, spec),
    params = spec$params, feature_params = spec$feature_params, run_id = "capture", seed = 1L))),
    error = function(e) if (is.null(cap$args)) stop(e))
})
seamed_arms <- c(arms["combined"], single_arms)
compilation <- do.call(rbind, lapply(names(seamed_arms), function(arm) {
  fns <- seamed_arms[[arm]]
  rows <- data.frame(arm = arm, fn = names(fns), bytecode = vapply(fns, bytecode, logical(1)))
  if ("ledgr_projection_feature_bundle_accessor_state" %in% names(fns)) {
    built <- bw_with(ns, fns, { st <- new.env(parent = emptyenv()); st$pulse_idx <- 1L
      list(feature = get("ledgr_projection_feature_accessor_state", envir = ns)(cap$args$projection, st, cap$args$feature_ids),
        features = get("ledgr_projection_feature_bundle_accessor_state", envir = ns)(cap$args$projection, st, cap$args$universe,
          cap$args$feature_ids, cap$args$active_alias_map)) })
    rows <- rbind(rows, data.frame(arm = arm, fn = c("returned ctx$feature closure", "returned ctx$features closure"),
      bytecode = c(bytecode(built$feature), bytecode(built$features))))
  }
  rows
}))
rownames(compilation) <- NULL
write_ev(compilation, "compilation.csv")

log_line("release-shape fixture")
scale_bars <- as.data.frame(ledgr_sim_bars(n_instruments = 500L, n_days = 1260L, seed = 20260530L))
fx_scale <- seal_pristine(scale_bars, "scale")
rm(scale_bars)
fixture <- add(fixture, data.frame(case = "release_shape_500x1260", instruments = fx_scale$instruments, bars = fx_scale$rows))
spec_scale <- spec_alias()
one <- grid_of(spec_scale, thresholds = 0)
run_base <- run_workflow(fx_scale, spec_scale, arms$base)
parity <- add(parity, parity_rows("s1_release_shape", "ledgr_run", run_base, run_workflow(fx_scale, spec_scale, arms$combined)))
parity <- add(parity, both("s1_release_shape", "ledgr_sweep", function(a) sweep_workflow(fx_scale, spec_scale, a, one, retain = FALSE)))
parity <- add(parity, both("s1_release_shape", "ledgr_sweep spot_fifo",
  function(a) sweep_workflow(fx_scale, spec_scale, a, one, compiled = "spot_fifo", retain = FALSE)))
parity <- add(parity, both("s2_monthly_release_shape", "ledgr_run", function(a) run_workflow(fx_scale, spec_monthly(), a)))
write_ev(do.call(rbind, fixture), "fixture.csv")
write_ev(do.call(rbind, parity), "parity.csv")

git1 <- function(...) {
  old <- Sys.getenv("HOME"); on.exit(Sys.setenv(HOME = old), add = TRUE)
  if (nzchar(Sys.getenv("USERPROFILE"))) Sys.setenv(HOME = Sys.getenv("USERPROFILE"))
  out <- suppressWarnings(system2("git", c("-C", shQuote(repo_root), ...), stdout = TRUE, stderr = FALSE))
  if (length(out)) out[[1L]] else NA_character_
}
seamed <- c(fold_engine = "R/fold-engine.R", sweep = "R/sweep.R", backtest_runner = "R/backtest-runner.R",
  runtime_projection = "R/runtime-projection.R", feature_alias_map = "R/feature-alias-map.R", pulse_context = "R/pulse-context.R")
write_ev(data.frame(key = c("r_version", "os", "collapse", "duckdb", "pkgload", "git_head", paste0("blob_", names(seamed)),
  "cpu", "gut", "fills_release_shape"),
  value = c(R.version.string, paste(Sys.info()[c("sysname", "release")], collapse = " "),
    as.character(packageVersion("collapse")), as.character(packageVersion("duckdb")), as.character(packageVersion("pkgload")),
    git1("rev-parse", "HEAD"), vapply(seamed, function(p) git1("rev-parse", paste0("HEAD:", p)), ""),
    Sys.getenv("PROCESSOR_IDENTIFIER"), gut, nrow(run_base$fills))), "environment.csv")
log_line("parity evidence written")

if (identical(phase, "all")) {
  # ---- warm clocks over a reused sealed snapshot, with per-observation load metering ----------
  invisible(gc.time(TRUE))
  # Per-process CPU snapshots, taken outside the timed region. A process's in-interval CPU is
  # its after minus before; a process that started (or reused an id) counts from zero, and a
  # process that exited is lost, so readings can undercount but never go negative. Processes
  # whose CPU Windows does not expose (protected ones) are invisible to this meter.
  cpu_by_process <- function() {
    out <- suppressWarnings(system2("powershell", c("-NoProfile", "-NonInteractive", "-Command",
      "Get-Process | Select-Object Id, CPU | ConvertTo-Csv -NoTypeInformation"), stdout = TRUE, stderr = FALSE))
    d <- utils::read.csv(text = out, stringsAsFactors = FALSE)
    d$CPU <- suppressWarnings(as.numeric(sub(",", ".", d$CPU, fixed = TRUE)))
    d[!is.na(d$CPU) & d$Id != Sys.getpid(), c("Id", "CPU")]
  }
  other_cpu_seconds <- function(before, after) {
    b <- before$CPU[match(after$Id, before$Id)]
    sum(ifelse(is.na(b) | after$CPU < b, after$CPU, after$CPU - b))
  }
  other_r <- function() {
    rows <- suppressWarnings(system2("tasklist", c("/FO", "CSV", "/NH"), stdout = TRUE, stderr = FALSE))
    tasks <- utils::read.csv(text = rows, header = FALSE, stringsAsFactors = FALSE)
    sum(tasks$V1 %in% c("Rscript.exe", "Rterm.exe", "R.exe") & tasks$V2 != Sys.getpid())
  }
  n_run <- 0L
  workloads <- list(
    "ledgr_run" = list(kind = "run", spec = spec_scale),
    "ledgr_sweep" = list(kind = "sweep", spec = spec_scale, grid = one),
    "ledgr_sweep spot_fifo" = list(kind = "sweep", spec = spec_scale, grid = one, compiled = "spot_fifo"),
    "ledgr_sweep 8 candidates" = list(kind = "sweep", spec = spec_scale, grid = grid_eight()),
    "ledgr_run monthly" = list(kind = "run", spec = spec_monthly()),
    "ledgr_sweep monthly" = list(kind = "sweep", spec = spec_monthly(), grid = grid_monthly())
  )
  clock_on <- function(fx, sweep_path, workflow, functions) {
    w <- workloads[[workflow]]; spec <- w$spec; grid <- w$grid
    if (identical(w$kind, "run")) {
      n_run <<- n_run + 1L
      path <- fresh_copy(fx); snapshot <- ledgr_snapshot_open(path, fx$id)   # untimed: pristine store per run
      invisible(gc()); a0 <- cpu_by_process(); g0 <- gc.time()[[3L]]; t0 <- Sys.time()
      run <- bw_with(ns, functions, quiet(ledgr_run(experiment(snapshot, spec), params = spec$params,
        feature_params = spec$feature_params, run_id = sprintf("timed-%04d", n_run), seed = 1L)))
      invisible(ledgr_results(run, what = "fills")); invisible(ledgr_results(run, what = "equity")); close(run)
      t1 <- Sys.time(); g1 <- gc.time()[[3L]]; a1 <- cpu_by_process()
      ledgr_snapshot_close(snapshot); unlink(path)
    } else {
      compiled <- w$compiled
      snapshot <- ledgr_snapshot_open(sweep_path, fx$id); on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
      invisible(gc()); a0 <- cpu_by_process(); g0 <- gc.time()[[3L]]; t0 <- Sys.time()
      invisible(bw_with(ns, functions, quiet(ledgr_sweep(experiment(snapshot, spec), grid, seed = 1L,
        compiled_accounting_model = compiled))))
      t1 <- Sys.time(); g1 <- gc.time()[[3L]]; a1 <- cpu_by_process()
    }
    elapsed <- as.numeric(t1 - t0, units = "secs")
    c(elapsed, g1 - g0, other_cpu_seconds(a0, a1) / elapsed)
  }
  # Pre-declared load rule for a shared machine: a pair is re-measured as a unit, in the same
  # arm order, when either observation ran with one or more other busy cores or ended with
  # another R process present. Up to max_retries extra attempts; every attempt is written,
  # and only the final attempt of each repetition is kept for the summary. A final attempt
  # that is still loaded is kept and fails the checker's load gate.
  paired <- function(fx, workflows, n, warm = 1L, max_retries = 3L) {
    sweep_path <- fresh_copy(fx); on.exit(unlink(sweep_path), add = TRUE)
    rows <- list()
    for (workflow in workflows) {
      for (w in seq_len(warm)) for (arm in names(arms)) invisible(clock_on(fx, sweep_path, workflow, arms[[arm]]))
      for (r in seq_len(n)) {
        order <- if (r %% 2L == 1L) c("base", "combined") else c("combined", "base")
        for (attempt in 0:max_retries) {
          obs <- lapply(1:2, function(pos) {
            v <- clock_on(fx, sweep_path, workflow, arms[[order[[pos]]]])
            log_line(fx$instruments, " ", workflow, " rep ", r, " attempt ", attempt, " ", order[[pos]], " ", round(v[[1L]], 2), " s")
            data.frame(instruments = fx$instruments, workflow = workflow, rep = r, attempt = attempt, position = pos,
              arm = order[[pos]], elapsed_s = v[[1L]], gc_s = v[[2L]], other_cpu_cores = round(v[[3L]], 3),
              other_r_processes = other_r())
          })
          pair <- do.call(rbind, obs)
          loaded <- any(pair$other_cpu_cores >= 1 | pair$other_r_processes > 0L)
          pair$kept <- !loaded || attempt == max_retries
          rows <- add(rows, pair)
          if (pair$kept[[1L]]) break
        }
      }
    }
    do.call(rbind, rows)
  }
  timing <- rbind(
    paired(fx_scale, c("ledgr_run", "ledgr_sweep", "ledgr_sweep spot_fifo"), reps),
    paired(fx_scale, "ledgr_sweep 8 candidates", 3L, warm = 0L),
    paired(fx_scale, c("ledgr_run monthly", "ledgr_sweep monthly"), 5L))
  write_ev(timing, "timing.csv")
  write_ev(summarise_timing(utils::read.csv(file.path(out_dir, "timing.csv"), stringsAsFactors = FALSE)), "timing_summary.csv")

  # ---- additivity: base, block only, prepared only and combined in one session ---------------
  # Four arms per repetition in a Williams order (each arm first once and each arm directly
  # after every other arm once over four repetitions); the same load rule, applied to the
  # whole block of four.
  four_arms <- c(arms["base"], single_arms, arms["combined"])
  williams <- list(c("base", "block", "combined", "prepared"), c("block", "prepared", "base", "combined"),
    c("prepared", "combined", "block", "base"), c("combined", "base", "prepared", "block"))
  factorial <- function(fx, workflows, n = 4L, warm = 1L, max_retries = 3L) {
    sweep_path <- fresh_copy(fx); on.exit(unlink(sweep_path), add = TRUE)
    rows <- list()
    for (workflow in workflows) {
      for (w in seq_len(warm)) for (arm in names(four_arms)) invisible(clock_on(fx, sweep_path, workflow, four_arms[[arm]]))
      for (r in seq_len(n)) {
        order <- williams[[(r - 1L) %% 4L + 1L]]
        for (attempt in 0:max_retries) {
          obs <- lapply(seq_along(order), function(pos) {
            v <- clock_on(fx, sweep_path, workflow, four_arms[[order[[pos]]]])
            log_line(fx$instruments, " ", workflow, " additivity rep ", r, " attempt ", attempt, " ", order[[pos]], " ", round(v[[1L]], 2), " s")
            data.frame(instruments = fx$instruments, workflow = workflow, rep = r, attempt = attempt, position = pos,
              arm = order[[pos]], elapsed_s = v[[1L]], gc_s = v[[2L]], other_cpu_cores = round(v[[3L]], 3),
              other_r_processes = other_r())
          })
          block <- do.call(rbind, obs)
          loaded <- any(block$other_cpu_cores >= 1 | block$other_r_processes > 0L)
          block$kept <- !loaded || attempt == max_retries
          rows <- add(rows, block)
          if (block$kept[[1L]]) break
        }
      }
    }
    do.call(rbind, rows)
  }
  write_ev(factorial(fx_scale, c("ledgr_run", "ledgr_sweep")), "additivity.csv")
  write_ev(summarise_additivity(utils::read.csv(file.path(out_dir, "additivity.csv"), stringsAsFactors = FALSE)),
    "additivity_summary.csv")

  width <- list()
  for (n in c(10L, 50L, 150L)) {
    fx_n <- seal_pristine(as.data.frame(ledgr_sim_bars(n_instruments = n, n_days = 1260L, seed = 20260530L)), sprintf("w%d", n))
    width <- add(width, paired(fx_n, c("ledgr_run", "ledgr_sweep"), 3L))
    unlink(fx_n$path)
  }
  write_ev(do.call(rbind, width), "width_scaling.csv")

  log_line("attribution profiles")
  focus <- c("output_handler$write_fill_events", "handler$buffer_event", "output_handler$flush_pulse_events",
    "ctx$features", "ledgr_feature_lookup_map", "ledgr_fill_event_payload", "ledgr_lot_apply_fill", "ledgr_call_strategy_fn")
  attribution <- list()
  sweep_path <- fresh_copy(fx_scale)
  for (workflow in c("ledgr_run", "ledgr_sweep")) for (arm in names(arms)) {
    prof <- tempfile(fileext = ".Rprof")
    utils::Rprof(prof, interval = 0.01)
    invisible(clock_on(fx_scale, sweep_path, workflow, arms[[arm]]))
    utils::Rprof(NULL)
    s <- utils::summaryRprof(prof); unlink(prof)
    tot <- s$by.total
    attribution <- add(attribution, data.frame(workflow = workflow, arm = arm, fn = focus,
      total_seconds = vapply(focus, function(f) { v <- tot[sprintf("\"%s\"", f), "total.time"]; if (is.na(v)) 0 else v }, 1),
      sampled_seconds = s$sampling.time))
  }
  unlink(sweep_path)
  write_ev(do.call(rbind, attribution), "attribution.csv")
  log_line("timing, width and attribution evidence written")
}
for (fx in list(fx_dense, fx_avail, fx_scale)) unlink(fx$path)
