# ledgr Agent Notes

This repository is an R package for deterministic, snapshot-backed,
event-sourced backtesting. Keep changes scoped to the active ticket and preserve
the v0.1.2 invariants.

## Core Rules

- Do not add a second execution path. User-facing wrappers must end in
  `ledgr_run()` / `ledgr_backtest_run()`.
- Do not bypass snapshot creation, sealing, hash verification, or no-lookahead
  pulse execution.
- Interactive tools must remain read-only against persistent ledgr tables.
- Functional strategies must return full named numeric target vectors, or use an
  explicit wrapper such as `ledgr_signal_strategy()` that maps to those targets.
- Do not silently treat missing strategy targets as zero.
- Do not commit generated local artifacts: `*.tar.gz`, `*.Rcheck/`,
  `coverage.html`, `tests/testthat/Rplots.pdf`.

## Useful Files

- Spec: `inst/design/ledgr_v0_1_2_spec_packet/v0_1_2_spec.md`
- Tickets: `inst/design/ledgr_v0_1_2_spec_packet/v0_1_2_tickets.md`
- Machine-readable tickets:
  `inst/design/ledgr_v0_1_2_spec_packet/tickets.yml`
- Contract index: `inst/design/contracts.md`
- ADRs: `inst/design/adr/`

## Local Verification

Windows R path used in this workspace:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', reporter='summary')"
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD build .
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD check --no-manual --no-build-vignettes ledgr_0.1.2.tar.gz
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
5. Update `v0_1_2_tickets.md` checkboxes and `tickets.yml` status together.
