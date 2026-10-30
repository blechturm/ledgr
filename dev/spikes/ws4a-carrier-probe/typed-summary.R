# Addendum only. Original clocks, CSVs and verdict are immutable.
a <- commandArgs(TRUE)
arg <- function(k, d) { z <- grep(paste0('^--', k, '='), a, value = TRUE); if (length(z)) sub(paste0('^--', k, '='), '', z[1]) else d }
folder <- dirname(normalizePath(sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]), winslash = '/'))
timing <- arg('timing', file.path(Sys.getenv('TEMP'), 'ws4a-typed-timing'))
profiles <- arg('profiles', file.path(Sys.getenv('TEMP'), 'ws4a-typed-profiles'))
out <- arg('out', file.path(Sys.getenv('TEMP'), 'ws4a-typed-summary'))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path(folder, 'profile-read.R'))
t <- read.csv(file.path(timing, 'additional_timings.csv'))
c <- read.csv(file.path(profiles, 'additional_components.csv'))
arms <- c('fork_r_indexed', 'fork_indexed', 'fork_typed')
alloc <- list(); n <- 0L
for (w in c('wide', 'partial')) for (arm in arms) for (shape in c('floor', w)) {
  tag <- paste(w, 'sweep', arm, shape, 'memory', sep = '_')
  dirs <- list.dirs(profiles, recursive = FALSE)
  dirs <- dirs[startsWith(basename(dirs), paste0(tag, '_attempt'))]
  dirs <- dirs[vapply(dirs, function(d) { f <- file.path(d, 'qualification.csv'); file.exists(f) && isTRUE(read.csv(f)$qualified[1]) }, logical(1))]
  stopifnot(length(dirs) == 1L)
  z <- read_allocation_profile(dirs)
  clock <- read.csv(file.path(dirs, 'timing.csv'))
  z$arm <- arm; z$workload <- w; z$shape <- shape; z$fills <- clock$fills; z$pulses <- clock$pulses
  z$bytes_per_pulse <- z$bytes / z$pulses; z$bytes_per_fill <- if (clock$fills) z$bytes / z$fills else NA_real_
  n <- n + 1L; alloc[[n]] <- z
}
alloc <- do.call(rbind, alloc)
rows <- splitrows <- list(); n <- 0L
for (workflow in c('sweep', 'durable')) for (w in c('wide', 'partial')) for (arm in arms) {
  z <- t[t$workflow == workflow & t$workload == w & t$arm == arm, ]
  work <- z[z$shape == w, ]; floor <- z[z$shape == 'floor', ]
  work <- work[order(work$pair), ]; floor <- floor[order(floor$pair), ]
  stopifnot(nrow(work) == 5L, nrow(floor) == 5L, identical(work$pair, floor$pair))
  cc <- c[c$workflow == workflow & c$workload == w & c$shape == w & c$arm == arm, ]
  g <- function(name) sum(cc$seconds[cc$component == name])
  lot <- g(if (arm == 'fork_typed') 'typed_lot_kernel' else 'carrier_lots')
  boundary <- if (arm == 'fork_typed') g('carrier_lots_typed') - lot else 0
  payload <- g('carrier_payload')
  event <- g('carrier_events') - payload + g('handler_flush_pulse_events')
  al <- alloc[alloc$arm == arm & alloc$workload == w & alloc$component == 'total', ]
  bytes <- al$bytes[al$shape == w]; floor_bytes <- al$bytes[al$shape == 'floor']
  marginal <- median((work$seconds - floor$seconds) * 1e6 / work$fills)
  n <- n + 1L
  rows[[n]] <- data.frame(workflow, workload = w, arm, pairs = 5L, fills = work$fills[1],
    median_seconds = median(work$seconds), own_floor_seconds = median(floor$seconds), marginal_us_per_fill = marginal,
    lot_kernel_seconds = lot, lot_boundary_seconds = boundary, plan_seconds = g('ledgr_fold_stage_plan'),
    fill_payload_seconds = payload, event_batch_seconds = event,
    sweep_Rprofmem_bytes = bytes, sweep_marginal_bytes_per_fill = (bytes - floor_bytes) / work$fills[1],
    bounds_result = if (workflow == 'durable') NA_character_ else if (marginal <= 40) 'GREEN' else if (marginal > 80) 'RED' else 'INCONCLUSIVE')
  splitrows[[n]] <- data.frame(workflow, workload = w, arm,
    component = c('plan', 'lot_kernel', 'lot_boundary', 'fill_payload', 'event_batch'),
    seconds = c(g('ledgr_fold_stage_plan'), lot, boundary, payload, event))
}
write.csv(do.call(rbind, rows), file.path(out, 'typed_arms.csv'), row.names = FALSE)
write.csv(do.call(rbind, splitrows), file.path(out, 'typed_components.csv'), row.names = FALSE)
write.csv(alloc, file.path(out, 'typed_allocations.csv'), row.names = FALSE)
write.csv(t, file.path(out, 'typed_timings.csv'), row.names = FALSE)
write.csv(c, file.path(out, 'typed_component_clocks.csv'), row.names = FALSE)
print(do.call(rbind, rows))
host <- do.call(rbind, lapply(c(timing, profiles), function(root) {
  files <- list.files(root, pattern = '^qualification[.]csv$', recursive = TRUE, full.names = TRUE)
  do.call(rbind, lapply(files, function(f) {
    z <- read.csv(f); z$phase <- basename(root); z$sample <- basename(dirname(f)); z
  }))
}))
write.csv(host, file.path(out, 'typed_host.csv'), row.names = FALSE)
floors <- list(); n <- 0L
for (w in c('wide', 'partial')) for (arm in arms) {
  z <- c[c$workflow == 'sweep' & c$workload == w & c$arm == arm & c$shape == 'floor', ]
  g <- function(name) sum(z$seconds[z$component == name])
  context <- g('ledgr_update_pulse_context_helpers')
  validation <- g('ledgr_validate_strategy_targets') + g('ledgr_validate_post_risk_targets')
  seconds <- c(context_refresh = context, validation = validation,
    decide_other = g('ledgr_fold_stage_decide') - context - validation,
    commit_other = g('ledgr_fold_stage_commit') - g('handler_flush_pulse_events'))
  n <- n + 1L; floors[[n]] <- data.frame(workload = w, arm, component = names(seconds),
    seconds = as.numeric(seconds), us_per_pulse = as.numeric(seconds) * 1e6 / 1260)
}
write.csv(do.call(rbind, floors), file.path(out, 'typed_floor_components.csv'), row.names = FALSE)
floor_bytes <- alloc[alloc$shape == 'floor', c('arm', 'workload', 'component', 'bytes')]
names(floor_bytes)[4] <- 'floor_bytes'
marginal_alloc <- merge(alloc[alloc$shape != 'floor', ], floor_bytes,
  by = c('arm', 'workload', 'component'), all.x = TRUE, sort = FALSE)
marginal_alloc$floor_bytes[is.na(marginal_alloc$floor_bytes)] <- 0
marginal_alloc$marginal_bytes_per_fill <- (marginal_alloc$bytes - marginal_alloc$floor_bytes) / marginal_alloc$fills
write.csv(marginal_alloc, file.path(out, 'typed_allocation_marginals.csv'), row.names = FALSE)
