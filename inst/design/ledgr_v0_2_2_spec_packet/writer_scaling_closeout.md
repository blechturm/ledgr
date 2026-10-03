# Workstream 6 Closeout: Writer Scaling

**Status:** Agent-provisional; ready for Type 1 close review.
**Date:** 2026-10-03
**Implementation range:** `4055454..19d99b9`
**Tickets:** LDG-2935 through LDG-2937

## Outcome

The fill-event candidate shipped at `c0ea8d7`. Canonical R fill rows are now
staged inside the persistent and memory output handlers and published once per
pulse through typed column writes. The first diagnostic-sequence decision at
`6765e9f` used a dense public-run denominator that never executes the query.
The Type 1 correction at `19d99b9` remeasured it in a file-backed store
against the named warm availability-aware long-window run. Both registered
gates pass, so the
persistent handler now initializes the next sequence once and advances it in
memory for later diagnostic blocks.

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

The record contains 39 identical parity rows: 35 cross-arm comparisons and
four base-versus-base comparator checks. They cover alias SMA, reversals with
fees, uneven availability, multiple sweep candidates, `db_live`,
checkpoint-every-two and the release shape. The release-shape sweep retained
no return or trade rows, so its parity rows compare zero rows and the populated
sweep return and trade comparisons come from p1 and p3. Other compared surfaces
include ledger events, fills, equity, sweep columns and retained results.
Existing fast-profile resume evidence also remained green, including
LTB-0007's exact ledger, state, feature, equity, fill and trade comparison
after recovery.

The record must be reproduced from a detached checkout of baseline `4055454`,
not from the current tree. Create and enter that worktree, then build the
package DLL once before running the record:

```text
git worktree add --detach C:/tmp/ledgr-ws6-record 4055454
Set-Location C:/tmp/ledgr-ws6-record
Rscript -e "pkgload::load_all('.', quiet = TRUE)"
Rscript dev/spikes/fill-event-block-write/spike_runner.R --phase all --out inst/design/ledgr_v0_2_2_spec_packet/ws6_fill_event_flush_evidence --reps 3
```

The runner loads the checkout containing it as the base arm, applies
`dev/spikes/fill-event-block-write/seam.R` to the candidate arm and compares
both in one interleaved R process. Running it from HEAD would instead compare
shipped code with shipped code plus the old seam and would not reproduce this
record.

Production keeps direct `buffer_event()` behavior for existing internal
callers. Only canonical `write_fill_events()` stages rows. The fold calls
`flush_pulse_events()` immediately after the compiled or canonical event
branch. `record_accounting_fact()` is the sole pre-flush reader and may patch
the current staged memory row. Calls with no staged canonical rows are no-ops,
so live database and compiled-accounting paths stay direct.

The first local edit placed the flush before event production. Source review
caught it before commit. The first LTB-0136 final-pulse witness was defective:
it traded on pulse one, so a pulse-two pre-production flush still published
the rows. The Type 1 correction makes a two-pulse run trade on pulse two. Moving
the flush before event production now fails that witness with the two final
rows absent. The committed code flushes after production.

## Detectors And Mutations

| Claim | Detector | Independent failure probe |
| --- | --- | --- |
| staged rows are hidden and columns remain aligned | LTB-0135 / LCL-0135 | changing the second staged instrument fails twice |
| publication does not occur through the scalar buffer | LTB-0135 / LCL-0135 | restoring `buffer_event()` publication fails three times |
| one flush occurs per pulse and final-pulse rows publish | LTB-0136 / LCL-0136 | moving the flush before production fails the final-pulse assertion; removing it fails fifteen assertions |
| failure after one valid fill is atomic and candidate-local | LTB-0137 / LCL-0137 | one-shot second-fill failure yields durable FAILED with zero rows; the next candidate equals an isolated reference |

The persistent failure witness reads status and row count from DuckDB. Its
durable half protects the existing fold transaction: publishing each fill
directly still rolls back and is not claimed as a staging detector. Running
the fold outside that transaction is the registered smallest failing change.
The sweep witness compares the completed candidate's semantic result with a
separate one-candidate sweep. It does not treat a shared helper as the oracle.

## LDG-2936: Diagnostic Sequence

`dev/bench/v0_2_2_workstream6/diagnostic_sequence_probe.R` uses the real
`run_diagnostics` table and the production `MAX(diagnostic_seq)` query in a
temporary file-backed DuckDB store. It measured seven batches of 100 queries
at zero, 50,000, 250,000 and 750,000 rows, then simulated 4,096-row appends
through 750,000 rows and clocked 100 queries at each allocation point.

The corrected denominator is the registered warm availability-aware public
run at 500 members and 1,514 pulses: 29.0 seconds with approximately 758,514
diagnostic rows. One percent is 0.29 seconds. The complete 184-query sequence
measured 0.3734 seconds, or 1.288% of that run. Accumulated query work had
exponent 1.26273 against the registered greater-than-1.10 scaling gate. Both
the wall and scaling gates pass.

The handler therefore reads the next sequence once, lazily on its first
diagnostic block, and advances the value in memory. Resume starts from the
durable maximum. An exception after transaction rollback deliberately
re-reads once, because attempted diagnostic blocks may have advanced the
in-memory value even though their rows rolled back. LTB-0138 starts from a
durable sequence seven, writes blocks of two and one rows, and obtains exact
sequences 7 through 10 with one initializer call. Calling the initializer for
each block fails the detector.

The heavy-protocol block `ported fold witnesses preserve every persisted
surface` in `tests/testthat/test-availability-fold-witnesses.R` protects the
rollback refresh. Replacing `next_diagnostic_seq(refresh = TRUE)` with the
cached call makes that block fail; the corrected block passed independently
with 43 expectations. It is the failed-fold detector, while LTB-0138 protects
ordinary and resumed block allocation.

Evidence is under `ws6_diagnostic_sequence_evidence/`. The removed query work
is 0.3734 seconds at the registered shape; no separate end-to-end speedup is
claimed for the implementation.

## Seven-Shape Walk

1. Repeated lookup: the scale-growing diagnostic `MAX()` lookup was removed
   from ordinary block writes. One initialization lookup remains per handler,
   plus one recovery lookup only after a rolled-back fold exception.
2. Growing scans: pulse staging has no scan over prior pulses. The repeated
   diagnostic history scan was removed after its corrected gate passed.
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

Focused writer, sweep, fold and availability-economics suites pass. The
control-plane and documentation-contract suites pass. The corrected isolated
ordinary fast profile ran 498 of 498 blocks with zero skips or failures in
81.660 seconds; the 112-second gate passed. Its summary is retained with the
fill-flush evidence. The full census remains in the scratch record at
`C:/tmp/ledgr_ws6_correction_fast`.

The Cut 2 review and first Workstream 6 close review are two invocations over
eleven tickets. A focused correction review would make three over eleven,
0.273 against the 0.5 gate.
