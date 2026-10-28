compiler_spike_args <- function(args) {
  out <- list(
    preset = "smoke",
    output = NULL,
    gut = "",
    benchmarks = TRUE,
    verify_gut = FALSE
  )
  i <- 1L
  while (i <= length(args)) {
    if (args[[i]] == "--preset") {
      i <- i + 1L
      out$preset <- args[[i]]
    } else if (args[[i]] == "--output") {
      i <- i + 1L
      out$output <- args[[i]]
    } else if (args[[i]] == "--gut") {
      i <- i + 1L
      out$gut <- args[[i]]
    } else if (args[[i]] == "--no-bench") {
      out$benchmarks <- FALSE
    } else if (args[[i]] == "--verify-gut") {
      out$verify_gut <- TRUE
    } else {
      stop("Unknown argument: ", args[[i]], call. = FALSE)
    }
    i <- i + 1L
  }
  if (!out$preset %in% c("smoke", "record")) {
    stop("`--preset` must be smoke or record.", call. = FALSE)
  }
  out
}

compiler_spike_environment <- function(compiled) {
  package_version <- function(package) {
    if (requireNamespace(package, quietly = TRUE)) {
      as.character(utils::packageVersion(package))
    } else {
      NA_character_
    }
  }
  compiler_line <- function(command) {
    path <- Sys.which(command)
    if (!nzchar(path)) {
      return(NA_character_)
    }
    output <- tryCatch(system2(path, "--version", stdout = TRUE, stderr = TRUE), error = identity)
    if (inherits(output, "condition") || !length(output)) NA_character_ else output[[1L]]
  }
  r_config <- function(key) {
    output <- tryCatch(
      system2(file.path(R.home("bin"), "R"), c("CMD", "config", key), stdout = TRUE, stderr = TRUE),
      error = identity
    )
    if (inherits(output, "condition") || !length(output)) NA_character_ else output[[1L]]
  }
  data.frame(
    recorded_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    r_version = R.version.string,
    platform = R.version$platform,
    os = paste(Sys.info()[c("sysname", "release", "version")], collapse = " "),
    cpu = Sys.getenv("PROCESSOR_IDENTIFIER", unset = NA_character_),
    blas = normalizePath(file.path(R.home("bin"), "Rblas.dll"), winslash = "/", mustWork = FALSE),
    lapack = normalizePath(file.path(R.home("bin"), "Rlapack.dll"), winslash = "/", mustWork = FALSE),
    gcc = compiler_line("gcc"),
    gxx = compiler_line("g++"),
    gfortran = compiler_line("gfortran"),
    cflags = r_config("CFLAGS"),
    cxxflags = r_config("CXXFLAGS"),
    fflags = r_config("FFLAGS"),
    omp_num_threads = Sys.getenv("OMP_NUM_THREADS", unset = NA_character_),
    bench_version = package_version("bench"),
    rcpp_version = package_version("Rcpp"),
    quickr_version = package_version("quickr"),
    ast2ast_version = package_version("ast2ast"),
    ncompiler_version = package_version("nCompiler"),
    stringsAsFactors = FALSE
  )
}

compiler_spike_source_files <- function(root) {
  for (file in list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)) {
    sys.source(file, envir = .GlobalEnv)
  }
  sys.source(file.path(root, "tests", "test-correctness.R"), envir = .GlobalEnv)
  sys.source(file.path(root, "benchmarks", "run-benchmarks.R"), envir = .GlobalEnv)
}

compiler_spike_main <- function(args, root) {
  options(warn = 1)
  spike_library <- Sys.getenv("LEDGR_COMPILER_SPIKE_LIB")
  if (nzchar(spike_library)) {
    .libPaths(c(spike_library, .libPaths()))
  }
  parsed <- compiler_spike_args(args)
  if (is.null(parsed$output)) {
    parsed$output <- file.path(root, "results", "local")
  }
  dir.create(parsed$output, recursive = TRUE, showWarnings = FALSE)
  Sys.setenv(OMP_NUM_THREADS = "4", OMP_THREAD_LIMIT = "4", OMP_DYNAMIC = "FALSE")

  compiler_spike_source_files(root)
  environment <- compiler_spike_environment(NULL)
  compiled <- compiler_spike_compile_all(root)
  correctness <- compiler_spike_run_correctness(compiled, gut = parsed$gut)

  utils::write.csv(compiled$status, file.path(parsed$output, "compiler_status.csv"), row.names = FALSE)
  utils::write.csv(compiled$compilation, file.path(parsed$output, "compilation.csv"), row.names = FALSE)
  utils::write.csv(correctness, file.path(parsed$output, "correctness.csv"), row.names = FALSE)
  utils::write.csv(
    environment,
    file.path(parsed$output, "environment.csv"),
    row.names = FALSE
  )

  failures <- correctness$status == "fail"
  if (any(failures)) {
    stop(
      "Correctness failed for: ",
      paste(paste(correctness$case[failures], correctness$variant[failures], sep = "/"), collapse = ", "),
      call. = FALSE
    )
  }

  if (parsed$verify_gut) {
    gutted <- compiler_spike_run_correctness(compiled, gut = "stateful")
    detected <- gutted$status == "fail" & gutted$workload == "stateful" & gutted$variant == "rcpp"
    if (!any(detected)) {
      stop("The deliberate stateful Rcpp gut was not detected.", call. = FALSE)
    }
    utils::write.csv(gutted, file.path(parsed$output, "gutted_correctness.csv"), row.names = FALSE)
  }

  if (parsed$benchmarks) {
    benchmark <- compiler_spike_run_benchmarks(compiled, parsed$preset)
    utils::write.csv(benchmark, file.path(parsed$output, "benchmarks.csv"), row.names = FALSE)
  }
  invisible(parsed$output)
}

if (sys.nframe() == 0L) {
  command <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", command, value = TRUE)
  script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/")
  compiler_spike_main(commandArgs(trailingOnly = TRUE), dirname(script))
}
