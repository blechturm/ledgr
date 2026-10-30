# Measurements are diagnostic evidence, not release gates. Children are serial.
a <- commandArgs(TRUE)
arg <- function(key, default) {
  z <- grep(paste0('^--', key, '='), a, value = TRUE)
  if (length(z)) sub(paste0('^--', key, '='), '', z[1]) else default
}
folder <- dirname(normalizePath(sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]), winslash = '/'))
out <- arg('out', file.path(tempdir(), 'ws4a-measure'))
lib <- arg('lib', 'C:/Users/maxth/AppData/Local/Temp/ws4a-lib')
prepared <- arg('prepared', 'C:/Users/maxth/AppData/Local/Temp/ws4a-evidence')
dir.create(out, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home('bin'), 'Rscript.exe')
run <- function(tag, args, sentinel = 'timing.csv') {
  child <- file.path(out, tag); dir.create(child, showWarnings = FALSE)
  if (!file.exists(file.path(child, sentinel))) {
    code <- system2(rscript, shQuote(c(file.path(folder, 'probe.R'), paste0('--out=', child),
      paste0('--lib=', lib), paste0('--prepared=', prepared), args)),
      stdout = file.path(child, 'stdout.txt'), stderr = file.path(child, 'stderr.txt'))
    if (code) stop('measurement child failed: ', child)
  }
  cat(tag, 'complete\n'); flush.console()
  child
}
if (arg('phase', 'profiles') == 'components') {
  components <- list(); calls <- list(); nc <- nk <- 0L
  for (producer in c('dense', 'availability')) for (arm in if (producer == 'dense') 'base' else c('base', 'fork'))
    for (shape in c('floor', 'sparse', 'wide')) {
      common <- c(paste0('--producer=', producer), paste0('--arm=', arm), paste0('--shape=', shape))
      tag <- paste(producer, arm, shape, sep = '_')
      child <- run(paste0(tag, '_components'), c(common, '--profile=components'))
      z <- read.csv(file.path(child, 'components.csv'))
      z$producer <- producer; z$arm <- arm; z$shape <- shape; z$workflow <- 'sweep'
      nc <- nc + 1L; components[[nc]] <- z
      if (shape != 'sparse') {
        child <- run(paste0(tag, '_calls'), c(common, '--profile=calls'))
        z <- read.csv(file.path(child, 'calls.csv'))
        z$producer <- producer; z$arm <- arm; z$shape <- shape
        nk <- nk + 1L; calls[[nk]] <- z
      }
      write.csv(do.call(rbind, components), file.path(out, 'components.csv'), row.names = FALSE)
      write.csv(do.call(rbind, calls), file.path(out, 'calls.csv'), row.names = FALSE)
    }
  quit(save = 'no')
}
if (arg('phase', 'profiles') == 'durable') {
  results <- list()
  for (arm in c('base', 'fork')) {
    child <- run(paste0('availability_', arm, '_durable_components'),
      c('--mode=durable', paste0('--arm=', arm), '--producer=availability', '--profile=components'))
    z <- read.csv(file.path(child, 'components.csv'))
    z$producer <- 'availability'; z$arm <- arm; z$shape <- 'wide'; z$workflow <- 'durable'
    results[[arm]] <- z
  }
  write.csv(do.call(rbind, results), file.path(out, 'durable_components.csv'), row.names = FALSE)
  quit(save = 'no')
}
if (arg('phase', 'profiles') == 'fork') {
  run('fork', c('--mode=census', '--phase=fork'), 'timings.csv')
  quit(save = 'no')
}
alloc <- list(); comp <- list(); calls <- list(); na <- nc <- nk <- 0L
for (producer in c('dense', 'availability')) for (arm in if (producer == 'dense') 'base' else c('base', 'fork')) {
  for (shape in c('floor', 'sparse', 'wide')) {
    common <- c(paste0('--producer=', producer), paste0('--arm=', arm), paste0('--shape=', shape))
    tag <- paste(producer, arm, shape, sep = '_')
    mem <- run(paste0(tag, '_memory'), c(common, '--profile=memory'))
    timing <- read.csv(file.path(mem, 'timing.csv'))
    lines <- readLines(file.path(mem, 'allocations.log'), warn = FALSE)
    size <- suppressWarnings(as.numeric(sub(' .*', '', lines)))
    # Rprofmem reports R-visible allocation, including Rcpp R allocations,
    # not malloc/RSS. Stack classifications are exclusive, inner component first.
    component <- rep('other_setup_results', length(lines))
    component[grepl('ledgr_fold_stage_commit', lines, fixed = TRUE)] <- 'commit'
    component[grepl('ledgr_fold_stage_decide', lines, fixed = TRUE)] <- 'decide'
    component[grepl('ledgr_fold_stage_observe_settle', lines, fixed = TRUE)] <- 'observe'
    component[grepl('ledgr_fold_stage_apply', lines, fixed = TRUE)] <- 'apply_other'
    component[grepl('ledgr_fold_stage_plan', lines, fixed = TRUE)] <- 'plan'
    component[grepl('carrier_events|ledgr_fill_event_payload|record_accounting_fact|write_fill_events|flush_pulse_events', lines)] <- 'event_batch'
    component[grepl('carrier_lots|ledgr_lot_apply_fill', lines)] <- 'lot_kernel'
    component[grepl('carrier_payload|ledgr_fill_event_payload', lines)] <- 'fill_payload'
    valid <- is.finite(size)
    totals <- tapply(size[valid], component[valid], sum)
    totals <- c(totals, total = sum(size[valid]))
    na <- na + 1L
    alloc[[na]] <- data.frame(producer, arm, shape, component = names(totals), bytes = as.numeric(totals),
      pulses = timing$pulses, fills = timing$fills, bytes_per_pulse = as.numeric(totals) / timing$pulses,
      bytes_per_fill = if (timing$fills) as.numeric(totals) / timing$fills else NA_real_)
    rm(lines, size); gc(FALSE)
    wall <- run(paste0(tag, '_components'), c(common, '--profile=components'))
    z <- read.csv(file.path(wall, 'components.csv'))
    z$producer <- producer; z$arm <- arm; z$shape <- shape
    nc <- nc + 1L; comp[[nc]] <- z
    if (shape != 'sparse') {
      cnt <- run(paste0(tag, '_calls'), c(common, '--profile=calls'))
      z <- read.csv(file.path(cnt, 'calls.csv'))
      z$producer <- producer; z$arm <- arm; z$shape <- shape
      nk <- nk + 1L; calls[[nk]] <- z
    }
    write.csv(do.call(rbind, alloc), file.path(out, 'allocations.csv'), row.names = FALSE)
    write.csv(do.call(rbind, comp), file.path(out, 'components.csv'), row.names = FALSE)
    write.csv(do.call(rbind, calls), file.path(out, 'calls.csv'), row.names = FALSE)
  }
}
for (producer in c('dense', 'availability')) run(paste0(producer, '_floor_cpu'),
  c(paste0('--producer=', producer), '--shape=floor', '--profile=cpu'))
