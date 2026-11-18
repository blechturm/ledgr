# Checker (spike protocol section 6): reruns the deterministic evidence into
# a scratch directory and diffs it against results/; runs the gut
# demonstration; guards package scope by hashing R, src, tests, NAMESPACE,
# DESCRIPTION, man and inst/design before and after. Timings are not diffed.
#
#   Rscript check.R --lib=<installed ledgr> --scratch=<dir>
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- arg("lib"); scratch <- arg("scratch")
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript")
scope <- function() {
  f <- c(list.files(file.path(repo, c("R", "src", "tests", "man", "inst/design")), recursive = TRUE, full.names = TRUE),
         file.path(repo, c("NAMESPACE", "DESCRIPTION")))
  f <- f[!grepl("\\.(o|dll|so)$", f)]
  stats::setNames(unname(tools::md5sum(f)), f)
}
run <- function(script, ...) {
  out <- system2(rscript, shQuote(c(file.path(here, script), paste0("--lib=", lib), paste0("--work=", file.path(scratch, "work")), ...)),
                 stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status"); if (is.null(status)) status <- 0L
  if (status != 0L) { cat(out, sep = "\n"); stop(script, " failed") }
  out
}
same_csv <- function(a, b, cols = NULL) {
  x <- utils::read.csv(a, stringsAsFactors = FALSE); y <- utils::read.csv(b, stringsAsFactors = FALSE)
  if (!is.null(cols)) { x <- x[cols]; y <- y[cols] }
  isTRUE(all.equal(x, y, check.attributes = FALSE))
}
before <- scope()
fail <- character()
run("gate_count.R", paste0("--out=", file.path(scratch, "gate_count.csv")))
for (f in c("gate_count.csv", "gate_count_differing.csv")) if (!same_csv(file.path(here, "results", f), file.path(scratch, f))) fail <- c(fail, f)
inv <- system2(rscript, shQuote(c(file.path(here, "ttr_inventory.R"), paste0("--tree=", repo),
                                  paste0("--out=", file.path(scratch, "ttr_inventory.csv")))), stdout = TRUE, stderr = TRUE)
for (f in c("ttr_inventory.csv", "ttr_inventory_by_function.csv")) if (!same_csv(file.path(here, "results", f), file.path(scratch, f))) fail <- c(fail, f)
run("direct.R", "--reps=1", paste0("--out=", file.path(scratch, "direct.csv")))
if (!same_csv(file.path(here, "results", "direct.csv"), file.path(scratch, "direct.csv"),
              c("shape", "set", "defs", "instruments", "admitted_cells", "all_cells", "cells_compared", "cells_differing"))) {
  fail <- c(fail, "direct.csv (cell columns)")
}
# Gut: without the full-coverage clause the conservative gate admits cells
# whose general answer differs (carried or missing inputs); the identity
# check must see them.
run("gate_count.R", "--no-gate-clause=full", paste0("--out=", file.path(scratch, "gut_gate_count.csv")))
gut <- utils::read.csv(file.path(scratch, "gut_gate_count.csv"))
gut_diff <- sum(gut$admitted_differing[gut$rule == "conservative"])
cat("gut (no full-coverage clause): conservative admitted cells differing from the general path:", gut_diff, "\n")
if (gut_diff == 0L) fail <- c(fail, "gut not detected")
after <- scope()
if (!identical(before, after)) fail <- c(fail, paste("package scope changed:", paste(names(after)[before != after], collapse = ", ")))
if (length(fail)) { cat("CHECK FAILED:", paste(fail, collapse = "; "), "\n"); quit(save = "no", status = 1L) }
cat("CHECK PASS\n")
