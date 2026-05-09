# ledgr v0.1.7.7 Spec

**Status:** Draft
**Target Version:** v0.1.7.7
**Scope:** Risk metric contract, Sharpe-style metric semantics,
PerformanceAnalytics parity checks, comparison-table numeric metrics, small
documentation/branding cleanup
**Inputs:**

- `inst/design/ledgr_roadmap.md`
- `inst/design/contracts.md`
- `inst/design/ledgr_v0_1_7_6_spec_packet/duckdb_architecture_review.md`
- `inst/design/ledgr_v0_1_7_6_spec_packet/auditr_v0_1_7_5_followup_plan.md`
- `inst/design/ledgr_v0_1_7_7_spec_packet/ledgr.svg`
- `vignettes/metrics-and-accounting.Rmd`
- `R/backtest.R`
- `R/run-store.R`
- `tests/testthat/test-metric-oracles.R`

---

## 1. Purpose

v0.1.7.7 defines ledgr's first explicit risk-adjusted metric contract before
v0.1.8 sweep mode needs stable ranking and scoring semantics.

The current standard metric set already covers:

- total return;
- annualized return;
- annualized volatility;
- max drawdown;
- number of closed trades;
- win rate;
- average trade;
- time in market.

It does not yet include Sharpe ratio or any other risk-adjusted metric. It also
does not yet expose raw numeric comparison columns alongside formatted display
strings for every metric users will rank by.

The release should make ledgr's metric layer small, auditable, frequency-safe,
and reusable by future sweep results. It must not turn ledgr into a metric zoo
or make `{PerformanceAnalytics}` the source of ledgr's canonical definitions.

---

## 1.1 Evidence Baseline

| Evidence | Classification | v0.1.7.7 handling |
| --- | --- | --- |
| Missing Sharpe-style metric | Product/API gap before sweep ranking | Define and preferably ship a ledgr-owned Sharpe ratio. |
| Risk-free-rate semantics | Contract gap | Define scalar annual rate handling and the future provider boundary. |
| Intraday/tick future support | Design footgun risk | Metrics must be frequency-safe and must not hard-code daily assumptions. |
| Formatted comparison values | UX/API friction | Add raw numeric companion columns so ranking does not require string parsing. |
| `{PerformanceAnalytics}` overlap | Interoperability opportunity | Use as optional parity oracle where definitions match; defer public adapter. |
| Real risk-free-rate data | Future adapter work | Defer FRED/Treasury/ECB/reference-data adapters to a later milestone. |
| `ledgr_snapshot_from_yahoo()` sealed-handle ambiguity | Documentation mismatch | Clarify returned handle is already sealed. |
| `ledgr_snapshot_seal()` sealed-idempotence behavior | Documentation mismatch | Document idempotent already-sealed behavior. |
| `quantmod` startup/S3 messages | Expected dependency noise with weak messaging | Document harmless stderr messages in Yahoo snapshot help. |
| Stored strategy extraction is under-promoted | Documentation/product-positioning gap | Make `ledgr_extract_strategy()` visible in README and experiment-store docs. |
| New `ledgr.svg` asset | Branding/docs requirement | Place optimized package logo in README and pkgdown assets. |

---

## 2. Release Shape

v0.1.7.7 has five coordinated tracks.

### Track A - Risk Metric Contract

Define the ledgr-owned risk metric contract. The preferred implementation is a
Sharpe ratio computed over excess returns. If Sharpe is deferred, the deferral
must be explicit and v0.1.8 sweep ranking must be unblocked by another
documented scoring mechanism.

### Track B - Metric Implementation And Oracles

Implement the chosen ledgr-owned metric definitions and independent oracle
tests over public result tables. Metrics must remain derived from public ledgr
tables, not hidden runner state.

### Track C - PerformanceAnalytics Parity, Not Adapter

Use `{PerformanceAnalytics}` as an optional external parity oracle where
definitions match. Do not expose a public PerformanceAnalytics adapter in this
release.

### Track D - Comparison, Provenance, And Documentation Hygiene

Expose raw numeric comparison columns for programmatic ranking and close the
small snapshot/Yahoo documentation gaps carried forward from the v0.1.7.5
retrospective. Make stored strategy extraction more prominent because it is a
distinctive part of ledgr's provenance story.

### Track E - Logo Placement

Promote the new logo from design-packet source asset into package-visible
documentation assets. The GitHub README and pkgdown site must show the logo.

---

## 3. Hard Requirements

### R1 - Ledgr Owns Its Core Metric Definitions

Core metrics must be computed by ledgr from public result tables. External
packages may be used for optional parity tests or examples, but they must not be
the canonical implementation of ledgr-owned metrics.

The public result tables are:

- `ledgr_results(bt, what = "equity")`;
- `ledgr_results(bt, what = "trades")`;
- `ledgr_results(bt, what = "fills")`;
- `ledgr_results(bt, what = "ledger")`.

There is still no `ledgr_results(bt, what = "metrics")` result table.

### R2 - Sharpe-Style Metrics Use Excess Returns

Any shipped Sharpe-style metric must be computed over period excess returns:

```text
excess_return[t] = equity_return[t] - rf_period_return[t]
```

The formula consumes a pulse-aligned per-period risk-free return vector. A
scalar annual risk-free rate is only the first provider for that vector. It is
not a separate formula branch.

### R3 - Frequency Safety

Metrics must not silently assume daily bars.

The annualization contract must either:

- reuse ledgr's detected `bars_per_year` convention with documented semantics;
- require an explicit user/provider value; or
- fail/defer loudly when the cadence cannot be interpreted safely.

The design must remain valid for future weekly, intraday, and tick/pulse data.

### R4 - Risk-Free Rate Scope Is Explicit

v0.1.7.7 must explicitly state what risk-free-rate support ships.

At minimum, the contract must define:

- default risk-free rate;
- scalar annual rate units;
- conversion from scalar annual rate to per-period return;
- whether time-varying risk-free series are shipped or deferred.

Real data providers such as FRED, Treasury, ECB, or other central-bank sources
are out of scope for this milestone.

### R5 - Edge Cases Are Defined

Metrics must define behavior for:

- zero trades;
- flat equity;
- constant returns;
- zero or near-zero volatility;
- short samples;
- all-`NA` or partially missing return inputs after public-table derivation.

Infinite Sharpe-style values must not be emitted silently for flat or
near-flat series.

### R6 - PerformanceAnalytics Is Optional And Read-Only

`{PerformanceAnalytics}` may be used only as an optional test oracle or
documentation reference in v0.1.7.7.

Requirements:

- no mandatory dependency;
- tests skip cleanly when absent;
- no public PerformanceAnalytics adapter;
- no mutation of ledgr stores;
- no effect on config hashes, data hashes, run identity, or snapshot hashes.

### R7 - Comparison Output Remains Programmatic

`ledgr_compare_runs()` must expose raw numeric values for ranking and filtering.
Formatted percentage strings may remain a print concern, but users must not need
to parse strings such as `"+5.2%"` to rank runs.

### R8 - Stored Strategy Extraction Is A First-Class Provenance Story

`ledgr_extract_strategy()` is one of ledgr's clearest differentiators: a user can
inspect the strategy source associated with a completed run from the sealed
experiment store, without rerunning the strategy and without trusting the stored
source by default.

Documentation must show this earlier and more prominently. The trust boundary
must remain explicit:

- `trust = FALSE` is the safe inspection default;
- `trust = TRUE` verifies the stored source hash before parsing/evaluating;
- hash verification proves identity of stored text, not code safety;
- legacy/pre-provenance runs may not have recoverable source.

### R9 - Logo Asset Is Package-Visible

The source logo may remain in the design packet. Package-facing assets must live
in a package-visible documentation location, preferably `man/figures/`.

The GitHub README and pkgdown site must show the logo without requiring a local
absolute path.

---

## 4. Track A Scope - Risk Metric Contract

### A1 - Metric Inventory

Document the metric inventory for v0.1.7.7.

Acceptance points:

- shipped metrics are listed explicitly;
- deferred metrics are listed explicitly;
- Sharpe is either shipped or explicitly deferred with a public rationale;
- Sortino, Calmar, Omega, information ratio, alpha/beta, benchmark-relative
  metrics, and VaR/tail metrics are either scoped or deferred;
- the decision is reflected in `metrics-and-accounting` documentation.

### A2 - Return Series Contract

Define the return series used by risk metrics.

Preferred contract:

```text
equity_return[t] = equity[t] / equity[t - 1] - 1
```

where `equity` comes from adjacent public equity rows.

Acceptance points:

- first public equity row is the base and does not produce a return;
- return timestamps are documented;
- missing, duplicate, or unordered public rows are handled defensively;
- the same return series feeds volatility, Sharpe, and any optional parity
  checks.

### A3 - Risk-Free Provider Boundary

Define an internal provider boundary that returns a per-period risk-free return
vector aligned to the return series.

Acceptance points:

- scalar annual risk-free rate provider exists if Sharpe ships;
- default risk-free rate is documented;
- conversion to per-period return uses the same annualization convention as the
  metric;
- time-varying rate series are shipped or explicitly deferred;
- the boundary is designed so v0.1.8.1 reference-data adapters can feed the same
  formula without changing Sharpe semantics.

### A4 - Frequency And Annualization

Define frequency behavior.

Acceptance points:

- `bars_per_year` source is documented;
- daily, weekly, intraday, and unknown cadence behavior is documented;
- metric identity and public semantics do not hard-code daily assumptions;
- tests cover at least daily-like and non-daily-like cadence, or document why
  non-daily is deferred loudly.

### A5 - Edge-Case Semantics

Define edge-case behavior.

Acceptance points:

- zero-volatility and near-zero-volatility behavior is deterministic;
- short samples return `NA_real_` or a documented classed condition, not
  misleading numeric values;
- zero-trade runs still compute equity-derived metrics where valid;
- tests cover flat equity, constant returns, and short samples.

---

## 5. Track B Scope - Implementation And Oracles

### B1 - Ledgr-Native Metric Implementation

Implement the shipped metric definitions inside ledgr's metric layer.
`ledgr_compute_metrics()` is already an exported public API; v0.1.7.7 extends
its `"standard"` metric set rather than introducing a new metric entry point.

Acceptance points:

- `ledgr_compute_metrics(bt)` exposes the new metric consistently;
- `summary(bt)` prints the new metric when available;
- the implementation derives from public result tables or the same internal
  helpers already used to produce those public tables;
- no metric computation mutates ledgr stores.

### B2 - Independent Oracle Tests

Extend public-table metric oracles.

Acceptance points:

- tests recompute every shipped metric independently from public tables;
- oracle code does not call the production metric helper under test;
- edge cases from A5 are covered;
- all tests run without optional packages.

### B3 - Metrics API Surface

Decide whether `ledgr_compute_metrics()` remains the only public metric helper
or whether a return-series helper is needed.

Acceptance points:

- if `ledgr_as_returns()` or equivalent is exported, it is documented as a
  return-series conversion helper, not a PerformanceAnalytics adapter;
- if it remains internal, the decision is recorded and parity tests can still
  use the internal return-series builder;
- no public adapter namespace is introduced for `{PerformanceAnalytics}`.

---

## 6. Track C Scope - PerformanceAnalytics Parity

### C1 - Optional Dependency Policy

Use `{PerformanceAnalytics}` only in optional tests.

Acceptance points:

- package is in `Suggests` only if needed;
- tests use `testthat::skip_if_not_installed("PerformanceAnalytics")`;
- absence of the package does not affect ledgr metric output;
- dependency versions do not enter run identity.

### C2 - Parity Targets

Compare only metrics whose definitions can be aligned.

Candidate parity checks:

- annualized return;
- annualized standard deviation / volatility;
- Sharpe ratio if shipped;
- max drawdown only if sign convention and compounding assumptions are explicit.

Acceptance points:

- each parity test names the exact PerformanceAnalytics function used;
- each test passes explicit annualization scale rather than relying on implicit
  periodicity inference;
- risk-free-rate units are aligned before comparison;
- any sign convention difference is normalized in the test, not hidden.

### C3 - Adapter Deferral

Record that a public PerformanceAnalytics adapter is deferred to a later
milestone.

Acceptance points:

- roadmap points to post-sweep PerformanceAnalytics interoperability;
- v0.1.7.7 docs explain that parity checks do not make PerformanceAnalytics a
  ledgr runtime dependency;
- no exported `ledgr_metrics_performanceanalytics()` or similar adapter is added.

---

## 7. Track D Scope - Comparison, Provenance, And Documentation Hygiene

### D1 - Raw Numeric Comparison Columns

Add raw numeric companion columns to `ledgr_compare_runs()` output.

Acceptance points:

- users can rank by numeric total return, max drawdown, and any shipped risk
  metric without parsing display strings;
- print methods may still show formatted percentages;
- full tibble output preserves raw columns;
- tests cover both raw data access and printed display.

### D2 - Snapshot/Yahoo Documentation Corrections

Close the three known documentation gaps.

Acceptance points:

- `?ledgr_snapshot_from_yahoo` states the returned handle is already sealed;
- `?ledgr_snapshot_seal` documents idempotent behavior on already-sealed
  handles;
- `?ledgr_snapshot_from_yahoo` notes that `quantmod` can emit harmless startup
  and S3-method-overwrite messages to stderr during fetches;
- rendered documentation and Rd files agree.

### D3 - Strategy Extraction Prominence

Make `ledgr_extract_strategy()` visible as a core provenance feature.

Recommended placement:

- README: add a compact Durable Research example after `ledgr_run_list()` or
  `ledgr_compare_runs()` showing `ledgr_extract_strategy(snapshot, run_id,
  trust = FALSE)`;
- experiment-store vignette: add a short "Inspect Stored Strategy Source"
  subsection after run info/compare and before reopen;
- strategy-development vignette: keep or strengthen the existing late example as
  the strategy-authoring angle;
- reference docs: ensure `?ledgr_extract_strategy` links to the experiment-store
  and strategy-development articles.

Acceptance points:

- docs show source inspection from a completed run without rerunning strategy
  code;
- `trust = FALSE` appears in the first example;
- trust-boundary prose explains that stored source is provenance, not inherently
  safe code;
- legacy/pre-provenance limitations are mentioned where the feature is taught;
- documentation contract tests pin the main article links and the safe default
  example.

### D4 - Metrics Documentation

Update metrics-and-accounting documentation.

Acceptance points:

- formulas are shown for shipped risk metrics;
- risk-free-rate assumptions are explicit;
- annualization and cadence caveats are explicit;
- edge cases are described;
- PerformanceAnalytics is framed as optional parity/interoperability, not the
  source of ledgr's metric contract.

---

## 8. Track E Scope - Logo Placement

### E1 - Source And Package Assets

The source logo is:

```text
inst/design/ledgr_v0_1_7_7_spec_packet/ledgr.svg
```

The package-facing assets should be placed under `man/figures/`. Prefer SVG as
the committed README/pkgdown asset. Generate a PNG only if GitHub or pkgdown
rendering proves the SVG unsuitable after local verification.

Acceptance points:

- original source asset remains in the design packet;
- package-facing SVG logo asset exists in `man/figures/`;
- asset size is reasonable for README/pkgdown use;
- any raster derivative is generated and committed only if needed for
  README/pkgdown compatibility; it must not be a local build artifact.

### E2 - README Placement

Acceptance points:

- `README.Rmd` includes the logo near the top using a relative path;
- `README.md` is regenerated and renders the same logo on GitHub;
- the logo does not obscure or replace the package title.

### E3 - pkgdown Placement

Acceptance points:

- pkgdown site displays the logo;
- `_pkgdown.yml` is updated only if the default `man/figures` convention is
  insufficient;
- local pkgdown build verifies the logo path.

---

## 9. Non-Goals

v0.1.7.7 must not implement:

- a full performance-analytics metric zoo;
- a public `{PerformanceAnalytics}` adapter;
- FRED, Treasury, ECB, central-bank, or other risk-free-rate data adapters;
- arbitrary user-supplied risk-free time series;
- sweep, tune, or parallel execution APIs;
- strategy reproducibility preflight;
- `{talib}` indicator adapter work;
- target-risk layer APIs.

External adapter PRs may land opportunistically when they satisfy ledgr's
adapter contracts, but they are not release drivers for v0.1.7.7.

---

## 10. Documentation Contract Updates

Documentation contract tests should pin the user-facing decisions that matter:

- metrics-and-accounting documents Sharpe-style formula and risk-free-rate
  assumptions;
- PerformanceAnalytics is optional parity/interoperability, not canonical
  metric source;
- `ledgr_compare_runs()` preserves raw numeric columns for ranking;
- snapshot/Yahoo docs include the three corrections from D2;
- README and experiment-store docs show `ledgr_extract_strategy(..., trust =
  FALSE)` as the safe stored-strategy inspection path;
- README/pkgdown logo assets exist and are referenced through repository-relative
  paths.

Avoid brittle tests for cosmetic wording unless the wording is itself the
contract.

---

## 11. Verification Plan

Targeted checks:

```r
pkgload::load_all(".", quiet = TRUE)
testthat::test_file("tests/testthat/test-metric-oracles.R")
testthat::test_file("tests/testthat/test-run-compare.R")
testthat::test_file("tests/testthat/test-documentation-contracts.R")
```

Optional parity check when installed:

```r
testthat::test_file("tests/testthat/test-metrics-performanceanalytics.R")
```

Release-gate checks:

- full Windows test suite;
- R CMD check;
- coverage threshold;
- pkgdown build;
- remote Ubuntu and Windows CI.

If any DuckDB persistence, schema, snapshot, or runner files are touched beyond
metric reads, follow the v0.1.7.6 release CI playbook and run the DuckDB-sensitive
gate before pushing.

---

## 12. Definition Of Done

- Shipped and deferred risk-adjusted metrics are explicitly listed.
- Sharpe ratio ships with documented semantics, or its deferral publicly records
  the alternate v0.1.8 scoring path.
- Shipped Sharpe-style metrics are computed from excess returns through a
  risk-free-rate provider boundary.
- Scalar annual risk-free-rate handling is documented and tested if Sharpe
  ships.
- Time-varying risk-free rates are explicitly shipped or explicitly deferred.
- Metric definitions are frequency-safe and avoid silent daily-only assumptions.
- `ledgr_compute_metrics()`, `summary(bt)`, and `ledgr_compare_runs()` expose
  shipped metrics consistently.
- `ledgr_compare_runs()` supports programmatic ranking through raw numeric
  columns.
- Public-table oracle tests cover every shipped metric.
- Optional `{PerformanceAnalytics}` parity tests cover matching definitions
  where practical and skip cleanly when absent.
- Edge cases are tested: zero trades, flat equity, constant returns, near-zero
  volatility, and short samples.
- Metrics documentation explains formulas, risk-free-rate assumptions, and
  ecosystem interoperability posture.
- Snapshot/Yahoo documentation gaps are closed.
- `ledgr_extract_strategy()` is shown prominently as a safe provenance
  inspection path in README and the experiment-store article.
- README and pkgdown show the ledgr logo from package-visible assets.
- Ubuntu and Windows CI are green.
