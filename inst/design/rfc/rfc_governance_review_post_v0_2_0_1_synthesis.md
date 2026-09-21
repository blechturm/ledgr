# RFC Synthesis: Post-v0.2.0.1 Governance Review

**Status:** Rejected by the maintainer on 2026-09-21. Retained as history;
binds nothing. Seed v2 remains the standing seed and stage 7 re-runs. See
the revision history for the grounds.

**Date:** 2026-09-21. **Window:** none; this cycle changes process, not code.

**Author:** Codex, synthesis author under the `rfc_cycle.md` rotation:
Claude wrote Seed v1, the Response Review, and Seed v2; Codex wrote the
Response. The final review belongs to an author who did not write this.

**Reviewed HEAD:** branch `v0.2.0.2` at `f57d0f7`.

## Cycle trail and citation keys

- **[ROADMAP]** `../ledgr_roadmap.md:1653-1766` supplies the scope, six
  non-negotiables, implementation-authority question, and test-audit mandate.
- **[S1]** `rfc_governance_review_post_v0_2_0_1_seed.md` proposed the first
  simplification; **[R]** its response counted and challenged it.
- **[RR]** `rfc_governance_review_post_v0_2_0_1_response_review.md:8-85`
  verified the count, counterexample, documentation test, and threshold.
- **[S2]** `rfc_governance_review_post_v0_2_0_1_seed_v2.md:35-278`
  corrected the facts and supplied Sections 4.1 through 4.8.
- **[BP]** `../ledgr_v0_2_0_1_spec_packet/batch_plan.md`; **[B3]**
  `../ledgr_v0_2_0_1_spec_packet/batch3-diagnostic-evidence.md`; **[B5]**
  `../ledgr_v0_2_0_1_spec_packet/batch5-finalization-evidence.md`; and **[B7]**
  `../ledgr_v0_2_0_1_spec_packet/batch7-benchmark-manual-evidence.md` are the
  packet evidence cited below.
- **[STYLE]** `../manual/optimization_coding_style.qmd:66-116,448-465` names
  the seven shapes and checklist. **[BENCH]**
  `../manual/benchmark_methodology.qmd` defines the benchmark clocks.

## Decision summary

The direction in [S2] is accepted with one classification correction and one
new boundary flag. Blanket batch review and batch evidence essays end. Review
is selected from a closed boundary classification, and executable records
replace prose wherever a claim can be rerun.

The canonical R implementation remains the normative oracle for optimized or
compiled execution. Runtime selection is a separate decision. A faster path
may diverge only under a later accepted RFC/spec that names an independent
oracle, the permitted divergence, its tests, and its review gate.

The authority-scaled size rule is accepted. Both open decisions are resolved;
none returns to stage 6. The separately scheduled test-suite audit remains a
required governance workstream and may propose tickets, not make test changes.

## Evidence reconciliation — counts

- The reproducible count is at least 26 review invocations. Fourteen events
  changed something under the broad response method; three were soft, leaving
  about eleven that rejected a record, forced a rerun, or replaced a guard
  ([S2]:58-76; [RR]:34-45).
- The packet has 24 Markdown files and 7,695 lines. Its ticket Markdown has
  1,687 lines for 26 tickets, its batch plan 612 lines, and fourteen batch
  evidence files range from 45 to 264 lines ([S2]:40-48).
- Exact searches for the checklist questions in `tests/` and `dev/` found no
  executable use. The documentation test checks six phrases, none the
  checklist question ([S2]:98-113; [RR]:47-51).
- The quality threshold is 5.0 percent of samples in a named profiled stage.
  It catches the alias map at 56.73 percent and `replicate()` at 6.39 percent
  without turning either observation automatically into a ticket
  ([S2]:171-186).
- Batch 3's review required a direct failed-append retry witness
  ([BP]:217-222; [B3]:30-38). Batch 5 changed atomic persistence, rollback,
  resume, and reopen behavior ([BP]:275-300; [B5]:7-47). Both therefore meet
  Section 4.2(c), contrary to [S2]'s application table.
- Batch 7's arithmetic checker passed before review corrected a phase label,
  Zipline teardown attribution, and the availability-provider clock boundary
  ([BP]:357-372; [B7]:97-110). A profile alone does not adjudicate those
  meanings.

## Binding process rules

### 4.1 Name the boundary and reuse the classifier

Every future implementation batch declares exactly one or more of these flags
in the packet's single ticket source: `frozen_oracle`, `accepted_evidence`,
`accounting_identity_hash_schema_persistence`, `public_contract`,
`evidence_clock_or_release_claim`, or `none`. Persistence includes atomic
write, retry, rollback, interruption, resume, and reopen behavior. Evidence
clock includes phase taxonomy, workload comparability, and permitted claims.

Optimized or compiled tickets also declare `oracle: canonical_r` unless an
accepted RFC/spec names another independent oracle. `runtime_default` is a
separate field and cannot alter oracle authority.

**Check:** an R/testthat packet-contract check rejects unknown or mixed
`none` flags, derives `review_required` from the five material flags, and
rejects an optimized/compiled ticket without its oracle and parity command.

### 4.2 Remove narrative; keep review where a boundary exists

Future packets use `tickets.yml` as the single ticket source and do not create
batch evidence essays or a hand-maintained Markdown duplicate. A batch has
tests, commits, and any Section 4.3 record. A material flag requires independent
review; `none` ships on tests and any Section 4.5 profile. File type never
waives a material flag. A review runs the registered identity/parity command
and leaves an executable guard, or records `guard_not_practical_reason` in
`tickets.yml`.

**Check:** the packet-contract test rejects duplicate ticket sources,
`batch*-evidence.md`, a missing review command/result/source commit for a
review-required batch, or review fields on a `none` batch. The release reviewer
reruns every registered review command.

### 4.3 Evidence is a record, a command, and a commit

Every empirical or behavioral closeout claim has `claim_id`, `record_prefix`,
one `reproduce_command`, and a full `source_commit`. A record is data, a checker,
and a README of at most 40 lines. Failed and superseded records remain named as
such; only an accepted record may support a release claim.

**Check:** one R release command verifies required files and statuses, checks
that each commit exists and is an ancestor of HEAD, runs each checker, and
fails on an unregistered claim or nonzero reproduction result.

### 4.4 Add the missing release-quality phase

Once per release, profile the public data-frame and CSV pipelines through
experiment, serial and parallel sweep, promotion, and every public results
read. Run a normalized-body duplication scan, a census of [STYLE]'s seven
shapes, and reachability guards for named forbidden hot-path calls. A function
at or above 5.0 percent of samples in a named stage is a finding that must be
classified, not necessarily fixed.

**Check:** the quality command emits a tracked table with stage, symbol,
samples, stage samples, share, shape ID, source anchor, and classification. It
fails on a missing required stage or shape, an unclassified threshold crossing,
or a forbidden reachable call. The first forbidden set is `digest`,
`canonical_json`, and hash helpers from the per-pulse fold path.

### 4.5 Profile every hot-path batch

Each batch enumerates every changed production file and classifies its surface
as `pulse`, `seal`, `public_results`, or `none`. Every non-`none` surface has
before-and-after profiles made by one registered command; timings are evidence,
not an automatic acceptance threshold.

**Check:** the packet-contract test compares the batch file inventory with the
Git diff and rejects an omitted production file, an unknown surface, or a
non-`none` surface without both profile rows and the reproduction command.

### 4.6 Guard assumptions before they become history

Peer records include the workflow idiom taught by current documentation, or a
separate row that does. A probe manifest identifies the candidate, the cheaper
mechanisms considered, and one of `CHEAPEST_PLAUSIBLE` or `WRONG_CANDIDATE`.
Every boundary review satisfies Section 4.2's guard field.

**Check:** benchmark and probe checkers reject a record without a documented-
idiom row, a probe without those fields, or a continued experiment after
`WRONG_CANDIDATE`.

### 4.7 Size budgets scale with authority; excess is routing

The physical-line caps are: horizon entry 40; release closeout 120; record
README 40; RFC seed, response, and synthesis 300 each. Implementation reviews
are inline and findings-only; PASS leaves only Section 4.2's structured result,
not a prose review artifact. Evidence beyond a cap moves to record
data/checkers, `dev/bench/notes`, or spike findings; the authority artifact
keeps a pointer and one decision paragraph. Stop for maintainer direction only
when neither deletion nor routing preserves the content.

**Check:** the documentation-contract test counts physical lines in governed
artifacts and requires every routed pointer to resolve. A cap exception needs
an explicit maintainer decision in the same commit.

### 4.8 Write down the process asymmetry

`AGENTS.md` carries these exact sentences: "The package is exact about
provenance, identity, and evidence. The process that builds it is not, because
Git already is."

**Check:** the documentation-contract test asserts that exact sentence and
the link to this accepted synthesis.

## Process document changes

| File | Section | Change after acceptance |
| --- | --- | --- |
| `AGENTS.md` | Core Rules | Add Section 4.8's sentence and authority link. |
| `../spike_protocol.md` | Size Budgets; Provenance; probe rules | Add Section 4.7 caps, Section 4.3 fields, and Section 4.6 probe manifest. |
| `../rfc_cycle.md` | new section after "Final review scope" | Keep stages/rotation; add Sections 4.1-4.3 classifier and review gate. |
| `../manual/optimization_coding_style.qmd` | Seven Shapes; Maintainer Checklist | Give shapes stable IDs and make the checklist the Section 4.4 census specification; re-render its sibling. |
| `../manual/benchmark_methodology.qmd` | Record Generation Workflow; Two clocks, two questions | Add Sections 4.3, 4.6, and the evidence-clock review flag; re-render its sibling. |
| `../ledgr_v0_2_0_1_spec_packet/batch_plan.md` | Review Protocol | Make no historical edit. Future packet templates must not copy its blanket batch-review or evidence-essay rules. |

The test-suite audit in [ROADMAP]:1689-1761 produces the specified table of
test blocks, finding class, lane, and reproduction command before proposing
movement or deletion. This synthesis creates no test-refactoring authority.

## Non-negotiable carry table

| Roadmap requirement, verbatim | Enforced by |
| --- | --- |
| independent review at material design and correctness boundaries; | Sections 4.1-4.2 |
| immutable or explicitly superseded empirical evidence; | Section 4.3 |
| visible failures, corrections, and abandoned approaches; | Sections 4.2-4.3 plus Git |
| scope containment and explicit maintainer acceptance; | Sections 4.1-4.2 and existing RFC acceptance |
| executable semantic and persistence invariants where practical; and | Sections 4.2, 4.4-4.6 |
| separate, honestly labelled cold, warm, and peer-comparison clocks. | Sections 4.1, 4.3, 4.6 and [BENCH] |

## Resolved and escalated decisions

1. **Boundary definition: resolved, widened precisely.** Clause (b) remains
   limited to accepted evidence. Clause (c) expressly covers Batches 3 and 5;
   the direct append-failure witness and atomic resume/finalization semantics
   were not profile findings. The new evidence-clock/claim flag covers Batch 7,
   whose checker established arithmetic but not attribution. Applied to
   v0.2.0.1, these corrections newly retain review for Batches 3, 5, and 7;
   Batches 0, 2, and diagnostic-only 10 remain outside. No stage-6 decision is
   needed.
2. **Size routing: resolved in favor of authority-scaled caps.** The 130-line
   2026-09-18 horizon entry loses no finding: measurements and source anchors
   at `horizon.md:324-390` move to `dev/bench/notes`; its derived-context
   question and source-guard direction at `:411-437` fit one paragraph plus a
   pointer. Content relocates; authority and discoverability remain. No
   stage-6 decision is needed.

## Rejected alternatives and non-goals

- Blanket review of every batch and removal of all implementation review are
  both rejected.
- Narrative evidence, duplicated ticket sources, and caps copied from the
  largest historical artifact are rejected.
- A faster implementation cannot become its own correctness oracle or runtime
  default through this process change.
- No v0.2.0.1 decision or historical artifact is rewritten. No RFC stage or
  role changes. No product code, test refactor, ticket cut, or new tool beyond
  R/testthat is authorized.

## Final-review checklist

The independent final reviewer:

1. confirms this file is at most 300 lines and its sections are in the required
   order;
2. recounts the 26 invocations, three soft events, and approximately eleven
   hard outcomes from [BP], [RR], and [S2];
3. applies Section 4.1 to all sixteen old batches and obtains review for 1, 3,
   4, 5, 6, 7, 8, 9, and 11 through 15, with 0, 2, and 10 outside;
4. verifies [B3], [B5], and [B7] establish the two boundary corrections;
5. checks every rule has an R/testthat enforcement route and every process
   document change names a section;
6. confirms the six [ROADMAP] lines appear verbatim, canonical-R authority is
   distinct from runtime default, and no historical edit is directed; and
7. runs `git diff --check`, verifies the RFC pipeline row, and confirms only
   this synthesis and that row are committed.

## Revision history

- 2026-09-21 — Draft synthesis by Codex from Seed v2, its preceding response
  and review, and the counted v0.2.0.1 record.
- 2026-09-21 — Final-review citation patches by Claude, in place: the
  `rfc_cycle.md` change row named a section that does not exist and now
  names its placement; the `benchmark_methodology.qmd` row now names the two
  headings that exist; the Direction line was rewrapped. No rule changed.
- 2026-09-21 — Rejected by the maintainer. The enforcement layer turns
  process judgment into form checks and would grow the test suite the way
  the review set out to shrink narrative; the same disease in a new medium.
  The synthesis brief was over-specified and was followed mechanically
  rather than critiqued at the process level. The rules in Sections 4.1
  through 4.8 are not themselves rejected; their enforcement is.

**Direction:** ready for stage 8 final review because both open decisions
are resolved by repository evidence.
