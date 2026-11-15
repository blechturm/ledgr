PASS
Mode: Type 1 confirmation of seed v2 against N1-N8, at 2d37f7047df38b6db50587e3bbc314b6a5c2cd25.

All eight findings are corrected. No correction states a new wrong fact affecting a classification, refusal or proof. Q1-Q4 remain decided.

Code paths below are relative to `C:/Users/maxth/ledgr-wt/deletion-readiness-review-r2`. `v2` means `inst/design/rfc/rfc_lean_core_deletion_readiness_v0_2_3_seed_v2.md`. Probe outputs are beside this report; the v1 review outputs were read only.

| Finding | Corrected? Is the text right? | Evidence |
| --- | --- | --- |
| N1 | Yes; right. Public reachability and the public refusal change are explicit; deletion depends on Q3. The new lean outcome and explanation hold. | v2:88-113, :184, :272-299. `R/risk-model.R:118-120` accepts references; :363-376 resolves only once. `lean_param_debug_0.txt` and `lean_param_debug_1.txt` reproduce both public entries against lean and pin; explanation below. |
| N2 | Yes; right. The omitted helpers have owners and classes, including the state-field refusal and surviving callers. | v2:163-164, :207-210. `R/strategy-contracts.R:5-30`, :43 establish unwrap/intermediate ownership. `R/strategy-state.R:231-237`, :317-329 establish field refusal ordering; :111, :140, :148-171 establish casting/default uses. The retained abort owns the class at :8-9 and serves state-view reads (:207-225), declaration validation and `R/pulse-snapshot.R:129`. |
| N3 | Yes; right. The close-shape refusal and its ordering are included; its proof no longer depends on a witness exercising it. | v2:182. `R/risk-model.R:419-424` reads equity, then prices, then tests nonzero targets. :463-470 checks fallback close type/length independently of target values. The review's `probe_refusals.txt` reproduces the named message/class. R1 cases at `dev/lean_core/parity/cut18_witness.R:200-226` do not exercise this shape refusal. |
| N4 | Yes; right. The outer classes and parent are correct, with the shipped contract and accepted debug placement distinguished. | v2:99-107, :191. `R/risk-model.R:482-502`; `inst/design/contracts.md:187-194` (Fold Core And Output Handlers, P2); pulse-plumbing synthesis LR-16 (:252). Both fresh probe outputs reproduce the outer classes and parent. |
| N5 | Yes; right. Empty-axis target normalization and missing-bar sizing fallback are included; feature groups may overlap. | v2:125-139, :162-163, :176. `dev/lean_core/checks.R:163-169` sends an empty helper target to the validator; witness `helper_empty_axis` is at `dev/lean_core/parity/cut18_witness.R:302`. `R/history-substrate.R:429-459` leaves absent bars as NA; `R/strategy-helpers.R:641-654` emits `sizing_unavailable` for unpriced positive-weight members; `dev/lean_core/checks.R:202-217` falls back on that evidence. |
| N6 | Yes; right. Both numeric-type and length predicates remain verbatim, proposal before context; R2 is claimed only for values. | v2:197, :244-248. `R/cost-model.R:406-410` contains those predicates in that order. `dev/lean_core/parity/cut18_witness.R:250-271` uses numeric batches and a foreign-resolver setup case. The review's `probe_cost_shape.txt` confirms the three same-length character-input refusals. |
| N7 | Yes; right. The proof now names the existing direct refusal check and explicitly excludes R1 as proof of it. | v2:186. `tests/testthat/test-availability-economics.R:259-261` expects `ledgr_post_risk_inadmissible`; R1 cases at `dev/lean_core/parity/cut18_witness.R:200-226` do not exercise it. |
| N8 | Yes; right. Resolver reconstruction includes the chain-order refusal and its owner. | v2:198. `R/cost-model.R:386-390` reconstructs the model; :345-349 invokes `ledgr_cost_chain()`; :247-250 raises `ledgr_invalid_cost_chain_order`. The review's `probe_cost_shape.txt` reproduces the fee-before-spread refusal. |

The new N1 claim was reproduced with `lean_param_probe.R`, a copy of the supplied probe using this worktree and output-directory databases, with condition-call/parent printing and pin calls after restoring the fold. In both debug settings, run and sweep produced:

```text
lean: simpleError/error/condition | missing value where TRUE/FALSE needed
pin:  ledgr_invalid_post_risk_targets/ledgr_risk_application_error/rlang_error/error/condition
parent: ledgr_invalid_strategy_result/rlang_error/error/condition
```

The lean condition call is `if (any(bad))` in `R/availability-economics.R:298`. An unresolved reference makes `lean_risk_steps()` return NULL (`dev/lean_core/checks.R:44`), so `lean_risk_targets()` calls `lean_risk_pin()` (:85). That function applies risk and calls admissibility without the quantity check (:96-100). With debug on, `dev/lean_core/loop.R:633-634` compares that fallback with `lean_risk_pin()` again. `lean_debug_same()` compares the identical error signatures and re-signals the error (`checks.R:16-28`); the quantity check at `loop.R:636` is never reached. The pin instead checks quantities before admissibility (`R/fold-engine.R:1019-1022`).

Reproduction commands (PowerShell; outputs captured in `lean_param_debug_0.txt` and `lean_param_debug_1.txt`):

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" "C:/Users/maxth/ledgr-wt/deletion-readiness-review-out-r2/lean_param_probe.R" 0
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" "C:/Users/maxth/ledgr-wt/deletion-readiness-review-out-r2/lean_param_probe.R" 1
```

New findings: none required or advisory.

Checked: v1 review and seed, every N1-N8 correction in v2, relevant code/callers, cited contract and LR-16, existing witness/test bodies, prior probe outputs, and fresh public run/sweep probes using read-only pin d5b3a151 with lean debug off/on. Both fresh logs reach `COMPLETE`; R emitted locale startup warnings. Git status has no tracked changes. No commit was made.

Not checked: unrelated inventory, design alternatives, full parity gate, timing, full test suite, package checks, or unimplemented switch behavior. No new tests or witnesses are requested. E:, ledgr-research and vendor data were not accessed.
