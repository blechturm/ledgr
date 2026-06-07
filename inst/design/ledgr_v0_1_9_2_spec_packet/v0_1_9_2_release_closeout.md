# v0.1.9.2 Release Closeout

**Status:** Local release gate complete; branch ready for remote CI, merge, and
tag.
**Date:** 2026-06-08.
**Branch:** `v0.1.9.2`.
**Accepted synthesis:**
`inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`.
**Spec packet:** `inst/design/ledgr_v0_1_9_2_spec_packet/`.

## Scope Closed

v0.1.9.2 ships compact saved-sweep artifacts and optional retained net
portfolio equity/return series for completed sweep candidates. Saved sweeps are
durable evidence objects, not committed runs. Promotion from a reopened sweep
re-executes the selected candidate from its reproduction key against the sealed
snapshot.

The release also completes the public `candidate_id` / `candidate_row` sweep
identity surface and the saved-sweep public API:

- `ledgr_sweep_retention()`;
- `ledgr_sweep_returns()`;
- `ledgr_sweep_returns_wide()`;
- `ledgr_sweep_save()`;
- `ledgr_sweep_open()`;
- `ledgr_sweep_list()`;
- `ledgr_sweep_info()`.

## Non-Scope Preserved

The packet does not ship ranking helpers, named selection views, automatic
winner selection, automatic promotion, full ledger/fill/trade/per-instrument
artifacts for every candidate, benchmark-relative diagnostics, signal decay,
implementation/cost decay, gross-vs-net attribution, liquidity, TCA, OMS,
taxes, financing, broker reconciliation, walk-forward integration, per-fold
retention dimensions, schema migration machinery, PerformanceAnalytics
adapter, or lazy/pushed-down wide pivots.

## Gate Evidence

- Read `inst/design/release_ci_playbook.md` before package-gate work.
- Targeted saved-sweep, retained-series, schema, validation, candidate,
  promotion, documentation, and API tests passed.
- Full local tests passed:
  `testthat::test_local('.', reporter = 'summary')`.
  Result: passed with one optional Yahoo-path skip.
- README cold-start passed:
  `Rscript --vanilla tools/check-readme-example.R`.
- Source build passed:
  `R CMD build --no-build-vignettes .`.
  Result: built `ledgr_0.1.9.2.tar.gz`; emitted known long archival design path
  warnings.
- Package check passed:
  `R CMD check --no-manual --no-build-vignettes ledgr_0.1.9.2.tar.gz`.
  Result: tests and examples passed; accepted warnings are the existing
  no-`inst/doc` vignette warnings. Accepted NOTE is the existing long archival
  design path NOTE.
- Coverage gate passed:
  `Rscript tools/check-coverage.R`.
  Result: generated `coverage.html` with 85.46% coverage, above the 80% gate.
- pkgdown build passed after adding the new sweep persistence help topics to
  `_pkgdown.yml`.
- WSL/Ubuntu schema and persistence smoke gate passed:
  `test-schema-validator-side-effects.R`, `test-schema-snapshots.R`,
  `test-schema.R`, `test-persistence-fresh-connection.R`,
  `test-sweep-persistence-schema.R`, and
  `test-sweep-persistence-roundtrip.R`.
- Storage smoke measurement passed:
  `sweep_retention_storage_smoke.md` records `ratio = 0.609524`.
- Generated `vignettes/sweeps.md` was regenerated from `vignettes/sweeps.qmd`
  after stale generated text was found.
- Anchored stale-claim search was run for synthesis Section 1 non-scope terms:
  `ranking`, `selection view`, `top.?n`, `winner`, `benchmark-relative`,
  `\balpha\b`, `\bbeta\b`, `gross-vs-net`, `signal decay`,
  `walk-forward integration`, `schema migration`,
  `PerformanceAnalytics adapter`, `ledgr_save_sweep`, and
  `full sweep artifact persistence`.
  Remaining hits are explicit non-scope statements, existing strategy-helper
  documentation, or historical NEWS.

## Reruns And Dispositions

- `R CMD check` exceeded the shell timeout while the child R process continued
  running. The process was monitored through `ledgr.Rcheck/00check.log` until
  completion; final result was 2 accepted warnings and 1 accepted NOTE.
- Coverage exceeded the shell timeout while the child R process continued
  running. The generated `coverage.html` was inspected after completion and
  recorded 85.46% coverage.
- The first pkgdown attempt failed because Quarto was not on PATH. Rerun with
  the installed RStudio Quarto path succeeded after `_pkgdown.yml` was patched
  to index the new public sweep persistence topics.
- The first WSL gate failed because stale Windows-built `src/*.o` artifacts were
  visible to the Linux linker. Local compiled artifacts were removed and the WSL
  gate passed from a clean compile state.

## Release Status

All `LDG-2581` through `LDG-2596` tickets are complete. The branch is ready for
remote CI, merge to `main`, main CI, tag `v0.1.9.2`, tag CI, and GitHub Release
creation per `inst/design/release_ci_playbook.md`.
