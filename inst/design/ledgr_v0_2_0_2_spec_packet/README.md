# v0.2.0.2 Packet: Test-Suite Cleanup

**Status:** Cut on 2026-09-21; ticket-cut review pending. This packet is the
pilot of the governance loop accepted the same day.

**Source of truth:** `tickets.yml` in this directory is the only ticket
authority. The workstream table below is a rendered view of it and is not
separately edited. There is no batch plan and no batch evidence essay.

## What this packet is

The five test-cleanup workstreams that the accepted testing-architecture
synthesis (`inst/design/rfc/rfc_testing_architecture_v0_2_0_2_synthesis.md`)
binds and says may implement directly without a further RFC. Their content
is the 930-row audit table at `788bd92`; their order is the audit's: oracle
repair, control plane, shrink, merge, delete. Nothing else in v0.2.0.2 is
cut here. The accounting-core consolidation RFC and the equity settlement
work follow after these workstreams land, in that order, not in parallel.

## Authorities

- `inst/design/rfc/rfc_testing_architecture_v0_2_0_2_synthesis.md` —
  the bound design and the five workstreams.
- `inst/design/rfc/rfc_governance_review_post_v0_2_0_1_synthesis_v2.md` —
  the loop this packet pilots: D1 briefs, D2 modes, D3 workstreams, D4
  artifacts, D8 gate.
- `inst/design/audits/post_v0_2_0_1_test_suite_audit.md` and its
  `_blocks.csv` — the block-level source for every ticket's scope.

## Workstreams

Twenty-eight tickets, LDG-2745 through LDG-2772. Each workstream gets one
Type 1 review at its close and opens only after the previous one closes.
With the ticket-cut review that is six review invocations: 6 / 28 = 0.21
against the pilot gate of at most 0.5.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 1 Oracle repair | 2745–2750 | 21 oracle repairs including the `engine_version` witness; the four graphics blocks; the warning muffle; the finalizer advisory; the eight red governance pins deleted with reasons | every repaired block fails on its stated defect; the suite is green |
| 2 Control plane | 2751–2760 | one runner with fail-closed selection; the two-sided census; profile tags for 23 homogeneous and 76 mixed files; the claims registry and checker; the canonical core into `fast`; CRAN mode; both gates; the control-plane mutation proof; `tests/README.md` | `fast` and CRAN run clean under budget with a reconciled census; gutted selection fails the gate |
| 3 Shrink | 2761–2765 | 134 fixture reductions across 50 files, cut by fixture family: sweep; experiment and run; availability; walk-forward and metrics; features, strategy, and cost | each reduced block's failure condition still fails under deliberate perturbation |
| 4 Merge | 2766–2770 | 77 merges across 37 files, cut by claim family: metrics; public behavior; identity and configuration; snapshot, features, and execution; determinism | no declared claim loses its detecting block; the overlap question answered per merge |
| 5 Delete | 2771–2772 | the remaining 67 `test-documentation-contracts.R` blocks: the render-freshness invariant rebuilt as a build step, then the file retired | the checker passes; the one real invariant runs somewhere that runs |

## Where the cut departs from the audit's disposition column

Two places, both because the synthesis binds a rule the audit predates.

The audit marks 49 `test-documentation-contracts.R` blocks *merge*. The
synthesis routes documentation surface pins to the render step, not to the
suite. Those 49 join the file's 26 deletions in Workstream 5, and the one
invariant among them that is real — rendered image targets exist and no
DuckDB notice leaked — is rebuilt as a build-step check before the file goes.
Merge therefore holds 77 blocks, not 126.

The audit marks `test-availability-fold-witnesses.R:74` as one of the 21
oracle repairs. The synthesis names it: keep the recorded `engine_version`,
exclude it from the economic comparison, never make it dynamic. It has its
own ticket so the rule is visible.

## Pilot counters

The closeout records: workstreams and review invocations; maintainer and
agent turns and heavy-command runtime attributable to governance; findings
by mode and whether each changed an outcome; reruns, rejected records, and
reopenings; retained governance files and lines; disputed classifications.
The gate is at most 0.5 review invocations per completed ticket, measured
at close. The closeout ends with a maintainer decision to promote, revise,
or abandon the loop.

## The cut review

One independent review under a two-question brief the maintainer writes:
does every requirement the synthesis binds have an owning ticket (Type 1),
and are the workstream grouping and review points sensible, including
whether twenty-eight is an honest grain (Type 2).

## Not in this cut

No test is edited before the cut review passes. No FIFO or equity ticket.
No spec document beyond this page; the synthesis is the spec.
