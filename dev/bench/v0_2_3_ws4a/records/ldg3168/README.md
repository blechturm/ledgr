# LDG-3168 candidate record

Product candidate `ba67ae8a` (LDG-3168: typed diagnostics staging, equity
record and stop validation) on `claude/ws4a-carrier`, base `b3611c01`. The
evidence commit that adds this folder also adds the ticket evidence; it
changes no product file. No timing window, memory workload or real-data
workload was run (cut 5 `amendment_performance`; decision (8)).

## Commands and outcomes

All from the worktree `C:/Users/maxth/ledgr-wt/ws4a-impl` with R 4.6.1, run
one at a time; scratch output under
`C:/Users/maxth/AppData/Local/Temp/ws13-3168/gates/`. `R/cpp11.R` and
`src/cpp11.cpp` were restored after each step. `sequence.log` holds the exit
codes.

| Gate | Command | Outcome |
| --- | --- | --- |
| Cases | `Rscript dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=<scratch>/check` | exit 0, 23 cases identical |
| Guts | `Rscript dev/bench/v0_2_3_ws4a/guts.R --base=HEAD --out=<scratch>/guts --guts=<36 guts>` | exit 0; 36 of 36 FAIL (expected), invalid-base control REFUSED (`guts.log`) |
| Dense | `Rscript dev/bench/peer_benchmark/dense/check.R --pkg=<worktree> --out=<scratch>/dense` | exit 0, PASS: nine native arms identical |
| A0 | `record.R --pkg=<worktree> --out=<scratch>/a0`, then `compare.R ... --result=<scratch>/a0/a0.csv` | both exit 0; 295 of 295 PASS (`a0-compare.csv`) |
| Migrations | `Rscript records/ldg3168/migration_probe.R <worktree>` | exit 0; nine controls fail their migrated blocks (`migration-probe.txt`; the first run, before the probe also patched the attached package copies, could not reach the two bare-name LTB-0278 calls) |
| Suite | `Rscript -e "pkgload::load_all(...); testthat::test_local(..., reporter='summary', stop_on_failure=TRUE)"` | exit 0 on ba67ae8a (one existing skip: quantmod missing-package path) |

The 36 guts: this ticket's C16_force_fold_equity, C18_drop_split_tail,
C18_retain_staging and C18_drain_unused_equity, plus the 32 registered for
LDG-3164 to LDG-3167 (`records/ldg3167/guts.log`).

## Moved case attachments and guts

Recorded case bytes are unchanged; only attachments moved:

- C16: both producers now fill the fold equity record, so the fact
  `fold_equity_rows` counts the fold rows finalisation consumes (the rows
  passed to `ledgr_run_fold_equity_frame()` inside `ledgr_run_finalize()`):
  0 on the dense run, as the base's empty accumulator gave. The typed
  precondition `ws4a_typed_c16()` (the dense record has rows, replay used
  once, prefix commit unused) is asserted with `ws_need()`; the record's
  rows are an observation, not compared. Finalisation's fold branch now
  builds its frame with that function (the same frame as before).
- Gut C16_force_fold_equity restores the old decision on the typed record
  (fold equity when the record has rows); it fails C16 at the case's
  replay/prefix precondition.
- Gut C10_skip_valuation_on_empty skips the empty-context pulse's row of
  the fold equity record (`ledgr_fold_equity_append()`) instead of the
  accumulator append; it fails C10's valued-pulse precondition.
- Gut C18_retain_staging keeps one staged row past the drain (the typed
  staging's `n`), C18_drain_unused_equity makes E hand out the record's
  unused rows; both fail C18 (diagnostics differ; the sweep's equity
  collection refuses duplicate pulses). C18_drop_split_tail is unchanged.

## Migrated tests

`migration_probe.R` swaps one carrier function at a time (namespace and
attached copy) and reruns each migrated block: dropping a used equity row
fails LTB-0521, the inline-summary block of `test-sweep.R` and LTB-0278;
exposing an unused row fails LTB-0521; an equity record that grows instead
of refusing fails LTB-0278; a memory handler regaining `record_equity_fact`
fails LTB-0518; P3 returning `diagnostic_segments` again fails LTB-0281; a
drained block missing a column fails the two diagnostic-production blocks.
Each block passes on the product.

Harness lines: 2,224 to 2,299 (+75: cases.R +9, guts.R -4, this probe +70)
under the 2,500-line budget (cut 5 `amendment_budget`).
