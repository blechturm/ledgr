# LDG-3272 (cut review 26, R9): the restart routes' pin tables, committed for
# independent verification. Reads loop_parity.R --dump output and writes, per
# workload and attempt, the runs, ledger_events and run_completion tables and
# the route's fold counts.
#
#   Rscript dev/lean_core/parity/evidence/ldg3272/dump.R --dump=<dir> --out=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  out <- arg("out")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  for (w in c("s5_restart_plain", "s5_restart_opening", "s5_restart_running", "s5_reopen_incomplete", "s5_recover_completion")) {
    t <- readRDS(file.path(arg("dump"), paste0(w, ".rds")))
    for (g in intersect(c("attempt1", "run", "route"), names(t))) {
      for (tab in intersect(c("runs", "ledger_events", "run_completion", "folds"), names(t[[g]]))) {
        utils::write.csv(t[[g]][[tab]], file.path(out, sprintf("%s__%s__%s.csv", w, g, tab)), row.names = FALSE)
      }
    }
  }
  cat("wrote", length(list.files(out)), "tables to", out, "\n")
})
