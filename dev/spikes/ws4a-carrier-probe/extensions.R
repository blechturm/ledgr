# Additional arms and quiet-host durable reruns. Children are fresh and serial.
a <- commandArgs(TRUE)
arg <- function(k, d) {
  z <- grep(paste0('^--', k, '='), a, value = TRUE)
  if (length(z)) sub(paste0('^--', k, '='), '', z[1]) else d
}
folder <- dirname(normalizePath(sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]), winslash = '/'))
out <- arg('out', file.path(Sys.getenv('TEMP'), 'ws4a-additional'))
lib <- arg('lib', 'C:/Users/maxth/AppData/Local/Temp/ws4a-lib')
prepared <- arg('prepared', 'C:/Users/maxth/AppData/Local/Temp/ws4a-evidence')
phase <- arg('phase', 'timing')
requested <- arg('arms', '')
workloads <- strsplit(arg('workloads', 'wide'), ',', fixed = TRUE)[[1L]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home('bin'), 'Rscript.exe')
ps <- 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
host <- function(exclude = integer()) {
  command <- "Get-Process | Where-Object { $_.ProcessName -in @('Rscript','Rterm','R') } | Select-Object Id,CPU | ConvertTo-Csv -NoTypeInformation"
  text <- system2(ps, c('-NoProfile', '-Command', shQuote(command)), stdout = TRUE)
  if (!length(text)) return(setNames(numeric(), character()))
  x <- read.csv(text = paste(text, collapse = '\n'))
  x <- x[!x$Id %in% c(Sys.getpid(), exclude), , drop = FALSE]
  setNames(x$CPU, as.character(x$Id))
}
activity <- function(before, after) {
  prior <- before[names(after)]; prior[is.na(prior)] <- 0
  sum(pmax(after - prior, 0), na.rm = TRUE)
}
quiet <- function() {
  repeat {
    before <- host(); Sys.sleep(2); after <- host()
    if (activity(before, after) < 0.2) return(after)
    cat('Waiting for quiet host; external R CPU is active\n'); flush.console()
    Sys.sleep(3)
  }
}
run <- function(tag, workflow, arm, shape, profile = 'none') {
  attempt <- 1L
  repeat {
    child <- file.path(out, paste0(tag, '_attempt', attempt))
    qfile <- file.path(child, 'qualification.csv')
    if (file.exists(qfile) && isTRUE(read.csv(qfile)$qualified[[1L]])) return(child)
    if (dir.exists(child)) { attempt <- attempt + 1L; next }
    dir.create(child)
    idle <- quiet()
    start <- format(Sys.time(), '%Y-%m-%dT%H:%M:%OS3Z', tz = 'UTC')
    p <- processx::process$new(rscript, c(file.path(folder, 'probe.R'),
      paste0('--out=', child), paste0('--lib=', lib), paste0('--prepared=', prepared),
      paste0('--mode=', if (workflow == 'durable') 'durable' else 'worker'),
      paste0('--arm=', arm), paste0('--shape=', shape), paste0('--profile=', profile)),
      stdout = file.path(child, 'stdout.txt'), stderr = file.path(child, 'stderr.txt'))
    previous <- host(p$get_pid()); foreign_cpu <- 0
    while (p$is_alive()) {
      Sys.sleep(2)
      next_host <- host(p$get_pid())
      foreign_cpu <- foreign_cpu + activity(previous, next_host)
      previous <- next_host
    }
    p$wait()
    if (p$get_exit_status() != 0L) stop('child failed: ', child)
    qualified <- foreign_cpu < 0.5
    write.csv(data.frame(qualified, external_R_cpu_seconds = foreign_cpu, external_R_ids = paste(union(names(idle), names(previous)), collapse = ';'), start_utc = start,
      end_utc = format(Sys.time(), '%Y-%m-%dT%H:%M:%OS3Z', tz = 'UTC')),
      qfile, row.names = FALSE)
    if (qualified) {
      cat(tag, 'qualified\n'); flush.console(); return(child)
    }
    cat(tag, 'excluded for external R overlap; retrying after quiet interval\n'); flush.console()
    attempt <- attempt + 1L
  }
}
if (phase == 'one_component') {
  stopifnot(length(workloads) == 1L, nzchar(requested), !grepl(',', requested, fixed = TRUE))
  run(paste(workloads, requested, 'component_repeat', sep = '_'), 'sweep', requested, workloads, 'components')
} else if (phase == 'timing') {
  rows <- list(); n <- 0L
  for (workflow in c('sweep', 'durable')) {
    arms <- if (workflow == 'sweep') c('fork_r', 'fork_indexed', 'fork_r_indexed') else c('base', 'fork', 'fork_r', 'fork_indexed', 'fork_r_indexed')
    if (nzchar(requested)) arms <- strsplit(requested, ',', fixed = TRUE)[[1L]]
    for (workload in workloads) for (arm in arms) for (pair in 1:5) {
      for (k in if (pair %% 2L) 1:2 else 2:1) {
        shape <- if (k == 1L) 'floor' else workload
        tag <- paste(workflow, arm, pair, shape, sep = '_')
        if (length(workloads) > 1L) tag <- paste(workload, tag, sep = '_')
        child <- run(tag, workflow, arm, shape)
        z <- read.csv(file.path(child, 'timing.csv'))
        z$workflow <- workflow; z$pair <- pair; z$order <- k
        z$workload <- workload
        n <- n + 1L; rows[[n]] <- z
        write.csv(do.call(rbind, rows), file.path(out, 'additional_timings.csv'), row.names = FALSE)
      }
    }
  }
} else {
  rows <- list(); n <- 0L
  for (workflow in c('sweep', 'durable')) {
    arms <- if (workflow == 'sweep') c('fork_r', 'fork_indexed', 'fork_r_indexed') else c('base', 'fork', 'fork_r', 'fork_indexed', 'fork_r_indexed')
    if (nzchar(requested)) arms <- strsplit(requested, ',', fixed = TRUE)[[1L]]
    for (workload in workloads) for (arm in arms) for (shape in if (workflow == 'sweep') c('floor', workload) else workload) {
      tag <- paste(workflow, arm, shape, 'components', sep = '_')
      if (length(workloads) > 1L) tag <- paste(workload, tag, sep = '_')
      child <- run(tag, workflow, arm, shape, 'components')
      z <- read.csv(file.path(child, 'components.csv'))
      z$workflow <- workflow; z$arm <- arm; z$shape <- shape; z$workload <- workload
      n <- n + 1L; rows[[n]] <- z
      write.csv(do.call(rbind, rows), file.path(out, 'additional_components.csv'), row.names = FALSE)
      if (workflow == 'sweep') {
        memory_tag <- paste(workflow, arm, shape, 'memory', sep = '_')
        if (length(workloads) > 1L) memory_tag <- paste(workload, memory_tag, sep = '_')
        run(memory_tag, workflow, arm, shape, 'memory')
      }
    }
  }
}
