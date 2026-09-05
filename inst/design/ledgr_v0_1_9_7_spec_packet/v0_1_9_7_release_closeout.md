# v0.1.9.7 Release Closeout

**Status:** Local release gate complete after review; ready for remote CI,
merge, and tag.
**Date:** 2026-09-05.
**Branch:** `v0.1.9.7`.
**Accepted synthesis:**
`inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`.
**Spec packet:** `inst/design/ledgr_v0_1_9_7_spec_packet/`.

## Scope Closed

v0.1.9.7 extends the validation arc from diagnostics into evidence-only
eligibility. It ships:

- a public source-neutral `ledgr_return_panel()` with a deterministic
  evidence-only `panel_hash`, plus renamed panel-or-sweep diagnostics;
- opt-in retained closed-trade evidence and `ledgr_sweep_trades()`;
- native K-Ratio using the pinned Kestner (2013) compounded-return definition;
- seven classed, serializable, hashable business-objective criteria plus named
  DSR and MinTRL evidence thresholds;
- the accepted strict-lattice stable-region criterion;
- `ledgr_sweep_filter()` as an all-candidates criterion tear-down that cannot
  rank, select, promote, or enter walk-forward selection;
- a warning-only intraday metric-context cadence guardrail that changes no
  metric, execution behavior, or identity; and
- the rebuilt Selection Integrity article with visible return-panel inputs and
  executed cautionary contrasts.

## Non-Scope Preserved

The packet does not ship automatic selection or promotion,
objective-filtered walk-forward identity, scored or weighted objective
composition, a public third-party criterion contract, broader non-lattice
robustness criteria, Triple Penance, cadence-aware walk-forward warnings, the
bounded intraday example, first-class intraday runtime, purging/embargo/CPCV,
benchmark-relative diagnostics, portfolio optimization, point-in-time data,
OMS, broker reconciliation, paper/live trading, liquidity/capacity policy, or
a compiled spot-FIFO default flip.

`business_objective_hash` and `panel_hash` remain evidence provenance. They do
not participate in run, sweep, candidate, promotion, session, or walk-forward
identity.

## Gate Evidence

- Read `inst/design/release_ci_playbook.md` before package-gate work.
- Confirmed branch `v0.1.9.7`, clean pre-gate status, and DESCRIPTION version
  `0.1.9.7`.
- Full local tests passed:
  `testthat::test_local('.', reporter = 'summary')`.
  Result: passed in 687.4 seconds with the existing Yahoo missing-package-path
  skip because `quantmod` is installed.
- README cold-start passed:
  `Rscript --vanilla tools/check-readme-example.R`.
  Result: installed ledgr 0.1.9.7 into a temporary library and executed README
  chunks under installed-package semantics.
- Source build passed:
  `R CMD build --no-build-vignettes .`.
  Result: built `ledgr_0.1.9.7.tar.gz` with the two known long archival-design
  path warnings.
- Package check passed:
  `R CMD check --no-manual --no-build-vignettes ledgr_0.1.9.7.tar.gz`.
  Result: examples, tests, Rd checks, and all 19 executable vignette sources
  passed. The accepted status is two existing `vignettes`/missing-`inst/doc`
  warnings and one existing long archival-path NOTE. The sandbox could not
  query CRAN/Bioconductor package indexes; dependency checks against the local
  release library passed, and remote CI remains authoritative.
- Coverage gate passed:
  `Rscript tools/check-coverage.R`.
  Result: 85.49%, above the 80% gate.
- Full pkgdown build passed through `Rscript dev/build-site.R` after the
  sandbox retry described below. The generated site contains the v0.1.9.7
  reference and Selection Integrity surfaces.
- Local WSL/Ubuntu gate passed on R 4.5.2 after compiled-artifact cleanup:
  the four playbook-minimum DuckDB tests plus sweep retention, sweep
  persistence roundtrip, business-objective plan and criteria, sweep filter,
  and metric-context tests all passed.
- WSL had no Quarto executable. The changed Selection Integrity source was
  therefore executed through `knitr::knit()` into `/tmp`; every R chunk passed
  without modifying the checked-in Markdown mirror. The full Quarto/pkgdown
  render passed on Windows.

## Reruns And Dispositions

- The first pkgdown build reached site initialization and failed with sandbox
  `EPERM` while statting `C:/Users/maxth`. The same repository wrapper was
  rerun with approved access to the user library and Quarto/Pandoc paths and
  passed in 391.6 seconds.
- The first WSL test command failed before test execution because Windows
  `src/*.o` artifacts were visible to the Linux linker. Only generated
  `src/cpp11.o`, `src/spot_fifo.o`, and the compiled library were removed. The
  exact WSL gate was rerun from clean source, rebuilt with the Linux toolchain,
  and passed.
- Full tests, coverage, build/check, pkgdown, and WSL generated local
  `Rplots.pdf`, coverage, a v0.1.9.7 tarball, a check directory, and compiled
  `src/` artifacts. Those gate artifacts were removed and are not part of the
  release diff; older ignored release archives were outside this gate.
- Removing the compiled `src/` artifacts means source-tree
  `pkgload::load_all()` must rebuild them. This local machine currently lacks
  the `decor` helper needed by that developer-only path. Standard package
  build, check, install, and remote-CI compilation passed or remain unaffected.

## Release Status

All v0.1.9.7 implementation batches have completed local release gates and
review. After this closeout commit, the next steps are remote branch CI, merge
to `main`, green main CI, tag `v0.1.9.7`, green tag CI, and GitHub Release
creation in the order required by
`inst/design/release_ci_playbook.md`.
