# Uses the strict comparator, executor and scope guard from check.R.
for (case in c('wide', 'durable', 'a0', 'floor', 'sparse', 'partial')) {
  mode <- if (case %in% c('durable', 'a0')) case else 'identity'
  shape <- if (case %in% c('durable', 'a0')) 'wide' else case
  x <- run(paste0(case, '_base'), mode, 'base', paste0('--shape=', shape))
  arms <- if (case == 'partial') c('fork_r_indexed', 'fork_indexed', 'fork_typed') else 'fork_typed'
  for (arm in arms) {
    y <- run(paste(case, arm, sep = '_'), mode, arm, paste0('--shape=', shape))
    if (mode == 'identity') x$equity$sweep_id <- y$equity$sweep_id <- NULL
    compare(x, y, paste('typed', arm, case, sep = '/'))
  }
  if (case == 'partial') partial <- x
}
x <- run('partial_durable_base', 'durable', 'base', '--shape=partial')
for (arm in c('fork_r_indexed', 'fork_indexed', 'fork_typed')) {
  y <- run(paste0('partial_durable_', arm), 'durable', arm, '--shape=partial')
  compare(x, y, paste0('typed/', arm, '/partial/durable'))
}
x <- run('fee_base', 'identity', 'base', '--fee=1')
y <- run('fee_fork_typed', 'identity', 'fork_typed', '--fee=1')
x$equity$sweep_id <- y$equity$sweep_id <- NULL
compare(x, y, 'typed/fork_typed/fee/memory')
identity <- do.call(rbind, rows)
write.csv(identity, file.path(out, 'typed_identity.csv'), row.names = FALSE)
if (!all(identity$identical)) {
  print(identity[!identity$identical, ]); stop('typed identity difference')
}
nr <- 0L; rows <- list()
gut <- run('partial_lifo', 'identity', 'fork_typed', '--shape=partial', '--mutation=lifo')
gut$equity$sweep_id <- NULL
compare(partial, gut, 'lifo')
# Re-execute both original guts through the unchanged native arm as well.
x <- run('wide_base', 'identity', 'base'); x$equity$sweep_id <- NULL
y <- run('gut_reorder', 'identity', 'fork', '--mutation=reorder'); y$equity$sweep_id <- NULL
compare(x, y, 'reorder')
x <- run('fee_base', 'identity', 'base', '--fee=1')
y <- run('gut_fee', 'identity', 'fork', '--fee=1', '--mutation=drop_fee')
x$equity$sweep_id <- y$equity$sweep_id <- NULL
compare(x, y, 'drop_fee')
guts <- do.call(rbind, rows)
write.csv(guts, file.path(out, 'typed_gut.csv'), row.names = FALSE)
stopifnot(all(vapply(c('lifo/', 'reorder/', 'drop_fee/'), function(prefix)
  any(!guts$identical[startsWith(guts$surface, prefix)]), logical(1))))
guard()
for (name in c('typed_identity.csv', 'typed_gut.csv')) {
  recorded <- file.path(folder, name); current <- file.path(out, name)
  if (arg('record', '0') == '1') stopifnot(file.copy(current, recorded, overwrite = TRUE)) else
    stopifnot(identical(readBin(recorded, 'raw', file.info(recorded)$size),
      readBin(current, 'raw', file.info(current)$size)))
}
cat('Typed identity, three guts, CSV diff and scope guard passed.\n')
