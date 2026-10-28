# M4: run ledgr's floor checks against the minimum-environment library.
#
# Usage:
#   Rscript --vanilla dev/bench/v0_2_3_install_floor/run_floor_checks.R \
#     --lib=C:/Users/maxth/ledgr-wt/m4-libs/lib-min \
#     [--root=<ledgr checkout>] [--records=<scratch dir for profile records>]
#
# Every child process sees only `lib` and the R base library: R_LIBS is the
# library, R_LIBS_USER and R_LIBS_SITE point at a directory that does not
# exist (R drops non-existent entries). Step 0 records the library paths a
# child actually resolves and fails if they differ from c(lib, .Library).
# Commands are the CI commands (.github/workflows/R-CMD-check.yaml), run from
# the checkout root. Writes floor_checks.csv and floor_checks.log here.

args <- commandArgs(trailingOnly = TRUE)
value_arg <- function(name, default = NULL) {
  hit <- args[startsWith(args, paste0("--", name, "="))]
  if (length(hit) == 0L) default else sub(paste0("^--", name, "="), "", hit[[length(hit)]])
}
file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
here <- normalizePath(dirname(file_arg), winslash = "/")
root <- value_arg("root", normalizePath(file.path(here, "..", "..", ".."), winslash = "/"))
lib <- normalizePath(value_arg("lib"), winslash = "/", mustWork = TRUE)
records <- value_arg("records", file.path(dirname(lib), "records"))
csv_path <- file.path(here, "floor_checks.csv")
log_path <- file.path(here, "floor_checks.log")

no_lib <- file.path(dirname(lib), "no-such-library")
if (dir.exists(no_lib)) stop("The placeholder library path must not exist: ", no_lib)
Sys.setenv(R_LIBS = lib, R_LIBS_USER = no_lib, R_LIBS_SITE = no_lib)
setwd(root)

r_bin <- file.path(R.home("bin"), "R")
rscript <- file.path(R.home("bin"), "Rscript")
probe <- tempfile(fileext = ".R")
writeLines("cat(normalizePath(.libPaths(), winslash = '/'), sep = '\\n')", probe)

steps <- list(
  list(step = "0_library_paths", cmd = rscript, args = c("--vanilla", shQuote(probe)),
       shown = "Rscript --vanilla <probe: cat(.libPaths())>"),
  list(step = "1_r_cmd_install", cmd = r_bin,
       args = c("CMD", "INSTALL", "--preclean", "-l", shQuote(lib), "."),
       shown = sprintf("R CMD INSTALL --preclean -l %s .", lib)),
  list(step = "2_fast_profile_ordinary", cmd = rscript,
       args = c("--vanilla", "tools/run-test-profile.R", "--profile=fast", "--mode=ordinary",
                paste0("--records=", records), "--run-index=1"),
       shown = sprintf("Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=%s --run-index=1", records)),
  list(step = "3_readme_cold_start", cmd = rscript,
       args = c("--vanilla", "tools/check-readme-example.R"),
       shown = "Rscript --vanilla tools/check-readme-example.R")
)

log <- file(log_path, open = "w", encoding = "UTF-8")
header <- c(
  sprintf("M4 floor checks, %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("R: %s on %s", R.version.string, utils::sessionInfo()$running),
  sprintf("root: %s (commit %s)", root,
          tryCatch(system2("git", c("-C", shQuote(root), "rev-parse", "HEAD"), stdout = TRUE),
                   error = function(e) NA_character_)),
  sprintf("R_LIBS=%s R_LIBS_USER=%s R_LIBS_SITE=%s", lib, no_lib, no_lib),
  ""
)
writeLines(header, log)

rows <- list()
for (s in steps) {
  started <- proc.time()[[3L]]
  out <- suppressWarnings(system2(s$cmd, s$args, stdout = TRUE, stderr = TRUE))
  seconds <- proc.time()[[3L]] - started
  status <- attr(out, "status")
  status <- if (is.null(status)) 0L else as.integer(status)
  note <- ""
  if (identical(s$step, "0_library_paths")) {
    expected <- normalizePath(c(lib, .Library), winslash = "/")
    if (!identical(trimws(out), expected)) {
      status <- 1L
      note <- "library paths differ from c(lib, .Library)"
    } else {
      note <- paste(trimws(out), collapse = " | ")
    }
  }
  writeLines(c(sprintf("== %s ==", s$step), sprintf("$ %s", s$shown),
               out, sprintf("-- exit %d after %.1f s %s", status, seconds, note), ""), log)
  flush(log)
  rows[[length(rows) + 1L]] <- data.frame(
    step = s$step, command = s$shown, exit_code = status,
    seconds = round(seconds, 1), note = note, stringsAsFactors = FALSE
  )
  cat(sprintf("%s: exit %d (%.1f s) %s\n", s$step, status, seconds, note))
  if (status != 0L && s$step %in% c("0_library_paths", "1_r_cmd_install")) break
}
close(log)
result <- do.call(rbind, rows)
utils::write.csv(result, csv_path, row.names = FALSE)
summary_csv <- file.path(records, "run-1-summary.csv")
if (file.exists(summary_csv)) file.copy(summary_csv, file.path(here, "fast_profile_summary.csv"), overwrite = TRUE)
if (any(result$exit_code != 0L) || nrow(result) < length(steps)) {
  cat("FLOOR_CHECKS_FAIL\n")
  quit(save = "no", status = 1L)
}
cat("FLOOR_CHECKS_OK\n")
