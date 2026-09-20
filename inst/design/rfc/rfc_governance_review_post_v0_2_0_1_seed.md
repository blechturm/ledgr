# RFC Seed: Post-v0.2.0.1 Governance Review

**Status:** Seed v1; non-binding. Input to the adversarial response stage.

**Release destination:** None. This cycle changes process documents, not
package code, and assigns no release.

**Author:** Claude (Opus, then Fable 5.1 for this artifact), after acting as
independent reviewer for Batches 9 through 15 and as author of most of the
2026-09-17 to 2026-09-20 horizon entries this seed cites. That bias is stated
in Section 8 so the response can attack it.

**Next step:** a different author writes the response. This seed proposes no
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

Every number below is a count over artifacts in this repository at the
`v0.2.0.2` branch head, or a horizon entry that records a measurement.

### 2.1 The decision cycle held

Horizon, seed, adversarial response, synthesis, binding spec: every product
decision that went through it came out sound. No batch shipped outside its
ticket. Spec, two amendments, and ticket cut were each independently reviewed
before implementation (`ledgr_v0_2_0_1_spec_packet/batch_plan.md:43-84`).
This seed proposes no change to that cycle. It is the boundary review, and it
works.

### 2.2 The implementation phase copied the decision cycle's shape

The packet holds 7,695 lines of Markdown in 25 files. Tickets alone are
1,687 lines for 26 tickets; the batch plan is 612. Fourteen batch evidence
documents range from 45 to 264 lines. The Stage O checker that actually
verifies the final records is 148 lines of R
(`dev/bench/v0_2_0_1_stage_o/check_stage_o_records.R`); the evidence document
wrapped around it is 264 lines and carries a section titled "Peer-record
attempt history" (`batch14-final-evidence.md:223`) documenting three
abandoned benchmark prefixes. The release closeout separately narrates a
citation-only SHA correction where the short commit had been correct.

The batch plan's review protocol reads: "A batch is the independent review
unit" and "stop for independent review before commit unless the maintainer
directs otherwise" (`batch_plan.md:14,32`). Sixteen batches ran under that
rule. Fifteen closed "Complete After Review". The cycle produced 45 commits.

The spike protocol already states the principle this violates: "Provenance
lives in the product. Git is the ledger for the build"
(`inst/design/spike_protocol.md`, section 5). It binds spikes. Nothing
extended it to batches, evidence, or closeouts.

### 2.3 What independent review found, against what it cost

Reviews were returned inline and are not durable: the packet directory
contains no review artifact, while 18 of its Markdown files assert that
independent review passed. There is therefore no record of what any review
cost or found, except where a correction followed. The batch plan records
those: Batch 1 needed a re-review after an option-containment correction
(`bdcab66`), Batch 4 a re-review with one patch, the timestamp amendment a
review plus focused re-review, Batch 7 a correction review, and the ticket cut
"an additional Claude review" (`batch_plan.md:44,73,120,153,370`). Five
corrections across roughly twenty review invocations.

The reviews that changed outcomes did so by measuring: a quadratic mutant
proving Batch 9's counters could not fail, a no-dedup mutant for Batch 13, a
CSV comparison exposing a 35 to 45 percent host slowdown in the Batch 14
availability record, a block-scoped skip guard in Batch 15 suppressing three
parity assertions. None of those findings came from reading narrative. The
six-section review format was the vehicle; execution was the mechanism.

### 2.4 Three boundaries that were never reviewed

Each is a question about what a measurement means. None had a ticket, so
none had a review.

- The peer harness measured a workflow with nine internal calls and no public
  API call, which production never takes (horizon 2026-09-17 durable-path
  entry; corrected by LDG-2741, `test-peer-benchmark-boundary.R`).
- The peer strategy reads `ctx$features_wide`; the quickstart teaches
  `ctx$features()`. The cycle's largest performance defect lived in the
  documented idiom and was invisible to the benchmark by construction
  (horizon 2026-09-18 per-pulse context entry).
- The availability prerequisite preregistered a 0.20 admission ratio, then
  tested a candidate that compared instants instead of deduplicating. The
  threshold was sound; the candidate attacked the wrong layer. A proven-exact
  448x observation-time fix was shelved by the `NEITHER` rule
  (`probe_findings.md` under
  `dev/spikes/v0_2_0_1_availability_timestamp_prerequisite/`).

The decision cycle handles ideas someone parked. It cannot handle assumptions
no one noticed were assumptions.

### 2.5 Bad-but-correct implementations have no phase

Every performance finding since the release passed its tests: alias-map
identity work discarded 362,880 times per sweep, a `replicate()` of a
constant schema, a character-indexed matrix fill, a public availability read
at 63 times the fold it audits, nine FIFO replay loops, twenty-seven
duplicate helper pairs (horizon entries dated 2026-09-18 and 2026-09-19).
Correct, green, and bad.

The style manual already names the shape. Shape 5 is "work computed and
discarded, or recomputed on every call"
(`inst/design/manual/optimization_coding_style.qmd:66`). Its maintainer
checklist asks "Is any value computed on a hot path never read on the common
branch?" (`:448`). That is the alias-map defect, verbatim. The only test that
references the manual checks that the document exists
(`test-documentation-contracts.R`). The question was written down and nothing
ran it.

Ticket review sees one diff. Tests see correctness. Nothing sees the codebase.

## 3. Existing Authority This Seed Builds On

- `spike_protocol.md` section 5: provenance lives in the product.
- `rfc_cycle.md`, "Final review scope": "verification, not design", cites
  line numbers, edits nothing. Already the run-do-not-read rule.
- `rfc_cycle.md`, prompt notes: "Code citations expected. Catches phantom
  claims"; constrain scope against "Codex's tendency to over-bind and
  Claude's tendency to add follow-up obligations".
- `optimization_coding_style.qmd`: seven shapes and the maintainer checklist.
- Twelve test files already carry executable source guards, including
  `test-availability-production-retirement.R` and the Stage L SHA guards.
  The pattern exists; it is applied to retirement, not to quality.

## 4. Proposed Direction

### 4.1 Name the boundary and reuse the classifier

A boundary is a point where correctness depends on a decision no test can
encode with an oracle that exists independently of the decision. The
question "does this need an RFC?" that already routes horizon entries to
seeds is that classifier. Consult it after the spec binds, not only before.
An accepted spec closes the open questions; a batch implementing it has none.

### 4.2 Strip decision-phase ceremony from the implementation phase

Deletions, each replacing a narrative with something executable:

- Batch-level independent review is removed as a default. A batch ships when
  its tests pass and, where Section 4.5 applies, its profile is attached.
  Independent review returns at the release gate only.
- Batch evidence documents are removed. A batch's evidence is its tests, its
  commit, and any record prefix it produced.
- Attempt histories, abandoned-prefix narratives, citation-correction
  disclosures, and "this document does not authorize" sentences are removed
  from evidence and closeouts. Git holds the history. A record that names its
  commit needs nothing else.
- Ticket Markdown and `tickets.yml` are reduced to one source. The cut
  reviewer's job of checking they agree disappears with the duplication.

### 4.3 Evidence is a record, a command, and a commit

Every performance or behavior claim in a closeout names a record prefix, the
one command that reproduces it, and the commit it ran at. The release-gate
reviewer runs the command. A claim without a command is prose, not evidence,
and does not enter the closeout.

### 4.4 Add the quality phase that does not exist

Once per release, executable, no reviewer judgment:

- profile the public pipeline end to end — snapshot from data frame and from
  CSV, experiment, serial and parallel sweep, promote, every public results
  read — and name any function above a fixed share;
- run a normalized-body duplication scan across `R/`;
- run a complexity census for the seven shapes: per-row loops over
  scale-growing inputs, `replicate` over constants, character-indexed matrix
  assignment, named-vector accumulation, per-element formatting;
- run reachability guards for known-bad patterns, the first being that no
  `digest`, `canonical_json`, or hash helper is reachable from the fold's
  per-pulse path.

The output is a table, committed as a release record. Items above threshold
become horizon entries or tickets. The style manual's checklist becomes the
census specification instead of a reading list.

### 4.5 One per-batch rule for hot paths

A batch touching anything reachable from the pulse loop, the seal path, or a
public results read ships with a before-and-after profile of that path. Three
surfaces, one command, no narrative. This is the only batch-level check that
survives Section 4.2, because it is the only one that catches Section 2.5.

### 4.6 Three guards for assumptions nobody parks

- The peer benchmark measures the idiom the documentation teaches, or carries
  a row that does. Written into the benchmark methodology manual as a rule.
- A spike probe names, in one sentence, why its candidate is the cheapest
  mechanism that could satisfy the threshold. The response reviewer's first
  question is whether a cheaper mechanism exists. A probe may return
  `WRONG_CANDIDATE` without burning its preregistered threshold.
- The public-workflow boundary test that now exists is the model: when a
  boundary review finds a question, it tries to leave a test behind so the
  question is never a boundary again.

### 4.7 Size budgets extend to everything an agent writes

Horizon's Open section is 8,006 lines across 121 entries; this author's
entries from the last four days run 129, 88, 75, 73, 50, and 48 lines. The
spike protocol caps a seed at 300 lines and a review report at one page;
nothing caps a horizon entry, an evidence document, or an inline review. Its
table gains rows: horizon entry 40 lines, inline review one page and findings
only, closeout 100 lines. "Verified non-findings" sections are removed; a
passed check is silent. Over budget is a stop-and-talk, as for seeds.

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

Section 4.2 moves "visible failures" from prose to Git and from batch to
release gate. It does not remove it. Section 4.6 strengthens the measurement
clocks. Nothing here touches the RFC cycle, the spike protocol's probe-first
rule, or maintainer acceptance.

## 6. Test-Suite Audit Workstream

The suite is 134 files and 40,067 lines; `test-documentation-contracts.R`
alone is 4,264 lines. The audit is executable and asks:

- which installed-package skip guards suppress behavioral assertions beyond
  the source check they exist for (Batch 15 found one: three parity
  assertions under a block-scoped guard in `test-peer-benchmark-boundary.R`);
- which tests assert documentation strings rather than behavior, and which of
  those would fail if the behavior changed and the string did not;
- what CRAN's check constraints require of the current skip, timing, and
  fixture patterns, per the roadmap's 2026-09-17 CRAN paragraph;
- which of the twelve existing source guards generalize into the Section 4.4
  census, and which are retirement-specific and stay.

Its output is a table of test files, the class of each finding, and a
command that reproduces it. It proposes no test rewrite; that is ticket
work.

## 7. Non-Goals

No v0.2.0.1 product decision is reopened; no historical RFC, spike, review,
or closeout is rewritten; the RFC cycle stages, role rotation, and spike
protocol are untouched; no prompt template library, no release assignment,
no tooling beyond R scripts and testthat guards the repository already runs.

## 8. Open Decisions For The Response

The response should attack these by counting or running, not by opinion.

1. **Section 2.3 claims five corrections across roughly twenty reviews.**
   Count them from the batch plan and the commit log. If more reviews changed
   outcomes than this seed found, batch-level review earned more than the
   seed credits.
2. **Section 4.2 removes batch-level review.** Name one finding from any
   v0.2.0.1 batch review that a passing test suite plus a hot-path profile
   would not have produced. If one exists, the deletion is too broad.
3. **Section 4.4's census thresholds are unset.** Propose the share above
   which a profiled function becomes a finding, and defend it against the
   alias map at 56.73 percent and the `replicate()` at 6.39 percent.
4. **Section 4.7's budgets are guesses.** Measure the entries and closeouts
   that carried real findings and set the caps from those.
5. **This author's bias.** The seed's author wrote the six-section reviews
   and the 129-line horizon entry it cites as over-length. It is lenient on
   the value those produced. The response should name any place the seed
   protects its own artifacts.
6. **Codex's bias.** Codex implemented most batches and wrote most evidence
   documents. A response defending batch evidence should do so with a
   finding those documents produced, not with the effort they represent.

## 9. Evidence And Authority

`ledgr_roadmap.md` (governance section: scope and non-negotiables);
`spike_protocol.md`; `rfc_cycle.md`; the v0.2.0.1 packet's `batch_plan.md`,
`batch14-final-evidence.md`, and `v0_2_0_1_release_closeout.md`;
`manual/optimization_coding_style.qmd`; horizon entries dated 2026-09-17
through 2026-09-20; `test-availability-production-retirement.R` and
`test-peer-benchmark-boundary.R` as the executable-guard pattern.

## Revision History

- 2026-09-20 — Seed v1, Claude. Written after the v0.2.0.1 release and
  before any response; no process document was edited.
