# Switch probe: for the functions in the old fold's files that stay reachable
# after the switch, the reachable functions that reference them (their kept
# parents), from reachability.R's graph. Run after reachability.R, in the
# same R session (source it with the same arguments first).
fold_files <- c("fold-engine.R", "fold-carrier.R", "fold-phase-contract.R", "compiled-spot-fifo.R")
kept_fold <- tab$fn[tab$file %in% fold_files & tab$reach_after]
parents <- lapply(stats::setNames(kept_fold, kept_fold), function(g) {
  p <- names(after_edges)[vapply(after_edges, function(e) g %in% e, logical(1L))]
  p <- intersect(p, after)
  if (g %in% lean_refs) p <- c("<lean fold>", p)
  p
})
rows <- data.frame(fn = kept_fold, file = tab$file[match(kept_fold, tab$fn)], lines = tab$lines[match(kept_fold, tab$fn)],
                   lean = kept_fold %in% lean_refs,
                   parents = vapply(parents, function(p) paste(utils::head(p, 6L), collapse = "; "), ""),
                   stringsAsFactors = FALSE)
rows <- rows[order(rows$lean, -rows$lines), ]
utils::write.csv(rows, file.path(out, "fold_files_kept.csv"), row.names = FALSE)
cat("kept in the old fold's files:", nrow(rows), "functions,", sum(rows$lines, na.rm = TRUE), "lines;",
    sum(rows$lean), "called by the lean fold\n")
print(rows[!rows$lean, ], row.names = FALSE)
