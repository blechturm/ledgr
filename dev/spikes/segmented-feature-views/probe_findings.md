# Probe findings: segmented feature views

**Ran:** 2026-09-27, `dev/spikes/segmented-feature-views/probe.R`, branch
`ldg-axis-repair` at `1ac6d03`. Evidence in `probe_evidence.csv`. **Purpose:**
spike protocol section 1. Establish by execution the facts a charter would
otherwise assert. Binds nothing; no package file changed.

## P1. Late-known bounded facts already work end to end

Executed, through the public run surface:

| key | value |
| --- | --- |
| `halt_effective_from` | 2020-01-03 16:00:00 |
| `halt_knowledge_time` | 2020-01-07 16:00:00 |
| `restricted_at_effective_from` | `FALSE` |
| `restricted_at_knowledge_time` | `TRUE` |
| `reason_at_knowledge_time` | `trading_halted` |

`ledgr_sim_pit_inputs()` emits a bounded `trading_status` interval whose
knowledge time falls four sessions after its effective time, and
`ledgr_run_explain()` shows the restriction absent at the effective instant and
present at the knowledge instant. So a fact learned after it took effect is
resolved causally today, in an ordinary availability-aware run. The two clocks
are not hypothetical and not untested.

This corrects a claim made twice in design prose on 2026-09-27, that ledgr's
two-clock paths had never run against two-clock data.

## P2. The segmented architecture already exists, for facts

`R/availability-provider-prepared.R` lines 5-19 state it and the code implements
it: canonical sparse facts are compiled **once, before the fold**, into
per-instrument piecewise-constant segments in a flat CSR layout, with one cursor
per instrument. `ledgr_availability_prepared_cursor()` (`:143-160`) advances
vectorised for a non-decreasing cutoff and re-seeks by `cumsum` for a decreasing
one, so, in the file's own words, "answers never depend on query order".

Measured on the fixture: `trading_status` compiles to 11 boundaries and 440
bytes, `lifetime` to 9 boundaries and 520 bytes, 960 bytes total for four
instruments.

Two consequences. The preparation shape proposed as a candidate in the accepted
synthesis is not a new architecture; it is the shipped one, one family up. And
the non-monotone-consumer objection raised in review is already answered for
facts by the re-seek, so the pattern to follow exists rather than needing
invention.

## P3. The payload is the whole question

The fact segment store is independent of the pulse count: it scales with
instruments times boundaries, roughly 240 bytes per instrument here. One feature
plane scales with instruments times pulses, and on this fixture that is
`4 x 22 x 8 = 704` bytes, giving a segment-store-to-plane ratio of 1.36.

That ratio inverts with the pulse axis, which is the point. Holding boundaries
fixed and taking 2,500 pulses instead of 22 leaves the segment store unchanged
while one feature plane per instrument grows about eighty-fold. A *segmented
feature view* would hold one such plane per segment, so its storage grows as
segments times instruments times pulses times features, while the fact store it
would be modelled on grows as instruments times boundaries.

**Withdrawn 2026-09-27 on review.** This section concluded that the payload was
therefore the whole question. It is not. Sizing a representation presumes the
revision it would hold has been demonstrated, and P1 did not demonstrate it: it
established the diagonal, "January 3 as known January 3", where historical
projection needs "January 3 as known January 7". The arithmetic above stands as
arithmetic; the conclusion drawn from it does not, and the charter now asks the
semantic question instead.

## Scale caveat

Four instruments and twenty-two pulses is a shape probe, not a scale
measurement. Per protocol section 9 these structural numbers do not belong in a
ranking and are not a cost estimate. They establish which quantity the spike
must measure and in what units.

## One fixture constraint found by execution

Case placement in the generator is fixed: the halt lands on instrument 2 across
weekdays 3 to 6, the delisting on instrument 1 at weekday 10, the missing
observation on instrument 4 at weekday 7. Requesting more instruments does not
produce more cases. So varying event density means composing several bundles
rather than scaling one, and the spike must do that rather than assume a density
argument exists.

## P4. A late-known barrier is constructible and causally gated

The halt measured in P1 is a `trading_status` fact. The accepted carry barriers
are an inactive lifetime interval, a corporate action under an undeclared price
basis, and a terminal assertion, so a halt is none of them. The generator sets
its terminal assertion's knowledge time equal to its effective time, and the
recipe declares `price_basis = "split_adjusted"`, which removes corporate
actions from the barrier set. So the default bundle contains **no late-known
barrier**, and P1 is evidence about ordinary decision-time causality rather than
about the two-clock historical view.

Moving the inactive row's knowledge time from 2020-01-14 to 2020-01-29:

| key | value |
| --- | --- |
| `late_known_barrier_constructs` | `TRUE` |
| `late_known_barrier_seals` | `TRUE` |
| `barrier_reasons_at_effective_from` | `status_unknown` |
| `barrier_reasons_at_knowledge_time` | `status_unknown|lifetime_inactive` |

A late-known inactive interval passes `ledgr_facts_lifetime()` and seals, so the
fixture the spike needs can be built through the public constructor. And it is
causally gated: `lifetime_inactive` is absent from the complete reasons at the
barrier's effective instant and present at its knowledge instant.

**Corrected 2026-09-27 on review.** An earlier version of this section read only
`target_restriction_reason`, saw `status_unknown` at both instants, and
concluded that a concurrent status expiry confounded the barrier. That was an
artefact of the field: `ledgr_availability_restrictions()` fills the singular
`reason` with `lifetime_inactive` only when status left it empty, while always
appending it to the complete `reasons` (`R/availability-provider.R:178-204`).
Reading the plural field shows the barrier behaving correctly. There is no
confound, so the charter no longer requires the fixture to decouple the status
family and no longer makes decoupling a kill condition.

One boundary this does not cross: target restriction is a trading gate, not
feature-input admissibility. P4 establishes that the fact can be built and is
resolved causally. It does not establish that a feature value is revised, which
is what the spike asks.

## P5. The backward re-seek is exercised by a test that can fail

An earlier charter cited `ledgr_availability_prepared_cursor()`'s backward
re-seek from source reading, which protocol section 8 returns. A first attempt
to execute it was vacuous, and a second still was: the halted row's segment
begins at `pmax(effective_from, knowledge_time)`, so at its effective instant it
is not yet applicable and both chosen boundaries resolved identically. Using its
knowledge boundary against its end:

| key | value |
| --- | --- |
| `reseek_values_differ_at_the_two_boundaries` | `TRUE` |
| `cursor_without_reseek_would_differ` | `TRUE` |
| `cursor_backward_reseek_matches_fresh` | `TRUE` |

So the two boundaries resolve differently, a cursor left at the later one would
read the wrong value, and a cursor seeked forward then back matches a fresh
forward seek. The guard row is what caught both vacuous versions.
