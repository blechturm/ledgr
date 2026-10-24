# Spot-crypto readiness: crypto2 data probe findings (Stage 1)

Run on 2026-10-24 against `6c79dad0` (ledgr 0.2.1.0, `pkgload::load_all()`),
crypto2 3.0.0 from CRAN (published 2026-10-08), R 4.6.1, host time zone
Europe/Vienna, probe run with `TZ=UTC`. No package code was changed. Runner:
`Rscript dev/spikes/crypto-readiness/data_probe.R <out_dir> <cache_dir> [lib_dir]`.
Raw downloads are cached as RDS under `<cache_dir>` (here
`E:/ledgr-data/crypto2/probe1/`); aggregate CSVs and `data_probe_log.txt` go
to `<out_dir>`. Neither is committed. Window: 2022-01-01..2023-12-31, top 100.

## Calls used

`crypto_list(only_active = FALSE, add_untracked = TRUE)`;
`crypto_listings(which = "historical", start_date, end_date, interval = "day",
limit = 100, quote = TRUE, sleep = 1)` per quarter;
`crypto_history(coin_list, start_date = "20220101", end_date = "20231231",
sleep = 1)` in batches of 20 coins; `crypto_info(coin_list, sleep = 1)`;
`crypto_global_quotes(which = "historical", quote = TRUE, interval = "daily")`;
raw endpoints via `crypto2:::construct_url()` for field inspection.

## Measured

- **Rank snapshots:** daily, all 730 days present, 97-100 rows a day (725
  days have ranks exactly 1..100; 5 days have rank holes, e.g. 2023-10-17
  lacks ranks 9, 15, 26). Columns: `cmc_rank`, `price`, `market_cap`,
  `circulating_supply`, `total_supply`, `max_supply`, `volume24h`,
  `date_added`, `last_updated` (crypto2 truncates it to a Date). Prices change
  day to day (0.43% of coin-days repeat, mostly stablecoins); 1.06 new
  entrants a day on average, max 7. Earliest snapshot: 2013-04-28 (7 coins).
- **Union:** 212 distinct CMC ids were ever in the top 100. Statuses today:
  204 active, 6 not active, 2 absent from `crypto_list()` entirely.
- **Coin statuses:** `crypto_list()` returns 8,121 active and 12,270 "inactive"
  coins and no untracked status. The raw CMC maps hold 1,770 inactive and
  10,500 untracked coins, both with `is_active = 0` and **no
  first/last_historical_data fields**. So dates exist only for active coins,
  and crypto2 cannot tell inactive from untracked. `crypto_info()` does: it
  reports all 6 non-active union coins as `untracked`.
- **Prices:** 210 of 212 coins returned bars; 143,966 bar rows after dedup.
  Missing: ARAW (1 day in the top 100, rank 99) and 1000SATS (17 days, best
  rank 45). Neither is in `crypto_list()` and both return no history.
- **CMC history endpoint ignores `timeStart`:** every call returns 400 daily
  points ending at `timeEnd` (a 3-day request returned 2021-04-06..2022-05-10).
  crypto2's 400-day chunks therefore overlap: 13,713 duplicate (id, date) rows
  on 2022-11-27..2023-02-04, all byte-identical. Dedup is safe; a two-year
  window costs 2 requests per coin.
- **Bar timestamps:** `timeOpen` D 00:00:00.000Z, `timeClose` and `timestamp`
  D 23:59:59.999Z for every row. crypto2 drops the milliseconds, so the bar is
  stamped D 23:59:59 and matches a 23:59:59 UTC session close directly.
- **Time-zone trap:** crypto2 parses these strings with
  `as.POSIXlt(format = "%Y-%m-%dT%H:%M:%S")` and no `tz`. Under the host zone
  Europe/Vienna the same bars came back at 21:59:59 UTC. The same expression
  under America/New_York gives 2022-05-09 03:59:59 UTC for the 2022-05-08 bar,
  a silent one-day shift. An adapter must run with `TZ=UTC` or re-stamp bars
  from the date.
- **Gaps:** 11 coins, 29 bar-days missing, clustered on 2022-07-28..31 (6-9
  coins) and 2022-09-30 (2 coins). 30 coins start after the window start; none
  enters the top 100 before its first bar. Bar quality: no NA, non-positive or
  inconsistent OHLC; 1,562 zero-volume bars; `market_cap` is 0 or NA on 2,649
  rows, otherwise equal to close x circulating supply.
- **Dead coins:** no union coin's series ends inside the window; the 6
  non-active coins stopped in 2024-2025, so their ends were fetched from
  2024-01-01 to 2026-10-23. There are two terminal shapes:
  - Abandoned (GCR, CNNC, REV, ANC): 2-8 trailing days of flat close and zero
    volume, then the series stops. The last close stays where it was, e.g. REV
    at 3.6% and ANC at 12.8% of their post-window max. There is no
    zero-price print.
  - Migrated (FTM to Sonic 2025-01-13, MATIC to POL 2025-03-24): the series
    stops mid-trading at a live price. MATIC's `market_cap` is 0 on its last 4
    days. Only `crypto_info()$notice` says it migrated.
  The window's collapses stay listed and active: LUNC fell from 116.41 to
  4.8e-05 by 2022-06-08 and was still ranked in the top 100 on 2023-12-31, USTC fell
  to 0.0065, FTT to 0.81. They are bar-continuous.
- **Duplicate symbols:** 2 in the union, both redenominations (BTT
  3718/16086, BNX 9891/23635). 7,757 of 20,391 `crypto_list()` rows share a
  symbol. Names also drift per id: id 1044 is "KWD" in window bars and "GCR"
  later. Use the CMC id.
- **Global data:** 728 daily rows (2 days missing). The top-100 listing market
  cap is a median 97% of `USD_total_market_cap` (range 84%-108%; above 100%
  means the two are not computed on one basis). It is a market-cap level, not
  an investable return series. A cap-weighted top-N benchmark should be built
  from the bars and ranks instead.
- **Cost:** listings 958 s for 730 requests; history 588 s for 212 coins
  (about 424 requests); the rest about 20 s. **No retries, no 429s, no failed
  days.** At sleep = 1 s the whole two-year top-100 sample takes about 26
  minutes.

## Lookahead

A listing dated D carries **day D's closing price**. Against bar D, the median
relative price difference is 1e-9 (97% within 1e-4) and market cap matches to
3e-12. Against bar D-1 the difference is 1.9%. The snapshot row says
`lastUpdated` D 23:00Z. Its quote says D 00:00Z, but the values are the D
close.

Rank D is therefore knowable no earlier than D's 23:59:59 close. On ledgr's
clock a strategy at pulse D sees the same instant. Lagging membership one day
(snapshot D governs pulse D+1) is the safe, recommended rule. Ranks cannot be
rebuilt from bars alone: top-100 by bar market cap overlaps the listing top 100
only 94%, because of the zero market caps above. The snapshots are needed.

## Terms

crypto2 says only that it "does not require an API key but in turn only
provides information that is also available through the website of
coinmarketcap.com". It says the same of CoinGecko ("from CoinGecko's website,
without an API key"). Neither the package documentation nor its site states the
providers' terms. The bundled crosswalk is CC BY 4.0. The providers' own terms
(fetched 2026-10-24) say:

- **CMC:** "strictly for your personal, non-commercial use"; no "data mining,
  crawling, 'scraping' ... or download or store Content (unless expressly
  authorized by CMC)"; no "distribute, redistribute, sell, license" "without
  our prior written permission".
- **CoinGecko:** no "mine data from, scrape" "without our prior written
  consent"; license "solely for your Personal Use ... and not for any
  commercial purpose".

Redistribution of a prepared dataset looks restricted under both. Recommend
the **adapter** route: users run crypto2 themselves. Do not host an extract.

## Smoke check

BTC (CMC1), LUNC (CMC4172) and ANC (CMC8857) bars over the window, stamped
D 23:59:59 UTC (2,190 rows), with a complete 730-day `ledgr_facts_sessions()`
calendar (open 00:00:00-23:59:59 UTC, venue `CMC_AGG`).
`ledgr_snapshot_from_df(..., invalid_observations = "error")` sealed with 0
quarantined (hash `d4b71f42...`). LUNC closes down to 4.8e-05 were accepted.

## Verdict

**Green:** crypto2 gave daily past rank snapshots, served full price histories
for coins that later died, and fetched the two-year top-100 sample in about 26
minutes with no rate-limit failure. None of the three kill clauses fired.

## What Stage 2 needs

- Membership from daily snapshots with a one-day lag. Handle rank holes, and
  ranked members with no bars (ARAW, 1000SATS): skip them, or record them as
  missing observations.
- Lifetime from bars (first and last bar), not from `crypto_list()`, which
  has no dates for dead coins. Status from `crypto_info()`.
- An explicit end-of-life rule. Abandoned coins stop at a stale positive price
  after zero-volume days. Migrated coins stop at a live price and need a
  conversion or forced-exit decision. ledgr's default 5-session stale horizon
  meets these ends; probe it on the dead-coin tails.
- An adapter that sets `TZ=UTC` (or re-stamps from the date), dedups the
  overlapping chunks, keys on CMC id, and keeps internal gaps as missing bars.
- A choice of the 7-day gap rule and benchmark (bars plus ranks, not global
  quotes). A test window where coins die *inside* it (e.g. 2024-2025), since
  2022-2023 has none.
