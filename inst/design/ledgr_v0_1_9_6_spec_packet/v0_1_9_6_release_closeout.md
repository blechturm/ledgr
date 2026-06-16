# v0.1.9.6 Release Closeout

**Status:** Local release gate complete; branch ready for remote CI, merge, and
tag.
**Date:** 2026-06-16.
**Branch:** `v0.1.9.6`.
**Accepted synthesis:**
`inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`.
**Spec packet:** `inst/design/ledgr_v0_1_9_6_spec_packet/`.

## Scope Closed

v0.1.9.6 is a validation-substrate and selection-integrity diagnostics release.
It ships:

- canonical single-run returns through `ledgr_results(bt, what = "returns")`
  and `as_tibble(bt, what = "returns")`;
- retained-sweep return panels plus matrix, data-frame, and optional xts
  projections for adapter consumers;
- a reviewed PBO spike that chose a native implementation path and kept CRAN
  `pbo` as optional reference evidence only;
- native evidence-only PBO/CSCV, minimum-track-record length, DSR, and
  deterministic effective-trial clustering diagnostics;
- the Selection Integrity teaching surface under the Methodological Diagnostics
  styleguide rule;
- an audit-only intraday-readiness review; and
- an internal current-surface peer benchmark redo covering zero-cost/no-risk
  and representative cost/risk rows.

## Non-Scope Preserved

The packet does not ship business-objective filtering, objective-filtered
walk-forward identity, K-Ratio, Triple Penance, purging, embargo, CPCV,
benchmark-relative diagnostics, portfolio optimization, intraday runtime
support, public benchmark claims, broker adapters, paper trading, live trading,
or a compiled spot-FIFO default flip.

## Gate Evidence

- Read `inst/design/release_ci_playbook.md` before package-gate work.
- DESCRIPTION version bumped to `0.1.9.6` before final build/check.
- Rendered generated vignette mirrors through Quarto:
  `tools/render-vignettes-gfm.R vignettes/sweeps.qmd` and
  `tools/render-vignettes-gfm.R vignettes/selection-integrity.qmd`.
- Full local tests passed:
  `testthat::test_local('.', reporter = 'summary')`.
  Result: passed with the existing optional Yahoo-path skip.
- README cold-start passed:
  `Rscript --vanilla tools/check-readme-example.R`.
  Result: installed ledgr 0.1.9.6 into a temporary library and executed README
  chunks under installed-package semantics.
- Source build passed:
  `R CMD build --no-build-vignettes .`.
  Result: built `ledgr_0.1.9.6.tar.gz`; emitted the known long archival design
  path warnings.
- Package check passed:
  `R CMD check --no-manual --no-build-vignettes ledgr_0.1.9.6.tar.gz`.
  Result: examples, tests, and vignette R code passed. Accepted warnings are
  the existing no-`inst/doc` vignette warnings. Accepted NOTE is the existing
  long archival design path NOTE.
- Coverage gate passed:
  `Rscript tools/check-coverage.R`.
  Result: 85.69% coverage, above the 80% gate.
- pkgdown build passed:
  `pkgdown::build_site(new_process = FALSE, install = FALSE)` with local
  Quarto/Pandoc environment variables set.
- Documentation-contract test passed after the release-gate docs updates:
  `testthat::test_file('tests/testthat/test-documentation-contracts.R',
  reporter = 'summary')`.
- WSL/Ubuntu local gate was not run because `wsl -l -v` reported no installed
  Linux distributions. Remote Ubuntu CI remains the required Linux gate.

## Reruns And Dispositions

- The first `R CMD check` failed while running `selection-integrity.qmd` because
  the vignette setup loaded ledgr through `pkgload` only when rendered from the
  source tree. Installed-package vignette execution did not attach ledgr, so
  `ledgr_sweep_retention()` was unavailable. The setup chunk now falls back to
  `library(ledgr)` when the source tree is not present, the article was
  rerendered from Quarto, and the rerun passed.
- The first pkgdown build failed in the sandbox because pkgdown attempted a CRAN
  HTTP request and package cache writes outside the workspace. The same command
  was rerun with approved unsandboxed access and passed.
- Quarto/pkgdown/coverage/check generated local `tests/testthat/Rplots.pdf`,
  `coverage.html`, `ledgr_0.1.9.6.tar.gz`, and `ledgr.Rcheck` artifacts. They
  were removed and were not committed.

## Release Status

All v0.1.9.6 implementation batches have passed local release gates. The branch
is ready for remote branch CI, merge to `main`, main CI, tag `v0.1.9.6`, tag CI,
and GitHub Release creation per `inst/design/release_ci_playbook.md`.
