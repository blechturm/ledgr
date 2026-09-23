# Atomic Class B Settlement Spike Inventory

## Question

Can one grouped operation consume parent lots, create on-axis recipient lots,
and apply a caller-supplied model-basis allocation atomically through the
fold, replay, interruption, and reopen?

## What ran

One seam after ordinary pulse accounting accepted a prototype group. The group
was fully validated against live lot state before one schema-compatible event
row was appended. The prototype used `CASHFLOW` with a `proto:` discriminator
only to exercise persistence; it does not decide production vocabulary.

| Case | Observed result |
| --- | --- |
| Pure stock exchange | Parent 5 became zero; child 2.5 received all 50 model basis. |
| Spin-off | Parent stayed 5 with basis 40; child 2.5 received basis 10. |
| Two recipients | Parent became zero; quantities 2.5 and 1.25 received basis 37.5 and 12.5. |
| Existing recipient | Child grew from 1 to 3.5 across two live lots; total basis stayed 70. |
| Malformed allocation | Failed before append; parent state and basis stayed intact. |
| Short recipient | Failed before append rather than crossing the short lot. |
| Resume and reopen | One grouped event survived interruption, resume, and reopen. |
| Compiled arm | Refused explicitly before append; no silent drop. |
| Two parent lots | Both parent lots became two child lots; their total basis 52 was preserved. |

## Demoted, deleted, and learned

Demoted: the earlier RED operation-3 result as evidence that Class B itself is
unrepresentable. It proved only that an opening-lot insertion cannot consume
existing lots.

Deleted from the working theory: that a multi-leg transformation necessarily
requires several persisted rows. One validated group fit in one row and replay
applied it as one operation.

Learned: the current lot carrier can support pure-stock and spin-off shapes
without a different state representation. A caller must still supply the
model-basis fractions; the spike does not derive them.

## Gutted path

The checker disabled parent-lot consumption while leaving recipient creation
active. The basis-preservation invariant failed before append, changing the
pure-stock case from `DONE` with one event to `ERROR` with zero events.

## Limits

Cash or mixed consideration, fractional-unit policy, taxes, off-axis
valuation, final event vocabulary, and compiled execution remain undecided.
This is a feasibility result, not production authorization.
