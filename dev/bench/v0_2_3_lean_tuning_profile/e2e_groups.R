# Groups the lean cells of a run cost map (cost_map.R) and a sweep cost map
# (sweep_map.R) into owner groups, as seconds and percent of the whole run or
# sweep, and prints the markdown rows of summary.md's "End-to-end after Cut
# 18" section (every number there comes from this script).
#
#   Rscript dev/bench/v0_2_3_lean_tuning_profile/e2e_groups.R --runs=<cost_map out> --sweeps=<sweep_map out> --out=<csv>

arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
rd <- function(d, f) utils::read.csv(file.path(d, f), stringsAsFactors = FALSE)
groups <- c("loop: planner", "loop: FIFO", "loop: fill records and position facts", "loop: strategy boundary",
            "loop: output checks", "loop: commit", "loop: valuation, advance, residual", "strategy's own code",
            "output publication", "features", "setup", "finalise and result", "sweep bookkeeping", "other")
group_of <- function(cell) {
  if (cell == "P3") return("loop: planner")
  if (cell == "P4 FIFO") return("loop: FIFO")
  if (cell == "P4 other") return("loop: fill records and position facts")
  if (cell %in% c("P2 context", "strategy: ledgr callees", "strategy: call wrapper")) return("loop: strategy boundary")
  if (startsWith(cell, "P2 ")) return("loop: output checks")
  if (cell == "P5") return("loop: commit")
  if (cell %in% c("P1", "E advance") || startsWith(cell, "loop: ")) return("loop: valuation, advance, residual")
  if (cell == "strategy: own work") return("strategy's own code")
  if (cell %in% c("transfer: write", "transfer: expand", "envelope: setup and commit")) return("output publication")
  if (grepl("^pre: feature", cell)) return("features")
  if (startsWith(cell, "pre: ")) return("setup")
  if (startsWith(cell, "post: ")) return("finalise and result")
  if (startsWith(cell, "sweep: ") && cell != "sweep: other") return("sweep bookkeeping")
  "other"
}
runs <- rd(arg("runs"), "cells.csv"); runs <- runs[runs$arm == "lean" & !is.na(runs$est_run_s), ]
sweeps <- rd(arg("sweeps"), "cells.csv")
x <- rbind(data.frame(kind = "run", shape = runs$shape, cell = runs$cell, s = runs$est_run_s),
           data.frame(kind = "sweep", shape = sweeps$shape, cell = sweeps$cell, s = sweeps$est_sweep_s))
x$group <- vapply(x$cell, group_of, "")
g <- stats::aggregate(s ~ kind + shape + group, x, sum)
g$pct <- 100 * g$s / stats::ave(g$s, g$kind, g$shape, FUN = sum)
utils::write.csv(g[order(g$kind, g$shape, match(g$group, groups)), ], arg("out"), row.names = FALSE)

cols <- list(c("run", "10x7200"), c("run", "20x23400"), c("run", "slice2_10x7200"), c("run", "500x1260"),
             c("run", "1166x252"), c("sweep", "10x7200"), c("sweep", "500x1260"))
cell_txt <- function(k, s, grp) {
  v <- g[g$kind == k & g$shape == s & g$group == grp, ]
  if (!nrow(v)) "-" else sprintf("%.2f (%.0f%%)", v$s, v$pct)
}
row <- function(...) paste0("| ", paste(c(...), collapse = " | "), " |")
cat(row("group", vapply(cols, function(c) paste(c[[1L]], c[[2L]]), "")), "\n", sep = "")
for (grp in groups) cat(row(grp, vapply(cols, function(c) cell_txt(c[[1L]], c[[2L]], grp), "")), "\n", sep = "")
rec_r <- rd(arg("runs"), "reconcile.csv"); rec_s <- rd(arg("sweeps"), "reconcile.csv")
tot <- vapply(cols, function(c) if (c[[1L]] == "run") sprintf("%.2f", rec_r$run_median_s[rec_r$arm == "lean" & rec_r$shape == c[[2L]]])
              else sprintf("%.2f", rec_s$sweep_median_s[rec_s$shape == c[[2L]]]), "")
cat(row("whole run or sweep (clock)", tot), "\n", sep = "")
