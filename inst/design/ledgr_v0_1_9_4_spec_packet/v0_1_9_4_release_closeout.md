# v0.1.9.4 Release Closeout

**Status:** Local release gate complete; branch ready for remote CI, merge, and
tag.
**Date:** 2026-06-11.
**Branch:** `v0.1.9.4`.
**Accepted synthesis:**
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`.
**Spec packet:** `inst/design/ledgr_v0_1_9_4_spec_packet/`.

## Scope Closed

v0.1.9.4 ships the first walk-forward evaluation surface:

- calendar-time fold definitions and validated fold windows;
- one shared execution path through `ledgr_sweep()` and `ledgr_run()`;
- train-window scalar candidate scoring and classed selection rules;
- selected-candidate test runs with promotion-ready candidate extraction;
- walk-forward session identity through `session_id`;
- fold/window/candidate identity through `candidate_key`;
- cost and risk identity handoff through `cost_model_hash` and
  `risk_chain_hash`;
- compact walk-forward persistence, reopen, inspection, and degradation-first
  result surfaces.

## Non-Scope Preserved

The packet does not ship selection-integrity diagnostics, PBO/CSCV/CPCV, DSR,
purging/embargo, randomized or blocked slice protocols, cross-snapshot
walk-forward, evaluation registries, ML-first tooling, candidate clustering,
benchmark-relative metrics, top-N or all-candidate test retention,
gross-vs-net attribution, signal decay, implementation/cost decay,
liquidity/capacity policy, OMS behavior, paper/live walk-forward,
target-construction helper expansion, risk-chain constraint expansion, or
compiled-core architecture work.

## Gate Evidence

- Read `inst/design/release_ci_playbook.md` before package-gate work.
- Targeted walk-forward tests passed:
  `test-walk-forward-folds.R`, `test-walk-forward-identity.R`,
  `test-walk-forward-orchestrator.R`, `test-walk-forward-schema.R`, and
  `test-walk-forward-selection.R`.
- Full local tests passed:
  `testthat::test_local('.', reporter = 'summary')`.
  Result: passed with one optional Yahoo-path skip.
- README cold-start passed:
  `Rscript --vanilla tools/check-readme-example.R`.
- Source build passed:
  `R CMD build --no-build-vignettes .`.
  Result: built `ledgr_0.1.9.4.tar.gz`; emitted known long archival design path
  warnings.
- Package check passed:
  `R CMD check --no-manual --no-build-vignettes ledgr_0.1.9.4.tar.gz`.
  Result: tests, examples, and vignette R code passed. Accepted warnings are
  the existing no-`inst/doc` vignette warnings. Accepted NOTE is the existing
  long archival design path NOTE.
- Coverage gate passed:
  `Rscript tools/check-coverage.R`.
  Result: 85.53% coverage, above the 80% gate.
- pkgdown build passed with explicit local Quarto path:
  `QUARTO_PATH=C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe`.
- WSL/Ubuntu schema and persistence smoke gate passed:
  `test-schema-validator-side-effects.R`, `test-schema-snapshots.R`,
  `test-schema.R`, and `test-persistence-fresh-connection.R`.

## Reruns And Dispositions

- The first full local test run failed only because release-pointer contract
  assertions still expected v0.1.9.3 as the latest completed packet and expected
  the v0.1.9.4 Section 17 horizon entry to remain open. The release-closeout
  assertions were updated and the documentation contract plus full local tests
  passed.
- The first `R CMD check` run failed one source-inspection test because
  `R/fold-engine.R` is not available at the repo-relative path in the installed
  package check layout. The test now skips only when that source file is absent;
  source-tree execution still enforces the guard. The rerun passed.
- The first pkgdown run failed because Quarto was not on PATH. Rerun with
  `QUARTO_PATH` reached reference metadata and found two public walk-forward
  topics missing from `_pkgdown.yml`; `ledgr_fold` and `ledgr_select_argmax`
  were added to the Experiment Workflow reference group. The rerun passed.
- The WSL gate initially required installing missing local WSL R dependencies
  (`decor`, `collapse`, and `yyjsonr`). After dependencies were present, the
  gate hit stale Windows-built `src/*.o` objects visible to the Linux linker.
  Local compiled artifacts were removed and the WSL gate passed from a clean
  compile state.
- A deep code review audit found no v0.1.9.4 release blockers. Its findings
  are recorded in `inst/design/audits/v0_1_9_4_deep_code_review_audit.md` for
  the next cycle.

## Release Status

All `LDG-2612` through `LDG-2626` tickets are complete. The branch is ready for
remote CI, merge to `main`, main CI, tag `v0.1.9.4`, tag CI, and GitHub Release
creation per `inst/design/release_ci_playbook.md`.
