# The per-run snapshot rehash after Workstream 22 (input to WS5)

2026-10-10, from Cut 11 Workstream 22 measurements on the ledgr tree at
`1df4d3f` (Sharadar S&P lake: 1,166 instruments, 7,213 sessions, 5.5 million
bars) and on the scale fixture (800 instruments, 1,260 sessions). This note
records measurements for the WS5 verification-policy session; it decides
nothing.

## Bottom line

Once Workstream 22 removed the fold antipatterns, the snapshot rehash became
the largest single cost of a committed run. On Sharadar it is about half of a
momentum run, and it probably accounts for most of a walk-forward. Dense and
point-in-time snapshots pay it identically. Its cost scales with the bars in
the whole snapshot, not with the run's universe or window, and it is
dominated by row-by-row R formatting of bars, not by the point-in-time facts.

## Where it runs

Every committed run recomputes the full snapshot hash and compares it with the
stored one. Nothing gates it: `availability_active` is passed to the guard but
does not condition the hash.

| Entry point | Full rehashes | Code |
| --- | --- | --- |
| `ledgr_run()`, dense or point-in-time | 1 | `ledgr_run_snapshot_guard()`, `R/run-snapshot.R` |
| `ledgr_backtest()` (legacy wrapper) | 2 | `ledgr_snapshot_validate()` in `R/backtest.R`, then the run guard |
| `ledgr_promote()` | 1 | commits a run |
| `ledgr_walk_forward()` | 1 per fold | each test run goes through `ledgr_run_window()` and the run guard; a DONE or INCOMPLETE test run reused on resume skips it |
| `ledgr_sweep()` candidates, walk-forward training sweeps | 0 | |
| `ledgr_rebuild_derived_state()`, snapshot list verification, availability inspection | 1 each, on demand | `R/derived-state.R`, `R/snapshots-list.R`, `R/availability-inspection.R` |

`ledgr_backtest()` hashing twice in a row is a defect whatever the session
decides.

## What it costs

Rprof on the final tree, sampled seconds (Windows timer granularity makes
sampled time about a third of elapsed; the ratio is stable within a run).
Profiles: `E:/ledgr-data/sharadar/experiments/LDG-2982/profile_final/` (private
store, function names and times only) and
`dev/bench/v0_2_2_real_data_scale/evidence/profile_final/` (fixture).

| Measure | Fixture momentum run | Sharadar momentum run |
| --- | --- | --- |
| Run, sampled | 7.2 s | 36.7 s |
| `ledgr_snapshot_hash`, sampled | 3.1 s (42%) | 17.9 s (49%) |
| of which bar and instrument rows (`hash_query_streaming`) | 3.0 s | 17.2 s |
| of which bar timestamp formatting | | 12.1 s |
| of which point-in-time fact payload | 0.05 s | 0.5-0.7 s |
| Rehash, elapsed (derived from the sampling ratio) | about 9 s | about 55 s |

On the Sharadar equal-weight run the rehash is 30 percent (17.6 of 59.2 s
sampled): the same absolute cost on a longer fold.

## Dense against point-in-time

| | Dense snapshot | Point-in-time snapshot |
| --- | --- | --- |
| When it rehashes | as in the table above | identical |
| What it hashes | instruments and every bar | the same, plus every fact table (sessions, membership sets, lifetimes, corporate actions, quarantine) through one `canonical_json` payload |
| Cost driver | bars in the whole snapshot | the same, plus fact rows |
| Bar part at 5.5 million bars | about 53 s elapsed (derived) | about 53 s elapsed |
| Fact part on Sharadar | none | about 2 s elapsed, 3-4 percent of the hash |
| Typical exposure | snapshots are often built for a fixed, smaller universe | snapshots usually carry the full survivorship-free history, so more bars per run |

The dense rows at Sharadar scale are derived, not measured: no dense snapshot
of that size exists here, and the bar-hashing code is shared by both kinds.

## Walk-forward

The Sharadar walk-forward (26 contiguous yearly folds, two candidates) took
1,894 s on the final tree, against 2,288 s before Workstream 22. With one
rehash of about 55 s per fold, about 24 minutes of the 32 are rehashing.
This is an estimate from the per-run cost, not a profile of the walk-forward;
the session should profile one walk-forward before relying on it.

## For the session

These are questions the measurements raise, not proposals:

- Whether a committed run must recompute the full hash at all, or may verify
  against a trusted digest with defined invalidation (the existing WS5 bullet
  on scoped or reused verification). The walk-forward case is the sharpest:
  26 identical rehashes of an unchanged snapshot in one session.
- Whether full verification, wherever it remains, moves the bar
  canonicalization into DuckDB or a binary payload (the existing hashing
  spike and binary-payload experiment). The R row formatting is about 70
  percent of the hash.
- Whether `ledgr_backtest()`'s second hash is simply removed.

## Caveats

Single unpaired profiles on a shared machine; the fixture A/A noise was up to
8 percent elapsed. The Workstream 22 phase clocks (one Sharadar pre-cut and
final pair, three fixture pairs per ticket) are in
`dev/bench/v0_2_2_real_data_scale/evidence/`.
