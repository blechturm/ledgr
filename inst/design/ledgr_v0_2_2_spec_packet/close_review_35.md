# WS35 close review (Type 1): Governance record normalization, `07f91bcf..d9cc7090`

## Verdict: **CHANGES_REQUIRED**

The structure is sound and every count reproduces. Four of the issues below need fixes. The worst is F1: three accepted syntheses are now headed as non-binding, which contradicts live Obligations-open rows that cite them. F2 and F3 break explicit LDG-3048 acceptance items, and F4 misstates a rejection reason. No redesign is needed.

## Findings

1. **High: three accepted syntheses are labelled `under review`, which turns accepted obligations into non-binding text.**
   - **Where:** `inst/design/rfc/rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md:3-5`, `rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md:3-5` and `rfc_compiled_hot_frame_b2_v0_1_9_x_synthesis.md:3-5`.
   - **What the headers say:** "awaiting final review; non-binding until maintainer acceptance".
   - **What the evidence says:**
     - All three final reviews exist and approve: "Approve synthesis as-is", and "Approve as binding artifact".
     - `ledgr_v0_1_8_10_spec_packet/v0_1_8_10_spec.md:45-52` lists all three under "Accepted RFC inputs".
     - `rfc/README.md:43,55,61,69` route accepted duties from these records as **Obligations open**, which line 21 defines as "an accepted synthesis binds later work".
   - **Why it matters:** the Role line is factually false. A reader who follows those pipeline rows now lands on a record that says it is non-binding. The implementer copied the census text instead of correcting metadata from evidence, which synthesis §2 permits.
   - **Fix:** set all three to `Status: accepted` with an acceptance-provenance line citing the final review and `v0_1_8_10_spec.md:45-52`. Recount to 28 accepted and 0 under review. Update `governance_record_normalization.md` and LDG-3047 evidence 1.

2. **Medium: the evidence guard accepts bare paths, which is exactly the case LDG-3048 acceptance 2 and 4 must catch.**
   - **Where:** `tools/governance-report.R:1021-1045`.
   - **Cause:** the result check runs over the path itself, so path words like `report`, `closeout` and `run` count as a "result".
   - **Probe of the guard's own predicates:** these strings all pass as well-formed:
     - `tests/testthat/test-governance-report.R#LTB-0273` (the exact pointer form Cut 15 uses);
     - `tools/governance-report.R`;
     - `dev/spikes/feature_keeping/closeout.md`;
     - "Verified and/or confirmed by inspection." (`and/or` counts as a path pointer).
   - **Untested branch:** no test mutates the evidence/acceptance count, so deleting the `incomplete_ticket_evidence` branch (`:1084`) leaves LTB-0273 green. This contradicts LCL-0271's `smallest_failing_change` and the closeout's "mutates each boundary independently" (`governance_record_normalization.md:78`).
   - **Fix:** strip pointer matches before testing for a result, and require remaining words. Add LTB-0273 mutations for a bare test anchor, a count mismatch and empty evidence.

3. **Medium: shrinking the README orphaned a closed review artifact (LDG-3048 acceptance 3).**
   - `cut_review_14.md` had its only inbound reference in the old README (base lines 48-49). It now has none anywhere in the repo, and Cut 14's `cut_review` field does not name it.
   - `cut_review_7.md` and `cut_review_13.md` were already orphaned before this change.
   - **Fix:** add one "Earlier cut reviews" line to `README.md#current-cut-review-records` listing cut_review_7, 9, 13 and 14, or put the file links into the Cut 7, 13 and 14 `cut_review` fields.

4. **Medium: the rejected-synthesis `Reason:` header misstates the recorded reason (LDG-3047 acceptance 4).**
   - **Where:** `rfc_governance_review_post_v0_2_0_1_synthesis.md:6`.
   - **Header says:** "rejected this broad design".
   - **Record says (`:266-271`):** the *enforcement layer* was rejected because it "turns process judgment into form checks". It also states that "Sections 4.1 through 4.8 are not themselves rejected".
   - **Fix:** restate that reason in one line and point to the revision history.

5. **Low: the empirical-evidence check never fires.**
   - **Where:** `tools/governance-report.R:1103`.
   - It only runs on evidence starting with `Empirical:`. No Cut 15 evidence uses that label, and `README.md#evidence-form` never defines it, so "zero empirical findings" means nothing.
   - The README rule also drops synthesis §5's "preserve reviewed ranges".
   - **Fix:** name the label (or its scope) in `#evidence-form` and add "reviewed ranges".

6. **Low: two dead anchors handed to WS35 remain.**
   - `horizon_migration_reconciliation.md:21,26` still point at the removed `rfc/README.md#terminal-outcome-policy` and `#feature-map-read-surface`.
   - The WS34 re-review (F6) left these "baselined for WS35". The file is linked from the new README as a durable closeout.
   - **Fix:** add redirect stubs in `rfc/README.md`, as was done for `snapshot-verification-policy`, or retarget the two links.

7. **Low: stale current-state prose remains in the history-wave register.**
   - `rfc_history_wave_v0_2_2_decisions.md:17-19` still says the wave is paused for the WS2 remainder (LFB-017/023/018), which is done. The real trigger is Cut 15 WS35 and WS39 acceptance.
   - Its new Authority line (`:5-6`, "decisions … bind the later v11 amendment") reads against `:11` ("Binds nothing until stage 3 …").
   - The two drafts (`rfc_sweep_*_v0_1_8_synthesis.md:3-5`) name no receiver, although `rfc_sweep_promotion_context_v0_1_8_decision.md` accepted that scope.
   - **Fix:** one-line rewrites, plus a `Receiver:` line on each draft.

8. **Low: some evidence numbers and claims are inaccurate.**
   - "582 → 81 lines" (`governance_record_normalization.md:51`, LDG-3048 evidence 1) are non-blank line counts. The raw counts are 684 → 103 lines, and the base size is 45,534 bytes, not 45,533.
   - LDG-3048 evidence 5 says the report-only guard role is recorded in the packet README, `inst/design/README.md` and `rfc/README.md`. None of them states it; only `dev/governance_guard/README.md` does.
   - The 327/996 run in `#verification` omits the source commit and the command.
   - **Fix:** relabel the counts and repoint or add one clause for the guard role.

## Per-ticket acceptance

| Ticket | # | Result |
| --- | --- | --- |
| LDG-3047 | 1 | Partial: canonical blocks are present and the pipeline has six states with history-wave Paused, but F1 and the draft receivers (F7) are wrong |
| | 2 | Met: v10 → v11 (2026-09-28); snapshot amendment linked and section-marked; the register states the carrier, consistent with §7 since governance acceptance (2026-10-14) precedes the amendment |
| | 3 | Met: fixtures detect stale accepted/active state, missing replacement and missing Trigger/Route |
| | 4 | Partial: bodies are verbatim (all 47 diffs are additions only) but the headers misstate F1 and F4 |
| | 5 | Met: 327 sources and 996 findings reproduced; report-only; `--check` aborts |
| LDG-3048 | 1 | Met: front door with no status, dependency or acceptance copies; line-count label is wrong (F8) |
| | 2 | Partial: rule stated once; guard misses bare paths (F2); empirical branch is unreachable (F5) |
| | 3 | Partial: Cut 15 artifacts linked and M2 stated; cut_review_14 orphaned (F3) |
| | 4 | Partial: bare-path detection fails open and the count branch is unmutated (F2) |
| | 5 | Mostly met: roles separated; guard-role citation overstated (F8) |

## Tests, mutations and counts

- **Focused suites:** all pass with 0 failures, skips or warnings.
  - `test-governance-report.R`: 2 tests, 177 expectations.
  - `test-documentation-contracts.R`: 24 tests, 1,031 expectations.
  - `test-test-control-plane.R`: 8 tests, 66 expectations.
- **Real-tree report:** 327 sources, 996 findings (they sum exactly by kind), 2 baseline entries resolved, `MODE report-only`.
- **Header and evidence scans:** zero findings on all 47 bounded syntheses; zero Cut 15 evidence findings from a direct call.
- **YAML:** 134 tickets, 39 workstreams, 268 claims; the fixture has 1 ticket.
- **Packet README:** all 36 link targets exist, and all six cited anchors exist.
- **Diff:** `git diff --check` is clean.
- **State tally:** 25 accepted / 4 amended / 10 superseded / 2 partial / 3 under review / 2 draft / 1 rejected reconciles to the census CSV, but F1 makes three of those wrong.
- **Mutations:** predicate probe as in F2. I did not run the full fixture-copy mutations; the tool's permission mode denied them, and the count-mismatch and missing-`tickets.yml` cases come from reading the code and test file.
- **Clean:**
  - The population is right: all 47 census records and only them. The governance-lifecycle synthesis is post-census and already carries its header.
  - No new registry, ledger, check mode or gate. Existing debt stays visible.
  - The lost Cut 14 and WS36 README narrative is preserved in `tickets.yml` and the closeouts.
  - The seven optimization shapes don't apply: no product path changed. The new loops run once over the current cut's tickets after one YAML parse, with no ordering or locale dependence.
- **Record-only:** `governance_scan_ticket_evidence` returns empty when `<packet>/tickets.yml` is missing (`:1055`). That falls short of synthesis §6 ("missing required source-tree files fail"). Make it a `governance_abort` with a deletion mutation.

## Maintainer decision

None, provided F1 is fixed from the v0.1.8.10 spec evidence, which §2 allows. If you do not accept "Accepted RFC inputs" as acceptance evidence, the three Obligations-open rows lose their binding source. That would make it **NEEDS_TYPE_2**. This is the first review of WS35, and it found issues, so under M2 Codex writes `close_review_35.md`.
