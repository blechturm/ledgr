# Result Output Closeout

**Status:** Agent-provisional; awaiting independent Type 1 review.
**Date:** 2026-09-28
**Cut:** 18
**Workstream:** 25
**Tickets:** LDG-2869 and LDG-2880 through LDG-2884
**Baseline:** `ddb7076`
**Implementation:** `83b3cb2`, `00e4352`, `eff7937`, `3301b84`,
`5b92c1d` and `d4e127d`, plus this closeout record.

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
incomplete-prefix reference uses the real bars-only run with completion
evidence replaced at the reader boundary to describe an achieved prefix; the
existing review-lane LTB-0064 continues to exercise a real incomplete run.

| Reference | Method | Before | After |
| --- | --- | ---: | ---: |
| Bars only | `print(bt)` | 16 | 15 |
| Bars only | `summary(bt)` | 57 | 29 |
| Bars only | metrics print | 96 | 12 |
| Supplied cash fact | `print(bt)` | 16 | 15 |
| Supplied cash fact | `summary(bt)` | 57 | 56 |
| Supplied cash fact | metrics print | 96 | 12 |
| Incomplete-prefix reference | `print(bt)` | 16 | 15 |
| Incomplete-prefix reference | `summary(bt)` | 67 | 39 |
| Incomplete-prefix reference | metrics print | 96 | 12 |

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
  period presentation and incomplete-prefix labels.
- LTB-0108 protects answer-first summary order, compact absent-fact evidence,
  full-policy reachability and incomplete withholding. Existing LTB-0034
  protects the supplied-fact detail.
- LTB-0110 protects compact metrics output and proves printing leaves names,
  values, attributes, context and the unclassed list unchanged.
- LTB-0111 protects the three metadata formatting corrections and the stored
  elapsed value.

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
changed in this correction.

The final ordinary fast record selected and passed 479 of 479 blocks in
110.560 seconds, with no failures or skips. The independent checker returned
`LEDGR_TEST_GATE_OK` against the 112-second bound. Records are at:

`C:/Users/maxth/ledgr-research/.tmp/ws25-fast-final`

## Shape And Cost

The seven-shape hot-path walk and an interleaved product clock do not apply to
this workstream. The production changes are print, format and result-reader
boundaries invoked on demand; no ingest, seal, fold, hydration, finalisation
or per-row result-reconstruction path changed. LDG-2869 selects already
materialized columns, and the backtest period adds one constant-count aggregate
query per explicit print. The only scale-sensitive issue found was redundant
test fixture construction; it was removed before the final gate rather than
hidden behind a slower lane or a wider bound.

## Sequencing And Governance

The release gate waited. Workstream 25 follows accepted Workstream 24, blocks
Workstream 26, and Workstream 26 blocks Workstream 15. This lets the README and
all articles be corrected once against the final output surface.

The independent combined Type 1 and Type 2 cut review is one invocation. The
requested Type 1 close review will be the second over six completed tickets,
`2 / 6 = 0.333`, within the 0.5 gate. This closeout is agent-provisional until
the maintainer accepts that review.
