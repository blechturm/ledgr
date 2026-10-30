# WS4a bounded probe; R 4.6.1. The two arms load the same archive install.
# --mode=worker --arm=base|fork --producer=dense|availability --shape=floor|sparse|wide
# --mode=census launches alternating fresh children, five pairs per comparison.
# --mode=identity writes full native outputs; --mode=a0 runs applicable A0 workloads.
a <- commandArgs(TRUE)
arg <- function(key, default = NULL) {
  x <- grep(paste0('^--', key, '='), a, value = TRUE)
  if (length(x)) sub(paste0('^--', key, '='), '', x[[1]]) else default
}
folder <- dirname(normalizePath(sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]), winslash = '/'))
root <- normalizePath(file.path(folder, '../../..'), winslash = '/')
out <- arg('out', file.path(tempdir(), 'ws4a'))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
mode <- arg('mode', 'worker'); arm <- arg('arm', 'base')
producer <- arg('producer', 'availability'); shape <- arg('shape', 'wide')
lib <- arg('lib', 'C:/Users/maxth/AppData/Local/Temp/ws4a-lib')
prepared <- arg('prepared', 'C:/Users/maxth/AppData/Local/Temp/ws4a-evidence')
.libPaths(c(lib, .libPaths()))
write <- function(x, name) write.csv(x, file.path(out, name), row.names = FALSE)
rscript <- file.path(R.home('bin'), 'Rscript.exe')
if (mode == 'census') {
  rows <- list(); nr <- 0L
  # Baseline census: adjacent floor/workload children, order reversed per pair.
  # Fork census: adjacent base/fork children, for each of the three shapes.
  fork <- identical(arg('phase', 'base'), 'fork')
  floorfork <- identical(arg('phase', 'base'), 'fork_floor')
  floor_arm <- arg('arm', 'fork')
  for (p in if (fork || floorfork) 'availability' else c('dense', 'availability')) {
    shapes <- strsplit(arg('shapes', if (fork) 'floor,sparse,wide' else 'sparse,wide'), ',', fixed = TRUE)[[1L]]
    for (s in shapes) {
      for (pair in seq_len(5L)) {
        order <- if (pair %% 2L) 1:2 else 2:1
        for (k in order) {
          ar <- if (floorfork) floor_arm else if (fork && k == 2L) 'fork' else 'base'
          sh <- if (!fork && k == 1L) 'floor' else s
          tag <- paste(p, s, pair, k, sep = '_')
          child <- file.path(out, tag); dir.create(child, showWarnings = FALSE)
          if (file.exists(file.path(child, 'timing.csv'))) {
            z <- read.csv(file.path(child, 'timing.csv'))
            z$pair <- pair; z$comparison <- s; z$order <- k
            nr <- nr + 1L; rows[[nr]] <- z
            next
          }
          code <- system2(rscript, shQuote(c(file.path(folder, 'probe.R'), '--mode=worker',
            paste0('--out=', child), paste0('--lib=', lib), paste0('--prepared=', prepared),
            paste0('--producer=', p), paste0('--arm=', ar), paste0('--shape=', sh))),
            stdout = file.path(child, 'stdout.txt'), stderr = file.path(child, 'stderr.txt'))
          if (code) stop('child failed: ', child)
          z <- read.csv(file.path(child, 'timing.csv'))
          z$pair <- pair; z$comparison <- s; z$order <- k
          nr <- nr + 1L; rows[[nr]] <- z
          write(do.call(rbind, rows), 'timings.csv')
          cat(tag, ar, sh, z$seconds, 'seconds\n'); flush.console()
        }
      }
    }
  }
  quit(save = 'no')
}
suppressPackageStartupMessages(library(ledgr))
ns <- asNamespace('ledgr')
source(file.path(folder, 'carrier.R'))
if (arm != 'base') {
  stopifnot(arm %in% c('fork', 'fork_r', 'fork_indexed', 'fork_r_indexed', 'fork_typed'))
  carrier <- install_carrier(folder, arg('mutation', 'none'),
    lot = if (arm == 'fork_typed') 'typed' else if (arm %in% c('fork_r', 'fork_r_indexed')) 'R' else 'native',
    indexed = arm %in% c('fork_indexed', 'fork_r_indexed', 'fork_typed'))
}
profile <- arg('profile', 'none')
components <- new.env(parent = emptyenv())
if (profile == 'components') {
  instrument <- function(env, name, label) {
    force(label)
    orig <- get(name, env)
    wrap <- function(...) {
      start <- proc.time()[['elapsed']]; z <- orig(...)
      elapsed <- proc.time()[['elapsed']] - start
      old <- components[[label]]
      if (is.null(old)) old <- c(calls = 0, seconds = 0)
      components[[label]] <- old + c(calls = 1, seconds = elapsed)
      z
    }
    if (identical(env, ns)) utils::assignInNamespace(name, wrap, ns = 'ledgr') else assign(name, wrap, env)
  }
  for (name in c('ledgr_fold_stage_observe_settle', 'ledgr_fold_stage_decide', 'ledgr_fold_stage_plan', 'ledgr_fold_stage_apply', 'ledgr_fold_stage_commit'))
    instrument(ns, name, name)
  for (name in c('ledgr_lot_apply_fill', 'ledgr_fill_event_payload',
    'ledgr_update_pulse_context_helpers', 'ledgr_validate_strategy_targets', 'ledgr_validate_post_risk_targets'))
    if (exists(name, ns, inherits = FALSE) && !(arm %in% c('fork_r', 'fork_r_indexed') && name == 'ledgr_lot_apply_fill')) instrument(ns, name, name)
  if (arm != 'base') for (name in c('carrier_lots', 'carrier_events', 'carrier_payload', 'carrier_afford')) instrument(carrier, name, name)
  if (arm == 'fork_typed') for (name in c('carrier_lots_typed', 'typed_lot_kernel', 'typed_lot_import', 'typed_lot_export')) instrument(carrier, name, name)
  original_factory <- ns$ledgr_output_handler
  timed_method <- function(original, label) {
    force(original); force(label)
    function(...) {
      start <- proc.time()[['elapsed']]; z <- original(...)
      elapsed <- proc.time()[['elapsed']] - start
      old <- components[[label]]
      if (is.null(old)) old <- c(calls = 0, seconds = 0)
      components[[label]] <- old + c(calls = 1, seconds = elapsed)
      z
    }
  }
  utils::assignInNamespace('ledgr_output_handler', function(sink, ...) {
    h <- original_factory(sink, ...)
    for (nm in c('write_fill_events', 'record_accounting_fact', 'flush_pulse_events'))
      if (is.function(h[[nm]])) h[[nm]] <- timed_method(h[[nm]], paste0('handler_', nm))
    h
  }, ns = 'ledgr')
}

# Capture native fold output only for identity; this is outside the timed call.
fold_results <- list(); handlers <- list()
if (mode %in% c('identity', 'durable', 'a0')) {
  original_fold <- ns$ledgr_execute_fold
  utils::assignInNamespace('ledgr_execute_fold', function(execution, output_handler) {
    z <- original_fold(execution, output_handler)
    fold_results[[length(fold_results)+1L]] <<- z
    handlers[[length(handlers)+1L]] <<- output_handler
    z
  }, ns = 'ledgr')
}
if (mode == 'a0') {
  source(file.path(root, 'dev/bench/v0_2_3_output_freeze/lib.R'))
  source(file.path(root, 'dev/bench/v0_2_3_output_freeze/fixtures.R'))
  ids <- c('avail_terminal_resume', 'avail_acquisition', 'avail_incomplete', 'walk_forward', 'failures')
  for (id in ids) {
    a0_workloads[[id]]$paths <- intersect(a0_workloads[[id]]$paths,
      c('run', 'run_resumed', 'sweep_w1', 'walk_forward'))
  }
  result <- a0_run_all(file.path(out, 'scratch'), ids = ids)
  # A0 itself observes all public/durable outputs. Add exact terminal lot/state
  # objects for the requirement that ledger parity alone is insufficient.
  states <- lapply(fold_results, function(x) list(state = x$state, state_prev = x$state_prev))
  saveRDS(list(outputs = result, states = states), file.path(out, 'identity.rds'))
  quit(save = 'no')
}
strategy <- function(ctx, params) {
  fast <- ctx$vec$feature('fast'); slow <- ctx$vec$feature('slow')
  usable <- is.finite(fast) & is.finite(slow); above <- usable & fast > slow
  prev_above <- if (is.null(ctx$state_prev$above)) rep(FALSE, length(usable)) else as.logical(ctx$state_prev$above)
  prev_usable <- if (is.null(ctx$state_prev$usable)) rep(FALSE, length(usable)) else as.logical(ctx$state_prev$usable)
  targets <- ctx$hold()
  tick <- if (is.null(ctx$state_prev$tick)) 1L else as.integer(ctx$state_prev$tick) + 1L
  if (params$shape == 'wide') {
    targets[prev_usable & usable & above & !prev_above] <- 1
    targets[prev_usable & usable & !above & prev_above] <- 0
  } else if (params$shape == 'partial') {
    targets[prev_usable & usable & above & !prev_above] <- 2
    targets[prev_usable & usable & !above & prev_above] <- 1
  } else if (params$shape == 'sparse' && tick %% 21L == 0L) {
    # Monthly top-20 momentum spread on the same SMA planes, unit positions.
    targets[] <- 0
    eligible <- which(usable)
    top <- head(eligible[order((fast - slow)[eligible], decreasing = TRUE)], 20L)
    targets[top] <- 1
  }
  # Identical vector-state cost on all three shapes, including the floor.
  list(targets = targets, state_update = list(above = above, usable = usable, tick = tick))
}
snapshot_path <- file.path(prepared, paste0(producer, '.duckdb'))
if (mode == 'durable') {
  dest <- file.path(out, 'snapshot.duckdb')
  if (file.exists(dest)) stop('durable output must be fresh')
  stopifnot(file.copy(snapshot_path, dest)); snapshot_path <- dest
}
snapshot <- ledgr_snapshot_open(snapshot_path, snapshot_id = 'ws4a')
exp <- ledgr_experiment(snapshot, strategy,
  features = ledgr_feature_map(
    fast = ledgr_ind_ttr('SMA', input = 'close', id = 'fast', n = 5L),
    slow = ledgr_ind_ttr('SMA', input = 'close', id = 'slow', n = 10L)),
  opening = ledgr_opening(cash = 1e7), cost_model = if (arg('fee', '0') == '1') ledgr_cost_fixed_fee(1) else ledgr_cost_zero(), risk_chain = ledgr_risk_none())
if (mode == 'durable') {
  if (profile == 'memory') Rprofmem(file.path(out, 'allocations.log'), threshold = 0)
  if (profile == 'cpu') Rprof(file.path(out, 'cpu.log'), interval = 0.001)
  start <- proc.time()[['elapsed']]
  bt <- suppressWarnings(ledgr_run(exp, params = list(shape = shape), run_id = 'carrier-wide', seed = 20260530L))
  elapsed <- proc.time()[['elapsed']] - start
  close(bt)
  if (profile == 'memory') Rprofmem(NULL)
  if (profile == 'cpu') Rprof(NULL)
  if (profile == 'components') write(do.call(rbind, lapply(ls(components), function(nm)
    data.frame(component = nm, calls = components[[nm]][['calls']], seconds = components[[nm]][['seconds']]))), 'components.csv')
  con <- DBI::dbConnect(duckdb::duckdb(), snapshot_path, read_only = TRUE)
  tables <- lapply(setNames(c('ledger_events', 'equity_curve', 'strategy_state'),
    c('ledger_events', 'equity_curve', 'strategy_state')), function(tab) {
      order <- if (tab == 'ledger_events') 'event_seq' else 'ts_utc'
      DBI::dbGetQuery(con, paste0('SELECT * FROM ', tab,
        " WHERE run_id = 'carrier-wide' ORDER BY ", order))
    })
  DBI::dbDisconnect(con, shutdown = TRUE)
  write(data.frame(arm, producer, shape, profile, seconds = elapsed,
    fills = sum(tables$ledger_events$event_type == 'FILL'), pulses = nrow(tables$equity_curve),
    availability_active = TRUE), 'timing.csv')
  saveRDS(list(tables = tables, states = lapply(fold_results,
    function(x) list(state = x$state, state_prev = x$state_prev))), file.path(out, 'identity.rds'))
  quit(save = 'no')
}
# Count fills and producer at the pulse boundary, not through a result reader.
fills <- 0L; pulses <- 0L; active <- NA
apply_orig <- ns$ledgr_fold_stage_apply
utils::assignInNamespace('ledgr_fold_stage_apply', function(fold_state, services, observation, plan, ...) {
  fills <<- fills + if (is.null(plan$pulse_plan$batch)) length(plan$accounting_events$fills) else length(plan$pulse_plan$batch$qty)
  pulses <<- pulses + 1L; active <<- services$availability_active
  apply_orig(fold_state, services, observation, plan, ...)
}, ns = 'ledgr')
profile <- arg('profile', 'none')
if (profile == 'memory') Rprofmem(file.path(out, 'allocations.log'), threshold = 0)
if (profile == 'cpu') Rprof(file.path(out, 'cpu.log'), interval = 0.001)
# Instrumentation runs attribute wall clocks separately; ordinary pairs do not.
counts <- new.env(parent = emptyenv())
if (profile == 'calls') {
  count <- function(name) {
    counts[[name]] <- 0L
    original <- get(name, ns)
    wrapper <- function(...) {
      old <- counts[[name]]
      counts[[name]] <- if (is.null(old)) 1L else old + 1L
      original(...)
    }
    utils::assignInNamespace(name, wrapper, ns = 'ledgr')
  }
  for (name in c('ledgr_next_open_fill_proposal', 'ledgr_resolve_fill_proposal',
    'ledgr_fill_context', 'ledgr_cost_model_resolve', 'ledgr_lot_apply_fill',
    'ledgr_lot_ensure_instrument', 'ledgr_lot_direction', 'ledgr_lot_add_realized', 'ledgr_fill_event_payload',
    'ledgr_fill_publication_deltas', 'ledgr_position_from_lots', 'ledgr_fill_leg_fees',
    'ledgr_ts_utc_posix', 'ledgr_assert_whole_second_utc')) count(name)
  original_count_factory <- ns$ledgr_output_handler
  counted_method <- function(original, name) {
    force(original); force(name); counts[[name]] <- 0L
    function(...) { counts[[name]] <- counts[[name]] + 1L; original(...) }
  }
  utils::assignInNamespace('ledgr_output_handler', function(sink, ...) {
    h <- original_count_factory(sink, ...)
    for (nm in c('write_fill_events', 'record_accounting_fact'))
      h[[nm]] <- counted_method(h[[nm]], paste0('handler_', nm))
    h
  }, ns = 'ledgr')
}
start <- proc.time()[['elapsed']]
sw <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(ws4a = list(strategy = list(shape = shape))),
  retain = ledgr_sweep_retention(returns = 'completed', trades = 'closed'), workers = 1L,
  seed = 20260530L, stop_on_error = TRUE))
elapsed <- proc.time()[['elapsed']] - start
if (profile == 'memory') Rprofmem(NULL)
if (profile == 'cpu') {
  Rprof(NULL); s <- summaryRprof(file.path(out, 'cpu.log'))
  write(data.frame(fn = rownames(s$by.total), s$by.total), 'profile_total.csv')
}
if (profile == 'components') write(do.call(rbind, lapply(ls(components), function(nm)
  data.frame(component = nm, calls = components[[nm]][['calls']], seconds = components[[nm]][['seconds']]))), 'components.csv')
write(data.frame(arm, producer, shape, profile, seconds = elapsed, fills, pulses,
  availability_active = active), 'timing.csv')
if (mode == 'identity') {
  events <- lapply(handlers, function(h) h$events())
  equity <- as.data.frame(ledgr_sweep_returns(sw))
  saveRDS(list(events = events, equity = equity,
    states = lapply(fold_results, function(x) list(state = x$state, state_prev = x$state_prev))),
    file.path(out, 'identity.rds'))
}
if (profile == 'calls') {
  counted <- ls(counts)
  table <- if (!length(counted)) data.frame(fn = character(), calls = integer(),
    fills = integer(), calls_per_fill = numeric()) else do.call(rbind, lapply(counted, function(nm)
      data.frame(fn = nm, calls = counts[[nm]], fills, calls_per_fill = if (fills) counts[[nm]] / fills else NA_real_)))
  write(table, 'calls.csv')
}
print(data.frame(arm, producer, shape, seconds = elapsed, fills, pulses))
