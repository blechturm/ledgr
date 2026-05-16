# RFC Response: Risk-Free-Rate Metric Context

**Status:** Reviewer response — substantially revised after UX assessment.
**Date:** 2026-05-16
**RFC:** `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1.md`
**Reviewer:** Codex

---

## Overall Assessment

The RFC is well-structured and its three-level progressive design is correct in
direction. The architectural boundaries are correctly drawn: risk-free-rate
affects metrics only, never execution identity, config hashes, or snapshot
provenance. The deferred adapter layer is correctly deferred.

The implementation sketch is clean. The normalizer-first approach and the Sharpe
split into `compute_sharpe_ratio_from_excess()` are both correct.

However, the RFC accepts a per-call API model without questioning it. That model
is architecturally wrong. Passing `risk_free_rate` independently to
`ledgr_compute_metrics()`, `summary()`, `ledgr_compare_runs()`, and
`ledgr_sweep()` does not give the user a consistent, auditable assumption — it
gives them four separate entry points where the assumption can silently diverge.
The RFC also proposes `ledgr_risk_free_rate()` as the primary named primitive,
but that is too narrow. Sharpe is one metric. Information ratio, Sortino, alpha,
Treynor all need external inputs too. Building a separate named object per input
does not scale.

Six gaps need resolution before ticket cut. The first two are architectural
rethinks, not incremental additions. The remaining four are the original gaps,
carried forward.

---

## Gap 1: The Per-Call Model Is Wrong

The RFC proposes:

```r
summary(bt, risk_free_rate = 0.04)
ledgr_compute_metrics(bt, risk_free_rate = 0.04)
ledgr_compare_runs(exp, risk_free_rate = 0.04)
ledgr_sweep(exp, ..., risk_free_rate = 0.04)
```

This means: no canonical place where assumptions live, no consistency
guarantee across surfaces, and nothing in the sweep result or promotion context
that records which rate produced the Sharpe values used to rank candidates.

The correct home for metric assumptions is the experiment, not the call site.

**Recommended model:**

```r
# L0: bare experiment — zero assumption everywhere, printed explicitly
exp <- ledgr_experiment(...)

# L1: scalar shorthand on the experiment
exp <- ledgr_experiment(..., risk_free_rate = 0.04)

# L2: template shorthand
exp <- ledgr_experiment(..., metric_context = ledgr_metric_us_equity())

# L3: full constructor
exp <- ledgr_experiment(..., metric_context = ledgr_metric_context(
  risk_free_rate = 0.04,
  calendar = ledgr_calendar_us_equity()
))
```

Under this model:

- `ledgr_compute_metrics(bt)` uses `exp$metric_context` by default.
- `summary(bt)` uses the same context.
- `ledgr_compare_runs(exp)` uses the experiment's context.
- `ledgr_sweep(exp)` uses the experiment's context for every candidate Sharpe.
- Promotion context records which `metric_context` produced the ranking.
- Call-time override is still allowed for sensitivity analysis but is explicitly
  ephemeral and does not alter the experiment record.

The experiment-level home solves all of the following at once:

- `ledgr_sweep()` and `ledgr_compute_metrics()` are consistent by
  construction, not by convention.
- Summary output correctly reflects the assumption that was actually used.
- Promoted-run metadata can record the metric context without a separate
  attachment step.
- Future adapters (FRED, central bank series) produce `ledgr_metric_context`
  objects that slot into the experiment like any other; no new call-site
  arguments needed.

**Snapshot boundary clarification.** The RFC correctly excludes risk-free rate
from the snapshot (execution identity). That boundary must hold. Metric context
belongs to the experiment record, not the sealed market-data snapshot. When a
future time-varying series is used, it belongs to the experiment's
`metric_context`, not to the snapshot, unless a future RFC explicitly argues
otherwise. Do not dissolve this boundary.

**Required change.** `ledgr_experiment()` should accept `metric_context`
(and optionally a `risk_free_rate` scalar shorthand). The per-call `risk_free_rate`
argument on metric functions may remain as a call-time override but should be
documented as ephemeral sensitivity analysis, not the primary path.

---

## Gap 2: `ledgr_risk_free_rate()` Is Too Narrow For The Metric Zoo

The RFC proposes `ledgr_risk_free_rate()` as the named assumption primitive.
This is the right instinct, but the wrong scope.

Sharpe needs `risk_free_rate` and `bars_per_year`. Information ratio needs
`benchmark`. Sortino needs a minimum acceptable return (`mar`). Alpha and
Treynor need a `market_factor`. These metrics are not exotic — they are the
natural next steps after Sharpe.

If each new metric gets its own named object type, the API grows
proportionally. If each object is passed per-call to each metric function, the
surfaces diverge. Neither scales.

**Recommended primitive:** `ledgr_metric_context` — an extensible container for
all metric computation assumptions.

```r
ledgr_metric_context(
  risk_free_rate = 0,           # scalar or future ledgr_risk_free_rate object
  calendar = ledgr_calendar_us_equity(),
  benchmark = NULL,             # reserved for information ratio
  market_factor = NULL,         # reserved for alpha, Treynor
  mar = NULL                    # reserved for Sortino
)
```

Reserved fields for future metrics default to `NULL`. Metric functions that
need them fail loudly if the relevant field is `NULL` when they are called.
Metric functions that do not need them ignore them. No behavioral surprise.

The `ledgr_risk_free_rate()` object proposed in the RFC's Level 2 remains
useful as a named, hashable assumption object accepted by the `risk_free_rate`
field. It is not the top-level primitive; it is one field value within
`ledgr_metric_context`.

**Templates as the primary UX path.**

Most users should never construct `ledgr_metric_context` by hand:

```r
ledgr_metric_us_equity()
# risk_free_rate = 0, calendar = US equity daily (252 trading days, 1 bar/day)

ledgr_metric_us_equity(risk_free_rate = 0.04)
# same calendar, nonzero assumption

ledgr_metric_crypto()
# risk_free_rate = 0, calendar = 365 days, 1 bar/day

ledgr_metric_crypto(risk_free_rate = 0.02)
```

Templates are thin constructors that call `ledgr_metric_context` with
market-specific defaults. Users who need intraday or non-standard cadences use
the composable calendar (see Gap 3) rather than a magic constant buried in the
template.

The `ledgr_metric_context()` accessor (see Gap 4) remains the retrieval path
for all computed results.

---

## Gap 3: `bars_per_year` Detection Must Be Composable, Not Inferred

The RFC shows `Annualization: 252 periods/year` in summary output and uses
`bars_per_year` throughout, but never explains where this value comes from.

The deeper problem is that 252 is a hardcoded daily equity constant. An
intraday user running minute bars gets the wrong annualization factor if ledgr
infers cadence from bar density without understanding that each trading day
contains 390 minutes, not 1 bar.

**Formula dependence.** The geometric conversion
`(1 + rf_annual)^(1 / bars_per_year) - 1` and the Sharpe annualization
`sqrt(bars_per_year)` both depend on `bars_per_year`. The value must be
explicit, not inferred.

**Recommended primitive:** composable calendar.

```r
ledgr_calendar(
  trading_days_per_year,     # integer, e.g. 252L
  bars_per_day = 1L          # integer, default 1 for daily data
)
# bars_per_year = trading_days_per_year * bars_per_day
```

Convenience constructors for common markets:

```r
ledgr_calendar_us_equity()
# trading_days_per_year = 252L, bars_per_day = 1L
# bars_per_year = 252

ledgr_calendar_us_equity(bars_per_day = 390L)
# bars_per_year = 98280
# correct for US equity minute bars

ledgr_calendar_crypto()
# trading_days_per_year = 365L, bars_per_day = 1L

ledgr_calendar(260L)
# user-specified, e.g. calendar year with more trading days
```

`bars_per_day = 1L` as the default means: existing daily users pass nothing
extra. Intraday users pass their bar frequency once. No inference from bar
density, no footgun when cadences mix.

The `ledgr_calendar` object carries `trading_days_per_year`, `bars_per_day`,
and the derived `bars_per_year`. It is a field on `ledgr_metric_context`. The
detected and used `bars_per_year` appears in summary output and in the
`ledgr_metric_context()` accessor output. Disclosure is always accurate because
it reads from the field that was actually used, not from a convention default.

**Pre-existing gap.** This is a pre-existing gap the RFC inherits. It must be
resolved before Level 1 ships, because the annualization disclosure is one of
the two things Level 1 is meant to fix.

---

## Gap 4: Attributes Are Fragile Storage

The RFC proposes carrying risk-free-rate context as attributes on metric lists
and comparison tables:

```r
attr(metrics, "risk_free_rate") <- provider_public_summary
attr(cmp, "risk_free_rate") <- provider_public_summary
```

R attributes are silently dropped by most common operations: `[`, `[[`,
`as.data.frame()`, `tibble::as_tibble()`, `dplyr::mutate()`, `rbind()`, and
many print methods strip attributes. Users who pipe comparison results through
a dplyr ranking step will lose the metric context they need to interpret the
Sharpe values.

This is a real fragility. The sweep and comparison workflows specifically
encourage dplyr ranking pipelines.

**Recommendation:** Use an explicit accessor:

```r
ledgr_metric_context(metrics)
ledgr_metric_context(cmp)
```

The returned object includes the risk-free assumption, calendar, and
`bars_per_year` used for computation. The underlying data (metric list or
comparison tibble) remains a plain list or tibble accessible via standard
extraction. Context is retrieved on demand.

This mirrors `ledgr_promotion_context()` and `ledgr_run_promotion_context()` —
contexts are read through explicit accessors, not attributes. Attributes may
still be used internally as the storage mechanism; the public contract is the
accessor.

Note that under the experiment-level model (Gap 1), `ledgr_metric_context()` is
also the constructor:

```r
# constructor form
ctx <- ledgr_metric_context(risk_free_rate = 0.04, calendar = ledgr_calendar_us_equity())

# accessor form
ledgr_metric_context(metrics)
ledgr_metric_context(cmp)
```

The generic dispatch is unambiguous: if called with a `ledgr_metrics` or
`ledgr_comparison` object as its first argument, it is an accessor; if called
with named assumption arguments, it is a constructor.

---

## Gap 5: Sweep Metrics Are Not Addressed

`ledgr_sweep()` computes per-candidate Sharpe ratios in the sweep result table.
The RFC does not address how `metric_context` reaches sweep metric computation
or how the assumption is disclosed in sweep results.

Under the per-call model the RFC proposes, this would require a separate
`risk_free_rate` argument on `ledgr_sweep()`. Under the experiment-level model
recommended here, this resolves automatically: `ledgr_sweep(exp)` reads
`exp$metric_context` for every candidate Sharpe computation. Consistency is
structural, not documentary.

If the experiment-level model is adopted:

- Sweep result metadata carries the `metric_context` from the experiment.
- `ledgr_metric_context(sweep_result)` returns the same context.
- Promoted-run comparison and per-run metrics use the same context.
- The sweep documentation simply states: "Candidate Sharpe is computed using the
  experiment's `metric_context`."

If the per-call model is retained despite Gap 1, then `ledgr_sweep()` must
accept `risk_free_rate` as a first-class argument with the same normalizer path,
and the sweep result must carry the assumption used. Documenting this as optional
is insufficient.

---

## Gap 6: `ledgr_compare_runs()` Scope Is Too Tentative

The RFC recommendation says: "Add `risk_free_rate` support to
`ledgr_compare_runs()` if implementation is narrow."

This is too conditional. `ledgr_compare_runs()` is the primary surface for
ranking multiple runs. If `summary()` and `ledgr_compute_metrics()` disclose the
risk-free assumption and `ledgr_compare_runs()` does not accept one, users
comparing runs by Sharpe have no way to control or inspect the assumption used.
That inconsistency is worse than a short implementation delay.

Under the experiment-level model, `ledgr_compare_runs(exp)` inherits
`exp$metric_context` and the inconsistency disappears. Under the per-call model,
`ledgr_compare_runs()` accepting the same `risk_free_rate` argument must be
Level 1, not conditional. If the implementation is too complex for v0.1.8.1,
that is a reason to narrow Level 1 differently, not to leave the comparison
surface inconsistent.

---

## Minor Points

**`metrics = "standard"` in Section 5.** This argument appears in the public
surface sketch without explanation. If it is a new argument proposed by this
RFC, it needs a separate design rationale. It should not enter scope silently
through an implementation sketch.

**`as_of` as a character string.** `as_of = "2026-05-16"` in
`ledgr_risk_free_rate()` is convenient but should be typed as a `Date` or
validated and normalized on input. Storing a character string and hashing it
means `"2026-05-16"` and `"2026-5-16"` are different hashes for the same date.

**`fill = "locf"` naming.** The acronym should be documented with its full
expansion ("last observation carried forward") and a note that it applies to
weekends and holidays in daily data. Make clear that `fill = "none"` (the
default) fails loudly rather than silently forward-filling.

**Level 2 hash stability.** The `hash` field in the `ledgr_risk_free_rate`
object needs a specified canonical serialization so the same logical assumption
always produces the same hash. If `as_of = NULL` is allowed, the canonical form
for `NULL` fields must be defined (e.g., excluded from the hash input, or
serialized as `"NULL"`). Under-specified hashing is a recurring fingerprint
stability risk in ledgr. The same rule applies to `ledgr_metric_context` if it
carries a `hash` field.

**Intraday disclosure.** When a user passes a daily calendar for a dataset that
contains multiple bars per day, ledgr should warn rather than silently under-
annualizing. A practical check: if `bars_per_year < actual_bar_count`, emit a
warning that the calendar may not match the bar frequency.

---

## Answers To Open Questions

**Q1. Should Level 2 ship in v0.1.8.1?**
Yes, but renamed. `ledgr_risk_free_rate()` ships as a hashable assumption object
accepted by the `risk_free_rate` field of `ledgr_metric_context`. It is not the
top-level primitive. Ship it alongside `ledgr_metric_context` and
`ledgr_calendar`, not as a standalone object.

**Q2. Should `ledgr_compare_runs()` accept `risk_free_rate` in v0.1.8.1?**
Yes, via the experiment's `metric_context`. Under the experiment-level model,
no separate argument is needed. See Gaps 1 and 6.

**Q3. Should metric lists expose `bars_per_year` as a field, attribute, or not?**
As a field in the `ledgr_metric_context()` accessor output, derived from the
`ledgr_calendar` object. Not as a separate top-level exported constant.
Document the value and the `ledgr_calendar` rule in the help page.

**Q4. Should a public annualization helper or constant be exported?**
No constant. `ledgr_calendar` and its convenience constructors are the public
surface. A constant without a composable calendar is a footgun for intraday
users. Ship the calendar; the constant can be derived from it.

**Q5. Should Level 3 series objects be designed only, or implemented now?**
Designed only in v0.1.8.1. The alignment, fill, and coverage rules have enough
edge cases that an untested implementation is riskier than a deferred one.

**Q6. If a time-varying series is used against weekly bars, what alignment rules
apply?**
This is the main reason Level 3 should not be implemented casually. The RFC's
current coverage rule ("must include every return period") does not specify
whether bar timestamps are matched exactly or by calendar day, or whether a
tolerance window is accepted. Specify this before implementation. Leave it for
the Level 3 design pass.

**Q7. Should scalar `risk_free_rate = 0` print explicitly in summary output?**
Yes. Print it unconditionally. A user who does not pass a rate should see
`0.00% annual` rather than having to wonder whether zero was the default. The
explicit zero also makes clear the assumption is controllable.

**Q8. Is `risk_free_rate` accepted as a sweep argument?**
Under the experiment-level model: no separate argument needed. `ledgr_sweep(exp)`
reads `exp$metric_context`. See Gap 5.

**Q9. Should `ledgr_experiment()` accept `metric_context`?**
Yes. This is the primary mechanism recommended in Gap 1. Also accept a
`risk_free_rate` scalar shorthand on `ledgr_experiment()` as L1 for the common
case where the user only needs to set a rate. The shorthand constructs a default
`ledgr_metric_context` with the provided rate and the default calendar.

---

## Revised Minimum Viable Scope

```text
Level 1 (ship in v0.1.8.1):
  ledgr_calendar(trading_days_per_year, bars_per_day = 1L)
  ledgr_calendar_us_equity()
  ledgr_calendar_crypto()
  ledgr_metric_context(risk_free_rate, calendar, ...)
  ledgr_metric_us_equity(risk_free_rate = 0)
  ledgr_metric_crypto(risk_free_rate = 0)
  ledgr_experiment() accepts risk_free_rate scalar and metric_context
  ledgr_metric_context() as accessor on metric results, comparison tables
  summary() discloses risk-free rate, annualization, and bars_per_year
  ledgr_compute_metrics() reads experiment metric_context by default
  ledgr_compare_runs() reads experiment metric_context
  ledgr_sweep() reads experiment metric_context for per-candidate Sharpe
  docs explain annualization convention and composable calendar

Level 2 (ship if hash stability is resolved):
  ledgr_risk_free_rate() constructor (named hashable assumption object)
  risk_free_rate field of ledgr_metric_context accepts scalar or this object

Level 3 (design only):
  ledgr_risk_free_series() — spec the alignment and fill rules, do not implement

Call-time overrides (retain for sensitivity analysis):
  risk_free_rate argument on metric functions remains valid
  document as ephemeral override, not canonical assumption

External adapters (defer):
  FRED, central bank, broker providers
```

---

## Verdict

The RFC is approved in direction. The design principles, three-level progressive
structure, deferred adapter layer, and provenance boundaries are all correct.

The implementation model must shift from per-call to experiment-level before
ticket cut. `ledgr_metric_context` replaces `ledgr_risk_free_rate` as the
top-level primitive. `ledgr_calendar` makes annualization composable and
intraday-safe. Templates make the common case require near-zero specification.

Do not proceed to ticket cut until:

1. `ledgr_experiment()` accepts `metric_context` and `risk_free_rate` shorthand.
2. `ledgr_calendar` is specified with composable `bars_per_day` parameter.
3. `ledgr_metric_context` is specified as the extensible container with reserved
   fields for future metric zoo inputs.
4. Attribute fragility is resolved in favour of the `ledgr_metric_context()`
   accessor.
5. `ledgr_sweep()` reads `exp$metric_context` — no separate argument required
   under the experiment-level model.
6. `ledgr_compare_runs()` is confirmed as Level 1.
