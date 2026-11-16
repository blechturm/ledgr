REVISE_SEED

Mode: Type 2 review; independent session, 2026-11-16.

The problem and the three-stage direction are sound. The seed is not ready for synthesis: the sweep profile misattributes calculation work, one stage-1 removal lacks a neutrality proof, the simple-path predicate does not establish the claimed evidence equivalence, and adapter and identity requirements are incomplete. Keep the maintainer's four answers. None needs reopening to address these findings.

Paths below are relative to C:/Users/maxth/ledgr-wt/fe-seed-review unless explicitly absolute. Source anchors refer to the supplied checkout. Synthetic probes and their output are in C:/Users/maxth/ledgr-wt/fe-seed-review-out/review_probe.R and review_probe.txt. The probe loads only the supplied pinned library. It performs no timing window, full test run, durable run, or private-data access.

F1. Required: the sweep's split/rebuild cost is not isolated by this classifier.

Claim: Section 2 and stage 1 attribute 0.13-0.20 s to splitting the payload and rebuilding matrices.

Evidence: feature_steps.R:39-55 gives the payload wrapper precedence over `compute other`. Every calculation stack contains `ledgr_history_precompute_payload`, so any compute sample that misses an earlier named helper becomes `payload split`, never `compute other`. The copied classifier in review_probe.txt maps the synthetic stack `"lapply" "ledgr_history_compute_feature_series" "ns$ledgr_history_precompute_payload"` to `payload split (sweep)`. The CSV has zero sweep `compute other` on all shapes, while run residuals are 0.025, 0.044 and 0.057 s (results/feature_steps.csv:17,51,85). In addition, `projection rebuild` precedes `projection other`: runtime construction, including its direct timestamp format, falls to rebuild on sweeps. The probe maps a runtime-format stack under `ns$ledgr_projection_from_payload` to `projection rebuild (sweep)`.

The `ns$` prefix itself is handled correctly by feature_steps.R:68: plain and `ns$` compute stacks both map to `compute other`. Causality and certification correctly precede their nested calculation/TTR work. Most leaf-first precedence is appropriate; the wrapper/residual ordering is the defect.

Consequence: split/rebuild exists, but its advertised saving is unsupported. Some of its apparent cost is calculation allocation, bookkeeping and runtime projection construction that the removal must retain. The existing aggregated CSV cannot recover the correct split.

Exact replacement for the split/rebuild reading and stage-1 saving: "Sweeps split matrices into instrument vectors and reconstruct them. The current profile charges residual compute and projection work to these wrappers, so 0.13-0.20 s is a contaminated attribution, not a removable-cost estimate. Reclassify with compute residual before the payload wrapper, and runtime projection residual before the rebuild wrapper, after their specific children. Measure the actual removal in the stage-1 cut."

F2. Required: distinguish sampled totals from measured removable overhead.

Claim: the raw-call premium is about 70 us per call and stage 1 should recover most of 0.16 s; formatting removal should recover about half the narrow-run feature time; negligible certification/probe cost is established.

Evidence: feature_steps.R:58-72 warms once, profiles all three repetitions, pools their samples, and scales by the median profiled elapsed time. This is a reasonable descriptive estimate, not a paired timing of the proposed removals. Only 50 samples support the entire 10x7200 run; 200 support 1166x252 (CSV:2,70). Certification has no samples on any shape. `TTR raw call` includes TTR computation, namespace checks, input mapping, lookup and `do.call` (R/indicator-ttr.R:852-862); it does not isolate their individual costs. Its 0.333 s is compared with 0.170 s from a separate, unprofiled measurement (feature_split.csv:4; features.R:47-49). Their difference cannot assign 70 us to dispatch alone.

For D definitions, R/runtime-projection.R:35,40,48 performs D+2 axis formats: D for dimnames, one for pulse_index, one direct `format` for pulses_iso. Only the first D+1 pass through `ledgr_projection_pulse_names`; the direct format is hidden in projection residual, or sweep rebuild under the current precedence. Section 2's aggregated `other` also includes output matrix allocation, calculated-count bookkeeping, writes and plane collection (R/history-features.R:456-501), not just ranges/indexing. "calculate: runs, carry" includes required-field slicing/admission, readiness and value buffers, even when no output-carry policy is active (R/history-features.R:329-405).

Consequence: the direction is plausible, but the estimates overstate what the profile proves. Zero samples mean unresolved at this resolution, not zero cost. Do not promote these numbers to acceptance thresholds or promise near-bare-TTR performance.

Exact addition after the table: "Cells are pooled sample-share estimates over profiled elapsed time; sample counts are 50/115, 152/345 and 200/490 for run/sweep. Zero-sample cells are unresolved. The raw-call bucket includes TTR itself; its difference from a separate bare-TTR clock is only a hypothesis about overhead. Formatting occurs D+2 times, including one call outside the named bucket; one format must remain. Savings require paired measurements on the cleaned path."

F3. Required: field pruning is not proven neutral for custom callbacks.

Claim: stage 1 may treat only the fields required by the definitions without changing any value or contract.

Evidence: required_fields controls admission, not a restricted callback schema (contracts.md:2565-2569,2593-2595; stable rule groups `#contract-context-indicator-computation` and `#contract-context-strict-features`). R/history-features.R:230-242 constructs the full instrument/time/OHLCV frame, and :308-320 hands it to custom callbacks. Those callbacks can currently inspect non-required columns, including their treatment. The probe constructs an accepted deterministic custom indicator with required_fields="close" whose series callback observes volume. It is certified `custom`, returns 101 through 108 with today's full inputs, and refuses with `ledgr_invalid_feature_output` after pruning to close. This is evidence of a real executable boundary, not proof that every underdeclared calculation is a desirable API. The seed has not established a rule permitting it to change that boundary in a neutral cut.

Also, inputs are currently prepared once per instrument/knowledge range and shared by definitions, not literally once for the whole preparation: :475-485 recomputes the full prefix at each range's knowledge cutoff, and :655-663 builds causality-probe inputs. Hoisting treatment across different knowledge cutoffs would change causal lifetime/terminal masks.

Consequence: a blanket required-field optimization can alter values, callback input shape, or refusals. It must not become a stage-1 shortcut based only on an admission declaration.

Exact replacement for stage 1 item 2: "Prune treatment only where certified constructor behavior proves that omitted fields are unobservable. Compute the field union from certified canonical definitions, not untrusted source labels or claimed metadata. Preserve today's complete raw/treated callback frame for custom definitions, including unregistered TTR forms; conservatively retain all five fields when such a definition is present. Share treatment across definitions within each instrument/knowledge cutoff, preserving probe behavior. A broader restriction on custom callback inputs requires an explicit contract decision outside this neutral cut."

This conservative implementation respects the maintainer's stage-1-first choice; no new maintainer choice is needed.

F4. Required: state the proofs for the other stage-1 removals and the pin oracle.

Claim: using direct treated vectors and retaining matrices is value-identical and constructor-faithful.

Evidence: for input="close", the current mapping already supplies `as.numeric(bars$close)` to the exported TTR function (R/indicator-ttr.R:806-844,852-862). The probe confirms direct TTR::SMA on that vector is identical to the current framed path. Certification replaces a matching claim with the canonical constructor definition (R/history-features.R:30-81), and multi-output execution shares raw results by a key excluding output but including arguments, required fields, input-carry family, history class and segment endpoints (:62-77,294-306). Normalization still masks stable_after and refuses invalid output (R/features-engine.R:343-371). Thus the frame is transport, not an alternative indicator algorithm. This supports the removal, provided those semantics remain.

The run already computes matrices and indexes their evidence directly (R/backtest-runner.R:668-680). The sweep splits them (R/history-substrate.R:381-405) and reconstructs them (R/runtime-projection.R:150-185). Explicit public precompute does this too and retains both payload and projection (R/precompute-features.R:91-132). Reuse actually reads the projection (R/sweep.R:297-312). The split is not exclusive to an implicit sweep, as Section 2 implies. Registered precompute tests assert the old physical shape (tests/testthat/test-precompute-features.R:27,43-62).

Consequence: these removals are credible, but two SMA columns on smooth bars are not the required oracle. Matrix changes must preserve fingerprint-to-concrete-ID mapping, row/axis order, types, aliases and sparse planes, not merely numeric values. A physical test assertion may change only with the ticket's stated representation-change reason; retain its semantic comparison.

Exact addition after the stage-1 list:

"The cut compares the installed d5b3a151 pin with the candidate using a diff-based checker. Compare exact values and NA placement, types/dimensions/names, every feature plane and history-read reason, and condition classes and identifying fields for refusals. Preserve caller RNG and causality-probe selection/order. Intentional differences are the engine marker, the associated old-precompute refusal, and the documented in-memory representation only; do not normalize away other identity or evidence differences.

"Cover built-in SMA separately from TTR SMA; every supported warmup rule and documented/derived output; bounded and history-dependent rows; stable_after greater than requires_bars; empty/short/no-calculated histories; custom series and fn-only callbacks; unregistered TTR arguments; forged catalogue claims; required-field-specific gaps, carry admission/exclusion, output carry and expiry, structural inactive sessions, terminals/relistings, and late-known facts. Exercise both clocks, scoring starts after data start, runs, implicit sweeps and explicit precompute/reuse. Demonstrate refusal timing before candidate/fold execution, and a registered FAILED durable run with no strategy/events/equity on preparation failure. Keep the existing registered tests. Use the shared timing harness for paired post-correctness measurements and record source/input identities."

These are future cut obligations, not claims that this review ran those gates. The public TTR mappings, forwarded args only, output selection, short-sample guard, canonical certification and raw-result sharing must remain explicit stage-1 invariants. Do not edit the emitted TTR callback bodies or captures while promising unchanged fingerprints (F9).

F5. Required: the dead-accessor claim misses registered test callers.

Claim: four functions at R/runtime-projection.R:357-559 are called only from dev/ and can simply be deleted.

Evidence: tests/testthat/test-feature-map-read-surface.R:31,41 calls the scalar and bundle state accessors in registered test LTB-0183. test-feature-accessor-scaling.R:21,27,145,148,247,324 also calls them. The bundle-values helper is called by the bundle accessors (R/runtime-projection.R:481,551). There are no external production callers of these four in R/, which supports "unused by production", not "called only from dev/". The optimization manual explicitly permits test-only seams with a testing contract and real caller (manual/optimization_coding_style.qmd:149-153). AGENTS.md:28-30 forbids changing a registered setup/fixture/oracle merely to pass a product failure.

Consequence: deletion as written breaks registered tests and risks removing evidence while claiming only dead-code cleanup.

Exact replacement: "These four helpers have no production entry callers; two remain registered test seams, and the shared bundle-values helper serves them. Retain those seams in stage 1 unless the cut states a separate retirement reason and preserves their registered behavioral coverage on the live accessor surface. Only wholly uncalled code may be deleted as routine cleanup."

The probe comment should be corrected, not its behavior removed: prefix invariance runs for all definitions; only the bounded custom fn/series refutation is custom-only (R/history-features.R:688-709; contracts.md:2728-2746, `#contract-context-feature-path`).

F6. Required: the engine-version repair needs a semantic dependency census, not four additions.

Claim: adding the four named missing helpers closes the engine-version gap.

Evidence: R/features-engine.R:1-93 hashes named bodies/formals without recursively hashing their callees. The four reported omissions are real, but so are `ledgr_ttr_build_input`, `ledgr_feature_plane_records`, `ledgr_history_feature_bounds` and `ledgr_projection_index_planes`, among others. The probe substitutes each of these plus raw_call, select_output, plane_exceptions and check_definition in a private environment used by a copy of the version function. Every substitution leaves the hash unchanged. No namespace binding is modified. Certification also depends on TTR catalogue matching/variant/width helpers (R/indicator-ttr.R:328-409), not solely the catalogue table body currently hashed.

Consequence: value, evidence, refusal, or reused-projection semantics could change without invalidating old precompute objects. The contract expressly binds every helper of the availability calculation (contracts.md:2683-2684, `#contract-context-strict-features`). Adding a generic adapter later creates another way for behavior to hide behind an unchanged dispatch body.

Exact addition to stage 1 item 5: "Inventory the ledgr-owned semantic helpers for certification/declarations, input mapping and treatment, bounds/ranges, calculation/output selection, planes, causality/refusals, and the prepared representation reused by sweeps. Bind each helper or document the separate identity that already binds it. Include the adapter descriptions and their calculation-affecting rules when stage 2 arrives. Add focused mutation tests showing representative value, evidence, refusal and representation changes move the engine marker. Do not solve this by a recursive hash of arbitrary environments, session state, or all package functions."

F7. Required: simple instruments do not have empty evidence planes.

Claim: one knowledge range, one input run, no terminal and no carried input makes the planes empty by construction.

Evidence: R/history-features.R:367-379 records a segment even without gaps, and :563-568 emits its start, readiness boundary and end. These records feed projection indexing (R/runtime-projection.R:77-97) and warmup reasons. The simple eight-row SMA3 probe emits segment_start=1, segment_ready=3, segment_end=8 and two warmup NA values. A second probe has one close run at rows 3-8, no close carry and no terminal: it emits segment_start=3, segment_ready=5, segment_end=8 plus required-input-missing reason_code=1 for rows 1-2. Both contradict empty planes. The H1 classification permits a late-starting/early-ending single run (features_h1.R:75-87), so even missing-input reason records are possible within its measured "simple" cohort.

Consequence: dropping planes can leave values identical while changing ready, not_ready, required_input_missing, or reader refusals. The H1 aggregate demonstrates SMA values/NA parity only, as summary.md:99-102 explicitly cautions.

Exact replacement: "The simple path constructs the same segment start/ready/end records and calculation bounds as the general path, including segments that never become ready. Only carry/reason exception sets proven absent may be empty. If a single run covers less than the calculation range, preserve the leading/trailing missing or inactive evidence and scatter values to the same axis positions. Value parity alone is insufficient."

F8. Required: define the simple gate per certified definition and calculation context.

Claim: the four instrument-level conditions suffice to bypass segment machinery for all definitions.

Evidence: admission uses each definition's required_fields and raw versus treated choice (R/history-features.R:342-348). Bounded definitions compress to expected sessions, while history-dependent definitions retain the common axis (:349-355); terminal assertions can split either (:360-363). A close-only single run says nothing about volume or high/low, structural holes under bounded compression, bounds, adapter support, or invalid outputs. Short segments must skip the call entirely (:372-376). Custom fn-only definitions compute exact bounded windows even without gaps (:316-321), so an adapter call cannot replace them. Late-known facts change ranges and prefix masks (:412-428,475-487). Certification and the causality check precede a preparation return (:455,500).

Consequence: "simple" is not a stable instrument property. The H1 SMA cohort cannot certify another row, policy, cutoff, or calculation bound. A broad gate would silently add a second set of feature semantics.

Exact addition to stage 3:

"State one gate over (certified definition or compatible raw-call group, instrument, bounds, knowledge cutoff, history policy). Initially admit only supported certified adapter rows. Custom and unregistered forms retain the general path. Require one unchanged knowledge range over the relevant calculation history; prove expected-session selection and finite admission for every required field under the row's input-carry family; account for terminal assertions and the sticky barrier over the prefix; establish the actual run's start/end and scatter mapping; and handle stable_after and empty/short histories without an early adapter call. A conservative first gate may require full expected, finite, uncarried coverage of the entire calculation slice and no terminal history. That narrower gate must be re-counted; the measured 582 H1 instruments are not its established coverage.

"For eligible cells use the same canonical adapter calculation, normalization/refusals, segment metadata, bounds and calculated counts. Preserve output-carry semantics or prove its no-op for the admitted slice. Run the existing global sampled causality check for every concrete definition, preserving instrument tie-breaking and sampled positions across fast/fallback partitions. Do not replace it with a debug-only check.

"Keep the stage-1-cleaned general plain-R calculator as the normative executable oracle. In debug, compare fast and general values, all planes and refusal outcomes and fail closed on divergence; do not silently choose the fast answer or conceal a mismatch by fallback. Test admitted cases and near misses on every gate clause, both clocks and debug settings. Pin differential checks remain independent of any adapter helper shared by both arms."

Rename stage 3 to "plain-R direct-call path for proven simple cases" and remove the current matrix-call bullet. The maintainer already chose one plain-R call per instrument, with a matrix interface considered only after a residual measurement; no further question is warranted.

F9. Required: retaining TTR fingerprints is feasible but requires preserving the emitted function identity.

Claim: making ledgr_ind_ttr() the registry constructor gives an unchanged fingerprint.

Evidence: its emitted fn and series_fn call `ledgr_ttr_call` and capture indicator_params (R/indicator-ttr.R:243-249,288-305). Fingerprints bind their bodies, formals, direct captures, ID, warmup and params (R/indicator.R:278-304; R/determinism.R:137-171). They do not recursively hash every called helper. The probe changes only the emitted series_fn body to a generic adapter call; the fingerprint changes. Adding an adapter field to captured params can also change it. Merely keeping the public constructor name does not preserve these bytes.

Consequence: a natural generic-constructor refactor would violate both stage 1's and stage 2's identity promise. Freezing or overriding the fingerprint while changing its declared function payload would undermine certification.

Exact addition: "Preserve TTR's emitted fn/series_fn bodies, formals, direct captures, params (including ttr_version), IDs and declarations. Route their existing helper through the internal adapter if useful, and bind the helper/adapter semantics in feature_engine_version. Pin ordinary and declared-session fingerprints for concrete, parameterized and bundled TTR forms before refactoring; verify canonical certification still recognizes them. Do not hard-code the old hash or add a compatibility reader. If this cannot be achieved, present the concrete identity diff for the maintainer's already-reserved decision before changing it."

F10. Required: the adapter description must represent the existing raw-result and certification contracts.

Claim: catalogue rows, warmup rules, an aligned numeric vector call and a candidate builder adequately specify the interface for TTR and a later adapter.

Evidence: TTR separates raw invocation and output selection; MACD histogram is derived, not a raw TTR column (R/indicator-ttr.R:847-862,966-994). Several flattened output definitions share one raw call, but not across incompatible carry families (R/history-features.R:62-77,294-306; BBands rows at R/indicator-history.R:250-253). Catalogue recognition depends on input shape, allowed and neutral args, exact algorithm variants, dependency width, and selected output (R/indicator-ttr.R:328-409). Unknown combinations and widths become custom; source="TTR" alone does not certify them. Warmup, first-valid stable_after, and history class are distinct. HL/HLC/OHLC mapping and the separate MFI/CMF volume argument are explicit (R/indicator-ttr.R:806-844,858-859). Registered tests cover hostile catalogue behavior (tests/testthat/test-indicator-history.R:243-284), while runtime prefix invariance still applies to catalogue rows.

Consequence: a numeric-vector-only interface can recompute every output and lose sharing, mis-handle derived outputs, or accidentally certify an unsupported form. A synthetic constructor validation call is not catalogue certification. TA-Lib readiness cannot be established by assigning a package/version and a warmup number.

Exact addition to stage 2:

"Use an immutable internal description with deterministic adapter/backend identity; package and, where applicable, underlying library/version and algorithm-setting identity; exact input mapping; normalized forwarded arguments distinct from metadata; deterministic dependency-width and stable-after rules; and catalogue matching keyed by input/function/output and algorithm variants. Preserve custom routing and classed refusals for unregistered combinations.

"Represent raw-call identity separately from selected/derived output identity, with raw invocation, output discovery/selection/derivation, aligned numeric normalization, and preparation-local raw sharing over compatible inputs/segments. Alternatively specify an equivalent multi-output protocol that demonstrably preserves today's sharing; a call returning only one selected vector is insufficient by itself.

"Certification candidates must reconstruct canonical ledgr-owned definitions and compare complete identity; an adapter/source name never authorizes caller-supplied code under a catalogue identity. Require registered hostile-fixture tests for every catalogue row, warmup rule and documented output, direct-backend parity including derived outputs, and unchanged runtime causality probing. Keep catalogue discovery and registry contents deterministic and covered by engine identity.

"Later adapters have distinct backend identity even for similarly named indicators; no cross-backend numerical equivalence or catalogue membership is presumed. A later TA-Lib adapter must supply these rules and evidence before shipping. No TA-Lib implementation or matrix-call obligation is created by this RFC."

F11. Required: expand the identity section into the actual layers and invalidation boundary.

Claim: stage 1 changes only the engine version; stage 2 has no identity change if TTR fingerprints stay fixed; the precompute mismatch is the complete effect.

Evidence: config stores concrete fingerprints and, for declared sessions, calculation declarations (R/backtest-config.R:235-266). config_hash_payload removes the redundant feature_set_hash, not the stored defs (R/config-hash.R:47-59). Per-candidate feature_set_hash is a sorted unique fingerprint-set hash (R/precompute-features.R:600-637); sweep feature_union_hash hashes the union and is separate from feature_engine_version (R/sweep.R:401-403). Engine changes therefore need not change logical config, feature-set or union hashes. Nevertheless stage 2 changes hashed dispatch/certification/catalogue code, so its engine marker must move even with fixed TTR fingerprints.

Reuse validates snapshot content, ordered universe, history policy/rules, grid labels, engine version, clock, candidate parameter hashes, resolved fingerprints/aliases and union coverage (R/precompute-features.R:187-290). It validates exact data/calculation start, cutoff, session count and axis hash before candidates (R/precompute-features.R:296-318,765-784; R/sweep.R:298-312). This is not unrestricted sharing between scoring windows or between bar-native/declared-session experiments.

Walk-forward candidate identity includes feature_set_hash and feature_params_hash, not feature_engine_version (R/walk-forward-identity.R:33-80). Its experiment hash comes from config_hash_payload and feeds the session layer (:176-185,201 onward). Thus engine-only changes do not automatically invalidate logical candidate/session keys. Fingerprint or stored declaration changes propagate through the appropriate feature/config layers. Engine version is saved as sweep metadata (R/sweep-persistence-schema.R:71-72); it is not a new version of every stored artifact or a blanket refusal of all older durable results.

Consequence: stage 2's "none" is false at the engine layer, and the seed could imply broader invalidation than exists. Engine version alone neither proves old config replay equivalence nor creates a walk-forward version boundary. Current no-value-change work can preserve logical identity, but this must be demonstrated, not inferred from the marker.

Exact replacement for Section 6:

"For stages 1-3, preserve logical calculation semantics and existing TTR function/capture/parameter identity. Prove unchanged base fingerprints, declared-session active fingerprints and stored declarations, candidate feature_set_hash, sweep feature_union_hash, config_hash, alias_map_hash, feature_params_hash, and corresponding walk-forward candidate/experiment/session identities on fixed inputs. Every stage changes feature_engine_version when its calculation, certification, evidence or prepared-representation implementation changes, including stage 2 with fixed TTR fingerprints. Debug selection is not a logical identity input.

"An old explicit precompute object refuses with ledgr_precomputed_engine_mismatch before candidates; regenerate it. Preserve every other current precompute ownership/axis/grid/fingerprint/alias validation and refusal. An in-memory shape change gets no legacy fallback. Durable sweeps retain their recorded engine marker; engine-only changes do not by themselves change config_hash or walk-forward keys, change the store schema, or declare all older stored results unreadable. Any later fingerprint/declaration change must name its propagated config, feature-set/union and walk-forward effects, rather than say only 'TTR config hashes change'."

Also narrow Section 4's universal refusal-parity sentence to calculation refusals, with the intentional new old-precompute engine mismatch stated explicitly. Preserve the separately accepted post-warmup-NA chore and its oracle-difference ledger if it lands first (macro_plan.md:657-674); do not absorb that behavior change into this neutral cut.

F12. Advisory: retain the sweep-reuse conclusion, but qualify its scope and remove an absolute claim.

Claim: each distinct definition is computed once and no per-candidate feature work remains.

Evidence: R/precompute-features.R:685-696 deduplicates by complete fingerprint across candidates. Sweep computation happens before tasks (R/sweep.R:276-317); candidates read the bound projection and their own definitions/aliases (:1649-1654,1747-1749). This supports one preparation per unique concrete definition, with internal segment/range/probe recomputations. Fingerprints include ID (R/indicator.R:282-304), so mathematically equal definitions with different concrete IDs are not generally deduplicated. Candidate feature materialization, parameter resolution and fingerprint/alias checking still occur (R/precompute-features.R:246-277,600-625), and candidate execution prepares its feature read surface.

Consequence: no per-candidate indicator-series recomputation is the useful claim. "The per-candidate cost is the fold" and "no per-candidate feature work remains" are too broad and can misdirect subsequent profiling. There is no need to invent another cache or execution engine.

Exact replacement: "Within one sweep, preparation computes the union of concrete fingerprints once and shares the immutable projection; candidates still resolve/validate identity and prepare their own aliases/read surface. Explicit precompute avoids repeating series calculation only when its existing ownership and causal-axis validation passes. The RFC changes the representation and calculator cost, not this reuse boundary."

F13. Advisory: two additional removals are small, neutral candidates before a new fast path.

Claim: the stage-1 list captures the obvious removable work.

Evidence: R/history-features.R:292 constructs the segment frame before checking the raw TTR cache at :294-300, so subsequent outputs can build a frame that is never read. This is relevant to the multi-field rows the seed proposes leaving framed. Also :343-345 slices every field into admission even though R/indicator-history.R:332-363 reads only normalized required_fields. This slicing can be restricted without narrowing the frame later supplied to custom code. Explicit precompute currently retains both split vectors and matrices (R/precompute-features.R:116-130), whereas the implicit sweep releases the split payload (R/sweep.R:292-294).

Consequence: there are cheap candidates that preserve current branches and may reduce the remaining gap before stage 3. Their savings are not measured here.

Exact addition: "Consider constructing a TTR frame only on a raw-cache miss, slicing only required fields for admission while retaining the complete callback input, and eliminating duplicate value ownership in explicit precompute when moving to matrices. Preserve output sharing and test each candidate against the pin before retaining it. These are candidates for the same removal cut, not prerequisites for another engine or cache."

Checked facts and input adequacy

The measurement tables are arithmetically consistent with the supplied aggregates. This supports the problem selection, not all its causal readings:

| Claim checked | Result and evidence |
| --- | --- |
| Wide feature shares 21%, 40%; 500x1260 sweep 20% | Correct rounded Cut-18 lean end-to-end shares: results/e2e_cut18_groups.csv:47,23,83 and summary.md:373-406. These are lean end-to-end shares of package feature work, not the pin's whole-run shares. |
| 0.08/0.83/1.10 s ledgr, 0/0.08/0.17 s bare TTR | Correct transcription of feature_split.csv:2-4. This measures compute only, not projection (features.R:47-49). Zero is clock/rounding resolution. The script checks the fast SMA5 values only and records a flag; it neither checks SMA10 nor stops on FALSE (features.R:50-57). |
| Step table | Rebuilt independently from the CSV in review_probe.txt. Walls, raw calls, treatment, segment sums, plane sums and grouped residuals agree within displayed rounding. The 1166x252 run's causality 0.005 s is shown as 0.00; it is not absent. The summary's standalone "segment framing 0.09" at summary.md:443 conflates 0.042 s frame with 0.052 s segment-other; the seed's table correctly calls their sum "segment frame and rest". Attribution and inferred savings need F1-F2. |
| Sweep bare-TTR six-definition clocks 0.24/0.48 s | CSV records 0.233/0.477 s, conventionally 0.23/0.48 at two decimal places (feature_steps.csv:36,70; feature_steps.R:117-120). Replace 0.24 with 0.23, or say approximately 0.24. These clocks use a mean over repetitions, unlike the profiled path median. |
| H1 582/1166, 7.8 ms vs 0.29 ms | Correct aggregate: features_h1.csv:2 gives 49.9%, 4.55/0.17 s, 7818/292 us. These are per instrument for the SMA5+SMA10 pair, not per indicator. Full H1 compute is 9.27 s; the 4.55 s subpath excludes certification/global probe/record manifestation. The classification is for close/SMA on those bounds, not the production gate. No private row-level claim was independently rerun. |
| Code map | Certification/canonicalization: R/history-features.R:19-151; range/cutoff preparation: :412-428,475-480; four segment branches: :282-324; planes: :540-611; causality: :647-742; projection/run entry: R/backtest-runner.R:664-680. Accurate with the qualifications above: zero-calculated definitions have no actual probe (:650-651), and the runtime custom refutation differs from prefix invariance. |
| TTR hard-wiring | Confirmed in certification/call keys and dispatch above; R/indicator.R:137-138, R/feature-parameters.R:290-299, R/strategy-provenance.R:104-116, R/indicator-history.R:203-268. The provenance dependency list is diagnostic metadata, distinct from indicator calculation identity. An additional adapter can currently run as custom through a series callback, or as fn-only; catalogue support is absent. |

Independently of the author, I derived the required counterexamples from the admission, segment, bounds, evidence and callback code, then executed the small synthetic classifier/calculation/fingerprint probes. I also compared installed-pin function bodies and formals with the checkout without loading checkout code: all 24 history-features, 49 history-substrate, 14 runtime-projection, 29 indicator-ttr and 19 features-engine function definitions compared equal. That establishes that these source anchors describe the supplied pin, rather than assuming the seed's mapping is current.

The smooth rectangular SMA fixtures are the right first inputs for common overhead and projection/sweep representation removals. They are not sufficient inputs for adapter architecture or a general simplicity gate. The synthesis needs cases derived from the semantic distinctions listed in F4/F8/F10. Keep H1 aggregates as evidence of an opportunity; a narrower production predicate needs its own coverage measurement by the authorized private-data executor, not access from this review.

Maintainer questions: none required. Keep stage 1 after Cut 21, internal adapters, plain R, and the engine fix in stage 1. macro_plan.md:1050-1069 confirms that order before slice 5. The requested revisions supply missing correctness obligations within those decisions. If an implementation cannot preserve TTR fingerprint payloads, F9 identifies the already-reserved decision and the concrete diff it must bring; it is not a reason to reopen the choice now.

What I checked and did not check

Read the seed including the maintainer answers; AGENTS.md; the design index; the requested contract rule groups; RFC pipeline and cycle rules; macro-plan ordering and relevant pending NA decision; the specified measurement runners/CSVs and feature/end-to-end summary sections; all named feature/adapter/projection/precompute code and the sweep/runner preparation paths. Followed identity into config hashing, walk-forward identity and sweep persistence, and checked the registered test callers relevant to proposed deletion and precompute shape. The review follows the Type 2 and evidence rules in rfc_cycle.md:274-282,304-312,330-338; acceptance is not implementation authority.

Ran only the small literal-script synthetic probe against the pinned library. Its second complete invocation exited 0 in about 0.6 s. R emitted locale-startup warnings; its versions and all probe outputs are retained. No benchmark timing windows, full suite, package check, long parity run, backend installation, TA-Lib execution, or private H1/vendor-data access occurred. I did not reproduce the author's timing sessions or obtain raw Rprof stacks, so the attribution defect is proven but a corrected numeric split is not claimed. The source-only profile and CSV reconciliation cannot establish future speedups.

No tracked file was edited and no commit was made. Git read commands refused with an unsafe-repository ownership error even with process-scoped safe.directory settings; I did not change global configuration. The supplied worktree's gitdir HEAD file reads 7eae4ac0eb57081fc2bf5e8bb111112fbd4e26ce. I did not independently establish the ancestry of the seed's dcc2fa9d evidence commit or a final git status. All authored artifacts are confined to the requested output directory.
