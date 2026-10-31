# Workstream 13 checkpoint review

- Reviewer: Codex; independent clean-context reviewer, no product authorship.
- Date: 2026-10-31.
- Mode: Type 1 checkpoint after LDG-3165/3166, before LDG-3167; v0.2.3 cut 5, macro WS4a part 2.
- Reviewed commit: `eb3695fcae38fcd574032560d0eec3a4d73990e0`, `claude/ws4a-carrier`; diff `975c8add..eb3695fc`.
- Verdict: **CHANGES_REQUIRED**. F1-F5 block checkpoint acceptance. The exact local patches below address parts of the findings, not the whole repair; implementation and verification need another review. No NEEDS_TYPE_2 issue identified.

Authority: cut 5 decisions (1)-(13) and its three amendments; synthesis Sections 3.1-3.3/4; design note consumer/boundary census, obligations, migrations, detectors and Section 8; `contracts.md#contract-execution-fold-core`, `#contract-execution-accounting-events`, `#contract-execution-event-staging`, `#contract-execution-compiled-accounting`, `#contract-execution-cost-model`; optimization manual's seven shapes and clarity rule. Read the WS12 close review and re-review, particularly their condition-precedence, incomplete-predicate, weakened-witness and evidence-identity findings. The performance/budget/F4.01 decisions and accepted cached-net residual were not reopened.

**Execution and evidence keys**

`ROOT` = `C:/Users/maxth/ledgr-wt/ws4a-impl`; `S` = `C:/Users/maxth/AppData/Local/Temp/ws13-review`. Actual commands used absolute paths, plain `Rscript`, and serial R jobs. Scratch scripts remain at S.

| Key | Command and result |
| --- | --- |
| G | `git -C ROOT diff 975c8add eb3695fc`, read by file; `git -C ROOT rev-parse HEAD`; source reads and `rg -n`. Initial tracked/untracked status clean. |
| C | `Rscript ROOT/dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=S/cases`: exit 0, all 23 cases identical. |
| M | `Rscript ROOT/dev/bench/v0_2_3_ws4a/guts.R --base=HEAD --out=S/guts-corrected --guts=C1_drop_notional,C2_notional_from_rounded,C7_plan_on_skip,C10_skip_valuation_on_empty,C11_affordability_order,C14b_write_retained_view,C15_wrong_context_pos`: exit 0, seven expected failures and invalid-base refusal. |
| T | `Rscript S/tests.R`: `testthat::test_local(ROOT, filter='^(ws4a-carrier|availability-economics|cost-model|cross-asset-corrections|derived-state|execution-spec|fill-model|ledger-writer|release-coverage-branches|risk-fold|runner|sweep)$', reporter='summary', stop_on_failure=TRUE)`: exit 0; eight expected final-bar warnings. Covers every changed test file and the changed fixture helper's consumers. |
| P | `Rscript S/probe.R base`, then `Rscript S/probe.R candidate`: base library `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`; condition-order, validator, detector and compiled-effect probes below. Both exit 0. |
| U | `Rscript S/public-refusal.R base`, then `Rscript S/public-refusal.R candidate`: public synthetic snapshot/experiment/run, finite cost parameters; different refusal classes/messages (F1). Both probe processes exit 0. |
| X | `Rscript S/patches.R`: local function copies only; compiled-wrapper patch preserves ordinary buy/sell outputs and follows perturbed carried cash; rejection patch accepts the production witness and rejects both corruptions; extended D1 accepts production and catches a P3 callback. Exit 0. |
| E | `Rscript S/records.R`: both recorded A0 comparisons contain 295 PASS rows; independently reproduces D13 and D13b hashes on `953338df`; maintained harness R totals 2,022 lines. Exit 0. |

No timing, memory workload, real-data workload or full suite was run. T includes existing unit-level allocation assertions. Dense/A0/full-suite results beyond C/T are attributed to the implementer's records, not independent reruns. An initial M invocation used my incorrect abbreviated gut names; three expected failures preceded a harness error. The corrected invocation above completed. After every pkgload-using job, including that aborted run, executed `git -C ROOT checkout -- R/cpp11.R src/cpp11.cpp`. Git/R required owner-account execution past Git's sandbox ownership rejection; no Git configuration was changed. No tracked record was rewritten.

**F1 - blocking: refusal semantics and registered refusal oracles changed without decision (10) authority.**

Evidence: `R/fold-carrier.R:145`, `:334`; `R/fold-engine.R:159`; `R/cost-model.R:423`; `tests/testthat/test-fill-model.R:237`; `tests/testthat/helper-fixtures.R:154`; `tickets.yml:1342`; commands G/P/U.

P confirms the original Inf-quantity refusal is `ledgr_invalid_fill_input: \`desired_qty_delta\` must be a finite numeric scalar.` The replacement raises `ledgr_invalid_pulse_plan` at the typed fill/plan validator. The old NaN `next_bar$open` witness has been replaced with a dense matrix witness expecting `next_open_price`. The latter is the correct message for the base dense scalar-open path, but changing the exercised path does not preserve the registered bar-input witness. Section 5 row `test-fill-model.R:197` authorizes a batch migration preserving refusals; Section 9 does not accept these condition/fault-boundary changes. An as-built evidence sentence is not retrospective acceptance.

This is also observable through supported public calls: U buys 2 units at 10 with `ledgr_cost_chain(ledgr_cost_fixed_fee(1e308), ledgr_cost_notional_bps_fee(1e308))`. All supplied numbers are finite. The fee overflows. Base raises `ledgr_invalid_lot_fill: Invalid fill input for lot accounting.` Candidate raises `ledgr_invalid_pulse_plan: Invalid internal plan: fill: \`fee\` contains a non-finite value.` Validation has moved from accounting into planning. Normal-cost success cases cannot establish preserved refusal behavior.

Required repair: preserve the applicable base class, message, precedence and diagnostic fault stage at the typed boundaries; add base/candidate multi-error controls including arithmetic overflow and nonfinite target deltas. Restore the registered refusal witnesses, or obtain a separately stated accepted reason before changing them. Do not merely change expected conditions to the new failures. No isolated exact patch covers selection among quantity/open/epoch/cost/accounting failures and their stages. This is an implementation/migration defect within the accepted preservation rule, not a request to redesign costs.

**F2 - blocking: the compiled wrapper ignores P3's effects.**

Evidence: `R/compiled-spot-fifo.R:156`, `:167`, `:190`; `src/spot_fifo.cpp:268`; `R/output-handler.R:768`; `tests/testthat/test-ws4a-carrier.R:1520`, `:1823`; commands G/P/X. P changes a fill's carried `cash_delta` by 1: canonical payload follows it, but the complete compiled return is identical before/after. The wrapper never reads either effect column; native code derives both again and its result feeds cash and publication. D8's runtime witness uses a canonical availability sweep, not the compiled opt-in. Counting R calls to the delta helper cannot detect native recomputation.

LDG-3166 explicitly includes the compiled wrapper among migrated consumers. Preserve the frozen native accounting calculation as required by synthesis 3.4, but use the carried effects at the wrapper's output boundary. Exact local product patch, verified by X on ordinary buy/sell rows and a carried-effect perturbation:

```diff
   batch$positions <- as.numeric(batch$positions)
-  batch$cash <- as.numeric(batch$cash[[1]])
+  batch$cash_delta <- fills$cash_delta
+  batch$position_delta <- fills$position_delta
+  batch$cash <- ledgr_cash_scan(state$cash, fills$cash_delta)[[n]]
```

The existing empty-batch return guards `[[n]]`; the shared scan preserves scalar cash-addition order. Native lot positions remain authoritative. Add a compiled production publication witness that follows perturbed carried effects and fails if the wrapper again substitutes native effects; verify ordinary multi-fill/reversal parity and append ordering. This patch does not remove or change the explicitly frozen C++ calculation, and is not a claim that native arithmetic invokes the R helper.

**F3 - blocking: V-plan and V-rejection prove less than their registered invariants.**

Evidence: `R/fold-carrier.R:244`, `:262`; `test-ws4a-carrier.R:1606`, `:1612`, `:1643`; design note F4.34/O3.46; command P. The constructor accepts (i) an empty plan declaring CASHFLOW or DISPOSITION, and (ii) an affordability rejection with its resolved price or execution epoch replaced by `NA_real_`. Tests check only FILL on an empty plan and a missing rejection position. They do not prove “empty plans declare no kinds” or “only unresolved price/absent opportunity NA.”

Exact additive product predicates inside `ledgr_carrier_problem()`: in the `plan` arm, after validating both child groups and before the FILL-kind consistency check, add:

```r
if (length(x$fill$k) == 0L && length(x$rejection$k) == 0L && length(kinds) > 0L) {
  return("an empty plan declares economic event kinds")
}
```

In the `rejection` arm, after validating its segments/primary and before the positive-price check, add:

```r
if (any(is.na(x$resolved_price) != (x$emit == 1L))) {
  return("resolved-price missingness disagrees with rejection phase")
}
if (any(is.na(x$exec_ts) != (x$primary == 1L))) {
  return("execution-epoch missingness disagrees with opportunity")
}
```

The first patch was exercised in P; X exercises the rejection patch on the actual planner witness. Add separate controls for all three empty-kind codes, both late-rejection missing fields, and impossible present values on final-pulse rejections. Preserve valid early missing-bar rejections and the base's deferred epoch refusal: do not impose a blanket epoch rejection on rows that never reach fill construction. These checks use existing phase/reason evidence and introduce no new carrier field.

**F4 - blocking: D1 and D8 leave concrete holes in the promised production predicates.**

Evidence: `tests/testthat/test-ws4a-carrier.R:1699`, `:1800`, `:1874`; design note Section 6 D1/D8 and Section 8 row 3166; commands G/P/X. D1 omits `ledgr_fold_stage_plan` despite the registered P3 scope. D8 reports zero hits for an injected inline `cash_delta <- -(fill$qty[[i]] * fill$price[[i]] + fill$fee[[i]])` in the payload: its static check recognizes the shared helper name, and its runtime counter also sees only that helper. This repeats WS12's “named helper present/absent is weaker than the claimed operation” failure pattern. F2 is an actual effect-provenance gap hidden by that limitation.

Exact D1 scope patch: add `"ledgr_fold_stage_plan"` to `ws4a_d1_planners`; add an own control injecting `rows <- vapply(seq_along(fill$k), function(i) fill$qty[[i]], 0)` there. X verifies production has no hits and this control has a hit. P4/publication list removal remains LDG-3167's responsibility.

For D8, retain the existing controls and add inline arithmetic detection in the named consumer regions plus a production handoff witness of the carried effects, including compiled publication. Its own inline-recomputation control must fail even when ordinary arithmetic produces identical numbers. No exact complete detector patch is supplied: the current callback/count predicate needs a substantive extension, not another helper-name ban.

**F5 - blocking: two existing fill-model tests lost their registered input/value witnesses.**

Evidence: `tests/testthat/test-fill-model.R:87`, `:140`; design note Section 5 rows `:59` and `:96` (`ws4a_carrier_design.md:744`); commands G/T. The former one-row proposal test used quantity 10 and OHLCV `100/101/99/100.5/100000`; its replacement uses a new multi-session fixture with different values and no corresponding original quantity/side witness. The matrix-backed test used SELL 5 and `101/102/99/100.5/100000`; the replacement checks side/quantity/open mapping but drops high/low/close/volume assertions. Both registered migrations explicitly retain original values and require corruption of every projected bar field to fail. Retiring S3 shape assertions does not retire those claims.

Required repair: retain the new coverage additively, and restore the original numerical/side/instrument/OHLCV witnesses at their typed or frozen context boundaries, with each registered corrupt-field control. If a field is deliberately no longer carried by the dense planner, locate its surviving boundary assertion or obtain an accepted reason to retire that particular claim. No evidence establishes an authorized exception; no inference about author intent is needed. The changed setup/oracles exceed the accepted migration allowance even though T passes.

**O1 - optional: make the condition reference and P1 boundary census precise.**

Evidence: `R/condition-reference.R:23`; `ws4a_carrier_design.md:250`; `R/fold-engine.R:559`, `:568`; commands G/P. Replace the three Fill seam classes prose lines with: “`ledgr_invalid_fill_proposal` and `ledgr_invalid_fill_context` are raised at the internal batch cost-resolver seam for misaligned side/quantity columns and execution-price columns, respectively. They remain stable top-level classes for tests of that seam.” Regenerate the corresponding Rd text when making that documentation edit. In the census row label replace “Settlement, terminal and stop paths in P1” with “Settlement, terminal, stop and freeze-transition diagnostic paths in P1”. The existing whole-P1 boundary contains these freeze-entry/exit name reads; naming them avoids implying all non-settlement reads are already positional.

**Answers to implementer-flagged items**

| Item | Assessment |
| --- | --- |
| (a) Resolver order | P reproduces base first-row short refusal versus candidate second-row resolver error. No exported resolver/spec/fold injection API exists; public experiment normalization rejects a function cost model with `ledgr_invalid_cost_model`. Built-in steps return columns without callback errors. The changed custom internal seam is covered by the accepted batch-call migration, not evidence of a public custom-resolver regression. The separate public overflow refusal is F1. |
| (b) Seam classes | Same semantic categories: malformed proposal-side versus execution-context input at the internal cost seam; the batch representation is authorized. Names survive, representation-specific messages change, public model validation does not. Documentation still describes deleted objects (O1). This does not justify unrelated quantity/accounting refusal changes. |
| (c) NaN/Inf migration | Not authorized as implemented; changed witness/path, message and Inf class/fault boundary. F1. |
| (d) Dense rejections | Within synthesis 3.3/Section 4: dense joins at decision and emits the common plan. Final-pulse and non-positive resolved-price rejections remain internal; P3 emits their diagnostics only on availability. Warning count/text and ordinary public outputs are preserved by inspected code, C/T and attributed dense/A0 evidence. |
| (e) Extra decision fields | Both authorized: `context_pos` is the Section 3.1 bridge (identity on dense), and `intent_reason` is explicitly in Section 4 with Section 3.2 placement preserved. No new public state normalization. |
| (f) D13b | Legitimate additive base-derived record. E independently reproduces both the original four-function D13 hash and the three-function D13b hash on 953338df; historical row values are unchanged. Dropping the planner was pre-authorized by Q1/D13. T executes the builder-edit control, which still fails the hash comparison. |
| (g) P1 named reads | Justified transitional boundary at function level: provider/valuation and corporate-action/terminal semantics stay intact; no named provider view crosses to P2/P3. Freeze-transition diagnostics also read named planes, so use O1's census precision. Conversions are once per produced view, including re-observation after dispositions; retained-view C14b and its gut pass. |

**Acceptance and economic assessment**

LDG-3165 substantially implements its five acceptance items: separated observation/execution, one strategy normalization, missing-target refusal, successful ordinary oracles and attributed full suite. Its owned V-packet/V-decision, F4.19, D3/D4/D5/D12d/D13/D16/D21 and O3.28 controls execute in T; E validates D13 provenance. The production code retains the E risk-plan validation and dynamic risk/short checks. Runtime totals in D4/D16 establish counts on their fixtures, not a universal proof of every possible per-pulse/per-view distribution.

LDG-3166 acceptance 1 is implemented in the inspected planners; its detector needs F4. Acceptance 2 is incomplete (F1/F2/F4). Acceptance 3 (M4), 4 (chained costs/rounding), and ordinary case portions of 5 pass C/M. Full-suite/dense/A0 results remain supported by the recorded executions. Section 8's V-plan/V-rejection and migration obligations are incomplete (F3/F5). No pending 3167/3168 publication batching, diagnostic buffer or equity work is counted as a present defect.

Cost steps keep compiled order; notional fees use spread-adjusted unrounded price and final rounding stays last. Affordability retains the cash-generating/unblocked first partition and radix stable-ID order, its sequential cash scan, private permutation/mask, and compaction into decision order. Early rejections precede affordability rejections, each in original decision order. Reason segments stable-sort by row, deduplicate first occurrence, and preserve blocking/planner/informational order. Both reconciliation expressions remain `sum(fill$cash_delta)` in fill order (`fold-engine.R:1234`, `:1481`), with the original tolerance. Planned positions feed diagnostics; P4 installs book net positions. C/M/T substantiate these ordinary economic claims; F1 bounds the refusal claim.

Empty and skipped production plans have typed empty columns and no kinds; scheduled skips bypass both strategy and planner while keeping P1/P4/P5. Constructor coverage is weaker (F3). E prepares epoch validity once; planners preserve first-required-use timing for the exercised base cases, including epoch-before-short and dense first-open/epoch/later-open order. No per-fill timestamp parsing remains in either planner.

Canonical handler, payload, db_live sink/writer and P4 read carried effect columns without rebuilding fill intents. Their metadata field order, live transaction choice, per-fill append, per-pulse flush, sequence/fact order and output boundaries are unchanged in the diff; C8/C13/C14 cases and migrated writer tests pass. Compiled input is columnar but effect provenance is F2. The native implementation and opt-in guard remain unchanged.

**Seven-shapes walk and cold read**

Scope: every changed function in `fold-carrier.R`; both planners and affordability; fold warning/kind gate, P1, skip decision/plan, P2-P5 and E; cost resolver factory/resolution; risk application/post-risk validation; fill payload/row, live writer/input check, handler/live sink fill methods; compiled batch wrapper. Also traced existing publication buffers, replay/readers and deleted fill/timestamp helpers' callers. No reader implementation changed in this diff.

| Shape | Result over that scope |
| --- | --- |
| Per-row frames/lists | Planner candidates/reasons/effects are columns. Public context frames remain boundary work. Existing publication-result/event/leg lists remain explicitly owned by 3167; metadata by WS8. |
| Table subset per ID | Planners use context/run ordinals and gather once; no new per-ID table scan. P2 retains existing public feature filtering. P1 named boundaries are described above. |
| Per-element parse/format | Epochs prepared in E; no per-fill planner parsing. Existing scalar output materialization remains at publication until its batching ticket. |
| Repetitive JSON | Existing metadata, intent, stop detail, reconciliation and state serialization routes retained; no new JSON path introduced. |
| Recomputed/discarded work | Canonical effects shared; duplicate target normalization removed. Compiled effect reuse incomplete (F2). Fixed-field validation is construction work; publication checks are the retained input boundary. |
| Quadratic validators | Vector length/type/bounds, sorting and duplicate/segment checks; no pairwise validator introduced. Missing predicates are F3, not a complexity defect. |
| Environment-held scalar writes | New plan/mask/segment vectors are local values. P4 still installs one lot result per fill as explicitly permitted through 3166. Existing staging/equity ownership awaits 3167/3168. |

New data-growing loops have stated reasons: affordability's ordered dependent cash scan (`availability-economics.R:344`) and one warning per actionable final-bar target (`fold-engine.R:152`). P4's indexed scalar bridge (`:1374`) is expressly temporary. Code-segment text iterates bounded dictionary ranks (`fold-carrier.R:434`); schema-field/part and cost/risk-step loops are not data-scale loops. P1's metadata/stop callbacks and P2's scalar stale-risk `all.equal` callback are inherited semantics, not newly introduced traversal. No new unjustified growing-collection loop found.

P1 reads availability current/next bars, settles corporate actions, processes scheduled and lifetime dispositions with re-observation, values in run order and records equity. It emits a context-axis decision packet, current-only decision data with row-and-pulse locator/history handle, and a separate run-axis execution packet. Dense observation/context remains on its frozen path. E sends only observation to P2 and removes decision data before P3.

P2 builds the public context from current data, invokes the strategy, validates intent and normalizes the complete named target vector once. Availability admissibility/mark gates precede risk; risk transforms preserve the context axis, followed by finite-value and short-exposure checks. It returns raw state update, intent, strategy/post-risk quantities, ordered actionable ordinals and their run-axis bridge. It does not consume the private execution packet.

P3 gathers one row per actionable ordinal, reads the private execution packet/provider execution service (dense reads the next matrix column), resolves vector costs and computes effects. Availability applies restrictions and the ordered cash scan; both producers construct typed fills/rejections and kind declarations. P3 gates accounting kinds and, on availability, reconciles and stages diagnostic columns with decoded reasons. P4/P5 consume the batch. These stages are explainable from code and carrier contract; the failures are enforcement/provenance/migration gaps, not an unintelligible representation.

**Evidence truth and independent input challenge**

Stable pointers are ticket labels plus immutable product/evidence commits: LDG-3165 `33331be8`/`ede8e70a`, LDG-3166 `9b13eb3c`/`eb3695fc`. The two `records/ldg316*/README.md`, `sequence.log` and `a0-compare.csv` resolve. E verifies their A0 counts and harness budget; C/T/M independently confirm the permitted subset. The explicit test-block labels remain better pointers than shifted historical line numbers.

LDG-3165 evidence lines for acceptance 1-3, ordinary oracle outcomes (4), recorded suite (5), and its Section 8 controls are supported within their stated fixtures. Its migration line is supported for risk shape/value normalization and mode-census removal. LDG-3166's recorded cost/M4/oracle/suite outcomes are supported; acceptance 1's structural coverage is incomplete (F4), acceptance 2 overstates universal effect reuse (F2/F4), its Section 8 line overstates F4.34/empty-plan validation (F3), and its migration line's claim that refusals keep classes is false (F1), with additional lost witnesses (F5). Correct these evidence claims after repair rather than treating passing counters as acceptance.

Independently, the accepted positional carrier is an appropriate boundary: explicit context/run axes remove repeated name recovery, separation removes P2's next-bar payload, and the base differential shows ordinary economics survive vector planning. The prescribed violating controls and condition comparisons are essential complements to frozen successful outputs; this review found failures precisely where tests asserted narrower claims. Reusing carried effects at the compiled wrapper boundary is compatible with preserving the native kernel as an unchanged accounting oracle. None of these repairs requires a second engine, a new execution-mode branch, new provenance, relaxed oracles or a reopened maintainer decision. Only this review file was added; no commit was made.
