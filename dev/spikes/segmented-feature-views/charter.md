# Spike charter: the late-known barrier revision seam

**Status:** Draft for maintainer ownership. Binds nothing. Authorizes no
production change, no spec packet, and no second execution path.
**Supersedes:** the first draft of this charter, returned on adversarial review
2026-09-27 for narrowing checkpoint (d) to payload size on evidence that did not
support it. The closing section records why.
**Governs:** `../../../inst/design/spike_protocol.md`, which overrides anything
here that conflicts with it.
**Feeds:** checkpoint part (d) of
`../../../inst/design/rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v10.md`
(accepted 2026-09-27).
**Probe:** `probe.R`, findings in `probe_findings.md`, evidence in
`probe_evidence.csv`, run 2026-09-27. Every claim below was executed or is cited
from `contracts.md`.

## The one question

> Does a late-known carry barrier revise an earlier finite-window feature value
> and its evidence, while a previously returned result stays unchanged?

This is the semantic seam, not a cost question. Nothing downstream can be sized
until it is answered, because a representation cannot be measured for a revision
that has not been shown to occur.

## Why this is the question, from the probe

**No shipped path produces the revision.** The engine consults no lifetime fact
when it builds a feature window, so a later-known barrier changes no feature
value today. The spike must build the smallest rule that makes one occur.

**The default fixture cannot exhibit it.** Probe P4: the generator's only
barrier-eligible fact is a terminal assertion whose knowledge time equals its
effective time, and its recipe declares `price_basis = "split_adjusted"`, which
removes corporate actions from the barrier set. The late-known halt in P1 is
`trading_status`, which is not a barrier. So the bundle contains no late-known
barrier.

**One can be built.** Probe P4 moved the inactive row's knowledge time fifteen
sessions later: `ledgr_facts_lifetime()` accepted it and
`ledgr_snapshot_from_df()` sealed it. So the fixture exists through public
constructors.

**But it must be decoupled.** In P4 the instrument was already restricted at the
barrier's effective instant, with reason `status_unknown` rather than
`lifetime_inactive`, because the generator ends the same instrument's
`trading_status` interval at that same instant. The fixture must separate the
status expiry from the lifetime boundary before a revision can be attributed to
the barrier. The reason code is the check that it did.

## Kill condition

The spike stops and recharters if the revision cannot be exhibited inside the
one-of-everything scope below: one barrier kind, one feature, one instrument.
The seam is then not separable at this size, and a spec cut follows.

Building a throwaway fork is not the failure condition. Protocol section 3 asks
for the smallest runnable fork and section 6 asks the inventory to show a gutted
path, so prototyping is the method. The test is proportion, not purity.

It also stops if the fixture cannot be decoupled per P4, because then no
observed revision can be attributed to the barrier rather than to a status
expiry.

## Scope: one of everything

One barrier kind, the inactive lifetime interval. One feature, an existing
finite-window indicator with its real calculation. One instrument carrying the
revision. One previously returned result held for the immutability check.

Not in scope: the carry policy, the other barrier kinds, output carry, the
history accessor, cross-sectional features, and any production API. Those are
the synthesis's work, not this spike's.

**No cost arm.** The first draft compared eager against lazy preparation. Lazy
was disqualified by the draft's own viability criterion before any measurement,
and sizing a revision that has not been demonstrated is premature. What eager
preparation costs against a declared workload and memory envelope is the
question this spike unblocks; it is deliberately not chartered here and needs
its own charter with those quantities stated.

## Fixture

`ledgr_sim_pit_inputs()` for the calendar, bars, membership and instruments,
then a hand-built lifetime frame through `ledgr_facts_lifetime()` carrying one
`known_inactive` interval whose knowledge time is later than its effective time,
with the `trading_status` family adjusted so its interval does not expire at the
same instant. Probe P4 established that this constructs and seals.

No generator refactor. If the fixed case placement turns out to block the work,
that is a finding for the closeout and a reason to extend the generator
afterwards.

## Deliverables

Protocol section 6's three, as written there: a runner writing evidence CSVs; a
checker that reruns into a scratch directory, diffs the recorded CSVs, and
guards package scope (`R`, `src`, `tests`, `NAMESPACE`, `DESCRIPTION`, `man`,
`inst/design`); and an inventory showing one gutted path failing and listing what
was demoted, deleted and learned. Counts of passes are not evidence, and a row
is evidence only if the fork derived it from provider facts.

## Test cases

At most ten, none written before a fork exists that can fail it. The order is
the protocol's: smallest runnable fork with one seam, run it, let its failures
generate the cases, freeze the expected answers in git with the reviewer named
in the commit message. A case the fork cannot fail is a policy sentence for the
synthesis, not a test.

The three the question implies, as a floor rather than a list to pre-author: the
value before the barrier is knowable, the value after, and a result returned
before the barrier became knowable which must not have changed.

## Boundaries

- The throwaway knowledge-dependent rule is **throwaway**. It is not a draft of
  instrument-narrowed expected sessions, which is scheduled for the next release
  on its own recorded reasoning, and must not be promoted into one.
- No hash ledger, registry, first-appearance record, gate mode or provenance
  machinery. Git is the ledger. Identity claims use ledgr's own primitives, or
  are labelled `proto:` once.
- Structural numbers from the small fixture never appear in a ranking, and this
  charter asks for no cost number at all.
- Nothing in `R/`, `src/`, `tests/`, `man/`, `NAMESPACE` or `DESCRIPTION`
  changes.

## What the first draft got wrong

Recorded so the narrowing is not re-proposed; the draft is in git.

It asked whether segmented preparation survives a pulse-scaled payload, treating
the semantic seam as settled. Probe P1 establishes only the diagonal, "January 3
as known January 3", where the question needs "January 3 as known January 7",
which nothing requests and `ledgr_run_explain()` cannot serve. Three supporting
defects: an unquantified kill condition, a lazy arm disqualified by the draft's
own viability criterion, and the cursor's backward re-seek cited from source
reading, which section 8 returns and probe P5 now executes.

## Terminal outcome

One page. What ran, what was learned about the package, what the synthesis may
consume, what remains open. Green, red or inconclusive in one sentence naming
the charter clause that decides it.

Two questions the charter expects to remain open, so the closeout does not
overclaim: what happens when a feature reads across instruments, since locality
arguments depend on per-instrument independence that cross-sectional features
break; and whether a forbidden output carry is handled by the same seam.
