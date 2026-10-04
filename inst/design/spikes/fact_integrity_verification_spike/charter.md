# Charter: Exact Fact Integrity Verification Spike

**Status:** Executable charter; binds nothing.
**Author:** Codex. **Date:** 2026-10-04
**Protocol:** `inst/design/spike_protocol.md`
**Feeds:** v0.2.2 macro-plan WS5 or one bounded internal ticket.

## 1. Question

> Can repeated timestamp formatting be removed from exact fact-family and
> rule-2 snapshot verification while preserving every existing hash and
> corruption failure?

That is the only question.

## 2. Cheaper Prerequisite

Does formatting distinct timestamps once preserve the current family and
bundle hashes while materially reducing `ledgr_facts_assert()` time?

The prerequisite probe answered yes: 30,000 membership rows fell from 0.31 to
0.06 seconds, with identical hashes.

## 3. Fork

The scratch fork changes only the timestamp-token helper used while building
canonical fact frames. It formats each distinct non-missing instant through
the retained scalar helper, then maps those exact tokens back to rows.

It may not trust a stored digest, cache a mutable fact object as verified,
change JSON, change a hash rule or bypass a table read.

## 4. Cases And Gate

The runner measures in-memory membership bundles at 6,000, 30,000 and 300,000
rows and one sealed rule-2 snapshot at 300,000 rows. It also mutates one fact
row after construction.

GREEN requires exact family, bundle and snapshot hashes, the same corruption
failure, and at least 2x lower median exact-assertion time at 300,000 rows.
Otherwise the spike is RED. This is the only gate.

## 5. Kill Condition

Stop if exactness requires a hash-version, schema, persistence or verification
policy change. That belongs to the WS5 RFC rather than this implementation
spike.

## 6. Deliverables And Gut

Exactly three executor deliverables:

- `spike_runner.R`, writing deterministic cases plus timing CSVs;
- `spike_checker.R`, rerunning into scratch, diffing deterministic evidence and
  guarding package scope;
- `spike_inventory.md`, naming what was demoted, deleted and learned.

The gut maps repeated instants to the wrong token. The stored fact hash must no
longer validate, and the deterministic case record must change.

The closeout is the protocol's one-page terminal record.

## 7. Non-Goals And Budgets

No verification policy, snapshot identity, schema, cache, public API or
resolver changes. Harness: 1,500 R lines; correction: 500 lines; charter: 150
lines; closeout: one page. An overrun stops the spike.

