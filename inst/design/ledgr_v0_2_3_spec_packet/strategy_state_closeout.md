# Workstream 17 Closeout: Typed Declared Strategy State

Status: close-review corrections complete; awaiting focused confirmation.

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
checkpoint. Resume reads the latest cursor and latest preceding payload on the
payload's own axis; P1 performs the single ID alignment when it prepares the
next decision axis. Sweep candidates are isolated; walk-forward windows
reset strategy state while their economic books may carry.

## Failure-sensitive evidence

- LTB-0532/LCL-0522: all atomic types, typed missingness, empty and reordered
  axes, all literal reserved names, attributed-value and cast-to-NA refusals,
  normalized public-run identity, malformed declarations and current-only rule
  binding.
- LTB-0533/LCL-0523: helper patches, raw complete/empty replacement, omission,
  reset, metadata separation, broadcast/alignment, NA reset and non-finite
  refusal.
- LTB-0534/LCL-0524: cursor/checkpoint recovery after a marker, N-to-N+1
  resume, resumed narrowed-axis byte parity, constant markers, encoder counts,
  no-state, never-changed and raw-identical returns.
- LTB-0535/LCL-0525: declared-state pulse inspection and explicit refusal of
  retired `state_prev`.
- LTB-0536/LCL-0526: changing point-in-time membership, departure, re-entry,
  defaults and axis-forced checkpoints.
- LTB-0537/LCL-0527: sequential and two-worker sweep fills, state-driven
  economics and candidate isolation for an equal declaration.
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
500-pulse dense workloads plus changed and unchanged 500-ID, four-asset-field
cells over 100 pulses. No-state, declared-unchanged and raw-identical
strategies each write 500 cursor rows, zero payload encodes and zero payload
bytes; changed-every-pulse writes 500 payloads totaling 51,892 bytes. Wall
times are descriptive, single-pass observations, not a performance gate. The
wide changed cell encodes 100 payloads (2,568,900 bytes) in 0.69 seconds; the
unchanged cell encodes no payload in 0.61 seconds on the recorded host.

The benchmark README walks all seven optimization shapes. Declarations are
validated and their typed default scalars prepared once per candidate; resume
performs two bounded queries; unchanged pulses neither encode nor hash state;
changed durable payloads use the uncached encoder; no data frame or growing
accumulator is created in the pulse loop. The general canonical JSON cache
remains owned by configuration/declaration identities and persisted metadata;
strategy-state payloads are no longer an owner. LTB-0534 fails if every-pulse
payload encoding or writing returns.

`evidence/current/mutations.csv` records seven isolated-copy mutations. They
cover type identity, every-pulse encoding, helper-patch replacement, metadata
leakage, axis-only checkpoint omission, restoring from a marker and seeding a
same-declaration candidate from non-default state. Every mutation applies
exactly once and is detected.

`ledgr_strategy_state_view()` deliberately copies each declared atomic vector
before user code sees it. This keeps a saved pulse view frozen against later
fold mutation; it is a bounded isolation copy, not accidental materialization.
The availability-state migration dropped local `members` and `plane_names`
assertions that remain owned by `test-flat-lazy-context.R` and
`test-availability-workflow.R`; no semantic oracle was retired.

## Deliberate exclusions

This workstream does not implement the future preferred storage architecture,
schema 125, a migration reader, compatibility aliases, sizing disclosure or
the final pattern article. Those remain with their named later owners.
