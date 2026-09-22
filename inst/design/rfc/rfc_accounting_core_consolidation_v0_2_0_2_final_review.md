# Final Review: Accounting-Core Consolidation For v0.2.0.2

**Mode:** Type 1 final review.
**Reviewer:** Codex.
**Date:** 2026-09-22.
**Reviewed artifact:**
`rfc_accounting_core_consolidation_v0_2_0_2_synthesis.md`, including both
maintainer amendments.

## Verdict

`PASS_AFTER_PATCHES`. I found no design problem requiring Type 2. The bound
carrier, consolidate-first direction, one-preparer decision, ownership
boundary, and sequencing remain intact. Four fidelity or evidence defects
must be corrected before maintainer acceptance.

## Required Patches

### F1 - The memory-buffer contract omits three auxiliary fields

Section 3.3 says memory differs from `ledger_events` only by `cash_delta` and
`position_delta`. `sweep.R:1534-1549` contains the eleven schema columns plus
five memory fields: those two, `event_realized`, `event_cost_basis`, and
parsed `meta`. Materialization keeps the eleven common columns and carries all
five as attributes at `sweep.R:1661-1665`.

This does not defeat one preparer: the eleven source columns are common. Patch
3.3 to name all five, state that replay-output attributes are not authoritative
inputs, and define whether the preparer consumes or independently checks the
already-parsed memory `meta`. Keep the block-equality witness over the prepared
contract, not over ignored source auxiliaries.

### F2 - D5 would not detect the rescan it is meant to prevent

D5 fails only on "superlinear growth in per-event cost." A basis or net scan
inside each write is O(depth) per event, not superlinear per event. Inventory
section 9 demonstrates exactly that forbidden shape: basis cost rises roughly
linearly from 45 us at depth 50 to 695 us at depth 800. D5 could therefore pass
with the old rescan restored.

Patch D5 to reject material positive depth dependence in normalized per-event
cost, using a preregistered noise allowance, and require a mutation that
reintroduces a write-path rescan and makes the detector fail. It remains a
failure-sensitive scaling detector; a timing ceiling alone is still
insufficient.

### F3 - The exact carrier's 3.23 us attribution is not reproducible

The inventory records an "index-addressed queue" and a 3.23 us prototype, but
does not preserve its runner or specify the synthesis's exact per-instrument
`lot_qty`/`lot_price`, head/tail, growth, and compaction carrier. I can confirm
the same primitive queue family, not that the exact bound carrier produced the
number. Section 3.1 does correctly disclose vector copy-on-modify and its
possible `collapse::setv` escape.

Patch line 110 to call 3.23 us a related prototype result, or preserve and run
the exact prototype before attributing the measurement to this carrier. The
production-validation profile in section 6 remains the release evidence.

### F4 - Three citation ranges need correction

- Chunked replay initializes state at `backtest-fills.R:134` and updates it at
  line 236; line 136 does neither.
- The fold computes deltas at `fold-engine.R:882-887` but updates positions and
  cash at lines 888-889.
- The ignored fallthrough is `lot-accounting.R:301`, not line 300.

All other explicit line references in sections 1-3 resolve to the stated code.

## Independent Verification

I reverified the three corrections that originated in my Seed v2. The durable
fills reader is the only listed driver using `dbFetch(..., n = 50000)`;
`ledger_events` admits FEE and not FILL_PARTIAL; and `mirai` invokes the worker
which constructs opening lot state at `sweep.R:1382`, so no built lot state
crosses the worker boundary.

For one instrument, two buys then two sells, five runs of 10,000 cycles gave a
median 24.75 us per fill. Separate two-lot net and basis scans measured 2.75
and 4.00 us. This reproduces the load-bearing result: current shallow cost is
about 30 us and most of the 28x claim was not scan removal. Exact microsecond
figures remain host-sensitive.

I profiled `ledgr_run()` twice on an independently generated 200-instrument,
1,260-session SMA 5/10 fixture. Runs took 21.11 and 21.23 seconds;
`ledgr_lot_apply_fill` accounted for 0.87 and 0.92 sampled seconds, or 4.12%
and 4.33% of wall. A free kernel implies 1.043x-1.045x, reproducing the
synthesis's shallow 3.5% / 1.04x ceiling in direction and scale. Windows
`Rprof()` sampled only 6.78-6.82 seconds, so this is a bounded attribution, not
a new benchmark record.

Both amendments are explicitly labelled maintainer decisions, state their
grounds in sections 2 and 3.3, and are named as departures from v2 in section
7 and the revision history. Cash and positions remain outside the lot kernel
in sections 2, 3.2, and every workstream step. The C++ signature citation
confirms why that boundary matters.

No production code, test, checker, ticket, schema, or roadmap change preceded
acceptance. The current tracked diff is empty; the RFC inputs and inventory
remain untracked alongside pre-existing excluded artifacts.

PASS_AFTER_PATCHES
