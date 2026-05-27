# Research Workflow


<style>
.ledgr-diagram {
  margin: 1.25rem auto 1.5rem auto;
  text-align: center;
}
&#10;.ledgr-diagram .mermaid {
  display: inline-block;
  max-width: 100%;
}
&#10;.ledgr-diagram .mermaid svg {
  display: block;
  height: auto !important;
  margin-left: auto;
  margin-right: auto;
}
&#10;.ledgr-workflow-diagram .mermaid svg {
  max-width: 980px !important;
}
&#10;.ledgr-validation-diagram .mermaid svg {
  max-width: 520px !important;
}
</style>

You have an idea for a trading rule. Maybe a fast moving average
crossing a slow one looks useful. How do you turn that hunch into
evidence you can reopen, inspect, and explain later?

That is the job of this article. You will create a sealed data snapshot,
declare an experiment, run the strategy once, explore a small grid,
inspect the candidate table, promote one candidate with a note, and
reopen the stored artifact.

The loop is deliberately short:

<div class="ledgr-diagram ledgr-workflow-diagram">

``` mermaid
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 18, "rankSpacing": 24, "curve": "linear"}, "themeVariables": {"fontFamily": "system-ui, -apple-system, Segoe UI, sans-serif", "fontSize": "22px", "primaryColor": "#f8fafc", "primaryTextColor": "#1f2937", "primaryBorderColor": "#64748b", "lineColor": "#64748b", "tertiaryColor": "#eef2ff", "tertiaryTextColor": "#1f2937", "tertiaryBorderColor": "#64748b", "clusterBkg": "#ffffff", "clusterBorder": "#cbd5e1"}}}%%

flowchart LR
  data["Seal data"]
  experiment["Declare experiment"]
  single["Run once"]
  sweep["Sweep candidates"]
  inspect["Inspect evidence"]
  promote["Promote with note"]
  reopen["Reopen and recover"]

  data --> experiment --> single --> sweep --> inspect --> promote --> reopen
  inspect -. new research iteration .-> experiment
```

</div>

Each step removes one common ambiguity:

- sealing fixes the evidence;
- experiment declaration fixes the strategy boundary;
- a single run checks that the setup behaves at all;
- sweeping compares declared candidates;
- inspection makes the selection rule visible;
- promotion records the human choice;
- reopening proves the result is a durable artifact.

The goal is not to make research slower. The goal is to make later
explanations possible.

After promotion, ledgr can show you the run metadata, the source sweep
context, the selected candidate, the strategy parameters, the strategy
source metadata, and the promotion note. Recoverability has limits,
especially for Tier 2 strategies that depend on external functions or
package state, but ledgr records enough provenance to explain what
caused a promoted result within the declared reproducibility tier.

Promotion records selection; it does not prove generalization. That
caveat is part of the workflow, not a footnote at the end.

## Prerequisites

This walkthrough uses `ledgr` plus `dplyr` for compact data
manipulation. Strategies themselves do not depend on `dplyr`; inside a
run they only read from the ledgr pulse context.

``` r
library(ledgr)
library(dplyr)

data("ledgr_demo_bars", package = "ledgr")
```

> [!NOTE]
>
> ### Running this yourself
>
> This article is evaluated when it is rendered. To keep package builds
> and local previews disposable, the code writes to a temporary DuckDB
> store. In a real project, replace `store_path` with a durable path
> such as `artifacts/ledgr_store.duckdb`.

> [!NOTE]
>
> ### About the demo data
>
> `DEMO_01` and `DEMO_02` are package-owned demo instruments. Real
> research should use a sealed snapshot of the market data you intend to
> study. The point here is the shape of the workflow, not the realism of
> the data.

## Project Topology

Start with a small project shape. One script creates the evidence, one
store holds the artifacts, and one report explains the research choice.

``` text
my-ledgr-project/
  artifacts/
    ledgr_store.duckdb
  reports/
    workflow_review.md
  scripts/
    research_workflow.R
```

ledgr does not require this exact layout. The point is simpler: keep the
script, durable store, and written reasoning close enough that a future
review can recover the full research decision.

In a real project, add generated stores such as `artifacts/*.duckdb` to
`.gitignore` unless you have a deliberate artifact-versioning policy.
The script and source data should explain how to recreate the store; Git
should not quietly become the database backup.

In this rendered article, use a temporary store so repeated builds do
not leave project artifacts behind. In a real project, make this a
boring durable path: future you should know where the evidence lives.

``` r
store_path <- file.path(tempdir(), "ledgr_research_workflow.duckdb")
if (file.exists(store_path)) {
  unlink(store_path)
}
```

## Fix The Evidence: Seal A Snapshot

First, choose the data window. Here you use two demo instruments over
the first half of 2019.

``` r
bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(
      ts_utc,
      ledgr_utc("2019-01-01"),
      ledgr_utc("2019-06-30")
    )
  )

bars |>
  slice_head(n = 4)
```

    # A tibble: 4 × 7
      ts_utc              instrument_id  open  high   low close volume
      <dttm>              <chr>         <dbl> <dbl> <dbl> <dbl>  <dbl>
    1 2019-01-01 00:00:00 DEMO_01        89.7  91.8  89.7  91.5 468600
    2 2019-01-02 00:00:00 DEMO_01        91.5  91.6  91.0  91.3 438315
    3 2019-01-03 00:00:00 DEMO_01        91.3  92.1  89.6  90.5 576390
    4 2019-01-04 00:00:00 DEMO_01        90.7  91.1  89.5  89.8 458921

You should see a small bar table. The exact print width depends on your
console, but the important columns are the timestamp, instrument, OHLC
prices, and volume.

Now seal those bars into the project store.

``` r
snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = store_path,
  snapshot_id = "demo_2019_h1"
)
```

Once the data is sealed, the snapshot becomes the identity of the
evidence. Every run below refers back to that same immutable input. If
you change the evidence, create a new snapshot instead of editing this
one. That is what makes later comparison and reopening meaningful.

## Declare The Experiment Boundary

The strategy should be able to ask for `fast` and `slow`, not for long
engine-generated feature IDs. The aliases are the names the strategy
will read at each pulse. The underlying indicator declarations still
remain part of the hashed experiment configuration.

``` r
features <- ledgr_feature_map(
  fast = ledgr_ind_sma(ledgr_param("fast_n")),
  slow = ledgr_ind_sma(ledgr_param("slow_n"))
)
```

This is the first place where the two parameter namespaces matter:
`feature_params` will choose `fast_n` and `slow_n`; strategy `params`
will choose values such as `qty` and `threshold`.

## Choose The Strategy

Use the demo SMA crossover strategy for the workflow. It expects active
aliases named `fast` and `slow`, then returns target holdings.

``` r
strategy <- ledgr_demo_sma_crossover_strategy()
```

You do not need to write a strategy for this vignette. The following
miniature example only shows the boundary that the demo strategy
follows: read pulse-known values from `ctx`, guard warmup with
`passed_warmup()`, and return a full named numeric target vector.

``` r
custom_sma_strategy <- function(ctx, params) {
  target <- ctx$flat()

  for (instrument_id in ctx$universe) {
    values <- ctx$features(instrument_id)

    # TRUE once enough bars have passed to calculate the slow SMA.
    if (passed_warmup(values) &&
        values[["fast"]] / values[["slow"]] - 1 > params$threshold) {
      target[[instrument_id]] <- params$qty
    }
  }

  target
}
```

For full strategy-authoring patterns, use
`vignette("strategy-development", package = "ledgr")`. This article
stays on the research workflow. While the example above shows the
internal mechanics, the rest of this workflow uses the built-in strategy
object created earlier.

## Sanity-Check One Run

Before you fan out into a sweep, run one parameter set. You are checking
two basic things: did anything trade, and do the derived results look
plausible? Sweeps amplify whatever your setup does, including doing
nothing.

At this stage, the exact performance number matters less than the
existence and plausibility of fills, positions, and equity.

``` r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)

single_run <- ledgr_run(
  exp,
  params = list(qty = 10, threshold = 0),
  feature_params = list(fast_n = 10L, slow_n = 40L),
  run_id = "workflow_single_run",
  seed = 2026
)

summary(single_run)
```

    ledgr Backtest Summary
    ======================

    Performance Metrics:
      Total Return:        1.07%
      Annualized Return:   2.11%
      Max Drawdown:        -0.76%

    Risk Metrics:
      Risk-Free Rate:      0.00% annual
      Annualization:       252 periods/year (US equity daily)
      Volatility (annual): 1.56%
      Sharpe Ratio:        1.349

    Trade Statistics:
      Total Trades:        2
      Win Rate:            100.00%
      Avg Trade:           $53.41

    Exposure:
      Time in Market:      59.69%

``` r
ledgr_results(single_run, what = "trades")
```

    # A tibble: 2 × 9
      event_seq ts_utc     instrument_id side    qty price   fee realized_pnl action
          <int> <date>     <chr>         <chr> <dbl> <dbl> <dbl>        <dbl> <chr> 
    1         3 2019-04-23 DEMO_01       SELL     10 102.      0         27.4 CLOSE 
    2         4 2019-06-13 DEMO_02       SELL     10  76.5     0         79.4 CLOSE 

``` r
head(ledgr_results(single_run, what = "equity"), 3)
```

    # A tibble: 3 × 6
      ts_utc     equity  cash positions_value running_max drawdown
      <date>      <dbl> <dbl>           <dbl>       <dbl>    <dbl>
    1 2019-01-01  10000 10000               0       10000        0
    2 2019-01-02  10000 10000               0       10000        0
    3 2019-01-03  10000 10000               0       10000        0

The first run should give you a completed backtest object, a trade
table, and an equity curve. You are not looking for the best result yet;
you are checking that the workflow produces evidence.

If this run has no fills, odd position changes, or implausible equity,
stop here and debug the strategy or feature declarations before
sweeping.

## Compare Declared Candidates

Now expand from one run to a small grid. Keep feature parameters and
strategy parameters separate, then combine them into one executable
grid.

``` r
feature_grid <- ledgr_feature_grid(
  fast_n = c(5L, 10L),
  slow_n = c(20L, 40L),
  .filter = fast_n < slow_n
)

strategy_grid <- ledgr_strategy_grid(
  qty = c(5, 10),
  threshold = c(0, 0.01)
)

grid <- ledgr_grid_cross(features = feature_grid, strategy = strategy_grid)
precomputed <- ledgr_precompute_features(exp, grid)

sweep <- ledgr_sweep(
  exp,
  grid,
  precomputed_features = precomputed,
  seed = 2026
)
```

Precomputing features is not a separate research decision. It is an
execution optimization: the same declared feature grid is computed once
and reused across candidates.

`ledgr_sweep()` gives you candidate evidence. It does not choose a
winner for you. That choice belongs in the next step, where you inspect
the table and make the ranking rule visible.

> [!TIP]
>
> ### Try it
>
> Add a third value to `fast_n` and `slow_n`. How many candidates does
> the `.filter` keep? How many would exist without the filter?

## Inspect Before You Promote

Now you have a table of candidates. Before you pick one, look at both
the successful rows and the rows that did not finish. You are not
validating yet; you are learning the shape of the evidence.

For this walkthrough, use a deliberately simple ranking rule: among
completed candidates, sort by Sharpe ratio descending. In real research,
make that rule visible before treating the top row as meaningful.

``` r
ranked <- sweep |>
  filter(status == "DONE") |>
  arrange(desc(sharpe_ratio))

candidate_columns <- c(
  "run_id", "status", "final_equity", "total_return",
  "sharpe_ratio", "params", "feature_params"
)

top_n <- ranked |>
  slice_head(n = 5) |>
  select(all_of(candidate_columns))
glimpse(top_n)
```

    Rows: 5
    Columns: 7
    $ run_id         <chr> "feature_403538546350/strategy_50fe1adcd9c5", "feature_4035385463…
    $ status         <chr> "DONE", "DONE", "DONE", "DONE", "DONE"
    $ final_equity   <dbl> 10225.14, 10112.57, 10164.67, 10082.34, 10141.20
    $ total_return   <dbl> 0.022514428, 0.011257214, 0.016467259, 0.008233629, 0.014119827
    $ sharpe_ratio   <dbl> 3.084337, 3.079333, 2.131805, 2.127012, 2.058200
    $ params         <list> [10, 0.01], [5, 0.01], [10, 0.01], [5, 0.01], [10, 0.01]
    $ feature_params <list> [5, 20], [5, 20], [5, 40], [5, 40], [10, 20]

``` r
issue_columns <- c("run_id", "status", "error_class", "error_msg", "warnings")

issues <- sweep |>
  filter(status != "DONE") |>
  select(any_of(issue_columns)) |>
  as_tibble()
issues
```

    # A tibble: 0 × 5
    # ℹ 5 variables: run_id <chr>, status <chr>, error_class <chr>, error_msg <chr>,
    #   warnings <list>

``` r
candidate <- ledgr_candidate(ranked, 1)
```

The output should look like a candidate table rather than a final
answer.

The `top_n` table shows which candidates would be selected by this
ranking choice. The `issues` table tells you whether any candidates
failed, warned, or produced diagnostics that should change how you read
the sweep.

> [!NOTE]
>
> ### Design note
>
> This explicit table code keeps the selection rule visible. The
> v0.1.8.6 cycle plans a sweep-review helper that ranks completed
> candidates, returns a compact review table, separates issue rows, and
> preserves the same explicit selection rule.

> [!TIP]
>
> ### Try it
>
> Sort by `total_return` instead of `sharpe_ratio`. Does the first
> candidate change? If it does, your “best” candidate depends on the
> metric, not only on the strategy.

## Commit The Selection With A Note

Promotion commits one selected candidate as a named run and attaches the
human selection note.

``` r
promoted <- ledgr_promote(
  exp,
  candidate,
  run_id = "workflow_promoted_candidate",
  note = paste(
    "Promoted from an exploratory same-snapshot sweep for workflow review.",
    "This note records the selection rationale; it is not statistical validation."
  )
)

summary(promoted)
```

    ledgr Backtest Summary
    ======================

    Performance Metrics:
      Total Return:        2.25%
      Annualized Return:   4.48%
      Max Drawdown:        -0.64%

    Risk Metrics:
      Risk-Free Rate:      0.00% annual
      Annualization:       252 periods/year (US equity daily)
      Volatility (annual): 1.42%
      Sharpe Ratio:        3.084

    Trade Statistics:
      Total Trades:        3
      Win Rate:            100.00%
      Avg Trade:           $75.05

    Exposure:
      Time in Market:      63.57%

The promoted run is now a committed run with its own run ID. The
selection note travels with the run.

Same-snapshot promotion is useful for audit, debugging, and durable
storage of the chosen candidate. It remains in-sample.

## Reopen The Artifact

The payoff for the project store is that you can come back later without
re-running the strategy.

``` r
close(single_run)
close(promoted)
ledgr_snapshot_close(snapshot)

snapshot <- ledgr_snapshot_load(
  store_path,
  snapshot_id = "demo_2019_h1",
  verify = TRUE
)

ledgr_run_list(snapshot)
```

    # ledgr run list
    # A tibble: 2 × 8
      run_id label tags  status final_equity total_return execution_mode reproducibility_level
      <chr>  <chr> <lgl> <chr>         <dbl> <chr>        <chr>          <chr>                
    1 workf… <NA>  NA    DONE         10107. +1.1%        audit_log      tier_1               
    2 workf… <NA>  NA    DONE         10225. +2.3%        audit_log      tier_1               

    # i Full identity and telemetry columns remain available on this tibble.
    # i Inspect one run with ledgr_run_info(snapshot, run_id).

``` r
info <- ledgr_run_info(snapshot, "workflow_promoted_candidate")
info
```

    ledgr Run Info
    ==============

    Run ID:          workflow_promoted_candidate
    Label:           NA
    Status:          DONE
    Archived:        FALSE
    Tags:            NA
    Snapshot:        demo_2019_h1
    Snapshot Hash:   6eeff5ca520c516a61e0228c5ac06d22548c9d74e4e98d1e9f71fccdd2b8a87e
    Config Hash:     fb6661ae72fdf430c49bcede949daf4f13ec62c06e45ceace708cbd19f470538
    Strategy Hash:   ca593cc1c3490b0ee6e80ef46b1daa2ebffc75eb73a4cc27c37dd05f9f6c5832
    Params Hash:     50fe1adcd9c5bc4ac19ed187e5c91bd9ae929ee26ddbb816038e09287d255d56
    Reproducibility: tier_1
    Execution Mode:  audit_log
    Elapsed Sec:     1.49
    Persist Features:TRUE
    Cache Hits:      0
    Cache Misses:    4

``` r
reopened <- ledgr_run_open(snapshot, "workflow_promoted_candidate")
summary(reopened)
```

    ledgr Backtest Summary
    ======================

    Performance Metrics:
      Total Return:        2.25%
      Annualized Return:   4.48%
      Max Drawdown:        -0.64%

    Risk Metrics:
      Risk-Free Rate:      0.00% annual
      Annualization:       252 periods/year (US equity daily)
      Volatility (annual): 1.42%
      Sharpe Ratio:        3.084

    Trade Statistics:
      Total Trades:        3
      Win Rate:            100.00%
      Avg Trade:           $75.05

    Exposure:
      Time in Market:      63.57%

Reopening turns the workflow from a temporary R session into a durable
research artifact.

You can also recover the selection context and strategy provenance
behind the promoted run. Today that recovery uses two public surfaces:

- `ledgr_run_info()` and `ledgr_run_open()` for the stored run;
- `ledgr_extract_strategy()` for strategy source and parameter
  provenance.

> [!WARNING]
>
> ### API gap
>
> The next few lines are intentionally lower-level. They show what ledgr
> already records today. The v0.1.8.6 cycle plans a helper that
> summarizes a promoted run’s “what caused this result?” record without
> asking users to inspect nested promotion-context fields directly.

``` r
promotion <- info$promotion_context
list(
  source = promotion$source,
  selected_candidate = promotion$selected_candidate$run_id,
  strategy_params_json = promotion$selected_candidate$params_json,
  feature_params_json = promotion$selected_candidate$feature_params_json
)
```

    $source
    [1] "ledgr_promote"

    $selected_candidate
    [1] "feature_403538546350/strategy_50fe1adcd9c5"

    $strategy_params_json
    [1] "{\"qty\":10,\"threshold\":0.01}"

    $feature_params_json
    [1] "{\"fast_n\":5,\"slow_n\":20}"

``` r
extracted <- ledgr_extract_strategy(
  snapshot,
  "workflow_promoted_candidate",
  trust = FALSE
)

extracted$strategy_params
```

    $qty
    [1] 10

    $threshold
    [1] 0.01

``` r
extracted$reproducibility_level
```

    [1] "tier_1"

``` r
extracted$hash_verified
```

    [1] TRUE

The result is compact but load-bearing: ledgr stores which sweep
candidate was selected, which strategy parameters and feature parameters
produced it, what note justified the promotion, and which strategy
source metadata was captured.

> [!NOTE]
>
> ### What recovery means
>
> Recovery is provenance, not magic. Tier 1 strategy source can usually
> be inspected, hash-checked, and optionally evaluated with
> `trust = TRUE`. Tier 2 strategies may depend on external functions or
> package state, so ledgr records the source text, hashes, parameters,
> dependency metadata, and warnings that explain what was captured and
> what remains outside the run artifact.

## What Promotion Does Not Prove

You now have a promoted candidate. What does it mean?

It means you can reopen the exact evidence trail: the sealed data,
feature declarations, parameter values, run identity, candidate row, and
promotion note. It does not mean the strategy will generalize.

A single-window sweep is exploratory evidence with an audit trail. Naive
sweep-and-pick selection is a selection-bias risk because every
candidate was compared on the same evidence window. Picking the highest
metric from that window can overfit the sample even when every
individual run was deterministic and leakage-safe at the pulse boundary.

The more candidates you try, the more opportunity you create for
sample-specific luck to look like skill.

<div class="ledgr-diagram ledgr-validation-diagram">

``` mermaid
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 18, "rankSpacing": 22, "curve": "linear"}, "themeVariables": {"fontFamily": "system-ui, -apple-system, Segoe UI, sans-serif", "fontSize": "15px", "primaryColor": "#f8fafc", "primaryTextColor": "#1f2937", "primaryBorderColor": "#64748b", "lineColor": "#64748b", "secondaryColor": "#eef2ff", "secondaryTextColor": "#1f2937", "secondaryBorderColor": "#64748b", "tertiaryColor": "#fff7ed", "tertiaryTextColor": "#1f2937", "tertiaryBorderColor": "#fb923c"}}}%%

flowchart TB
  window["Same evidence window<br/>Candidate 1<br/>Candidate 2<br/>Candidate 3<br/>Candidate ..."]
  pick["Pick highest metric"]
  caveat["Selection recorded<br/>not validated"]

  window --> pick --> caveat
```

</div>

Use the promotion note to record the human choice. Treat walk-forward
and out-of-sample evaluation as the next conceptual layer when the
question becomes selection quality rather than artifact reproducibility.

> [!TIP]
>
> ### Try it
>
> Write one sentence explaining why you promoted the candidate and one
> sentence explaining why that promotion is not validation. If the
> second sentence feels hard to write, the selection rule probably needs
> more work.

## Write The Human Research Note

Do not leave the reasoning only in your head. Write a short report next
to the stored artifacts. A compact report should include:

- hypothesis and data window
- snapshot hash and data-source assumptions
- feature and strategy declarations
- candidate grid summary
- candidate ranking rule
- top-N candidate table
- issue and failure review
- equity and drawdown plots
- promotion note
- reason for rejecting alternatives
- selection caveat: promoted candidate is not statistically validated by
  promotion itself

Here is the shape of a useful entry:

``` text
Hypothesis and data window:
  SMA crossover candidates may capture persistent moves in DEMO_01 and DEMO_02
  over the 2019 H1 demo window.

Promotion note:
  Promoted the top Sharpe candidate after checking that all candidate rows
  completed and no issue rows changed the interpretation.

Selection caveat:
  This is a same-window exploratory selection. Promotion records the chosen
  candidate and its provenance; it does not prove out-of-sample performance.
```

The report is where the human reasoning lives. ledgr records what
happened, which inputs were used, and which candidate was promoted; it
does not certify that the selection protocol was statistically sound.

## Next Layer: Walk-Forward Evaluation

The workflow above teaches the single-window foundation. Walk-forward
and out-of-sample evaluation are the planned next conceptual layer for
separating candidate selection from held-out evidence.

When you ask “is this candidate’s evidence reproducible?”, the workflow
above is the right starting point. When you ask “does this strategy
generalize?”, walk-forward is the next question you want. That layer is
not part of this article; the public roadmap places walk-forward
evaluation at v0.1.9.x.

This v0.1.8.5 article should not imply that promotion alone validates a
strategy.

## Where Next

- For full strategy-authoring patterns, use
  `vignette("strategy-development", package = "ledgr")`.
- For feature maps, indicator identity, and active aliases, use
  `vignette("indicators", package = "ledgr")`.
- For sweep mechanics, failure rows, seeds, and promotion context, use
  `vignette("sweeps", package = "ledgr")`.
- For durable stores, run discovery, archive state, and reopening, use
  `vignette("experiment-store", package = "ledgr")`.
