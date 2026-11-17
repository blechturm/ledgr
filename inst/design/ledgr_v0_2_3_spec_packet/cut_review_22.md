CHANGES_REQUIRED

Mode: Type 2 cut review; independent session, 2026-11-17.

Reviewed detached e458f38f7bb3af06a90b8a7a0845193c19513b50. The stage-1 direction stands. The cut cannot yet deliver a passing package with only its declared test changes, and its census does not establish the promised engine-version coverage. No finding requires reopening the maintainer's settled RFC, deletion or Cut 21 disposition.

Repository paths below are relative to C:/Users/maxth/ledgr-wt/cut22-review. Probe paths are relative to C:/Users/maxth/ledgr-wt/cut22-review-out. `tickets.yml` means inst/design/ledgr_v0_2_3_spec_packet/tickets.yml.

R1. Required: decision 7 omits two engine-version literals.

Claim: only LTB-0144's literal needs updating; LTB-0276 remains unchanged (tickets.yml:3408, :7370, :7402).

Evidence: the same old engine-version literal also appears in tests/testthat/test-fingerprint-stability.R:34, compared at :54, and test-strict-ttr-cleanup.R:182, inside LTB-0276. Neither assertion only exercises a deleted function, so decision 4's legacy-test permission does not cover them. The scalar-helper mock in test-fingerprint-stability.R:67 does exercise the deleted helper and belongs in decision 4's itemised retirement. The raw-call count assertions and source-text assertions do not need changing.

Consequence: a correct new version fails two tests the cut forbids changing. In particular, the assertion that LTB-0276 is unchanged contradicts the required version move.

Replacement for the engine-literal portion of decision 7 and corresponding ticket acceptance:

> Update only the feature-engine literals at test-strict-feature-acceleration.R:205, test-fingerprint-stability.R:34 and test-strict-ttr-cleanup.R:182, with the stated reason that the engine implementation identity changes. All indicator and strategy fingerprint literals stay. LTB-0276's raw-call counts and source assertions stay unchanged; its engine-version literal changes. List the legacy scalar-helper mock separately under decision 4. Preserve the other allowed representation changes and additive-test rule.

R2. Required: the census starts downstream of semantic preparation and mistakes partial identity coverage for coverage.

Claim: recensus from the measuring step's roots plus the stated bindings repairs every semantic dependency (tickets.yml:3381, :7399-7401).

Evidence: dev/spikes/feature_stage1_probe/census_walk.R:43 starts at compute, payload, projection, single-definition read and definition conversion. It does not start where a public entry prepares the substrate or selects the calculation start. R/history-substrate.R:371 selects that start; :1499 constructs the substrate, including lifetime segments at :1554, terminal segments and bar matrices. These producers are upstream of the six provisional mask readers, so following the readers cannot discover them. The hand-added decoder rows are also not traversed as roots; if they are retained, their dependencies need classification too. Some purported other bindings are explicitly only partial in results/census.csv, for example the warmup-rules table and width inference.

Executed counterexample: census_probe.R / census_probe.txt wraps ledgr_history_lifetime_segments, changing its known_inactive state level to known_active, and rebuilds the hostile fixture from the same inputs. Output: `version unchanged: TRUE`, `history identity unchanged: TRUE`, `axis unchanged: TRUE`, `feature result changed: TRUE`, `numeric cells changed: 2`, `NA placement changed: 3`, `producer in census: FALSE`. Binding the six downstream readers does not bind this producer's body. The policy identity is a versioned declaration, not an automatic hash of this implementation. See contracts.md#contract-context-strict-features and #contract-context-feature-path.

Consequence: the proposed repair can pass all four representative mutation tests while a missing semantic dependency still changes fresh feature results under the old engine and history identities. An existing precompute can consequently look current while differing from fresh preparation.

Replacement for the census and mutation acceptance:

> Begin the census at run, implicit sweep, explicit precompute and pulse-inspection feature preparation, including substrate construction and calculation-bound selection, then filter to the RFC's semantic categories. Include dynamically selected constructor/closure dependencies explicitly. Record the boundary for shared history producers; a manual rule-version constant alone is not automatic implementation coverage. For every retained semantic row, name a complete binding, not a partial output identity. Reconcile missing and extra rows on final code. Prove the engine binding for each newly bound helper by replacement, retain the four representative semantic mutations, and include the lifetime-segment-producer counterexample. A missing row or a falsely claimed separate binding fails. Do not hash arbitrary environments or every package function.

This expands discovery, not product rewrite scope: shared producers need classification and an adequate binding, not optimization in this cut.

R3. Required: revise the provisional default for read-only helpers.

Claim: all eleven UNSURE rows should enter engine identity because four readers decide what a stored plane means (tickets.yml:3388-3392).

Evidence: R/history-frame.R:341, :350, :359 and :665 read current projection records; none produces the reusable projection. The single-definition entry at R/history-features.R:769 recomputes on read and retains nothing in precompute. census_probe.R / census_probe.txt changes the evidence decoder's not_ready reason. Matrices, retained records and projection stay identical; read evidence changes; an old projection and a newly regenerated projection read identically under the new decoder. Regeneration does not restore the previous evidence. The concrete output is `prepared matrices and records unchanged: TRUE`, `projection unchanged: TRUE`, `old and regenerated object read identically under new decoder: TRUE`.

Consequence: automatically binding reader implementation makes old explicit precomputes refuse even when they contain exactly the state fresh preparation would produce. That does not close a stale-preparation hole. It broadens invalidation beyond the stated repair. The measuring census already distinguishes “not prepared state” from preparation, but decision 5 loses that distinction.

Replacement for the provisional-default paragraph:

> Bind the six substrate mask/bounds helpers and ledgr_feature_def_declarations, subject to the complete dependency reconciliation. Exclude the four pure read-side decoders and the recomputing ledgr_history_feature_planes entry from the precompute engine bind list, with that explicit reason. Keep their value/evidence parity tests. If a helper also produces or defines an encoding consumed by reusable preparation, identify and bind that shared rule rather than binding read-only presentation or recomputation merely by reachability. A reader-only change that leaves fresh and existing prepared state equivalent must not invalidate precompute; test that negative case.

R4. Required: make the keep decision attributable and specify the new timing and memory surfaces.

Claim: each candidate passes a median speed/2-percent rule against the cut base; candidate 5 passes on memory; cut17-helper-1 supplies the measurement precedent (tickets.yml:3366-3372, :7387, :7434).

Evidence: the first clause includes candidates 1-5, while the next gives candidate 5 a memory keep rule without expressly replacing its speed requirement. A cumulative comparison against the cut base also cannot establish each candidate's contribution: candidate 1's saving can hide a regression from a later candidate. The probe's probe_time.R:57 uses proc.time on sub-second compute calls and saves summary medians, not the raw paired observations. That is descriptive input, not the final 2-percent gate. The benchmark manual explicitly reports about 5-percent swings for sub-second cells (inst/design/manual/benchmark_methodology.qmd:313). dev/bench/timing/protocols/cut17-helper-1/protocol.md specifies Sys.time, frozen batches lasting about three seconds in the faster arm, and the timer/GC/warm-up boundary. The shared timing harness requires identical work strings (benchmark_methodology.qmd:355-360), while this cut intentionally changes engine markers and representation. Its shared harness has no peak-memory sampler (benchmark_methodology.qmd:352). A smaller retained object is not a measurement of sweep peak memory.

Consequence: an implementer could keep a regressing candidate on another candidate's saving, use an unresolved 2-percent measurement, or report a serialization digest/retained size as the wrong proof. Candidate 5's two apparent keep rules can disagree.

Replacement for the keep/measurement clauses:

> Candidates 1 and 4 are assessed separately; candidates 2+3 are one assessed unit. Name each unit's target cells before comparison and compare matched arms differing only by that unit, with prerequisite edits identical. These speed units require faster target-cell medians. Also compare the final package against the immutable accepted cut-base commit on all six run/sweep shape cells. Keep d5b3a151 solely as the semantic oracle. Candidate 5 has the memory rule instead of a minimum-speedup rule; all units retain the 1.02 regression bound on every measured cell.
>
> Commit cut22-feature-1's four protocol files before recording. Use at least eight alternating fresh-process pairs, Sys.time, and frozen repetitions making the faster arm's batch last about three seconds or more. Record timer resolution, warm-up, byte compilation, GC and cache lifecycle, raw observations and exact commands; retain failed attempts. An A/A record establishes whether the host resolves this margin; noise is inconclusive, not a reason to select favourable pairs. Name the feature clock endpoints and include the production engine-version work, or report it separately and include it in a complete preparation clock. Work signatures compare values, axes, planes and logical mappings, excluding only the declared engine marker/physical representation differences; fault controls still detect a changed value or plane.
>
> For candidate 5, measure the whole explicit-precompute object's bytes, and declare the sweep-memory metric, worker count and lifecycle before running it. One executable bounded choice is peak R heap for sequential sweep feature preparation, using the repository's gc(reset=TRUE)/max-used method in fresh children, with fixtures prepared outside the phase and the projection retained at its end. Label it peak R heap, not process-tree memory; validate sensitivity to an extra live allocation. Smaller retained size alone cannot satisfy the peak criterion. Keep the timing harness unchanged.

R5. Required: reconcile the scope exclusions with the authorized harness work and legacy inventory.

Claim: nothing in dev/lean_core changes, yet decision 8 modifies the FIFO capture, census and evidence; deletion acceptance permits no remaining caller anywhere in dev/ (tickets.yml:3420-3438, :7356, :7412-7417).

Evidence: the required FIFO files are dev/lean_core/parity/fifo_capture_tests.R, fifo_check.R and evidence/fifo_parity.csv, with the census currently under parity/evidence/cut21/ldg3248/review2/fifo_census/. Existing legacy callers also remain in historical developer scripts, for example dev/benchmark_ldg_712_indicator_series_fn.R:158, dev/design-checks/history_wave_stage1/burnin.R:6 and dev/spikes/history-indicator-conformance/runner.R:226. These are different from live package callers. No exported, vignette or article call to the three exact functions was found. R/features-engine.R:7 and :17 are live engine-hash references and must disappear with the functions, before the next oracle run.

Consequence: the literal exclusions prohibit work required elsewhere, and the no-dev-caller acceptance can demand historical evidence rewrites rather than safe removal from the current package. The FIFO disposition itself is authorized and does not need reconsideration.

Replacement for the relevant scope/deletion clauses:

> No lean-core execution code changes. Decision 8 alone may change its FIFO capture/check tooling, a maintained census tool and the replacement FIFO population evidence; fifo.R and every FIFO value oracle stay. Preserve the previous count and failure explanation in ticket evidence. Historical captured records are not rewritten.
>
> Delete the three named legacy functions and their engine-hash references together. Require no remaining caller using the candidate package in R/, registered tests, public documentation or maintained developer tools. Inventory historical developer consumers and identify those requiring their original installed pin; they may retain historical references. Migrate any maintained current-package consumer or report it before deletion. List every retired legacy test assertion and preserve its live-path claim where applicable.

R6. Advisory: pin the entire formatted-axis result, not just the format string/hash.

Claim: the same format string is sufficient for candidate 1 (tickets.yml:3342, :7353).

Evidence: R/runtime-projection.R:35, :40 and :48 consume it as matrix column names, pulse-index names and pulses_iso; R/precompute-features.R:783 hashes it. review_probe.R / review_probe.txt shows a named POSIXct axis preserves the original names on pulses_iso and on the character vector used as matrix column dimnames, while pulse_index has timestamp names. The reused probe's projection digest covers only feature_values and feature_planes (dev/spikes/feature_stage1_probe/probe_check.R:50), so it does not protect all these consumers.

Consequence: identical visible timestamps alone do not prove identical attributes at every consumer.

Suggested addition to LDG-3250:

> Compare the full pulse-name vector, matrix dimnames, pulse_index, pulses_posix, pulses_iso and axis_hash against the pin, including attributes and encodings. Cover named and empty axes, non-UTC inputs and fractional seconds. Reuse the pin's formatted vector unchanged; do not unname, round, sort or deduplicate it.

R7. Advisory: correct the measured-corpus description and retain explicit constructor-form coverage.

Claim: 284 cases are six substrates times three starts times sixteen definition sets plus read-entry cases (tickets.yml:3290; dev/spikes/feature_stage1_probe/findings.md:84).

Evidence: the committed fixtures contain fifteen sets. The actual total is 6 x 3 x 15 + 14 = 284. The four deterministic CSVs rerun byte-for-byte identically (reconcile_probe.txt); c2/c3/c23 each have zero differing cases, and the narrowed-custom negative control differs in 58. Thus the main empirical result is faithful; the factor count is a transcription error. Additional review probes found exact parity on nine sets, including the other built-ins, MACD histogram, BBands bundles, MFI/CMF, a custom OHLC volatility form, carry-excluded ROC, Wilder EMA, parameterized EMA and a parameterized bundle. They do not prove every possible form.

Consequence: the current rule has executable support beyond smooth close-only SMA, but a claim of sixteen sets is inaccurate, and successful outcomes alone need not prove the intended certification route was used.

Suggested replacement/addition:

> The measuring corpus has fifteen sets and fourteen single-definition read cases. The permanent corpus records certification outcome and field union for concrete, bundled and resolved parameterized forms, including a forged claim and unregistered forms. Required coverage includes hl/hlc/hlcv, separate MFI/CMF volume, custom ohlc and raw versus treated selection. A missing case or the wrong route fails even if both sides return the same refusal.

R8. Advisory: compare the two FIFO populations by keys as well as passing aggregate counts.

Claim: replacing fifo_parity.csv for the stated capture/population reason and passing on two captures closes the follow-up.

Evidence: tickets.yml:7320-7322 records the maintainer's precise reason and authorization. The old checker compares aggregate CSV rows; fifo_check.R:40-50 cannot establish equality of call populations with equal totals. The earlier investigation needed (file, test, digest) multiplicities and call order to isolate the unseeded strategies and by-reference artifact.

Consequence: the stated reason satisfies AGENTS.md's registered-oracle rule, and excluding test-rng-isolation.R from this census is the right bounded fix. Its registered tests must continue to run normally. Recording keys from only one capture leaves a weaker repeatability proof than the investigation already used.

Suggested addition to LDG-3254:

> Record file, test and call-time book/input digest in both independent captures; compare their ordered populations and key multiplicities after the named file exclusion. Refuse an omitted deterministic call or a changed key even when totals agree. Keep mocked/refusal accounting and every value comparison. Exclude the RNG file only from this capture/census, never from package testing.

Checked: the accepted RFC, its Type 2 review and confirmation; Cut 22 and workstream/ticket acceptances; Cut 17 oracle/measurement rules; macro-plan item c; LDG-3248's final two evidence entries; AGENTS.md, relevant contract rule groups, optimization shapes, spike and timing rules. Traced certification, canonical declarations, all five TTR input mappings, raw-result sharing and the separate volume argument. Candidate 5's production split reader inventory is correct: workers take history_substrate$feature_projection (R/sweep.R:1651), staging carries that substrate (:1328-1349), validation uses metadata and projection rather than payload vectors (R/precompute-features.R:155-318), ownership uses snapshot/policy/universe/range (R/history-substrate.R:233), and walk-forward delegates training to ledgr_sweep_window (R/walk-forward.R:594). No additional production split-vector reader or necessary logical-identity move was found. Preserve fingerprint-to-ID mapping, aliases and planes; this does not authorize changing reuse boundaries or adding an old-format fallback.

Executed only small pin/namespace-copy probes and the deterministic probe runner, writing all outputs here. The supplied pin was loaded from C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151; no Temp library was used. The R source diff against d5b3a151 contains only strategy-helpers.R and strategy-types.R, confirming the feature-path premise. Locale startup warnings occurred. Did not run timing windows, memory benchmarks, the full suite, package check, lean gate, FIFO capture suite or private-data work. Did not test a candidate implementation, which does not exist yet. No tracked file was edited and no commit was made.
