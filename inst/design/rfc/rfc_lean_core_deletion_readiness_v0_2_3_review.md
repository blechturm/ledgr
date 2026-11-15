CHANGES_REQUIRED
Mode: Type 1 — independent factual review of seed v1 at f9de1bb0.

Paths below are relative to the review worktree unless identified as output files.

**N1 — required: F1's unresolved-parameter branch is publicly reachable.**

Claim: seed:60-95 and :157 say compilation resolves every reference, only an internal spec can retain one, and Q3 changes no public path (:237-240).

Evidence: `probe_public_reference.R` and `.txt` in the output directory call public `ledgr_run()` and `ledgr_sweep()` with a normal experiment using `ledgr_risk_max_weight(ledgr_param("w"))` and strategy parameter `w = ledgr_param("other")`. An observer at `ledgr_execute_fold()` inspects the untouched execution spec. Both entries print:

```text
PUBLIC SPEC: unresolved reference = TRUE
PUBLIC SPEC: lean_risk_steps returns NULL = TRUE
CLASS: ledgr_invalid_post_risk_targets/ledgr_risk_application_error/rlang_error/error/condition
```

`R/risk-model.R:374-376` validates the resolved value with a validator that explicitly accepts references (:118-120); it does not resolve again. JSON validation preserves the original parameter value (`R/strategy-provenance.R:53`). No spec was hand-built in this probe.

Consequence: the parameter-reference Delete and Q3 rest on a false reachability premise. The proposed setup refusal changes a public failure's class, timing and message.

Fix: correct F1, the Delete row and Q3's factual premise; present the public behavior change to the maintainer for decision. This finding does not decide Q3.

**N2 — required: the target/state fallback dependency inventory is incomplete.**

Claim: seed:26 and Section 4 classify every fallback dependency.

Evidence: these semantic helpers lack a classification:

- `ledgr_unwrap_strategy_target()` is called by the target validator (`R/strategy-contracts.R:43`); it owns helper unclassing and routes intermediate refusals (:24-30). `ledgr_strategy_intermediate_classes()` supplies the intermediate predicate and refused class name (:10, :14).
- `ledgr_strategy_state_field()` is called by state apply (`R/strategy-state.R:328`), with its own unknown-field refusal (:231-237).
- `ledgr_strategy_state_default_value()` is called by the retained default-scalar function (`R/strategy-state.R:171`) and calls `ledgr_strategy_state_cast()` (:160). The latter also serves declaration validation and identity reconstruction (:111, :140).
- `ledgr_strategy_state_abort()` is mentioned at seed:179 but never classified. It supplies the state refusal class (`R/strategy-state.R:8-9`) and has surviving callers including pulse snapshot (:129 in `R/pulse-snapshot.R`), declaration validation and state-view reads.

Consequence: successful normalization, reset behavior and refusal ownership remain unassigned. These are dependencies of the five checks, not the unrelated FIFO/planner work deferred to Section 6.

Fix: explicitly classify these helpers, including surviving callers and the state-field refusal. They may be grouped under their semantic owners.

**N3 — required: the risk Merge omits a price-context refusal.**

Claim: seed:156 describes two `ledgr_invalid_risk_context` refusals and says those two are raised in the merged implementation.

Evidence: `R/risk-model.R:465-470` also refuses a nonnumeric or wrong-length fallback close with message `Risk application requires one flat decision-time close per instrument.` Its class vector starts with `ledgr_invalid_risk_context`, `ledgr_risk_application_error`. `probe_refusals.txt` reproduces it with `list(close = numeric())` and universe `"AAA"`. Risk application reaches this accessor after equity validation and before checking nonzero-target prices (:419-424).

Consequence: the listed two refusals do not preserve the complete fallback rule; the omitted refusal has a distinct message and precedence, including on zero targets.

Fix: include this refusal and identify its owner and ordering in the Merge.

**N4 — required: the post-risk quantity refusal class is wrong.**

Claim: seed:164 lists `ledgr_invalid_strategy_result` “with parent”; F1:89-90 similarly describes a strategy-result refusal.

Evidence: `R/risk-model.R:495-502` raises `ledgr_invalid_post_risk_targets` / `ledgr_risk_application_error`, with a `ledgr_invalid_strategy_result` parent. `probe_refusals.txt` reproduces that exact hierarchy after the seed's hand-built parameter plan. `inst/design/contracts.md:187-194` explicitly names this refusal; `R/condition-reference.R:796-797` documents it.

Consequence: the Delete inventory misidentifies the behavior being moved to debug. Together with N1, the seed also understates the public failure affected by Q3.

Fix: correct the class hierarchy and cite the contract plus the accepted pulse-plumbing LR-16 disposition. The planned debug-only placement itself is not challenged here.

**N5 — required: F3 misses feature-specific fallback uses.**

Claim: seed:107-120 names only three dependencies, says missing bars use none, and lists no uncovered-feature dependency for the target validator (:138).

Evidence: membership can produce an empty decision axis while still calling the strategy (`inst/design/contracts.md:1333-1337`). A zero-length `ledgr_target` on that axis explicitly falls back to `ledgr_validate_strategy_targets()` (`dev/lean_core/checks.R:165-169`); the existing witness is `helper_empty_axis` (`dev/lean_core/parity/cut18_witness.R:302`). Also, absent bars leave NA closes in the prepared matrices (`R/history-substrate.R:429-459`); positive-weight unpriced members produce `sizing_unavailable` evidence (`R/strategy-helpers.R:641-654`), which takes the sizing fallback (`dev/lean_core/checks.R:202-217`).

Consequence: F3's “none” statements omit target normalization for empty axes and sizing validation for missing bars.

Fix: add these dependencies and allow the feature groups to overlap: a missing bar can also mean a missing close and a stale mark.

**N6 — required: two length tests do not preserve the cost input refusals.**

Claim: seed:170 says the two documented shape refusals remain as “two length tests per pulse,” with R2 witnesses as proof.

Evidence: `R/cost-model.R:406-410` tests numeric types as well as lengths. `probe_cost_shape.txt`, against the pin, shows same-length character `side` or `qty` raises `ledgr_invalid_fill_proposal`, and same-length character `open` raises `ledgr_invalid_fill_context`. R2's cases use numeric batches; its only setup fallback case checks a foreign resolver (`dev/lean_core/parity/cut18_witness.R:250-271`).

Consequence: length-only checks lose documented refusals, and the named R2 cases would not detect that loss.

Fix: specify retaining both type and length predicates verbatim, including proposal-before-context precedence; correct the proof claim rather than treating R2 as evidence for these refusals.

**N7 — required: the named R1 proof does not exercise post-risk inadmissibility.**

Claim: seed:159 cites “R1 refusal cases” for retaining `ledgr_availability_validate_post_risk()`.

Evidence: R1 exercises closed long-only/max-weight plans and short-exposure refusals (`dev/lean_core/parity/cut18_witness.R:200-226`); none raises `ledgr_post_risk_inadmissible`. As the seed correctly observes, those steps cannot violate this predicate. The existing direct refusal check is instead `tests/testthat/test-availability-economics.R:259-261`.

Consequence: R1 cannot detect loss of the refusal named in that row.

Fix: point the Retain row to the existing direct check and its contracted class, rather than claiming R1 proves it. No additional witnesses are requested.

**N8 — required: resolver construction has an omitted refusal class.**

Claim: seed:171 lists only `ledgr_invalid_cost_model` for the retained resolver constructors.

Evidence: `ledgr_cost_resolver_from_plan_json()` reconstructs the model (`R/cost-model.R:386-390`); reconstruction calls `ledgr_cost_chain()` (:345-349), whose order check raises `ledgr_invalid_cost_chain_order` (:247-250). `probe_cost_shape.txt` reproduces this from valid JSON containing a fixed fee followed by a spread:

```text
ledgr_invalid_cost_chain_order/rlang_error/error/condition
Invalid cost chain order: price transform at step 2 follows a fee adder.
```

Consequence: the constructor's refusal inventory is incomplete, although Retain can preserve this behavior.

Fix: include the chain-order refusal and its reconstruction/validation owner in that row.

Checked: Section 19.10 against `checks.R`, the relevant `loop.R`/`plan.R` paths, package fallback bodies and callers; risk and cost setup; walk-forward training/test routing (`R/walk-forward.R:595`, :1167; `R/walk-forward-folds.R:784`); promotion (`R/sweep.R:812`); contracts, condition reference and pulse-plumbing LR-16. Only the runner and sweep build execution specs (`R/backtest-runner.R:794`, `R/sweep.R:1723`); no additional surviving caller was found that independently changes a proposed class. The other-step-type and foreign/nonnumeric-cost-resolver exclusions are supported by setup validation/construction. The seed's hand-built defect reproduces, including the lean base R error. Cut 18 reported `145 cases x 2 debug settings, 0 differ; manifest missing 0, unlisted 0`; its CSV contains 290 matching rows. R emitted locale startup warnings. Final Git status has no tracked changes; HEAD is f9de1bb02d74df8c9c5652fd692ad6047d346d88.

Not checked: parity gate, timing, full suite, package checks, vendor data, or unimplemented switch behavior. No Section 7 design choice was decided, no new coverage was requested, and no commit was made.
