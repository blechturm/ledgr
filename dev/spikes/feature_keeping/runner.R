# Feature-keeping spike runner. Binds nothing; changes no package code.
#
# Rscript runner.R run <repo> <evidence_dir> <scratch_dir> [full|quick] [normal|gut]
# Rscript runner.R child <repo> <work_dir> <case> <arm> <rep> [normal|gut]

`%||%` <- function(x, y) if (is.null(x)) y else x

fk_args <- commandArgs(trailingOnly = TRUE)
if (length(fk_args) < 1L) stop("Expected command: run or child")
fk_command <- fk_args[[1L]]

fk_load <- function(repo) {
  .libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
  pkgload::load_all(repo, quiet = TRUE)
}

fk_bars <- function(n_instruments, n_days) {
  bars <- as.data.frame(ledgr_sim_bars(
    n_instruments = n_instruments,
    n_days = n_days,
    seed = 20261014L,
    instrument_prefix = "FK_"
  ))
  bars$high <- pmax(bars$high, bars$open, bars$close)
  bars$low <- pmin(bars$low, bars$open, bars$close)
  bars
}

fk_snapshot <- function(bars, db_path, snapshot_id) {
  unlink(c(db_path, paste0(db_path, ".wal")))
  ids <- sort(unique(as.character(bars$instrument_id)))
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = ids),
    db_path = db_path,
    snapshot_id = snapshot_id
  )
}

fk_custom_indicator <- function(counter = NULL) {
  ledgr_indicator(
    id = "fk_feature",
    fn = function(window, params = list()) {
      if (!is.null(counter)) counter$n <- counter$n + 1L
      mean(utils::tail(window$close, 20L))
    },
    requires_bars = 20L
  )
}

fk_strategy <- function(ctx, params) {
  signal <- ctx$vec$feature("fk_feature")
  targets <- ctx$flat()
  targets[is.finite(signal) & signal > params$threshold] <- 1
  targets
}

fk_experiment <- function(snapshot, ids, indicator, persist_features) {
  ledgr_experiment(
    snapshot = snapshot,
    strategy = fk_strategy,
    features = list(indicator),
    opening = ledgr_opening(cash = 1000000),
    universe = ids,
    cost_model = ledgr_cost_zero(),
    persist_features = persist_features
  )
}

fk_strip_identity <- function(x) {
  if (!is.data.frame(x)) return(x)
  x <- x[, setdiff(names(x), c("run_id", "candidate_id", "event_id")), drop = FALSE]
  for (name in names(x)) {
    if (inherits(x[[name]], "POSIXt")) {
      x[[name]] <- format(as.POSIXct(x[[name]], tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    }
  }
  rownames(x) <- NULL
  x
}

fk_result_hash <- function(bt) {
  value <- list(
    equity = fk_strip_identity(ledgr_results(bt, "equity")),
    fills = fk_strip_identity(ledgr_results(bt, "fills")),
    ledger = fk_strip_identity(ledgr_results(bt, "ledger"))
  )
  digest::digest(serialize(value, NULL, version = 3L), algo = "sha256", serialize = FALSE)
}

fk_cache_stats <- function() {
  registry <- ledgr:::.ledgr_feature_cache_registry
  keys <- ls(registry, all.names = TRUE)
  values <- if (length(keys)) mget(keys, envir = registry, inherits = FALSE) else list()
  data.frame(
    cache_entries = length(keys),
    cache_values = sum(vapply(values, length, integer(1))),
    cache_bytes = as.numeric(utils::object.size(values)),
    stringsAsFactors = FALSE
  )
}

fk_rss <- function() {
  if (!requireNamespace("ps", quietly = TRUE)) return(NA_real_)
  as.numeric(ps::ps_memory_info(ps::ps_handle())[["rss"]])
}

fk_with_cache <- function(cache_on, code) {
  if (isTRUE(cache_on)) return(force(code))
  testthat::with_mocked_bindings(
    force(code),
    ledgr_feature_cache_key_from_normalized_parts = function(...) NULL,
    .package = "ledgr"
  )
}

fk_run_one <- function(exp, snapshot, run_id, threshold = 100) {
  started <- proc.time()[["elapsed"]]
  bt <- suppressWarnings(ledgr_run(
    exp,
    params = list(threshold = threshold),
    run_id = run_id
  ))
  seconds <- proc.time()[["elapsed"]] - started
  info <- ledgr_run_info(snapshot, run_id)
  bench <- ledgr_backtest_bench(bt)
  t_post <- bench$mean[bench$component == "t_post"]
  out <- list(
    seconds = seconds,
    t_post = if (length(t_post)) as.numeric(t_post[[1L]]) else NA_real_,
    result_hash = fk_result_hash(bt),
    cache_hits = as.integer(info$feature_cache_hits[[1L]]),
    cache_misses = as.integer(info$feature_cache_misses[[1L]])
  )
  close(bt)
  out
}

fk_timing_child <- function(work_dir, case, arm, rep) {
  shape <- switch(
    case,
    cold = c(N = 40L, T = 400L),
    `repeat` = c(N = 40L, T = 400L),
    persist = c(N = 80L, T = 500L),
    stop("Unknown timing case: ", case)
  )
  bars <- fk_bars(shape[["N"]], shape[["T"]])
  db_path <- file.path(work_dir, "store.duckdb")
  snap <- fk_snapshot(bars, db_path, paste0("fk_", case, "_", arm, "_", rep))
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  ids <- sort(unique(as.character(bars$instrument_id)))
  persist <- identical(arm, "persist_on")
  cache_on <- !arm %in% c("cache_off", "persist_on", "persist_off")
  exp <- fk_experiment(snap, ids, fk_custom_indicator(), persist)
  ledgr_feature_cache_clear()
  before_bytes <- file.info(db_path)$size

  values <- fk_with_cache(cache_on, {
    first <- fk_run_one(exp, snap, paste0("fk-", case, "-", arm, "-", rep, "-1"))
    second <- if (identical(case, "repeat")) {
      fk_run_one(exp, snap, paste0("fk-", case, "-", arm, "-", rep, "-2"))
    } else {
      list(seconds = NA_real_, t_post = NA_real_, result_hash = NA_character_, cache_hits = NA_integer_, cache_misses = NA_integer_)
    }
    list(first = first, second = second)
  })

  con <- ledgr:::ledgr_snapshot_connection(snap)$con
  feature_rows <- as.numeric(DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM features"
  )$n[[1L]])
  after_bytes <- file.info(db_path)$size
  data.frame(
    case = case,
    arm = arm,
    rep = as.integer(rep),
    seconds_first = values$first$seconds,
    seconds_second = values$second$seconds,
    t_post_first = values$first$t_post,
    result_hash_first = values$first$result_hash,
    result_hash_second = values$second$result_hash,
    cache_hits_first = values$first$cache_hits,
    cache_misses_first = values$first$cache_misses,
    cache_hits_second = values$second$cache_hits,
    cache_misses_second = values$second$cache_misses,
    feature_rows = feature_rows,
    db_growth_bytes = as.numeric(after_bytes - before_bytes),
    status = "ok",
    note = "",
    stringsAsFactors = FALSE
  )
}

fk_capture_indicator <- function(captured) {
  ledgr_indicator(
    id = "fk_feature",
    fn = function(window, params = list()) captured$value,
    series_fn = function(bars, params = list()) rep(captured$value, nrow(bars)),
    requires_bars = 1L
  )
}

fk_correctness_child <- function(work_dir, gut) {
  bars <- fk_bars(3L, 40L)
  ids <- sort(unique(as.character(bars$instrument_id)))
  db_a <- file.path(work_dir, "a.duckdb")
  snap_a <- fk_snapshot(bars, db_a, "fk_correctness_a")
  on.exit(ledgr_snapshot_close(snap_a), add = TRUE)
  captured <- new.env(parent = emptyenv())
  captured$value <- 1
  ind <- fk_capture_indicator(captured)
  exp_a <- fk_experiment(snap_a, ids, ind, FALSE)
  ledgr_feature_cache_clear()
  first <- fk_run_one(exp_a, snap_a, "fk-correctness-1", threshold = 1.5)
  captured$value <- 2
  if (identical(gut, "gut")) ledgr_feature_cache_clear()
  warm <- fk_run_one(exp_a, snap_a, "fk-correctness-2", threshold = 1.5)
  ledgr_feature_cache_clear()
  fresh <- fk_run_one(exp_a, snap_a, "fk-correctness-3", threshold = 1.5)

  fills_for <- function(snapshot, run_id) {
    bt <- ledgr_run_open(snapshot, run_id)
    on.exit(close(bt), add = TRUE)
    nrow(ledgr_results(bt, "fills"))
  }
  first_fills <- fills_for(snap_a, "fk-correctness-1")
  warm_fills <- fills_for(snap_a, "fk-correctness-2")
  fresh_fills <- fills_for(snap_a, "fk-correctness-3")

  ledgr_feature_cache_clear()
  captured$value <- 2
  same_a <- fk_run_one(exp_a, snap_a, "fk-samehash-a", threshold = 1.5)
  db_b <- file.path(work_dir, "b.duckdb")
  snap_b <- fk_snapshot(bars, db_b, "fk_correctness_b")
  on.exit(ledgr_snapshot_close(snap_b), add = TRUE)
  exp_b <- fk_experiment(snap_b, ids, ind, FALSE)
  same_b <- fk_run_one(exp_b, snap_b, "fk-samehash-b", threshold = 1.5)
  info_a <- ledgr_snapshot_info(snap_a)
  info_b <- ledgr_snapshot_info(snap_b)

  key_v1 <- ledgr:::ledgr_feature_cache_key_from_parts(
    "engine-probe", "FK_001", "feature-probe", "engine-v1", "2020-01-01T00:00:00Z", "2020-01-03T00:00:00Z"
  )
  key_v2 <- ledgr:::ledgr_feature_cache_key_from_parts(
    "engine-probe", "FK_001", "feature-probe", "engine-v2", "2020-01-01T00:00:00Z", "2020-01-03T00:00:00Z"
  )
  ledgr:::ledgr_feature_cache_set(key_v1, c(1, 2, 3))
  engine_isolated <- is.null(ledgr:::ledgr_feature_cache_get(key_v2, 3L))

  reader <- tryCatch({
    bt <- ledgr_run_open(snap_a, "fk-correctness-3")
    on.exit(close(bt), add = TRUE)
    ledgr_results(bt, "features")
    "accepted"
  }, error = function(e) class(e)[[1L]])

  data.frame(
    capture_first_fills = first_fills,
    capture_warm_fills = warm_fills,
    capture_fresh_fills = fresh_fills,
    capture_warm_hits = warm$cache_hits,
    capture_stale = warm_fills != fresh_fills,
    engine_version_isolated = engine_isolated,
    same_hash = identical(info_a$snapshot_hash, info_b$snapshot_hash),
    different_ids = !identical(info_a$snapshot_id, info_b$snapshot_id),
    same_hash_reused = same_b$cache_hits > 0L,
    same_hash_outputs_equal = identical(same_a$result_hash, same_b$result_hash),
    public_feature_reader = identical(reader, "accepted"),
    reader_result = reader,
    stringsAsFactors = FALSE
  )
}

fk_walk_child <- function(work_dir) {
  bars <- fk_bars(8L, 140L)
  ids <- sort(unique(as.character(bars$instrument_id)))
  snap <- fk_snapshot(bars, file.path(work_dir, "walk.duckdb"), "fk_walk")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  counter <- new.env(parent = emptyenv())
  counter$n <- 0L
  exp <- fk_experiment(snap, ids, fk_custom_indicator(counter), FALSE)
  dates <- sort(unique(as.Date(bars$ts_utc)))
  folds <- ledgr_folds_rolling(
    start = min(dates),
    end = max(dates),
    train_window = "60 days",
    test_window = "25 days"
  )
  grid <- ledgr_param_grid(
    list(threshold = 99),
    list(threshold = 101)
  )
  ledgr_feature_cache_clear()
  first <- suppressWarnings(ledgr_walk_forward(
    exp, grid, folds, ledgr_rule_argmax("sharpe_ratio"),
    seed = 1L, opening_state_policy = "flat_test_state"
  ))
  calls_first <- counter$n
  cache_first <- fk_cache_stats()
  second <- suppressWarnings(ledgr_walk_forward(
    exp, grid, folds, ledgr_rule_argmax("sharpe_ratio"),
    seed = 2L, opening_state_policy = "flat_test_state"
  ))
  calls_second <- counter$n - calls_first
  cache_second <- fk_cache_stats()
  for (bt in c(first$test_runs, second$test_runs)) try(close(bt), silent = TRUE)
  data.frame(
    folds_first = nrow(first$folds),
    folds_second = nrow(second$folds),
    feature_calls_first = calls_first,
    feature_calls_second = calls_second,
    entries_first = cache_first$cache_entries,
    entries_second = cache_second$cache_entries,
    values_first = cache_first$cache_values,
    values_second = cache_second$cache_values,
    bytes_first = cache_first$cache_bytes,
    bytes_second = cache_second$cache_bytes,
    stringsAsFactors = FALSE
  )
}

fk_scale_child <- function(work_dir, arm) {
  full <- identical(arm, "full")
  n_instruments <- if (full) 1166L else 563L
  n_days <- if (full) 7213L else 757L
  started <- proc.time()[["elapsed"]]
  rss_start <- fk_rss()
  bars <- fk_bars(n_instruments, n_days)
  rss_bars <- fk_rss()
  ids <- sort(unique(as.character(bars$instrument_id)))
  snap <- fk_snapshot(bars, file.path(work_dir, "scale.duckdb"), paste0("fk_scale_", arm))
  rm(bars)
  gc()
  rss_sealed <- fk_rss()
  indicator <- ledgr_indicator(
    id = "fk_feature",
    fn = function(window, params = list()) utils::tail(window$close, 1L),
    series_fn = function(bars, params = list()) bars$close,
    requires_bars = 1L
  )
  exp <- fk_experiment(snap, ids, indicator, FALSE)
  ledgr_feature_cache_clear()
  run <- fk_run_one(exp, snap, paste0("fk-scale-", arm), threshold = 1e20)
  cache <- fk_cache_stats()
  gc()
  rss_retained <- fk_rss()
  ledgr_snapshot_close(snap)
  data.frame(
    scale = arm,
    n_instruments = n_instruments,
    n_sessions = n_days,
    expected_values = as.numeric(n_instruments) * as.numeric(n_days),
    cache_entries = cache$cache_entries,
    cache_values = cache$cache_values,
    cache_bytes = cache$cache_bytes,
    rss_start = rss_start,
    rss_after_bars = rss_bars,
    rss_after_seal_gc = rss_sealed,
    rss_after_run_gc = rss_retained,
    run_seconds = run$seconds,
    total_seconds = proc.time()[["elapsed"]] - started,
    result_hash = run$result_hash,
    status = "ok",
    note = "",
    stringsAsFactors = FALSE
  )
}

fk_write_child <- function(work_dir, value) {
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, file.path(work_dir, "result.csv"), row.names = FALSE, na = "")
}

fk_child_main <- function(args) {
  if (length(args) < 6L) stop("child requires repo, work_dir, case, arm, rep")
  repo <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
  work_dir <- args[[3L]]
  case <- args[[4L]]
  arm <- args[[5L]]
  rep <- as.integer(args[[6L]])
  gut <- if (length(args) >= 7L) args[[7L]] else "normal"
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  fk_load(repo)
  value <- switch(
    case,
    cold = fk_timing_child(work_dir, case, arm, rep),
    `repeat` = fk_timing_child(work_dir, case, arm, rep),
    persist = fk_timing_child(work_dir, case, arm, rep),
    correctness = fk_correctness_child(work_dir, gut),
    walk = fk_walk_child(work_dir),
    scale = fk_scale_child(work_dir, arm),
    stop("Unknown child case: ", case)
  )
  fk_write_child(work_dir, value)
}

fk_child_call <- function(script, repo, scratch_dir, case, arm, rep, gut, timeout) {
  tag <- paste(case, arm, rep, sep = "-")
  work <- file.path(scratch_dir, tag)
  if (dir.exists(work)) unlink(work, recursive = TRUE, force = TRUE)
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  result <- tryCatch(
    processx::run(
      file.path(R.home("bin"), "Rscript.exe"),
      c(script, "child", repo, work, case, arm, as.character(rep), gut),
      timeout = timeout,
      echo = FALSE,
      error_on_status = FALSE
    ),
    error = identity
  )
  file <- file.path(work, "result.csv")
  if (inherits(result, "error") || !file.exists(file) || !identical(result$status, 0L)) {
    note <- if (inherits(result, "error")) conditionMessage(result) else paste(result$stderr, collapse = " ")
    value <- data.frame(case = case, arm = arm, rep = rep, status = "failed", note = substr(note, 1L, 500L), stringsAsFactors = FALSE)
  } else {
    value <- utils::read.csv(file, stringsAsFactors = FALSE, check.names = FALSE)
  }
  unlink(work, recursive = TRUE, force = TRUE)
  value
}

fk_bind_rows <- function(rows) {
  names_all <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    for (name in setdiff(names_all, names(x))) x[[name]] <- NA
    x[, names_all, drop = FALSE]
  })
  do.call(rbind, rows)
}

fk_median <- function(x) stats::median(as.numeric(x), na.rm = TRUE)

fk_run_main <- function(args) {
  if (length(args) < 4L) stop("run requires repo, evidence_dir and scratch_dir")
  repo <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
  evidence_dir <- args[[3L]]
  scratch_dir <- args[[4L]]
  scale_mode <- if (length(args) >= 5L) args[[5L]] else "full"
  gut <- if (length(args) >= 6L) args[[6L]] else "normal"
  dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(scratch_dir, recursive = TRUE, showWarnings = FALSE)
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  script <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "dev/spikes/feature_keeping/runner.R"
  script <- normalizePath(script, winslash = "/", mustWork = TRUE)

  timing_rows <- list()
  orders <- list(c("cache_on", "cache_off"), c("cache_off", "cache_on"), c("cache_on", "cache_off"))
  for (case in c("cold", "repeat")) {
    for (rep in seq_along(orders)) {
      for (arm in orders[[rep]]) {
        timing_rows[[length(timing_rows) + 1L]] <- fk_child_call(script, repo, scratch_dir, case, arm, rep, gut, 180000L)
      }
    }
  }
  persist_orders <- list(c("persist_on", "persist_off"), c("persist_off", "persist_on"), c("persist_on", "persist_off"))
  for (rep in seq_along(persist_orders)) {
    for (arm in persist_orders[[rep]]) {
      timing_rows[[length(timing_rows) + 1L]] <- fk_child_call(script, repo, scratch_dir, "persist", arm, rep, gut, 180000L)
    }
  }
  timings <- fk_bind_rows(timing_rows)
  utils::write.csv(timings, file.path(evidence_dir, "timings.csv"), row.names = FALSE, na = "")

  correctness <- fk_child_call(script, repo, scratch_dir, "correctness", "current", 1L, gut, 180000L)
  walk <- fk_child_call(script, repo, scratch_dir, "walk", "current", 1L, gut, 240000L)
  scale_arm <- if (identical(scale_mode, "full")) "full" else "envelope"
  scale <- fk_child_call(script, repo, scratch_dir, "scale", scale_arm, 1L, gut, 600000L)
  if (!"status" %in% names(scale) || !identical(as.character(scale$status[[1L]]), "ok")) {
    utils::write.csv(
      scale,
      file.path(evidence_dir, "memory_full_attempt.csv"),
      row.names = FALSE,
      na = ""
    )
    scale <- fk_child_call(script, repo, scratch_dir, "scale", "envelope", 1L, gut, 600000L)
  }
  utils::write.csv(correctness, file.path(evidence_dir, "correctness.csv"), row.names = FALSE, na = "")
  utils::write.csv(walk, file.path(evidence_dir, "walk_forward.csv"), row.names = FALSE, na = "")
  utils::write.csv(scale, file.path(evidence_dir, "memory.csv"), row.names = FALSE, na = "")

  ok_timing <- timings$status == "ok"
  cold_on <- timings$seconds_first[timings$case == "cold" & timings$arm == "cache_on" & ok_timing]
  cold_off <- timings$seconds_first[timings$case == "cold" & timings$arm == "cache_off" & ok_timing]
  repeat_on <- timings$seconds_second[timings$case == "repeat" & timings$arm == "cache_on" & ok_timing]
  repeat_off <- timings$seconds_second[timings$case == "repeat" & timings$arm == "cache_off" & ok_timing]
  persist_on <- timings$seconds_first[timings$case == "persist" & timings$arm == "persist_on" & ok_timing]
  persist_off <- timings$seconds_first[timings$case == "persist" & timings$arm == "persist_off" & ok_timing]
  capture_clean <- isTRUE(!correctness$capture_stale[[1L]])
  correctness_clean <- capture_clean && isTRUE(correctness$engine_version_isolated[[1L]]) &&
    isTRUE(correctness$same_hash_outputs_equal[[1L]])
  repeat_ratio <- fk_median(repeat_on) / fk_median(repeat_off)
  cache_benefit <- is.finite(repeat_ratio) && repeat_ratio <= 0.90
  memory_measured <- "status" %in% names(scale) && identical(as.character(scale$status[[1L]]), "ok")
  cache_keep <- cache_benefit && correctness_clean && memory_measured
  persistence_consumer <- isTRUE(correctness$public_feature_reader[[1L]])
  persistence_outputs_equal <- length(unique(timings$result_hash_first[timings$case == "persist" & ok_timing])) == 1L
  persistence_keep <- persistence_consumer && persistence_outputs_equal
  verdict <- if (cache_keep || persistence_keep) "GREEN" else "RED"
  decision <- data.frame(
    verdict = verdict,
    cold_cache_ratio = fk_median(cold_on) / fk_median(cold_off),
    repeat_cache_ratio = repeat_ratio,
    repeat_cache_saving = 1 - repeat_ratio,
    cache_benefit = cache_benefit,
    cache_correctness = correctness_clean,
    cache_memory_measured = memory_measured,
    cache_keep = cache_keep,
    persistence_ratio = fk_median(persist_on) / fk_median(persist_off),
    persistence_public_consumer = persistence_consumer,
    persistence_outputs_equal = persistence_outputs_equal,
    persistence_keep = persistence_keep,
    stringsAsFactors = FALSE
  )
  utils::write.csv(decision, file.path(evidence_dir, "decision.csv"), row.names = FALSE, na = "")
  metadata <- data.frame(
    field = c("tree", "r_version", "platform", "scale_mode", "gut"),
    value = c("f262e77a", R.version.string, R.version$platform, scale_mode, gut),
    stringsAsFactors = FALSE
  )
  utils::write.csv(metadata, file.path(evidence_dir, "metadata.csv"), row.names = FALSE, na = "")
  print(decision)
}

if (identical(fk_command, "child")) {
  fk_child_main(fk_args)
} else if (identical(fk_command, "run")) {
  fk_run_main(fk_args)
} else {
  stop("Unknown command: ", fk_command)
}
