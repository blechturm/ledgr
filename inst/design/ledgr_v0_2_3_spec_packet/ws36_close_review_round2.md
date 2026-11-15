CHANGES_REQUIRED

Mode: Type 1 close review of workstream 36 (Cut 18), round 2; fresh session at `898facdb`. Scope: F1-F6 and the fallback inventory. Settled maintainer decisions were applied without reopening them.

Source paths are relative to `C:/Users/maxth/ledgr-wt/ws36-close-review-r2`; probe/output paths are relative to `C:/Users/maxth/ledgr-wt/ws36-close-review-out-r2`.

| Finding | Result | Evidence |
| --- | --- | --- |
| F1 | Fixed | `checks.R:194` establishes container shape before extraction at `:197`. Atomic and zero-length cases match the pin in `witness.csv`; `atomic_mutation.txt`: `mutation sizing_field_before_shape: CAUGHT` (8 differences across both modes). |
| F2 | Fixed | `checks.R:195` fences classed columns to the pin. `column_subset_dispatch` has the pin's `ledgr_invalid_strategy_result` in both modes; removing the fence is caught only by this case (`classed_mutation.csv`). |
| F3 | Fixed | `checks.R:165` delegates the empty helper axis. `helper_empty_axis` is identical in both modes; removing the empty-axis fence is caught only by this case (`empty_mutation.csv`). |
| F4 | Fixed | `loop.R:592` puts target validation inside the outcome comparator. `wrong_refusal.txt`: `CAUGHT`, `ledgr_internal_error`, `Lean target validation differs from the pin's at pulse 1.` Matching target refusals also pass the fold subset in both modes. |
| F5 | Fixed | `payload.txt`: `mutation debug_payload_unchecked: CAUGHT`. Only `DBG/refusal_ids_only_differ` differs, once per mode (`payload.csv:144`, `:289`); the baseline comparator and matching-refusal cases pass. |
| F6 | Fixed | `run_stage2b.R` runs the unchanged checker against `evidence_cut18` at this head, exit 0. `stage2b.txt`: `CHECK PASSED`; both guts fail economic parity, clock corruption exits 1, missing/misassigned clock cells refuse. Stage-2b history now stays within `dev/spikes/r_floor` (`git_review.txt`). |

The `checks.R` and `loop.R` citations above mean `dev/lean_core/`. The direct runner reports `145 cases x 2 debug settings, 0 differ; manifest missing 0, unlisted 0`. Source inspection and these probes found no new wrong value or refusal introduced by the fixes.

N1. Required — The inventory omits retained package calls.

Claim: Section 19.10's last column is incomplete, including setup, debug and refusal dependencies used by the corresponding checks.

Evidence: `lean_core_interface.md:1234` through `:1238` omit the following direct calls:

| Row | Missing calls and source locations |
| --- | --- |
| Targets | `ledgr_is_strategy_intermediate()` (`dev/lean_core/loop.R:581`); `ledgr_strategy_targets_contract()` (`loop.R:584`, malformed-result refusal). |
| Risk | `ledgr_is_param_ref()` (`dev/lean_core/checks.R:44`); `ledgr_risk_validate_compiled_plan()` (`loop.R:226`, setup); `ledgr_availability_validate_strategy_targets()` (`loop.R:629`, debug); `ledgr_validate_post_risk_quantities()` (`loop.R:636`, debug). |
| Cost | `ledgr_cost_zero()` (`checks.R:110`, closure identification at setup). |
| State patch | `ledgr_strategy_state_default_scalars()` (`loop.R:498`, conditional setup). |

`inventory_probe.R` checks the literal boundary/setup calls against their rows and instruments the two calls inside the replacement preparation functions. Output (`inventory_probe.txt`):

```text
ledgr_is_param_ref: actual calls 1; named in inventory row FALSE
ledgr_cost_zero: actual calls 1; named in inventory row FALSE
```

The same output records `named in inventory row FALSE` for all six listed `loop.R` calls. The sizing row has no missing direct package call; the cost fallback and debug calls to `ledgr_plan_resolve()` are present as documented. No named package function was found absent from its stated code path, apart from N2's routing claim.

Consequence: An audit relying on this inventory can miss surviving setup/refusal owners and debug-oracle dependencies. This violates the requested completeness of the inventory; it does not demonstrate an execution mismatch.

Fix: Add the missing calls to their rows, labelling setup, debug and refusal use. Distinguish adjacent boundary helpers from the actual fast-path fallback. The fallback paragraph (`lean_core_interface.md:1240`), revision 16 (`macro_plan.md:64`) and WS14a (`macro_plan.md:1056`) otherwise preserve the settled retention/classification obligation correctly.

N2. Required — The state-patch row assigns valid patches to a fallback it does not call.

Claim: `lean_core_interface.md:1238` describes the plain patch path as fields in state order and assigns an "otherwise named patch" to `ledgr_strategy_state_apply_values()`. Valid subsets and reordered declared fields also stay in lean code. The full-name comparison only skips repeated name checks; it is not the admission boundary (`dev/lean_core/checks.R:246`, `:251`).

Evidence: `inventory_probe.R` instruments both package fallbacks and compares accepted subset and reordered patches with the pin. Output:

```text
subset patch: identical to pin TRUE; apply_values calls 0; validate_value calls 0
reordered patch: identical to pin TRUE; apply_values calls 0; validate_value calls 0
```

Consequence: The inventory misstates both the lean acceptance surface and when the package patch implementation remains necessary.

Fix: Describe the plain container path as a nonempty uniquely named list of declared fields, including subsets and any order, with plain typed values. Describe the full-state-order predicate as the name-check shortcut. Reserve the package container fallback for the actual invalid/empty-container or invalid-name/field cases; retain the separately documented value fallback. No implementation change is needed.

Checked: the round-1 report, fix diff and final source identity; all direct replacement witnesses in both modes; the four new direct mutations; the wrong-target-refusal fold mutation; six frozen-path workloads in each mode (`witness_nonfinite`, `s2_sizing_malformed`, `s2_sizing_malformed_target`, `s2_risk_bind`, `s2_cost_chain`, `witness_state_container`), each mode 97 tables, zero differences; Section 19.10 against `checks.R`, `loop.R`, `plan.R`; macro-plan revision 16/WS14a; relevant ticket evidence. The final timing-record checker passes all ten cells (eight pairs each); line counts reproduce production 2,116 -> 2,256, debug 153 -> 177, loop production 910. The stage-2b checker passes. Tracked status is clean; execution sources have no change after `7474044b`.

Not checked: no new timing windows, full gate, variant driver, full test suite, package check, vendor data or switch implementation. Historical/intermediate proofs and all raw timing summaries were not independently rerun or recomputed. No tracked file was edited and no commit was made.
