# Lean Core Deletion Readiness: Addendum 1

- Author: Claude, 2026-11-28, at the maintainer's request.
- Status: **draft**, for the maintainer's acceptance before Cut 28.
  Extends the accepted
  [seed v2](rfc_lean_core_deletion_readiness_v0_2_3_seed_v2.md); changes none
  of its classifications.
- Why: the two holistic reviews after Cut 27
  ([A](../ledgr_v0_2_3_spec_packet/holistic_review_codex.md) H7,
  [B](../ledgr_v0_2_3_spec_packet/holistic_review_claude.md) H1 and H3)
  found eight rules that are implemented twice and that seed v2 does not
  classify. Seed v2 rule 4 (Section 5) and macro plan switch obligation 3
  make each of them a switch blocker until it is classified. Seven are lean
  fast paths added in Cuts 14 to 21, after the seed. The eighth is the lot
  kernel.
- Evidence: release/v0.2.3 at `15e9b785`; the pin `7f65733f`. Callers below
  were read in R/ and dev/lean_core/, not only grepped. "After the switch"
  means the old fold (R/fold-engine.R) and the lean debug comparators that
  compare against it are gone.

## 1. The eight rules

The classes are seed v2's (Section 2): Retain, Merge, Replace, Delete.

| # | Lean | Package | Package callers after the switch | Refusals | Class |
| --- | --- | --- | --- | --- | --- |
| 1 | `lean_ctx_dollar` (loop.R) | `$.ledgr_pulse_context` (R/pulse-context.R) | every `ctx$name` read: strategies, pulse inspection, tests | the retired-field and unknown-field refusals (`ledgr_unknown_context_field`) | **Merge** |
| 2 | `lean_strategy_view` (loop.R) | `ledgr_strategy_state_view()` (R/strategy-state.R) | `ledgr_pulse_context()`'s default; the fold's return boundary | none (its `$` and `[[` methods own the read refusals) | **Merge** |
| 3 | `hold()` in `lean_ctx_helpers` (loop.R) | `ledgr_pulse_context_current_targets()` (R/pulse-context.R) | the package context's `hold()` | the numeric, finite and alignment refusals on `positions` (`ledgr_invalid_pulse_context`) | **Merge** |
| 4 | `lean_context` (loop.R) | `ledgr_update_pulse_context_helpers()` and `ledgr_filter_pulse_context_features()` | `ledgr_pulse_context()` only, which only tests call; the filter has none | `ledgr_validate_pulse_context()` in the constructor | **Replace** |
| 5 | `lean_gross` (loop.R) | `ledgr_availability_marked_gross()` (R/availability-economics.R) | none | none (returns NA) | **Replace** |
| 6 | `lean_plan_affordability` (plan.R) | `ledgr_plan_affordability()` | none (its caller, the old planner, goes) | none | **Replace** |
| 7 | `lean_plan_execution_view` (plan.R) | `ledgr_carrier_execution_view()` (R/fold-carrier.R) | its direct test (row R146) | key order (`ledgr_internal_error`; debug-only by the interface's P3 placement); the reason dictionary (`ledgr_invalid_pulse_plan`, production) | **Merge** |
| 8 | the fifo.R kernel (`lean_lot_apply` and its operations) | `ledgr_lot_apply()` and its operations (R/lot-accounting.R) | opening import (`ledgr_lot_book_from_opening`), replay (R/accounting-replay.R), terminal dispositions (`ledgr_disposition_post`, called from the lean fold) | the lot-state and lot-input refusals | **Merge**, timing in Section 3 |

### Why each class

1. **Merge.** The method is the public read surface and stays. Today the
   lean fast path reaches production only because the harness installs it
   over the method (loop_harness.R, `"$.ledgr_pulse_context" =
   lean_ctx_dollar`). The harness retires at the switch, so without a merge
   the fast path silently disappears. The fast path becomes the method's
   first branch. The method's refusals stay where they are, unchanged; the
   lean code already forwards every case it does not accept. The
   `lean_pin_ctx_dollar` alias goes.
2. **Merge.** Its first branch shares a plain named list under the class
   instead of copying every field. The fold's return boundary then also
   stops copying (review A, H7). The plain-state predicate is not widened.
3. **Merge.** The aligned finite-positions fast path becomes the first
   branch of `ledgr_pulse_context_current_targets()`. The refusals move
   nowhere; every other input still reaches them.
4. **Replace.** After the switch the package builder has no production
   caller: the fold builds its context with `lean_context`, and pulse
   inspection captures the fold's context. `ledgr_pulse_context()`, which
   five test files call to build contexts by hand, is rebuilt on the same
   builder, so those tests test the context the fold builds and not a
   second one. Its signature and its `ledgr_validate_pulse_context()` call
   stay. `ledgr_filter_pulse_context_features()` and the debug comparator
   `lean_loop_pin_ctx` are deleted.
5. **Replace.** The lean body (a zero quantity contributes exactly 0,
   without `ifelse()`) becomes `ledgr_availability_marked_gross()`'s body,
   under the package name, and `lean_gross` and its debug comparator go.
6. **Replace.** As 5, under `ledgr_plan_affordability()`. The lean version
   already keeps the package's formula when a generator flag is NA.
7. **Merge.** The function has a direct test that owns its refusals
   (test-ws4a-carrier.R, row R146), so it keeps its name and file. The lean
   body becomes its body: the key-order check runs in debug only, as the
   interface's P3 validation placement already states ("Execution view:
   key and group checks debug-only; dictionary refusal kept"), and the
   dictionary refusal moves verbatim. Row R146 is unchanged. Row R150's
   census entry names `ledgr_carrier_execution_view` again, not
   `lean_plan_execution_view`.
8. **Merge.** One kernel, in R/lot-accounting.R under the package names the
   three callers use, with the fifo.R body. `ledgr_lot_apply`'s old body,
   its dust helpers and `lean_fill_leg_fees` (parity scripts only) go.
   `ledgr_lot_input` stays only as the debug branch of the merged input
   boundary. About 320 lines go (review B, H1).

### Proof

Seed v2 Section 2's proof per class applies:
- Merge: the existing witnesses and the recorded pin outcomes, in both debug
  modes. A refusal no witness exercises is checked by a diff that shows the
  moved code unchanged (seed v2 rule 3).
- Replace: public parity on the gate corpus. Rules 4 to 6 have no refusals.
  Rule 4's constructor refusal stays in `ledgr_pulse_context()` unchanged.
- Rule 8 additionally needs the FIFO parity check (`fifo_check.R`, the
  LDG-3214 gate) extended to the opening-import and terminal-disposition
  streams. It already compares the two kernels bit for bit on captured fold
  and replay streams.

## 2. Correction to seed v2 Section 6

Section 6 says the FIFO, the planner and valuation have no runtime fallback.
That is true of the fold. It is not true of the package: the package lot
kernel keeps three production callers after the switch (rule 8 above).

## 3. Open: when the kernel merge lands

On 2026-11-28 the maintainer agreed to keep the switch as Cut 27 decision
(7) set it, and to merge the kernels in their own cut after the switch.
Writing this addendum shows a conflict with that routing:
- After Cut 28, a fill runs the fifo.R kernel, while a terminal disposition
  in the same pulse, opening import and replay run `ledgr_lot_apply()`.
- contracts.md, contract-execution-fold-carrier, says: "One typed lot
  implementation serves every consumer: the fold, replay, ... opening
  initialisation, ... terminal dispositions and recovery".
- Macro plan rule 6 says every cut is release-ready.

So, with the merge after the switch, Cut 28 would leave the release branch
in breach of a contract sentence until the kernel cut lands. Decision (7)
decided who owns the D7 test, not that the product may run two kernels.

The choices:
- **(a) Kernel cut after the switch, with a recorded exception.** Cut 28
  records the breach as a known, temporary exception in its release-impact
  record: the release branch is not released until the kernel cut lands,
  and the kernel cut is the next cut. Cut 28 stays smaller. For one cut the
  branch is not release-ready.
- **(b) Merge in Cut 28.** The switch moves the three callers onto the
  fifo.R kernel and deletes the old one. Cut 28 grows by about 320 deleted
  lines and the extended FIFO check. Every cut stays release-ready.

Claude now recommends (b). The merge is mostly routing: fifo.R already has
`lean_lot_opening`, `lean_lot_disposition` and `lean_lot_apply_blocks` for
these callers, and its parity proof already exists. (a) would need an
exception to a macro rule for one cut's convenience.

## 4. Not in this addendum

The holistic reviews' other findings are routed by the maintainer's
2026-11-28 decision, to Cut 28 or to the subtraction cut after it, and are
not classifications.
