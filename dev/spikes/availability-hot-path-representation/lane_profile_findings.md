# Availability Hot-Path Lane Profile Findings

**Date:** 2026-09-14. **Stage:** prerequisite probe (`spike_protocol.md` section 1)
requested by Response Review v1. Not a spike, charter, or implementation.

## Source state and environment

- Branch `v0.2.0.1`; HEAD `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`; worktree
  unchanged apart from the two probe files.
- R 4.5.2 (2025-10-31 ucrt), `x86_64-w64-mingw32`; ledgr from the working tree
  via `pkgload::load_all(export_all = TRUE)` with srcrefs; collapse 2.1.7
  (production dependency state); duckdb 1.4.3.
- `Rprof(interval = 0.01, memory.profiling = TRUE, line.profiling = TRUE,
  gc.profiling = TRUE)` around `ledgr_run()` only; process working set sampled
  every 200 ms by an external PowerShell sampler per child process.
- Fixture: 563 instruments, 505-member axis, 40 open weekday sessions
  (2021-01-04 to 2021-02-26, all 54 civil days declared), 22,520 complete bars,
  four identical complete lists effective 2021-01-04/01-18/02-01/02-15 (each
  knowable the day before), `active` status and `known_active` lifetime facts
  for all 563, `ctx$flat()`, cash 1e6, zero positions, stale limit 2, zero cost.
- `t_loop` starts at `R/fold-engine.R:1113`, wraps
  `output_handler$run_transaction(run_loop)` at 1116 (transaction, pulse loop,
  final bind at 1093, persistence at 1105-1108), and ends at 1141.

## Question

Which lane dominates wall time and allocation pressure in the current
availability-aware flat fold on a shortened, public, production-shaped
synthetic fixture?

## What ran

`lane_profile_probe.R`: one unmeasured warm-up, three measured profiled runs,
and one unprofiled reference run used only as a cross-check, each a fresh
child process with its own scratch store and run ID. Every run reached `DONE`
with 20,200 `decision/recorded` rows plus 40 `reconciliation/reconciled` rows
(one portfolio-scope row per pulse), zero execution-stage rows, zero fills, and
all four fact families `declared` in `ledgr_experiment_plan()`.

No `execution_view()` call: a `trace()` on
`ledgr_fold_build_availability_pulse_plan` summed `length(actionable_idx)` to
zero in every run, and `execution_view()` is reachable only inside that loop
(`R/availability-economics.R:225-251`); it appears in no profiler sample.

After profiling stopped, each child replayed the diagnostic lane from the
persisted rows (constructor per row, then `do.call(rbind, rows)`) under
`proc.time()`. The replay feeds persisted scalars, so it excludes the fold's
live `[[id]]` lookups and slightly understates construction.

## Results

Runs 1-3 then median: wall 56.95 / 51.14 / 51.50 (51.50 s); `t_loop`
54.80 / 49.08 / 49.45 (49.45 s); peak working set 773.7 / 814.1 / 804.7
(804.7 MiB); in-loop samples 3528 / 3157 / 3181 (31.81 s, 64% of `t_loop`);
GC samples 752 / 733 / 761. Reference run: wall 51.51 s, `t_loop` 49.47 s,
peak 819.7 MiB; profiler overhead on `t_loop` is nil.

| lane (sampled self time, s) | run1 | run2 | run3 | share | growth MiB | gc |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| final_rbind (`fold-engine.R:1093`) | 13.32 | 13.09 | 13.43 | 41.9% | 7585.9 | 614 |
| provider_status_lifetime | 11.10 | 9.34 | 9.24 | 29.4% | 1488.4 | 81 |
| diag_construct (`availability-economics.R:408`) | 9.24 | 7.83 | 7.87 | 24.7% | 702.9 | 45 |
| provider_membership | 0.63 | 0.51 | 0.53 | 1.7% | 305.6 | 3 |
| valuation | 0.39 | 0.31 | 0.32 | 1.0% | 64.0 | 0 |
| residual_fold | 0.28 | 0.27 | 0.25 | 0.8% | 40.7 | 0 |
| diag_append_retain | 0.31 | 0.21 | 0.16 | 0.7% | 18.6 | 0 |
| duckdb_diag_append | 0.01 | 0.01 | 0.01 | 0.0% | 0.0 | 0 |

Share is the median fraction of in-loop samples; growth is median positive
Vcell growth (Rprof's memory fields fell between samples, minimum delta
-6,641,231 cells, so this is a lower bound on allocation, not retained memory).
Sampled totals (median, overlapping): `run_transaction` 31.81 s,
`decision_view` 9.85 s, `rbind` 13.32 s, `append_diagnostic` 8.00 s. Hottest
in-loop lines: `fold-engine.R:1093` (1332 samples), `availability-economics.R:408`
(910), then `availability-provider.R` 187-235 and 51-57 at 79-117 each.

Deterministic replay (median / reference): 20,240 rows; construct 12.05 /
12.07 s; bind 20.29 / 20.90 s; retained list 110.0 MiB against a 3.2 MiB bound
frame. Reference `t_loop` 49.47 s minus replayed construct plus bind 32.97 s
leaves at most 16.50 s for every non-diagnostic lane combined. Rprof sampled
64% of `t_loop`; the replay places the unsampled remainder in the bind and
construction (sampled 13.3 s and 7.9 s against replayed 20.3 s and 12.1 s), so
the leader is the same under either method.

## Attribution result

**DIAGNOSTICS_DOMINANT.** Grouped median in-loop shares: diagnostics 67.0%,
provider 31.2%, valuation 1.0%, residual 0.8%; diagnostics led in every run;
margin 35.8 points. Under the pre-registered rule the diagnostic-first wall
attribution is not falsified: construction plus bind plus persistence is the
largest lane and provider resolution is smaller. The sampling-independent
bound agrees: diagnostics is at least 33.0 s of a 49.5 s loop.

## What Seed v2 may consume

- On this fixture the retained row list plus final `do.call(rbind, ...)` is
  the largest wall lane and the largest allocation source; the bind alone is
  the single largest lane (41.9% sampled, 20.3 s replayed, 614 of about 750 GC
  samples). The memory mechanism reproduces on real fold output: 110 MiB
  retained for a 3.2 MiB result.
- Provider resolution is second at 31.2%; within it status, lifetime and
  terminal-event resolution (`availability-provider.R:187-235`, applicability
  filter at 51-57) dominate; membership is 1.7% at four identical headers.
- Valuation, append retention, DuckDB append and residual work are each at
  or under 1% here.
- The flat fold writes one reconciliation row per pulse; diagnostic rows are
  `pulses x axis + pulses`.
- `t_loop` includes transaction, final bind and persistence
  (`R/fold-engine.R:1113-1141`); the fold's stride-sampled `t_ctx`/`t_target`/
  `t_fill` timers do not isolate these lanes.

## What remains open

- Scaling: 40 pulses, one axis width, identical lists. The bind is
  super-linear in rows and provider cost grows with accumulated headers, so the
  ordering at 757 pulses is not established here and must not be extrapolated.
- Whether status/lifetime resolution leads once the diagnostic representation
  is corrected: the kill/recharter question.
- Non-flat folds (the `execution_view()` path) were not profiled.
- Implementation choice, chunk size, collapse version floor, comparative
  writer design, and release placement.

## Handoff

READY_FOR_CODEX_SEED_V2
