e0_lib_paths <- function() {
  unique(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
}

e0_rscript <- function() {
  candidates <- c(
    Sys.getenv("R_SCRIPT", unset = ""),
    "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe",
    file.path(R.home("bin"), "Rscript.exe"),
    file.path(R.home("bin"), "Rscript")
  )
  hit <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(hit)) stop("Cannot locate Rscript.", call. = FALSE)
  hit[[1L]]
}

e0_parse_args <- function(args, defaults) {
  out <- defaults
  i <- 1L
  while (i <= length(args)) {
    key <- args[[i]]
    if (!startsWith(key, "--") || i == length(args)) {
      stop("Expected --name value arguments.", call. = FALSE)
    }
    name <- sub("^--", "", key)
    if (!name %in% names(out)) stop("Unknown argument: ", key, call. = FALSE)
    out[[name]] <- args[[i + 1L]]
    i <- i + 2L
  }
  out
}

e0_spec <- function(preset) {
  if (identical(preset, "smoke")) {
    return(list(
      preset = preset, n_inst = 8L, from = "2020-01-01",
      to = "2020-04-30", lookback = 20L, workers = 2L,
      candidate_n = c(2L, 3L, 4L, 5L)
    ))
  }
  if (identical(preset, "record")) {
    return(list(
      preset = preset, n_inst = 160L, from = "2018-01-01",
      to = "2022-12-31", lookback = 252L, workers = 2L,
      candidate_n = c(5L, 10L, 15L, 20L)
    ))
  }
  stop("`preset` must be smoke or record.", call. = FALSE)
}

e0_load_ledgr <- function(package_root) {
  .libPaths(e0_lib_paths())
  pkgload::load_all(package_root, quiet = TRUE, compile = FALSE)
  invisible(TRUE)
}

e0_constructor_args <- function(inputs, family) {
  x <- inputs$recipe$constructors[[family]]
  x[names(x) != "enabled"]
}

e0_facts <- function(inputs) {
  do.call(ledgr_facts, list(
    do.call(
      ledgr_facts_sessions,
      c(list(df = inputs$sessions), e0_constructor_args(inputs, "sessions"))
    ),
    do.call(
      ledgr_facts_membership_snapshots,
      c(list(df = inputs$membership), e0_constructor_args(inputs, "membership"))
    ),
    do.call(
      ledgr_facts_lifetime,
      c(list(df = inputs$lifetime), e0_constructor_args(inputs, "lifetime"))
    ),
    do.call(
      ledgr_facts_trading_status,
      c(list(df = inputs$trading_status), e0_constructor_args(inputs, "trading_status"))
    )
  ))
}

e0_strategy <- function(ctx, params) {
  month <- substr(ctx$ts_utc, 1L, 7L)
  if (identical(ctx$state_prev$month, month)) return(ctx$hold())
  target <- ctx |>
    ledgr_signal_return(lookback = params$lookback) |>
    ledgr_select_top_n(n = params$n, partial = "allow") |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance(ctx, equity_fraction = params$invested)
  list(targets = target, state_update = list(month = month))
}

e0_fixture <- function(spec, scratch) {
  dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
  ids <- sprintf("E0_%04d", seq_len(spec$n_inst))
  inputs <- ledgr_sim_pit_inputs(
    instrument_ids = ids,
    from = spec$from,
    to = spec$to,
    seed = 1601L,
    venue_id = "E0_VENUE",
    universe_id = "E0_UNIVERSE",
    cases = c("missing_observation", "halt")
  )
  db_path <- file.path(scratch, paste0("e0_", spec$preset, ".duckdb"))
  snapshot <- ledgr_snapshot_from_df(
    inputs$bars,
    instruments_df = inputs$instruments,
    facts = e0_facts(inputs),
    db_path = db_path,
    snapshot_id = paste0("history_e0_", spec$preset),
    price_basis = inputs$recipe$price_basis
  )
  experiment <- ledgr_experiment(
    snapshot,
    e0_strategy,
    features = list(ledgr_ind_returns(spec$lookback)),
    universe = ledgr_universe_members(inputs$recipe$scopes$universe_id),
    valuation_policy = ledgr_valuation_stale(5L),
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1e6)
  )
  candidates <- stats::setNames(
    lapply(spec$candidate_n, function(n) {
      list(n = n, lookback = spec$lookback, invested = 0.95)
    }),
    sprintf("candidate_%02d", seq_along(spec$candidate_n))
  )
  list(
    inputs = inputs,
    snapshot = snapshot,
    db_path = db_path,
    experiment = experiment,
    grid = do.call(ledgr_param_grid, candidates)
  )
}

e0_serialized_bytes <- function(x) {
  length(serialize(x, NULL, ascii = FALSE, xdr = TRUE, version = 3L))
}

e0_contains_data_frame <- function(x) {
  if (is.data.frame(x)) return(TRUE)
  if (!is.list(x)) return(FALSE)
  any(vapply(unclass(x), e0_contains_data_frame, logical(1)))
}

e0_field_group <- function(name) {
  groups <- list(
    experiment = c("exp"),
    bars = c("bars_by_id", "bars_mat", "static_bars_views"),
    axis = c("pulses_posix", "pulses_iso", "execution_opportunities_posix"),
    features = c("precomputed_features", "runtime_projection"),
    availability = c("availability_data", "availability_config", "corporate_action_rows"),
    evaluation = c("metric_kernel", "retain", "compiled_accounting_model"),
    identity = c("snapshot_hash", "strategy_hash", "master_seed")
  )
  hit <- names(groups)[vapply(groups, function(x) name %in% x, logical(1))]
  if (length(hit)) hit[[1L]] else "candidate"
}

e0_mori_candidate <- function(name) {
  name %in% c(
    "bars_by_id", "bars_mat", "static_bars_views", "pulses_posix",
    "pulses_iso", "execution_opportunities_posix", "runtime_projection",
    "availability_data", "corporate_action_rows"
  )
}

e0_task_split <- function(tasks) {
  fields <- names(tasks[[1L]])
  invariant <- vapply(fields, function(field) {
    all(vapply(tasks[-1L], function(task) {
      identical(tasks[[1L]][[field]], task[[field]])
    }, logical(1)))
  }, logical(1))
  shared <- tasks[[1L]][fields[invariant]]
  variants <- lapply(tasks, function(task) task[fields[!invariant]])
  list(invariant = invariant, shared = shared, variants = variants)
}

e0_payload_map <- function(tasks) {
  split <- e0_task_split(tasks)
  fields <- names(split$invariant)
  rows <- lapply(fields, function(field) {
    x <- tasks[[1L]][[field]]
    data.frame(
      field = field,
      group = e0_field_group(field),
      invariant = split$invariant[[field]],
      type = typeof(x),
      class = paste(class(x), collapse = ";"),
      length = length(x),
      nrow = if (is.data.frame(x) || is.matrix(x)) nrow(x) else NA_integer_,
      ncol = if (is.data.frame(x) || is.matrix(x)) ncol(x) else NA_integer_,
      object_bytes = as.numeric(object.size(x)),
      serialized_bytes = e0_serialized_bytes(x),
      contains_data_frame = e0_contains_data_frame(x),
      mori_candidate = split$invariant[[field]] && e0_mori_candidate(field),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

e0_payload_summary <- function(tasks) {
  split <- e0_task_split(tasks)
  task_serialized <- vapply(tasks, e0_serialized_bytes, numeric(1))
  variant_serialized <- vapply(split$variants, e0_serialized_bytes, numeric(1))
  data.frame(
    measure = c(
      "task_count", "task_list_object_bytes", "full_task_serialized_sum",
      "full_task_serialized_min", "full_task_serialized_max",
      "shared_object_bytes", "shared_serialized_bytes",
      "variant_serialized_sum", "repeated_shared_wire_proxy",
      "staged_shared_wire_proxy", "current_minus_staged_wire_proxy"
    ),
    value = c(
      length(tasks), as.numeric(object.size(tasks)), sum(task_serialized),
      min(task_serialized), max(task_serialized),
      as.numeric(object.size(split$shared)), e0_serialized_bytes(split$shared),
      sum(variant_serialized),
      e0_serialized_bytes(split$shared) * length(tasks),
      e0_serialized_bytes(split$shared) * 2 + sum(variant_serialized),
      sum(task_serialized) -
        (e0_serialized_bytes(split$shared) * 2 + sum(variant_serialized))
    ),
    note = c(
      "actual candidate tasks", "R object.size; shared references are not additive",
      "base R XDR serialization proxy, not mirai wire telemetry",
      rep("base R XDR serialization proxy", 2L),
      "invariant list once", "base R XDR serialization proxy",
      "candidate-varying lists", "shared proxy repeated per current task",
      "shared proxy once per two daemons plus variants",
      "positive means staged transport proxy is smaller"
    ),
    stringsAsFactors = FALSE
  )
}

e0_memory_point <- function(label, tasks = NULL, promises = NULL, results = NULL) {
  info <- ps::ps_memory_info()
  data.frame(
    label = label,
    epoch = as.numeric(Sys.time()),
    wset_bytes = unname(info[["wset"]]),
    private_commit_bytes = unname(info[["mem_private"]]),
    tasks_object_bytes = if (is.null(tasks)) 0 else as.numeric(object.size(tasks)),
    promises_object_bytes = if (is.null(promises)) 0 else as.numeric(object.size(promises)),
    results_object_bytes = if (is.null(results)) 0 else as.numeric(object.size(results)),
    stringsAsFactors = FALSE
  )
}

e0_daemon_pids <- function(workers) {
  started <- proc.time()[["elapsed"]]
  map <- mirai::everywhere(Sys.getpid(), .min = workers)
  pids <- as.integer(unlist(map[mirai::.flat], use.names = FALSE))
  list(pids = pids, elapsed_sec = proc.time()[["elapsed"]] - started)
}

e0_parallel_eval_current <- function(tasks, workers, capture) {
  pid_probe <- e0_daemon_pids(workers)
  capture$daemon_pids <- pid_probe$pids
  capture$pid_probe_sec <- pid_probe$elapsed_sec
  if (!is.null(capture$daemon_pid_path)) {
    e0_write_csv(
      data.frame(pid = as.integer(capture$daemon_pids)),
      capture$daemon_pid_path
    )
  }
  points <- list(e0_memory_point("before_submit", tasks = tasks))
  submit_start <- proc.time()[["elapsed"]]
  promises <- lapply(tasks, function(task) {
    mirai::mirai(
      get(
        "ledgr_sweep_worker_eval_candidate_task",
        envir = asNamespace("ledgr")
      )(task),
      task = task
    )
  })
  capture$submit_sec <- proc.time()[["elapsed"]] - submit_start
  points[[length(points) + 1L]] <- e0_memory_point(
    "after_submit", tasks = tasks, promises = promises
  )
  results <- vector("list", length(promises))
  collect_start <- proc.time()[["elapsed"]]
  for (i in seq_along(promises)) {
    results[[i]] <- promises[[i]][]
    if (inherits(results[[i]], "errorValue")) {
      stop(
        sprintf("Current mirai task %s failed: %s", tasks[[i]]$run_id, results[[i]]),
        call. = FALSE
      )
    }
    points[[length(points) + 1L]] <- e0_memory_point(
      paste0("after_collect_", i), tasks, promises, results
    )
  }
  capture$collect_sec <- proc.time()[["elapsed"]] - collect_start
  capture$retention <- do.call(rbind, points)
  results
}

e0_parallel_eval_staged <- function(tasks, workers, capture, gut = "none") {
  split <- e0_task_split(tasks)
  if (identical(gut, "omit-bars-by-id")) split$shared$bars_by_id <- NULL
  stage_start <- proc.time()[["elapsed"]]
  stage_map <- do.call(
    mirai::everywhere,
    list(.expr = quote(TRUE), .ledgr_e0_shared = split$shared, .min = workers)
  )
  invisible(stage_map[mirai::.flat])
  capture$stage_sec <- proc.time()[["elapsed"]] - stage_start
  pid_probe <- e0_daemon_pids(workers)
  capture$daemon_pids <- pid_probe$pids
  capture$pid_probe_sec <- pid_probe$elapsed_sec
  if (!is.null(capture$daemon_pid_path)) {
    e0_write_csv(
      data.frame(pid = as.integer(capture$daemon_pids)),
      capture$daemon_pid_path
    )
  }
  points <- list(e0_memory_point("after_stage", tasks = tasks))
  submit_start <- proc.time()[["elapsed"]]
  promises <- lapply(split$variants, function(variant) {
    mirai::mirai(
      {
        task <- .ledgr_e0_shared
        task[names(variant)] <- variant
        get(
          "ledgr_sweep_worker_eval_candidate_task",
          envir = asNamespace("ledgr")
        )(task)
      },
      variant = variant
    )
  })
  capture$submit_sec <- proc.time()[["elapsed"]] - submit_start
  points[[length(points) + 1L]] <- e0_memory_point(
    "after_submit", tasks = tasks, promises = promises
  )
  results <- vector("list", length(promises))
  collect_start <- proc.time()[["elapsed"]]
  for (i in seq_along(promises)) {
    results[[i]] <- promises[[i]][]
    if (inherits(results[[i]], "errorValue")) {
      stop(
        sprintf("Staged mirai task %s failed: %s", tasks[[i]]$run_id, results[[i]]),
        call. = FALSE
      )
    }
    points[[length(points) + 1L]] <- e0_memory_point(
      paste0("after_collect_", i), tasks, promises, results
    )
  }
  capture$collect_sec <- proc.time()[["elapsed"]] - collect_start
  cleanup_start <- proc.time()[["elapsed"]]
  cleanup_map <- mirai::everywhere(
    if (exists(".ledgr_e0_shared", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".ledgr_e0_shared", envir = .GlobalEnv)
    },
    .min = workers
  )
  invisible(cleanup_map[mirai::.flat])
  capture$stage_cleanup_sec <- proc.time()[["elapsed"]] - cleanup_start
  capture$retention <- do.call(rbind, points)
  results
}

e0_result_identity <- function(out, arm) {
  rows <- lapply(seq_len(nrow(out)), function(i) {
    candidate <- ledgr_candidate(out, out$candidate_id[[i]], allow_failed = TRUE)
    key <- ledgr_candidate_reproduction_key(candidate)
    key$source_sweep$sweep_id <- "<sweep-id>"
    data.frame(
      arm = arm,
      candidate_id = out$candidate_id[[i]],
      status = out$status[[i]],
      final_equity = sprintf("%.17g", out$final_equity[[i]]),
      total_return = sprintf("%.17g", out$total_return[[i]]),
      n_trades = as.integer(out$n_trades[[i]]),
      execution_seed = as.integer(out$execution_seed[[i]]),
      snapshot_hash = attr(out, "snapshot_hash"),
      strategy_hash = attr(out, "strategy_hash"),
      reproduction_key_hash = digest::digest(
        ledgr:::canonical_json(key), algo = "sha256", serialize = FALSE
      ),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

e0_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}
