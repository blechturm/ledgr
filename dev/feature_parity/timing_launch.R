# Starts the shared timing runner (or any R script) with TMPDIR, TMP and TEMP
# pointed at a scratch directory, so the runner's tempdir() (its arm
# libraries, overlay and slot work) is created there and not under
# AppData/Local/Temp. The child inherits this process's environment and
# processor affinity; its exit status is returned.
#
#   Rscript timing_launch.R --tmp=<scratch dir> <script> <script args...>
local({
  argv <- commandArgs(TRUE)
  if (!length(argv) || !startsWith(argv[[1L]], "--tmp=")) stop("usage: timing_launch.R --tmp=<dir> <script> <args...>")
  tmp <- sub("^--tmp=", "", argv[[1L]])
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  tmp <- normalizePath(tmp, winslash = "\\")
  Sys.setenv(TMPDIR = tmp, TMP = tmp, TEMP = tmp)
  status <- system2(file.path(R.home("bin"), "Rscript.exe"), argv[-1L])
  quit(save = "no", status = as.integer(status))
})
