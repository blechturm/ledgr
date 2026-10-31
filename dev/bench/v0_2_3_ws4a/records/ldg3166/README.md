# LDG-3166 candidate record

Product candidate `9b13eb3c` (LDG-3166: typed plan batch on both producers)
on `claude/ws4a-carrier`, base `31d21f37`. The evidence commit that adds this
folder also adds design note Section 1.8 and the ticket evidence; it changes
no product file. No timing window, memory workload or real-data workload was
run (cut 5 `amendment_performance`; decision (8): the real-data oracle runs
at LDG-3164 and LDG-3169).

## Commands and outcomes

All from the worktree `C:/Users/maxth/ledgr-wt/ws4a-impl` with R 4.6.1, run
sequentially (each `load_all` rebuilds the DLL); scratch output under
`C:/Users/maxth/AppData/Local/Temp/ws13-3166/gates/`. `R/cpp11.R` and
`src/cpp11.cpp` were restored after each step. `sequence.log` holds the exit
codes.

| Gate | Command | Outcome |
| --- | --- | --- |
| Cases | `Rscript dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=<scratch>/check` | exit 0, 23 cases identical |
| Guts | `Rscript dev/bench/v0_2_3_ws4a/guts.R --base=HEAD --out=<scratch>/guts --guts=<26 guts>` | exit 0; 26 of 26 FAIL (expected), invalid-base control REFUSED |
| Dense | `Rscript dev/bench/peer_benchmark/dense/check.R --pkg=<worktree> --out=<scratch>/dense` | exit 0, PASS: nine native arms identical |
| A0 | `record.R --pkg=<worktree> --out=<scratch>/a0`, then `compare.R ... --result=<scratch>/a0/a0.csv` | both exit 0; 295 of 295 PASS (`a0-compare.csv`) |
| Suite | `Rscript -e "pkgload::load_all(...); testthat::test_local(..., reporter='summary', stop_on_failure=TRUE)"` | exit 0 (one skip: quantmod missing-package path) |

The 26 guts: this ticket's C1_drop_notional (M10), C2_notional_from_rounded
(M9), C7_plan_on_skip, C8a_suppress_stop, C8b_suppress_exception,
C11_affordability_order (M4), plus M2_reorder_pulse_fills (moved here); the
LDG-3165 guts C7_strategy_on_skip, C10, C12, C14b, C15, C17; and the 13
LDG-3164 guts.

## Moved guts and case attachments

Moved to the typed plan, with recorded case bytes unchanged:

- case hooks: C4's planned/actual table reads `plan$batch$fill`
  (`planned_position_after`, actual positions at `pos`); C8a/C8b's
  perturbation reads the typed plan (`value$batch`, `plan$fill$k`); C11's
  fill order reads the planner's fill rows;
- guts: C1/C2 patch the batch cost resolver `(side, qty, open, steps)`; C11
  (M4) and M2 reorder typed fill rows through `ws_fill_rows()`.

First differences under the moved guts: C1 and M2 change the ledger, fills,
trades and equity on both producers; C2 the ledger and fills; C11, C8a and
C8b fail their preconditions with the same first difference as their base
record in `gut_results.csv` (fill order no longer ZZZ, AAA; no INCOMPLETE
stop; no P5 abort).

## Detector record

`records/detectors/frozen.csv` gains row `D13b`: the D13 digest of the three
dense builders without `ledgr_fold_build_pulse_plan` (design note Section 6,
D13), computed on base `953338df`; the base four-builder digest reproduced
the frozen `D13` value with the same method. Historical rows are unchanged.

Harness lines: 2,008 to 2,022 (+14) under the 2,500-line budget
(cut 5 `amendment_budget`).
