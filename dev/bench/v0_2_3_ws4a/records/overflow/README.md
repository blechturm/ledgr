# Overflow refusal record (cut 5 amendment_overflow)

Product commit `9b05538f` ("Overflow refusal: refuse a fill whose lot
accounting overflows as invalid fill input") on `claude/ws4a-carrier`,
parent `6c39c045`. The evidence commit that adds this folder changes no
product file. No timing, memory or real-data run (cut 5
`amendment_performance`).

## Change

`ledgr_lot_apply()` (`R/lot-accounting.R`) computes a fill's appended
basis, positions, dust rules and event-order totals before its refusal
selection; slots are still written after it. A fill row whose closing
results (realized P&L, realized after fee, closing basis change, position)
or opened basis, position or totals (cost basis, realized, compensation)
are non-finite refuses with `ledgr_invalid_lot_fill`, "Invalid fill input
for lot accounting.". The earliest failing row refuses; within a row a
closing overflow precedes the through check and an opened or total
overflow follows it. A book that fails V-book (`reduction = FALSE`) keeps
the applied-row `ledgr_lot_state_invariant`. Openings and dispositions are
unchanged.

## Commands and outcomes

From the worktree `C:/Users/maxth/ledgr-wt/ws4a-impl`, R 4.6.1, one job at
a time, scratch `C:/Users/maxth/AppData/Local/Temp/ws13-overflow/gates/`;
`R/cpp11.R` and `src/cpp11.cpp` restored after each step.

| Gate | Command | Outcome |
| --- | --- | --- |
| Cases | `check.R --base=HEAD --out=<scratch>/check` | exit 0, 23 cases identical |
| Guts | `guts.R --base=HEAD --out=<scratch>/guts --guts=<36 guts of records/ldg3168>` | exit 0; 36 of 36 FAIL (expected), invalid-base control REFUSED (`guts.log`) |
| Dense | `peer_benchmark/dense/check.R --pkg=<worktree> --out=<scratch>/dense` | exit 0, PASS: nine native arms identical |
| A0 | `cut3_successors/a0/record.R`, then `compare.R --successor=<scratch>/a0` | both exit 0; 295 of 295 PASS (`a0-compare.csv`) |
| Probe | `Rscript records/ldg3167/probe_multi.R candidate <scratch>/probe-candidate.rds` | exit 0 (`probe-candidate.txt`) |
| Suite | `testthat::test_local(..., stop_on_failure = TRUE)` | exit 0 (one existing skip: quantmod missing-package path) |

## Probe outcomes against the base (`records/ldg3167/probe-base-953338df.txt`)

Ten of the 16 outcomes match the base: `pub1_lot2` run, `pub1_lot2_live`
run (fill 1's earlier publication refusal, `ledgr_config_non_finite`),
`pub_only` run and sweep, and both outcomes of `ok1_fee2`, `nan1_nan2` and
`nan1_pub2` (`ledgr_invalid_lot_fill` from the fee input).

Six differ by the accepted decision, each now `ledgr_invalid_lot_fill`
(workstream 12 raised `ledgr_lot_state_invariant` in all six):

| Scenario | Base |
| --- | --- |
| `pub1_lot2` sweep | completed |
| `pub1_lot2_live` sweep | completed |
| `lot1_pub2` run | `ledgr_config_non_finite` at metadata encoding |
| `lot1_pub2` sweep | completed |
| `lot_only` run | `ledgr_config_non_finite` at metadata encoding |
| `lot_only` sweep | completed |

`[WS4a overflow refusal]` adds the availability side: buying 1e308 at 10
is rejected by affordability first, and the run and sweep keep the base's
`ledgr_config_non_finite`; selling a 1e308 long held at basis -1 for 1.5
overflows the realized P&L with a finite cash effect, which the base
completed as a durable run and a sweep (fill `realized_pnl` Inf) on both
producers, and is now refused on both.
