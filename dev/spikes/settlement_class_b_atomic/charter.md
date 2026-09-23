# Charter: Atomic Class B Settlement

**Status:** Executable bounded spike. Binds nothing.
**Date:** 2026-09-23

## Question

Can one validated grouped accounting operation consume existing parent lots,
create one or more on-axis recipient lots, and apply a caller-supplied model-
basis allocation atomically through fold, replay, interruption, and reopen?

## Prerequisite

The current lot carrier must preserve total basis for one direct pure-stock
exchange and one direct spin-off transformation. If either fails, stop before
adding a fold seam.

## Kill condition

Stop if the runnable core needs more than one fold injection seam or cannot
represent the group as one persisted row. The spike does not choose final
ledger vocabulary or basis policy.

## Scope

At most nine observed cases: pure stock, spin-off, two recipients, existing
recipient holding, malformed allocation, short recipient, interruption and
reopen, compiled refusal, and multiple parent lots. Cash consideration,
fractions, taxes, and off-axis valuation remain outside this question.
