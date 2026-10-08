# Spike inventory: recursive-indicator history

Executor deliverables for
`inst/design/spikes/recursive_indicator_history_spike/charter.md`. Run on
2026-10-08 against the unchanged package code of `9452e9e`.

## What ran

| Artifact | What it does | Evidence |
| --- | --- | --- |
| `probe.R` | section 1 probe, before the charter | `probe_evidence.csv` |
| `spike_runner.R` | prerequisite plus classification of eight indicators on two seeded paths; fragility probes; `--gut` swaps in window-local certification | `evidence/prerequisite.csv`, `evidence/classification.csv`, `evidence/fragility.csv`, `evidence/gut/` |
| `spike_checker.R` | reruns both modes into scratch, diffs, asserts the gut's named rows, reports agreement with `expected.csv` and fragility disagreements, guards package and design scope | prints `SPIKE CHECK OK` |
| `expected.csv` | eight frozen class answers with their basis | |

Harness: `probe.R` 142 lines, `spike_runner.R` 184, `spike_checker.R` 82,
within the 1,500-line budget.

## Classification rule

History sensitivity: an indicator is history dependent if any gap between
the full-history series and the series started at bar 31 or 61 exceeds
1e-9 relative (scale `max(1, |value|)`). Among those, the executor's rule (not
chartered) reads `decaying` if the start-61 gaps above tolerance shrink at
every step, otherwise `path_dependent`. `fragility.csv` shows the rule is
fragile across seeds and start choices.

## Gutted path

The gut re-implements the shipped window-local certification (`fn` against
`series_fn` over a window of `requires_bars`, absolute tolerance) rather than
calling `ledgr_compute_feature_series_strict_scalar`, which uses
`stable_after` and `all.equal`; equivalent on these fixtures. Every indicator
then classifies as `bounded` and nothing is flagged: on both paths `ttr_ema5`
goes from `decaying` to `bounded` and `running_max_strict` loses its flag. The
checker asserts both rows.

## Demoted

- Decay-distance measurement, dropped at round one of review: an EMA's decay
  follows from its smoothing constant. Gap against distance between starts
  (charter section 5) was not recorded either.
- Three-way classification as a mechanical result (see Classification rule).

## Deleted

Nothing in the package. `spike_checker.R` diffs `R`, `src`, `tests`,
`NAMESPACE`, `DESCRIPTION` and `man` against `9452e9e`, and checks those plus
`inst/design` are untouched by the rerun.

## Learned about the package

- `ledgr_compute_feature_series()` reproduces exactly what a public dense
  `ledgr_run()` sees, for all eight indicators on both paths (16 rows).
- On both chartered paths, 1e-9 separates bounded indicators (largest gap
  3.7e-13) from history-dependent ones (every per-start maximum at least
  0.10). On a monotone path, TTR EMA, RSI and the running max all read
  `bounded`: the check proves dependence, never boundedness.
- The P3b flag ("not bounded and declares `strict_window`") catches
  `running_max_strict` on both chartered paths and nothing else, and misses it
  on the monotone path.
- The decaying-versus-path-dependent rule is not stable across seeds and
  start choices: 11 of 27 fragility probes disagree with the expected
  class.
- Strategy state refuses `NA` numbers in JSON, so the harness stores values
  as 17-significant-digit strings, which round-trip doubles exactly.
