# RFC Seed v2: Post-v0.2.0.1 Governance Review

**Status:** Rejected on direction, 2026-09-21, by the type-2 review and
the maintainer. Retained as history. A replacement seed with a different
model follows; this file is not revised.

**Release destination:** None. This cycle changes process documents, not
package code.

**Author:** Claude, returning after the Codex response and the seed author's
response review. Bias is stated in Section 8.

**Next step:** a different author writes the synthesis. This seed proposes no
charter and edits no process document.

## 1. Question

How should ledgr's build process stay clear, safe, and strict against agent
drift and hallucination while spending far fewer tokens than the v0.2.0.1
cycle did, without weakening the six non-negotiables the roadmap names?

The roadmap fixes the scope: reduce process cost and entropy, prefer
executable checks over narrative, define proportionate routes, settle
implementation authority, reopen no v0.2.0.1 product decision, rewrite no
historical record (`ledgr_roadmap.md`, "After v0.2.0.1: Governance Review").

## 2. What The Cycle Established

Every number is a count over repository artifacts at `af1a016`, or a horizon
entry that records a measurement. Counts corrected by the response are
marked.

### 2.1 The decision cycle held

Horizon, seed, adversarial response, synthesis, binding spec: every product
decision that went through it came out sound. No batch shipped outside its
ticket. Spec, two amendments, and ticket cut were each independently reviewed
before implementation (`batch_plan.md:43-84`). This seed proposes no change
to that cycle. It is the boundary review, and it works.

### 2.2 The implementation phase copied the decision cycle's shape

The packet holds 7,695 lines of Markdown in 24 files (v1 said 25). Tickets
are 1,687 lines for 26 tickets; the batch plan is 612. Fourteen batch
evidence documents run 45 to 264 lines. The Stage O checker that verifies
the final records is 148 lines of R
(`dev/bench/v0_2_0_1_stage_o/check_stage_o_records.R`); the document around
it is 264 lines and carries a "Peer-record attempt history" section
(`batch14-final-evidence.md:223`).

The batch plan reads "A batch is the independent review unit" and "stop for
independent review before commit unless the maintainer directs otherwise"
(`batch_plan.md:14,32`). Sixteen batches; fifteen "Complete After Review".

The spike protocol already states the principle: "Provenance lives in the
product. Git is the ledger for the build" (`spike_protocol.md`, section 5).
It binds spikes. Nothing extended it to batches, evidence, or closeouts.

### 2.3 What independent review found, against what it cost

Reviews were returned inline and are not durable; 18 packet files assert
that review passed and none records what it cost. The response counted from
batch plan, amendment revision records, packet README, and evidence status
sections: at least 26 review invocations, and 14 events that changed
requirements, code, tests, harnesses, or evidence. This seed adopts that
method and corrects v1's five-of-twenty, which counted only `batch_plan.md`
re-review lines. Three of the 14 are soft: two are "non-blocking"
observations carried into the next preflight (`batch_plan.md:257-259,
294-296`), and one harness asymmetry "cannot mask a difference" and needed
no rerun (`batch12:16-19`). Roughly eleven rejected a record, forced a
rerun, or replaced a guard.

The reviews that changed outcomes did so by running something. Batch 13 is
the leading case: both arms hashed a `PEER_` fixture instead of the frozen
Stage L one, so every executable gate would have passed; source review
compared the stored hash, rejected the record, forced eight reruns, and
left a fail-closed refusal (`batch13:13-17`; `765e467`). None of the
others came from reading narrative either.

### 2.4 Three boundaries that were never reviewed

Each is a question about what a measurement means. None had a ticket, so
none had a review.

- The peer harness measured a workflow with nine internal calls and no public
  API call (horizon 2026-09-17; corrected by LDG-2741).
- The peer strategy reads `ctx$features_wide`; the quickstart teaches
  `ctx$features()`. The cycle's largest performance defect lived in the
  documented idiom, invisible to the benchmark by construction (horizon
  2026-09-18 per-pulse context entry).
- The availability prerequisite preregistered a 0.20 ratio, then tested a
  candidate that compared instants instead of deduplicating. A proven-exact
  448x fix was shelved by the `NEITHER` rule (`probe_findings.md` under
  `dev/spikes/v0_2_0_1_availability_timestamp_prerequisite/`).

The decision cycle handles ideas someone parked. It cannot handle assumptions
no one noticed were assumptions.

### 2.5 Bad-but-correct implementations have no phase

Every performance finding since the release passed its tests: alias-map
identity work discarded 362,880 times per sweep, a `replicate()` of a
constant schema, a character-indexed matrix fill, a public availability read
at 63 times the fold it audits, nine FIFO replay loops, twenty-seven
duplicate helper pairs (horizon 2026-09-18 and 2026-09-19). Correct, green,
and bad.

The style manual names the shape: shape 5 is "work computed and discarded,
or recomputed on every call" (`optimization_coding_style.qmd:66`). Its
maintainer checklist asks "Is any value computed on a hot path never read on
the common branch?" (`:448`). That is the alias-map defect, verbatim. The
only test referencing the manual asserts six phrases
(`test-documentation-contracts.R:3444-3451`; v1 wrongly said existence);
none is the checklist question. It was written down and nothing ran it.

Ticket review sees one diff. Tests see correctness. Nothing sees the codebase.

## 3. Existing Authority This Seed Builds On

`spike_protocol.md` section 5 and its budget table; `rfc_cycle.md` "Final
review scope" and its prompt notes ("Code citations expected"); the style
manual's shapes and checklist; twelve test files with executable source
guards, led by `test-availability-production-retirement.R`. The guard
pattern exists; it is applied to retirement, not to quality.

## 4. Proposed Direction

### 4.1 Name the boundary and reuse the classifier

A boundary is a point where correctness depends on a decision no test can
encode with an oracle that exists independently of the decision. "Does this
need an RFC?" already routes horizon entries to seeds and is that
classifier. Consult it after the spec binds, not only before.

### 4.2 Remove narrative; keep review where a boundary exists

What goes, each replaced by something executable:

- Batch evidence documents. The response author, who wrote them, found "no
  evidence that the documents themselves discovered defects." A batch's
  evidence is its tests, its commit, and any record prefix it produced. A
  record is a CSV plus a checker script plus a README of at most 40 lines,
  not a document.
- Attempt histories, abandoned-prefix narratives, citation-correction
  disclosures, and "this document does not authorize" sentences. Git holds
  the history. A record that names its commit needs nothing else.
- Ticket Markdown and `tickets.yml` as two sources. One source; the
  agreement check disappears with the duplication.

What stays, answering the response's open question. Independent review is
retained at a material implementation boundary, defined as a batch that:

- (a) freezes, or measures against, a frozen oracle or fixture;
- (b) produces or replaces accepted empirical evidence;
- (c) changes accounting, identity, hash, schema, or persistence behavior; or
- (d) changes a public contract.

At such a boundary the reviewer's mandate is to run the identity or parity
check, not read the narrative, and the review leaves an executable guard
behind wherever one is possible. Batch 13 is the pattern: the review
compared a hash and left a fail-closed refusal. Batches outside (a) through
(d) ship on tests plus Section 4.5. Documentation-only and status-only
batches are never reviewed.

### 4.3 Evidence is a record, a command, and a commit

Every performance or behavior claim in a closeout names a record prefix, the
one command that reproduces it, and the commit it ran at. The release-gate
reviewer runs the command. A claim without a command is prose, not evidence,
and does not enter the closeout.

### 4.4 Add the quality phase that does not exist

Once per release, executable, no reviewer judgment: profile the public
pipeline end to end (snapshot from data frame and CSV, experiment, serial
and parallel sweep, promote, every public results read); run a
normalized-body duplication scan across `R/`; run a complexity census for
the seven shapes; run reachability guards for known-bad patterns, the first
being that no `digest`, `canonical_json`, or hash helper is reachable from
the fold's per-pulse path.

Threshold, adopted from the response: 5.0 percent of captured samples in the
named profiled stage. Crossing it creates a finding to classify, not a
ticket or a claim. It catches both the alias map at 56.73 percent and the
`replicate()` at 6.39 percent. The output is a table committed as a
release record. The style manual's checklist becomes the census
specification instead of a reading list.

### 4.5 One rule for every batch on a hot path

A batch touching anything reachable from the pulse loop, the seal path, or a
public results read ships with a before-and-after profile of that path.
Three surfaces, one command, no narrative; it applies to every batch.

### 4.6 Three guards for assumptions nobody parks

- The peer benchmark measures the idiom the documentation teaches, or
  carries a row that does; a rule in the benchmark methodology manual.
- A spike probe names, in one sentence, why its candidate is the cheapest
  mechanism that could satisfy the threshold. The response reviewer's first
  question is whether a cheaper one exists. A probe may return
  `WRONG_CANDIDATE` without burning its preregistered threshold.
- A boundary review leaves a test behind so the question is never a boundary
  again; models: the public-workflow boundary test, Batch 13's hash refusal.

### 4.7 Size budgets scale with authority; over budget is routing

The rule. An artifact's budget is set by what it binds, not by what past
artifacts measured: horizon binds nothing and gets the smallest cap; a
closeout binds a release; a seed binds an RFC and has 300. Excess over
budget is narrative, which is deleted, or evidence, which moves to a linked
file — a record CSV, a `dev/bench/notes` file, a spike findings file — with
the artifact keeping a pointer and one paragraph. Stop-and-talk applies
only when neither move is possible; that is the smell the budget detects.

Rows added to the spike protocol table: horizon entry 40 lines; release
closeout 120 lines; empirical checkpoint a record CSV, checker script, and
README of at most 40 lines, not a document; inline review one page,
findings only. A passed check is silent.

The response's observed maxima and v1's median both derive the number from
this cycle's own artifacts; the response review (finding 5) makes the
circularity argument and is not repeated here. The 2026-09-17 durable-path
entry already follows this rule: 33 lines pointing to a 598-line note.

### 4.8 The asymmetry, written down

The package is exact about provenance, identity, and evidence. The process
that builds it is not, because Git already is. This sentence goes into
`AGENTS.md` so the instinct that produced Section 2.2 has a place to stop.

## 5. What This Does Not Change

The roadmap's non-negotiables stay binding: independent review at material
design and correctness boundaries; immutable or explicitly superseded
empirical evidence; visible failures, corrections, and abandoned approaches;
scope containment and explicit maintainer acceptance; executable semantic and
persistence invariants where practical; separate, honestly labelled cold,
warm, and peer clocks.

Section 4.2 moves "visible failures" from prose to Git and removes review
only where no boundary exists. Section 4.6 strengthens the clocks. The RFC
cycle, the probe-first rule, and maintainer acceptance are untouched.

## 6. Test-Suite Audit Workstream

The suite is 134 files and 40,067 lines; `test-documentation-contracts.R`
is 4,264. The audit is executable: which installed-package skip guards
suppress behavioral assertions beyond their source check (Batch 15 found
one); which tests assert documentation strings rather than behavior; what
CRAN's constraints require of skip, timing, and fixture patterns; which of
the twelve source guards generalize into the Section 4.4 census. Output: a
table of files, finding class, and reproducing command. No rewrite is
proposed; that is ticket work.

## 7. Non-Goals

No v0.2.0.1 product decision is reopened; no historical RFC, spike, review,
or closeout is rewritten; the RFC cycle stages, role rotation, and spike
protocol are untouched; no prompt template library, no release assignment,
no tooling beyond R scripts and testthat guards the repository already runs.

## 8. Open Decisions For The Synthesis

Settled by the response and not reopened: the review count, the doc-test
claim, the file count, the 5 percent threshold. Remaining:

1. **Section 4.2's boundary definition.** Applied to v0.2.0.1 it removes
   review from Batches 0, 2, 3, 5, 7, and 10. By the response's list, two
   hard corrections came from that set: Batch 3's append-failure witness and
   Batch 7's phase labels. The synthesis decides whether they make (b) too
   narrow.
2. **Section 4.7's rule.** The response may contest the authority basis or
   the rows. The question is whether routing preserves the value the
   response attributed to the long entries, or loses it.
3. **This author's bias, both points the response found.** Section 4.4
   promotes this author's profiling method; Section 4.2 keeps review at the
   gate this author reviewed; Section 4.7 would route this author's own
   entries. Stated for the maintainer to weigh.
4. **The response author's bias.** Conceded in the response: no defense of
   batch evidence documents from their effort. The synthesis should hold the
   same line.

## 9. Evidence And Authority

`ledgr_roadmap.md` (governance section); `spike_protocol.md`;
`rfc_cycle.md`; the v0.2.0.1 packet's `batch_plan.md`,
`batch14-final-evidence.md`, and `v0_2_0_1_release_closeout.md`;
`optimization_coding_style.qmd`; horizon entries 2026-09-17 through
2026-09-20; `rfc_governance_review_post_v0_2_0_1_response.md` and
`_response_review.md`; `test-availability-production-retirement.R` and
`test-peer-benchmark-boundary.R` as the executable-guard pattern.

## Revision History

- 2026-09-20 — Seed v1, Claude. Written after the v0.2.0.1 release and
  before any response.
- 2026-09-20 — Seed v2, Claude, after the response and response review:
  count method and three corrections adopted; Section 4.2 split; 5 percent
  threshold; authority-scaled size rule in Section 4.7.
