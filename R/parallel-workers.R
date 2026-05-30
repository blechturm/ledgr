ledgr_parallel_workers_normalize <- function(workers) {
  if (is.null(workers)) {
    workers <- 1L
  }
  if (!is.numeric(workers) ||
      length(workers) != 1L ||
      is.na(workers) ||
      !is.finite(workers) ||
      workers < 1 ||
      workers != as.integer(workers)) {
    rlang::abort(
      "`workers` must be a whole-number scalar greater than or equal to 1.",
      class = c("ledgr_invalid_parallel_workers", "ledgr_parallel_error")
    )
  }
  as.integer(workers)
}

ledgr_parallel_backend_available <- function(backend = "mirai") {
  backend <- ledgr_parallel_backend_normalize(backend)
  if (identical(backend, "mirai")) {
    return(requireNamespace("mirai", quietly = TRUE))
  }
  FALSE
}

ledgr_parallel_backend_normalize <- function(backend) {
  if (!is.character(backend) ||
      length(backend) != 1L ||
      is.na(backend) ||
      !nzchar(backend) ||
      !identical(backend, "mirai")) {
    rlang::abort(
      "`backend` must be \"mirai\".",
      class = c("ledgr_invalid_parallel_backend", "ledgr_parallel_error")
    )
  }
  backend
}

ledgr_parallel_require_backend <- function(workers,
                                           backend = "mirai",
                                           backend_available = NULL) {
  workers <- ledgr_parallel_workers_normalize(workers)
  backend <- ledgr_parallel_backend_normalize(backend)
  if (workers <= 1L) {
    return(invisible(FALSE))
  }
  if (is.null(backend_available)) {
    backend_available <- ledgr_parallel_backend_available(backend)
  }
  if (!isTRUE(backend_available)) {
    rlang::abort(
      paste0(
        "Parallel sweep with `workers > 1` requires optional package `mirai`. ",
        "Install it with `install.packages(\"mirai\")`, or run with `workers = 1`."
      ),
      class = c("ledgr_parallel_backend_missing", "ledgr_parallel_error")
    )
  }
  invisible(TRUE)
}

ledgr_parallel_normalize_worker_packages <- function(worker_packages,
                                                     arg = "`worker_packages`") {
  if (is.null(worker_packages)) {
    return(character())
  }
  if (!is.character(worker_packages)) {
    rlang::abort(
      sprintf("%s must be NULL or a character vector of package names.", arg),
      class = c("ledgr_invalid_worker_packages", "ledgr_parallel_error")
    )
  }
  worker_packages <- as.character(worker_packages)
  invalid <- is.na(worker_packages) | !nzchar(worker_packages)
  if (any(invalid)) {
    rlang::abort(
      sprintf("%s must not contain NA or empty package names.", arg),
      class = c("ledgr_invalid_worker_packages", "ledgr_parallel_error")
    )
  }
  sort(unique(worker_packages))
}

ledgr_parallel_worker_dependencies <- function(preflight,
                                               worker_packages = NULL) {
  if (!inherits(preflight, "ledgr_strategy_preflight")) {
    rlang::abort(
      "`preflight` must be a ledgr_strategy_preflight object.",
      class = c("ledgr_invalid_worker_dependencies", "ledgr_parallel_error")
    )
  }
  if (!isTRUE(preflight$allowed)) {
    rlang::abort(
      paste0(
        "Parallel worker setup requires a Tier 1 or Tier 2 strategy preflight. ",
        "Tier 3 strategies, including arbitrary `.GlobalEnv` helper calls, are unsupported on workers."
      ),
      class = c("ledgr_parallel_strategy_not_allowed", "ledgr_parallel_error")
    )
  }
  user_packages <- ledgr_parallel_normalize_worker_packages(worker_packages)
  qualified <- preflight$qualified_package_dependencies
  if (is.null(qualified)) {
    qualified <- preflight$package_dependencies %||% character()
  }
  attached <- preflight$attached_package_dependencies %||% character()
  qualified <- ledgr_parallel_normalize_worker_packages(
    qualified,
    arg = "`preflight$qualified_package_dependencies`"
  )
  attached <- ledgr_parallel_normalize_worker_packages(
    attached,
    arg = "`preflight$attached_package_dependencies`"
  )
  out <- list(
    require_namespace = qualified,
    attach = sort(unique(c(attached, user_packages))),
    user_packages = user_packages
  )
  out$all_packages <- sort(unique(c(out$require_namespace, out$attach)))
  structure(out, class = c("ledgr_worker_dependencies", "list"))
}

ledgr_parallel_check_worker_packages <- function(dependencies) {
  if (!inherits(dependencies, "ledgr_worker_dependencies")) {
    rlang::abort(
      "`dependencies` must be a ledgr_worker_dependencies object.",
      class = c("ledgr_invalid_worker_dependencies", "ledgr_parallel_error")
    )
  }
  for (pkg in dependencies$require_namespace) {
    ledgr_parallel_require_worker_package(pkg, mode = "requireNamespace")
  }
  for (pkg in dependencies$attach) {
    ledgr_parallel_require_worker_package(pkg, mode = "library")
  }
  invisible(TRUE)
}

ledgr_parallel_require_worker_package <- function(package,
                                                  mode = c("requireNamespace", "library")) {
  mode <- match.arg(mode)
  if (!requireNamespace(package, quietly = TRUE)) {
    rlang::abort(
      sprintf(
        "Worker package setup requires package `%s` for `%s`, but it is not installed. Install `%s` or remove it from worker dependencies.",
        package,
        mode,
        package
      ),
      class = c("ledgr_parallel_worker_package_missing", "ledgr_parallel_error")
    )
  }
  invisible(TRUE)
}

ledgr_parallel_worker_setup <- function(workers = 1L,
                                        preflight,
                                        worker_packages = NULL,
                                        backend = "mirai",
                                        backend_available = NULL,
                                        dry_run = TRUE) {
  workers <- ledgr_parallel_workers_normalize(workers)
  backend <- ledgr_parallel_backend_normalize(backend)
  dependencies <- ledgr_parallel_worker_dependencies(
    preflight = preflight,
    worker_packages = worker_packages
  )
  if (workers <= 1L) {
    return(ledgr_parallel_worker_setup_plan(
      workers = workers,
      backend = "sequential",
      dependencies = dependencies,
      ledgr_source_path = ledgr_parallel_ledgr_source_path(),
      initialized = FALSE,
      actions = "sequential"
    ))
  }

  ledgr_parallel_require_backend(
    workers = workers,
    backend = backend,
    backend_available = backend_available
  )
  ledgr_parallel_check_worker_packages(dependencies)
  source_path <- ledgr_parallel_ledgr_source_path()
  actions <- c(
    ledgr_parallel_ledgr_load_action(source_path),
    if (length(dependencies$require_namespace) > 0L) {
      paste0("requireNamespace:", dependencies$require_namespace)
    },
    if (length(dependencies$attach) > 0L) {
      paste0("library:", dependencies$attach)
    }
  )
  if (!isTRUE(dry_run)) {
    ledgr_parallel_mirai_start(workers)
    ledgr_parallel_mirai_everywhere_expr(
      ledgr_parallel_ledgr_load_expr(source_path),
      workers = workers
    )
    for (pkg in dependencies$attach) {
      ledgr_parallel_mirai_everywhere_expr(
        ledgr_parallel_worker_attach_expr(pkg),
        workers = workers
      )
    }
  }
  ledgr_parallel_worker_setup_plan(
    workers = workers,
    backend = backend,
    dependencies = dependencies,
    ledgr_source_path = source_path,
    initialized = !isTRUE(dry_run),
    actions = actions
  )
}

ledgr_parallel_worker_setup_plan <- function(workers,
                                             backend,
                                             dependencies,
                                             ledgr_source_path,
                                             initialized,
                                             actions) {
  structure(
    list(
      workers = workers,
      backend = backend,
      dependencies = dependencies,
      ledgr_source_path = ledgr_source_path,
      initialized = isTRUE(initialized),
      actions = as.character(actions)
    ),
    class = c("ledgr_parallel_worker_setup", "list")
  )
}

ledgr_parallel_ledgr_source_path <- function() {
  namespace_path <- tryCatch(getNamespaceInfo("ledgr", "path"), error = function(e) NULL)
  if (is.character(namespace_path) &&
      length(namespace_path) == 1L &&
      !is.na(namespace_path) &&
      nzchar(namespace_path)) {
    if (ledgr_parallel_is_source_package_path(namespace_path)) {
      return(normalizePath(namespace_path, winslash = "/", mustWork = FALSE))
    }
  }
  desc <- file.path(getwd(), "DESCRIPTION")
  if (!file.exists(desc)) {
    return(NULL)
  }
  if (ledgr_parallel_is_source_package_path(getwd())) {
    return(normalizePath(getwd(), winslash = "/", mustWork = FALSE))
  }
  NULL
}

ledgr_parallel_is_source_package_path <- function(path) {
  if (!is.character(path) ||
      length(path) != 1L ||
      is.na(path) ||
      !nzchar(path)) {
    return(FALSE)
  }
  desc <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc)) {
    return(FALSE)
  }
  first <- tryCatch(readLines(desc, n = 5L, warn = FALSE), error = function(e) character())
  if (!any(grepl("^Package: ledgr$", first))) {
    return(FALSE)
  }
  r_dir <- file.path(path, "R")
  dir.exists(r_dir) && length(list.files(r_dir, pattern = "[.][Rr]$", full.names = TRUE)) > 0L
}

ledgr_parallel_ledgr_load_action <- function(source_path) {
  if (is.character(source_path) &&
      length(source_path) == 1L &&
      !is.na(source_path) &&
      nzchar(source_path)) {
    return("pkgload::load_all")
  }
  "library:ledgr"
}

ledgr_parallel_ledgr_load_expr <- function(source_path) {
  substitute(
    {
      .ledgr_lib_paths <- LIB_PATHS
      if (is.character(.ledgr_lib_paths) && length(.ledgr_lib_paths) > 0L) {
        .libPaths(unique(c(.ledgr_lib_paths, .libPaths())))
      }
      .ledgr_source_path <- SOURCE_PATH
      if (is.character(.ledgr_source_path) &&
          length(.ledgr_source_path) == 1L &&
          nzchar(.ledgr_source_path) &&
          file.exists(file.path(.ledgr_source_path, "DESCRIPTION")) &&
          requireNamespace("pkgload", quietly = TRUE)) {
        pkgload::load_all(.ledgr_source_path, quiet = TRUE)
      } else {
        library(ledgr)
      }
      TRUE
    },
    list(SOURCE_PATH = source_path %||% "", LIB_PATHS = .libPaths())
  )
}

ledgr_parallel_worker_attach_expr <- function(package) {
  substitute(
    {
      .ledgr_worker_package <- PACKAGE
      if (!requireNamespace(.ledgr_worker_package, quietly = TRUE)) {
        stop(sprintf("Worker package `%s` is not installed.", .ledgr_worker_package), call. = FALSE)
      }
      do.call("library", list(.ledgr_worker_package, character.only = TRUE))
      TRUE
    },
    list(PACKAGE = package)
  )
}

ledgr_parallel_mirai_start <- function(workers) {
  daemons <- getExportedValue("mirai", "daemons")
  daemons(workers)
  invisible(TRUE)
}

ledgr_parallel_mirai_stop <- function() {
  daemons <- getExportedValue("mirai", "daemons")
  daemons(0L)
  invisible(TRUE)
}

ledgr_parallel_mirai_everywhere_expr <- function(expr, workers = 1L) {
  workers <- ledgr_parallel_workers_normalize(workers)
  everywhere <- getExportedValue("mirai", "everywhere")
  eval(substitute(FUN(EXPR, .min = WORKERS), list(FUN = everywhere, EXPR = expr, WORKERS = workers)))
  invisible(TRUE)
}
