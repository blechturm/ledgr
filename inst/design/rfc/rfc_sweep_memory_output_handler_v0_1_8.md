# RFC: Sweep Memory Output Handler — LDG-2108 Re-implementation

**Status:** Draft RFC; maintainer decision pending Codex response.
**Date:** 2026-05-14
**Author:** Codex (on behalf of maintainer)
**Related documents:**

- `inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md`
- `inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_tickets.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`
- `inst/design/contracts.md`
- `R/sweep.R`
- `R/backtest-runner.R`

---

## Problem Statement

LDG-2108 is marked Done and ships `ledgr_sweep()`. The implementation evaluates
candidates by cloning the source snapshot's DuckDB into a tempfile, running each
candidate through `ledgr_run()` against the clone, and deleting the tempfile on
exit.

**The maintainer has rejected this approach unconditionally:**

> "Sweep mode must be without DuckDB writes — period."

This is not a performance concern. It is an architectural correctness requirement.
Sweep mode is exploratory evaluation. It is not a lighter version of persistence.
A sweep candidate that writes to a throwaway DuckDB and then discards it is
doing the wrong work for the wrong reason. The ephemeral clone achieves "no
source mutation" by redirection rather than by elimination.

The architecture note (`ledgr_v0_1_8_sweep_architecture.md`) stated this
explicitly before LDG-2108 was written:

> "In-memory summary rows for sweep... Sweep may use a cheaper output handler,
> but it must not change strategy semantics, feature values, pulse order, fill
> timing, state transitions, final-bar behavior, random draws, or event-stream
> meaning."

The LDG-2108 implementation tasks 4–6 also required this:

> "4. Add fold-core output-handler injection: `NULL` keeps the current persistent
>    `ledgr_run()` handler; a supplied handler is used for sweep candidates."
> "5. Move the loop transaction boundary behind the output handler... so
>    sweep candidates do not require a store connection."
> "6. Route post-loop output materialization through the handler boundary:
>    sweep candidates retain only the summary data needed for result rows."

The ephemeral clone approach was an expedient workaround for the absence of
output-handler injection. It does not satisfy tasks 4–6 and it violates the
maintainer's design intent.

LDG-2108 must be reopened and re-implemented.

---

## Additional Finding: Feature Wiring Bug

A code review discovered a second correctness defect in the current
implementation. In `ledgr_sweep_run_candidate()`:

```r
candidate_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = exp$strategy,
  features = candidate_features$features,   # NULL — field does not exist
  ...
)
```

`candidate_features` is the return value of `ledgr_resolve_candidate_features()`,
which carries fields `label`, `params`, `feature_defs`, `feature_ids`,
`fingerprints`, and `feature_set_hash`. There is no `$features` field.
`candidate_features$features` evaluates to `NULL`. The experiment is built with
`features = NULL`.

All current tests pass because no test strategy calls `ctx$feature()`. Any
strategy that reads a feature value during evaluation would silently receive
wrong results. This bug is also resolved by the re-implementation described below.

---

## Required Re-implementation

The correct execution path for a sweep candidate is:

```text
ledgr_sweep_run_candidate()
  -> ledgr_run_fold(exp, params, output_handler = ledgr_memory_output_handler())
  -> memory handler accumulates: metrics, final equity
  -> returns collected summary without touching DuckDB
```

`ledgr_clone_snapshot_for_sweep()` and its `on.exit` cleanup are deleted
entirely. No tempfile is created. No DuckDB connection is opened for sweep
candidates.

---

## Questions For Codex

This RFC asks Codex to specify the memory output handler contract and the
re-implementation plan before work begins.

### Q1: Memory output handler contract

What is the minimal interface a memory output handler must expose so that:

- `ledgr_run_fold()` can call it identically to the persistent handler;
- it accumulates enough information to populate a `ledgr_sweep_results` row
  (final equity, standard metric columns, execution seed, feature fingerprints);
- it does not open any DuckDB connection;
- it does not write to any persistent store;
- it does not mutate package-global state (`.ledgr_telemetry_registry`,
  `.ledgr_preflight_registry`)?

Specifically: what events does `ledgr_run_fold()` currently emit to the output
handler, and which of those events does the memory handler need to observe in
order to compute the standard metrics without re-running the fold?

### Q2: Metrics computation path

The standard metrics (`total_return`, `annualized_return`, `volatility`,
`sharpe_ratio`, `max_drawdown`, `n_trades`, `win_rate`, `avg_trade`,
`time_in_market`, `final_equity`) are currently computed by
`ledgr_compute_metrics(bt)` and `ledgr_compute_equity_curve(bt)` after
`ledgr_run()` returns a full backtest object.

For the memory handler, there are two possible approaches:

**Option A — Retain equity curve in memory during fold:**
The memory handler accumulates bar-level equity or cash/position state during
fold execution, then computes metrics from that in-memory series after the fold
completes. No DuckDB is required, but the handler must buffer O(bars) state.

**Option B — Reuse existing metric helpers post-fold via in-memory ledger:**
The fold core writes events into an in-memory ledger (e.g., a list or data
frame) rather than DuckDB. After the fold, `ledgr_compute_metrics()` runs
against this in-memory ledger using the same logic path as `ledgr_run()`.
This is closer to a full in-memory backtest object and maximises parity
assurance, but requires the metric helpers to accept non-DuckDB inputs.

Which option is preferable for v0.1.8, and does the current fold core support
either cleanly without a large internal refactor?

### Q3: Preflight and telemetry global state

The architecture note identified two package-global side-channels that currently
couple the fold core to persistence:

- `.ledgr_telemetry_registry` — populated during fold, read by
  `write_persistent_telemetry()` for DuckDB write
- `.ledgr_preflight_registry` — preflight timing metadata

For a memory-only sweep candidate:

- Should telemetry be routed through the output handler and discarded (not
  accumulated into the global registry)?
- Should preflight run once per sweep (since the strategy function is fixed
  across candidates) and its result be attached to the sweep result object?
- Are there other global side-channel writes that the memory handler must
  suppress or redirect?

### Q4: Impact on `ledgr_run_fold()` signature

LDG-2102 extracted `ledgr_run_fold()` as the private shared fold core. Does
the current `ledgr_run_fold()` signature already accept an `output_handler`
argument, or does it need to be added as part of this re-implementation?

If the argument does not exist yet, what is the minimal signature change that
allows handler injection without breaking the current persistent `ledgr_run()`
path? The default should preserve current `ledgr_run()` behavior exactly.

### Q5: Clone deletion

`ledgr_clone_snapshot_for_sweep()` and the associated `on.exit` cleanup in
`ledgr_sweep()` are deleted. Confirm there are no other call sites that depend
on the clone or that need corresponding cleanup changes.

### Q6: Test coverage required

The current `test-sweep.R` does not include a strategy that calls
`ctx$feature()`. After re-implementation, what test or tests would definitively
prove that:

- feature values are correctly materialized and passed through to candidate
  evaluation (no `features = NULL` regression);
- the memory handler produces the same metric values as `ledgr_run()` for the
  same strategy, params, and snapshot (LDG-2112 parity)?

Should those tests live in `test-sweep.R` or be reserved for the dedicated
LDG-2112 parity suite?

---

## Constraints

The re-implementation must:

- call the same `ledgr_run_fold()` fold core as `ledgr_run()`;
- not open any DuckDB connection for sweep candidates;
- not write to any tempfile;
- not mutate the source experiment store;
- produce metrics semantically equivalent to `ledgr_run()` on the same inputs;
- pass `exp$features` (the factory or static list) through to candidate
  execution so per-candidate feature materialization works correctly;
- preserve all current `ledgr_sweep()` public behavior (failure capture,
  `stop_on_error`, `precomputed_features` validation, sweep_id, seed derivation,
  result attributes).

The re-implementation must not:

- add a public `ledgr_run_fold()` export;
- add a public memory-handler API;
- change `ledgr_run()` public behavior or result shape;
- change `config_hash` for unchanged execution configuration;
- require any change to `ledgr_param_grid`, `ledgr_precompute_features`, or
  the candidate feature resolution helpers.

---

## Scope Note

This RFC is scoped to LDG-2108 only. It does not ask for parallel sweep,
walk-forward, PBO/CSCV, or any other v0.1.8 non-goal. The memory handler is
a private internal primitive. It is not a public API.
