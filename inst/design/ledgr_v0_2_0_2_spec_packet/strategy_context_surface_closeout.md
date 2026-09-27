# Strategy Context Surface Closeout

**Status:** Agent-provisional; awaiting the focused Type 1 re-review.
**Date:** 2026-09-27
**Cut:** 13
**Workstream:** 20
**Implementation range:** `385c10e..7e521aa`, plus this closeout record.

## Shipped Claims And Detectors

| Claim | Detecting evidence | Commit |
| --- | --- | --- |
| Contracts use one decision axis, singular position plane and context-first entrances. | LTB-0084 through LTB-0087 | `58ada69`, `3890c02`, `26baa1c` |
| Exact zero member weights do not require a sizing close; positive weights retain their checks. | LTB-0088 | `3167565` |
| Real dense and availability callbacks expose current feature reads but no indexable future projection. | LTB-0089 | `2cf48cc` plus the close-review correction |
| Empty membership, empty axis and explicit empty selection remain distinct. | LTB-0090 | `fa2890c` |
| One authored table matches actual dense and availability callback surfaces. | LTB-0091 | `7295cf2` |
| The taught context-first helper pipeline agrees across run and sweep. | LTB-0092 and the executed article | `91b9437` |

The implementation tests and claim records carry the exact fixtures, condition
classes and smallest failing changes. This closeout links them rather than
repeating their inventories.

## Two Corrections, Kept Distinct

Membership projection of context predicates corrects a proposed design before
it shipped. A held nonmember can have a missing current close; its predicate
entry is outside the current allocation population and must not invalidate a
member decision.

Zero-weight sizing corrects shipped helper behavior. An explicit zero member
weight and omission now produce the same zero target without a price lookup.
This is a widening: a strategy that previously succeeded still succeeds.
Positive weights and explicit nonmember names retain their failures.

## Direct Probe And Mutation Record

The historical probe was run directly under R 4.6.1 and rlang 1.2.0:

```text
Rscript dev/spikes/strategy-context-surface/probe.R <normal-output>
Rscript dev/spikes/strategy-context-surface/probe.R <gut-output> gut
```

Both new outputs were diffed against the committed `observations.csv`, and the
normal and gut outputs were diffed against each other. Historical byte identity
is deliberately gone. The expected census changes are visible: 28 public names
became 25, 14 public functions became 13, `positions`, `safety_state` and both
tombstones disappeared, `vec$positions` became `vec$position`, `tradable`
appeared, and the old candidate-rule spelling is absent. The stale probe also
tries to mutate retired `ctx$positions`, so its later state and empty-axis rows
are no longer runtime authority.

The gut still changes the economically relevant reservation row from AAA=6 to
AAA=10 while OLD remains held at two. Applying the same reservation removal to
the package made LTB-0085 fail three assertions: full allocation, 0.6
allocation and predicate-projection targets. LTB-0085 is the live reservation
detector.
Restoring the old zero-weight price lookup separately makes LTB-0088 fail in
both dense and availability contexts.

Adding one undocumented `future_probe` member through both context-update paths
made LTB-0091 fail once for dense and twice for availability (held nonmember
and empty axis). The first close review found that LTB-0089's structural
assertions covered only its hand-built slow context. The corrected block now
records exposure from every real callback in both full-fold runs. Reattaching
the three retired projection fields through the fast updater made its dense
assertion fail on all five pulses. Adding one unit to sweep final equity made
LTB-0092 fail the run/sweep comparison.

## Close-Review Corrections

The correction removes the obsolete contract promise that the deleted target
tombstones fail with migration guidance. The strategy-context help now calls
`ctx$universe` the decision axis and describes `ctx$tradable()` as a
convenience predicate, not a promise that an instrument can be sized or
executed. The target help now matches the accepted empty-domain behavior: a
zero-length target is valid without a supplied non-empty universe.

The Strategy Authoring Tools article was also edited as teaching, not merely as
ticket coverage. It now presents two authoring paths up front, derives weights
through a pipeline, and makes the separate context-aware rebalance call the
economic boundary. The hold-and-edit path shows a real BUY then SELL, the
missing-input example preserves error and count types, and the residual-budget
trap is a warning callout. Generic target-vector teaching remains linked to its
canonical Strategy Development article.

The adversarial editorial pass found that the first rewrite still repeated one
pipeline, hid hold behind flat positions, placed the budget warning too late,
and retained benchmark and preflight material from other canonical homes. The
final article is 2,888 words rather than 3,934. It opens with the two paths and
one terminology boundary, shows a price-conditioned stateful round trip while
preserving another holding, puts five easily confused intent cases in one
rendered table, executes the main helper strategy, and removes the repeated
pipeline, raw sizing formulas, volatile benchmark, duplicated preflight lesson
and broken stored-source heading. Three stale prose-pin assertions were changed
to protect that structure and those executed outcomes; the function-level
flooring and helper-semantic assertions remain.

The same pass found that the causality detector followed context members only
at the top level. LTB-0089 now also inspects one level of list and environment
caches. Nesting the projection in `.pulse_lookup` made the dense assertion fail
at all five pulses; baseline dense and availability folds remain green.

## Cost And Shape

The new entrance path validates and aligns primitive vectors on the prepared
axis. It creates no data frame, performs no history query and does not scan
facts. The direct entrance fixtures have no store from which a query could be
served. These are warm, in-process microbenchmarks, not cold-start or
end-to-end clocks. At 505 instruments, three interleaved 10,000-iteration
process pairs measured the old value constructors *with `universe =`
validation* at 189, 193 and 188 microseconds per selection-plus-signal pair,
and the context entrances at 196, 204 and 202. The medians are 189 and 202
microseconds: 13 microseconds extra, about 0.016 seconds if used once at each
of 1,260 pulses. A plain value construction without universe validation is a
different operation and was not the baseline. Both measured arms returned the
same 252 selected instruments and score sum 253.

The decision-time feature repair retains the prepared projection engine-side
and exposes bounded closures and current planes. It adds no row construction,
table subset or history replay. Its warm, interleaved 505-instrument,
400-update clock measured medians of 0.095 seconds before and 0.090 after.

The final correction record is green. The ordinary fast profile ran 465 of 465
blocks with zero failures or skips in 84.130 seconds, and the independent
checker passed the 112-second registered-runner bound. All 17 executable
chunks in the revised Strategy Authoring Tools article ran while regenerating
its Markdown sibling, and an independent freshness render was byte-identical.

## Deferred And Rejected Work

- Removing callback inspection tables is deferred to the focused horizon
  question; this cut neither materializes tables automatically nor creates an
  inspection subsystem.
- Rebalance bands, partial-rebalance semantics and a richer missing-intent
  object remain out of scope.
- Scheduler and causal-frame designs remain separate questions.
- Strategy-preflight semantics were not changed.
- Compatibility aliases, tombstones, member-count gates, documentation
  generators and a second strategy engine were rejected.

## Governance

The accepted cut contains nine completed tickets. Its independent cut review,
close review and two correction reviews make four invocations over nine
tickets, `4 / 9 = 0.444`, below the 0.5 gate. This draft does not accept the
workstream; acceptance belongs to the maintainer after independent review.
