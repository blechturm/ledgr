# ledgr v0.1.7.3 Spec

**Status:** Draft
**Target Version:** v0.1.7.3
**Scope:** accounting correctness, metric explainability, and documentation discoverability
**Inputs:**

- `inst/design/ledgr_v0_1_7_3_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_7_3_spec_packet/categorized_feedback.yml`
- `inst/design/contracts.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/ledgr_design_philosophy.md`
- `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.2/`

---

## 1. Purpose

v0.1.7.3 is a correctness and explainability release.

The release must make ledgr's reported accounting state auditable from public
result tables. Every summary number that ledgr prints must have a documented
definition and an independent regression oracle that can be recomputed from
fills, trades, equity rows, and opening capital without relying on the metric
implementation under test.

The release also strengthens documentation discovery for headless users and
agents. A user who starts from `?ledgr_run`, `?ledgr_experiment`,
`?ledgr_backtest`, package help, or installed vignettes must be able to find the
right teaching article without using a browser or reading the README first.

---

## 2. Release Shape

v0.1.7.3 has four coordinated tracks.

### Track A - Accounting Correctness

Treat event-sourced ledger events as the accounting oracle. Fix the confirmed
Episode 013 defect where fills and trades show a closed position but the final
equity row reports an open position and inflated total return.

The release must verify that cash, positions, equity, and summary metrics agree
with ledger fills across small deterministic scenarios.

### Track B - Metric Definitions And Independent Oracles

Define each public metric ledgr prints or compares. Add tests that recompute
those metrics from public result tables with straightforward R code rather than
calling ledgr's metric internals.

The goal is not merely to make tests pass. The goal is to make every displayed
number explainable to a user who inspects the raw tables.

### Track C - Documentation Discoverability And Reading Order

Make installed docs discoverable from function-level help and package-level
help. Rework pkgdown organization so article order communicates the intended
learning path.

This is a different fix from README-level discovery. README links are useful,
but agents and headless users often start from help pages, not from GitHub.

### Track D - Vignette And Concept Alignment

Review the existing vignettes against the north star:

```text
teach the economic/accounting story first,
then show the R mechanics,
then show how to inspect and verify the result.
```

Add or revise concept material where the current docs do not explain fills,
trades, equity curves, metrics, helper composition, or feature-ID behavior.
Indicator documentation must be consolidated around a single installed
`indicators` vignette rather than preserving separate installed teaching paths
for built-in indicators and TTR-backed indicators.

---

## 3. Hard Requirements

### R1 - The Ledger Is The Accounting Oracle

The final public accounting state must be derivable from ledger events:

- final positions are cumulative fill deltas by instrument;
- final cash is opening cash minus buy cash flows plus sell cash flows minus
  fees;
- final `positions_value` is final position quantity times the valuation price
  used for the equity row;
- final equity is `cash + positions_value`;
- metrics derived from equity must use the same equity rows returned by public
  result accessors.

If any persisted table disagrees with the ledger for a completed run, that is a
correctness defect, not a documentation gap.

### R2 - Equity Rows Must Be Written At A Coherent Fill Boundary

The runner must not write an equity row from a mixture of pre-fill and post-fill
state. For a pulse where fills occur, cash, positions, and positions value must
all reflect the same lifecycle point.

The Episode 013 regression must pass in every supported execution mode that can
write an equity curve.

### R3 - Public Metrics Must Have Definitions

The help page for the summary command and any metric/comparison entry point must
define every metric it displays:

- total return;
- annualized return;
- max drawdown;
- annualized volatility;
- total trades / `n_trades`;
- win rate;
- average trade;
- time in market.

Definitions must state whether the metric uses fills, closed trades, equity
rows, opening capital, or timestamps.

### R4 - Metrics Must Have Independent Test Oracles

Regression tests for public metrics must recompute expected values from public
tables. Tests must not use the same internal metric function to define both the
actual and expected result.

Acceptable oracle inputs:

- `ledgr_results(bt, what = "fills")`;
- `ledgr_results(bt, what = "trades")`;
- `ledgr_results(bt, what = "equity")`;
- opening cash/equity from the run setup;
- documented constants such as annualization factors.

### R5 - Fills And Trades Semantics Must Stay Explicit

`fills` are execution events. `trades` are closed trade rows. `n_trades` counts
closed trade rows, not fill rows.

Open-only runs, flat runs, and final-bar no-fill runs must remain valid states,
but docs and tests must make those states understandable:

- zero closed trades can be correct;
- `win_rate = NA` is correct when there are no closed trades;
- open positions can affect equity without appearing as closed trades;
- final-bar target changes under next-open fill can warn without producing a
  fill.

### R6 - Documentation Must Be Discoverable From Help Pages

Core help pages must point to the relevant installed articles. At minimum:

- `ledgr_run()`;
- `ledgr_experiment()`;
- `ledgr_backtest()`;
- `ledgr_results()`;
- `ledgr_compare_runs()`;
- `ledgr_snapshot_from_df()` / snapshot creation entry points;
- `ledgr_feature_id()`, `ledgr_ind_returns()`, and `ledgr_ind_ttr()`;
- `signal_return()`, `select_top_n()`, `weight_equal()`, and
  `target_rebalance()`.

Each entry point should include either `@seealso` or an `@section Articles:`
block with both interactive and noninteractive discovery forms, for example:

```r
vignette("strategy-development", package = "ledgr")
system.file("doc", "strategy-development.html", package = "ledgr")
```

### R7 - Package-Level Help Must Provide A Documentation Spine

`?ledgr` / `?ledgr-package` must include a compact "Start here" section naming
the installed vignettes and giving browser-free lookup commands:

```r
vignette(package = "ledgr")
system.file("doc", package = "ledgr")
system.file("doc", "strategy-development.html", package = "ledgr")
system.file("doc", "experiment-store.html", package = "ledgr")
system.file("doc", "metrics-and-accounting.html", package = "ledgr")
system.file("doc", "indicators.html", package = "ledgr")
```

If R7 is implemented before D1, the metrics-and-accounting path must be added
as part of D1 before the release gate closes.

If the `indicators` vignette is implemented after the package help spine, the
`indicators.html` path must be added before the release gate closes.

### R8 - Helper Composition Semantics Must Be Documented

The helper pipeline must have a compact contract in help or vignette form:

```text
signal -> selection -> weights -> target quantities -> existing execution path
```

The docs must state what each stage accepts and returns, what metadata is
preserved, and where execution semantics begin. `target_rebalance()` must
document that share quantities are floored to whole numbers.

### R9 - Feature And Indicator Output Discovery Must Improve

The Episode 006 BBands/MACD findings must be reviewed before ticket finalization.
The release should make multi-output TTR indicator behavior and exact feature ID
strings easier to discover.

At minimum, examples that rely on feature IDs must show
`ledgr_feature_id()` before using the ID in `ctx$feature()` or helper code.

The release must also remove the redundant installed-documentation split between
general indicator concepts and TTR-specific examples. Built-in ledgr indicators
and TTR-backed indicators should be taught in one installed indicators vignette.
TTR-specific output-column and warmup details should remain discoverable from
function help, especially `?ledgr_ind_ttr`.

### R10 - Pkgdown Must Imply Reading Order

The pkgdown article structure must make the intended path visible. The preferred
shape is section ordering plus "what to read next" links rather than only
filename numbering.

The site should distinguish:

- start-here tutorials;
- core concepts;
- research workflow articles;
- reference/design materials.

### R11 - Vignettes Must Match The North Star

Before the release gate, review installed and pkgdown-only vignettes for:

- economic/accounting story before API syntax;
- runnable examples using demo data where appropriate;
- no unexplained cleanup ceremony;
- explicit target/fill/trade/metric distinctions;
- explicit feature-ID and warmup behavior where indicators appear;
- headless/offline discoverability;
- clear next-reading links.

---

## 4. Track A Scope - Accounting Correctness

### A1 - Episode 013 Regression

Create a focused regression from
`2026-05-02_013_trades_fills_and_metrics/reproducible_script.R`.

The fixture must assert:

- fills contain BUY 1 and SELL 1 for the same instrument;
- trades contain one closed trade with realized P&L of 1;
- cumulative fill deltas imply final position zero;
- final equity row has zero `positions_value` for that instrument state;
- final equity and total return do not include an unfilled open position.

Run this fixture in every supported execution mode that can write an equity
curve, including standard mode and audit-log mode.

### A2 - Deterministic Accounting Fixtures

Add small hand-checkable scenarios:

- flat strategy / no fills;
- buy 1 and remain open;
- buy 1 and sell 1 at a profit;
- buy 1 and sell 1 at a loss;
- multi-instrument closed positions;
- final-bar no-fill;
- fee-bearing trade if fees are in public scope;
- helper target with fractional allocation floored to whole shares.

Each fixture must specify expected fills, trades, final cash, final positions,
final positions value, final equity, and relevant metrics.

### A3 - Derived-State Cross-Check

Use `R/derived-state.R` reconstruction as an oracle where appropriate, but do
not rely only on internal reconstruction. At least one test layer must recompute
from public result tables in test code.

If derived state and persisted equity differ, the test should identify which
table is inconsistent with fills.

---

## 5. Track B Scope - Metric Definitions And Oracles

### B1 - Metric Definition Table

Add a canonical metric definition table to `contracts.md` and user-facing help.

The table should include:

| metric | source table | definition |
| --- | --- | --- |
| total return | equity | final equity / initial capital - 1 |
| annualized return | equity | documented annualization over run duration |
| max drawdown | equity | maximum peak-to-trough decline, for example `min(equity / cummax(equity)) - 1` |
| annualized volatility | equity returns | documented annualization of equity returns |
| total trades | trades | number of closed trade rows |
| win rate | trades | share of closed trades with positive realized P&L, `NA` when none |
| average trade | trades | mean realized P&L over closed trades, `NA` when none |
| time in market | equity | share of equity timestamps with non-zero positions value |

The exact definitions may change during implementation if the current code uses
different intended semantics, but the final docs and tests must agree.

`initial capital` must be defined by the implementation and tests as one stable
quantity, such as opening cash/equity from the run setup or the first equity row
if that is the intended public contract. The spec must not leave this ambiguous
at ticket time.

The first Track B implementation ticket must resolve this definition before any
total-return oracle tests are written.

### B2 - Summary Help

The help page for the summary method must define displayed metrics and state the
return value of `summary(bt)`.

If `summary(bt)` continues returning the original backtest object invisibly,
document that. If it changes to a summary object, document and test the new
contract.

### B3 - Public Result Table Semantics

Update `ledgr_results()` docs to clarify:

- fills versus trades;
- open-only positions;
- zero-row schemas;
- realized P&L meaning;
- `side`, `qty`, and `action` expectations for ordinary open/close cases.

Partial close semantics should be documented only if the code fully supports
and tests them.

---

## 6. Track C Scope - Discoverability And Pkgdown

### C1 - Function-Level Article Links

Add article references to major help pages. The links must name the problem the
article solves, not just list titles.

Examples:

```text
Writing strategies and understanding pulses:
  vignette("strategy-development", package = "ledgr")

Inspecting durable runs and experiment stores:
  vignette("experiment-store", package = "ledgr")

Accounting, fills, trades, and metrics:
  vignette("metrics-and-accounting", package = "ledgr")

Indicators, feature IDs, and warmup:
  vignette("indicators", package = "ledgr")
```

### C2 - Pkgdown Article Structure

Update `_pkgdown.yml` so articles imply a reading order:

```text
Start Here
  Getting Started [installed]
  Strategy Development And Comparison [installed]
  Experiment Store [installed]

Core Concepts
  Accounting, Fills, Trades, And Metrics [installed]
  Indicators And Feature IDs [installed]
  Strategy Context And Pulses [installed or section in Strategy Development]

Research Workflow
  Who ledgr is for [pkgdown-only]
  Research to Production [pkgdown-only]
  Why R [pkgdown-only]

Reference And Design
  Contracts [requires pkgdown/design-reference decision]
  Release CI Playbook [requires pkgdown/design-reference decision]
  Design packets [requires pkgdown/design-reference decision]
```

The exact names can change. The site must make the intended order explicit.
Pkgdown-only positioning articles must remain under `vignettes/articles/` and
must not become installed vignettes unless the documentation contract is changed
deliberately.

The Reference And Design section is aspirational unless the release explicitly
chooses how pkgdown should link to `inst/design/` materials. Do not copy design
files into installed vignettes just to satisfy this outline.

---

## 7. Track D Scope - Vignettes And Concepts

### D1 - Metrics And Accounting Vignette

Add an installed vignette. The recommended title is `metrics-and-accounting`.

It should teach:

- ledger events as the accounting source of truth;
- fills versus trades;
- equity curve construction;
- how summary metrics are derived;
- how to recompute key metrics manually with ordinary R/dplyr;
- why open positions and closed trades can differ;
- how final-bar no-fill and zero-trade runs should be interpreted.

Function-level help links to this vignette must be added only after the article
exists and is installed. Do not add stale `vignette("metrics-and-accounting",
package = "ledgr")` references before the vignette is present.

### D2 - Existing Vignette Review

Review:

- `getting-started`;
- `strategy-development`;
- `experiment-store`;
- current indicator/TTR documentation;
- pkgdown-only background articles under `vignettes/articles/`.

For each, decide whether it:

- fits the ledgr north star;
- explains the "why" before the "how";
- uses current terminology;
- has a clear next-reading link;
- avoids stale version references and hidden assumptions;
- avoids brittle shell examples when code contains `$` or multi-line strategy
  definitions; prefer `.R` script snippets for Windows-facing examples;
- aligns `ledgr_signal_strategy()` help and examples with the actual function
  signature and the broader `function(ctx, params)` strategy convention.

### D3 - Feature/Indicator Concept Coverage

After reviewing episode 006, create an installed `indicators` vignette, or
rename/refactor the existing TTR material into that role, covering:

- exact feature IDs;
- `ledgr_feature_id()`;
- built-in ledgr indicators and TTR-backed indicators under one mental model;
- multi-output TTR indicators;
- warmup `NA` as the general indicator contract;
- helper feature registration boundaries.

The current `ttr-indicators` vignette should not remain as a parallel installed
teaching article once `indicators` exists. Fold reusable teaching material into
the general indicators vignette and move TTR-specific reference facts into
function help. Retiring or deleting `ttr-indicators` requires matching updates
to package help, function-level article links, pkgdown navigation, contracts,
and documentation tests.

---

## 8. Non-Goals

v0.1.7.3 must not expand ledgr's execution model while fixing accounting and
docs:

- no sweep/tune implementation;
- no short-selling or margin semantics;
- no new broker/fill model beyond what is needed to fix correctness;
- no new exported documentation helper such as `ledgr_docs()` in this cycle;
  reconsider only if function-level and package-level help still fail a later
  discovery audit;
- no exported feature-map API in this cycle; `ledgr_feature_map()`,
  `ctx$features()`, and `passed_warmup()` remain design proposals;
- no second strategy execution path;
- no silent treatment of missing targets as zero;
- no broad rewrite of result storage unless required by the confirmed equity
  defect.

---

## 9. Release Gate

The release is not ready until:

- Episode 013 has a failing-then-passing regression test;
- deterministic accounting fixtures pass;
- summary and comparison metrics are independently recomputed in tests;
- metric definitions appear in contracts and user-facing help;
- episode 006 raw findings have been reviewed, and any confirmed feature/TTR
  docs or defects are either addressed or explicitly deferred;
- `metrics-and-accounting` exists as an installed vignette before help pages
  link to it;
- `indicators` is the installed indicator teaching vignette, and
  `ttr-indicators` is not left as a redundant installed teaching article unless
  the documentation contract explicitly says why;
- function-level help pages point to installed articles;
- pkgdown article order reflects the intended reading path;
- vignettes have been reviewed against the north star;
- full Windows and Ubuntu/WSL checks pass using the release CI playbook.

The final release checklist must include the Ubuntu parity lessons from
`inst/design/release_ci_playbook.md` so the tag is moved only after remote CI is
green on the target commit.
