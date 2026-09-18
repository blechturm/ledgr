# Availability Diagnostic Block-Write Prerequisite Findings

**Date:** 2026-09-15. **Stage:** prerequisite probe under
`spike_protocol.md` section 1. This is not a Charter, production
implementation, semantic acceptance suite, or public benchmark. No package
file changed.

## Source state and environment

- Branch `v0.2.0.1`; HEAD `b0fe6b8` plus the reviewed, uncommitted diagnostic
  writer and prepared-provider spike seams.
- R 4.5.2 on Windows, collapse 2.1.8 from the isolated probe library.
- Registered shape: 757 pulses, 505 instrument-scope decision rows and one
  portfolio-scope reconciliation row per pulse, 383,042 rows total.
- Both paths used 4,096-row typed chunks and manifested 94 data frames at the
  same boundaries. Persistence was held constant behind a counting handler.

## Question

At the registered 757-pulse by 505-instrument shape, can constructing and
appending one typed diagnostic block per pulse remove at least 75% of the wall
used by the reviewed scalar-fields-plus-row-append path, while producing
byte-identical R values across a chunk boundary?

The 75% threshold was registered in `probe.R` before execution. It is only a
prerequisite routing rule; it is not a product performance promise.

## What ran

The control calls the reviewed `ledgr_availability_diagnostic_fields()` and
`ledgr_columnar_diagnostic_writer()$append()` once per row. This is the GREEN
writer-spike path held constant in the prepared-provider spike. Character
columns are fetched from the environment, changed by one scalar assignment,
and assigned back for every row; numeric, integer, and POSIXct columns use
`collapse::setv()`.

The probe-local floor constructs all 506 typed field values for a pulse as
vectors and assigns each vector slice to the same bounded columns once. It uses
base block replacement for character columns and `collapse::setv()` for the
other types. It changes neither schema nor chunk boundaries.

A nine-pulse parity pass produced 4,554 rows, crossing the 4,096-row flush
boundary. The manifested data frames were identical, including types, values,
row order, missing values, and continuous `diagnostic_seq`. Each arm was then
warmed and measured three times at the full registered row shape.

## Results

| path | run 1 | run 2 | run 3 | median |
| --- | ---: | ---: | ---: | ---: |
| scalar fields plus row append | 43.67 s | 43.50 s | 43.72 s | 43.67 s |
| one typed block per pulse | 0.30 s | 0.34 s | 0.27 s | 0.30 s |

The block floor reduced measured diagnostic construction and retention wall by
99.31%, far beyond the registered 75% routing threshold. The control agrees in
scale with the prepared-provider profile, which assigned 9.78 seconds to field
construction and 40.80 seconds to append/retain inside the full fold; DuckDB
diagnostic append was only 0.72 seconds there.

## Answer

**PULSE_BLOCK_REQUIRED.** The remaining diagnostic discontinuity is not the
bounded chunk or DuckDB persistence. It is the scalar API between the fold and
the chunk: 383,042 scalar field-list constructions and, more importantly, one
copy-producing character-column replacement per field per row. Moving the
existing production rule to one typed block per pulse removes that work in the
smallest runnable fork.

This makes a 25-40 second warm 757-pulse fold plausible, not proven. The probe
does not measure the whole fold, peak working set, real DuckDB persistence,
failure rollback, interruption and resume, reopen, mixed reason families,
execution diagnostics, or parallel workers. It also does not authorize
coalescing, sampling, or deleting ordinary diagnostic evidence.

## What a Charter may consume

- Compare exactly two arms behind the existing writer seam: the reviewed
  scalar-fields/row-append writer and one per-pulse typed-block writer.
- Hold the reviewed prepared availability provider constant in both arms.
- Preserve every diagnostic row, type, value, order, reason, sequence,
  transaction boundary, failure, resume, reopen, and explanation result.
- Exercise the registered 757-pulse fold plus bounded semantic cases containing
  decision, restriction, risk, no-fill, fill, reconciliation, exception, and
  completion diagnostics.
- Measure warm wall around `ledgr_run()`, externally sampled peak working set,
  diagnostic construction/append/persistence lanes, and the mechanism actually
  selected. Keep cold snapshot sealing outside this comparison and report it
  separately.
- Use a full-fold envelope, not this micro-probe result, to decide GREEN. Gut
  the block dispatch so unchanged outputs with the control mechanism cannot
  pass.

## Artifacts

- `probe.R` contains the registered question, both local paths, parity check,
  measurement protocol, and routing rule.
- `probe_measurements.csv` contains all six raw measurements and the derived
  answer.

PREREQUISITE_DISPOSITION: READY_FOR_CHARTER
