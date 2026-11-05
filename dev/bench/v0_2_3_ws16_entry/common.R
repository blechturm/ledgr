# Shared helpers for the WS16 cut-entry record. Every probe sources this file.
# The record measures the pinned reference build d5b3a151 (product-identical
# to cad309f4); it changes nothing in R/.

ws16_arg <- function(name, default = NULL) {
  args <- commandArgs(trailingOnly = TRUE)
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}

ws16_need <- function(name) {
  value <- ws16_arg(name)
  if (is.null(value)) stop("Missing --", name, "=.", call. = FALSE)
  value
}

ws16_here <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  normalizePath(dirname(sub("^--file=", "", file_arg[[1L]])), winslash = "/")
}

ws16_out <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

ws16_user_lib <- function() {
  # collapse 2.1.8 (the DESCRIPTION floor) resolves only from this library.
  user <- "C:/Users/maxth/AppData/Local/R/win-library/4.6"
  if (dir.exists(user)) .libPaths(unique(c(user, .libPaths())))
}

# An installed pinned build, for clocks and memory.
ws16_load_installed <- function(lib) {
  lib <- normalizePath(lib, winslash = "/", mustWork = TRUE)
  ws16_user_lib()
  .libPaths(unique(c(lib, .libPaths())))
  Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  suppressPackageStartupMessages(library(ledgr))
  if (!startsWith(normalizePath(find.package("ledgr"), winslash = "/"), lib)) {
    stop("ledgr was not loaded from ", lib, call. = FALSE)
  }
  marker <- file.path(lib, "LEDGR_INSTALLED_FROM_COMMIT")
  if (file.exists(marker)) readLines(marker, warn = FALSE)[[1L]] else NA_character_
}

# The pinned source tree, for probes that need internals and test helpers.
ws16_load_source <- function(pkg) {
  ws16_user_lib()
  suppressMessages(pkgload::load_all(pkg, quiet = TRUE, export_all = TRUE))
  desc <- file.path(pkg, "LEDGR_SOURCE_COMMIT")
  if (file.exists(desc)) readLines(desc, warn = FALSE)[[1L]] else NA_character_
}

# Replaces a namespace function with `make(orig)`; returns the original.
ws16_wrap <- function(name, make) {
  ns <- asNamespace("ledgr")
  orig <- get(name, envir = ns, inherits = FALSE)
  wrapped <- make(orig)
  unlockBinding(name, ns)
  assign(name, wrapped, envir = ns)
  lockBinding(name, ns)
  invisible(orig)
}

# Nearest ledgr function on the call stack outside the named set.
ws16_caller <- function(skip) {
  fns <- vapply(sys.calls(), function(cl) {
    f <- cl[[1L]]
    if (is.symbol(f)) return(as.character(f))
    if (is.call(f) && length(f) == 3L && as.character(f[[1L]]) %in% c(":::", "::")) {
      return(as.character(f[[3L]]))
    }
    ""
  }, character(1))
  hits <- rev(fns[startsWith(fns, "ledgr_") & !fns %in% skip])
  if (length(hits)) hits[[1L]] else "<direct>"
}

ws16_shape <- function(x) {
  paste0(paste(class(x), collapse = "/"), ":", typeof(x), "[",
         if (is.null(dim(x))) length(x) else paste(dim(x), collapse = "x"), "]")
}

ws16_bytes <- function(x) {
  if (is.environment(x)) {
    return(sum(vapply(as.list.environment(x, all.names = TRUE), ws16_bytes, numeric(1))))
  }
  if (is.function(x)) return(0)
  as.numeric(utils::object.size(x))
}

ws16_write <- function(df, path) {
  utils::write.csv(df, path, row.names = FALSE, na = "")
  invisible(path)
}
