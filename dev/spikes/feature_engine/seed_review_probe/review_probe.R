.libPaths(c('C:/Users/maxth/AppData/Local/Temp/claude/a337d437c6e22de3/78383ced-ac83-4579-b480-65f39660106d/scratchpad/ws16/lib-d5b3a151', .libPaths()))
library(ledgr)
ns <- asNamespace('ledgr')
repo <- 'C:/Users/maxth/ledgr-wt/fe-seed-review'
out <- 'C:/Users/maxth/ledgr-wt/fe-seed-review-out'
sink(file.path(out, 'review_probe.txt'))
cat('R:', as.character(getRversion()), '\nledgr:', as.character(packageVersion('ledgr')), '\nTTR:', as.character(packageVersion('TTR')), '\n')

# Evaluate only the classifier declarations, never the benchmark runner.
step_file <- file.path(repo, 'dev/bench/v0_2_3_lean_tuning_profile/feature_steps.R')
exprs <- parse(step_file)
for (expr in exprs) {
  if (is.call(expr) && identical(expr[[1L]], as.name('<-')) && identical(expr[[2L]], as.name('steps'))) eval(expr)
}
src <- readLines(step_file)
classify <- eval(parse(text = paste(c('function(s) {', src[68:69], '}'), collapse = '\n')))
stacks <- c(
  plain_compute = '"lapply" "ledgr_history_compute_feature_series" "run_path"',
  ns_compute = '"lapply" "ns$ledgr_history_compute_feature_series" "run_path"',
  nested_probe = '"ledgr_ttr_raw_call" "ledgr_feature_certify" "ledgr_history_feature_causality"',
  runtime_format = '"format.POSIXct" "format" "ledgr_runtime_projection" "ns$ledgr_projection_from_feature_matrix"',
  sweep_compute = '"lapply" "ledgr_history_compute_feature_series" "ns$ledgr_history_precompute_payload"',
  sweep_runtime = '"format.POSIXct" "ledgr_runtime_projection" "ns$ledgr_projection_from_payload"')
cat('\nClassifier copied from feature_steps.R:68-69\n')
print(vapply(stacks, classify, ''))

# Check installed pin vs checkout function syntax without loading checkout code.
cat('\nPin/checkout function body/formal comparisons\n')
for (f in c('history-features.R', 'history-substrate.R', 'runtime-projection.R', 'indicator-ttr.R', 'features-engine.R')) {
  differences <- character()
  count <- 0L
  for (expr in parse(file.path(repo, 'R', f))) {
    if (!is.call(expr) || !identical(expr[[1L]], as.name('<-')) || !is.symbol(expr[[2L]]) ||
        !is.call(expr[[3L]]) || !identical(expr[[3L]][[1L]], as.name('function'))) next
    name <- as.character(expr[[2L]])
    if (!exists(name, ns, inherits = FALSE)) { differences <- c(differences, paste0(name, ':absent')); next }
    current <- eval(expr[[3L]], envir = ns)
    pinned <- get(name, ns)
    count <- count + 1L
    if (!identical(body(current), body(pinned)) || !identical(formals(current), formals(pinned))) differences <- c(differences, name)
  }
  cat(f, ':', count, 'compared; differences:', paste(differences, collapse = ', '), '\n')
}

axis <- as.POSIXct('2020-01-01', tz = 'UTC') + 86400 * 0:7
raw <- list(open = c(10, NA_real_, 12:17), high = 21:28, low = 1:8, close = 11:18, volume = 101:108)
treated <- raw
treated$open <- ns$ledgr_history_input_carry_calculation(raw$open, rep(TRUE, 8L), 5L, TRUE, rep(FALSE, 8L))$value
inputs <- list(instrument_id = 'SYNTHETIC', axis = axis, expected = rep(TRUE, 8L), terminal = rep(FALSE, 8L),
               terminal_asserted = rep(FALSE, 8L), raw = raw, treated = treated,
               carried = lapply(raw, function(x) rep(FALSE, 8L)))
inputs$carried$open[[2L]] <- TRUE

# An admitted custom callback can observe non-required columns today.
custom <- ledgr_indicator('custom_volume', function(bars) as.numeric(tail(bars$volume, 1L)), requires_bars = 1L,
                          series_fn = function(bars) as.numeric(bars$volume), required_fields = 'close')
cert <- ns$ledgr_feature_certify(custom)
full <- ns$ledgr_history_feature_calculate(cert, inputs, 1L)
pruned <- inputs
for (field in c('raw', 'treated', 'carried')) pruned[[field]] <- pruned[[field]]['close']
pruned_result <- tryCatch(ns$ledgr_history_feature_calculate(cert, pruned, 1L), error = function(e) class(e)[[1L]])
cat('\nCustom required_fields=close but callback observes volume\n')
cat('certification:', cert$certification, '\nfull values:', paste(full$value, collapse = ','), '\npruned result:')
print(pruned_result)

sma <- ledgr_ind_ttr('SMA', input = 'close', n = 3L)
cert <- ns$ledgr_feature_certify(sma)
calculated <- ns$ledgr_history_feature_calculate(cert, inputs, 1L, cache = new.env(parent = emptyenv()))
exceptions <- ns$ledgr_feature_plane_exceptions(cert, inputs, calculated, 1L, 1:8)
cat('\nSimple close run: planes are not empty\n')
print(exceptions)
cat('values:', paste(calculated$value, collapse = ','), '\n')
cat('direct TTR equals frame path:', identical(as.numeric(TTR::SMA(inputs$treated$close, n = 3L)), calculated$value), '\n')

# One run can start late and still have no carry or terminal.
late <- inputs
late$raw$close[1:2] <- NA_real_
late$treated$close[1:2] <- NA_real_
late$carried$close[] <- FALSE
late_calc <- ns$ledgr_history_feature_calculate(cert, late, 1L, cache = new.env(parent = emptyenv()))
cat('\nOne late run, no close carry or terminal\n')
print(ns$ledgr_history_feature_runs(late$expected & is.finite(late$treated$close)))
print(ns$ledgr_feature_plane_exceptions(cert, late, late_calc, 1L, 1:8))

# Hashing is syntactic: replacing a wrapper call changes fingerprint.
changed <- sma
body(changed$series_fn) <- quote(ledgr_adapter_call(bars, params))
cat('\nFingerprint after wrapper body change equal:', identical(ns$ledgr_indicator_fingerprint(sma), ns$ledgr_indicator_fingerprint(changed)), '\n')

# Resolve the implicit do.call() lookup used by the pin's raw call.
cat('\nRaw-call input for SMA and TTR formal defaults\n')
print(formals(TTR::SMA))
cat('do.call numeric vector and TTR direct identical:', identical(ns$ledgr_ttr_raw_call(ns$ledgr_history_feature_frame(inputs, inputs$treated, 1:8), sma$params), TTR::SMA(inputs$treated$close, n = 3L)), '\n')

cat('\nOmitted helpers: changing their binding alone leaves engine hash unchanged\n')
for (helper_name in c('ledgr_ttr_raw_call', 'ledgr_ttr_build_input', 'ledgr_ttr_select_output',
                      'ledgr_feature_plane_exceptions', 'ledgr_feature_plane_records',
                      'ledgr_history_feature_bounds', 'ledgr_history_feature_check_definition',
                      'ledgr_projection_index_planes')) {
  local_env <- new.env(parent = ns)
  assign(helper_name, function(...) stop('changed helper'), envir = local_env)
  version_fn <- ns$ledgr_feature_engine_version
  environment(version_fn) <- local_env
  cat(helper_name, ':', identical(version_fn(), ns$ledgr_feature_engine_version()), '\n')
}

# Copy the CSV rows to an independently rebuilt compact table, no timing.
cat('\nStep table independently regrouped from CSV, seconds\n')
tab <- read.csv(file.path(repo, 'dev/bench/v0_2_3_lean_tuning_profile/results/feature_steps.csv'))
mapping <- list(
  pulse_names = 'projection pulse names', raw_call = 'TTR raw call', inputs = 'input treatment',
  calculate = 'calculate other (runs, carry)', segment = c('segment frame', 'segment other'),
  planes = c('plane exceptions', 'plane records'), split_rebuild = c('payload split (sweep)', 'projection rebuild (sweep)'),
  checks = c('certification', 'causality probe'),
  other = c('ranges and bounds', 'projection index planes', 'projection other', 'compute other', 'other'))
for (key in unique(paste(tab$shape, tab$path))) {
  rows <- tab[paste(tab$shape, tab$path) == key, ]
  cat(key, 'wall=', rows$wall_s[[1L]], 'samples=', rows$samples[[1L]], '\n')
  print(vapply(mapping, function(s) sum(rows$seconds[rows$step %in% s]), 0))
}
sink()
