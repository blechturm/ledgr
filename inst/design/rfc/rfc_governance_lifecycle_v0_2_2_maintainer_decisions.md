# RFC Maintainer Decisions: Authority And Lifecycle Of Governance Documents

- Status: maintainer decisions, recorded 2026-10-13; binding inputs for the
  synthesis. Drafted by Claude from the maintainer's choices; the maintainer
  accepted the recommendations as stated here on 2026-10-13.
- Baseline: `ce32c0d7` (seed v2 and its census)
- Resolves: seed v2 Section 6, M1 and M2. Everything else in seed v2 stays
  the synthesis author's to weigh.

## M1. The review gate

**Decision: seed v2 option (b) now, with option (c) as the scheduled
reassessment, and the measurement defined now.**

1. The 0.5 gate is retired. The ratio is recorded, not gated.
2. One invocation is one independent verdict: a cut review, a workstream
   close review, a focused re-review or a final review, written by a
   reviewer that is not the implementing agent's session. An agent-run
   review of an agent's own cut counts separately and is labelled as such;
   it never enters the independent count.
3. The denominator is completed tickets. A dropped ticket is excluded from
   both counts.
4. The ratio appears once per cut, at cut close, with the counts it is made
   of, and once more as a packet total at closeout. It is not restated in
   ticket or workstream fields.
5. The other D8 counters stay, recorded at the same two points: findings by
   mode and whether each changed an outcome, and maintainer decision turns.
6. Escalation: a third correction round on one workstream stops and goes to
   the maintainer, who decides whether the ticket, the implementation or
   the brief is wrong.
7. Reassessment: owner the maintainer; trigger the v0.2.2 closeout; inputs
   the counts above measured under this definition for every v0.2.2 cut;
   dispositions keep, revise or drop, recorded in `rfc_cycle.md` where the
   pilot text now stands (lines 249-251 at the baseline).

Why: the ratio breaches at every denominator (81 over 98 completed tickets;
11 of 13 cuts), so as a gate it rewards nothing, and the breaches include
the correction rounds that found this release's defects. The number is still
the cost signal, so it is kept and made comparable. Rejected: keeping 0.5
measured per packet, because the packet figure also breaches; deciding at
closeout without a definition, because the closeout could not then count.

## M2. Where consequential review findings live

**Decision: seed v2 option (a).**

1. A review that returns findings writes a file in the owning packet, named
   for its review point in the existing pattern (`cut_review_13.md`;
   `close_review_27.md` for a workstream close review).
2. The `tickets.yml` review field holds the verdict, the link and one line
   on what changed. A `PASS` with no findings is that one line, no file.
3. The rule applies from the first review after this synthesis is accepted.
   Closed tickets and past review fields are not rewritten; they stay
   records.

Why: findings are what the "changed an outcome" counter counts, cut reviews
already work this way, and a finding inside a YAML field cannot be cited by
line. Rejected: findings in the field with an optional file, because the
counter would then have two homes.

## Directions for the synthesis

Endorsed by the maintainer with the decisions above; they are inputs, not
product decisions.

- Guard scope is the census's governance scope (top-level `inst/design`,
  all of `rfc/`, `manual/`, the current packet), not "current-release
  records"; the stale v0.1.8 headers the pipeline cites are only caught in
  that scope.
- Check mode starts after the sweep normalizes record headers, not merely
  one cut after report mode.
