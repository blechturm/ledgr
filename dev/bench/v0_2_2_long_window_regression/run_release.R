args <- commandArgs(TRUE)
if (!length(args) || !identical(args[[1L]], "--release")) {
  stop("Release-only cases require the explicit --release flag.")
}
script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
if (length(args) >= 2L && identical(args[[2L]], "terminal")) {
  # Single-arm terminal-outcome fixture (LDG-2961): <repo> <out_dir> [--accept].
  status <- system2(file.path(R.home("bin"), "Rscript"), c(
    shQuote(file.path(script, "terminal_release.R")), "--release",
    shQuote(args[-(1:2)])
  ))
  quit(status = status)
}
suite <- file.path(script, "run_suite.R")
status <- system2(file.path(R.home("bin"), "Rscript"), c(
  shQuote(suite), shQuote(args[-1L]), "release", "--release"
))
quit(status = status)
