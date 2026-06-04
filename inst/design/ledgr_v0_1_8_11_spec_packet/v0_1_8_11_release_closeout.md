# ledgr v0.1.8.11 Release Closeout

Date: 2026-06-04
Branch: `v0.1.8.11`
Ticket: `LDG-2537`

## Scope Closed

v0.1.8.11 closes the documentation, structure, and cleanup cycle before
v0.1.9 feature planning. The release did not change public API, execution
semantics, event schema, durable identity bytes, compiled-accounting scope,
target-risk behavior, walk-forward behavior, OMS behavior, or cost/liquidity
surfaces.

The packet now has all tickets complete. The deferred manual families from
LDG-2532 are authored in this release: observability/determinism, snapshots and
data, sweep, features, and benchmark methodology. All seven manual articles
carry the Section 3.7 two-layer standard: Synthesis plus Implementation Trace.
The `adr/`, `architecture/`, and `maintainer_review/` directories are wound
down to README ledgers.

## Release Metadata

- `DESCRIPTION` version updated to `0.1.8.11`.
- `NEWS.md` has a v0.1.8.11 entry.
- Design index, roadmap, horizon, AGENTS.md, ticket markdown, ticket YAML, and
  batch plan reflect the closed packet.
- `inst/design/horizon.md` records that no v0.1.8.12 documentation follow-on is
  planned from this cycle.

## Verification

Completed locally on Windows with R 4.5.2:

- `Rscript tools/render-maintainer-manual.R` passed.
- `quarto render vignettes/sweeps.qmd --to gfm` passed with explicit
  `QUARTO_R`.
- `quarto render vignettes/research-workflow.qmd --to gfm` passed with
  explicit `QUARTO_R`.
- `testthat::test_file("tests/testthat/test-documentation-contracts.R")`
  passed.
- `testthat::test_local(".", reporter = "summary")` passed with one expected
  skip for the missing-package Yahoo snapshot path.
- `R CMD build --no-build-vignettes .` passed.
- `R CMD check --no-manual --no-build-vignettes ledgr_0.1.8.11.tar.gz` passed
  with accepted caveats below.
- `pkgdown::build_site(new_process = FALSE, install = FALSE)` passed after
  setting `QUARTO_PATH`, `QUARTO_R`, and `RSTUDIO_PANDOC`.
- `git diff --check` passed after final release-gate edits.

## Accepted Caveats

- `R CMD check --no-manual --no-build-vignettes` reports the expected
  no-built-vignettes warnings. This is the release playbook check mode used for
  local verification.
- `R CMD check` reports existing non-portable long-path notes for two
  v0.1.8.10 spike prompt/review records. They are archival design records and
  are not a v0.1.8.11 execution or documentation-regression finding.
- A plain `R CMD build .` attempts full HTML vignette rendering and is not the
  local release-gate path for this package; the accepted local package artifact
  was built with `--no-build-vignettes`.

## Generated Artifact Cleanup

Release-gate build/check artifacts were removed before commit:

- `ledgr_0.1.8.11.tar.gz`
- `ledgr.Rcheck/`
- `tests/testthat/Rplots.pdf`
- Quarto-local generated state under vignette/manual render paths

## Remaining Release Playbook Steps

After review, merge `v0.1.8.11` to `main`, push the release branch/main, and tag
the version according to `inst/design/release_ci_playbook.md`.
