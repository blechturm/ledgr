CHANGES_REQUIRED
Mode: Type 1 close review of workstream 35; independent fresh session; verification, not design.

Reviewed detached 7378f1845384b3c91f259bdede79675f0036021f against 176be4a7 and semantic pin d5b3a151. The workstream does not meet every acceptance item. The requested oracle driver and both requested timing checks exit 0, but that does not establish the required identity or make all the evidence true. No finding requires a new design decision; no NEEDS_TYPE_2 concern is raised.

Paths without a prefix are relative to C:/Users/maxth/ledgr-wt/ws35-review. Probe scripts and reproduced outputs are under C:/Users/maxth/ledgr-wt/ws35-close-out.

For compact citations, bare oracle*.R, measure_helper.R, sites.csv and results/... refer to dev/bench/v0_2_3_helper/; tickets.yml refers to inst/design/ledgr_v0_2_3_spec_packet/tickets.yml. Probe filenames refer to the output directory.

1. The fast-path gates do not establish base equivalence for every accepted operand.

   Claim: absence of attributes on a derived operand does not prove uniqueness, and names(x) need not return an attribute-free vector for a classed x.

   Evidence: R/strategy-helpers.R:475 derives held_leavers by one-dimensional indexing. The gate at :476 then admits a flattened character matrix with duplicate elements. identity_probe.R, using the pin's parsed functions and the independently installed candidate, demonstrates universe = matrix(c("AAA", "BBB", "AAA", "CCC"), 2), positions c(1, 0, 1, 0), and membership c(FALSE, TRUE, FALSE, TRUE). Matrix anyDuplicated() is 0; flattened anyDuplicated() is 3; held_leavers has NULL attributes. The pin refuses with "Held index leavers need an explicit decision: AAA." The candidate refuses with "Held index leavers need an explicit decision: AAA, AAA." Classes and conditionCall() agree. Base setdiff() de-duplicates; the replacement does not.

   The same probe supplies numeric weights with a names() method returning classed character IDs and a subsetting method on those IDs. R/strategy-helpers.R:761 gates only universe, so the replacement invokes that subsetting method where base setdiff() strips the class. The pin's unknown-ID message ends "EEE, FFF."; the candidate's ends "FFF, EEE." Both refuse with ledgr_invalid_strategy_type and the same call. R/strategy-types.R:39 and :43 likewise assume x_names is plain without testing it. These are accepted classed operands, not changes to the entrance validators.

   Consequence: decisions (1) and (3), and LDG-3233's identity acceptance, fail. The existing matrix case keeps all positions flat and misses the observable held-leaver difference. The universal "results ... and refusals are unchanged" evidence is false. This concerns contract-strategy-outputs and the cut's stronger explicit refusal-identity obligation.

   Kind: wrong answers, with false identity evidence.

   Smallest fix: retain the original base operations when the source axis does not establish unique flattened IDs; test every operand whose attributes matter, including names() results, before using the plain-vector shortcut. Audit the other shortcuts for the same lost guarantees. Preserve the existing entrances and refusal points. Add these witnesses to the new oracle manifest; do not strengthen a validator or alter an existing registered test.

2. The mutation driver reports a required signal as present when it is missing.

   Claim: the reported "13 mutations each caught by its own signal" and consequently "18 of 18 as required" are false as written.

   Evidence: dev/bench/v0_2_3_helper/oracle_mutations.R:13 requires signal names for derived_names on reb_subset_nonlexical. Both committed dev/bench/v0_2_3_helper/results/oracle_ldg3232/diffs_mut_derived_names.csv:2 and dev/bench/v0_2_3_helper/results/oracle_ldg3233/diffs_mut_derived_names.csv:2 contain evidence, not names. The reproduced CSV has the same result. oracle_check.R:59 appends "MISSING signal names on reb_subset_nonlexical" when its explicit hit test fails; :36 searches for the substring "signal names on reb_subset_nonlexical", which also occurs in that failure text. oracle_controls_probe.R executes the unchanged record() function with a missing-signal log and exit 1: it prints "ok" and records ok = TRUE. Independently checking the reproduced CSVs finds the correct named signal for 12 mutations, but FALSE for derived_names.

   Consequence: the mutation is detected as a difference, but its registered signal requirement is unmet and the driver hides that failure. LDG-3232's oracle acceptance and both tickets' mutation evidence are not satisfied.

   Kind: wrong answer in the harness, false evidence, and a missing acceptance item.

   Smallest fix: make the explicit hit boolean a required part of success. Have the comparator emit names when a nested names attribute is added or removed, alongside evidence if appropriate. Retain the deliberately changed case and expected surface; rerun and update the evidence.

3. Condition and signal capture discards required comparison surfaces.

   Claim: the oracle does not compare all non-trace condition payloads and parent conditions under decision (5).

   Evidence: oracle_run.R:92 retains only a parent's class and message. At :106 and :107 warnings and messages retain only type, class and message, omitting calls and payloads. The drop list at :90 also excludes body, footer and use_cli_format, beyond the expressly excluded trace/harness provenance. comparator_probe.R extracts the actual capture functions unchanged. Changing only a parent's instrument_id from AAA to BBB produces identical captured records. Changing a warning's call from alpha() to beta() and its instrument_id from AAA to BBB also produces identical captured records. The unmodified comparator exits 0 with "0 differences" for both pairs. These probes are additional controls; they do not claim the current package emits those changed conditions.

   Consequence: the oracle can certify equality after observable condition changes that the accepted decision requires it to detect. The added-warning mutation checks signal presence, not these omitted surfaces.

   Kind: missing acceptance item; the complete-condition comparison claim is overstated.

   Smallest fix: use one recursive condition normalizer for terminal errors, parents, warnings and messages, preserving calls, field presence and all non-trace payloads. Exclude only the specified provenance. Add separate failing controls for parent payloads and signal calls/fields.

4. The arm controls check function text but do not force callee resolution from that arm.

   Claim: a candidate resolving a changed callee from the pin can pass both the source control and clean comparison.

   Evidence: oracle_run.R:59 hashes deparse(f), which omits the closure environment; :60 checks those hashes only. arm_resolution_probe.R loads the installed 7378f184 library, leaves every function body unchanged, and changes only ledgr_target_size()'s enclosing environment so ledgr_target_named_amount resolves to the function parsed from d5b3a151. It then runs the unchanged oracle_run.R. Output: "candidate target_size resolves target_named_amount from pin source: TRUE", followed by successful capture of all 135 cases and "unchanged oracle_run arm controls accepted the pinned callee". extra_checks_review.R compares this mixed arm with the pin: exit 0, 0 differences. The real candidate installation was not modified on disk.

   Consequence: the existing claimed-library and wrong-source controls do reproduce, but they do not establish the stronger conclusion claimed at tickets.yml:5571 that every changed callee resolved from the candidate. Decision (5) explicitly requires this accidental pinned-callee case to fail.

   Kind: missing acceptance item and false arm-control evidence.

   Smallest fix: verify the enclosing namespace and lookup path of the changed functions and their changed callees, in addition to their bodies/formals. Include this mixed-resolution control and require exit 3.

5. The required grid and pin-reach checks are incomplete.

   Claim: site labels and broad error classes do not establish the required branch/side-effect coverage, and some expressly required operand cases are absent.

   Evidence: oracle_cases.R:43 defaults reach to NULL. oracle_run.R:110 evaluates reach only on success; all refusals receive NA. oracle_compare.R:66 accepts any error of the expected class and :69 rejects only FALSE, so NA passes. Only 13 of the 135 reproduced cases have a reach predicate result. oracle_controls_probe.R replaces both skip-then-overflow records with an earlier unknown-name refusal of the same broad class, including unchanged notes. Comparing the resulting record with itself exits 0 instead of refusing missing late-refusal/notes reach. The manifest's site coverage at oracle_compare.R:54 is based on declared strings, not reached sites.

   The grid at oracle_cases.R:72 and :182 covers ordinary character keep and named logical masks, but no named character keep, classed keep or dimensioned character keep. Its only classed universe at :138 has no methods. Adjust cases beginning at :234 lack zero-weight and guard-scaling witnesses, although those shared branches apply to adjust. The accepted decision at tickets.yml:2146 requires named ID operands and classed/dimensioned operands, and :2153 requires both verbs wherever the branch applies. The matrix held-leaver and classed-name witnesses in finding 1 are also absent. sites.csv has no explicit entries for the rewritten zero_pos and valid_pos lookups at R/strategy-helpers.R:607, :655 and :681.

   Consequence: the manifest cannot independently reject some incorrectly authored inputs; agreement between arms can hide a missing intended branch. LDG-3232's manifest/pin-reach acceptance is incomplete.

   Kind: missing acceptance item.

   Smallest fix: complete the stated operand and verb coverage, map every changed lookup to a site, and make reach assertions apply to errors and notes as well as successful values. Assert the named refusal/side effect rather than only a broad error class. Keep these additions in the new oracle, without editing registered tests.

6. The executed-site attribution and several ticket percentages are false.

   Claim: S09 is counted as executed on six calls on which its union is never reached, and the ticket's per-site numbers do not consistently reproduce from its cited CSV.

   Evidence: measure_helper.R:104 uses exists("skipped_weight") as the execution test. In the product, the union is inside length(skipped_weight) > 0L at R/strategy-helpers.R:624. site_reach_probe.R executes the base's own helper on genuine captured views with the frozen representative arguments, without timing. For both verbs at all three sizes it reports "skipped_weight exists TRUE length 0 S09 ran FALSE". Nevertheless results/measure_base/sites_timing.csv:13 and the other five S09 rows mark it TRUE.

   Recalculating the committed shares without that unexecuted site changes the reported rebalance totals 77.1/67.7/54.8 percent to 68.9/64.7/52.9; adjust 71.0/53.0/56.0 becomes 65.4/50.8/54.4. These remain isolated, inclusive estimates, not a decomposition. Separately, tickets.yml:5553 reports S17 rebalance at 500 instruments as 19.1 percent; sites_timing.csv:55 gives 26.3413 percent. S01 rebalance at 10 instruments is reported as 7.1 percent, while rows :2 and :3 sum to 6.6176 percent. These are not rounding differences.

   Consequence: LDG-3232's measured site shares are not faithfully reported, weakening the input used to select rewrite sites. The timing gate's ratios are unaffected by this arithmetic/capture error.

   Kind: false evidence.

   Smallest fix: determine execution from the actual branch predicate (or an execution hook), retain unexecuted isolated costs as explicitly hypothetical, and regenerate all ticket percentages from the committed source CSV. Distinguish S12's whole validator timing from its inner setdiff cost. New timing is needed only where the recorded operands or measurement itself were wrong.

7. The final candidate's timed helper batches do not meet decision (6)'s stated duration.

   Claim: the counts were calibrated to about three seconds on the base, leaving the candidate well below the accepted "about three seconds or more" requirement.

   Evidence: tickets.yml:2182 requires frozen counts so timed batches last about three seconds or more. dev/bench/timing/protocols/cut17-helper-1/protocol.md:35 says calibration was on the base. The reproduced ldg3233-close check reports candidate medians 1.395653/1.636231/1.779109 seconds for rebalance and 1.458230/1.651165/1.799882 for adjust. audit_records.R confirms the individual candidate observations are also around 1.4-1.8 seconds. The shared checker has no minimum-duration check, so its CHECK PASS does not establish this separate protocol obligation. The match-versus-gated comparison has similarly short batches.

   Consequence: the ratios are reproducible and comfortably below 1.02 against the accepted base, but the record does not satisfy the timing duration as written. No inference that the measured speedup is absent follows from this finding.

   Kind: missing acceptance item.

   Smallest fix: freeze repetitions large enough for the faster arm before the next comparison and record all pairs under the resulting protocol, preserving the existing observations and required disposition/history. Do not retroactively relabel these durations as compliant. Waiving the accepted duration would require maintainer authority, not a reviewer silently interpreting it away.

8. The timing packet does not commit the actual execution commands.

   Claim: decision (6)'s command-provenance deliverable is missing.

   Evidence: tickets.yml:2202 requires the protocol, raw record, commands and resolved identities to be committed. The four attempt folders contain session/plan/raw/host CSVs and frozen harness/protocol files. Their session.csv files record identities and settings, but no invocation. dev/bench/timing/protocols/cut17-helper-1/protocol.md:9 gives only the candidate-overlay option. The helper scripts give usage templates. Searching the helper tools and the record CSV/Markdown files finds no completed runner invocation with the actual base, candidate, protocol, label/output and host launcher. The session metadata makes substantial reconstruction possible; it is not a record of the commands executed.

   Consequence: the resolved arm identities and raw observations are present, but this expressly required provenance item is not.

   Kind: missing acceptance item.

   Smallest fix: commit the actual launcher/runner and verification commands alongside each record, recovered from execution history where available. Label any reconstructed invocation as reconstructed rather than asserting historical execution.

Checked:

- Read Cut 17's measured_input, decisions (1)-(7), cut_review, WS35 reason, both tickets and their evidence; both cut reviews; AGENTS.md; the strategy-output/target/sizing-evidence contracts; and the optimization manual. Reviewed the complete product diff and the helper/protocol tools, records and their frozen harness inputs. The seven-shape review is recorded; no new growing R loop was added to product code.
- Installed a git archive of 7378f184 with R CMD INSTALL --no-docs --no-multiarch into ws35-close-out/lib-7378f184 and wrote its full SHA marker. The original pinned library was read only. Git proves no R/ difference d5b3a151..176be4a7, a564a226..7378f184, or 90e973b5..7378f184.
- oracle_check.R against that installation: exit 0, 135 cases, nominal 18/18. Independently audited every mutation's actual CSV, finding the derived_names signal failure above. A separately executed second pin arm compares equal to the first. Reproduced omission, missing-surface, claimed-library and wrong-source controls, with the additional limitations above.
- Reproduced collapse_semantics.R: the CSV matches the committed one exactly under collapse 2.1.8. Additional fmatch probes agree with match for NA, empty strings, empty inputs, cross-encoding names, matrix, factor, ordinary classed and named operands, with default NA and 0 nomatch. This is positive evidence on those operands, not a universal proof for arbitrary S3 methods. No collapse index operator replaced a logical mask; duplicate/uniqueness operations remain base.
- Captured views buy positions with ordinary quantity targets rather than the sizing helper. Their inputs are independent of that helper; the two arms' input digests agree. Fresh notes environments and binding snapshots are used for the covered evaluations. The protocol's six helper arms use installed packages, genuine warmed views and frozen arguments; the whole-run arms use the ordinary package path, sealing and verified open, with matching fill/sizing signatures and positive reach counts. No lean implementation is installed by that protocol.
- Both requested shared checks exit 0: ldg3233-close/attempt-1 and ldg3232-base-base-2/attempt-1. Close helper ratios reproduce as 0.477/0.575/0.601 and 0.481/0.558/0.582; descriptive whole run 26.6281 versus 26.8936 seconds, ratio 0.990130. Base/base-2 ratios are 0.998-1.014. Each has 112 observations and invariant work per cell. The first base/base record also passes using its frozen protocol; its 0.946116 noise observation reproduces. The match-versus-gated record has valid inputs but fails the two 10-ID helper bounds at 1.084055 and 1.084865, consistent with the disclosed tradeoff; large-cell ratios reproduce.
- All six protocol-refusal demonstrations reproduce: clean 0, helper over bound 1, descriptive times ten 0, missing raw 1, changed helper work 1, changed descriptive work 1. The descriptive bound of 1,000,000 changes only that ratio gate; the shared validity checks remain active. That implementation is consistent with decision (6)'s descriptive exception.
- The measure_base first-use/cached figures, timer fractions and host labels reproduce arithmetically from their records. The isolated site timing method is explicitly inclusive and approximate, with the errors above. fmatch_compare's recorded ratios reproduce from its medians. lean_helper's raw rows reproduce its median paired fold saving 3.8227 percent and run saving 3.0695 percent, identical work strings and a faster candidate in all seven rounds. The in-situ CSV supports approximately 268 to 144 microseconds per cached helper call and roughly 112-114 microseconds of column reads. Its script records fill count and final equity, not the full work signature promised in its header; full in-situ signature equality is unverified.
- Product hunks are confined to the five permitted functions in the two named R files; public formals and ledgr_target() are unchanged, and no constructor bypass, execution engine, validator, risk/sizing-evidence boundary or store-format change was added. Excluding the asset_reads found-input files as instructed, non-product changes stay in the permitted evidence/tool locations. Existing registered tests, fixtures and oracles, dev/lean_core, DESCRIPTION and NAMESPACE are unchanged. No prohibited generated artifact is tracked.

Not checked:

- No new timing window, paired measurement, full test suite or package check was run. Historical elapsed times and host conditions were checked through committed records, not remeasured. The scratch 20-40 ID crossover and 0.35-microsecond binding estimate are unverified; they are explicitly labeled scratch.
- The claimed full-suite outcome and Status OK package check are unverified execution claims: their logs are not in this packet. They are plausible given the installed candidate, unchanged registered tests and product-source equality with the claimed checked commit, but are not established by this review's execution.
- No arbitrary-input identity claim is certified beyond the inspected code and executed probes. Found-input asset_reads work was excluded from acceptance as requested. No E:, ledgr-research or vendor data was accessed. No tracked file was edited and no commit was made.
