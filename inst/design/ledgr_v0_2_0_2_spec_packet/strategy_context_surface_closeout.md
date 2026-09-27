# Strategy Context Surface Closeout

**Status:** Agent-provisional; awaiting the Workstream 20 Type 1 close review.
**Date:** 2026-09-27
**Cut:** 13
**Workstream:** 20
**Implementation range:** `385c10e..91b9437` plus this closeout commit.

## Shipped Claims And Detectors

| Claim | Detecting evidence | Commit |
| --- | --- | --- |
| Contracts use one decision axis, singular position plane and context-first entrances. | LTB-0084 through LTB-0087 | `58ada69`, `3890c02`, `26baa1c` |
| Exact zero member weights do not require a sizing close; positive weights retain their checks. | LTB-0088 | `3167565` |
| Supported feature reads cannot reach beyond the invoking pulse. | LTB-0089 | `2cf48cc` |
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
and empty axis). Reattaching the raw projection made LTB-0089 fail its field and
object-enumeration assertions. Adding one unit to sweep final equity made
LTB-0092 fail the run/sweep comparison.

## Cost And Shape

The new entrance path validates and aligns primitive vectors on the prepared
axis. It creates no data frame, performs no history query and does not scan
facts. The direct entrance fixtures have no store from which a query could be
served. At 505 instruments, three interleaved 10,000-iteration process pairs
measured the old value constructors at 189, 193 and 188 microseconds per
selection-plus-signal pair, and the context entrances at 196, 204 and 202.
The medians are 189 and 202 microseconds: 13 microseconds extra, about 0.016
seconds if used once at each of 1,260 pulses. Both arms returned the same 252
selected instruments and score sum 253.

The decision-time feature repair retains the prepared projection engine-side
and exposes bounded closures and current planes. It adds no row construction,
table subset or history replay. Its interleaved 505-instrument, 400-update
clock measured medians of 0.095 seconds before and 0.090 after.

The final ticket records are green. The last ordinary fast profile ran 465 of
465 blocks with zero failures or skips in 84.720 seconds and passed the
112-second registered-runner bound. All 55 chunks in the touched Strategy
Authoring Tools article executed while regenerating its Markdown sibling.

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

The accepted cut contains nine completed tickets. Its independent cut review
is one invocation. The requested close review will make two invocations over
nine tickets, `2 / 9 = 0.222`, below the 0.5 gate. No implementation correction
round has occurred. This draft does not accept the workstream; acceptance
belongs to the maintainer after independent review.
