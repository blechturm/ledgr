# On Reproducibility: Provenance and Strategy Tiers


ledgr treats a backtest result as an experiment artifact. The question
is not only “what was the return?” The question is:

``` text
which sealed data, which strategy, which parameters, which features,
which opening state, and which execution assumptions produced this run?
```

This article explains the reproducibility model behind that question. It
is about provenance and replay boundaries, not whether a strategy has
predictive edge.

<div class="ledgr-callout ledgr-callout-warning">

**Evidence is not validation**

Provenance records what ran. It does not prove that a selected strategy
will generalize. A promoted candidate, a verified strategy hash, and a
sealed snapshot are evidence-capture tools, not statistical validation
of the selection rule.

</div>

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
  targets <- ctx$flat()

  for (id in ctx$universe) {
    if (ctx$close(id) > params$threshold) {
      targets[id] <- params$qty
    }
  }

  targets
}
```

The same rule matters for future sweep workers. Sweep mode can send
explicit parameter combinations to workers. It cannot reliably send an
arbitrary interactive session.

``` r
snapshot <- ledgr_snapshot_from_df(bars, snapshot_id = "research_snapshot")

features <- list(ledgr_ind_returns(5))

strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    ret_5 <- ctx$feature(id, "return_5")
    if (is.finite(ret_5) && ret_5 > params$min_return) {
      targets[id] <- params$qty
    }
  }

  targets
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

## The Provenance Model

For completed runs, ledgr stores run provenance alongside the result
tables. The provenance record includes the captured strategy source
where available, source hash, parameter JSON and parameter hash,
dependency-version metadata, ledgr version, R version, and
reproducibility tier.

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

    Run ID:          qty_10
    Label:           NA
    Status:          DONE
    Archived:        FALSE
    Tags:            NA
    Snapshot:        research_snapshot
    Snapshot Hash:   6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e
    Feature Set Hash: fca1ef954400ce7477424f60b32a500cb8bd7665882cfdf37f0ee409e7d6ac5f
    Config Hash:     721bcde02cc7916bb1fd40cb6b136887533332dea1587f4b5b8bfd6817cf5b1d
    Strategy Hash:   f4b2b315e3352a0ac466722988f4deb3d925056b6dff585dbb102ed405ccce91
    Params Hash:     3220f4b13aab31b2d35b6044d9d6e143ac6a8c9de9edd3353936006a683abdb9
    Reproducibility: tier_1
    Execution Mode:  audit_log
    Elapsed Sec:     0.94
    Persist Features:TRUE
    Cache Hits:      0
    Cache Misses:    2

## Extract Stored Strategy Source

`ledgr_run_strategy()` inspects stored strategy provenance for a
run. The default is intentionally read-only:

``` r
stored <- ledgr_run_strategy(snapshot, "qty_10", trust = FALSE)
stored
```

    ledgr Extracted Strategy
    ========================

    Run ID:          qty_10
    Reproducibility: tier_1
    Source Hash:     f4b2b315e3352a0ac466722988f4deb3d925056b6dff585dbb102ed405ccce91
    Params Hash:     3220f4b13aab31b2d35b6044d9d6e143ac6a8c9de9edd3353936006a683abdb9
    Hash Verified:   TRUE
    Trust:           FALSE
    Source Available:TRUE

``` r
writeLines(stored$strategy_source_text)
```

    function (ctx, params)
    {
        targets <- ctx$flat()
        for (id in ctx$universe) {
            ret_5 <- ctx$feature(id, "return_5")
            if (is.finite(ret_5) && ret_5 > params$min_return) {
                targets[id] <- params$qty
            }
        }
        targets
    }

`trust = FALSE` returns source text and metadata without parsing,
evaluating, or executing the stored source. In this mode, the source
text is just data.

Use `trust = TRUE` only when you explicitly trust the experiment store
and intentionally want ledgr to parse and evaluate the stored text into
a function object.

``` r
trusted <- ledgr_run_strategy(snapshot, "qty_10", trust = TRUE)
trusted$strategy_function
```

Hash verification proves stored-text identity, not code safety. A
verified hash means the stored text matches the stored hash. It does not
mean the source is safe to evaluate, economically sensible, or
independent from external state.

Legacy/pre-provenance runs and strategy types without capturable source
may report `strategy_source_text = NA`. Those runs can still be
inspected through `ledgr_run_info()` and result tables, but the strategy
function cannot be recovered from provenance alone.

Stored source is a strong audit artifact, but it is only one part of
reproducibility. A strategy may call external packages. It may close
over data objects. It may rely on package versions, system libraries, or
runtime state outside ledgr’s database. That is why ledgr classifies
strategies before execution.

## Reproducibility Tiers

### Tier 1: Self-Contained

<div class="ledgr-callout ledgr-callout-note">

**Definition**

Tier 1 means ledgr can inspect the strategy from stored source and
explicit parameters under its static preflight rules. The strategy
depends only on ledgr, base/recommended R, and declared run inputs.

</div>

Tier 1 is self-contained under ledgr’s static preflight rules. The
strategy can be understood from stored source and explicit parameters,
using base/recommended R references and ledgr’s exported public
namespace.

``` r
tier_1_strategy <- function(ctx, params) {
  targets <- ctx$flat()

  for (id in ctx$universe) {
    targets[id] <- params$qty
  }

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

<div class="ledgr-callout ledgr-callout-warning">

**Definition**

Tier 2 means ledgr can inspect and run the strategy, but full replay
also depends on environment details outside ledgr’s store, such as
package installation, package versions, system libraries, or immutable
captured values.

</div>

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

Captured mutable environments may be classified as Tier 2 because ledgr
can resolve that the object exists. Do not treat that classification as
approval. If the object can change between runs or workers, move the
value into `params` or freeze it before running.

#### What ledgr Preserves And What You Own

Tier 2 is allowed for ordinary runs and future sweep mode. It is not
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

<div class="ledgr-callout ledgr-callout-important">

**Definition**

Tier 3 means the strategy depends on external state ledgr cannot recover
or execute safely. The run is rejected before execution; there is no
`force = TRUE` override.

</div>

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
override on `ledgr_run()` or `ledgr_sweep()`; move external values into
`params`, qualify package calls, or use ledgr’s exported helpers
instead.

Preflight rejection is the first boundary. A covered Tier 3 strategy
stops before fold execution, before output-handler side effects, and
before later determinism hashing can become the first user-facing error.
The condition class chain includes `ledgr_strategy_tier3` and
`ledgr_strategy_preflight_error`.

The most common hard rejections are:

| Pattern | Example | Why it fails |
|----|----|----|
| wall-clock access | `Sys.time()` or `do.call("Sys.time", list())` | runtime date/time is not stored run input |
| process environment | `Sys.getenv("TOKEN")` | external process state is not stored run input |
| dynamic evaluation | `get("x")`, `eval(expr)`, `assign("x", 1)` | preflight cannot recover the value path as stored metadata |
| global assignment | `x <<- 1` | strategy mutates state outside the run artifact |
| context mutation | `attr(ctx, "secret") <- 1` | strategy mutates ledgr’s execution context |
| unresolved helper | `my_helper(ctx)` | helper source is not stored as part of the strategy |

Recommended-R functions such as `stats::median()` remain Tier
1-compatible when called explicitly or resolved through R’s
base/recommended namespace. They are not package dependencies outside
the active R distribution.

Ambient strategy RNG calls such as `runif(1)` are a separate case. They
are allowed as Tier 2 for ordinary sequential runs because ledgr’s
execution seed contract can make a continuous strategy run repeatable,
but they are not certified for resume or parallel equivalence. A resumed
run reconstructs positions and cash from events; it does not restore
`.Random.seed` to the exact point a continuous run would have reached
before the next pulse.

Strategies that need pulse-specific stochastic inputs in resume-safe or
parallel-safe paths should derive those inputs from `ctx$pulse_seed`.
The field is a stable integer derived from the execution seed and the
1-based pulse position in the run’s pulse sequence, so it does not
depend on worker order, timestamps, event sequence numbers, or ambient
RNG state. `ctx$seed` remains the per-execution seed; `ctx$pulse_seed`
is the per-pulse derivative.

This is different from custom-indicator RNG restrictions: feature
generation must be deterministic for a given snapshot and feature
definition. Prefer making random decisions explicit in the research
design. A seeded decision may be repeatable, but it is still part of the
decision process.

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
```

Avoid this pattern. Store intentional strategy variation in `params`,
and let ledgr record decisions and state changes through the run
artifacts.

## What To Remember

Reproducibility in ledgr is a chain:

``` mermaid
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

<div class="ledgr-callout ledgr-callout-tip">

**Try it**

Write a strategy that calls `Sys.time()` and run
`ledgr_strategy_preflight()`. What tier does ledgr assign, and what
dependency did the preflight reject?

</div>

## Where Next

For the end-to-end research loop and the selection-validation
distinction, read `vignette("research-workflow", package = "ledgr")`.
For strategy-authoring patterns that avoid Tier 3 failures, read
`vignette("strategy-development", package = "ledgr")`. For store-level
source inspection and reopen workflows, read
`vignette("experiment-store", package = "ledgr")`.
