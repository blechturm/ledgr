# v0.2.0.2 Packet: Test-Suite Cleanup

**Status:** Cut on 2026-09-21. Cut review (`cut_review.md`) returned
`PASS_AFTER_PATCHES` at `6d37eeb`; patched in place. Workstream 1 opens on
the maintainer's word. This packet is the pilot of the governance loop
accepted the same day.

**Source of truth:** `tickets.yml` in this directory is the only ticket
and sequencing authority. The workstream table below is a rendered view of
it and is not separately edited. There is no batch plan and no batch
evidence essay.

## What this packet is

The five test-cleanup workstreams that the accepted testing-architecture
synthesis (`inst/design/rfc/rfc_testing_architecture_v0_2_0_2_synthesis.md`)
binds and says may implement directly without a further RFC. Their content
is the 930-row audit table at `788bd92`; their order is the synthesis's:
oracle repair, control plane, shrink, merge, delete. Nothing else in
v0.2.0.2 is cut here. The accounting-core consolidation RFC and the equity
settlement work follow after these workstreams land, in that order, not in
parallel.

## Authorities

- `inst/design/rfc/rfc_testing_architecture_v0_2_0_2_synthesis.md` —
  the bound design and the five workstreams.
- `inst/design/rfc/rfc_governance_review_post_v0_2_0_1_synthesis_v2.md` —
  the loop this packet pilots: D1 briefs, D2 modes, D3 workstreams, D4
  artifacts, D8 gate.
- `inst/design/audits/post_v0_2_0_1_test_suite_audit.md` and its
  `_blocks.csv` — the block-level source for every ticket's scope.

## Workstreams

Thirty-one tickets, LDG-2745 through LDG-2775; IDs are stable and the
`workstream` field, not the ID range, places a ticket. A workstream opens
only when the previous one's review is accepted; ticket dependencies are
intra-workstream. With the cut review that is six review invocations:
6 / 31 = 0.19 against the pilot gate of at most 0.5.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 1 Oracle repair | 2745–2750, 2773 | 21 oracle repairs including the `engine_version` witness; the four graphics blocks; the warning muffle; the finalizer advisory; the eight red governance pins deleted with reasons; the four bound rules applied to the twelve mock files and seven frozen fixtures | every repaired block fails on its stated defect; no mock supplies what its block asserts; the suite is green |
| 2 Control plane | 2751–2760 | one runner with fail-closed selection and named heavy protocols with owners; the two-sided census; profile tags for 23 homogeneous and 76 mixed files; the claims registry and checker; the canonical core into `fast` and extended parity registered in `review`; CRAN mode; both gates with `review` unconditional at release; the control-plane mutation proof; `tests/README.md` | `fast` and CRAN run clean under budget with a reconciled census; gutted selection fails the gate; no registered claim rests only on optional-dependency skips |
| 3 Shrink | 2761–2765 | 134 fixture reductions across 50 files, cut by fixture family: sweep; experiment and run; availability; walk-forward and metrics; features, strategy, and cost | each reduced block's failure condition still fails under deliberate perturbation |
| 4 Merge | 2766–2770, 2774 | 126 merges: 77 across 37 files by claim family — metrics; public behavior; identity and configuration; snapshot, features, and execution; determinism — and the 49 documentation-surface blocks, each merged into its claim family with an executable oracle or deleted with its own reason | no declared claim loses its detecting block; the overlap question answered per merge; every one of the 49 has a named outcome |
| 5 Delete and closeout | 2771, 2772, 2775 | the 18 remaining replace-then-delete pins: one current-state artifact and link check built in a bound lane, then the pins deleted; the packet closeout with the pilot counters and clocks | the checker passes; the replacement runs where the census sees it; the closeout states the ratio and the maintainer's decision on the loop |

## Where the cut departs from the audit's disposition column

One place. The audit marks `test-availability-fold-witnesses.R:74` as one
of the 21 oracle repairs. The synthesis names it: keep the recorded
`engine_version`, exclude it from the economic comparison, never make it
dynamic. It has its own ticket so the rule is visible.

The first cut also rerouted the 49 documentation-surface merges to a
render-step check. The cut review refused that: the synthesis binds 126
merges and 26 deletions and says nothing about a render step, and the 49
carry heterogeneous guarantees — runnable examples, installed help paths,
public journeys — that one freshness check cannot replace. They are back in
Merge under LDG-2774, with per-row outcomes required.

## What the cut review added

Owners for the synthesis's 2.5 rules (LDG-2773), the D5 review questions
(`review_obligations` in `tickets.yml`), heavy-protocol ownership
(LDG-2751), optional-dependency coverage (LDG-2755, LDG-2757), the
unconditional release run of extended parity (LDG-2756, LDG-2758), the
closeout (LDG-2775), and workstream gating in the YAML itself. The review's
two preferences — folding the mutation proof into the gate ticket and the
README into the closeout — are noted and not taken; it called them
preferences, not findings.

## Pilot counters

The closeout (LDG-2775) records: workstreams and review invocations;
maintainer and agent turns and heavy-command runtime attributable to
governance; findings by mode and whether each changed an outcome; reruns,
rejected records, and reopenings; retained governance files and lines;
disputed classifications. The gate is at most 0.5 review invocations per
completed ticket, measured at close. The closeout ends with a maintainer
decision to promote, revise, or abandon the loop.

## Not in this cut

No test is edited before workstream 1 opens. No FIFO or equity ticket. No
spec document beyond this page; the synthesis is the spec.
