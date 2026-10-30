# Protocol ws4a-timing-1

Status: frozen by LDG-3163 (v0.2.3 cut 5, decision (4)), before cut
acceptance. The cells, workloads and bounds are decision (4)'s. The `reps`
and `pairs` in `matrix.csv` are frozen as sized by the recorded smoke in
`dev/bench/v0_2_3_ws4a/records/timing/` (`functional_check.csv`,
`base_marginal_smoke.csv`); that smoke is a base record, not a completed
A/A gate window, which macro rule 12 does not require here. Runs on the shared harness in
`dev/bench/timing/`; the benchmark manual's "Before/After Regression Gates"
states the harness rules. The executable statement is this folder's
`matrix.csv`, `thresholds.csv` and `workloads.R`; this page explains them,
and where they disagree the files bind.

## Workloads

Every slot builds its own fixture in its fresh work directory from
`ledgr_sim_bars(500, 1260, seed = 20260530)` (500 instruments `DEMO_01` to
`DEMO_500`, 1,260 business days from 2018-01-01), with every bar moved to
21:00 UTC. Every fixture has zero cost, no risk rule, cash 1e7 and the
default next-open timing; no execution seed is passed.

- **Producers.** `availability`: a snapshot with complete facts, one
  session row per calendar day (open 14:30-21:00 on bar days, closed
  otherwise) and one complete membership snapshot of universe `u`,
  effective before the first session, listing every instrument, so every
  instrument is a member every session; the experiment's universe is
  `ledgr_universe_members("u")`. `dense`: the same bars, no facts, no
  universe rule.
- **wide**: the carrier probe's SMA 5/10 transition (`fast`, `slow` via
  `ledgr_ind_ttr("SMA")`), one unit: enter on a fresh fast-above-slow
  crossing, exit on the reverse, each only when the previous pulse was
  usable. State carries the `above` and `usable` vectors.
- **nofill**: the same features, reads and state update as wide, with flat
  targets (`ctx$flat()`), so no fill happens. It is the probe's floor.
- **sparse**: on the first pulse of each calendar month (month of
  `ctx$ts_utc` differs from the previous pulse's, carried in state), when
  every instrument's 63-session return (`ledgr_ind_returns(63)`) is finite,
  hold the top 20 by that return, ties by instrument ID in C-locale order
  (`order(..., method = "radix")`), 10 units each, everything else zero;
  otherwise hold. Before the return is warm nothing is held, so there are
  no warmup trades.

## Cells and bounds

| Cell | Path | Bound | Decision (4) |
| --- | --- | --- | --- |
| `avail_wide_run`, `dense_wide_run` | durable `ledgr_run()` | 0.60 each | wide all-fill durable runs |
| `dense_wide_sweep` | `ledgr_sweep()` | 1.03 | dense wide sweep |
| `avail_wide_sweep` | `ledgr_sweep()` | 1.00 | availability wide sweep, fixed relative cell |
| `avail_nofill_run`, `dense_nofill_run`, `avail_nofill_sweep`, `dense_nofill_sweep` | run, sweep | 1.03 each | no-fill runs and sweeps |
| `avail_sparse_run`, `dense_sparse_run`, `avail_sparse_sweep`, `dense_sparse_sweep` | run, sweep | 1.00 each | sparse-rebalance runs and sweeps |
| `read_fills`, `read_trades` | `ledgr_results()` | 1.03 each | warm public fills and trades reads (replay path) |
| `read_equity` | `ledgr_results()` | 1.03 | warm public equity reads, a result-reader cell, not a replay witness |
| `avail_wide_marginal` | two `ledgr_sweep()`s | 1.00, and the absolute bound below | absolute cell |

A gate passes a ratio cell when the candidate median over the base median
is at most its bound (`dev/bench/timing/check.R`). The shared checker
requires a bound for every cell, so `avail_wide_marginal` also carries
1.00; it cannot bind before the absolute bound while the base marginal is
above 40 us.

## One measurement

**Run and sweep cells** (`ws4a_path`, args producer, shape, path, reps).
Untimed: the fixture, one warm-up execution of the same path and shape,
`gc()`. Timed, clock `run` or `sweep` (`as.numeric(Sys.time())`): from
immediately before the first `ledgr_run()` or `ledgr_sweep()` call of the
first rep to immediately after the last `close()` or `ledgr_sweep()` return
of the last rep. A run is persisted in the snapshot's store under its own
run_id per rep (`ws4a-timed<rep>`), its handle closed, no reader called. A
sweep is one candidate, one worker, `stop_on_error = TRUE`, retaining
completed returns and closed trades, in memory, not saved. Work: the
outcome `status|closed trades|final equity` (runs from `ledgr_run_list()`,
sweeps from the returned row), which every rep must repeat from the
warm-up; nofill must be `DONE|0|10000000.0000`, wide and sparse must close
trades.

**Reader cells** (`ws4a_reader`, args what, reps). Untimed: the
availability wide fixture, one durable `ledgr_run()` whose handle stays
open, one warm `ledgr_results(bt, what)` call, `gc()`. Timed, clock
`read`: `reps` complete `ledgr_results()` calls, from immediately before
the first to immediately after the last returns. Work: the row count, which
every call must return, and the number of complete calls. Fills and trades
must return rows: those are the replayed rows that make them replay
witnesses.

**Absolute cell** (`ws4a_marginal`, args reps). One process times matched
availability wide and nofill sweeps (the sweep above). Untimed first: the
fixture; one durable wide `ledgr_run()`, whose `ledgr_results()` fills and
closed trades and final equity fix the fill count, because a sweep row
reports closed trades but no fill count; one warm-up nofill sweep; `gc()`.
Then per rep, a nofill sweep and then a wide sweep, each timed from
immediately before its call to immediately after its return. A rep's fills
are its closed trades plus the run's fills that closed nothing; the
workload refuses a rep whose fills or final equity differ from the run, a
nofill rep that traded, and unequal fill denominators across reps. Its own
clock is `marginal = (wide_total - nofill_total) / reps /
fills_per_repetition`, never clamped; a nonpositive or nonfinite value is
reported as measured and the shared checker fails it as invalid seconds.
Work: reps, the fill count per repetition, the run's fills and closed
trades, both outcomes and the materialisation policy. The two totals are
returned as further named clocks (`wide_total`, `nofill_total`), which
`measure.R` does not persist: the work string must be identical on every
row of a cell, so it cannot carry per-process seconds.

`dev/bench/v0_2_3_ws4a/timing_absolute.R` reads the shared checker's
per-cell result for `avail_wide_marginal` and fails unless the record is
valid, every pair has a valid candidate row and the candidate median is
finite, positive and at most 40e-6 seconds. It never subtracts medians of
separate cells. Its `--self-test` rejects 45 us against a 240 us base,
accepts 30 us, and rejects zero, negative and nonfinite values.

## Reps

Every timed section should last about 3 s or more on the maintainer host
(`dev/bench/timing/records/clock-probe/README.md`). The frozen reps come
from one functional pass of every cell at reps 1 on the base (953338df,
one R process, a possibly shared host, not a timing window): timed
sections of about 21.9 s (availability wide run), 17.0 (dense wide run),
12.3 (dense wide sweep), 22.7 (availability wide sweep), 7.4 and 2.1
(availability and dense nofill runs), 6.5 and 1.9 (nofill sweeps), 5.9 and
2.0 (sparse runs), 4.9 and 1.9 (sparse sweeps), 3.6 per fills read, 3.7 per
trades read, 0.04 per equity read, and 21.7 wide and 6.4 nofill sweep
totals in the absolute cell (226.06 us per fill over 67,725 fills, matching
the carrier probe's 226.50). Cells near 2 s use reps 2 and equity reads
reps 75. On a quiet host the absolute cell then read 216.95, 215.05 and
215.83 us per fill (spread 0.9%), with 67,725 fills in every run
(`base_marginal_smoke.csv`).

## Records

- **Base record (LDG-3163).** The recorded smoke above
  (`dev/bench/v0_2_3_ws4a/records/timing/`): every cell's functional pass
  and three quiet runs of the absolute cell. It is not an A/A gate window;
  the gate's alternating pairs carry their own noise evidence (macro rule
  12). The absolute verdict on the base is expected to fail: about 216 us
  per fill against the 40 us bound.
- **Gate records (LDG-3164 replay cells, LDG-3169 all cells).** The same
  protocol, unchanged, with the candidate.

```powershell
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF; `
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/runner.R `
  --protocol=dev/bench/timing/protocols/ws4a-timing-1 --base=<commit> --candidate=<commit> --label=<name>
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/check.R `
  --protocol=dev/bench/timing/protocols/ws4a-timing-1 --record=dev/bench/timing/records/ws4a-timing-1/<name>/attempt-1
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/v0_2_3_ws4a/timing_absolute.R `
  --protocol=dev/bench/timing/protocols/ws4a-timing-1 --record=dev/bench/timing/records/ws4a-timing-1/<name>/attempt-1
```
