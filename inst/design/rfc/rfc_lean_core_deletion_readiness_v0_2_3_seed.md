# Lean Core Deletion Readiness: Seed v1

- Author: Claude, 2026-11-15, at the maintainer's request.
- Status: seed. Proposes classifications; implements nothing. The maintainer
  names the review mode.
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
behaviour. This seed sorts every package function in Section 19.10 into one
of four classes. It also says what proof each move needs, and which of the
features the lean core does not cover yet still depend on each function.

## 2. The four classes

- **Retain.** The function stays as an independent semantic owner. It has
  callers beyond the fold, or it owns a contracted refusal. The lean code
  calls it, with no copy of its rule. Proof needed: none beyond its
  existing tests.
- **Merge.** The fast path and the fallback become one function, in the
  package file that owns the rule today. The fast path becomes its first
  branch. The fallback's refusal code moves over verbatim (same class,
  message, payload and precedence) and is not rewritten. Proof needed: the
  Cut 18 witness cases of that check, against recorded pin outcomes
  (Section 4), in both debug modes.
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

**F1. Two fallback branches are unreachable from public entry.** Only two
places build an execution spec: `ledgr_run()` (`R/backtest-runner.R`) and
`ledgr_sweep()` (`R/sweep.R`). Both of them:

- compile the risk plan with the strategy params, which resolves every
  `ledgr_param()` (`ledgr_risk_compile_arg()`);
- build the cost resolver with `ledgr_cost_resolver_from_plan_json()`.

`ledgr_risk_validate_compiled_step()` also admits only `long_only` and
`max_weight`. So these lean branches cannot be reached:

- the risk plan's "other step type" branch;
- the risk plan's "parameter reference" branch;
- the cost resolver's "not the package's resolver" branch.

Only a hand-built internal spec reaches them. A probe on such a spec (a
compiled `max_weight` step carrying `ledgr_param("w")`) showed that it
passes `ledgr_risk_validate_compiled_plan()`. `ledgr_apply_risk_plan()` then
returns missing targets with a coercion warning, not a ledgr refusal.

The branches split into dead code and one hidden defect:

- **Dead code: the other-step-type and non-package-resolver branches.**
  Cut 18 sent every input outside the fast path to the pin without asking
  whether that input could arrive. The pin's own `ledgr_apply_risk_step()`
  default and `ledgr_plan_resolve()`'s output-shape check are the same kind
  of defensive code. The resolver-shape conditions look left over from a
  resolver that was once meant to be swappable.
- **A latent validation defect: the parameter-reference branch.**
  `ledgr_risk_validate_compiled_step()` reuses
  `ledgr_risk_validate_max_weight()`, which lets a parameter reference
  through because the uncompiled chain needs that. A compiled plan must not
  hold one. Downstream, by reading only:
  - the old fold's post-risk quantity check refuses the missing targets
    under a strategy-result class;
  - the lean path stops in `ledgr_availability_validate_post_risk()` with an
    unclassed base R error.

  No public entry reaches it: run and sweep refuse a missing parameter at
  compile time with `ledgr_risk_plan_parameter_missing`. Q3 fixes the cause.

**F2. After the switch the in-loop oracle has nothing in-tree to compare
with.** Today `lean_debug_same()` compares each lean result with the pin's
function in the same session. Once a check is merged, the package holds only
one version, so the in-loop comparison would compare the code with itself.
The witness harness (`dev/lean_core/parity/cut18_witness.R`) already runs
each case against the pinned library, so the oracle can move there. The pin
outcomes are recorded once per case (value, or the condition's class,
message, payload and parent). After the switch the harness checks the
package against those recordings. This seed proposes that move (Q1).

**F3. The features the lean core does not cover yet** (`lean_loop_coverage()`)
use three of these fallbacks in production once they are ported:

- membership, status and lifetime facts, and execution restrictions:
  `ledgr_availability_validate_strategy_targets()` stops being debug-only;
- stale marks: the risk price becomes the availability risk mark, not the
  decision close (`ledgr_risk_context_prices()`);
- missing closes: the helpers emit `sizing_unavailable` rows, which take the
  sizing fallback today.

The other uncovered features (compiled FIFO, checkpoints, restart, schedules,
declared sessions, corporate actions, opening positions, declared execution
opportunities, missing bars, history calls in the strategy, walk-forward)
use none of the Section 19.10 functions.

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
| `ledgr_validate_strategy_targets()` | lean boundary; `ledgr_signal_strategy()` (3 calls); `ledgr_strategy_echo()` | `ledgr_invalid_strategy_result`: universe shape, intermediate signal, not numeric, names, non-finite, missing or extra instruments | **Merge**: `lean_targets()`'s two accept paths become the function's first branch. The run-constant universe predicate (`lean_targets_axis_ok()`) is passed in as an optional argument; other callers keep computing it. | R3 witnesses (21) and the signal-strategy tests | none |
| `ledgr_is_strategy_intermediate()`, `ledgr_abort_intermediate_strategy_result()`, `ledgr_strategy_targets_contract()` | lean boundary; strategy contracts; `R/risk-model.R` | the intermediate-signal refusal; the contract message text | **Retain** | none | none |

These are also called at the boundary directly, with no fast path, so they
are not duplicates: `ledgr_validate_strategy_intent_reason()`,
`ledgr_abort_strategy_error()`, `ledgr_strategy_state_defaults()` (reset).
All three are **Retain**.

### 4.2 Sizing evidence (P2)

| Function | Callers after the switch | Refusal and error paths | Class | Proof | Uncovered features |
| --- | --- | --- | --- | --- | --- |
| `ledgr_validate_sizing_evidence()` | lean boundary only | `ledgr_invalid_strategy_result`: shape, rows, instrument outside the axis, column types, reason codes, typed values. It also handles `sizing_unavailable` rows and stale evidence (returns NULL). | **Merge**: `lean_sizing_evidence()` becomes the first branch in `R/sizing-evidence.R`; the vapply path stays for the cold inputs | R4 witnesses (31) | missing closes, restrictions (`sizing_unavailable`) |

### 4.3 Risk (P2)

| Function | Callers after the switch | Refusal and error paths | Class | Proof | Uncovered features |
| --- | --- | --- | --- | --- | --- |
| `ledgr_apply_risk_plan()`, `ledgr_apply_risk_step()`, `ledgr_apply_risk_step_long_only()`, `ledgr_apply_risk_step_max_weight()`, `ledgr_risk_context_equity()`, `ledgr_risk_context_prices()` | lean fallback only | `ledgr_invalid_risk_context` (equity not finite and non-negative; a nonzero target without a positive finite price, with the instrument list); `ledgr_unsupported_risk_step` (unreachable, F1) | **Merge**: one risk application in `R/risk-model.R`: steps compiled once per run (`lean_risk_steps()`), applied per pulse (`lean_risk_apply()`). The two `ledgr_invalid_risk_context` refusals are raised in place, in the pin's order (equity before prices, step by step). The price vector is an argument. | R1 witnesses (22) | stale marks pass the risk mark as the price (F3) |
| the unsupported-step branch and the parameter-reference branch | none from public entry (F1) | `ledgr_unsupported_risk_step`; for an unresolved reference, missing targets with a coercion warning (F1) | **Delete**. Setup refuses an unresolved reference instead: `ledgr_risk_validate_compiled_step()` with `ledgr_invalid_risk_plan`. This changes only a hand-built internal spec. | one probe: a compiled plan carrying `ledgr_param()` refuses at setup | none |
| `max_weight` re-test in `lean_risk_steps()` | merged setup | none (setup already validated it) | **Delete** (duplicate of `ledgr_risk_validate_max_weight()`) | the R1 setup cases | none |
| `ledgr_availability_validate_post_risk()` | lean risk path | `ledgr_post_risk_inadmissible` (contracted reason `post_risk_inadmissible`) | **Retain**. The lean guard copies its predicate; the switch cut drops the guard and calls the function on every risk pulse (one vector expression). The two shipped steps cannot trip it; it guards future steps. | R1 refusal cases | none |
| `ledgr_availability_validate_short_exposure()` | lean risk path; lean no-risk path; planner row check (`R/availability-economics.R`, `dev/lean_core/plan.R`) | `ledgr_short_exposure_unsupported` (contracted) | **Retain**. The switch cut drops the two loop guards and calls it directly. The planner keeps its own row mask: it orders the first failing row across three checks (`ledgr_plan_refuse_first()`), and the function raises for that row. | R1 refusal cases; planner witnesses | none |
| `ledgr_risk_validate_compiled_plan()` and `_step()`, `ledgr_risk_validate_max_weight()` | run setup; `ledgr_execution_spec()` | `ledgr_invalid_risk_plan`, `ledgr_invalid_risk_model` | **Retain** | none | none |
| `ledgr_is_param_ref()` | feature parameters (6 call sites), risk compile | none | **Retain**. Lean's own use goes with the parameter-reference branch. | none | none |
| `ledgr_availability_validate_strategy_targets()` (debug only today) | lean, debug | `ledgr_restricted_target`, `ledgr_nonmember_exposure_increase` (contracted) | **Retain**. It becomes a production call when membership and restrictions are ported. | none now | membership, restrictions (F3) |
| `ledgr_validate_post_risk_quantities()` (debug only, LR-16) | lean, debug | `ledgr_invalid_strategy_result` with parent | **Delete** with the old fold. The merged risk function returns axis-length doubles by construction. The debug assertion stays as an internal hand-off check in the lean debug block (pulse plumbing R1). | debug suite | none |

### 4.4 Cost resolution (P3)

| Function | Callers after the switch | Refusal and error paths | Class | Proof | Uncovered features |
| --- | --- | --- | --- | --- | --- |
| `ledgr_cost_model_resolve()` | the resolver closure only | `ledgr_invalid_fill_proposal`, `ledgr_invalid_fill_context` (batch shape; documented in the condition reference; unreachable from the planner's own columns) | **Merge** with `lean_cost_resolve()`: one batch resolve in `R/cost-model.R` on steps compiled once per run. The two shape refusals stay at its entry (two length tests per pulse), so the documented conditions do not change. | R2 witnesses (13) | none |
| `ledgr_cost_resolver_from_model()`, `ledgr_cost_resolver_from_plan_json()` | run and sweep setup | `ledgr_invalid_cost_model` | **Retain**. The resolver carries its compiled steps, so the lean code reads them instead of extracting them from the closure. | none | none |
| `ledgr_cost_zero()` used to recognise the closure by its body (`lean_cost_steps()`) | none after the merge | none | **Delete** that use. `ledgr_cost_zero()` itself stays: it is a public constructor. | R2 setup cases | none |
| `ledgr_plan_resolve()` | lean debug; the unreachable non-package-resolver branch (F1) | `ledgr_invalid_pulse_plan` (output shape), debug-only on the lean path since Cut 18 | **Delete** the function and the branch. The output-shape assertion stays as a debug check on the merged resolve. | `cost_columns_short` variant (debug on) | none |

### 4.5 Declared state (P5)

| Function | Callers after the switch | Refusal and error paths | Class | Proof | Uncovered features |
| --- | --- | --- | --- | --- | --- |
| `ledgr_strategy_state_apply_values()` | lean: the patch fallback, and every full replacement (`patch = FALSE`) | `ledgr_invalid_strategy_state` (through `ledgr_strategy_state_abort()`): not a uniquely named list, undeclared fields | **Merge**: `lean_state_apply()`'s patch path becomes the first branch | R5 witnesses (42) | none |
| `ledgr_strategy_state_validate_value()` | merged apply only | unclassed atomic, broadcast and name rules, declared type, NaN or infinity | **Merge** with `lean_state_value()` | R5 witnesses | none |
| `ledgr_strategy_state_default_scalars()` | run and sweep setup; `ledgr_execution_spec()`; state defaults | none on these paths | **Retain** | none | none |

### 4.6 Tally

- **Retain:** 9 owners: targets helpers, intent reason and strategy error,
  post-risk, short exposure, risk-plan validation, parameter reference,
  strategy-target availability, cost resolver construction, state default
  scalars.
- **Merge:** 5 rules: targets, sizing evidence, risk application, cost
  resolve, state apply with value check.
- **Replace:** none.
- **Delete:** 6 items: the two unreachable risk branches, the duplicate
  `max_weight` test, the post-risk quantity recheck function, the
  closure-body identification, and `ledgr_plan_resolve()` with its branch.

## 5. Rules for the switch cut

1. No new compatibility wrapper, forwarder or alias keeps an old internal
   signature alive. A merged function takes the arguments its callers need,
   and every caller is updated in the same cut.
2. Delete a function only when no caller, fallback, refusal path or debug
   assertion still needs it. `ledgr_validate_strategy_targets()` keeps its
   signal-strategy callers.
3. A merge moves the fallback's refusal code verbatim: same class, message,
   payload and precedence. Its witness cases must pass unchanged against the
   recorded pin outcomes.
4. A rule implemented twice that this audit does not classify remains a
   switch blocker (macro plan item 3).
5. Debug-only checks follow pulse plumbing: an internal hand-off is checked
   in debug only, and an external entry (the strategy's return) keeps its
   production check.

## 6. Outside Section 19.10

The lean modules (`fifo.R`, `plan.R`, `loop.R`) also re-implement old-fold
code: the FIFO, the planner and valuation. None of those has a runtime
fallback; the switch deletes the old fold. Many package helpers are shared,
not duplicated, for example the lot-book validators, affordability and the
diagnostic writers. This seed does not list them. The proposal (Q2): the
switch cut lists, by script, every `R/` function whose only callers are the
old fold. Each one is either deleted with the fold or named as a shared
helper the lean core calls. That list is the item-3 check for everything
outside Section 19.10.

## 7. Questions for the maintainer

- **Q1. The oracle after the switch.** Record the pin's outcome for every
  Cut 18 witness case once (pin `d5b3a151`), then check the merged package
  functions against those recordings in a separate process. The in-loop
  `lean_debug_same()` comparisons for merged checks are then removed.
  Recommended: yes. The alternative keeps the old functions in the package
  as test-only copies, which is the duplication this audit removes.
- **Q2. Scope outside Section 19.10.** Is the switch cut's scripted
  old-fold caller list (Section 6) enough for item 3, or should this audit
  also list those functions? Recommended: the scripted list, because it is
  mechanical and goes stale less easily than prose.
- **Q3. Unresolved risk parameters.** Is it acceptable that setup refuses a
  compiled plan carrying `ledgr_param()` with `ledgr_invalid_risk_plan`?
  Today such a spec, which only internal code can build, passes setup and
  produces missing targets with a warning. No public path changes.
  Recommended: yes.
- **Q4. When to merge.** Should the merges land in the switch cut, or in a
  cut just before it while both cores still exist? Recommended: in the
  switch cut. Merging before it would mean the old fold and the lean core
  call one merged function, so the in-loop oracle would compare the function
  with itself before Q1's recordings exist.
