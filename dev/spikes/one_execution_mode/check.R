# One-execution-mode probe checker.
#
#   Rscript dev/spikes/one_execution_mode/check.R <repo> <evidence_dir> [--rerun]
#
# 1. Guards package scope: R, src, tests, NAMESPACE, DESCRIPTION, man and
#    inst/design must be unchanged against HEAD.
# 2. Re-diffs every recorded case from its per-arm CSVs (dense against
#    availability), per surface: identical or the first differing row.
# 3. Flags the gut case: it must differ in a fill price, not only in ts_utc.
# 4. With --rerun, reruns the diff cases into a scratch directory and diffs
#    every recorded CSV against the rerun.

args <- commandArgs(TRUE)
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
evidence <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
rerun <- "--rerun" %in% args
source(file.path(repo, "dev/spikes/one_execution_mode/probe.R"))

failures <- character()
fail <- function(...) failures <<- c(failures, paste0(...))

scope <- system2("git", c("-C", repo, "status", "--porcelain", "--", "R", "src", "tests",
                          "NAMESPACE", "DESCRIPTION", "man", "inst/design"), stdout = TRUE)
scope <- scope[!grepl("\\.(o|dll|so|gcda)$", scope)]
if (length(scope)) fail("package scope changed: ", paste(scope, collapse = "; "))
cat("scope guard:", if (length(scope)) "CHANGED" else "clean", "\n")

read_plain <- function(path) {
  if (!file.exists(path)) return(NULL)
  x <- utils::read.csv(path, colClasses = "character", check.names = FALSE, na.strings = "NA")
  x
}
surfaces <- c("fills", "ledger", "equity", "trades", "positions", "metrics")
cases <- setdiff(list.dirs(evidence, full.names = FALSE, recursive = FALSE), c("clock", "prereq"))
table_rows <- list()
for (case in cases) {
  for (s in surfaces) {
    dense <- read_plain(file.path(evidence, case, "dense", paste0(s, ".csv.gz")))
    avail <- read_plain(file.path(evidence, case, "availability", paste0(s, ".csv.gz")))
    err <- c(dense = file.exists(file.path(evidence, case, "dense", "error.txt")),
             availability = file.exists(file.path(evidence, case, "availability", "error.txt")))
    result <- if (any(err)) {
      paste(names(err)[err], "refused:", vapply(names(err)[err], function(a)
        readLines(file.path(evidence, case, a, "error.txt"))[[1L]], character(1)), collapse = "; ")
    } else oem_diff(dense, avail)
    table_rows[[length(table_rows) + 1L]] <- data.frame(case = case, surface = s, result = result)
  }
}
diff_table <- do.call(rbind, table_rows)
print(diff_table, right = FALSE)

gut_fills <- diff_table$result[diff_table$case == "gut" & diff_table$surface == "fills"]
if (length(gut_fills) && grepl("price=", gut_fills)) {
  cat("gut: FLAGGED (fill price differs)\n")
} else if (length(gut_fills)) {
  fail("gut case not flagged: ", gut_fills)
}

if (rerun) {
  scratch <- file.path(tempdir(), "oem_rerun")
  diff_cases <- intersect(cases, oem_cases())
  status <- system2(file.path(R.home("bin"), "Rscript"),
                    c(file.path(repo, "dev/spikes/one_execution_mode/probe.R"), repo, scratch, diff_cases),
                    stdout = FALSE, stderr = FALSE)
  if (!identical(status, 0L)) fail("rerun failed with status ", status)
  recorded <- list.files(evidence, pattern = "\\.(csv|csv\\.gz|txt)$", recursive = TRUE)
  recorded <- recorded[!grepl("^(clock|prereq)/|identity\\.csv$", recorded)]
  for (f in recorded) {
    if (grepl("\\.txt$", f)) {
      same <- identical(readLines(file.path(evidence, f)), readLines(file.path(scratch, f)))
      if (!same) fail("rerun differs: ", f)
      next
    }
    d <- oem_diff(read_plain(file.path(evidence, f)), read_plain(file.path(scratch, f)))
    if (!identical(d, "identical")) fail("rerun differs: ", f, ": ", d)
  }
  cat("rerun:", length(recorded), "recorded files compared\n")
}

if (length(failures)) {
  cat("CHECK FAILED\n", paste0("- ", failures, collapse = "\n"), "\n")
  quit(status = 1L)
}
cat("CHECK OK\n")
