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

So the open question is not whether per-instrument segmentation works. It does,
and it ships. The question is whether it survives a payload that scales with the
pulse axis.

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

## P4. A late-known barrier is constructible; the fixture confounds it

The halt measured in P1 is a `trading_status` fact. The accepted carry barriers
are an inactive lifetime interval, a corporate action under an undeclared price
basis, and a terminal assertion, so a halt is none of them. The generator sets
its terminal assertion's knowledge time equal to its effective time, and the
recipe declares `price_basis = "split_adjusted"`, which removes corporate
actions from the barrier set. So the default bundle contains **no late-known
barrier at all**, and P1 is evidence about ordinary decision-time causality
rather than about the two-clock historical view.

Moving the inactive row's knowledge time from 2020-01-14 to 2020-01-29:

| key | value |
| --- | --- |
| `late_known_barrier_constructs` | `TRUE` |
| `late_known_barrier_seals` | `TRUE` |
| `barrier_restricted_at_effective_from` | `TRUE` |
| `barrier_restricted_at_knowledge_time` | `TRUE` |
| `barrier_reason_at_knowledge_time` | `status_unknown` |

Two findings. A late-known inactive interval passes `ledgr_facts_lifetime()` and
seals, so the fixture the spike needs can be built through the public
constructor. And this probe cannot observe its causality in isolation: the
instrument is restricted already at the effective instant, and the reason is
`status_unknown` rather than `lifetime_inactive`, because the generator ends the
same instrument's `trading_status` interval at that same instant. The reason
code is what exposes the confound. Any fixture for the spike must decouple the
status expiry from the lifetime boundary before it can attribute a revision to
the barrier.

## P5. The backward re-seek is exercised, not asserted

An earlier draft of the charter cited `ledgr_availability_prepared_cursor()`'s
backward re-seek from source reading, which protocol section 8 returns. Now
executed: two cursors over the same segments, one seeked forward to the last
boundary and then back to the first, the other seeked only forward to the first,
read identically (`cursor_backward_reseek_matches_fresh` is `TRUE`).
