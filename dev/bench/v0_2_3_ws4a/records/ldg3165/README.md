# LDG-3165 candidate record

Product candidate `33331be8` (LDG-3165: typed observation and decision) on
`claude/ws4a-carrier`, base `975c8add`. The evidence commit that adds this
folder also strengthens the `[WS4a D5 D21]` test (a leaked next-bar column
under any name) and adds design note Section 1.7; it changes no product
file. No timing window, memory workload or real-data workload was run
(cut 5 `amendment_performance`; decision (8): the real-data oracle runs at
LDG-3164 and LDG-3169).

## Commands and outcomes

All from the worktree `C:/Users/maxth/ledgr-wt/ws4a-impl` with R 4.6.1;
scratch output under `C:/Users/maxth/AppData/Local/Temp/ws13-3165/`.
`R/cpp11.R` and `src/cpp11.cpp` were restored after each `load_all`.

| Gate | Command | Outcome |
| --- | --- | --- |
| Cases | `Rscript dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=<scratch>/check` | exit 0, 23 cases identical |
| Guts | `Rscript dev/bench/v0_2_3_ws4a/guts.R --base=HEAD --out=<scratch>/guts --guts=C7_plan_on_skip,C7_strategy_on_skip,C10_skip_valuation_on_empty,C12_fill_before_settlement,C14b_write_retained_view,C15_wrong_context_pos,C17_drop_continuation,C3_tolerance_x10,C4_lifo,C5a_reorder_carried_openings,C5b_kahan_on_openings,C6_leave_one_live_lot,C9_drop_comp_in_unpack,C14a_book_by_reference,M3_drop_lot_fee,M5_positions_plus_delta,M7_drop_partial_remainder,M11_uncompensated_totals,M11_cumsum_total_basis,C14a_rename_by_reference` | exit 0; all 20 FAIL (expected), invalid-base control REFUSED |
| Dense | `Rscript dev/bench/peer_benchmark/dense/check.R --pkg=<worktree> --out=<scratch>/dense` | exit 0, PASS: nine native arms identical |
| A0 | `record.R --pkg=<worktree> --out=<scratch>/a0`, then `compare.R ... --result=<scratch>/a0/a0.csv` | both exit 0; 295 of 295 PASS (`a0-compare.csv` here) |
| Suite | `Rscript -e "pkgload::load_all(...); testthat::test_local(..., reporter='summary', stop_on_failure=TRUE)"` | exit 0 (one skip: quantmod missing-package path); the run read the strengthened ws4a-carrier test file |

## Moved guts and case attachments

The three guts and two case hooks that read the base observation move to the
typed attachment (`lib.R` `ws_context`; `guts.R` `ws_skip_gut`,
`C15_wrong_context_pos`); recorded case bytes are unchanged. Under the moved
guts the first differences are the frozen facts and outputs, not an
attachment error: `C7_plan_on_skip` planner calls 4 to 8;
`C7_strategy_on_skip` strategy calls 4 to 8 and extra decision rows; M8
(`C15_wrong_context_pos`, the reversed packet bridge) the context-axis table,
equity and fills.

Harness lines: 1,995 to 2,008 (+13) under the 2,500-line budget
(cut 5 `amendment_budget`, 2026-10-31).
