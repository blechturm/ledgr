# Charter: Snapshot Hash Rule-3 Conformance Spike

**Status:** Executable charter; binds nothing.
**Author:** Codex. **Date:** 2026-10-12.
**Protocol:** `inst/design/spike_protocol.md`.
**Feeds:** snapshot-verification RFC synthesis, WS5-A.

## 1. Question

> Can seed v2's exact rule-3 candidate produce one portable root with bounded,
> near-linear cost at the shapes v0.2.2 must support?

That is the only question. The spike does not choose different bytes.

## 2. Cheaper Prerequisite

Can one R-owned column-major block be encoded without per-row calls and below
one microsecond per bar at 500,000 rows?

The seed-v2 review answered yes in a scratch probe: 0.32 microseconds per row
for the column-major block, versus 0.96 for the rejected row-major layout.

## 3. Runnable Fork

The smallest fork is a standalone R encoder under
`dev/spikes/snapshot_hash_rule_3_conformance/`. It implements seed v2 Section
5 without modifying package code. Its first run emits one dense root from one
instrument block, one bar block and the canonical empty fact record.

Only after that run may the executor select and freeze at most ten cases from
seed v2's golden-corpus menu. Expected roots, the checker and the gut are not
written before the fork runs.

## 4. One Gate

GREEN requires all of the following as one conformance gate:

- the selected deterministic roots are identical on Windows and Ubuntu;
- insertion order, fetch size, DuckDB threads and repeated processes do not
  move a root, while each selected covered-value mutation does;
- the base bar path costs at most one microsecond per row at the largest
  registered shape and has endpoint exponent at most 1.10 over 0.5, 1, 2 and
  5 million rows; and
- the encoder stays block-bounded, with whole-process peak RSS and the retained
  fact-JSON peak reported separately.

Any failed clause makes the spike RED. Timing noise is reported, not used to
change the gate.

## 5. Kill Condition

Stop and return to the RFC if the exact candidate needs a second
canonicalization engine or materializes instruments or bars beyond one logical
block. The retained fact projection is measured separately under the seed's
B4 and does not itself trigger this kill condition.

## 6. Deliverables and Gut

Exactly three executor deliverables:

- `spike_runner.R`, writing deterministic and measured evidence CSVs;
- `spike_checker.R`, rerunning into scratch, diffing deterministic evidence and
  guarding package scope; and
- `spike_inventory.md`, naming what was demoted, deleted and learned.

The gut changes one byte-order assertion so a hostile input is accepted in the
wrong order. The deterministic evidence or the checker must fail.

The closeout is the protocol's one-page terminal record.

## 7. Containment and Budgets

No production code, tests, contracts, tickets, schema, hash marker or public
API changes. No private Sharadar data. Harness: 1,500 R lines; any correction:
500 lines; charter: 150 lines; closeout: one page. An overrun stops the spike.
