# Additional rows only: the original measurements and verdict stay frozen.
a <- commandArgs(TRUE)
arg <- function(k, d) {
  z <- grep(paste0('^--', k, '='), a, value = TRUE)
  if (length(z)) sub(paste0('^--', k, '='), '', z[1]) else d
}
folder <- dirname(normalizePath(sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]), winslash = '/'))
timing_dir <- arg('timing', file.path(Sys.getenv('TEMP'), 'ws4a-additional-timing'))
profile_dir <- arg('profiles', file.path(Sys.getenv('TEMP'), 'ws4a-additional-profiles'))
out <- arg('out', file.path(Sys.getenv('TEMP'), 'ws4a-additional-summary'))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path(folder, 'profile-read.R'))
stopifnot(all(read.csv(file.path(folder, 'identity.csv'))$identical))
times <- read.csv(file.path(timing_dir, 'additional_timings.csv'))
clocks <- read.csv(file.path(profile_dir, 'additional_components.csv'))
write.csv(clocks, file.path(out, 'additional_components.csv'), row.names = FALSE)
pick <- function(tag) {
  dirs <- list.dirs(profile_dir, recursive = FALSE, full.names = TRUE)
  dirs <- dirs[startsWith(basename(dirs), paste0(tag, '_attempt'))]
  good <- vapply(dirs, function(d) {
    f <- file.path(d, 'qualification.csv')
    file.exists(f) && isTRUE(read.csv(f)$qualified[[1L]])
  }, logical(1))
  stopifnot(sum(good) == 1L)
  dirs[good]
}
allocations <- list(); na <- 0L
for (arm in c('fork_r', 'fork_indexed', 'fork_r_indexed')) for (shape in c('floor', 'wide')) {
  d <- pick(paste('sweep', arm, shape, 'memory', sep = '_'))
  z <- read_allocation_profile(d)
  t <- read.csv(file.path(d, 'timing.csv'))
  z$arm <- arm; z$shape <- shape; z$fills <- t$fills; z$pulses <- t$pulses
  z$bytes_per_pulse <- z$bytes / z$pulses
  z$bytes_per_fill <- if (t$fills) z$bytes / z$fills else NA_real_
  na <- na + 1L; allocations[[na]] <- z
}
allocation <- do.call(rbind, allocations)
write.csv(allocation, file.path(out, 'additional_allocations.csv'), row.names = FALSE)
rows <- list(); nr <- 0L; component_rows <- list()
for (workflow in unique(times$workflow)) for (arm in unique(times$arm[times$workflow == workflow])) {
  z <- times[times$workflow == workflow & times$arm == arm, ]
  work <- z[z$shape == 'wide', ]; floor <- z[z$shape == 'floor', ]
  work <- work[order(work$pair), ]; floor <- floor[order(floor$pair), ]
  stopifnot(nrow(work) == 5L, nrow(floor) == 5L, identical(work$pair, floor$pair))
  marginal <- median((work$seconds - floor$seconds) * 1e6 / work$fills)
  c <- clocks[clocks$workflow == workflow & clocks$arm == arm & clocks$shape == 'wide', ]
  g <- function(nm) sum(c$seconds[c$component == nm])
  payload <- g(if (arm == 'base') 'ledgr_fill_event_payload' else 'carrier_payload')
  lot <- g(if (arm == 'base') 'ledgr_lot_apply_fill' else 'carrier_lots')
  event <- if (arm == 'base') g('handler_write_fill_events') - payload +
    g('handler_record_accounting_fact') + g('handler_flush_pulse_events') else
    g('carrier_events') - payload + g('handler_flush_pulse_events')
  bytes <- allocated <- NA_real_
  if (workflow == 'sweep') {
    al <- allocation[allocation$arm == arm & allocation$component == 'total', ]
    bytes <- al$bytes[al$shape == 'wide']
    allocated <- (bytes - al$bytes[al$shape == 'floor']) / work$fills[1L]
  }
  nr <- nr + 1L
  rows[[nr]] <- data.frame(workflow, arm, pairs = 5L, fills = work$fills[1L],
    median_seconds = median(work$seconds), own_floor_seconds = median(floor$seconds),
    marginal_us_per_fill = marginal, lot_kernel_seconds = lot, fill_payload_seconds = payload,
    event_batch_seconds = event, explicit_allocated_bytes = bytes,
    marginal_allocated_bytes_per_fill = allocated,
    bounds_result = if (workflow == 'durable') NA_character_ else
      if (marginal <= 40) 'GREEN' else if (marginal > 80) 'RED' else 'INCONCLUSIVE')
  component_rows[[nr]] <- data.frame(workflow, arm,
    component = c('plan', 'lot_kernel', 'fill_payload', 'event_batch'),
    seconds = c(g('ledgr_fold_stage_plan'), lot, payload, event))
}
write.csv(do.call(rbind, rows), file.path(out, 'additional_arms.csv'), row.names = FALSE)
write.csv(do.call(rbind, component_rows), file.path(out, 'additional_component_exclusive.csv'), row.names = FALSE)
print(do.call(rbind, rows))
