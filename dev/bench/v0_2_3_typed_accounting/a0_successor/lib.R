# Successor to the historical A0 output freeze. It reuses that harness but
# restores the pre-Cut-7 opening default only for the two fixtures that omit
# an opening. Product code receives an explicit ledgr_opening() object.

successor_here <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
}

successor_load <- function() {
  here <- normalizePath(successor_here(), winslash = "/")
  old <- normalizePath(file.path(here, "..", "..", "v0_2_3_output_freeze"), winslash = "/")
  source(file.path(old, "lib.R"), local = .GlobalEnv)
  pkg <- a0_arg(
    "pkg",
    normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
  )
  suppressMessages(pkgload::load_all(pkg, quiet = TRUE))

  add_opening <- function(fixture) {
    force(fixture)
    function(db_path) {
      original <- get("ledgr_experiment", envir = .GlobalEnv, inherits = TRUE)
      existed <- exists("ledgr_experiment", envir = .GlobalEnv, inherits = FALSE)
      previous <- if (existed) get("ledgr_experiment", envir = .GlobalEnv) else NULL
      assign(
        "ledgr_experiment",
        function(..., opening = NULL) {
          if (is.null(opening)) opening <- ledgr_opening(cash = 100000)
          original(..., opening = opening)
        },
        envir = .GlobalEnv
      )
      on.exit({
        if (existed) {
          assign("ledgr_experiment", previous, envir = .GlobalEnv)
        } else {
          rm("ledgr_experiment", envir = .GlobalEnv)
        }
      }, add = TRUE)
      fixture(db_path)
    }
  }
  for (id in c("avail_incomplete", "failures")) {
    a0_workloads[[id]]$fixture <<- add_opening(a0_workloads[[id]]$fixture)
  }
  invisible(pkg)
}
