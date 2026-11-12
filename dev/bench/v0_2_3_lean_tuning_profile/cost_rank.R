# Ranks the lean arm's whole-run costs per shape from cost_map.R's outputs
# (LDG-3221 summary): every attribution cell's estimated seconds per run,
# plus the measured snapshot open, with the owner each cost would go to.
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/cost_rank.R --in=<cost_map out dir> --out=<csv>

arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
dir <- arg("in")
cells <- utils::read.csv(file.path(dir, "cells.csv"), stringsAsFactors = FALSE)
rec <- utils::read.csv(file.path(dir, "reconcile.csv"), stringsAsFactors = FALSE)
lean <- cells[cells$arm == "lean", c("shape", "cell", "est_run_s")]
lean <- rbind(lean, data.frame(shape = rec$shape[rec$arm == "lean"], cell = "snapshot open and verification (measured)",
                               est_run_s = rec$snapshot_open_median_s[rec$arm == "lean"]))
owner <- function(cell) {
  if (identical(cell, "strategy: own work")) return("none (the strategy's own code)")
  if (grepl("^(P[1-5]|E |strategy|loop:)", cell)) return("Cut 15 (loop tuning)")
  if (grepl("features|feature projection|feature declarations", cell)) return("feature-engine RFC")
  if (grepl("^transfer: write|envelope: setup and commit", cell)) return("store-write RFC")
  if (grepl("^transfer: expand", cell)) return("Cut 15 (loop tuning)")
  "none"
}
lean$owner <- vapply(lean$cell, owner, "")
# The snapshot open is outside the committed-run clock: no share of the run.
in_run <- !grepl("^snapshot open", lean$cell)
lean$share_of_run <- ifelse(in_run, lean$est_run_s / stats::ave(ifelse(in_run, lean$est_run_s, 0), lean$shape, FUN = sum),
                            NA_real_)
lean <- lean[order(lean$shape, -lean$est_run_s), ]
lean$rank <- stats::ave(seq_len(nrow(lean)), lean$shape, FUN = seq_along)
utils::write.csv(lean, arg("out"), row.names = FALSE)
by_owner <- stats::aggregate(est_run_s ~ shape + owner, lean, sum)
print(by_owner[order(by_owner$shape, -by_owner$est_run_s), ], row.names = FALSE)
