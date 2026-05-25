#!/usr/bin/env Rscript

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg)) {
  sub("^--file=", "", file_arg[[1]])
} else {
  "dev/spikes/ledgr_v0_1_8_3_pulse_view_construction/run_pulse_view_construction_spike.R"
}
script_dir <- dirname(normalizePath(script_path, mustWork = FALSE))
source(file.path(script_dir, "..", "ledgr_v0_1_8_3_sweep_optimization", "common.R"))

arg_value <- function(key, default = NULL) {
  args <- parse_cli()
  args[[key]] %||% default
}

drop_index_cols <- function(x) {
  x$time_index <- NULL
  x$feature_rank <- NULL
  x$instrument_rank <- NULL
  rownames(x) <- NULL
  x
}

base_bars_views <- function(bars_mat, instrument_ids, pulses_posix) {
  n_pulses <- length(pulses_posix)
  if (n_pulses == 0L) {
    return(vector("list", 0L))
  }
  instrument_ids <- as.character(instrument_ids)
  n_inst <- length(instrument_ids)
  all_bars <- data.frame(
    time_index = rep(seq_len(n_pulses), each = n_inst),
    instrument_id = rep(instrument_ids, times = n_pulses),
    ts_utc = as.POSIXct(rep(pulses_posix, each = n_inst), tz = "UTC"),
    open = as.vector(bars_mat$open),
    high = as.vector(bars_mat$high),
    low = as.vector(bars_mat$low),
    close = as.vector(bars_mat$close),
    volume = as.vector(bars_mat$volume),
    gap_type = as.vector(bars_mat$gap_type),
    is_synthetic = as.vector(bars_mat$is_synthetic),
    stringsAsFactors = FALSE
  )
  out <- split(all_bars, all_bars$time_index, drop = TRUE)
  out <- lapply(out, drop_index_cols)
  names(out) <- NULL
  out
}

base_feature_views <- function(projection, feature_ids = NULL) {
  feature_ids <- ledgr:::ledgr_projection_feature_ids(projection, feature_ids)
  n_pulses <- length(projection$pulses_posix)
  feature_table <- vector("list", n_pulses)
  features_wide <- vector("list", n_pulses)
  if (length(feature_ids) == 0L || n_pulses == 0L) {
    return(list(feature_table = feature_table, features_wide = features_wide))
  }

  instruments <- names(projection$instrument_index)
  n_inst <- length(instruments)
  n_def <- length(feature_ids)
  feature_blocks <- lapply(feature_ids, function(feature_id) {
    as.vector(projection$feature_values[[feature_id]])
  })
  long <- data.frame(
    time_index = rep(seq_len(n_pulses), times = n_def, each = n_inst),
    feature_rank = rep(seq_along(feature_ids), each = n_inst * n_pulses),
    instrument_rank = rep(seq_len(n_inst), times = n_pulses * n_def),
    instrument_id = rep(instruments, times = n_pulses * n_def),
    ts_utc = as.POSIXct(rep(projection$pulses_posix, times = n_def, each = n_inst), tz = "UTC"),
    feature_name = rep(feature_ids, each = n_inst * n_pulses),
    feature_value = unlist(feature_blocks, use.names = FALSE),
    stringsAsFactors = FALSE
  )
  long <- long[order(long$time_index, long$feature_rank, long$instrument_rank), , drop = FALSE]
  feature_table <- split(long, long$time_index, drop = TRUE)
  feature_table <- lapply(feature_table, drop_index_cols)
  names(feature_table) <- NULL

  wide <- data.frame(
    time_index = rep(seq_len(n_pulses), each = n_inst),
    instrument_id = rep(instruments, times = n_pulses),
    ts_utc = rep(projection$pulses_iso, each = n_inst),
    stringsAsFactors = FALSE
  )
  for (feature_id in feature_ids) {
    wide[[feature_id]] <- as.vector(projection$feature_values[[feature_id]])
  }
  features_wide <- split(wide, wide$time_index, drop = TRUE)
  features_wide <- lapply(features_wide, drop_index_cols)
  names(features_wide) <- NULL

  list(feature_table = feature_table, features_wide = features_wide)
}

data_table_feature_views <- function(projection, feature_ids = NULL, as_df = TRUE) {
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("data.table is not installed.", call. = FALSE)
  }
  feature_ids <- ledgr:::ledgr_projection_feature_ids(projection, feature_ids)
  n_pulses <- length(projection$pulses_posix)
  empty <- vector("list", n_pulses)
  if (length(feature_ids) == 0L || n_pulses == 0L) {
    return(list(feature_table = empty, features_wide = empty))
  }
  instruments <- names(projection$instrument_index)
  n_inst <- length(instruments)
  n_def <- length(feature_ids)
  dt <- data.table::data.table(
    time_index = rep(seq_len(n_pulses), times = n_def, each = n_inst),
    feature_rank = rep(seq_along(feature_ids), each = n_inst * n_pulses),
    instrument_rank = rep(seq_len(n_inst), times = n_pulses * n_def),
    instrument_id = rep(instruments, times = n_pulses * n_def),
    ts_utc = as.POSIXct(rep(projection$pulses_posix, times = n_def, each = n_inst), tz = "UTC"),
    feature_name = rep(feature_ids, each = n_inst * n_pulses),
    feature_value = unlist(lapply(feature_ids, function(feature_id) {
      as.vector(projection$feature_values[[feature_id]])
    }), use.names = FALSE)
  )
  data.table::setorder(dt, time_index, feature_rank, instrument_rank)
  feature_table <- split(dt, by = "time_index", keep.by = FALSE)
  feature_table <- lapply(feature_table, function(x) {
    x[, c("feature_rank", "instrument_rank") := NULL]
    if (isTRUE(as_df)) as.data.frame(x) else x
  })
  names(feature_table) <- NULL

  wide <- data.table::data.table(
    time_index = rep(seq_len(n_pulses), each = n_inst),
    instrument_id = rep(instruments, times = n_pulses),
    ts_utc = rep(projection$pulses_iso, each = n_inst)
  )
  for (feature_id in feature_ids) {
    wide[, (feature_id) := as.vector(projection$feature_values[[feature_id]])]
  }
  features_wide <- split(wide, by = "time_index", keep.by = FALSE)
  if (isTRUE(as_df)) {
    features_wide <- lapply(features_wide, as.data.frame)
  }
  names(features_wide) <- NULL

  list(feature_table = feature_table, features_wide = features_wide)
}

collapse_feature_views <- function(projection, feature_ids = NULL) {
  if (!requireNamespace("collapse", quietly = TRUE)) {
    stop("collapse is not installed.", call. = FALSE)
  }
  feature_ids <- ledgr:::ledgr_projection_feature_ids(projection, feature_ids)
  n_pulses <- length(projection$pulses_posix)
  feature_table <- vector("list", n_pulses)
  features_wide <- vector("list", n_pulses)
  if (length(feature_ids) == 0L || n_pulses == 0L) {
    return(list(feature_table = feature_table, features_wide = features_wide))
  }

  instruments <- names(projection$instrument_index)
  n_inst <- length(instruments)
  n_def <- length(feature_ids)
  long <- data.frame(
    time_index = rep(seq_len(n_pulses), times = n_def, each = n_inst),
    feature_rank = rep(seq_along(feature_ids), each = n_inst * n_pulses),
    instrument_rank = rep(seq_len(n_inst), times = n_pulses * n_def),
    instrument_id = rep(instruments, times = n_pulses * n_def),
    ts_utc = as.POSIXct(rep(projection$pulses_posix, times = n_def, each = n_inst), tz = "UTC"),
    feature_name = rep(feature_ids, each = n_inst * n_pulses),
    feature_value = unlist(lapply(feature_ids, function(feature_id) {
      as.vector(projection$feature_values[[feature_id]])
    }), use.names = FALSE),
    stringsAsFactors = FALSE
  )
  long <- long[order(long$time_index, long$feature_rank, long$instrument_rank), , drop = FALSE]
  feature_table <- collapse::rsplit(long, long$time_index)
  feature_table <- lapply(feature_table, drop_index_cols)
  names(feature_table) <- NULL

  wide <- data.frame(
    time_index = rep(seq_len(n_pulses), each = n_inst),
    instrument_id = rep(instruments, times = n_pulses),
    ts_utc = rep(projection$pulses_iso, each = n_inst),
    stringsAsFactors = FALSE
  )
  for (feature_id in feature_ids) {
    wide[[feature_id]] <- as.vector(projection$feature_values[[feature_id]])
  }
  features_wide <- collapse::rsplit(wide, wide$time_index)
  features_wide <- lapply(features_wide, drop_index_cols)
  names(features_wide) <- NULL

  list(feature_table = feature_table, features_wide = features_wide)
}

tidyr_feature_views <- function(projection, feature_ids = NULL) {
  if (!requireNamespace("tibble", quietly = TRUE) ||
      !requireNamespace("dplyr", quietly = TRUE) ||
      !requireNamespace("tidyr", quietly = TRUE)) {
    stop("tibble, dplyr, and tidyr are required.", call. = FALSE)
  }
  feature_ids <- ledgr:::ledgr_projection_feature_ids(projection, feature_ids)
  n_pulses <- length(projection$pulses_posix)
  empty <- vector("list", n_pulses)
  if (length(feature_ids) == 0L || n_pulses == 0L) {
    return(list(feature_table = empty, features_wide = empty))
  }
  instruments <- names(projection$instrument_index)
  n_inst <- length(instruments)
  n_def <- length(feature_ids)
  long <- tibble::tibble(
    time_index = rep(seq_len(n_pulses), times = n_def, each = n_inst),
    feature_rank = rep(seq_along(feature_ids), each = n_inst * n_pulses),
    instrument_rank = rep(seq_len(n_inst), times = n_pulses * n_def),
    instrument_id = rep(instruments, times = n_pulses * n_def),
    ts_utc = as.POSIXct(rep(projection$pulses_posix, times = n_def, each = n_inst), tz = "UTC"),
    feature_name = rep(feature_ids, each = n_inst * n_pulses),
    feature_value = unlist(lapply(feature_ids, function(feature_id) {
      as.vector(projection$feature_values[[feature_id]])
    }), use.names = FALSE)
  )
  long <- dplyr::arrange(long, .data$time_index, .data$feature_rank, .data$instrument_rank)
  feature_table <- tidyr::nest(long, data = -"time_index")$data
  feature_table <- lapply(feature_table, function(x) {
    x$feature_rank <- NULL
    x$instrument_rank <- NULL
    as.data.frame(x)
  })

  wide <- tibble::tibble(
    time_index = rep(seq_len(n_pulses), each = n_inst),
    instrument_id = rep(instruments, times = n_pulses),
    ts_utc = rep(projection$pulses_iso, each = n_inst)
  )
  for (feature_id in feature_ids) {
    wide[[feature_id]] <- as.vector(projection$feature_values[[feature_id]])
  }
  features_wide <- tidyr::nest(wide, data = -"time_index")$data
  features_wide <- lapply(features_wide, as.data.frame)

  list(feature_table = feature_table, features_wide = features_wide)
}

bench <- function(label, reps, expr) {
  times <- numeric(reps)
  sizes <- numeric(reps)
  ok <- TRUE
  error <- NA_character_
  for (i in seq_len(reps)) {
    gc()
    value <- NULL
    elapsed <- tryCatch(
      system.time(value <- expr())[["elapsed"]],
      error = function(e) {
        ok <<- FALSE
        error <<- conditionMessage(e)
        NA_real_
      }
    )
    times[[i]] <- elapsed
    sizes[[i]] <- if (ok) as.numeric(object.size(value)) else NA_real_
    if (!ok) break
  }
  data.frame(
    label = label,
    ok = ok,
    reps = if (ok) reps else which(is.na(times))[1] %||% 0L,
    median_sec = if (ok) stats::median(times) else NA_real_,
    mean_sec = if (ok) mean(times) else NA_real_,
    min_sec = if (ok) min(times) else NA_real_,
    max_sec = if (ok) max(times) else NA_real_,
    object_mb = if (ok) stats::median(sizes) / 1024^2 else NA_real_,
    error = error,
    stringsAsFactors = FALSE
  )
}

main <- function() {
  load_ledgr_source()
  reps <- as.integer(arg_value("reps", "5"))
  out_dir <- arg_value(
    "out-dir",
    file.path("inst", "design", "spikes", "ledgr_v0_1_8_3_pulse_view_construction")
  )
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  temp_dir <- tempfile("ledgr-pulse-view-construction-")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  def <- scenario_defs()$reference
  fixture <- make_experiment(
    n_instruments = def$n_instruments,
    n_days = def$n_days,
    temp_dir = temp_dir,
    feature_mode = def$feature_mode,
    metric_context = def$metric_context
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)

  grid <- make_grid(def$n_candidates)
  resolved <- ledgr:::ledgr_resolve_feature_candidates(fixture$exp, grid, stop_on_error = FALSE)
  meta <- ledgr:::ledgr_precompute_snapshot_meta(fixture$exp$snapshot)
  range <- ledgr:::ledgr_precompute_scoring_range(meta)
  bars_by_id <- ledgr:::ledgr_precompute_fetch_bars(
    fixture$exp$snapshot,
    fixture$exp$universe,
    range$warmup_start,
    range$scoring_end
  )
  bars_by_id <- ledgr:::ledgr_sweep_normalize_bars_by_id(bars_by_id, fixture$exp$universe)
  bars_mat <- ledgr:::ledgr_sweep_bars_matrix(bars_by_id, fixture$exp$universe)
  pulses <- as.POSIXct(bars_by_id[[fixture$exp$universe[[1L]]]]$ts_utc, tz = "UTC")
  payload <- ledgr:::ledgr_precompute_payload(
    ledgr:::ledgr_precompute_unique_feature_defs(resolved$candidates),
    bars_by_id
  )
  projection <- ledgr:::ledgr_projection_from_payload(payload, fixture$exp$universe, pulses)
  candidate_feature_ids <- vapply(resolved$candidates, function(candidate) {
    candidate$feature_defs[[1]]$id
  }, character(1))
  unique_feature_ids <- unique(candidate_feature_ids)

  current_union <- ledgr:::ledgr_projection_pulse_views(projection, unique_feature_ids)
  base_union <- base_feature_views(projection, unique_feature_ids)
  data_table_union <- tryCatch(data_table_feature_views(projection, unique_feature_ids, as_df = TRUE), error = identity)
  collapse_union <- tryCatch(collapse_feature_views(projection, unique_feature_ids), error = identity)
  tidyr_union <- tryCatch(tidyr_feature_views(projection, unique_feature_ids), error = identity)
  equality_row <- function(label, object, field) {
    reference <- current_union[[field]]
    value <- if (inherits(object, "error")) object else object[[field]]
    data.frame(
      comparison = paste(label, field, sep = "_"),
      equal = if (inherits(value, "error")) FALSE else isTRUE(all.equal(reference, value, check.attributes = TRUE)),
      error = if (inherits(value, "error")) conditionMessage(value) else NA_character_,
      stringsAsFactors = FALSE
    )
  }
  equality <- do.call(rbind, list(
    equality_row("base", base_union, "feature_table"),
    equality_row("base", base_union, "features_wide"),
    equality_row("data_table_df", data_table_union, "feature_table"),
    equality_row("data_table_df", data_table_union, "features_wide"),
    equality_row("collapse", collapse_union, "feature_table"),
    equality_row("collapse", collapse_union, "features_wide"),
    equality_row("tidyr", tidyr_union, "feature_table"),
    equality_row("tidyr", tidyr_union, "features_wide")
  ))

  candidates <- list(
    current_bars_once = function() ledgr:::ledgr_bars_pulse_views(bars_mat, fixture$exp$universe, pulses),
    base_split_bars_once = function() base_bars_views(bars_mat, fixture$exp$universe, pulses),
    current_features_50_candidate = function() lapply(candidate_feature_ids, function(fid) {
      ledgr:::ledgr_projection_pulse_views(projection, fid)
    }),
    base_split_features_50_candidate = function() lapply(candidate_feature_ids, function(fid) {
      base_feature_views(projection, fid)
    }),
    data_table_df_features_50_candidate = function() lapply(candidate_feature_ids, function(fid) {
      data_table_feature_views(projection, fid, as_df = TRUE)
    }),
    data_table_native_features_50_candidate = function() lapply(candidate_feature_ids, function(fid) {
      data_table_feature_views(projection, fid, as_df = FALSE)
    }),
    collapse_features_50_candidate = function() lapply(candidate_feature_ids, function(fid) {
      collapse_feature_views(projection, fid)
    }),
    tidyr_features_50_candidate = function() lapply(candidate_feature_ids, function(fid) {
      tidyr_feature_views(projection, fid)
    }),
    current_features_union_once = function() ledgr:::ledgr_projection_pulse_views(projection, unique_feature_ids),
    base_split_features_union_once = function() base_feature_views(projection, unique_feature_ids),
    data_table_df_features_union_once = function() data_table_feature_views(projection, unique_feature_ids, as_df = TRUE),
    data_table_native_features_union_once = function() data_table_feature_views(projection, unique_feature_ids, as_df = FALSE),
    collapse_features_union_once = function() collapse_feature_views(projection, unique_feature_ids),
    tidyr_features_union_once = function() tidyr_feature_views(projection, unique_feature_ids)
  )

  results <- do.call(rbind, lapply(names(candidates), function(label) {
    bench(label, reps, candidates[[label]])
  }))
  rownames(results) <- NULL

  write.csv(results, file.path(out_dir, "pulse_view_construction_results.csv"), row.names = FALSE)
  write.csv(equality, file.path(out_dir, "pulse_view_construction_equality.csv"), row.names = FALSE)

  report <- c(
    "# Pulse View Construction Spike",
    "",
    sprintf("Reps: %d", reps),
    "",
    "Fixture: v0.1.8.3 reference workload shape, 50 candidates, 4 instruments, 252 pulses, single feature mode.",
    "",
    "## Package Availability",
    "",
    paste0("- data.table: ", requireNamespace("data.table", quietly = TRUE)),
    paste0("- collapse: ", requireNamespace("collapse", quietly = TRUE)),
    paste0("- dplyr: ", requireNamespace("dplyr", quietly = TRUE)),
    paste0("- tidyr: ", requireNamespace("tidyr", quietly = TRUE)),
    paste0("- tibble: ", requireNamespace("tibble", quietly = TRUE)),
    "",
    "## Equality Checks",
    "",
    markdown_table(equality),
    "",
    "## Timings",
    "",
    markdown_table(results),
    "",
    "## Interpretation",
    "",
    "The current helper path constructs many small data.frames. The split/nest candidates build one indexed table and split by pulse index.",
    "A production dependency decision should compare base split against package-backed variants after preserving the public data-frame schema."
  )
  writeLines(report, file.path(out_dir, "pulse_view_construction_report.md"))
  print(results)
  invisible(results)
}

if (identical(environment(), globalenv())) {
  main()
}
