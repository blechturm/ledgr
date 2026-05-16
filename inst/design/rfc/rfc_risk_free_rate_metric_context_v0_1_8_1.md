# RFC: Risk-Free-Rate Metric Context

**Status:** Request for comment - design proposal, no implementation started.
**Author:** ledgr maintainer
**Reviewer:** Codex
**Date:** 2026-05-16
**Target cycle:** v0.1.8.1 candidate scope
**Context files:**
- `inst/design/contracts.md` - current standard metric and Sharpe contract
- `inst/design/ledgr_roadmap.md` - v0.1.8.1 reference-data and risk-free-rate milestone
- `inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_spec.md` - auditr finding route
- `R/backtest.R` - current scalar `risk_free_rate` implementation
- `R/fold-core.R` - sweep metric computation path
- `R/run-store.R` - comparison-table metric computation path

---

## 1. Background

ledgr already computes Sharpe-style metrics from period excess returns:

```text
excess_return[t] = equity_return[t] - rf_period_return[t]
sharpe = mean(excess_return) / sd(excess_return) * sqrt(bars_per_year)
```

The current public input is a scalar annual rate:

```r
summary(bt, risk_free_rate = 0.02)
ledgr_compute_metrics(bt, risk_free_rate = 0.02)
```

The scalar annual rate is converted geometrically:

```text
rf_period_return = (1 + rf_annual)^(1 / bars_per_year) - 1
```

This is a sound first contract. The auditr v0.1.8 run showed that the UX is not
explicit enough:

- summary output prints "Sharpe Ratio" without showing when a nonzero
  `risk_free_rate` was used;
- users need to know the annualization convention when verifying Sharpe by
  hand;
- roadmap already names reference-data and risk-free-rate adapters as a
  v0.1.8.1 candidate direction.

This RFC proposes a progressive UX that starts with today's scalar path and
adds richer provenance only where it pays for itself.

---

## 2. Design Principles

1. Risk-free rate affects metrics only.
   It must not affect strategy execution, fills, equity, run identity, config
   hash, candidate selection mechanics, or snapshot sealing.

2. The Sharpe formula is owned by ledgr.
   New providers must produce a pulse-aligned per-period risk-free return
   vector consumed by the same formula. Providers must not redefine Sharpe.

3. Scalar annual rates remain valid.
   Existing user code must keep working.

4. Metadata is optional at first, but recoverable when supplied.
   A bare `0.04` is convenient. A named risk-free assumption should be
   inspectable and hashable.

5. External data is not hidden.
   If ledgr later supports FRED, Treasury, ECB, or broker/custodian data, the
   source, retrieval time, coverage, and hash must be visible.

6. Reference data is not market snapshot data.
   Risk-free-rate inputs belong to metric context, not to the sealed tradable
   market-data snapshot, unless a future RFC explicitly chooses otherwise.

---

## 3. Proposed UX Levels

### Level 1: Scalar Annual Rate

Keep the current simple path:

```r
summary(bt, risk_free_rate = 0.04)
metrics <- ledgr_compute_metrics(bt, risk_free_rate = 0.04)
cmp <- ledgr_compare_runs(exp, risk_free_rate = 0.04)
```

Expected summary output should disclose the assumption:

```text
Risk Metrics:
  Risk-Free Rate:      4.00% annual
  Annualization:       252 periods/year
  Volatility (annual): 12.30%
  Sharpe Ratio:        0.845
```

If `risk_free_rate = 0`, the summary may either print the zero assumption or
keep the current compact output. The safer teaching default is to print it
once the section is already present:

```text
Risk-Free Rate:      0.00% annual
```

Level 1 is enough to fix the auditr finding.

### Level 2: Named Risk-Free Assumption Object

Add a lightweight metadata-bearing object:

```r
rf <- ledgr_risk_free_rate(
  annual_rate = 0.04,
  label = "manual_4pct",
  source = "manual assumption",
  as_of = "2026-05-16"
)

summary(bt, risk_free_rate = rf)
metrics <- ledgr_compute_metrics(bt, risk_free_rate = rf)
cmp <- ledgr_compare_runs(exp, risk_free_rate = rf)
```

The object should be explicit and small:

```r
str(rf)
#> List of 6
#>  $ type       : chr "scalar_annual"
#>  $ annual_rate: num 0.04
#>  $ label      : chr "manual_4pct"
#>  $ source     : chr "manual assumption"
#>  $ as_of      : chr "2026-05-16"
#>  $ hash       : chr "<sha256>"
#>  - attr(*, "class")= chr "ledgr_risk_free_rate"
```

Suggested print:

```text
ledgr Risk-Free Rate
  Label:       manual_4pct
  Rate:        4.00% annual
  Source:      manual assumption
  As of:       2026-05-16
```

Metric outputs can carry the normalized assumption as an attribute:

```r
metrics <- ledgr_compute_metrics(bt, risk_free_rate = rf)
attr(metrics, "risk_free_rate")
#> normalized scalar metadata
```

Comparison tables can carry a table-level attribute:

```r
cmp <- ledgr_compare_runs(exp, risk_free_rate = rf)
attr(cmp, "risk_free_rate")
```

Level 2 gives ledgr-style provenance without committing to external providers.

### Level 3: Time-Varying Risk-Free Series

Add a typed series object for users who already have reference data:

```r
rf <- ledgr_risk_free_series(
  data = sofr_rates,
  date_col = "date",
  rate_col = "sofr",
  rate_type = "annualized",
  label = "sofr_daily_export",
  source = "FRED SOFR CSV export"
)

metrics <- ledgr_compute_metrics(bt, risk_free_rate = rf)
```

The series provider must produce a vector aligned to the equity-return periods:

```text
equity timestamps:       t0, t1, t2, ...
period returns:              r1, r2, ...
rf_period_return vector:     f1, f2, ...
```

Rules to specify:

- coverage must include every return period or fail loudly;
- date/time zone interpretation must be explicit;
- rate units must be explicit (`annualized`, `period`, possibly `daily`);
- interpolation/fill-forward must be explicit, not silent;
- the normalized series should carry a content hash;
- missing rates should fail unless the user requested a documented fill rule.

Example with explicit fill rule, if accepted:

```r
rf <- ledgr_risk_free_series(
  sofr_rates,
  date_col = "date",
  rate_col = "sofr",
  rate_type = "annualized",
  fill = "locf",
  source = "FRED SOFR CSV export"
)
```

Level 3 is useful, but it is also the first level that can grow real edge cases.
It should be designed now and implemented only if v0.1.8.1 has room.

---

## 4. Deferred Adapter Layer

External fetching should be a later layer:

```r
rf <- ledgr_risk_free_from_fred(
  "SOFR",
  start = "2020-01-01",
  end = "2024-12-31"
)
```

Reasons to defer fetching:

- network access and rate limits;
- authentication and local caching;
- data revisions;
- calendars and holidays;
- source-specific units;
- reproducibility of retrieval time;
- dependency discipline.

The adapter layer should produce the same Level 3 object. It should not add a
new metric formula or bypass the normalized provider path.

---

## 5. Proposed Public Surface

### v0.1.8.1 Minimum

```r
ledgr_compute_metrics(bt, metrics = "standard", risk_free_rate = 0)
summary(bt, metrics = "standard", risk_free_rate = 0)
ledgr_compare_runs(exp, ..., risk_free_rate = 0)
```

Changes:

- summary prints risk-free-rate and annualization context;
- docs explain the annualization convention;
- `ledgr_compare_runs()` accepts the same scalar `risk_free_rate` argument if it
  does not already;
- tests assert scalar parity across summary, metrics, comparison, and sweep
  metric code where applicable.

### v0.1.8.1 Optional

```r
ledgr_risk_free_rate(
  annual_rate,
  label = NULL,
  source = "manual",
  as_of = NULL
)
```

The existing `risk_free_rate` argument accepts either a finite scalar annual
rate or a `ledgr_risk_free_rate` object.

### Future Or Optional In v0.1.8.1

```r
ledgr_risk_free_series(
  data,
  date_col,
  rate_col,
  rate_type = c("annualized", "period"),
  label = NULL,
  source = NULL,
  fill = c("none", "locf")
)
```

This should not be implemented casually. It needs explicit coverage and
alignment tests.

---

## 6. Internal Implementation Sketch

### Normalize Inputs

Introduce an internal normalizer:

```r
ledgr_risk_free_normalize <- function(risk_free_rate) {
  # numeric scalar -> normalized scalar provider
  # ledgr_risk_free_rate -> validate and return normalized metadata
  # ledgr_risk_free_series -> validate structural fields, alignment deferred
}
```

Normalized scalar shape:

```r
list(
  type = "scalar_annual",
  annual_rate = 0.04,
  label = "manual_4pct",
  source = "manual assumption",
  as_of = "2026-05-16",
  hash = "<sha256>"
)
```

Bare numeric input can normalize to:

```r
list(
  type = "scalar_annual",
  annual_rate = 0.04,
  label = NULL,
  source = "argument",
  as_of = NULL,
  hash = "<sha256>"
)
```

### Produce Per-Period Returns

Replace scalar-only `compute_rf_period_return()` usage with a provider helper:

```r
ledgr_rf_period_returns <- function(provider, equity, bars_per_year) {
  # returns numeric vector length nrow(equity) - 1
}
```

For scalar providers:

```r
rep((1 + annual_rate)^(1 / bars_per_year) - 1, nrow(equity) - 1)
```

For series providers:

- align provider observations to adjacent equity periods;
- convert annualized observations to period returns;
- validate complete coverage;
- return a numeric vector.

### Compute Sharpe From Vectors

Split the formula:

```r
compute_sharpe_ratio_from_excess <- function(excess_returns, bars_per_year)
```

Then:

```r
returns <- compute_period_returns(equity$equity)
rf_returns <- ledgr_rf_period_returns(provider, equity, bars_per_year)
excess_returns <- returns - rf_returns
compute_sharpe_ratio_from_excess(excess_returns, bars_per_year)
```

This preserves the current formula while making provider shape explicit.

### Carry Metric Context

`ledgr_compute_metrics()` currently returns a named list. v0.1.8.1 can attach
context:

```r
attr(metrics, "risk_free_rate") <- provider_public_summary
attr(metrics, "bars_per_year") <- bars_per_year
```

This is not execution provenance. It is metric-computation context.

If comparison tables support nonzero risk-free rates:

```r
attr(cmp, "risk_free_rate") <- provider_public_summary
attr(cmp, "bars_per_year") <- maybe_common_or_per_run_summary
```

Per-run `bars_per_year` may differ in theory. If so, use a per-row column or a
list-column only if needed. Do not imply a single global annualization value if
comparison runs use different cadences.

---

## 7. UX Details

### Summary Output

Recommended summary section:

```text
Risk Metrics:
  Risk-Free Rate:      4.00% annual
  Annualization:       252 periods/year
  Volatility (annual): 12.30%
  Sharpe Ratio:        0.845
```

For a named object:

```text
Risk Metrics:
  Risk-Free Rate:      4.00% annual (manual_4pct)
  Source:              manual assumption
  Annualization:       252 periods/year
  Volatility (annual): 12.30%
  Sharpe Ratio:        0.845
```

For a series object:

```text
Risk Metrics:
  Risk-Free Rate:      sofr_daily_export
  Source:              FRED SOFR CSV export
  Coverage:            2020-01-02 to 2024-12-31
  Annualization:       252 periods/year
  Volatility (annual): 12.30%
  Sharpe Ratio:        0.845
```

### Docs

Docs should teach:

- `risk_free_rate = 0.04` means four percent per year;
- scalar annual rates are converted geometrically to the detected bar cadence;
- the detected annualization factor is printed or recoverable;
- risk-free-rate assumptions change Sharpe-style metrics only;
- they do not change the run, fills, equity curve, config hash, or strategy
  provenance.

### Error Messages

Bad scalar:

```text
`risk_free_rate` must be a finite scalar annual rate greater than -1, a
ledgr_risk_free_rate object, or a ledgr_risk_free_series object.
```

Series coverage failure:

```text
`risk_free_rate` series does not cover all equity return periods.
Missing coverage starts at 2022-01-03.
```

Invalid series unit:

```text
`rate_type` must be "annualized" or "period".
```

---

## 8. Storage And Provenance

Risk-free-rate context is not part of run execution identity.

Do not put risk-free-rate metadata into:

- run config hash;
- strategy hash;
- snapshot hash;
- feature hash;
- sweep candidate execution seed derivation.

Acceptable places:

- attributes on metric result lists;
- attributes on comparison result tables;
- printed summary output;
- optional future metric-audit table, if ledgr decides to persist metric
  computations separately from runs.

If a future workflow stores a report artifact, it should record:

- provider type;
- scalar annual rate or series hash;
- source;
- as-of or retrieval time if available;
- bars-per-year / annualization context;
- ledgr metric formula version.

---

## 9. Open Questions

1. Should Level 2 ship in v0.1.8.1, or should v0.1.8.1 only improve scalar UX?
2. Should `ledgr_compare_runs()` accept `risk_free_rate` in v0.1.8.1?
3. Should metric lists expose `bars_per_year` as a field, an attribute, or not
   at all?
4. Should a public annualization helper or constant be exported, or is
   documentation sufficient?
5. Should Level 3 series objects be designed only, or implemented now?
6. If a time-varying series is used against intraday or weekly bars, what
   alignment rules should be accepted?
7. Should scalar `risk_free_rate = 0` print explicitly in summary output, or
   only nonzero assumptions?

---

## 10. Recommendation

For v0.1.8.1:

1. Ship Level 1 improvements.
2. Add `risk_free_rate` support to `ledgr_compare_runs()` if implementation is
   narrow.
3. Prefer shipping Level 2 if it remains a small constructor plus normalizer.
4. Design Level 3 in the docs/RFC thread, but defer implementation unless the
   ticket cut proves it can be done without opening calendar, interpolation,
   and external-provider complexity.

Defer external adapters such as FRED or central-bank providers until the
normalized risk-free-rate object shape is stable.

