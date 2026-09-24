# Settlement Axis Density Spike Inventory

**Status:** Executed inventory; non-binding.
**Date:** 2026-09-23

## Question And Fork

The spike asked whether a hidden non-member recipient can be sealed on the
physical axis without pre-entitlement bars, become held at its first real bar,
and complete the public availability workflow without backfill.

The runner copied tracked package source to scratch and added one seam before
availability valuation. At pulse three the seam applied and persisted the
previously measured positive operation-3 event for `CHILD`. Everything after
that seam was ordinary `ledgr_run()`: provider resolution, valuation, equity,
finalization, durable results and reopen.

## Recorded Results

The complete-history control and late-start arm both reached `DONE`. Each
produced five equity rows, one child ledger row, a final child position of two,
positions value of 40 and final equity of 100040. Equity, availability and
ledger surfaces were identical after excluding run and event identities; the
maximum numeric difference on every surface was zero.

In both arms the child had zero availability rows before entitlement. Its first
row was the entitlement pulse, with `member = FALSE`, `held = TRUE`,
`priced = TRUE` and `mark_source = current_close`. Reopened equity and
availability were identical to the original result surfaces.

The boundary case, with the first child bar one pulse after entitlement, failed
before producing result surfaces. It raised `ledgr_config_non_finite` while
serializing non-finite diagnostic detail. This is a package observation, not a
repair made by the spike. It still rejects an unpriced received holding, but
through a lower-level error than the intended valuation stop.

## Demoted

The seed-v4 response's claim that all axis instruments require bars at every
pulse is demoted from blocker to an over-broad source inference. The cited
row-count guard is not the path taken by this public availability run. The live
run supplies a ragged bar matrix and fold equity to finalization.

The Sharadar prerequisite result should be described as post-event coverage,
not as proof by itself. Combined with this ledgr execution, however, absence of
pre-event bars is not a density blocker when the first real bar exists as the
holding becomes effective.

## Deleted From The Working Theory

- Fabricated or backfilled pre-entitlement prices are not required.
- A recipient need not have complete history across the experiment window.
- The static-axis design need not be rejected because of the cited finalizer
  branch.

## Learned

- Physical presence does not imply strategy visibility. The child stayed
  absent while it was neither a member nor held.
- A held non-member enters the provider axis and values at its current real
  close.
- Ragged pre-holding history and a complete-history control produce identical
  persisted surfaces at this shape.
- A valid mark is still required when the holding becomes effective.
- Durable finalization and reopen preserve the result.

The spike did not test recursive closure, off-axis recipients, negative parent
legs, group serialization or real settlement terms.

## Gut Demonstration

The checker disabled the sole injection condition in the scratch fork. All
three arms then had zero child ledger rows, zero child position, no child
availability rows and final equity 100000. `cases.csv` changed, so the checker
failed the recorded evidence loudly. The seam was not written to package
source.

## Containment

The runner and checker use temporary package copies and DuckDB stores. Package
and design status is compared before and after the rerun and gut. No production
file, test, namespace, dependency, manual page or prior RFC artifact is edited.
