# Cut 11 typed-accounting baseline

Status: LDG-3200 baseline frozen before the first accounting reader change.

The WS23 public-output oracle is the separately named
`a0_successor/records/` pair. Its immutable before arm is commit `0d6c0b11`;
the candidate arm has the same 281-file set and is byte-identical except for
the four accepted INCOMPLETE-sweep `annualized_return` cells checked by
`a0_successor/compare.R`.

The older `dev/bench/v0_2_3_output_freeze/records/` corpus was produced at
`20034e00`. `check.R` still verifies its own 290-file manifest as a historical
integrity check; it is not the WS23 before arm and is not claimed as parity
evidence for this cut.

`source_census.csv` is a literal source-count inventory. Each family is
reconciled against every `R/*.R` file: a new file, deleted seam or changed
count fails `check.R`. `accounting_surface_census.csv` classifies the matched
production, test and teaching seams as producer, writer, reader, test, doc or
storage reference. Adding, deleting or reclassifying a matched seam fails the
checker. `accounting_field_map.csv` assigns every schema-124 logical
accounting field to its current source and typed-carrier rule;
`diagnostic_field_map.csv` pins all 22 diagnostic fields, their types,
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
fresh-process harness when required. `protocol_smoke.csv` is one explicitly
non-gating candidate execution that proves the repaired public API, event/fill
counts and ledger digest work string execute at product commit `7361951e`.

Run `Rscript dev/bench/v0_2_3_typed_accounting/check.R`.
