# ledgr Research Workflow -- UX Design Decisions

**Status:** v0.1.7 UX overhaul proposal. Decisions made during v0.1.6 review cycle.
**Scope:** Public API shape, interaction patterns, and object model for the
research workflow. Implementation targeted at v0.1.7 (API overhaul) and
v0.1.8+ (sweep/precompute). v0.1.6 ships the current comparison/recovery/docs
release without API changes.

---

## Guiding Principles

- **Tidyverse adjacent.** The gold standard for usability and composability is
  the tidyverse. Patterns should feel familiar to a tidyverse user without
  requiring tidyverse as a dependency.
- **"Of course it works that way."** The mental model should feel inevitable.
  No surprises, no sharp edges, no invisible consequences.
- **Sensible defaults.** The happy path requires minimal decisions. Full control
  is available but not forced.
- **Low cognitive load.** Users should not need to reason about DuckDB
  connections, file paths, or schema versions during normal research.
- **Informative and opinionated.** Default output surfaces what matters.
  Everything else is accessible on request.
- **Able to dig deeper.** Progressive disclosure: simple surface for the common
  case, full access when needed.

---

## Core Mental Model

Three objects, three roles:

```
snapshot    the anchor      sealed data + store reference, persists across sessions
exp         the spec        strategy + features + opening state, ephemeral R object
runs / bt   the result      run handle(s) for immediate result access
```

`snapshot` is the only object that must be saved across sessions. `exp` is
recreated from code. `bt` and `runs` are handles to artifacts already persisted
in the store.

---

## Interaction Patterns

Research workflow APIs follow one of three patterns.

### Pattern 1 -- Execution (assign the result)

Side-effectful operations that create persisted artifacts. Always assigned.
Never piped directly into a read.

```r
bt   <- exp |> ledgr_run(params = list(...), run_id = "my_run")
runs <- exp |> ledgr_tune(ledgr_param_grid(...))
```

### Pattern 2 -- Mutation (reassign snapshot)

Operations that write mutable metadata to the store. Return `snapshot` so they
are chainable. Always reassigned. Consistent with `df <- df |> mutate(...)`.

```r
snapshot <- snapshot |> ledgr_run_label("my_run", "My label")
snapshot <- snapshot |> ledgr_run_tag("my_run", c("candidate", "v1"))
snapshot <- snapshot |> ledgr_run_archive("other_run", reason = "dominated")
```

Chains are allowed when operating on the same run:

```r
snapshot <- snapshot |>
  ledgr_run_label("my_run", "Winner") |>
  ledgr_run_tag("my_run", c("production", "v1"))
```

### Pattern 3 -- Read (terminal, not reassigned)

Pure reads from run handles or the store. Return tibbles or info objects.
Terminal -- not reassigned to `snapshot` or `exp`.

```r
runs    |> ledgr_compare_runs()
bt      |> ledgr_results(what = "equity")
snapshot |> ledgr_run_list()
snapshot |> ledgr_run_info("my_run")
snapshot |> ledgr_extract_strategy("my_run")
```

Lifecycle operations (`close()`, constructors, snapshot import, schema tools,
plotting) do not follow these patterns and are not research workflow APIs.

---

## Return Value Contract

| Function | Returns | Pattern |
|---|---|---|
| `ledgr_run()` | `ledgr_backtest` handle | Execution |
| `ledgr_tune()` | named `ledgr_run_collection` | Execution |
| `ledgr_run_label()` | `snapshot` | Mutation |
| `ledgr_run_tag()` | `snapshot` | Mutation |
| `ledgr_run_untag()` | `snapshot` | Mutation |
| `ledgr_run_archive()` | `snapshot` | Mutation |
| `ledgr_run_list()` | `ledgr_run_list` tibble | Read |
| `ledgr_compare_runs()` | `ledgr_comparison` tibble | Read |
| `ledgr_run_info()` | `ledgr_run_info` object | Read |
| `ledgr_run_open()` | `ledgr_backtest` handle | Read |
| `ledgr_results()` | tibble | Read |
| `ledgr_extract_strategy()` | `ledgr_extracted_strategy` | Read |

`ledgr_run_list` and `ledgr_comparison` are S3 subclasses of `tbl_df`. They
are fully composable with dplyr. Their `print()` methods show a curated column
subset with formatted numbers and a footer pointing to more.

---

## Print Method Standards

All S3 print methods follow these conventions:

- **Header line** naming the object type and store context.
- **Curated columns** -- at most 7-8. The columns that matter at a glance.
- **Formatted numbers** -- `return`, `drawdown`, `win_rate` shown as percentages
  in print. Stored as ratios in the underlying tibble for dplyr composability.
- **Footer lines** pointing to the next level of detail.
- **No NA noise** -- fields that are NA are omitted from print output, not shown
  as `NA`.

Example `ledgr_run_list` output:

```
# ledgr experiment store -- momentum.duckdb
# 3 active runs, 1 archived

# A tibble: 3 x 7
  run_id         label                        tags            status  final_equity  return  n_trades
  <chr>          <chr>                        <chr>           <chr>         <dbl>  <chr>      <int>
1 momentum_v1    Slow SMA moderate -- winner  production, v1  DONE         112300  +12.3%       201
2 slow_moderate  NA                           candidate, v1   DONE         112300  +12.3%       201
3 conservative   NA                           candidate, v1   DONE         105420   +5.4%       143

# i Provenance detail: ledgr_run_info(snapshot, run_id)
# i 1 archived run: ledgr_run_list(snapshot, include_archived = TRUE)
```

Example `ledgr_comparison` output:

```
# ledgr comparison -- momentum.duckdb
# 4 completed runs

# A tibble: 4 x 7
  run_id            label  final_equity   return  drawdown  n_trades  win_rate
  <chr>             <chr>         <dbl>   <chr>    <chr>       <int>    <chr>
1 slow_moderate     NA           112300  +12.3%   -11.2%        201     54%
2 fast_moderate     NA           108930   +8.9%   -12.4%        287     51%
3 slow_conservative NA           105420   +5.4%    -8.1%        143     54%
4 fast_conservative NA           103200   +3.2%    -9.8%        198     50%

# i Identity hashes: ledgr_compare_runs(snapshot, what = "identity")
# i Telemetry:       ledgr_compare_runs(snapshot, what = "telemetry")
```

---

## New API Surface (v0.1.7)

All items in this section are proposed for v0.1.7. None are currently
implemented. Current APIs (`ledgr_backtest()`, `ledgr_run_label(db_path, ...)`,
etc.) remain the stable lower-level forms and are not deprecated.

### `ledgr_experiment()`

**Design this interface first.** `ledgr_experiment()` sets the shape for
everything else in v0.1.7 and is the foundation sweep mode (v0.1.8) builds
on. The `ledgr_run()`, `ledgr_tune()`, `ledgr_param_grid()`, and
`ledgr_opening()` designs all depend on what `exp` carries. Lock this down
before touching anything else.

Bundles snapshot + strategy + features into a reusable spec. The object that
flows through the research cycle.

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = my_strategy,
  features = list(ledgr_ind_sma(20), ledgr_ind_returns(1)),
  opening  = ledgr_opening(cash = 100000)
)
```

When `features` is a function of `params`, ledgr computes features per
parameter combination. When it is a fixed list, features are precomputed once
and reused across all combinations.

```r
# Fixed features -- precomputed once
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = my_strategy,
  features = list(ledgr_ind_sma(20))
)

# Features as function of params -- computed per combination
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = my_strategy,
  features = function(params) list(ledgr_ind_sma(params$sma_n))
)
```

### `ledgr_run()`

Single run on an experiment. Returns a `ledgr_backtest` handle.

```r
bt <- exp |>
  ledgr_run(
    params = list(threshold = 0.005, qty = 10, sma_n = 20),
    run_id = "momentum_v1"
  )
```

### `ledgr_tune()`

Grid search on an experiment. Each combination becomes a persisted run. Returns
a named `ledgr_run_collection`.

```r
runs <- exp |>
  ledgr_tune(
    ledgr_param_grid(
      slow_moderate = list(threshold = 0.005, qty = 10, sma_n = 20),
      fast_moderate = list(threshold = 0.005, qty = 10, sma_n = 10)
    )
  )
```

**Open question:** `ledgr_tune()` must be reconciled with the v0.1.7 sweep
architecture (`ledgr_sweep()`, `ledgr_precompute_features()`) before tickets are
cut. The user-facing name may be the same, but the internal precompute strategy
differs. Resolve before v0.1.7 spec packet is cut.

### `ledgr_param_grid()`

Typed grid constructor. Disambiguates a parameter grid from a single params
object. Names become `run_id`s.

```r
ledgr_param_grid(
  conservative = list(threshold = 0.010, qty = 10, sma_n = 20),
  moderate     = list(threshold = 0.005, qty = 10, sma_n = 20),
  aggressive   = list(threshold = 0.002, qty = 20, sma_n = 10)
)
```

### `ledgr_opening()`

Typed opening state. Anchors the starting cash, positions, and cost basis to a
specific date. The `date` sets the start of the pulse loop; bars before it are
available for indicator warmup only.

```r
# Cash only -- date defaults to first bar in snapshot
opening <- ledgr_opening(cash = 100000)

# Existing portfolio
opening <- ledgr_opening(
  date       = "2018-01-01",
  cash       = 87500,
  positions  = c(AAA = 100, BBB = 50),
  cost_basis = c(AAA = 105.50, BBB = 98.20)  # optional, defaults to first bar
)
```

Opening events are recorded in the ledger as `OPENING_CASH` and
`OPENING_POSITION` events timestamped at `date`. State is always derivable from
the full event sequence.

**Validation constraint:** `opening$date` must leave enough bars before it in
the snapshot to satisfy the warmup requirement of every indicator in `features`.
Failure is a loud error naming the conflicting indicator and the earliest valid
opening date.

### `ledgr_opening_from_broker()`

Reconciles opening state from a broker adapter. Captures cash, positions, cost
basis, and timestamp from the broker's current account state. Returns a
`ledgr_opening` object identical in structure to the manual constructor.

```r
opening <- ledgr_opening_from_broker(broker_adapter)
```

---

## `ctx` Naming (v0.1.7)

Current names are technically correct but pedagogically wrong:

| Removed | Replacement | Meaning |
|---|---|---|
| `ctx$targets()` | `ctx$flat()` | zero target vector -- go flat unless signal |
| `ctx$current_targets()` | `ctx$hold()` | targets from current positions -- hold unless signal |

`ctx$hold()` reads naturally in strategy code:

```r
strategy <- function(ctx, params) {
  targets <- ctx$hold()           # hold everything unless overridden
  if (signal) targets["AAA"] <- 1
  targets
}
```

`ctx$targets()` and `ctx$current_targets()` are hard-removed in v0.1.7. No
aliases. Calling them after the upgrade is a loud error.

---

## Strategy Signature (v0.1.7)

`function(ctx, params)` is the only supported strategy signature from v0.1.7
onward. `function(ctx)` is hard-removed. Strategies with no tunable parameters
receive an empty list and may ignore the argument:

```r
flat_strategy <- function(ctx, params) ctx$flat()
```

**Why this must happen before sweep mode:** `ledgr_sweep()` (v0.1.7) requires
strategies to be sweep-compatible, which is defined as `function(ctx, params)`
with explicit params and no hidden mutable state. If `function(ctx)` remains a
valid signature, the compatibility check in sweep mode becomes ambiguous --
ledgr cannot tell whether a zero-argument strategy omitted params intentionally
or accidentally. Unifying the signature now eliminates that ambiguity before
the sweep contract is locked in.

Tier classification (for reproducibility) is based on source content and
external references, not on the function signature.

---

## `db_path` Visibility (v0.1.7)

`db_path` appears exactly once -- at snapshot creation. After that it is carried
by `snapshot`, inherited by `exp`, and further inherited by `bt` and `runs`.
Users never pass `db_path` to a run, comparison, or metadata function.

The existing `db_path`-first public APIs (`ledgr_run_label(db_path, ...)`,
`ledgr_run_list(db_path)`, `ledgr_compare_runs(db_path, ...)`, etc.) are
hard-removed in v0.1.7. The snapshot-first signatures replace them entirely.
`db_path` strings remain valid only as an argument to snapshot constructors and
`ledgr_snapshot_load()`.

---

## Full Workflow Reference (v0.1.7 target state)

```r
library(ledgr)

# -- Define -------------------------------------------------------------------

snapshot <- ledgr_demo_bars |>
  ledgr_snapshot_from_df(db_path = "research/momentum.duckdb")

momentum <- function(ctx, params) {
  targets <- ctx$hold()
  for (id in ctx$universe) {
    ret <- ctx$feature(id, paste0("sma_", params$sma_n))
    if (!is.na(ret) && ret >  params$threshold) targets[id] <- params$qty
    if (!is.na(ret) && ret < -params$threshold) targets[id] <- 0
  }
  targets
}

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = momentum,
  features = function(params) list(
    ledgr_ind_sma(params$sma_n),
    ledgr_ind_returns(1)
  ),
  opening  = ledgr_opening(cash = 100000)
)

# -- Verify -------------------------------------------------------------------

exp |>
  ledgr_pulse_snapshot("2018-03-15T00:00:00Z") |>
  momentum(params = list(threshold = 0.010, qty = 10, sma_n = 20))

bt <- exp |>
  ledgr_run(params = list(threshold = 0.010, qty = 10, sma_n = 20))

bt |> ledgr_results(what = "equity")

# -- Search -------------------------------------------------------------------

runs <- exp |>
  ledgr_tune(
    ledgr_param_grid(
      slow_conservative = list(threshold = 0.010, qty = 10, sma_n = 20),
      slow_moderate     = list(threshold = 0.005, qty = 10, sma_n = 20),
      fast_conservative = list(threshold = 0.010, qty = 10, sma_n = 10),
      fast_moderate     = list(threshold = 0.005, qty = 10, sma_n = 10)
    )
  )

runs |> ledgr_compare_runs()

# -- Organise -----------------------------------------------------------------

snapshot <- snapshot |>
  ledgr_run_tag("slow_moderate",     c("candidate", "grid_v1")) |>
  ledgr_run_tag("slow_conservative", c("candidate", "grid_v1"))

snapshot <- snapshot |>
  ledgr_run_archive("fast_moderate",     reason = "dominated by slow_moderate") |>
  ledgr_run_archive("fast_conservative", reason = "dominated by slow_conservative")

snapshot |> ledgr_run_list()

# -- Commit -------------------------------------------------------------------

bt <- exp |>
  ledgr_run(
    params = list(threshold = 0.005, qty = 10, sma_n = 20),
    run_id = "momentum_v1"
  )

snapshot <- snapshot |>
  ledgr_run_label("momentum_v1", "Slow SMA moderate -- grid_v1 winner") |>
  ledgr_run_tag("momentum_v1", c("production", "momentum_v1"))

# -- Inspect ------------------------------------------------------------------

snapshot |> ledgr_run_info("momentum_v1")
snapshot |> ledgr_run_open("momentum_v1") |> ledgr_results(what = "equity")
snapshot |> ledgr_run_open("momentum_v1") |> ledgr_results(what = "trades")
snapshot |> ledgr_extract_strategy("momentum_v1")

# -- Next session -------------------------------------------------------------

snapshot <- ledgr_snapshot_load("research/momentum.duckdb", "demo_2015_2021")

snapshot |> ledgr_run_list()
snapshot |> ledgr_compare_runs()
snapshot |> ledgr_run_open("momentum_v1") |> ledgr_results(what = "equity")
```

---

## `close(bt)` Lifecycle (v0.1.7)

Currently `close(bt)` is required to flush the DuckDB checkpoint before the
connection is released. Forgetting it causes silent data loss on some platforms.
The contract should match how R users actually think about objects.

**Target behaviour:**

- `close(bt)` remains valid and flushes immediately when called.
- If `close()` is never called, the finalizer auto-checkpoints on GC and emits
  a one-time message (`"ledgr: run '<id>' checkpointed on garbage collection"`)
  so users can learn the pattern without losing data.
- In-memory runs (no `db_path` provided) never require `close()` -- there is
  nothing to flush.

The GC path is a safety net, not the intended workflow. Documentation continues
to show explicit `close(bt)`.

---

## Version Assignment

### v0.1.6 (current -- no API changes)

v0.1.6 is the comparison/recovery/docs release. API shapes are frozen. No
return-type changes, no signature changes. Items originally scoped here
(curated print methods, snapshot return from mutations) are moved to v0.1.7.

### v0.1.7 (UX reshape -- hard breaking)

No backward compatibility. The package has no known users. Full design
discussion to follow once v0.1.6 is shipped. Confirmed scope:

**New surface:**
- `ledgr_experiment()` -- central spec object; design this first
- `ledgr_run()` -- single run on an experiment
- `ledgr_tune()` -- grid search (pending reconciliation with v0.1.8 sweep architecture)
- `ledgr_param_grid()` -- typed grid constructor
- `ledgr_opening()` and `ledgr_opening_from_broker()` -- opening state
- `ledgr_run_list` and `ledgr_comparison` S3 print methods with curated columns and footers

**Hard removals:**
- `ctx$targets()` and `ctx$current_targets()` removed; replaced by `ctx$flat()` and `ctx$hold()`
- `function(ctx)` strategy signature removed; `function(ctx, params)` is the only valid form
- All `db_path`-first public APIs removed; snapshot-first signatures replace them
- `ledgr_backtest()` demoted to internal/low-level; `ledgr_run()` is the public API

**Lifecycle:**
- `close(bt)` made optional; auto-checkpoint on GC with informational message
- In-memory runs require no `close()` at all

### v0.1.8 and beyond

Sweep mode (`ledgr_sweep()`, `ledgr_precompute_features()`) builds on the
`ledgr_experiment()` foundation established in v0.1.7. Full spec in
`inst/design/ledgr_sweep_mode_ux.md`. Reconcile `ledgr_tune()` naming with
v0.1.8 sweep architecture before cutting v0.1.7 tickets.
