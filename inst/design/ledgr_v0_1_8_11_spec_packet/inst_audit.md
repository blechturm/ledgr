# inst/ Subdirectory Audit

**Ticket:** LDG-2538
**Status:** Completed
**Date:** 2026-06-04
**Scope:** `inst/design/architecture/`, `inst/design/maintainer_review/`,
`inst/diagrams/`, `inst/examples/`, `inst/schemas/`, and `inst/testdata/`

## Summary

This audit inventories every tracked file in the scoped `inst/` subdirectories,
records reference evidence, and records the reviewed disposition. The initial
audit phase deleted, moved, migrated, and gitignored nothing before review. The
cleanup phase then applied only the reviewed deletions listed below.

The binding architecture paths are preserved:

- `inst/design/architecture/fold_core_trust_boundary.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`

## Inventory Baseline

- Tracked scoped files: 19.
- Tracked scoped-file size before cleanup: 167,999 bytes.
- Ignored local Quarto render artifacts under `inst/design/maintainer_review/`:
  24 files / 3,987,432 bytes plus `fold_core_workbook.html` at 41,942 bytes.
- `.Rbuildignore` currently excludes `inst/design/maintainer_review`.
- `inst/design/maintainer_review/.gitignore` currently ignores `.quarto/`,
  `*.html`, and `*_files/`.

## Checks Run

```text
git ls-files inst/design/architecture inst/design/maintainer_review inst/diagrams inst/examples inst/schemas inst/testdata
git status --ignored --short inst/design/architecture inst/design/maintainer_review inst/diagrams inst/examples inst/schemas inst/testdata
rg -n "inst/(design/(architecture|maintainer_review)|diagrams|examples|schemas|testdata)|architecture/|maintainer_review/|fold_core_trust_boundary|ledgr_v0_1_8_sweep_architecture" R tests vignettes inst/design dev .github .Rbuildignore README.md DESCRIPTION
rg -n "getting-started|inst/examples|inst/schemas|inst/diagrams|yahoo_mock|system.file\(" R tests vignettes inst/design dev .github README.md DESCRIPTION NAMESPACE
```

For delete candidates, the reference sweep covered `R/`, `tests/`,
`vignettes/`, `inst/design/`, `dev/`, and `.github/`, plus root package
metadata where relevant.

## Tracked File Dispositions

| ID | File | Bytes | Reference evidence | Current purpose | Final disposition |
| --- | --- | ---: | --- | --- | --- |
| INST-001 | `inst/design/architecture/fold_core_trust_boundary.md` | 6,526 | 4 full-path refs; 17 basename refs | Binding snapshot/fold trust-boundary architecture note. | Keep, load-bearing. Do not rename or relocate without a separate ticket. |
| INST-002 | `inst/design/architecture/ledgr_feature_map_ux.md` | 9,006 | 2 full-path refs; 28 basename refs | Active feature-map UX/design input. | Keep, load-bearing design context. |
| INST-003 | `inst/design/architecture/ledgr_sweep_mode_ux.md` | 25,644 | 20 full-path refs; 37 basename refs | Active sweep-mode UX/design input cited by sweep architecture and RFCs. | Keep, load-bearing design context. |
| INST-004 | `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md` | 39,606 | 28 full-path refs; 44 basename refs | Binding sweep architecture note. | Keep, load-bearing. Do not rename or relocate without a separate ticket. |
| INST-005 | `inst/design/architecture/sweep_mode_code_review.md` | 6,767 | 7 full-path refs; 16 basename refs | Review record used by the sweep architecture note. | Keep as architecture provenance. |
| INST-006 | `inst/design/maintainer_review/.gitignore` | 31 | Directory-local ignore rules. | Ignores local Quarto render outputs. | Keep. |
| INST-007 | `inst/design/maintainer_review/README.md` | 1,300 | Directory index. | Explains maintainer-review workbooks. | Keep, but remain excluded from package build. |
| INST-008 | `inst/design/maintainer_review/feature_value_path_workbook.qmd` | 23,107 | 4 full-path refs; 11 basename refs | Maintainer workbook for feature value path review. | Keep as internal workbook; already excluded from package build. |
| INST-009 | `inst/design/maintainer_review/fold_core_workbook.qmd` | 12,660 | 7 full-path refs; 22 basename refs | Maintainer workbook backing fold-core manual article. | Keep as internal workbook; already excluded from package build. |
| INST-010 | `inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd` | 37,466 | 10 full-path refs; 11 basename refs | Historical optimization-round maintainer review and benchmark provenance. | Keep as internal provenance for now; consider manual migration only if future manual work needs the narrative. |
| INST-011 | `inst/diagrams/database_erd.mmd` | 1,750 | 0 refs | Old Mermaid ERD; contains stale run-time `data_hash` and old table sketches. | Deleted after review. |
| INST-012 | `inst/diagrams/dual_spine.mmd` | 802 | 0 refs | Old provenance/execution spine sketch; refers to v0.1.0/v0.1.1 and `Strategy: on_pulse`. | Deleted after review. |
| INST-013 | `inst/diagrams/error_hierarchy.mmd` | 497 | 0 refs | Unreferenced Mermaid sketch. | Deleted after review. |
| INST-014 | `inst/diagrams/pulse_lifecycle.mmd` | 1,288 | 0 refs | Unreferenced Mermaid sketch. | Deleted after review. |
| INST-015 | `inst/diagrams/run_state_machine.mmd` | 420 | 0 refs | Unreferenced Mermaid sketch. | Deleted after review. |
| INST-016 | `inst/diagrams/snapshot_state_machine.mmd` | 454 | 0 refs | Unreferenced Mermaid sketch. | Deleted after review. |
| INST-017 | `inst/examples/README.md` | 329 | 1 full-path historical ref | Installed examples directory pointer; says this is not the first-run path but points to stale `vignette("getting-started")`. | Deleted after review; no useful installed example surface remained. |
| INST-018 | `inst/schemas/README.md` | 120 | 0 refs | Placeholder saying versioned storage schemas have no implementations yet. | Deleted after review. |
| INST-019 | `inst/testdata/yahoo_mock.csv` | 226 | 3 full-path refs; used by `tests/testthat/test-snapshot-adapters.R` through `system.file("testdata", ...)`. | Keep, load-bearing runtime test fixture. |

## Ignored Local Artifacts

`git status --ignored --short` reports the following ignored artifacts under
`inst/design/maintainer_review/`:

- `.quarto/`
- `fold_core_workbook.html`
- `fold_core_workbook_files/`

These are already ignored by `inst/design/maintainer_review/.gitignore`; the
whole `inst/design/maintainer_review` directory is already excluded from package
builds by `.Rbuildignore`. No repository cleanup is needed unless the maintainer
wants to remove local ignored files from the workspace.

## .Rbuildignore Review

Current `.Rbuildignore` state is mostly aligned with the audit outcome:

- `^inst/design/maintainer_review$` correctly excludes internal workbooks and
  local render artifacts from package builds.
- `inst/design/architecture/` remains package-included as installed design
  authority. This is acceptable because several docs and tests treat
  `inst/design` as installed contract/design material.
- `inst/testdata/yahoo_mock.csv` remains package-included and should stay
  package-included because tests load it via `system.file()`.
- `inst/diagrams/`, `inst/examples/`, and `inst/schemas/` were package-included
  before cleanup; reviewed dead placeholders were deleted rather than hidden
  with new `.Rbuildignore` entries.

## Cleanup Applied After Review

1. Deleted `inst/diagrams/*.mmd` (`INST-011` through `INST-016`).
2. Deleted `inst/schemas/README.md` (`INST-018`).
3. Deleted `inst/examples/README.md` (`INST-017`) because no useful installed
   example surface remained and the only specific pointer was stale.
4. Keep the architecture notes and maintainer-review source workbooks in place.
5. Keep `inst/testdata/yahoo_mock.csv`.
6. Re-run full tests, `R CMD check`, and manual render checks.

## Package Size

- Pre-cleanup build tarball: `ledgr_0.1.8.10.tar.gz`, 3,153,183 bytes.
- Post-cleanup build tarball: `ledgr_0.1.8.10.tar.gz`, 3,151,436 bytes.
- Delta: -1,747 bytes.

## Verification Notes

- Every tracked scoped file is listed above with a disposition.
- Every delete candidate had a stale-reference `rg` check across `R/`,
  `tests/`, `vignettes/`, `inst/design/`, `dev/`, and `.github/`.
- The follow-up `getting-started` sweep found no live package-doc references
  after deleting `inst/examples/README.md`; remaining hits are archival design
  packet material plus this audit row.
- Reviewed deletion candidates were removed after review. No files were moved,
  migrated, or newly gitignored.
- Tarball size after cleanup is recorded in the LDG-2538 completion note.
- `R CMD build --no-build-vignettes` succeeded before and after cleanup.
- `R CMD check --no-manual --no-build-vignettes` completed on the post-cleanup
  tarball with the existing 2 warnings / 2 notes state: missing `inst/doc`
  vignette outputs and existing package-structure notes.
- `quarto render inst/design/manual` passed via RStudio's bundled Quarto.
- Full local tests were run. They failed only in `test-documentation-contracts.R`
  on stale generated-doc/manual assertions already routed to LDG-2539.
