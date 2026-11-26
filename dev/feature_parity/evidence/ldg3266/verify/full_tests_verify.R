# LDG-3266: the full suite in an isolated verification
# library. verify-lib holds duckdb 2.0.0 (the golden schema fixtures' version),
# nanonext 1.10.4 and mirai 2.7.4 from the Posit Package Manager snapshot of
# 2026-11-20; it precedes the final ledgr library and the host library on
# .libPaths() and on R_LIBS, so sweep worker processes load the same set. The
# host's shared library is not changed.
verify <- "C:/Users/maxth/ledgr-wt/cut24-scratch/verify-lib"
lib <- "C:/Users/maxth/ledgr-wt/cut24-scratch/libs/final-add30fed"
.libPaths(c(verify, lib, .libPaths()))
Sys.setenv(R_LIBS = paste(c(verify, lib, Sys.getenv("R_LIBS")), collapse = ";"))
for (p in c("duckdb", "nanonext", "mirai")) {
  cat(p, as.character(utils::packageVersion(p)), find.package(p), "\n")
}
stopifnot(requireNamespace("mirai", quietly = TRUE))
pkgload::load_all("C:/Users/maxth/ledgr-wt/ws44", quiet = TRUE)
res <- testthat::test_local("C:/Users/maxth/ledgr-wt/ws44", reporter = "summary", load_package = "none", stop_on_failure = FALSE)
df <- as.data.frame(res)
cat(sprintf("\nFULL: %d files, %d tests, %d failed, %d errors, %d skipped\n",
  length(unique(df$file)), nrow(df), sum(df$failed > 0), sum(df$error), sum(df$skipped)))
