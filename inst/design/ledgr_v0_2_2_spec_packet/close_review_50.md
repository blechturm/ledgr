# Workstream 50 close review

Mode: Type 1, independent clean-context Codex review.

Product range: `e7e5264a..34234f37` on `codex/ws50-closeout`.
Research range: `7124eaa..e58fc69` on
`claude/sharadar-dividends-v004`. Macro-plan handoff: `30f28ad6`.

## Verdict

CHANGES_REQUIRED. The behavioral record was adequate, but three bounded
corrections were required by the research repository's native-guarantee rule.
No Type 2 design issue was found.

## Findings

1. The research worker reconstructed entitled holdings by replaying FILL and
   DISPOSITION rows even though ledgr's public ledger, availability result,
   CASHFLOW `entitled_quantity` and corporate-action summary own that state.
   G-016 and G-025 used the duplicate reconstruction.
2. The setup and checker pinned a raw DuckDB-file SHA beside ledgr's verified
   native snapshot hash, duplicating snapshot-integrity authority.
3. Retiering LTB-0471..0473 shifted test lines without refreshing the committed
   helper census.

The smallest corrections are to use native ledgr result surfaces, remove the
raw snapshot SHA and refresh `helpers.csv`. The reviewer found no product
defect in LDG-3091.

## Clean evidence

- LTB-0471..0473 passed with 88 expectations. Restoring either scalar timestamp
  parse or removing the composition count made its detector fail.
- The research checker passed. A fresh aggregate M1-M13 run killed every
  single-record mutation, including M10 changing 26 DONE folds to 25.
- The corrected walk-forward reports 26 of 26 folds DONE in 458.67 seconds.
- Both timing arms ran 573 of 573 blocks. Base median 114.15 seconds;
  candidate median 113.65 seconds; ratio 0.996. Both miss the unchanged
  112-second bound, so this proves no WS50 regression, not a gate pass.
- LDG-3084's article, consumer-proof, exclusion-versus-intent, WS8 and deferred
  modernization handoffs are accurate.
- YAML, diff checks and privacy scans were clean. No private workload or full
  suite was run by the reviewer.

## Maintainer disposition

On 2026-10-23 the maintainer accepted the unchanged absolute timing miss as a
no-regression result, without widening the bound or moving further tests. The
exhausted fast-lane headroom remains routed to WS8. The three review findings
were accepted for mechanical correction and coordinator verification; this is
not yet the Workstream 50 acceptance record.
