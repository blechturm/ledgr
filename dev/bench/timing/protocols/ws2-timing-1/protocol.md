# Protocol ws2-timing-1

Status: frozen before any product change of v0.2.3 cut 4 (LDG-3156). Runs on
the shared harness in `dev/bench/timing/`; the benchmark manual's
"Before/After Regression Gates" states the harness rules. The executable
statement is this folder's `matrix.csv`, `thresholds.csv` and `workloads.R`;
this page explains them, and where they disagree the files bind.

## What is measured

Every cell is one workload, one public path and one seed state:

- `run`: `ledgr_run()` once per sweep candidate, each handle closed;
- `sweep`: one `ledgr_sweep()` over the same grid, one worker, retaining
  completed returns and closed trades;
- `seeded`: the sweep gets the workload's seed and each committed run gets
  that candidate's `execution_seed` from the sweep;
- `unseeded`: the sweep and every committed run get `seed = NULL`.

| Workload | Source of the fixture | Bars | Candidates | Sweep seed | Seed states |
| --- | --- | --- | --- | --- | --- |
| `dense_scale_50x1260` | WS1 `matrix.R` | 50 x 1260 | `q10`, `q20` | 7 | seeded, unseeded |
| `timing_scale` | A0 `timing.R` | 20 x 252 | `q10`, `q20` | 7 | seeded, unseeded |
| `stochastic_50x1260` | this protocol | 50 x 1260 | `k5`, `k10` | 11 | seeded |

**Reps.** Every timed section should last about 3 s or more on the
maintainer host: under one second a cell swings about 5% per pair
(`dev/bench/timing/records/clock-probe/README.md`). Each cell's `reps` arg,
frozen in `matrix.csv`, repeats its timed path that many times inside one
timed section, with the clock around all reps and a distinct run_id per rep.
From the base-tree smoke timings of one pass: dense run about 4.8 s and
sweep about 3.8 s, stochastic run about 7.2 s and sweep about 5.9 s (all
`reps=1`); timing_scale run about 0.88 s (`reps=4`) and sweep about 0.6 s
(`reps=6`).

Ten cells, eight pairs, 160 fresh processes per window. The fixture
builders are copied into `workloads.R` unchanged in substance, so the four
files are the protocol's whole input. All prices are deterministic; only
the stochastic strategy draws.

**The stochastic workload** follows the contract's recipe: a seed-required
guard (`stop()` when `ctx$pulse_seed` is NULL), then
`withr::with_seed(ctx$pulse_seed, sample.int(length(ctx$universe), k))` on
every pulse. When the book holds anything the target is flat; otherwise it
buys exactly `k` drawn instruments (quantity 10, 5 bps spread, cash 1e7).
Every instrument has a bar every session, so the number of trades is the
same whichever instruments a pulse seed draws, under the current pulse rule
or any other; the draws change only which instruments trade. Its work is
therefore invariant by construction across arms, including after LDG-3159
replaces the pulse-seed rule.

**Work.** Each process reports its candidates' statuses and trade counts as
`DONE;DONE|<trades>;<trades> x<reps>`. The workload itself fails unless
every rep gives both candidates `DONE` with the same nonzero trade counts,
and the harness requires every row of a cell, in both arms and every pair,
to report the same work. The deterministic workloads do not draw, so no
accepted change of cut 4 changes their trade counts. On the base tree each
cell reported `DONE;DONE` with trade counts 3086;3086 (dense), 118;118
(timing_scale) and 3145;6290 (stochastic) in both seed states and paths;
the held draft's probe found the same stochastic counts for sweep seeds 11,
12 and 999.

## One measurement

One process per cell and arm. After the harness loads the arm's ledgr:

1. untimed, identical for both arms and paths, in the cell's seed state: the
   fixture's snapshot in a fresh DuckDB file, one sweep (supplying each
   candidate's params and, when seeded, its execution seed), one committed
   run per candidate, then `gc()`;
2. the timed path, `reps` times, in the same seed state;
3. untimed: each rep's runs' statuses and trade counts (`ledgr_run_list()`),
   or each rep's sweep `status` and `n_trades`.

**Clock endpoints** (clock `run` or `sweep`, `as.numeric(Sys.time())`):
immediately before the first `ledgr_run()` or `ledgr_sweep()` call of the
first rep, and immediately after the last `close()` or `ledgr_sweep()`
return of the last rep.

**Retained surfaces.** Run path: each candidate's persisted run in the
snapshot's DuckDB store as `ledgr_run()` writes it, run_id
`ws2-timed<rep>-<candidate>`; no reader is called. Sweep path: each rep's
returned in-memory sweep with completed returns and closed trades; it is
not saved. The timed snapshot has already been opened and
executed against in both arms.

**Candidate compatibility.** The workloads use only the public calls above,
`ctx$pulse_seed` and `withr`. The base runs them now; the final candidate,
after the v2 pulse rule and kind pinning, runs the same files unchanged.
Candidate and execution seeds come from `ledgr_derive_seed()`, which cut 4
leaves unchanged.

## Bounds

The threshold map (`thresholds.csv`, cut 4 decision text and LDG-3156):
0.97 for seeded `dense_scale_50x1260` run and sweep, where the cheap pulse
seeds must show a speedup, and 1.03 for every other cell. A gate passes a
cell when the candidate median over the base median is at most its bound.

## Records

- **Base record (LDG-3156).** An A/A window, base against itself on a quiet
  machine, checked with `--aa`. It establishes validity and noise only.
- **Gate record (LDG-3161).** The same protocol, unchanged, with the final
  candidate.

Commands, from the package root, on the normal desktop (power plan and
affinity are enforced; background activity is recorded, not gated):

```powershell
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF; `
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/runner.R `
  --protocol=dev/bench/timing/protocols/ws2-timing-1 --base=<commit> --candidate=<commit> --label=base-aa
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/check.R `
  --protocol=dev/bench/timing/protocols/ws2-timing-1 `
  --record=dev/bench/timing/records/ws2-timing-1/base-aa/attempt-1 --aa
```
