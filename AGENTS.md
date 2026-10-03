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
- Spikes, prototypes, and comparative experiments follow
  `inst/design/spike_protocol.md`: probe the package by execution before
  writing design prose, build the smallest runnable core before any expected
  table, keep provenance in the product rather than the harness, and deliver
  a runner, a diff-based checker, and a gut demonstration. Size budgets in
  that document are stop signals, not targets.
- Governance loop (accepted 2026-09-21, pilot on the next packet): the
  maintainer writes every operative brief and names its mode. `Type 1`
  verifies an accepted direction and always asks independently whether the
  inputs are right; `Type 2` challenges the design; a design concern found
  in Type 1 returns `NEEDS_TYPE_2`. Review is per workstream, not batch.
  `tickets.yml` is the sole ticket authority; batches produce no evidence
  essay; a decision-changing rejection gets a concise durable reason, which
  Git does not hold. Details: `inst/design/rfc_cycle.md`.
- Contracts and specifications define semantics. Canonical R is the
  normative executable oracle for optimized or compiled paths; runtime
  default is a separate decision; divergence fails closed pending an RFC.
- Code on ingest, seal, fold, hydration, finalisation, or result-reader paths
  follows the optimization coding style in
  `inst/design/manual/optimization_coding_style.qmd` (reviewable draft):
  no R-level iteration over collections that grow with bars, fact rows,
  instruments x pulses, events, diagnostics, or candidates; prepare and index
  once, read primitives by index, manifest data frames only at boundaries,
  write by index into typed buffers, and replace pairwise validators with
  grouped sweeps. Its seven named shapes are review criteria for any change on
  those paths; a new loop over such a collection needs a stated reason.
- This file stays operational and under 150 lines: rules, current state,
  entry points for open work, verification, and ticket workflow. Release
  history and packet narratives belong in `inst/design/ledgr_roadmap.md` and
  `inst/design/README.md`; when a packet closes, replace its bullet here with
  a pointer rather than appending its story.

## Design Documents

Read before implementing any non-trivial change:

- Design index: `inst/design/README.md`
- Execution contracts (authoritative): `inst/design/contracts.md`
- Milestone roadmap: `inst/design/ledgr_roadmap.md`
- RFC cycle process reference: `inst/design/rfc_cycle.md`
- Spike protocol (binding for spikes and prototypes): `inst/design/spike_protocol.md`
- Optimization coding style (maintainer manual; review criteria for hot-path,
  ingest, seal, and reader code): `inst/design/manual/optimization_coding_style.qmd`
- ADRs: `inst/design/adr/`

## Current State

Current planning context (2026-10-03):

- v0.2.1.0 is published. Its packet retains the historical
  `ledgr_v0_2_0_2_spec_packet/` path and is release evidence, not current
  implementation authority.
- The current release branch is `v0.2.2`. Its active packet is
  `inst/design/ledgr_v0_2_2_spec_packet/`; `tickets.yml` is the sole status and
  sequencing authority. Cut 1 Workstreams 1 through 4 are accepted and
  Workstream 5 is in progress.
- `inst/design/contracts.md` is the normative current-behavior source. Cite its
  stable topic headings, not line numbers. Accepted RFC syntheses bind pending
  design; they do not override shipped behavior before implementation.
- The roadmap is the compact committed sequence. Detailed v0.2.2 dependencies
  live in the packet macro plan, parked ideas in `horizon.md`, and displaced
  planning narrative in `roadmap_history.md` and
  `planning_context_history.md`.
- Reuse public capabilities and production semantics. Design only missing
  behavior; do not add research-specific manifests or parallel provenance.

## Active Design Entry Points

Start from the task, not from release history. Completed packets and archived
planning are evidence, not authorization for new work.

| Question | Start here |
| --- | --- |
| What is current behavior? | `inst/design/contracts.md`, by topic heading |
| What is being implemented now? | `inst/design/ledgr_v0_2_2_spec_packet/README.md`, then `tickets.yml` |
| What is the v0.2.2 dependency plan? | `inst/design/ledgr_v0_2_2_spec_packet/macro_plan.md` |
| Which accepted decisions are pending implementation? | `inst/design/decisions.md`, then the linked accepted source |
| Which RFC is active or due? | `inst/design/rfc/README.md` |
| Where is a non-binding idea parked? | `inst/design/horizon.md` |
| What is the cross-version sequence? | `inst/design/ledgr_roadmap.md` |
| Where is displaced planning history? | `inst/design/roadmap_history.md` and `inst/design/planning_context_history.md` |
| What governs optimization work? | `inst/design/manual/optimization_coding_style.qmd` and `inst/design/manual/benchmark_methodology.qmd` |
## Local Verification

Current Windows R path used here; it does not change the `DESCRIPTION` floor.

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', reporter='summary')"
& "C:\Program Files\R\R-4.6.1\bin\x64\R.exe" CMD build .
& "C:\Program Files\R\R-4.6.1\bin\x64\R.exe" CMD check --no-manual --no-build-vignettes ledgr_<version>.tar.gz
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" tools/check-coverage.R
```

Prefer targeted checks while editing, then full tests and package check.

Local pkgdown builds use `dev/build-site.R`. It sets Quarto/Pandoc and the user
library fallback, cleans stale compiled `src/` artifacts, then runs pkgdown.

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/build-site.R --check  # verify toolchain only
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/build-site.R          # full build into docs/
```

The live site redeploys from the `pkgdown` workflow on push to `main`.

## Ticket Workflow

1. Read the ticket, its dependencies, and the relevant contract section.
2. Add or update tests for the acceptance criteria.
3. Implement the smallest change that satisfies the ticket.
4. Run targeted tests, then full tests/package checks when the change affects
   public API, runner behavior, snapshots, CI, or release gates.
5. Update `tickets.yml`; it is the only ticket authority. Any readable view
   is generated, not edited.
