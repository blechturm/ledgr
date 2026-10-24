# Spot-crypto readiness: prerequisite probe findings (Stage 0)

Run on 2026-10-24 against `c6374bb2` (v0.2.2 line, package version 0.2.1.0)
with `pkgload::load_all()`. No package code was changed. Runner:
`Rscript dev/spikes/crypto-readiness/probe.R <out_dir>`, which writes
`probe_log.txt` and the evidence CSVs (fills, trades, equity, ledger,
positions, all read after reopen) into `<out_dir>`.

## What ran

- Synthetic BTCUSD and ETHUSD daily bars on 120 consecutive UTC days
  (2024-01-01 to 2024-04-29), one venue `SYNTH_SPOT`, sessions built with
  `ledgr_facts_sessions()` as `open` 00:00:00 to 23:59:59 UTC on every day,
  bars stamped at the session close. Whole-feed gap: no bar for either asset
  on 2024-03-10..13. 232 bar rows, sealed with `price_basis = "split_adjusted"`.
- A strategy starting from `ctx$hold()` that sets scheduled fractional
  quantities (0.0371 BTC / 1.2345 ETH, then 0.05 / 0.5, 0.0123456789 /
  2.000001, 0.0200001 / 0.333333333 decided the day before the gap, then
  0 / 0.1) on `ctx$tradable()` IDs. Cost `ledgr_cost_notional_bps_fee(10)`,
  metric context `ledgr_metric_crypto()`, opening cash 10,000.
- `ledgr_run()`, then `close()`, `ledgr_snapshot_close()`, reopen with
  `ledgr_snapshot_open(verify = TRUE)` and `ledgr_run_open()`, and read
  everything back. Helper runs: `ledgr_target_rebalance()` at 1,000 and
  100,000 USD; a run with no metric context.

## (a) Fractional quantities: preserved

- Every scheduled fraction filled at exactly the requested delta, e.g.
  `BTCUSD SELL qty=0.0376543211` (0.05 - 0.0123456789) and
  `ETHUSD SELL qty=1.666667667` (2.000001 - 0.333333333).
- The fee equals `qty * price * 10 bps` exactly: `max abs: 0`.
- An independent FIFO replay over the product's fill rows matches every
  `realized_pnl` (`max |replay_pnl - product_pnl|: 0`) and leaves the same
  open lot, `ETHUSD 0.10000000000000001@2389.98`.
- Ledger-derived final positions (`ledgr_state_reconstruct`):
  `BTCUSD qty=0`, `ETHUSD qty=0.10000000000000001` (the double nearest 0.1).
  Equity 10,461.635 = cash 10,208.201 + 0.1 x ETH close.
- Reopen: snapshot hash `5a34c497...` and config hash `98caa743...` identical;
  fills, trades, equity, ledger, `ledgr_run_fills`, completion, summary and
  reconstructed positions all `identical values: TRUE` at `tolerance = 0`.

Where a fraction is rounded, refused or lost:

- `ledgr_target_rebalance()` floors to whole units, as `contracts.md`
  states ("floors share quantities to whole numbers"). At 1,000 USD and
  50/50 weights both targets became 0 (unfloored 0.01159 BTC, 0.2127 ETH)
  and the run made no fill, with no warning raised. At 100,000 USD,
  1.1594 BTC became 1 and 21.27 ETH became 21.
- `ledgr_target_quantity(qty = 0.0371)` and `ledgr_weights()` accept
  fractions unchanged.
- Nothing else rounds. The ledger `meta_json` shows binary residue
  (`position_delta: 0.012900000000000002`), not loss. Printed money uses two
  decimals only for display.

## (b) 24/7 session clock: preserved

- 120 equity rows on 120 distinct dates; 34 weekend pulses; US holidays
  2024-01-01, -01-15, -02-19 and -03-29 are ordinary pulses. The first fill
  executed on Saturday 2024-01-06 at the 00:00:00 session open.
- Gap: marks went `stale_close` age 1..4 and equity held at 10,387.39. The
  target decided on 03-09 is recorded `no_fill execution_bar_missing` on
  03-09..03-12 (stale-priced IDs stay in `ctx$tradable()`, so the strategy
  re-requested), and the 03-13 request filled at the 03-14 open. Result:
  `Status: DONE`, `Valuation: STALE - 2 holdings ... (longest age 4
  sessions)`, no freeze, nothing INCOMPLETE (the gap is under the default
  5-session horizon).

## Annualization on a 365-session clock

- With `ledgr_metric_crypto()`: `Annualization: 365 periods/year (crypto
  daily)`, annualized return 14.85%, volatility 1.79%, Sharpe 7.762. The
  stored context survives reopen (summary identical).
- With no metric context the same equity reports `252 periods/year (US
  equity daily)`, 10.03%, 1.48%, Sharpe 6.449, with no warning; the cadence
  check only fires on sub-daily intervals. The declared 7-day session
  calendar is not consulted.

## Verdict

**Green:** neither fractional quantities nor the 24/7 daily clock needed a
production change, so the brief's kill condition ("if either property needs a
production change, stop") did not fire.

## Not blockers; route as findings

1. `ledgr_target_rebalance()` whole-unit flooring (contract-bound) makes the
   weights helper unusable at crypto price scales and yields a silent no-trade
   run at small notional. A quantity-granularity decision (per-instrument step
   or none) belongs to the later spike or an RFC, not a correction.
2. The default metric context silently annualizes a declared 365-session
   calendar at 252. Disclosed in `summary()`, but not marked as a default and
   not checked against the session facts.
3. The default stale horizon (5 sessions, calibrated on S&P data) is 5
   calendar days on this clock. Stage 1 should choose it on real data.

## What the crypto2 data stage (Stage 1) needs

- A whole-second session-close stamp for each daily bar (e.g. 23:59:59 UTC),
  because a bar off every declared session close is sealed but never a pulse
  (`contracts.md`, Off-Session Bars).
- A 24/7 `ledgr_facts_sessions()` frame covering the full window; the
  constructor refuses a calendar with missing civil dates.
- An explicit `ledgr_metric_crypto()` on every experiment (finding 2).
- Strategies that size with `ledgr_target_quantity()` or their own fractional
  arithmetic until finding 1 is decided.
- Mapping of listing snapshots, delistings and untracked coins onto
  membership, lifetime and missing observations; none of that was probed here.
- USD as an unstated convention: the probe declared no currency; print shows
  `Opening Cash: $10000.00`.
