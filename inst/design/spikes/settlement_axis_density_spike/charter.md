# Charter: Settlement Axis Density Spike

**Status:** Executable charter; binds nothing.
**Author:** Codex. **Date:** 2026-09-23
**Protocol:** `inst/design/spike_protocol.md`
**Feeds:** the equity-settlement RFC after seed v4.

## 1. Why This Exists

The Type 2 response to seed v4 says that a recipient starting to trade
mid-window cannot sit on ledgr's sealed physical axis because finalization
requires one bar per axis instrument and pulse. Source inspection also shows
that availability runs carry ragged matrices and fold-supplied equity facts.
Those readings disagree. The package must decide the question by execution.

The prerequisite probe built one scratch fork before this charter recorded
cases. It found that both a complete-history control and a late-start recipient
reached `DONE`. The record run now freezes the outputs that produced that
question, rather than an expected answer written from source.

## 2. The Question

> Can the current public availability run support a non-member recipient that
> is sealed on the physical axis, has no bars before entitlement, becomes held
> at its first real bar, and completes finalization and reopen without invented
> history?

That is the only question.

## 3. Cheaper Prerequisite

Can a sealed snapshot contain an axis instrument whose bars start after the
experiment begins while complete membership facts keep it outside the strategy
universe?

The runnable fork answered yes before the evidence cases were frozen. Snapshot
construction and sealing accepted that shape without a package edit.

## 4. Fork And Comparison

One scratch-only seam injects the already measured positive operation-3 shape
before valuation at pulse three. It updates state and persists the event, then
the ordinary availability fold, finalizer, result readers and reopen path run.

The two comparison arms differ only in child history:

- complete control: child bars exist for all five pulses;
- late start: child bars begin at the entitlement pulse.

Both carry the child on the sealed physical axis. Complete membership facts
contain only the parent, so the child remains a non-member. The child becomes
visible only if the injected holding makes the ordinary provider include it.

A third observed boundary case starts child bars one pulse after entitlement.
It was added after the fork ran; it is not a third design alternative.

## 5. Kill And Recharter Condition

Stop if the question needs more than the one pre-valuation injection seam or
requires a production-package edit outside the scratch fork. That would mean
axis density cannot be isolated from settlement design.

## 6. Evidence

Evidence comes from `ledgr_run()` and its persisted result surfaces:

- terminal status and equity;
- ledger replay position;
- availability visibility, membership, holding and mark source;
- reopened equity and availability identity;
- surface parity between the complete and late-start arms.

Fixture labels identify cases. They are not counted as evidence. No licensed
data, vendor value or corporate-action meaning enters the spike.

## 7. Deliverables And Gut

Per protocol section 6, exactly three executor deliverables:

- `spike_runner.R`, writing `cases.csv` and `parity.csv`;
- `spike_checker.R`, rerunning, byte-diffing and guarding package scope;
- `spike_inventory.md`, naming what was demoted, deleted and learned.

The gut disables the single injection branch. It must change recorded evidence
for the child position and visibility without touching the source tree.

The closeout is the protocol's one-page terminal record.

## 8. Non-Goals

This spike does not choose settlement vocabulary or serialization, prove a
negative parent leg, design basis allocation, test transitive recipient
closure, change membership, or authorize release scope. It does not repair any
error discovered beyond the one question.

## 9. Budgets

The harness stays below 1,500 lines of R, any correction below 500 lines, this
charter below 150 lines and the closeout to one page. Overrun stops the spike.
