# A0 gut demonstration: runs check.R as a subprocess once as a control and
# once per corruption in a0_guts (lib.R). The control must pass; every
# corruption must make check.R exit non-zero and name the corrupted table.
# Writes gut_results.csv next to this script.
#
# Usage: Rscript gut.R [--records=<dir>]

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "lib.R"))
})
here <- a0_script_dir()
records_dir <- a0_arg("records", file.path(here, "records"))
rscript <- file.path(R.home("bin"), "Rscript")
check <- file.path(here, "check.R")

run_check <- function(gut_name) {
  out_dir <- file.path(tempdir(), paste0("a0_gut_", if (is.null(gut_name)) "control" else gut_name))
  q <- function(x) shQuote(x, type = "cmd")
  args <- c(q(check), paste0("--records=", q(records_dir)), paste0("--out=", q(out_dir)),
    paste0("--agreement=", q(file.path(tempdir(), "agreement_unused.csv"))))
  if (!is.null(gut_name)) args <- c(args, paste0("--gut=", gut_name))
  output <- suppressWarnings(system2(rscript, args, stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status") %||% 0L
  list(status = as.integer(status), output = output)
}

rows <- list()
control <- run_check(NULL)
cat("control:", tail(control$output, 1L), "\n")
rows[[1L]] <- data.frame(gut = "control", what = "no corruption", expected_table = "",
  exit_status = control$status, check_failed = control$status != 0L, names_table = NA,
  first_report = tail(control$output, 1L), stringsAsFactors = FALSE)
for (name in names(a0_guts)) {
  g <- a0_guts[[name]]
  res <- run_check(name)
  report <- grep(" / ", res$output, value = TRUE, fixed = TRUE)
  names_table <- any(grepl(sprintf("%s / [a-z_0-9]+ / %s:", g$workload, g$expect), report))
  cat(sprintf("%s: exit %d, names %s/%s: %s\n", name, res$status, g$workload, g$expect, names_table))
  writeLines(paste("   ", res$output[grepl("FAIL|/|expected|actual", res$output)]))
  rows[[length(rows) + 1L]] <- data.frame(gut = name, what = g$what,
    expected_table = paste(g$workload, g$expect, sep = "/"), exit_status = res$status,
    check_failed = res$status != 0L, names_table = names_table,
    first_report = if (length(report)) trimws(report[[1L]]) else "", stringsAsFactors = FALSE)
}
results <- do.call(rbind, rows)
a0_write_table(as.data.frame(lapply(results, a0_fmt_atomic), stringsAsFactors = FALSE), file.path(here, "gut_results.csv"))
ok <- !results$check_failed[[1L]] && all(results$check_failed[-1L]) && all(results$names_table[-1L])
cat(sprintf("a0 gut: %s\n", if (ok) "PASS (control passes, every corruption fails check.R and is named)" else "FAIL"))
quit(status = if (ok) 0L else 1L)
