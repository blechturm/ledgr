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

Status: Completed on Windows native R. Ubuntu/WSL blocked by package
installation failure.

Tested versions:

- Windows native R: R 4.5.2, `tidyfinance` 0.5.0. The package emitted a
  warning that it was built under R 4.5.3.
- Ubuntu/WSL: R 4.5.2. `tidyfinance` 0.5.0 could not be installed because
  source installation of dependencies failed: `arrow` requires a C++20
  compiler and `RPostgres` failed configure. `tidyfinance` remained
  unavailable on WSL.

Observed Windows call:

```r
tidyfinance::download_data_risk_free(
  start_date = "2010-01-04",
  end_date = "2010-01-31",
  frequency = "daily"
)
```

First 20 returned rows:

| date | risk_free |
|---|---:|
| 2010-01-04 | 0.000001944 |
| 2010-01-05 | 0.000001167 |
| 2010-01-06 | 0.000001167 |
| 2010-01-07 | 0.000000778 |
| 2010-01-08 | 0.000000778 |
| 2010-01-11 | 0.000000389 |
| 2010-01-12 | 0.000000778 |
| 2010-01-13 | 0.000000778 |
| 2010-01-14 | 0.000000778 |
| 2010-01-15 | 0.000001167 |
| 2010-01-18 | 0.000001167 |
| 2010-01-19 | 0.000001167 |
| 2010-01-20 | 0.000001167 |
| 2010-01-21 | 0.000000778 |
| 2010-01-22 | 0.000000778 |
| 2010-01-25 | 0.000000778 |
| 2010-01-26 | 0.000000778 |
| 2010-01-27 | 0.000000389 |
| 2010-01-28 | 0.000000389 |
| 2010-01-29 | 0.000000778 |

The daily result is a tibble with columns `date <Date>` and
`risk_free <numeric>`. Returned rows are business days only for this window:
weekends are omitted, not present as `NA` rows. Observed date gaps were one
day and three days. The help page states that business-day gaps such as
holidays are forward-filled from the most recent available rate.

The returned `risk_free` values are period returns, not annualized quoted
rates. The `download_data_risk_free()` help page states that upstream FRED
T-bill discount rates are converted to the target period length. For the daily
post-2001 series, the provider uses 4-week T-bill observations and an exponent
of `1/20`. This matches the observed scale: the first value
`0.000001944` implies roughly `0.0000389` over 20 trading days, or about
`0.00389%`, which corresponds to a very low annualized bill-rate environment.

Monthly call:

```r
tidyfinance::download_data_risk_free(
  start_date = "2010-01-01",
  end_date = "2010-03-31",
  frequency = "monthly"
)
```

Returned rows:

| date | risk_free |
|---|---:|
| 2010-01-01 | 0.000016898 |
| 2010-02-01 | 0.000076006 |
| 2010-03-01 | 0.000126752 |

Monthly output also uses `date <Date>` and `risk_free <numeric>`. Dates are
month starts in this probe (`2010-01-01`, `2010-02-01`, `2010-03-01`), while
the help page states that post-2001 monthly source observations are aggregated
from the last non-`NA` daily observation per calendar month before conversion
to the monthly target period.

Decision note: a future `ledgr_risk_free_series()` wrapper should treat
`tidyfinance::download_data_risk_free()` 0.5.0 output as already normalized to
period returns for the requested frequency. It should not divide by 252 or 12.
It should still record provider name, provider version, frequency, and the
conversion convention because this is provider-version-specific.

### SPIKE-2

Status: Completed on Windows native R. Ubuntu/WSL blocked by the same
`tidyfinance` installation failure recorded in SPIKE-1.

Observed Windows call:

```r
tidyfinance::download_data_stock_prices(
  symbols = c("SPY", "AAPL"),
  start_date = "2020-01-01",
  end_date = "2020-12-31"
)
```

Returned shape:

- Rows: 504 for the two-symbol 2020 probe.
- Columns: `symbol`, `date`, `volume`, `open`, `low`, `high`, `close`,
  `adjusted_close`.
- Types: `symbol <character>`, `date <Date>`, all price and volume columns
  numeric.
- Returned dates are trading days only. Non-trading days are omitted, not
  present as `NA` rows. Observed within-symbol date gaps were one, two, three,
  and four days.

First 10 rows:

| symbol | date | volume | open | low | high | close | adjusted_close |
|---|---|---:|---:|---:|---:|---:|---:|
| SPY | 2020-01-02 | 59151200 | 323.54 | 322.53 | 324.89 | 324.87 | 297.42 |
| SPY | 2020-01-03 | 77709700 | 321.16 | 321.10 | 323.64 | 322.41 | 295.17 |
| SPY | 2020-01-06 | 55653900 | 320.49 | 320.36 | 323.73 | 323.64 | 296.30 |
| SPY | 2020-01-07 | 40496400 | 323.02 | 322.24 | 323.54 | 322.73 | 295.46 |
| SPY | 2020-01-08 | 68296000 | 322.94 | 322.67 | 325.78 | 324.45 | 297.04 |
| SPY | 2020-01-09 | 48473300 | 326.16 | 325.52 | 326.73 | 326.65 | 299.06 |
| SPY | 2020-01-10 | 53029300 | 327.29 | 325.20 | 327.46 | 325.71 | 298.20 |
| SPY | 2020-01-13 | 47086800 | 326.39 | 326.22 | 327.96 | 327.95 | 300.25 |
| SPY | 2020-01-14 | 62832800 | 327.47 | 326.84 | 328.62 | 327.45 | 299.80 |
| SPY | 2020-01-15 | 72056600 | 327.35 | 327.26 | 329.02 | 328.19 | 300.47 |

Split behavior:

- The AAPL split window around 2020-08-31 did not show a discontinuity in
  `close` returns. `close` and `adjusted_close` returns were effectively equal
  through the split window.
- This indicates Yahoo/tidyfinance `close` is already split-adjusted in
  historical rows.

Dividend behavior:

- `close` and `adjusted_close` differed on every returned row in the probe.
- Return differences clustered on dividend dates. Examples:
  - SPY 2020-03-20: `close_ret = -0.0487`, `adjusted_ret = -0.0431`.
  - SPY 2020-06-19: `close_ret = -0.0101`, `adjusted_ret = -0.00571`.
  - AAPL 2020-05-08: `close_ret = 0.0210`, `adjusted_ret = 0.0238`.
  - AAPL 2020-02-07: `close_ret = -0.0159`, `adjusted_ret = -0.0136`.

Decision note: for future benchmark-return adapters, `adjusted_close` is the
right default return basis because it is split- and dividend-aware. `close`
appears split-adjusted but not dividend-adjusted and should only be exposed as
an explicit alternative if a future RFC needs price-return semantics.

### SPIKE-3

Status: Optional spike completed on Windows native R. Ubuntu/WSL blocked by the
same `tidyfinance` installation failure recorded in SPIKE-1.

Discovery:

```r
tidyfinance::list_supported_types(domain = "Fama-French")
```

Returned 297 Fama-French rows in `tidyfinance` 0.5.0. The canonical 3-factor
type names observed were:

- `factors_ff_3_monthly`
- `factors_ff_3_weekly`
- `factors_ff_3_daily`

Daily 3-factor probe:

```r
tidyfinance::download_data_factors_ff(
  dataset = "factors_ff_3_daily",
  start_date = "2010-01-04",
  end_date = "2010-01-31"
)
```

Returned 19 rows with columns `date`, `mkt_excess`, `smb`, `hml`, and
`risk_free`. Types were `date <Date>` and numeric factor columns. Ranges:

- `mkt_excess`: `-0.0213 .. 0.0169`
- `smb`: `-0.0067 .. 0.0061`
- `hml`: `-0.0128 .. 0.0122`
- `risk_free`: `0 .. 0`

Monthly 3-factor probe:

```r
tidyfinance::download_data_factors_ff(
  dataset = "factors_ff_3_monthly",
  start_date = "2010-01-01",
  end_date = "2010-03-31"
)
```

Returned 3 rows with the same columns. Ranges:

- `mkt_excess`: `-0.0335 .. 0.063`
- `smb`: `0.0043 .. 0.0146`
- `hml`: `0.0033 .. 0.0219`
- `risk_free`: `0 .. 0.0001`

The factor endpoint uses decimal period returns, not percent values. It does
not match the standalone `download_data_risk_free()` values exactly for the
same dates. For example, standalone January 2010 monthly `risk_free` was
`0.000016898`, while Fama-French January 2010 monthly `risk_free` was `0`.
This is expected provider divergence: the factor endpoint reflects the
Fama-French dataset's own rounded factor file, while the standalone risk-free
endpoint is tidyfinance's FRED-derived converted series.

Decision note: a future factor adapter must not assume factor `risk_free`
equals `download_data_risk_free()` output. If both are exposed, provenance must
record the endpoint and dataset name separately.

### Known Gaps For Future Adapter RFC

These are follow-up questions for a future external reference-data adapter RFC,
not defects in this spike:

- No independent FRED-direct cross-check was run. The risk-free period-return
  conclusion is grounded in tidyfinance output plus the tidyfinance help-page
  conversion formula, but an adapter test should still pin a small independent
  FRED reference example.
- No multi-regime probe was run. Adapter design should verify behavior across
  at least one high-rate period and one modern low/zero-rate period.
- Empty-range and missing-data behavior was not tested.
- Ubuntu/WSL provider behavior remains unverified because `tidyfinance` could
  not be installed on the available WSL environment.
- Weekly risk-free behavior was not tested. The risk-free helper currently
  documents `daily` and `monthly`; factor endpoints include weekly datasets,
  which should be handled separately if factor adapters open.
