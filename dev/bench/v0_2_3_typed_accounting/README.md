# Cut 11 typed-accounting baseline

Status: LDG-3200 baseline frozen before the first accounting reader change.

The canonical current-format output record is the existing
`dev/bench/v0_2_3_output_freeze/records/` corpus. It covers the seven required
proof families (`dense_cost`, `dense_risk_features`, `dense_dividend_state`,
`avail_terminal_resume`, `avail_acquisition`, `avail_incomplete`, and
`walk_forward`) plus the registered failure family. Its manifest pins every
stored table, full diagnostics, public fills/trades/metrics, memory-sink
diagnostics and inline summaries, close/reopen, interrupt/resume and ordering.
`check.R` verifies that corpus's own manifest before checking the new literal
seam census and the two field maps.

The record was produced at `20034e00` from the fixture identities documented
in the output-freeze inventory. This ticket deliberately references those
frozen bytes instead of copying 290 files into a second directory. Current
package and runtime versions, canonical types/missings, row keys and byte
encoding are recorded by that harness and its manifest.

`source_census.csv` is a literal source-count inventory. Each family is
reconciled against every `R/*.R` file: a new file, deleted seam or changed
count fails `check.R`. `accounting_field_map.csv` assigns every schema-124
logical accounting field to its current source and its typed-carrier rule.
`diagnostic_field_map.csv` pins all 22 logical diagnostic fields, their types,
nullability and ordering owner.

Private Sharadar evidence is an **open gate**. No private data was available
to this implementation session, so no aggregate digest, count, latency or
peak-memory result is claimed. It closes only when the registered private run
records aggregate per-table row counts and SHA-256 digests for full/filtered
diagnostics, point/history explanations, D8/valuation summaries and economics.
Raw vendor data must not enter the repository.

The shared timing protocol is registered as `cut11-accounting-1`. Its three
cells are descriptive under macro-plan rule 16. The immutable before arm is
commit `0d6c0b11`; fill-heavy, quiet and sweep records are taken by the shared
fresh-process harness when a candidate commit exists.

Run `Rscript dev/bench/v0_2_3_typed_accounting/check.R`.
