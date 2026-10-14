# Workstream 30 Focused Re-review 1

**Mode:** Type 1 focused re-review  
**Range:** `a4d31cda..69d81c47`  
**Verdict:** `CHANGES_REQUIRED`  
**Date:** 2026-10-14

All twelve findings from the first close review are closed in the product.
The correction round left four medium findings. No finding reopens the
accepted current-only design.

## Findings

1. **N1: the metric-fallback detector could not fail.** LTB-0265 used two
   pulses one year apart, which the removed inference path and the current
   default both annualized to 252. Weekly pulses are required so the removed
   path infers 52 and disagrees with the explicit default.
2. **N2: malformed current valuation policy changed condition.** The current
   policy-schema guard inspected the full policy shape before ordinary shape
   validation. A schema-2 record with an invalid field therefore raised the
   misleading policy-schema condition instead of the existing
   `ledgr_invalid_valuation_policy` condition and constructor message.
3. **N3: the current-only census overclaimed alias resolution.** Five restored
   legacy comparisons hidden behind local aliases passed check mode, including
   the literal `availability_close_v1` convention. The registered behavioral
   tests caught the important paths. The census claim must be narrowed to
   directly extracted comparisons, retain a literal guard for
   `availability_close_v1`, and make its self-test exercise source extraction.
4. **N4: typed-missing telemetry lacked a detector.** Forcing
   `telemetry_missing` to `FALSE` passed the suite even though the closeout and
   LDG-3028 evidence claimed that missing telemetry was covered. A real stored
   run with its telemetry row deleted must return typed missing values and set
   `telemetry_missing = TRUE`.

## Low-severity observations

- Dead missing-policy branches in terminal and corporate-action code conflict
  with the current-only rule and should be removed.
- LCL-0248 is now review-profile, so the fast lane has no refused snapshot-hash
  rule detector. This is recorded, not made part of the focused correction.
- A local fast-record path must not be presented as durable committed evidence.

## Maintainer disposition

Under the accepted M1 lifecycle, this is Workstream 30's second review round.
The maintainer directed Codex to make the mechanical fixes with recorded
mutation witnesses and to stop for maintainer acceptance rather than request a
third correction review. Review counts are recorded once at Cut 14 close.
