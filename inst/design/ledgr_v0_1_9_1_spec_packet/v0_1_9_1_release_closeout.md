# ledgr v0.1.9.1 Release Closeout

Date: 2026-06-05
Branch: `v0.1.9.1`
Ticket: `LDG-2574`

## Scope Closed

v0.1.9.1 closes the public transaction-cost API packet. It shipped classed
cost-model constructors, ordered cost-chain composition, cost and timing
inspection helpers, explicit `timing_model`, required `cost_model`, legacy
shape rejection, and deterministic cost identity through `cost_model_hash` and
`cost_plan_json`.

The release keeps cost application separate from liquidity, quantity mutation,
target risk, OMS lifecycle semantics, broker reconciliation, financing, taxes,
and TCA. Those remain future packets or later roadmap work.

## Release Metadata

- `DESCRIPTION` version updated to `0.1.9.1`.
- `NEWS.md` has a v0.1.9.1 entry.
- Design index, roadmap, AGENTS.md, ticket markdown, ticket YAML, and batch plan
  reflect the closed packet.
- `vignettes/research-to-production.qmd` and
  `vignettes/research-to-production.md` reflect the v0.1.9.1 cost API surface
  without retaining legacy cost/timing field references.

## Verification

Local release-gate verification completed on 2026-06-05:

- Targeted cost, timing, identity, run-store, sweep, and documentation-contract
  checks passed.
- Full Windows source tests passed with one expected Yahoo optional-package
  skip.
- Focused WSL schema/persistence tests passed after removing stale compiled
  objects left by the Windows/WSL toolchain switch.
- Edited vignettes rendered through the local Quarto executable.
- Plain `R CMD build .` still hits the established Quarto multi-format product
  issue. The accepted release build path,
  `R CMD build --no-build-vignettes .`, passed with existing long-path
  warnings.
- `R CMD check --no-manual --no-build-vignettes ledgr_0.1.9.1.tar.gz` passed
  with expected no-vignettes warnings and the existing long-path note.
- `tools/check-coverage.R` passed at 85.55% coverage.
- `pkgdown::build_site()` passed after adding the v0.1.9.1 cost API reference
  topics to `_pkgdown.yml`.

## Remaining Release Playbook Steps

After the local release-gate commit, push `v0.1.9.1`, wait for branch CI, merge
to `main`, wait for main CI, tag `v0.1.9.1`, wait for tag CI, and create or
update the GitHub Release according to `inst/design/release_ci_playbook.md`.
