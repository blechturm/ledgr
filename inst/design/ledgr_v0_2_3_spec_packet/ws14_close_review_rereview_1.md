# Workstream 14 focused close re-review

**Mode:** Type 1, clean-context review by Claude Opus 4.6 with high effort.

**Reviewed tree:** `9f9e86f9`

**Verdict:** `PASS_AFTER_PATCHES`

The six findings from the first close review are resolved. The unified
execution architecture, semantic detectors, exact-output gates, identity
refusals and milestone records hold. No Type 2 issue remains. Six focused
record and detector patches are required before acceptance.

## Required patches

1. **Stale public help.** The corporate-action result help still described a
   removed dense-only raised condition, and the precompute help still said a
   fixed-basket feature series starts at the scoring boundary. Both clocks now
   use the unified stop outcome and shared causal-history start.
2. **Incomplete branch census.** Two result readers branch on the prepared
   execution-clock kind. The census prefilter saw only the former
   availability tokens, so those branches were absent from the record and
   disposition table. Extend the shared scanner and its synthetic detector,
   then regenerate the two mode-branch census files.
3. **Weak aggregate real-data checker.** The checker compared common columns
   but did not refuse an unexpected extra column. Assert exact column-set
   differences: only `diagnostics` may be candidate-only in the sweep record,
   and the walk-forward tables may have no unexpected columns.
4. **Unmatched phase-attribution methods.** The base record used an installed
   package while the candidate record used `load_all()`. Rerun the exact
   candidate from its installed library and quote that matched record.
5. **Missing public negative coverage control.** The migrated private-seam
   tests pin their private failure class. Add a public `ledgr_run()` case that
   proves a post-opening rectangular gap still refuses with
   `LEDGR_SNAPSHOT_COVERAGE_ERROR`.
6. **Incomplete performance routing.** The bar-native wide cell is faster
   than v0.2.2 but 1.588 times slower than the post-WS4a attribution base.
   Route it with the other red bar-native cells to WS5 and WS14.

## Clean areas

- No compatibility path, dense fold, alternate planner or alternate context
  implementation was reintroduced.
- Rule-4 stored identities refuse; rule 5 remains current-only.
- The focused semantic, carrier, result and documentation suites pass.
- The fast, review and heavy profiles, source build, package check and private
  aggregate controls have complete records.
- The timing records retain every economic control and the peer smoke record
  classifies unavailable peers rather than omitting them.

The patches above do not alter the accepted architecture or product behavior.
A focused clean-context confirmation is sufficient after they land.

## Focused confirmation 1

**Reviewed range:** `9f9e86f9..06d1fc44`

**Verdict:** `CHANGES_REQUIRED`

The aggregate checker, matched attribution record, public coverage control and
performance routing are resolved. Two corrections remain:

1. The corporate-action help still contained a second reference to the
   removed dense-only raised condition. The history-unavailable condition also
   still said fixed-basket contexts have no causal history.
2. The mode scanner recognized the clock resolver but not direct
   `clock_kind`, `$clock_kind` or local aliases. It therefore missed clock
   branches in substrate construction, precompute and sweep execution.

These are documentation and detector corrections, not product or design
changes. The reviewer also independently confirmed the strengthened private
aggregate checker against the existing record; the maintainer-side run and
unexpected-column mutation had already passed before this review.

## Focused confirmation 2

**Reviewed range:** `06d1fc44..2bd5baa7`

**Verdict:** `PASS`

Both residuals are resolved. The generated corporate-action and condition
help matches its source and the unified behavior. A fresh census matches both
committed CSVs, every owner has a disposition, and the synthetic detector
fails when the symbol, field or alias support is removed. No compatibility
path, fallback, product behavior or second execution path was added.

One non-blocking note is routed to macro WS12 documentation debt:
`ledgr_pulse_snapshot()` still describes its experiment form as
availability-aware even though a fixed-basket experiment supplies history.
It does not affect the implemented API or this workstream's oracles.
