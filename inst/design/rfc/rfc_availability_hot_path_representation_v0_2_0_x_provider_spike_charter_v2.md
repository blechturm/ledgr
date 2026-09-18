# Availability Hot-Path Representation - Provider Spike Charter v2

Charter v2 supersedes v1 by applying Charter Review v1 findings B1, B2, M1,
M2, and M3 only; non-binding until the second and final pre-execution
structural review passes (`spike_protocol.md` sections 8, 2, 4). Author:
Claude, who executed the diagnostic-writer spike and wrote neither Seed v2 nor
the provider probe. Branch `v0.2.0.1` at `b0fe6b8`; nothing staged or indexed.

## One question and its cheaper prerequisite

> Can one prepared availability provider, compiled once per build from the
> canonical sparse fact tables into keyed primitive vectors or matrices with
> monotone change cursors, replace the current per-pulse data-frame resolver
> with identical `decision_view()` and `execution_view()` results on the
> shared availability fold, inside the 757-pulse envelope registered below?

Prerequisite (`dev/spikes/availability-provider-preparation/`), answered
`PREPARATION_REQUIRED`: the probe measured the current provider rebuilding an
unchanged decision view on the registered 757-pulse dense/static fixture at
396.02 s for 757 `decision_view()` calls against a 0.0036 s median
pre-resolved floor with all 757 views identical. The floor is not a candidate:
it omits changing facts, compilation cost, and `execution_view()`.

## Smallest runnable fork

One seam: the closures returned by `ledgr_availability_provider_build()`
(`R/availability-provider.R:303-395`), selected once per build by
`options(ledgr.internal.spike_availability_provider)`, default `current`, in
the process that builds the provider: direct runs, reopen, and result views.
Parallel sweep and walk-forward workers are out of scope: `mirai` workers get
only the source path and `.libPaths()` (`R/parallel-workers.R:159-211,
289-308`), so parallel dispatch is unchanged and unmeasured. The seam stamps
each provider with a `spike_arm` attribute outside `identity()` and every
view; evidence rows record the observed arm, and an unobserved or default arm
never satisfies parity. Mechanism under test: the per-pulse data-frame
resolver and its repetition per actionable target
(`R/availability-provider.R:68-234,353-372`). Unchanged: the other provider
elements and the version string; the view list's shape, names, types, and
order; `ledgr_facts_resolve()`, which calls the current membership resolver
directly (`R/availability-inspection.R:107`), as the public membership
reference.

## Comparison arms and fixtures

1. The current production provider as built at `b0fe6b8`.
2. One prepared provider: canonical sparse facts stay the durable input; the
   build step compiles them before the fold into instrument-indexed primitive
   vectors or matrices ordered by effective time, knowledge time, and fact
   ID, plus monotone change cursors over applicability boundaries (effective
   from, knowledge, effective to, supersession once knowable and effective),
   re-seeking on a cutoff below the previous one so answers never depend on
   query order; no fact frame is filtered, sorted, split, or subset per
   instrument and pulse; frames manifest only at existing boundaries; the
   view keeps its shape; collapse operations are details, not a third arm.

Both arms hold the GREEN columnar diagnostic writer constant
(`ledgr.internal.spike_diagnostic_writer = "columnar"`). Semantic fixture:
small and public (at most 16 instruments and 40 sessions), generated with a
non-flat strategy and at least one fact per category below so the fork can
fail; not a witness list. Fold fixture: the registered 563/505/757
dense/static fixture from `spike_fixture(FIXTURES$envelope757)` in
`dev/spikes/availability-hot-path-representation/spike_runner.R`, unchanged;
its sealed store may be built once and copied per run. Eventful provider
fixture: public synthetic facts on the same 757 cutoffs and a constant
505-wide axis (lists rotating members at constant width; status and lifetime
facts changing with knowledge lags), deterministic from a registered formula
with event counts in `fixture.csv`; a provider-only pass, not a fold or arm.

## Evidence claims

Categories the semantic fixture must contain and the fork must be able to
fail; cases derive from actual failures, at most ten, and a category the fork
cannot fail becomes a policy sentence. Existing `test-availability-*.R` files
run under the prepared arm as the regression net; a failure is a case.

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
7. Revisited or out-of-order cutoffs: both arms answer shuffled and repeated
   cutoffs (execution and non-pulse times included) with full views compared
   by `identical()`; `ledgr_facts_resolve()` checks only membership evidence.
8. Interruption, rollback, resume, durable reopen: appended traces, error
   evidence after rollback, identical `availability` and `ledgr_run_explain()`
   results whichever arm serves the reopen (`contracts.md:463-471,873-884`).
9. Identical diagnostics, events, fills, equity, state, completion, and run
   identity between arms on both fold fixtures; identical eventful views.

## Registered envelope, kill condition, and measurement boundary

Envelope, prepared arm at 757 pulses, three components: median fold wall
around `ledgr_run()` at most 180 s; every measured peak working set (external
sampler) at most 1,024 MiB; the eventful provider-only pass at most 82 s.
Basis (`evidence/lanes_757.csv`, `envelope_757.csv`): provider resolution
took 82.7% of the profiled columnar run's 506.98 s `t_loop`, 419.1 s, leaving
87.9 s in the loop; against its 516.75 s wall the non-provider remainder is
about 98 s, a cross-clock estimate, so an arm at the 180 s ceiling keeps
about 82 s for preparation plus provider views; the same 82 s bounds the
eventful pass. Memory sits 120 MiB above the current arm's 900.8 MiB peak;
compiled state is bounded by the sparse tables.

One kill and recharter condition: if the prepared arm preserves every claim
but breaches any envelope component, close the spike without a third arm; the
profiled run chooses the destination: recharter provider preparation if
provider resolution still leads, otherwise route the new leading lane.

Same host, R, and dependency versions; one fresh process, scratch store copy,
and run ID per run; `t_loop` secondary. Provider-only decomposition: harness
wrappers around both views inside the fold, plus out-of-fold passes per arm
over all 757 decision cutoffs and the registered 40-opening `execution_view()`
sample, once on the static facts (current reference 396.02 s, rerun once) and
once on the eventful facts. Prepared arm: one unmeasured warm-up, three
measured fold runs (medians beside raw values), and one profiled run (lane
classifier). Current arm: one fold run, stopped by the external control at
1,800 s or 4,096 MiB and recorded as stopped. The executor selects the
collapse library explicitly (default 2.1.7 or isolated 2.1.8), runs both arms
under it, and records the loaded version and any 2.1.8 dependence. GREEN:
every claim holds and every envelope component is met. RED: a claim cannot
be preserved without narrowing semantics, or identity, schema, or the view
contract changes. INCONCLUSIVE: the measurement cannot separate the arms.

## Deliverables, non-goals, and reviews

Exactly the three items of `spike_protocol.md` section 6: a runner that
regenerates the fixtures, executes both arms, and writes evidence CSVs; a
checker that reruns the semantic phase into scratch space, byte-diffs the
deterministic CSVs, validates the measurement CSVs against the rules above,
and guards package scope over every Git change type; and an inventory showing
one gutted path failing and listing what was demoted, deleted, and learned.
Identity uses ledgr's own run and snapshot identity or is labelled `proto:`
once. No hash ledgers, registries, ancestry or workspace gates, tripwires, or
review modes. Harness within 1,500 R lines; a diff over 500 lines is a
stop-and-talk; destructive scope tests run only in a verified scratch
repository addressed with `git -C`. Non-goals: availability-policy change,
public API redesign, schema migration, Sharadar-specific code, a second
execution engine, parallel pulse execution, durable expanded matrices,
package-wide collapse rewrite, and public benchmark claims. Reviews: this
v2's structural review is the second and final; a section 7 evidence review
(rerun, gut one path, diff) by a non-executor follows; the author reviews
neither. Revision: 2026-09-15 v1 at `b0fe6b8`; v2 applying B1, B2, M1, M2, M3.

CHARTER_DISPOSITION: READY_FOR_INDEPENDENT_REVIEW
