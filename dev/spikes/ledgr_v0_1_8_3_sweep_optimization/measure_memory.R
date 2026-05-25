#!/usr/bin/env Rscript

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "dev/spikes/ledgr_v0_1_8_3_sweep_optimization/measure_memory.R"
source(file.path(dirname(normalizePath(script_path, mustWork = FALSE)), "common.R"))

feature_ids_for_candidate <- function(candidate) {
  vapply(candidate$feature_defs, function(def) def$id, character(1))
}

measure_view_memory <- function(def_name) {
  load_ledgr_source()
  def <- scenario_defs()[[def_name]]
  temp_dir <- tempfile("ledgr-v0-1-8-3-memory-")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  fixture <- make_experiment(
    n_instruments = def$n_instruments,
    n_days = def$n_days,
    temp_dir = temp_dir,
    feature_mode = def$feature_mode,
    metric_context = def$metric_context
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)

  grid <- make_grid(def$n_candidates)
  meta <- ledgr_precompute_snapshot_meta(fixture$exp$snapshot)
  range <- ledgr_precompute_scoring_range(meta)
  bars_by_id <- ledgr_precompute_fetch_bars(
    fixture$exp$snapshot,
    fixture$exp$universe,
    range$warmup_start,
    range$scoring_end
  )
  bars_by_id <- ledgr_sweep_normalize_bars_by_id(bars_by_id, fixture$exp$universe)
  bars_mat <- ledgr_sweep_bars_matrix(bars_by_id, fixture$exp$universe)
  pulses_posix <- as.POSIXct(bars_by_id[[fixture$exp$universe[[1L]]]]$ts_utc, tz = "UTC")
  bars_views <- ledgr_bars_pulse_views(bars_mat, fixture$exp$universe, pulses_posix)

  resolved <- ledgr_resolve_feature_candidates(fixture$exp, grid, stop_on_error = FALSE)
  projection <- ledgr_projection_from_payload(
    payload = ledgr_precompute_payload(
      ledgr_precompute_unique_feature_defs(resolved$candidates),
      bars_by_id
    ),
    universe = fixture$exp$universe,
    pulses_posix = pulses_posix,
    feature_engine_version = ledgr_feature_engine_version(),
    alias_index = NULL
  )

  candidate_rows <- lapply(seq_along(resolved$candidates), function(i) {
    feature_ids <- feature_ids_for_candidate(resolved$candidates[[i]])
    views <- ledgr_projection_pulse_views(projection, feature_ids)
    data.frame(
      candidate = i,
      n_candidate_features = length(feature_ids),
      feature_views_bytes = as.numeric(utils::object.size(views)),
      feature_table_bytes = as.numeric(utils::object.size(views$feature_table)),
      features_wide_bytes = as.numeric(utils::object.size(views$features_wide)),
      stringsAsFactors = FALSE
    )
  })
  candidate_sizes <- do.call(rbind, candidate_rows)

  data.frame(
    scenario = def$name,
    n_candidates = def$n_candidates,
    n_instruments = def$n_instruments,
    n_pulses = length(pulses_posix),
    n_projection_features = length(projection$feature_values),
    bars_by_id_bytes = as.numeric(utils::object.size(bars_by_id)),
    bars_mat_bytes = as.numeric(utils::object.size(bars_mat)),
    bars_views_bytes = as.numeric(utils::object.size(bars_views)),
    runtime_projection_bytes = as.numeric(utils::object.size(projection)),
    median_candidate_feature_views_bytes = stats::median(candidate_sizes$feature_views_bytes),
    max_candidate_feature_views_bytes = max(candidate_sizes$feature_views_bytes),
    sum_candidate_feature_views_bytes = sum(candidate_sizes$feature_views_bytes),
    median_candidate_feature_table_bytes = stats::median(candidate_sizes$feature_table_bytes),
    median_candidate_features_wide_bytes = stats::median(candidate_sizes$features_wide_bytes),
    retained_peak_proxy_bytes = as.numeric(utils::object.size(bars_by_id)) +
      as.numeric(utils::object.size(bars_mat)) +
      as.numeric(utils::object.size(bars_views)) +
      as.numeric(utils::object.size(projection)) +
      max(candidate_sizes$feature_views_bytes),
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- parse_cli()
  out_dir <- args[["out-dir"]] %||% file.path("inst", "design", "spikes", "ledgr_v0_1_8_3_sweep_optimization")
  data_dir <- file.path(out_dir, "data")
  scenarios <- strsplit(args[["scenarios"]] %||% "reference,wider,persistent", ",", fixed = TRUE)[[1]]
  scenarios <- trimws(scenarios)
  rows <- do.call(rbind, lapply(scenarios, measure_view_memory))
  write_csv(rows, file.path(data_dir, "post_change_memory.csv"))
  print(rows, row.names = FALSE)
  invisible(rows)
}

if (identical(environment(), globalenv())) {
  main()
}
