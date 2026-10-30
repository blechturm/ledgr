# Summarize executed clocks; no fixture constants or expected timing table.
a <- commandArgs(TRUE)
arg <- function(key, default) {
  z <- grep(paste0('^--', key, '='), a, value = TRUE)
  if (length(z)) sub(paste0('^--', key, '='), '', z[1]) else default
}
base <- arg('base', 'C:/Users/maxth/AppData/Local/Temp/ws4a-census-base')
fork <- arg('fork', 'C:/Users/maxth/AppData/Local/Temp/ws4a-census-fork')
ffdir <- arg('fork-floor', 'C:/Users/maxth/AppData/Local/Temp/ws4a-census-fork-floor')
out <- arg('out', 'C:/Users/maxth/AppData/Local/Temp/ws4a-summary')
dir.create(out, recursive = TRUE, showWarnings = FALSE)
b <- read.csv(file.path(base, 'timings.csv'))
f <- if (file.exists(file.path(fork, 'timings.csv'))) read.csv(file.path(fork, 'timings.csv')) else b[FALSE, ]
ff <- read.csv(file.path(ffdir, 'timings.csv'))
clocks <- rbind(transform(b, phase = 'base_census'), if (nrow(f)) transform(f, phase = 'fork_census') else NULL, transform(ff, phase = 'fork_floor_pairs'))
write.csv(clocks, file.path(out, 'timings.csv'), row.names = FALSE)
rows <- list(); n <- 0L
for (producer in unique(clocks$producer)) for (arm in c('base', 'fork')) {
  cells <- if (arm == 'fork') ff[ff$arm == arm & ff$producer == producer, ] else b[b$producer == producer, ]
  if (!nrow(cells)) next
  for (shape in c('sparse', 'wide')) {
    work <- cells[cells$shape == shape, ]
    floor <- cells[cells$shape == 'floor' & cells$comparison == shape, ]
    work <- work[order(work$pair), ]; floor <- floor[order(floor$pair), ]
    stopifnot(nrow(work) == 5L, nrow(floor) == 5L, all(work$fills == work$fills[1]))
    n <- n + 1L
    rows[[n]] <- data.frame(producer, arm, shape, pairs = nrow(work), pulses = work$pulses[1],
      fills = work$fills[1], median_seconds = median(work$seconds), floor_seconds = median(floor$seconds),
      marginal_us_per_fill = median((work$seconds - floor$seconds) * 1e6 / work$fills))
  }
}
write.csv(do.call(rbind, rows), file.path(out, 'marginal_costs.csv'), row.names = FALSE)
print(do.call(rbind, rows))
