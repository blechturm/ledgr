# ledgr v0.2.0.1 Spec Review

**Role:** Claude, independent spec reviewer. Claude wrote the accepted synthesis; the
spec draft was written by another author. This review verifies the spec against the
accepted RFC artifacts, the spike evidence, and the current source. It opens no design
space and creates no tickets. **Date:** 2026-09-16.

## 1. Reviewed baseline and containment

- Branch `v0.2.0.1`; HEAD `f0b847d02c2cf66a9871fdda119f55e0ccfd7e42` (the acceptance
  commit, which carries the three spike seams, the harnesses, the evidence, and the
  accepted RFC artifacts).
- Under review: `inst/design/ledgr_v0_2_0_1_spec_packet/v0_2_0_1_spec.md`, 661 lines,
  status "Draft for independent spec review".
- Working tree before this review: `inst/design/README.md` modified (one draft-packet
  pointer), the spec packet directory untracked, and the pre-existing
  `dev/spikes/asset_availability_pit/` scratch files, which were not read, modified,
  staged, or removed. Nothing staged.
- This review adds exactly one file, this one. No spec, code, test, evidence, or
  index file was edited; nothing was staged, committed, or pushed; no expensive spike,
  757-pulse protocol, cold seal, or peer record was run. Final containment is reported
  in Section 3.

## 2. Findings ordered by severity

### High

**H1 - Section 3.1 retires the resolver that Section 3.2 keeps alive.** Section 3.1
requires removing "the old row-list writer, scalar per-row diagnostic construction, and
data-frame-scanning provider from `R/`", and the Section 4.1 mechanism row requires a
source guard proving no "production old provider remains". Section 3.2 and Section 2.1
simultaneously bind `ledgr_facts_resolve()` unchanged as the independent public
reference. That function resolves membership through
`ledgr_membership_resolve_at()` (`R/availability-inspection.R:107`) and evidence through
`ledgr_membership_evidence()` (`:56`, `:114`, defined at `:397`); the membership resolver
lives in `R/availability-provider.R:68` and is the data-frame-scanning resolver the
prepared provider replaces. The status, lifetime, and terminal-event resolvers
have no caller outside the current provider closures (`:187-235`). As written, ticket cut must
either delete the public reference's engine or leave the source guard undefined.

Required revision: name the retained functions (`ledgr_membership_resolve_at()`,
`ledgr_membership_evidence()`, and any helper they need) as the public reference's
engine, define the "old provider" removed by the guard as
`ledgr_availability_provider_build_current()`, its per-pulse view assembly, and the
unused status/lifetime/terminal resolvers, and state that no fold, result, or reopen
consumer may call the retained resolver. This keeps the accepted synthesis's M1
resolution (final review) intact and makes the guard falsifiable.

**H2 - The Section 3.5 status sweep is not equivalent to the pairwise validator once
supersession links exist.** The current validator exempts a pair only when one row
directly supersedes the other (`R/availability-facts.R:1310-1311`), and tests each pair
independently. Section 3.5 replaces it with "a running maximum end per status value"
and "exempt direct supersession pairs exactly as today before conflict testing" without
saying how a pairwise exemption survives an aggregate. Two shapes break the described
algorithm inside one `(instrument_id, source, precedence)` group:

- row X (status A, end 10, unlinked), row Y (status A, end 20, superseded by row J),
  row J (status B, start 15): pairwise finds no conflict (J overlaps only Y, which is
  exempt); a running maximum of 20 for status A flags J. False positive.
- the same Y, plus row Z (status B, start 5, unlinked, not linked to Y): pairwise
  flags Z against Y; an implementation that drops superseded rows from the running
  maximum to honor the J exemption misses it. False negative.

Section 4.2 lists "direct supersession exemptions and non-exempt conflicts" but not
these mixed shapes, so a wrong implementation could pass the adversarial list and
depend on random sets to surface the defect.

Required revision: bind exemption handling that is pairwise-exact, for example sweep
the rows that carry no supersession link and check every linked row pairwise against
all rows of its group (links are few and within one source), or an equivalent
construction; add the two shapes above to the Section 4.2 adversarial cases; and state
that the membership and lifetime sweeps have no exemption and therefore use the plain
running maximum per state.

### Medium

**M1 - Section 3.2 describes the membership shape inaccurately in three places.**
The measured implementation (`R/availability-provider-prepared.R:23-93`) keeps headers
in the resolver's processing order `(effective_from, knowledge_time, set_id)` (`:28`)
and derives a separate eligibility order over `max(effective_from, knowledge_time)`
for the cursor (`:42-43`). The processing order decides which complete header resets
state: the last eligible complete header in processing order resets, and every
eligible header at or after it contributes (`:76-79`). Section 3.2 says headers are
"ordered by eligibility time", which would change the result whenever a complete list
becomes knowable later than a list with a later effective time. Section 3.2 also names
only "complete-list headers", omitting partial headers (`complete = FALSE`), which
contribute their sets but never reset state; and it calls the flat start, end, member,
and instrument-index vectors "partial membership assertions", whereas they hold the
interval-assertion family (`set_id` absent, `:45-56`), a different family from partial
lists.

Required revision: state both orders and the complete/partial header rule, and rename
the flat vectors to interval assertions with the last-applicable-wins override
(`:85-89`). The accepted synthesis's Section 4 item 2 already carries the correct
wording for the two shapes.

**M2 - Section 7.1's relative criterion cannot be run after Section 3.1 retires the
reference.** Section 7.1 requires the release warm record to be "faster than a retained
same-session reference by more than that reference's run-to-run spread" and forbids
comparing unrelated clocks. After stage D the old writer and provider are removed from
installed code and may live only where "it cannot be sourced by installed package
execution" (Section 3.1), so no same-session full-fold reference exists at stage H.
Section 4.1 already places the two-arm 757-pulse comparison "before the reference arm
is retired".

Required revision: bind the relative-spread criterion to that pre-retirement closeout
pair (recorded once, cited by prefix), and define the stage H warm record as the
absolute envelope (median at most 60 s, every peak at most 1,024 MiB) plus the reported
figures, with the pre-retirement pair as its comparison context.

**M3 - Section 3.3 forbids what Section 4.1 tests.** Section 3.3 fixes the chunk
capacity at 4,096 rows and states "the capacity is not configurable"; Section 4.1
requires "tests at 7-row and 4,096-row chunks plus multi-chunk flush". The spike used
`ledgr.internal.spike_diagnostic_chunk_rows` for that, which Section 3.1 removes.

Required revision: state the internal injection path for tests, for example an
internal constructor argument of the writer defaulting to 4,096 that the fold passes
unchanged and tests set through an internal entry point or a mocked binding, and keep
the prohibition on any public or option-based tuning.

**M4 - Section 3.4 must be scoped to the path that has the defect.** The equity prefix
is lost only when finalization takes its pulse list from fold-supplied equity facts
(`R/run-finalize.R:221-222`, `:237-241`), which the fold records only when
availability is active (`R/fold-engine.R:321`, `:515-517`); dense runs recompute the whole
curve from events every invocation and are not defective. Section 3.4 is written for
all finalization. Applying the merge with "conflicting duplicates ... fail closed" to
the dense path would turn any recomputation difference into a hard failure of a path
that works today, and applying it without care would rely on floating-point identity.

Required revision: scope the merge to availability-aware runs whose invocation equity
covers less than the achieved prefix, state that the dense full-recompute path is
unchanged, and add a dense interrupted-then-resumed case to Section 4.3 as a regression
guard. The DuckDB transaction already spans deletion, append, and status
(`R/run-finalize.R:421-426`), so the atomicity requirement is consistent with source.

### Low

**L1 - Section 3.7 changes the record preset defaults without listing that change in
scope.** The harness defaults `record` to 100 instruments and 252 sessions
(`dev/bench/peer_benchmark/peer_benchmark.R:91-96`); `--n-inst`, `--n-days`,
`--release`, `--fast`, `--slow`, and `--seed` exist, with defaults 5, 10, and 20260530.
The explicit command already pins 500 by 1,260. Either add the default change to
Section 2.2 or drop "the `record` preset defaults must agree" and rely on the explicit
flags recorded in the closeout. Also record the `--engine-set` value used, since the
harness has an `all` and a `ledgr-cost` set.

**L2 - Section 3.3 carries spike-harness language into production.** "Outside
block-path trace counts" refers to the spike checker's traced constructor counts, which
do not exist in installed code; say that the post-rollback row is constructed and
written outside the block writer path. The diagnostic schema has no logical or list
columns (`R/availability-diagnostic-writer.R:113-127`), so "logical" and "list" in the
setv sentence are harmless but describe no column.

**L3 - Section 3.2 defers the tie rules to "exact current ... tie ... rules" without
stating them.** Two implementers need the rules written down: lifetime resolves to the
last applicable row in `(effective_from, knowledge_time, read order)` order
(`R/availability-provider-prepared.R:222-230`); status removes rows superseded by an
applicable row, takes the top precedence, and reports `conflicting` when distinct
statuses tie at that precedence (`:197-205`); status defaults to `unknown` when the
family is declared and no row applies, and to `active` when it is not declared
(`:241`). These match the measured arm and should be bound explicitly.

**L4 - Section 3.2 names two provider-build consumers; there are three.**
`ledgr_availability_provider()` is called by the fold (`R/backtest-runner.R:666`), the
`availability` result view (`R/availability-results.R:314`), and the INCOMPLETE reopen
path in `ledgr_run_open()` (`R/run-store.R:1152`), which uses the build only for the
session calendar. Name the third consumer so the "all true provider-build consumers"
gate is complete; `ledgr_run_explain()` consumes the result view
(`R/availability-results.R:454`) and needs no separate build.

## 3. Verification performed

Read-only inspections; no spike, protocol, seal, or peer record was rerun.

- Read AGENTS.md, the spec, the accepted synthesis (including its acceptance revision
  and Section 14), the maintainer decisions, the final review with its focused
  verification, the three spike inventories, the provider and block evidence reviews,
  the sealing probe findings, and both manuals.
- Traced the prepared provider in full (`R/availability-provider-prepared.R`), the
  fold's block seam (`R/fold-engine.R:332-347`), the writer (`R/availability-diagnostic-writer.R`),
  the pairwise validators (`R/availability-facts.R:1297-1358`), the seal call sites
  (`R/availability-persistence.R:318`, `:336-343`), interval validation (`:877-886`,
  which rejects `effective_to <= effective_from`, so touching and equal endpoints are
  the only boundary cases), the membership schema (`R/availability-schema.R:37-49`,
  `member BOOLEAN NOT NULL`), finalization (`R/run-finalize.R:97-113`, `:215-241`,
  `:421-426`), resume indexing (`R/backtest-runner.R:730-753`), every caller of the
  provider wrapper and of the old resolver functions, the worker transfer
  (`R/parallel-workers.R:66-85`: source path and library paths only), and the peer
  harness argument parser and defaults.
- Recomputed the sweep equivalence argument for membership and lifetime: with rows
  visited in start order and `effective_to > effective_from` enforced, a row conflicts
  with an earlier opposing row exactly when its start lies before that row's end, so
  a running maximum per state reproduces the pairwise test, including equal starts and
  nested intervals; the status case differs only through the pairwise exemption (H2).
- Confirmed the seal-path bypass precondition: `ledgr_facts()` refuses two membership
  families on one universe (provider inventory), and Section 3.5 additionally forbids
  mixing an interval family into the bypass, so excluding set-backed rows cannot hide
  an interval-versus-set conflict.
- Working-tree containment after writing this file: `git status --porcelain` shows the
  pre-existing README modification, the two pre-existing untracked directories, and
  this review as the only addition; `git diff --check` reports nothing; the index is
  empty.

## 4. Verified non-findings

- **Scope fidelity.** Maintainer decisions 1 to 5 are represented: v0.2.0.1 patch
  placement, precedence over the crypto probe, one packet with the three workstreams and
  separate cold gates, the release-cycle peer closeout with honest unavailable lanes,
  and the deferrals. Valuation, crypto, compiled expansion, broad loop or frame removal,
  the Docker laboratory, hosted LEAN, and public rankings are excluded (Sections 2.3 and
  7.4). No public API, schema, hash, identity, accounting, or availability-policy change
  is introduced (Sections 2.1, 3.6, 4.4).
- **Prepared status, lifetime, and terminal-event representation.** The CSR segment
  tables, per-instrument monotone advance, vectorised backward re-seek
  (`R/availability-provider-prepared.R:135-163`), inclusive start and exclusive end
  (`:119`), held former members after members in stable order (`:264-266`), fixed
  universes in configured order (`:182-183`), and query-order independence are stated
  correctly.
- **Public reference and workers.** `ledgr_facts_resolve()` is bound unchanged, and the
  provider spike compared 602 membership cutoffs against it. After the option seams are
  removed, workers cannot depend on process options: the worker transfer carries only
  the source path and library paths.
- **Diagnostics.** The 4,096-row capacity is the measured shape; per-pulse block
  construction in emission order, exact schema and sequence, the write-time renumbering
  owner, rollback with one post-rollback error row, and interrupt and resume are stated
  and paired with falsifiable tests (Section 4.1). No hidden fallback can ship: option
  removal, source guard, and release gate 2 together forbid it.
- **collapse posture.** No version floor; `setv()` only on non-character columns; the
  prepared provider uses no collapse operation; the suite must pass under 2.1.7 and
  2.1.8 (gate 6). This is honest to the evidence.
- **Finalization invariant.** The strict full-prefix validator is retained and its
  weakening is forbidden; the merge is keyed, calendar-bound, fail-closed on conflict,
  and atomic; DONE and INCOMPLETE reopen are required (Sections 3.4, 4.3). M4 narrows
  the scope; it does not weaken the invariant.
- **Parity and identity.** The three exclusions are exactly the block spike's and are
  sufficient: they are the only per-store locators, and run IDs at both levels,
  `archived_at_utc`, `config_hash`, and all other fields are compared. Old paths exist
  only until the two-arm gate and cannot be sourced by installed code afterward.
- **Benchmarks.** Cold and warm clocks are defined and kept apart; the availability
  closeout and the peer record answer different questions and the peer benchmark cannot
  prove availability performance (Section 3.7); the four phases are defined per engine
  with unavailable rather than estimated fields; LEAN and other optional peers stay
  `UNAVAILABLE` with reasons; the 60 to 90 s seal figure and the 24.93 s fold stay
  context, not thresholds or claims (Sections 7.1, 7.2, 7.4).
- **Enforceability.** Every Section 4 row names durable tests or a closeout artifact;
  the stage table preserves independent review stops and an implementable order; no
  test or benchmark is claimed passed because a spike passed (Sections 0.2, 9).
- **Observation, no finding.** Finalization also deletes and rewrites the `features`
  table per invocation (`R/run-finalize.R:401-420`) from the whole runtime projection,
  so no prefix is lost there; it stays out of scope.

## 5. Ticket-cut blockers

1. H1: define which resolver functions survive for `ledgr_facts_resolve()` and what
   the "old provider" source guard removes.
2. H2: bind pairwise-exact supersession handling in the status sweep and add the two
   mixed adversarial shapes to Section 4.2.
3. M1 to M4: correct the membership description, the post-retirement relative
   criterion, the chunk-capacity test path, and the finalization scope. These are
   bounded text changes; none reopens an accepted product or architecture decision.

L1 to L4 may be folded into the same revision.

## 6. Verdict

The spec is faithful to the accepted synthesis and maintainer decisions, excludes the
deferred work, and gates the right things. It is not yet cuttable: two sections bind
instructions that contradict each other or the retained pairwise semantics, and four
passages would let two implementers build incompatible behavior. One bounded revision
closes all of them.

SPEC_REVIEW_DISPOSITION: REVISE_SPEC_FIRST
