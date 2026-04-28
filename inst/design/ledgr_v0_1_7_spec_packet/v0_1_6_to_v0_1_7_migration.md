# ledgr v0.1.6 to v0.1.7 Migration Notes

**Status:** Skeleton for LDG-1001. Fill in with executable examples as the
implementation tickets land.

v0.1.7 is an intentional public API reset. The goal is to move normal research
workflows from `db_path`-first calls and direct `ledgr_backtest()` usage to a
snapshot-first, experiment-first model.

## Top-Level Workflow

### v0.1.6 style

```r
bt <- ledgr_backtest(
  snapshot = snapshot,
  strategy = strategy,
  strategy_params = list(qty = 10),
  universe = c("AAA", "BBB"),
  initial_cash = 100000
)
```

### v0.1.7 style

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  universe = c("AAA", "BBB"),
  opening = ledgr_opening(cash = 100000)
)

bt <- exp |> ledgr_run(params = list(qty = 10))
```

## Strategy Signature

### Replace

```r
strategy <- function(ctx) {
  targets <- ctx$targets()
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

## Target Constructors

| v0.1.6 | v0.1.7 |
|---|---|
| `ctx$targets()` | `ctx$flat()` |
| `ctx$current_targets()` | `ctx$hold()` |

`ctx$flat()` means "go flat unless I set a target." `ctx$hold()` means "keep
current holdings unless I override them."

## Store Operations

### Replace

```r
ledgr_run_list(db_path)
ledgr_run_info(db_path, "run_id")
ledgr_compare_runs(db_path)
```

### With

```r
snapshot <- ledgr_snapshot_load(db_path, snapshot_id)

snapshot |> ledgr_run_list()
snapshot |> ledgr_run_info("run_id")
snapshot |> ledgr_compare_runs()
```

`db_path` appears in normal workflows at snapshot creation or snapshot loading.
After that, use the snapshot handle.

## Still To Be Filled In

- Final `ledgr_run()` argument list after LDG-1003.
- Final snapshot-first store signatures after LDG-1005.
- Final close/checkpoint behavior after LDG-1008.
- Updated README and vignette examples after LDG-1010.
