# Protocol smoke-1

Status: example and smoke protocol for the shared timing harness (LDG-3155).
**Not timing evidence.** Its records show that the harness runs end to end;
no cut gates on them.

## What it measures

One workload, `small_dense` in `workloads.R`: 10 instruments x 250 sessions
of deterministic prices, a strategy that trades every instrument on every
pulse, a 5 bps spread and opening cash 1e6. One process measures two clocks:

- `cold`: snapshot creation and sealing plus one committed `ledgr_run()`,
  closed;
- `warm`: a second committed run on the same open snapshot, closed.

The two cells, `small_cold` and `small_warm`, run the same workload in
separate processes and record one clock each. Work is the two runs' trade
counts, which must agree across every row of a cell.

## Pairs and bounds

Eight pairs, the harness minimum. The bounds (1.03 for `small_cold`, 0.97
for `small_warm`) are illustrative: they give the checker demonstrations one
cell of each kind. An A/A record of this protocol is checked with `--aa`,
which never gates.

## Commands

```powershell
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF; `
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/runner.R `
  --protocol=dev/bench/timing/protocols/smoke-1 --base=HEAD --candidate=HEAD --label=<name>
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/timing/check.R `
  --protocol=dev/bench/timing/protocols/smoke-1 --record=dev/bench/timing/records/smoke-1/<name>/attempt-1 --aa
```
