# External yardstick brief (ChatGPT Deep Research)

Written 2026-10-09 for the point-in-time universe audit
([charter](charter.md), Stage 3). The maintainer runs the prompt below in
ChatGPT Deep Research and commits the result unedited as `yardstick.md`. The
prompt deliberately says nothing about how ledgr behaves, so the yardstick
does not mirror ledgr's vocabulary or choices.

````text
I am auditing a backtesting engine and need an independent, source-backed
yardstick for CAUSAL POINT-IN-TIME BACKTESTING OF DAILY EQUITY STRATEGIES OVER
HISTORICAL INDEX-MEMBERSHIP UNIVERSES (for example, the historical
constituents of the S&P 500 since 1998, from a vendor such as Sharadar,
CRSP/Compustat or Norgate). Do not evaluate any particular engine. Produce the
standard an engine should be measured against.

Context, so you can separate responsibilities:
- A data-preparation layer (adapter) turns vendor data into sealed,
  versioned inputs: daily bars, trading sessions, index membership over time,
  listing lifetimes and terminal events, trading status, corporate actions and
  identifiers.
- The engine consumes those sealed inputs and runs a strategy day by day:
  which instruments it may see and trade, prices and valuation, order
  execution, accounting, corporate-action and delisting handling, results,
  resumption after interruption, and walk-forward evaluation.
- The research layer owns the strategy and the universe definition.
A prior study already compared HOW frameworks split ownership of universe
construction (QuantConnect LEAN, Zipline, Qlib, Backtrader, vectorbt,
quantstrat, Feast/Delta Lake/lakeFS/MLflow patterns). Do not repeat that
comparison. Focus on WHAT must be true for results to be correct.

Use primary sources wherever possible: peer-reviewed finance literature
(survivorship bias, delisting returns, look-ahead and data-snooping biases,
index-reconstitution effects), data-vendor documentation (CRSP delisting codes
and delisting returns, Compustat point-in-time, Sharadar SEP/ACTIONS/SP500
tables, Norgate), index-provider methodology (S&P Dow Jones Indices:
announcement versus effective dates), exchange rules (halts, suspensions,
delisting procedures), and the documentation of serious backtesting
platforms. Cite every claim. Say where evidence is weak or sources disagree.

Cover at least these areas:
1. Universe membership: announcement time versus effective time; knowledge
   time and later corrections (bitemporal facts); survivorship-free history;
   what the strategy may know on a decision date.
2. Listing lifetimes and terminal events: delistings, cash and stock mergers,
   bankruptcies, liquidations; delisting returns; positions held through a
   terminal event; what to do when settlement terms are unknown.
3. Corporate actions: splits, cash and stock dividends, spin-offs, rights,
   identifier and ticker changes; adjusted versus unadjusted prices; total
   return; how positions, cost basis and cash change.
4. Missing, stale and untraded prices: gaps in vendor bars, zero-volume
   carried prices, halts and suspensions; valuation with stale marks; when a
   position cannot be valued or traded.
5. Calendars and timestamps: trading sessions and holidays, time zones,
   timestamps of daily bars, when a decision is made versus when it executes.
6. Execution timing and look-ahead: next-open versus same-close fills, using
   only information available at decision time, sizing with unavailable
   prices, rebalancing members that cannot trade.
7. Indicators and history on a changing universe: warm-up for new listings
   and re-entrants, gaps inside an indicator window, readiness, history
   before an instrument joins the universe.
8. Evaluation: walk-forward and out-of-sample splits that respect time order;
   state carried between evaluation windows; parameter selection without
   look-ahead.
9. Reproducibility and audit: data vintages and restatements, pinned
   inputs, identity of a run, explaining a result after the fact,
   resumption after interruption without changing results.

Output, in this order:
A. A guarantee table. One row per guarantee, each phrased so that it can be
   tested. Columns: ID; guarantee; area (1 to 9); owner (data layer, engine,
   or research layer); class (universal correctness requirement, or optional
   capability); failure mode and bias if it is missing, with any published
   evidence of its size; how serious platforms or data products meet it;
   sources.
B. A catalogue of concrete test scenarios that would expose a violation of
   each universal guarantee on a small synthetic daily-equity dataset (for
   example: a member added with a known announcement date; a held stock that
   delists for cash; a two-day halt; a split while held). Reference the
   guarantee IDs each scenario tests.
C. Common failure modes in practice, ranked by documented impact, with
   sources.
D. Open questions where there is no consensus, with the competing positions.

Keep correctness gaps (results are wrong or biased) separate from capability
gaps (a feature is unavailable but results are not wrong). Prefer daily US
equities; note briefly where other markets or intraday data change a
guarantee.
````
