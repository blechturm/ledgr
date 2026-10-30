# Re-execute native outputs, two guts, and diff deterministic evidence CSVs.
# --out must be fresh scratch. --record=1 records the first executed answers.
a <- commandArgs(TRUE)
arg <- function(key, default = NULL) {
  x <- grep(paste0('^--', key, '='), a, value = TRUE)
  if (length(x)) sub(paste0('^--', key, '='), '', x[[1]]) else default
}
folder <- dirname(normalizePath(sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]), winslash = '/'))
root <- normalizePath(file.path(folder, '../../..'), winslash = '/')
out <- arg('out', file.path(tempdir(), 'ws4a-check'))
lib <- arg('lib', 'C:/Users/maxth/AppData/Local/Temp/ws4a-lib')
prepared <- arg('prepared', 'C:/Users/maxth/AppData/Local/Temp/ws4a-evidence')
dir.create(out, recursive = TRUE, showWarnings = FALSE)
guard <- function() {
  scope <- c('R', 'src', 'tests', 'NAMESPACE', 'DESCRIPTION', 'man', 'inst/design')
  base <- c('-c', paste0('safe.directory=', root), '-C', root)
  status <- system2('git', shQuote(c(base, 'diff', '--exit-code', '145cc93b', '--', scope)))
  if (status != 0L) stop('protected package scope changed')
  untracked <- system2('git', shQuote(c(base, 'ls-files', '--others', '--exclude-standard', '--', scope)), stdout = TRUE)
  if (length(untracked)) stop('untracked product files: ', paste(untracked, collapse = ', '))
}
guard()
rscript <- file.path(R.home('bin'), 'Rscript.exe')
run <- function(tag, mode, arm, ...) {
  dest <- file.path(out, tag); dir.create(dest, showWarnings = FALSE)
  if (!file.exists(file.path(dest, 'identity.rds'))) {
    status <- system2(rscript, shQuote(c(file.path(folder, 'probe.R'), paste0('--mode=', mode),
      paste0('--arm=', arm), paste0('--out=', dest), paste0('--lib=', lib),
      paste0('--prepared=', prepared), ...)), stdout = file.path(dest, 'stdout.txt'),
      stderr = file.path(dest, 'stderr.txt'))
    if (status) stop('identity execution failed: ', dest)
  }
  readRDS(file.path(dest, 'identity.rds'))
}
rows <- list(); nr <- 0L
edge <- function(x, last = FALSE) {
  if (!length(x)) return('<empty>')
  value <- x[if (last) length(x) else 1L]
  paste(capture.output(dput(value)), collapse = ' ')
}
compare <- function(a, b, path) {
  # Traverse structure and columns, not individual rows. No numerical tolerance.
  if (is.data.frame(a) && is.data.frame(b)) {
    if (!identical(names(a), names(b))) stop('column shape changed: ', path)
    for (nm in names(a)) compare(a[[nm]], b[[nm]], paste(path, nm, sep = '/'))
  } else if (is.list(a) && is.list(b) && identical(names(a), names(b)) && length(a) == length(b)) {
    for (i in seq_along(a)) compare(a[[i]], b[[i]], paste(path,
      if (is.null(names(a))) i else names(a)[i], sep = '/'))
  } else {
    nr <<- nr + 1L
    same <- identical(a, b, num.eq = FALSE, single.NA = FALSE)
    # Event identities, JSON bytes, doubles and NA payloads all compare exactly.
    rows[[nr]] <<- data.frame(surface = path, base_length = length(a), fork_length = length(b),
      identical = same, base_first = edge(a), fork_first = edge(b),
      base_last = edge(a, TRUE), fork_last = edge(b, TRUE), stringsAsFactors = FALSE)
  }
}
base <- run('wide_base', 'identity', 'base')
fork <- run('wide_fork', 'identity', 'fork')
# sweep_id is generated as a local locator. It is the sole exclusion here;
# ledger run_id/event_id and every numeric equity fact remain in the comparison.
base$equity$sweep_id <- fork$equity$sweep_id <- NULL
compare(base, fork, 'wide/memory')
base_d <- run('durable_base', 'durable', 'base')
fork_d <- run('durable_fork', 'durable', 'fork')
compare(base_d, fork_d, 'wide/durable')
base_a0 <- run('a0_base', 'a0', 'base')
fork_a0 <- run('a0_fork', 'a0', 'fork')
compare(base_a0, fork_a0, 'A0')
for (shape in c('floor', 'sparse')) {
  x <- run(paste0(shape, '_base'), 'identity', 'base', paste0('--shape=', shape))
  y <- run(paste0(shape, '_fork'), 'identity', 'fork', paste0('--shape=', shape))
  x$equity$sweep_id <- y$equity$sweep_id <- NULL
  compare(x, y, paste0(shape, '/memory'))
}
# Same workload cases, additional carrier arms; preserve original rows above.
for (extra_arm in c('fork_r', 'fork_indexed', 'fork_r_indexed')) {
  x <- run(paste0('wide_', extra_arm), 'identity', extra_arm)
  x$equity$sweep_id <- NULL
  compare(base, x, paste0('additional/', extra_arm, '/wide/memory'))
  x <- run(paste0('durable_', extra_arm), 'durable', extra_arm)
  compare(base_d, x, paste0('additional/', extra_arm, '/wide/durable'))
  x <- run(paste0('a0_', extra_arm), 'a0', extra_arm)
  compare(base_a0, x, paste0('additional/', extra_arm, '/A0'))
  for (shape in c('floor', 'sparse')) {
    x <- run(paste0(shape, '_base'), 'identity', 'base', paste0('--shape=', shape))
    y <- run(paste0(shape, '_', extra_arm), 'identity', extra_arm, paste0('--shape=', shape))
    x$equity$sweep_id <- y$equity$sweep_id <- NULL
    compare(x, y, paste0('additional/', extra_arm, '/', shape, '/memory'))
  }
}
identity <- do.call(rbind, rows)
write.csv(identity, file.path(out, 'identity.csv'), row.names = FALSE)
if (!all(identity$identical)) {
  print(identity[!identity$identical, ]); stop('identity difference; evidence retained')
}
# Guts corrupt the same runnable fork, not an unrelated expectation.
reorder <- run('gut_reorder', 'identity', 'fork', '--mutation=reorder')
reorder$equity$sweep_id <- NULL
fee_base <- run('fee_base', 'identity', 'base', '--fee=1')
fee_gut <- run('gut_fee', 'identity', 'fork', '--fee=1', '--mutation=drop_fee')
fee_base$equity$sweep_id <- fee_gut$equity$sweep_id <- NULL
nr <- 0L; rows <- list()
compare(base, reorder, 'reorder'); compare(fee_base, fee_gut, 'drop_fee')
gut <- do.call(rbind, rows)
write.csv(gut, file.path(out, 'gut.csv'), row.names = FALSE)
stopifnot(any(!gut$identical[startsWith(gut$surface, 'reorder/')]),
  any(!gut$identical[startsWith(gut$surface, 'drop_fee/')]))
guard()
for (name in c('identity.csv', 'gut.csv')) {
  recorded <- file.path(folder, name); current <- file.path(out, name)
  if (arg('record', '0') == '1') {
    stopifnot(file.copy(current, recorded, overwrite = TRUE))
  } else if (!identical(readBin(recorded, 'raw', n = file.info(recorded)$size),
    readBin(current, 'raw', n = file.info(current)$size))) stop('evidence CSV differs: ', name)
}
cat('Identity, two guts, CSV diff and package-scope guard passed.\n')
