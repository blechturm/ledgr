# Execution Engine Audit

**Scope:** `R/backtest-runner.R`, `R/fill-model.R`, `R/derived-state.R`,
`R/pulse-context.R`, `R/ledger-writer.R`, `R/run-store.R`

**Branch:** v0_1_7_2 · **Initial audit:** 2026-05-11 · **Review findings incorporated:** 2026-05-11

---

## Critical — release-blocking

### 1. Opening-position cost basis is never seeded into the lot map

**Files:** `backtest-runner.R:301–344`, `backtest-runner.R:1220`,
`backtest-runner.R:1612`, `backtest-runner.R:1887`, `derived-state.R:239`,
`R/run-store.R:341`

`ledgr_opening(positions = ..., cost_basis = ...)` writes opening holdings as
`CASHFLOW` events with `cash_delta = 0`, `position_delta = qty`, and the
caller-supplied cost basis stored in `meta_json`. Every lot-accounting path
skips non-`FILL` events unconditionally:

```r
# resume replay (backtest-runner.R:1220)
if (!identical(existing_events$event_type[[i]], "FILL")) next

# live loop (backtest-runner.R:1612)
if (identical(write_res$row$event_type, "FILL")) { ... }

# post-run reconstruction (backtest-runner.R:1887)
if (!identical(events_df$event_type[[i]], "FILL") || ...) { next }

# derived-state reconstruction (derived-state.R:239)
if (!identical(row$event_type[[1]], "FILL") || ...) { return(invisible(TRUE)) }
```

**Reproduced:** opening long at cost $50 sold at $60 returns `realized_pnl = 0`,
`action = "OPEN"`, and no closed trade row. Expected: realized P&L = $10, a
closed trade record.

**Cascade — trade metrics and comparison stats are also wrong:**

`ledgr_extract_fills()` queries only `FILL`/`FILL_PARTIAL` events and builds
FIFO from an empty map. When an opening position is sold, no prior lot exists,
so it is classified `OPEN` instead of `CLOSE`. `run-store.R:341` (comparison
stats) does the same. Affected metrics for any run that uses
`ledgr_opening(positions = ...)` and later liquidates those holdings:

- `realized_pnl` is understated or zero
- `unrealized_pnl` is overstated by the full market value (cost basis treated as 0)
- `n_trades`, `win_rate`, `avg_trade` are wrong because closing fills are
  classified as opens

**Fix:** Extract a shared FIFO lot-accounting helper that accepts an optional
`seed_lots` argument. Seed opening lots from `CASHFLOW` events' `meta_json`
before the event replay loop in every reconstruction path. Apply the helper in
all five locations (see below).

---

## Important

### 2. FIFO lot-matching logic is duplicated in five places

The initial audit counted four locations. The fifth is `run-store.R:341`
(comparison-stats computation). All five must receive the same opening-position
fix or they will diverge:

1. `backtest-runner.R` — resume replay (lines ~1220–1276)
2. `backtest-runner.R` — live loop (lines ~1617–1667)
3. `backtest-runner.R` — post-run reconstruction (lines ~1880–1953)
4. `derived-state.R` — standalone reconstruction (`apply_event`)
5. `run-store.R` — comparison-stats FIFO (line ~341)

**Recommendation:** One `ledgr_lot_accounting` helper function with a clear
signature. All five paths call it. The opening-position patch is then applied
in exactly one place.

### 3. `spread_bps` applies the full spread per leg — underdocumented

**File:** `fill-model.R:62–64`

```r
# Spec §8 (v0.1.0): next-open fill uses full spread_bps adjustment.
multiplier <- if (side == "BUY") (1 + spread_bps / 10000) else (1 - spread_bps / 10000)
```

A round trip costs `2 × spread_bps / 10000` of notional. `spread_bps = 10`
produces ~20 bps of round-trip friction, not 10. Users will read the parameter
as a quoted bid/ask spread where each leg pays half. This is a spec-level
decision (the comment is explicit), but it is not surfaced in any public docs.

**Recommendation:** Document the full-spread-per-leg convention prominently in
`ledgr_opening()` and fill-model parameter docs, or rename to `round_trip_bps`
to make the semantics self-describing.

### 4. Six preallocated live equity arrays are dead code

**File:** `backtest-runner.R:1199–1204`, `1686–1692`

`eq_ts`, `eq_cash`, `eq_positions_value`, `eq_equity`, `eq_realized`,
`eq_unrealized` are allocated before the loop and updated at every pulse. They
are never read after the loop completes. The authoritative equity curve is
computed from scratch at lines 1778–2025 using `findInterval` over the persisted
ledger events and is what gets written to the database.

These six arrays cost one vector write per pulse per variable. For a 10-year
daily run on 500 instruments that is ~7.5 million unused assignments.

Safe cleanup candidate after confirming test coverage.

---

## Minor

### 5. Non-universe instruments in opening positions

**Correction from initial audit:** `ledgr_experiment()` validates that opening
position instruments are a subset of the universe (`experiment.R:388`). The
initial audit was only correct for lower-level entry points: raw config/runner
calls that bypass `ledgr_experiment()` can still reach the runner with
out-of-universe opening positions without validation. Not a user-facing footgun
via the public API.

### 6. Global RNG side effect

**File:** `backtest-runner.R:403`

`set.seed(runtime_seed)` is called unconditionally at engine entry, defaulting
to seed 1 when `cfg$engine$seed` is `NULL`. Reproducible by design, but mutates
caller session RNG state. Strategy code using `runif()` or `sample()` gets
seed-1 output even when no seed was explicitly requested. Affects other
session-level RNG-dependent code including test suites.

### 7. `commission_fixed` can make small SELL fills lose cash

**File:** `fill-model.R:63–65`, `ledger-writer.R:67–71`

```r
cash_delta <- +(qty * fill_price - commission_fixed)
```

If `commission_fixed > qty * fill_price`, cash_delta is negative for a SELL.
No guard. Unlikely with default config but possible with small fractional-share
trades and aggressive fixed commissions.

---

## Corrected from initial audit

**Pending-buffer overflow guard** — the initial audit flagged `>` vs `>=` as a
bug. This was a false positive. `pending_idx` is incremented before the guard
check (`backtest-runner.R:1568`). Using `>=` would reject the last valid slot.
The current `>` is correct.

**Non-universe opening positions via public API** — corrected above (§5).

---

## Verified Correct

**Fill timing:** Fills are timestamped at `next_bar$ts_utc`. `findInterval` in
the post-run equity reconstruction correctly assigns each fill to the pulse after
the decision. Equity at decision time reflects pre-fill positions. Correct.

**Cash accounting identity:** `derived-state.R:395–407` verifies
`cash == initial_cash + sum(cash_delta)` and `positions == cumulative
position_delta` before writing. Catches ledger inconsistencies at reconstruction
time.

**Kahan summation for realized P&L:** Used throughout. Prevents float drift in
long simulations.

**Snapshot tamper detection:** Hash recomputed and compared to stored hash
before run starts. Data hash of the bars subset verified on resume.

**OHLC consistency check:** `validate_bars_subset` verifies OHLC bounds before
the run. Corrupt bar data aborts at startup.

**Coverage enforcement:** Universe/time-range bars coverage verified at
startup — sparse snapshot aborts before any fills.

**`ctx$equity` correctness:** `state$cash` at decision time is post-fill from
all previous pulses. `positions_value` uses current close and pre-fill positions.
Correct decision-time equity.

**Resume determinism:** Ledger events, features, equity curve, and strategy
state at and after the resume point are deleted before re-running.
`config_hash` and `data_hash` verified before proceeding.

---

## Summary

| Severity | Issue |
|---|---|
| **Critical / release-blocking** | Opening position cost basis not seeded into lot map — realized/unrealized P&L, n_trades, win_rate, avg_trade all wrong for runs using `ledgr_opening(positions = ...)` |
| **Important** | FIFO lot-matching duplicated in five places — patch must be applied consistently |
| **Important** | `spread_bps` full-spread-per-leg semantics underdocumented |
| **Important** | Six live equity arrays are dead code |
| **Minor** | Non-universe opening positions bypass validation below `ledgr_experiment()` |
| **Minor** | `set.seed(1)` global side effect on every run without explicit seed |
| **Minor** | `commission_fixed > qty * fill_price` can make SELL cash_delta negative |
| ~~Minor~~ | ~~Pending buffer overflow guard uses `>` not `>=`~~ — false positive, `>` is correct |
