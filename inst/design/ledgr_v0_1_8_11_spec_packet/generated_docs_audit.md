# Generated Docs And Man-Page Audit

**Ticket:** LDG-2536
**Status:** Completed after Claude review
**Date:** 2026-06-04
**Scope:** `man/`, `inst/doc/`, and `vignettes/`

## Summary

This audit reviewed generated help pages, generated or rendered vignette
siblings, and vignette sources for stale execution, sweep, B2, benchmark, and
contract language after the v0.1.8.x optimization and documentation arc.

No generated documentation changes were made in this batch. The findings below
route source-doc and render-process work for review before any generated
artifact churn lands.

## Inventory

- `man/`: 120 roxygen-generated `.Rd` files.
- `inst/doc/`: absent in the working tree; there are no committed installed
  vignette artifacts to audit in this directory.
- `vignettes/`: 13 `.qmd` source files and 11 tracked rendered `.md` siblings.
  The two article sources under `vignettes/articles/` do not have tracked `.md`
  siblings.

## Checks Run

```text
rg --files man inst/doc vignettes
rg -n -i "future sweep mode|future sweep|v0\.1\.7|v0\.1\.8\.[0-9]|v0\.2\.x|db_live|raw bars|R6|data_hash|compiled_accounting_model|Backtrader|benchmark|audit_log" man vignettes -g "*.Rd" -g "*.qmd" -g "*.md"
rg -n "Config Hash:|Elapsed Sec:|Snapshot Hash:|Run ID:|Started At:|Completed At:|Execution Mode:" vignettes -g "*.md"
rg -n "raw bars|R6|data_hash|ctx\$targets|ctx\$current_targets|missing strategy targets|silently" man vignettes -g "*.Rd" -g "*.qmd" -g "*.md"
rg -n "v0\.1\.7|v0\.1\.8\.5|v0\.1\.8\.8" R man -g "*.R" -g "*.Rd"
```

The first command reports that `inst/doc` does not exist. This is an inventory
fact, not a failure.

## Findings

| ID | Classification | Files | Consuming Ticket | Finding | Recommendation |
| --- | --- | --- | --- | --- | --- |
| GD-001 | fix-now | `vignettes/research-to-production.qmd`; `vignettes/research-to-production.md` | LDG-2539 | The article still presents v0.1.8.6, v0.1.8.7, and v0.1.8.8 as future/planned roadmap cycles. Those cycles are now completed release records. | Reword the section to a versionless "current research layer / deferred production surfaces" description, then render only the matching `.md` changes. |
| GD-002 | fix-now | `vignettes/reproducibility.qmd`; `vignettes/reproducibility.md` | LDG-2539 | The article says "future sweep workers" and "future sweep mode" even though sweep mode and parallel worker semantics now exist. | Replace with current wording about ordinary runs, sweep mode, and parallel workers; render the tracked `.md` sibling. |
| GD-003 | fix-now | `vignettes/experiment-store.qmd`; `vignettes/experiment-store.md` | LDG-2539 | The experiment-store article says the public roadmap keeps point-in-time regressor work out of v0.1.8.5. The boundary is still valid, but the version pin is stale. | Reword to a versionless deferred-surface note; render only source-matching `.md` changes. |
| GD-004 | fix-now | `R/backtest.R`; `man/ledgr_backtest.Rd`; `man/ledgr_run.Rd` | LDG-2539 | Roxygen text still says v0.1.7 introduced the experiment-first workflow and that `ledgr_run()` is the v0.1.7 single-run API. | Make the public help text versionless, then regenerate affected `.Rd` files from source. |
| GD-005 | fix-now | `R/experiment.R`; `man/ledgr_opening.Rd`; `man/ledgr_experiment.Rd`; `man/ledgr_opening_from_broker.Rd` | LDG-2539 | Roxygen/man text still names v0.1.7 for current opening, experiment, and broker-adapter boundary language. | Remove stale version pins from public help text. Keep any runtime error-message version references only if review decides they are useful migration hints. |
| GD-006 | fix-now | `R/param-grid.R`; `man/ledgr_feature_grid.Rd` | LDG-2539 | The feature-grid help calls the helpers the canonical v0.1.8.5 authoring path. The path is still current, but the release-specific wording is stale. | Reword as "canonical authoring path" without the version pin; regenerate the affected help page. |
| GD-007 | defer-with-reason | `R/sweep.R`; `man/ledgr_sweep.Rd` | LDG-2539 | The sweep help says parallel interruption is discard-all in v0.1.8.8. The behavior is still current, but the version pin reads like release history in user help. | Prefer versionless wording in public docs. Defer until the roxygen cleanup pass so only source-driven `.Rd` churn lands. |
| GD-008 | process finding | `vignettes/experiment-store.md`; `vignettes/research-workflow.md`; `vignettes/reproducibility.md`; `tools/render-vignettes-gfm.R` | LDG-2539 | Claude's Batch 8 review found that rendering `research-workflow.qmd` changed live-output fields unrelated to the source edit. The audit also found drift-prone fields in `experiment-store.md`, `research-workflow.md`, and `reproducibility.md` (`Config Hash`, `Elapsed Sec`, run summaries, and execution-mode summaries). | Decide whether tracked `.md` siblings should avoid live-output fields, use deterministic/mocked output, or be committed only after a "diff matches source intent" gate. |
| GD-009 | no-action | `vignettes/sweeps.qmd`; `vignettes/sweeps.md`; `vignettes/strategy-development.qmd`; `vignettes/strategy-development.md`; `vignettes/articles/why-r.qmd`; `man/ledgr_run.Rd`; `man/ledgr_sweep.Rd` | None | B2 / `compiled_accounting_model = "spot_fifo"` language is scoped correctly: default remains `NULL`, opt-in is explicit, the accelerator is memory-backed and sweep-scoped, and durable `ledgr_run()` compiled integration fails closed. | Keep as is. |
| GD-010 | no-action | `vignettes/articles/why-r.qmd`; `vignettes/articles/who-ledgr-is-for.qmd` | None | Peer names such as Backtrader and benchmark framing appear only in narrative comparison surfaces. The scan did not find package-vignette speed marketing claims in generated docs. | Keep as is. |
| GD-011 | no-action | `man/`; `vignettes/` | None | Contract-stale terms removed in earlier cycles, including raw bars execution, R6 strategy execution, and durable `data_hash` identity, were not found in generated docs or vignettes. Deprecated `ctx$targets()` / `ctx$current_targets()` appeared only in source-level runtime diagnostics, not public generated help. | Keep as is. |
| GD-012 | no-action | `inst/doc/` | None | `inst/doc/` is absent, so there are no committed installed vignette artifacts to inspect in this tree. | Keep the audit result. Revisit only if future release tooling commits `inst/doc` artifacts. |

## Source / Generated Traceability

- `man/*.Rd` files are roxygen-generated and should be changed through their
  `R/*.R` source files, then regenerated.
- Tracked vignette `.md` siblings should be changed through the matching `.qmd`
  source and rendered with `tools/render-vignettes-gfm.R`.
- Batch 8 established an important guard: when rendering a tracked `.md`
  sibling, unrelated live-output drift must be reverted or separately routed.

## Proposed Next Steps

1. Review this audit and confirm the fix-now classifications.
2. Consume GD-001 through GD-008 in LDG-2539.
3. Render/regenerate only the artifacts whose sources changed.
4. Add a release-gate check or manual checklist item for GD-008 so generated
   markdown diffs are compared against source intent before commit.

## Verification Notes

- Stale-term `rg` checks were run against `man/` and `vignettes/`.
- Source/generated traceability was checked by matching `.Rd` findings to
  roxygen source files and `.md` findings to `.qmd` source files.
- No generated documentation artifacts were edited by this audit batch.
