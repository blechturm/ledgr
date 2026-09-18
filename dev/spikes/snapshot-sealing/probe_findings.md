# Snapshot Sealing Probe Findings

**Date:** 2026-09-15. **Stage:** prerequisite probe under
`spike_protocol.md` section 1. Not a Charter, comparison, or implementation.
No package file changed.

## Source state and environment

- Branch `v0.2.0.1`; HEAD `b0fe6b8` plus the uncommitted provider-spike
  seam (not on the sealing path).
- R 4.5.2 on Windows, collapse 2.1.8 (isolated library), duckdb 1.4.3;
  ledgr loaded from the working tree.
- Fixture: the writer spike's registered `spike_fixture(FIXTURES$envelope757)`,
  built in 33 s: 563 instruments, 426,191 bars, 60 identical complete
  membership lists (30,300 rows), 563 status and 563 lifetime facts, a
  1,060-day session calendar. Context, not a peer comparison: the dense peer
  benchmark ingested 630,000 bars in 19.78 s including the CSV read and
  snapshot creation, so this fixture seals about 60 times slower per bar.

## Question

On the registered 757-pulse availability fixture, which phase of
`ledgr_snapshot_from_df()` dominates wall time, and which functions carry the
self time inside that phase?

## What ran

`probe.R` traces entry and exit of eleven phase functions for exact inclusive
wall time, and runs `Rprof()` (20 ms, gc profiling) around the whole call for
attribution by phase and by innermost function. The profiler roughly doubles
the seal's wall time (1,449 s here against 850-868 s unprofiled in the
provider spike), so shares are the evidence and inclusive seconds are upper
bounds. Direct timings of individual suspects were taken separately on
slices and extrapolated.

## Results

| phase (traced, inclusive) | seconds | share |
| --- | ---: | ---: |
| `ledgr_snapshot_validate_availability_for_seal` | 1,377.96 | 95.1% |
| `ledgr_availability_validate_inputs` | 40.96 | 2.8% |
| `ledgr_snapshot_hash` | 9.48 | 0.7% |
| `ledgr_snapshot_write_availability` | 8.09 | 0.6% |
| `ledgr_create_schema`, `_validate_for_seal`, `_metadata_for_seal`, checkpoint | 0.38 | 0.0% |
| `ledgr_snapshot_from_df` total | 1,448.58 | 100% |

Innermost-function self time (46,580 samples): `identical` 47.9%,
`ledgr_fact_validate_membership_conflicts` 31.4%, garbage collection 15.8%,
`format.POSIXlt` 1.2%, everything else under 0.3% each. The DuckDB bulk
copies via parquet took 0.24 s.

Direct timings of the suspects (unprofiled, slices extrapolated to the full
fixture): the pairwise membership validator 47.7 s for 6,000 rows, about
1,200 s for 30,300 rows (459 million pairs); the per-bar timestamp loop in
`ledgr_availability_observation_times()` about 17 s (0.02 s when
`ledgr_fact_time()` is called once on the vector); the session-close token
check about 9 s; the per-fact-row hash payload plus canonical JSON about 7 s;
per-row provenance JSON validation about 1 s.

## What this establishes

Sealing is not inherently slow. The DuckDB writes, the streaming hash, and
the fact writes together take under 20 s on this fixture. One call dominates:
the seal-time availability validation re-runs
`ledgr_fact_validate_membership_conflicts()` over every persisted membership
row (`R/availability-persistence.R:318`), a nested pair loop
(`R/availability-facts.R:1324-1343`) whose cost grows with the square of the
row count. For complete-list rows the check can never fire (every row asserts
`member = TRUE`; it flags only overlapping rows with different flags), and
the snapshot constructor itself does not run it. The status and lifetime
validators have the same shape (`R/availability-facts.R:1303`, `:1345`) and
were small here only because those tables were small.

The per-bar loop in the ingest dry run and the per-row JSON work are real
instances of the same anti-pattern and worth removing (about 30 s together),
but they are not the discontinuity.

## What the next Charter may consume

- The prerequisite answer is **QUADRATIC_VALIDATOR_AT_SEAL**: one
  O(n^2) validator, run at seal over all membership rows, is about 95% of
  sealing on the registered fixture.
- A grouped, state-aware sweep replaces the pair loop at O(n log n): within
  each (instrument, universe) group, sort by `effective_from`, keep a running
  maximum end per membership state, and flag a row whose start lies before
  the running maximum of the opposing state, with half-open intervals and
  open ends preserved; a single running maximum across states would not
  preserve the current "overlapping opposing assertions" semantics. The
  status validator needs the same sweep grouped by instrument, source, and
  precedence with superseded pairs exempted. Set-backed membership rows may
  be excluded from the comparison only after a setwise validation confirms
  that every persisted set row has `member = TRUE`, a valid header, and the
  required snapshot invariants, because the database does not enforce
  `set_id` implying `member = TRUE`.
- The remaining ingest cost is bounded and vectorisable: call
  `ledgr_fact_time()` once on the timestamp vector; validate and hash
  `unique()` provenance strings; cache family hashes across
  `ledgr_facts_assert()` calls.
- Forecast, not a measurement: after the validator fix this fixture should
  seal in roughly 60-90 s under the cold clock of `spike_protocol.md` section
  10, dominated by the ingest dry run and the hash, with a further factor of
  about two available from the bounded items above. The figure stays labelled
  a forecast until measured after implementation.

## What remains open

Whether the status and lifetime validators need the same sweep now or only
when their tables grow; whether complete-set rows should be exempt from the
membership validator at seal or the validator should be made linear for all
shapes; the cold end-to-end clock for a Sharadar-scale panel after the fix;
and the loop audit's other seal-path items (`dev/spikes/snapshot-sealing/loop_audit.md`).

## Handoff

**READY_FOR_CHARTER_OR_TICKET.** The mechanism is a single validator with a
known linear replacement, so the maintainer may route it as a bounded ticket
rather than a two-arm spike; if a spike is chartered, a different author
writes it and both structural reviews apply.
