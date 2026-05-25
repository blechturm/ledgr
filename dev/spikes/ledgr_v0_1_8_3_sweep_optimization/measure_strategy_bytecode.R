#!/usr/bin/env Rscript

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "dev/spikes/ledgr_v0_1_8_3_sweep_optimization/measure_strategy_bytecode.R"
source(file.path(dirname(normalizePath(script_path, mustWork = FALSE)), "common.R"))

time_strategy_variant <- function(def, compiled = FALSE, reps = 1L) {
  temp_dir <- tempfile("ledgr-v0-1-8-3-bytecode-")
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

  if (isTRUE(compiled)) {
    fixture$exp$strategy <- compiler::cmpfun(fixture$exp$strategy)
  }

  grid <- make_grid(def$n_candidates)
  warmup <- ledgr_sweep(fixture$exp, ledgr_param_grid(warmup = grid$params[[1]]), seed = 2402L)
  stopifnot(identical(warmup$status[[1]], "DONE"))
  times <- run_timed_path(reps, function(i) {
    ledgr_sweep(fixture$exp, grid, seed = 2402L)
  })

  info <- ledgr_strategy_source_info(fixture$exp$strategy)
  cbind(
    data.frame(
      scenario = def$name,
      variant = if (isTRUE(compiled)) "cmpfun" else "plain",
      strategy_hash = info$hash,
      body_identical_to_plain = NA,
      stringsAsFactors = FALSE
    ),
    elapsed_summary(times)
  )
}

main <- function() {
  args <- parse_cli()
  out_dir <- args[["out-dir"]] %||% file.path("inst", "design", "spikes", "ledgr_v0_1_8_3_sweep_optimization")
  data_dir <- file.path(out_dir, "data")
  reps <- as.integer(args[["reps"]] %||% "1")

  load_ledgr_source()
  def <- scenario_defs()$reference
  plain <- time_strategy_variant(def, compiled = FALSE, reps = reps)
  compiled <- time_strategy_variant(def, compiled = TRUE, reps = reps)
  probe_strategy <- function(ctx, params) ctx$flat()
  compiled$body_identical_to_plain <- identical(body(compiler::cmpfun(probe_strategy)), body(probe_strategy))
  plain$body_identical_to_plain <- TRUE

  rows <- rbind(plain, compiled)
  write_csv(rows, file.path(data_dir, "strategy_bytecode_check.csv"))
  print(rows, row.names = FALSE)
  invisible(rows)
}

if (identical(environment(), globalenv())) {
  main()
}
