# Closeout: Two-Clock History Spike

**Verdict: red on size; green on semantics.** Every historical answer is right
with the resolution rules unchanged, and the diagonal equals the shipped
answers. But segment count is not linear in facts: a low-precedence fact that
fills gaps under many short facts rewrites every gap, so segments grow about
as short facts times long facts, even when adjacent equal states are merged.
Section 6 stops the spike and returns it to the maintainer.

Run 2026-10-08 against the unchanged package code of `9452e9e`. Artifacts in
`dev/spikes/two-clock-history/`. Independently reviewed 2026-10-08
(PASS_AFTER_PATCHES; patches applied).

## What ran

- **Representation:** bitemporal segments (charter section 3). For each
  knowledge epoch the facts are filtered to those known by then and handed to
  the unchanged prepared provider and membership resolver; a segment is
  written only when an epoch changes an effective interval. Built once,
  before any query; no SQL or filtering per query.
- **Cases:** retracted halt; a supersession chain whose answer differs if a
  superseded fact revives; a cross-source precedence tie; a membership
  snapshot correction; a late-known membership interval; an incomplete
  snapshot later completed; a late-known lifetime fact; the diagonal over ten
  days for each; and (case 9, added after the size kill fired, at the
  maintainer's go-ahead) growth under restatement.
- **Diagonal:** status and lifetime compare with the fold's prepared
  provider; membership with the inspection resolver and the fold's prepared
  membership.
- **Gut:** answering with the shipped diagonal collapses every late-knowledge
  row to today's answer while the diagonal still passes.

## What was learned about the package

- **The semantics need no new rule.** 16 of 16 `(s, t)` answers match the
  frozen v11-derived answers; the diagonal is 10 of 10 on every fixture.
- **Size.** The charter's two-per-fact constant was miscalibrated: any
  segment layout needs about three per appended fact (before, during, after),
  and case 9 measures 3.05 to 3.2. Restatement is the real cost:

  | 20 short + 20 long facts | segments | merged |
  | --- | --- | --- |
  | long facts outrank the short ones | 883 | 83 |
  | long facts sit under the short ones | 483 | 483 |

  Merging adjacent equal states fixes the first; nothing in this
  representation fixes the second.
- **Family declaration must be carried apart from rows.** The provider's
  no-fact default keys on row presence (`unknown` with rows, `active`
  without), as the v0.2.0.1 spec requires; shipped code is safe because an
  empty family is refused at construction. A history filter creates the empty
  case. Not a rule change: in any constructible snapshot, declared and
  non-empty coincide.
- **Chains are validated and resolved differently.** The v0.2.0.1 spec
  (section 4.2) exempts only direct supersession pairs from the conflict
  check, so three statuses at one precedence in one source are refused; the
  resolver drops every superseded fact and handles chains. The spec never
  addresses chains: a contract gap, not a confirmed defect.

## Sharadar census (after closeout, at the maintainer's request)

`sharadar_census.R` over the private lake, aggregates only
(`evidence/sharadar_census.csv`):
- **No restatement is observable.** One acquisition; S&P 500 membership is
  the only family with a knowledge column, and it is synthetic: effective
  date plus exactly one day, at both ends. No later-known interval overlaps
  an earlier-known one. Corporate actions and lifetime carry no knowledge
  time; trading status has no facts.
- **Real size: 2.61 segments per fact** (5,030 for 1,925 facts over 1,180
  instruments; at most 3 per instrument). 1,146 instruments have one
  interval, 34 have two.
- **An honest end cannot be expressed as intervals.** "Member from day 1,
  known day 2; removed day 10, known day 11" as two open facts is refused as
  a structural conflict: an interval row holds one knowledge time, so its end
  must be known when its start is. Membership snapshot sets avoid this.

## What the spec may consume

Proposals for the WS3 history interfaces, not decisions:
1. Bitemporal segments give the right answers with the existing rules, and
   on the data ledgr actually holds they cost under three segments per fact.
   Gap-filling restatement stays quadratic per instrument but does not occur
   in that data.
2. A prepared history representation must carry family declaration
   explicitly.
3. Decide whether supersession chains are valid before WS3 relies on them.
4. Two-clock membership needs snapshot sets, or an interval fact whose end
   can become known later.

## What remains open

- Restatement on real data is unmeasured: it needs a second Sharadar
  acquisition diffed against `20260905T092008Z`.
- Bytes, revision counts and seek cost on the real cursor (not measured).
- Sessions and corporate actions as known at `t` (charter section 8).
