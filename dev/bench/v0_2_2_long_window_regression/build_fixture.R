args <- commandArgs(TRUE)
if (length(args) != 3L) {
  stop("Usage: build_fixture.R <repo> <shape_id> <out_dir>")
}
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
shape_id <- args[[2L]]
out_dir <- args[[3L]]
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
source(file.path(dirname(normalizePath(script, winslash = "/")), "helpers.R"))
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
row <- lwreg_shape(shape_id)
probe <- lwreg_build_fixture(row, out_dir)
cat("FIXTURE_OK", shape_id, probe$bar_rows, "bars\n")
