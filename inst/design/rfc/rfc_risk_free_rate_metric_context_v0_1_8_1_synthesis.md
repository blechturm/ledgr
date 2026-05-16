# RFC Synthesis: Risk-Free-Rate Metric Context

**Status:** Accepted design - binding for v0.1.8.2 ticket cut and implementation.
**Date:** 2026-05-16
**Source RFC:** `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1.md`
**Reviewer response:** `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_response.md`

---

## 1. Decision Summary

The RFC direction is accepted, but the top-level primitive changes.

The design should not center on a per-call `risk_free_rate` argument. That is
too weak for ledgr's provenance model and too easy to make inconsistent across
summary, comparison, sweep, and promotion workflows.

The accepted direction is:

```text
metric_context is the user-facing metric-assumption object
metric_kernel is the internal precompiled metric machinery
```

Risk-free-rate assumptions are one field inside a broader metric context. The
metric context is metadata for analysis, not execution identity.

Core rules:

- A run stores a default metric context as run metadata.
- A comparison table has exactly one metric context.
- A sweep result table has exactly one metric context.
- Promotion context records the source sweep metric context used to compute the
  candidate table.
- Metric context never changes strategy execution, fills, equity, event
  ordering, seed derivation, snapshot hash, strategy hash, feature hash, or
  execution config hash.

Release sequencing:

- v0.1.8.2 should ship metric context and `metric_kernel` integration.
- Typed memory events and single-pass sweep summary reconstruction should move
  to the v0.1.8.3 optimization slice.
- The metric-kernel interface must therefore be stable across both shapes:
  today's `events -> equity/fills -> metrics` chain and the future single-pass
  summary helper.

---

## 2. Public UX

### Experiment Default

The preferred path is a market template:

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  metric_context = ledgr_metric_us_equity(risk_free_rate = 0.04)
)
```

The lower-level path is for users who need explicit control:

```r
ctx <- ledgr_metric_context(
  risk_free_rate = 0.04,
  calendar = ledgr_calendar_us_equity()
)

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  metric_context = ctx
)
```

Scalar shorthand should be supported for common use:

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  risk_free_rate = 0.04
)
```

The shorthand is equivalent to `ledgr_metric_context(risk_free_rate = 0.04)`,
which uses `ledgr_calendar_us_equity()` by default. The default should be
explicit in docs and printed output.

The UX priority is:

```text
market templates -> scalar shorthand -> explicit metric_context
```

`ledgr_metric_context(...)` is the composable primitive. It should not be the
first thing most users need to learn.

Implementation requirements for `ledgr_experiment()`:

- add `metric_context = NULL` and `risk_free_rate = NULL` parameters;
- `metric_context` may be `NULL` or a `ledgr_metric_context` object;
- `risk_free_rate` is a scalar shorthand and may be `NULL` or a finite annual
  scalar greater than `-1`;
- specifying both a non-NULL `metric_context` and non-NULL `risk_free_rate`
  errors because they are two ways to set the same assumption;
- `metric_context = NULL, risk_free_rate = NULL` resolves to the default metric
  context;
- the resolved metric context is added to the `ledgr_experiment` structure as
  `metric_context`;
- legacy experiment-like objects with missing or NULL `metric_context` resolve
  through `ledgr_metric_context_resolve(NULL)`.

### Metrics And Summary

The default behavior reads the run's stored metric context:

```r
summary(bt)
metrics <- ledgr_compute_metrics(bt)
```

Call-time override remains useful for sensitivity analysis:

```r
summary(bt, metric_context = ledgr_metric_context(risk_free_rate = 0.00))
metrics <- ledgr_compute_metrics(bt, metric_context = ledgr_metric_context(risk_free_rate = 0.02))
```

The override is ephemeral. It does not mutate the run's stored metric context
and should be documented as sensitivity analysis.

Implementation requirements for `ledgr_compute_metrics_internal()`:

- replace the direct `ledgr_estimate_bars_per_year()` default path with metric
  context resolution;
- if the run has stored metric context metadata, use that context's calendar to
  derive `bars_per_year`;
- if no stored metric context exists because the run predates v0.1.8.2, fall
  back to `ledgr_estimate_bars_per_year()` and mark the returned context as
  inference-based / legacy;
- call-time `metric_context` overrides the stored run context for that call
  only;
- the returned `ledgr_metrics` object carries the context that actually
  produced the values.

### Comparison

`ledgr_compare_runs()` must compute all rows under one metric context.

Mixed per-run metric assumptions inside one comparison table are rejected as a
UX model. A comparison table is an analysis view and owns one analysis context.

Preferred forms:

```r
cmp <- ledgr_compare_runs(snapshot)
cmp <- ledgr_compare_runs(snapshot, metric_context = ledgr_metric_us_equity(risk_free_rate = 0.02))
```

The existing snapshot-first workflow is the required v0.1.8.2 path. Experiment
input is useful, but it is not required for the first metric-context ticket if
it creates dispatch or compatibility risk. Users can still compare under an
experiment's context explicitly:

```r
cmp <- ledgr_compare_runs(snapshot, metric_context = ledgr_metric_context(exp))
```

Resolution rules:

1. If the first argument is a `ledgr_snapshot` and `metric_context = NULL`, use
   the default metric context.
2. If `metric_context` is supplied, use it for every row.
3. If experiment input ships in v0.1.8.2, `metric_context = NULL` uses
   `exp$metric_context`.
4. The used context is recoverable from the comparison object through an
   accessor.

The existing function may keep the first formal argument name for backward
compatibility, but the docs should describe it as accepting a snapshot or
experiment.

Mixed-cadence comparison is not supported silently. If the selected completed
runs have incompatible observed bar cadences, `ledgr_compare_runs()` should
fail loudly and instruct users to compare cadence-compatible runs separately.
If all runs appear cadence-compatible but the supplied calendar is suspicious
for the observed data, ledgr should warn rather than silently annualizing with a
likely wrong `bars_per_year`.

Known implementation target: current comparison metrics hardcode
`risk_free_rate = 0` in `ledgr_compare_runs_metric_stats()` in `R/run-store.R`.
That path must be threaded through the comparison metric context.

The required v0.1.8.2 signature change is:

```r
ledgr_compare_runs(snapshot, run_ids = NULL, include_archived = FALSE,
                   metrics = c("standard"), metric_context = NULL)
```

`metric_context = NULL` resolves to the default context. This preserves current
behavior while disclosing the assumption and removing the hidden hardcoded
`risk_free_rate = 0`.

### Sweep

`ledgr_sweep()` also owns exactly one metric context per result table:

```r
sweep <- ledgr_sweep(exp, grid)
ledgr_metric_context(sweep)
```

Every candidate metric in the sweep table is computed under that one context.
The sweep result stores that context at table level, not as a duplicated
row-level list-column.

Any sweep result reconstruction path must explicitly preserve this table-level
metric context. This applies to the current
`tibble::as_tibble(do.call(rbind, rows))` style and to the future optimized
single-pass result builder. The accessor contract must not depend on accidental
attribute retention by tibble operations.

In the current sweep builder, apply the metric-context attribute after the
tibble is built, using the same explicit post-build pattern as `sweep_id`. The
future single-pass optimization must re-apply the same attribute after any
tibble rebuild.

No separate `risk_free_rate` argument is needed on `ledgr_sweep()` if the
experiment-level model is implemented. If a later call-time override is added,
it must apply to the whole sweep table and be recorded as the sweep's metric
context.

### Promotion

Promotion records the source sweep metric context because candidate metrics and
rankings were computed under that context.

The promoted run has its own default metric context from the target experiment.
Usually train and test experiments should use the same context, but ledgr should
record rather than assume that.

The distinction is:

```text
source sweep metric_context = what produced the candidate table
run metric_context          = default analysis context for the committed run
comparison metric_context   = what produced this comparison table
```

---

## 3. Public Objects

### `ledgr_calendar`

Accepted as the public annualization primitive:

```r
ledgr_calendar(
  trading_days_per_year,
  bars_per_day = 1L
)
```

Derived:

```text
bars_per_year = trading_days_per_year * bars_per_day
```

Convenience constructors:

```r
ledgr_calendar_us_equity()
ledgr_calendar_us_equity(bars_per_day = 390L)
ledgr_calendar_crypto()
```

This avoids a single exported `252` constant that becomes wrong for intraday or
non-equity data. Summary output should print the used annualization context.

`ledgr_calendar_us_equity(bars_per_day = 390L)` is the documented US equity
minute-bar path. The constructor documentation should explain common values,
not merely expose the parameter.

This is not only new capability. It corrects an existing inference footgun.
Current code infers annualization from median bar spacing through
`snap_to_frequency()`. That table maps 60-second bars to calendar minutes per
year (`525600`) rather than US equity trading minutes (`252 * 390 = 98280`).
Daily data happens to work because the 86400-second entry is hardcoded to
`252`.

Transition policy:

1. If a metric context supplies a calendar, the calendar wins.
2. If no metric context is available, existing inference remains as a backward
   compatibility fallback.
3. The fallback inference is documented as imprecise for intraday and unusual
   calendars.
4. If a supplied calendar's `bars_per_year` is substantially less than the
   observed number of bars in the equity curve, ledgr should emit a diagnostic
   warning that the calendar may not match the data frequency and suggest the
   appropriate `bars_per_day` style fix.

Known limitation: `trading_days_per_year * bars_per_day` assumes a uniform
session model supplied by the user. It can represent US equity daily and minute
bars when `bars_per_day` is chosen correctly, but it does not model session
breaks, half-days, continuous futures sessions, or exchange-specific calendars.
Session-aware calendars remain a future extension.

### `ledgr_metric_context`

Accepted as the top-level assumption container:

```r
ledgr_metric_context(
  risk_free_rate = 0,
  calendar = ledgr_calendar_us_equity(),
  benchmark = NULL,
  market_factor = NULL,
  mar = NULL
)
```

Reserved fields are allowed to remain `NULL`. Metrics that need them should
fail loudly in the future rather than silently using defaults.

Metric-context fields:

- `risk_free_rate`: scalar annual rate or `ledgr_risk_free_rate` object now;
  future time-varying values should follow the provider contract sketched for
  `ledgr_risk_free_series`.
- `calendar`: `ledgr_calendar` object that derives `bars_per_year`.
- `benchmark`: reserved for information ratio and related metrics; future
  non-NULL values should be aligned return providers, not ticker symbols that
  trigger hidden lookup.
- `market_factor`: reserved for alpha, beta, and Treynor-style metrics; future
  non-NULL values should follow the same aligned-provider contract.
- `mar`: reserved for Sortino-style metrics; likely scalar annual or aligned
  provider, to be specified before public Sortino support.

The reusable pattern for future provider fields is:

```text
provider -> aligned numeric vector -> validated coverage -> explicit fill rule
```

Do not add hidden snapshot lookups for benchmark or market-factor fields without
a new RFC.

Thin templates are the primary UX and should ship with the metric-context
feature:

```r
ledgr_metric_us_equity(risk_free_rate = 0)
ledgr_metric_crypto(risk_free_rate = 0)
```

These should just call `ledgr_metric_context()` with market-specific defaults.

### `ledgr_risk_free_rate`

Accepted as a subordinate object, not the top-level primitive:

```r
ledgr_risk_free_rate(
  annual_rate,
  label = NULL,
  source = "manual",
  as_of = NULL
)
```

It may be used as the `risk_free_rate` field inside `ledgr_metric_context`.

The `as_of` value must be validated and normalized, preferably to `Date`.
Hashing must use ledgr's internal `canonical_json()` helper and must define how
optional `NULL` fields are represented.

### `ledgr_risk_free_series`

Design only for v0.1.8.2 unless implementation remains clearly bounded.

Time-varying series introduce alignment, fill, timezone, coverage, and calendar
edge cases. The object shape should be designed in the RFC thread, but the
implementation should be deferred unless the ticket cut explicitly proves it is
safe.

External data adapters such as FRED or central-bank providers are deferred.

---

## 4. Storage And Identity

Metric context should be stored as metadata, not execution identity.

Runs created after this feature must store a metric context. Runs created
before this feature have a defined fallback: accessors return a default metric
context with `risk_free_rate = 0` and the backward-compatible inferred
annualization when that can be recovered, otherwise the default calendar.
Accessors must return a complete metric context object, not `NULL`.

Transfer point:

- `ledgr_run()` stores the resolved experiment metric context as run metadata at
  run creation / successful run finalization time.
- `ledgr_compute_metrics()` must not be the first place that persists this
  context; metric context is an experiment/run analysis assumption, not a lazy
  metric artifact.
- If the context write fails after a run succeeds, warn and keep the successful
  run rather than rolling back execution artifacts.

Accepted storage model for v0.1.8.2:

```text
metric_context_json
metric_context_hash
metric_context_version
```

Add these as columns on the existing `runs` table, consistent with how
`config_json` and related run metadata are stored today. A separate
`run_metric_context` table can be extracted later if query patterns justify it.

`metric_context_version` is the schema version of the serialized
`ledgr_metric_context` JSON format. It is an integer; the initial value is `1`.
It is not the ledgr package version and not a formula hash.

`metric_context_hash` is computed with ledgr's internal `canonical_json()`
helper over
the normalized `ledgr_metric_context` fields. NULL reserved fields are omitted
from the hash input. `ledgr_risk_free_rate$as_of` must be normalized to an ISO
date string before hashing. The same logical metric context must produce the
same hash regardless of list insertion order.

The exact storage shape is an implementation decision. The design requirement
is that the context is recoverable from a run and excluded from execution
identity.

Do not include metric context in:

- execution config hash;
- strategy hash;
- snapshot hash;
- feature-set hash;
- sweep execution seed derivation.

Metric context may appear in:

- run metadata;
- metric result context;
- comparison result context;
- sweep result metadata;
- promotion context;
- printed output.

---

## 5. Accessor Contract

Attributes alone are too fragile as a public contract. They may be used
internally, but users need an accessor.

Accepted public accessor:

```r
ledgr_metric_context(x)
```

Recommendation: use S3 dispatch with one public name. The same generic is the
constructor when called with named assumption arguments and the accessor when
called with a ledgr object as the first argument. This is concise and consistent
with ledgr's explicit context helpers. Do not create
`ledgr_metric_context_used()` unless implementation review finds a real
dispatch ambiguity.

Accessor targets:

- `ledgr_experiment`
- `ledgr_backtest`
- `ledgr_metrics`
- `ledgr_comparison`
- `ledgr_sweep_results`
- promotion context objects, if useful

`ledgr_compute_metrics()` should return a small classed object, e.g.
`ledgr_metrics`, rather than an unclassed list in v0.1.8.2. This closes the
accessor contract: `ledgr_metric_context(metrics)` dispatches on the classed
metric result. The object should remain list-like enough for existing code that
uses `$` or `[[` to keep working.

---

## 6. Sweep Performance Constraint

Metric context must not make no-DB sweep slower in the candidate loop.

Accepted internal pattern:

```text
metric_context -> metric_kernel
```

Interface contract:

```text
any function that consumes equity/fills/events to produce metrics accepts
metric_kernel
```

In v0.1.8.2 this means `ledgr_metrics_from_equity_fills()` accepts
`metric_kernel`. In the future typed-memory-events optimization, the
single-pass summary helper accepts the same `metric_kernel` input. The metric
context work must not force a second metrics API change when the single-pass
helper lands.

At sweep start:

```r
metric_context <- ledgr_metric_context_resolve(exp$metric_context)
metric_kernel <- ledgr_metric_kernel(
  context = metric_context,
  pulses = pulses_posix
)
```

`metric_kernel` replaces the standalone `bars_per_year` parameter in the sweep
candidate path. After this migration, `bars_per_year` is removed from the
`ledgr_sweep_run_candidate()` signature and not passed separately.
Annualization is read from `metric_kernel$bars_per_year` so there is exactly
one source of metric cadence truth.

Minimum `metric_kernel` structure:

```r
list(
  metric_context = normalized_context_plain_list,
  metric_context_hash = "<sha256>",
  metric_context_version = 1L,
  bars_per_year = 252,
  rf_period_return = 0,
  calendar = normalized_calendar_plain_list
)
```

The `metric_context` and `calendar` fields inside the kernel are plain lists
with class attributes stripped. Full classed objects remain available through
result accessors, not from the kernel directly. This keeps `metric_kernel`
serialization-safe for future worker dispatch.

For scalar risk-free rates, `rf_period_return` is a numeric scalar computed as:

```text
(1 + annual_rate)^(1 / bars_per_year) - 1
```

For future series providers, `rf_period_return` may be a numeric vector aligned
to the equity return periods.

`ledgr_metric_context_resolve(NULL)` returns the default
`ledgr_metric_context()`, currently `risk_free_rate = 0` with the default
calendar. If a legacy path has no explicit calendar but has pulses/equity
timestamps, the kernel may use backward-compatible inference for
`bars_per_year`; otherwise it uses the default calendar.

`pulses` in `ledgr_metric_kernel(context, pulses)` has four roles:

- when `context` carries an explicit calendar, the calendar determines
  `bars_per_year`;
- when no explicit calendar is available on a legacy/default path, pulses may
  be used for fallback inference;
- when a supplied calendar looks inconsistent with observed data, pulses support
  the diagnostic warning;
- future series providers use pulses for temporal alignment, but annualization
  still comes from the calendar.

Per candidate:

```r
metrics <- ledgr_metrics_from_equity_fills(
  equity,
  fills,
  metric_kernel = metric_kernel
)
```

For scalar risk-free rates, the per-period risk-free return scalar/vector is
computed once per sweep and reused. For future series providers, alignment to
the sweep pulse calendar must also happen once per sweep, not once per
candidate.

For Level 3 series providers, alignment happens in `ledgr_metric_kernel()` at
sweep setup time before the candidate loop. The aligned risk-free return vector
is stored in the kernel as a plain numeric vector. There must be no DuckDB
access, file access, provider lookup, or alignment work inside the candidate
loop or per pulse.

The metric kernel must be serialization-safe for future parallel sweep. It
must be a plain named list with no R environment captures, no active bindings,
no closures that carry mutable state, no live connections, no external
pointers, and no reference semantics. For scalar risk-free rates this is just
metadata plus a precomputed period return and `bars_per_year`. For Level 3
providers, the aligned per-period return vector must also be a plain numeric
vector before candidate dispatch.

This keeps the fold core independent:

```text
fold core -> events/equity/fills -> metric kernel -> candidate summary row
```

Metric context is post-fold analysis. It must not enter strategy context, target
validation, fill timing, or execution state transitions.

---

## 7. Summary Output

Summary output should always disclose the metric context enough to interpret
Sharpe:

```text
Risk Metrics:
  Risk-Free Rate:      0.00% annual
  Annualization:       252 periods/year (US equity daily)
  Volatility (annual): 12.30%
  Sharpe Ratio:        0.845
```

For a named rate:

```text
Risk-Free Rate:      4.00% annual (manual_4pct)
```

The zero assumption should print explicitly. This resolves auditr's finding
that users cannot tell whether Sharpe used a nonzero or default risk-free rate.

For custom calendars, print the decomposition rather than only the product:

```text
Annualization:       98280 periods/year (252 trading days * 390 bars/day)
```

Sensitivity analysis is intentionally manual in v0.1.8.2. To compare the same
runs under several metric contexts, users should call `ledgr_compare_runs()`
once per context, add an assumption label column, and bind the resulting
tables. A convenience sensitivity wrapper is future work.

---

## 8. Revised v0.1.8.2 Scope

Ship in v0.1.8.2 if accepted at ticket cut:

- `ledgr_calendar()`;
- `ledgr_calendar_us_equity()`;
- `ledgr_calendar_crypto()`;
- `ledgr_metric_context()`;
- `ledgr_metric_us_equity()`;
- `ledgr_metric_crypto()`;
- `ledgr_experiment(metric_context = ..., risk_free_rate = ...)`;
- run metadata storage for metric context;
- classed `ledgr_metrics` results;
- summary and metric computation using run/experiment metric context by
  default;
- `ledgr_compare_runs(..., metric_context = NULL)` using one comparison-level
  metric context;
- `ledgr_sweep()` using one sweep-level metric context;
- promotion context records source sweep metric context;
- metric-kernel interface compatible with both the current summary chain and a
  future single-pass summary helper;
- docs explaining annualization and risk-free assumptions.

Maybe ship if small:

- `ledgr_risk_free_rate()` named scalar assumption object.

Design only:

- `ledgr_risk_free_series()`;
- alignment/fill rules for time-varying series;
- external adapters.

Defer:

- FRED/central-bank fetchers;
- benchmark-relative metrics;
- alpha/beta/Treynor/Sortino public metrics;
- persisted metric audit history beyond the run default context;
- automatic inference of intraday calendar semantics from bar density;
- typed memory events and single-pass sweep summary reconstruction unless
  explicitly pulled forward as a co-designed optimization ticket.

---

## 9. Corrections To Reviewer Response

The reviewer response correctly identifies the need for experiment-level metric
context and composable annualization. Two points need adjustment:

1. `ledgr_compare_runs()` currently accepts a snapshot, not an experiment. The
   synthesis therefore supports both experiment and snapshot inputs rather than
   assuming the experiment form already exists.
2. `metrics = "standard"` is already part of the current public surface. It is
   not a new RFC proposal.
3. `ledgr_compare_runs_metric_stats()` currently hardcodes
   `risk_free_rate = 0`; this is the concrete comparison-path implementation
   site that must consume the comparison metric context.

---

## 10. Remaining Ticket-Cut Choices

1. Should `ledgr_risk_free_rate()` ship in v0.1.8.2 or be deferred behind the
   broader metric-context implementation?
2. The default calendar for v0.1.8.2 is `ledgr_calendar_us_equity()`,
   preserving current daily-equity behavior. Crypto, international, and
   intraday users must pass an explicit template or calendar; docs must make
   this visible.
3. Should experiment input for `ledgr_compare_runs(exp, ...)` ship in
   v0.1.8.2 or be deferred behind the required snapshot-first
   `metric_context` argument?
