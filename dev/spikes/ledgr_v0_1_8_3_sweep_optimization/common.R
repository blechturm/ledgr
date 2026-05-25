#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x)) y else x

resolve_repo_root <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else ""
  script_dir <- if (nzchar(script_path)) dirname(normalizePath(script_path, mustWork = TRUE)) else getwd()
  root_candidate <- normalizePath(file.path(script_dir, "..", "..", ".."), mustWork = FALSE)
  if (file.exists(file.path(root_candidate, "DESCRIPTION"))) {
    return(root_candidate)
  }
  normalizePath(getwd(), mustWork = TRUE)
}

parse_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list()
  for (arg in args) {
    if (grepl("^--[^=]+=.*", arg)) {
      key <- sub("^--([^=]+)=.*$", "\\1", arg)
      value <- sub("^--[^=]+=", "", arg)
      out[[key]] <- value
    } else if (grepl("^--", arg)) {
      out[[sub("^--", "", arg)]] <- TRUE
    }
  }
  out
}

repo_root <- resolve_repo_root()
setwd(repo_root)

load_ledgr_source <- function() {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required to run this benchmark from source.", call. = FALSE)
  }
  pkgload::load_all(".", quiet = TRUE)
}

git_values <- function(...) {
  old_home <- Sys.getenv("HOME", unset = NA_character_)
  userprofile <- Sys.getenv("USERPROFILE", unset = NA_character_)
  if (!is.na(userprofile) && nzchar(userprofile)) {
    Sys.setenv(HOME = userprofile)
    on.exit({
      if (is.na(old_home)) Sys.unsetenv("HOME") else Sys.setenv(HOME = old_home)
    }, add = TRUE)
  }
  value <- tryCatch(
    system2("git", c(...), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  )
  if (!length(value)) NA_character_ else value
}

git_value <- function(...) {
  value <- git_values(...)
  if (!length(value) || all(is.na(value))) NA_character_ else value[[1]]
}

environment_info <- function(label) {
  data.frame(
    label = label,
    timestamp_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    git_head = git_value("rev-parse", "HEAD"),
    git_head_short = git_value("rev-parse", "--short", "HEAD"),
    git_status_short = paste(git_values("status", "--short"), collapse = " | "),
    git_v0_1_8_2_tag = git_value("rev-parse", "refs/tags/v0.1.8.2"),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    platform = R.version$platform,
    os = Sys.info()[["sysname"]],
    os_release = Sys.info()[["release"]],
    machine = Sys.info()[["machine"]],
    logical_cores = parallel::detectCores(logical = TRUE),
    physical_cores = parallel::detectCores(logical = FALSE),
    stringsAsFactors = FALSE
  )
}

package_versions <- function() {
  pkgs <- c("ledgr", "pkgload", "testthat", "duckdb", "DBI", "tibble")
  rows <- lapply(pkgs, function(pkg) {
    version <- tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NA_character_)
    data.frame(package = pkg, version = version, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

benchmark_timer <- function(expr) {
  gc(verbose = FALSE)
  start <- proc.time()[["elapsed"]]
  value <- suppressWarnings(force(expr))
  elapsed <- proc.time()[["elapsed"]] - start
  list(value = value, elapsed = as.numeric(elapsed))
}

make_grid <- function(n_candidates) {
  entries <- vector("list", n_candidates)
  names(entries) <- sprintf("candidate_%03d", seq_len(n_candidates))
  lookbacks <- rep(c(5L, 10L, 20L, 40L, 80L), length.out = n_candidates)
  for (i in seq_len(n_candidates)) {
    entries[[i]] <- list(
      lookback = lookbacks[[i]],
      threshold = 0.0005 + (i %% 5L) * 0.00025,
      qty = 1 + (i %% 3L)
    )
  }
  do.call(ledgr_param_grid, entries)
}

make_feature_defs <- function(params, feature_mode) {
  if (identical(feature_mode, "wide")) {
    return(list(
      ledgr_ind_returns(5L),
      ledgr_ind_returns(10L),
      ledgr_ind_returns(20L),
      ledgr_ind_returns(40L),
      ledgr_ind_returns(80L)
    ))
  }
  list(ledgr_ind_returns(params$lookback))
}

make_experiment <- function(n_instruments,
                            n_days,
                            temp_dir,
                            feature_mode = "single",
                            metric_context = NULL) {
  bars <- ledgr_sim_bars(
    n_instruments = n_instruments,
    n_days = n_days,
    seed = 2402L,
    instrument_prefix = "BENCH_"
  )
  db_path <- file.path(temp_dir, "benchmark.duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)

  features <- function(params) {
    make_feature_defs(params, feature_mode)
  }

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    feature_id <- sprintf("return_%d", params$lookback)
    for (instrument_id in names(targets)) {
      value <- ctx$feature(instrument_id, feature_id)
      targets[[instrument_id]] <- if (is.finite(value) && value > params$threshold) params$qty else 0
    }
    targets
  }

  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = features,
    opening = ledgr_opening(cash = 100000),
    metric_context = metric_context
  )

  list(snapshot = snapshot, exp = exp, bars = bars)
}

run_loop_baseline <- function(exp, grid, seed, prefix) {
  out <- vector("list", length(grid$params))
  for (i in seq_along(grid$params)) {
    bt <- ledgr_run(
      exp,
      params = grid$params[[i]],
      run_id = paste0(prefix, "_", grid$labels[[i]]),
      seed = seed
    )
    out[[i]] <- bt$run_id
    close(bt)
  }
  invisible(out)
}

scenario_defs <- function() {
  list(
    smoke = list(
      name = "smoke_3_candidates",
      n_candidates = 3L,
      n_instruments = 2L,
      n_days = 126L,
      feature_mode = "single",
      reps = 2L,
      include_run_loop = TRUE,
      include_precompute = TRUE,
      metric_context = NULL
    ),
    reference = list(
      name = "reference_50_candidates",
      n_candidates = 50L,
      n_instruments = 4L,
      n_days = 252L,
      feature_mode = "single",
      reps = 2L,
      include_run_loop = FALSE,
      include_precompute = TRUE,
      metric_context = NULL
    ),
    wider = list(
      name = "wider_feature_payload",
      n_candidates = 10L,
      n_instruments = 12L,
      n_days = 504L,
      feature_mode = "wide",
      reps = 2L,
      include_run_loop = FALSE,
      include_precompute = TRUE,
      metric_context = NULL
    ),
    persistent = list(
      name = "persistent_comparison",
      n_candidates = 5L,
      n_instruments = 4L,
      n_days = 252L,
      feature_mode = "single",
      reps = 2L,
      include_run_loop = TRUE,
      include_precompute = FALSE,
      metric_context = NULL
    ),
    metric_context = list(
      name = "metric_context_non_default",
      n_candidates = 5L,
      n_instruments = 4L,
      n_days = 252L,
      feature_mode = "single",
      reps = 2L,
      include_run_loop = FALSE,
      include_precompute = TRUE,
      metric_context = ledgr_metric_us_equity(risk_free_rate = 0.03)
    )
  )
}

select_scenarios <- function(names_csv = NULL) {
  defs <- scenario_defs()
  if (is.null(names_csv) || !nzchar(names_csv)) {
    return(defs)
  }
  requested <- strsplit(names_csv, ",", fixed = TRUE)[[1]]
  requested <- trimws(requested)
  missing <- setdiff(requested, names(defs))
  if (length(missing)) {
    stop("Unknown workload(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  defs[requested]
}

elapsed_summary <- function(times) {
  data.frame(
    reps = length(times),
    median_sec = stats::median(times),
    mean_sec = mean(times),
    min_sec = min(times),
    max_sec = max(times),
    stringsAsFactors = FALSE
  )
}

run_timed_path <- function(reps, expr_factory) {
  times <- numeric(reps)
  for (i in seq_len(reps)) {
    result <- benchmark_timer(expr_factory(i))
    times[[i]] <- result$elapsed
  }
  times
}

run_scenario <- function(def, out_dir, label) {
  temp_dir <- tempfile("ledgr-v0-1-8-3-benchmark-")
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
  seed <- 2402L

  warmup <- ledgr_sweep(fixture$exp, ledgr_param_grid(warmup = grid$params[[1]]), seed = seed)
  stopifnot(identical(warmup$status[[1]], "DONE"))

  rows <- list()

  sweep_plain_times <- run_timed_path(def$reps, function(i) {
    ledgr_sweep(fixture$exp, grid, seed = seed)
  })
  rows$sweep_plain <- cbind(
    scenario_metadata(def, fixture, label, "sweep_plain"),
    elapsed_summary(sweep_plain_times)
  )

  if (isTRUE(def$include_precompute)) {
    precompute_times <- run_timed_path(def$reps, function(i) {
      ledgr_precompute_features(fixture$exp, grid)
    })
    precomputed <- ledgr_precompute_features(fixture$exp, grid)
    sweep_precomputed_times <- run_timed_path(def$reps, function(i) {
      ledgr_sweep(fixture$exp, grid, precomputed_features = precomputed, seed = seed)
    })
    rows$precompute <- cbind(
      scenario_metadata(def, fixture, label, "precompute"),
      elapsed_summary(precompute_times)
    )
    rows$sweep_precomputed <- cbind(
      scenario_metadata(def, fixture, label, "sweep_precomputed"),
      elapsed_summary(sweep_precomputed_times)
    )
  }

  if (isTRUE(def$include_run_loop)) {
    run_loop_times <- run_timed_path(def$reps, function(i) {
      run_loop_baseline(fixture$exp, grid, seed = seed, prefix = paste(label, def$name, i, sep = "_"))
    })
    rows$run_loop <- cbind(
      scenario_metadata(def, fixture, label, "run_loop"),
      elapsed_summary(run_loop_times)
    )
  }

  do.call(rbind, rows)
}

scenario_metadata <- function(def, fixture, label, path) {
  data.frame(
    label = label,
    scenario = def$name,
    path = path,
    n_candidates = def$n_candidates,
    n_instruments = def$n_instruments,
    n_days = def$n_days,
    n_bars = nrow(fixture$bars),
    feature_mode = def$feature_mode,
    metric_context = if (is.null(def$metric_context)) "default" else "non_default_us_equity_rf_0.03",
    stringsAsFactors = FALSE
  )
}

run_measurement <- function(label,
                            out_dir,
                            workload_names = NULL,
                            reps_override = NULL) {
  load_ledgr_source()
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  scenarios <- select_scenarios(workload_names)
  if (!is.null(reps_override)) {
    scenarios <- lapply(scenarios, function(x) {
      x$reps <- as.integer(reps_override)
      x
    })
  }
  results <- do.call(rbind, lapply(scenarios, function(def) {
    message("Running ", def$name, " (", def$reps, " reps)...")
    run_scenario(def, out_dir = out_dir, label = label)
  }))
  row.names(results) <- NULL
  results
}

profile_reference_workload <- function(label, out_dir) {
  load_ledgr_source()
  temp_dir <- tempfile("ledgr-v0-1-8-3-profile-")
  dir.create(temp_dir, recursive = TRUE)
  on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  def <- scenario_defs()$reference
  fixture <- make_experiment(def$n_instruments, def$n_days, temp_dir, def$feature_mode, def$metric_context)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  grid <- make_grid(def$n_candidates)

  profile_file <- tempfile("ledgr-v0-1-8-3-rprof-", fileext = ".out")
  on.exit(unlink(profile_file, force = TRUE), add = TRUE)

  Rprof(profile_file, interval = 0.01)
  on.exit(Rprof(NULL), add = TRUE)
  suppressWarnings(ledgr_sweep(fixture$exp, grid, seed = 2402L))
  Rprof(NULL)

  summary <- summaryRprof(profile_file)
  keep_profile_rows <- function(tbl, n = 20L) {
    watch <- c("ledgr_execute_fold", "ledgr_equity_from_events", "ledgr_fills_from_events")
    idx <- unique(c(seq_len(min(n, nrow(tbl))), which(row.names(tbl) %in% watch)))
    tbl[idx, , drop = FALSE]
  }
  total_tbl <- keep_profile_rows(summary$by.total, 20L)
  self_tbl <- keep_profile_rows(summary$by.self, 20L)
  total <- data.frame(
    label = label,
    profile = "by_total",
    frame = row.names(total_tbl),
    total_tbl,
    row.names = NULL,
    check.names = FALSE
  )
  self <- data.frame(
    label = label,
    profile = "by_self",
    frame = row.names(self_tbl),
    self_tbl,
    row.names = NULL,
    check.names = FALSE
  )
  rbind(total, self)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

markdown_table <- function(df, digits = 3) {
  if (!nrow(df)) return(character())
  formatted <- df
  for (name in names(formatted)) {
    if (is.numeric(formatted[[name]])) {
      formatted[[name]] <- format(round(formatted[[name]], digits), trim = TRUE, nsmall = 0)
    } else {
      formatted[[name]] <- as.character(formatted[[name]])
    }
  }
  header <- paste0("| ", paste(names(formatted), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(formatted)), collapse = " | "), " |")
  rows <- apply(formatted, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, sep, rows)
}

write_measurement_report <- function(label,
                                     report_path,
                                     results,
                                     env,
                                     versions,
                                     profile = NULL,
                                     notes = character()) {
  lines <- c(
    paste0("# v0.1.8.3 ", label, " Sweep Optimization Report"),
    "",
    paste0("**Generated:** ", env$timestamp_utc[[1]]),
    paste0("**Git HEAD:** `", env$git_head_short[[1]], "`"),
    paste0("**v0.1.8.2 tag:** `", substr(env$git_v0_1_8_2_tag[[1]], 1L, 7L), "`"),
    "",
    "## Purpose",
    "",
    "Record reproducible timing evidence for the v0.1.8.3 single-core sweep optimization cycle.",
    "The workloads are intentionally public-API based and are designed to be rerun before and after optimization.",
    "",
    "## Environment",
    "",
    markdown_table(env[, c("label", "r_version", "platform", "os", "logical_cores", "physical_cores")]),
    "",
    "## Package Versions",
    "",
    markdown_table(versions),
    "",
    "## Workload Results",
    "",
    markdown_table(results[, c(
      "scenario", "path", "n_candidates", "n_instruments", "n_days",
      "n_bars", "feature_mode", "metric_context", "reps", "median_sec",
      "mean_sec", "min_sec", "max_sec"
    )]),
    "",
    "## Interpretation Notes",
    "",
    notes
  )
  if (!is.null(profile)) {
    fold_row <- profile[profile$profile == "by_total" & profile$frame == "\"ledgr_execute_fold\"", , drop = FALSE]
    fold_pct <- if (nrow(fold_row)) fold_row$total.pct[[1]] else NA_real_
    equity_row <- profile[profile$profile == "by_total" & profile$frame == "\"ledgr_equity_from_events\"", , drop = FALSE]
    fills_row <- profile[profile$profile == "by_total" & profile$frame == "\"ledgr_fills_from_events\"", , drop = FALSE]
    equity_pct <- if (nrow(equity_row)) equity_row$total.pct[[1]] else NA_real_
    fills_pct <- if (nrow(fills_row)) fills_row$total.pct[[1]] else NA_real_
    reconstruction_pct <- sum(c(equity_pct, fills_pct), na.rm = TRUE)
    split_note <- if (is.finite(fold_pct)) {
      c(
        "",
        "## LDG-2108B Split Check",
        "",
        paste0(
          "LDG-2108B estimated fold-core work at about 64% of measured sweep wall time ",
          "and post-candidate reconstruction at about 31%-33%. In this v0.1.8.3 ",
          label,
          " Rprof sample, `ledgr_execute_fold()` accounts for about ",
          round(fold_pct, 1),
          "% of total sampled time on the reference workload."
        ),
        "",
        "That means the old phase split should not be treated as current without remeasurement. Fold/context work still dominates, while the direct post-candidate reconstruction share is not reproduced at the same magnitude by this sampling report. LDG-2408/LDG-2409 should therefore use the post-change report to confirm whether summary reconstruction remains the right optimized slice."
      )
    } else {
      c(
        "",
        "## LDG-2108B Split Check",
        "",
        "The profile did not capture `ledgr_execute_fold()` in the top sampled frames. Treat the LDG-2108B hot-path split as stale until a targeted phase profile is rerun."
      )
    }
    reconstruction_note <- if (is.finite(equity_pct) || is.finite(fills_pct)) {
      c(
        "",
        "## Post-Fold Reconstruction Share",
        "",
        paste0(
          "`ledgr_equity_from_events()` accounts for about ",
          if (is.finite(equity_pct)) round(equity_pct, 1) else "NA",
          "% of sampled reference-workload time, and `ledgr_fills_from_events()` accounts for about ",
          if (is.finite(fills_pct)) round(fills_pct, 1) else "NA",
          "%. Their simple summed share is about ",
          round(reconstruction_pct, 1),
          "%."
        ),
        "",
        "This sum is a diagnostic upper-bound style number, not an additive phase timer: Rprof total percentages can overlap through call stacks. It is still useful as the baseline watch point for LDG-2408 and LDG-2409."
      )
    } else {
      c(
        "",
        "## Post-Fold Reconstruction Share",
        "",
        "The profile did not capture `ledgr_equity_from_events()` or `ledgr_fills_from_events()` in the top sampled frames. Use a targeted phase profile if post-fold reconstruction remains the optimization claim."
      )
    }
    lines <- c(
      lines,
      split_note,
      reconstruction_note,
      "",
      "## Profile Top Frames",
      "",
      markdown_table(utils::head(profile[, c("profile", "frame", "total.time", "total.pct", "self.time", "self.pct")], 20L))
    )
  }
  writeLines(lines, report_path, useBytes = TRUE)
  invisible(report_path)
}
