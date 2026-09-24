# Charter: Settlement Quantity Primitive Spike

**Status:** Charter, pre-probe. Binds nothing.
**Author:** Claude. **Date:** 2026-09-23
**Protocol:** `inst/design/spike_protocol.md`
**Feeds:** the equity-settlement RFC synthesis. It is not part of it.

## 1. Why this exists

Seed v2 reserves a new top-level `SETTLEMENT` ledger event type for
transitions that mutate quantity or lots. Both seeds and both Type 2
responses assumed that type is necessary. None checked whether the
primitive already exists.

Reading the source says it does. `R/accounting-replay.R:153-167` maps a
`CASHFLOW` whose meta carries `source = "opening_position"` to operation
3, requiring a finite `position_delta` and a finite `cost_basis` and
failing closed if either is malformed. `R/lot-accounting.R:367-372` is
the FIFO side. That is quantity injected into an instrument at a
declared basis, with no trade, no price and no fill.

A settlement is that operation with a different source tag.

**This charter cites a code read, not an execution.** Under protocol
section 1 that is not yet admissible evidence. Case 1 below executes it,
and every later case depends on case 1 passing. If case 1 fails, the
charter's premise is wrong and the spike closes red in one sitting.

## 2. The question

> Can a settlement be expressed as an operation-3 event emitted during a
> fold, or does it require a new ledger event type?

That is the whole question. The spike answers it by running the package.

## 3. The cheaper prerequisite

> Does the fold's event path accept an operation-3-shaped event emitted
> at a pulse, rather than before the fold, at all?

Operation 3 is emitted today by `R/fold-event-buffer.R` before the fold
runs, never during it. Mid-run emission is the untested half. If the
answer is no, the main question cannot be asked and the spike stops.

## 4. Kill and recharter condition

The spike stops and returns to the maintainer if mid-run emission needs
changes to the fold event path beyond a single injection seam, measured
as one diff inside the 500-line correction budget.

That outcome is a finding, not a failure: it is the evidence synthesis
needs to justify a new event type, which is what seed v2 already assumes.

Two outcomes that are **not** kill conditions:

- the compiled arm dropping the event silently. That is the expected
  confirmation of F6 in the Type 2 response and belongs in the closeout;
- a leg failing without preserving the prefix. That is the atomicity
  finding the spike exists to surface.

## 5. Runnable core, then cases

Order is fixed by protocol section 3. Build the smallest fork that can
emit one operation-3 event at one pulse, run it, and let its failures
generate the cases. No expected table is written before the fork exists.

The probe inputs, capped at nine:

1. Operation 3 emitted before the fold. Baseline; confirms the read.
2. The same shape emitted mid-run at a pulse carrying no fill.
3. Mid-run, at a pulse carrying a fill on the same instrument.
4. Positive `position_delta` into an instrument holding nothing. The
   spin-off child shape.
5. Negative `position_delta` taking a held position to zero. The
   extinguished-parent shape.
6. Two legs at one timestamp bound to one source identity. The
   multi-leg spin-off shape.
7. Leg two malformed after leg one applied. Does the prefix survive?
8. Case 2 under `compiled_accounting_model = "spot_fifo"`.
9. Resume and reopen across a mid-run operation-3 event.

Cases 7 and 9 are expected to be the informative ones. Any case the
fork cannot fail is a policy sentence for the spec, not a test.

## 6. Deliverables

Per protocol section 6, exactly three:

- a runner that writes evidence CSVs, one row per case, derived from
  fold output rather than narrated;
- a checker that reruns into a scratch directory, diffs against the
  recorded CSVs, and guards that nothing landed in `R`, `src`, `tests`,
  `NAMESPACE`, `DESCRIPTION`, `man` or `inst/design`;
- a one-page inventory naming what was demoted, deleted and learned.

The gutted path is the operation-3 branch itself: remove the
`opening_position` source test in `R/accounting-replay.R` inside the
spike tree and show the evidence change. One gutted path, not a suite.

Harness lives in `dev/spikes/settlement_quantity_primitive/`, which is
untracked. The fork may edit `R/` inside the spike working tree; the
checker's job is to prove none of it lands.

## 7. Budgets

| Artifact | Budget |
| --- | --- |
| This charter | 150 lines |
| Spike harness, all R | 1,500 lines |
| Any single correction diff | 500 lines |
| Closeout | one page |
| Review rounds per artifact | two |

Over budget is a stop-and-talk, not a review request.

## 8. What this spike does not decide

It does not choose the daily visibility or payment convention, write any
basis derivation, specify the sealed fact schema, touch the Sharadar
adapter, rerun the census, or cut a ticket. It does not decide whether
Tier 2 ships in v0.2.0.2.

It answers one question so that synthesis knows whether it is designing
a new ledger event type or reusing an existing operation. Those are
different documents, and that is the only reason this runs first.

## 9. Closeout

One page: what ran, what was learned about the package, what the spec
may consume, what remains open. Green, red or inconclusive stated in one
sentence naming the section 2 or section 3 clause that decides it.
