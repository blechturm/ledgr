# Probe: do prepared fast-context feature accessors return exactly what the
# production accessors return, value for value and error for error, on inputs
# captured from a real run? Usage, from the repository root:
#   Rscript dev/spikes/feature-accessor-lookup/probe.R
suppressMessages(pkgload::load_all(".", quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
source("dev/spikes/feature-accessor-lookup/seam.R")
prepared <- fl_prepared_functions(ns)

bars <- as.data.frame(ledgr_sim_bars(n_instruments = 6L, n_days = 60L, seed = 11L))
snap <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "probe")
features <- ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n")))
exp <- ledgr_experiment(snap, ledgr_demo_sma_crossover_strategy(), features = features,
  opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())

# Capture the production factory's inputs from a real run.
captured <- new.env()
original <- get("ledgr_projection_feature_bundle_accessor_state", envir = ns)
capture <- function(projection, state, universe, feature_ids = NULL, active_alias_map = NULL) {
  captured$args <- list(projection = projection, universe = universe, feature_ids = feature_ids, active_alias_map = active_alias_map)
  original(projection, state, universe, feature_ids, active_alias_map)
}
invisible(fl_with(ns, list(ledgr_projection_feature_bundle_accessor_state = capture),
  suppressWarnings(ledgr_run(exp, params = list(qty = 1, threshold = 0), feature_params = list(fast_n = 3L, slow_n = 7L),
    run_id = "probe", seed = 1L))))
a <- captured$args
cat("captured universe:", length(a$universe), " feature ids:", paste(a$feature_ids, collapse = ","),
  " alias map:", paste(names(a$active_alias_map), a$active_alias_map, sep = "=", collapse = ","), "\n")

build <- function(functions) fl_with(ns, functions, {
  state <- new.env(parent = emptyenv()); state$pulse_idx <- 1L
  list(state = state,
    feature = get("ledgr_projection_feature_accessor_state", envir = ns)(a$projection, state, a$feature_ids),
    features = get("ledgr_projection_feature_bundle_accessor_state", envir = ns)(a$projection, state, a$universe,
      a$feature_ids, a$active_alias_map))
})
outcome <- function(expr) tryCatch(expr, error = function(e) paste0("<error> ", class(e)[[1L]], ": ", conditionMessage(e)))
base <- build(NULL); prep <- build(prepared)
calls <- list(
  features_member = function(acc) acc$features(a$universe[[3L]]),
  features_unknown_id = function(acc) acc$features("NOPE"),
  features_numeric_id = function(acc) acc$features(1),
  features_explicit_map = function(acc) acc$features(a$universe[[2L]], features),
  feature_known = function(acc) acc$feature(a$universe[[4L]], a$feature_ids[[1L]]),
  feature_unknown_feature = function(acc) acc$feature(a$universe[[4L]], "sma_999"),
  feature_unknown_instrument = function(acc) acc$feature("NOPE", a$feature_ids[[1L]])
)
for (p in c(1L, 30L, 60L)) {
  base$state$pulse_idx <- p; prep$state$pulse_idx <- p
  for (nm in names(calls)) {
    b <- outcome(calls[[nm]](base)); r <- outcome(calls[[nm]](prep))
    cat(sprintf("pulse %2d %-28s identical=%s  %s\n", p, nm, identical(b, r), paste(format(b), collapse = " ")))
  }
}
ledgr_snapshot_close(snap)
