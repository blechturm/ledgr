# Cut 9 Scoring-Boundary Oracle

Owned by LDG-2968. It records the public-path mismatch that Cut 9 repairs and
gives LDG-2969 and LDG-2971 a failure-sensitive target. It is correctness
evidence, not a benchmark.

## Fixture

Ten daily bars for `AAA`, where day `d` has open and close `d`. SMA(3), zero
cost, 1000 initial cash, next-open fills. The strategy targets one share once
`sma_3` is finite and records every value it saw. The opening or scoring start
is day 6. The walk-forward fold trains on days 6-8 and tests on days 9-10.

| Arm | Entry point | Boundary |
| --- | --- | --- |
| `run` | `ledgr_run()` with `ledgr_opening(date = day 6)` | public |
| `backtest` | `ledgr_backtest(start = day 6)` | public |
| `sweep` | `ledgr_sweep()` of the dated experiment, retained returns | public |
| `promote` | `ledgr_promote()` of that sweep candidate | public |
| `run_window`, `sweep_window` | `ledgr_run_window()`, `ledgr_sweep_window()` over days 6-10 | internal |
| `walk_forward`, `walk_forward_test` | `ledgr_walk_forward()` fold rows, score rows and durable test run | public |
| `execution_start` | `ledgr_experiment_window(execution_start_utc = day 7)` | internal |

Strategy state is decoded read-only from the persisted store, because ledgr
exports no strategy-state result kind. The internal window helpers isolate
the defect; they carry no product claim.

## Groups

`check_record.R` assigns every assertion to one group:

- `boundary`: no arm evaluates, fills, writes equity, emits a ledger event or
  contributes metric input before its scoring start, and a distinct execution
  start refuses. Sweeps are checked through what they expose: `scoring_range`,
  retained-return timestamps and count, a final-equity bound implied by the
  earliest permitted fill, and a time in market that is a whole number of
  scoring pulses.
- `value`: exact cross-path values. These also depend on where feature state
  starts, so they stay red until Workstream 19 (LDG-2971).

Expected values come from fixture arithmetic, never from another engine path.

| Tree | boundary | value |
| --- | --- | --- |
| pre-cut `1cd9e52` | fail | fail |
| after LDG-2969 | pass | fail |
| after LDG-2971 | pass | pass |

`--self-test=<pre_cut_dir>` splices each recorded pre-cut arm (ordinary sweep,
window sweep, walk-forward training) into a boundary-correct base and requires
the boundary group to fail on that arm alone. The base is the record under test
when its boundary group passes, and otherwise a fixture-derived reference.

## Commands

From the repository root, on a clean tracked tree:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/bench/v0_2_2_scoring_boundary/run_record.R . C:/tmp/ledgr-cut9-record

& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/bench/v0_2_2_scoring_boundary/check_record.R C:/tmp/ledgr-cut9-record `
  --expect=boundary:pass,value:fail `
  --self-test=dev/bench/v0_2_2_scoring_boundary/evidence/pre_cut
```

Checked-in records live under `evidence/<stage>/`.
