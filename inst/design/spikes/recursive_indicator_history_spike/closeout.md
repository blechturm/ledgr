# Closeout: Recursive-Indicator History Spike

**Verdict: red on the charter's question, with its first half answered
green.** Kill condition 3 fired: a sampled check could not tell decaying from
path-dependent behavior on the sine path, so a three-way classification needs
a declaration after all. The bounded-versus-history-dependent split and the
P3b flag worked on every row.

Run 2026-10-08 against the unchanged package code of `9452e9e`. Artifacts in
`dev/spikes/recursive-indicator-history/`.

## What ran

- **Prerequisite:** the internal engine (`ledgr_compute_feature_series()`)
  reproduced a public dense `ledgr_run()` exactly for all eight indicators on
  both paths, 16 of 16 rows.
- **Classification:** eight indicators (SMA 5 and 20, ledgr EMA 5, a custom
  five-bar rolling max, TTR EMA 5, TTR RSI 14, and a running max, undeclared
  and declared `strict_window`) on a sine-and-trend path and a seeded random
  walk, 120 bars each. History sensitivity compares the full-history series
  with series started at bars 31 and 61.
- **Gut:** swapping in the shipped window-local certification makes every
  indicator read `bounded` and clears the P3b flag; the checker asserts both
  named rows.

## What was learned about the package

- **Bounded is mechanically detectable.** A relative tolerance of 1e-9
  separates bounded indicators (largest gap 3.7e-13) from history-dependent
  ones (smallest largest-gap 0.10), on both paths, with no false alarms.
- **The silent strict-window hazard is detectable.** "Not bounded and declares
  `strict_window`" flags the declared running max on both paths and nothing
  else. Today's window-local certification cannot see it.
- **Decaying versus path-dependent is not.** TTR EMA and RSI read as decaying
  on both paths. The running max reads as path dependent on the random walk
  but as decaying on the rising sine path, where its gap shrinks each day.
  14 of 16 rows match the frozen answers; the two misses are these.
- `stable_after` and `gap_contract` say nothing about history dependence; the
  check had to be run to know.

## What the spec may consume

These are proposals for the joint WS3/WS4 history-start decision, not
decisions:
1. A history rule can treat **bounded** indicators mechanically, for example
   hydrating them by `stable_after` bars, without a new declaration.
2. A **history-sensitivity check** at experiment build can refuse or warn on
   an indicator that is not bounded but declares `strict_window`, closing the
   P3b hazard.
3. **History-dependent indicators need a declaration or a policy**:
   whether a finite burn-in is acceptable cannot be inferred, because
   convergence depends on the data path.

## What remains open

- How to fix P3b in the product, and whether to refuse or warn.
- Whether a burn-in declaration, a full-history rule, or refusal applies to
  history-dependent indicators in windows.
- Gap transitions for recursion in availability mode.
- Pulse inspection under the history rule (WS3).
