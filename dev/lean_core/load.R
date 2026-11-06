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

lean_core_pin <- "d5b3a151"

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
