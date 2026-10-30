# WS4a typed-carrier probe: brief

**Mode:** probe under `inst/design/spike_protocol.md`. It is the "bounded
allocation/profile probe" that the v0.2.3 macro plan, WS4a, puts before the
focused Type 2 typed-fold-carrier RFC. It binds nothing, changes no product
code, and feeds that RFC.
**Executor:** named by the maintainer. **Branch:** a new branch from
`release/v0.2.3`, worktree under `C:/Users/maxth/ledgr-wt/`.
**Written:** 2026-10-30, by Claude, for the maintainer's approval.

## Question

On the wide all-fill shape, how much per-fill cost disappears when one pulse's
fills are planned and applied as vectors through a typed batch? Lots stay the
position authority, and the ledger must stay byte-identical.

Today, on the peer suite's 500 x 1260 SMA 5/10 transition workload (67,725
fills), ledgr pays about 155 us per fill in a canonical-R sweep. That figure is
measured above the no-fill floor of 1.84 s; PMwR pays under 9 us. Both stage
loops run in R once per fill (`R/fold-engine.R:143`, `:1342`). Evidence:
`dev/spikes/pmwr-performance/probe_findings.md`.

**Prerequisite question, answered first:** which producer runs this
workload, dense or availability? Can the same economics run on the
availability producer, the one WS4b keeps, by declaring facts that cover every
instrument and session? If not, stop and report. That answer is itself RFC
input.

## Kill condition

- **GREEN:** the fork's per-fill marginal cost on the wide shape is at most
  40 us, and every identity check below is byte-identical.
- **RED:** identity needs a change to event order, economics or lot results;
  or the marginal cost stays above 80 us.
- **Inconclusive:** anything between. Report attribution by component.

The bounds are the maintainer's to change before work starts.

## Steps

1. **Census on the current tree** (macro plan: no-fill, sparse-rebalance and
   wide all-fill shapes), for each producer that can run the shape:
   - wall time, as alternating fresh processes, at least 5 pairs, median;
   - per-fill marginal cost against the no-fill floor;
   - bytes allocated per pulse and per fill (`Rprofmem`, `bench::bench_memory`
     or `gc()` deltas; state which);
   - the per-fill call chain, with one row per function that runs once per fill.
   Sparse-rebalance: pick a workload from A0 or write a monthly top-N rebalance
   on the same bars. Use the vector-state strategy from the PMwR probe, so the
   strategy's named-list state cost is not counted against the carrier.
2. **Smallest runnable fork, one seam.** Write the fork in
   `dev/spikes/ws4a-carrier-probe/` and install it in the probe process only
   (namespace override, as `dev/bench/v0_2_3_ws2_reverts/runner.R` does).
   - It replaces the plan stage and the apply stage for one pulse.
   - **Plan:** the actionable indices go to vectors of next-open price,
     quantity, side, fee and cash delta, read by matrix index. The cost model
     is resolved once per pulse. There are no proposal objects, and no
     per-fill timestamp validation: the pulse axis is already validated.
   - **Apply:** the lot kernel runs once per pulse over the batch. Fills in
     one pulse touch distinct instruments. Positions are recomputed once per
     pulse, from lots.
   - Events go to the existing typed column buffer as one block.
   - Keep `meta_json` byte-identical. Removing it is WS8's job, and the typed
     accounting synthesis owns that change.
   - Report the three components separately (plan, lot kernel, event batch),
     so the RFC sees which one needs native code.
3. **Identity:** base and fork must produce the same ordered `ledger_events`
   rows on every column, including `event_id` and `meta_json`; the same
   equity facts; the same strategy state; and the same final cash, positions
   and realized P&L. Check this on the 500 x 1260 workload and on every A0
   workload the fork's producer runs (`dev/bench/v0_2_3_output_freeze/`).
4. **Timing of the fork:** the same protocol as step 1. This is a probe, not
   a gate; the shared harness `dev/bench/timing/` stays for gates.

## Deliverables (spike protocol, section 6)

- `probe.R`: the runner. It writes evidence CSVs.
- A checker. It reruns into a scratch directory, diffs against the recorded
  CSVs, and guards package scope (`R`, `src`, `tests`, `NAMESPACE`,
  `DESCRIPTION`, `man`, `inst/design`).
- A gut: one fork variant that reorders two fills in a pulse, and one that
  drops a fee. Each must fail the identity check.
- `probe_findings.md`: one page. It covers what ran, the per-fill marginal
  costs and allocations by component and producer, the verdict with its kill
  clause, and what the RFC may consume. Include the per-pulse floor broken
  down (context refresh, validation, decide) if it surfaces.

## Read first

- `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`, WS4a and WS4b.
- `inst/design/rfc/rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md`,
  Sections 3.2 and 7. Lots are the only position authority, and
  `position_delta` was rejected as an authority. The fork must not use
  `positions + delta`.
- `inst/design/manual/optimization_coding_style.qmd`, the seven shapes.
- `dev/spikes/pmwr-performance/`: the probe, timings and profiles.
- `dev/spikes/pulse-first-batch/REPORT.md` (RED): loop order is not the
  lever; per-candidate context and transitions are.
- `dev/spikes/compiler-native-functions/REPORT.md`: native options, if the
  lot kernel needs one.
- The redundant-accounting spike, on branch `codex/accounting-spike-v0.2.3` at
  `35adbc2a`. Read it with `git show`. Per-fill payload: 5.94 s for 68,688
  fills.

## Out of scope

- Any change under `R/`, `src/`, `tests/` or `inst/design/` (except
  committing this folder).
- Removing `meta_json`, readers or replay (WS7/WS8).
- The compiled spot-FIFO envelope; the public `ctx` or strategy API (WS5);
  removing the dense path (WS4b).
- Writing the RFC.

Budgets (spike protocol, section 4) are stop signals: harness at most 1,500
lines of R, findings one page, at most ten identity cases.

## Shell

- One simple command per call, with absolute paths. Use `git -C`; never
  `cd X && ...`.
- Use plain `Rscript` (R 4.6.1). Install arms from `git archive` into a
  scratch library, as `dev/spikes/pmwr-performance/` did.
- Keep large outputs outside the repository.
- Do not run timing while other heavy R work runs on the host. Record what
  else was running.
