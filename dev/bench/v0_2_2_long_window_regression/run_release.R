args <- commandArgs(TRUE)
if (!length(args) || !identical(args[[1L]], "--release")) {
  stop("Release-only cases require the explicit --release flag.")
}
script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
suite <- file.path(script, "run_suite.R")
status <- system2(file.path(R.home("bin"), "Rscript"), c(
  shQuote(suite), shQuote(args[-1L]), "release", "--release"
))
quit(status = status)
