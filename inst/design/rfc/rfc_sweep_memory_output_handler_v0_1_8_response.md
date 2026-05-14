# RFC Response: Sweep Memory Output Handler For v0.1.8

**Status:** Reviewer response.
**Date:** 2026-05-14
**RFC:** `inst/design/rfc/rfc_sweep_memory_output_handler_v0_1_8.md`
**Reviewer:** Codex

---

## Overall Assessment

I agree with the RFC's central correction. The ephemeral DuckDB clone approach
must not close LDG-2108.

The problem is not only performance and not only source-store mutation. A sweep
candidate that writes a complete run into a throwaway DuckDB has already crossed
the wrong boundary. It turns exploratory candidate evaluation into hidden
persistence, then discards the evidence. That violates the v0.1.8 architecture:

```text
ledgr_run()   -> fold core -> persistent DuckDB output handler
ledgr_sweep() -> fold core -> in-memory summary output handler
```

The current LDG-2108 worktree should be treated as an exploratory stub, not as
the implementation to salvage. `ledgr_clone_snapshot_for_sweep()` should be
deleted, and `ledgr_sweep()` should evaluate candidates through the same fold
semantics with an in-memory output path.

There is one important correction to the RFC's feature-wiring finding: the
current worktree now has a `features` field on resolved candidate metadata.
However, sweep execution still should not depend on that field. Candidate
feature resolution is identity and validation metadata. Execution should pass
the source experiment's `exp$features` factory/static list into the fold and let
the normal candidate params materialization path resolve it. That keeps
`ledgr_run()` and `ledgr_sweep()` on the same feature semantics.

---

## Code Review Findings

### Finding 1: `ledgr_run_fold()` Is Still A Persistent Runner

`R/backtest-runner.R` currently names the function `ledgr_run_fold()`, but the
function still performs persistent-run setup before the fold loop starts:

- opens a DuckDB connection from `cfg$db_path`;
- creates and validates schema;
- inserts or resumes a row in `runs`;
- writes strategy provenance;
- prepares snapshot runtime views;
- mutates `runs.snapshot_id`, `runs.data_hash`, `runs.execution_mode`, and
  `runs.schema_version`;
- queries `ledger_events` for the next event sequence;
- writes opening-position `CASHFLOW` events directly through
  `ledgr_write_opening_position_events()`.

Because these happen before the output handler boundary, adding an
`output_handler` argument alone is not sufficient. A memory sweep path would
still open a store and write run artifacts unless persistent setup is separated
from the true fold core.

### Finding 2: Direct DuckDB Calls Remain Inside And After The Loop

LDG-2102 moved several per-pulse writes behind `output_handler`, but the fold is
not yet output-agnostic.

Remaining direct dependencies include:

- `DBI::dbWithTransaction(con, { run_loop(); output_handler$flush_pending() })`
  around the loop;
- direct `DBI::dbGetQuery()` after the loop to read `ledger_events`;
- direct post-loop `DBI::dbWithTransaction()` writes to `features`;
- direct post-loop `DBI::dbWithTransaction()` writes to `equity_curve`;
- persistent status update inside the post-loop transaction.

The memory handler design must move these responsibilities behind handler or
pure helper boundaries. Otherwise sweep still depends on a store-shaped run.

### Finding 3: Opening Positions Are A Required Memory-Handler Event

The RFC asks what events the memory handler must observe. The answer is not only
fills.

Opening positions are currently written as `CASHFLOW` events before the pulse
loop. Those events seed FIFO lot accounting and cost basis during post-run
equity reconstruction. A memory sweep handler must capture them too, or opening
position parity will regress.

The current direct writer should be split into:

```text
ledgr_opening_position_event_rows(...)
  -> rows

persistent handler:
  append rows to ledger_events

memory handler:
  keep rows in memory
```

### Finding 4: The Existing Metrics Helpers Are DB-Bound

`ledgr_compute_metrics()` currently reads from a `ledgr_backtest` object through
DuckDB:

- `ledgr_backtest_equity(con, bt$run_id)`;
- `ledgr_extract_fills_impl(bt, con = con)`;
- `ledgr_estimate_bars_per_year(bt, equity, con = con)`.

Calling these helpers from sweep would force either a persisted run or a fake
in-memory backtest adapter. Neither is the right v0.1.8 cut.

The reusable parts already exist as lower-level pure functions:

- `compute_period_returns()`;
- `compute_annualized_return()`;
- `compute_annualized_volatility()`;
- `compute_sharpe_ratio()`;
- `compute_max_drawdown()`;
- `compute_time_in_market()`;
- `ledgr_lot_apply_event()`.

The implementation should extract DB-free helpers around these rather than make
sweep pretend to be a DuckDB-backed backtest.

### Finding 5: Feature Lookup Is Input-Source Work, Not Output-Handler Work

The memory output handler should not own feature materialization. The output
handler decides what to retain from execution. Feature lookup is fold input.

The current runner builds:

- pulse timestamps;
- `bars_by_id`;
- `bars_mat`;
- feature series;
- feature matrices;
- per-pulse feature tables.

That code currently reads from DuckDB. For sweep, the fold needs a prepared
in-memory input source or payload so the candidate can run without writing run
artifacts. If `precomputed_features` is supplied, its payload should be used for
feature matrices rather than recomputing and then merely validating it.

---

## Q1: Minimal Memory Output Handler Contract

The minimal memory handler should expose the same method names the fold calls
today, plus one or two methods that move transaction/finalization decisions out
of the fold.

Required methods:

```text
record_run_status(status, error_msg = NA_character_)
record_failure(msg)
abort_run(msg, class = "ledgr_run_failed")

write_telemetry(status, strict = TRUE, telemetry = NULL, processed = NA_integer_)
store_session_telemetry(telemetry)

init_buffers(max_events)
buffer_event(write_res)
pending_event_count()
flush_pending()

buffer_strategy_state(ts_utc, state_json)
write_strategy_state(ts_utc, state_json)

write_fill_events(fill, event_seq_start, use_transaction = FALSE)

run_transaction(fn)
finalize_outputs(...)
result()
```

The methods that matter for metrics are:

- `buffer_event(write_res)`: capture every `FILL` / `FILL_PARTIAL` ledger event
  row emitted through `ledgr_fill_event_row()`;
- opening-position event capture: capture every `CASHFLOW` opening-position row;
- `finalize_outputs(...)`: receive or construct the final in-memory equity
  curve, fills/trades, metrics, final positions, final cash, and final equity;
- `result()`: return the summary bundle consumed by `ledgr_sweep()`.

The memory handler can make telemetry and status methods local no-ops or local
state updates. It must not call `ledgr_store_run_telemetry()`, must not mutate
`.ledgr_telemetry_registry`, and must not write to `run_telemetry`.

`write_fill_events()` should not be used in sweep if memory sweep forces the
audit-log execution path. It should still exist and abort with a clear internal
error if called, because a memory sweep entering the db-live write path would be
a bug.

---

## Q2: Metrics Computation Path

Use a third option: Option B-prime.

The memory handler should retain an in-memory ledger event stream, but the
metric path should be pure helper based, not a fake `ledgr_backtest` object.

Recommended path:

```text
fold loop
  -> memory handler captures opening CASHFLOW rows and FILL rows
post-loop
  -> ledgr_equity_from_events(events_df, pulses, close_matrix, initial_cash, universe)
  -> ledgr_fills_from_events(events_df)
  -> ledgr_metrics_from_equity_and_fills(equity_df, fills_df, bars_per_year)
  -> memory handler result bundle
```

This is preferable to Option A because it preserves the existing event-sourced
semantics. Equity and metrics are reconstructed from the same ledger event
meaning used by persistent runs. It is also preferable to full Option B because
it avoids pretending the in-memory result is a DuckDB-backed `ledgr_backtest`.

Implementation consequence:

- extract the existing post-loop equity reconstruction block from
  `R/backtest-runner.R` into a pure helper;
- extract the fill/trade reconstruction logic from `ledgr_extract_fills_impl()`
  into a pure helper that accepts `events_df`;
- extract metric aggregation from `ledgr_compute_metrics_internal()` into a pure
  helper that accepts `equity_df`, `fills_df`, and a bars-per-year value.

The persistent path can keep using the public `ledgr_compute_metrics(bt)` API.
The sweep path should call the private pure helper directly.

The current fold core does not support this cleanly yet. It already has most of
the required logic, but that logic is embedded after direct DB reads and before
direct DB writes. The work is a medium internal refactor, not a wholesale second
engine.

---

## Q3: Preflight And Telemetry Global State

Telemetry should be routed through the output handler and discarded or retained
locally for debugging. Sweep candidates must not populate
`.ledgr_telemetry_registry`.

Preflight should run once per sweep only if the preflight contract remains
strategy-body based and independent of candidate params. Current preflight
already returns package dependency information, so the sweep result can retain
the preflight object or a compact summary as result metadata. If future
preflight starts inspecting candidate-varying feature definitions, that must
become per-candidate preflight.

`.ledgr_preflight_registry` is currently used as a timing side channel:
`ledgr_run()` sets a start timestamp and the runner later consumes it. Sweep
should avoid that registry. The caller should pass preflight timing/result
explicitly into the fold or output handler.

Other global state to account for:

- `.ledgr_feature_cache_registry`: acceptable only as an optimization keyed by
  snapshot hash, feature fingerprint, feature engine version, and range.
  Correctness must not depend on cache warmth. Precomputed sweep payloads should
  bypass or replace this hot path where available.
- `.ledgr_sweep_id_state`: acceptable for non-RNG `sweep_id` generation. It is
  not execution semantics and does not affect candidate results.
- `.ledgr_json_cache`: acceptable canonical JSON memoization, not output state.
- strategy and indicator registries: expected package registries, not per-run
  output state.

---

## Q4: Impact On `ledgr_run_fold()` Signature

The current signature is:

```r
ledgr_run_fold <- function(config, run_id = NULL, control = list())
```

It does not accept an output handler, and simply adding one is not enough
because persistent setup happens before the handler is constructed.

There are two viable implementation shapes.

### Preferred Low-Risk Shape

Keep `ledgr_run_fold()` as the persistent wrapper for now, and extract a deeper
private execution core:

```r
ledgr_run_fold <- function(config, run_id = NULL, control = list()) {
  # persistent setup, run row, snapshot views, persistent handler
  ledgr_execute_fold(execution, output_handler)
}

ledgr_sweep_run_candidate <- function(exp, params, ...) {
  execution <- ledgr_prepare_sweep_execution(exp, params, ...)
  ledgr_execute_fold(execution, ledgr_memory_output_handler(...))
}
```

The shared execution semantics live in `ledgr_execute_fold()`. The public
contract remains true: `ledgr_run()` and `ledgr_sweep()` share the same fold
core. The wrapper name is less important than the boundary being real.

This shape has the lowest risk because it avoids forcing all persistent
registration/resume behavior through a new generic interface in the same ticket.

### Alternative Shape

Refactor `ledgr_run_fold()` itself to accept:

```r
ledgr_run_fold <- function(config,
                           run_id = NULL,
                           control = list(),
                           output_handler = NULL,
                           input_source = NULL)
```

`output_handler = NULL` preserves the current persistent path. A non-null memory
handler plus an in-memory input source skips persistent run registration and
post-loop writes.

This is workable, but easier to get wrong because `ledgr_run_fold()` currently
mixes persistent orchestration and fold execution throughout the function.

---

## Q5: Clone Deletion

`ledgr_clone_snapshot_for_sweep()` has no legitimate future role in v0.1.8
sweep. It should be deleted with the associated `on.exit()` cleanup in
`ledgr_sweep()`.

No other call sites should depend on the clone. The replacement is:

```text
ledgr_sweep()
  -> load or validate source snapshot bars once
  -> prepare candidate execution input
  -> run fold core with memory handler
```

If a helper for reading snapshot bars into an in-memory payload is needed, it
should be named for input preparation, not cloning, and it must not create a
DuckDB file.

---

## Q6: Required Tests

The re-implementation needs tests at two layers.

### LDG-2108 Tests

These should live in `test-sweep.R` and prove the memory path itself:

1. **No DuckDB write artifacts for sweep candidates.**
   Run a sweep and assert the source store's `runs`, `ledger_events`,
   `equity_curve`, `features`, `strategy_state`, and `run_telemetry` row counts
   for candidate labels do not increase.

2. **No tempfile DuckDB clone.**
   Test structurally by asserting `ledgr_clone_snapshot_for_sweep()` no longer
   exists internally. Behaviorally, assert sweep does not create any additional
   run store path.

3. **Feature-consuming strategy succeeds.**
   Use a strategy that calls `ctx$feature("AAA", "return_1")` or
   `ctx$feature("AAA", "sma_2")` and changes targets based on the value.
   Successful rows must be `DONE`, and the candidate feature fingerprints must
   be non-empty.

4. **Feature-factory failure rethrow preserves class.**
   Use `features = function(params) list(ledgr_ind_sma(params$n))` with one
   invalid candidate. With `stop_on_error = FALSE`, record one failed row. With
   `stop_on_error = TRUE`, rethrow `ledgr_invalid_args`.

5. **Memory handler output bundle has required standard metric fields.**
   The result row should contain `total_return`, `annualized_return`,
   `volatility`, `sharpe_ratio`, `max_drawdown`, `n_trades`, `win_rate`,
   `avg_trade`, `time_in_market`, and `final_equity`.

### LDG-2112 Parity Tests

The full semantic parity suite belongs in LDG-2112:

- compare `ledgr_run()` and `ledgr_sweep()` metrics for the same deterministic
  strategy, params, snapshot, and seed;
- include a strategy that consumes features;
- include feature-factory parameter sweeps where changing params changes the
  feature set;
- include opening positions;
- include final-bar no-fill;
- include fees/spread/cash deltas;
- include explicit seeded stochastic strategy parity.

LDG-2108 should not wait for the full parity suite, but it must include enough
tests to prove that the memory handler is actually memory-only and that
feature-consuming strategies work.

---

## Recommended Re-implementation Plan

1. Reopen LDG-2108 and mark the current implementation notes as superseded.

2. Delete the ephemeral clone path:
   `ledgr_clone_snapshot_for_sweep()` and all candidate execution through
   `ledgr_run()` against a temp snapshot.

3. Extract a true private execution core from `ledgr_run_fold()`:
   one function should contain strategy invocation, target validation, reserved
   risk slot, fill timing, cost resolution, state transitions, and event
   emission. It should not register runs or write persistent outputs.

4. Add `ledgr_memory_output_handler()` as a private internal handler.
   It captures opening `CASHFLOW` rows, fill rows, local status, local warnings,
   and summary artifacts. It does not write DuckDB and does not update telemetry
   registries.

5. Route transaction scope through the handler:
   persistent handler wraps the loop and post-run writes in DuckDB transactions;
   memory handler calls the supplied function directly.

6. Route post-loop materialization through private pure helpers:
   reconstruct equity and fills from in-memory events, then compute metrics from
   in-memory equity/fills.

7. Make sweep input source explicit:
   load snapshot bars into an in-memory payload once, or use
   `precomputed_features` when supplied. The output handler must not own feature
   lookup.

8. Preserve all existing public `ledgr_sweep()` behavior already designed:
   row order, failure capture, `stop_on_error`, `sweep_id`, seed derivation,
   result attributes, and precomputed feature validation.

---

## Decision

Accept the RFC. LDG-2108 should be reopened and re-implemented around a true
memory output handler and a true fold input/output boundary.

The current DuckDB clone implementation is not a valid v0.1.8 compromise. It
should not be committed as the sequential sweep implementation, because it
violates the central reason sweep exists: fast exploratory candidate evaluation
without durable run artifacts or hidden throwaway persistence.
