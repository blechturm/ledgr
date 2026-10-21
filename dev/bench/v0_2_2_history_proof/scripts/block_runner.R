# Usage: Rscript block_runner.R <pkg_root> <LTB-a,LTB-b> <file1> [file2 ...]
# Runs the named [LTB] blocks of the given test files and prints one line per
# block: BLOCK|<id>|pass|<n expectations> or BLOCK|<id>|fail|<failed>|<error>.
args <- commandArgs(TRUE)
root <- args[[1L]]
blocks <- strsplit(args[[2L]], ",", fixed = TRUE)[[1L]]
files <- args[-(1:2)]
suppressMessages(pkgload::load_all(root, quiet = TRUE, helpers = FALSE))
pattern <- paste0("^\\[(", paste(blocks, collapse = "|"), ")\\]")
seen <- character()
for (f in files) {
  res <- testthat::test_file(
    file.path(root, "tests", "testthat", f),
    reporter = "silent",
    load_package = "none",
    stop_on_failure = FALSE,
    package = "ledgr",
    desc = NULL
  )
  df <- as.data.frame(res)
  df <- df[grepl(pattern, df$test), , drop = FALSE]
  for (i in seq_len(nrow(df))) {
    id <- sub("^\\[(LTB-[0-9]+)\\].*$", "\\1", df$test[[i]])
    seen <- c(seen, id)
    bad <- df$failed[[i]] > 0 || isTRUE(df$error[[i]])
    cat(sprintf("BLOCK|%s|%s|%d|%d|%s\n", id, if (bad) "fail" else "pass",
      df$nb[[i]], df$failed[[i]], if (isTRUE(df$error[[i]])) "error" else ""))
  }
}
for (id in setdiff(blocks, seen)) cat(sprintf("BLOCK|%s|missing|0|0|\n", id))
