# A0 brief: freeze current native outputs before WS1

**Brief drafted by Claude, 2026-10-28; the maintainer authorized running it
the same day.** Measurement step A0 of the accepted
[v0.2.3 macro plan](macro_plan.md), under `inst/design/spike_protocol.md`.

## 1. Why

WS1 replaces the persistent and memory output handlers with one handler
behind a sink interface and removes the parity tests that hold the two equal
to each other. Before any handler code changes, today's native outputs must be
recorded so the new handler is checked against what the current tree
produces, not only against itself (macro plan rule 4, edge A0 -> WS1).

## 2. Question

Which workloads and outputs does today's tree produce through both output
handlers, recorded deterministically enough that WS1 can prove byte-identical
results, and what do the two handlers cost today?

## 3. Where to work

- Worktree `C:/Users/maxth/ledgr-wt/a0-output-freeze`, branch
  `claude/a0-output-freeze` (from `release/v0.2.3` at `20034e00`).
- Deliverables under `dev/bench/v0_2_3_output_freeze/`.
- **No product change:** do not edit `R/`, `src/`, `tests/`, `man/`,
  `vignettes/`, `DESCRIPTION` or `NAMESPACE`. Ignore line-ending churn in
  `R/cpp11.R` and `src/cpp11.cpp` if it appears; never commit it.
- Synthetic data only. The private Sharadar v0.2.2 reference already exists
  outside the repository and is out of scope.

## 4. Inputs

- Handlers: `ledgr_persistent_output_handler` (`R/backtest-runner.R:252`) and
  `ledgr_memory_output_handler` (`R/sweep.R:1982`), both injected into
  `ledgr_execute_fold(execution, output_handler)` (`R/fold-engine.R:1573`).
- Current handler-parity tests (read them first; they show what is held
  equal today): `tests/testthat/test-sweep-parity.R`,
  `test-sweep-persistence-parity.R`, `test-workstream8-exact-parity.R`,
  `test-availability-parity.R`, plus any other test or `dev/bench` runner that
  calls either handler (search for both names and for `ledgr_sweep`).
- Inventory rows C6, H6 and R3 in
  `inst/design/ledgr_v0_2_3_spec_packet/inventory_reconciliation.md`; the
  roadmap bullet "One output handler".

## 5. What to build

1. **Inventory (`inventory.md`).** Every test and bench that runs either
   handler, what it compares, and which fixture it uses. From that, choose a
   workload set that covers, at minimum: committed run (`ledgr_run`) and
   sweep (`ledgr_sweep`) on the same workload; dense and availability mode;
   a cost model; a risk chain; corporate actions and a terminal outcome;
   resume of an interrupted run; walk-forward; one and two workers. Reuse
   existing fixtures and public APIs; state why each workload is in the set.
2. **Canonical records (`record.R`, `records/`).** For each workload and
   each handler path, write the native outputs (ledger and fill events,
   equity, diagnostics, metrics, and any other table the handler writes) in
   a canonical form: a declared sort key per table; numbers serialized
   losslessly; fields that legitimately vary between runs (run IDs, wall
   clock, telemetry) excluded with the reason recorded per field. Add a
   `manifest.csv` with one SHA-256 per record file. Keep the records small;
   if they exceed 10 MB in total, stop and report.
3. **Checker (`check.R`).** Re-runs every workload on the current tree and
   compares with `records/` byte for byte, exiting non-zero on any
   difference and naming the workload, table and first differing row. It
   also records today's agreement between the two handlers on shared
   workloads, naming any known difference rather than hiding it.
4. **Determinism.** Two consecutive `record.R` runs on the same tree produce
   identical manifests. If anything is non-deterministic, find and document
   the field, do not paper over it.
5. **Gut demonstration (`gut.R`).** Each corruption must make `check.R`
   fail: change one fill quantity, change one equity value in the last
   significant digit, drop one diagnostic row, swap the order of two
   ledger events.
6. **Baseline timing (`timing.R`, `timing.csv`).** Wall time per workload
   for the committed-run path and the sweep path, three alternating
   repetitions each, medians reported, plus the committed-run versus sweep
   gap (inventory H6). Record host conditions (power plan, other heavy
   processes, R and package versions). Descriptive only, not a gate.
7. **Closeout (`closeout.md`, one page).** Answer, workload table, record
   sizes, determinism result, gut results, timings, excluded fields with
   reasons, open points for the WS1 cut.

## 6. Budgets and stop conditions

Stop and report if: the harness passes 1,500 R lines; records exceed 10 MB;
a workload cannot run without changing product code; or output is
non-deterministic for a reason you cannot isolate.

## 7. Rules

- Commit only your own paths on `claude/a0-output-freeze` with
  `git -C C:/Users/maxth/ledgr-wt/a0-output-freeze commit --only <paths>`.
  Do not merge, do not push.
- Shell: one simple command per call, absolute paths, `git -C` instead of
  `cd`, plain `Rscript` (R 4.6.1 is on PATH), script files for probes, no
  `rm -rf`, no sleep or polling loops.
- UTF-8 or ASCII only.
- Report: commit SHA, workload table, record size, determinism result, gut
  results, timing table, excluded fields, and open points.
