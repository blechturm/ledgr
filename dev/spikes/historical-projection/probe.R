# Rscript probe.R IMPLEMENTATION_REPO OUTPUT_DIR [gut]
# Sources production R functions and runs the production fold/output handler.
# Does not exercise sealed-snapshot ingestion or the public ledgr_run() entry.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L)
repo <- normalizePath(args[[1L]], mustWork = TRUE)
out <- args[[2L]]
gut <- length(args) > 2L && identical(args[[3L]], "gut")
env <- new.env(parent = globalenv())
env$`%||%` <- rlang::`%||%`
for (file in sort(list.files(file.path(repo, "R"), "[.]R$", full.names = TRUE))) {
  sys.source(file, envir = env)
}
if (gut) {
  # Detector demonstration only: closures still retain the projection.
  for (name in c("ledgr_update_fast_pulse_context_helpers",
                 "ledgr_update_pulse_context_helpers")) {
    original <- env[[name]]
    env[[name]] <- local({
      fn <- original
      function(...) { ctx <- fn(...); ctx$.feature_projection <- NULL; ctx }
    })
  }
}
rows <- list()
record <- function(mode, pulse, observation, value) {
  rows[[length(rows) + 1L]] <<- data.frame(mode, pulse, observation,
    value = paste(capture.output(dput(value)), collapse = " "))
}
with(env, {
  ids <- c("AAA", "BBB", "CCC")
  pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + (0:11) * 86400
  iso <- ledgr_projection_pulse_names(pulses)
  closes <- outer(c(100, 200, 300), 1:12, "+")
  dimnames(closes) <- list(ids, iso)
  bars <- stats::setNames(lapply(seq_along(ids), function(j) {
    data.frame(instrument_id = ids[[j]], ts_utc = pulses,
      open = closes[j, ], high = closes[j, ], low = closes[j, ],
      close = closes[j, ], volume = 100, gap_type = "NONE", is_synthetic = FALSE)
  }), ids)
  bars_mat <- ledgr_sweep_bars_matrix(bars, ids)
  def <- ledgr_feature_sma_n(3)
  # Preflight this pure strategy, not the audit observer below.
  leaking_strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[] <- ctx$.feature_projection$feature_values[["sma_3"]][, 12L]
    target
  }
  strategy <- function(ctx, params) {
    projection <- ctx$.feature_projection
    future <- tryCatch(projection$feature_values[["sma_3"]][, 12L],
      error = function(e) paste("ERROR", class(e)[[1L]]))
    list(targets = ctx$hold(), observed = list(
      shape = dim(projection$feature_values[["sma_3"]]),
      pulse_count = length(projection$pulse_index),
      current = ctx$vec$feature("sma_3"), future = future))
  }
  preflight <- ledgr_strategy_preflight(leaking_strategy)
  record("both", 0L, "preflight", list(tier = preflight$tier, allowed = preflight$allowed))
  for (mode in c("dense", "availability")) {
    active <- identical(mode, "availability")
    compute <- if (active) ledgr_compute_feature_series_strict else ledgr_compute_feature_series
    values <- t(vapply(bars, compute, numeric(length(pulses)), feature_def = def))
    projection <- ledgr_projection_from_feature_matrix(list(sma_3 = values), ids,
      pulses, feature_engine_version = ledgr_feature_engine_version(active))
    provider <- NULL
    if (active) {
      data <- list(families = data.frame(family = "sessions"),
        membership = data.frame(), status = data.frame(), lifetime = data.frame(),
        sessions = data.frame(session_date = as.Date(pulses), is_open = TRUE,
          close_ts_utc = pulses, open_ts_utc = pulses - 7 * 3600))
      config <- list(universe = list(instrument_ids = ids), availability = list(
        valuation_policy = list(max_sessions = 0L), execution_timing_version = 2L))
      provider <- ledgr_availability_provider_portable(data, config,
        snapshot_hash = "proto:synthetic-normalized-input", bars_by_id = bars)
    }
    counter <- 0L
    observer <- function(ctx, params) {
      counter <<- counter + 1L
      result <- strategy(ctx, params)
      if (counter %in% c(1L, 12L)) {
        fields <- if (counter == 1L) names(result$observed) else "current"
        for (name in fields) {
          record(mode, counter, name, result$observed[[name]])
        }
      }
      result$observed <- NULL
      result
    }
    execution <- ledgr_execution_spec(
      run_id = paste0("projection-probe-", mode), instrument_ids = ids,
      strategy_fn = observer, strategy_params = list(),
      strategy_call_signature = ledgr_strategy_signature(strategy),
      strategy_is_functional = TRUE, pulses_posix = pulses, pulses_iso = iso,
      start_idx = 1L, max_pulses = Inf, checkpoint_every = 0L, telemetry_stride = 0L,
      state = list(cash = 1000, positions = stats::setNames(rep(0, 3), ids)),
      bars_by_id = bars, bars_mat = bars_mat, feature_defs = list(def),
      runtime_projection = projection,
      cost_resolver = ledgr_cost_resolver_from_model(ledgr_cost_zero()),
      event_seq_start = 1L, telemetry = ledgr_sweep_telemetry_env(),
      event_mode = "buffered", use_fast_context = !active,
      availability_provider = provider,
      execution_opportunities_posix = if (active) pulses[-1L] - 7 * 3600 else NULL)
    result <- ledgr_execute_fold(execution, ledgr_memory_output_handler(execution$run_id))
    record(mode, 0L, "fold_status", result$status)
    record(mode, 0L, "callbacks", counter)
    absent <- execution
    absent$runtime_projection <- NULL
    record(mode, 0L, "null_projection", tryCatch({
      ledgr_execute_fold(absent, ledgr_memory_output_handler(execution$run_id))
      "ACCEPTED"
    }, error = function(e) class(e)[[1L]]))
  }
})
dir.create(out, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, rows), file.path(out, "observations.csv"), row.names = FALSE)
cat(R.version.string, "\n")
