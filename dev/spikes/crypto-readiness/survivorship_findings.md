# Spot-crypto readiness, Stage 2: point-in-time top-100 survivorship probe

Run on 2026-10-24 against `d0876a9a` (ledgr 0.2.1.0 via `pkgload::load_all()`),
crypto2 3.0.0, R 4.6.1, `TZ=UTC`. No package code was changed. Runner:
`Rscript dev/spikes/crypto-readiness/survivorship_probe.R <out_dir> <cache_dir>
<probe1_cache_dir> <lib_dir> [download|analyze|all]`. Raw data is cached under
`E:/ledgr-data/crypto2/probe2/` and stays outside the repository; the aggregate
CSVs in `survivorship_evidence/` come from the `analyze` stage, which makes no
network call.

**Verdict: green.** Every held coin's end of life was representable with
existing public facts, so the kill clause ("a dead or migrated coin forces
every honest run to stop INCOMPLETE, and no existing public fact ... lets a
strategy or the data declare the ending") did not fire. One routed defect
(D1) aborts a fractional run when a coin held only as float dust dies.

## What ran

- **Window** 2020-01-01..2025-12-31, 2,192 daily sessions on a complete 24/7
  `ledgr_facts_sessions()` calendar (00:00:00-23:59:59 UTC, venue `CMC_AGG`).
  Bars stamped at 23:59:59 UTC, keyed `CMC<id>`, internal gaps left missing.
- **Universe:** 484 CMC ids were in the daily top 100 on some snapshot day;
  455 have bars (748,494 rows after dropping 221,141 byte-identical overlap
  rows). 399 are alive at the window end; 56 end inside it (49 abandoned, 7
  migrated). 29 ranked coins have no history at all (below).
- **One snapshot, two membership universes** (hash `5f215a30...`):
  `cmc_top100` (point in time) and `cmc_top100_survivors` (the same daily
  sets minus the 56 coins that end inside the window). Same bars, sessions
  and lifetime facts. A second snapshot without lifetime facts
  (`bf968e63...`) serves the gut run.
- **Runs:** default valuation and corporate-action policies,
  `ledgr_cost_notional_bps_fee(10)`, opening cash 1,000,000,
  `ledgr_metric_crypto()`. Each run took 11-16 s; each seal 13-24 s.

## Membership

`ledgr_facts_membership_snapshots(complete = TRUE, knowledge = "evidenced")`
with a `members` list-column. The snapshot dated D has `effective_from` and
`knowledge_time` both the civil date D+1, which ledgr resolves to that
session's open (00:00:00 UTC), one second after the D close the listing
reflects. That is the "next session" option. `ledgr_facts_resolve()` confirms
the lag: the first entrant (CMC45, ranked in snapshot 2020-01-01) is
`omitted_from_complete_set` at the 2020-01-01 close and `member_asserted` at
the 2020-01-02 close.

- **Rank holes:** 11 days hold fewer than 100 ranks (the minimum is 81, on
  2021-09-28). The complete set is whatever is ranked; nothing is filled in.
- **Ranked coins without bars:** 29 coins and 1,616 ranked coin-days, mostly
  2020 members that CMC no longer serves (MCO, LEND, INB, FXC, ERD, ...). They
  are dropped from membership, so 447 snapshot days have fewer than 100
  members. This is a survivorship hole in the source that no ledgr surface
  can recover.
- **Members with no bar on the pulse:** 212 of 217,553 member-pulses. They
  stay members; both strategies skip unpriced members.

## End of life (provisional default)

Lifetime from bars: `known_active` from the first bar to the session after
the last bar, then `known_inactive` with `terminal_event = "migrated"` when
the `crypto_info()` notice says so (migrat, swap, rebrand, upgrad,
"updated to"), else `"abandoned"`. The family uses
`knowledge = "assume_effective"`: the death is knowable at the session after
the last bar. The plan labels the family `assumption_backed`. The policy is
the research default: `held_terminal_position = "last_permissible"`.

Dead coins mostly leave the top 100 long before they die: 54 of 56 left more
than a year before their last bar (median 1,289 days). Their median last close
is 0.3% of their window maximum, with a typical 6-7 day flat, zero-volume
tail. Only FTM (migrated to Sonic) was held when its series ended.

- **With lifetime facts** (`ew_pit`): one `DISPOSITION` of FTM on 2025-01-14,
  before the decision, at its age-1 close, with proceeds 35,844.22 and
  assumption label `default`. The run is `DONE` and warns.
- **Without lifetime facts** (`ew_pit_no_lifetime`, the gut run): FTM freezes
  for 347 sessions. The strategy's exit target cannot fill (no bar). The run
  is `DONE` and `FROZEN`, with 35,844.22 (1.70% of equity) still frozen at the
  end and a total return of 107.21% if that holding is worthless. Neither
  representation stops a run `INCOMPLETE`.

## Survivorship comparison

| Run | Total return | CAGR | Vol | Sharpe | Max DD | Turnover/yr | Mean holdings | Ended coins held / at death |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| EW, point in time | 109.0% | 13.07% | 65.2% | 0.523 | -80.9% | 3.33 | 99.1 | 43 / 1 (FTM, disposed) |
| EW, survivors only | 141.3% | 15.80% | 65.5% | 0.560 | -81.1% | 3.29 | 95.5 | 0 / 0 |
| MV, point in time | -7.36% | -1.27% | 5.37% | -0.211 | -17.2% | 2.85 | 14.0 | 9 / 0 |
| MV, survivors only | -7.40% | -1.27% | 5.37% | -0.212 | -17.2% | 2.76 | 13.7 | 0 / 0 |

**Headline gap, equal weight:** the survivor-only backtest overstates CAGR by
2.73 points a year (32.2 points of total return) and Sharpe by 0.037. The gap
comes from holding coins that later died while they were still top-100
members and falling, not from the death event: 43 such coins were held, but
only one was held at death. **Minimum variance:** no gap (CAGR difference
0.007 points). The strategy sits in stablecoins (38% of held coin-sessions
are dollar-pegged by price behaviour) and holds cash for its first 252
sessions, so dead coins barely enter it.

## What min-variance needed for crypto

The WS48 strategy from `c6374bb2` runs verbatim except step 6:

1. `ledgr_target_rebalance(..., keep = held_excluded)` is replaced by its
   availability-aware arithmetic without the whole-unit floor (about 30
   lines, kept inside the strategy because preflight requires it).
2. A dust rule (`min_notional = 1` USD). The floor had also been zeroing
   `solve.QP()`'s near-zero weights. Without it, those weights become dust
   targets and trigger D1 (`mv_pit_no_dust_rule`, below).

## Defects to route

- **D1, fractional dust vs lots (blocking for fractional runs).** CMC3356
  (TMTG) was bought at 0.89101464257119367 and sold at 0.89101464257119356:
  a near-zero weight became a ~1e-16 target. The position vector kept
  1.11e-16 (2^-53). The lot ledger closed that within its absolute
  `.Machine$double.eps * max(1, |q|)` dust tolerance. When the coin's series
  ended, `ledgr_disposition_post()` disposed the dust position. With no long
  lot to close, it opened a short lot and aborted with
  `ledgr_lot_state_invariant` ("Disposition left live lots after reaching zero
  position"). The whole run ended `FAILED`. The terminal contract
  (Valuation And Terminal Outcomes) routes terminal failures to typed
  `INCOMPLETE` stops, such as `terminal_mark_unavailable`, which "never aborts
  the run"; this failure aborts it. The cause is positions and lots
  disagreeing on dust; fractional sizing makes it reachable, and the floor
  had masked it.
- **D2, 8-decimal price rounding.** Ingest rounds every price to 8 decimals.
  On raw crypto2 prices, 708 closes would round to 0 or below (refused) and
  16,000 closes in 39 coins lose more than 1e-4 relative precision (max
  100%). The adapter re-quotes 185 coins in 10^k-token units (k = 1..12) to
  keep 6 or more significant digits. Route: relative or per-instrument price
  precision.
- **Minor:** crypto runs print "Corporate actions: NOT SUPPLIED - returns may
  omit distributions", an equity-centric label. Stage 0 findings 1 and 2
  stand; finding 1 now has a second consequence (D1).

## Download facts

Listings: 16 new quarters plus one day (1,911 s); 8 quarters reused from
Stage 1. History: the 210 Stage 1 coins fetched for 2020-21 and 2024-25
(1,165 s); 274 coins over the full window (2,166 s); 127 single-coin refetches
of suspicious coverage (877 s). `crypto_info()` for 85 coins (about 20 s; 31
return no info). That is about 1 h 42 min of polite network time
(19:35-21:25 UTC), with zero retry messages and no 429s. The process was
killed externally once (exit 127, together with its watcher) and resumed from
cache; the batch in flight is not in the timings. crypto2 swallows a failed
400-day chunk (`purrr::possibly`), so coverage has to be checked after the
download.

## What a real adapter needs

Stage 1's duties (UTC, dedup, CMC id, 23:59:59 stamps, missing gaps), plus:

- a coverage check and refetch, because a failed chunk is silent;
- price re-quoting, until D2 is decided;
- a terminal-label map from `crypto_info()` notices, which are free text and
  missing for about a third of dead coins;
- a stated knowledge time for deaths;
- a disclosed count of ranked coins without history, which an adapter cannot
  fix;
- an optional stablecoin flag for strategies;
- until D1 is fixed, a dust rule in every fractional strategy.

## Checker and gut

The `analyze` stage was rerun into a second scratch directory and its six
evidence CSVs diffed against the first: identical (`diff -r`, no output), and
both runs sealed the same snapshot hashes. Gut demonstrations: removing the
lifetime facts turns FTM's disposition into a 347-session freeze;
removing the dust rule turns `mv_pit` from `DONE` into `FAILED`.
