# v0.1.9.5 Release Closeout

**Status:** Local release gate complete; branch ready for remote CI, merge, and
tag.
**Date:** 2026-06-13.
**Branch:** `v0.1.9.5`.
**Accepted synthesis:**
`inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md`.
**Spec packet:** `inst/design/ledgr_v0_1_9_5_spec_packet/`.

## Scope Closed

v0.1.9.5 is a naming, teaching, contract, and audit-hardening release after the
v0.1.9.1-v0.1.9.4 feature arc. It ships:

- the public API naming-consistency pass and consolidated rename table;
- candidate extraction through `ledgr_candidate()` and walk-forward snapshot
  locator verification;
- scheduled v0.1.9.4 deep-review hardening in runner/results behavior,
  accounting, timestamp hashing, compiled spot-FIFO validation, and contracts;
- split and refreshed vignette teaching surfaces for quickstart, risk/cost,
  walk-forward, strategy authoring, snapshots, and metric conventions;
- additive review helpers `ledgr_sweep_review()` and `ledgr_temp_store()`;
- maintainer manual articles for target risk, cost resolver flow, and
  walk-forward machinery.

## Non-Scope Preserved

The packet does not ship validation-toolkit statistics, strategy decorators,
crypto-readiness work, target-construction helper expansion, the standalone
debugging article, additional sweep/metric-context splits, lower-value
vignette-audit helpers, paired entry/exit trade views, promotion-recovery
summaries, OMS behavior, paper trading, live trading, or default compiled
execution.

## Gate Evidence

- Read `inst/design/release_ci_playbook.md` before package-gate work.
- DESCRIPTION version bumped to `0.1.9.5` before release gates.
- Full local tests passed:
  `testthat::test_local('.', reporter = 'summary')`.
  Result: passed with one optional Yahoo-path skip.
- README cold-start passed:
  `Rscript --vanilla tools/check-readme-example.R`.
- Source build passed:
  `R CMD build --no-build-vignettes .`.
  Result: built `ledgr_0.1.9.5.tar.gz`; emitted known long archival design path
  warnings.
- Package check passed:
  `R CMD check --no-manual --no-build-vignettes ledgr_0.1.9.5.tar.gz`.
  Result: examples, tests, and vignette R code passed. Accepted warnings are
  the existing no-`inst/doc` vignette warnings. Accepted NOTE is the existing
  long archival design path NOTE.
- Coverage gate passed:
  `Rscript tools/check-coverage.R`.
  Result: 85.69% coverage, above the 80% gate.
- pkgdown build passed with explicit local Quarto path:
  `QUARTO_PATH=C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe`.
- WSL/Ubuntu schema and persistence smoke gate passed:
  `test-schema-validator-side-effects.R`, `test-schema-snapshots.R`,
  `test-schema.R`, and `test-persistence-fresh-connection.R`.
- Naming / release sweeps passed:
  old-name hits are confined to NEWS and design history; release context points
  at the active v0.1.9.5 packet; DESCRIPTION and NEWS both name 0.1.9.5.

## Reruns And Dispositions

- The first `R CMD check` command exceeded the initial 15 minute tool timeout
  while running vignette R code. The underlying check continued and completed
  successfully with the accepted warnings and NOTE above. Per the release
  playbook, this timeout is recorded as a release-gate timeout rather than a
  package failure.
- The first pkgdown run failed because `_pkgdown.yml` did not list the new
  `print.ledgr_walk_forward_degradation` topic. The reference index entry was
  added beside the walk-forward topics and the rerun passed.
- The first WSL gate failed before tests because stale Windows-built
  `src/*.o` objects were visible to the Linux linker. The local object files
  were removed and the WSL gate passed from a clean Linux compile state.
- Quarto/pkgdown generated local `tests/testthat/Rplots.pdf` and
  `vignettes/.gitignore` artifacts. They were removed and were not committed.

## Release Status

All v0.1.9.5 implementation batches have passed local release gates. The branch
is ready for remote branch CI, merge to `main`, main CI, tag `v0.1.9.5`, tag CI,
and GitHub Release creation per `inst/design/release_ci_playbook.md`.
