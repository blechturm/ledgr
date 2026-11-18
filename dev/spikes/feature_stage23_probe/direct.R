# Stage-3 ceiling on the crossover fixtures (CHARTER.md, question). The
# direct path computes every conservative-gate cell with one adapter call
# per (definition, instrument); this script checks it against the general
# path cell by cell and times both.
#
# Timed, as medians over --reps:
#   general     ledgr_history_compute_feature_series() (the whole call)
#   keep        what a direct path still pays inside that call: certification,
#               the causality probe (same definitions, instruments and
#               positions) and plane-record assembly
#   gate        the conservative predicate for every (definition, instrument)
#   direct      one adapter call per admitted cell, values and segment records
# Ceiling saving = general - keep - gate - direct. It assumes nothing else is
# needed; a real stage 3 also keeps its debug comparison, so this is an upper
# bound.
#
#   Rscript direct.R --lib=<installed ledgr> --reps=7 --out=results/direct.csv
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                       winslash = "/")), "common.R"))
shapes <- strsplit(arg("shapes", "crossover_10x7200,crossover_500x1260,crossover_1166x252"), ",")[[1L]]
reps <- as.integer(arg("reps", "7"))

compare <- function(substrate, certified, bounds, general, direct) {
  # Values: every admitted row identical over the whole axis. Records: the
  # general path's segment records for those rows equal the direct ones, and
  # it holds no carry or reason exception there.
  recs <- attr(general, "ledgr_feature_planes")
  bad <- 0L; cells <- 0L
  for (d in seq_along(certified)) {
    seg <- direct$segments[direct$segments[, "def"] == d, , drop = FALSE]
    r <- recs[[d]]
    for (k in seq_len(nrow(seg))) {
      i <- seg[k, "instrument"]; cells <- cells + 1L
      same_value <- identical(general[[d]][i, ], direct$values[[d]][i, ])
      g <- which(r$segment_row == i)
      same_seg <- length(g) == 1L && r$segment_start[g] == seg[k, "start"] && r$segment_end[g] == seg[k, "end"] &&
        identical(as.integer(r$segment_ready[g]), as.integer(seg[k, "ready"]))
      no_exc <- !any(r$input_row == i) && !any(r$output_row == i) && !any(r$reason_row == i)
      if (!(same_value && same_seg && no_exc)) bad <- bad + 1L
    }
  }
  c(cells = cells, differing = bad)
}

rows <- list()
for (shape in shapes) {
  snapshot <- crossover_snapshot(shape)
  for (set in c("run", "sweep")) {
    widths <- if (set == "run") c(5, 10) else c(3, 5, 8, 12, 20, 40)
    exp <- crossover_exp(snapshot, widths)
    substrate <- ns$ledgr_history_substrate_for_experiment(exp)
    start <- ns$ledgr_history_calculation_start(substrate)
    defs <- defs_for(exp)
    bounds <- ns$ledgr_history_feature_bounds(substrate, start, NULL)
    certified <- lapply(defs, ns$ledgr_feature_certify)
    general <- ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = start)
    cells <- gate_cells(substrate, certified, bounds)
    direct <- direct_compute(substrate, certified, bounds, cells)
    cmp <- compare(substrate, certified, bounds, general, direct)
    calc <- seq.int(bounds$from, bounds$to)
    count <- do.call(rbind, lapply(general, function(m) as.integer(rowSums(!is.na(m[, calc, drop = FALSE])))))
    chunks <- lapply(certified, function(cert) ns$ledgr_feature_plane_chunks(length(substrate$instrument_ids)))
    t_general <- time_median(function() ns$ledgr_history_compute_feature_series(substrate, defs, calculation_start = start), reps)
    t_cert <- time_median(function() lapply(defs, ns$ledgr_feature_certify), reps)
    t_causality <- time_median(function() ns$ledgr_history_feature_causality(substrate, certified, bounds, count, general), reps)
    t_records <- time_median(function() ns$ledgr_feature_plane_records(chunks, substrate$instrument_ids, bounds), reps)
    t_gate <- time_median(function() gate_cells(substrate, certified, bounds), reps)
    t_direct <- time_median(function() direct_compute(substrate, certified, bounds, cells), reps)
    keep <- t_cert + t_causality + t_records
    rows[[paste(shape, set)]] <- data.frame(shape = shape, set = set, defs = length(defs),
      instruments = length(substrate$instrument_ids), admitted_cells = sum(cells$conservative),
      all_cells = nrow(cells), cells_compared = cmp[["cells"]], cells_differing = cmp[["differing"]],
      general_s = round(t_general, 4), keep_s = round(keep, 4), certification_s = round(t_cert, 4),
      causality_s = round(t_causality, 4), records_s = round(t_records, 4), gate_s = round(t_gate, 4),
      direct_s = round(t_direct, 4), ceiling_saving_s = round(t_general - keep - t_gate - t_direct, 4),
      ceiling_saving_share = round((t_general - keep - t_gate - t_direct) / t_general, 3), stringsAsFactors = FALSE)
    print(rows[[paste(shape, set)]][, c("shape", "set", "cells_compared", "cells_differing", "general_s", "keep_s",
                                        "gate_s", "direct_s", "ceiling_saving_share")])
  }
  ledgr::ledgr_snapshot_close(snapshot)
}
out <- do.call(rbind, rows); rownames(out) <- NULL
utils::write.csv(out, arg("out"), row.names = FALSE)
utils::write.csv(provenance(), sub("\\.csv$", "_provenance.csv", arg("out")), row.names = FALSE)
