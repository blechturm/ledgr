# lean_core_load(lib, debug = FALSE): the pinned build plus one lean
# environment (interface table Section 17).
#
# `lib` is either the installed pinned library (it holds
# LEDGR_INSTALLED_FROM_COMMIT and the package directory ledgr/) or, for the
# test-suite capture, the pinned source archive (it holds LEDGR_SOURCE_COMMIT
# and is loaded with pkgload). Any other build is refused, and the loaded
# namespace must come from exactly that directory, before and after loading.
# The lean files of dev/lean_core/ (every *.R beside this file except load.R)
# are sourced into one environment whose parent is the ledgr namespace; it
# records `debug` as `.lean_debug` (not a public option).

# The reference build (lean fold core synthesis, Q2 pin record): the release
# head at Cut 26's close since Cut 27 (maintainer, 2026-11-27); d5b3a151
# before it.
lean_core_pin <- "7f65733f"

lean_core_dir <- function() {
  for (i in rev(seq_len(sys.nframe()))) {
    f <- sys.frame(i)$ofile
    if (is.character(f)) return(dirname(normalizePath(f, winslash = "/")))
  }
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg)) return(dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/")))
  stop("lean_core_dir: source load.R with source() or run it with Rscript", call. = FALSE)
}

# Captured at source time: the directory of this file.
lean_core_home <- lean_core_dir()

lean_core_load <- function(lib, debug = FALSE) {
  stopifnot(is.logical(debug), length(debug) == 1L, !is.na(debug))
  # The entry record's loaders: ws16_load_installed() and ws16_load_source().
  source(file.path(lean_core_home, "..", "bench", "v0_2_3_ws16_entry", "common.R"), local = TRUE)
  lib <- normalizePath(lib, winslash = "/", mustWork = TRUE)
  from_source <- file.exists(file.path(lib, "LEDGR_SOURCE_COMMIT"))
  origin <- if (from_source) lib else normalizePath(file.path(lib, "ledgr"), winslash = "/", mustWork = TRUE)
  loaded_from <- function() normalizePath(getNamespaceInfo("ledgr", "path"), winslash = "/")
  if ("ledgr" %in% loadedNamespaces() && !identical(loaded_from(), origin)) {
    stop("lean_core_load: ledgr is already loaded from ", loaded_from(), ", not ", origin, call. = FALSE)
  }
  commit <- if (from_source) ws16_load_source(lib) else ws16_load_installed(lib)
  if (!identical(loaded_from(), origin)) {
    stop("lean_core_load: ledgr was loaded from ", loaded_from(), ", not ", origin, call. = FALSE)
  }
  if (!identical(commit, lean_core_pin)) {
    stop("lean_core_load: ", lib, " is not the pinned build ", lean_core_pin,
         " (marker: ", commit, ")", call. = FALSE)
  }
  lean <- new.env(parent = asNamespace("ledgr"))
  lean$.lean_debug <- debug
  lean$.lean_pin <- commit
  lean$.lean_lib <- lib
  lean$.lean_home <- lean_core_home
  files <- setdiff(list.files(lean_core_home, pattern = "[.]R$", full.names = TRUE),
                   file.path(lean_core_home, "load.R"))
  for (f in sort(files, method = "radix")) sys.source(f, envir = lean, keep.source = FALSE)
  lean
}

# Sources further files (the recorder, a parity runner) into a lean
# environment, so they too see ledgr internals by name.
lean_core_source <- function(lean, files) {
  for (f in files) sys.source(f, envir = lean, keep.source = FALSE)
  invisible(lean)
}

# --- the harness boundary for sweep workers (Cut 26, LDG-3271) -------------
# The pin starts a sweep's workers with ledgr_parallel_worker_setup(); a
# worker loads the package the parent's namespace came from, unless that is
# an installed library and the working directory is a ledgr source package,
# in which case the worker pkgload::load_all()s the working directory
# (ledgr_parallel_ledgr_source_path(), R/parallel-workers.R:244-262). Run from
# a worktree, an installed-pin comparison therefore ran its workers on the
# worktree's source. Every runner that can start workers calls these two
# after resolving its own path arguments.

# Moves the working directory to a fresh directory that is not a ledgr source
# package (or to `control`, for the source-package control) and returns the
# old one. Relative paths given to the runner must be resolved before.
lean_harness_workdir <- function(control = NULL) {
  dir <- if (is.null(control)) {
    d <- tempfile("lean_harness_wd_")
    dir.create(d)
    d
  } else {
    normalizePath(control, winslash = "/", mustWork = TRUE)
  }
  invisible(setwd(dir))
}

# Records the ledgr namespace origin of every worker the pin starts, in either
# arm, against `declared` (the arm's pinned build: an installed library's
# ledgr/ directory or a source archive). Returns read(), which returns and
# clears the records since the last read: one row per worker setup with the
# number of workers started and the origins they reported.
lean_worker_origin_install <- function(declared) {
  declared <- normalizePath(declared, winslash = "/", mustWork = TRUE)
  ns <- asNamespace("ledgr")
  # One file per worker report, so concurrent workers never interleave.
  channel <- tempfile("lean_worker_origin_")
  dir.create(channel)
  inner <- get("ledgr_parallel_worker_setup", envir = ns)
  setups <- new.env(parent = emptyenv())
  setups$n <- integer()
  wrapped <- function(workers = 1L, preflight, worker_packages = NULL, backend = "mirai",
                      backend_available = NULL, dry_run = TRUE) {
    plan <- inner(workers = workers, preflight = preflight, worker_packages = worker_packages,
                  backend = backend, backend_available = backend_available, dry_run = dry_run)
    n <- ledgr_parallel_workers_normalize(workers)
    if (!isTRUE(dry_run) && n > 1L) {
      setups$n <- c(setups$n, n)
      ledgr_parallel_mirai_everywhere_expr(substitute(
        writeLines(normalizePath(getNamespaceInfo("ledgr", "path"), winslash = "/"),
                   tempfile(paste0(Sys.getpid(), "_"), tmpdir = CHANNEL)),
        list(CHANNEL = channel)), workers = n)
    }
    plan
  }
  environment(wrapped) <- list2env(list(inner = inner, setups = setups, channel = channel), parent = ns)
  unlockBinding("ledgr_parallel_worker_setup", ns)
  assign("ledgr_parallel_worker_setup", wrapped, envir = ns)
  lockBinding("ledgr_parallel_worker_setup", ns)
  list(
    declared = declared,
    read = function() {
      files <- list.files(channel, full.names = TRUE)
      origin <- vapply(files, function(f) paste(readLines(f, warn = FALSE), collapse = ""), "", USE.NAMES = FALSE)
      file.remove(files)
      out <- list(setups = setups$n, workers = sum(setups$n), reported = length(origin),
                  origins = unique(origin),
                  ok = length(origin) == sum(setups$n) && all(origin == declared))
      setups$n <- integer()
      out
    },
    restore = function() {
      unlockBinding("ledgr_parallel_worker_setup", ns)
      assign("ledgr_parallel_worker_setup", inner, envir = ns)
      lockBinding("ledgr_parallel_worker_setup", ns)
    }
  )
}

# The build a harness arm declares, and its label: an installed library's
# ledgr/ directory ("installed pin"), or a pinned source archive loaded with
# pkgload ("source pin"; its workers load that archive as source).
lean_declared_origin <- function(lib) {
  lib <- normalizePath(lib, winslash = "/", mustWork = TRUE)
  if (file.exists(file.path(lib, "LEDGR_SOURCE_COMMIT"))) list(path = lib, label = "source pin")
  else list(path = file.path(lib, "ledgr"), label = "installed pin")
}
