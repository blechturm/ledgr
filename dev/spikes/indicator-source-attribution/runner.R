args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

script_arg <- commandArgs(FALSE)
script_arg <- script_arg[startsWith(script_arg, "--file=")]
if (length(script_arg) != 1L) stop("runner.R needs one --file argument.")
script_path <- normalizePath(
  sub("--file=", "", script_arg[[1L]], fixed = TRUE),
  winslash = "/",
  mustWork = TRUE
)
spike_dir <- dirname(script_path)
repo_dir <- normalizePath(
  file.path(spike_dir, "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)

mode <- arg_value("mode", "all")
out_dir <- normalizePath(
  arg_value("out-dir", file.path(spike_dir, "evidence")),
  winslash = "/",
  mustWork = FALSE
)
seed <- as.integer(arg_value("seed", "20260530"))
n_inst <- as.integer(arg_value("n-inst", "500"))
n_days <- as.integer(arg_value("n-days", "1260"))
fast_n <- as.integer(arg_value("fast", "5"))
slow_n <- as.integer(arg_value("slow", "10"))
gut_arm <- arg_value("gut-arm", "")

if (anyNA(c(seed, n_inst, n_days, fast_n, slow_n)) ||
    n_inst < 1L || n_days < slow_n || fast_n < 1L || slow_n <= fast_n) {
  stop("Invalid registered fixture arguments.", call. = FALSE)
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(out_dir)) {
  stop(sprintf("Could not create evidence directory `%s`.", out_dir))
}

load_ledgr <- function() {
  pkgload::load_all(repo_dir, export_all = TRUE, quiet = TRUE)
  if (!requireNamespace("TTR", quietly = TRUE)) {
    stop("TTR is required for the indicator attribution probe.", call. = FALSE)
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for the indicator attribution probe.", call. = FALSE)
  }
}

elapsed <- function(expr) {
  started <- proc.time()[["elapsed"]]
  value <- force(expr)
  list(value = value, seconds = proc.time()[["elapsed"]] - started)
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

sha256_file <- function(path) {
  digest::digest(file = path, algo = "sha256")
}

peer_sma_ttr <- function(id, n) {
  force(id)
  force(n)
  ledgr_indicator(
    id = id,
    fn = function(window) {
      x <- as.numeric(window$close)
      if (length(x) < n) return(NA_real_)
      as.numeric(TTR::SMA(x, n = n))[[length(x)]]
    },
    requires_bars = n,
    series_fn = function(bars, params) {
      as.numeric(TTR::SMA(as.numeric(bars$close), n = n))
    }
  )
}

strategy_for <- function(fast_id, slow_id) {
  force(fast_id)
  force(slow_id)
  function(ctx, params) {
    targets <- ctx$hold()
    wide <- ctx$features_wide
    instruments <- as.character(wide$instrument_id)
    count <- length(instruments)
    fast <- if (fast_id %in% names(wide)) {
      suppressWarnings(as.numeric(wide[[fast_id]]))
    } else {
      rep(NA_real_, count)
    }
    slow <- if (slow_id %in% names(wide)) {
      suppressWarnings(as.numeric(wide[[slow_id]]))
    } else {
      rep(NA_real_, count)
    }
    ready <- is.finite(fast) & is.finite(slow)
    targets[instruments[ready]] <- ifelse(fast[ready] > slow[ready], 1, 0)
    targets
  }
}

arm_spec <- function(arm, gut = FALSE) {
  if (identical(arm, "A")) {
    return(list(
      label = "native_ledgr_sma",
      features = ledgr_feature_map(
        fast = ledgr_ind_sma(fast_n),
        slow = ledgr_ind_sma(slow_n)
      ),
      fast_id = sprintf("sma_%d", fast_n),
      slow_id = sprintf("sma_%d", slow_n)
    ))
  }
  if (identical(arm, "B")) {
    return(list(
      label = "private_peer_ttr_wrapper",
      features = ledgr_feature_map(
        fast = peer_sma_ttr("wrapper_fast", fast_n),
        slow = peer_sma_ttr("wrapper_slow", slow_n)
      ),
      fast_id = "wrapper_fast",
      slow_id = "wrapper_slow"
    ))
  }
  if (identical(arm, "C")) {
    public_slow_n <- if (isTRUE(gut)) slow_n + 1L else slow_n
    return(list(
      label = "public_ledgr_ttr_sma",
      features = ledgr_feature_map(
        fast = ledgr_ind_ttr(
          "SMA", input = "close", id = "public_fast", n = fast_n
        ),
        slow = ledgr_ind_ttr(
          "SMA", input = "close", id = "public_slow", n = public_slow_n
        )
      ),
      fast_id = "public_fast",
      slow_id = "public_slow"
    ))
  }
  stop(sprintf("Unknown arm `%s`.", arm), call. = FALSE)
}

normalize_time_columns <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  for (name in names(x)) {
    if (inherits(x[[name]], "POSIXt")) {
      x[[name]] <- format(x[[name]], "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
    } else if (inherits(x[[name]], "Date")) {
      x[[name]] <- format(x[[name]], "%Y-%m-%d")
    }
  }
  x
}

normalize_surface <- function(x) {
  x <- normalize_time_columns(x)
  excluded <- intersect(
    c("run_id", "event_id", "created_at_utc", "candidate_id"),
    names(x)
  )
  if (length(excluded) > 0L) {
    x <- x[, setdiff(names(x), excluded), drop = FALSE]
  }
  rownames(x) <- NULL
  list(rows = x, excluded = excluded)
}

normalize_features <- function(precomputed, spec) {
  values <- precomputed$projection$feature_values
  required <- c(spec$fast_id, spec$slow_id)
  if (!all(required %in% names(values))) {
    stop("Precomputed output omitted a registered SMA feature.", call. = FALSE)
  }
  list(
    instruments = names(precomputed$projection$instrument_index),
    pulses = as.character(precomputed$projection$pulses_iso),
    fast = unname(values[[spec$fast_id]]),
    slow = unname(values[[spec$slow_id]])
  )
}

hash_object <- function(x) {
  digest::digest(x, algo = "sha256", serialize = TRUE)
}

output_summary <- function(output, arm, permutation, position) {
  feature_values <- c(as.numeric(output$features$fast), as.numeric(output$features$slow))
  data.frame(
    permutation = permutation,
    position = as.integer(position),
    arm = arm,
    feature_rows = as.integer(length(feature_values)),
    feature_na = as.integer(sum(is.na(feature_values))),
    feature_na_hash = hash_object(is.na(feature_values)),
    feature_value_hash = hash_object(feature_values),
    feature_axis_hash = hash_object(list(
      output$features$instruments,
      output$features$pulses
    )),
    equity_rows = nrow(output$equity),
    equity_hash = hash_object(output$equity),
    fills_rows = nrow(output$fills),
    fills_hash = hash_object(output$fills),
    trades_rows = nrow(output$trades),
    trades_hash = hash_object(output$trades),
    excluded_equity = paste(output$excluded$equity, collapse = ";"),
    excluded_fills = paste(output$excluded$fills, collapse = ";"),
    excluded_trades = paste(output$excluded$trades, collapse = ";"),
    stringsAsFactors = FALSE
  )
}

numeric_residual <- function(left, right, tolerance = 1e-8) {
  if (!identical(dim(left), dim(right)) || !identical(is.na(left), is.na(right))) {
    return(list(equal = FALSE, max_abs = Inf, max_relative = Inf))
  }
  keep <- is.finite(left) & is.finite(right)
  if (!all((!is.finite(left)) == (!is.finite(right)))) {
    return(list(equal = FALSE, max_abs = Inf, max_relative = Inf))
  }
  if (!any(keep)) {
    return(list(equal = TRUE, max_abs = 0, max_relative = 0))
  }
  delta <- abs(left[keep] - right[keep])
  denom <- pmax(abs(left[keep]), abs(right[keep]), 1)
  list(
    equal = isTRUE(all.equal(
      left, right, tolerance = tolerance, check.attributes = TRUE
    )),
    max_abs = max(delta),
    max_relative = max(delta / denom)
  )
}

surface_residual <- function(left, right, tolerance = 1e-8) {
  if (!identical(names(left), names(right)) || nrow(left) != nrow(right)) {
    return(list(equal = FALSE, max_abs = Inf, max_relative = Inf))
  }
  equal <- TRUE
  max_abs <- 0
  max_relative <- 0
  for (name in names(left)) {
    old <- left[[name]]
    new <- right[[name]]
    if (is.numeric(old) && is.numeric(new)) {
      residual <- numeric_residual(old, new, tolerance = tolerance)
      equal <- equal && residual$equal
      max_abs <- max(max_abs, residual$max_abs)
      max_relative <- max(max_relative, residual$max_relative)
    } else {
      equal <- equal && identical(old, new)
    }
  }
  list(equal = equal, max_abs = max_abs, max_relative = max_relative)
}

compare_outputs <- function(left, right, pair, permutation) {
  axis_equal <- identical(left$features$instruments, right$features$instruments) &&
    identical(left$features$pulses, right$features$pulses)
  fast <- numeric_residual(left$features$fast, right$features$fast)
  slow <- numeric_residual(left$features$slow, right$features$slow)
  equity <- surface_residual(left$equity, right$equity)
  fills <- surface_residual(left$fills, right$fills)
  trades <- surface_residual(left$trades, right$trades)
  data.frame(
    permutation = permutation,
    pair = pair,
    feature_axis_identical = axis_equal,
    feature_na_mask_identical = identical(
      is.na(c(left$features$fast, left$features$slow)),
      is.na(c(right$features$fast, right$features$slow))
    ),
    feature_values_equal = fast$equal && slow$equal,
    feature_max_abs = max(fast$max_abs, slow$max_abs),
    feature_max_relative = max(fast$max_relative, slow$max_relative),
    equity_equal = equity$equal,
    equity_max_abs = equity$max_abs,
    equity_max_relative = equity$max_relative,
    fills_equal = fills$equal,
    fills_max_abs = fills$max_abs,
    fills_max_relative = fills$max_relative,
    trades_equal = trades$equal,
    trades_max_abs = trades$max_abs,
    trades_max_relative = trades$max_relative,
    stringsAsFactors = FALSE
  )
}

bench_value <- function(bench, component) {
  value <- bench$mean[bench$component == component]
  if (length(value) != 1L) return(NA_real_)
  as.numeric(value)
}

run_one_arm <- function(arm, permutation, position, base_path, snapshot_id,
                        snapshot_hash, scratch_dir, profile_path = NULL) {
  copy_started <- proc.time()[["elapsed"]]
  store_path <- file.path(
    scratch_dir,
    sprintf("store_%s_%s_%d.duckdb", permutation, arm, position)
  )
  if (!file.copy(base_path, store_path, overwrite = TRUE)) {
    stop("Could not copy the sealed base store.", call. = FALSE)
  }
  store_sha256 <- sha256_file(store_path)
  store_copy_sec <- proc.time()[["elapsed"]] - copy_started

  open_clock <- elapsed(ledgr_snapshot_open(store_path, snapshot_id))
  snapshot <- open_clock$value
  on.exit(try(ledgr_snapshot_close(snapshot), silent = TRUE), add = TRUE)
  verified_hash <- as.character(
    ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  )
  prior_runs <- DBI::dbGetQuery(
    ledgr:::get_connection(snapshot),
    "SELECT COUNT(*) AS n FROM runs"
  )$n[[1L]]
  if (!identical(verified_hash, snapshot_hash) || prior_runs != 0) {
    stop(sprintf(
      paste(
        "Copied store failed the hash or zero-prior-run precondition:",
        "expected_hash=%s actual_hash=%s prior_runs=%s."
      ),
      snapshot_hash,
      verified_hash,
      as.character(prior_runs)
    ))
  }

  removed_cache_entries <- ledgr_feature_cache_clear()
  cache_entries_before <- length(ls(
    ledgr:::.ledgr_feature_cache_registry,
    all.names = TRUE
  ))
  if (cache_entries_before != 0L) {
    stop("Feature cache was not empty after clear.", call. = FALSE)
  }

  spec <- arm_spec(arm, gut = identical(gut_arm, arm))
  experiment_clock <- elapsed(ledgr_experiment(
    snapshot,
    strategy_for(spec$fast_id, spec$slow_id),
    features = spec$features,
    opening = ledgr_opening(cash = 1e7),
    cost_model = ledgr_cost_zero(),
    persist_features = FALSE
  ))
  experiment <- experiment_clock$value
  run_id <- sprintf("attr_%s_%d_%s", permutation, position, arm)

  if (!is.null(profile_path)) {
    utils::Rprof(profile_path, interval = 0.01, memory.profiling = TRUE)
  }
  run_clock <- tryCatch(
    elapsed(ledgr_run(experiment, run_id = run_id, seed = seed)),
    finally = if (!is.null(profile_path)) utils::Rprof(NULL)
  )
  backtest <- run_clock$value
  on.exit(try(close(backtest), silent = TRUE), add = TRUE)

  equity_clock <- elapsed(as.data.frame(ledgr_results(backtest, "equity")))
  fills_clock <- elapsed(as.data.frame(ledgr_results(backtest, "fills")))
  trades_clock <- elapsed(as.data.frame(ledgr_results(backtest, "trades")))
  bench <- ledgr_backtest_bench(backtest)
  info <- ledgr_run_info(snapshot, backtest$run_id)

  feature_clock <- elapsed(ledgr_precompute_features(
    experiment,
    ledgr_param_grid(only = list())
  ))
  feature_output <- normalize_features(feature_clock$value, spec)
  equity_output <- normalize_surface(equity_clock$value)
  fills_output <- normalize_surface(fills_clock$value)
  trades_output <- normalize_surface(trades_clock$value)
  output <- list(
    features = feature_output,
    equity = equity_output$rows,
    fills = fills_output$rows,
    trades = trades_output$rows,
    excluded = list(
      equity = equity_output$excluded,
      fills = fills_output$excluded,
      trades = trades_output$excluded
    )
  )

  measurement <- data.frame(
    permutation = permutation,
    position = as.integer(position),
    arm = arm,
    arm_label = spec$label,
    status = as.character(info$status),
    store_sha256 = store_sha256,
    snapshot_hash = verified_hash,
    prior_runs = as.integer(prior_runs),
    cache_removed_before = as.integer(removed_cache_entries),
    cache_entries_before = as.integer(cache_entries_before),
    cache_hits = as.integer(info$feature_cache_hits),
    cache_misses = as.integer(info$feature_cache_misses),
    store_copy_sec = store_copy_sec,
    snapshot_open_sec = open_clock$seconds,
    experiment_sec = experiment_clock$seconds,
    run_sec = run_clock$seconds,
    t_pre_sec = bench_value(bench, "t_pre"),
    t_loop_sec = bench_value(bench, "t_loop"),
    equity_result_sec = equity_clock$seconds,
    fills_result_sec = fills_clock$seconds,
    trades_result_sec = trades_clock$seconds,
    feature_extract_sec = feature_clock$seconds,
    measured_sec = experiment_clock$seconds + run_clock$seconds +
      equity_clock$seconds + fills_clock$seconds + trades_clock$seconds,
    R_version = paste(R.version$major, R.version$minor, sep = "."),
    ledgr_version = as.character(utils::packageVersion("ledgr")),
    TTR_version = as.character(utils::packageVersion("TTR")),
    duckdb_version = as.character(utils::packageVersion("duckdb")),
    collapse_version = as.character(utils::packageVersion("collapse")),
    stringsAsFactors = FALSE
  )

  close(backtest)
  ledgr_snapshot_close(snapshot)
  unlink(store_path)
  list(measurement = measurement, output = output)
}

run_permutation <- function(permutation, base_path, snapshot_id, snapshot_hash,
                            scratch_dir) {
  order <- strsplit(permutation, "", fixed = TRUE)[[1L]]
  if (length(order) != 3L || !identical(sort(order), c("A", "B", "C"))) {
    stop("A permutation must contain A, B and C exactly once.", call. = FALSE)
  }
  outputs <- list()
  measurements <- vector("list", 3L)
  summaries <- vector("list", 3L)
  for (position in seq_along(order)) {
    arm <- order[[position]]
    result <- run_one_arm(
      arm, permutation, position, base_path, snapshot_id, snapshot_hash,
      scratch_dir
    )
    measurements[[position]] <- result$measurement
    outputs[[arm]] <- result$output
    summaries[[position]] <- output_summary(
      result$output, arm, permutation, position
    )
  }
  parity <- rbind(
    compare_outputs(outputs$A, outputs$B, "A_B", permutation),
    compare_outputs(outputs$A, outputs$C, "A_C", permutation),
    compare_outputs(outputs$B, outputs$C, "B_C", permutation)
  )
  raw_dir <- file.path(out_dir, "raw")
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(raw_dir)) {
    stop(sprintf("Could not create raw evidence directory `%s`.", raw_dir))
  }
  write_csv(
    do.call(rbind, measurements),
    file.path(raw_dir, sprintf("measurements_%s.csv", permutation))
  )
  write_csv(
    do.call(rbind, summaries),
    file.path(raw_dir, sprintf("outputs_%s.csv", permutation))
  )
  write_csv(
    parity,
    file.path(raw_dir, sprintf("parity_%s.csv", permutation))
  )
  invisible(TRUE)
}

run_profile <- function(arm, base_path, snapshot_id, snapshot_hash, scratch_dir) {
  raw_profile <- file.path(scratch_dir, sprintf("profile_%s.out", arm))
  result <- run_one_arm(
    arm = arm,
    permutation = "PROFILE",
    position = match(arm, c("A", "B", "C")),
    base_path = base_path,
    snapshot_id = snapshot_id,
    snapshot_hash = snapshot_hash,
    scratch_dir = scratch_dir,
    profile_path = raw_profile
  )
  profile <- summaryRprof(raw_profile, memory = "both")
  by_total <- as.data.frame(profile$by.total, stringsAsFactors = FALSE)
  by_total$function_name <- rownames(by_total)
  rownames(by_total) <- NULL
  by_total$arm <- arm
  by_total$arm_label <- result$measurement$arm_label[[1L]]
  by_total <- by_total[, c(
    "arm", "arm_label", "function_name",
    setdiff(names(by_total), c("arm", "arm_label", "function_name"))
  ), drop = FALSE]
  write_csv(by_total, file.path(out_dir, sprintf("profile_%s.csv", arm)))
  invisible(TRUE)
}

read_raw <- function(prefix, permutations) {
  do.call(rbind, lapply(permutations, function(permutation) {
    utils::read.csv(
      file.path(out_dir, "raw", sprintf("%s_%s.csv", prefix, permutation)),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }))
}

position_spreads <- function(measurements) {
  rows <- list()
  index <- 1L
  phases <- c(
    "experiment_sec", "run_sec", "t_pre_sec", "t_loop_sec",
    "equity_result_sec", "fills_result_sec", "trades_result_sec",
    "measured_sec"
  )
  for (arm in c("A", "B", "C")) {
    for (position in 1:3) {
      selected <- measurements[
        measurements$arm == arm & measurements$position == position,
        , drop = FALSE
      ]
      for (phase in phases) {
        values <- as.numeric(selected[[phase]])
        rows[[index]] <- data.frame(
          arm = arm,
          position = position,
          phase = phase,
          observations = length(values),
          minimum = min(values),
          maximum = max(values),
          mean = mean(values),
          spread = diff(range(values)),
          stringsAsFactors = FALSE
        )
        index <- index + 1L
      }
    }
  }
  do.call(rbind, rows)
}

pairwise_effects <- function(measurements, spreads) {
  pairs <- list(A_B = c("A", "B"), A_C = c("A", "C"), B_C = c("B", "C"))
  phases <- c(
    "experiment_sec", "run_sec", "equity_result_sec",
    "fills_result_sec", "trades_result_sec"
  )
  rows <- list()
  index <- 1L
  for (pair_name in names(pairs)) {
    pair <- pairs[[pair_name]]
    position_differences <- numeric(3L)
    position_percent <- numeric(3L)
    dominant_phases <- character(3L)
    dominant_shares <- numeric(3L)
    for (position in 1:3) {
      phase_means <- lapply(pair, function(arm) {
        selected <- measurements[
          measurements$arm == arm & measurements$position == position,
          , drop = FALSE
        ]
        vapply(phases, function(phase) mean(selected[[phase]]), numeric(1))
      })
      names(phase_means) <- pair
      total_means <- vapply(pair, function(arm) {
        selected <- measurements[
          measurements$arm == arm & measurements$position == position,
          , drop = FALSE
        ]
        mean(selected$measured_sec)
      }, numeric(1))
      delta <- phase_means[[1L]] - phase_means[[2L]]
      position_differences[[position]] <- total_means[[1L]] - total_means[[2L]]
      position_percent[[position]] <- abs(position_differences[[position]]) /
        min(total_means)
      dominant_index <- which.max(abs(delta))
      dominant_phases[[position]] <- phases[[dominant_index]]
      dominant_shares[[position]] <- if (sum(abs(delta)) > 0) {
        abs(delta[[dominant_index]]) / sum(abs(delta))
      } else {
        0
      }
    }
    measured_spreads <- spreads[
      spreads$phase == "measured_sec" & spreads$arm %in% pair,
      , drop = FALSE
    ]
    largest_spread <- max(measured_spreads$spread)
    signs <- sign(position_differences)
    stable_direction <- all(signs == signs[[1L]]) && signs[[1L]] != 0
    threshold_seconds <- min(abs(position_differences)) > 1
    threshold_percent <- min(position_percent) > 0.05
    above_spread <- min(abs(position_differences)) > largest_spread
    localized <- all(dominant_shares >= 0.5)
    rows[[index]] <- data.frame(
      pair = pair_name,
      left_arm = pair[[1L]],
      right_arm = pair[[2L]],
      position_1_difference_sec = position_differences[[1L]],
      position_2_difference_sec = position_differences[[2L]],
      position_3_difference_sec = position_differences[[3L]],
      position_1_percent_faster_arm = position_percent[[1L]],
      position_2_percent_faster_arm = position_percent[[2L]],
      position_3_percent_faster_arm = position_percent[[3L]],
      largest_within_position_spread_sec = largest_spread,
      stable_direction = stable_direction,
      exceeds_one_second = threshold_seconds,
      exceeds_five_percent = threshold_percent,
      exceeds_largest_spread = above_spread,
      localized_by_phase = localized,
      dominant_phase_position_1 = dominant_phases[[1L]],
      dominant_phase_position_2 = dominant_phases[[2L]],
      dominant_phase_position_3 = dominant_phases[[3L]],
      structural_difference = stable_direction && threshold_seconds &&
        threshold_percent && above_spread && localized,
      stringsAsFactors = FALSE
    )
    index <- index + 1L
  }
  do.call(rbind, rows)
}

aggregate_evidence <- function(permutations, base_path, snapshot_id,
                               snapshot_hash, fixture_sha256) {
  measurements <- read_raw("measurements", permutations)
  outputs <- read_raw("outputs", permutations)
  parity <- read_raw("parity", permutations)
  spreads <- position_spreads(measurements)
  effects <- pairwise_effects(measurements, spreads)

  write_csv(measurements, file.path(out_dir, "measurements.csv"))
  write_csv(outputs, file.path(out_dir, "outputs.csv"))
  write_csv(parity, file.path(out_dir, "parity.csv"))
  write_csv(spreads, file.path(out_dir, "position_spreads.csv"))
  write_csv(effects, file.path(out_dir, "pairwise_effects.csv"))
  write_csv(data.frame(
    fixture_seed = seed,
    instruments = n_inst,
    pulses = n_days,
    fast_n = fast_n,
    slow_n = slow_n,
    snapshot_id = snapshot_id,
    snapshot_hash = snapshot_hash,
    sealed_store_sha256 = fixture_sha256,
    permutations = paste(permutations, collapse = ";"),
    stringsAsFactors = FALSE
  ), file.path(out_dir, "fixture.csv"))
  write_csv(data.frame(
    git_commit = system2("git", c("-C", repo_dir, "rev-parse", "HEAD"), stdout = TRUE),
    R_version = paste(R.version$major, R.version$minor, sep = "."),
    ledgr_version = as.character(utils::packageVersion("ledgr")),
    TTR_version = as.character(utils::packageVersion("TTR")),
    duckdb_version = as.character(utils::packageVersion("duckdb")),
    collapse_version = as.character(utils::packageVersion("collapse")),
    comparison_tolerance = 1e-8,
    stringsAsFactors = FALSE
  ), file.path(out_dir, "environment.csv"))
  invisible(TRUE)
}

run_all <- function() {
  load_ledgr()
  permutations <- c("ABC", "ACB", "BAC", "BCA", "CAB", "CBA")
  scratch_dir <- tempfile("indicator-source-attribution-")
  dir.create(scratch_dir, recursive = TRUE)
  on.exit(unlink(scratch_dir, recursive = TRUE, force = TRUE), add = TRUE)

  bars <- as.data.frame(ledgr_sim_bars(
    n_instruments = n_inst,
    n_days = n_days,
    seed = seed,
    instrument_prefix = "PEER_"
  ))
  base_path <- file.path(scratch_dir, "sealed-base.duckdb")
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = base_path,
    snapshot_id = sprintf(
      "indicator-source-attribution-%d-%d-%d",
      n_inst,
      n_days,
      seed
    )
  )
  snapshot_id <- snapshot$snapshot_id
  snapshot_hash <- as.character(
    ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  )
  ledgr_snapshot_close(snapshot)
  fixture_sha256 <- sha256_file(base_path)

  rscript <- Sys.which("Rscript")
  if (!nzchar(rscript)) stop("Rscript is unavailable.", call. = FALSE)
  shared <- c(
    script_path,
    "--mode=child",
    paste0("--out-dir=", out_dir),
    paste0("--base-path=", base_path),
    paste0("--snapshot-id=", snapshot_id),
    paste0("--snapshot-hash=", snapshot_hash),
    paste0("--scratch-dir=", scratch_dir),
    paste0("--seed=", seed),
    paste0("--n-inst=", n_inst),
    paste0("--n-days=", n_days),
    paste0("--fast=", fast_n),
    paste0("--slow=", slow_n),
    paste0("--gut-arm=", gut_arm)
  )
  for (permutation in permutations) {
    message("[indicator-attribution] permutation ", permutation)
    status <- system2(
      rscript,
      c(shared, paste0("--permutation=", permutation))
    )
    if (!identical(status, 0L)) {
      stop(sprintf("Permutation %s failed with status %s.", permutation, status))
    }
  }
  if (!nzchar(gut_arm)) {
    for (arm in c("A", "B", "C")) {
      message("[indicator-attribution] profile arm ", arm)
      profile_args <- shared
      profile_args[[2L]] <- "--mode=profile"
      status <- system2(rscript, c(profile_args, paste0("--arm=", arm)))
      if (!identical(status, 0L)) {
        stop(sprintf("Profile arm %s failed with status %s.", arm, status))
      }
    }
  }
  aggregate_evidence(
    permutations, base_path, snapshot_id, snapshot_hash, fixture_sha256
  )
  message("[indicator-attribution] evidence written to ", out_dir)
}

if (identical(mode, "child")) {
  load_ledgr()
  run_permutation(
    permutation = arg_value("permutation"),
    base_path = normalizePath(arg_value("base-path"), winslash = "/"),
    snapshot_id = arg_value("snapshot-id"),
    snapshot_hash = arg_value("snapshot-hash"),
    scratch_dir = normalizePath(arg_value("scratch-dir"), winslash = "/")
  )
} else if (identical(mode, "profile")) {
  load_ledgr()
  run_profile(
    arm = arg_value("arm"),
    base_path = normalizePath(arg_value("base-path"), winslash = "/"),
    snapshot_id = arg_value("snapshot-id"),
    snapshot_hash = arg_value("snapshot-hash"),
    scratch_dir = normalizePath(arg_value("scratch-dir"), winslash = "/")
  )
} else if (identical(mode, "all")) {
  run_all()
} else {
  stop(sprintf("Unknown mode `%s`.", mode), call. = FALSE)
}
