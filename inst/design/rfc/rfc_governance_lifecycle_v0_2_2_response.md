# RFC Response: Authority And Lifecycle Of Governance Documents

- Status: Type 2 response to seed v1, non-binding
- Author: Claude (Fable 5.1), not the seed's session. The seed is also
  Claude-authored; the maintainer's brief overrode the rotation that
  `rfc_cycle.md` lines 71-83 want, which the response review should weigh.
- Date: 2026-10-13
- Mode: Type 2 on framing, rule-set size and the audit evidence. Decisions
  already recorded in the 2026-10-13 cleanup amendment (`macro_plan.md`
  lines 792-852) are not argued.
- Baseline read: `3a939f8a`; every count below was re-measured there.
- Brief: maintainer-supplied

## 1. Answer

`REVISE_SEED`. The problem is framed about right: the current binding answer
is hard to find and the living documents decay by appending, and the audit's
structural findings hold in substance. The rule set is not the smallest.
Three parts restate decisions the 2026-10-13 amendment already took, one
rule cannot work as written because `contracts.md` has no clause-level
anchors, one contradicts how accepted records are amended today, and the
pilot history in Sections 1 and 7 is wrong. Seed v2 needs:

1. The pilot ran and was decided; the reassessment it scheduled is what is
   overdue. Reframe, and route the gate decision to the maintainer-decision
   stage rather than to synthesis.
2. Clause-level anchors in `contracts.md` as a precondition for rules 5.1,
   5.3 and 5.7 and for guard checks 3 and 4.
3. Records may gain appended, dated amendment sections; accepted text is not
   rewritten. The seed's "only its status header changes" must say that.
4. The guard is a standalone markdown and YAML tool with a scoped link
   check. The census tool it claims to build on does not exist.

## 2. Is the problem framed correctly?

**Mechanism: yes.** Findability and decay are the right pair, the findings
reproduce (Section 3), and the decay has one shape: a rule exists in prose,
nobody runs it, the next agent appends. `contracts.md` lines 9-13 already
require the back-link 15 clauses lack; `decisions.md` lines 14-16 state the
exit every closeout skipped; `rfc/README.md` lines 66-70 require the
pipeline and bridge to move at acceptance. The load-bearing element is
therefore the guard, not the vocabulary (Section 5).

**Overstated: "no procedure for supersession."** A partial one exists: a
later document binds only when it "explicitly supersedes the earlier source
and identifies the operative replacement sections" (`README.md` lines
56-57); partial supersession keeps every operative source visible
(`decisions.md` lines 15-16); `rfc_cycle.md` line 237 binds amendment
discipline; ten superseded historical-projection versions carry dated
headers. Missing are the mechanics: the notice at the target, the table,
and a way to find the claims and tests that protect a clause.

**Mis-scoped: the D8 reassessment.** The evidence form (D4) belongs here,
since evidence essays are document decay. The gate is a different question
with a different owner: D8 made it a maintainer decision (synthesis v2 lines
181-204) and `rfc_cycle.md` reserves stage 6 for the maintainer's binary
choices (lines 26-30). A synthesis that derives the gate's replacement from
a document audit decides the review model as a side effect. Seed v2 should
carry the gate to a maintainer-decisions artifact and record the answer.

**Redundant with the 2026-10-13 amendment.** Roadmap rows releases only
(`macro_plan.md` lines 800-810), the "Remaining order" section (811-815),
the horizon scan (816-824), the bridge exits and header fixes (825-839) and
the present-tense pass (840-852) are decided. Sections 4.1 and 8 restate
them. The RFC should bind rules and cite the amendment for the steps, or
acceptance creates a second holder of the same decision.

**Unstated: the first supersession table.** The seed names the
execution-core consolidation RFC (Section 8, item 4). The history wave comes
first: its register will "write one amendment to v11" (`rfc/README.md` line
31), superseding sections of an accepted synthesis before this RFC is
applied. Seed v2 should make that amendment the first carrier or an
explicit exception.

## 3. The audit evidence, checked

Each finding was re-measured at `3a939f8a` with a link resolver, a field
word-counter over `tickets.yml` and `grep` over the sources named.

- **A. Sequencing authority.** Six files state who holds it and five agree,
  so "7 or more files claim" it is overstated: `tickets.yml` once cut
  (`README.md` line 7, `AGENTS.md` line 83, packet `README.md` line 27,
  `macro_plan.md` lines 18-20, roadmap lines 4-7). The conflict is design
  index item 3 (lines 38-39), which says the roadmap binds dependency order
  while the roadmap defers to the macro plan (lines 4-5), and the order of
  uncut work living only in the amendment log, which the amendment itself
  admits (line 794). Cut progress: `README.md` line 66 says Cuts 1 through
  8, `macro_plan.md` lines 3-4 and roadmap line 156 say 12, packet
  `README.md` lines 3 and 55 say 13. Substance confirmed.
- **B. Appending.** 3,387 words at `29e00aa8` (2026-10-05) to 7,112 now;
  12 dated amendments under Section 7; the remaining order restated at
  lines 730, 788 and 850 and again in the pipeline row. Context frames:
  Section 5 (lines 515-517) and the pipeline row (`rfc/README.md` line 57)
  say the next release; the 2026-10-09 amendment places "context-frame
  retirement with the WS3 cut" (line 642). Strictly the amendment places
  the Due RFC item, not the retirement: an ambiguity with a contradiction's
  effect. Confirmed.
- **C. Invisible amendments.** `contracts.md` lines 9-13 confirmed. Missing
  back-links are 15 across four rows, not 14 across three: feature-map 2,
  snapshot verification 5, legacy removal 7, and accounting-core
  consolidation 1 (`decisions.md` line 30 names the Execution Contract; the
  list at `contracts.md` lines 67-74 omits it). The snapshot-verification
  synthesis header (lines 1-13) carries no notice. Corrected count.
- **D. Status headers.** 47 files are named `_synthesis.md` or
  `_synthesis_vN.md`, not 43. Three say "pending final review" although a
  final-review file exists (compiled hot frame B2, strategy-authoring
  helpers, strategy-callback addendum); two say draft (sweep candidate
  promotion, sweep promotion context); one has a `Stage` line and no status
  (optimization round v0.1.8.7); eleven historical-projection versions sit
  together. The pipeline cites the helpers synthesis at lines 37 and 50 and
  the addendum at line 64 as accepted sources. Confirmed except the count.
- **E. Exits.** The terminal-outcomes row left in `4f2d6c74` at Cut 6 close
  on 2026-10-06, not at release closeout. The feature-map row stays while
  the Context Contract holds its rule (`contracts.md` lines 1351, 1369,
  1442). Exactly six inbound anchors are broken, all to removed pipeline
  rows: `#terminal-outcome-policy` from `horizon.md`, the horizon migration
  reconciliation, and both terminal-outcomes seeds; `#feature-map-read-
  surface` from `horizon.md` and the reconciliation. Confirmed.
- **F. Status words.** The history-wave row is `Active` and "Paused in
  stage 2" (`rfc/README.md` line 31). Eleven review tokens are in use,
  `PASS` to `APPROVED`, with `REVISE` beside `REVISE_SEED` and `REJECT`
  beside `REJECTED`, plus spike `GREEN` and `RED`; `rfc_cycle.md` line 261
  defines only `NEEDS_TYPE_2`. Confirmed.
- **G. Force.** `rfc_cycle.md` lines 3 and 338 versus `README.md` lines
  42-44; the manual's header (lines 8-12) disclaims what `AGENTS.md` lines
  47-55 bind. Confirmed.
- **H. The gate.** Recorded figures: 6/3 = 2.000 (`tickets.yml` line 204),
  21/26 = 0.808 (line 189), 8/11, 8/12, 7/11, 6/9, 4/2 and 3/1 breach; 2/4,
  4/9, 7/20 and 7/17 meet. The arithmetic appears 15 times as `n/m = x`,
  the gate value 38 times, "breach" 12 times; the seed's 54 was not
  reproduced, the order of magnitude holds. Denominators are per workstream
  and per cut (line 173 runs a cumulative count inside one workstream); D8
  preregistered per packet. Confirmed in substance; see Section 4, Q3.
- **I. Evidence essays.** 17,762 words at `6c8861c1` (2026-10-04) to
  74,254; the `evidence` fields grew from 5,404 words (30.4 percent) to
  29,950 (40.3 percent); 191 distinct commit-hash tokens; `acceptance` is
  17.4 percent and `scope` 13.0 percent. The packet `README.md` is 583
  lines, cut narrative occupies lines 67-575, the last cut section is Cut 9
  while line 3 says 13 are closed. Confirmed.
- **J. Claims.** Of 252: 19 cite a contract heading alone, 169 cite only a
  ticket, cut or batch, 63 cite a synthesis or RFC. Confirmed (166 to 169).
- **K. Guards.** `test-project-metadata.R` lines 73-79 pin two `AGENTS.md`
  section names; `test-documentation-contracts.R` lines 2036-2038 pin three
  contract phrases. Nothing checks links, headers, states or sizes.
  Confirmed.
- **Links, not in the seed.** 905 relative links in the current governance
  files, `rfc/`, the v0.2.2 packet and `manual/` (977 across `inst/design`);
  66 file targets missing in that scope, 109 in all, nearly all in
  historical audits and packets. This sets the guard's scope (Q5).

**Wrong in the seed.**

1. "The pilot review never ran" (Section 1, lines 27-30; Section 7). It
   ran on v0.2.0.2 Cut 1: `test_cleanup_closeout.md` lines 115-126 record
   11 reviews over 31 tickets, 0.355, and the turn counts; the packet
   `README.md` lines 322-329 record the decision, "promote for v0.2.0.2,
   reassess before the next version"; `AGENTS.md` line 36 says "applied
   since v0.2.1.0". The reassessment is what never ran, and `rfc_cycle.md`
   lines 249-251 still describe a pilot: finding C in miniature, a decision
   that lives in a packet README and never reached the process document.
2. Section 6: "built on the census tool the hygiene workstream already
   added". `tools/` holds no such tool; the hygiene workstream is part of
   the removal cut, which is not cut (`macro_plan.md` line 734).
3. "No procedure for supersession" (Section 1): partial, as above.
4. Counts: 14 across 3 rows is 15 across 4; 43 syntheses is 47; 166 is
   169; 54 is not reproducible; 591 links is 905 or 977 by scope.

## 4. The Section 10 questions

**Q1. Record versus living document.** The split is right. Several files
are both, and the seed should say which part is which rather than assign
each file to one kind:

- `tickets.yml`: status, sequencing and dependencies are living; `evidence`,
  `cut_review` and `close_review` are records, 4,060 words of review prose
  with no file behind most of it (the packet holds only `cut_review_7`,
  `_9` and `_13`).
- `rfc/README.md`: row state is living; the context-frame row (line 57) is
  a record wearing a row. A row carries state, one link and one trigger.
- `horizon.md`: a living index over dated record entries, with addenda and
  a redirect section (line 4121). It already behaves both ways.
- Working registers (the history-wave register, lines 3-8) are living until
  stage 3 and records after; the vocabulary has no state for them.
- Accepted syntheses with appended amendments: validation Sections 14 and
  15 (lines 578, 622), walk-forward Sections 14, 16 and 17 (lines 589, 744,
  989), and the v11 amendment to come. `rfc_cycle.md` lines 59-65 allow
  in-place patches for three cases. The seed's rule 3.1 ("never rewritten
  after acceptance; only its status header changes") contradicts both. The
  defensible rule: accepted text is not rewritten; a record may gain a
  dated, appended amendment section; the header lists every amendment.

**Q2. Vocabulary; `consolidated` and the bridge.** Two gaps and one surplus.
Gaps: `working` for registers, and `amended <date>` in the header of a
record with appended amendments. Surplus: the `tickets.yml` status
harmonization is a sweep chore, and the roadmap-row rule is already
decided. The Type 2 verdict set is fine. `consolidated` on a synthesis does
not make the bridge redundant: the bridge holds which standing heading
receives the rule, which no header holds, and four rows point at a v0.1.9.5
spec with no header at all (`decisions.md` lines 20-23). It should become
derived: guard check 4 compares the synthesis header, the bridge row and
the contracts back-link, and once the guard exists the bridge can be
generated. Until then it indexes and holds no state (`README.md` lines
34-37).

**Q3. The gate.** The ratio failed for two reasons that are not ledgr's cut
size. D8 preregistered it per packet (lines 183-185) and the pilot measured
it that way (11/31); v0.2.2 applies it per cut and per workstream
(`tickets.yml` lines 173, 204), where a one-ticket workstream with a
cut-review share and one close review cannot meet it. And it counts the
correction rounds that are the yield, although D8 says a correct packet
must not fail for lacking defects (lines 186-188). The escalation rule
measures something else, a stuck workstream, so it is an addition, not a
replacement. The cost signal to keep is the one D8 lists (lines 191-195):
one packet-level ratio and the maintainer's decision turns, recorded at cut
close and summed at closeout, with no gate. The maintainer pays the cost
directly (D9), so a recorded number is enough. The choice is the
maintainer's under stage 6.

**Q4. The evidence form.** It loses one thing reviewers rely on. Most close
reviews have no file, so "verdict, a link and one line" would drop the
finding lists; Workstream 27's F1 to F7 exist only in `tickets.yml` line
204, and the "changed an outcome" accounting needs them. Rule to add: a
review that returns findings writes a file, as cut reviews do; a `PASS` is
one line. Two clarifications: the reviewed commit range is an evidence
record, so its hashes stay; raw `dev/bench` records are gitignored
(`.gitignore` lines 112-115), so only tracked summaries are the record.
The form leaves `acceptance` (17.4 percent) and `scope` (13.0 percent)
alone, rightly, but `acceptance` is where prose returns next.

**Q5. Report then fail.** Right, in the order of how deterministic each
check is: (1) links and anchors, scoped to living documents and
current-release records with historical directories allowlisted, since 66
to 109 broken historical links would otherwise block and records are not
rewritten to satisfy a checker; (2) the header format on records and the
state vocabulary of pipeline and bridge rows; (3) the header, bridge and
back-link triangle; (4) supersession pairs, once the first table exists.
Size findings stay reports (D4, line 120). The guard is a markdown and YAML
tool independent of the R census tool. Its failing test defines a claim,
so it gets a `claims.yml` entry and a Type 1 review (D6, lines 154-156),
joins the fast profile only if it stays well under a second, and skips
outside a source tree as `test-project-metadata.R` lines 73-75 do.

**Q6. Missed and wrong.** Wrong: Section 3 above. Missed:

- `contracts.md` has no clause-level anchors: 13 H2 headings, one H3 (line
  1104), every clause a bullet. Rule 5.7 cannot localize a clause inside a
  280-line Execution Contract; the 19 claims citing a heading alone prove
  it, and rule 5.1 and guard check 3 share the gap. Clause anchors are the
  precondition for all of Section 5; the present-tense pass can add them.
- A contract that defines current behaviour by pointing at a record: the
  rule-3 bytes are "defined by" seed v2 Section 5 (`contracts.md` lines
  443-449), which the design index calls evidence (lines 46-48). Rule 4.1
  needs: no current rule is specified by reference to a seed or review.
- The pilot record (Section 3, item 1); amended records and working
  registers (Q1); the v11 amendment as the first supersession event
  (Section 2); historical broken links and the guard's scope (Q5).

## 5. The smallest set

Keep, load-bearing: the holder table (4.1) with the clause-anchor
precondition and the no-reference-to-records line; the record and living
rule with appended amendments; one fixed header on records; the target
notice and contracts back-link at acceptance (5.2, 5.3); redirect stubs
(5.5); the guard with four failing checks; one pilot rule (exit trigger and
owner); the pipeline and bridge state words, because the guard needs a
closed set. Move: the gate to a maintainer decision; the evidence form to a
D4 restatement with the review-file rule. Drop or cite: the `tickets.yml`
status harmonization (sweep chore); the roadmap and remaining-order rules
(cite the amendment); any claims backfill beyond "the guard reports them".

## 6. Changes required for seed v2

1. Sections 1 and 7: correct the pilot history, frame the overdue
   reassessment, and route the gate to a maintainer-decisions artifact.
2. Add the clause-anchor precondition for `contracts.md` (H3 per clause
   group or an `<a id>` per bullet), added by the present-tense pass.
3. Rules 3.1 and 5.6: appended dated amendments allowed, accepted text not
   rewritten, header lists amendments; add `working` for registers.
4. Section 4.1: forbid specifying a current rule by reference to a seed,
   response or review; name `contracts.md` lines 443-449 for the sweep.
5. Section 4.2: the bridge is derived; guard check 4 is the triangle.
6. Section 6: standalone tool, scoped link check with a historical
   allowlist, no "already added", claim entry and Type 1 review.
7. Section 7: the review-file rule; reviewed-range hashes allowed; tracked
   summaries are the record.
8. Section 8: make the v11 amendment the first supersession-table carrier
   or exempt it; cite the 2026-10-13 amendment for the sweep steps.
9. Section 2: 15 across four rows, 47 syntheses, 169 ticket-only claims,
   905 or 977 links by scope, 66 or 109 missing files, and replace 54 with
   the three counts in Section 3 H.
10. A rotation note: seed and response share a model family.

## 7. Not checked

- Of the seven contradictions in Section 2, four were touched (next step,
  context frames, the force of `rfc_cycle.md` and of the manual); legacy
  readability, the test-oracle rule and the feature-map status were not.
- Of the three defects Section 7 credits to correction rounds, only the
  split-store detector was located (`tickets.yml` line 204, F2); the two
  test-integrity cases were not found in `tickets.yml` by grep.
