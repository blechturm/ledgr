# LDG-3217: collects launch.R folders (mem_<arm>_<shape>_w<workers>_<rep>)
# into evidence CSVs and compares lean with pinned per shape and worker count.
#
#   Rscript summarize.R --work=<dir>[,<dir>...] --out=<evidence dir>
#
# preparation peak: a worker's lifetime peak private commit when the
# envelope's last preparation step returns (exit of
# ledgr_availability_valuation_state, after the fold reader; WS28 close
# review finding 1). entry peak: the same at fold entry, the boundary first
# reported (kept so the earlier figures stay identifiable). run peak: the
# lifetime peak over the whole run and reads. Components are sized at fold
# entry (inputs) and fold exit (output buffers and the fold result) and
# grouped into the skeleton synthesis Section 5.1 categories as in
# dev/bench/v0_2_3_ws16_entry/summarize.R, for every worker and repeat, with
# the basis of each category. Only aggregates are written.

arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) stop("Missing --", name, "=.", call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
dirs <- unlist(lapply(strsplit(arg("work"), ",")[[1L]], list.files, pattern = "^mem_", full.names = TRUE))
dirs <- dirs[file.exists(file.path(dirs, "tree.csv"))]
parse <- function(d) {
  p <- regmatches(basename(d), regexec("^mem_(pinned|lean)_(.+)_w([0-9]+)_([0-9]+)$", basename(d)))[[1L]]
  data.frame(arm = p[[2L]], shape = p[[3L]], workers = as.integer(p[[4L]]), rep = as.integer(p[[5L]]))
}

category <- function(group, name) {
  out <- rep("other", length(name))
  out[group == "output_handler"] <- "output: handler buffers"
  out[group == "fold_result"] <- "output: fold result"
  out[group == "fold_result" & name == "state"] <- "final lots and state"
  hs <- group == "history_substrate"
  out[hs & name %in% c("bars", "bar_gap_runs")] <- "source/history: bar planes"
  out[hs & name %in% c("segments", "segment_counts", "sessions", "provider_plan", "axis",
                       "pulse_index", "instrument_ids", "instrument_index")] <- "source/history: facts and axes"
  out[hs & name == "feature_projection"] <- "feature payload"
  out[hs & name == "history_memo"] <- "retained views (history memo)"
  out[group == "execution" & name %in% c("state")] <- "lots and opening state"
  out[group == "execution" & name %in% c("availability_provider", "schedule_sessions",
                                          "corporate_action_plan")] <- "provider and schedule"
  out[startsWith(group, "stack:")] <- "transient copies (stack objects >= 1 MiB)"
  out
}

workers <- list(); trees <- list(); cats <- list()
for (d in dirs) {
  key <- parse(d)
  tree <- utils::read.csv(file.path(d, "tree.csv"))
  trees[[length(trees) + 1L]] <- cbind(key, tree[, c("parent_peak_private_mib", "worker_peak_private_mib",
                                                     "tree_peak_sampled_mib", "tree_peak_bound_mib")])
  for (w in list.files(d, pattern = "^worker_[0-9]+$", full.names = TRUE)) {
    ph <- utils::read.csv(file.path(w, "memory_phases.csv"))
    run <- utils::read.csv(file.path(w, "memory_run.csv"))
    entry <- ph$peak_private_mib[ph$phase == "fold entry"]
    prep_end <- ph$peak_private_mib[ph$phase == "exit ledgr_availability_valuation_state"]
    if (length(entry) != 1L || length(prep_end) != 1L) stop("missing preparation marks in ", w, call. = FALSE)
    workers[[length(workers) + 1L]] <- cbind(key, worker = basename(w),
      opened_peak_mib = round(ph$peak_private_mib[ph$phase == "snapshot opened"]),
      entry_peak_mib = round(entry),
      preparation_peak_mib = round(prep_end),
      run_peak_mib = round(max(ph$peak_private_mib)),
      run_s = round(run$run_s, 2), n_fills = run$n_fills, result_digest = run$result_digest)
    co <- utils::read.csv(file.path(w, "memory_components.csv"))
    co$category <- category(co$group, co$name)
    ag <- stats::aggregate(mib ~ at + category, data = co, FUN = sum)
    cats[[length(cats) + 1L]] <- cbind(key, worker = basename(w), at = ag$at, category = ag$category,
                                       mib = round(ag$mib, 1))
  }
}
workers <- do.call(rbind, workers)
trees <- do.call(rbind, trees)
cats <- do.call(rbind, cats)
ord <- function(x) x[order(x$shape, x$workers, x$arm, x$rep), ]
utils::write.csv(ord(workers), file.path(out, "memory_workers.csv"), row.names = FALSE)
utils::write.csv(ord(trees), file.path(out, "memory_tree.csv"), row.names = FALSE)
# The basis of each category: what it measures, and what it does not.
cats$basis <- "measured"
memo <- cats$category == "retained views (history memo)"
cats$basis[memo] <- paste("not measured: sized at fold entry, before the fold reader exists, and the momentum",
                          "workload issues no history reads (WS28 close review finding 2; disposed 2026-11-13)")
cats <- cats[order(cats$shape, cats$workers, cats$arm, cats$rep, cats$worker, cats$at, cats$category), ]
utils::write.csv(cats[, c("shape", "arm", "workers", "rep", "worker", "at", "category", "mib", "basis")],
                 file.path(out, "memory_categories.csv"), row.names = FALSE)

# Lean against pinned, per shape and worker count: the largest value over
# repeats and workers of each arm.
agg <- stats::aggregate(cbind(entry_peak_mib, preparation_peak_mib, run_peak_mib) ~ shape + workers + arm, data = workers, FUN = max)
tagg <- stats::aggregate(cbind(tree_peak_sampled_mib, tree_peak_bound_mib) ~ shape + workers + arm, data = trees, FUN = max)
m <- merge(agg, tagg)
wide <- merge(m[m$arm == "pinned", -3L], m[m$arm == "lean", -3L], by = c("shape", "workers"), suffixes = c("_pinned", "_lean"))
wide$entry_ratio <- round(wide$entry_peak_mib_lean / wide$entry_peak_mib_pinned, 3)
wide$preparation_ratio <- round(wide$preparation_peak_mib_lean / wide$preparation_peak_mib_pinned, 3)
wide$run_ratio <- round(wide$run_peak_mib_lean / wide$run_peak_mib_pinned, 3)
wide$results_identical <- vapply(seq_len(nrow(wide)), function(i) {
  x <- workers[workers$shape == wide$shape[[i]] & workers$workers == wide$workers[[i]], ]
  length(unique(x$result_digest)) == 1L
}, TRUE)
utils::write.csv(wide, file.path(out, "memory_compare.csv"), row.names = FALSE)
print(wide[, c("shape", "workers", "entry_peak_mib_pinned", "entry_peak_mib_lean", "preparation_peak_mib_pinned", "preparation_peak_mib_lean", "preparation_ratio",
               "run_peak_mib_pinned", "run_peak_mib_lean", "run_ratio", "tree_peak_bound_mib_pinned",
               "tree_peak_bound_mib_lean", "results_identical")], row.names = FALSE)
