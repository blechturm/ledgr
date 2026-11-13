# LDG-3230 stop rule: the cost of lean_state_patch()'s per-pulse name checks
# (loop.R, the anyDuplicated and %in% tests), the upper bound of a state-patch
# fast path's saving. Run 2026-11-13 under the High performance plan with
# P-core affinity 0xFFFF (pcore.ps1); output in stop_state_patch.txt.
chk <- compiler::cmpfun(function(update, strategy_state, state_fields) {
  nm <- names(update)
  length(update) == 0L || is.null(nm) || anyNA(nm) || !all(nzchar(nm)) || anyDuplicated(nm) ||
    !all(nm %in% names(strategy_state)) || !all(nm %in% names(state_fields))
})
N <- 200000L
for (case in list(list(k = 1L), list(above = rep(TRUE, 500), usable = rep(TRUE, 500)))) {
  st <- case; sf <- lapply(case, function(x) "f")
  t0 <- proc.time()[[3]]; for (i in seq_len(N)) chk(case, st, sf); t1 <- proc.time()[[3]]
  cat(sprintf("%d field(s): the name checks %.2f us per pulse\n", length(case), 1e6 * (t1 - t0) / N))
}
