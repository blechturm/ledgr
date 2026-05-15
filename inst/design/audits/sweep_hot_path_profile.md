# Sweep Hot-Path Profile

**Date:** 2026-05-15  
**Ticket:** LDG-2108B  
**Branch:** v0.1.8  
**Script:** `dev/spikes/ledgr_sweep_performance/profile_hot_path.R`

## Purpose

Profile the LDG-2108 memory-backed sequential sweep path after LDG-2108A showed
only a modest speedup over a persistent `ledgr_run()` loop. This spike is
diagnostic only. It does not change runtime behavior and does not propose an
optimization patch for v0.1.8.

The exit question was: where does the current 50-candidate sweep time go?

## Fixture

The profile uses the same benchmark shape as LDG-2108A.

- 4 synthetic instruments
- 252 EOD bars per instrument
- 1,008 total bars
- 50 sweep candidates
- Feature-consuming strategy using `ctx$feature()`
- Candidate-varying feature factory:
  `ledgr_ind_returns(params$lookback)`, with lookbacks `5`, `10`, `20`, `40`,
  and `80`
- Seed: `2108`
- Warnings suppressed inside timed sections
- Temporary DuckDB files deleted at script exit

## Methods

Three diagnostic layers were used:

1. Coarse namespace-wrapper timing around selected private phases. The wrappers
   are installed only inside the profiling process and restored afterward.
2. Base `Rprof()` sampling for the 50-candidate plain sweep and the
   precomputed-feature sweep.
3. Small repeated timings for selected suspected helpers.

`Rprof()` sampling time is used for relative hotspot ranking, not as an exact
wall-clock substitute. The wrapper timings are more useful for phase-level
wall-clock proportions.

## Coarse Phase Timing

Plain sweep:

| Phase | Calls | Elapsed | Share of measured wall |
|---|---:|---:|---:|
| `ledgr_sweep_run_candidate()` | 50 | 27.85s | 97.0% |
| `ledgr_execute_fold()` | 50 | 18.30s | 63.8% |
| `ledgr_equity_from_events()` | 50 | 5.73s | 20.0% |
| `ledgr_fills_from_events()` | 50 | 3.11s | 10.8% |
| Feature matrix build | 50 | 0.05s | 0.2% |
| Feature resolution | 1 | 0.09s | 0.3% |

Precomputed-feature sweep:

| Phase | Calls | Elapsed | Share of measured wall |
|---|---:|---:|---:|
| `ledgr_sweep_run_candidate()` | 50 | 26.52s | 99.6% |
| `ledgr_execute_fold()` | 50 | 17.14s | 64.4% |
| `ledgr_equity_from_events()` | 50 | 5.66s | 21.3% |
| `ledgr_fills_from_events()` | 50 | 3.16s | 11.9% |
| Feature matrix hydration from precompute | 50 | 0.01s | 0.04% |

## Rprof Findings

For both plain and precomputed sweeps, the profile shape is essentially the
same.

Top total-time frames:

- `ledgr_execute_fold()`: about 65% of sampled time.
- `ledgr_update_pulse_context_helpers()`: about 25%.
- `ledgr_attach_feature_helpers()`: about 21%.
- `ledgr_features_wide()`: about 17%.
- `ledgr_equity_from_events()`: about 21%.
- `ledgr_fills_from_events()`: about 12%.

Top self-time frames are broad R data-structure operations rather than one
single ledgr arithmetic primitive:

- `data.frame()`
- `$<-.data.frame`
- `as.data.frame()`
- `%in%`
- `deparse()`
- `format.POSIXlt()`
- `rbind()`
- list and data-frame indexing

The practical interpretation is that the hot path is dominated by repeated
per-pulse R object construction and conversion, plus post-candidate
event-derived reconstruction.

## Micro-Timing Notes

Direct repeated timings were run for:

- `ledgr_sweep_bars_matrix()`
- `ledgr_sweep_compute_feature_matrix()`
- `ledgr_sweep_feature_matrix_from_precomputed()`
- `ledgr_features_wide()`
- `ledgr_update_pulse_context_helpers()`
- `ledgr_validate_strategy_targets()`

Most individual calls are below `proc.time()` resolution at this small
universe/feature width. That is itself useful: there is no single expensive
feature-matrix call in this workload. The cost accumulates because context and
feature-table helper work happens once per pulse per candidate:

```text
50 candidates x 252 pulses = 12,600 pulse contexts
```

## Interpretation

The original expectation that feature precompute or DuckDB removal would unlock
large single-core gains is not supported by this workload.

What is not slow here:

- fetching bars once for the sweep;
- normalizing bars;
- resolving feature factories;
- building or hydrating this cheap feature matrix;
- computing scalar summary metrics.

What is slow:

- running the fold 50 times;
- rebuilding pulse context helpers and feature-wide tables on every pulse;
- reconstructing equity and fills from in-memory events after every candidate.

The post-candidate reconstruction cost is material: `ledgr_equity_from_events()`
and `ledgr_fills_from_events()` together account for roughly **31%-33%** of the
measured sweep wall time. The fold itself accounts for roughly **64%**, with
Rprof pointing strongly at data-frame/context helper churn inside each pulse.

## Recommendation

Do not add an optimization patch to v0.1.8 before LDG-2109.

The profile does reveal real opportunities, but they touch the fold hot path and
derived accounting path. Those are exactly the areas v0.1.8 is trying to
stabilize for parity, provenance, and promotion. Optimizing them now would risk
destabilizing the release contract.

Recommended follow-up after the v0.1.8 sweep/promotion contract is stable:

1. Investigate a faster sweep pulse context path that avoids rebuilding
   `features_wide` and closures every pulse.
2. Investigate summary-only in-memory accounting that avoids parsing and
   replaying the event stream multiple times per candidate, while preserving
   ledger parity guarantees.
3. Re-profile after LDG-2109/LDG-2112 because provenance columns and parity tests
   may slightly change allocation patterns.

No immediate optimization ticket is recommended for the current cycle unless a
reviewer decides that the context-helper churn has a very small, isolated fix.

## Design Memory

This finding should stay visible in `horizon.md`: single-core sweep performance
is currently limited by pulse-context/data-frame churn and post-candidate
event-derived reconstruction, not by feature precompute or DuckDB persistence
alone.

## Raw Output Excerpt

```text
PLAIN SWEEP ELAPSED
[1] 28.7

PLAIN PHASE TIMINGS
phase                                      calls elapsed_sec pct_total
ledgr_sweep_run_candidate                    50       27.85     97.0
ledgr_execute_fold                           50       18.30     63.8
ledgr_equity_from_events                     50        5.73     20.0
ledgr_fills_from_events                      50        3.11     10.8
ledgr_sweep_compute_feature_matrix           50        0.05      0.2

PRECOMPUTED SWEEP ELAPSED
[1] 26.62

PRECOMPUTED PHASE TIMINGS
phase                                      calls elapsed_sec pct_total
ledgr_sweep_run_candidate                    50       26.52     99.6
ledgr_execute_fold                           50       17.14     64.4
ledgr_equity_from_events                     50        5.66     21.3
ledgr_fills_from_events                      50        3.16     11.9
ledgr_sweep_feature_matrix_from_precomputed  50        0.01      0.0
```
