CHANGES_REQUIRED

Mode: Type 1 close review of workstream 41 (Cut 22), round 1; independent fresh session, 2026-11-18.

Reviewed 434cb9766b959cd8dd78bdfcd9b191ab1fc6cbd6 against b33e01d7. The R/ tree is identical to 45df6928. No finding reopens the accepted RFC, legacy deletion, FIFO disposition, or the maintainer's pending choice about keeping candidate 5 despite its failed rule.

Repository paths are relative to C:/Users/maxth/ledgr-wt/ws41-close-review. Probe paths and outputs are relative to C:/Users/maxth/ledgr-wt/ws41-close-review-out. `tickets.yml` means inst/design/ledgr_v0_2_3_spec_packet/tickets.yml.

F1. Required: a certification dependency still changes prepared values without moving either feature identity or engine identity.

Claim: every semantic census row has a complete binding; ledgr_function_fingerprint is covered as engine-version machinery.

Evidence: dev/feature_parity/census.csv:57 calls this helper "engine version machinery (the version computation runs it on every bound helper)". The new version instead deparses formals and bodies directly (R/features-engine.R:77); it does not call ledgr_function_fingerprint. Instrumentation in probes.R / probes.txt records zero calls to that helper and four other similarly classified determinism helpers while computing the unchanged 034f0c23... marker.

binding_probe.R / binding_probe.txt supplies a fixed, supported forged TTR SMA claim with deterministic constant-zero replacement callbacks. Initially certification replaces those callbacks with the canonical SMA. A real namespace replacement of ledgr_function_fingerprint hashes its original result once more. Output: `engine unchanged: TRUE`, `active feature fingerprint unchanged: TRUE`, `substrate history identity unchanged: TRUE`, `certification: catalogue -> custom`, `prepared values identical: FALSE`, `different finite numeric cells: 10`; the last finite value changes from 60.80647 to 0. Both preparations succeed. This is the same input definition and substrate, not two independently reconstructed definitions with different fingerprints.

The census check nevertheless accepts this helper as unbound. Its child-environment replacement test only asks whether the engine marker moves; for every `identity:` row it expects that it does not (dev/feature_parity/census.R:111, :121, :137). It never tests the claimed other identity.

Consequence: decision 5's repair remains incomplete. A helper governing catalogue matching can change fresh prepared values under the same engine and supplied active feature identities. The current mutation proof cannot reject this false separate-binding claim.

Fix: bind this semantic dependency and reconcile its dependencies under their actual roles. Reclassify the alleged machinery rows; retain exclusions only with a valid reason or a demonstrated complete identity. Add this fixed-claim mutation, and make separate-binding proofs observe the named identity or its refusal rather than treating an unchanged engine marker as proof of coverage. No recursive environment hash is needed.

F2. Required: a pure read-side helper unnecessarily invalidates explicit precomputes.

Claim: the bind list follows decision 5's preparation/read boundary.

Evidence: R/features-engine.R:21 binds ledgr_history_substrate_terminal_at; dev/feature_parity/census.csv:136 classifies it as preparation, although its first root is ledgr_history_feature_evidence. Its body merely selects `$sticky` from the shared terminal-planes helper (R/history-substrate.R:1409). Its callers are bar-history readers (R/history-frame.R:85 and R/history-treatment.R:431). Feature preparation calls ledgr_history_substrate_terminal_planes directly (R/history-features.R:191).

reader_probe.R / reader_probe.txt traverses the preparation roots without the added read roots: terminal_at is the only bound helper absent. Replacing it with a reader that inverts the returned mask gives `reader-only semantic mutation moves engine: TRUE`, `old and fresh complete precompute state otherwise identical: TRUE`, and `validating old precompute after reader-only change: ledgr_precomputed_engine_mismatch`. The complete-object comparison removes only the two engine markers.

Consequence: an old explicit precompute refuses even though it contains exactly the state fresh preparation produces. This is the unnecessary read-side invalidation rejected by cut-review R3 and decision 5.

Fix: exclude terminal_at with its read-side reason, retain the shared terminal_planes rule's binding, correct the census, and extend the reader-only negative test to this helper.

F3. Required: the oracle's field-union recording is inferred, not observed.

Claim: the oracle records and checks the field union actually used by candidate 2.

Evidence: dev/feature_parity/runner.R:205 independently derives a union from certification metadata and emits it at :227 before preparation. It does not observe ledgr_history_feature_fields or the fields handed to ledgr_history_feature_inputs, including the causality probe's calls.

probes.R / probes.txt replaces the candidate's field selector with all five fields. On MFI/CMF, the actual selection is `open,high,low,close,volume`, but the runner's calculation still records `high,low,close,volume`; the prepared result is identical. make_subset.R creates a nine-case subset of the unchanged runner/checker logic and committed pin expectations. subset/runner_fault.R applies that same all-fields fault. The committed check.R reports `cases 9 ... observations pin 117 candidate 117` and `CHECK PASS` against subset/expected.csv. Thus the optimization can be disabled while its field-union proof passes.

Consequence: the values and counted routes provide useful parity evidence, but the recorded union does not establish the claimed treatment mechanism or discriminate its regression, as decision 2 requires.

Fix: observe the candidate's actual selected/treated fields at the preparation and causality hand-offs and assert them against the certified expected union. Preserve the complete-frame assertion for mixed/custom definitions and the full-field single-definition read route. Add an all-fields fault that fails the mechanism assertion even when values remain identical; do not require the pin's deliberately wider physical treatment to equal the optimized candidate's.

F4. Required: resolved parameterized forms are absent from the permanent value corpus.

Claim: decision 2's concrete, bundled and resolved parameterized forms are all covered with certification, field-union and value observations.

Evidence: tickets.yml:3343 expressly requires these forms. dev/feature_parity/corpus.R:141 builds only concrete definitions and concrete bundles; no case constructs ledgr_param or resolves a parameterized feature map. runner.R:214 takes all its compute sets from that function. The parameterized SMA in identity.R records two fingerprint identities, not its feature values, treatment or execution route.

exactness_probe.R independently resolves parameterized RSI and a two-output BBands bundle, computes them on empty and hostile substrates, and exercises their single-definition reads. Both installed arms report three `catalogue ttr` certifications and a `close` union. final_checks.txt reports `extra pin comparisons: 43 identical: 43` for these and the other small probes. These results support the implementation but do not add the missing cases to the permanent checker.

Consequence: the claimed permanent coverage and missing-case refusal do not cover this explicitly required constructor route. A regression confined to resolved parameterized forms can escape the registered corpus.

Fix: add resolved parameterized single-output and bundled forms to the permanent corpus, with certification, observed fields, cached/closure routes, values and refusal coverage. Register their expected cases so dropping them refuses. Keep the existing corpus and registered tests intact.

F5. Required: candidate 4's keep verdict treats one A/A median deviation as the uncertainty of the measurement.

Claim: candidate 4's target gains are resolved beyond A/A noise, so decision 3a permits keeping it (tickets.yml:7463).

Evidence: all six timing records pass the unchanged shared checker and every saved median ratio reproduces (evidence_checks.R / evidence_checks.txt). Candidate 4's target ratios are 0.9899164 and 0.9918946. The justification compares these gains with the single A/A median deviations of about 0.3% and 0.2%. The committed A/A pairs on those cells range from 0.9605950 to 1.0244915 and from 0.9769138 to 1.0332092.

noise_probe.R / noise_probe.txt recomputes the median-ratio statistic under all 256 within-pair arm-label exchanges of those same A/A observations. The arms contain the same commit. Apparent improvements at least as large as candidate 4's occur in 12.5% and 18.75% of these labelings. The central 95% ranges are approximately 0.98450-1.01575 and 0.98527-1.01495, encompassing both claimed gains. This is an uncertainty diagnostic from committed observations, not a new timing window or a proposed new significance gate.

Consequence: the numbers reproduce, but the inference that the host resolves these 0.8-1.0% gains is not established. A/A VALID proves record validity; a near-one realized A/A median does not establish that uncertainty is smaller than the gain. Decision 3a and protocol.md:73 require an unresolved unit to remain inconclusive, not kept.

Fix: correct the keep justification and apply the accepted noise rule. Either provide a reproducible uncertainty assessment establishing resolution under a compliant measurement record, or mark unit 4 inconclusive and revert it. Preserve these observations and any rejected attempts; update affected final-code evidence if the product changes. This finding adds no minimum speedup and makes no judgment about the pending candidate-5 decision.

F6. Advisory: the stored-config legacy list-definition issue is real and predates this cut.

Claim: backtest-runner.R's fallback list definitions can be refuted by the live causality/parity check; this is flagged only.

Evidence: R/backtest-runner.R:1098 and :1105 still construct ledgr_feature_return_1 and ledgr_feature_sma_n. They are distinct from the three functions authorized for deletion. exactness_probe.R runs the same sma_n definition on the supplied pin and final package: both refuse with ledgr_indicator_gap_parity, with identical recorded condition fields. probes.txt shows the scalar/series discrepancy at tolerance zero on a concrete fixture.

Consequence: deleting the old engine has not created this discrepancy. Retiring its old built-in checker block does not establish that these fallback list definitions work on the live path.

Fix: retain the flag for separate maintainer disposition. No expansion of decision 4 or compatibility fallback is requested in this review.

Checked:

- Read Cut 22, workstream 41, LDG-3249 through LDG-3255, the three cut-review records, accepted RFC, AGENTS.md, the four named contract groups and the seven optimization shapes. Traced field selection, raw/treated admission, custom mixtures, hl/hlc/ohlc/hlcv mappings, MFI/CMF's separate volume argument, certification, short-sample guards, raw-cache keys, derived outputs and sharing, the causality inputs and single-definition entry. No current value discrepancy was found in the kept speed changes.
- Installed 45df6928 into this review's output library. The final oracle reproduces: 548 cases, 57 refusing pin cases, 6,039 observations, CHECK PASS. Additional fixed-input pin probes match in all 43 results, including resolved parameterized forms and a TTR export masked before certification. The accepted implementation captures that resolved function; masking after certification would not replace the captured function. The raw-cache key, selection/normalization and sharing changes were traced against the pin; no ordinary-input counterexample was found.
- Re-executed all seven fault types on a twelve-case subset: each exits 1 with its intended signal. Missing arm, case and component each exit 2; pin against pin exits 0 (fault_subset/checks.txt and missing_controls.txt). Reviewed the committed full-corpus fault transcripts and distinct signal sets. F3 records the additional fault they miss.
- Census check reproduces 278 rows: 134 engine, 129 excluded, 15 identity, with no missing/extra walked rows. That mechanical pass does not resolve F1/F2. The preparation roots include substrate construction, calculation bounds and dynamic emitted closures; the lifetime producer and six named mask/bounds helpers are bound. The five expressly excluded read entries stay unbound.
- Diffed every tests/ change against b33e01d7. Existing-test changes match decisions 4 and 7 and the itemized reasons; the census tests are additive. Fingerprint literals, LTB-0276 counts and source predicates stay. Three installed-package test files (feature-engine-census, fingerprint-stability, strict-ttr-cleanup), seven tests, pass with zero failures/errors. This independently confirms the wrapped d353261b... literal; the ordinary version is 034f0c23.... ledgr_validate_feature_def has only registered-test callers and its stated test-seam entry; deleting it is outside decision 4. The three deleted functions have no maintained current-package caller; historical consumers are inventoried.
- Candidate 5's revert is complete: its affected product files, physical-shape tests and three developer producers equal their pre-candidate-5 state at 9f4c1a24. Its object-byte and heap medians reproduce exactly. Whole-object bytes roughly halve; 1166x252 peak heap falls 14.44%; 500x1260 changes by only 1,176 bytes and its sensitivity remains unresolved. The failure, revert and numbers are recorded. No recommendation to override that result is made.
- Rechecked all committed timing attempts with the unchanged check.R, including saved-input verification: A/A VALID and five gate records PASS. Matched unit-arm source differences isolate their named units. Protocol inputs predate recording, clocks include the engine marker, and all six final/base ratios reproduce: 0.488891, 0.443443, 0.765667, 0.787203, 0.780749, 0.819788. Units 1 and 2+3 have substantial target gains; F5 concerns unit 4's noise interpretation. Counted one engine-version call per run, two-candidate sweep, precompute, reuse validation and inspection (final_checks.txt).
- Decision 6's committed identity comparison reproduces: 155 equal identities, changed engine, old-precompute engine refusal with zero strategy calls, readable old run and recorded old sweep engine. Inspected the identity construction, including experiment identity within the walk-forward session hash. No emitted-closure, fingerprint, declaration, config, alias, feature-set/union or walk-forward identity change was found in the product diff.
- FIFO changes are confined to the permitted tooling and population evidence; fifo.R, fifo_parity.R and value oracles are unchanged. The two-capture checker compares ordered file/test/kind/digest keys and multiplicities, retains value/refusal accounting, and excludes RNG isolation only from capture/census. Committed per-file populations sum to 145,630 lot calls plus 39 input refusals, 60,468 distinct keys across 117 files; the recorded two-capture check and equal-total negative controls pass/refuse as stated. The prior 156,571 count and rejection reason are preserved.
- Reviewed full-suite and package-check records: 232 files, 1,353 tests, zero failures/errors, one skip; R CMD check Status: OK. Recounted both full lean CSVs: 203 workloads, 3,136 tables, zero differences, 202 PASS and one PASS* each. Independently ran dense_risk_features through lean_gate.R at debug 0 and 1: 30 tables and zero differences each, frozen paths matched, overlaid engine 034f0c23....
- Recomputed lines: 55,048 -> 54,978 (-70), or -129 excluding the 59-line bind list. The seven-shape walk finds removal of repeated formatting and unused slicing/frame work, no new scale-growing loop in changed production code; the definition walk and fixed bind-list walk are explicit. NEWS and the RFC status describe the declared engine/precompute impact. The final checkout is clean. Targeted tooling regenerated the cpp11 files' line endings; those were restored, with no retained tracked change and no commit.

Not checked by fresh long runs: timing windows, workload memory benchmarks, full test suite, package check, full lean gate, FIFO captures or the full FIFO replay. Their committed inputs, arithmetic, tooling and records were reviewed as described; the large FIFO capture chunks were not independently regenerated. No private data, E:, ledgr-research or vendor data was accessed. No library under AppData/Local/Temp was used. Scratch builds, probes and review outputs are under the requested output directory. No maintainer design decision is needed to address F1-F5 under the accepted cut.
