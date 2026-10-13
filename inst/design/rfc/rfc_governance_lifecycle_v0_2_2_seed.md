# RFC Seed: Authority And Lifecycle Of Governance Documents

- Status: Seed v1; Type 2 response is next
- Author: Claude, seed v1 author, at the maintainer's request
- Date: 2026-10-13
- Window: none; this changes process and design documents, not package code
- Baseline reviewed: `93f4204c` (v0.2.2)
- Skipped stage: research input. The evidence is a measured structural audit
  of the governance files (summarized in Section 2); prior art is the
  accepted governance synthesis v2 of 2026-09-21.

## 1. Question and Boundary

How should ledgr's governance documents state their authority, record their
lifecycle and supersede each other, so that a reader or agent finds the
current binding answer quickly and correctly, and so that the documents do
not decay as work accumulates?

The question arose from supersession: the planned execution-core
consolidation (dense as a special case of availability) will supersede
contract clauses, sections of about 18 syntheses and many claims, and ledgr
has no procedure for that. An audit then showed that supersession cannot be
defined alone, because there is no shared lifecycle vocabulary and no single
holder of several facts it would need to update.

This seed is also the pilot review that governance synthesis v2 D8 requires.
D8 bound its model "as a pilot for the next implementation packet only",
preregistered one gate (at most 0.5 review invocations per completed ticket)
and said "the model is revised or abandoned if it misses the gate". The
pilot review never ran, and the model has continued through v0.2.2.

Out of scope: the content of any contract rule or accepted decision; the RFC
cycle's stage structure, except where this seed changes it; the test control
plane's design, except the claim-source rule in Section 5; package code.

## 2. Evidence

A read-only audit at `9319139a` resolved 591 relative links and anchors,
parsed `tickets.yml` and `tests/claims.yml`, and measured git growth. It
confirmed the six issues already known (roadmap table, macro-plan amendment
log, horizon never pruned, `decisions.md` exits, stale synthesis headers,
release history in `contracts.md`) and found these structural problems:

| # | Problem | Measured evidence |
| --- | --- | --- |
| A | No single holder of the current order | 7 or more files claim sequencing authority; five statements of cut progress give three answers; `inst/design/README.md` item 3 says the roadmap binds dependency order, while the roadmap defers to the macro plan |
| B | Living documents are amended by appending | macro plan 3.3k to 7.1k words since 2026-10-04, 12 dated amendments, the remaining order restated 5 times; section 5 still contradicts a later amendment on context-frame retirement |
| C | Cross-document amendments are invisible at the target | `contracts.md` (lines 9-13) requires an `Accepted change pending` link for each pending clause; 14 are missing across 3 `decisions.md` rows; the snapshot-verification synthesis carries no notice of the legacy-removal amendment |
| D | Status headers decay and use no shared vocabulary | 43 synthesis files, about 13 status forms; 3 still say "pending final review" after their final reviews, 2 say "draft", 1 has none, and the RFC pipeline cites two of them as accepted sources; 11 point-in-time synthesis versions sit side by side |
| E | Exit rules are applied early, late or not at all | one `decisions.md` row left early, several stay after consolidation; removed pipeline rows delete their anchors (6 broken inbound links) |
| F | Status words mean different things in different files | "accepted" is design-binding for syntheses, opened for cuts, done for workstreams; the pipeline uses "Active" for a paused cycle; 12 review verdict tokens are in use and only `NEEDS_TYPE_2` is defined |
| G | Process documents disagree on their own force | `rfc_cycle.md` line 3 calls itself "not a binding methodology"; the design index and `AGENTS.md` treat it as binding; the optimization manual disclaims authority that `AGENTS.md` and `tickets.yml` give it |
| H | The review gate is ceremony | the 0.5 gate was missed in at least 7 of 13 v0.2.2 cuts, each "recorded rather than padded"; a three-ticket cut needs 2/3 before any correction round; the ratio arithmetic is restated 54 times in `tickets.yml` |
| I | Evidence essays returned despite D4 | `tickets.yml` grew from 17,255 to 74,254 words since 2026-10-04; evidence fields are about 40 percent of it, with about 191 commit hashes; the packet README is 90 percent per-cut narrative and stops at Cut 9 |
| J | Claims cite tickets, not standing rules | of 252 claims, 19 cite a contract heading alone and 166 cite only a ticket or cut, so superseding a clause cannot find the tests that protect it |
| K | Governance rules are prose-only | apart from two `AGENTS.md` section names and three contract headings, no test or tool checks links, back-links, status values or size rules |

The audit also listed seven contradictions between files that affect what
binds (next step, context-frame scope, legacy readability, whether
`rfc_cycle.md` binds, the test-oracle rule, the feature-map status, the
optimization manual's force). They are symptoms of A, B, C and G.

## 3. Proposal in One View

1. **Two kinds of document.** A *record* (seed, response, review, synthesis,
   closeout, spike record) is never rewritten after acceptance; only its
   status header changes. A *living document* (contracts, the macro plan's
   remaining order, the roadmap, `decisions.md`, the RFC pipeline,
   `AGENTS.md`, the indexes) is edited in place and keeps a short dated
   change line, never an append-only narrative.
2. **One authority ladder,** stated once in the design index, with each fact
   held by exactly one file and linked from the others.
3. **One lifecycle vocabulary** for every artifact type and one set of review
   verdicts.
4. **Supersession rules:** a supersession table in the superseding synthesis,
   notices at every target, anchors that survive removal, and claims that
   cite the rules they protect.
5. **Mechanical guards** for the rules above, report-only first.
6. **Pilot review outcome:** replace the 0.5 gate with an escalation rule,
   restore D4's evidence form, and state the force of each process document.

## 4. Authority, Document Kinds and Vocabulary

### 4.1 One fact, one holder

| Fact | Sole holder | Others |
| --- | --- | --- |
| Current package behaviour | `contracts.md` | link by heading |
| Accepted design not yet in contracts | the operative synthesis section, indexed by `decisions.md` | link |
| Executable work, its state and order | `tickets.yml` | do not restate state |
| Order of work not yet cut into tickets | one "Remaining order" section of the macro plan | link |
| Release sequence and release goals | the roadmap, releases only | link |
| Parked, non-binding ideas | `horizon.md` | never cited as authority; committed scope leaves it |
| RFC pipeline state | `rfc/README.md` | link |
| Process | `rfc_cycle.md`, `spike_protocol.md`, the release playbook, `AGENTS.md` | binding for the process each governs |

Each governance file opens with one role line naming which rows of this
table it holds. A statement of a fact outside a file's role is replaced by a
link. The packet README becomes an entry point with a current-state pointer,
not a status ledger.

### 4.2 Lifecycle vocabulary

- **Records (RFC artifacts):** `draft`, `under review`, `accepted`,
  `consolidated` (the rule now lives in a standing document named in the
  header), `superseded` or `superseded in part` (by a named section). The
  header format is fixed: `**Status:** <state> (<date>)`, then one line
  naming the source of any later change.
- **RFC pipeline rows:** `due` (trigger fired, no artifact yet), `active`
  (a stage is running), `paused` (named resume point), `obligations open`,
  `parked` (trigger not fired), `closed`. Each state has one definition.
- **`tickets.yml`:** cuts `draft`, `open`, `closed`; workstreams and tickets
  `open`, `review_pending`, `complete`, `dropped`. "Accepted" is reserved for
  design acceptance and the maintainer's acceptance of a workstream, which
  sets `complete`.
- **`decisions.md` rows:** `pending` then `consolidated, awaiting closeout`,
  then removed at release closeout with the receiving heading cited. This
  fixes the false "Missing consolidation" column without breaking the exit
  rule.
- **Review verdicts:** Type 1 `PASS`, `PASS_AFTER_PATCHES`,
  `CHANGES_REQUIRED`, `NEEDS_TYPE_2`; Type 2 responses `PROCEED`,
  `REVISE_SEED`, `REJECT`. Other tokens are retired.

### 4.3 Force of process documents

`rfc_cycle.md` drops its "reference card, not binding" status line and
binds the process it governs, as the design index already says. A manual
states in its header whether it is guidance or binding review criteria; the
optimization manual's seven shapes are binding review criteria, as
`AGENTS.md` and `tickets.yml` already treat them. Every pilot names its exit
trigger and its decision owner; a pilot that passes its trigger without a
decision is flagged by the guard in Section 6.

## 5. Supersession Rules

1. **Supersession table.** A synthesis or maintainer amendment that changes
   accepted text carries a table: target artifact, section anchor,
   disposition (`superseded`, `amended`, `unchanged`), replacing section.
   When the change is broad, the table is generated from a mechanical
   census of the affected rule, as the legacy-removal inventory was, and
   the final review checks the table against the census.
2. **Notices at acceptance, not at implementation.** On acceptance, every
   target record gets a status-header line ("superseded in part by X Section
   n; applied by cut Y" or "pending application") and a one-line marker at
   each affected heading. Bodies are not rewritten.
3. **Contracts.** The existing `Accepted change pending` back-link is added
   on acceptance for each affected clause; the implementing commit rewrites
   the clause and removes the link, as `contracts.md` already requires.
4. **Living documents** are corrected in place when a later decision changes
   them, with one dated change line naming the source. No section of a
   living document may be contradicted by a later section of the same file.
5. **Anchors survive.** Removing a heading, row or anchor that has inbound
   links leaves a redirect stub, as `horizon.md` already does.
6. **Superseded versions** of a synthesis stay in place, so links keep
   working, but carry the mandatory superseded header.
7. **Claims cite standing rules.** A new or edited claim names at least one
   contract heading or operative synthesis section in `source`, in addition
   to any ticket, so a supersession census finds the claims of a clause. The
   166 ticket-only claims are backfilled when touched and listed by the
   guard until then.

## 6. Mechanical Guards

One report-mode tool, `tools/check-governance.R`, built on the census tool
the hygiene workstream already added, checks:

- every relative link and anchor under `inst/design` resolves;
- every synthesis has a status header with a state from Section 4.2, and
  every pipeline row, `decisions.md` row and `tickets.yml` status uses the
  defined vocabulary;
- every supersession-table entry has a matching target notice, and no notice
  lacks a table entry;
- `decisions.md` pending rows and `contracts.md` back-links agree;
- the size rules that are rules, not caps (`AGENTS.md` under 150 lines,
  roadmap rows releases only);
- claims without a standing-rule source and pilots past their trigger, as
  reports.

It runs report-only for one cut and then turns its first checks (links,
vocabulary, supersession pairs, back-links) into failing blocks of the
documentation-contract tests. D4 rejected hard line caps enforced by test,
so size findings stay reports.

## 7. Pilot Review: Gate, Evidence and Accounting

**The 0.5 gate is replaced.** It cannot be met at ledgr's cut size: a
three-ticket cut reaches 0.667 with its cut review and one close review. The
correction rounds it penalizes are the ones that found the defects that
mattered this release (a split-store regression, two tests bent to pass, a
slowdown hidden by deleted tests). D8 already rejected yield quotas because
they reward manufactured findings; a ratio gate that is almost always
breached rewards nothing. In its place:

- **Escalation rule.** A third correction round on the same workstream stops
  and goes to the maintainer, who decides whether the ticket, the
  implementation or the brief is wrong.
- **One recorded measure, no gate.** Per review: findings, and whether each
  changed an outcome. D8 already lists this; it becomes the main signal.
- **Accounting once.** Review counts are recorded at cut close only, not in
  every ticket.

**D4's evidence form is restored.**

- Ticket evidence is, per acceptance item, a pointer to the record plus a
  one-line result.
- Numbers live in the record under `dev/bench/` or the test evidence, not in
  prose.
- A review entry is its verdict, a link to the review file and one line on
  what changed.
- Commit hashes appear only where they identify an evidence record.

Product provenance is unchanged: ledgr stays strict about its own records.
What leaves is narrative about the build process. Size findings are
reported by the guard; they are not capped.

## 8. Application and Sequence

This RFC changes no package behaviour. On acceptance:

1. `rfc_cycle.md`, the design index, `AGENTS.md` and the file role lines are
   updated, and the guard tool is added in report mode.
2. The post-probe governance sweep, already scheduled in the macro plan,
   applies the rules: roadmap rewrite, remaining-order section, horizon
   scan, `decisions.md` exits, status headers, contracts present-tense pass,
   packet README trim, evidence-form cleanup of open tickets.
3. Closed tickets are not rewritten. Their evidence is a record.
4. This RFC is accepted before the execution-core consolidation RFC opens,
   so that RFC is the first to carry a supersession table.

## 9. Alternatives Considered

- **Supersession rules alone.** Rejected: supersession needs states,
  holders and notices that do not exist yet.
- **Keep the 0.5 gate and cut larger tickets.** Rejected: it trades review
  cost for coarser claims, which D3's workstream grouping already balances,
  and it still penalizes the rounds that find defects.
- **Move superseded syntheses to an archive directory.** Rejected for now:
  it breaks inbound links; the mandatory header achieves discoverability.
- **Hard size caps on `tickets.yml` fields.** Rejected, as D4 already did.
- **Backfill all 252 claim sources now.** Rejected: high cost for little
  immediate value; the guard lists them and edits backfill them.

## 10. Questions for the Response

1. Is the record versus living-document split right, and is any document
   both?
2. Is the vocabulary minimal and complete? Does `consolidated` on a
   synthesis make the `decisions.md` bridge redundant?
3. Is the escalation rule a sufficient replacement for the 0.5 gate, or does
   removing the ratio lose a cost signal the maintainer needs?
4. Does the evidence form lose information that reviewers rely on?
5. Is report-then-fail the right path for the guard, and which checks
   should fail first?
6. What did the audit miss, and which of its findings are wrong?

## 11. Sequence

Seed v1, Type 2 response by Codex, response review, synthesis by an author
other than this seed's, Type 1 final review, maintainer acceptance. The
application in Section 8 follows the one-execution-mode probe.
