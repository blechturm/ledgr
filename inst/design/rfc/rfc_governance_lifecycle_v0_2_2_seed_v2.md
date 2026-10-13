# RFC Seed v2: Authority And Lifecycle Of Governance Documents

- Status: draft; revised seed; maintainer decisions are next
- Author: Claude, seed v1 author. Drafted by an agent: it binds nothing
  until the maintainer accepts its framing.
- Date: 2026-10-13
- Baseline: `2d0a875e` (seed v1, response and response review committed)
- Inputs: seed v1, the Type 2 response (`REVISE_SEED`), the response review
  (Codex), governance synthesis v2 (D4, D6, D8), `rfc_cycle.md`
- Rotation: seed and response are both Claude; the maintainer's brief
  overrode `rfc_cycle.md` lines 71-83. The response review is Codex and
  independent. Disclosure does not itself establish independence.
- Stages: research input skipped (the census in Section 2 replaces it); the
  maintainer-decisions stage is used for Section 6; synthesis goes to an
  author other than this seed's.

Revision: v1's pilot history was wrong, its counts did not reproduce, its
rules banned what accepted practice allows (appended amendments, evidence
promoted by reference) and it decided the review gate inside a document
audit. This version corrects the history, ships a census whose output is
the only source of its counts, states authority per section, narrows the
rules to what makes the binding answer findable, defines the guard's own
acceptance, and returns the gate to the maintainer.

## 1. Question and Boundary

How do governance documents state authority, record their lifecycle and
supersede each other, so that the current binding answer is findable and
the documents stop decaying?

Partial supersession discipline already exists: a later document binds
only when it explicitly supersedes and names the operative replacement
(`README.md` line 56); partial supersession keeps every operative source
visible (`decisions.md` lines 14-16); amendment discipline is bound
(`rfc_cycle.md` line 237). What is missing is mechanics: notices at the
target, stable addresses for rules, a way to find the claims that protect
a rule, and any check that the prose rules are followed.

The governance pilot ran and was decided. Synthesis v2 D8 bound the loop
as a pilot; v0.2.0.2 Cut 1 measured 11 / 31 = 0.355
(`ledgr_v0_2_0_2_spec_packet/test_cleanup_closeout.md` line 122), and the
packet recorded "promote for v0.2.0.2, reassess before the next version"
(packet `README.md` line 328; closeout line 198). The reassessment never
ran, and `rfc_cycle.md` lines 249-251 still describe a pilot. That is the
overdue item, and its gate question is the maintainer's (Section 6).

Out of scope: the content of any rule or decision; the RFC stage
structure; the test control plane's design beyond the claim-source rule;
package code. Steps the 2026-10-13 cleanup amendment already decided
(`macro_plan.md` lines 792-860: roadmap shape, remaining-order section,
horizon scan, governance sweep, contracts present-tense pass) are cited,
not restated.

## 2. Evidence

`dev/governance_census/census.R` ships with this seed. It reads tracked
files only, writes deterministic CSV records to
`dev/governance_census/records/` (two runs are byte-identical) and takes
about 6 s. Every count below is a row of `records/summary.csv` at the
baseline; the method is stated in the tool's header.

| Measure | Count |
| --- | --- |
| Relative links, governance scope (297 files) | 886 occurrences |
| Missing-file occurrences, governance scope | 45 (12 targets) |
| Missing-file occurrences, all of `inst/design` | 51 (15 targets) |
| Broken anchors, either scope | 6 |
| Synthesis files; status forms (first four words) | 47; 15 |
| Pending final review although a review file exists | 3 |
| Draft; no status line | 2; 1 |
| Historical-projection versions; superseded headers | 11; 9 |
| `decisions.md` rows; heading links without back-link | 14; 14 in 3 rows |
| `contracts.md` H2; H3; explicit anchor ids | 13; 1; 0 |
| Claims: contract only, ticket only, RFC, mixed | 19, 169, 63, 1 |
| `tickets.yml` words | 74,254 |
| Ticket evidence; acceptance; scope words | 29,950; 12,957; 9,632 |
| Review-field words (cut, close, spike reviews) | 4,144 |
| Ratio expressions `n/m = x` (lines); "breach" | 21 (15); 12 |
| Review invocations / completed tickets, 13 cuts | 81 / 98 |
| Cuts whose recorded ratio exceeds 0.5 | 11 of 13 |
| Macro plan words; dated amendments | 7,112; 12 |

Discrepancies are not all defects. The 14 unmatched back-links are
topic-heading mismatches, and some receiving rules have already shipped.
Most missing files are historical links to removed R sources. The cut
counts come from `cut_review_counts.csv`, a transcription that the tool
checks phrase by phrase against `tickets.yml`.

## 3. Rules

**R1. Authority per section.** Each governance file opens with one role
line. A section whose force differs from its file's role says so in its
first line: for example "consolidated into `contracts.md` #execution-
contract", or "open obligation". Neither file kind nor a header confers
authority. A rule binds only through an accepted synthesis section, a
contract rule group or a recorded maintainer decision, and a rule
incorporated from evidence by reference names the accepting source, as
the snapshot-verification synthesis D1 (line 21) does for the bytes at
`contracts.md` lines 443-450. Two conflicts are resolved by role lines:
- the roadmap binds the release sequence, and the macro plan's remaining
  order binds uncut order inside a release (`README.md` line 38 today says
  the roadmap binds dependency order);
- `rfc_cycle.md` binds the process it governs (line 3 calls it
  non-binding; `README.md` lines 42-44 already bind it).

**R2. Records and living documents.** Accepted text in a record (seed,
response, review, synthesis, closeout) is not rewritten. The narrow
in-place corrections of `rfc_cycle.md` lines 59-65 remain. A later change
to a record is a dated amendment section appended to it, as the
validation and walk-forward syntheses already have, and the record's
header lists each amendment. A working register carries `working` until
its last stage closes, then becomes a record. A living document is
corrected in place with one dated change line, and no later section of it
may contradict an earlier one. A file can hold both kinds: in `tickets.yml`,
status, sequencing and dependencies are living, and evidence and review
fields are records.

**R3. Closed vocabularies, only where the guard checks.**
- Record header states: `draft`, `under review`, `accepted`,
  `amended <date>`, `working`, `consolidated` (with the receiving rule
  group), `superseded` or `superseded in part` (with the replacing
  section).
- Pipeline row states, each defined once in `rfc/README.md`: `due`,
  `active`, `paused`, `obligations open`, `parked`, `closed`.
- Bridge row states: `pending`, `consolidated, awaiting closeout`.
- Verdicts: Type 1 `PASS`, `PASS_AFTER_PATCHES`, `CHANGES_REQUIRED`,
  `NEEDS_TYPE_2`; Type 2 `PROCEED`, `REVISE_SEED`, `REJECT`.

Harmonizing `tickets.yml` status words is sweep work, not a rule here.

**R4. Stable addresses for rule groups.** `contracts.md` gains one H3
heading or explicit id per group of related rules, not one per bullet.
The present-tense pass already scheduled (`macro_plan.md` line 840) adds
them. Supersession tables, back-links and claim sources cite group
addresses.

**R5. Supersession.**
1. Text that changes accepted text carries a table: target artifact,
   address, disposition (`superseded`, `amended`, `unchanged`) and
   replacing section. When the change is broad, a census of the affected
   rule generates the table, and the final review checks the table
   against the census.
2. On acceptance, each target gets a header line naming the change and
   one marker at each affected heading. The bridge gains its row, and each
   affected contract group gains the back-link that `contracts.md` lines
   9-13 already require. The implementing commit rewrites the group and
   removes the back-link.
3. Whether two rules are equal is a bounded human reconciliation; a word
   match never decides it. The scheduled clause comparison (`macro_plan.md`
   line 840) is its first instance.
4. A removed heading, row or anchor that has inbound links leaves a
   redirect stub. Superseded versions stay in place under their header.
5. An accepted obligation stays until a ticket owns it or the maintainer
   drops it (`rfc_cycle.md` lines 172-180 and 209-214).

**R6. The bridge.** The guard checks the triangle: synthesis header,
bridge row and contract back-link. Stale rows are reconciled before
pending links are added. The bridge stays a hand-kept index until one
declared source of section mappings exists; none is proposed here.

**R7. Claims.** A new or edited claim cites a rule-group address or an
operative synthesis section in `source`, in addition to any ticket. The
guard reports the 169 ticket-only claims; there is no backfill.

**R8. Evidence (D4 restated).** Ticket evidence is, per acceptance item,
a pointer to its record plus a one-line result. The record carries D4's
fields: input identity, environment, commit, command, result, clock
(synthesis v2 lines 110-115). Reviewed commit ranges are evidence and
stay. Decision-changing findings and rejection reasons stay durable, in
one place (Section 6, M2). Review arithmetic appears once, at cut close.

**R9. Pilots.** A pilot names its exit trigger, a reassessment owner and
its possible dispositions. The guard reports a pilot past its trigger.

## 4. The Guard

The census grows into a check tool with a report mode and a check mode.
Its scope is the governance scope above: living documents and
current-release records.

- **Baseline.** Known old defects are baselined by entry (file, line,
  target), not by directory, because historical directories still hold
  operative rules. The baseline only shrinks; adding an entry needs a
  maintainer reason.
- **It fails on:**
  - a broken link or anchor not in the baseline;
  - a new link to a baselined broken target;
  - a duplicate explicit id, or a slug collision that a link uses;
  - a record header state outside R3;
  - a supersession-table entry without a target notice, or a notice
    without a table entry;
  - a triangle mismatch on a bridge row not marked for reconciliation.
- **It passes** when there are zero unbaselined findings. Passing proves
  that the documents are consistent, not that judgment was exercised.
  Synthesis v2 lines 130-136 rejected checks on process form as evidence
  of independence, among them a guard per review. This guard checks the
  document graph, not reviews.
- **Size and claim-source findings** stay reports; D4 rejected test caps.
- **Control plane.**
  - The failing check is one registered block with a structural-detector
    oracle and mutation witnesses: a broken link inserted, and a target
    notice removed.
  - It skips outside a source tree, as `test-project-metadata.R` lines
    73-75 do.
  - Its profile follows measured cost. At about 6 s the full census does
    not fit the fast budget, so it runs in the review profile unless the
    failing subset measures small enough for fast.
- **Review.** It defines a claim, so its first version gets a Type 1
  review (synthesis v2 D6).

## 5. First Application: the v11 Amendment

The history-wave register will write one amendment to historical-
projection v11 (`rfc/README.md` line 31). If this RFC is accepted before
that amendment is written, the amendment is the first supersession
carrier under R5. If not, it is an explicit transition exception: written
under today's rules, it receives its table and notices when the sweep
applies these rules. Either way it is not left unmarked.

## 6. Decisions for the Maintainer

**M1. The review gate.**
- **Evidence.**
  - 81 invocations over 98 completed tickets, 0.827, across 13 cuts.
  - Recorded per-cut ratios: 8/12, 8/11, 2/4, 3/1, 4/2, 6/9, 3/4, 2/2, 5/4,
    5/4, 8/17, 21/26, 6/3. Eleven exceed 0.5.
  - Cut 12's 26 counts a dropped ticket; 25 completed.
  - The v0.2.0.2 pilot measured 11 / 31 = 0.355 and was promoted with a
    reassessment that never ran.
  - D8 preregistered the ratio per packet; v0.2.2 records it per cut and
    per workstream.
- **Caveats.** Invocations are not classified consistently (Cuts 9-10
  include agent reviews). Missing evidence is not separated from zero
  cost. Outcome-changing findings and maintainer effort were not measured.
- **Options.**
  - (a) Keep 0.5, measured per packet at closeout.
  - (b) Record the ratio without a gate, and add an escalation rule: a
    third correction round on one workstream goes to the maintainer.
  - (c) Re-measure consistently at v0.2.2 closeout and decide then.
- **Recommendation: (b) now, with (c) as the scheduled reassessment.** The
  owner is the maintainer, the trigger is v0.2.2 closeout, and the
  disposition (keep, revise or drop) is recorded in `rfc_cycle.md`.

**M2. Where consequential review findings live.**
- **Evidence.** The packet holds three cut-review files (`cut_review_7`,
  `_9` and `_13`). Close-review findings otherwise live only in
  `tickets.yml` review fields, 4,144 words in total.
- **Options.**
  - (a) A review that returns findings writes a file; a `PASS` is one line
    in `tickets.yml`.
  - (b) Findings stay in the review field, one place, and a file is
    optional.
- **Recommendation: (a).** Findings are what "changed an outcome" counts,
  and a field read through YAML is hard to cite. It is a new obligation,
  not D4 restored.

## 7. Application and Sequence

On acceptance:
- the rules go into `rfc_cycle.md`, the design index and `AGENTS.md`;
- the census becomes the guard in report mode, and its check mode follows
  after one cut;
- the governance sweep already scheduled after the one-execution-mode
  probe (`macro_plan.md` lines 792-860) applies the rules;
- no closed ticket is rewritten.

This RFC is accepted before the execution-core consolidation RFC opens,
and Section 5 covers anything that supersedes earlier.

## 8. Rejected

- Header-only records. Accepted practice appends dated amendments.
- A ban on rules defined by reference to a seed or review. It would
  withdraw an accepted incorporation; R1 requires traceability instead.
- An anchor on every contract bullet. Group addresses localize enough.
- Directory-wide allowlists for historical links. They would hide
  operative rules.
- Deciding the gate in synthesis. It belongs to the maintainer (D8).
- Backfilling 169 claim sources now. The guard reports them; edits fix
  them.
- Moving superseded syntheses to an archive directory. It breaks inbound
  links.

## 9. Sequence

Seed v1, response, response review, this seed v2, maintainer decisions
on M1 and M2, synthesis by an author other than this seed's, Type 1
final review, maintainer acceptance, then application in the sweep.
