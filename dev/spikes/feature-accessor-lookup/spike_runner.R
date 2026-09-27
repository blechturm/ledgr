# Runner for the feature-accessor lookup spike.
#
# Question: does building the fast-context ctx$feature()/ctx$features() lookups
# once per run (hashed instrument, universe and feature-id lookups; the active
# alias map normalized once) cut warm ledgr_run, ledgr_sweep and compiled
# spot_fifo sweep time by more than 5% at 500 x 1,260 (SMA 5/10), with identical
# results and identical accessor errors? Two arms: production accessors ("base")
# and the in-memory seam in seam.R ("prepared").
#
# Usage, from the repository root:
#   Rscript dev/spikes/feature-accessor-lookup/spike_runner.R \
#       [--phase parity|all] [--out <dir>] [--reps <n>] [--gut none|shifted]
# parity writes fixture.csv, conformance.csv, parity.csv and environment.csv;
# all adds timing.csv, timing_summary.csv, width_scaling.csv and attribution.csv.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
spike_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
phase <- arg_value("--phase", "all")
out_dir <- arg_value("--out", file.path(spike_dir, "evidence"))
reps <- as.integer(arg_value("--reps", "7"))
gut <- arg_value("--gut", "none")
stopifnot(phase %in% c("parity", "all"), gut %in% c("none", "shifted"), reps >= 3L)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (!file.exists(file.path(repo_root, "src", paste0("ledgr", .Platform$dynlib.ext)))) {
  stop("Build the package once first; the runner loads with compile = FALSE.")
}
suppressMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
source(file.path(spike_dir, "seam.R"))
source(file.path(spike_dir, "summarise_timing.R"))
arms <- list(base = NULL, prepared = fl_prepared_functions(ns, gut))
write_ev <- function(x, name) utils::write.csv(x, file.path(out_dir, name), row.names = FALSE)
log_line <- function(...) cat(sprintf("[%s] ", format(Sys.time(), "%H:%M:%S")), ..., "\n", sep = "")
quiet <- function(expr) suppressWarnings(suppressMessages(expr))
add <- function(lst, row) c(lst, list(row))

# ---- fixtures and strategies ---------------------------------------------------------
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
concrete_map <- function() ledgr_feature_map(fast = ledgr_ind_sma(5L), slow = ledgr_ind_sma(10L))
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
scalar_strategy <- function(ctx, params) {
  t <- ctx$flat()
  for (id in ctx$universe) {
    f <- ctx$feature(id, "sma_5"); s <- ctx$feature(id, "sma_10")
    if (is.finite(f) && is.finite(s) && f > s) t[id] <- 1
  }
  t
}
spec_alias <- function(valuation = NULL) list(strategy = ledgr_demo_sma_crossover_strategy(), features = alias_features(),
  valuation = valuation, params = list(qty = 1, threshold = 0), feature_params = list(fast_n = 5L, slow_n = 10L))
spec_map <- function() { m <- concrete_map(); list(strategy = explicit_map_strategy(m), features = m, valuation = NULL,
  params = list(), feature_params = list()) }
spec_scalar <- function() list(strategy = scalar_strategy, features = list(ledgr_ind_sma(5L), ledgr_ind_sma(10L)),
  valuation = NULL, params = list(), feature_params = list())
experiment <- function(snapshot, spec) ledgr_experiment(snapshot, spec$strategy, features = spec$features,
  opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(), valuation_policy = spec$valuation)
grid_of <- function(spec, thresholds = c(0, 0.01)) {
  if (length(spec$feature_params)) {
    ledgr_grid_cross(features = ledgr_feature_grid(fast_n = 5L, slow_n = 10L),
      strategy = ledgr_strategy_grid(qty = 1, threshold = thresholds))
  } else {
    ledgr_param_grid(list(unused = 1), list(unused = 2))
  }
}

# ---- workflows under one arm ----------------------------------------------------------
read_events <- function(path, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
}
run_workflow <- function(fx, spec, functions, run_id = "spike-run") {
  path <- fresh_copy(fx)
  snapshot <- ledgr_snapshot_open(path, fx$id)
  run <- fl_with(ns, functions, quiet(ledgr_run(experiment(snapshot, spec), params = spec$params,
    feature_params = spec$feature_params, run_id = run_id, seed = 1L)))
  out <- list(fills = ledgr_results(run, what = "fills"), equity = ledgr_results(run, what = "equity"),
    trades = ledgr_results(run, what = "trades"))
  close(run); ledgr_snapshot_close(snapshot)
  out$ledger_events <- read_events(path, run_id)
  unlink(path)
  out
}
sweep_workflow <- function(fx, spec, functions, grid = grid_of(spec), compiled = NULL, retain = TRUE) {
  snapshot <- ledgr_snapshot_open(fx$path, fx$id)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  retention <- if (retain) ledgr_sweep_retention(returns = "completed", trades = "closed") else ledgr_sweep_retention()
  s <- fl_with(ns, functions, quiet(ledgr_sweep(experiment(snapshot, spec), grid, seed = 1L, retain = retention,
    compiled_accounting_model = compiled)))
  drop_id <- function(x) if (is.data.frame(x)) x[setdiff(names(x), "sweep_id")] else x   # sweep_id is random per call
  a <- attributes(s)
  keep <- names(s)[!grepl("^t_", names(s))]
  list(columns = stats::setNames(lapply(keep, function(n) s[[n]]), keep),
    returns = drop_id(a$sweep_returns), trades = drop_id(a$sweep_trades),
    attributes = a[setdiff(names(a), c("names", "row.names", "class", "sweep_id", "sweep_returns", "sweep_trades"))])
}
nrows <- function(x) if (is.data.frame(x)) nrow(x) else if (is.list(x) && length(x) && is.atomic(x[[1L]])) length(x[[1L]]) else length(x)
parity_rows <- function(case, workflow, base, other) {
  do.call(rbind, lapply(names(base), function(surface) data.frame(case = case, workflow = workflow, surface = surface,
    rows_base = nrows(base[[surface]]), rows_prepared = nrows(other[[surface]]), identical = identical(base[[surface]], other[[surface]]))))
}

# ---- accessor conformance on inputs captured from a real run ---------------------------
conformance <- function(fx) {
  captured <- new.env()
  original <- get("ledgr_projection_feature_bundle_accessor_state", envir = ns)
  capture <- function(projection, state, universe, feature_ids = NULL, active_alias_map = NULL) {
    captured$args <- list(projection = projection, universe = universe, feature_ids = feature_ids, active_alias_map = active_alias_map)
    original(projection, state, universe, feature_ids, active_alias_map)
  }
  spec <- spec_alias()
  path <- fresh_copy(fx); snapshot <- ledgr_snapshot_open(path, fx$id)
  run <- fl_with(ns, list(ledgr_projection_feature_bundle_accessor_state = capture), quiet(ledgr_run(experiment(snapshot, spec),
    params = spec$params, feature_params = spec$feature_params, run_id = "capture", seed = 1L)))
  close(run); ledgr_snapshot_close(snapshot); unlink(path)
  a <- captured$args
  build <- function(functions) fl_with(ns, functions, {
    state <- new.env(parent = emptyenv()); state$pulse_idx <- 1L
    list(state = state,
      feature = get("ledgr_projection_feature_accessor_state", envir = ns)(a$projection, state, a$feature_ids),
      features = get("ledgr_projection_feature_bundle_accessor_state", envir = ns)(a$projection, state, a$universe,
        a$feature_ids, a$active_alias_map))
  })
  outcome <- function(expr) tryCatch(expr, error = function(e) paste0("<error> ", class(e)[[1L]], ": ", conditionMessage(e)))
  describe <- function(x) if (is.character(x) && length(x) == 1L && startsWith(x, "<error>")) x else
    paste(sprintf("%s=%s", names(x) %||% "", format(x, digits = 15)), collapse = " ")
  fmap <- alias_features(); fmap_concrete <- concrete_map()
  u <- a$universe; f1 <- a$feature_ids[[1L]]
  calls <- list(
    features_first_member = function(acc) acc$features(u[[1L]]),
    features_last_member = function(acc) acc$features(u[[length(u)]]),
    features_unknown_instrument = function(acc) acc$features("NOPE"),
    features_numeric_instrument = function(acc) acc$features(1),
    features_na_instrument = function(acc) acc$features(NA_character_),
    features_parameterized_map = function(acc) acc$features(u[[2L]], fmap),
    features_concrete_map = function(acc) acc$features(u[[2L]], fmap_concrete),
    feature_known = function(acc) acc$feature(u[[3L]], f1),
    feature_unknown_feature = function(acc) acc$feature(u[[3L]], "sma_999"),
    feature_unknown_instrument = function(acc) acc$feature("NOPE", f1),
    feature_default_for_unknown_instrument = function(acc) acc$feature("NOPE", f1, default = -1)
  )
  base <- build(arms$base); prep <- build(arms$prepared)
  n_pulse <- ncol(a$projection$feature_values[[f1]])
  rows <- list()
  for (p in unique(c(1L, n_pulse %/% 2L, n_pulse))) {
    base$state$pulse_idx <- p; prep$state$pulse_idx <- p
    for (nm in names(calls)) {
      b <- outcome(calls[[nm]](base)); r <- outcome(calls[[nm]](prep))
      rows <- add(rows, data.frame(call = nm, pulse = p, identical = identical(b, r), base_outcome = describe(b)))
    }
  }
  do.call(rbind, rows)
}

# ---- parity phase -----------------------------------------------------------------------
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
write_ev(conformance(fx_dense), "conformance.csv")
cases <- list(
  list(case = "f1_active_alias_map", fx = fx_dense, spec = spec_alias(), compiled = TRUE),
  list(case = "f2_explicit_feature_map", fx = fx_dense, spec = spec_map(), compiled = FALSE),
  list(case = "f3_scalar_feature", fx = fx_dense, spec = spec_scalar(), compiled = FALSE),
  list(case = "f4_availability_uneven", fx = fx_avail, spec = spec_alias(valuation = ledgr_valuation_stale(2L)), compiled = FALSE)
)
for (cs in cases) {
  fixture <- add(fixture, data.frame(case = cs$case, instruments = cs$fx$instruments, bars = cs$fx$rows))
  parity <- add(parity, parity_rows(cs$case, "ledgr_run", run_workflow(cs$fx, cs$spec, arms$base),
    run_workflow(cs$fx, cs$spec, arms$prepared)))
  parity <- add(parity, parity_rows(cs$case, "ledgr_sweep", sweep_workflow(cs$fx, cs$spec, arms$base),
    sweep_workflow(cs$fx, cs$spec, arms$prepared)))
  if (cs$compiled) {
    parity <- add(parity, parity_rows(cs$case, "ledgr_sweep spot_fifo", sweep_workflow(cs$fx, cs$spec, arms$base, compiled = "spot_fifo"),
      sweep_workflow(cs$fx, cs$spec, arms$prepared, compiled = "spot_fifo")))
  }
}

log_line("release-shape fixture")
scale_bars <- as.data.frame(ledgr_sim_bars(n_instruments = 500L, n_days = 1260L, seed = 20260530L))
fx_scale <- seal_pristine(scale_bars, "scale")
rm(scale_bars)
fixture <- add(fixture, data.frame(case = "s1_release_shape", instruments = fx_scale$instruments, bars = fx_scale$rows))
spec_scale <- spec_alias()
one <- grid_of(spec_scale, thresholds = 0)
run_base <- run_workflow(fx_scale, spec_scale, arms$base)
parity <- add(parity, parity_rows("s1_release_shape", "ledgr_run", run_base, run_workflow(fx_scale, spec_scale, arms$prepared)))
parity <- add(parity, parity_rows("s1_release_shape", "ledgr_sweep", sweep_workflow(fx_scale, spec_scale, arms$base, one, retain = FALSE),
  sweep_workflow(fx_scale, spec_scale, arms$prepared, one, retain = FALSE)))
parity <- add(parity, parity_rows("s1_release_shape", "ledgr_sweep spot_fifo",
  sweep_workflow(fx_scale, spec_scale, arms$base, one, compiled = "spot_fifo", retain = FALSE),
  sweep_workflow(fx_scale, spec_scale, arms$prepared, one, compiled = "spot_fifo", retain = FALSE)))
write_ev(do.call(rbind, fixture), "fixture.csv")
write_ev(do.call(rbind, parity), "parity.csv")

git1 <- function(...) {
  old <- Sys.getenv("HOME"); on.exit(Sys.setenv(HOME = old), add = TRUE)
  if (nzchar(Sys.getenv("USERPROFILE"))) Sys.setenv(HOME = Sys.getenv("USERPROFILE"))
  out <- suppressWarnings(system2("git", c("-C", shQuote(repo_root), ...), stdout = TRUE, stderr = FALSE))
  if (length(out)) out[[1L]] else NA_character_
}
write_ev(data.frame(key = c("r_version", "os", "collapse", "duckdb", "pkgload", "git_head", "blob_runtime_projection",
  "blob_feature_alias_map", "blob_pulse_context", "cpu", "gut", "fills_release_shape"),
  value = c(R.version.string, paste(Sys.info()[c("sysname", "release")], collapse = " "),
    as.character(packageVersion("collapse")), as.character(packageVersion("duckdb")), as.character(packageVersion("pkgload")),
    git1("rev-parse", "HEAD"), git1("rev-parse", "HEAD:R/runtime-projection.R"), git1("rev-parse", "HEAD:R/feature-alias-map.R"),
    git1("rev-parse", "HEAD:R/pulse-context.R"), Sys.getenv("PROCESSOR_IDENTIFIER"), gut, nrow(run_base$fills))), "environment.csv")
log_line("parity evidence written")

if (identical(phase, "all")) {
  # ---- warm clocks over a reused sealed snapshot -----------------------------------------
  invisible(gc.time(TRUE))
  # Background load contaminates wall clocks. Each observation records the CPU time
  # every other process used while it ran (as average busy cores) and how many other R
  # processes were running when it finished. Per-process CPU snapshots are taken outside
  # the timed region: a process's in-interval CPU is its after minus before, a process
  # that started (or reused an id) counts from zero, and a process that exited is lost,
  # so readings can undercount but never go negative. Processes whose CPU Windows does
  # not expose (protected ones) are invisible to this meter.
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
  clock_on <- function(fx, sweep_path, workflow, functions) {
    if (workflow == "ledgr_run") {
      n_run <<- n_run + 1L
      path <- fresh_copy(fx); snapshot <- ledgr_snapshot_open(path, fx$id)   # untimed: pristine store per run
      invisible(gc()); a0 <- cpu_by_process(); g0 <- gc.time()[[3L]]; t0 <- Sys.time()
      run <- fl_with(ns, functions, quiet(ledgr_run(experiment(snapshot, spec_scale), params = spec_scale$params,
        feature_params = spec_scale$feature_params, run_id = sprintf("timed-%04d", n_run), seed = 1L)))
      invisible(ledgr_results(run, what = "fills")); invisible(ledgr_results(run, what = "equity")); close(run)
      t1 <- Sys.time(); g1 <- gc.time()[[3L]]; a1 <- cpu_by_process()
      ledgr_snapshot_close(snapshot); unlink(path)
    } else {
      compiled <- if (workflow == "ledgr_sweep spot_fifo") "spot_fifo" else NULL
      snapshot <- ledgr_snapshot_open(sweep_path, fx$id); on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
      invisible(gc()); a0 <- cpu_by_process(); g0 <- gc.time()[[3L]]; t0 <- Sys.time()
      invisible(fl_with(ns, functions, quiet(ledgr_sweep(experiment(snapshot, spec_scale), one, seed = 1L,
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
        order <- if (r %% 2L == 1L) c("base", "prepared") else c("prepared", "base")
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
  timing <- paired(fx_scale, c("ledgr_run", "ledgr_sweep", "ledgr_sweep spot_fifo"), reps)
  write_ev(timing, "timing.csv")
  write_ev(summarise_timing(utils::read.csv(file.path(out_dir, "timing.csv"), stringsAsFactors = FALSE)), "timing_summary.csv")

  # ---- width scaling (3 repetitions; run and canonical sweep) --------------------------------
  width <- list()
  for (n in c(10L, 50L, 150L)) {
    fx_n <- seal_pristine(as.data.frame(ledgr_sim_bars(n_instruments = n, n_days = 1260L, seed = 20260530L)), sprintf("w%d", n))
    width <- add(width, paired(fx_n, c("ledgr_run", "ledgr_sweep"), 3L))
    unlink(fx_n$path)
  }
  write_ev(do.call(rbind, width), "width_scaling.csv")

  # ---- attribution: one sampled profile per arm and workflow (not a clock) ---------------------
  log_line("attribution profiles")
  focus <- c("ledgr_call_strategy_fn", "ctx$features", "feature", "ledgr_feature_lookup_map", "ledgr_normalize_alias_map",
    "%in%", "unname", "stats::setNames", "vapply")
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
