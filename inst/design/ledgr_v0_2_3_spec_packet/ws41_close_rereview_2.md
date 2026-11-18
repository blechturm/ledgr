CHANGES_REQUIRED

Mode: Type 1 focused re-review 2 of workstream 41 (Cut 22) close; independent fresh session, 2026-11-18; reviewed cb4caf684e74d8d86f945ca9aa9ecb9c12ed2f2f against 52712282.

G1. Not completely fixed: the original empty_treated and prep_only controls now fail on the reported 476 and 396 cases, and reach is recorded independently, but shared loss of the preparation observer on refusing cases still passes (rereview2/controls.txt, common_observer_probe.txt and runner_observer_probe.txt; H1).

G2. Fixed: faults.R:41 checks the requested library's selector before running; :57 records any runner failure as ok = FALSE. The unrelated-error driver exits 1 with FAULTS FAIL on the installed candidate; the same driver exits 0 with an explicit not-run disposition on the pin, whose namespace independently confirms selector absence (rereview2/driver_probe.txt).

Repository references are relative to C:/Users/maxth/ledgr-wt/ws41-close-review; runner.R, check.R and faults.R mean the files under dev/feature_parity/. Probe references are relative to C:/Users/maxth/ledgr-wt/ws41-close-review-out.

H1. Required: the refusal exception still permits an absent preparation observation despite positive independent reach.

Claim: an empty compute preparation trace is accepted only on the 147 past-end early returns, and every case reaching preparation must retain its field evidence.

Evidence: runner.R:150 records the treated fields and :152 increments prep_seen in the same observer. prep_reached comes independently from ranges (:165) or read bounds (:176); causality_checks comes from the definition-check seam (:210). Thus the reach counters are independent, but the seen counters share the observer whose loss they help check.

check.R:180 requires a prep entry only when prep_seen is positive. On any refusal, :182 accepts prep_seen <= prep_reached, including zero with positive reach. The inter-arm comparison (:129) catches candidate-only observer loss, but both arms use the same runner, so it cannot establish phase presence when that observer loses the same records in both.

rereview2/common_observer_probe.R removes only the preparation observer's two outputs on the 57 refusing cases in both fresh full-corpus observation files: prep entries and prep_seen. It retains every independent reach/check counter, causality entry, value, route, field union, refusal and corpus case. The committed checker exits 0: `cases 631 (refusing on the pin 57), observations pin 8280 candidate 8280`, `CHECK PASS` (common_observer_probe.txt). Candidate-only loss correctly fails with SIGNAL handoffs 57.

rereview2/runner_observer_probe.R confirms this by execution. It copies the committed runner, selects six existing compute cases and one existing read-entry case, and filters the committed expected rows to those seven cases. Its sole observation fault skips the inputs recorder's writes during preparation of the two custom_volume_strict refusing cases, in both arms. Returned inputs and every independent recorder remain intact. The baseline and faulty runs both produce `cases 7 (refusing on the pin 2), observations pin 90 candidate 90`, `CHECK PASS`; every non-observer component is identical (runner_observer_probe.txt). For hostile_carry2|data_start|custom_volume_strict, the accepted faulty record has an empty treated_fields value and `prep_reached=3;prep_seen=0;causality_checks=0;causality_reached=0;causality_seen=0`. This case did prepare inputs and then refuse; it is not a past-end return.

Consequence: the current recorded runs are populated, but the permanent proof can lose preparation evidence on refusing cases and still pass. The independent reach observation survives; the check becomes vacuous through its refusal allowance. This is a remaining G1 proof defect, not a prepared-value discrepancy or a Type 2 design question.

Fix: require preparation phase presence from independent reach on these registered cases, including refusals. Retain the smaller positive count allowed when a refusal stops later ranges. If a case can legitimately refuse inside input construction before any successful hand-off, identify that situation independently instead of exempting every refusal. Add a shared-observer-loss control that removes both outputs of this recorder while retaining independent reach; it must fail.

Checked:

- Read the brief, both preceding reviews, the focused diff, relevant Cut 22 requirements and evidence, accepted RFC and cut reviews, AGENTS.md, the named contract groups, and the applicable process/style text. Traced the calculation, causality and single-definition read hand-offs.
- Installed committed cb4caf68 under the requested output lib/rereview2 directory. Fresh pin and candidate runs reproduce 631 cases, 57 pin refusals, 8,280 observations per arm and CHECK PASS; pin against itself passes. All 7,649 pre-existing candidate observation rows equal the preceding review's rows after removing the new handoffs component (rereview2/audit.txt).
- The committed handoff summary reproduces: compute has 294 cases reaching preparation, 147 zero-reach cases all past_end, 236 reaching causality and six refusals with partial preparation counts. All 22 read-entry cases reach preparation. The full current data has no case with positive preparation reach and zero seen; H1 concerns what the checker accepts when recording is lost.
- Candidate-only controls fail for cleared treated fields, a dropped causality phase, cleared read-entry traces, erased read-entry counters and a false early-return record. Dropping a handoffs row refuses with exit 2. Clearing its value or dropping a required counter exits nonzero, sometimes through a parsing error; none passes (rereview2/controls.txt).
- Reran the complete fault driver: FAULTS PASS, all eight faults caught with distinct signal sets, all_fields producing treated_fields only on 126 cases. Missing arm, case and component refuse; cleared_treated and causality_dropped fail with treated_fields only; pin against itself passes. All 14 result rows exactly match the committed fault table. The handoff summary also matches the committed text exactly (rereview2/final_evidence.txt and faults/). These successful controls do not cover H1's shared loss of both outputs from the preparation observer.
- The diff changes no R/ or tests/ file, corpus.R or corpus_expected.csv. R/ also equals 39ac4ba4. Existing value comparisons, route assertions and field-union expectations remain; each observed phase still checks its fields separately, preserving the pin's wider treatment and the full-field read/custom assertions. No tracked file was edited, Git configuration changed or commit made.

Not checked: timing windows, memory benchmarks, the full test suite, package check, any lean gate, FIFO captures or replay. F1-F6 and the accepted timing record were not reopened. No private/vendor data, E: or ledgr-research was accessed; no Temp library was used. Scratch scripts and outputs are under rereview2/, the scratch installation is under lib/, and this file is the review deliverable.
