# Edge-checks spike, 2026-11-06

**Question.** How fast is today's fold if ledgr checks only where data or
code enters from outside, plus the strategy output, and trusts its own
modules (response review D1-D4,
`inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_response_review.md`)?
**Kill condition:** if the edge tree's ledger, equity or diagnostics differ
from the pin on a valid run, it measures a different program and the spike
stops.

**Outcome: green.** With the internal re-checks removed, the fold loop is
29 percent faster on momentum (1,954 to 1,389 us per pulse) and 17 percent
faster on fill-heavy (5,988 to 4,984), with byte-identical results tables,
and a strategy returning a missing target is still refused.

## What ran

- `patch.R` copies the pinned tree (`d5b3a151`) and removes the internal
  re-checks on the per-pulse path by exact text replacements, each required
  to match once (`evidence/patches.csv`):
  - every carrier group check (`ledgr_carrier_new()`): stage hand-offs, the
    publication block, legs, staging and equity;
  - the append check on write in the output handler (D4);
  - the fill payload's input and execution-epoch checks;
  - the lot kernel's self-check of its applied rows;
  - P5's two cash and exposure reconciliations (the staged reconciliation
    row stays).

  Kept: the strategy's targets, intent and sizing notes; post-risk and
  short-exposure checks; history request checks; preparation's data checks;
  the lot kernel's input check and overflow refusals; diagnostic staging,
  which is redesigned separately; the read check. The repository's `R/`
  does not change.
- `worker.R` runs one tree on one workload in its own R process (two trees
  cannot share a session) and records the fold's `t_loop`, the run's wall
  time, the ledger, equity and diagnostics tables of its first run, and what
  a strategy returning a missing target raises.
- `run.R` alternates pinned and edge workers per workload, two rounds of
  three timed runs after a warm-up run, High performance plan, P-core
  affinity; it also runs a gut tree (the edge tree with one staged
  diagnostic value changed) once.
- `check.R` reruns with one round and one repetition, diffs `patches.csv`,
  `parity.csv` and `edge.csv`, checks the timing rows, requires the gut tree
  to differ and guards package scope.

## Result

Median of six runs per tree and workload (`evidence/timing.csv`).

| | momentum 40 x 504 | fill-heavy 500 x 1,260 |
| --- | ---: | ---: |
| fold loop, pinned (us per pulse) | 1,954 | 5,988 |
| fold loop, edge checks only | 1,389 | 4,984 |
| saved per pulse | 565 (29%) | 1,004 (17%) |
| whole `ledgr_run()`, pinned (s) | 1.39 | 9.24 |
| whole `ledgr_run()`, edge checks only | 1.20 | 7.99 |

Parity (`evidence/parity.csv`): the edge tree's ledger (296 and 67,725
rows), equity (504 and 1,260) and diagnostics (2,500 and 699,040) are
identical to the pin's. The gut tree's diagnostics differ, so the
comparison can fail. Both trees refuse a strategy returning a missing
target with `ledgr_invalid_strategy_result` (`evidence/edge.csv`).

## What was learned about the package

- Internal re-checks cost more than the check-cost probe's estimate (252
  and 729 us per pulse), because that probe left out the payload checks,
  the lot kernel's self-check and the two P5 reconciliations: removing all
  of them saves 565 and 1,004 us.
- On valid runs nothing depends on these checks: removing them changes no
  ledger row, equity value or diagnostic row.
- The user boundary is unaffected: bad strategy output is refused with the
  same class.
- What the edge tree does not catch any more is a defect in ledgr's own
  modules that the tests miss (response finding 6, accepted in D1).
- The remaining per-pulse cost of fill-heavy is the stages' work: about
  5 ms. Diagnostic staging (about 450 us, unchanged here) is the next
  plumbing item.

## What the spike leaves out

Refusal paths (no faulted runs beyond the strategy edge), sweeps and
walk-forward, the durable `live` mode, the compiled FIFO, and the diagnostic
staging redesign. The edge tree is a measurement fork of today's fold, not
a proposal for it: the old fold stays the frozen oracle, and the lean core
builds the same rule in.
