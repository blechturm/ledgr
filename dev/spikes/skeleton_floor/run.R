# Runner: the skeleton variants against the R floor, per shape.
#   Rscript dev/spikes/skeleton_floor/run.R <ledgr lib> <out dir> [shapes] [rounds] [gut]
#   shapes: comma list like 3x40,10x7200 (default 10x7200,20x23400,500x1260)
#   gut:    "same_bar_fill" breaks the full skeleton on purpose
# Writes parity.csv (every variant against the floor's fills, equity and
# cash), timings_raw.csv (one row per round and variant) and timings.csv
# (median us per pulse; above-floor cost as the median of same-round paired
# differences). Rounds alternate and rotate the variant order.
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
out <- args[[2]]
shapes <- strsplit(if (length(args) >= 3) args[[3]] else "10x7200,20x23400,500x1260", ",")[[1]]
rounds <- if (length(args) >= 4) as.integer(args[[4]]) else 7L
gut <- if (length(args) >= 5) args[[5]] else ""
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path("dev", "spikes", "r_floor", "fixture.R"))
source(file.path("dev", "spikes", "r_floor", "floor.R"))
source(file.path("dev", "spikes", "skeleton_floor", "skeleton.R"))
cmp <- compiler::cmpfun
fold_floor <- cmp(r_floor_fold_strategy)
fold_skel <- cmp(skel_fold)
fold_flat <- cmp(skel_fold_flat)

par_rows <- list(); raw_rows <- list()
for (shape in shapes) {
  dims <- as.integer(strsplit(shape, "x")[[1]])
  p <- r_floor_prepare(r_floor_fixture(dims[[1]], dims[[2]]))
  s <- r_floor_transition
  variants <- list(
    floor = function() fold_floor(p, s),
    skeleton = function() fold_skel(p, s, gut = gut),
    no_try = function() fold_skel(p, s, try = FALSE),
    no_hook = function() fold_skel(p, s, hook = FALSE),
    floor_record = function() fold_skel(p, s, record = "floor"),
    stages_only = function() fold_skel(p, s, try = FALSE, hook = FALSE, record = "floor"),
    flat = function() fold_flat(p, s)
  )
  ref <- variants$floor()
  for (v in names(variants)) {
    got <- variants[[v]]()
    par_rows[[length(par_rows) + 1L]] <- data.frame(shape = shape, variant = v,
      n_fills = nrow(got$fills), fills_identical = identical(got$fills, ref$fills),
      equity_identical = identical(got$equity$equity, ref$equity$equity),
      cash_identical = identical(got$equity$cash, ref$equity$cash))
  }
  for (r in seq_len(rounds)) {
    order <- names(variants)[(seq_along(variants) + r - 2L) %% length(variants) + 1L]
    for (v in order) {
      gc(FALSE)
      t0 <- Sys.time(); variants[[v]](); t1 <- Sys.time()
      raw_rows[[length(raw_rows) + 1L]] <- data.frame(shape = shape, round = r, variant = v,
        seconds = as.numeric(difftime(t1, t0, units = "secs")))
    }
  }
}
parity <- do.call(rbind, par_rows)
raw <- do.call(rbind, raw_rows)
summ <- do.call(rbind, lapply(split(raw, list(raw$shape, raw$variant), drop = TRUE), function(x) {
  n_pulse <- as.integer(strsplit(x$shape[[1]], "x")[[1]])[[2]]
  fl <- raw[raw$shape == x$shape[[1]] & raw$variant == "floor", ]
  paired <- x$seconds[order(x$round)] - fl$seconds[order(fl$round)]
  data.frame(shape = x$shape[[1]], variant = x$variant[[1]],
             us_per_pulse = round(stats::median(x$seconds) / n_pulse * 1e6, 2),
             above_floor_us = round(stats::median(paired) / n_pulse * 1e6, 2),
             above_floor_min_us = round(min(paired) / n_pulse * 1e6, 2),
             above_floor_max_us = round(max(paired) / n_pulse * 1e6, 2))
}))
lv <- c("floor", "skeleton", "no_try", "no_hook", "floor_record", "stages_only", "flat")
summ <- summ[order(match(summ$shape, shapes), match(summ$variant, lv)), ]
rownames(summ) <- NULL
utils::write.csv(parity, file.path(out, "parity.csv"), row.names = FALSE)
utils::write.csv(raw, file.path(out, "timings_raw.csv"), row.names = FALSE)
utils::write.csv(summ, file.path(out, "timings.csv"), row.names = FALSE)
print(parity, row.names = FALSE); print(summ, row.names = FALSE)
