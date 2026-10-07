# Closeout: Two-Clock History Spike

**Verdict: red on the size kill condition; green on semantics.** Every
historical answer is right with the resolution rules unchanged, and the
diagonal equals the shipped provider. But segments written exceeded twice the
fact rows on four of seven fixtures (worst: three per fact row), so section 6
stops the spike and returns it to the maintainer.

Run 2026-10-08 against the unchanged package code of `9452e9e`. Artifacts in
`dev/spikes/two-clock-history/`.

## What ran

- **Representation:** bitemporal segments (charter section 3). For each
  knowledge epoch the fixture's facts are filtered to those known by then and
  handed to the unchanged prepared provider and membership resolver; a segment
  is written only when an epoch changes the state of an effective interval.
  Built once, before any query; no SQL or filtering per query.
- **Cases:** retracted halt, a supersession chain, a cross-source precedence
  tie, a membership snapshot correction, a late-known membership interval, an
  incomplete snapshot later completed, a late-known lifetime fact, and the
  diagonal over ten days for each fixture.
- **Gut:** answering with the shipped diagonal collapses every late-knowledge
  row to today's answer (cases 1, 2 and 4 on named rows, among others) while
  the diagonal still passes.

## What was learned about the package

- **The semantics need no new rule.** Sixteen of sixteen `(s, t)` answers match
  the frozen v11-derived answers, and the diagonal is 10 of 10 on every
  fixture.
- **Family declaration must be carried apart from fact rows.** The prepared
  builder infers "trading status is declared" from row presence, so filtering
  to early knowledge turns `unknown` into `active`. The spike carries the
  declaration separately. The executor reads this as a representation need,
  not a resolution-rule change (kill condition 1); the maintainer decides.
- **Size is bounded by the facts, but not by twice them.** Each fact splits
  the effective axis into before, during and after, so it can open three
  segments, not two. The charter's constant assumed one segment per fact.
- **Fact-model limits:** supersession stays within one source; a one-source
  chain of three different statuses is refused as a structural conflict.
- **Reads:** a `k`-column window read costs `k` interval lookups.

## What the spec may consume

These are proposals for the WS3 history interfaces, not decisions:
1. Bitemporal segments answer v11 section 3 with the existing rules, built
   once before the fold. The size bound to state is about three segments per
   fact row, not two; whether that is acceptable is the maintainer's call.
2. A prepared history representation must carry family declaration
   explicitly, not infer it from rows.
3. The two fact-model limits above should be stated in the contract, or
   lifted, before WS3 relies on correction chains.

## What remains open

- Whether to accept the observed three-per-fact bound or recharter (kill
  condition 3 fired).
- Bytes, revision counts and seek cost on the real cursor (not measured).
- Sessions and corporate actions as known at `t` (charter section 8).
- An independent review of the frozen answers in `expected.csv`.
