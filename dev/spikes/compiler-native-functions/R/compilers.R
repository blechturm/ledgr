compiler_spike_elapsed <- function(start) {
  unname((proc.time() - start)[["elapsed"]])
}

compiler_spike_condition <- function(x) {
  paste(strsplit(conditionMessage(x), "\n", fixed = TRUE)[[1L]], collapse = " | ")
}

compiler_spike_timed_compile <- function(name, compile, first_call) {
  started <- proc.time()
  fn <- compile()
  compiled <- proc.time()
  value <- first_call(fn)
  finished <- proc.time()
  list(
    fn = fn,
    first_value = value,
    record = data.frame(
      compiler = name,
      compile_sec = unname((compiled - started)[["elapsed"]]),
      first_execution_sec = unname((finished - compiled)[["elapsed"]]),
      compile_plus_first_sec = unname((finished - started)[["elapsed"]]),
      stringsAsFactors = FALSE
    )
  )
}

compiler_spike_special_quickr_source <- function() {
  function(x) {
    declare(type(x = double(NA)))
    out <- double(length(x))
    for (i in seq_along(x)) {
      out[i] <- x[i]
    }
    out
  }
}

compiler_spike_special_ast2ast_source <- function() {
  function(x) {
    argtypes(x |> type(vec(double)))
    out <- numeric(length(x))
    for (i in 1L:length(x)) {
      out[i] <- x[i]
    }
    return(out)
  }
}

compiler_spike_ncompiler_stateful_source <- function() {
  function(prices, signals, initial_cash, cost_rate, equity_fraction) {
    n <- length(prices)
    out <- numeric(n + 3L)
    cash <- initial_cash
    holdings <- 0.0
    total_cost <- 0.0
    for (i in 1:n) {
      equity_before <- cash + holdings * prices[i]
      target <- 0.0
      if (signals[i] > 0.5) {
        target <- floor(equity_before * equity_fraction / prices[i])
      }
      quantity <- target - holdings
      cost <- abs(quantity) * prices[i] * cost_rate
      cash <- cash - quantity * prices[i] - cost
      holdings <- target
      total_cost <- total_cost + cost
      out[i] <- cash + holdings * prices[i]
    }
    out[n + 1L] <- cash
    out[n + 2L] <- holdings
    out[n + 3L] <- total_cost
    return(out)
  }
}

compiler_spike_compile_all <- function(root) {
  status <- list()
  compilation <- list()
  variants <- list(
    numerical = list(
      base_r = rolling_variance_reference,
      vectorized_r = rolling_variance_vectorized
    ),
    stateful = list(base_r = stateful_reference),
    batch = list(
      base_r = batch_repeated_reference,
      vectorized_r = batch_matrix_r
    ),
    masked = list(base_r = masked_row_mean_reference),
    special = list(base_r = identity)
  )

  record_status <- function(compiler, available, detail, version = NA_character_) {
    status[[length(status) + 1L]] <<- data.frame(
      compiler = compiler,
      available = available,
      version = version,
      detail = detail,
      stringsAsFactors = FALSE
    )
  }

  rcpp_env <- new.env(parent = baseenv())
  rcpp_result <- tryCatch({
    started <- proc.time()
    Rcpp::sourceCpp(
      file.path(root, "src", "reference.cpp"),
      env = rcpp_env,
      rebuild = TRUE,
      showOutput = FALSE,
      verbose = FALSE
    )
    compiled <- proc.time()
    sample <- compiler_spike_make_stateful_data(32L)
    rcpp_env$stateful_rcpp(sample$prices, sample$signals, 1e6, 0.001, 0.95)
    finished <- proc.time()
    compilation[[length(compilation) + 1L]] <- data.frame(
      compiler = "rcpp_bundle",
      compile_sec = unname((compiled - started)[["elapsed"]]),
      first_execution_sec = unname((finished - compiled)[["elapsed"]]),
      compile_plus_first_sec = unname((finished - started)[["elapsed"]]),
      stringsAsFactors = FALSE
    )
    variants$numerical$rcpp <- rcpp_env$rolling_variance_rcpp
    variants$stateful$rcpp <- rcpp_env$stateful_rcpp
    variants$batch$rcpp <- rcpp_env$batch_rcpp
    variants$masked$rcpp <- rcpp_env$masked_row_mean_rcpp
    variants$special$rcpp <- rcpp_env$special_values_rcpp
    record_status("rcpp", TRUE, "sourceCpp bundle compiled", as.character(utils::packageVersion("Rcpp")))
    TRUE
  }, error = function(e) {
    record_status("rcpp", FALSE, compiler_spike_condition(e))
    FALSE
  })

  if (requireNamespace("quickr", quietly = TRUE)) {
    quick_specs <- list(
      numerical = list(
        source = rolling_variance_quickr_source,
        first = function(fn) fn(compiler_spike_make_matrix(32L, 3L), 5L)
      ),
      stateful = list(
        source = stateful_quickr_source,
        first = function(fn) {
          x <- compiler_spike_make_stateful_data(32L)
          fn(x$prices, x$signals, 1e6, 0.001, 0.95)
        }
      ),
      batch = list(
        source = batch_quickr_source,
        first = function(fn) {
          x <- compiler_spike_make_batch_data(32L, 3L)
          fn(x$prices, x$signals, 1e6, 0.001, x$equity_fractions)
        }
      ),
      batch_parallel = list(
        target = "batch",
        source = batch_quickr_parallel_source,
        first = function(fn) {
          x <- compiler_spike_make_batch_data(32L, 3L)
          fn(x$prices, x$signals, 1e6, 0.001, x$equity_fractions)
        }
      ),
      masked = list(
        source = masked_row_mean_quickr_source,
        first = function(fn) fn(matrix(1:12, 4L, 3L) + 0, matrix(1L, 4L, 3L))
      ),
      special = list(
        source = compiler_spike_special_quickr_source,
        first = function(fn) fn(c(1, 2, 3))
      )
    )
    failures <- character()
    for (name in names(quick_specs)) {
      spec <- quick_specs[[name]]
      one <- tryCatch(
        compiler_spike_timed_compile(
          paste0("quickr_", name),
          function() quickr::quick(spec$source()),
          spec$first
        ),
        error = identity
      )
      if (inherits(one, "condition")) {
        failures <- c(failures, paste0(name, ": ", compiler_spike_condition(one)))
      } else {
        target <- if (is.null(spec$target)) name else spec$target
        variant_name <- if (name == "batch_parallel") "quickr_openmp" else "quickr"
        variants[[target]][[variant_name]] <- one$fn
        compilation[[length(compilation) + 1L]] <- one$record
      }
    }
    record_status(
      "quickr",
      length(failures) == 0L,
      if (length(failures)) paste(failures, collapse = " || ") else "all six functions compiled",
      as.character(utils::packageVersion("quickr"))
    )
  } else {
    record_status("quickr", FALSE, "package not installed")
  }

  if (requireNamespace("ast2ast", quietly = TRUE)) {
    ast_specs <- list(
      numerical = list(
        source = rolling_variance_ast2ast_source,
        first = function(fn) fn(compiler_spike_make_matrix(32L, 3L), 5L)
      ),
      stateful = list(
        source = stateful_ast2ast_source,
        first = function(fn) {
          x <- compiler_spike_make_stateful_data(32L)
          fn(x$prices, x$signals, 1e6, 0.001, 0.95)
        }
      ),
      batch = list(
        source = batch_ast2ast_source,
        first = function(fn) {
          x <- compiler_spike_make_batch_data(32L, 3L)
          fn(x$prices, x$signals, 1e6, 0.001, x$equity_fractions)
        }
      ),
      masked = list(
        source = masked_row_mean_ast2ast_source,
        first = function(fn) fn(matrix(1:12, 4L, 3L) + 0, matrix(1L, 4L, 3L))
      ),
      special = list(
        source = compiler_spike_special_ast2ast_source,
        first = function(fn) fn(c(1, 2, 3))
      )
    )
    failures <- character()
    for (name in names(ast_specs)) {
      spec <- ast_specs[[name]]
      one <- tryCatch(
        compiler_spike_timed_compile(
          paste0("ast2ast_", name),
          function() ast2ast::translate(spec$source()),
          spec$first
        ),
        error = identity
      )
      if (inherits(one, "condition")) {
        failures <- c(failures, paste0(name, ": ", compiler_spike_condition(one)))
      } else {
        variants[[name]]$ast2ast <- one$fn
        compilation[[length(compilation) + 1L]] <- one$record
      }
    }
    record_status(
      "ast2ast",
      length(failures) == 0L,
      if (length(failures)) paste(failures, collapse = " || ") else "all five functions compiled",
      as.character(utils::packageVersion("ast2ast"))
    )
  } else {
    record_status("ast2ast", FALSE, "package not installed")
  }

  if (
    requireNamespace("nCompiler", quietly = TRUE) &&
      identical(Sys.getenv("LEDGR_COMPILER_SPIKE_NCOMPILER"), "1")
  ) {
    one <- tryCatch(
      compiler_spike_timed_compile(
        "ncompiler_stateful",
        function() {
          nf <- nCompiler::nFunction(
            fun = compiler_spike_ncompiler_stateful_source(),
            argTypes = list(
              prices = "numericVector",
              signals = "numericVector",
              initial_cash = "numericScalar",
              cost_rate = "numericScalar",
              equity_fraction = "numericScalar"
            ),
            returnType = "numericVector"
          )
          nCompiler::nCompile(nf)
        },
        function(fn) {
          x <- compiler_spike_make_stateful_data(32L)
          fn(x$prices, x$signals, 1e6, 0.001, 0.95)
        }
      ),
      error = identity
    )
    if (inherits(one, "condition")) {
      record_status(
        "nCompiler",
        FALSE,
        paste("installed, but stateful compilation failed:", compiler_spike_condition(one)),
        as.character(utils::packageVersion("nCompiler"))
      )
    } else {
      variants$stateful$ncompiler <- one$fn
      compilation[[length(compilation) + 1L]] <- one$record
      record_status(
        "nCompiler",
        TRUE,
        "secondary stateful function compiled",
        as.character(utils::packageVersion("nCompiler"))
      )
    }
  } else if (requireNamespace("nCompiler", quietly = TRUE)) {
    record_status(
      "nCompiler",
      FALSE,
      paste(
        "installed; opt-in compile disabled after the Windows/R 4.6.1 probe",
        "failed while building generated Eigen tensor support; set",
        "LEDGR_COMPILER_SPIKE_NCOMPILER=1 to retry"
      ),
      as.character(utils::packageVersion("nCompiler"))
    )
  } else {
    record_status("nCompiler", FALSE, "package not installed")
  }

  list(
    variants = variants,
    status = do.call(rbind, status),
    compilation = if (length(compilation)) do.call(rbind, compilation) else data.frame()
  )
}
