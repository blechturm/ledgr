# Runs this cut's dispatch witnesses (tests/testthat/test-indicator-dispatch.R
# of --tests) against the package source at --tree, one test per line.
#   Rscript witness_on_tree.R --tree=<package source> --tests=<tree holding the witness file>
argv <- commandArgs(TRUE)
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
pkgload::load_all(arg("tree"), quiet = TRUE)
res <- as.data.frame(testthat::test_file(file.path(arg("tests"), "tests/testthat/test-indicator-dispatch.R"),
                                          reporter = "silent"))
res <- res[, c("test", "nb", "failed", "error", "skipped")]
res$result <- ifelse(res$error, "ERROR", ifelse(res$failed > 0, "FAIL", "PASS"))
cat("tree:", normalizePath(arg("tree"), winslash = "/"), "\n")
for (i in seq_len(nrow(res))) cat(sprintf("%-5s %3d expectations, %3d failed  %s\n",
  res$result[i], res$nb[i], res$failed[i], res$test[i]))
