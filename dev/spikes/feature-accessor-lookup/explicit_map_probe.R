# Supplementary probe for the feature-accessor spike: the explicit-map idiom
# ctx$features(id, feature_map), taught in the indicators and strategy-authoring
# vignettes. uncovered_paths_probe.R showed it costs about 165 us per call because
# ledgr_feature_lookup_map() validates the map object and then calls
# ledgr_feature_id(feature_map), which validates it again; each validation
# re-derives the ids by flattening the indicator list.
#
# Two alternatives for ledgr_feature_lookup_map(), bound in memory only, both on
# top of the prepared accessors from seam.R:
#   validate_once   validate once, then read feature_ids from the object (the same
#                   checks and error order as the second validation);
#   memo            validate_once, remembering the last map whose lookup succeeded
#                   and returning its lookup when the next map is identical().
#                   Production would hold the memo per accessor, that is per run.
# Writes explicit_map_conformance.csv (value, or error class and message, for
# valid and malformed maps, each called twice in a row, under all arms),
# explicit_map_calls.csv (per-call microseconds and R-heap bytes on captured
# release-shape inputs) and explicit_map_runs.csv (one unprofiled release-shape
# run each for production, prepared accessors alone, prepared plus validate_once and
# prepared plus memo: wall,
# GC and parity of fills and equity against production; single runs, not a clock).
#
# Usage, from the repository root:
#   Rscript dev/spikes/feature-accessor-lookup/explicit_map_probe.R [--out <dir>]

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
spike_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
out_dir <- arg_value("--out", file.path(spike_dir, "evidence"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
source(file.path(spike_dir, "seam.R"))
quiet <- function(expr) suppressWarnings(suppressMessages(expr))
stopifnot(capabilities("profmem"))

production_lookup <- get("ledgr_feature_lookup_map", envir = ns)
validate_once <- production_lookup
body(validate_once) <- local({
  b <- body(production_lookup)
  hits <- 0L
  walk <- function(e) {
    if (is.call(e)) {
      if (identical(e, quote(feature_ids <- ledgr_feature_id(feature_map)))) {
        hits <<- hits + 1L
        return(quote(feature_ids <- {
          if (any(vapply(feature_map$indicators, ledgr_feature_declaration_is_unresolved, logical(1)))) {
            ledgr_abort_unresolved_feature_id()
          }
          feature_map$feature_ids
        }))
      }
      for (i in seq_along(e)) if (!is.null(e[[i]])) e[[i]] <- walk(e[[i]])
    }
    e
  }
  out <- walk(b)
  stopifnot(hits == 1L)
  out
})
environment(validate_once) <- ns
# R's JIT compiles only the first instance of a closure body created in a local environment,
# so every function the arms bind is compiled explicitly and the prepared seam is built once.
validate_once <- compiler::cmpfun(validate_once)
prepared_fns <- lapply(fl_prepared_functions(ns), compiler::cmpfun)
bytecode <- function(f) any(grepl("<bytecode", utils::capture.output(print(f)), fixed = TRUE))
memo_factory <- function() {
  memo <- new.env(parent = emptyenv())
  f <- function(feature_map = NULL, active_alias_map = NULL) {
    is_map <- inherits(feature_map, "ledgr_feature_map")
    if (is_map && !is.null(memo$map) && identical(feature_map, memo$map)) return(memo$lookup)
    out <- validate_once(feature_map, active_alias_map = active_alias_map)
    if (is_map) { memo$map <- feature_map; memo$lookup <- out }
    out
  }
  compiler::cmpfun(f)
}
# One function list per arm, rebuilt (fresh memo) for each measurement. The accessor resolves
# ledgr_feature_lookup_map() at call time, so every call runs inside fl_with() for its arm.
arm_set <- function() list(
  production = prepared_fns,
  validate_once = c(prepared_fns, list(ledgr_feature_lookup_map = validate_once)),
  memo = c(prepared_fns, list(ledgr_feature_lookup_map = memo_factory())))
arms <- c("production", "validate_once", "memo")

# ---- captured release-shape inputs --------------------------------------------------------
bars <- as.data.frame(ledgr_sim_bars(n_instruments = 500L, n_days = 1260L, seed = 20260530L))
path <- tempfile(fileext = ".duckdb")
s <- ledgr_snapshot_from_df(bars, db_path = path, snapshot_id = "x"); ledgr_snapshot_close(s); rm(bars)
concrete_map <- ledgr_feature_map(fast = ledgr_ind_sma(5L), slow = ledgr_ind_sma(10L))
explicit_strategy <- local({ fmap <- concrete_map; function(ctx, params) {
  t <- ctx$flat()
  for (id in ctx$universe) { v <- ctx$features(id, fmap); if (all(is.finite(v)) && v[["fast"]] > v[["slow"]]) t[id] <- 1 }
  t
} })
holder <- new.env()
capture <- function(projection, state, universe, feature_ids = NULL, active_alias_map = NULL) {
  holder$args <- list(projection = projection, universe = universe, feature_ids = feature_ids, active_alias_map = active_alias_map)
  stop(structure(class = c("probe_captured", "error", "condition"), list(message = "captured", call = NULL)))
}
snapshot <- ledgr_snapshot_open(path, "x")
tryCatch(quiet(fl_with(ns, list(ledgr_projection_feature_bundle_accessor_state = capture), ledgr_run(ledgr_experiment(snapshot,
  explicit_strategy, features = concrete_map, opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero()),
  run_id = "cap", seed = 1L))), error = function(e) if (is.null(holder$args)) stop(e))
ledgr_snapshot_close(snapshot)
a <- holder$args; u <- a$universe
build <- function(fns) fl_with(ns, fns, {
  state <- new.env(parent = emptyenv()); state$pulse_idx <- 40L
  list(state = state, features = get("ledgr_projection_feature_bundle_accessor_state", envir = ns)(a$projection, state, u,
    a$feature_ids, a$active_alias_map))
})

# ---- conformance: value or error for valid and malformed maps, each called twice ---------------
outcome <- function(expr) tryCatch(paste(sprintf("%s=%s", names(expr), format(expr, digits = 15)), collapse = " "),
  error = function(e) paste0("<error> ", class(e)[[1L]], ": ", conditionMessage(e)))
tampered_ids <- concrete_map; tampered_ids$feature_ids[["fast"]] <- "sma_7"
swapped_aliases <- concrete_map; swapped_aliases$aliases <- rev(swapped_aliases$aliases)
unknown_feature <- ledgr_feature_map(fast = ledgr_ind_sma(5L), slow = ledgr_ind_sma(30L))
maps <- list(
  concrete = concrete_map,
  concrete_rebuilt = ledgr_feature_map(fast = ledgr_ind_sma(5L), slow = ledgr_ind_sma(10L)),
  reordered = ledgr_feature_map(slow = ledgr_ind_sma(10L), fast = ledgr_ind_sma(5L)),
  parameterized = ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(10L)),
  tampered_feature_ids = tampered_ids,
  swapped_aliases = swapped_aliases,
  unknown_feature = unknown_feature,
  character_map = c(fast = "sma_5", slow = "sma_10"),
  not_a_map = list(fast = "sma_5")
)
sequence <- c("concrete", "concrete", "tampered_feature_ids", "concrete", "concrete_rebuilt", "reordered", "parameterized",
  "parameterized", "concrete", "swapped_aliases", "unknown_feature", "unknown_feature", "character_map", "not_a_map", "concrete")
sets <- arm_set()
conformance <- do.call(rbind, lapply(arms, function(arm) {
  acc <- build(sets[[arm]])
  data.frame(arm = arm, step = seq_along(sequence), map = sequence, instrument = u[[7L]],
    outcome = fl_with(ns, sets[[arm]], vapply(sequence, function(m) outcome(acc$features(u[[7L]], maps[[m]])), "")))
}))
wide <- reshape(conformance, idvar = c("step", "map", "instrument"), timevar = "arm", direction = "wide")
wide$identical_to_production <- wide$outcome.validate_once == wide$outcome.production & wide$outcome.memo == wide$outcome.production
utils::write.csv(conformance, file.path(out_dir, "explicit_map_conformance.csv"), row.names = FALSE)

# ---- per-call cost on captured inputs ----------------------------------------------------------
pulses <- round(seq(20L, ncol(a$projection$feature_values[[a$feature_ids[[1L]]]]), length.out = 10L))
measure <- function(fun) {
  invisible(gc()); tf <- tempfile(); utils::Rprofmem(tf, threshold = 0); fun(); utils::Rprofmem(NULL)
  lines <- readLines(tf); unlink(tf); big <- grep("^[0-9]+ :", lines, value = TRUE)
  invisible(gc()); t0 <- Sys.time(); fun(); secs <- as.numeric(Sys.time() - t0, units = "secs")
  c(bytes = sum(as.numeric(sub(" :.*$", "", big))), secs = secs)
}
sets <- arm_set()
calls <- do.call(rbind, lapply(arms, function(arm) {
  acc <- build(sets[[arm]])
  m <- fl_with(ns, sets[[arm]], measure(function() for (p in pulses) { acc$state$pulse_idx <- p; for (id in u) acc$features(id, concrete_map) }))
  n <- length(pulses) * length(u)
  data.frame(arm = arm, calls = n, bytes_per_call = round(m[["bytes"]] / n, 1), microseconds_per_call = round(1e6 * m[["secs"]] / n, 2),
    accessor_bytecode = bytecode(acc$features), lookup_bytecode = bytecode(sets[[arm]]$ledgr_feature_lookup_map %||% production_lookup))
}))
utils::write.csv(calls, file.path(out_dir, "explicit_map_calls.csv"), row.names = FALSE)

# ---- one unprofiled release-shape run per arm ----------------------------------------------------
invisible(gc.time(TRUE))
run_arm <- function(functions) {
  p <- tempfile(fileext = ".duckdb"); file.copy(path, p); snap <- ledgr_snapshot_open(p, "x")
  invisible(gc()); g0 <- gc.time()[[3L]]; t0 <- Sys.time()
  run <- fl_with(ns, functions, quiet(ledgr_run(ledgr_experiment(snap, explicit_strategy,
    features = concrete_map, opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero()), run_id = "x", seed = 1L)))
  out <- list(fills = ledgr_results(run, what = "fills"), equity = ledgr_results(run, what = "equity"))
  t1 <- Sys.time(); g1 <- gc.time()[[3L]]
  close(run); ledgr_snapshot_close(snap); unlink(p)
  list(out = out, wall = as.numeric(t1 - t0, units = "secs"), gc = g1 - g0)
}
sets <- arm_set()
run_arms <- list(production = NULL, prepared_only = prepared_fns, validate_once = sets$validate_once, memo = sets$memo)
results <- lapply(run_arms, run_arm)
runs <- do.call(rbind, lapply(names(results), function(arm) data.frame(arm = arm, elapsed_s = round(results[[arm]]$wall, 2),
  gc_s = round(results[[arm]]$gc, 2), fills = nrow(results[[arm]]$out$fills),
  identical_to_production = identical(results[[arm]]$out, results$production$out))))
utils::write.csv(runs, file.path(out_dir, "explicit_map_runs.csv"), row.names = FALSE)
unlink(path)
print(wide[c("step", "map", "identical_to_production")], row.names = FALSE)
print(calls, row.names = FALSE); print(runs, row.names = FALSE)
