# Workstream 6 Closeout: Writer Scaling

**Status:** Agent-provisional; ready for Type 1 close review.
**Date:** 2026-10-03
**Range:** `4055454..6765e9f`
**Tickets:** LDG-2935 through LDG-2937

## Outcome

The fill-event candidate shipped at `c0ea8d7`. Canonical R fill rows are now
staged inside the persistent and memory output handlers and published once per
pulse through typed column writes. The diagnostic-sequence candidate was
measured at `c0ea8d7` and rejected at `6765e9f`: its repeated query is
superlinear, but its full measured contribution is below the registered
one-percent public-run gate. No diagnostic production code changed.

## LDG-2935: Fill-Event Flush

The current-tree record was started from `4055454` before production editing.
Its two arms ran in one R 4.6.1 process, on the same sealed fixture, with
interleaved order and three repetitions. The candidate arm was the previously
reviewed in-memory seam applied to that current tree.

At 500 instruments, 1,260 pulses and 68,201 fills:

| Public path | Baseline median | Candidate median | Paired median saving |
| --- | ---: | ---: | ---: |
| `ledgr_run()` | 65.463 s | 58.381 s | 10.08% |
| `ledgr_sweep()` | 52.914 s | 45.432 s | 20.36% |

Both paths cleared the preregistered five-percent gate. The raw clocks,
environment and fixture are under `ws6_fill_event_flush_evidence/`. These are
the registered two-arm gate clocks, not a separately claimed post-commit
speedup.

All 39 registered comparisons were identical. They cover alias SMA, reversals
with fees, uneven availability, multiple sweep candidates, `db_live`,
checkpoint-every-two and the release shape. Compared surfaces include ledger
events, fills, equity, trades, sweep columns and retained results. Existing
fast-profile resume evidence also remained green, including LTB-0007's exact
ledger, state, feature, equity, fill and trade comparison after recovery.

Production keeps direct `buffer_event()` behavior for existing internal
callers. Only canonical `write_fill_events()` stages rows. The fold calls
`flush_pulse_events()` immediately after the compiled or canonical event
branch. `record_accounting_fact()` is the sole pre-flush reader and may patch
the current staged memory row. Calls with no staged canonical rows are no-ops,
so live database and compiled-accounting paths stay direct.

The first local edit placed the flush before event production. Source review
caught it before commit, and LTB-0136 gained a two-pulse final-fill witness
that fails under that placement. The committed code flushes after production.

## Detectors And Mutations

| Claim | Detector | Independent failure probe |
| --- | --- | --- |
| staged rows are hidden and columns remain aligned | LTB-0135 / LCL-0135 | changing the second staged instrument fails twice |
| publication does not occur through the scalar buffer | LTB-0135 / LCL-0135 | restoring `buffer_event()` publication fails three times |
| one flush occurs per pulse and final-pulse rows publish | LTB-0136 / LCL-0136 | removing the fold flush fails fifteen assertions |
| failure after one valid fill is atomic and candidate-local | LTB-0137 / LCL-0137 | one-shot second-fill failure yields durable FAILED with zero rows; the next candidate equals an isolated reference |

The persistent failure witness reads status and row count from DuckDB. The
sweep witness compares the completed candidate's semantic result with a
separate one-candidate sweep. It does not treat a shared helper as the oracle.

## LDG-2936: Diagnostic Sequence

`dev/bench/v0_2_2_workstream6/diagnostic_sequence_probe.R` uses the real
`run_diagnostics` table and the production `MAX(diagnostic_seq)` query.
It measured seven batches of 100 queries at zero, 50,000, 250,000 and 750,000
rows, then simulated 4,096-row appends through 750,000 rows and clocked each
sequence allocation.

The registered denominator is the Workstream 6 public long-window run above:
58.381 seconds, so one percent is 0.58381 seconds. The complete 184-query
sequence measured 0.425 seconds, or 0.728% of that run. Accumulated query work
had exponent 1.14045 against the registered greater-than-1.10 scaling gate.
The scaling gate passed and the wall gate failed. Because both were required,
the candidate was rejected and the handler remains unchanged.

Evidence is under `ws6_diagnostic_sequence_evidence/`. No speedup is credited
to this rejected candidate.

## Seven-Shape Walk

1. Repeated lookup: the diagnostic `MAX()` lookup remains but is measured and
   rejected below the materiality gate; no new repeated lookup was added.
2. Growing scans: pulse staging has no scan over prior pulses. The diagnostic
   scan is the rejected candidate recorded above.
3. Per-element work with a batch replacement: eleven persistent columns and
   sixteen memory columns now receive one vector write per pulse, replacing
   scalar writes per fill.
4. Scale-growing collections: staged row and leg lists are bounded by the
   largest single pulse, grow geometrically and are reused; they do not grow
   with run history.
5. Recomputed discarded work: no new parse, serialization, hash or derived
   state is recomputed by the flush.
6. Frame construction: the change adds no per-pulse or per-fill data frame.
   Existing one-row fill construction is unchanged.
7. Mutation and copy shape: durable and memory typed columns remain owned by
   environments and use `collapse::setv()`; staged accounting patches replace
   one bounded list entry and never copy the cumulative event store.

The flush performs fixed column-count `vapply()` passes over only the current
pulse. Total work is linear in emitted rows, with no scale-growing validation
or history scan.

## Boundaries And Verification

There is no public API, schema, run or snapshot identity, snapshot hash,
tolerance, default, verification-policy or failure-semantics change.
`contracts.md` now records pre-flush visibility and the existing fold
transaction as the durable atomicity boundary; it makes no partial-flush
promise. `db_live` and compiled accounting were exercised as no-staged paths
and stayed exact.

Focused writer, sweep and fold suites pass. The control-plane and
documentation-contract suites pass. The isolated ordinary fast profile ran
497 of 497 blocks with zero skips or failures in 83.780 seconds; the
112-second gate passed. Its summary is retained with the fill-flush evidence.

The Cut 2 review is one invocation over eleven tickets. This requested
Workstream 6 close review would make two invocations over eleven tickets,
0.182 against the 0.5 gate.
