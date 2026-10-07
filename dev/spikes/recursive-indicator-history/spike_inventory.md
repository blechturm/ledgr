# Spike inventory: recursive-indicator history

Executor deliverables for
`inst/design/spikes/recursive_indicator_history_spike/charter.md`. Run on
2026-10-08 against the unchanged package code of `9452e9e`.

## What ran

| Artifact | What it does | Evidence |
| --- | --- | --- |
| `probe.R` | section 1 probe, before the charter | `probe_evidence.csv` |
| `spike_runner.R` | prerequisite plus classification of eight indicators on two seeded paths; `--gut` swaps in window-local certification | `evidence/prerequisite.csv`, `evidence/classification.csv`, `evidence/gut/` |
| `spike_checker.R` | reruns both modes into scratch, diffs, asserts the gut's named rows, reports agreement with `expected.csv`, guards package scope | prints `SPIKE CHECK OK` |
| `expected.csv` | eight frozen class answers with their basis | |

Harness: `probe.R` 142 lines, `spike_runner.R` 161, `spike_checker.R` 88, within
the 1,500-line budget.

## Gutted path

The gut replaces history sensitivity with the shipped window-local
certification (`fn` against `series_fn` over the same declared window).
Every indicator then classifies as `bounded` and nothing is flagged: on both
paths `ttr_ema5` goes from `decaying` to `bounded` and `running_max_strict`
loses its flag. The checker asserts both rows.

## Demoted

- Decay-distance measurement, dropped at round one of review: an EMA's decay
  follows from its smoothing constant.
- Three-way classification as a mechanical result: on the rising sine path
  the running maximum's gap shrinks every day, so the check reads it as
  decaying. Only the random-walk path exposes it as path dependent.

## Deleted

Nothing in the package. No package file changed (`spike_checker.R` diffs
`R`, `src`, `tests`, `NAMESPACE`, `DESCRIPTION` and `man` against `9452e9e`).

## Learned about the package

- `ledgr_compute_feature_series()` reproduces exactly what a public dense
  `ledgr_run()` sees, for all eight indicators on both paths (16 rows).
- One relative tolerance of 1e-9 separates bounded indicators (largest gap
  3.7e-13) from history-dependent ones (smallest largest-gap 0.10) on both
  paths. Bounded is detectable from the definition alone.
- The P3b hazard is detectable as "not bounded and declares
  `strict_window`": it flags `running_max_strict` and nothing else, on both
  paths. The shipped strict path's window-local certification cannot see it.
- Whether a history-dependent indicator converges (decaying) or may never
  converge (path dependent) is a property of the data path as much as of
  the definition. A sampled check on two paths did not decide it.
- Strategy state refuses `NA` numbers in JSON, so the harness stores values
  as 17-significant-digit strings, which round-trip doubles exactly.
