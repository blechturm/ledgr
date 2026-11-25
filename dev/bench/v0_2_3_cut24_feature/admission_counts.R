# Cut 24 decision 3 (LDG-3258): expected admission counts of the four
# admission workloads, established before stage 3 independently of the
# product: the conservative gate is the measuring step's own predicate
# (dev/spikes/feature_stage23_probe/common.R, gate_cells()), applied to the
# exact fixtures and definitions of protocols/cut24-feature-1/workloads.R on
# the cut base. Writes admission_expected.csv (case, path, definition,
# certification, instruments, admitted) and the fixture digests.
#
#   Rscript admission_counts.R --lib=<cut base library> --work=<dir> --out=<dir>
here_cut24 <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                    winslash = "/"))
repo_cut24 <- normalizePath(file.path(here_cut24, "..", "..", ".."), winslash = "/")
# common.R loads the library from --lib, defines `ns`, `work` and gate_cells().
source(file.path(repo_cut24, "dev/spikes/feature_stage23_probe/common.R"))
wl <- new.env()
sys.source(file.path(repo_cut24, "dev/bench/timing/protocols/cut24-feature-1/workloads.R"), envir = wl)
out_dir <- arg("out")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

fixtures <- list(
  custom = function() wl$cut24_bar_native("500x1260", file.path(work, "custom"), ns),
  zero = function() list(snapshot = NULL, substrate = wl$cut24_gap_substrate(ns, keep = 0L)),
  low = function() list(snapshot = NULL, substrate = wl$cut24_gap_substrate(ns, keep = 5L)),
  pit = function() wl$cut24_pit(file.path(work, "pit"), ns))
rows <- list(); digests <- list()
for (case in names(fixtures)) {
  dir.create(file.path(work, case), recursive = TRUE, showWarnings = FALSE)
  fx <- fixtures[[case]]()
  sub <- fx$substrate
  digests[[case]] <- data.frame(case = case, instruments = length(sub$instrument_ids), axis = length(sub$axis),
    bars_digest = wl$cut24_sha(lapply(sub$bars, unname)), axis_digest = wl$cut24_sha(as.numeric(sub$axis)),
    stringsAsFactors = FALSE)
  bounds <- ns$ledgr_history_feature_bounds(sub, ns$ledgr_history_calculation_start(sub), NULL)
  for (path in c("run", "sweep")) {
    defs <- if (identical(case, "custom")) wl$cut24_custom_defs(ns) else wl$cut24_sma_defs(ns, path)
    certified <- stats::setNames(lapply(defs, ns$ledgr_feature_certify), vapply(defs, function(d) d$id, ""))
    cells <- gate_cells(sub, certified, bounds)
    for (d in names(certified)) {
      cd <- cells[cells$def == d, ]
      rows[[length(rows) + 1L]] <- data.frame(case = case, path = path, definition = d,
        certification = certified[[d]]$certification, instruments = nrow(cd), admitted = sum(cd$conservative),
        stringsAsFactors = FALSE)
    }
  }
  if (!is.null(fx$snapshot)) ledgr::ledgr_snapshot_close(fx$snapshot)
}
expected <- do.call(rbind, rows)
utils::write.csv(expected, file.path(out_dir, "admission_expected.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, digests), file.path(out_dir, "fixture_digests.csv"), row.names = FALSE)
print(expected, row.names = FALSE)
