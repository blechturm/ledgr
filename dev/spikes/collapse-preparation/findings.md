# collapse::rsplit() for bars-by-instrument preparation: findings and inventory

**Outcome: red. Retain base `split()`.** The stop rule decides it: the saving is about 60 ms per
preparation call, which is immaterial at workflow scale. Exact preservation of what `split()`
produces also needs offsetting conversions: original row names and a locale-ordered group sequence.
Findings bind no design.

**Question.** Can `collapse::rsplit()` materially cut the time or allocation of ledgr's two
bars-by-instrument splits while preserving what is consumed downstream? The two arms are production
`split()` and `collapse::rsplit(x, f, sort = TRUE, simplify = FALSE)`.

**Baseline.** Detached worktree at `2ee12d4` (the tip of `codex/ws16-v0.2.1.0`). Both sites are
blob-identical to `ae040e7`: `R/precompute-features.R:298`, inside `ledgr_precompute_fetch_bars()`,
and `R/backtest-runner.R:873`, inside `ledgr_run_fold()`. The environment is R 4.6.1 (Windows),
collapse 2.1.8, duckdb 1.5.5, pkgload 1.5.3 and `LC_COLLATE = English_United States.utf8`; see
`evidence/environment.csv`. The spike was moved to a worktree at `b14579f`, where both files are
unchanged, and its checker reran the parity phase there and passed.

## What ran

`probe.R` ran the real calls on a three-instrument sealed snapshot; `row.names` was the only
difference. `spike_runner.R` swaps each site's single `split()` in an in-memory copy of the
production function (it fails unless exactly one call matches) and binds the copy for one call;
tracked files never change. Split inputs are captured from real `ledgr_precompute_fetch_bars()` and
`ledgr_run()` calls, DuckDB query included, and prepared outside the timer. Containing steps evaluate
the production statements verbatim (precompute post-query, `fetch_bars` with its query, runner
hydration on both paths). Fixtures: seven small cases (NA volume, mixed-case collation, uneven
history, absent instrument, single group, collapse options, row-name-reading indicator) and two
from `ledgr_sim_bars(500, 2500, seed = 1)`, even (1,250,000 rows) and uneven (1,155,962 rows). The
uneven case reaches the runner only through the availability path: a dense run rejects it before the
split with `LEDGR_SNAPSHOT_COVERAGE_ERROR`.

## Semantics, from execution (`parity.csv`, `downstream.csv`)

- **Preserved in every group of every case:** columns, types, POSIXct `tzone`, values and NAs, row
  membership, and within-group order. Absent instruments are absent in both arms, and a single group
  stays a single group.
- **Row names differ.** `split()` keeps each row's position in the whole query result; `rsplit()`
  restarts at 1. This affects every group but the first (499 of 500 at scale). No ledgr code reads
  them: runner columns, matrices and pulse views, run fills and equity, and sweep metrics are all
  identical. User `fn()`/`series_fn()` callbacks do see them, and a callback reading `rownames()`
  gets different feature values (c7). `contracts.md` promises only "ascending time order".
- **Group order differs under this collation.** `split()` orders `aaa|b_1|B2|BBB` by the session
  locale; `rsplit()` orders `B2|BBB|aaa|b_1`. Under `LC_COLLATE = C`, base matches `rsplit()`. The
  precompute object's `payload` and `warmup` order therefore changes (and today depends on the
  machine's collation). Sweep metrics are unchanged, because projection indexes values by universe id.
- **Options.** Pinned `sort = TRUE` is unaffected by
  `set_collapse(sort = FALSE, stable.algo = FALSE, nthreads = 2, na.rm = TRUE)`. Unpinned `rsplit()`
  only coincides because the query orders by `instrument_id`; on reversed input it returns
  first-appearance order.

## Measurements

All figures are for 500 × 2,500, with medians over 15 alternating-order reps after warm-up
(`timing_summary.csv`, `memory.csv`). Allocation is R heap only, via `Rprofmem`; it is not peak
memory.

| Step (even / uneven) | base ms | rsplit ms | paired saving ms | allocated MB base → rsplit |
|---|---|---|---|---|
| precompute split | 67.4 / 63.6 | 9.9 / 9.7 | 56.9 / 54.5 | 141.6 → 81.3 |
| runner split | 76.8 / 72.4 | 11.7 / 11.2 | 64.6 / 61.6 | 156.0 → 95.6 |
| `fetch_bars`, DuckDB query included | 163.4 / 147.5 | 90.0 / 84.9 | 68.5 / 65.2 | 208.4 → 157.6 |
| runner hydration (dense / availability) | 352.4 / 955.4 | 279.2 / 870.9 | 54.1 / 83.0 | 493.0 → 432.7 / 1040.7 → 983.9 |

Relative IQR is at most 0.16. Retained split output (`object.size`) is 72.5 → 67.8 MB; the
difference is the row-name vectors. The input frame is 66.8 MB.

**Workflow context** (warm iteration on an existing sealed snapshot, 3 reps). These context clocks
include DuckDB, feature computation, fold execution and run-store writes:

- A flat `ledgr_run` takes 15.74 s in both arms: a saving of 71 ms, IQR 29–262, about 0.5%. GC is
  about 3.4 s.
- An SMA `ledgr_precompute_features` goes from 1.19 s to 1.03 s: a saving of 157 ms, or two fetches.

`call_counts.csv` shows how often each site runs, independent of candidate count:
- runner site once per `ledgr_run`;
- precompute site twice per `ledgr_precompute_features`;
- precompute site once per `ledgr_sweep`, whether or not a precomputed payload is supplied.

## Detector sensitivity

`spike_checker.R --gut misgroup` rotates the grouping key by one row in the candidate. `parity.csv`
and `downstream.csv` then fail, for example `c1_baseline` rows-equal drops from 3 to 0. Dense
hydration and precompute stop on their own misalignment guards. The availability hydration path does
not: it aligns by timestamp and overwrites `instrument_id` with the group key, so misgrouped bars
silently changed `bars_mat` and the pulse views, and only this diff caught it. The ungutted checker
passes all 15 checks, including the package-scope guard.

## Learned, demoted, deleted

- **Learned** (beyond the above):
  - `ledgr_with_collapse_deterministic()` (sort = TRUE) has no call sites.
  - The first `load_all()` compile rewrote `R/cpp11.R` and `src/cpp11.cpp` line endings. I
    restored them, and the runner now loads with `compile = FALSE`.
- **Demoted:**
  - 3-rep smoke timings, never cited.
  - Per-group evidence rows, reduced to per-case counts.
  - Context clocks: reported, not ranked.
- **Deleted:**
  - An order-sensitive attribute check. It was a false positive; only `row.names` differs.
  - Sweep comparison of timing columns and result-object attributes.
  - A gut that crashed the runner instead of producing evidence. Stopped arms are now rows.

## Limitations

- One Windows machine and one recording run.
- Context clocks have 3 reps and are GC-dominated.
- Scale ids are all of the `DEMO_nnn` form, so collation matters only in c2 and c6.
- Walk-forward folds and parallel workers were not exercised.
- DuckDB native memory is outside `Rprofmem`.

## Recommendation: reject; retain `split()`

`rsplit()` makes the split about 6.6× faster with about 40% less allocation. The saving is a
one-time ~55–70 ms per preparation call. It never scales with candidates, and it is under 1% of a
warm run.

Adopting it would also change two observable but uncontracted properties: indicator-callback row
names, and the collation-dependent order of the precompute object. Keeping them exactly would need
per-group conversions.

Whether those two properties belong in the contract (locale-independent ordering, universe-independent
row names) is a separate maintainer question that this spike does not answer. The availability-path
silence under misgrouping is noted for any future change to that path.

Rerun from the worktree root:
- `Rscript dev/spikes/collapse-preparation/spike_runner.R --phase all`
- `spike_checker.R` (add `--gut misgroup` to see the failure)
