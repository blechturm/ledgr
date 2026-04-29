# ledgr v0.1.6 to v0.1.7 Migration Guide

v0.1.7 is an intentional public API reset. The normal research workflow moves
from direct `ledgr_backtest()` calls to an experiment-first model:

```text
snapshot -> ledgr_experiment() -> ledgr_run() -> run store APIs
```

The old engine path still exists internally and as a compatibility wrapper, but
new user-facing documentation should teach the experiment workflow.

## 1. Create Or Load A Snapshot First

### v0.1.6 style

```r
bt <- ledgr_backtest(
  data = bars,
  strategy = strategy,
  initial_cash = 100000,
  run_id = "candidate"
)
```

### v0.1.7 style

```r
snapshot <- ledgr_snapshot_from_df(bars, db_path = "research.duckdb")

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  opening = ledgr_opening(cash = 100000)
)

bt <- exp |>
  ledgr_run(params = list(), run_id = "candidate")
```

In a new session, reopen the snapshot handle:

```r
snapshot <- ledgr_snapshot_load("research.duckdb", "snapshot_id")
```

## 2. Use `function(ctx, params)`

### Replace

```r
strategy <- function(ctx) {
  targets <- ctx$flat()
  targets
}
```

### With

```r
strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets
}
```

Strategies without tunable parameters still accept `params`; they can ignore it.
Do not use `ctx$params`. Parameters arrive as the second argument.

## 3. Rename Target Helpers

| v0.1.6 | v0.1.7 |
|---|---|
| `ctx$targets()` | `ctx$flat()` |
| `ctx$current_targets()` | `ctx$hold()` |

`ctx$flat()` starts from a flat/default target vector. `ctx$hold()` starts from
current positions.

## 4. Move Starting State Into `ledgr_opening()`

### v0.1.6 style

```r
ledgr_backtest(
  snapshot = snapshot,
  strategy = strategy,
  initial_cash = 100000
)
```

### v0.1.7 style

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  opening = ledgr_opening(cash = 100000)
)
```

Opening positions are explicit:

```r
opening <- ledgr_opening(
  cash = 50000,
  positions = c(DEMO_01 = 10),
  cost_basis = c(DEMO_01 = 52.30)
)
```

Negative opening positions and negative strategy targets remain outside the
supported v0.1.7 public workflow.

## 5. Pass Run-Time Parameters To `ledgr_run()`

### v0.1.6 style

```r
ledgr_backtest(
  snapshot = snapshot,
  strategy = strategy,
  strategy_params = list(window = 20, qty = 10)
)
```

### v0.1.7 style

```r
exp <- ledgr_experiment(snapshot, strategy, features = list(ledgr_ind_sma(20)))

bt <- exp |>
  ledgr_run(params = list(window = 20, qty = 10), run_id = "sma_20_qty_10")
```

`params` must be a JSON-safe list. `params = list()` is valid.

## 6. Use Snapshot-First Store APIs

### Replace

```r
ledgr_run_list(db_path)
ledgr_run_info(db_path, "run_id")
ledgr_compare_runs(db_path)
ledgr_run_open(db_path, "run_id")
```

### With

```r
snapshot <- ledgr_snapshot_load(db_path, snapshot_id)

ledgr_run_list(snapshot)
ledgr_run_info(snapshot, "run_id")
ledgr_compare_runs(snapshot)
ledgr_run_open(snapshot, "run_id")
```

Mutation helpers also take the snapshot handle:

```r
snapshot <- snapshot |>
  ledgr_run_label("run_id", "approved baseline") |>
  ledgr_run_tag("run_id", c("baseline", "reviewed")) |>
  ledgr_run_archive("old_run", reason = "superseded")
```

## 7. Ask ledgr For Feature IDs

Feature IDs are exact strings. Do not guess them.

```r
features <- list(
  ledgr_ind_sma(20),
  ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
)

ledgr_feature_id(features)
```

Use those strings in `ctx$feature()`.

## 8. Parameter Grids Are Typed Objects Only

v0.1.7 introduces `ledgr_param_grid()` as a typed parameter-grid object for
future sweep/tune workflows. It does not execute runs.

```r
grid <- ledgr_param_grid(
  fast = list(window = 10, qty = 5),
  slow = list(window = 20, qty = 5)
)
```

There is no `ledgr_sweep()`, `ledgr_precompute_features()`, or `ledgr_tune()`
execution API in v0.1.7.

## 9. Close Durable Handles

`close(bt)` remains the deterministic cleanup path for backtest handles.
v0.1.7 adds a finalizer safety net for forgotten close calls, but scripts should
still close run and snapshot handles explicitly:

```r
close(bt)
ledgr_snapshot_close(snapshot)
```

## 10. Use The Demo Dataset For Examples

`ledgr_demo_bars` is the canonical offline demo dataset for documentation,
examples, and quick local experiments.

```r
bars <- subset(ledgr_demo_bars, instrument_id %in% c("DEMO_01", "DEMO_02"))
```

It replaces ad-hoc inline bar construction in user-facing examples.
