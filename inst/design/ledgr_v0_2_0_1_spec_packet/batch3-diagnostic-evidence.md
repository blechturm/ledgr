# Batch 3 Diagnostic Writer And Block Evidence

**Ticket:** LDG-2724
**Implementation base:** `82d58fa25fa95f0595b37ecdbcce42330c2756d7`
**Runtime:** R 4.6.1, duckdb 1.5.2, testthat 3.3.2, collapse 2.1.7
by default and collapse 2.1.8 from the isolated library
**Status:** Implemented; pending independent review.

## Production boundary

Ordinary availability-aware folds now select the typed column writer and one
typed diagnostic block per pulse without setting a process option. The writer
constructor's internal `chunk_rows` argument defaults to 4,096 and ordinary
fold calls omit it. The former chunk-capacity option has no package or harness
consumer; a production-boundary test sets that obsolete option to one and
proves that two rows remain buffered under the 4,096-row default.

The exact row-list and scalar-column selections remain temporarily available
for the Batch 4 pre-retirement parity gate. Missing or malformed selection
values choose the production block path. No public argument, experiment
config, durable identity field, or package dependency floor changed.

## Writer and failure boundary

The production writer preallocates typed columns. It uses
`collapse::setv()` only for numeric, integer, and POSIXct storage and base
replacement for character storage. A block may span chunk boundaries without
changing row order, types, missing values, or diagnostic sequence.

Full chunks reset only after `write_run_diagnostics()` succeeds. The final
partial chunk is exposed by `drain()` without release; the fold calls
`release()` only after `write_run_diagnostics()` or `write_run_evidence()`
returns successfully. A directly injected append failure proves that a full
chunk remains available for retry. Existing fold witnesses prove that an
unexpected fold failure rolls back the active transaction and leaves one
post-rollback error row, constructed outside the block path. Deliberate
interruption and resume preserve the committed prefix, including the
resume-then-error case with continuous sequence.

## Capacity and semantic coverage

Direct constructor tests exercise 7-row and 4,096-row capacities with a block
three rows larger than each capacity. Both cases flush one exact full chunk,
retain the final three rows, and reproduce the input block exactly after
reassembly. Invalid zero, negative, fractional, missing, infinite, vector, and
character capacities fail with `ledgr_invalid_args`.

The durable fold suite covers direct, 4,096-row, interruption/resume,
exception rollback, nonmember-increase rollback, resume-then-error, early
exit, and interruption/resume/early-exit scenarios. Every persisted surface
matches the retained scalar reference arm.

## Registered deterministic replay

The diagnostic-block semantic phase was rerun into isolated scratch evidence;
the reviewed evidence directory was not modified. Under collapse 2.1.8, all
five deterministic files were byte-identical to the reviewed records:

- `fixture.csv`;
- `cases.csv`;
- `diagnostics_reference.csv`;
- `coverage.csv`; and
- `setv_trace.csv`.

The replay observed zero scalar diagnostic-constructor calls in the block arm
and exactly one block-constructor call per processed pulse. All scenario,
chunk, persisted-identity, availability-reopen, and explanation-reopen parity
flags remained true where applicable.

The same bounded semantic phase was also run under collapse 2.1.7. Its five
deterministic files were byte-identical both to the reviewed records and to the
2.1.8 replay. The production-boundary test passed separately under both
collapse versions. `DESCRIPTION` was unchanged.

The earlier typed-writer spike runner was also replayed after removal of the
chunk option. Its constructor-only capacity injection reproduced
`fixture.csv`, `cases.csv`, and `diagnostics_40_rows.csv` byte-for-byte, so the
Batch 4 reference harness remains executable.

## Package verification

The complete `test-availability-*.R` regression net passed under R 4.6.1 and
the default collapse 2.1.7 library in 265.2 seconds. All 16 files completed
with zero failures or warnings; the installed mirai dependency allowed the
parallel availability test to run rather than skip.

No 757-pulse performance protocol, full package suite, cold-seal benchmark,
or peer benchmark was run. Those records belong to later packet gates.
