# Feature Engine Stages 2-3: Type 2 Response

REVISE_SEED

The accepted direction is sound, and the conservative direct calculation looks viable. The seed errs chiefly on answer preservation: its key-only certification proposal does not yet preserve today's recognition and refusal behavior. It also understates the proof and cost of maintaining the fast path; the measured opportunity warrants a small implementation, not a broader registry or gate framework.

Mode: Type 2, RFC response, Codex, 2026-11-18; maintainer-approved brief, drafted by Claude. Reviewed head: `b3454fc7` (supplied; Git refused ownership checks even with process-scoped safe-directory settings, so independently unverified). Evidence: the seed and accepted parent in full, parent review F1-F13, requested source and contract groups, probe scripts/results, permanent-oracle tools, optimization rules and pulse-plumbing R1; small synthetic probes against the supplied installed build. Its engine marker matches `bc6a3ea254d0a37b`, and all 215 top-level function bodies/formals in the eleven requested R files match the worktree. No timing run, full suite, package check or private-data access was performed. Recommendations are non-binding.

Paths below are relative to this worktree unless absolute. `seed` means `rfc_feature_engine_stages_v0_2_3_seed.md` in this directory. Review scripts and outputs are under `C:/Users/maxth/ledgr-wt/fe-stages-probes/`.

1. **A single metadata key is not yet an equivalent certification selector.**

   Evidence: `R/history-features.R:96-121` constructs all four built-ins for every discovered width, before certification examines candidates; `:32-59` substitutes the supplied ID and checks claimed and content identities, including contradictions. A valid `ledgr_ind_sma(.Machine$integer.max)` currently refuses during unrelated EMA construction (`R/indicator-builtins.R:75`); selecting SMA alone would succeed. Also, a SMA3 definition carrying the canonical RSI3 fingerprint under the same ID currently raises `ledgr_indicator_history_contradiction`, despite its SMA metadata. Both outcomes were executed (`C:/Users/maxth/ledgr-wt/fe-stages-probes/stages_response_probe.txt:4` and `:9`).

   Consequence: seed Section 3's “at most one” candidate and assertion that the carry contradiction covers today's refusals are insufficient. Under **Indicator Computation And Identity** and **Availability-Aware Strict Features**, recognition must still install canonical functions; a metadata mismatch must not silently become custom and execute caller code.

   Change: specify selection against both claimed and content identity, preserving candidate precedence and ID substitution. Retain the existing candidate procedure for cases the new selector cannot prove equivalent. Add these witnesses; correcting the unrelated-width refusal requires a separately stated behavior decision, not an incidental optimization.

2. **Catalogue membership does not prove that constructor validation was redundant.**

   Evidence: `R/indicator-ttr.R:250` calls TTR before catalogue lookup; `R/history-features.R:127-145` catches construction errors and omits that candidate. Catalogue matching permits arguments such as ROC's `type` (`R/indicator-ttr.R:347`); it does not validate their backend domain. In a local constructor copy with only synthetic validation suppressed, ROC3 with `type="invalid"` and MACD with `nFast=100, nSlow=3, nSig=2, output="macd"` acquire catalogue declarations, but today's certification returns custom. Their public constructors refuse; MACD's synthetic input has only 50 rows. See `C:/Users/maxth/ledgr-wt/fe-stages-probes/stages_response_probe.txt:21` and `:30`. No namespace or product code was changed.

   Consequence: these are hostile-definition witnesses, not valid public constructions. They refute the seed's assumption that every definition reaching certification already passed the constructor. A table-only replacement broadens recognition and changes which calculation/refusal path runs (**TTR Adapter**, **Indicator Computation And Identity**).

   Change: separate canonical construction from validation while preserving emitted closure identity. Prove the no-backend selector's accepted domain, including allowed argument values, normalization, widths, `stable_after`, versions and output selection. Retain existing candidate construction outside that proven domain; remove the unconditional “never calls the backend” requirement until equivalence is demonstrated. Do not copy TTR's general validator into ledgr merely to save this call.

3. **Debug must compare refusals as well as successful answers.**

   Evidence: accepted parent `rfc_feature_engine_v0_2_3_seed_v2.md:411-417` requires refusal-outcome comparison; seed Section 4 lists only values, counts and records. A valid catalogue `runSD(n=1)` passes the conservative gate on finite bars and then refuses with `ledgr_invalid_feature_output` in both paths, verified in `C:/Users/maxth/ledgr-wt/fe-stages-probes/stages_response_gate/gate_probe.txt:2`. Admission therefore does not imply successful calculation. Current precedence is certification, then instrument/range/definition calculation, then causality (`R/history-features.R:475`, `:495-521`).

   Consequence: computing the fast answer and comparing only if it returns cannot detect an extra fast-path refusal. Grouping admitted cells ahead of fallback cells could change the first refusal (**Feature Path And Intent Constructors**).

   Change: capture and compare success/condition outcomes with classes and identifying fields, using independent preparation-local caches. Re-raise the agreed product refusal; fail closed on disagreement. Preserve the complete existing loop order. Add competing-error witnesses with admitted and fallback definitions in both orders, plus empty bounds before gate construction. Keep output validation and sampled causality in production.

4. **This can be an internal optimization, but file placement is not its justification.**

   Evidence: AGENTS.md's prohibition concerns a second set of execution semantics. The accepted parent's Stage 3 explicitly authorizes an equivalent calculator inside preparation. The manual's **Rules**, “A fast path names its canonical path, its differential and its exit” (`inst/design/manual/optimization_coding_style.qmd:343`), additionally requires a removal/merge condition and a history-representation-map entry. The seed supplies neither. **Feature Path And Intent Constructors** still says “one uncached production path” (`inst/design/contracts.md:2752`).

   Consequence: a feature flag or clock-specific fork would be a second mode regardless of its filename; a deterministic per-cell shortcut sharing canonical calculation need not be. Debug parity alone is not the authority.

   Change: justify the shortcut by the parent's accepted scope and common semantics. State its exit: remove or merge it when common-path simplification removes its measured benefit or makes its predicate unnecessary. Add its representation-map row, and explicitly reconcile the contract's wording with one common preparer containing equivalent internal calculator selection. Add no user-selectable execution mode.

5. **The saving is a component estimate; rejected-cell cost needs an owner.**

   Evidence: `dev/spikes/feature_stage23_probe/direct.R:63-69` subtracts separately timed medians. Its record clock manifests empty chunks, while `common.R:115-134` collects segment rows separately; it does not measure the integrated production writes/assembly. The prototype gate already costs 0.073-0.130 seconds on wide fixtures. Seed Section 5 times only fully admitted dense fixtures, while its gate-count results include zero-admission substrates. Seed Section 4 also proposes full expected/terminal planes and finiteness matrices per field set.

   Consequence: 49-59% supports investigation, not a rigorous upper bound or a demonstrated net saving. Stage 2 changes the baseline; with no admitted cells the new gate buys no calculation saving. Retaining several instrument-by-axis temporary planes can also increase peak memory.

   Change: call the figures a prototype component estimate. Measure incremental Stage 3 against completed Stage 2, including zero/low/mixed admission on public fixtures, integrated records and peak memory. Reduce transient finiteness planes to instrument flags rather than retaining all field-set planes. Keep a cheap rejection path and a stated no-regression/size decision. No clean-machine rerun or private count is needed for this response; honor the maintainer's deferral of private coverage.

6. **The permanent checker needs an explicit mechanism-observation update.**

   Evidence: `dev/feature_parity/runner.R:133-190` counts constructor/backend calls and treats every preparation range as a hand-off to treated inputs. `dev/feature_parity/check.R:109-129` requires both arms to match recorded routes and hand-off counts. Stage 2 intentionally removes synthetic TTR calls; Stage 3 intentionally skips treated inputs. Even a semantically identical implementation will fail those observations.

   Consequence: “the permanent oracle must pass” is not a complete verification plan. Rebaselining all observations would weaken the independent pin, contrary to AGENTS.md's test-oracle rule.

   Change: state the separate reason and narrow disposition for changed mechanism observations. Preserve exact pin comparisons of values, planes, reads, certification, refusal details/order, RNG and causality selection. Replace obsolete route/hand-off expectations with independently observed gate decisions, actual adapter calls, raw sharing and fallback treatment; retain fault controls. Run changed-engine identity checks and extend the helper census/replacement proofs. Keep emitted fingerprints and logical identity comparisons unchanged (**Execution And Feature Identity**).

7. **The prototype proves a narrower claim than the production proposal, and one count is wrong.**

   Evidence: `common.R:89-111` implements only built-in SMA and close-input TTR; the 13,408 cases in `results/direct.csv:2-7` are TTR SMA. `direct.R:23-43` compares values, segment records and absent exceptions, not refusal ordering or calculated-count equality; the prototype has no shared raw cache. `results/gate_count_differing.csv:2-5` records four additional relaxed cells, across two panel/instrument occurrences, not seed Section 4's two cells.

   Consequence: the numbers do not certify the registry, multi-field inputs, multi-output sharing or production ordering. This is an evidence limit, not an observed value defect. My separate whole-slice reuse probe matched 192 admitted cases across all catalogue rows, short slices and later starts (`C:/Users/maxth/ledgr-wt/fe-stages-probes/stages_response_gate/gate_probe.txt:1`), supporting the proposed reuse without replacing the required oracle.

   Change: label the 13,408 result as SMA coverage and correct two cells to four. Require explicit cache-sharing/count/refusal witnesses for every input/output family, mixed carry families and `stable_after` variants. The six timing rows, certification costs, 57-67% sampled bucket sums, conservative coverage and 57-line/nine-function inventory reconcile with the supplied CSVs. The full 14-cell gut total and historical CHECK PASS were not independently rerun; my corpus-only gut reproduced ten differences. Preserve the complete gut output with the next evidence record.

8. **The sticky-barrier clause is redundant under the prefix-terminal exclusion.**

   Evidence: `R/history-substrate.R:1437-1459` derives sticky barriers solely from asserted terminals over that same prefix. No assertion anywhere in the prefix therefore implies no sticky barrier in the calculation slice. Seed Section 5 asks for separate near misses on both.

   Consequence: an isolated sticky-only witness cannot exist under those premises. The gate is conservative rather than minimal: one-range and whole-prefix terminal exclusions can also reject harmless histories. That is acceptable for this cut.

   Change: state the implication, avoid a duplicate admission scan, and test the combined terminal invariant. Keep the conservative coverage and finiteness clauses; do not expand into relaxed segment/reason reconstruction for this release work.

Answers to the seven questions:

1. Not every clause is independently necessary (finding 8). Together, on a valid substrate with unchanged certification, the nonempty full-slice clauses establish one run, identical raw/treated required inputs and empty carry/reason exceptions. Preserve the separate empty/short guard, bounds, counts and error order (finding 3). I found no admitted value/record difference from whole-slice `segment` reuse.
2. It reuses arithmetic, not all bookkeeping. Keep prefix-relative row indices, input shape/order and the existing cache lifetime: one instrument and knowledge range. The key still excludes selected output but includes remaining params, required fields, carry family, history class and segment endpoints (`R/history-features.R:62-80`, `:307-325`). Preserve MACD derivation and BBands' distinct carry-family keys; do not merge them because inputs happen to agree. Short slices make no call. Findings 3 and 7 identify missing proof.
3. Not as specified. Findings 1-2 name executable counterexamples. Shared canonical construction is appropriate; an unconditional metadata lookup without backend validation needs a narrower proven domain or fallback.
4. Built-ins as a fixed `ledgr` descriptor are reasonable. Keep existing kernels and fingerprints; avoid runtime registration, discovery, mutable hooks, optional-backend loading merely to inspect a built-in, or a public adapter schema. Its cost is moving four mappings and updating census/identity proofs; accept it only if it removes parallel bookkeeping.
5. No, under the parent's accepted equivalence boundary and finding 4's conditions. Its location alone does not settle the question.
6. Recommend **7.1(a)**: one private debug mechanism, restoring prior state and set explicitly in workers; suite debug-on and parity on/off as in pulse-plumbing **R1** (`rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md:84-92`). Cost: duplicate admitted-cell work in debug and worker/test wiring. Option (b) would weaken the accepted parent's real-workload debug obligation. Recommend **7.2 one cut, two separately closed workstreams**, Stage 2 reviewed before Stage 3 depends on it; cost: two reviews and a residual measurement, without two cut ceremonies. Recommend **7.3 the small built-in descriptor**, with the limits and cost in answer 4.
7. The main arithmetic and source map check out. Correct the relaxed count, narrow the parity claim, qualify the estimate and preserve unverified historical evidence as such (findings 5 and 7). The code's causality check skips definitions with no calculated cells; its sampled production check remains a refutation, not a general proof (**Feature Path And Intent Constructors**).

Seed v2 should:

- Add the exact certification selection/validation boundary and the counterexamples in findings 1-2.
- Add refusal-outcome debug comparison, competing-error witnesses, checker dispositions and the fast path's exit/map entry.
- Add incremental Stage 3 cost and memory checks for poor gate coverage, with separate workstream closes.
- Remove unconditional single-key/no-backend promises and the redundant sticky-only witness.
- Reword “no new calculation code” as reuse of canonical arithmetic, “upper bound” as a component estimate, and “two cells” as four. Keep the fixed registry, conservative gate, fingerprints and production causality probe.
