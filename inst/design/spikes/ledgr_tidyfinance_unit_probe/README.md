# ledgr tidyfinance Unit Probe

**Status:** Pre-spec investigation. Findings inform future external
reference-data adapter design but do not commit to an implementation cycle.
**Scope:** Empirical verification of what `tidyfinance::download_data_*()`
returns, so any future ledgr adapter can wrap upstream values correctly
without assuming unit semantics.
**Non-scope:** ledgr API design, adapter implementation, metric-context
integration, beta or benchmark feature design. Findings inform design; they
do not produce a public ledgr function.

The accepted v0.1.8.2 metric-context synthesis names `benchmark` and
`market_factor` as reserved provider fields and explicitly defers external
adapters. This spike is the upstream empirical work that must happen before
any future RFC can specify how a tidyfinance-backed reference-data adapter
should normalize provider output. The spike is informational only; it does
not propose, commit to, or schedule any adapter.

Platform matrix: **Windows 11 (native R)** and **Ubuntu/WSL**. Spikes that
fail on one platform should record the failure mode, not be abandoned.

---

## SPIKE-1: Risk-Free Rate Output Semantics

**Effort:** 0.25-0.5 day
**Blocking:** Any future `ledgr_risk_free_series` implementation that wraps
tidyfinance. Not blocking for v0.1.8.2 ticket cut.

**Question:** What does `tidyfinance::download_data_risk_free()` actually
return for the `risk_free` column?

Specifically:

- Is the value annualized or already a period return?
- Decimal (for example `0.04`) or percent (for example `4.0`)?
- For `frequency = "daily"`, is the cadence calendar days or business days?
- How are weekends or non-business gaps represented: NA, forward-fill, or
  silent omission?
- Does the returned `date` align to settlement, observation, or quote
  convention?

**Tasks:**

1. Install `tidyfinance` if not already present. Record version on each
   platform.
2. Call `tidyfinance::download_data_risk_free(start_date = "2010-01-04", end_date = "2010-01-31", frequency = "daily")`.
   Record the first 20 rows verbatim.
3. Compare the daily values to a public source for the same period (for
   example the 3-month T-bill rate from FRED). Compute the implied period
   return from a candidate annualized rate and compare to the observed
   value.
4. Repeat with `frequency = "monthly"`. Record values and compare to a known
   monthly risk-free series.
5. Check whether returned rows for non-business-day dates exist, are missing,
   or are forward-filled.
6. Inspect column types and timezone, if any.
7. Repeat the entire probe on Ubuntu/WSL.

**Record:**

- Exact unit (annualized vs period, decimal vs percent)
- Cadence (calendar days vs business days)
- Gap handling (omitted, NA, LOCF)
- Column types and timezone behavior
- Any platform difference
- `tidyfinance` version under which each finding was observed

**Decision gate:** A future `ledgr_risk_free_series` wrapper that uses
tidyfinance must convert provider output to ledgr's normalized period-return
form. The conversion rule is provider-version-specific. Record the verified
semantics for the tested `tidyfinance` version in the findings section. Do
not commit to a particular conversion until this spike completes and the
external-adapter RFC opens.

---

## SPIKE-2: Stock Prices Output For Benchmark Returns

**Effort:** 0.25-0.5 day
**Blocking:** Any future `ledgr_reference_returns_from_tidyfinance_stock_prices()`
adapter design. Not blocking for v0.1.8.2 ticket cut.

**Question:** What does `tidyfinance::download_data("stock_prices", symbols = ...)`
return, and what is the safe return-calculation contract on top of it?

Specifically:

- Which price columns are present (open, high, low, close, adjusted_close,
  volume)?
- Are values already adjusted for splits and dividends?
- What is the date column type and timezone?
- How are non-trading days handled?
- Are missing dividend/split events flagged?

**Tasks:**

1. Call `tidyfinance::download_data("stock_prices", symbols = c("SPY", "AAPL"), start_date = "2020-01-01", end_date = "2020-12-31")`.
   Record column names and first 10 rows.
2. Verify behavior on a known split or dividend event in the requested range
   (for example the AAPL 4:1 split on 2020-08-31). Confirm whether `close`
   and `adjusted_close` differ as expected across the event.
3. Compute simple returns from `adjusted_close` and from `close`. Confirm
   the adjusted-close return is the dividend/split-aware return.
4. Check NA handling for missing trading days or missing tickers.
5. Repeat on Ubuntu/WSL.

**Record:**

- Available columns and their meanings
- Split/dividend adjustment behavior
- Return-method recommendation (`adjusted_close` vs `close`)
- NA and missing-data handling
- Platform behavior
- `tidyfinance` version under which each finding was observed

**Decision gate:** A future benchmark-returns adapter must commit to one
return method (most likely `adjusted_close`) and document it explicitly.
Record the verified semantics for the tested `tidyfinance` version. Do not
commit to a particular return method until this spike completes and the
external-adapter RFC opens.

---

## SPIKE-3: Fama-French Factor Output (Optional)

**Effort:** 0.25 day
**Blocking:** None for v0.1.8.2. Only relevant if a future factor adapter
RFC is opened.

**Question:** What does the Fama-French 3-factor download return, especially
the unit of `mkt_excess` and `risk_free`, and is the scaling consistent
with SPIKE-1?

This spike is optional. Skip unless the factor-related deferred RFC opens.

**Tasks:**

1. Discover the canonical type name for the Fama-French 3-factor dataset
   before calling `download_data()`. Try
   `tidyfinance::list_supported_types(domain = "Fama-French")` and
   `tidyfinance::list_supported_types_ff()`. Record the exact type strings
   returned. Recent tidyfinance releases use frequency-typed names such as
   `factors_ff_3_monthly` and `factors_ff_3_daily`; do not hard-code a type
   string without first confirming it through the discovery helper.
2. Call the Fama-French 3-factor download for a recent date range using one
   of the discovered type names. Record column names, types, and units
   (decimal vs percent).
3. Compare `risk_free` from this call to the `download_data_risk_free()`
   output from SPIKE-1 for an overlapping period. Note any discrepancy.

**Record:**

- Factor column units
- Whether factor `risk_free` matches the standalone `risk_free` series
- `tidyfinance` version under which each finding was observed

---

## Decision Gates Summary

| Spike | Primary decision |
|---|---|
| SPIKE-1 | Unit/cadence/gap semantics for `download_data_risk_free()` |
| SPIKE-2 | Adjusted-close vs close return method; provider price-adjustment semantics |
| SPIKE-3 (optional) | Factor unit and `risk_free` consistency across endpoints |

SPIKE-1 and SPIKE-2 should complete before any RFC for an external
reference-data adapter is opened. SPIKE-3 is informational and can wait
until factor adapter work is requested. None of the spikes block v0.1.8.2
ticket cut or implementation.

---

## Findings

Spike scripts live under `dev/spikes/ledgr_tidyfinance_unit_probe/`. Raw
output artifacts are local scratch and are not committed.

### SPIKE-1

To be recorded.

### SPIKE-2

To be recorded.

### SPIKE-3

To be recorded.
