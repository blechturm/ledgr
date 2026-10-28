command <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", command, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/")
root <- dirname(script)
source(file.path(root, "spike_runner.R"))

output <- file.path(tempdir(), "ledgr-compiler-spike-probe")
compiler_spike_main(
  c("--preset", "smoke", "--output", output, "--verify-gut"),
  root
)
cat("Probe evidence:", normalizePath(output, winslash = "/"), "\n")
