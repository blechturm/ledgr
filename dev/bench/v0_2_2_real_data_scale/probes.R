# Growth-shape micro-probes for the Cut 11 findings F1, F2 and F4 to F13
# (LDG-2982).
#
#   Rscript probes.R <repo> <out_dir> [finding ...]
#
# Each probe measures one finding against the collection it scales with, at
# two or three sizes, and writes rows to <out_dir>/probes.csv: finding,
# collection, size, metric, value. Timing probes report seconds and their
# growth exponent (log time ratio over log size ratio); counting probes report
# how often a shape runs. Run it on the pre-cut tree to show each shape and on a
# candidate tree to show it removed. Probes use synthetic data only.

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(args[[1L]], winslash = "/")
out_dir <- args[[2L]]
only <- if (length(args) > 2L) args[-(1:2)] else NULL
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
source(file.path(here, "fixture.R"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
ns <- asNamespace("ledgr")
rows <- list()
emit <- function(finding, collection, size, metric, value) {
  rows[[length(rows) + 1L]] <<- data.frame(finding = finding, collection = collection, size = size,
                                           metric = metric, value = signif(value, 6), stringsAsFactors = FALSE)
  cat(sprintf("%-4s %-22s %8s %-28s %s\n", finding, collection, size, metric, signif(value, 6)))
}
secs <- function(expr) { t0 <- Sys.time(); force(expr); as.numeric(difftime(Sys.time(), t0, units = "secs")) }
exponent <- function(finding, collection, sizes, times) {
  emit(finding, collection, paste(range(sizes), collapse = "->"), "growth_exponent",
       log(times[[length(times)]] / times[[1L]]) / log(sizes[[length(sizes)]] / sizes[[1L]]))
}
counting <- function(fun, expr) {
  calls <- 0L
  suppressMessages(trace(fun, tracer = function() calls <<- calls + 1L, where = ns, print = FALSE))
  on.exit(suppressMessages(untrace(fun, where = ns)), add = TRUE)
  force(expr)
  calls
}
run_on <- function(snapshot, strategy, params, features = list(), run_id = "probe") {
  exp <- ledgr_experiment(snapshot, strategy, features = features, universe = ledgr_universe_members("U"),
                          valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1e6))
  ledgr_run(exp, params = params, run_id = run_id)
}
fixture <- function(n_inst, n_days, n_mem) scale_fixture_snapshot(tempfile(fileext = ".duckdb"), n_inst, n_days, n_mem)
probe <- function(id) is.null(only) || id %in% only

# F1: the availability results plane against pulses (events grow with pulses).
if (probe("F1")) {
  sizes <- c(120L, 240L)
  times <- vapply(sizes, function(d) {
    s <- fixture(60L, d, 30L); on.exit(ledgr_snapshot_close(s))
    bt <- run_on(s, scale_equal_weight, list(f = 0.95))
    t <- secs(ledgr_results(bt, "availability")); emit("F1", "pulses", d, "availability_seconds", t); t
  }, numeric(1))
  exponent("F1", "pulses", sizes, times)
}

# F2: fill recording-pulse resolution against fills.
if (probe("F2") && exists("ledgr_fill_recording_pulses_from_evidence", envir = ns)) {
  sizes <- c(10000L, 40000L)
  nses <- 5000L
  d <- as.POSIXct("2000-01-03", tz = "UTC") + 86400 * (0:(nses - 1L))
  sessions <- data.frame(status = "open", session_open = d + 14.5 * 3600, session_close = d + 21 * 3600)
  times <- vapply(sizes, function(n) {
    set.seed(n); k <- sample.int(nses - 1L, n, TRUE) + 1L
    fills <- data.frame(event_seq = seq_len(n), ts_utc = sessions$session_open[k], instrument_id = "A")
    diag <- data.frame(event_seq = seq_len(n), instrument_id = "A", stage = "execution", outcome = "filled",
                       decision_ts_utc = sessions$session_close[k - 1L], execution_ts_utc = sessions$session_open[k])
    t <- secs(ns$ledgr_fill_recording_pulses_from_evidence(fills, diag, sessions,
          list(execution_timing_convention = "availability_open_v2", execution_timing_version = 2L)))
    emit("F2", "fills", n, "resolution_seconds", t); t
  }, numeric(1))
  exponent("F2", "fills", sizes, times)
}

# F4: the sweep memory handler's diagnostic append against accumulated rows.
if (probe("F4")) {
  chunk <- as.data.frame(ns$ledgr_availability_diagnostic_columns(4096L), stringsAsFactors = FALSE)
  chunk$run_id <- "probe"; chunk$instrument_id <- sprintf("I%04d", seq_len(4096L)); chunk$reason_code <- "decision_recorded"
  sizes <- c(50L, 100L, 200L)
  times <- vapply(sizes, function(k) {
    h <- ns$ledgr_memory_output_handler("probe")
    t <- secs(for (i in seq_len(k)) h$write_run_diagnostics(chunk))
    emit("F4", "diagnostic_rows", k * 4096L, "append_seconds", t); t
  }, numeric(1))
  exponent("F4", "diagnostic_rows", sizes * 4096L, times)
}

# F5: asset-state normalisation per pulse against the decision axis.
if (probe("F5") && exists("ledgr_fold_asset_state_normalize", envir = ns)) {
  for (n in c(250L, 500L, 1000L)) {
    axis <- sprintf("I%04d", seq_len(n)); st <- list(month = "2000-01")
    t <- secs(for (i in 1:200) { st <- ns$ledgr_fold_asset_state_normalize(st, axis, drop_exited = TRUE)
                                  st <- ns$ledgr_fold_asset_state_normalize(st, axis) })
    emit("F5", "axis", n, "ms_per_pulse", 1000 * t / 200)
  }
}

# F6 and F7: durable appends of features and diagnostics, counted per run.
if (probe("F6") || probe("F7")) {
  appends <- new.env(); appends$features <- 0L; appends$diag <- 0L
  suppressMessages(trace("dbAppendTable", where = asNamespace("DBI"), print = FALSE, tracer = quote({
    tb <- tryCatch(as.character(name), error = function(e) "")
    if (identical(tb, "features")) assign("features", get("features", appends) + 1L, appends)
    if (identical(tb, "run_diagnostics")) assign("diag", get("diag", appends) + 1L, appends)
  })))
  for (m in c(20L, 40L)) {
    s <- fixture(2L * m, 120L, m)
    appends$features <- 0L; appends$diag <- 0L
    bt <- run_on(s, scale_momentum, list(lookback = 20L, n = 5L), list(ledgr_ind_returns(20L)), run_id = paste0("f6-", m))
    n_diag <- nrow(ledgr_results(bt, "diagnostics"))
    emit("F6", "instruments", 2L * m, "feature_appends_per_run", appends$features)
    emit("F7", "diagnostic_rows", n_diag, "diagnostic_appends_per_run", appends$diag)
    ledgr_snapshot_close(s)
  }
  suppressMessages(untrace("dbAppendTable", where = asNamespace("DBI")))
}

# F8: fill-heavy loop time against held members (fills grow with members).
if (probe("F8")) {
  sizes <- c(40L, 80L, 160L)
  times <- vapply(sizes, function(m) {
    s <- fixture(2L * m, 120L, m); on.exit(ledgr_snapshot_close(s))
    json <- 0L
    t <- secs(json <- counting("canonical_json", bt <- run_on(s, scale_equal_weight, list(f = 0.95), run_id = paste0("f8-", m))))
    fills <- nrow(ledgr_results(bt, "fills"))
    emit("F8", "members", m, "run_seconds", t)
    emit("F8", "members", m, "canonical_json_calls_per_fill", json / max(1L, fills))
    t / max(1L, fills)
  }, numeric(1))
  exponent("F8", "members(seconds_per_fill)", sizes, times)
}

# F9: per-row timestamp tokens against rows, with a fixed set of instants.
if (probe("F9") && exists("ledgr_fact_time_token", envir = ns)) {
  instants <- as.POSIXct("2000-01-03 21:00", tz = "UTC") + 86400 * (0:999)
  sizes <- c(100000L, 400000L)
  times <- vapply(sizes, function(n) { x <- rep_len(instants, n)
    t <- secs(ns$ledgr_fact_time_token(x)); emit("F9", "rows(1000 distinct)", n, "token_seconds", t); t }, numeric(1))
  exponent("F9", "rows(1000 distinct)", sizes, times)
}

# F10: snapshot build time per bar against bars.
if (probe("F10")) {
  sizes <- c(100L, 400L)
  times <- vapply(sizes, function(n) {
    t <- secs(s <- fixture(n, 500L, n %/% 2L)); ledgr_snapshot_close(s)
    emit("F10", "bars", n * 500L, "build_seconds", t); t }, numeric(1))
  exponent("F10", "bars", sizes * 500L, times)
}

# F11 and F12: per-candidate setup and per-pulse state serialisation in a sweep.
if (probe("F11") || probe("F12")) {
  s <- fixture(60L, 120L, 30L)
  exp <- ledgr_experiment(s, scale_equal_weight, universe = ledgr_universe_members("U"),
                          valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1e6))
  for (k in c(1L, 3L)) {
    grid <- ledgr_strategy_grid(f = seq(0.9, 0.99, length.out = k))
    if (probe("F11")) {
      prov <- counting("ledgr_availability_provider_build_prepared", ledgr_sweep(exp, grid, seed = 1L))
      views <- counting("ledgr_projection_pulse_views", ledgr_sweep(exp, grid, seed = 1L))
      plans <- counting("ledgr_corporate_action_plan", ledgr_sweep(exp, grid, seed = 1L))
      emit("F11", "candidates", k, "provider_builds", prov)
      emit("F11", "candidates", k, "pulse_view_builds", views)
      emit("F11", "candidates", k, "corporate_action_plans", plans)
    }
    if (probe("F12")) {
      json <- counting("canonical_json", ledgr_sweep(exp, grid, seed = 1L))
      emit("F12", "candidates x pulses", k * 120L, "canonical_json_calls_per_pulse", json / (k * 120L))
    }
  }
  ledgr_snapshot_close(s)
}

# F13: context vectors built per pulse in a durable run.
if (probe("F13") && exists("ledgr_pulse_context_vec", envir = ns)) {
  s <- fixture(60L, 120L, 30L)
  vec <- counting("ledgr_pulse_context_vec", run_on(s, scale_equal_weight, list(f = 0.95), run_id = "f13"))
  emit("F13", "pulses", 120L, "context_vec_builds_per_pulse", vec / 120L)
  ledgr_snapshot_close(s)
}

out <- do.call(rbind, rows)
utils::write.csv(out, file.path(out_dir, "probes.csv"), row.names = FALSE)
cat("PROBES_OK", nrow(out), "rows\n")
