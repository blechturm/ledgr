# Lean Core Deletion Readiness: Seed v2

- Author: Claude, 2026-11-15, at the maintainer's request.
- Status: seed v2. Proposes classifications; implements nothing.
- Changes from v1: corrects every finding of the Type 1 review
  ([review](rfc_lean_core_deletion_readiness_v0_2_3_review.md), on v1 at
  `f9de1bb0`: CHANGES_REQUIRED, N1-N8, all accepted).
  - N1: the parameter-reference branch is reachable from public input, and
    the lean core refuses it differently from the pin. This reopens Q3.
  - N2: five target and state helpers were missing.
  - N3: a risk refusal was missing.
  - N4: the class of the post-risk quantity refusal was wrong.
  - N5: two uncovered-feature dependencies were missing.
  - N6: the cost input refusals test types as well as lengths.
  - N7: a proof was named that does not exercise its refusal.
  - N8: a resolver refusal was missing.
- Required by: macro plan, "Switch obligations from lean-owned
  replacements", item 1 (revision 16); `lean_core_interface.md` Section
  19.10, the fallback inventory.
- Evidence: release/v0.2.3 at `d882ce02`. Cut 18 closed at `bdeea449`, with
  the lean sources of its final code `7474044b`. The end-to-end profile is
  `053316af` plus `d882ce02`. Pin: `d5b3a151`.
- Not decided here: the switch cut itself, and porting the features the lean
  core does not cover yet.

## 1. The question

Cut 18 put lean fast paths in front of fold-only package functions. Each
package function stays as two things:

- the fallback, for every input outside the fast path and for every refusal
  and error;
- the differential oracle, compared on every pulse with debug on.

The maintainer's target after the switch is one authoritative implementation
per semantic rule, with optimised common paths and complete fallback
behaviour. This seed sorts every package function in Section 19.10, and the
helpers those functions depend on, into one of four classes. It also says
what proof each move needs, and which of the features the lean core does not
cover yet still depend on each function.

## 2. The four classes

- **Retain.** The function stays as an independent semantic owner. It has
  callers beyond the fold, or it owns a contracted refusal. The lean code
  calls it, with no copy of its rule. Proof needed: none beyond its
  existing tests.
- **Merge.** The fast path and the fallback become one function, in the
  package file that owns the rule today. The fast path becomes its first
  branch. The fallback's refusal code moves over verbatim (same class,
  message, payload and precedence) and is not rewritten. Proof needed: the
  Cut 18 witness cases of that check, against recorded pin outcomes (Q1),
  in both debug modes. Where no witness case exercises a refusal, the proof
  is the verbatim move itself, checked by diff (Section 5, rule 3).
- **Replace.** The lean function becomes the whole rule, with new code for
  its refusals, and the package function is deleted. Proof needed: a full
  witness set for every refusal, plus public parity.
- **Delete.** Nothing needs the code: it is an unreachable branch, a
  duplicate test of something setup already guarantees, or an identification
  trick that a merge makes unnecessary. Proof needed: a probe or a short
  argument that no public entry reaches it.

Result: nothing needs Replace. Every lean fast path either merges into the
package function it shadows, or calls a retained owner. Merge is cheaper to
prove than Replace because the refusal code is moved, not re-authored.

## 3. Findings that shape the answer

**F1. Two fallback branches are dead code; the third hides a defect that
public input reaches.** Only `ledgr_run()` (`R/backtest-runner.R:794`) and
`ledgr_sweep()` (`R/sweep.R:1723`) build an execution spec. Walk-forward and
promotion go through them. Both build the cost resolver with
`ledgr_cost_resolver_from_plan_json()`, and
`ledgr_risk_validate_compiled_step()` admits only `long_only` and
`max_weight`.

- **Dead code: the risk plan's "other step type" branch and the cost
  resolver's "not the package's resolver" branch (with its non-numeric step
  argument test).**
  - Setup validation and resolver construction exclude both; the review
    confirmed this.
  - Cut 18 sent every input outside the fast path to the pin without asking
    whether that input could arrive.
  - The pin's own `ledgr_apply_risk_step()` default and
    `ledgr_plan_resolve()`'s output-shape check are the same kind of
    defensive code.
- **A validation defect: the parameter-reference branch.**
  - The defect: `ledgr_risk_compile_arg()` resolves `ledgr_param("w")` from
    the strategy params, then validates the resolved value with
    `ledgr_risk_validate_max_weight()` (`R/risk-model.R:374-376`). That
    validator lets a reference through (`:118-120`) because the uncompiled
    chain needs that.
  - So a parameter value that is itself a reference passes compilation and
    reaches the fold. Example: `ledgr_run(exp, params = list(w =
    ledgr_param("other")))`, or the same value in a sweep grid.
  - The review's probe reaches the fold this way through both public
    entries.
  - Outcomes (probes, both entries):
    - pin: `ledgr_invalid_post_risk_targets` (parent
      `ledgr_invalid_strategy_result`), saying the targets must be finite.
      It blames the targets, not the risk parameter.
    - lean core, debug off and on: an unclassed base R error, "missing value
      where TRUE/FALSE needed", from
      `ledgr_availability_validate_post_risk()`.
  - Why the lean core differs: its pin path (`lean_risk_pin()`) skips the
    post-risk quantity check, which pulse plumbing LR-16 moved to debug, and
    that check is what catches the missing targets on the pin.
  - Why debug does not catch it: the debug comparison runs `lean_risk_pin()`
    on both sides, so it compares the same error with itself. No Cut 18
    witness case uses this input.
  - No public run reaches the lean core today, because nothing in `R/` calls
    it. This is a refusal difference to fix before the switch (Q3), not a
    wrong result any user can get now.

**F2. After the switch the in-loop oracle has nothing in-tree to compare
with.** Today `lean_debug_same()` compares each lean result with the pin's
function in the same session. Once a check is merged, the package holds only
one version, so the in-loop comparison would compare the code with itself.
The witness harness (`dev/lean_core/parity/cut18_witness.R`) already runs
each case against the pinned library, so the oracle can move there. The pin
outcomes are recorded once per case (value, or the condition's class,
message, payload and parent). After the switch the harness checks the
package against those recordings (Q1, decided).

**F3. The features the lean core does not cover yet** (`lean_loop_coverage()`)
use these fallbacks in production once they are ported. The groups overlap:
a missing bar can also mean a missing close and a stale mark.

- membership, status and lifetime facts, and execution restrictions:
  - `ledgr_availability_validate_strategy_targets()` stops being debug-only.
  - A membership universe can leave the decision axis empty while the
    strategy is still called (`contracts.md`, the empty public domain). A
    zero-length `ledgr_target` on that axis takes the target fallback
    (`lean_targets()`, witness case `helper_empty_axis`).
- stale marks: the risk price becomes the availability risk mark, not the
  decision close (`ledgr_risk_context_prices()`).
- missing bars and missing closes: the prepared close matrix holds NA, and
  the helpers emit `sizing_unavailable` rows for unpriced members, which take
  the sizing fallback.

The other uncovered features (compiled FIFO, checkpoints, restart, schedules,
declared sessions, corporate actions, opening positions, declared execution
opportunities, history calls in the strategy, walk-forward) use none of the
Section 19.10 functions.

## 4. Inventory, by semantic owner

Each block lists:

- the package function and its callers after the switch (the old fold's
  calls are gone);
- its refusal and error paths;
- the proposed class and the proof that class needs;
- which uncovered features depend on it.

Witness counts are the rows per replacement in `cut18_witness_cases.csv`.

### 4.1 Strategy targets (P2 boundary)

| Function | Callers after the switch | Refusal and error paths | Class | Proof | Uncovered features |
| --- | --- | --- | --- | --- | --- |
| `ledgr_validate_strategy_targets()` | lean boundary; `ledgr_signal_strategy()` (3 calls); `ledgr_strategy_echo()` | `ledgr_invalid_strategy_result`: universe shape, intermediate signal, not numeric, names, non-finite, missing or extra instruments | **Merge**: `lean_targets()`'s two accept paths become the function's first branch. The run-constant universe predicate (`lean_targets_axis_ok()`) is passed in as an optional argument; other callers keep computing it. | R3 witnesses (21) and the signal-strategy tests | membership: the empty axis (F3) |
| `ledgr_unwrap_strategy_target()` | the target validator only | routes the intermediate refusal; unclasses a helper target | **Merge** into the target validator (it is that rule's normalisation step) | R3 witnesses | membership: the empty axis |
| `ledgr_strategy_intermediate_classes()` | `ledgr_is_strategy_intermediate()`, `ledgr_abort_intermediate_strategy_result()` | none; supplies the refused class name | **Retain** (owner of the intermediate set) | none | none |
| `ledgr_is_strategy_intermediate()`, `ledgr_abort_intermediate_strategy_result()`, `ledgr_strategy_targets_contract()` | lean boundary; strategy contracts; `R/risk-model.R` | the intermediate-signal refusal; the contract message text | **Retain** | none | none |

These are also called at the boundary directly, with no fast path, so they
are not duplicates: `ledgr_validate_strategy_intent_reason()`,
`ledgr_abort_strategy_error()`, `ledgr_strategy_state_defaults()` (reset).
All three are **Retain**.

### 4.2 Sizing evidence (P2)

| Function | Callers after the switch | Refusal and error paths | Class | Proof | Uncovered features |
| --- | --- | --- | --- | --- | --- |
| `ledgr_validate_sizing_evidence()` | lean boundary only | `ledgr_invalid_strategy_result`: shape, rows, instrument outside the axis, column types, reason codes, typed values. It also handles `sizing_unavailable` rows and stale evidence (returns NULL). | **Merge**: `lean_sizing_evidence()` becomes the first branch in `R/sizing-evidence.R`; the vapply path stays for the cold inputs | R4 witnesses (31) | missing bars, missing closes, restrictions (`sizing_unavailable`) |

### 4.3 Risk (P2)

| Function | Callers after the switch | Refusal and error paths | Class | Proof | Uncovered features |
| --- | --- | --- | --- | --- | --- |
| `ledgr_apply_risk_plan()`, `ledgr_apply_risk_step()`, `ledgr_apply_risk_step_long_only()`, `ledgr_apply_risk_step_max_weight()`, `ledgr_risk_context_equity()`, `ledgr_risk_context_prices()` | lean fallback only | `ledgr_invalid_risk_context` (class vector starting `ledgr_invalid_risk_context`, `ledgr_risk_application_error`) in three cases, in this order within a `max_weight` step: equity not finite and non-negative; a non-numeric or wrong-length decision close, raised before any target test, also when every target is zero (`R/risk-model.R:465-470`); a nonzero target without a positive finite price, with the instrument list. `ledgr_unsupported_risk_step` (dead, F1). | **Merge**: one risk application in `R/risk-model.R`: steps compiled once per run (`lean_risk_steps()`), applied per pulse (`lean_risk_apply()`). The three `ledgr_invalid_risk_context` refusals are raised in place, verbatim, in the pin's order, step by step. The price vector is an argument. | R1 witnesses (22) for equity and prices. The close-shape refusal has no witness; on the lean path the close comes from the prepared matrix, so its proof is the verbatim move. | stale marks pass the risk mark as the price (F3) |
| the unsupported-step branch | none (F1, dead) | `ledgr_unsupported_risk_step` | **Delete** | the setup argument in F1 | none |
| the parameter-reference branch | public input reaches it (F1) | pin: `ledgr_invalid_post_risk_targets`; lean: an unclassed base R error (F1) | **Delete after Q3**. Setup then refuses an unresolved reference, so the branch has no input left. | one probe: the public input of F1 refuses at setup | none |
| `max_weight` re-test in `lean_risk_steps()` | merged setup | none (setup already validated it, once Q3 lands) | **Delete** (duplicate of `ledgr_risk_validate_max_weight()`) | the R1 setup cases | none |
| `ledgr_availability_validate_post_risk()` | lean risk path | `ledgr_post_risk_inadmissible` (contracted reason `post_risk_inadmissible`) | **Retain**. The lean guard copies its predicate; the switch cut drops the guard and calls the function on every risk pulse (one vector expression). The two shipped steps cannot trip it; it guards future steps. | the direct check `tests/testthat/test-availability-economics.R:259-261` (R1 cannot trip it) | none |
| `ledgr_availability_validate_short_exposure()` | lean risk path; lean no-risk path; planner row check (`R/availability-economics.R`, `dev/lean_core/plan.R`) | `ledgr_short_exposure_unsupported` (contracted) | **Retain**. The switch cut drops the two loop guards and calls it directly. The planner keeps its own row mask: it orders the first failing row across three checks (`ledgr_plan_refuse_first()`), and the function raises for that row. | R1 refusal cases; planner witnesses | none |
| `ledgr_risk_validate_compiled_plan()` and `_step()`, `ledgr_risk_validate_max_weight()` | run setup; `ledgr_execution_spec()` | `ledgr_invalid_risk_plan`, `ledgr_invalid_risk_model` | **Retain**; Q3 adds the unresolved-reference refusal here | the Q3 probe | none |
| `ledgr_is_param_ref()` | feature parameters (6 call sites), risk compile | none | **Retain**. Lean's own use goes with the parameter-reference branch. | none | none |
| `ledgr_availability_validate_strategy_targets()` (debug only today) | lean, debug | `ledgr_restricted_target`, `ledgr_nonmember_exposure_increase` (contracted) | **Retain**. It becomes a production call when membership and restrictions are ported. | none now | membership, restrictions (F3) |
| `ledgr_validate_post_risk_quantities()` (debug only on the lean path, LR-16) | lean, debug | `ledgr_invalid_post_risk_targets` / `ledgr_risk_application_error`, parent `ledgr_invalid_strategy_result`; named in `contracts.md` (P2 bullet, "After the risk chain only the transformed quantities are checked") and in `R/condition-reference.R` | **Delete** from production with the old fold, as pulse plumbing LR-16 accepted. Before that is safe, Q3 must make missing post-risk quantities unreachable (F1). The switch cut amends the contract's P2 bullet. The debug assertion stays as an internal hand-off check in the lean debug block. | the Q3 probe; debug suite | none |

### 4.4 Cost resolution (P3)

| Function | Callers after the switch | Refusal and error paths | Class | Proof | Uncovered features |
| --- | --- | --- | --- | --- | --- |
| `ledgr_cost_model_resolve()` | the resolver closure only | `ledgr_invalid_fill_proposal` (`side` or `qty` not numeric, or of different lengths), then `ledgr_invalid_fill_context` (`open` not numeric, or not one per fill); documented in the condition reference; unreachable from the planner's own columns | **Merge** with `lean_cost_resolve()`: one batch resolve in `R/cost-model.R` on steps compiled once per run. Both refusals stay at its entry verbatim, type and length tests, proposal before context, so the documented conditions do not change. | R2 witnesses (13) for the values. No witness covers the two shape refusals, so their proof is the verbatim move. | none |
| `ledgr_cost_resolver_from_model()`, `ledgr_cost_resolver_from_plan_json()` | run and sweep setup | `ledgr_invalid_cost_model`; `ledgr_invalid_cost_chain_order` from the reconstruction (`ledgr_cost_plan_reconstruct()` through `ledgr_cost_chain()`) | **Retain**. The resolver carries its compiled steps, so the lean code reads them instead of extracting them from the closure. | existing cost-model tests | none |
| `ledgr_cost_zero()` used to recognise the closure by its body (`lean_cost_steps()`) | none after the merge | none | **Delete** that use. `ledgr_cost_zero()` itself stays: it is a public constructor. | R2 setup cases | none |
| `ledgr_plan_resolve()` | lean debug; the dead non-package-resolver branch (F1) | `ledgr_invalid_pulse_plan` (output shape), debug-only on the lean path since Cut 18 | **Delete** the function and the branch. The output-shape assertion stays as a debug check on the merged resolve. | `cost_columns_short` variant (debug on) | none |

### 4.5 Declared state (P5)

| Function | Callers after the switch | Refusal and error paths | Class | Proof | Uncovered features |
| --- | --- | --- | --- | --- | --- |
| `ledgr_strategy_state_apply_values()` | lean: the patch fallback, and every full replacement (`patch = FALSE`) | `ledgr_invalid_strategy_state` (through `ledgr_strategy_state_abort()`): not a uniquely named list, undeclared fields | **Merge**: `lean_state_apply()`'s patch path becomes the first branch | R5 witnesses (42) | none |
| `ledgr_strategy_state_field()` | the merged apply only | its own unknown-field refusal (`R/strategy-state.R:231-237`), after apply's undeclared-field check | **Merge** into the apply function, with its refusal verbatim | R5 witnesses | none |
| `ledgr_strategy_state_validate_value()` | merged apply only | unclassed atomic, broadcast and name rules, declared type, NaN or infinity | **Merge** with `lean_state_value()` | R5 witnesses | none |
| `ledgr_strategy_state_abort()` | state apply; pulse snapshot (`R/pulse-snapshot.R:129`); declaration validation; state-view reads | owns the `ledgr_invalid_strategy_state` class | **Retain** (owner of the state refusal) | none | none |
| `ledgr_strategy_state_default_scalars()`, `ledgr_strategy_state_default_value()`, `ledgr_strategy_state_cast()` | run and sweep setup; `ledgr_execution_spec()`; state defaults; declaration validation and identity reconstruction (`cast`) | none on these paths | **Retain** (owners of the reset values and type casting) | none | none |

### 4.6 Tally

- **Retain:** 12 owners:
  - targets: the intermediate set, the targets helpers, intent reason and
    strategy error;
  - risk: post-risk, short exposure, risk-plan validation, parameter
    reference, strategy-target availability;
  - cost: resolver construction;
  - state: the state refusal, default values and casting.
- **Merge:** 5 rules, now with their helpers:
  - targets, with its unwrap step;
  - sizing evidence;
  - risk application;
  - cost resolve;
  - state apply, with field lookup and value check.
- **Replace:** none.
- **Delete:** 6 items:
  - the dead unsupported-step branch;
  - the parameter-reference branch, after Q3;
  - the duplicate `max_weight` test;
  - the post-risk quantity check in production, after Q3;
  - the closure-body identification;
  - `ledgr_plan_resolve()` with its dead branch.

## 5. Rules for the switch cut

1. No new compatibility wrapper, forwarder or alias keeps an old internal
   signature alive. A merged function takes the arguments its callers need,
   and every caller is updated in the same cut.
2. Delete a function only when no caller, fallback, refusal path or debug
   assertion still needs it. `ledgr_validate_strategy_targets()` keeps its
   signal-strategy callers.
3. A merge moves the fallback's refusal code verbatim: same class, message,
   payload and precedence. Its witness cases must pass unchanged against the
   recorded pin outcomes. A refusal no witness exercises is checked by a diff
   showing the moved code unchanged; no new witness families are added for
   it.
4. A rule implemented twice that this audit does not classify remains a
   switch blocker (macro plan item 3).
5. Debug-only checks follow pulse plumbing: an internal hand-off is checked
   in debug only, and an external entry (the strategy's return) keeps its
   production check. A check moves to debug only once no public input can
   trip it (F1 shows the cost of skipping that test).

## 6. Outside Section 19.10

The lean modules (`fifo.R`, `plan.R`, `loop.R`) also re-implement old-fold
code: the FIFO, the planner and valuation. None of those has a runtime
fallback; the switch deletes the old fold. Many package helpers are shared,
not duplicated, for example the lot-book validators, affordability and the
diagnostic writers. As decided (Q2), the switch cut lists by script every
`R/` function whose only callers are the old fold. Each one is either deleted
with the fold or named as a shared helper the lean core calls. That list is
the item-3 check for everything outside Section 19.10.

## 7. Questions for the maintainer

Q1, Q2 and Q4 are decided (Section 8). Q3 is reopened, because its premise
in v1 ("no public path changes") was wrong.

- **Q3 (reopened). Unresolved risk parameters.** A parameter value that is
  itself a `ledgr_param()` reference passes risk-plan compilation today.
  - Today: the run fails at the first risk pulse. The pin raises
    `ledgr_invalid_post_risk_targets`, saying the targets are not finite;
    the lean core raises an unclassed base R error.
  - Proposed: compilation refuses at setup, before any pulse, with
    `ledgr_invalid_risk_plan`. The message names the parameter and says that
    its value is itself an unresolved reference. The compiled-step
    validation refuses a reference too, so a hand-built spec cannot carry
    one either.
  - What changes publicly: this one misuse fails earlier, with a different
    class and a clearer message. It happens in setup, so a sweep candidate
    with this value fails as a setup failure, not mid-fold.
  - This also removes the lean/pin difference before the switch. Parity
    against the pin then records this input as a deliberate difference.
  - Recommended: yes, landing in the switch cut with the risk merge.

## 8. Maintainer decisions (2026-11-15)

Taken on v1 while its Type 1 review was running:

- Q1: the oracle moves to recorded pin outcomes, one per witness case,
  checked out of process; the in-loop comparisons for merged checks go.
- Q2: the switch cut lists, by script, every `R/` function whose only
  callers are the old fold.
- Q3: agreed on v1's premise; reopened in v2 (Section 7).
- Q4: the merges land in the switch cut itself.
