# Cut 5 independent review

- Reviewer: Codex, independent clean-context reviewer; did not draft the cut.
- Date: 2026-10-30.
- Mode: Type 1 against the accepted typed-carrier synthesis; Type 2 on ticket grain, dependencies, oracles and gate falsifiability.
- Reviewed commit: `95a838c4d96964e44fa13d49ba4507f5013323cd`, `release/v0.2.3`.
- Verdict: **CHANGES_REQUIRED**.

The direction is faithful: one canonical lot implementation, both producers joining at the normalized decision, unchanged accounting/publication semantics, and the deferred WS4b/WS5/WS7/WS8 work remain recognizable. The cut is not yet an acceptance-ready implementation brief. Its measurement preparation happens after the proposed acceptance point, several ticket boundaries lack their necessary consumer migrations, and some gates either reject required behavior or do not measure their stated claim. These are cut repairs within the accepted direction, not a request to reopen that direction.

Citation keys below: `tickets.yml` and `macro_plan.md` are in this packet; `S` is `inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md`; `Phase` is `inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md`. Line numbers refer to the reviewed commit. Each quoted patch is replacement text for the named field or named portion of that field; the findings must be applied together.

## Required findings

### F1. Acceptance precedes the evidence and decisions that acceptance requires

Evidence: `S:329-355,373-376`; `macro_plan.md:66-70`; `tickets.yml:327-331,381-384,403-413,1025-1072`. LDG-3162/3163 are future tickets that will choose locators, dictionaries, capacity, detector predicates, cases, workload details and measurement protocols. Waiting to implement LDG-3164 is weaker than settling these before accepting the cut. LDG-3162's acceptance also permits an open Type 2 checkpoint instead of a passing design review. Its Section 4 consumer map and Section 5 case census do not themselves establish a unique owner for every bound clause, Section 8 route and Section 9 failure scenario. In particular, construction/alias invariants and the independent closing cold read need explicit owners, not an implementer's inference.

Why it matters: the reviewer cannot approve an unwritten detector, unknown memory instrument or unresolved capacity formula as a checkable gate. A future implementation checkpoint does not satisfy macro rule 11.

Exact patch, replace cut decision (9) and the opening of `sequencing` through the implementation gate:

> Drafting gate: LDG-3162 and LDG-3163 are pre-acceptance preparation and change no product code. Cut 5 remains draft until both are complete, every proposed oracle/checker has been exercised on the unchanged base with its expected baseline outcome recorded, thresholds and detector controls are frozen, and every surprise is settled in this cut. A subsequent independent cut review must pass before LDG-3164 starts. An open Type 2 question blocks acceptance; it is not a completed acceptance item. The serial product sequence is LDG-3164 through LDG-3169 after that gate.

Exact patch, replace LDG-3162 scope (c), its corresponding acceptance item and the final design-review acceptance item:

> Obligation register: enumerate every bound clause in synthesis Sections 2-5, every Section 8 route and every Section 9 scenario. Each indivisible obligation has exactly one implementing ticket, affected producers/consumers, an oracle or detector, and a failing control; cross-references do not create another owner. LDG-3164 owns lot/import/replay/compiled-book ownership; LDG-3165 owns observation/decision alignment and retained-view isolation; LDG-3166 owns plan ordering and effects; LDG-3167 owns candidate/publication failure boundaries and publication-buffer isolation; LDG-3168 owns diagnostic/equity prefixes and stop handling. Each owner validates the groups it introduces. LDG-3169 owns final route verification and an independent cold reader's explanation of each changed stage from code and the carrier contract. All seven Section 9 scenarios are named cases. Acceptance requires a complete, reviewed register, no unresolved design question, and a passing design review; the pre-acceptance cut review follows LDG-3163.

### F2. Producer-only tickets cannot promise green consumers without explicit handoffs

Evidence: `tickets.yml:1082-1096,1106-1119,1129-1164,1188-1192`; `R/fold-phase-contract.R:90-114`; `R/fold-engine.R:1094,1293-1314,1342-1399,1418-1466`; `R/compiled-spot-fifo.R:168-247`; `S:89-107`. P4/P5 still consume list plans and old observation/decision fields; the compiled wrapper consumes fill objects. LDG-3166 deletes their producing representation, but compiled column input is assigned to LDG-3167. The old fold validator requires named positions, while comprehensive retyping validation is postponed to LDG-3168. Merely promising a later adapter map does not specify which green ticket does this work.

Why it matters: the implementer must enlarge earlier tickets, restore deleted per-fill objects, or leave intermediate tests red. Those are materially different ticket grains.

Exact patch, append to LDG-3164 scope:

> This ticket also retypes fold positions, names the E/import/result boundary adapters, and updates construction and E/stop validation for the new positions and book, including types, exact lengths, segment bounds and run-axis mapping. It preserves ordinary copy-on-modify isolation across every migrated book consumer. It does not defer these validators to LDG-3168.

Exact patch, append to LDG-3165 scope:

> Migrate every P3, P4, P5 and E read of the changed observation/decision interface in this ticket, including scheduled-skip and stop paths, and validate each new group at construction. Preserve downstream economic algorithms until their owning ticket. No consumer reconstructs the old mixed observation containing next bars for P2.

Exact patch, append to LDG-3166 scope and remove the compiled-column-input assignment from LDG-3167:

> Migrate P4/P5 plan readers and the compiled wrapper's input to the fill/rejection columns here. An indexed scalar application loop may remain until LDG-3167, through the single typed lot implementation. It must not recreate a list or S3 object per fill. LDG-3167 owns candidate batching and indexed event/leg publication, not this interface migration. Constructors validate the new plan groups now.

Exact patch, replace LDG-3168's validator sentence:

> Extend the already-migrated E/stop validator for typed pending diagnostics and equity; add their exact lengths, types, dictionary/bound checks and used-prefix checks. Earlier groups retain their owning tickets' construction validators.

### F3. Three structural gates overreach the accepted representation boundary

Evidence: `tickets.yml:1096,1162-1169,1179-1192`; `S:99-107,214-232,380-389`; `R/availability-economics.R:460-467`; `R/output-handler.R:353-385,769-781`. LDG-3164 forbids every per-fill named lookup anywhere in R before LDG-3166 changes planning. LDG-3167 forbids every per-fill list while explicitly preserving the memory `meta` list. LDG-3168's unqualified run-long/list-grown detector can reject the existing filtered retained diagnostic chunks, which are distinct from transient staging.

Why it matters: these gates cannot all be green under the stated sequence and scope. Relaxing them ad hoc during implementation would leave their actual predicates undecided; following them literally would pull routed work into WS4a.

Exact patch, replace the first acceptance item of LDG-3164:

> No named-list FIFO implementation remains. The typed lot kernel and migrated book consumers perform no per-fill instrument-name lookup; named boundary adapters are individually enumerated. Planner representation is gated at LDG-3166, not here.

Exact patch, replace the first acceptance item of LDG-3167:

> No per-fill economic carrier or per-leg staging list remains in publication. The explicitly routed memory meta list, canonical JSON and memory aggregate auxiliaries retain their existing semantics and bytes. The detector rejects an injected economic staging list and accepts the retained metadata representation.

Exact patch, replace LDG-3168's diagnostic detector acceptance item:

> Detectors reject list-segment pulse staging and staging retained across pulses, and accept the existing bounded writer and filtered retained-output chunks. The capacity case exceeds a writer chunk, stops early and verifies used prefixes and sequence gaps; retained-output size is not mislabeled as transient staging capacity.

### F4. The test-migration exception cannot accommodate the changes it mandates

Evidence: `tickets.yml:342-346,384-393`; `tests/testthat/test-execution-spec.R:557-573` requires the literal old fill-intent helper and `for (entry in accounting_events$fills)`; `tests/testthat/test-fold-phase-contract.R:4-7,39-59` constructs old list books, tests the deleted accumulator and rejects unnamed positions. These assertions cannot keep their structural predicates and fixture representations when the synthesis deletes those representations. They are not all helpers deleted with the named-list FIFO, nor just a slot census change.

Why it matters: a green full suite would require an unapproved interpretation of decision (10), or obsolete compatibility objects. Neither is an honest implementation instruction. Economic failures still must never be repaired by weakening tests.

Exact patch, replace decision (10):

> Registered-test migration is limited to the pre-acceptance, per-block list in LDG-3162. Each entry states the representation change authorized by the synthesis, the old semantic assertion, its replacement and a demonstrated violation that fails it. Permitted mechanical edits include constructing typed books/positions/equity instead of removed containers, comparing the same logical FIFO witness, and replacing source predicates that name removed helpers or list traversal with predicates enforcing the same ownership/order claim on columns. This includes test-fold-phase-contract.R's constructor/accumulator/position checks and test-execution-spec.R's old P4 source assertions. Preserve all economic input values, expected outputs, conditions, fault boundaries and allocation bounds. No entry may mask a product failure; any semantic or fault-boundary change needs a separately stated, accepted reason before implementation.

Exact patch, replace decision (2)'s sentence "No oracle, fixture, canonicalisation or expected byte changes":

> No economic oracle, fixture value, canonicalisation or expected byte changes. Only the representation and structural-test migrations individually approved under decision (10) are permitted; they preserve the old logical and economic witnesses.

### F5. The shared ratio checker does not enforce the absolute 40 us/fill bound

Evidence: `tickets.yml:351-358,1058-1063`; `dev/bench/timing/check.R:245-268`; `S:346-353`. The checker compares candidate/base medians from the gate attempt. The proposed threshold is `40e-6 / B0`, where B0 is an earlier smoke median. It therefore permits candidate `C <= 40e-6 * B / B0`, not `C <= 40e-6`. For B0=200 us, gate base B=240 us and candidate C=45 us, the ratio passes (0.1875 <= 0.20) although the promised absolute gate fails. The harness also requires positive seconds (`check.R:180-181`); a marginal difference needs an explicit invalid-measurement rule.

Why it matters: a green named checker can certify a false performance claim. This is a mathematical defect, independent of the eventual implementation.

Exact patch, replace decision (4)'s availability-wide-sweep bound and the corresponding LDG-3163 bound-computation acceptance text:

> Availability wide sweep has an absolute candidate median marginal-time gate of <=40e-6 seconds per executed fill. Freeze the matched no-fill subtraction, repetition normalization and actual executed-fill denominator before acceptance. Retain the paired ratio cell as an additional fixed relative gate, but do not call that ratio the absolute gate. After the unchanged shared checker's validity checks pass, the small WS4a checker consumes its per-cell results and separately fails when median_candidate exceeds 40e-6. Nonfinite or nonpositive marginal measurements fail measurement validity; do not clamp, omit or replace them. Before acceptance, demonstrate rejection of a 45 us candidate with B0=200 us and paired base=240 us. Reuse the shared harness; do not copy its collection/validation machinery.

### F6. The matrix omits dense risk cells and leaves replay's local gate contradictory

Evidence: `S:343-353`; `tickets.yml:358-374,377-380`. Only availability gets sparse run/sweep and wide sweep cells, despite the explicit both-producer no-fill/sparse/wide obligation. Decision (6) gates singleton replay at LDG-3164, while decision (8) says only LDG-3169 gates timing. Public fills/trades are valid replay witnesses (`R/backtest-fills.R:123-153,173-174`), but public equity reads stored equity (`R/backtest-results.R:274-288`); labeling all three together as "the replay path" does not fix a separate replay threshold.

Why it matters: dense regressions can be invisible, and a combined reader clock can dilute a FIFO regression with unrelated work. The singleton decision must be settled when the old implementation is removed.

Exact patch, replace decision (4)'s sparse/read clauses and append these matrix requirements:

> Sparse-rebalance run and sweep cells cover availability and dense separately, each at ratio <=1.00. Add a separate dense wide sweep cell at ratio <=1.03. Retain all other producer/run/sweep cells and the availability absolute gate. Fills and trades have separate warm public-reader cells, each <=1.03, with recorded nonzero replayed rows and a fixed number of complete invocations; equity has its own <=1.03 result-reader cell and is not a replay witness. The frozen workload specifies the rebalance calendar, selection/tie ordering, costs, recording policy, warmup and returned-output materialization. Any numeric revision requires baseline/noise evidence before cut acceptance.

Exact patch, replace decision (8):

> LDG-3164 through LDG-3168 end with A0, dense and their applicable case/detector gates exact and the full suite green. The real-data oracle runs at LDG-3164 and LDG-3169. LDG-3164 additionally gates replay timing and replay memory to decide singleton versus consecutive conflict-free blocks under decision (6); this is an explicit exception to postponing the full timing matrix. Other timing cells may regress between tickets. LDG-3169 gates every oracle, timing cell and memory workload on the final candidate.

### F7. The memory instrument and workload boundaries do not establish the promised peak-live result

Evidence: `S:326-327,343-353`; `tickets.yml:365-374,1065-1068`. The synthesis distinguishes cumulative allocation from peak live memory and requires book growth and replay. The cut instead names `gc()` maximum-used R heap, without specifying components/aggregation, collection policy, setup boundary or replay measurement. A heap high-water mark is not a measurement of simultaneously reachable carrier memory or native allocation. Resetting before "the run" does not establish a replay budget on which LDG-3164 can decide singleton versus blocking.

Why it matters: the same implementation can receive different claims depending on GC policy and omitted phases. Forward-run evidence cannot certify singleton replay's copy behavior. The measuring tool and its scope are still a pre-acceptance decision.

Exact patch, replace decision (5):

> Memory is a pre-acceptance gate specification, not an implementation-time choice. For both producers' wide workloads, cumulative Rprofmem bytes per actual fill must be <=base. On >=5,000 instruments x 252 sessions, including book growth and fills consuming >10 lots, forward execution and replay are separate measured operations; each peak-live budget is <=1.10 x its matched base. LDG-3163 must register and validate the measuring method, covered memory domains, phase boundaries, collection policy, repetitions and byte aggregation before cut acceptance. A controlled excess of independently allocated live book storage across growth/replay must fail the applicable budget; freeze the injection size and observation point. Report gc maximum-used R heap separately with its exact calculation; do not relabel it as peak live or silently substitute RSS/cumulative allocation. If the required peak-live claim cannot be measured, settle the metric/requirement with the maintainer before accepting the cut. The resulting frozen replay memory gate is used at LDG-3164 as well as LDG-3169.

### F8. The close can waive a timing failure after seeing the implementation

Evidence: `tickets.yml:1209-1211` accepts a timing miss with a linked maintainer exception; `S:349-353` permits numeric revisions before acceptance, never after seeing implementation failure.

Why it matters: a failing timing gate can still close this cut without satisfying its accepted bound. A general exception path is broader authority than this synthesis grants.

Exact patch, replace LDG-3169's timing acceptance item:

> Every timing cell passes the thresholds frozen before cut acceptance, including the separate absolute marginal-time check. A miss keeps the ticket and workstream open. A linked exception is not a PASS under this cut; any proposed change to the accepted requirement returns through the governance process and is not an implementation-time threshold adjustment.

### F9. The real-data reference is present, but its claimed accompanying inputs are not registered at the cited location

Evidence: `tickets.yml:307-320`; external `C:/Users/maxth/ledgr-research/experiments/v0_2_2-reference/compare.R:3-7,23-29`. Inspection of `E:/ledgr-data/reference/v0.2.3-base-953338df/` found the six workload directories, `w1-data/` and `w1.log`; no accompanying library or `build-state.json` there or under it. The comparator can compare saved CSVs without either input, but a fresh worker requires the library and state JSON. The present "beside it" statement does not identify usable rerun inputs. This does not establish that they are absent elsewhere.

Why it matters: saved comparisons corroborate output identity, not the ability to reproduce the candidate gate. The implementer should not reconstruct a private snapshot or guess its state file during implementation.

Exact patch, replace measured_input's parenthetical beginning with the private reference path:

> The six saved reruns are at E:/ledgr-data/reference/v0.2.3-base-953338df/, one r1 directory per workload. The library and rebuilt snapshot state are not registered by the claim "beside it". Before acceptance, LDG-3163 records their actual private absolute paths, input identities, fresh-library installation command and complete unchanged/cost-mutant comparator commands in the private evidence record, with a stable pointer here. The reference is ready for fresh candidate gating only after those commands have passed their specified positive/negative controls.

## Optional finding

### F10. Record one final source identity after the closing edits

Evidence: `tickets.yml:1202-1208` lists checks before contract/NEWS edits; `inst/design/rfc_cycle.md:304-307` requires empirical source identity. No product defect follows from that ordering alone, but the close should distinguish the tested candidate from later evidence/documentation edits.

Exact patch, append to LDG-3169 scope:

> Complete the contract and NEWS edits before the final package check. Record the tested source identity and any subsequent evidence-only diff; a later product edit invalidates the affected gate records. Keep generated build/check artifacts outside the tracked tree.

## Source audit and verification limits

The source table's substantive descriptions match the reviewed R code: the 19-slot carrier, named position/list-book representation, next-bar-bearing observation, duplicate target validation, per-fill planner objects and scalar FIFO/publication, bounded writer versus retained memory subset, two equity representations, and the cited external lot consumers. `git diff 145cc93b HEAD -- R src` was empty. The finalizer really uses `availability_active || length(fold_equity) > 0` at `R/run-finalize.R:449-453`; filling dense fold equity therefore requires the explicit producer-based fix already owned by LDG-3168. The historical probe and descriptive dense timings match their cited records; none was rerun. The broad detector wording in F3, rather than the declared out-of-scope list, is the principal route intrusion.

Reading alone could not independently establish the cited oracle PASS claims. After the required reading, these non-timing checks were used; all new outputs were outside the repository. Rscript was `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe`; scripts below are repository-relative unless marked external, with absolute paths used at invocation. Base package path was `C:/Users/maxth/ledgr-wt/ws4a-base` (worktree HEAD `953338df8165449e508960cb3a12de91673b8199`). Scratch prefix was `C:/Users/maxth/AppData/Local/Temp/ledgr-cut5-review-`.

- `dev/bench/v0_2_3_cut3_successors/a0/record.R --pkg=<base> --out=<scratch>a0-95a838c4`: exit 0. `compare.R --pkg=<base> --successor=<scratch>a0-95a838c4 --result=<scratch>a0-comparison-95a838c4.csv`: exit 0, 295 checks, zero failures.
- `dev/bench/peer_benchmark/dense/check.R --pkg=<base> --out=<scratch>dense-95a838c4`: exit 1 before recording/comparison, in the Git scope check (`dense/native.R:15-24`). A direct base-worktree Git command reported dubious ownership. No guard or Git configuration was changed. This review does not claim an independent dense PASS or an economic failure from that invocation.
- External `C:/Users/maxth/ledgr-research/experiments/v0_2_2-reference/compare.R unused E:/ledgr-data/reference/v0.2.2 <workload> unused C:/Users/maxth/Documents/GitHub/ledgr E:/ledgr-data/reference/v0.2.3-base-953338df/<workload>/r1`: saved-output comparisons only, no worker or timing execution. `w2_minvar`, `w2_article`, `w3_changing`, `w3_full`, `w4_wf` exited 0, exact snapshot/table comparisons. `w4_sweep` exited 1 with only `sweep_candidates.provenance` differing (four rows); the cited seed_contract-only value-free probe was not independently reproduced. This corroborates the recorded comparison pattern, not a fresh six-workload rerun.

No timing, full suite, package build or product change was performed for this review. Required findings block acceptance; optional F10 does not. Only this review file is delivered, without a commit.
