# Workstream 41 evidence

This directory holds the bounded, vendor-neutral evidence for Cut 16
Workstream 41.

- `aggregate_segment_census.R` reconciles the shared segment representation
  against the checked-in aggregate WS39 lake record. It does not read private
  rows.
- `worker_transport.R` measures the real staged and candidate-varying task
  shapes and checks sequential/two-worker economic parity. It is an object
  payload record, not a process-memory claim.
- `evidence/ws41_fixture_ladder/` records the established 800-instrument
  public-cycle comparison against the accepted Workstream 40 tree.
- the fast, review and heavy profile directories contain the registered test
  census records. The exact resource gates remain owned by LDG-3069.

The full current-format private-lake census and process-tree resource record
remain with Workstream 44. Nothing here substitutes aggregate inference for
those later measurements.
