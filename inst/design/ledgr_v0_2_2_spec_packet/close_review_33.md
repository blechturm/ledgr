# Workstream 33 Close Review

**Role:** record
**Status:** working
**Authority:** Independent Type 1 close review of Cut 15 Workstream 33,
implementation range `1cbc5166..99775513`.
**Reviewed:** 2026-10-15.
**Verdict:** CHANGES_REQUIRED.

The implementation establishes stable contract addresses and accounts for the
whole decision bridge, but seven bounded documentation defects require a first
correction round. None requires a maintainer design decision.

## Findings

### F1 - Cost arithmetic is reversed

`contracts.md` says execution price is rounded before fees. The shipped
resolver in `R/cost-model.R` computes notional fees from the
spread-adjusted, unrounded price and rounds the exposed fill price separately
to eight digits by default. `test-cost-model.R` pins that order. Correct the
contract and its reconciliation row.

### F2 - Zero-price terminal dispositions are omitted

The fill-validity clause says every accepted price is positive.
`ledgr_lot_apply_fill()` accepts zero only through the internal
`allow_zero_price = TRUE` path used by terminal `DISPOSITION` events. State the
ordinary positive-price rule and that sole zero-price exception exactly.

### F3 - Removed bridge anchors break inbound links

Eleven inbound links target seven removed decision anchors. Preserve
locator-only `Removed` stubs for execution-window minimum, fill-transition
validity, cost rounding and fees, walk-forward snapshot override, equity
corporate actions, testing architecture and accounting-core consolidation.
Each stub names its receiver but carries no authority or editable obligation.

### F4 - Two bridge dispositions overclaim contract consolidation

The testing-architecture and accounting-core rows say their full designs moved
to contract groups that state only a subset. Either add faithful standing
clauses if the omitted material is current contract material, or classify the
rows as corrected or transferred to exact durable owners. Verify the testing
runner and gate records and the accepted accounting synthesis and production
implementation; do not duplicate editable obligations.

### F5 - Bridge exit timing is too broad

The new introduction allows ordinary early removal. Restore the rule that
bridge rows ordinarily leave at release closeout. Cite governance-synthesis
Section 4 as one-time authority for Workstream 33 to close already-consolidated
rows, not as a general early-exit rule.

### F6 - The real-tree bridge oracle is overstated

The report-only governance guard cannot parse the new bridge table until
Workstream 35 normalizes it. Do not claim that it validates the real bridge.
Compare the exact contract backlink group set independently for every retained
row; deleting any one of OMS's three backlinks must fail. Attribute the
real-tree conclusion to the reconciliation and independent review, leaving
guard/table alignment to Workstream 35.

### F7 - One historical identity phrase remains

Replace `pre-Cut-10 identity` with the present-tense rule: `"fail"` sessions
omit the no-selection policy from identity, while other policies include it.

## Nits

- The retained OMS and objective-filtered rows have no open ticket owner; say
  that explicitly and let their pipeline rows route future work.
- The roadmap points at the removed snapshot-verification anchor. That file is
  owned by Workstream 34 and is not part of this correction.

## Verified clean

- All 13 H2 contract routes and all 81 explicit H3 rule-group IDs exist and
  remain stable when an unrelated paragraph is inserted.
- All 15 pre-change decision rows are represented in the reconciliation.
- The focused suites pass 1,381 expectations.
- The report-only guard scans 319 sources and reports 1,115 existing findings.
- No product source file changed in the reviewed range.

The workstream remains unaccepted pending correction and focused independent
re-review.
