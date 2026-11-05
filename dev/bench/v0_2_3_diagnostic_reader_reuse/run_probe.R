args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: run_probe.R <base-source-root> <candidate-source-root> <output-dir>")
base_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
candidate_root <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
output_dir <- normalizePath(args[[3L]], winslash = "/", mustWork = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
script_dir <- dirname(normalizePath(sub("^--file=", "", file_arg), winslash = "/"))
run <- function(script, arguments) {
  output <- system2(rscript, c(file.path(script_dir, script), arguments), stdout = TRUE, stderr = TRUE)
  cat(output, sep = "\n")
  code <- attr(output, "status"); if (is.null(code)) code <- 0L
  if (code != 0L) stop(script, " failed with exit status ", code)
}
arms <- list(base = base_root, candidate = candidate_root)
for (label in names(arms)) {
  run("build_run.R", c(arms[[label]], output_dir, label))
  build <- file.path(output_dir, paste0(label, "-build.csv"))
  for (surface in c("print", "summary", "point_explain", "history_explain", "diagnostics", "metrics")) {
    run("measure_surface.R", c(arms[[label]], build, surface, file.path(output_dir, paste0(label, "-", surface, ".csv"))))
  }
}
surface_files <- list.files(output_dir, pattern = "-(print|summary|point_explain|history_explain|diagnostics|metrics)\\.csv$", full.names = TRUE)
summary <- do.call(rbind, lapply(surface_files, utils::read.csv, stringsAsFactors = FALSE))
utils::write.csv(summary, file.path(output_dir, "reader-summary.csv"), row.names = FALSE); print(summary)
