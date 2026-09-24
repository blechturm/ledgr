# Addendum to Type 2 Response v2: Equity Settlement

**Status:** Addendum, read-only. Binds nothing.
**Author:** Claude. **Date:** 2026-09-23
**Extends:** `rfc_equity_settlement_post_v0_2_0_2_response_v2.md`
**Occasioned by:** the settlement quantity primitive spike closeout.

## 1. Why this is separate

Response v2 was written before the spike ran. Its findings are frozen
against ground that has since moved. This records what moved.

It is a separate file rather than an edit because the reviewed document
sits at its line budget, and because a reversal produced by new evidence
should be a dated event in the record rather than a silent revision.

## 2. What the spike established

Operation 3, the opening-position CASHFLOW at `R/accounting-replay.R:153`,
can be emitted mid-fold, persisted, resumed and reopened. It is a lot
insertion primitive only. `ledgr_lot_apply_opening()` appends
unconditionally and has no consumption branch, so a negative delta taking
a held position to zero leaves two opposing live lots rather than closing
the chain.

Two consequences follow that the closeout does not state.

**No realized profit or loss.** `ledgr_lot_add_realized()` is reached only
from the fill path. An extinguishment through operation 3 reports net
position correctly and realizes nothing. The gain disappears silently.

**Basis reallocation does not exist.** A spin-off splits an existing cost
basis between parent and child. The opening path only ever adds quantity
times basis to the running total. It cannot reduce the parent. A negative
and positive pair does not emulate it, because both append and neither
rewrites the chain.

## 3. What this changes in response v2

**Section 5 is narrower than written.** It placed cash acquisitions in
Tier 1 on the reasoning that cash-only consideration is cheap. A cash
acquisition extinguishes a position, so it needs consumption and
realization. It sits on the far side of the same wall as a stock
acquisition. Tier 1 is dividends and pure distributions, nothing else.

**Seed v2's B4 is falsified for that subtype.** Its falsifier was a
cash-only case needing quantity or lot mutation that cannot be
represented without a settlement transition. A cash acquisition is one.

**Section 6 gains a scenario.** A spin-off whose parent basis must be
reduced. No primitive exists, and inserting the child at zero basis
fabricates a basis that overstates its later realized gain.

## 4. What this does not change

Findings F2 through F5 stand unaltered: the recipient epoch mismatch, the
rounded price quotient, the vacuous positivity check, and the missing bar
vintage binding. The spike touched none of them.

The section 4 boundary adjudication stands. The adapter and core split
survives intact and nothing here reaches it.

F1 remains withdrawn. F6 is now observed rather than argued: the compiled
arm completed with status DONE and no event, no error and no diagnostic.

## 5. A Type 2 opinion, offered as an opinion

The tier partition cuts on recipient location, which answers whether a
received thing can be valued. The spike says the binding constraint is
which lot operation an event needs. Those are independent dimensions and
the table tracks only the first.

My view is that the release boundary should be cut on the second, with
the axis tiers retained for the valuation question where they are
correct. I offer that as a reviewer's position. The seed author is free
to reject it and derive a different structure from the same evidence.

## 6. Revised disposition

The earlier disposition accepted seed v2 with bound conditions. That
judgement was correct on the evidence then available and is now stale.
The seed's tier partition and ledger vocabulary predate a measurement
that contradicts them. This is new ground, not a changed reading of the
seed's reasoning.

TYPE_2_DISPOSITION: REVISE_SEED
