CHANGES_REQUIRED
Mode: Type 2 cut review, before implementation; fresh reviewer at the supplied fc66c0f8 checkout.

**Role:** record
**Status:** accepted
**Authority:** Non-binding review record. Its disposition is recorded in Cut 25 cut_review in tickets.yml.

The three chores follow the maintainer's direction. TTR catalogue rows are within Section 6's decision: it says an undefined indicator cell reports NA, without a custom-indicator exception. Keeping the common normaliser is faithful; no maintainer question is needed. The required corrections concern an omitted existing test change, the oracle's fault proof, and the reach and coverage of the NA change.

R1. Required: name the existing NA-refusal expectation that must change.

Claim: decision 3 says “No registered test changes,” and LDG-3269's change allowance does not name an existing feature-series oracle change (`inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:4146`, `:8656`). The final suite is supposed to pass.

Evidence: `tests/testthat/test-features.R:136` constructs `c(NA_real_, 1, NA_real_, 3)` with stable_after = 2 and expects “NA outside” at line 138. Its helper calls the live segment and normaliser (`:34`). This test block has no LTB marker, but it is an existing executable oracle. `existing_test_probe.R` / `existing_test_probe.txt` in this output directory run that unchanged file on the supplied base library and with only the three-line refusal removed in memory. Base: all three blocks pass. Patch: exactly one failed expectation, “Expected live_feature_series(bars, na_late_def) to throw a error.”

Consequence: the smallest implementation cannot pass the full suite without an existing oracle change that the cut has not specified. This is an authorized semantic correction, and needs its own stated reason under AGENTS.md; it must not be discovered and silently adjusted during implementation.

Exact replacement for decision 3's final sentence, with the same allowance added to LDG-3269's scope and last acceptance item:

> One existing expectation changes: in test-features.R, block “feature series uses and validates vectorized series functions”, the na_late_def case keeps its setup and series c(NA_real_, 1, NA_real_, 3), and replaces the “NA outside” expect_error with expect_identical(values, c(NA_real_, 1, NA_real_, 3)). Stated reason: the maintainer's 2026-11-04 decision replaces this obsolete refusal with accepted post-warmup NA; the literal result also proves that a later finite value recovers after NA. All other expectations in that block, including length, type, warmup, NaN and Inf, stay unchanged. Commit the base and candidate transcripts. No other existing test changes beyond decision 1 are authorized.

R2. Required: run final-library faults against a baseline that accepts the declared difference.

Claim: decision 4 sends faults.R through --declared=none, while decision 5 and LDG-3270 require final-code FAULTS PASS (`tickets.yml:4163`, `:4170`, `:8671`).

Evidence: `dev/feature_parity/faults.R:65` runs the supplied library with each fault, compares it against the pin at line 73, and demands pairwise distinct component signal sets at line 78. The unfaulted patched candidate already differs in almost every fault's expected component. `checker_probe.R` / `checker_probe.txt` independently compare the supplied saved pin and patched observations, then damage one values record or one planes record. With --declared=none all three comparisons exit 1 with exactly the same signal sequence; “fault component signal sets distinct: FALSE”. These are observation-level controls, not a claim to have run the full fault driver.

Consequence: on the final library, pre-existing expected differences mask fault detection and defeat signal separation. Running faults only on the pin avoids that failure but leaves the final candidate and the new declared-comparison branch unproved. Pin-against-pin with --declared=none is correct; applying that option to all faults is not.

Exact replacement for decision 4's faults sentence and corresponding LDG-3270 requirement:

> faults.R accepts an explicit declared-file option. Its product faults run on the final candidate library against the pin using the frozen declared_expected.csv; an unfaulted final-library control must first CHECK PASS under the same comparison. Every active fault must then exit 1 with its required signal and the existing pairwise-distinct signal requirement. The pin-against-pin repeat and structural controls manufactured solely from pin observations use --declared=none. Record the library and declared option for every control. Do not regenerate declared expectations during fault runs.

R3. Required: prove the declared comparison itself, and establish semantics before recording candidate expectations.

Claim: accepting every candidate-produced component for the 52 cases, checking their count and refusal none, plus the four listed controls establishes the intended difference (`tickets.yml:4147-4169`).

Evidence: the writer records all components except treated_fields from the final candidate. The listed controls detect an absent change and differences outside a frozen declaration, but none changes only a declared case's value, NA mask, plane or handoff. The existing broad faults also damage undeclared cases, so detecting those faults does not establish that declared data are compared. Initial recording has a separate problem: `declaration_independence_probe.R` / its `.txt` show a faulty normaliser that erases finite values after a post-warmup NA. It preserves the proposed finite-then-all-NA fixture and NaN/Inf refusals, while custom_volume_strict still completes with wrong values: hostile_carry2 has 10 finite cells instead of 13; panel_carry5 has 494 instead of 592. A final-candidate writer would record the wrong data. R1's literal recovery assertion closes this particular value witness.

Consequence: a candidate-produced file is acceptable as a regression record for behavior the pin cannot produce. It is insufficient as its own initial semantic proof. A checker could also ignore declared data while passing all four named controls. The missing controls affect what is proven, without requiring a different product design.

Exact addition to decision 4 and LDG-3269's oracle acceptance:

> Freeze the exact declared case-key set from the committed oracle_flips.csv, excluding treated_fields-only differences. Require exactly those 52 cases, unique complete component keys, and refusal none; a missing, duplicate or additional declaration refuses. Before writing the final-candidate record, independently verify the newly accepted values from the fixture inputs and declarations: runSD(n = 1) and custom_na supply all-NA outputs, and custom_volume_strict supplies the volume values with their missingness and existing admission rules. The literal NA-recovery and carry/evidence assertions are additional semantic checks. Candidate output is not the expected value for these checks.
>
> With that file frozen, separately mutate only one declared case's values, NA mask, planes and handoffs; each comparison must fail with the relevant signal. Also show that one undeclared-case flip fails, that restoring the old NA refusal fails, and that removing the NaN refusal fails the independent tests. Run malformed-declaration controls for missing, duplicate and extra keys. Never regenerate the file for a negative control. Keep the pin-only corpus expectations unchanged.

R4. Required: declare the other newly reachable refusal and the exact evidence/carry behavior.

Claim: the cut declares only the lookahead-refusal consequence and says a matching NA pair is never refuted (`tickets.yml:4066-4068`, `:4122-4126`). It describes the cell as “not calculated” in the proposed contract sentence.

Evidence: `R/history-features.R:323` excludes non-finite results from the internal calculated mask. Its prefix check runs first (`:638-648`), then custom bounded fn/series_fn parity (`:651-685`). Removing an earlier segment-wide NA refusal can therefore expose either check. `reach_probe.R` / `reach_probe.txt` independently demonstrate:

- A prefix recomputation returning NA changes the refusal to ledgr_feature_lookahead_detected, as declared.
- A full series containing NA elsewhere, with a finite sampled value that disagrees with fn, changes the refusal to ledgr_indicator_gap_parity. Both classes inherit ledgr_invalid_feature_output.
- An all-NA series with a finite fn completes: there are no calculated cells to sample. The limitation is broader than matching NA pairs.
- For closes 10,11,12,13,NA,16,17, a feature undefined at close 13, price_carry = NULL and output_carry = 3, output is 10,11,12,NA,12,16,17. At the undefined cell, public evidence has calculated TRUE, ready TRUE, calculation_valid FALSE, no source/age, and calculation_non_finite. The following missing-input cell carries 12 at age 2. Retained-plane and recomputing readers agree.

The last behavior follows `R/history-features.R:326-335`, `R/history-treatment.R:452`, `R/history-features.R:760-772` and `R/history-frame.R:379-412`. NA is neither a carry source nor itself a missing-input gap. It does not reset the segment or prevent later finite recovery.

Consequence: the listed consequence is correct but incomplete, and the public evidence field called calculated must not be confused with calculation_valid. These are consequences of retaining the existing machinery, not choices to return to the maintainer or reasons to redesign the probe.

Exact replacement for decision 3's “Declared consequence” passage, carried into the identity/release-impact qualifications and LDG-3269 acceptance:

> Acceptance of post-warmup NA removes only the normaliser's NA refusal. Existing checks still apply: a prefix mismatch can now refuse with ledgr_feature_lookahead_detected, and a sampled fn/series_fn disagreement can now refuse with ledgr_indicator_gap_parity, where the normaliser previously refused first. Both inherit ledgr_invalid_feature_output. Checks still sample only finite calculated cells; an NA cell is not refuted even if fn would return a finite value there, and an all-NA series has no probe samples. Test both newly reachable refusal classes and retain this sampling scope.
>
> An admitted post-warmup NA cell is ready but not calculation-valid; public evidence keeps calculated TRUE and reports calculation_non_finite, with no output source or age. It is not filled by output carry and is not a carry source. A later unavailable-input cell can still carry an earlier finite output within its existing age limit. Segment readiness and subsequent finite recovery are unchanged. Add a literal finite/NA/finite-and-gap witness and require retained-plane and recomputing evidence to agree. Use “not calculation-valid” in the new contract sentence.

R5. Required: explicitly cover both clocks and the public paths newly receiving NA.

Claim: the acceptance matrix fulfills WS12's “both paths in both modes,” and the existing oracle supplies the remaining preparation proof (`tickets.yml:4141-4146`, `:4184-4187`, `:8653`).

Evidence: `macro_plan.md:659-672` requires both indicator paths in both modes. The cut names run and sweep, but never requires the bar-native and declared-session clocks. The committed na_probe.R uses availability_runtime_fixture, which supplies session facts (`tests/testthat/helper-availability-runtime.R:1-48`). The 52 changed oracle cases are all compute cases, independently reproduced in `checker_probe.txt`; no changed public-entry case exercises this behavior. `dev/feature_parity/corpus.R:274` supplies no newly accepted post-warmup-NA definition to its e2e fixtures.

The NA values and planes travel from calculation into durable-run projection (`R/backtest-runner.R:665-684`), implicit sweep preparation (`R/sweep.R:276-291`), explicit precompute and reuse (`R/precompute-features.R:84-127`, `R/sweep.R:298-310`), and pulse inspection (`R/pulse-snapshot.R:392-410`). Parallel sweep workers receive the prepared invariant and projection; they do not calculate a separate series (`R/sweep.R:1325-1344`, `:1615-1624`, `:1649-1653`). Both history readers then expose the accepted cells. Those paths are reachable, but the proposed new assertions do not require an NA case through them.

Consequence: substituting run/sweep for the two clocks weakens the macro requirement. An unchanged ordinary e2e corpus cannot prove the new input is preserved across precompute, inspection and worker handoffs.

Exact addition to decision 3 and LDG-3269 acceptance:

> LTB-0567 explicitly crosses fn/series_fn with bar-native/declared-session clocks and durable run/sweep for NA, NaN and Inf. Assert the expected clock on each fixture. On a small NA-and-recovery fixture, also check explicit precompute, a sweep reusing that precompute, pulse inspection, and a two-worker sweep against the same literal values and evidence as serial execution. Assert that NA cells survive projection/payload handoffs and both history-reader forms. The worker check uses the supported installed backend and reports a skip only when that backend is unavailable. These are focused semantic witnesses; the existing 694-case corpus and its 52-case declared set remain unchanged.

R6. Advisory: correct the measured schema-mutant count.

Claim: measured_input says “the two mutant checks pass” (`tickets.yml:4039`).

Evidence: there are five definition mutants in `tests/testthat/test-schema-current.R:89-124`: table removal, column rename, default change, CHECK change and index removal. The committed schema transcript reports 14 total expectations, not two mutants. Independent `schema_probe.R` / `schema_probe.txt` confirm all five mutations are detected, the 2,886 catalogue rows and dimension digests match under DuckDB 2.0.1, and damaging a fixture row or dimension digest is detected.

Consequence: the number does not describe the committed input. It understates the retained guard; this does not require a different schema implementation.

Exact replacement in measured_input:

> the catalogue-row comparison, the per-dimension digest and all five existing definition-mutant checks pass

What I checked:

- Authority map: schema bullet -> decision 1 / LDG-3267; UTC bullet -> decision 2 / LDG-3268; NA bullet and Section 6 -> decisions 3-4 / LDG-3269; final proofs -> decision 5 / LDG-3270. Contract, three vignette passages, decisions owner, NEWS and LR-24 are routed. TTR inclusion is faithful. R1 and R5 are the missing test obligations.
- Identity: the normaliser is census CSV line 89 and explicitly bound by R/features-engine.R:60. The in-memory three-line patch changes engine 88b4237e... to 100eff97... . Indicator constructors, their closures/captures and declarations, config/run identities, feature-set identity and storage format need no change. UTC helpers are not census-bound. Changed-engine mode is appropriate; identity_check.R:44-77 has the fixed name-set completeness guard and requires old-precompute refusal before strategy calls. The final implementation must still execute that proof; I found no reason to change its identity design.
- UTC: independently reproduced all 532 frozen observations, the 500-element vector, refused edges at three positions, names/matrix/empty inputs, and extra boundaries including ancient timed years, invalid leap days, space-with-Z and trailing line endings. A vector implementation following decision 2 agrees. Both proposed faults are detectable; the local-date witness was run under explicit TZ=Europe/Vienna. Preserve the exact original space-form predicate before replacing its separator; unconditional space replacement would widen acceptance. The finite fixture is an adequate regression oracle alongside a source-level equivalence review, not a proof over every possible input.
- Schema: removing the two environment checks is sound, retains the catalogue/digest guard and leaves LCL-0256's provenance claim accurate. The proposed row/digest witnesses can fail. R6 corrects the measuring prose.
- Not-run claims: skipping the lean loop gate is justified. Its declared features are TTR SMA; unavailable inputs split calculation segments and warmup stays NA, so the changed post-warmup refusal is not reached. No lean/fold/interface code changes. Skipping a timing gate is also justified by macro rule 16 and this chore's scope; descriptive parser timing remains required. These skips do not replace R5's semantic coverage.
- Other measured numbers: the committed UTC CSV supports 0.255 ms rounded to 0.26 ms, 67 ms, 0.66 s and 18 ms; the fixture supports 500 + 32 rows, with 11 accepted and 21 refused edges. Independent comparison of saved arms confirms 694 cases, 52 non-treated-field changes, the 14/14/14/10 split, and 270 treated-fields-only cases. The NA CSVs record the stated eight-session run/sweep behavior. Evidence-path, census-binding and lean-workload claims were checked against source.

What I did not check:

No implementation was performed. I did not run timing windows, the full suite, R CMD check, the lean gate, the full oracle/fault driver, final identity/store-reuse proofs, or actual parallel workers. DuckDB 2.0.0 results were read from the committed transcript; my schema execution used 2.0.1. The new declared-file implementation does not exist yet, so its gaps above are requirements on the proposed checker, not observed bugs in code already written. Git status/revision queries were refused as unsafe repository; I did not change Git configuration. All probe files and outputs were written in cut25-review-out, and no tracked file was edited.
