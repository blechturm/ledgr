compiler_spike_bench_one <- function(
  workload,
  variant,
  fn,
  args,
  dimensions,
  iterations,
  data_prepare_sec,
  compile_sec
) {
  fn_call <- function() do.call(fn, args)
  invisible(fn_call())
  marked <- bench::mark(
    fn_call(),
    iterations = iterations,
    check = FALSE,
    memory = TRUE,
    filter_gc = FALSE
  )
  data.frame(
    workload = workload,
    variant = variant,
    n_sessions = dimensions$n_sessions,
    n_instruments = dimensions$n_instruments,
    lookback = dimensions$lookback,
    n_configs = dimensions$n_configs,
    iterations = iterations,
    data_prepare_sec = data_prepare_sec,
    compile_sec = compile_sec,
    median_sec = as.numeric(marked$median[[1L]]),
    min_sec = as.numeric(marked$min[[1L]]),
    mem_alloc_bytes = as.numeric(marked$mem_alloc[[1L]]),
    compile_prepare_median_sec = compile_sec + data_prepare_sec +
      as.numeric(marked$median[[1L]]),
    measurement_status = "measured",
    stringsAsFactors = FALSE
  )
}

compiler_spike_compile_cost <- function(compilation, workload, variant) {
  key <- if (variant == "rcpp") {
    "rcpp_bundle"
  } else if (variant == "quickr") {
    paste0("quickr_", workload)
  } else if (variant == "quickr_openmp") {
    "quickr_batch_parallel"
  } else if (variant == "ast2ast") {
    paste0("ast2ast_", workload)
  } else if (variant == "ncompiler") {
    paste0("ncompiler_", workload)
  } else {
    NA_character_
  }
  if (is.na(key) || !nrow(compilation)) {
    return(0)
  }
  value <- compilation$compile_sec[compilation$compiler == key]
  if (length(value)) value[[1L]] else 0
}

compiler_spike_iterations <- function(size, preset) {
  if (preset == "smoke") {
    return(3L)
  }
  if (size >= 1e7) {
    return(1L)
  }
  if (size >= 1e6) {
    return(3L)
  }
  5L
}

compiler_spike_run_benchmarks <- function(compiled, preset = "smoke") {
  stopifnot(preset %in% c("smoke", "record"))
  rows <- list()
  add <- function(x) rows[[length(rows) + 1L]] <<- x

  numerical_grid <- if (preset == "smoke") {
    expand.grid(
      n_sessions = c(252L, 1260L),
      n_instruments = 100L,
      lookback = c(20L, 63L),
      KEEP.OUT.ATTRS = FALSE
    )
  } else {
    expand.grid(
      n_sessions = c(252L, 1260L, 2520L),
      n_instruments = c(10L, 100L, 500L),
      lookback = c(5L, 20L, 63L, 252L),
      KEEP.OUT.ATTRS = FALSE
    )
  }
  numerical_grid <- numerical_grid[numerical_grid$lookback <= numerical_grid$n_sessions, ]
  for (i in seq_len(nrow(numerical_grid))) {
    shape <- numerical_grid[i, ]
    started <- proc.time()
    x <- compiler_spike_make_matrix(shape$n_sessions, shape$n_instruments, 100L + i)
    prep <- compiler_spike_elapsed(started)
    for (variant in names(compiled$variants$numerical)) {
      add(compiler_spike_bench_one(
        "numerical",
        variant,
        compiled$variants$numerical[[variant]],
        list(x, as.integer(shape$lookback)),
        list(
          n_sessions = shape$n_sessions,
          n_instruments = shape$n_instruments,
          lookback = shape$lookback,
          n_configs = NA_integer_
        ),
        compiler_spike_iterations(length(x), preset),
        prep,
        compiler_spike_compile_cost(compiled$compilation, "numerical", variant)
      ))
    }
  }

  stateful_sessions <- if (preset == "smoke") c(252L, 1260L) else c(252L, 1260L, 2520L)
  for (i in seq_along(stateful_sessions)) {
    n_sessions <- stateful_sessions[[i]]
    started <- proc.time()
    x <- compiler_spike_make_stateful_data(n_sessions, 200L + i)
    prep <- compiler_spike_elapsed(started)
    args <- list(x$prices, x$signals, 1e6, 0.001, 0.9)
    for (variant in names(compiled$variants$stateful)) {
      add(compiler_spike_bench_one(
        "stateful",
        variant,
        compiled$variants$stateful[[variant]],
        args,
        list(
          n_sessions = n_sessions,
          n_instruments = 1L,
          lookback = NA_integer_,
          n_configs = 1L
        ),
        compiler_spike_iterations(n_sessions, preset),
        prep,
        compiler_spike_compile_cost(compiled$compilation, "stateful", variant)
      ))
    }
  }

  batch_grid <- if (preset == "smoke") {
    expand.grid(
      n_sessions = 252L,
      n_configs = c(1L, 10L, 100L, 1000L),
      KEEP.OUT.ATTRS = FALSE
    )
  } else {
    expand.grid(
      n_sessions = c(252L, 1260L),
      n_configs = c(1L, 10L, 100L, 1000L, 10000L),
      KEEP.OUT.ATTRS = FALSE
    )
  }
  for (i in seq_len(nrow(batch_grid))) {
    shape <- batch_grid[i, ]
    size <- shape$n_sessions * shape$n_configs
    started <- proc.time()
    x <- compiler_spike_make_batch_data(shape$n_sessions, shape$n_configs, 300L + i)
    prep <- compiler_spike_elapsed(started)
    args <- list(x$prices, x$signals, 1e6, 0.001, x$equity_fractions)
    for (variant in names(compiled$variants$batch)) {
      add(compiler_spike_bench_one(
        "batch",
        variant,
        compiled$variants$batch[[variant]],
        args,
        list(
          n_sessions = shape$n_sessions,
          n_instruments = 1L,
          lookback = NA_integer_,
          n_configs = shape$n_configs
        ),
        compiler_spike_iterations(size, preset),
        prep,
        compiler_spike_compile_cost(compiled$compilation, "batch", variant)
      ))
    }
    rm(x)
    gc(verbose = FALSE)
  }

  masked_shapes <- if (preset == "smoke") {
    list(c(252L, 100L))
  } else {
    list(c(252L, 10L), c(1260L, 100L), c(2520L, 500L))
  }
  for (i in seq_along(masked_shapes)) {
    shape <- masked_shapes[[i]]
    started <- proc.time()
    x <- compiler_spike_make_matrix(shape[[1L]], shape[[2L]], 400L + i)
    valid <- matrix(1L, nrow(x), ncol(x))
    valid[seq.int(7L, length(valid), by = 29L)] <- 0L
    x[valid == 0L] <- 777
    prep <- compiler_spike_elapsed(started)
    for (variant in names(compiled$variants$masked)) {
      add(compiler_spike_bench_one(
        "masked",
        variant,
        compiled$variants$masked[[variant]],
        list(x, valid),
        list(
          n_sessions = shape[[1L]],
          n_instruments = shape[[2L]],
          lookback = NA_integer_,
          n_configs = NA_integer_
        ),
        compiler_spike_iterations(length(x), preset),
        prep,
        compiler_spike_compile_cost(compiled$compilation, "masked", variant)
      ))
    }
  }

  result <- do.call(rbind, rows)
  result$speedup_vs_base_r <- NA_real_
  keys <- paste(
    result$workload,
    result$n_sessions,
    result$n_instruments,
    ifelse(is.na(result$lookback), "NA", result$lookback),
    ifelse(is.na(result$n_configs), "NA", result$n_configs),
    sep = "/"
  )
  for (key in unique(keys)) {
    idx <- which(keys == key)
    baseline <- result$median_sec[idx[result$variant[idx] == "base_r"]]
    if (length(baseline) == 1L) {
      result$speedup_vs_base_r[idx] <- baseline / result$median_sec[idx]
    }
  }
  result
}
