# Closeout: Two-Clock History Spike

**Verdict: red on size; green on semantics.** Every historical answer is right
with the resolution rules unchanged, and the diagonal equals the shipped
provider. But segment count is not bounded by the facts: facts that only
append cost about three segments each, and facts that restate a long span
make it grow about as short facts times long facts. Section 6 stops the spike
and returns it to the maintainer.

Run 2026-10-08 against the unchanged package code of `9452e9e`. Artifacts in
`dev/spikes/two-clock-history/`.

## What ran

- **Representation:** bitemporal segments (charter section 3). For each
  knowledge epoch the facts are filtered to those known by then and handed to
  the unchanged prepared provider and membership resolver; a segment is
  written only when an epoch changes an effective interval. Built once,
  before any query; no SQL or filtering per query.
- **Cases:** retracted halt, a supersession chain, a cross-source precedence
  tie, a membership snapshot correction, a late-known membership interval, an
  incomplete snapshot later completed, a late-known lifetime fact, the
  diagonal over ten days for each, and (case 9, added after the first
  closeout) growth when long facts restate many short ones.
- **Gut:** answering with the shipped diagonal collapses every late-knowledge
  row to today's answer while the diagonal still passes.

## What was learned about the package

- **The semantics need no new rule.** 16 of 16 `(s, t)` answers match the
  frozen v11-derived answers; the diagonal is 10 of 10 on every fixture.
- **Size grows with restatement, not with facts.** Append-only: about 3
  segments per fact (each fact splits the open tail into three). With 20
  short facts and 20 long restating facts on one instrument: 883 segments, 22
  per fact. Each restating fact rewrites every interval it covers. Merging
  adjacent equal states would help when the restater dominates, but not when
  a low-precedence fact fills many gaps (reasoned, not run).
- **The default status depends on row presence.** With no fact applicable,
  the provider answers `unknown` if the status family has rows and `active` if
  it has none. Shipped code is safe: an empty family is refused at
  construction. A history filter creates the empty case, so the
  representation must carry declaration itself. Not a rule change.
- **The status conflict check disagrees with the resolver on chains.** The
  resolver drops every superseded fact; the check excuses only direct
  supersession pairs, so a one-source chain of three different statuses is
  refused. Likely a validation defect. Supersession across sources is refused
  by design.
- **Reads:** a `k`-column window read costs `k` interval lookups.

## What the spec may consume

Proposals for the WS3 history interfaces, not decisions:
1. Bitemporal segments give the right answers with the existing rules. Their
   size is acceptable only if restatement is rare per instrument; that needs
   counting on real (Sharadar) facts before it is relied on.
2. A prepared history representation must carry family declaration
   explicitly.
3. Fix or contract the chain refusal before WS3 relies on correction chains.

## What remains open

- Recharter: measure restatement depth on real facts, or try a
  representation that stores facts once and resolves at read time (which the
  current charter's kill condition 2 forbids).
- Bytes, revision counts and seek cost on the real cursor (not measured).
- Sessions and corporate actions as known at `t` (charter section 8).
- An independent review of the frozen answers in `expected.csv`.
