# ledgr v0.2.0.1 Spec Re-Review

**Role:** Claude, independent focused re-reviewer; author of the first spec review, not
of the spec or its revision. This is a closure check of the first review's findings,
not a new design cycle. **Date:** 2026-09-16.

## 1. Reviewed baseline and containment

- Branch `v0.2.0.1`; HEAD `f0b847d02c2cf66a9871fdda119f55e0ccfd7e42`.
- Under review: `inst/design/ledgr_v0_2_0_1_spec_packet/v0_2_0_1_spec.md`, revised in
  place on 2026-09-16, 723 lines, status "Revised draft for focused independent spec
  re-review". ASCII, LF, final newline, no trailing whitespace; `git diff --check`
  clean before and after this review.
- The first review (`v0_2_0_1_spec_review.md`, 272 lines, disposition
  `REVISE_SPEC_FIRST`) is unchanged and was not edited.
- Working tree before this review: `inst/design/README.md` modified, the spec packet
  directory untracked (spec and first review only), and the pre-existing untracked
  `dev/spikes/asset_availability_pit/` scratch files, which were not read, modified,
  staged, or removed. Nothing staged. No `v0_2_0_1_tickets.md`, `tickets.yml`, or
  `batch_plan.md` exists.
- This review adds exactly one file, this one. No spec, source, test, index, or review
  file was edited; nothing was staged, committed, or pushed; no spike, sealing protocol,
  or peer benchmark was rerun.

## 2. Closure of original findings

**H1 - Provider retirement versus public reference: CLOSED.** Section 3.1 now retires
exactly `ledgr_availability_provider_build_current()`, its per-pulse view assembly,
`ledgr_availability_members_at()`, and the status, lifetime, and terminal-event
resolvers that lose their last caller with it, and retains
`ledgr_membership_resolve_at()`, `ledgr_membership_evidence()`, and their helpers as the
installed engine of `ledgr_facts_resolve()` and `ledgr_facts_history()`. Source agrees:
`ledgr_availability_members_at()` (`R/availability-provider.R:59-66`) is a wrapper called
only by the current provider closures (`:340`, `:372`); the public inspection path calls
`ledgr_membership_resolve_at()` and `ledgr_membership_evidence()` directly
(`R/availability-inspection.R:56`, `:107`, `:114`); the family resolvers (`:187-235`)
have no caller outside `ledgr_availability_provider_build_current()`. Section 3.1, the
Section 4.1 mechanism row, the Section 5 boundary row, and release gate 2 all state
that no fold, result, or reopen consumer may call the retained path and that the guard
does not demand its removal. The guard is falsifiable: the retired builder, assembly,
and unused resolvers are named functions whose absence can be asserted.

**H2 - Supersession-exact status validation: CLOSED.** Section 3.5 now classifies a row
as involved when it names a direct predecessor or is named as one, sweeps only
uninvolved rows with the per-status running maximum, compares every unordered pair
containing an involved row under the current predicate, and exempts only a pair in
which one row directly names the other. That reproduces
`ledgr_fact_validate_source_conflicts()` (`R/availability-facts.R:1303-1321`) exactly:
uninvolved pairs are decided by the sweep, whose equivalence for start-ordered rows
with `effective_to > effective_from` is the same argument as for membership, and every
pair touching an involved row keeps its pair identity. Section 4.2 adds both mixed
shapes from the first review, the X/Y/J false-positive guard and the Y/Z false-negative
guard, with the correct expected outcomes. Membership and lifetime are stated to use
the plain running maximum per state because they have no exemption. The clause that the
hybrid must equal the retained pairwise reference on every row set, and may be replaced
only by an equally tested construction, keeps the gate binding.

**M1 - Membership representation: CLOSED.** Section 3.2 distinguishes the header
processing order `(effective_from, knowledge_time, set_id)`
(`R/availability-provider-prepared.R:28`), the separate eligibility order over
`max(effective_from, knowledge_time)` driving one cursor with backward re-seek
(`:42-43`, `:64-71`), the last eligible complete header in processing order resetting
state with that header and every later eligible complete or partial header contributing
(`:76-79`), all eligible partial headers contributing when no complete header is
eligible (`last_complete` of zero, `:77`), and interval assertions without `set_id` kept
as flat vectors in `(effective_from, knowledge_time, fact_id)` order with the last
applicable assertion per instrument overriding (`:45-56`, `:85-89`). The wording matches
the measured implementation; no CSR membership design is introduced.

**M2 - Benchmark comparison lifecycle: CLOSED.** Section 7.1 places the two-arm
comparison before retirement, in one quiet-host session with a warm-up and at least
three measured runs per arm, records its prefix, and applies the relative-spread
criterion there. Stage H uses the absolute 60-second and 1,024-MiB production
envelope, requires a host comparable to the reviewed block spike or leaves the gate
open, cites the pre-retirement pair by prefix as context, and forbids restoring or
rerunning the retired path to manufacture a reference. Unrelated clocks cannot be
compared.

**M3 - Diagnostic chunk injection: CLOSED.** Section 3.3 keeps the production capacity
at 4,096, adds an internal test-only capacity argument on the unexported constructor
that ordinary fold calls omit, allows tests to call the constructor directly or mock
the internal binding, and forbids any option, public argument, config field, or
durable identity input. Section 4.1's 7-row and 4,096-row tests are now implementable.

**M4 - Finalization scope: CLOSED.** Section 3.4 applies the merge only to
availability-aware runs for which finalization uses fold-supplied equity facts and the
current invocation does not cover the complete achieved prefix, which is the defective
path (`R/run-finalize.R:221-241`; fold equity facts are recorded only when availability
is active, `R/fold-engine.R:515-517`). Dense runs keep their full recomputation and do
not enter the merge or its conflict rule. Section 4.3 adds the dense
interrupted-then-resumed regression case. The strict validator, keyed merge,
fail-closed rules, atomic transaction, and DONE and INCOMPLETE reopen requirements are
unchanged.

**L1 - Peer preset defaults: CLOSED.** Section 3.7 states that changing the `record`
preset defaults is outside the packet and pins every workload parameter and
`--engine-set all` in the release command; all flags exist in the harness
(`dev/bench/peer_benchmark/peer_benchmark.R:24-50`, `:81-96`).

**L2 - Production wording: CLOSED.** Section 3.3 now says the post-rollback one-row
error is constructed and written outside the ordinary block-writer path, and the setv
sentence names only numeric, integer, POSIXct, and character columns.

**L3 - Tie and default rules: CLOSED, with one Low inaccuracy (Section 3 below).**
Section 3.2 states superseded-fact removal, top precedence, `conflicting` on tied
distinct statuses, lifetime and terminal event from the last applicable row in
`(effective_from, knowledge_time, original read order)`, and the `unknown` and empty
terminal defaults, matching `R/availability-provider-prepared.R:197-205`, `:222-230`,
and `:241-243`.

**L4 - Provider-build consumers: CLOSED.** Section 3.2 and the Section 5 boundary row
name the fold, the `availability` result view (`R/availability-results.R:314`), and the
`ledgr_run_open()` INCOMPLETE validation (`R/run-store.R:1152`), and state that
`ledgr_run_explain()` reuses the result view (`R/availability-results.R:454`).

## 3. New findings, if any, ordered by severity

### Low

**N1 - The status default rule is keyed on the wrong condition.** Section 3.2 says "a
declared status family with no applicable row resolves to `unknown`; an undeclared
family resolves to `active`". Both the current and the prepared provider key the
default on whether any status rows exist, not on family declaration: with zero
persisted status rows every instrument resolves to `active`
(`R/availability-provider.R:188-189`; `R/availability-provider-prepared.R:173`, `:241`),
and only a family with rows but none applicable at the cutoff resolves to `unknown`.
A declared family with zero rows is the edge where a literal reading of the spec
diverges from both implementations. Patch in place: state the rule by row presence, and
add a declared-but-empty status family to the focused provider tests in Section 4.1 so
the productionized build is checked against the current behavior. This is a wording
precision, not a blocking contradiction, and no spike fixture exercised that edge.

### Observation, no finding

"A host comparable to the reviewed block spike" (Section 7.1) is a judgment. The
closeout's required host metadata makes it reviewable, which is sufficient for this
packet.

## 4. Verification performed

Read-only inspections plus the one permitted test; no spike, sealing protocol, or peer
benchmark was rerun.

- Read AGENTS.md (unchanged since the baseline), the first review, the revised spec in
  full, the accepted synthesis Sections 4, 5, 9, 10, and 14, and the maintainer
  decisions.
- Mapped every function in `R/availability-provider.R` and every caller of
  `ledgr_availability_members_at()`, `ledgr_membership_resolve_at()`, and
  `ledgr_membership_evidence()` across `R/`; confirmed `ledgr_facts_history()` exists
  and uses the evidence helper.
- Re-read the status validator predicate and exemption
  (`R/availability-facts.R:1303-1321`) against the Section 3.5 hybrid and the two
  Section 4.2 mixed shapes.
- Re-read the prepared membership, cursor, status, and lifetime code
  (`R/availability-provider-prepared.R:23-93`, `:135-163`, `:188-243`) against
  Sections 3.2 and 3.5, including the no-complete-header branch and the defaults.
- Re-read the finalization equity source and transaction (`R/run-finalize.R:221-241`,
  `:421-426`) and the fold's availability-only equity facts (`R/fold-engine.R:515-517`)
  against Section 3.4.
- Confirmed the peer-harness flags and defaults against Section 3.7.
- Ran `tests/testthat/test-documentation-contracts.R` against the current tree: 72
  tests, 0 failures, 0 errors, 0 skips.
- Confirmed no ticket artifacts exist, the first review's disposition line and length
  are intact, and the spec's scope and non-goal lists are unchanged from the first
  review apart from the corrections.
- Working-tree containment after writing this file: `git status --porcelain` shows the
  pre-existing README modification, the two pre-existing untracked directories, and
  this re-review as the only addition; `git diff --check` reports nothing; the index is
  empty.

## 5. Ticket-cut readiness

- Scope fidelity holds: the accepted synthesis direction and all five maintainer
  decisions are represented; valuation, crypto, compiled availability expansion, broad
  loop or frame cleanup, the Docker laboratory, hosted LEAN, and public rankings remain
  excluded (Sections 2.3, 3.7, 7.4).
- No public API, schema, hash, identity, accounting, or availability-policy change has
  entered the packet (Sections 2.1, 3.6, 4.4).
- The three persisted-table parity exclusions are unchanged and exact (Section 4.1).
- No test or benchmark is claimed passed on spike evidence alone (Sections 0.2, 9).
- The mechanisms are now described precisely enough that two implementers would build
  compatible behavior; the only remaining imprecision is N1, a one-sentence patch.
- Ticket cut may proceed once the maintainer accepts the spec, with N1 patched in place
  or carried as a named ticket-level correction. No further review round is required.

## 6. Verdict

Every finding of the first review is closed without a new blocking contradiction and
without scope expansion. One Low wording inaccuracy remains and does not affect the
accepted direction or any gate.

SPEC_RE_REVIEW_DISPOSITION: READY_TO_CUT_TICKETS
