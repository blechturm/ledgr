# Design Philosophy: From Research to Production


ledgr is built around one design premise: strategies should use the same
contract across backtest, paper, and live modes. Not a translation of
research code into production code. Not a reimplementation. The same
strategy function, the same logic, the same event-sourced ledger model.

This article explains the arc ledgr is designed to cover, how the
event-sourced model enables it, and where v0.1.x sits on that path.

## The Arc

<div class="ledgr-diagram ledgr-research-production-arc">

``` mermaid

flowchart LR
  research["research"]
  paper["paper trading"]
  live["live trading"]

  research --> paper --> live
```

</div>

Most backtesting libraries stop at the first arrow. The strategy exits
the research environment as a CSV of returns and is re-implemented in a
production system that has nothing to do with the backtest. The results
differ. The bugs differ. The audit trail is gone.

ledgr is designed so that the strategy that produced the backtested
results uses the same contract in production. The event-sourced ledger
is what makes that continuity possible.

## The Ledger Is The Bridge

In ledgr, results are never computed directly from price arrays. Every
decision – a target position, a fill, a cash change – is recorded as an
immutable event. Equity, trades, and metrics are derived from that
ledger after the fact.

<div class="ledgr-diagram ledgr-ledger-bridge">

``` mermaid

flowchart LR
  data["data"]
  snapshot["sealed snapshot"]
  pulses["pulses"]
  ledger["event ledger"]
  results["results"]

  data --> snapshot --> pulses --> ledger --> results
```

</div>

This is not just a correctness choice. It is an architectural choice
that makes the research-to-production arc coherent. Backtest and paper
fills share the same ledger event schema, so the reconstruction logic,
result views, and audit trail work identically across both modes. Live
trading extends the event stream with broker lifecycle events –
submissions, acknowledgments, partial fills, rejections – without
changing the strategy contract. Safety gates, reconciliation, and
operational controls are adapter concerns; the strategy itself does not
change.

## The Experiment Store

Before a strategy is deployed it needs to be validated – not just
against one parameter set on one data slice, but across many
combinations and market regimes, with full provenance.

The ledgr experiment store makes this durable. A **sealed snapshot**
pins the market data permanently. A **`run_id`** is an immutable
experiment key. Strategy identity is captured from source text and
parameters. Every run is auditable and discoverable after the R session
ends.

This is a concrete user-facing workflow:

``` r
snapshot <- ledgr_snapshot_open(db_path, "snapshot_id")

runs <- ledgr_run_list(snapshot)

info <- ledgr_run_info(snapshot, "sma_20_production_candidate")

bt <- ledgr_run_open(snapshot, "sma_20_production_candidate")
ledgr_results(bt, what = "equity")

snapshot <- snapshot |>
  ledgr_run_label("sma_20_production_candidate", "approved-baseline") |>
  ledgr_run_archive("discarded-parameter-test", reason = "bad regime fit")
```

`run_id` is the immutable experiment key. `label`, tags, and archive
state are mutable metadata only; they do not change the snapshot hash,
strategy source hash, strategy parameter hash, config hash, or ledger
artifacts. Older runs created before provenance capture remain
inspectable as legacy/pre-provenance runs, but they cannot be upgraded
into fully reproducible experiments after the fact.

The research workflow before deployment has two phases:

**Commit**. Full provenance run. Validate named candidates with durable
artifacts: sealed snapshot hash, strategy source hash, parameter hash,
config hash, ledgr and R version, dependency versions, compact
telemetry, and result artifacts. Use `ledgr_run_compare()` to compare
named variants and `ledgr_run_strategy()` to inspect stored strategy
source.

**Explore**. Fast parameter sweep mode builds on the same experiment
object and parity contracts. Use sweep mode to evaluate parameter-grid
candidates without committing each candidate as a durable run, then
promote a selected candidate when it should become an auditable stored
run.

## The Edge Device

DuckDB runs anywhere R runs, including ARM edge hardware such as a
Raspberry Pi or a small cloud VPS. A validated strategy can be deployed
to an edge device with an R instance, a DuckDB experiment store, and a
broker adapter.

The device maintains its own ledger, appending live fills to the same
schema the backtest used. If the device restarts,
`ledgr_state_reconstruct()` rebuilds current positions and cash from the
ledger events. No in-memory state is trusted across restarts. The ledger
reconstructs ledgr’s expected state. In paper and live modes, that
expected state must still be reconciled against broker-reported orders,
positions, cash, and fills before trading resumes.

This makes the deployment target simpler than traditional production
systems. There is no separate database, no separate execution engine, no
translation layer. R, DuckDB, and a broker adapter are sufficient for
systematic EOD and low-frequency intraday strategies.

## The Strategy Contract

The sweep-to-production path works cleanly for strategies written as
self-contained `function(ctx, params)` functions with explicit,
JSON-safe parameters and no hidden mutable state:

``` r
sma_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    values <- c(sma = ctx$feature(id, paste0("ttr_sma_", params$window)))
    if (ledgr_passed_warmup(values) && ctx$close(id) > values[["sma"]]) {
      targets[id] <- params$quantity
    }
  }
  targets
}
```

This is Tier 1 reproducibility: the strategy is fully self-contained,
its parameters are hashable, and its source is capturable. Tier 1
strategies earn full experiment-store identity – source hash, parameter
hash, provenance metadata – and are the natural fit for sweep mode and
edge deployment.

ledgr supports less constrained strategies too, but the reproducibility
tier is always visible in run provenance. The trust boundary is
explicit, not hidden.

## Cost And Timing Are Explicit

Production-shaped research needs execution assumptions that are visible
at the run boundary. In v0.1.9.1, ledgr makes timing and transaction
costs explicit parts of experiment construction:

``` r
experiment <- ledgr_experiment(
  snapshot,
  strategy = sma_strategy,
  params = list(window = 20, quantity = 10),
  timing_model = ledgr_timing_next_open(),
  cost_model = ledgr_cost_chain(
    ledgr_cost_spread_bps(5),
    ledgr_cost_fixed_fee(1)
  )
)
```

Use `ledgr_cost_zero()` when a zero-cost baseline is intentional. That
choice is still recorded as a cost model, with its own `cost_model_hash`
and `cost_plan_json`, so a no-cost run is not confused with an
omitted-cost run.

`ledgr_cost_spread_bps()` uses a quoted-spread convention: the
configured basis points describe the full quoted spread, and ledgr
applies half of that spread to each side of the trade. A buy pays above
the execution-bar open; a sell receives below it. Fixed and notional
fees add explicit costs without changing quantity, side, instrument, or
execution timestamp.

## What v0.1.x Delivers Today

v0.1.x is the correctness-first research layer. It already covers:

- sealed snapshots, hash verification, and deterministic replay across
  machines and R sessions;
- project-local DuckDB stores with run discovery, labels, tags,
  archival, comparison, reopening, and strategy-source inspection;
- deterministic pulse execution with no-lookahead `ctx`, full target
  holdings, next-open fills, final-bar no-fill warnings, and an
  append-only ledger;
- accounting surfaces for ledger events, fills, trades, equity rows,
  summary metrics, and explicit metric contexts;
- built-in indicators, TTR-backed indicators, multi-output bundles,
  feature maps, warmup diagnostics, pulse inspection, and active
  aliases;
- feature and strategy grids, sweep execution, candidate rows, compact
  saved sweeps, retained return series, promotion context, and explicit
  selection-is-not-validation framing;
- public cost-model constructors, classed target-risk transforms,
  timing-model identity, required explicit costs, reproducibility tiers,
  strategy preflight, stored strategy source, and a deterministic demo
  dataset for documentation and examples.

The current research layer also includes the first walk-forward surface:

- v0.1.9.4 shipped walk-forward evaluation over the existing sweep and run
  surfaces, consuming cost identity, saved-sweep retention infrastructure,
  and risk-chain identity;
- the next planned validation-toolkit work may add DSR, PBO/CSCV over
  retained return panels, and deterministic candidate clustering;
- crypto-readiness evidence and target-construction helper extensions
  remain separate future packets.

The target-risk layer is intentionally narrow: it transforms target
quantities before timing and cost. It does not implement affordability
enforcement, liquidity/capacity policy, margin, shorting or borrow
policy, OMS lifecycle behavior, or broker-grade controls.

Paper and live trading adapters, OMS state machine semantics, and
observability tooling follow in the v0.2.x and v0.3.x range.

The path from a validated experiment-store entry to a running edge
device is shorter than it looks. The research work done in v0.1.x is not
throwaway scaffolding – it is the foundation the production system
builds on.
