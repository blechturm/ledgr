# Probe findings: two-clock history

**Ran:** 2026-10-07, `dev/spikes/two-clock-history/probe.R` at `9452e9e`.
Evidence in `probe_evidence.csv`. **Purpose:** spike protocol section 1, before
the charter. Binds nothing; no package file changed. Provider calls are
internal and labelled so; fact construction, sealing and
`ledgr_facts_resolve()` are public.

**Fixture:** one sealed snapshot, ten open sessions, two instruments, three
late-known facts:
- a trading halt on AAA for days 3-5, known on day 3, retracted on day 8 by a
  fact that supersedes it for the same interval;
- BBB `known_inactive` from day 4, learned only on day 9;
- a complete membership set {AAA, BBB} from day 1, corrected to {AAA} for the
  same effective day by a set known on day 7.

## P1. The shipped lookup answers only the diagonal

Asked at decision day `t` about day `t` itself, the prepared provider and
`ledgr_facts_resolve()` behave causally:

| Day | AAA status | BBB lifetime | Members |
| --- | --- | --- | --- |
| 2 | unknown | unknown | AAA+BBB |
| 4 | halted | unknown | AAA+BBB |
| 5 | halted | unknown | AAA+BBB |
| 8 | unknown | unknown | AAA |
| 9 | unknown | known_inactive | AAA |

There is no call that answers "day 4 as known on day 8". The prepared segments
start at the later of effective and knowledge time and end at the effective
end, so the retraction, known on day 8 for an interval that closed on day 6,
**never appears at any cutoff**. A history read on day 8 or later that looked
back at day 4 could not see that the halt was withdrawn. This is the defect
v11 section 7(b) names: a diagonal-only lookup fails the detecting case.

## P2. Re-timing facts to reuse the unchanged resolvers is not enough

The cheapest reuse idea keeps the facts known by `t`, sets each one's
knowledge time to its effective time, rebuilds, and resolves at `s` with the
unchanged provider:

| (s, t) | AAA status | BBB lifetime | Members |
| --- | --- | --- | --- |
| (4, 5) | halted | unknown | AAA+BBB |
| (4, 8) | active | unknown | refused |
| (5, 9) | active | known_inactive | refused |

For trading status and lifetime the re-timed answers match what v11 section 3
demands: the retraction applies to day 4 once known, and BBB's inactivity
applies to day 5 once known. For membership the trick fails outright: moving
the correction onto the original's effective and knowledge time makes the
constructor refuse with "Each membership snapshot group must resolve to
exactly one `set_id`". Knowledge time is part of how a membership correction
is identified and ordered, so a history representation must keep both clocks;
it cannot collapse one into the other.

## P3. Lifetime cannot express a correction

A lifetime assertion followed by a contradicting one for the same effective
time, learned later, is refused at construction with
`ledgr_fact_structural_conflict` ("Lifetime facts cannot assert incompatible
overlapping states"). Trading status has `supersedes_fact_id`; membership
uses later-known complete sets; lifetime has neither. Lifetime can carry
late-known facts but not revisions. Whether that is a deliberate contract or
a gap belongs to the semantic question, not to a representation.

## What a charter may consume

- The detecting case exists and is cheap: one superseded halt shows the
  diagonal losing a revision, with expected answers fixed by v11 section 3.
- Supersession and precedence for trading status are pure functions of the
  applicable fact set; P2 shows the existing rule gives the right historical
  answer once the applicable set is chosen by `(s, t)`.
- Membership needs knowledge time inside its ordering, so `(s, t)` selection
  must filter on knowledge while keeping knowledge in the sort key.
- Lifetime revisions are not expressible today; the spike must not invent a
  revision rule for them.

**Scale:** two instruments and ten sessions are a semantic fixture, not a
size measurement. Per protocol section 9 nothing here ranks representations.
