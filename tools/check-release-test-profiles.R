args <- commandArgs(trailingOnly = TRUE)

value_arg <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
root <- normalizePath(file.path(dirname(script), ".."), winslash = "/")
source(file.path(root, "tests", "test-control-plane.R"), local = TRUE)

paths <- c(value_arg("fast-summary"), value_arg("review-summary"))
if (anyNA(paths) || any(!nzchar(paths)) || any(!file.exists(paths))) {
  stop("Both fast and review summary files are required.")
}
records <- do.call(rbind, lapply(paths, function(path) {
  row <- utils::read.csv(path, stringsAsFactors = FALSE)
  data.frame(
    profile = row$profile,
    passed = row$failed_blocks == 0L && row$executed_blocks == row$expected_blocks,
    stringsAsFactors = FALSE
  )
}))
ledgr_test_release_gate(records)
cat("LEDGR_RELEASE_TEST_PROFILES_OK profiles=fast,review\n")
