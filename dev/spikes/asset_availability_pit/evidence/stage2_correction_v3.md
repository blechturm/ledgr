# Stage 2 Witness Correction V3

**Status:** Maintainer-approved and independently reviewed 2026-09-07.

**Prior evidence:** `asset_availability_witness_v2` at commit `b818d76`.

**Affected witnesses:** W02 and W22. M1 is the only affected mutation.

## W02 Package Coverage Error

The v2 W02 `c0a` expectation named `ledgr_missing_bars`. Independent Stage 3
review ran the frozen missing-bar fixture through `ledgr_run()` and found that
the actual preflight condition is `LEDGR_SNAPSHOT_COVERAGE_ERROR`. The
corrected expected value and reason code use that package class.

The W02 `c0b` arithmetic was correct but had not been observed through the
package. Stage 3 now runs both `c0a` and `c0b` through `ledgr_run()`. The
complete-data control observes A01 sold before A02 is bought, final cash
15000, final equity 40000, and no affordability rejection.

## W22 And M1 Observability

The v2 W22 `c1` table did not contain execution-bar availability, fill price,
or fill status. M1 therefore could not mutate a genuine observed packet and
was incorrectly implemented by appending rows.

V3 changes the synthetic S3 A02 execution open from 50 to 52 while retaining
the stale decision-time valuation mark of 50. Both W22 `c0` and `c1` now
record:

- `execution_bar_available = true`;
- `fill_price = 52`; and
- `fill_status = filled`.

Their cash after execution changes from 95000 to 95200. M1 mutates the existing
`c1` rows to `execution_bar_available = false` and `fill_price = 50` while
leaving `fill_status = filled`. The checker must reject both value mismatches
and emit `stale_execution_price`. It adds no evidence rows.

## Policy And Provider Effect

Policy v4 is unchanged. W02 `c0a` corrects a package error-class label; W22
separates an execution price from a stale valuation mark so the already
approved no-stale-execution principle is testable.

Every implementation of W02 and W22 must be rerun after approval. No Stage 3
implementation has been committed and no Stage 4 provider exists.

## Approval

- Maintainer approver: repository maintainer, approved 2026-09-07.
- Independent correction reviewer: Claude, accepted 2026-09-07.
- Active Stage 2 evidence commit: pending commit.
