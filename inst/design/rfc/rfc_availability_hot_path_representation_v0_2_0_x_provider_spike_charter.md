# Availability Hot-Path Representation - Provider Spike Charter

Charter v1, non-binding until two pre-execution structural reviews pass
(`spike_protocol.md` sections 8, 2, 4). Author: Claude, who executed the
diagnostic-writer spike and wrote neither Seed v2 nor the provider probe.
Branch `v0.2.0.1` at `b0fe6b8`; nothing staged, committed, or indexed.

## One question and its cheaper prerequisite

> Can one prepared availability provider, compiled once per build from the
> canonical sparse fact tables into keyed primitive vectors or matrices with
> monotone change cursors, replace the current per-pulse data-frame resolver
> with identical `decision_view()` and `execution_view()` results on the
> shared availability fold, inside the 757-pulse envelope registered below?

Prerequisite (`dev/spikes/availability-provider-preparation/`): how much time
does the current provider spend rebuilding an unchanged decision view on the
registered 757-pulse dense/static fixture, and what lower bound does a
once-prepared primitive-vector view expose? Answer `PREPARATION_REQUIRED`:
396.02 s for 757 production `decision_view()` calls, rising from about 390 ms
to 590 ms per pulse as identical headers accumulated, against a 0.0036 s
median pre-resolved floor with all 757 views identical. The floor is not a
candidate: it omits changing facts, compilation cost, and `execution_view()`.

## Smallest runnable fork

One seam: the closures returned by `ledgr_availability_provider_build()`
(`R/availability-provider.R:303-395`), selected once per build by
`options(ledgr.internal.spike_availability_provider)`, default `current`, and
shared by direct runs, reopen, result views, sweep, and walk-forward workers.
Mechanism under test: membership resolution filters and sorts every
applicable header and rescans the membership table once per header
(`R/availability-provider.R:68-137`); status, lifetime, and terminal-event
resolution loop over the axis and subset fact frames per instrument
(`187-234`); `execution_view()` repeats membership resolution per actionable
target (`353-372`). Unchanged: the sparse fact tables as the durable input;
the `facts`, `history`, `identity`, `sessions`, and `valuation_policy`
elements and the provider version string; the view list's shape, names,
types, and order; `ledgr_facts_resolve()`, which calls the current membership
resolver directly (`R/availability-inspection.R:107`) as the public reference.

## Comparison arms and fixtures

1. The current production provider as built at `b0fe6b8`.
2. One prepared provider embodying the earlier arc's principle: canonical
   sparse facts stay the durable input; the build step compiles them before
   the fold into instrument-indexed primitive vectors or matrices ordered by
   effective time, knowledge time, and fact ID, plus monotone change cursors
   over applicability boundaries (effective from, knowledge, effective to,
   supersession once knowable and effective); a cutoff below the previous
   one resets or re-seeks the cursors, so answers never depend on query
   order; no fact frame is filtered, sorted, split, or subset per instrument
   and pulse; frames manifest only at existing boundaries and the view keeps
   its current shape; collapse operations are details, not a third arm.

Both arms hold the GREEN columnar diagnostic writer constant
(`ledgr.internal.spike_diagnostic_writer = "columnar"`), so the provider is
the only varying seam. Semantic fixture: small and public (at most 16
instruments and 40 sessions), generated with a non-flat strategy and at least
one fact per category below so the fork can fail; not a witness list.
Full-scale fixture: the registered 563-instrument, 505-member, 757-pulse
dense/static fixture regenerated unchanged from `probe.R`; a sealed store may
be built once per fixture and copied per run.

## Evidence claims

Categories the semantic fixture must contain and the fork must be able to
fail; cases derive from actual failures, at most ten; a category the fork
cannot fail becomes a policy sentence. Existing `test-availability-*.R` files
run under the prepared arm as the regression net: a failure is a generated
case, and pass counts are not evidence.

1. Effective versus knowledge time: facts apply only after both, and a fact
   effective but not yet knowable cannot shadow a tie (`contracts.md:351-355`).
2. Complete and partial membership changes, interval assertions, and
   complete-set omission citing the header (`v0_2_0_0_spec.md:212-218`).
3. Status precedence, top-precedence conflicts, and source-local supersession
   applied once knowable and effective (`v0_2_0_0_spec.md:219-221`).
4. Lifetime assertions, `known_inactive` restriction, and terminal events
   stopping a holding without settlement (`contracts.md:408-436`).
5. Held nonmembers after members in stable-ID order: hold, exit, reduce, and
   the classed exposure-increase failure (`contracts.md:343-350`).
6. Both views: decisions at closes, execution facts at the next opening with
   membership frozen from the decision (`contracts.md:356-360`).
7. Deterministic answers when cutoffs are revisited or queried out of order:
   both arms answer shuffled and repeated cutoffs, execution and non-pulse
   times included, compared by `identical()` and to `ledgr_facts_resolve()`.
8. Interruption, rollback, resume, durable reopen: appended traces, error
   evidence after rollback, identical `availability` and `ledgr_run_explain()`
   results whichever arm serves the reopen (`contracts.md:463-471,873-884`).
9. Identical diagnostics, ledger events, fills, equity, strategy state,
   completion, and run identity between arms on both fixtures.

## Registered envelope, kill condition, and measurement boundary

Prepared arm at 757 pulses: wall around `ledgr_run()` at most 180 s and
externally sampled peak working set at most 1,024 MiB. Completion, not an
intermediate step: the writer spike's profiled columnar run
(`evidence/lanes_757.csv`), scaled to its 506.98 s `t_loop`, assigns about
419 s to provider resolution and 98 s to all else (diagnostics 74 s), so an
arm at the ceiling spends at most 82 s, or 108 ms per pulse, on preparation
plus 757 decision views; above that it stays the leading lane. Memory sits
120 MiB above the current arm's 900.8 MiB peak: compiled state is bounded by
the sparse tables (30,300 membership, 563 status, 563 lifetime rows).

One kill and recharter condition: if the prepared arm preserves every claim
and its profiled 757-pulse run no longer shows provider resolution as the
largest grouped lane, but its median 757-pulse run still breaches the
envelope, close the spike without a third arm and route the newly largest
lane into its own question.

Same host, R, and dependency versions; one fresh process, scratch store copy,
and run ID per run; wall by `proc.time()`, `t_loop` secondary, peak working
set from the external sampler; provider-only decomposition from harness
wrappers around both views, one out-of-fold pass of all 757 decision views per
arm (current reference 396.02 s, rerun once), and a registered 40-opening
`execution_view()` sample per arm. Prepared arm: one unmeasured warm-up, three
measured runs with medians beside raw values, and one profiled run classified
with the lane profile's classifier. Current arm: one run, stopped by the
external control at 1,800 s or 4,096 MiB and recorded as stopped if
unfinished. The executor selects the collapse library explicitly (default
2.1.7 or the isolated 2.1.8), runs both arms under the same one, and records
the loaded version and any 2.1.8 dependence. GREEN: every claim holds and the
median wall and every measured peak sit inside the envelope. RED: a claim
cannot be preserved without narrowing semantics, or identity, schema, or the
view contract changes. INCONCLUSIVE: the measurement cannot separate the arms.

## Deliverables, non-goals, and reviews

Exactly the three items of `spike_protocol.md` section 6: a runner that
regenerates both fixtures, executes both arms, and writes evidence CSVs; a
checker that reruns the semantic phase into scratch space, byte-diffs the
deterministic CSVs, validates the measurement CSVs against the rules above,
and guards package scope over every Git change type; and an inventory showing
one gutted path failing and listing what was demoted, deleted, and learned.
Identity uses ledgr's own run and snapshot identity or is labelled `proto:`
once. No hash ledgers, registries, ancestry or workspace gates, tripwires, or
review modes. Harness within 1,500 R lines; a diff over 500 lines is a
stop-and-talk; destructive scope tests run only in a verified scratch
repository addressed with `git -C`. Non-goals: availability-policy change,
public API redesign, schema migration, Sharadar-specific code or licensed
fixtures, a second execution engine, parallel pulse execution, durable
expanded matrices, package-wide collapse rewrite, diagnostics-writer or
valuation optimization, release placement, and any public benchmark claim.
Reviews: two pre-execution structural reviews by an independent non-author,
applying sections 8, 2, and 4, the second final; then a section 7 evidence
review (rerun, gut one path, diff the evidence) by a non-executor; the author
reviews neither. Revision: 2026-09-15, Charter v1 at `b0fe6b8`.

CHARTER_DISPOSITION: READY_FOR_INDEPENDENT_REVIEW
