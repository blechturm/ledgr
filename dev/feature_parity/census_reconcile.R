# Reconciles the final census with the measuring step's (Cut 22 decision 5:
# missing and extra rows are reconciled on the final code). For every helper
# in either census: its row in each, and why it entered or left.
#
#   Rscript census_reconcile.R --probe=<dev/spikes/feature_stage1_probe/results/census.csv>
#     --final=<census.csv> --out=<csv>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  probe <- utils::read.csv(arg("probe"), stringsAsFactors = FALSE)
  final <- utils::read.csv(arg("final"), stringsAsFactors = FALSE)
  deleted <- c("ledgr_compute_feature_series", "ledgr_compute_feature_scalar_at", "ledgr_check_no_lookahead")
  helpers <- sort(union(probe$helper, final$helper), method = "radix")
  p <- match(helpers, probe$helper)
  f <- match(helpers, final$helper)
  why <- ifelse(!is.na(p) & !is.na(f), "in both",
    ifelse(is.na(f) & helpers %in% deleted, "left: deleted by decision 4",
      ifelse(is.na(f), "left: not reached from the preparation roots on the final code",
        ifelse(final$first_root[f] %in% c("ledgr_history_substrate", "ledgr_history_substrate_for_experiment",
                                          "ledgr_history_calculation_start"),
               "entered: substrate construction and calculation bounds (cut review 22, R2)",
               "entered: reached from the preparation roots on the final code"))))
  out <- data.frame(helper = helpers,
                    probe_category = probe$category[p], probe_bound_by = probe$bound_by[p],
                    final_category = final$category[f], final_binding = final$binding[f],
                    reconciliation = why, stringsAsFactors = FALSE)
  utils::write.csv(out, arg("out"), row.names = FALSE)
  print(table(out$reconciliation))
  moved <- !is.na(p) & !is.na(f) & startsWith(probe$bound_by[p], "engine version") != (final$binding[f] == "engine version")
  cat("rows in both whose engine binding changed:", sum(moved), "\n")
})
