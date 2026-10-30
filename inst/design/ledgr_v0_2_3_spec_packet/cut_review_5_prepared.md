# Cut 5 prepared-cut independent review

- Reviewer: Codex, independent clean-context reviewer; author of neither the cut, preparation nor earlier reviews.
- Date: 2026-10-30.
- Mode: Type 1 against the accepted synthesis, earlier reviews and completed preparation; Type 2 limited to whether implementation still needs a new maintainer decision. Maintainer-owned brief, drafted by Claude.
- Reviewed commit: `4759d2530c152dfaf8d76784e27ac2832f8dda72`, branch `release/v0.2.3`.
- Verdict: **PASS_AFTER_PATCHES**.

The preparation supports acceptance, but the current brief needs the exact reconciliations in findings 1-2. Those patches suffice without another review. No new architecture, threshold, memory-metric or workstream decision is required. Acceptance remains the maintainer's action; this review does not start LDG-3164.

Citation keys: `T` = this packet's `tickets.yml`; `N` = `ws4a_carrier_design.md`; `M` = `macro_plan.md`; `S` = `inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md`; `W` = `dev/bench/v0_2_3_ws4a`; `P` = `dev/bench/timing/protocols/ws4a-timing-1`. Lines refer to the reviewed commit. Patches below are instructions for later correction, not changes made by this review.

## 1. Required: reconcile current preparation status and incorporate its settled deviations

Evidence: `T:323-339` still promises future private controls and says the protocol, cases, memory method and detector controls do not exist. `T:469-473,506-509` describes preparation without recording its completion. This disagrees with the completed tickets and evidence at `T:1109,1150-1156,1160,1189-1196`. `N:17-18,731-745,766-775,796-802` retains pre-preparation status, including an unresolved acceptance blocker and the old estimate/budget. The timing implementation's settled details are in `N:712-724`, but decision (4) does not explicitly incorporate them. Decision (5) retains its original peak-live proposal before the explicit supersession at `T:406-418`.

Why it matters: decision (9) and macro rule 11 require surprises to be settled in the operative cut. An implementer should not have to decide whether to repeat completed preparation, recover unretained clocks, enforce the withdrawn metric or obtain another disposition. The historical rejections remain useful evidence; they should be labelled as history rather than current requirements.

Exact patches:

- In `T.measured_input`, replace the sentences from "Before acceptance, LDG-3163 records these paths" through "positive and negative controls" (`T:323-328`) with:

  > LDG-3163 completed this registration and its controls. The stable value-free pointer is dev/bench/v0_2_3_ws4a/records/realdata.md; the private command and identity record is E:/ledgr-data/reference/v0.2.3-base-953338df/EVIDENCE.md. The unchanged w2_minvar rerun was IDENTICAL (exit 0); the cost-mutant comparator DIFFERS (exit 1), with the snapshot hash unchanged. The reference is ready to gate a freshly installed candidate.

- Replace the final sentence beginning "The new timing protocol" (`T:336-339`) with:

  > LDG-3162 and LDG-3163 are complete. The accepted design gate is ws4a_carrier_design.md, with its recorded third-round maintainer disposition. The protocol is frozen in dev/bench/timing/protocols/ws4a-timing-1/; base case, gut, mutation, detector, memory and timing-smoke records are in dev/bench/v0_2_3_ws4a/records/, indexed by LDG-3163's evidence below. All 23 base cases reproduce; 34 guts and M1-M12 have their expected failures. All 30 detector rows have the expected base outcomes and passing own controls. D2, D16, D18, D22 and W1 have tested predicates but production attachments deferred to their named implementation owners; they are not claimed as production PASSes. C13b is the specified new candidate-atomicity assertion, not a base identity claim. The timing smoke covers all sixteen cells; the base absolute marginal is 215.05-216.95 us/fill and is expected to fail the 40 us bound. Decision (9) now awaits the prepared-cut review's required patches and maintainer acceptance, not another preparation run.

- Append to decision (4):

  > The recorded timing deviations in ws4a_carrier_design.md Section 7 are incorporated: the matched untimed durable run supplies the fill denominator, with the registered repetition checks; wide_total and nofill_total are returned clocks but are not persisted by the unchanged shared harness; reader cells use the availability run; run and sweep cells perform their registered untimed warm-up; and the marginal cell also has a 1.00 ratio bound. The frozen base record is the functional and quiet marginal smoke, not an A/A window. These details do not change any bound.

- Replace decision (5), up to but not including "(6) Replay" (`T:393-418`), with:

  > (5) Memory: both producers' 500 x 1260 wide sweeps must allocate no more cumulative explicit-size Rprofmem bytes per actual fill than their recorded base. The 5,000 x 252 wide and deep-book workloads measure forward execution and replay separately; the deep case has 250 instruments consuming 15 live lots. The gated metric, settled by the maintainer on 2026-10-30, is peak R heap, sum(gc()[, "max used"] * c(56, 8)) in a fresh child after gc(reset = TRUE) at the phase boundary, at most 1.10 x the matched base median. It covers only the R heap and includes garbage awaiting collection; it is not peak live memory. The five repetitions, default collection policy, phase boundaries, frozen control sizes and base values are registered in dev/bench/v0_2_3_ws4a/records/memory/ and memory.R. Validation found spread at most 0.6%, every independently allocated live-storage control breached (1.18-1.44 x), and pointer aliases did not breach. The earlier process peak-commit method failed validation (range/median up to 0.15; one unchanged run at 1.13 x its median) and remains observational only; method.md preserves the rejection. The frozen replay memory budget applies at LDG-3164 and LDG-3169.

- In `T.sequencing`, replace the pre-acceptance preparation sentences at `T:468-473` with:

  > Pre-acceptance preparation (decision 9) is complete: LDG-3162 fixes the reviewed design and obligation register; LDG-3163 supplies the frozen protocol, reproduced case records, validated memory method and exercised detector controls. The subsequent prepared-cut review and maintainer acceptance remain the implementation gate.

- In `T.review_lifecycle`, replace `T:506-509` with:

  > LDG-3162's independent design-review chain closed at PASS_AFTER_PATCHES, with N6, N7, O1 and O2 applied under the recorded third-round maintainer disposition. LDG-3163's review chain closed at PASS_AFTER_PATCHES with its exact N1 memory-integrity patch applied. Both tickets are complete. The subsequent independent prepared-cut review is cut_review_5_prepared.md (4759d253, PASS_AFTER_PATCHES); its required corrections precede maintainer acceptance. An open Type 2 question would still block acceptance.

- In `N:17-18`, replace "It is a checklist; the records it calls for do not exist until LDG-3163 builds them" with "It is the implementation checklist; LDG-3163 has completed the base records indexed by its ticket evidence and dev/bench/v0_2_3_ws4a/records/."
- Label `N:731-745` with the prefix "**Historical memory proposal, superseded by the maintainer settlement below.**" and change "Memory-method validation is unresolved and blocks cut acceptance" to "At the design-note review, memory-method validation was unresolved and blocked cut acceptance". Preserve the rejected method and its reason.
- Replace `N:766-768`, starting "LDG-3163 must show", with "LDG-3163 recorded an unchanged w2_minvar rerun as IDENTICAL and the ledgr_cost_notional_bps_fee(1) scratch mutant as DIFFERS; see dev/bench/v0_2_3_ws4a/records/realdata.md."
- Label `N:770-773` "**Historical budget estimate at LDG-3162**"; append after `N:775`: "Current maintained R totals 1,963 lines, including the base detector script and protocol workloads, against decision (12)'s 2,000-line limit; package tests remain outside that stated path budget. The earlier 1,400/1,500 figures are historical." Keep the historical LDG-3162 evidence at `T:1155`, but append to it: "This is the design-gate estimate at af5f6fb8; LDG-3163's completed record supersedes it: 1,963/2,000 lines and a validated peak-R-heap method."
- Replace `N:796-802` with:

  > The design gate and LDG-3163 base preparation are complete, subject to the prepared-cut review's corrections before acceptance. Their review chains and results are recorded in tickets.yml. No semantic change beyond the synthesis and the explicit maintainer settlements is authorized. The shape and fault-timing changes listed below require acceptance with this cut; other proposed weakening of fixtures, fault boundaries or oracles returns through governance.

## 2. Required: make the consumer census retain LDG-3165's complete handoff

Evidence: `T:1246-1251` expressly migrates every P3/P4/P5/E read of the new observation/decision in LDG-3165, preserving downstream algorithms until their owners. However, `N:115,119,122,124` assigns E58 and E67 to 3166 and splits E62/E65 into 3165 production versus 3166 consumption. Actual P3 reads the old decision fields and mixed observation at `R/fold-engine.R:1054-1066,1094`; P5 reads old valuation/target fields at `R/fold-engine.R:1458-1480`. This is the producer-only handoff problem of earlier cut-review F2 reappearing in the preparation census, not a new design question.

Why it matters: following those rows literally leaves 3165's consumers broken or requires reconstructing the old interface to pass its full-suite gate. The cut already chooses the remedy. Distinguishing interface migration from later planner arithmetic preserves the accepted ticket grain.

Exact patch: change only the Ticket cells of these `N` rows:

| Row | Replacement Ticket cell |
| --- | --- |
| E58 | `3165 (observation-interface read); 3166 retains ownership of the plan/effects reconciliation change` |
| E62 | `3165 (produce and migrate the P3 input read); 3166 (typed plan construction)` |
| E65 | `3165 (produce and migrate the P3 decision read); 3166 (typed plan construction)` |
| E67 | `3165 (decision-interface read); 3166 retains ownership of the plan/effects reconciliation change` |

Append after the Section 1.3 table:

> LDG-3165 completes all consumers of its changed observation and decision groups, including P3, P5, E, skips and stops. These interface reads do not wait for LDG-3166. The existing planning and reconciliation algorithms remain until LDG-3166 changes their plan/effect representation; no mixed next-bar observation is reconstructed for P2.

## 3. Optional: state how the base detector census becomes per-ticket gates

Evidence: `W/detectors.R:64-67,104-108` deliberately scans later-stage P2/P3/P4 code on the base, including P4's scalar lot-call loop. That is valid baseline evidence, but `T:1210-1211,1285-1288` permits scalar P4 calls through LDG-3166. `N:673,783-788` scopes the actual D25 obligation to the kernel and assigns other detectors by ticket. Likewise `N:662` already excludes the dense planner from the eventual D13 frozen set. The authoritative scopes are sufficient; one explicit handoff would prevent treating the base script's expected-failure exit code as a final product verdict.

Exact patch: append after `N:792`:

> detectors.R certifies base outcomes, not implementation completion. Each owning ticket installs its applicable predicates and controls in test-ws4a-carrier.R and requires production PASS for those regions. At LDG-3164, D3 covers the kernel and migrated book consumers, and D25 covers the typed lot operations, excluding the P4 scalar caller allowed until LDG-3167 and replay while decision (6) permits singleton calls. Later owners add their stage regions; production attachments may not remain NOT_EVALUABLE at their owning ticket's close. Preserve the historical baseline record.

## Preparation and acceptance assessment

| Obligation | Evidence and assessment |
| --- | --- |
| Unchanged product base | Independent `git diff 953338df -- R src tests NAMESPACE DESCRIPTION man` is empty. `W/records/base.txt:1-5` identifies original and supplemental recordings. No product result is inferred from documentation acceptance. |
| Existing exact oracles | `T:301-328` records A0 295/0 and nine dense arms, plus six real-data comparisons with the previously decided seed marker difference. `W/records/realdata.md:9-58` supplies the fresh positive/negative control record. Existing A0/dense/private workload executions were not repeated here; the private evidence/library/state paths exist. |
| New cases and mutations | Independently reran `check.R`: 23 cases identical. `W/records/gut_results.csv:2-36` records 34 expected failures and invalid-ref refusal; `mutations.csv:2-13` maps every M1-M12. Full mutation runs are reviewed recorded evidence, not newly rerun claims. C13b's actual typed fault remains LDG-3167 work (`N:545-547`), with its equality/changed/missing-field predicate controls already exercised. |
| Detectors | Independently reproduced all 30 rows and their controls. The five NOT_EVALUABLE attachments are explicit (`W/records/detectors/baseline.csv:27-31`), have tested predicates and named owners. They do not leave the required semantics to implementation. |
| Timing | `P/matrix.csv:2-17`, `thresholds.csv:2-17` freeze sixteen cells, eight pairs and the prescribed bounds. `P/protocol.md:113-139` records the smoke and expected absolute base failure. All twelve absolute-checker self-tests passed independently. Recorded timing deviations are preserved; macro rule 12 requires no new A/A window. |
| Memory and budget | Independent summarize reproduces all four cells: spread <=0.005877, controls 1.183-1.443 x, aliases <=1.004 x. The exact missing-column patch is present at `W/memory.R:203-208`; `ldg3163_review_rereview_1.md:38-53` records its negative controls and 1,963-line final count. Metric, control sizes and 2,000-line limit remain as decided. |

Thus the evidence obligations of decision (9) are discharged to the stated base/typed distinction. Its cut-text reconciliation obligation and macro rule 11 are not fully discharged until findings 1-2 are applied. No new timing, memory or real-data workload is needed for those corrections.

| Remaining ticket | Can it close without another design decision? |
| --- | --- |
| LDG-3164 | Yes: one book/kernel, every external consumer, construction/ownership tests and replay gates are fixed (`T:1204-1224`, `N:783`). Singleton versus consecutive blocks is the already-decided evidence branch in decision (6), not discretion to choose a different budget. |
| LDG-3165 | Yes after finding 2: axes, dictionaries, locators, normalization, all consumers and retained-view isolation are specified (`N:184-249,784`). |
| LDG-3166 | Yes: both planners, ordered affordability/costs, publication-effect reuse, compiled and live-writer input migration are fixed (`T:1261-1291`). The prior re-review's N1 repair is intact. |
| LDG-3167 | Yes: block ordering, candidate-error versus append/flush boundaries, event/leg ownership and typed controls are fixed (`T:1300-1319`, `N:545-550,674`). No full private rollback is promised. |
| LDG-3168 | Yes: capacity formula, stop ownership, used prefixes, both equity writers and producer-based finalization are fixed (`N:251-265`, `T:1328-1344`). |
| LDG-3169 | Yes: full gates, identity declarations, contract/NEWS promotion, source identity and the independent cold read are assigned (`T:1353-1367,518-523`, `N:521,788`). A failed performance gate remains open; it cannot become PASS through an exception. |

Earlier cut-review findings remain resolved in the cut itself: F1's acceptance gate is retained; F2's consumer/validator ownership and handler/live-input repair are retained but need the census correction above; F3's metadata/retained-output allowances remain; F4's individually reasoned test migrations remain (`N:556-640,804-810`); F5-F6 retain separate absolute/ratio, both-producer and replay gates; F7 is explicitly settled by the maintainer's peak-R-heap decision; F8 prohibits a post-failure timing waiver; F9 has registered real-data inputs/controls; F10 preserves final tested identity. The LDG-3162 third-round disposition is honored, not reopened.

No further scope contradiction was found. Q1 remains dense-from-decision; Q6 assigns both equity representations to WS4a. The macro's WS4b amendment explicitly moves P4 to WS4a (`M:222-228,255-261`), matching `S:65-69,231-240` and LDG-3168. The two workstreams and their acceptance dependency agree (`T:465-481,580-593`). Routes to WS4b/WS5/WS6/WS7/WS8 and the compiled-envelope RFC remain deferred (`T:482-496`, `N:481-502`, `S:378-392`). Stable contract anchors consulted: `contract-execution-fold-core`, `contract-execution-event-staging`, `contract-execution-compiled-accounting`, `contract-execution-decision-and-fill-contexts`, `contract-execution-cost-model`, and `contract-availability-affordability` in `inst/design/contracts.md`.

## Independent execution record and limits

Read the cut, note, synthesis, macro, earlier review chains, relevant contracts, scripts and records before executing checks. Actual commands used absolute paths and `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe`. Below, `ROOT` abbreviates `C:/Users/maxth/Documents/GitHub/ledgr`, `TMP` abbreviates `C:/Users/maxth/AppData/Local/Temp/ledgr-cut5-prepared-4759d253`, and `LIB` abbreviates `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`.

| Command | Exit/result |
| --- | --- |
| `Rscript ROOT/dev/bench/v0_2_3_ws4a/check.R --out=TMP/check` | 0; 23 identical cases |
| `Rscript ROOT/dev/bench/v0_2_3_ws4a/detectors.R --lib=LIB --root=ROOT --out=TMP/detectors` | 0; frozen.csv copied to scratch first; 30 expected outcomes, every own control TRUE |
| `Rscript ROOT/dev/bench/v0_2_3_ws4a/memory.R --mode=summarize --lib=LIB --scratch=TMP/empty-memory --records=TMP/memory` | 0; committed memory records copied to scratch first; four validated cells, no workload/preparation run |
| `Rscript ROOT/dev/bench/v0_2_3_ws4a/timing_absolute.R --self-test` | 0; twelve expected results |
| `git -C ROOT checkout -- R/cpp11.R src/cpp11.cpp` after each pkgload-bearing command | Restored; initial index.lock sandbox denial resolved by authorized escalation |
| `git diff --no-index` on each regenerated detector/memory CSV versus its committed counterpart | Only checkout CRLF versus emitted LF differs; `--ignore-space-at-eol` exits 0 for both |

No timing windows, memory workloads, real-data workloads or full package suite ran. No vendor data was printed. No tracked record was rewritten. Only this review file is added; no commit. Review accounting: one independent prepared-cut review, two required Type 1 reconciliations, one optional clarification, zero new Type 2 decisions.
