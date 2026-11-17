# Regroups a feature_steps CSV into the RFC's Section 2 rows and prints the
# clean table beside the RFC's (busy-machine) table.
#   Rscript steps_table.R <clean csv> <rfc csv> <out csv>
a <- commandArgs(TRUE)
groups <- list(
  "axis formatting" = c("projection pulse names", "projection axis format (direct)"),
  "TTR raw call" = "TTR raw call",
  "input treatment" = "input treatment",
  "calculate bookkeeping" = "calculate other (runs, carry)",
  "segment frame and rest" = c("segment frame", "segment other"),
  "plane exceptions and records" = c("plane exceptions", "plane records"),
  "compute residual" = "compute other",
  "causality probe, certification" = c("causality probe", "certification"),
  "payload split and rebuild" = c("payload split (sweep)", "projection rebuild (sweep)"),
  "other" = c("ranges and bounds", "projection index planes", "projection other", "other"))
regroup <- function(tab, label) {
  keys <- unique(paste(tab$shape, tab$path))
  do.call(rbind, lapply(keys, function(k) {
    rows <- tab[paste(tab$shape, tab$path) == k, ]
    wall <- if ("plain_wall_s" %in% names(rows)) rows$plain_wall_s[[1L]] else rows$wall_s[[1L]]
    data.frame(source = label, shape = rows$shape[[1L]], path = rows$path[[1L]], step = c(names(groups), "whole path", "bare TTR"),
      share = c(vapply(groups, function(g) sum(rows$share[rows$step %in% g]), 0), 1, NA),
      seconds = c(vapply(groups, function(g) sum(rows$share[rows$step %in% g]) * wall, 0), wall,
                  if ("bare_ttr_s" %in% names(rows)) rows$bare_ttr_s[[1L]] else NA),
      samples = rows$samples[[1L]], stringsAsFactors = FALSE)
  }))
}
clean <- regroup(read.csv(a[[1L]], stringsAsFactors = FALSE), "clean")
rfc <- regroup(read.csv(a[[2L]], stringsAsFactors = FALSE), "rfc")
both <- rbind(clean, rfc)
both$share <- round(both$share, 3)
both$seconds <- round(both$seconds, 3)
utils::write.csv(both, a[[3L]], row.names = FALSE)
cols <- unique(paste(both$shape, both$path))
for (src in c("clean", "rfc")) {
  cat("\n", src, "seconds (share)\n")
  sub <- both[both$source == src, ]
  m <- sapply(cols, function(cc) {
    r <- sub[paste(sub$shape, sub$path) == cc, ]
    ifelse(is.na(r$share), sprintf("%.2f", r$seconds), sprintf("%.2f (%.0f%%)", r$seconds, 100 * r$share))
  })
  rownames(m) <- c(names(groups), "whole path", "bare TTR")
  colnames(m) <- sub("crossover_", "", cols)
  print(noquote(m))
}
