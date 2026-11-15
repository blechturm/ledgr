# Slice-3 probe (slice-3 cut input, 2026-11-15)

A probe, not product code. The question: what does the lean loop need to
reproduce the pin for slice 3, and how big is it? Nothing in `dev/lean_core/`
was changed by it. The slice-3 cut rebuilds the work properly. The method
is Cut 16's slice-2 probe (`dev/spikes/slice2_probe/`).

Slice 3 (macro plan WS16 compact-state point 2, plus Cut 16's deferrals):
- schedules;
- declared sessions;
- stale and frozen marks and the valuation policies;
- missing bars and closes;
- the stale-mark risk rows and the unavailable-risk-mark stop;
- the sizing skip;
- history reads in the strategy.

`probe.patch` is the final diff against `a0ca20e2`:
- `dev/lean_core/loop.R`, +235/-38 lines, every change marked "slice-3
  probe";
- 16 slice-3 workloads (`s3_`) appended to
  `parity/loop_workloads_slice2.R`.

`probe_step2.patch` is the stage with only the refusals lifted.

Reproduce: create a worktree at `a0ca20e2`, `git apply probe.patch`, then
run `loop_parity.R --lib=<pin library d5b3a151> --debug=0|1
--workloads=... --out=...`.

## Steps and results

| Step | Files | Result |
| --- | --- | --- |
| 1. Pin only | `pin_branches.R` | Missing bars need an availability-aware run. A valuation policy needs a declared session calendar. So stale marks exist only with declared sessions, and slice 3's features are one block. |
| 2. Refusals lifted one at a time, debug on | `a_baseline` .. `f_sched_debug1` | Declared sessions with complete bars: identical after three coverage-line changes. The lean preparation already builds the session axis; the loop already reads the declared execution times. The membership check wrongly counted the session calendar as a fact family. Missing bars: debug stops at the first one ("Lean packet field `mark` differs"). Schedules: the lean loop decides every pulse (`momentum_40x504`: 20,160 decisions against the pin's 1,401). |
| 3. Missing bars and marks | `g_marks_debug1` .. `j_s3_debug0` | 11 workloads identical in both debug modes (170 tables). |
| 4. Schedules and history reads | `k_sched_debug1` .. `n_hist_debug*` | Schedules: identical once the loop has a skip pulse. History reads: identical with only the refusal lifted; the lean context already carries the pin's history view. |
| Final patch, slice-3 set | `o_all_debug0`, `o_all_debug1` | 16 `s3_` workloads plus `momentum_40x504`: 266 tables identical in each mode. |
| 5. Full gate, against `loop_freeze.csv` | `p_gate_debug0`, `p_gate_debug1` | 90 workloads, 1,561 tables, 0 different in each mode. 59 PASS, 31 PATH, all expected (below). |

The 31 PATH verdicts in step 5:
- 16 new `s3_` workloads, which have no freeze row.
- 8 backstop witnesses, which now run lean because history reads are
  covered.
- `momentum_40x504`, which now runs lean.
- 6 workloads that used to stop at "declared sessions" and now stop at
  their next uncovered feature: opening positions, corporate actions, sweep
  workers or walk-forward (slices 4-5). `avail_incomplete` and `failures`
  now run four of their folds lean.

No table differs, and no workload is refused that was not refused before.

## What the probe does (and the cut must do properly)

- **Coverage.**
  - Lift the declared-sessions, schedules, declared execution
    opportunities, missing-bar, missing-close and history-read refusals.
  - Narrow the membership refusal to families other than `sessions`.
- **P1 marks.** In the probe, a run with any missing bar takes its marks
  from the pin's valuation state and provider view each pulse. The probe
  uses this as a stand-in, as Cut 16's probe called the pin's risk plan.
  The pin's rule itself is small and vectorised (last observed close, its
  age in sessions, permissible within `max_sessions`, frozen when held
  under `exhausted = "freeze"`). The cut decides whether the lean loop owns
  it.
- **Valuation.**
  - Positions are valued at the marks.
  - `valuation_horizon_exhausted` stops the run when a holding has no
    usable mark. The stop happens before the equity row, does not count
    the pulse, and records its affected exposure in the completion row.
  - `valuation_frozen` and `valuation_freeze_exited` rows track the frozen
    set across pulses.
- **P2.**
  - The pin's view, with `risk_mark` set to the mark.
  - Marks for sizing evidence and the max-weight price.
  - `ledgr_availability_validate_strategy_targets()` runs in production:
    a frozen holding is hold-or-exit restricted.
  - `risk_mark_unavailable` stops the run on a new or larger long position
    at an unusable mark. The stop counts the pulse; the whole decision
    segment is explicit with no post-risk target.
  - `stale_mark_reduction` and `stale_mark_pass_through` risk rows.
  - Per-cell decision fields: price, mark source and age, restriction
    reasons, `sizing_unavailable`.
- **Scheduled skip pulse.** No strategy call. One `scheduled_skip` row,
  then `marked` evidence rows for holdings at a stale or frozen close, then
  a reconciliation row with targets equal to positions. No decision cells
  and no holds.
- **Records.**
  - The clean-row rule: a decision cell or fill is implicit only on a
    current-close mark with age 0, the plain reason and no risk row
    (`ledgr_diagnostic_clean_hold`, `_fill`).
  - Reconciliation gross is taken at the marks.
  - The pulse layout is: valuation (and skip) rows, intent, sizing,
    decision cells, risk rows, rejections, fills, reconciliation, stop
    rows.
  - The pin defaults a segment's `reasons` to its reason code.

## Workloads the cut must include

These are the 16 `s3_` workloads, plus the cases the probe review added.
The review's script, `review/review_probe.R`, shows all of them identical
on this patch in both debug modes. What each `s3_` workload reaches on the
pin (review P8):
- `s3_stop_freeze` completes DONE with frozen holdings; it reaches no stop.
- `s3_reduce_on_stale` reaches only pass-through risk rows. The cap
  reduction is in `s3_stale_reduction` (200 to 66.0).
- `s3_stop_refuse` reaches `valuation_horizon_exhausted`.
- `s3_risk_mark_stop` reaches `risk_mark_unavailable` with an expired
  reference.
- `s3_freeze_exit` reaches `valuation_freeze_exited`.

Added by the probe review (`review/slice3_probe_review.md`, P1-P7):
1. Increasing a frozen holding (`ledgr_restricted_target`), and
   liquidating one: `execution_bar_missing`, then a sale when bars return.
2. A valuation stop on a scheduled-skip pulse, including one on the first
   missing session.
3. `max_pulses` prefixes on declared sessions and on schedules
   (`full_run = FALSE`, no completion row). A session with no bars at all.
   Closed sessions: marks age by session, not by calendar day.
4. Sizing helpers at stale and frozen marks: `sizing_liquidation` with no
   price, then `execution_bar_missing`.
5. History reads of features: the matrix and the long frame.
6. Schedule queries inside the strategy. A schedule with no decision pulse
   (`ledgr_schedule_no_decision`). A sweep whose candidates resolve
   different schedules: one completes, one fails.
7. A buy into an instrument that has never had a bar (`missing` source, no
   age).

## Notes for the cut

- **Correction to the accepted deletion-readiness seed v2.**
  `ledgr_availability_validate_strategy_targets()` becomes a production
  call in slice 3, not slice 4, because frozen holdings are restricted.
  Its class (retain) is unchanged.
- **Probe shortcuts the cut must replace:**
  - the trigger (any missing bar anywhere in the prepared planes);
  - the assertion that the context axis equals the run axis (true for a
    fixed basket, `R/availability-provider-prepared.R:472`);
  - per-pulse lists for the new rows;
  - per-cell decision fields kept as one vector per pulse.
- **Size.**
  - Declared sessions and history reads are nearly free.
  - Marks and their records are the bulk.
  - Schedules are small.
  - The probe leans on the pin for the mark rule, so the cut's lean code
    will be somewhat larger than the probe's +235 lines.
  - A natural split is 3a (sessions, missing bars and marks) and 3b
    (schedules and history reads).
- **Debug.** The fixed-basket packet check (`lean_loop_debug_packet`) is
  skipped on marked runs in the probe. The context check runs against the
  pin's view.
