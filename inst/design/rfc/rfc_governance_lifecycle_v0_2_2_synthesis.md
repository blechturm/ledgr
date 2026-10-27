# Synthesis: Authority And Lifecycle Of Governance Documents

Role: record; accepted governance decisions, binding in their stated scope.
Status: accepted
Mode: Decision synthesis. Author: Codex. Date: 2026-10-13.
Acceptance: maintainer, 2026-10-14, after the final-review corrections.
Amendments: none.
Final review: PASS_AFTER_PATCHES; corrections applied in Section 10.

Baseline: ea10ab72ff1feca54950c2e1c6f3156d9b02efd7. The decisions file is
uncommitted at this baseline; its supplied SHA-256 is:
AC62B1FC9B4EA9059B5CCA229CF20632C7F8B8FC1EC0C574AA11142EAD796FD0
Citations use this tree and M; acceptance authorizes later application.

Citation key (paths relative to inst/design unless root/ is specified):
S = rfc/rfc_governance_lifecycle_v0_2_2_seed_v2.md
M = rfc/rfc_governance_lifecycle_v0_2_2_maintainer_decisions.md
R = rfc/rfc_governance_lifecycle_v0_2_2_response.md
V = rfc/rfc_governance_lifecycle_v0_2_2_response_review.md
F = rfc/rfc_governance_lifecycle_v0_2_2_final_review.md
G = rfc/rfc_governance_review_post_v0_2_0_1_synthesis_v2.md
P = rfc_cycle.md; I = README.md; B = decisions.md; C = contracts.md
Q = ledgr_v0_2_2_spec_packet/macro_plan.md
A = root/AGENTS.md; J = rfc/README.md
E = root/dev/governance_census/; E/records/ contains the census CSVs.
Aliases cite files:lines; table replacements name this file's sections.

## 1. Choice and evidence boundary

Adopt S Sections 3-5 with these revisions; structure cannot approve judgment.
M:15-34,47-54,66-71 settle gate, findings home, scope and activation.

The pilot, dated amendments and missing rule-group addresses hold (V:82-95).
The extra accounting back-link defect, reference ban and causal gate diagnosis
do not (V:97-137). Use census records, not those assertions, for migration;
a mismatch proves neither non-implementation nor semantic disagreement.

E/records/summary.csv:3-41 records 14 missing bridge/heading pairs across
three rows, 47 syntheses, nine superseded history versions, 252 claims
(19 contract-only, 169 ticket-only, 63 RFC, one mixed), six dead anchors,
and 886 scoped links with 45 missing-file occurrences over 12 targets.
S:64's 297 files is stale: the recorded population is 299 (summary:21).
These are census populations, not permanent guard expectations; do not merge
them with V:47-55's different baseline/parser or call them current totals.

81/98 and 11/13 cuts above 0.5 are historical, not M1-certified counts
(summary:13,19,36; V:64-72). E/cut_review_counts.csv and its cut_reviews.csv
output verify phrases, not independence. Missing costs/session evidence are
unknown, not zero. Recount at closeout under M1 without rewriting records
or inferring causation.

## 2. Authority and document lifetime (S R1-R2)

A governance file starts with a Role line: record, living or mixed, followed
by its purpose and authority source (or non-binding). A section of different
force starts with that qualification and its accepting or receiving source.
Neither a file name, normalized status nor index grants authority.

Contracts bind shipped behavior; accepted synthesis sections and recorded
maintainer decisions bind their stated pending scope. Acceptance does not
claim implementation. Incorporated evidence binds only the expressly
promoted rule, with a link to its accepting section. Preserve snapshot
hash-rule incorporation; do not enact R:279-280's blanket ban (V:112-116).
Process documents bind their adopted process rules, not package semantics.

Resolve both role conflicts: the roadmap binds release scope and release
sequence; the macro plan's Remaining order binds uncut within-release order;
tickets.yml alone sequences cut work. P binds its process despite P:3,338's
disclaimers. I:38-44 and A:83-88 must express these boundaries consistently.

Records preserve accepted text, evidence and rejection reasons. Permit
dated appended amendments, listed and linked in the header with acceptance
provenance; affected sections receive the notices in Section 4. Preserve
P:59-65's narrow typo/citation, final-review bug-fix and expressly requested
inline-decision exceptions, with revision notes. Do not use an exception
to redesign accepted scope silently. Contested major revisions get versions.
At declared last-stage close, freeze working registers and their provenance.

Living documents change in place with a short dated source line. Move
displaced narrative to history with redirects; do not append a competing
current answer. In tickets.yml, status/dependencies/sequencing are living;
evidence/review fields are records. Apply rules by section, not extension.
Normalization may correct metadata from evidence; a passed final review
alone is not proof of maintainer acceptance.

## 3. Addresses, headers and claims (S R3-R4, R7)

Record Status values: draft; under review; accepted; amended YYYY-MM-DD;
working; consolidated; superseded; superseded in part; rejected.
Keep rejected distinct from superseded (E/records/synthesis_headers.csv:14).
Amended requires dated amendment links and acceptance provenance;
consolidated requires receiving rule-group addresses; supersession requires
replacement sections and date. Partial cases also identify operative
remainder/open obligations. Working is the register state, not acceptance.
Role and Status are separate: an accepted review does not bind its opinions.

Pipeline states, defined once in J: due = owed but not started; active =
in progress; paused = started, awaiting a named trigger; obligations open =
accepted duties awaiting ownership; parked = non-binding possibility;
closed = no remaining duty in that row, retained only as history/redirect.
Use one state, not active plus a prose assertion of paused.
Bridge states: pending; consolidated, awaiting closeout.
Type 1 verdicts: PASS, PASS_AFTER_PATCHES, CHANGES_REQUIRED, NEEDS_TYPE_2.
Type 2 verdicts: PROCEED, REVISE_SEED, REJECT.
The guard checks designated metadata/row fields, not quoted historic words.
Historical verdicts remain records; specific legacy exceptions are baselined.
Ticket status harmonization remains cut work, not a new ticket schema.

C gains a stable H3 or explicit ID for each related rule group during the
scheduled present-tense pass (Q:855-862). No per-bullet anchors. Retain H2
routes; add a group address before a new reference needs that precision.
Tables, back-links and new/edited claim sources cite the operative group or
accepted synthesis section, plus their ticket if applicable. Existing
ticket-only sources are reported, not blanket-backfilled or auto-promoted.
Source changes must preserve what the actual block detects. Size and source
warnings are advisory, not new line caps or proof of oracle independence.

## 4. Supersession, consolidation and obligations (S R5-R6)

A change to accepted text carries a table with target artifact, addressed
section/group, disposition (superseded, amended, unchanged), and replacement
section. For unchanged, name the retained address, not a fictitious change.
For broad changes, generate the affected-rule inventory from a census and
have the final reviewer reconcile every row and omission to that inventory.
A human compares meaning; keyword equality cannot establish consolidation.

At acceptance, changed targets get a dated header notice and a marker at
each affected heading linking to the replacing section/table. Unchanged
rows require no change notice. Partial notices must not retire unrelated
rules. Add the bridge mapping and an Accepted change pending back-link at
each affected contract group, preserving the shipped rule until implemented.
Process-only changes map to the standing process receiver, not an invented
contract group. The implementing commit rewrites the receiving rule and
removes its pending link; source metadata names the receiving address.
Consolidation passes without a stale pending link.

Keep B a hand-maintained index. Reconcile stale rows before adding pending
links: its current unmatched pairs include already-shipped rules. Do not
generate a bridge without a declared authoritative section-mapping source.
Check source notice, bridge mapping and receiver back-link as a triangle,
with stage-aware expectations; the guard cannot decide semantic equality.

Ordinary bridge exit remains closeout with the exact receiver recorded
(B:14-16). The governance cut may close already-consolidated rows with
that same proof in its removal record, as Q:840-854 explicitly authorizes;
it is not a silent general early-exit rule. Until exit, use consolidated,
awaiting closeout. Never remove an operative remainder to tidy a row.
Keep superseded versions at their paths. A removed heading, row or anchor
with inbound references leaves its old address as a redirect stub naming
the receiver. A stub is a locator, not continued authority.
Accepted obligations stay visible with source and trigger until ticket cut
owns them or the maintainer explicitly drops them with a reason
(P:172-180,209-214). Consolidation alone discharges no unimplemented duty.

## 5. Evidence, reviews and pilots (S R8-R9; M1 and M2)

Ticket evidence gives each acceptance item's record pointer and one-line
result. Preserve reviewed ranges and G D4's empirical fields: input identity,
environment, source commit, reproduction command, result and clock
(G:104-120). Keep consequential rejection reasons, not session transcripts.
A summary without those fields or its necessary retained evidence does not
suffice. Neither all raw files nor only summaries are universally required.

M2 is decided: a review returning findings writes a file in the owning
packet, named for its review point (cut_review_13.md; close_review_27.md).
The tickets.yml review field holds verdict, link and one line on what
changed. PASS with no findings gets that one line, no file. This applies
from the first review after acceptance; closed tickets and past fields stay
records (M:47-54). This adds a findings-home rule to D4, not a claim that
D4 already required it. Reject the review's optional-file alternative.

M1 is decided: retire the 0.5 gate; record the ratio without gating.
One invocation is one independent verdict at cut review, workstream close,
focused re-review or final review, from a session other than the implementing
agent's. Own-session agent reviews are labelled and counted separately,
never in that numerator. Completed tickets are the denominator; dropped
tickets enter neither count. Count verdicts, not component findings.
Record counts and ratio once at cut close and once as the packet total,
not in ticket/workstream fields. Do not erase historic repetitions.
Other D8 counters stay at these two points, including findings by mode and
outcome change, and maintainer decision turns (M:15-26; G:191-195).
Unknown historical measurements stay labelled unknown, not estimated zero.

A third correction round on one workstream stops for the maintainer to
decide whether ticket, implementation or brief is wrong. Reassessment owner:
maintainer. Trigger: v0.2.2 closeout. Inputs: M1-defined counts for every
v0.2.2 cut. Dispositions: keep, revise, drop; record the decision in P at
the current pilot passage (M:27-34). This is measurement now, not postponing
its definition. The other D8 failure conditions remain (G:197-200).
Every later pilot names owner, exit trigger and dispositions. The guard
reports overdue pilots; it cannot infer a human reassessment from a date.

**Closeout reassessment, 2026-10-27:** keep M1 unchanged. The complete v0.2.2
record is 202 independent verdicts over 202 completed tickets, with the
per-cut counts, finding outcomes and maintainer turns recorded in the
[release-gate closeout](../ledgr_v0_2_2_spec_packet/release_gate_closeout.md#final-m1-accounting-and-reassessment).
The equality is incidental and is not a target or quality score. Report-only
accounting exposed correction cost without encouraging ticket padding, while
the third-round escalation repeatedly forced an explicit maintainer choice.
The eight-hour publication path is not an M1 failure; its release-candidate,
CI-gate and evidence-reuse redesign is routed to a separate v0.2.3 RFC.

## 6. Guard contract and placement (S Section 4)

Extend the census into a standalone report/check tool; do not treat its
exploratory parser or totals as a completed detector. Scope: tracked
.md/.qmd sources at top-level inst/design, recursively rfc/, manual/ and
the current packet, including historical records there (M:66-69).
Read tracked sources from the working tree; resolve local targets there,
even outside scan scope. Existing untracked targets are advisory, not missing.
External URLs and code examples are not local-link findings. Validate used
reference links, relative paths, renderer heading slugs and explicit IDs.
Read claims.yml as the source-warning input; do not widen into package or
vendor-data validation. Unlike the census's tracked-path resolution, check
uses working-tree targets and fragments, never only old committed blobs.

Baseline identity is source file, target and occurrence index (source order
among uses of that target); the line is a locator the tool refreshes.
Never exempt a directory or all uses of a target. Additional occurrences
are new debt. The baseline shrinks; additions need a maintainer reason.
Reconciliation exceptions name the row/mismatch, owner and cut disposition,
not a permanent bypass.

Check fails on any unbaselined case:

- Broken local target/anchor, including a new link to a baselined dead target.
- Duplicate explicit ID or a used ambiguous heading-slug collision.
- Missing required metadata, invalid Role/Status/row-state/verdict token,
  or missing receiver/replacement/amendment provenance required by its state.
- Changed table row without its matching notice/marker, or vice versa;
  missing replacement, wrong address, or missing declared remainder.
- Stage-inconsistent source/bridge/receiver mappings outside an individually
  recorded reconciliation exception. Malformed/missing checker inputs fail.

Pass means zero unbaselined structural failures, with debt and advisory
reports still visible. Test clean and fully baselined trees, valid partial
supersession, unchanged rows, promoted references, consolidated mappings
without pending links, and redirect stubs as passes. Test each failure
class; specifically insert a broken link and remove a target notice, add a
new use of old debt, and remove only one partial-supersession marker.
Test an untracked target as advisory, then delete it and require failure.

Use one registered structural-detector block in the existing test control
plane, with claim source, oracle-independence and mutation witnesses.
Place the full scan in review; the seed's roughly six-second census is not
a fresh fast-budget measurement. A measured smaller failing subset may move
to fast only through the existing lane/gate rules, with unchanged bounds.
Skip only outside a source tree; missing required source-tree files fail.
No guard per review or independence score (G:130-136); implementation gets
Type 1 review under D6 (G:154-156).
Start in report mode. Check starts no earlier than the cut after the
governance cut, and only once workstream 4's header normalization and the
reviewed baseline/fixtures exist (M:70-71; Q:803-811). Time alone is not
activation. Acceptance does not deliver the guard.

## 7. Application and process wording authorized on acceptance

The 2026-10-13 amendment owns the governance cut (Q:792-869): after the
one-execution-mode probe, before the WS3/WS4 implementation cut. Each of its
four workstreams applies these rules with a Type 1 close review:

1. Rules and guard: process wording, guard delivery in report mode, baseline.
2. Contracts: present-tense pass, rule-group addresses, bridge/back-links.
3. Planning documents: roadmap, Remaining order and horizon scan.
4. Records: synthesis headers, packet README trim, open-ticket evidence form.
Workstream 2 compares clauses after Cut 14 (Q:855-862); workstream 4 preserves
acceptance evidence, duties and rejection reasons. Keep guard delivery in
the pipeline until the cut's tickets own it; do not create a second program.

S Section 5 stands: if acceptance precedes the history-wave amendment,
that amendment to v11 is the first application-specific supersession carrier.
Otherwise retain the amendment under its original rules, record the explicit
transition exception; the governance cut adds its table/notices. The history
wave owns the amendment (J:31); workstream 4 owns retrospective normalization.
This synthesis's process-change table below is not a waiver for v11.
Acceptance still precedes opening the execution-core consolidation RFC.

Authorize these substantive wording changes, not immediate edits here:

- P:3,338: "This living document binds the RFC and review processes it
  governs. Historical examples explain them; a deviation names its reason
  and maintainer authorization." Keep stage-skipping/rotation provisions;
  do not let the old non-binding disclaimer nullify adopted rules.
- P:59-65: retain its narrow exceptions, then "Otherwise use a new version
  for contested major revisions, or an accepted dated appended amendment
  with the lifecycle synthesis's supersession table and notices."
- P:249-251,274-278: replace the stale pilot-only/0.5-gate wording with
  Section 5's M1 measurement, escalation and closeout reassessment, and
  M2's prospective findings-home rule. Preserve modes, routes and briefs.
- I:32-48: "Authority attaches to accepted sections, not file kinds.
  Contracts bind shipped rules; accepted changes bind pending scope.
  Promoted references name their accepting section. The roadmap binds
  releases; the macro plan binds uncut within-release order; tickets.yml
  sequences cut work. Process documents bind their adopted process rules."
- A:36-43,86-88: retain human briefs and Type 1's independent-input question;
  substitute "Review ratios are recorded, not gated; a third correction round
  escalates to the maintainer. Findings follow rfc_cycle.md's record rule.
  Cite stable contract rule-group addresses; acceptance alone does not
  change shipped behavior." Replace existing wording, not append lines;
  keep A under 150 lines (currently 145). Link rather than duplicating M.

Apply Section 3's state definitions to J/B, and Section 4's notices to
affected records/receivers in the acceptance/application steps they name.

## 8. Replacement map and rejected alternatives

Addresses below name sections/headers in the citation-key files. An unchanged
entry names its retained address; numbers in the last column refer here.

```text
Target/address                          Disposition   Replacement/retained
G D1, human briefs                      unchanged     G D1
G D2, modes and synthesis                unchanged     G D2
G D3, workstreams                        unchanged     G D3
G D4, evidence/findings                  amended       Section 5
G D5, process-form limit                 unchanged     G D5
G D6, proportionate routes               unchanged     G D6
G D7, implementation authority           unchanged     G D7
G D8, gate/pilot measurement              amended       Section 5 (M1)
G D9, cost                               unchanged     G D9
P Status header                         amended       Sections 2, 7
P When to deviate                        amended       Sections 2, 7
P File naming conventions               amended       Sections 2, 4, 7
P Review modes, workstreams, and routes  amended       Sections 5, 7
I What can bind work                    amended       Sections 2, 7
A Core Rules                            amended       Sections 2, 5, 7
A Current State                         amended       Sections 2, 7
C opening pending-change rule           amended       Sections 3, 4
B exit rule                             amended       Sections 3, 4
J RFC Pipeline                          amended       Sections 3, 4
```
P sections not listed, and text outside the cited amended spans within
listed sections, are unchanged at their existing addresses.

G D5 still excludes agent-governance machinery and a standing release profile.
Annotate these amendments, not wholesale supersession of G/C/process rules.

Response requests 1/7 take M1/M2; 2/3 take group addresses and correction
exceptions. Reject 4's reference ban, 5's generated bridge without a mapping
source, and 6's directory exemptions/unmeasured sub-second threshold.
Keep 8's v11 transition; 9 takes reproducible, baseline-labelled counts.
Keep 10's disclosure: seed/response are Claude, review/synthesis Codex;
model family alone proves no independence.

## 9. Type 1 final review checklist (pre-acceptance)

Verify S R1-R9/Sections 4-5, M1/M2 and both directions against sources.
Check rejected-state, triangle, cut exit and v11 transition consistency;
route new design concerns as NEEDS_TYPE_2. Recheck census populations/method
and independence caveat; the replacement map, promoted rules and open duties;
and wording that removes both role conflicts and the obsolete operative gate.
Verify guard scope, identity, witnesses, activation and lane are implementable,
not claimed run. Check only this file/row changed, ASCII/79-column/350-line
limits, and no claim of completed acceptance or implementation.

## 10. Revision note

2026-10-14: applied F Section 2 corrections 1-5 (PASS_AFTER_PATCHES): ea10ab72
governance cut/timing, replacement map, baseline identity, working-tree
targets/witness and A's line budget. M1/M2 unchanged; submitted for acceptance.
