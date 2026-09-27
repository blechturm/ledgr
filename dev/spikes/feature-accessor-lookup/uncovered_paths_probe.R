# Probe (d) for the feature-accessor spike: the two accessor paths the prepared
# seam leaves at production behaviour.
#   explicit feature map   ctx$features(id, feature_map) on the fast context: the map
#                          object is validated and resolved on every call;
#   availability path      contexts are rebuilt each pulse through
#                          ledgr_attach_feature_helpers(), which constructs fresh
#                          projection accessors per pulse.
# Writes uncovered_profiles.csv (one sampled profile per workload at 500 x 1,260,
# production code only) and uncovered_calls.csv (per-call R-heap allocation via
# Rprofmem and unprofiled microseconds, base vs prepared where the seam applies).
#
# Usage, from the repository root:
#   Rscript dev/spikes/feature-accessor-lookup/uncovered_paths_probe.R [--out <dir>]

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
spike_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
out_dir <- arg_value("--out", file.path(spike_dir, "evidence"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
source(file.path(spike_dir, "seam.R"))
prepared <- fl_prepared_functions(ns)
quiet <- function(expr) suppressWarnings(suppressMessages(expr))

bars <- as.data.frame(ledgr_sim_bars(n_instruments = 500L, n_days = 1260L, seed = 20260530L))
seal <- function(b, sessions) {
  path <- tempfile(fileext = ".duckdb"); facts <- NULL
  if (sessions) {
    b$ts_utc <- as.Date(b$ts_utc, tz = "UTC")
    dates <- seq(min(b$ts_utc), max(b$ts_utc), by = "day"); open <- !format(dates, "%u") %in% c("6", "7")
    facts <- ledgr_facts(ledgr_facts_sessions(data.frame(session_date = dates, status = ifelse(open, "open", "closed"),
      session_open = ifelse(open, "14:30:00", NA_character_), session_close = ifelse(open, "21:00:00", NA_character_),
      knowledge_time = as.POSIXct(min(dates) - 1L, tz = "UTC")), venue_id = "SPIKE", timezone = "UTC"))
  }
  s <- ledgr_snapshot_from_df(b, db_path = path, snapshot_id = "u", facts = facts); ledgr_snapshot_close(s)
  path
}
alias_map <- ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n")))
concrete_map <- ledgr_feature_map(fast = ledgr_ind_sma(5L), slow = ledgr_ind_sma(10L))
explicit_strategy <- local({ fmap <- concrete_map; function(ctx, params) {
  t <- ctx$flat()
  for (id in ctx$universe) { v <- ctx$features(id, fmap); if (all(is.finite(v)) && v[["fast"]] > v[["slow"]]) t[id] <- 1 }
  t
} })

# 1. Profiles of the uncovered workloads (production code).
focus <- c("ledgr_execute_fold", "ledgr_call_strategy_fn", "ctx$features", "feature", "ledgr_feature_lookup_map",
  "ledgr_validate_feature_map_object", "ledgr_feature_id", "ledgr_normalize_alias_map", "%in%",
  "ledgr_update_pulse_context_helpers", "ledgr_attach_feature_helpers", "ledgr_projection_feature_accessor",
  "ledgr_projection_feature_bundle_accessor", "ledgr_projection_feature_vector_accessor",
  "ledgr_filter_pulse_context_features", "ledgr_update_fast_pulse_context_helpers", "ledgr_feature_names_message")
profile_run <- function(label, path, exp_fun, params, feature_params) {
  snapshot <- ledgr_snapshot_open(path, "u"); on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  prof <- tempfile(fileext = ".Rprof")
  t0 <- Sys.time(); utils::Rprof(prof, interval = 0.01)
  run <- quiet(ledgr_run(exp_fun(snapshot), params = params, feature_params = feature_params, run_id = label, seed = 1L))
  utils::Rprof(NULL); wall <- as.numeric(Sys.time() - t0, units = "secs"); close(run)
  s <- utils::summaryRprof(prof); unlink(prof)
  data.frame(workload = label, fn = focus,
    total_seconds = vapply(focus, function(f) { v <- s$by.total[sprintf("\"%s\"", f), "total.time"]; if (is.na(v)) 0 else v }, 1),
    sampled_seconds = s$sampling.time, wall_seconds = round(wall, 2))
}
dense <- seal(bars, FALSE); avail <- seal(bars, TRUE)
profiles <- rbind(
  profile_run("explicit_feature_map_run", dense, function(s) ledgr_experiment(s, explicit_strategy, features = concrete_map,
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero()), list(), list()),
  profile_run("availability_path_run", avail, function(s) ledgr_experiment(s, ledgr_demo_sma_crossover_strategy(),
    features = alias_map, opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
    valuation_policy = ledgr_valuation_stale(2L)), list(qty = 1, threshold = 0), list(fast_n = 5L, slow_n = 10L))
)
utils::write.csv(profiles, file.path(out_dir, "uncovered_profiles.csv"), row.names = FALSE)

# 2. Per-call cost on captured fast-context inputs, plus the per-pulse accessors of the availability path.
holder <- new.env()
original <- get("ledgr_projection_feature_bundle_accessor_state", envir = ns)
capture <- function(projection, state, universe, feature_ids = NULL, active_alias_map = NULL) {
  holder$args <- list(projection = projection, universe = universe, feature_ids = feature_ids, active_alias_map = active_alias_map)
  stop(structure(class = c("probe_captured", "error", "condition"), list(message = "captured", call = NULL)))
}
snapshot <- ledgr_snapshot_open(dense, "u")
tryCatch(quiet(fl_with(ns, list(ledgr_projection_feature_bundle_accessor_state = capture), ledgr_run(ledgr_experiment(snapshot,
  ledgr_demo_sma_crossover_strategy(), features = alias_map, opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero()),
  params = list(qty = 1, threshold = 0), feature_params = list(fast_n = 5L, slow_n = 10L), run_id = "cap", seed = 1L))),
  error = function(e) if (is.null(holder$args)) stop(e))
ledgr_snapshot_close(snapshot)
a <- holder$args; u <- a$universe
pulses <- round(seq(20L, ncol(a$projection$feature_values[[a$feature_ids[[1L]]]]), length.out = 10L))
measure <- function(fun) {
  invisible(gc()); tf <- tempfile(); utils::Rprofmem(tf, threshold = 0); fun(); utils::Rprofmem(NULL)
  lines <- readLines(tf); unlink(tf); big <- grep("^[0-9]+ :", lines, value = TRUE)
  invisible(gc()); t0 <- Sys.time(); fun(); secs <- as.numeric(Sys.time() - t0, units = "secs")
  c(bytes = sum(as.numeric(sub(" :.*$", "", big))), secs = secs)
}
rows <- list()
for (arm in c("base", "prepared")) {
  fns <- if (arm == "prepared") prepared else NULL
  acc <- fl_with(ns, fns, { state <- new.env(parent = emptyenv()); state$pulse_idx <- 1L
    list(state = state, features = get("ledgr_projection_feature_bundle_accessor_state", envir = ns)(a$projection, state, u,
      a$feature_ids, a$active_alias_map)) })
  calls <- length(pulses) * length(u)
  for (shape in c("alias", "explicit_feature_map")) {
    m <- measure(function() for (p in pulses) { acc$state$pulse_idx <- p
      for (id in u) if (shape == "alias") acc$features(id) else acc$features(id, concrete_map) })
    rows[[length(rows) + 1L]] <- data.frame(arm = arm, shape = shape, calls = calls, bytes_per_call = round(m[["bytes"]] / calls, 1),
      microseconds_per_call = round(1e6 * m[["secs"]] / calls, 2))
  }
}
# Availability path: the three projection accessors ledgr_attach_feature_helpers() builds each pulse,
# on the captured dense inputs (production only; the seam does not reach this path).
m_build <- measure(function() for (p in pulses) {
  ledgr_projection_feature_accessor(a$projection, p, a$feature_ids)
  ledgr_projection_feature_vector_accessor(a$projection, p, a$feature_ids)
  ledgr_projection_feature_bundle_accessor(a$projection, p, u, a$feature_ids, a$active_alias_map) })
rows[[length(rows) + 1L]] <- data.frame(arm = "base", shape = "availability_per_pulse_accessor_build", calls = length(pulses),
  bytes_per_call = round(m_build[["bytes"]] / length(pulses), 1), microseconds_per_call = round(1e6 * m_build[["secs"]] / length(pulses), 2))
m_calls <- measure(function() for (p in pulses) {
  f <- ledgr_projection_feature_bundle_accessor(a$projection, p, u, a$feature_ids, a$active_alias_map)
  for (id in u) f(id) })
rows[[length(rows) + 1L]] <- data.frame(arm = "base", shape = "availability_per_pulse_build_and_calls", calls = length(pulses) * length(u),
  bytes_per_call = round(m_calls[["bytes"]] / (length(pulses) * length(u)), 1),
  microseconds_per_call = round(1e6 * m_calls[["secs"]] / (length(pulses) * length(u)), 2))
utils::write.csv(do.call(rbind, rows), file.path(out_dir, "uncovered_calls.csv"), row.names = FALSE)
unlink(c(dense, avail))
print(profiles, row.names = FALSE); print(do.call(rbind, rows), row.names = FALSE)
