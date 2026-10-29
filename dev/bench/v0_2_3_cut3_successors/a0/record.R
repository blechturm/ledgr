# A0 successor recorder (LDG-3161; ws2_rng_design.md Section 8.1).
#
# Calls the unchanged A0 harness (dev/bench/v0_2_3_output_freeze/lib.R and its
# fixtures) on the candidate tree and writes a separately named record. The
# one difference from the original recorder is maintainer decision (17): the
# wall-clock field walk_forward/wf_folds selected_at_utc joins the harness's
# wall-clock exclusions, so the successor record does not depend on the day it
# is recorded. compare.R tests that this is the only exclusion added.
#
# Usage: Rscript record.R [--out=<dir>] [--pkg=<package root>] [--workloads=<id,id>]
#   --out        defaults to records/ next to this script
#   --pkg        package tree to load (default: the tree holding this script)
#   --workloads  restrict to some A0 workloads (used by guts.R; a partial
#                record is never committed)

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  source(file.path(here, "..", "lib.R"))
})
a0_succ_here <- file.path(sr_dir, "a0")
a0_succ_pkg <- sr_arg("pkg", sr_root)
suppressMessages(pkgload::load_all(a0_succ_pkg, quiet = TRUE))
source(file.path(a0_succ_pkg, "dev", "bench", "v0_2_3_output_freeze", "lib.R"))

# Decision (17): exactly one exclusion is added.
a0_succ_extra_exclusion <- data.frame(table = "wf_folds", column = "selected_at_utc",
  reason = "wall clock at walk-forward selection (maintainer decision (17), LDG-3161)", stringsAsFactors = FALSE)
a0_exclusions <- rbind(a0_exclusions, a0_succ_extra_exclusion)

out_dir <- sr_arg("out", file.path(a0_succ_here, "records"))
ids <- sr_arg("workloads")
ids <- if (is.null(ids)) names(a0_workloads) else strsplit(ids, ",", fixed = TRUE)[[1L]]
if (dir.exists(out_dir)) invisible(file.remove(list.files(out_dir, recursive = TRUE, full.names = TRUE)))
results <- a0_run_all(file.path(tempdir(), "a0_successor_work"), ids = ids)
manifest <- a0_write_records(results$tables, out_dir)
cat(sprintf("a0 successor record: %d files, %.1f KB in %s (pkg %s)\n", nrow(manifest),
  sum(as.numeric(manifest$bytes)) / 1024, out_dir, a0_succ_pkg))
