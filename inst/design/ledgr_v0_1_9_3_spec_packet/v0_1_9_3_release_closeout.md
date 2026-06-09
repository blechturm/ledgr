# v0.1.9.3 Release Closeout

**Status:** Local release gate complete; branch ready for remote CI, merge, and
tag.
**Date:** 2026-06-09.
**Branch:** `v0.1.9.3`.
**Accepted synthesis:**
`inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`.
**Spec packet:** `inst/design/ledgr_v0_1_9_3_spec_packet/`.

## Scope Closed

v0.1.9.3 ships the first target-risk layer:

- classed public risk constructors:
  `ledgr_risk_none()`, `ledgr_risk_chain()`,
  `ledgr_risk_long_only()`, and `ledgr_risk_max_weight()`;
- canonical risk identity through `risk_chain_hash` and `risk_plan_json`;
- no-op-normalized risk identity in committed-run config hashes;
- a behavior-preserving phased-pulse fold substrate with the risk slot between
  strategy target validation and fill timing;
- bounded built-in target transforms for long-only and max-weight risk;
- risk identity in sweep rows, saved-sweep schema v2, promotion provenance, and
  reopened candidates;
- parallel and compiled-path safety checks for risk-enabled sweep execution.

## Non-Scope Preserved

The packet does not ship arbitrary risk callbacks, affordability enforcement,
liquidity or capacity policy, OMS behavior, broker-grade shorting or margin
semantics, portfolio optimization, target-construction helper expansion,
walk-forward implementation, statistical-validation diagnostics,
`failure_type` saved-sweep columns, cost estimation inside risk, or compiled
core architecture changes.

## Gate Evidence

- Read `inst/design/release_ci_playbook.md` before package-gate work.
- Targeted documentation and target-risk tests passed:
  `test-documentation-contracts.R`, `test-risk-model.R`, and
  `test-risk-config.R`.
- Full local tests passed:
  `testthat::test_local('.', reporter = 'summary')`.
  Result: passed with one optional Yahoo-path skip.
- README cold-start passed:
  `Rscript --vanilla tools/check-readme-example.R`.
- Source build passed:
  `R CMD build --no-build-vignettes .`.
  Result: built `ledgr_0.1.9.3.tar.gz`; emitted known long archival design path
  warnings.
- Package check passed:
  `R CMD check --no-manual --no-build-vignettes ledgr_0.1.9.3.tar.gz`.
  Result: tests, examples, and vignette R code passed. Accepted warnings are
  the existing no-`inst/doc` vignette warnings. Accepted NOTE is the existing
  long archival design path NOTE.
- Coverage gate passed:
  `Rscript tools/check-coverage.R`.
  Result: 85.28% coverage, above the 80% gate.
- pkgdown build passed after adding the new target-risk help topic group to
  `_pkgdown.yml`.
- WSL/Ubuntu schema and persistence smoke gate passed:
  `test-schema-validator-side-effects.R`, `test-schema-snapshots.R`,
  `test-schema.R`, and `test-persistence-fresh-connection.R`.

## Reruns And Dispositions

- A plain `R CMD build .` attempted to build rendered Quarto vignettes and
  failed on missing rendered outputs. The release playbook gate uses
  `R CMD build --no-build-vignettes .`, which passed.
- The first pkgdown run failed because Quarto was not on PATH. Rerun with the
  installed RStudio Quarto path succeeded after `_pkgdown.yml` was patched to
  index `ledgr_risk_chain`.
- The first WSL gate failed because stale Windows-built `src/*.o` artifacts
  were visible to the Linux linker. Local compiled artifacts were removed and
  the WSL gate passed from a clean compile state.

## Release Status

All `LDG-2597` through `LDG-2611` tickets are complete. The branch is ready for
remote CI, merge to `main`, main CI, tag `v0.1.9.3`, tag CI, and GitHub Release
creation per `inst/design/release_ci_playbook.md`.
