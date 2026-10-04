# Sharadar Long-Window Usability Evidence

Date: 2026-10-02.
Status: empirical input to v0.2.2 planning.
Authority: evidence and proposed outcomes. The roadmap owns scheduling, and
`tickets.yml` owns any fix. This note selects no API signature.

## Evidence boundary

**Source.** The private ledgr-research repository at
`369c1d490c6bf20c9652c025622eb3cbdde3bce7`, chiefly the
[EXP-0003 result](https://github.com/blechturm/ledgr-research/blob/369c1d490c6bf20c9652c025622eb3cbdde3bce7/experiments/EXP-0003-sharadar-ledgr-usability/result.md)
and the
[feedback register](https://github.com/blechturm/ledgr-research/blob/369c1d490c6bf20c9652c025622eb3cbdde3bce7/docs/governance/ledgr-feedback.md)
entries LFB-017 to LFB-026.

**What was measured.** Executions against ledgr 0.2.1.0 (`5f19dbc`) on a sealed
point-in-time S&P 500 snapshot built from a Sharadar canonical build.

| Property | Value |
| --- | --- |
| Window | 1997-12-31 to 2026-09-04 (7,214 open sessions) |
| Instruments | 1,168 |
| Bars | 5.49 M |
| Membership | About 600 complete sets, about 500 members each |
| Lifetime | 528 in-window terminal facts |
| Sessions | qlcal NYSE, `assume_effective` |
| Corporate actions | None supplied |

**What this note contains.** Aggregates only. No licensed rows or private
identifiers appear here.

**Reproducers.**

- The behavioural findings reproduce with synthetic data through the public
  API:
  [`scripts/sharadar/reproduce_exp0003_ledgr_findings.R`](https://github.com/blechturm/ledgr-research/blob/369c1d490c6bf20c9652c025622eb3cbdde3bce7/scripts/sharadar/reproduce_exp0003_ledgr_findings.R).
- The performance causes come from this repository's
  `dev/bench/notes/long_window_scaling_findings.md`, with its reproducer in
  `dev/bench/long_window/`.

[ledgr-research-findings-index.md](ledgr-research-findings-index.md) maps
every finding to its ledgr home.

## What works

The public surface works mechanically on 30 years of real point-in-time data:

- snapshot construction, sealing and re-verification;
- `ledgr_experiment_plan()`;
- strategy preflight;
- risk and cost chains;
- runs, completion evidence and every `ledgr_results()` table;
- metrics with a metric context;
- labels, tags and archive;
- reopening a run in a fresh process;
- sweep save and open;
- walk-forward train, select and test on the folds it reaches.

Three refusals behave as documented:

- compiled spot-FIFO for availability-aware runs and sweeps;
- precomputed features for availability-aware sweeps;
- strict corporate-action policy without an action family, which runs and
  reports `not_supplied`.

## B0: terminal stops make long windows unusable (LFB-011)

Every started run stopped `INCOMPLETE / terminal_settlement_unsupported` at
the first held delisting.

| Basket | Sessions reached | Share of 7,214 |
| --- | ---: | ---: |
| Top-10 monthly | 448 | 6.2% |
| Top-50, or weekly rebalancing | 171 | 2.4% |
| Equal-weight membership, 2019-2021 | 28 | 3.7% of 757 |

The selection layer then has nothing to work with:

- **Sweep.** A 3 x 3 sweep produced nine `INCOMPLETE` candidates. Review,
  filter, return matrix, candidate selection, promotion, PBO, DSR, effective
  trials and minimum track record all refuse with "no completed candidates".
- **Walk-forward.** It completed folds 1-4 in both rolling and anchored
  schemes, while the number of completed train candidates fell 4 -> 2 -> 1 ->
  1. At fold 5 none was left, and `ledgr_walk_forward_no_selection` aborted
  the session (LFB-023).

This extends the 2026-09-29 horizon entry "Untradable holdings end the run
instead of booking the loss":

- the measured prefix lengths show the scale;
- the whole selection surface fails, not only the disclosure defects named
  there.

**Outcome sought:** the terminal-outcome direction already parked there,
coordinated with LFB-011, LFB-013 and LFB-014.

## Gap robustness

### LFB-017: the canonical rebalance pipeline

`ledgr_selection()` selects eligible members, and eligibility does not
require a current close. `ledgr_target_rebalance()` then raises
`ledgr_target_sizing_unavailable`, which is documented as fail-closed. The
error aborts the whole run.

- **Real data.** On a real first decision, 498 of 499 members had a bar.
- **Synthetic.** A two-member case with one gap reproduces it.
- **Workaround.** `ledgr_selection(where = is.finite(ctx$vec$close) &
  ctx$vec$close > 0)` completes `DONE`.

**Outcome sought:** the default helper pipeline handles an ordinary gap
without aborting the run. One way is to exclude unsizable members with a
diagnostic. Another is to give `ledgr_target_rebalance()` an explicit policy.
At minimum, the survivorship and strategy-helper articles should show the
filter. This belongs with the v0.2.2 untradable holdings and selection
session.

### LFB-019, LFB-022: other gap failures

- **LFB-019.** `ledgr_state_reconstruct()` fails with `ledgr_missing_bars` on
  a completed run whose snapshot has one missing observation.
- **LFB-022.** `ledgr_pulse_snapshot()` refuses a membership universe in
  which one member has no bar on the requested date.

**Outcome sought:** both follow the run's availability semantics, or refuse
with a reason that names the dense-only assumption.

## Smaller workflow findings

- **LFB-018.** A run interrupted before its pulse loop, during feature
  computation, stays in status `CREATED`. Interrupts inside the strategy
  callback correctly give `FAILED`.
- **LFB-020.** Folds starting before the snapshot's first bar are refused
  correctly, but the message reads "hydration start must be before or equal
  to execution start" and does not name the cause.
- **LFB-021.** `ledgr_facts_history()` and `ledgr_facts_resolve()` do not
  accept the lifetime family, so the terminal schedule that stops runs cannot
  be read publicly.

## Performance (LFB-024 to LFB-026, LFB-016)

The 30-year runs measured:

- **Cold first run:** about 25 minutes. Another run timed out at 30 minutes.
- **Later runs in the same R process:** 81-89 s each, whatever their length.
- **A 9-candidate sweep:** 49 minutes.
- **Walk-forward:** about 3.5 minutes per fold.
- **Peak memory:** 7.0 GB.

`dev/bench/notes/long_window_scaling_findings.md` attributes the time, ranked:

1. **Strict-window features (LFB-024).** 88-91% of a cold run. A
   vectorised, masked series gives identical values 393-543 times faster.
2. **Full snapshot re-hash per run and per fact-reader call (LFB-025).** This
   is the roughly 80 s of fixed per-run cost.
3. **Write-only feature persistence.** Every run writes all feature values,
   and nothing reads them.
4. **No feature reuse (LFB-026).**

The pulse loop runs at about 8.5-9.7 ms per pulse and is not a cause.

**Outcome sought:** the v0.2.2 indicator warmup session, the snapshot
verification session and the long-window performance workstream, which
already route these causes. Single long runs, sweeps and walk-forward should
then cost minutes instead of hours.

These measurements are also the availability-aware, long-history data point
that the 2026-10-01 horizon entry "A suite of peer workloads, not one" lacks.
