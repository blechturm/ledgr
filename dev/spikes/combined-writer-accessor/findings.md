# Block write and prepared accessors together: findings

**Outcome: worth it.** With both changes applied, results stay byte-identical (67 parity rows) and
warm wall time at 500 × 1,260 (SMA 5/10, 68,201 fills) falls by:

- `ledgr_run`: 22%;
- one-candidate `ledgr_sweep`: 38%;
- compiled `spot_fifo` sweep: 25%;
- 8-candidate sweep: 38% (91 s saved).

The two savings add up. A failure inside the per-fill loop behaves the same in both arms. Findings
bind no design.

**Arms.** Production ("base") against both in-memory seams bound together ("combined"):
- the block write from `dev/spikes/fill-event-block-write/seam.R`;
- the prepared accessors from `dev/spikes/feature-accessor-lookup/seam.R`.

The baseline is a detached worktree at `b14579f`: R 4.6.1 on Windows, collapse 2.1.8, duckdb 1.5.5.
The evidence was recorded 14:33 to 16:28 on 2026-09-27.

## Parity (`parity.csv`: 67 rows, all identical)

Runs are compared on ledger events, fills, equity and trades. Sweeps are compared on atomic
non-timing columns, retained returns and trades, and attributes, with the random `sweep_id` dropped.

| Case | Workflows |
|---|---|
| c1 SMA crossover through the active alias map | run, sweep, `spot_fifo` sweep |
| c2 reversal pattern, 10 bps fee | run |
| c3 explicit feature map | run, sweep |
| c4 availability path, uneven history, stale(2) | run, sweep |
| c5 `db_live` | run |
| c6 `ledgr_backtest`, `checkpoint_every = 2` | backtest |
| c7 monthly rebalance (SMA 20/60) | run, sweep |
| c8 eight candidates (fast 5/10 × slow 20/40 × threshold 0/0.01) | sweep |
| s1 release shape | run, sweep, `spot_fifo` sweep |
| s2 monthly rebalance at release shape | run |

## Time (`timing.csv`, `timing_summary.csv`)

Warm clocks start from a reused sealed snapshot, with a fresh store copy per run made outside the
timer. Pairs alternate arm order and were re-measured under a load rule.

| Workload | reps | base s | combined s | saving s (IQR) | saving | GC base → combined |
|---|---|---|---|---|---|---|
| `ledgr_run` | 7 | 67.56 | 52.03 | 14.75 (13.98–19.51) | 22.1% | 9.4 → 7.1 s |
| `ledgr_sweep`, 1 candidate | 7 | 44.25 | 27.70 | 16.55 (15.86–18.93) | 38.2% | 6.3 → 4.0 s |
| `ledgr_sweep` `spot_fifo` | 7 | 27.81 | 20.82 | 7.03 (6.99–7.47) | 25.4% | 4.1 → 3.3 s |
| `ledgr_sweep`, 8 candidates | 3 | 242.5 | 146.2 | 90.7 (88.5–94.6) | 37.6% | 34.6 → 23.0 s |
| `ledgr_run`, monthly rebalance | 5 | 18.58 | 17.31 | 1.37 (0.83–1.53) | 7.4% | 2.8 → 2.6 s |
| `ledgr_sweep`, monthly rebalance | 5 | 6.05 | 4.54 | 1.57 (1.41–1.58) | 25.7% | 0.6 → 0.4 s |

**Eight candidates.** The saving is about 11 s per candidate, a little under the single SMA 5/10
candidate's 16.5 s. The accessor saving is fixed per strategy call, about 7 s per candidate. The
block-write saving follows fills, and the slower SMA and threshold candidates trade less.

**Monthly rebalance.** This strategy reads features and changes targets only on the first pulse of
each month, and holds otherwise. At release shape that is 9,002 fills on about 60 active pulses
(about 150 per active pulse) and about 30,000 feature calls, against 68,201 fills and 630,000 calls
for the daily strategy.

Both savings shrink with activity:
- The run saves 1.4 s of 18.6 s, because its fixed per-run costs dominate.
- The sweep has fewer fixed costs, so it still saves 26%.

Nothing got slower.

**Width** (`width_scaling.csv`, 3 reps, 1,260 sessions; every pair ran load-free):

| Instruments | `ledgr_run` saving | `ledgr_sweep` saving |
|---|---|---|
| 10 | 0.14 s (4.2%) | 0.04 s (1.8%) |
| 50 | 1.17 s (13.7%) | 1.13 s (20.0%) |
| 150 | 2.20 s (10.1%) | 4.57 s (32.8%) |
| 500 | 14.75 s (22.1%) | 16.55 s (38.2%) |

The gain is small at 10 instruments and substantial from 50 up. At 3 repetitions the run's 50/150
ordering is within noise.

## The two savings add up

| Workflow | block alone (own spike) | prepared alone (own spike) | sum | combined |
|---|---|---|---|---|
| `ledgr_run` | 6.54 s | 6.87 s | 13.4 s | 14.75 s |
| `ledgr_sweep` | 8.74 s | 8.25 s | 17.0 s | 16.55 s |
| `spot_fifo` sweep | 0 (already batch-writes) | 7.08 s | 7.1 s | 7.03 s |

The same-session four-arm phase (`additivity.csv`) gives block alone 6.42 / 9.03 s and combined
13.70 / 16.21 s (run / sweep). Combined minus block alone is 7.3 / 7.2 s, which matches the accessor
spike.

That phase's "prepared alone" arm is not usable (2.5 / 3.4 s). R 4.6.1's JIT byte-compiles a
closure made in a local environment only for the first copy of its code in a session. That arm was
the runner's second copy of the accessor seam, so it ran interpreted, at about 17 µs per call
instead of 8. A scratch diagnostic and a ten-line reproduction confirmed this.

Every other arm in every spike used a single, first copy. The runner now compiles each seam with
`compiler::cmpfun()` and writes `compilation.csv`, which shows byte code throughout. Installed
packages are byte-compiled at install, so this is a harness effect only.

## Where the time went (`attribution.csv`, one 10 ms `Rprof` per arm)

| Frame | `ledgr_run` base → combined | `ledgr_sweep` base → combined |
|---|---|---|
| fill-event writing (`write_fill_events`) | 11.8 → 6.2 s | 7.1 → 2.3 s |
| of which per-event buffer writes, then per-pulse flush | 5.1 → 0.35 + 0.33 s | 5.0 → 0.42 + 0.73 s |
| `ctx$features` | 9.3 → 4.6 s | 9.0 → 4.4 s |
| alias-map lookup inside it | 2.1 → 0 s | 2.0 → 0 s |
| sampled total | 45.8 → 35.7 s | 30.3 → 19.4 s |

The largest untouched costs are:
- lot accounting (`ledgr_lot_apply_fill`), about 6.9 s of the run;
- per-fill row and JSON construction (`ledgr_fill_event_payload`), about 5.7 s.

## Failure path (`failure.csv`)

`ledgr_lot_apply_fill()` is wrapped to raise an error on the 45th fill, on the reversal fixture. That
fill is the 9th of 20 in its pulse, so under the block write, 8 of the pulse's events are staged but
not flushed.

| Workflow | Status | Persisted events | Events before failing pulse / fill |
|---|---|---|---|
| `ledgr_run`, audit log | FAILED | 0 | 36 / 44 |
| `ledgr_run`, `db_live` | FAILED | 0 | 36 / 44 |
| `ledgr_backtest`, `checkpoint_every = 2` | FAILED | 0 | 36 / 44 |
| `ledgr_sweep`, candidate 1 | FAILED, injected error recorded | n/a | |
| `ledgr_sweep`, candidate 2 | DONE, 1,854 trades | n/a | |

Every row is the same in both arms. The durable fold runs inside one `DBI::dbWithTransaction()`
(`R/fold-engine.R` calls `output_handler$run_transaction(run_loop)`), checkpoints included, so a
failure rolls the whole run back. Staged rows can never reach the store. The sweep's memory handler
is per candidate. Under current semantics, the block write needs no failure-semantics decision.

## Hygiene and limits

- **Shared machine.** One kept one-candidate sweep pair (rep 3) ran next to another session's R
  processes, up to 1.98 other busy cores, on every one of its four attempts. That fails the
  checker's load gate. That pair saved 20.8 s. Without it, the sweep's median saving is 16.4 s
  instead of 16.5 s. Every other kept observation was under one other busy core.
- **Partial rerun.** A rerun with compiled seams was stopped after its parity phase: the numbers
  above already answer the question. `fixture.csv`, `parity.csv`, `failure.csv`, `compilation.csv`
  and `environment.csv` come from that rerun and match the earlier recording's deterministic output.
  The timing, additivity, width and attribution files come from the 14:33 recording.
- **Coverage.** One Windows machine; `load_all()` code, not an installed build; one profile per arm.
  Walk-forward and the peer-benchmark lanes were not timed.

Rerun from the worktree root:
- `Rscript dev/spikes/combined-writer-accessor/spike_runner.R --phase all`
- `spike_checker.R` (add `--gut misorder` to see parity fail)
