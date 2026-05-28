# run_width_sweep.R
#
# Two-mode instrument x feature width sweep for v0.1.8.6 LDG-2449/2450.
#
# This is the post-5.0/post-5.1 load measurement used to separate feature
# access scaling from fill/event/replay scaling and to record the storage/schema
# decision. It reuses the structured benchmark harness in run_benchmarks.R.
#
# Usage:
#   Rscript dev/bench/run_width_sweep.R --preset smoke --repeats 1 --warmup 1
#   Rscript dev/bench/run_width_sweep.R --preset record --repeats 3 --warmup 1

source(file.path("dev", "bench", "run_benchmarks.R"))

width_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- bench_parse_args(args)
  out
}

width_grid <- function(preset = "smoke") {
  if (identical(preset, "record")) {
    return(expand.grid(
      n_inst = c(100L, 250L, 500L),
      n_feat = c(10L, 25L, 50L),
      stringsAsFactors = FALSE
    ))
  }
  expand.grid(
    n_inst = c(20L, 50L),
    n_feat = c(5L, 10L),
    stringsAsFactors = FALSE
  )
}

width_pulses <- function(preset = "smoke") {
  if (identical(preset, "record")) 252L else 60L
}

width_projection <- function(n_inst, n_pulses, n_feat) {
  universe <- sprintf("WIDTH_%04d", seq_len(n_inst))
  pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (seq_len(n_pulses) - 1L)
  feature_values <- lapply(seq_len(n_feat), function(i) {
    matrix(
      as.numeric(i) + seq_len(n_inst * n_pulses) * 1e-8,
      nrow = n_inst,
      ncol = n_pulses,
      dimnames = list(universe, NULL)
    )
  })
  names(feature_values) <- sprintf("bench_f_%03d", seq_len(n_feat))
  ledgr:::ledgr_runtime_projection(
    feature_values = feature_values,
    universe = universe,
    pulses_posix = pulses
  )
}

width_time_projection_views <- function(n_inst, n_pulses, n_feat, repeats = 1L) {
  projection <- width_projection(n_inst, n_pulses, n_feat)
  feature_ids <- sprintf("bench_f_%03d", seq_len(n_feat))
  schema_times <- numeric(repeats)
  full_times <- numeric(repeats)
  schema <- NULL
  full <- NULL
  for (i in seq_len(repeats)) {
    gc(reset = TRUE, full = TRUE)
    schema_times[[i]] <- system.time(
      schema <- ledgr:::ledgr_projection_pulse_views(
        projection,
        feature_ids,
        feature_table = "schema"
      )
    )[["elapsed"]]
    gc(reset = TRUE, full = TRUE)
    full_times[[i]] <- system.time(
      full <- ledgr:::ledgr_projection_pulse_views(
        projection,
        feature_ids,
        feature_table = "full"
      )
    )[["elapsed"]]
  }
  data.frame(
    n_inst = n_inst,
    n_pulses = n_pulses,
    n_feat = n_feat,
    view_iterations = repeats,
    schema_view_sec = stats::median(schema_times),
    full_long_view_sec = stats::median(full_times),
    first_schema_rows = nrow(schema$feature_table[[1L]]),
    first_full_rows = nrow(full$feature_table[[1L]]),
    full_long_rows_total = n_inst * n_pulses * n_feat,
    stringsAsFactors = FALSE
  )
}

width_run_suite <- function(args) {
  bench_load_ledgr_source()
  set.seed(args$seed)
  grid <- width_grid(args$preset)
  n_pulses <- width_pulses(args$preset)
  view_repeats <- if (identical(args$preset, "record")) 3L else 1L
  rows <- list()
  view_rows <- list()
  k <- 0L
  vk <- 0L
  for (i in seq_len(nrow(grid))) {
    n_inst <- as.integer(grid$n_inst[[i]])
    n_feat <- as.integer(grid$n_feat[[i]])
    vk <- vk + 1L
    message(sprintf("[width] isolated views n_inst=%d n_feat=%d pulses=%d", n_inst, n_feat, n_pulses))
    view_rows[[vk]] <- width_time_projection_views(n_inst, n_pulses, n_feat, repeats = view_repeats)
    for (mode in c("read_score", "turnover")) {
      spec <- list(
        kind = "run",
        n_inst = n_inst,
        n_pulses = n_pulses,
        n_feat = n_feat,
        trade = identical(mode, "turnover"),
        replay = identical(mode, "turnover")
      )
      total <- args$warmup + args$repeats
      for (iter in seq_len(total)) {
        is_warmup <- iter <= args$warmup
        scenario <- paste0("width_", mode)
        message(sprintf(
          "[width] %s n_inst=%d n_feat=%d iter=%d warmup=%s",
          scenario,
          n_inst,
          n_feat,
          iter,
          is_warmup
        ))
        k <- k + 1L
        row <- bench_run_scenario_once(
          scenario,
          spec,
          iter = iter + i * 100L,
          seed = args$seed,
          is_warmup = is_warmup
        )
        row$width_mode <- mode
        row$width_grid_id <- sprintf("inst_%d_feat_%d", n_inst, n_feat)
        rows[[k]] <- row
      }
    }
  }
  raw <- do.call(rbind, rows)
  measured <- raw[!raw$is_warmup, , drop = FALSE]
  summary <- width_summarize(measured)
  views <- do.call(rbind, view_rows)
  decision <- width_storage_decision(summary, views, args$preset)
  env <- bench_environment(args)
  width_write_outputs(raw, summary, views, decision, env, args)
  invisible(list(raw = raw, summary = summary, views = views, decision = decision, environment = env))
}

width_summarize <- function(measured) {
  split_rows <- split(measured, paste(measured$width_grid_id, measured$width_mode, sep = "::"))
  out <- lapply(split_rows, function(df) {
    first <- df[1L, , drop = FALSE]
    data.frame(
      width_grid_id = first$width_grid_id,
      width_mode = first$width_mode,
      n_inst = first$n_inst,
      n_pulses = first$n_pulses,
      n_feat = first$n_feat,
      measured_iterations = nrow(df),
      median_t_wall_sec = bench_median(df$t_wall_sec),
      median_t_pre_sec = bench_median(df$t_pre_sec),
      median_t_residual_sec = bench_median(df$t_residual_sec),
      median_t_loop_sec = bench_median(df$t_loop_sec),
      median_replay_sec = bench_median(df$replay_sec),
      median_security_bars_sec = bench_median(df$security_bars_sec),
      median_feature_cells_sec = bench_median(df$feature_cells_sec),
      median_events_sec = bench_median(df$events_sec),
      warnings = sum(df$warnings, na.rm = TRUE),
      failures = sum(df$failures, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out[order(out$n_inst, out$n_feat, out$width_mode), , drop = FALSE]
}

width_storage_decision <- function(summary, views, preset) {
  max_failures <- sum(summary$failures, na.rm = TRUE)
  max_warnings <- sum(summary$warnings, na.rm = TRUE)
  max_full_rows <- max(views$full_long_rows_total, na.rm = TRUE)
  max_full_sec <- max(views$full_long_view_sec, na.rm = TRUE)
  max_schema_sec <- max(views$schema_view_sec, na.rm = TRUE)
  decision <- "deferred"
  view_ratio <- if (is.finite(max_schema_sec) && max_schema_sec > 0) {
    max_full_sec / max_schema_sec
  } else {
    NA_real_
  }
  rationale <- paste(
    "v0.1.8.6 records the post-5.0/5.1 width sweep and keeps DuckDB-backed",
    "feature storage and typed persistent event columns deferred unless a",
    "maintainer accepts a separate storage/schema implementation gate.",
    sprintf(
      "The largest isolated full-long view built %.1fM rows; schema-only view timing was %.2fs versus %.2fs full-long%s.",
      max_full_rows / 1e6,
      max_schema_sec,
      max_full_sec,
      if (is.finite(view_ratio)) sprintf(" (~%.1fx)", view_ratio) else ""
    )
  )
  if (max_failures > 0L) {
    decision <- "deferred"
    rationale <- paste(
      "Width sweep completed with scenario failures; storage/schema work is not",
      "accepted until benchmark failures are understood."
    )
  }
  data.frame(
    preset = preset,
    decision = decision,
    typed_persistent_event_columns = "deferred",
    duckdb_feature_storage = decision,
    max_full_long_rows_total = max_full_rows,
    max_schema_view_sec = max_schema_sec,
    max_full_long_view_sec = max_full_sec,
    warning_count = max_warnings,
    failure_count = max_failures,
    rationale = rationale,
    stringsAsFactors = FALSE
  )
}

width_write_outputs <- function(raw, summary, views, decision, env, args) {
  dir.create(args$out_dir, recursive = TRUE, showWarnings = FALSE)
  stamp <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
  stem <- file.path(args$out_dir, paste0("ledgr_width_sweep_", args$preset, "_", stamp))
  raw_path <- paste0(stem, "_raw.csv")
  summary_path <- paste0(stem, "_summary.csv")
  views_path <- paste0(stem, "_isolated_views.csv")
  decision_path <- paste0(stem, "_storage_decision.csv")
  env_path <- paste0(stem, "_environment.json")
  json_path <- paste0(stem, "_results.json")
  md_path <- paste0(stem, "_summary.md")

  utils::write.csv(raw, raw_path, row.names = FALSE)
  utils::write.csv(summary, summary_path, row.names = FALSE)
  utils::write.csv(views, views_path, row.names = FALSE)
  utils::write.csv(decision, decision_path, row.names = FALSE)
  jsonlite::write_json(env, env_path, auto_unbox = TRUE, pretty = TRUE, na = "null")
  jsonlite::write_json(
    list(environment = env, raw = raw, summary = summary, isolated_views = views, decision = decision),
    json_path,
    dataframe = "rows",
    pretty = TRUE,
    na = "null"
  )
  width_write_markdown(summary, views, decision, env, md_path)
  message("[width] wrote:")
  message("  ", raw_path)
  message("  ", summary_path)
  message("  ", views_path)
  message("  ", decision_path)
  message("  ", env_path)
  message("  ", json_path)
  message("  ", md_path)
}

width_write_markdown <- function(summary, views, decision, env, path) {
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(c(
    "# ledgr Width Sweep Summary",
    "",
    sprintf("- Created: `%s`", env$created_at),
    sprintf("- Preset: `%s`", env$preset),
    sprintf("- Git: `%s` on `%s`", env$git_sha, env$git_branch),
    "",
    "The read/score mode isolates feature access and scoring without fills.",
    "The turnover mode includes fills/events and persistent replay timing.",
    "",
    "| Grid | Mode | Wall s | Bars/sec | Feature cells/sec | Loop s | Replay s |",
    "| --- | --- | ---: | ---: | ---: | ---: | ---: |"
  ), con)
  for (i in seq_len(nrow(summary))) {
    writeLines(sprintf(
      "| `%s` | `%s` | %.4f | %.1f | %.1f | %.4f | %.4f |",
      summary$width_grid_id[[i]],
      summary$width_mode[[i]],
      summary$median_t_wall_sec[[i]],
      summary$median_security_bars_sec[[i]],
      summary$median_feature_cells_sec[[i]],
      summary$median_t_loop_sec[[i]],
      summary$median_replay_sec[[i]]
    ), con)
  }
  writeLines(c(
    "",
    "## Isolated View Build",
    "",
    "| Instruments | Features | Pulses | Schema s | Full long s | Full rows |",
    "| ---: | ---: | ---: | ---: | ---: | ---: |"
  ), con)
  for (i in seq_len(nrow(views))) {
    writeLines(sprintf(
      "| %d | %d | %d | %.4f | %.4f | %.0f |",
      views$n_inst[[i]],
      views$n_feat[[i]],
      views$n_pulses[[i]],
      views$schema_view_sec[[i]],
      views$full_long_view_sec[[i]],
      views$full_long_rows_total[[i]]
    ), con)
  }
  writeLines(c(
    "",
    "## Storage Decision",
    "",
    sprintf("- Decision: `%s`", decision$decision[[1L]]),
    sprintf("- Typed persistent event columns: `%s`", decision$typed_persistent_event_columns[[1L]]),
    sprintf("- Rationale: %s", decision$rationale[[1L]])
  ), con)
}

if (sys.nframe() == 0L) {
  args <- width_parse_args()
  width_run_suite(args)
}
