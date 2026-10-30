# Derive component attribution from diagnostic runs, separately from paired clocks.
a <- commandArgs(TRUE)
arg <- function(key, default) {
  z <- grep(paste0('^--', key, '='), a, value = TRUE)
  if (length(z)) sub(paste0('^--', key, '='), '', z[1]) else default
}
profiles <- arg('profiles', 'C:/Users/maxth/AppData/Local/Temp/ws4a-profiles')
components <- arg('components', 'C:/Users/maxth/AppData/Local/Temp/ws4a-components-final')
durable <- arg('durable', '')
out <- arg('out', 'C:/Users/maxth/AppData/Local/Temp/ws4a-summary')
dir.create(out, recursive = TRUE, showWarnings = FALSE)
script_folder <- dirname(normalizePath(sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]), winslash = '/'))
source(file.path(script_folder, 'profile-read.R'))
wall <- read.csv(file.path(components, 'components.csv'))
if (nzchar(durable) && file.exists(file.path(durable, 'durable_components.csv'))) wall <- rbind(wall,
  read.csv(file.path(durable, 'durable_components.csv')))
write.csv(wall, file.path(out, 'component_clocks.csv'), row.names = FALSE)
rows <- list(); n <- 0L
for (wf in unique(wall$workflow)) for (p in unique(wall$producer)) for (ar in unique(wall$arm))
  for (sh in unique(wall$shape)) {
    z <- wall[wall$workflow == wf & wall$producer == p & wall$arm == ar & wall$shape == sh, ]
    if (!nrow(z)) next
    g <- function(name) sum(z$seconds[z$component == name])
    payload <- g(if (ar == 'base') 'ledgr_fill_event_payload' else 'carrier_payload')
    lot <- g(if (ar == 'base') 'ledgr_lot_apply_fill' else 'carrier_lots')
    event <- if (ar == 'base') g('handler_write_fill_events') - payload +
      g('handler_record_accounting_fact') + g('handler_flush_pulse_events') else
      g('carrier_events') - payload + g('handler_flush_pulse_events')
    context <- g('ledgr_update_pulse_context_helpers')
    validation <- g('ledgr_validate_strategy_targets') + g('ledgr_validate_post_risk_targets')
    totals <- c(plan = g('ledgr_fold_stage_plan'), lot_kernel = lot, fill_payload = payload,
      event_batch = event, observe = g('ledgr_fold_stage_observe_settle'),
      context_refresh = context, target_validation = validation,
      decide_other = g('ledgr_fold_stage_decide') - context - validation,
      commit_other = g('ledgr_fold_stage_commit') - g('handler_flush_pulse_events'))
    if (wf == 'durable') totals <- totals['fill_payload']
    n <- n + 1L
    rows[[n]] <- data.frame(workflow = wf, producer = p, arm = ar, shape = sh,
      component = names(totals), seconds = as.numeric(totals))
  }
exclusive <- do.call(rbind, rows)
write.csv(exclusive, file.path(out, 'component_exclusive.csv'), row.names = FALSE)
allocation_rows <- list(); count <- 0L
for (p in c('dense', 'availability')) for (ar in if (p == 'dense') 'base' else c('base', 'fork'))
  for (sh in c('floor', 'sparse', 'wide')) {
    directory <- file.path(profiles, paste(p, ar, sh, 'memory', sep = '_'))
    timing <- read.csv(file.path(directory, 'timing.csv'))
    parsed <- read_allocation_profile(directory)
    totals <- setNames(parsed$bytes, parsed$component)
    pages <- parsed$unpriced_new_pages
    count <- count + 1L
    allocation_rows[[count]] <- data.frame(producer = p, arm = ar, shape = sh,
      component = names(totals), bytes = as.numeric(totals), unpriced_new_pages = as.integer(pages),
      pulses = timing$pulses, fills = timing$fills,
      bytes_per_pulse = as.numeric(totals) / timing$pulses,
      bytes_per_fill = if (timing$fills) as.numeric(totals) / timing$fills else NA_real_)
  }
alloc <- do.call(rbind, allocation_rows)
write.csv(alloc, file.path(out, 'allocations.csv'), row.names = FALSE)
rows <- list(); n <- 0L
for (p in unique(alloc$producer)) for (ar in unique(alloc$arm)) for (sh in c('sparse', 'wide')) {
  x <- alloc[alloc$producer == p & alloc$arm == ar & alloc$shape == sh, ]
  f <- alloc[alloc$producer == p & alloc$arm == ar & alloc$shape == 'floor', ]
  if (!nrow(x)) next
  fbytes <- setNames(f$bytes, f$component)[x$component]; fbytes[is.na(fbytes)] <- 0
  x$marginal_bytes_per_fill <- (x$bytes - fbytes) / x$fills
  n <- n + 1L; rows[[n]] <- x
}
write.csv(do.call(rbind, rows), file.path(out, 'allocation_marginals.csv'), row.names = FALSE)
calls <- read.csv(file.path(components, 'calls.csv'))
rows <- list(); n <- 0L
for (p in unique(calls$producer)) for (ar in unique(calls$arm)) {
  w <- calls[calls$producer == p & calls$arm == ar & calls$shape == 'wide', ]
  f <- calls[calls$producer == p & calls$arm == ar & calls$shape == 'floor', ]
  if (!nrow(w)) next
  w$floor_calls <- setNames(f$calls, f$fn)[w$fn]
  w$marginal_calls_per_fill <- (w$calls - w$floor_calls) / w$fills
  n <- n + 1L; rows[[n]] <- w
}
write.csv(do.call(rbind, rows), file.path(out, 'call_chain.csv'), row.names = FALSE)
print(exclusive[exclusive$shape == 'wide' & exclusive$producer == 'availability' &
  exclusive$component %in% c('plan', 'lot_kernel', 'fill_payload', 'event_batch'), ])
