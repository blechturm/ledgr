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
end (`R/availability-provider-prepared.R:102-108`), so the retraction, known on
day 8 for an interval that closed on day 6, gets an empty segment. It appears
at none of the probed cutoffs, and by that construction at no cutoff. A
history read on day 8 or later that looked back at day 4 could not see that
the halt was withdrawn. This is the defect
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

Each family is re-timed and resolved separately, so the membership refusal is
recorded on its own row and does not hide the other answers. For trading
status and lifetime the re-timed answers match what v11 section 3
demands: the retraction applies to day 4 once known, and BBB's inactivity
applies to day 5 once known. For membership the trick fails outright: moving
the correction onto the original's effective and knowledge time makes the
constructor refuse with "Each membership snapshot group must resolve to
exactly one `set_id`". Knowledge time is part of how a membership correction
is identified and ordered, so a history representation must keep both clocks;
it cannot collapse one into the other.

## P3. Lifetime refuses the one correction shape tried

A lifetime assertion followed by a contradicting one for the same effective
time, learned later, is refused at construction with
`ledgr_fact_structural_conflict` ("Lifetime facts cannot assert incompatible
overlapping states"). Trading status has `supersedes_fact_id`; membership
uses later-known complete sets; lifetime offers neither for this shape. Only
this same-time contradiction was tried; other lifetime revision shapes are
untested. Whether that is a deliberate contract or a gap belongs to the
semantic question, not to a representation.

## What a charter may consume

- The detecting case exists and is cheap: one superseded halt shows the
  diagonal losing a revision, with expected answers fixed by v11 section 3.
- The trading-status rule reads only the applicable fact set (supersession,
  then precedence, in the prepared provider's `resolve_status`); P2 shows
  supersession giving the right historical answer once the set is chosen by
  `(s, t)`. Precedence ties were not exercised.
- Membership needs knowledge time inside its ordering, so `(s, t)` selection
  must filter on knowledge while keeping knowledge in the sort key.
- The tried lifetime revision is refused at construction; the spike must not
  invent a revision rule for lifetime.
- Only trading status, membership snapshots and lifetime were probed.
  Membership intervals use their own segment start
  (`R/availability-provider-prepared.R:47`), and sessions and corporate
  actions carry knowledge times too; none of these was exercised here.

**Scale:** two instruments and ten sessions are a semantic fixture, not a
size measurement. Per protocol section 9 nothing here ranks representations.
