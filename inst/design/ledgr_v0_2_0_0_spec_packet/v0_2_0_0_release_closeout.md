# v0.2.0.0 Release Closeout

**Status:** Local release gate complete after maintainer review; ready for
remote CI, merge, and tag.
**Date:** 2026-09-13.
**Branch:** `v0.2.0.0`.
**Implementation baseline:** `970489eee5390754eee379e474d46e16195313ec`.
**Spec packet:** `inst/design/ledgr_v0_2_0_0_spec_packet/`.

## Scope Closed

v0.2.0.0 combines API and representation hardening with ledgr's first
point-in-time asset-availability workflow. It ships:

- corrected reversal-fee projection, eager fill reads, restored ranked-sweep
  lineage, explicit risk restoration, and recorded run risk identity;
- durable run locators, a corrected named-target workflow, and the four-stage
  mechanical extraction of the existing run coordinator;
- normalized point-in-time fact families, a complete session clock, invalid-row
  quarantine, availability-aware snapshot identity, and transactional storage;
- dynamic member-plus-held decision axes, strict expected-session feature gaps,
  stable per-asset state, target restrictions, stale-mark valuation, bounded
  affordability, and controlled incomplete outcomes on the shared fold;
- public facts inspection, availability and diagnostic result views, run
  explanations, completion-aware inventory, and explicit incomplete-comparison
  refusal; and
- the executable Survivorship Bias article plus honest completion and
  closed-trade print defaults.

No second engine, general short financing, settlement economics, OMS,
imputation framework, or representation optimization is introduced.

## Environment

Windows gates used R 4.6.1 on Windows 11, DuckDB 1.5.5, dplyr 1.2.1,
testthat 3.3.2, covr 3.6.5, mirai 2.7.2, pbo 1.3.5, quantmod 0.4.29,
quarto R package 1.5.1, and pkgdown 2.2.1. WSL used Ubuntu, R 4.5.2, and
DuckDB 1.5.2. The WSL image had no Quarto executable.

## Local Gate Evidence

- The full Windows source suite passed in 811.2 seconds with no failures,
  errors, or test-attributed warnings. The only conditional skip was the
  missing-quantmod path because quantmod was installed. The six parallel-sweep
  tests ran outside covr.
- `Rscript --vanilla tools/check-readme-example.R` passed under installed-package
  semantics in 26.9 seconds.
- `Rscript tools/render-vignettes-gfm.R --check --all` executed and verified all
  20 QMD-to-GFM siblings in 186.8 seconds.
- `Rscript dev/build-site.R` built the full pkgdown 2.2.1 site in 428.2 seconds.
  Its post-build scan found no DuckDB shared-home notice in 24 rendered articles.
- `tools::checkRd()` passed all 149 Rd files.
- `R CMD build .` completed in 373.5 seconds and built
  `ledgr_0.2.0.0.tar.gz`, including all package vignettes.
- `R CMD check --no-manual --no-build-vignettes ledgr_0.2.0.0.tar.gz`
  completed in 1023.6 seconds with `Status: OK`. Installation, examples,
  tests, and execution of all 20 vignettes passed with no errors, warnings,
  or notes.
- The four playbook-minimum WSL persistence tests passed on R 4.5.2 and DuckDB
  1.5.2: schema-validator side effects, snapshot schema, general schema, and
  fresh-connection persistence.
- `Rscript tools/check-coverage.R` passed on WSL/Linux at 85.92 percent, above
  the required 80 percent.

## Release Chores

- Package-owned DuckDB drivers request session-local extension and secret
  storage when the installed version supports it. DuckDB 1.5.5 uses the quiet
  path; DuckDB 1.5.2 uses its compatible native driver. No global message or
  warning suppression was added.
- The GFM renderer now has a full freshness mode that renders copied sources in
  an ignored temporary directory, normalizes only documented volatile output,
  and compares every committed sibling.
- A documentation contract resolves every relative local image reference in
  `vignettes/*.md`. Three existing figure artifacts that were hidden by a broad
  ignore rule are now tracked explicitly.
- `tests/testthat/Rplots.pdf` is ignored and excluded from source packages.
- CRAN package `pbo` is declared in `Suggests`. The `quantstrat` numerical
  comparison moved to `dev/manual/verify-dsr-quantstrat.R` because quantstrat is
  unavailable on CRAN; it remains optional evidence and is not a runtime
  dependency.
- Three archival review/spike files with non-portable tar path lengths remain in
  the repository but are excluded from built source packages.

## Reruns And Dispositions

- The first source-package check found two source-only documentation tests that
  lacked installed-package guards and one unqualified `setNames()` call. The
  guards and `stats::setNames()` qualification were added; affected tests pass.
- WSL first encountered Windows object files under `src/`. Only generated
  objects and libraries were removed, after which the Linux persistence gate
  passed from clean sources.
- WSL DuckDB 1.5.2 does not expose the 1.5.5 `shared_home` argument. The driver
  became capability-aware rather than raising the package's minimum DuckDB
  version for a noise-suppression chore; both version paths pass.
- Two Windows coverage attempts exposed an installed-source assumption, a
  covr-only indicator-registry collision, and child-process loading of covr's
  instrumented DLL. The source guards were added, the feature test now uses the
  registered built-in indicator, and child processes load the installed package
  under covr while retaining source loading otherwise.
- A later Windows coverage collection completed its tests but failed reading a
  covr RDS shard. This was treated as a separate coverage-transport failure.
  The CI-matching Linux coverage run passed at 85.92 percent.
- Remote branch CI run `34784297278` reproduced the same covr shard-read
  failure on Ubuntu after README, acceptance, `R CMD check`, and pkgdown had
  passed. The one failed-job rerun allowed by the release playbook reproduced
  it; the first package frame was `ledgr_collect_coverage()` calling
  `covr::package_coverage()` before `readRDS()` failed.
- The two tests that launch fresh child R processes now skip only under covr.
  They remain active in ordinary tests and `R CMD check`, while coverage no
  longer depends on child-process finalizers writing readable trace shards.
  A preserved-shard WSL run passed at 85.95 percent with the 80 percent
  threshold unchanged. Remote branch CI must pass on the corrective commit
  before merge.
- WSL executable-documentation verification was unavailable because that image
  has no Quarto executable. The complete executable documentation surface passed
  on Windows; Linux pkgdown remains a distinct branch-CI gate.

## Maintainer Acceptance And Remote Evidence

The maintainer accepted Batch 16 on 2026-09-13 after reviewing the completed
local evidence and determining that another independent review cycle was not
proportionate to the narrow production delta. Branch CI, merge to `main`, main
CI, tag `v0.2.0.0`, tag CI, and the GitHub Release remain separate later
evidence in the order required by `inst/design/release_ci_playbook.md`.
