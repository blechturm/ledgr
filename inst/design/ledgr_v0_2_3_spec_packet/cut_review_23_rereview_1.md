PASS

Mode: focused re-review 1 of Cut 23, Type 2. Independent fresh session; reviewed 7250158caa61b89c6d831eca2012c671e6d3008c against 7268a8e5. No implementation authorship.

R1-R6 are applied faithfully and completely in the decisions and their matching ticket requirements. The workstream 42 close-review reason agrees with them. I found no new contradiction, unexecutable or unfalsifiable acceptance item, loss of the unchanged-public-run scope, or missing decision a careful implementer needs. This is approval of the revised cut; its final-code proofs remain implementation obligations.

References to tickets.yml below mean inst/design/ledgr_v0_2_3_spec_packet/tickets.yml at the reviewed revision. References to prior probe files mean the supplied cut23-review-out directory; I reviewed those scripts and outputs without rerunning them.

R1. Applied: the private refusal changes are declared and testable.

Decision 1 now distinguishes fingerprint-bearing refusal invariants from the fingerprint-free sma_0 and integer-overflow class changes, preserves the overflow warning, and leaves sma_1.5 in registered/unknown-id dispatch (tickets.yml:3638). Decision 3 declares both private-input differences (tickets.yml:3670). Decision 4(e) gives the absent/unknown-fingerprint cases and expected classes, including sma_997's fingerprint mismatch (tickets.yml:3698). LDG-3256 carries these requirements in its first and third acceptance items (tickets.yml:7828, :7830); workstream 42 carries the exception at :4168.

This matches refusal_probe.txt and the source's lazy shadow comparison at R/backtest-runner.R:1068 followed by the old constructor at :1105. The cut no longer demands the incompatible old private refusal class from eager built-in construction. It adds no compatibility validator or public refusal change.

R2. Applied: an unchanged-engine proof is expressly authorized.

Decision 2 permits the identity-tooling change with a stated reason (tickets.yml:3663). Decision 5(b) specifies a separate unchanged-engine mode, preserves Cut 22's changed-engine mode, compares all recorded identities, requires one equal bc6a3ea2-prefixed engine record per arm, rejects missing/duplicate records, proves successful base-precompute reuse against fresh preparation, retains stored reads, and requires changed-engine and missing-identity controls (tickets.yml:3723). LDG-3257's scope and identity acceptance incorporate that decision (tickets.yml:7840, :7847); workstream 42 requires the proof and controls at :4168.

The stated reason remains accurate: dev/feature_parity/identity_check.R:25 requires an engine change and :28 requires old-precompute refusal; checker_probe.txt demonstrates the reversed outcome. Those existing tools are still unchanged because this commit revises the cut. The new mode and successful-reuse comparison are now authorized implementation work, rather than impossible demands on the existing checker. The ticket's explicit reference to decision 5(b) retains its missing/duplicate refusal requirements.

R3. Applied: raw rebuild, certification and fingerprint expectations are separated.

Decision 4(a)-(d) now requires an independently assembled expected raw definition, explicit stored overlays, exact active-fingerprint retention, function code/formals/capture comparisons, a non-default required_fields/tolerance case, canonical certification under the retained fingerprint, the converted built-in's own fingerprint when the stored one is removed, and equal old/new widths on both clocks (tickets.yml:3683). Its concluding requirements distinguish changed witnesses that fail on the base from invariants that pass on both arms, and require omitted-overlay and omitted-active-fingerprint faults to fail (tickets.yml:3704). LDG-3256 binds all of (a)-(f) and those demonstrations at :7830; workstream 42 agrees at :4168.

This matches witness_probe.txt: ordinary declarations alone cannot expose a dropped overlay, and the active stored fingerprint differs from the bare built-in's fingerprint. R/history-features.R:59 explicitly retains the claimed fingerprint during canonicalization. R/history-frame.R:490 validates declarations before deriving width. The revised expectations are compatible with those behaviors and can distinguish the two specified faulty rebuilds. No equality with the bare built-in's base fingerprint is demanded for active-clock certification.

R4. Applied: oracle branch coverage and expectation regeneration are executable.

Decision 5(a) limits rebuild coverage to ordinary and dated committed runs on both clocks, requires an observer, and keeps sweep/precompute/reuse/inspection output comparisons without claiming they execute this rebuild (tickets.yml:3709). The same augmented corpus runs on pin and candidate; expectations come only from augmented pin observations via check.R --write-expected, with a reviewed structural diff confined to existing e2e cases, no deleted case, and unchanged other cases. Pin/pin, candidate/pin and existing fault controls remain required. LDG-3257 expressly includes the observer in scope and carries the oracle requirements at :7841 and :7846. Workstream 42's coverage claim is corrected at :4168.

The distinction agrees with consumer_probe.txt and the separate e2e calls in dev/feature_parity/runner.R:405, :410, :416, :419, :429 and :439. check.R:78 implements the named pin-recording operation. The opening now correctly distinguishes called legacy constructors from unused computation callbacks (tickets.yml:3581); measured_input(c) also acknowledges full declaration validation and the observed consumers at :3610. These changes preserve the stated reason for the fixture addition and do not authorize accepting candidate-generated expectations.

R5. Applied: census checking cannot be satisfied by a walk-only exit.

Decision 5(c) names --source, --out and --census, requires CENSUS CHECK PASS and replacement proofs, and permits only location changes while preserving helpers, roots and bindings (tickets.yml:3735). LDG-3257 repeats those requirements at :7848; workstream 42 requires the census check at :4168. This addresses census.R:102's successful walk-only exit when --census is absent. No census expansion or identity change is authorized.

R6. Applied: the lean omission has the narrower reason; timing remains justified.

Decision 6 now relies on unchanged lean code/interfaces, targeted rebuild/certification/width evidence of unchanged boundary inputs, and the public differential oracle. It accurately describes the lean gate as a candidate-package/lean-loop comparison under shared candidate preparation, rather than dismissing that integration comparison as useless (tickets.yml:3746; dev/feature_parity/lean_gate.R:1). The timing omission retains macro-plan rule 16 and explicitly makes no speed claim (tickets.yml:3752; macro_plan.md:158).

LDG-3257 includes decisions 5 and 6 in scope (tickets.yml:7840), and its final acceptance requires the workstream close review (:7852), whose reason expressly checks both omissions (:4168). There is no separate acceptance item demanding either omitted run, and no conflict with the required full-suite and package checks.

No new findings.

Checked:

- Compared all R1-R6 replacement requirements with the complete 7268a8e5-to-7250158c tickets.yml diff, the resulting Cut 23 text, workstream 42 and both tickets. Checked the retained exclusions and stated reasons for test/tooling changes.
- Read the original brief and review, the committed F6 probe findings and relevant script, and the supplied refusal, definition, witness, checker and consumer evidence. Cross-checked the affected claims against config storage, rebuild dispatch, indicator conversion, certification, history width, oracle corpus/runner/checker, identity tooling, census tooling, the lean wrapper, macro-plan rule 16, AGENTS.md and contracts.md's #contract-context-strict-features group. Settled cleanup, validator deletion and pre-CRAN policy were not reopened.
- Verified HEAD as 7250158caa61b89c6d831eca2012c671e6d3008c. The revision range changes only tickets.yml and adds the predecessor's review to the packet; no product or test implementation changed. Git commands succeeded using explicit git-dir/work-tree paths after ordinary discovery hit the ownership check; no Git configuration changed. Status reported no working-tree changes, with warnings about the inaccessible user ignore file.

Not checked:

- No fresh R execution or independent rerun of predecessor probes. No timing windows, full test suite, package check, oracle, lean gate or other long run. This re-review does not assert that the future implementation or tooling already passes.
- No tracked file edited and no commit made. Only this requested report was written. No library under AppData/Local/Temp was used; no E:, ledgr-research or vendor data was accessed.
