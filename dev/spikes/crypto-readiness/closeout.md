# Spot-crypto readiness spike: closeout

**Verdict: green.** Each stage's kill condition did not fire:
- **Stage 0:** fractional quantities and a 24/7 clock needed no production
  change.
- **Stage 1:** crypto2 supplies past rank snapshots and the price history of
  coins that later died, within polite rate limits.
- **Stage 2:** existing lifetime facts declare a held coin's death or migration,
  and no honest run was forced INCOMPLETE.

The package was `v0.2.2` at `c6374bb2`, unchanged. Maintainer decision
(2026-10-25): crypto support lands in v0.2.2, before the first CRAN release.

## What ran

| Stage | Files | Commit |
| --- | --- | --- |
| 0, prerequisite (synthetic BTC/USD, ETH/USD, 120 days, 24/7, a 4-day outage) | `probe.R`, `probe_findings.md` | `6c79dad0` |
| 1, crypto2 data (2022-2023, 212 top-100 coins) | `data_probe.R`, `data_probe_findings.md` | `d0876a9a` |
| 2, point-in-time top-100 survivorship (2020-2025, 484 coins, 748,494 bars) | `survivorship_probe.R`, `survivorship_findings.md`, `survivorship_evidence/` | `e45d7b48` |

Raw data stays outside the repository, under `E:/ledgr-data/crypto2/`.

## What was learned about the package

**Works today:**
- fractional quantities through fills, lots, trades, equity and durable reopen;
- a 7-day session calendar;
- membership snapshots with a one-day knowledge lag;
- lifetime `known_inactive` facts with a terminal event, which dispose of a
  held migrated coin under the research default;
- `ledgr_metric_crypto()` annualizing at 365.

**Defects and gaps to route:**
- **D1 (correctness, any fractional strategy).** A buy and sell that differ
  by about 1e-16 leave position dust. A later disposition opens a short lot
  and aborts the run as FAILED with `ledgr_lot_state_invariant`. The position
  vector and lot ledger need one dust rule. Maintainer: a correction ticket in
  the next cut, ahead of crypto work.
- **D2.** Ingest rounds prices to 8 decimals, so micro-priced tokens round to
  0 or lose precision. Workaround: re-quote in units of 10^k tokens.
- **D3.** `ledgr_target_rebalance()` floors to whole units. At crypto prices
  and small accounts it trades nothing, and says nothing. A quantity-step
  decision is needed.
- **D4.** With no metric context, a 365-session calendar is annualized at 252,
  and nothing says so.
- **D5.** The stale-mark default of 5 sessions was tuned on equities and
  should be re-tuned on crypto data.
- **D6 (minor).** The equity-centric label "Corporate actions: NOT SUPPLIED"
  appears on crypto runs.

## Data findings (crypto2 3.0.0)

- **Coverage:** daily rank snapshots back to 2013; dead coins keep their
  history.
- **Terms:** CMC and CoinGecko terms allow personal, non-commercial use only
  and forbid redistribution. So the deliverable is an **adapter** where users
  download the data themselves, not a hosted dataset.
- **Adapter duties:**
  - force UTC, because crypto2 reads times in local time and shifts days
    silently;
  - lag membership one day, because ranks use the same day's close;
  - key on CMC id, because symbols are not unique;
  - drop the duplicate rows from overlapping 400-day chunks;
  - check coverage and refetch, because failed chunks are swallowed;
  - map terminal labels from free-text `crypto_info()` notices;
  - re-quote prices (D2);
  - disclose ranked coins that have no history: 29 coins and 1,616 coin-days
    in 2020-2025, a survivorship hole no surface can close.

## Result (aggregate, private data, 2020-2025, 10 bps, cost included)

| Equal weight | CAGR | Sharpe | Max drawdown |
| --- | ---: | ---: | ---: |
| Point in time | 13.07% | 0.523 | -80.9% |
| Survivors only | 15.80% | 0.560 | -81.1% |

- **Survivorship bias:** 2.7 CAGR points a year. Dead coins leave the top 100 a
  median 1,289 days before they die, so the bias comes from holding coins in
  decline.
- **Min-variance** degenerates to stablecoins (CAGR -1.3%). A meaningful
  crypto minimum-variance test excludes pegged coins.

## What the spec may consume, and what remains open

**Consumable now:** the three findings files, the adapter duties above, and
defects D1-D6.

**Open:**
- the D1 fix;
- decisions on D2-D5;
- a terminal-outcome rule for abandoned coins, which stop at a positive stale
  price;
- the adapter's API shape;
- how a CRAN-safe article runs without network access: a pkgdown-only page or
  a cached extract that meets the terms.

**Next, per the maintainer's process rule:** write the crypto cut from these
measurements, have Codex review it, then implement.
