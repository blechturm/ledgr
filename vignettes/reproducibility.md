# On Reproducibility: Provenance and Strategy Tiers


ledgr treats a backtest result as an experiment artifact. The question
is not only “what was the return?” The question is:

``` text
which sealed data, which strategy, which parameters, which features,
which opening state, and which execution assumptions produced this run?
```

By the end of this article you can tell which of your runs ledgr can
replay exactly, which depend on code outside the run, and how to move a
strategy into the self-contained tier. It is about provenance and replay
boundaries, not whether a strategy has predictive edge.

> [!WARNING]
>
> ### Evidence is not validation
>
> Provenance records what ran. It does not prove that a selected strategy
> will generalize. A promoted candidate, a verified strategy hash, and a
> sealed snapshot are evidence-capture tools, not statistical validation
> of the selection rule.


## Setup

``` r
library(ledgr)
library(dplyr)
data("ledgr_demo_bars", package = "ledgr")

bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      ledgr_utc("2019-01-01"),
      ledgr_utc("2019-06-30")
    )
  )
```

## The Experiment Model

A ledgr run is produced from explicit inputs. The experiment fixes:

- a sealed snapshot;
- a strategy function;
- registered feature definitions;
- an opening state;
- a universe and execution options.

`ledgr_run()` then supplies strategy parameters and an immutable
`run_id`. The run derives fills, ledger events, equity, trades, metrics,
and comparison tables from those inputs. The sealed snapshot is the
evidence base. The strategy declares desired holdings at each pulse. The
feature list declares which derived values are available to the
strategy. The opening state declares cash and any starting positions.

That shape matters because each part has a different reproducibility
role. Market data are sealed. Parameters are stored and hashed. Strategy
source is captured when possible. Results are derived from ledger events
rather than remembered from an in-memory session.

## Why `params` Is The Boundary

Use `params` for strategy variation. Parameters are canonicalized,
hashed, and stored with the run. Hidden globals are not.

``` r
strategy <- function(ctx, params) {
  above <- ctx$vec$close > params$threshold
  targets <- ctx$flat()
  targets[above] <- params$qty
  targets
}
```

The same rule matters for every saved run and sweep row: explicit values
can be canonicalized and hashed; an arbitrary interactive session
cannot.

``` r
snapshot <- ledgr_snapshot_from_df(bars, snapshot_id = "research_snapshot")

features <- list(ledgr_ind_returns(5))

strategy <- function(ctx, params) {
  rising <- ledgr_signal_return(ctx, lookback = 5) > params$min_return
  ctx |>
    ledgr_selection(where = rising, missing = "exclude") |>
    ledgr_target_quantity(ctx, params$qty)
}

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
)

bt <- ledgr_run(
  exp,
  params = list(min_return = 0, qty = 10),
  run_id = "qty_10"
)
```

    Warning: LEDGR_LAST_BAR_NO_FILL: target changed on the final available bar, but the
    next-open fill model requires a following bar. No fill was emitted for this target
    change. Check the strategy's final-pulse behavior or extend the snapshot if this trade
    should be fillable.

The `LEDGR_LAST_BAR_NO_FILL` warning means the rule changed its target
on the last bar, where no later open exists to fill it. It does not
affect what the run records;
`vignette("execution-semantics", package = "ledgr")` explains it.

## The Provenance Model

For completed runs, ledgr stores run provenance alongside the result
tables. The provenance record includes the captured strategy source
where available, source hash, parameter JSON and parameter hash,
dependency-version metadata, ledgr version, R version, and
reproducibility tier.

If the strategy has a declarative schedule, provenance also stores its
canonical declaration and schedule hash. The inner strategy source hash
stays the identity of the decision function itself; the schedule
contributes separately to run and candidate identity. A parameterized
schedule records both what the author declared and the fixed rule
resolved for that candidate. The compiled decision mask is temporary
execution state and is not persisted.

Those fields do not make every run perfectly replayable. They make the
claim inspectable. A run should be explainable later: what source text
ledgr captured, which parameters were supplied, whether the source hash
still verifies, and what reproducibility tier ledgr assigned before
execution.

``` r
ledgr_run_info(snapshot, "qty_10")
```

    ledgr Run Info
    ==============

    Run ID:           qty_10
    Label:            NA
    Status:           DONE
    Archived:         FALSE
    Tags:             NA
    Snapshot:         research_snapshot
    Snapshot Hash:    1f315cc620d0849849114d32cb44b042ec567f9512db99ad802c4ac89efe3a43
    Feature Set Hash: de5d1af37415a1f7423cff4e673f917b944231a8767977d28edd092a775c9097
    Risk Chain Hash:  71863d276abfadf01e5451b8feb3ae38690b42c350db22b2740bf990358c0a11
    Config Hash:      37d83c3e5ec60663e37f5a054a745e195977892e347f228a05a255ab69eec579
    Strategy Hash:    bacaf6e70817b64d2a9221bc85f88607caed1e47d1da0e4a1bad4f61567f2989
    Params Hash:      3220f4b13aab31b2d35b6044d9d6e143ac6a8c9de9edd3353936006a683abdb9
    Reproducibility:  tier_1
    Execution Mode:   audit_log
    Fill Timing:      dense_bar_timestamp
    Timing Version:   N/A
    Elapsed Sec:      1.160

## Extract Stored Strategy Source

`ledgr_run_strategy()` inspects stored strategy provenance for a run.
The default is intentionally read-only:

``` r
stored <- ledgr_run_strategy(snapshot, "qty_10", trust = FALSE)
stored
```

    ledgr Extracted Strategy
    ========================

    Run ID:           qty_10
    Reproducibility:  tier_1
    Source Hash:      bacaf6e70817b64d2a9221bc85f88607caed1e47d1da0e4a1bad4f61567f2989
    Params Hash:      3220f4b13aab31b2d35b6044d9d6e143ac6a8c9de9edd3353936006a683abdb9
    Hash Verified:    TRUE
    Trust:            FALSE
    Source Available: TRUE

``` r
writeLines(stored$strategy_source_text)
```

    function (ctx, params)
    {
        rising <- ledgr_signal_return(ctx, lookback = 5) > params$min_return
        ledgr_target_quantity(ledgr_selection(ctx, where = rising, missing = "exclude"), ctx, params$qty)
    }

``` r
names(stored[c("R_version", "ledgr_version", "dependency_versions")])
```

    [1] "R_version"           "ledgr_version"       "dependency_versions"

``` r
dependencies <- names(stored$dependency_versions)
dependencies[order(tolower(dependencies), method = "radix")]
```

    [1] "collapse" "DBI"      "digest"   "duckdb"   "ledgr"    "R"        "tibble"
    [8] "TTR"      "yyjsonr"

The compact print emphasizes source identity. The field names above show
where the recorded runtime and dependency versions live without making
this article’s render depend on whichever package versions happen to be
installed today. Those versions are metadata, not a promise that every
external system library can be reconstructed.

`trust = FALSE` returns source text and metadata without parsing,
evaluating, or executing the stored source. In this mode, the source
text is just data.

Use `trust = TRUE` only when you explicitly trust the experiment store
and intentionally want ledgr to parse and evaluate the stored text into
a function object.

``` r
trusted <- ledgr_run_strategy(snapshot, "qty_10", trust = TRUE)
is.function(trusted$strategy_function)
```

    [1] TRUE

``` r
rerun_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = trusted$strategy_function,
  features = features,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
)

ledgr_run(
  rerun_exp,
  params = trusted$strategy_params,
  run_id = "qty_10_rerun"
)
```

    Warning: LEDGR_LAST_BAR_NO_FILL: target changed on the final available bar, but the
    next-open fill model requires a following bar. No fill was emitted for this target
    change. Check the strategy's final-pulse behavior or extend the snapshot if this trade
    should be fillable.

    ledgr Backtest Results
    ======================

    Run ID:                            qty_10_rerun
    Period:                            2019-01-01 to 2019-06-28
    Opening Cash:                      $10000.00
    Final Equity:                      $10119.69
    Total Return:                      1.20%
    Max Drawdown:                      -0.82%
    Closed Trades:                     20
    Metric Calendar:                   US equity daily (default) (252 days/year * 1 bars/day = 252 bars/year)

    Economic events: NOT SUPPLIED - returns may omit distributions
    Price basis: UNDECLARED - distribution double counting cannot be ruled out

    Use summary(bt) for metrics and evidence

Hash verification proves stored-text identity, not code safety. A
verified hash means the stored text matches the stored hash. It does not
mean the source is safe to evaluate, economically sensible, or
independent from external state.

Runs created by older versions of ledgr, and strategy types whose source
cannot be captured, may report `strategy_source_text = NA`. Those runs
can still be inspected through `ledgr_run_info()` and result tables, but
the strategy function cannot be recovered from provenance alone.

Stored source is a strong audit artifact, but it is only one part of
reproducibility. A strategy may call external packages. It may close
over data objects. It may rely on package versions, system libraries, or
runtime state outside ledgr’s database. That is why ledgr classifies
strategies before execution.

## Reproducibility Tiers

### Tier 1: Self-Contained

> [!NOTE]
>
> ### Definition
>
> Tier 1 means ledgr can inspect the strategy from stored source and
> explicit parameters under its static preflight rules. The strategy
> depends only on ledgr, base/recommended R, and declared run inputs.


Tier 1 is self-contained under ledgr’s static preflight rules. The
strategy can be understood from stored source and explicit parameters,
using base/recommended R references and ledgr’s exported public
namespace.

``` r
tier_1_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets[] <- params$qty
  targets
}

ledgr_strategy_preflight(tier_1_strategy)
```

    ledgr Strategy Preflight
    =========================

    Tier:    tier_1
    Allowed: TRUE
    Reason:  Strategy is self-contained under ledgr's static preflight rules.

### Tier 2: Inspectable With User-Managed Environment

> [!WARNING]
>
> ### Definition
>
> Tier 2 means ledgr can inspect and run the strategy, but full replay
> also depends on environment details outside ledgr’s store, such as
> package installation, package versions, system libraries, or immutable
> captured values.


Tier 2 is inspectable but needs environment management outside ledgr.
Examples include package-qualified calls outside the active R
distribution and resolved immutable non-function objects captured from
the strategy environment.

#### Package Dependencies

``` r
tier_2_strategy <- function(ctx, params) {
  TTR::SMA(c(1, 2, 3), n = 2)
  ctx$flat()
}

ledgr_strategy_preflight(tier_2_strategy)
```

    ledgr Strategy Preflight
    =========================

    Tier:    tier_2
    Allowed: TRUE
    Reason:  Strategy uses package dependency outside the active R distribution: TTR.
    Package Dependencies: TTR

The `TTR::SMA()` call is written this way on purpose. Namespace
qualification tells ledgr which package supplies the function. That
makes the dependency visible in the preflight result and keeps the
strategy inspectable. The run can proceed, but ledgr cannot preserve the
installed `TTR` version or its system requirements by itself.

#### Captured Values

Resolved external scalar values are also Tier 2, not Tier 3. They are
visible to the preflight because they exist in the strategy closure, but
ledgr does not turn them into replayable run parameters. Prefer putting
values that define the research question into `params`, especially for
sweeps.

``` r
captured_threshold <- 100

tier_2_captured <- function(ctx, params) {
  above <- ctx$vec$close > captured_threshold
  targets <- ctx$flat()
  targets[above] <- params$qty
  targets
}

tier_1_parameterized <- function(ctx, params) {
  above <- ctx$vec$close > params$threshold
  targets <- ctx$flat()
  targets[above] <- params$qty
  targets
}

list(
  captured_value = ledgr_strategy_preflight(tier_2_captured)$tier,
  explicit_parameter = ledgr_strategy_preflight(tier_1_parameterized)$tier
)
```

    $captured_value
    [1] "tier_2"

    $explicit_parameter
    [1] "tier_1"

Both functions are inspectable, but only the second makes the threshold
a declared run input. That is why the tier changes even though the
arithmetic is the same.

Captured mutable environments may be classified as Tier 2 because ledgr
can resolve that the object exists. Do not treat that classification as
approval. If the object can change between runs or workers, move the
value into `params` or freeze it before running.

#### What ledgr Preserves And What You Own

Tier 2 is allowed for ordinary runs and sequential sweeps. It is not
fully reproducible by ledgr alone. Users own package installation,
package version parity, system libraries, and any other runtime
environment needed by their strategy.

Common environment-management approaches in R projects include `renv`,
Docker, `{rix}` (<https://github.com/ropensci/rix>), and `{uvr}`
(<https://github.com/nbafrank/uvr>). ledgr does not require those tools
and this article does not teach them. The point is simpler: if a
strategy is Tier 2, ledgr can preserve the run evidence, but the user
must preserve the surrounding environment.

### Tier 3: Rejected External State

> [!IMPORTANT]
>
> ### Definition
>
> Tier 3 means the strategy depends on external state ledgr cannot recover
> or execute safely. The run is rejected before execution; there is no
> `force = TRUE` override.


Tier 3 is external state ledgr cannot recover or execute safely. Common
examples are unqualified helper functions from the interactive session,
wall-clock or process-environment calls such as `Sys.time()`,
`Sys.Date()`, and `Sys.getenv()`, and global assignment with `<<-`.

``` r
my_helper <- function(ctx) ctx$flat()

tier_3_strategy <- function(ctx, params) {
  my_helper(ctx)
}

ledgr_strategy_preflight(tier_3_strategy)
```

    ledgr Strategy Preflight
    =========================

    Tier:    tier_3
    Allowed: FALSE
    Reason:  Strategy references unresolved symbol(s): my_helper.
    Unresolved Symbols: my_helper

Tier 3 strategies fail before execution. There is no `force = TRUE`
override on `ledgr_run()` or `ledgr_sweep()`. Move scalar configuration
into `params`, qualify package calls, or place a small helper inside the
strategy body so its source is captured. Do not put function objects in
`params`; run parameters must remain JSON-safe values.

``` r
repaired_strategy <- function(ctx, params) {
  choose_targets <- function(context, quantity) {
    above <- context$vec$close > params$threshold
    targets <- context$flat()
    targets[above] <- quantity
    targets
  }

  choose_targets(ctx, params$qty)
}

ledgr_strategy_preflight(repaired_strategy)
```

    ledgr Strategy Preflight
    =========================

    Tier:    tier_1
    Allowed: TRUE
    Reason:  Strategy is self-contained under ledgr's static preflight rules.

Preflight rejection comes first. A Tier 3 strategy stops before the run
starts: before any pulse executes and before anything is written, so the
preflight error is the first one you see. The condition class chain
includes `ledgr_strategy_tier3` and `ledgr_strategy_preflight_error`.

The most common hard rejections are:

| Pattern | Example | Why it fails |
|----|----|----|
| wall-clock access | `Sys.time()` or `do.call("Sys.time", list())` | runtime date/time is not stored run input |
| process environment | `Sys.getenv("TOKEN")` | external process state is not stored run input |
| dynamic evaluation | `get("x")`, `eval(expr)`, `assign("x", 1)` | preflight cannot recover the value path as stored metadata |
| global assignment | `x <<- 1` | strategy mutates state outside the run artifact |
| context mutation | `attr(ctx, "secret") <- 1` | strategy mutates ledgr’s execution context |
| private context internals | `ctx$.history` or `environment(ctx$feature)` | the private carriers hold prepared data beyond the pulse; read history with `ledgr_history_frame()` |
| unresolved helper | `my_helper(ctx)` | helper source is not stored as part of the strategy |

Recommended-R functions such as `stats::median()` remain Tier
1-compatible when called explicitly or resolved through R’s
base/recommended namespace. They are not package dependencies outside
the active R distribution.

## Random Decisions

Ambient strategy RNG calls such as `runif(1)` are a separate case. They
are allowed as Tier 2 for ordinary sequential runs because ledgr’s
execution seed contract can make a continuous strategy run repeatable,
but they are not certified for resume or parallel equivalence. A resumed
run reconstructs positions and cash from events; it does not restore
`.Random.seed` to the exact point a continuous run would have reached
before the next pulse.

Strategies that need pulse-specific stochastic inputs in resume-safe or
parallel-safe paths should derive those inputs from `ctx$pulse_seed`.
The field is an integer computed from the execution seed and the 1-based
pulse position in the run’s pulse calendar, so it does not depend on
worker order, timestamps, event sequence numbers, or ambient RNG state.
A straight run, a resumed run, a sweep candidate and its promoted run
get the same value at the same position of the same calendar. `ctx$seed`
remains the per-execution seed; `ctx$pulse_seed` is the per-pulse
derivative, and it is `NULL` when the run has no seed.

This is different from custom-indicator RNG restrictions: feature
generation must be deterministic for a given snapshot and feature
definition. Prefer making random decisions explicit in the research
design. A seeded decision may be repeatable, but it is still part of the
decision process.

### The Recipe

Draw inside `withr::with_seed(ctx$pulse_seed, ...)`, and stop when there
is no seed. This strategy holds 10 shares of one instrument per pulse,
chosen at random:

``` r
random_pick <- function(ctx, params) {
  if (is.null(ctx$pulse_seed)) {
    stop("random_pick needs a seed: pass `seed =` to ledgr_run() or ledgr_sweep().")
  }
  pick <- withr::with_seed(ctx$pulse_seed, sample.int(length(ctx$universe), 1L))
  targets <- ctx$flat()
  targets[ctx$universe[pick]] <- params$qty
  targets
}

random_exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = random_pick,
  opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
)

ledgr_strategy_preflight(random_pick)[c("tier", "ambient_rng_symbols")]
```

    $tier
    [1] "tier_2"

    $ambient_rng_symbols
    character(0)

The recipe is Tier 2 because of the `withr::` call, and preflight
reports no ambient RNG symbol. Use `sample.int()` for the draw, as here.
Preflight detects direct calls to `runif()`, `rnorm()` and `sample()`,
even inside `with_seed()`, and refuses them on resume and in sweeps with
several workers. Other draws, such as `sample.int()`, `rbinom()` or
draws inside package functions, are not detected. That gap is unchanged:
an undetected draw outside `with_seed()` is still ambient RNG and still
not certified. Detection is parked as an open design question ([Ambient
RNG detection for
strategies](https://github.com/blechturm/ledgr/blob/main/inst/design/horizon.md#2026-10-29-execution-ambient-rng-detection-for-strategies)).

A seed is required. Without one, the guard stops the run on its first
pulse:

``` r
tryCatch(
  ledgr_run(random_exp, params = list(qty = 10), run_id = "random_unseeded"),
  ledgr_strategy_error = function(error) conditionMessage(error$parent)
)
```

    [1] "random_pick needs a seed: pass `seed =` to ledgr_run() or ledgr_sweep()."

With a seed, the draws move the strategy between instruments. A
different seed gives different fills. The random switches often change
the target on the last bar, so these runs raise the
`LEDGR_LAST_BAR_NO_FILL` warning explained above; this chunk hides it.

``` r
bt_seed_1 <- ledgr_run(random_exp, params = list(qty = 10), seed = 1L, run_id = "random_seed_1")
bt_seed_2 <- ledgr_run(random_exp, params = list(qty = 10), seed = 2L, run_id = "random_seed_2")

fills_1 <- ledgr_results(bt_seed_1, "fills")
fills_2 <- ledgr_results(bt_seed_2, "fills")

head(fills_1[c("ts_utc", "instrument_id", "side", "qty")])
```

    # A tibble: 6 x 4
      ts_utc     instrument_id side    qty
      <date>     <chr>         <chr> <dbl>
    1 2019-01-02 DEMO_01       BUY      10
    2 2019-01-07 DEMO_01       SELL     10
    3 2019-01-07 DEMO_02       BUY      10
    4 2019-01-10 DEMO_01       BUY      10
    5 2019-01-10 DEMO_02       SELL     10
    6 2019-01-11 DEMO_01       SELL     10

``` r
table(fills_1$instrument_id)
```


    DEMO_01 DEMO_02
         62      61

``` r
c(seed_1 = nrow(fills_1), seed_2 = nrow(fills_2))
```

    seed_1 seed_2
       123    131

``` r
identical(
  fills_1[c("ts_utc", "instrument_id", "side", "qty")],
  fills_2[c("ts_utc", "instrument_id", "side", "qty")]
)
```

    [1] FALSE

The same seeded sweep gives the same candidates with one worker and with
two. Parallel sweeps need the `mirai` package; each worker loads ledgr
and `withr`:

``` r
grid <- data.frame(qty = c(5, 10))
sweep_1_worker <- ledgr_sweep(random_exp, grid, seed = 2026L, workers = 1L)
sweep_2_workers <- ledgr_sweep(random_exp, grid, seed = 2026L, workers = 2L)

data.frame(
  qty = grid$qty,
  execution_seed = sweep_1_worker$execution_seed,
  final_equity_1_worker = sweep_1_worker$final_equity,
  final_equity_2_workers = sweep_2_workers$final_equity,
  n_trades_1_worker = sweep_1_worker$n_trades,
  n_trades_2_workers = sweep_2_workers$n_trades
)
```

      qty execution_seed final_equity_1_worker final_equity_2_workers n_trades_1_worker
    1   5      359458135              10018.95               10018.95                56
    2  10      724846829              10001.72               10001.72                58
      n_trades_2_workers
    1                 56
    2                 58

``` r
identical(sweep_1_worker$execution_seed, sweep_2_workers$execution_seed) &&
  identical(sweep_1_worker$final_equity, sweep_2_workers$final_equity) &&
  identical(sweep_1_worker$n_trades, sweep_2_workers$n_trades)
```

    [1] TRUE

This works because ledgr seeds every seeded run with one fixed RNG kind,
Mersenne-Twister with Inversion and Rejection, and workers start with
the same kind, so `with_seed()` draws the same numbers in every process.

### Your Own Random State

ledgr restores your RNG kind and `.Random.seed` (or their absence)
around its own work (store writes, seeding, worker start and stop) and
around the user code it runs for you: strategies, indicator and feature
callbacks, ranking and selection expressions such as `rank_by`, and the
`test` and `test_dates` helpers of `ledgr_indicator_dev()`, which
restore on each call. The arguments you pass are evaluated first, before
ledgr saves your random state, so random draws in them advance your
stream as if you had made them yourself: two calls of
`ledgr_run(exp, seed = sample.int(1e6, 1))` get different seeds.
Expressions that ledgr captures and runs later, such as `rank_by` and
`.filter`, are restored. An S3 method you define is restored when a
restoring ledgr function calls it after entry, and is your own code when
another ledgr function calls it. The strategy from
`ledgr_signal_strategy()` and the indicator function from
`ledgr_adapter_r()` do not restore: inside a run they draw like any
strategy or indicator, and when you call them yourself they are your own
code. A pending Box-Muller normal variate is not preserved.

``` r
set.seed(99)
untouched <- runif(1)

set.seed(99)
invisible(ledgr_sim_bars(n_instruments = 1, n_days = 5, seed = 1L))
identical(runif(1), untouched)
```

    [1] TRUE

ledgr’s simulator seeded and drew its own numbers, yet your next draw is
the one you would have got without it.

## Hidden Mutable State

Static analysis is not proof of semantic reproducibility. Patterns such
as `<<-`, mutable captured environments, dynamic dispatch, and
dynamically constructed calls can make a strategy order-dependent or
worker-dependent even when some symbols resolve.

``` r
counter <- 0

bad_strategy <- function(ctx, params) {
  counter <<- counter + 1
  ctx$flat()
}

ledgr_strategy_preflight(bad_strategy)$tier
```

    [1] "tier_3"

The global assignment is caught here, but preflight cannot see every
form of hidden state, such as a mutable object reached through a
captured environment. Avoid this pattern. Store intentional strategy
variation in `params`, and let ledgr record decisions and state changes
through the run artifacts.

## What To Remember

Reproducibility in ledgr is a chain:

```mermaid
flowchart LR
  A[Sealed snapshot] --> B[Experiment inputs]
  B --> C[Preflight tier]
  C --> D[Run provenance]
  D --> E[Ledger events]
  E --> F[Derived results]
  D --> G[Stored source inspection]
```

Tier 1 is the cleanest path. Tier 2 is allowed but requires user-managed
environment parity. Tier 3 fails because ledgr cannot recover what the
strategy depended on.

> [!TIP]
>
> ### Try it
>
> Write a strategy that calls `Sys.time()` and run
> `ledgr_strategy_preflight()`. What tier does ledgr assign, and what
> dependency did the preflight reject?


## Where Next

- `vignette("research-workflow", package = "ledgr")` follows a research
  idea through code iterations, sweeps, and promotion.
- `vignette("strategy-authoring-tools", package = "ledgr")` covers
  helper pipelines, one-pulse testing, and strategy state.
- `vignette("experiment-store", package = "ledgr")` covers store-level
  source inspection and reopening.
