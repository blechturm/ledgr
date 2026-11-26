# LDG-3270: the full test suite in the maintainer's default library (duckdb
# 2.0.1, mirai 2.7.4, nanonext 1.10.4), with the candidate library first on
# .libPaths() and R_LIBS so sweep worker processes load the same ledgr. No
# verification library: LDG-3267 removed the schema test's version pin.
#
#   Rscript full_tests.R --lib=<candidate library> --tree=<worktree>
argv <- commandArgs(TRUE)
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
lib <- normalizePath(arg("lib"), winslash = "/")
tree <- normalizePath(arg("tree"), winslash = "/")
.libPaths(c(lib, .libPaths()))
Sys.setenv(R_LIBS = paste(c(lib, Sys.getenv("R_LIBS")), collapse = ";"))
for (p in c("ledgr", "duckdb", "nanonext", "mirai")) {
  cat(p, as.character(utils::packageVersion(p)), find.package(p), "\n")
}
cat("tree", tree, "HEAD", system2("git", c("-C", tree, "rev-parse", "HEAD"), stdout = TRUE), "\n")
stopifnot(requireNamespace("mirai", quietly = TRUE))
pkgload::load_all(tree, quiet = TRUE)
res <- testthat::test_local(tree, reporter = "summary", load_package = "none", stop_on_failure = FALSE)
df <- as.data.frame(res)
cat(sprintf("\nFULL: %d files, %d tests, %d failed, %d errors, %d skipped\n",
  length(unique(df$file)), nrow(df), sum(df$failed > 0), sum(df$error), sum(df$skipped)))
