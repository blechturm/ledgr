# Result Output Closeout

**Status:** Agent-provisional; awaiting independent Type 1 review.
**Date:** 2026-09-28
**Cut:** 18
**Workstream:** 25
**Tickets:** LDG-2869 and LDG-2880 through LDG-2884
**Baseline:** `ddb7076`
**Implementation:** `83b3cb2`, `00e4352`, `eff7937`, `3301b84`,
`5b92c1d`, `d4e127d` and correction `3ccb3a3`, plus this closeout
record.

## Outcome

The ordinary backtest print is now a one-screen result. It reports the run,
period and principal performance answers without exposing the internal
execution mode. The summary puts performance before evidence and collapses an
unused corporate-action policy to the two required warnings plus a pointer to
the public full-policy accessor. A metrics object prints as a compact table.
Run-info and extracted-strategy labels are aligned, and elapsed time is
formatted at the print boundary without changing its stored value.

LDG-2869 joins this cut from its Cut 16 deferral. Curated shared-table prints
now apply only while the complete schema is present. A caller-selected table
keeps the caller's columns and order instead of silently restoring the
curated view. The five intact consumers retain their previous print content.

## Output Size And Content

The same fixtures were run at the pre-cut baseline and after the cut. The
original incomplete-prefix reference replaced completion evidence at the
reader boundary. The correction record uses the real availability-aware
incomplete run from heavy-protocol LTB-0064 instead.

| Reference | Method | Before | After |
| --- | --- | ---: | ---: |
| Bars only | `print(bt)` | 16 | 15 |
| Bars only | `summary(bt)` | 57 | 29 |
| Bars only | metrics print | 96 | 13 |
| Supplied cash fact | `print(bt)` | 16 | 15 |
| Supplied cash fact | `summary(bt)` | 57 | 56 |
| Supplied cash fact | metrics print | 96 | 13 |
| Real incomplete run | `print(bt)` | 16 | 15 |
| Real incomplete run | `summary(bt)` | 67 | 40 |
| Real incomplete run | metrics print | 96 | 13 |

The supplied-fact summary deliberately remains detailed. The compact path is
only for a run to which corporate-action facts were not supplied. Both
ordinary prints retain these exact warnings:

```text
Corporate actions: NOT SUPPLIED - returns may omit distributions
Price basis: UNDECLARED - distribution double counting cannot be ruled out
```

The combined cut review decided that this block may collapse to those two
lines plus `ledgr_corporate_action_summary(bt)`. That exported accessor returns
the complete sealed policy record, identities, counts, totals and omitted-
value information. The same review decided that metric sections may precede
evidence. Metric order inside those sections and the incomplete-run rules from
`contracts.md` remain unchanged.

## Detectors

- LTB-0106 protects selected-column fidelity and unchanged intact-table
  output for the shared curated printer.
- LTB-0107 protects the one-screen backtest result, its values, warning lines,
  period presentation and incomplete-prefix labels. It also proves that
  printing does not call the full metrics replay and compares the lightweight
  closed-trade count with canonical accounting replay on two reversals.
- LTB-0108 protects answer-first summary order, compact absent-fact evidence,
  full-policy reachability and incomplete withholding. Existing LTB-0034 now
  protects exact absent-policy settings and identities as well as supplied-
  fact detail.
- LTB-0110 protects compact metrics output and proves printing leaves names,
  values, attributes, context and the unclassed list unchanged. It also binds
  the printed object's persisted-prefix scope.
- LTB-0111 protects one aligned value column across both metadata prints and
  the unchanged stored elapsed value.

Restoring the old print branches, restoring the full absent-fact block,
removing the metrics method or restoring the metadata defects makes the
owning detector fail. The final focused suites for result output,
corporate-action results, run telemetry, backtest S3 behavior and exports all
pass.

## Fast Gate

The first valid ordinary fast record ran three times at 115.730, 116.850 and
103.930 seconds. Its 115.730-second median exceeded the 112-second bound even
though all blocks passed. Profiling the new detectors found redundant
DuckDB-backed setup in three blocks. Their oracles were retained while literal
in-memory objects replaced setup that the assertions did not test; existing
public-path blocks continue to own those boundaries. No production code was
changed in that gate-only correction.

The correction record selected and passed 479 of 479 blocks in 97.480 seconds,
with no failures or skips. The independent checker returned
`LEDGR_TEST_GATE_OK` against the 112-second bound. Records are at:

`C:/Users/maxth/ledgr-research/.tmp/ws25-correction-fast`

## Shape And Cost

The first closeout incorrectly exempted explicit result readers from the
seven-shape walk. Its first implementation called `ledgr_compute_metrics()`
from `print(bt)`, replaying every fill through FIFO lot accounting. The close
review measured 0.62 seconds at 6,294 fills and 1.97 seconds at 31,514 fills,
versus 0.11 and 0.12 seconds before the cut.

The correction uses one DuckDB window aggregate for the equity headline and
one ledger query followed by a single event-order pass with an integer
instrument index. The pass holds only current numeric positions, parses no
FILL JSON, never scans open lots and parses metadata only for non-FILL
events to identify position changes. Its cost is O(pulses) in DuckDB plus
O(events) in R. On an
interleaved 100-instrument clock it printed in 0.11 seconds at 6,200 fills and
0.28 seconds at 31,400 fills; closed-trade counts exactly matched
`ledgr_compute_metrics()` at both sizes. This restores the small-shape baseline
and removes the nonlinear lot-replay mechanism without claiming constant cost.

LDG-2869 still selects already materialized columns. The first valid fast
record's redundant test fixture construction remains a test-only correction;
it was removed without moving evidence to a slower lane or widening the bound.

The metrics object deliberately remains a persisted-prefix measurement object:
its values and attributes do not gain completion state. Its print now says to
use `summary(bt)` for completion-aware withholding and achieved-prefix labels.
Summary spacing now has exactly one blank before completion evidence and one
before corporate-action evidence.

The metadata-bearing Experiment Store, Reproducibility and Research Workflow
articles were regenerated here. Quickstart, Strategy Development, Custom
Indicators, Corporate-Action Cash, Sweeps, Metric Contexts And Conventions,
and the concurrent README rewrite remain the explicit Workstream 26
documentation handoff; they are not silently claimed current by this closeout.

## Sequencing And Governance

The release gate waited. Workstream 25 follows accepted Workstream 24, blocks
Workstream 26, and Workstream 26 blocks Workstream 15. This lets the README and
all articles be corrected once against the final output surface.

The independent combined Type 1 and Type 2 cut review, the first close review
and the requested focused re-review total three invocations over six completed
tickets, `3 / 6 = 0.500`, at the gate. This closeout remains agent-provisional
until the maintainer accepts the focused re-review.
