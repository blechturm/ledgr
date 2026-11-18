CHANGES_REQUIRED

Mode: Type 2 cut review of Cut 23, workstream 42, LDG-3256 and LDG-3257. Independent session; supplied review tree 7268a8e5.

The cleanup is viable. I found no counterexample to unchanged runs from current public inputs. The cut nevertheless contains a false refusal claim, an identity checker that enforces the opposite result, witnesses with incompatible expectations, and an impossible coverage claim. Correct these before implementation. None requires reopening the maintainer's cleanup decision or adding compatibility support.

R1. Required: eager construction does not preserve every refusal.

Claim: decision 1 says the built-in is constructed before the shadow test "as now", so sma_0 retains its class and point of refusal; decisions 1 and 4 require unchanged refusals (tickets.yml:3633, :3666, :7766).

Evidence: R/backtest-runner.R:1068 short-circuits when the fingerprint is absent. Its built-in argument is an unforced promise on that route. Thus R/backtest-runner.R:1105 reaches the old validator at R/features-engine.R:238. With a fingerprint, the shadow comparison instead forces ledgr_ind_sma(), whose refusal class is ledgr_invalid_args (R/indicator-builtins.R:18). refusal_probe.R and refusal_probe.txt in this review's output directory execute the base and an in-memory conversion of the two rebuild branches:

- sma_0, fingerprint absent: ledgr_invalid_feature_def -> ledgr_invalid_args.
- sma_2147483648, fingerprint absent: the same class change, with the integer-coercion warning in both arms.
- Both malformed widths with an unknown fingerprint: ledgr_invalid_args in both arms, before fingerprint mismatch.
- sma_1.5: ledgr_invalid_config in both arms; sma_997 with an unknown fingerprint: ledgr_run_hash_mismatch in both arms.

Consequence: a careful implementation of the specified construction cannot pass the specified same-class witness. The cut's "one declared difference" is incomplete even though these malformed fingerprint-free configs are not produced by public feature constructors.

Fix: make the private-input difference explicit rather than introduce a compatibility validator. Replace the construction/refusal sentences in decision 1 with:

> Construct the built-in once in the recognized branch and reuse it for the shadow comparison and conversion. Fingerprint-bearing entries retain their refusal classes and precedence. For manually supplied fingerprint-free malformed SMA ids, construction now refuses with ledgr_invalid_args instead of the old list constructor's ledgr_invalid_feature_def; preserve the existing integer-coercion warning before refusal for an overflowing suffix. A non-integer suffix continues through registered/unknown-id dispatch. No current public constructor produces either malformed definition.

Add that difference to decision 3 and replace decision 4's sma_0 sentence with explicit absent/unknown-fingerprint cases, including the overflowing and non-integer suffixes. Amend LDG-3256 and the close-review wording accordingly. If unchanged private refusals are intended instead, the construction decision needs a different implementation and a proving transcript; the present text cannot promise both.

R2. Required: the named identity checker rejects the required outcome and accepts an engine change.

Claim: decision 5b and LDG-3257 prescribe identity.R and identity_check.R to prove every identity unchanged, including bc6a3ea2 (tickets.yml:3678, :7784).

Evidence: dev/feature_parity/identity_check.R:15 excludes the engine from ordinary equality, :25 requires it to differ, and :28 requires old-precompute engine mismatch with zero strategy calls. identity.R:128 implements that earlier Cut 22 scenario. checker_probe.R runs only the checker on tiny synthetic CSV records, not the identity workload or oracle. checker_probe.txt records: identical engines, with all other checker predicates satisfied, give IDENTITY CHECK FAIL; changing the engine gives IDENTITY CHECK PASS.

Consequence: this acceptance item is unexecutable as written. It also supplies no positive proof that a base precompute remains reusable under the unchanged engine identity.

Fix: replace decision 5b and its ticket acceptance with:

> Add a narrowly scoped unchanged-engine comparison mode to the identity tooling, preserving Cut 22's existing changed-engine mode. On fixed base/final inputs, compare every recorded identity, require exactly one equal engine-version record in each arm with the expected bc6a3ea2 prefix, and refuse missing or duplicate records. Reuse a base explicit precompute on the candidate successfully and compare its logical result with fresh preparation; keep the stored-run and stored-sweep read checks. Demonstrate that a changed engine record and a missing identity record each fail this mode. Run it on base 6d12ef79 and the final code.

Authorize these tooling edits expressly in decisions 2/5 and LDG-3257. They are evidence changes with a stated reason, not product identity changes.

R3. Required: define executable witnesses for active fingerprints and overlay retention.

Claim: decision 4 requires the same canonical definition as the built-in itself, an identical rebuild after removing the stored fingerprint, and every witness to fail on the base (tickets.yml:3662, :3665, :3668).

Evidence: certification deliberately preserves the claimed fingerprint at R/history-features.R:60. An availability-active config stores the active fingerprint (R/backtest-config.R:245), whereas the converted built-in initially has its base fingerprint (R/precompute-features.R:672). witness_probe.txt shows that the correct active rebuild differs from the missing-fingerprint rebuild, and its certified definition's fingerprint differs from certification of the bare built-in. It also shows:

- Dropping all five declaration overlays while retaining the active fingerprint produces an identical definition on the ordinary built-in fixture.
- The base already certifies the stored definition as builtin with identical canonical declarations.
- With non-default stored required_fields and tolerance, dropping the overlay changes the raw rebuild while certification still gives identical canonical declarations.

These observations follow R/history-features.R:59: certification replaces claimed built-ins with canonical declarations. The same-class refusal invariant, where retained, also already passes on the base.

Consequence: literal active-clock equality expectations fail a correct change. Ordinary built-in fixtures cannot expose removal of the overlay. Certification assertions alone do not prove the rebuild, and unchanged invariants cannot all be required to fail on the base.

Fix: replace decision 4's equality/base-failure wording with:

> Build the expected raw definition independently from the constructor's conversion, apply each stored declaration field explicitly, and retain the exact stored fingerprint. Compare non-function fields exactly and functions by their code/formals/capture identities. For certification compare the canonical built-in with that expected retained fingerprint and canonical declarations. After removing the stored fingerprint, expect the converted built-in's own fingerprint; do not require equality with the active-fingerprint result. Add a focused raw-rebuild case with non-default stored declarations so omission of the overlay fails, and explicitly assert retention of the active fingerprint. Compare old/new history widths on both clocks. Show the changed raw-rebuild, missing-fingerprint certification and namespace-removal witnesses failing on the base; show unchanged certification and refusal invariants passing on both arms. Prove that dropping the declaration overlay or the stored active fingerprint fails the corresponding witness.

The non-default stored case tests the existing internal overlay rule; it need not be presented as a public constructor output. Apply R1's explicit refusal expectations separately.

R4. Required: the oracle addition cannot reach rebuild branches through all the named entries.

Claim: decision 5a says adding returns(1) makes a run, implicit sweep, explicit precompute, reuse, pulse inspection and dated run reach both rebuild branches on both clocks (tickets.yml:3671).

Evidence: consumer_probe.R instruments only definitions returned by ledgr_feature_defs_from_config(), unwraps them at certification/width boundaries, and records other field access. Its final consumer_probe.txt has successful routes on both clocks: run, promotion and a selected walk-forward test run each call the rebuild once; sweep, explicit precompute, reuse and pulse inspection each call it zero times. Reopening a stored run also calls it zero times. This agrees with the sole production caller at R/backtest-runner.R:520 and the separate conversion path at R/sweep.R:1649. dev/feature_parity/runner.R:405, :410, :416, :419, :429 and :439 exercise those distinct routes.

Consequence: no faithful implementation can demonstrate the stated branch coverage for those sweep/precompute/inspection entries. Their oracle comparisons remain useful, but cannot prove this rebuild executes there.

Fix: replace decision 5a's coverage sentence with:

> fx_e2e_features() gains ledgr_ind_returns(1L) because the current public-entry corpus lacks the return_1 rebuild branch. Ordinary and dated committed runs reach both rebuild branches on each clock; record that coverage with a small observer. Sweep, explicit precompute, reuse and pulse inspection use the experiment's converted definitions without this rebuild and retain their public-output comparisons. Run the same augmented corpus on the pin and candidate. Regenerate corpus_expected.csv from the augmented pin observations with check.R --write-expected; review the diff, allowing only structural observation changes caused by the added feature in existing e2e cases. All other cases remain unchanged. Pin/pin, candidate/pin and the existing fault controls must pass.

This gives the fixture change its stated coverage reason under AGENTS.md. Regeneration from the pin is the correct procedure; it must not authorize accepting candidate-produced expectations or deleting old cases. Correct the close-review coverage claim too. In the opening, say the legacy callbacks are unused during current run computation: the old list constructors themselves are still called by ordinary runs.

R5. Advisory: name the census check, not merely a successful walk.

Claim: decision 5c and LDG-3257 require a passing census proof with unchanged walked helpers/bindings.

Evidence: dev/feature_parity/census.R:102 returns successfully without checking anything when --census is omitted. Missing/extra helper checks begin at :109; replacement proofs and CENSUS CHECK PASS occur later. None of the three deletion targets, or the rebuilt-config dispatcher, is in the current bound list or census.

Consequence: a walk-only exit zero could be misreported as the required proof. No expansion of the census is needed for this cut.

Fix: append:

> Invoke census.R with --source=<final tree>, --out=<evidence directory> and --census=<final tree>/dev/feature_parity/census.csv; require CENSUS CHECK PASS and its replacement-proof output. Compare helper names, roots and bindings with the base; only locations may change.

R6. Advisory: narrow the reason for omitting the lean gate; the timing omission is justified.

Claim: decision 6 partly justifies skipping the lean gate because both arms receive the candidate R overlay and cannot compare base with candidate.

Evidence: dev/feature_parity/lean_gate.R:1 describes a candidate-package versus lean-loop comparison, with shared candidate preparation. That is intentionally an integration comparison, not a base/candidate differential; the shared overlay alone does not make it useless. The package arm still calls ledgr_run() (dev/lean_core/parity/loop_parity.R:444). Here the changed object has the same certified definition and width, and no lean module changes. Macro-plan rule 16 at macro_plan.md:158 explicitly defers performance gates to milestones.

Consequence: the skip is proportionate here, but its generic explanation could wrongly excuse later preparation changes that alter lean inputs.

Fix: replace the lean reason with:

> No lean code or interface changes. The targeted rebuild, certification and width proofs establish unchanged inputs to the existing fold/lean boundary; the public differential oracle covers this preparation change. The lean gate compares the candidate package with the lean loop under shared candidate preparation, so it is not the evidence for base/candidate equivalence here.

Keep the timing omission and milestone citation. Construction remains before the fold; this cut makes no measured speed claim.

Checked:

- Read Cut 23/WS42 and both tickets, Cut 22's oracle/identity/census precedent, F6 and the committed three-script probe and outputs, the requested production paths, AGENTS.md, the strict-feature contract group (#contract-context-strict-features), feature identity/conversion, the parity corpus/runner/checker/census/identity tooling, and the lean wrapper and macro-plan gate rules.
- definition_probe.txt compares sma_1, sma_3, sma_200 and return_1 on both clocks. Old and proposed overlaid definitions produce equal certification, canonical function identities, parameters, declarations and widths (1, 3, 200 and 2). Converted missing-fingerprint sma_3 and return_1 pass preparation on fx_empty. The committed probe's ordinary-run certification and bare-list refusal explanation agrees with the code; its read_fields.R compares only bare lists and base fingerprints, not active overlays or consumer coverage. The new probes supply those missing observations.
- The consumer probe found only ID reads outside certification and width boundaries for rebuilt definitions on its successful run, promotion and walk-forward cases. Static tracing also covers both width callers (R/history-frame.R:731 and :1268). Width validates the complete declaration before reading reach; it is not literally a reader of only history_class/requires_bars/stable_after. No extra source field or rebuilt function was found entering persistent config or identity: config writing precedes rebuilding; preparation uses certified canonical definitions. This supports the intended unchanged-public-run scope, subject to the corrected final-code proofs.
- reachability_probe.txt retains fingerprints through config JSON round trips on both clocks. Raw fingerprint-free feature lists refuse at experiment construction; factories returning them refuse public run/sweep materialization, and the attempted walk-forward also refuses before rebuilding. Successful stored-run reopening retains fingerprints. The public paths do not offer raw stored-definition execution. No new public reachability counterexample was found. The contract selects by claimed identity and preserves custom shadows; a built-in-looking name alone is not its authority rule.
- Searched production R, exports, registered tests, tools, man/vignettes and developer callers for all three deletion names. The listed dispatcher branches and validator test/seam are the maintained consumers found. The test-removal reason is sound: it tests a helper with no remaining product caller, and the public indicator validation tests remain. Historical benchmark/projection probes remain records. Both bare_refusal.R and read_fields.R call deletion targets and must remain base records; run_certification.R is the final-code rerun. No new loop over bars, facts, events or candidates is needed by this cleanup.

Not checked: no implementation was made; no timing windows, full test suite, package check, full feature oracle, lean gate or other long workloads were run. The checker probe used synthetic CSVs only. Source probes used pkgload with compile=FALSE and the supplied pin's native DLL, registered in-process after pkgload could not load a source DLL; production R came from this source tree. Logs include the library paths; no library under AppData/Local/Temp was used. All probe scripts, scratch stores and outputs are under cut23-review-out. Git status/HEAD verification was refused by Git's repository-ownership check, including a command-local safe.directory attempt; no Git configuration was changed. No tracked file was edited, no commit made, and no E:, research or vendor data accessed.
