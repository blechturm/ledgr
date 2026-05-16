# ledgr Agent Notes

This repository is an R package for deterministic, snapshot-backed,
event-sourced backtesting. Keep changes scoped to the active ticket and preserve
the execution contracts in `inst/design/contracts.md`.

## Core Rules

- Do not add a second execution engine. `ledgr_run()` is the committed-run
  execution entry point. `ledgr_sweep()` must share the same internal fold core and
  must not introduce a second execution path.
- Do not bypass snapshot creation, sealing, hash verification, or no-lookahead
  pulse execution.
- Interactive tools must remain read-only against persistent ledgr tables.
- Functional strategies must return full named numeric target vectors, or use an
  explicit wrapper such as `ledgr_signal_strategy()` that maps to those targets.
- Do not silently treat missing strategy targets as zero.
- Do not commit generated local artifacts: `*.tar.gz`, `*.Rcheck/`,
  `coverage.html`, `tests/testthat/Rplots.pdf`.
- Use UTF-8 or ASCII encoding only. Do not introduce other encodings in R
  source, test, or design files.

## Design Documents

Read before implementing any non-trivial change:

- Design index: `inst/design/README.md`
- Execution contracts (authoritative): `inst/design/contracts.md`
- Milestone roadmap: `inst/design/ledgr_roadmap.md`
- ADRs: `inst/design/adr/`

Active cycle (v0.1.8.1 — update this block each cycle):

- Spec: `inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_spec.md`
- Tickets: `inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_tickets.md`
- Machine-readable tickets: `inst/design/ledgr_v0_1_8_1_spec_packet/tickets.yml`

## Active Design Entry Points

Read these before working in the listed areas. They are accepted design decisions
binding for their stated release scope unless marked otherwise. v0.1.8.1
implementation is limited to the active spec packet.

| Area | Read |
| --- | --- |
| Sweep performance / optimization | `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md` |
| Multi-output indicator authoring | `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md` |
| Metric context / risk metrics | `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` (accepted for v0.1.8.2) |
| v0.1.9 risk layer / tiered output | `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary.md`, `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_response.md` (RFC under review) |

## Local Verification

Windows R path used in this workspace:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', reporter='summary')"
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD build .
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD check --no-manual --no-build-vignettes ledgr_<version>.tar.gz
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" tools/check-coverage.R
```

Targeted checks are preferred while editing, followed by full tests and package
check before committing release-ticket work.

## Ticket Workflow

1. Read the ticket, its dependencies, and the relevant contract section.
2. Add or update tests for the acceptance criteria.
3. Implement the smallest change that satisfies the ticket.
4. Run targeted tests, then full tests/package checks when the change affects
   public API, runner behavior, snapshots, CI, or release gates.
5. Update the active `tickets.md` checkboxes and `tickets.yml` status together.
