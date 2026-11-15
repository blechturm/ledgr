CHANGES_REQUIRED

Mode: Type 1 close review of workstream 36, Cut 18. Independent fresh session at `9775c360`; implementation range `0cb7e702..6a3724a5`.

Repository paths below are relative to `C:/Users/maxth/ledgr-wt/ws36-close-review`. Probe paths are relative to `C:/Users/maxth/ledgr-wt/ws36-close-review-out`. The findings apply the accepted cut and amendments; none asks to reopen the trust principle or the R2/R4 disposition.

F1. required — Atomic sizing evidence changes the contracted refusal.

Claim: `lean_sizing_evidence()` extracts fields before establishing that the user-returned evidence supports `$`.

Evidence: `dev/lean_core/checks.R:189` and `:190` precede the shape predicate at `:191`. The pin checks shape first at `R/sizing-evidence.R:23`; these package sources are unchanged from `d5b3a151`, and the probe loads the installed pin. `probe_exactness.R` tests `1`, `"bad"`, `TRUE`, and `numeric()`: lean raises `simpleError/error/condition`, message `$ operator is invalid for atomic vectors`; the pin raises `ledgr_invalid_strategy_result/rlang_error/error/condition`, message `Strategy sizing evidence has an invalid shape.`

`probe_entry.R` also reproduces this through public snapshot, experiment and run APIs, with a strategy returning `structure(ctx$hold(), sizing_evidence = 1)`. `probe_entry.txt` records the pin refusal above, the base error with debug off, and `ledgr_internal_error: Lean sizing evidence differs from the pin's at pulse 1.` with debug on. All three diagnostic rows have stage `strategy` and timestamp `2021-01-04`.

Consequence: An ordinary malformed strategy return changes both refusal class and message in production. Debug detects the disagreement but does not make the two modes equivalent. This violates amendment lean_owned (b)/(c) and `inst/design/contracts.md#contract-strategy-outputs`.

Fix: Delegate invalid containers to the pin before any field extraction. Add atomic and zero-length non-NULL evidence cases to the required manifest and a public-return witness in both debug modes.

F2. required — The sizing accept path admits a user value the pin refuses.

Claim: The fused numeric checks assume that user-returned numeric columns have ordinary subsetting semantics.

Evidence: `dev/lean_core/checks.R:193` admits classed numeric columns, and `:199` checks the complete requested-quantity column. The pin instead checks `x$requested_quantity[!unavailable]` at `R/sizing-evidence.R:72`. In `probe_exactness.R`, `[.review_quantity` returns `NA_real_`; an otherwise valid one-row `ledgr_sizing_evidence` has `requested_quantity = structure(0, class = "review_quantity")`, zero rounded/pre-floor/held quantities, missing price, and reason `sizing_zero_target`. Lean returns that evidence unchanged. The installed pin raises `ledgr_invalid_strategy_result` with `Strategy sizing evidence contains an invalid typed value.` See `probe_exactness.txt`, “Sizing evidence column with subset dispatch”.

Consequence: The plain path accepts what the pin refuses. These columns came from strategy code, so they do not carry an internal guarantee that permits bypassing their observable R behavior. The existing wrong-class and nonnumeric-price witnesses do not cover this admission.

Fix: Restrict the fused path to representations for which the rewritten operations are equivalent by construction, delegating object/dispatch-bearing evidence and columns to the pin. Cover container dispatch and column dispatch in the required cases, with a mutation that removes the new admission fence. Do not reject these inputs independently with a new refusal.

F3. required — Empty helper targets lose an attribute the pin preserves.

Claim: The helper accept path always subsets the unclassed target, including the pin's special empty-axis return.

Evidence: `dev/lean_core/checks.R:165` returns `u[ids]`. At `R/strategy-contracts.R:56`, the pin returns the unclassed target directly when both target and axis are empty. `probe_exactness.R` uses the exported constructor `ledgr::ledgr_target(numeric(), universe = character(), origin = "review")`. The lean value has only `names = character()`; the pin value also has `origin = "review"`; `identical(a, b)` is FALSE. This is an accepted value difference, without a custom method. The registered empty-target case at `dev/lean_core/parity/cut18_witness.R:288` uses a plain numeric vector and misses the helper branch.

Consequence: R3's exact-value claim is false on the empty-axis input accepted by its own predicate and covered by the amendment's empty-axis requirement. This is a direct replacement mismatch; the existing fold workloads still pass.

Fix: Preserve the pin's empty-axis early-return behavior, or delegate that case. Add an empty helper carrying its normal origin/sizing attributes to the manifest and a discriminating normalization fault.

F4. required — Target refusals bypass the debug comparison.

Claim: R3 compares successful values only, although the amendment requires every replacement outcome to be compared with the pin on every pulse.

Evidence: `dev/lean_core/loop.R:592` evaluates `lean_targets()` before the debug comparison at `:593`. A refusal unwinds before the pin is called. `probe_debug.R` loads the real debug-on fold, instruments its pin-validator binding, and injects a wrong refusal into the lean target function in the probe environment. `probe_debug.txt` reports `mutant reached: TRUE; pin comparison calls: 0`, then `review_wrong_refusal/rlang_error/error/condition: review: wrong target refusal`. The pin would accept the strategy's `ctx$hold()` target. The outcome comparator used for sizing, risk and patches is absent here.

Consequence: A target refusal regression escapes the promised per-pulse differential assertion. The direct witnesses can compare selected refusals, but their debug flag does not exercise this loop boundary.

Fix: Put the target call and pin call inside the outcome comparison in debug mode, retaining the ordinary lean call in production. Add reached wrong-refusal and matching-refusal cases that verify the comparator actually invokes both sides and re-signals an equal pin refusal.

F5. required — The required payload-only discrimination proof is missing.

Claim: The committed faults do not demonstrate that changing only `instrument_ids`, with class, message and reason preserved, fails specifically on the payload comparison.

Evidence: The complete direct mutation registry is at `dev/lean_core/parity/cut18_witness.R:31` through `:73`; the loop registries are `loop_parity.R`, `loop_variants.csv` and `loop_variant_changes.csv` in that directory. None contains that fault. The direct cases call the replacements at `cut18_witness.R:335`; they do not invoke `lean_debug_same()`. `probe_payload_witness.R` adds one in-memory fault registration to the existing witness runner: replace `ids = e$instrument_ids` with `ids = NULL` in the debug signature. Its output is `130 cases x 2 debug settings, 0 differ; manifest missing 0, unlisted 0` and `mutation debug_payload_unchecked: MISSED` (expected probe exit 1). No tracked source or manifest was edited.

Consequence: The amendment's explicit A2 discrimination obligation remains unproven. The direct refusal capture includes payload fields and the production debug signature currently includes IDs, but the recorded proof does not establish that a payload-only regression reaches and fails that comparison.

Fix: Register a reached condition corruption that changes only the IDs, exercise it through the debug outcome comparator against an independent pin outcome, and assert that the payload difference is the detecting signal. Keep the direct condition-capture test as well. Do not alter the historical A0 oracle or widen allowed errors.

F6. required — The claimed stage 2b checker pass does not reproduce at the review head.

Claim: `check.R --evidence=evidence_cut18` exits 1 on the committed inputs, despite LDG-3236's `CHECK PASSED` evidence.

Evidence: I ran `dev/spikes/r_floor/stage2b/check.R` with the specified pin, `--scratch=C:/Users/maxth/ledgr-wt/ws36-close-review-out/stage2b`, and `--evidence=evidence_cut18`. The rerun parity/contract comparisons passed; both gutted references failed economic parity; the corrupted clocked record exited 1; missing and misassigned clock cells were refused. The final result was `CHECK FAILED`, solely because `stage 2b commits touch:` paths outside `dev/spikes/r_floor`. The guard is at `check.R:87` through `:92`, and its failing exit is at `:96`. Commit `d1509c3e1228172858bad9f23ff6a6b7a38d40d1` combines eight stage-2b evidence files with 60 files outside that scope. `probe_scope.R` independently reproduces that guard input; see `probe_scope.txt`.

Consequence: The final committed evidence cannot satisfy LDG-3236's checker acceptance as recorded. The numerical tables themselves reproduce; this is a failure of the claimed complete checker result, not a performance objection.

Fix: Separate the offending stage-2b evidence commit from the other records so the preserved scope guard passes, then rerun the checker on the resulting committed head and update the ticket evidence. Do not certify the earlier pre-commit pass as the final result or suppress the scope guard.

Checked:

- Read the Cut 18 decisions, both amendments, the R2/R4 disposition, workstream 36 and LDG-3234/3235/3236; Section 19.10; the implementation diff; the relevant contracts and optimization style. Compared all replacement implementations with the installed pin's functions; the relevant `R/` files also have no diff from `d5b3a151`.
- The frozen census checker passes at `0cb7e702`: 1,630 sites, 277 classification statements, bijection with the inventory. Inspected the forwarder classifications, amended worklist, census cross-reference, stop evidence, and the changed hand-offs. No additional removal/ownership finding. The context still allocates a fresh per-pulse lookup and retains its debug checks. The cost output-shape assertion names its producer and guarantee; the planner supplies internal numeric columns, and arithmetic preserves column types/lengths even for empty batches and overflow. Foreign resolvers retain the pin path. The once-per-run predicates compute on prepared constants and retain their pin fallbacks. No additional economic-guard finding beyond F1/F2.
- Reviewed the changed code against all seven optimization shapes. New step/field loops range over fixed declarations; the affordability loop remains sequential by its economic rule. No style finding is included.
- Reran `cut18_witness.R`: 130 cases in each debug mode, zero differences. Reran the repeated-fee, reversed-risk-step and sizing-unavailable faults individually: each CAUGHT. Inspected all registered loop variants and both re-anchors. Reconciled their committed results with the effective manifests: debug 0 has 77 rows/33 variants; debug 1 has 76 rows/34 variants; none missing, unreached or non-CAUGHT. The three negative controls retain their expected non-CAUGHT verdicts. This does not discharge F5's absent fault.
- Reran a frozen-path gate subset in both debug modes: `tight_cash`, `witness_state_container`, `witness_retained_context`, `witness_error_cleanup`, `s2_risk_bind`, `s2_cost_chain`, `s2_sizing_notice`. Each mode passed seven workloads and 120 tables, zero different, all seven frozen paths checked. Outputs: `subset_debug0.csv` and `subset_debug1.csv`.
- Independently recomputed all nine paired-comparison summaries from their raw observations, including within-round savings, medians, minima and threshold counts. Recomputed the timing record's ten ratios and its descriptive changes from Cut 16. The timing record checker passes: 160 slots, eight pairs per cell. Recomputed both original and Cut 18 stage-2b summaries, attribution cells and ratios from raw CSVs. All numerical summaries reproduce to the recorded precision. `recompute_evidence.R`, `recompute_evidence.txt` and `paired_recomputed.csv` retain the calculations. The settled R2/R4 exceptions are respected.
- Recomputed the line count with `cut18_lines.R`: production 2,116 to 2,253 (+137), debug 153 to 178 (+25), loop production 925 to 909. The committed `lines.csv` matches; the 300-line replacement allowance and 925-line loop limit hold. Also reconciled the committed proof counts: gate 74 workloads/1,311 tables; batch one 15/232; inert hooks 7/108, zero differences in both modes.

Not checked: no new timing windows, full gate, variant-driver run, full test suite, package check, vendor data, later slices or switch implementation. Intermediate proof claims were inspected in their committed records, not rerun. Three direct faults were rerun, not the entire direct mutation registry. Stage-2b records were regenerated for the allowed one-round checker, not for a new performance comparison. No tracked file was edited and no commit was made; the final tracked worktree status is clean.
