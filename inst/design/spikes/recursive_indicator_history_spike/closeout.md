# Closeout: Recursive-Indicator History Spike

**Verdict: red on the charter's question.** Kill condition 3 fired: a sampled
check cannot tell decaying from path-dependent behavior, so a three-way
classification needs a declaration. The bounded-versus-history-dependent
split and the P3b flag worked on every chartered row, but only as a one-way
test: the check can prove an indicator depends on history, never that it
does not.

Run 2026-10-08 against the unchanged package code of `9452e9e`. Artifacts in
`dev/spikes/recursive-indicator-history/`. Independently reviewed 2026-10-08
(PASS_AFTER_PATCHES; patches applied, including `evidence/fragility.csv`).

## What ran

- **Prerequisite:** the internal engine (`ledgr_compute_feature_series()`)
  reproduced a public dense `ledgr_run()` exactly for all eight indicators on
  both paths, 16 of 16 rows.
- **Classification:** eight indicators (SMA 5 and 20, ledgr EMA 5, a custom
  five-bar rolling max, TTR EMA 5, TTR RSI 14, and a running max, undeclared
  and declared `strict_window`) on a sine-and-trend path and a seeded random
  walk, 120 bars each. History sensitivity compares the full-history series
  with series started at bars 31 and 61.
- **Executor's three-way rule** (not chartered): history-dependent indicators
  are `decaying` if the start-61 gaps above tolerance never fail to shrink,
  otherwise `path_dependent`.
- **Gut:** swapping in a re-implementation of the shipped window-local
  certification makes every indicator read `bounded` and clears the P3b flag.
- **Fragility** (after review): the three history-dependent indicators on a
  monotone path, three other second starts on the sine path, and five more
  random walks.

## What was learned about the package

- **History dependence is detectable when the data exposes it.** A
  tolerance of 1e-9 separates bounded indicators (largest gap 3.7e-13) from
  history-dependent ones on both chartered paths: every per-start maximum is
  at least 0.10. But on a monotone path TTR EMA, RSI and the running max all
  read `bounded`: the starts converge exactly. The check can prove
  dependence, never boundedness.
- **The P3b hazard is caught only on revealing data.** "Not bounded and
  declares `strict_window`" flags the declared running max on both chartered
  paths and nothing else; on the monotone path it misses. Today's
  window-local certification never sees it.
- **Decaying versus path-dependent is not decidable by sampling.** The
  executor's rule gave 14 of 16 expected classes on the chartered paths, but
  11 of 27 fragility probes disagree: RSI reads `path_dependent` on 3 of 5
  walks, the running max reads `decaying` on 3 of 5 walks, and one sine start
  flips the running max. The 14 of 16 was luck of the seed.
- `stable_after` and `gap_contract` say nothing about history dependence.

## What the spec may consume

Proposals for the joint WS3/WS4 history-start decision, not decisions:
1. **Bounded must be known from the definition, not tested.** Built-in
   window indicators can carry it; custom indicators need to declare it.
2. A **history-sensitivity check** at experiment build can refuse an
   indicator that declares `strict_window` and shows history dependence on
   the experiment's own data. It narrows the P3b hazard; it cannot close it.
3. **History-dependent indicators need a declaration or a policy.**

## Deviations

- Charter section 5 asked how the gap changes with distance between starts;
  only per-start maximum and final gaps were recorded.
- The gut re-implements the shipped certification (window width
  `requires_bars`, absolute tolerance) instead of calling it; equivalent on
  these fixtures.

## What remains open

- How to fix P3b in the product, and whether to refuse or warn.
- Burn-in declaration, full-history rule, or refusal for history-dependent
  indicators in windows; gap transitions for recursion in availability mode.
- Pulse inspection under the history rule (WS3).
