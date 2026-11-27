# Workstream 46 close review round 1: non-blank, non-comment code lines of
# the files the round changes, at 400c6a14 (the reviewed commit) and in the
# working tree; the definition of ../lines_harness.csv (whose 400c6a14 counts
# this reproduces).
#   Rscript lines_r1.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", "..", "..", "..", ".."), winslash = "/")
code <- function(x) sum(!grepl("^\\s*$", x) & !grepl("^\\s*#", x))
files <- c(harness = "dev/lean_core/loop_workers.R", workload = "dev/lean_core/parity/loop_workloads_slice5.R",
           workload = "dev/lean_core/parity/loop_parity.R", witness = "dev/lean_core/parity/loop_variants.R",
           witness = "dev/lean_core/parity/loop_freeze_changes.R", harness = "dev/lean_core/recorder/run.R")
at <- function(f) code(system2("git", c("-C", repo, "show", paste0("400c6a14:", f)), stdout = TRUE))
now <- function(f) code(readLines(file.path(repo, f), warn = FALSE))
out <- data.frame(role = names(files), file = unname(files), reviewed_400c6a14 = vapply(files, at, 0),
                  round1 = vapply(files, now, 0), row.names = NULL)
out$change <- out$round1 - out$reviewed_400c6a14
utils::write.csv(out, file.path(here, "lines_r1.csv"), row.names = FALSE)
print(out)
