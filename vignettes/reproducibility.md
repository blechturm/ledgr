On Reproducibility: Provenance and Strategy Tiers
================

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

ledgr treats a backtest result as an experiment artifact. The question
is not only “what was the return?” The question is:

``` text
which sealed data, which strategy, which parameters, which features,
which opening state, and which execution assumptions produced this run?
```

This article explains the reproducibility model behind that question.

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
  opening = ledgr_opening(cash = 10000)
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

## Extract Stored Strategy Source

`ledgr_extract_strategy()` inspects stored strategy provenance for a
run. The default is intentionally read-only:

``` r
stored <- ledgr_extract_strategy(snapshot, "qty_10", trust = FALSE)
stored
writeLines(stored$strategy_source_text)
```

`trust = FALSE` returns source text and metadata without parsing,
evaluating, or executing the stored source. In this mode, the source
text is just data.

Use `trust = TRUE` only when you explicitly trust the experiment store
and intentionally want ledgr to parse and evaluate the stored text into
a function object.

``` r
trusted <- ledgr_extract_strategy(snapshot, "qty_10", trust = TRUE)
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

## Stored Source Is Not Full Reproducibility

Stored source is a strong audit artifact, but it is only one part of
reproducibility. A strategy may call external packages. It may close
over data objects. It may rely on package versions, system libraries, or
runtime state outside ledgr’s database.

That is why ledgr classifies strategies before execution.

## Reproducibility Tiers

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

Tier 2 is inspectable but needs environment management outside ledgr.
Examples include package-qualified calls outside the active R
distribution and resolved non-function objects captured from the
strategy environment.

``` r
tier_2_strategy <- function(ctx, params) {
  jsonlite::toJSON(params, auto_unbox = TRUE)
  ctx$flat()
}

ledgr_strategy_preflight(tier_2_strategy)
```

The `jsonlite::toJSON()` call is written this way on purpose. Namespace
qualification tells ledgr which package supplies the function. That
makes the dependency visible in the preflight result and keeps the
strategy inspectable. The run can proceed, but ledgr cannot preserve the
installed `jsonlite` version or its system requirements by itself.

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

Tier 3 is external state ledgr cannot recover. The most common example
is an unqualified helper function from the interactive session.

``` r
my_helper <- function(ctx) ctx$flat()

tier_3_strategy <- function(ctx, params) {
  my_helper(ctx)
}

ledgr_strategy_preflight(tier_3_strategy)
```

Tier 3 strategies fail before execution by default. There is no
`force = TRUE` override in v0.1.7.8.

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

``` text
sealed snapshot -> experiment inputs -> preflight tier -> run provenance
-> ledger events -> derived results -> stored source inspection
```

Tier 1 is the cleanest path. Tier 2 is allowed but requires user-managed
environment parity. Tier 3 fails by default because ledgr cannot recover
what the strategy depended on.
