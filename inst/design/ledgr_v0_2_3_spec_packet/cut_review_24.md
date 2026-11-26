CHANGES_REQUIRED

Mode: Type 2 cut review; independent session, 2026-11-25.

Reviewed `fd9dd63015f70a463ee72c9c73377c9b9543a7b7`, detached. The cut carries the accepted design, including all four maintainer decisions. The changes below make its measurements and proofs decidable and reconcile its test restrictions with the required implementation. None asks the maintainer to decide those four matters again.

Repository paths are relative to `C:/Users/maxth/ledgr-wt/cut24-review`. `tickets.yml` means `inst/design/ledgr_v0_2_3_spec_packet/tickets.yml`. Probe paths are relative to `C:/Users/maxth/ledgr-wt/cut24-review-out`.

R1. Required: freeze the calculation of the decision statistics and a heap measurement, not just their names.

Claim: decision 3 and LDG-3258 supply enough protocol to resolve lazy adoption and stage-3 retention.

Evidence: `tickets.yml:3837` and `:8057` name an A/A-derived label-exchange range and memory noise figure, but give neither calculation, a memory phase, nor a memory collector/checker. The shared checker computes a ratio of arm medians and compares it with a numeric bound (`dev/bench/timing/check.R:287`); it does not compute label-exchange ranges. The manual explicitly says the shared harness has no memory sampler (`inst/design/manual/benchmark_methodology.qmd:352`). Cut 22 supplied its separate memory boundary, fresh children, metric, repetition count and sensitivity check in `dev/bench/timing/protocols/cut22-feature-1/protocol.md`, implemented by `dev/feature_parity/memory.R:6`, `:82` and `:134`. Its wall-time uncertainty calculation is described in [inst/design/ledgr_v0_2_3_spec_packet/ws41_close_review_round1.md:65](https://github.com/blechturm/ledgr/blob/ea580bc6b1d345f7aae9e6836b4f12fe94e18afe/inst/design/ledgr_v0_2_3_spec_packet/ws41_close_review_round1.md#L65); it was a diagnostic, not an existing shared-harness gate.

Consequence: a valid timing CHECK PASS does not establish a resolved saving or the heap condition. Different reasonable interpretations can retain different implementations from the same observations. LDG-3258 is the right ticket to settle this before either candidate exists; the cut needs to say what it freezes.

Replacement: append to decision 3 and replace LDG-3258's protocol acceptance item with the following, retaining its workload list as corrected by R2:

> Freeze workloads and the calibration method before the base A/A record, and freeze the resulting numeric protocol before any candidate comparison. Use eight alternating fresh-process pairs per cell. Calibrate and freeze repetitions so each timed batch lasts about three seconds or more, including the certification and admission cells. Preserve every pair and attempt. For each cell, compute all 256 within-pair label exchanges of the base A/A observations using the shared checker's statistic, median(candidate) / median(base). Commit their central 95% interval [L, U], using quantile type 7, and the script and raw observations that produce it. A measured ratio below L resolves a saving; above U is a regression; otherwise no saving is established. Apply this separately to every measured feature cell and certification cell. Freeze U as the corresponding no-regression bound; retain the separate saving test. Record the actual host state. Do not infer a saving from CHECK PASS alone.
>
> Name and commit the peak-R-heap collector and checker under the cut protocol, reusing or extending dev/feature_parity/memory.R rather than copying the timing harness. Measure both wide shapes on the run and sweep preparation paths, with fixture/substrate construction outside the phase, the production preparation and integrated projection inside it, and the projection retained at the end. In each fresh child, reset GC maxima immediately before the phase and record max-used Ncells and Vcells in bytes afterwards. Use eight alternating children per arm and cell. Record loaded library/commit, debug=0, phase, raw bytes and host state. From the base A/A children compute all within-pair label exchanges of the difference of arm medians; memory noise is the larger absolute endpoint of its central 95% interval (quantile type 7). Retention requires the candidate-minus-stage-2 median to be no greater than this figure on every memory cell. An extra live 8 MiB allocation inside the phase must move the measurement beyond that noise on each arm; otherwise the memory evidence is inconclusive. Commit a machine-readable retention verdict and its inputs. Memory is not encoded as seconds or an equal-work string in the timing harness. Every memory child sets the debug value explicitly.

This supplies a concrete method using the cut's existing precedents. It does not require a quiet host, another execution engine or process-memory measurement.

R2. Required: separate custom-only, hostile zero-admission and actual low-admission costs at a useful shape.

Claim: the three admission cells in decision 3 cover synthesis rule 9's rejected-cell costs.

Evidence: `tickets.yml:3841` makes zero admission custom-only, while `:3842` calls the hostile corpus substrates low admission. The cut also correctly requires custom-only preparation to build no gate planes (`:8164`). The hostile substrates are three instruments by ten sessions (`dev/feature_parity/corpus.R:22`, `:23`, `:49`), and the committed gate count records zero admissions for both SMA definitions on all three policies (`dev/spikes/feature_stage23_probe/results/gate_count.csv:20`). My independent four-clause calculation reproduces 0/3 on each hostile substrate, 4/6 on each panel, and their dimensions (`review_probe.R`, `review_probe.txt`). It does not call the spike's gate. Thus custom-only bypasses gate construction, and the proposed low cell has no admitted work. Neither is a wide, mostly rejected workload. The public PIT panel is useful mixed coverage, but is 197/200 for these SMA definitions, so it is almost fully admitted.

Consequence: tiny hostile calls can be batched long enough to measure fixed overhead; they cannot establish how the gate's mask/finiteness work scales on a wide rejected panel. Certification's fixed cost can dominate them. A gate that skips planes for custom definitions yet pays too much on hundreds of certified rejected instruments can pass the named cells. There is also no genuinely low, nonzero admission cell as written. This weakens rule 9, rather than challenging its conservative gate.

Replacement for decision 3's admission-cell clause and the corresponding LDG-3258/LDG-3265 lists:

> Keep the hostile corpus substrates as semantic and small-overhead controls. Time four admission workloads, each on both the run and sweep preparation sequences: (a) custom-only on 500 x 1,260, using a deterministic close-returning series callback with its matching scalar callback, requires_bars=1 and required_fields='close'; (b) certified zero admission on 500 x 1,260, derived from the dense public fixture by removing one middle-session bar from every instrument while retaining that expected session, with price_carry=2; (c) certified low admission on the same shape and policy, leaving exactly five instruments complete and removing the same middle-session bar from the other 495; (d) the existing simulated PIT panel, using the exact generator, dates, seed and policy of feature_stage23_probe/gate_count.R. Certified cells use Cut 22's run and sweep SMA definition sets. Freeze bounds, definitions and fixture digests in LDG-3258. Independently establish and commit expected admission counts before stage 3: custom-only 0 with no gate construction, certified zero 0/500 per definition, low 5/500 per definition, and the PIT panel's per-definition counts. Observe actual execution choices separately. Batch complete preparations to the protocol's duration; do not enlarge only the repetition count and describe the tiny corpus as a scaling test. Retention applies to all these measured cells.

The original hostile fixtures stay unchanged. The additional large fixtures exercise the cost the accepted rule asks the cut to own.

R3. Required: authorize the unavoidable registered-test changes explicitly.

Claim: the cut can change the engine version twice, run the suite with debug on, and pass that suite with only decision 9's listed test changes.

Evidence: `tickets.yml:3885` lists the debug helper, permanent-checker mechanism changes, corpus additions and optional refusal exception. It omits the three current engine-version literals at `tests/testthat/test-strict-feature-acceleration.R:205`, `test-fingerprint-stability.R:34` and `test-strict-ttr-cleanup.R:182`. Both stage closes require a changed engine version (`tickets.yml:8124`, `:8223`). This is the same issue Cut 22 explicitly handled in its decision 7 (`tickets.yml:3481`). Also, the suite-on debug shadow intentionally adds segment/backend calls, while registered package assertions still count every call: LTB-0143 at `test-strict-feature-acceleration.R:150` and `:166`, and LTB-0276 at `test-strict-ttr-cleanup.R:45` and `:63`. Their helper reaches the common preparer (`tests/testthat/helper-indicator-history.R:66`). The permanent-checker permission does not authorize changing these package assertions.

Consequence: correct implementation cannot meet the test gate under the stated restriction. Keeping an old engine hash, hiding shadow calls, or disabling debug across these tests would evade a requirement. This is separate from the stage-2 permanent-checker gate, which is achievable.

Replacement: append to decision 9 and to LDG-3261/LDG-3266's test acceptance:

> At each implemented stage update only the feature-engine literals at test-strict-feature-acceleration.R:205, test-fingerprint-stability.R:34 and test-strict-ttr-cleanup.R:182, with the stated reason that engine implementation identity changes; keep every indicator and strategy fingerprint literal. For stage 3, revise only the mechanism-count assertions/recorders in LTB-0143 and LTB-0276 that debug shadow execution changes. Observe production preparation, debug shadow and causality work separately, require the existing production and causality counts where their work is unchanged, and assert the additional shadow counts independently. Keep canonical-dispatch, exact-value, raw-sharing, source and refusal assertions. The suite remains debug-on. Record each test change and its reason in its ticket; these permissions do not extend to semantic expectations or unrelated fixtures.

R4. Required: the changed-engine identity mode needs the completeness guard that Cut 23 added only to its other mode.

Claim: the identity checks named at both closes prove every required logical identity is unchanged.

Evidence: `tickets.yml:8124` and `:8223` select changed-engine mode. That branch takes its comparable names from the base record (`dev/feature_parity/identity_check.R:36`), never from an independent required set. The committed-name-set and duplicate checks start only in the unchanged-engine branch (`:53`). The Cut 23 close evidence explains exactly this shared-omission defect and its correction in that branch (`tickets.yml:8031`). I ran the current changed-engine checker on the committed Cut 22 base/final records: original PASS, removing `walk_forward:session_id` from both PASS (154/154), renaming it in both PASS (155/155). See `review_probe.R`, `identity_original.txt`, `identity_missing_both.txt` and `identity_renamed_both.txt`. These are checker probes using saved records, not a rerun of the identity workload.

Consequence: the two requested closes can certify an omitted required identity. LDG-3258's new emitted-function pin does not repair missing walk-forward/config/union observations in the separate identity checker. Rule 13's completeness remains unproved.

Replacement: add to LDG-3258, before refactoring, and reference it in both closes:

> Freeze the required record-name sets for changed-engine identity comparisons, including the shared logical identities and the mode-specific base/store/precompute records, independently from identity.R's recording sites and synthesis rule 13. Make changed-engine mode validate each arm against those committed sets, reject missing, unexpected or duplicate records, and require exactly one engine record per arm before comparing values. Keep its engine-change, old-precompute-refusal and stored-result-read checks. Controls removing or renaming one required identity in both arms, dropping one in one arm, duplicating one and removing an engine record must fail; complete original records must pass. Commit the transcripts. The new emitted-function pin also checks its required case/component population independently, so deleting a pinned form cannot pass by reducing both records.

This extends the established Cut 23 proof method to the mode this cut actually uses; it changes no product identity.

R5. Required: expose exact calculated counts to an independent witness, not only their selection effect.

Claim: the named permanent observations and stage-3 witnesses can detect a wrong calculated count even when values and causality selection remain correct.

Evidence: rule 7 requires exact calculated counts; `tickets.yml:8166` repeats it. The current runner records selected instruments/positions, values and planes, but not the `calculated_count` matrix handed to causality (`dev/feature_parity/runner.R:208`, `:241`, `:287`; `R/history-features.R:509`, `:521`). LDG-3264 names gate choices, adapter/backend calls, cache hits and treatment, but no count observation (`tickets.yml:8183`). My count-only probe increments every positive accumulated count before calling the original causality routine. Counts change from `118 118 118 118 2 118` to `119 119 119 119 3 119`; the selected instrument and the complete returned values/plane records remain identical (`count_probe.R`, `count_probe.txt`). A per-cell debug comparison cannot by itself detect a subsequent accumulation error, and selection equality is weaker than count equality.

Consequence: a new direct-path count accumulation can be wrong while all the named external semantic components agree. The debug success comparator must itself also have a count-only negative test; the required condition-field mismatch test does not exercise that branch.

Replacement: add to LDG-3258's frozen base evidence and LDG-3263/LDG-3264's acceptance:

> Observe the actual calculated_count matrix at the causality-entry seam, without a production-only test counter. Freeze base general-path expected matrices before stage-3 edits for admitted, fallback and mixed preparations, including later starts, short/never-ready slices and output carry. Compare the candidate's production matrix exactly with them and account for debug work separately. A count-only fault that changes positive counts while preserving which.max and sampled positions must fail. Add debug comparator negatives differing only in one count and only in one segment-ready record, as well as the condition-field-only negative already required. Values, record and refusal expectations continue to come from the pin or frozen base general path, never from the candidate.

R6. Required: a valid negative measurement must be able to finish its decision ticket, and dropping stage 3 needs a close branch.

Claim: LDG-3260 and LDG-3265 can resolve all the adopted/lapsed/retained/dropped outcomes they authorize.

Evidence: both require a matched record with the harness check passing (`tickets.yml:8106`, `:8206`), while their next items explicitly allow no saving or a retention failure (`:8108`, `:8207`). The shared checker fails a ratio above its bound; it does not label that a valid negative decision. In addition, after LDG-3265 drops stage 3, LDG-3266 still unconditionally asks for stage-3 mechanism fault controls and a second engine change (`:8221`, `:8223`), even if all the stage-3 production edits were reverted.

Consequence: the tickets demand positive evidence to record an authorized negative result. This encourages rerunning until a passing record exists, or retaining unnecessary code/hash changes merely to close a dropped stage. The split into two measured decisions is sound; these completion conditions are not total.

Replacement for LDG-3260's and LDG-3265's record acceptance, with the following close qualification added to LDG-3266:

> The matched record satisfies every shared-harness validity, provenance, work and completeness check. Keep and report its performance verdict even when ratios fail the frozen bound. A record failing only a performance bound is valid negative evidence for lapse/drop; invalid or inconclusive evidence establishes no saving. Do not obtain a passing record by dropping pairs or retrying without the harness's recorded attempt disposition.
>
> LDG-3266 closes the retained implementation if the shortcut is kept. If LDG-3265 drops it, record that disposition, remove its production calculator/gate and candidate-specific mechanism expectations, preserve the stage-2 semantic and unchanged mechanism proofs, and verify the contract/map edits were reverted. Apply engine-change and precompute-refusal checks to actual retained semantic implementation changes; do not require an artificial second engine change when the final semantic implementation is the stage-2 close. Record any retained debug scaffolding and its identity treatment. Prototype measurements and rejection reasons remain evidence. A named retention exception still requires the maintainer's recorded disposition before closing.

Checked: the rule-to-ticket map is otherwise faithful. This is the complete map, with the proof qualifications above:

| Accepted obligation | Cut decision / tickets |
| --- | --- |
| Rule 1, fixed registry and conditional ledgr entry | Decision 1; LDG-3259, including TTR-only fallback |
| Rule 2, complete adapter responsibilities | LDG-3259 scope expressly incorporates rule 2; readers, catalogue layout, source values, parameter constructors and provenance are covered |
| Rule 3, identity-based ordered certification and TTR validation | LDG-3259's eager stage and hostile witnesses |
| Rule 4, measured lazy construction and exact eager domain | Decisions 3-4; LDG-3258, LDG-3260; only the keyed maximum-width SMA exception |
| Rule 5, one preparer and early-return/reach boundaries | LDG-3263, first acceptance item |
| Rule 6, conservative gate and transient instrument flags | LDG-3263, scope and gate acceptance |
| Rule 7, arithmetic reuse, records, ordering, raw sharing, fallback frame | LDG-3263; LDG-3264; R5 closes the count observation gap |
| Rule 8, production guards and debug outcome comparison | Decision 6; LDG-3262, LDG-3263; suite/parity close in LDG-3266 |
| Rule 9, measured retention, heap, size and exit | Decisions 3, 7-8; LDG-3265, LDG-3266; R1-R2 and R6 repair the decision evidence |
| Rule 10, independent pin and direct-backend parity | LDG-3261, LDG-3266; existing semantic exclusions and conditional exception remain bounded |
| Rule 11, unchanged stage-2 mechanisms, narrow stage-3 replacement | Decision 5; LDG-3261, LDG-3264; pin semantics stay independent |
| Rule 12, both closes' registered witnesses and gut | LDG-3259, LDG-3263, both closes; R3 supplies necessary package-test permissions |
| Rule 13, emitted/logical identities, census and per-stage engine effect | LDG-3258, LDG-3259, LDG-3261, LDG-3266; R4 repairs completeness |
| Exact contract replacement and representation-map row | Decision 8; LDG-3263; undone if dropped |

All six final-review patches are carried: the exact two-width eager domain and both renamed-SMA witnesses; the retention test rather than report-only costs; the TTR-only fallback; unchanged stage-2 mechanism expectations with namespace lookup; pulse inspection and empty bounds; corrected evidence citations through the patched authority. No cut clause reinstates metadata-only recognition, removes synthetic validation, relaxes the gate or expands the catalogue. The sequencing is honest: stage 2's close review precedes LDG-3262, and LDG-3264/3265 join before the final close. Correctness witnesses in LDG-3263 must pass before its performance comparison; LDG-3264's final checker work may follow without making the candidate its own oracle.

The stage-2 permanent-checker gate is achievable as written on its existing expectations. Built-in construction hits none of its counted backend seams; attempted TTR certification retains one synthetic call. My seam probe reproduced zero and one respectively (`review_probe.txt`). Registry callbacks must continue namespace lookup, as the cut already requires. Corpus additions can gain independently pin-derived expected rows without changing any existing row. If a new certification-refusal case is added to that corpus, its certification must be observed inside the refusal boundary: today's runner certifies outside `observe()` at `dev/feature_parity/runner.R:284`. Separate registered certification tests also satisfy the witness obligation. No blanket count waiver is justified.

The proposed witnesses otherwise can fail the relevant wrong implementations: the SMA/RSI conflicting claim and recomputed/copied-function cases challenge metadata selection; invalid ROC/MACD definitions and preserved synthetic-call observations challenge lost validation; MACD and BBands invocation/sharing/separation observations challenge wrong raw-call grouping even when finite inputs give equal values; plane digests challenge segment errors; competing errors in both definition orders and across instruments/ranges challenge first-refusal changes. Gate near misses, independent execution observations and the full-coverage gut challenge carried/terminal admissions. The admitted runSD(1) refusal plus success/refusal and condition-field-only negatives challenge a success-only comparator. Pin-only expectation provenance and reviewed diffs are explicit acceptance requirements, not permission to regenerate expectations from the candidate. R4-R5 identify two additional false passes in the named proof tools; I did not infer that every future test already exists.

Decision 6 meets the current-cut part of pulse-plumbing R1 and synthesis rule 8: one private default-off flag, restored state, suite-on, parity-on/off and explicit timing/parity child selection, without removing current production guards. Sweep's feature union and common preparation run in the parent at `R/sweep.R:276` through `:291`, before staging at `:355` and mirai candidate submission at `:1565`. Worker-local derived history planes (`:1328`) are not another feature calculation. Thus the conditional mirai clause does not presently require carrying this flag into candidate workers merely to exercise this shortcut. The standalone parity/timing children do require explicit setting; R1 above includes heap children. The future lean switch's wider assertion/property obligations remain deferred as the synthesis states. Pulse inspection reaches the same preparer through `R/pulse-snapshot.R:395` and `R/history-substrate.R:381`.

Every measured_input number is traceable, with these limits:

| Number | Evidence and interpretation |
| --- | --- |
| 49-59% wide, 27% on 10 x 7,200 | `dev/spikes/feature_stage23_probe/results/direct.csv:2` through `:7`, ceiling_saving_share. Subtracted component medians, including empty record assembly; neither integrated savings nor an upper bound, as synthesis:40 states. |
| 13,408 identical admitted TTR SMA cells | Sum of admitted/cells_compared in those six rows, all cells_differing=0. SMA only; no refusal-order, raw-sharing or accumulated-count proof. |
| About 14 ms per definition | certification_s / defs in the same rows: about 27.7-30.3 ms for two or 82.5-92 ms for six. Descriptive busy-host results. |
| Dense, 197/200 PIT, 4/6 on each panel, none hostile | `results/gate_count.csv`, conservative rows for the two SMA definitions; `gate_count.R` supplies fixtures/policies. These are not every catalogue row or real-data coverage. Hostile counts and small shapes independently reproduced here. |
| 57 lines, nine functions | Non-adapter rows of `results/ttr_inventory_by_function.csv:2` through `:11`: sum code_lines=57, nine distinct (file,function_name) pairs. There are ten grouped rows because one function has two kinds; the cut's nine is correct. |
| 68b505b9 and unchanged R/ | `git diff --stat 68b505b9 HEAD -- R` is empty at the reviewed commit. Independently compared installed function bodies/formals with source: 269 functions across the thirteen named R files, zero differences (`review_probe.txt`). |

The maximum-SMA, both renamed-SMA, SMA-with-RSI-claim, validation-suppressed invalid ROC/MACD, and runSD(1) examples were independently executed in `certification_probe.R` / `certification_probe.txt`. The observed classes/custom outcomes agree with the synthesis; runSD(1) certifies and then refuses preparation. This establishes their usefulness as hostile inputs independently of the cut author. It does not prove the not-yet-written candidate.

Also checked Cut 22/23's workstreams, ticket evidence and review corrections, the permanent runner/checker/corpus, census and identity machinery, shared timing protocol/collector/checker and Cut 22 memory collector, the accepted parent Sections 4/6/7, synthesis/final review and response records, the relevant contracts and optimization/benchmark rules, and the representation-map requirement. The four maintainer choices need no new question. LDG-3258 should precede all product edits; it currently freezes emitted identities and nominal workloads, but R1, R2, R4 and R5 name the missing baseline proof/calibration inputs.

Not checked by execution: timing windows, peak-heap benchmarks, the full permanent oracle/fault driver, full tests, R CMD check, real/vendor data, native-code behavior or a candidate implementation. Existing probe timing/value totals were audited from committed files, not rerun. Small probes used the supplied read-only installed build; locale startup and expected coercion/TTR warnings occurred. All scripts and outputs were written only under cut24-review-out. No tracked file was edited, no commit was made, and final git status is clean. Git's implicit repository discovery refused ownership checks; read-only commands with explicit git-dir/work-tree verified HEAD, the R/ diff and status without changing Git configuration.
