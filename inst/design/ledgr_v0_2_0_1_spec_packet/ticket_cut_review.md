# ledgr v0.2.0.1 Ticket-Cut Review

**Role:** Independent reviewer of the accepted v0.2.0.1 spec's ticket cut.
This verifies coverage, fidelity, sequencing, honesty, artifact consistency,
and governance alignment. It is not a design or implementation review.
**Date:** 2026-09-16.

## 1. Reviewed baseline and containment

- Reviewed branch `v0.2.0.1` at cut commit
  `a1169697f4aba28bacbc537f80be7df4376485fe`, immediately after development-
  version commit `c5bf78f029e877404f67f38fe6af48fb3ae4e27b`.
- `f0b847d02c2cf66a9871fdda119f55e0ccfd7e42` is an ancestor of the cut and is
  still the runtime source baseline: the later two commits changed version,
  NEWS, governance, documentation-contract tests, and packet documents, but no
  file under `R/`, `src/`, or the reviewed spike and sealing directories.
- Read the requested authority chain in order: `AGENTS.md`; accepted spec;
  first review; focused re-review; packet README; Markdown tickets; YAML;
  batch plan; accepted synthesis; maintainer decisions; both commit stats; and
  the v0.2.0.0 ticket, YAML, and batch-plan format precedent.
- HEAD began with exactly one unrelated untracked directory,
  `dev/spikes/asset_availability_pit/`. I did not enumerate, read, modify,
  stage, or remove it.
- No spike, 757-pulse run, seal, peer benchmark, ticket, or implementation was
  executed. This review adds only this file.

## 2. Findings ordered by severity

### Medium

**M1 - The hard DAG does not preserve the accepted Stage G to Stage H
sequence.** `v0_2_0_1_tickets.md:45` makes LDG-2731 ready immediately after
LDG-2719 even though it is labelled Stage G, and LDG-2733 and LDG-2734 do not
depend on LDG-2732 (`:51-54`, `:809`, `:860`). The YAML agrees with that graph
(`tickets.yml:192`, `:221`, `:235`), so this is not a serialization typo. The
batch plan says dependencies are the hard readiness gate and numeric batch
order is only the default (`batch_plan.md:11-15`). Consequently the benchmark-
phase work can start before Stages C-F close, and both Stage H measurement
tickets can start before the Stage G manual and report work passes review.
That contradicts the accepted sequence in spec Section 6, where G follows the
production and correctness stages and H follows G.

Smallest correction: make LDG-2731 depend on the C/D, E, and F closures
LDG-2726, LDG-2727, LDG-2729, and LDG-2730; make LDG-2733 and LDG-2734 depend
on LDG-2732. Apply the same edges to the prose DAG and YAML. Existing
transitive dependencies may remain even when redundant.

**M2 - The record-specific peer documentation has no executable owner at the
time its evidence exists.** Spec Section 8 requires the peer README and tracked
report to carry the exact closeout command, record prefix, environment, parity
status, and non-ranking language. LDG-2732 owns that update before the peer run
and omits the record prefix (`v0_2_0_1_tickets.md:756-779`). LDG-2734 later
runs the record and cites its prefix only in the release closeout (`:856-887`);
it does not update the peer README or tracked report. LDG-2732 therefore cannot
truthfully finish its assigned environment and parity text, while LDG-2734 is
not accountable for completing it. This is the exact kind of split ownership
under which no ticket can be held to the accepted requirement.

Smallest correction: keep record-independent manual and methodology updates in
LDG-2732. Move the final peer README and tracked-report update to LDG-2734,
after the record runs, and name all five required fields including the exact
record prefix. Add LDG-2734 to the Section 8 gate-ownership row.

**M3 - The cut schedules two registered full-scale seals where the accepted
packet requires one closeout seal.** LDG-2730 says to measure the seal on the
registered fixture during Stage F (`v0_2_0_1_tickets.md:682`), while LDG-2733
again requires the registered full seal as the Stage H cold record (`:825-827`).
Spec Section 7.2 requires the registered full seal once at closeout, and the
accepted synthesis likewise places one full-scale post-fix seal in the packet
closeout. Stage F's exit evidence is randomized and adversarial equivalence,
setwise-bypass mutation coverage, existing seal tests, and independent review;
it does not require an earlier full-population measurement. The current cut
widens the accepted work and duplicates an expensive lifecycle clock at two
different source states.

Smallest correction: remove the registered-fixture measurement from LDG-2730
and remove Section 7.2 from that ticket's source reference. Keep targeted seal
fixtures plus structural proof that production no longer calls the pairwise
validator. Leave LDG-2733 as the sole owner of the registered full-scale cold
seal and its record prefix.

### Low

**L1 - Section 3.6's telemetry half is not owned.** The gate table assigns only
the collapse dependency posture to LDG-2724 and LDG-2735
(`v0_2_0_1_tickets.md:68`). No ticket mentions the other binding half of
Section 3.6: existing persisted and public telemetry names remain unchanged,
and no schema column, hash input, public telemetry API, or durable lane name is
introduced. LDG-2735 checks schemas and identity generally, but its task and
acceptance text do not make the telemetry prohibition independently
reviewable.

Smallest correction: rename the gate-ownership row to cover the complete
dependency and telemetry posture, and add one explicit LDG-2735 verification
item for the unchanged telemetry names and the four prohibited additions.

**L2 - The documentation contract does not lock the exact ticket-cut status
map.** The artifacts are correct: LDG-2719 alone is `review_pending`, every
other YAML ticket is `pending`, Batch 0 is Review Pending, and Batches 1-8 are
Pending. The new documentation test checks only that YAML contains no status
beginning with `complete` (`test-documentation-contracts.R:3008`) and that the
batch plan contains a Review Pending line (`:3010`). It would still pass if an
implementation ticket became `in_progress`, if several tickets became
`review_pending`, or if LDG-2719 became `pending`. That is weaker than the
governance state the test claims to lock.

Smallest correction: parse `tickets.yml` in that test and assert the exact map:
LDG-2719 is `review_pending`; LDG-2720 through LDG-2735 are `pending`. Keep the
existing no-complete assertion as a readable failure message if desired.

## 3. Verification performed

- Inspected `git log`, `git show --stat` for `c5bf78f` and `a116969`, the full
  development-version diff, and ancestry from `f0b847d` to HEAD.
- Parsed all 17 Markdown tickets and all 17 YAML tickets. IDs, case-normalized
  titles, priorities, efforts, statuses, and dependency sets agree with zero
  mismatches. Case normalization follows the v0.2.0.0 precedent: Markdown uses
  title case and YAML uses sentence case.
- Checked every YAML dependency exists and traversed the graph: no missing
  node and no cycle. Checked the batch plan: every ticket occurs exactly once,
  with no missing, duplicate, or extra ID and no dependency on a later batch.
  The sequencing finding is about missing hard edges, not an internal mismatch
  between the three artifacts.
- Parsed `tickets.yml` with R's YAML reader: version `0.2.0.1`, 17 tickets, 17
  unique IDs.
- Mapped the spec's Sections 0-10, every Section 4 matrix row, all ten Section
  9 gates, and re-review N1 to the ownership table and ticket bodies. Apart
  from L1 and the record-specific split in M2, each requirement has an
  accountable ticket.
- Verified the critical retirement order: LDG-2725 depends on the independently
  reviewed provider and writer boundaries, and LDG-2726 depends on LDG-2725.
  The only same-session relative record therefore occurs before deletion.
  LDG-2733 can run after deletion because it uses the absolute envelope and
  cites the earlier prefix; it does not require a live reference arm.
- Verified the ticket-cut environment: package `0.2.0.1`; R 4.5.2 ucrt on
  `x86_64-w64-mingw32`; duckdb 1.4.3; testthat 3.3.1; collapse 2.1.7 in the
  default library; and collapse 2.1.8 in
  `C:/tmp/ledgr-collapse-218-lib`.
- Ran the permitted focused documentation-contract file at HEAD through
  `pkgload::load_all()`: zero failures, errors, or skips.
- Inspected AGENTS, design index, roadmap, horizon, NEWS, packet README, ticket
  statuses, and batch statuses. They consistently say v0.2.0.1 is active,
  Batch 0 awaits review, Batches 1-8 are pending, and no runtime change or
  release gate is complete.

## 4. Verified non-findings

- **Scope fidelity holds.** No ticket imports valuation, spot crypto, compiled
  availability expansion, broad loop cleanup, the Docker laboratory, hosted
  LEAN, or a public ranking. No public API, schema, hash, identity, accounting,
  or availability-policy change is authorized.
- **The old/runtime-reference boundary is faithful.** LDG-2726 removes the
  installed current builder, view assembly, members wrapper, unused family
  resolvers, row-list writer, scalar construction, options, and arm stamps.
  It retains `ledgr_membership_resolve_at()`,
  `ledgr_membership_evidence()`, and their helpers solely for the unchanged
  public inspection contracts and forbids provider consumers from calling
  them.
- **Provider, writer, and finalization semantics are not reinterpreted.** The
  two measured membership shapes, row-presence status default, cursor and tie
  rules, internal-only chunk injection, rollback behavior, and the
  availability-only fold-equity merge are stated accurately. Dense finalization
  remains on full recomputation.
- **Status conflict validation is pairwise-exact.** LDG-2729 preserves direct
  supersession pair identity and owns both mixed adversarial cases. LDG-2728
  owns the plain membership and lifetime sweeps; LDG-2730 owns only the
  setwise-validated membership bypass.
- **N1 is carried correctly.** The accepted spec is patched to key the default
  on persisted-row presence, LDG-2719 records the patch, and LDG-2720 owns the
  declared-but-empty-family detector.
- **Artifact metadata is honest.** Only LDG-2719 is Review Pending, every other
  ticket is Pending, no ticket or benchmark is claimed complete, and the
  governance surfaces distinguish the completed v0.2.0.0 packet from the
  active v0.2.0.1 cut.
- **Baseline wording is supportable.** `f0b847d` is the unchanged runtime
  source baseline; `c5bf78f` opened package version 0.2.0.1; `a116969` is the
  ticket-cut commit under review. The packet's environment versions reproduce.

## 5. Verdict

The implementation split is faithful, metadata consistency is strong, and the
critical two-arm parity-before-retirement invariant is enforced. The cut still
needs bounded corrections to its hard closeout sequence, peer-report ownership,
and single-seal placement before Batch 0 can be marked Complete After Review.
These corrections do not reopen the accepted spec or require a new design
round.

TICKET_CUT_REVIEW_DISPOSITION: CORRECT_CUT_FIRST
