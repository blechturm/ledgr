# NMOF probe: findings

**Answer.** Yes. `NMOF::minvar()` drops into the vignette strategy with
identical fills. An NMOF heuristic (`LSopt`) runs reproducibly from
`ctx$pulse_seed`, but only when the strategy pins the RNG kind:
`withr::with_seed(ctx$pulse_seed, ...)` alone is **not** parallel-equivalent
under ledgr's mirai workers.

Status: green on the prerequisite (kill condition not met). The question is
answered with one ledgr defect found and two preflight gaps. Findings bind
nothing.

Setup: NMOF 2.12-0, quadprog 1.5.8, withr 3.0.3, mirai 2.7.2, R 4.6.1. The
NMOF library is `E:/ledgr-data/r-lib/extra`, prepended with `.libPaths()`.
The fixture is `ledgr_sim_pit_inputs()` with 20 instruments, 2017-2021 and
seed 7, plus the vignette's facts, membership universe and monthly schedule.
Bare `ledgr_sim_bars()` cannot carry a schedule: it raises
`ledgr_schedule_sessions_required`. Rerun with
`Rscript dev/spikes/nmof-probe/probe.R`, use `--check` to diff against
`evidence/`, and `--gut` for the gut demonstration.

## Parity (prerequisite and probe 1)

| Check | Result |
| --- | --- |
| 25 random covariance matrices (n 5-30, 1-11 binding zero weights) | max abs weight diff 3.8e-15 |
| 48 scheduled decisions (19 instruments, same `sigma`) | max abs weight diff 6.9e-17; targets `identical()` at all 48 |
| Full runs, quadprog vs minvar | 833 vs 833 fills, `identical()` |

The tiny differences have a known cause. `minvar()` *is* `quadprog::solve.QP`
with `Dmat = 2 * var` and an extra `-diag(n)` block for the default
`wmax = 1`. Same solver, rescaled and redundantly constrained problem.
`minvar()` returns a `variance` attribute, which `ledgr_align_weights()`
accepts without `as.numeric()`.

## Readability (probe 2)

Before (vignette, 14 lines from `n <- ncol(sigma)`):

```r
n <- ncol(sigma)
solution <- quadprog::solve.QP(
  Dmat = sigma,
  dvec = rep(0, n),
  Amat = cbind(rep(1, n), diag(n)),
  bvec = c(1, rep(0, n)),
  meq = 1L
)$solution
if (any(!is.finite(solution)) || any(solution < -1e-8) ||
    abs(sum(solution) - 1) > 1e-8) {
  stop("The optimizer returned invalid long-only weights.")
}
solution[solution < 0] <- 0
solution <- solution / sum(solution)
```

After (7 lines; the guard and the clip stay because the solver is the same):

```r
solution <- NMOF::minvar(sigma)
if (any(!is.finite(solution)) || any(solution < -1e-8) ||
    abs(sum(solution) - 1) > 1e-8) {
  stop("The optimizer returned invalid long-only weights.")
}
solution[solution < 0] <- 0
solution <- solution / sum(solution)
```

The solver call goes from 8 lines to 1. The constraint algebra (`Amat`,
`bvec`, `meq`) disappears into named bounds (`wmin`, `wmax`, `groups`). For
teaching the method, that also hides the part the vignette explains.

## Heuristic (probe 3): cardinality-constrained min-variance, at most 5 names

`mv_card` in `probe.R` uses `NMOF::LSopt()` over a logical selection
(LSselect-vignette idiom). The objective is `minvar()` variance of the
selected names, and the neighbour swaps one selected name for one unselected
name (500 steps). Its helpers must live inside the strategy body, because an
unqualified user helper is Tier 3. A guard `stop()`s when `ctx$pulse_seed` is
NULL, because `withr::with_seed(NULL, ...)` silently draws unseeded numbers
(probed).

| Check | Result |
| --- | --- |
| Two sequential runs, `seed = 42` | fills and equity `identical()` |
| `seed = 43` | different fills (seed is live) |
| Max names held | 5 |
| Run without `seed =` | `ledgr_strategy_error` at the first decision (the guard) |
| Sweep, 2 candidates, workers 1 vs 2, **kinds pinned** | rows, retained returns and trades `identical()` |
| Same sweep, plain `withr::with_seed(ctx$pulse_seed, ...)` | **differ** on every metric, the equity series and the trades |
| Gut (no `with_seed`, ambient RNG) | sequential runs still identical; workers 1 vs 2 differ, so the gut is caught |
| LSopt vs exhaustive (last decision, C(19,5) = 11628, 0.23 s) | optimum in 3 of 5 seeds; gaps 0.7% and 1.4% |

**Root cause of the parallel divergence.** mirai daemons run
`L'Ecuyer-CMRG`. `withr::with_seed(seed, ...)` with default
`.rng_kind = NULL` keeps the active kind, so the same seed draws `17 5 1 10 4`
locally and `2 4 12 18 17` on a daemon. The fold's own
`set.seed(as.integer(execution_seed))` (`R/fold-engine.R:1629`) does not pin
the kind either. That same call is why the ambient-RNG gut passes the
sequential check. The working form pins the kinds:

```r
withr::with_seed(ctx$pulse_seed, { ... }, .rng_kind = "Mersenne-Twister",
  .rng_normal_kind = "Inversion", .rng_sample_kind = "Rejection")
```

## Preflight (probe 4)

| Strategy | Tier | Package deps / worker `require_namespace` | Ambient RNG |
| --- | --- | --- | --- |
| `mv_qp` (vignette) | tier_2 | quadprog | none |
| `mv_nmof` | tier_2 | NMOF | none |
| `mv_card` (pinned) and `mv_card_naive` | tier_2 | NMOF, withr | none |
| `mv_card_gut` (unseeded `sample.int`) | tier_2 | NMOF | none |
| probe `sample(1L)` | tier_2 | none | sample |
| probe `sample.int(1L)` | **tier_1** | none | none |
| probe `set.seed(ctx$pulse_seed, kind = ...)` | tier_3 | none | none |

Worker `attach` is empty and `unresolved` is empty for all of them. On
workers I did nothing extra: ledgr's worker load expression prepends the
parent's `.libPaths()` before `pkgload::load_all`, so NMOF resolved without
`worker_packages`.

## Awkward or surprising

1. Parallel equivalence breaks for the obvious seeding idiom. Seeding in the
   body with `set.seed`/`RNGkind` is Tier 3, so a package helper is the only
   legal route, and its default form is wrong on workers.
2. The ambient-RNG list is `runif`, `rnorm`, `sample`
   (`R/strategy-preflight.R:677`). Unseeded `sample.int()` is classed Tier 1,
   and RNG drawn inside a package (`LSopt`, `TAopt`) is invisible.
3. Transitive runtime dependencies are invisible. `minvar()` loads quadprog
   via `requireNamespace` (it is a Suggests of NMOF), but preflight and the
   worker check list only NMOF.
4. A stochastic strategy needs a hand-written NULL-seed guard. Otherwise a
   run without `seed =` is silently non-reproducible.
5. A heuristic's result depends on the seed (2 of 5 seeds missed the
   optimum), so the seed is part of the research result, not noise.

## What a portfolio-construction RFC should take from this

- Solvers are ordinary R behind `pkg::fn()`. NMOF needs no adapter;
  `ledgr_align_weights()` plus `ledgr_target_rebalance()` already form the
  seam.
- Decide where the RNG kind is pinned. The candidate is the fold
  (`set.seed(execution_seed, kind = "Mersenne-Twister", normal.kind =
  "Inversion", sample.kind = "Rejection")`) and/or worker setup. If the fold
  pins it, plain `with_seed()` inherits the pinned kind. A fold change needs a
  ticket and an equivalence test; it is not done here.
- Extend preflight's RNG detection: `sample.int`, the other `r*` draws, and a
  note that package-internal RNG is not detectable. Consider surfacing
  Suggests-loaded dependencies of declared packages.
- Make the stochastic-strategy pattern a documented helper or recipe: a seed
  guard plus pinned-kind seeding from `ctx$pulse_seed`.
- At about 20 names, exhaustive search is cheap. Heuristics earn their place
  only at larger n, where their seed sensitivity should be reported.
