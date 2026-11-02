# Workstream 17 Closeout: Typed Declared Strategy State

Status: implementation complete; awaiting independent Type 1 close review.

## Product boundary

LDG-3185 and LDG-3186 implement the accepted D5 state model without changing
schema 124. Experiments declare flat typed asset and portfolio defaults. The
normalized declaration enters configuration identity and the unconditional
store-format fingerprint through `ledgr_strategy_state_rule_version`. Older or
missing rule markers refuse; there is no migration, alias or compatibility
fallback.

The fold owns one complete typed state. `ctx$state` is a pulse-frozen view.
`ledgr_strategy_result()` returns a field patch, while raw `state_update` is a
complete replacement and `reset_state = TRUE` restores all defaults. The
three operations remain distinct. Unknown fields, incompatible shapes/types,
non-finite values and malformed coverage refuse with classed conditions.

Every completed pulse writes one cursor/checkpoint row in the existing table.
An unchanged state writes a constant non-NULL marker and performs no payload
encoding. A changed value or asset-axis ID set writes one complete typed
checkpoint. Resume reads the latest cursor and latest preceding payload, then
aligns asset state by ID. Sweep candidates are isolated; walk-forward windows
reset strategy state while their economic books may carry.

## Failure-sensitive evidence

- LTB-0532/LCL-0522: all atomic types, typed missingness, empty and reordered
  axes, normalized public-run identity, malformed declarations and current-only
  rule binding.
- LTB-0533/LCL-0523: helper patches, raw complete/empty replacement, omission,
  reset, metadata separation, broadcast/alignment, NA reset and non-finite
  refusal.
- LTB-0534/LCL-0524: cursor/checkpoint recovery, N-to-N+1 resume, constant
  markers, encoder counts, no-state, never-changed and raw-identical returns.
- LTB-0535/LCL-0525: declared-state pulse inspection and explicit refusal of
  retired `state_prev`.
- LTB-0536/LCL-0526: changing point-in-time membership, departure, re-entry,
  defaults and axis-forced checkpoints.
- LTB-0537/LCL-0527: sequential and two-worker sweep equality and candidate
  isolation.
- LTB-0538/LCL-0528: two walk-forward folds reset state and begin the durable
  test run from exactly one first checkpoint.

The focused state suite, the fold-phase checker and the affected run, resume,
availability, scheduling, carrier, context and documentation suites pass. The
exact-source `R CMD build . --no-build-vignettes` and `R CMD check --no-manual
--no-build-vignettes ledgr_0.2.2.tar.gz` pass installation, namespace, code,
documentation, all tests, examples and executable vignette code. The check has
only the two expected missing-`inst/doc` warnings caused by the requested
no-build-vignettes mode.

## Cost and optimization evidence

`dev/bench/v0_2_3_strategy_state/evidence/current/record.csv` contains four
500-pulse dense workloads. No-state, declared-unchanged and raw-identical
strategies each write 500 cursor rows, zero payload encodes and zero payload
bytes; changed-every-pulse writes 500 payloads totaling 51,892 bytes. Wall
times are descriptive, single-pass observations, not a performance gate.

The benchmark README walks all seven optimization shapes. Declarations and
defaults are prepared once per candidate; resume performs two bounded queries;
unchanged pulses neither encode nor hash state; no data frame or growing
accumulator is created in the pulse loop. LTB-0534 fails if every-pulse payload
encoding or writing returns.

`evidence/current/mutations.csv` records two isolated-copy mutations. Replacing
each encoded field type with `numeric` fails LTB-0532 (and three dependent
state-path blocks); restoring every-pulse payload encoding fails LTB-0534.
Both mutations apply exactly once and are detected.

## Deliberate exclusions

This workstream does not implement the future preferred storage architecture,
schema 125, a migration reader, compatibility aliases, sizing disclosure or
the final pattern article. Those remain with their named later owners.
