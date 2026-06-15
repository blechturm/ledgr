# ledgr v0.1.9.6 Intraday-Readiness Audit

Date: 2026-06-15

Status: Batch 9 audit artifact for LDG-2654. Audit only; no runtime behavior
change is authorized or made here.

## 1. Scope And Question

This audit checks whether ledgr can honestly remain described as
EOD-first but intraday-tolerant after the v0.1.9.x feature arc. The audit
looks for architectural footguns, not feature opportunities.

Required surfaces reviewed:

- snapshot sealing and timestamp precision;
- pulse calendars and fold windows;
- metric annualization and risk-free-rate context;
- feature warmup and no-lookahead checks;
- fill timing, cost contexts, and target-risk boundaries;
- retained return panels and validation projections;
- sweep, walk-forward, and run identity;
- generated examples and user-facing teaching surfaces.

## 2. Executive Summary

Verdict: ledgr remains EOD-first but intraday-tolerant for whole-second bar
data. No hard blocker was found in snapshot sealing, pulse iteration,
feature warmup, retained-return panels, or identity hashing. Those paths are
mostly timestamp-grid and row-count based rather than date-only.

However, first-class intraday support would need bounded follow-up work before
the package should claim more than tolerance. The main risks are metric
calendar defaults, a calendar-day walk-forward health warning, and the limited
next-open execution/cost policy. These are not reasons to block the validation
substrate, but they are real enough to keep intraday runtime work behind a
future RFC or explicitly scoped packet.

Severity counts:

- High: 0
- Medium: 3
- Low: 2
- Confirmed-as-is surfaces: 7

## 3. Findings

### M-1 - Intraday metrics can be silently annualized with a daily calendar

Finding -> metric context defaults and metric annualization do not currently
guard against obvious intraday cadence mismatches.

Affected surface -> `ledgr_results(bt, what = "metrics")`, run summaries,
sweep metrics, walk-forward degradation metrics, and any downstream diagnostic
that reads those annualized values.

Source evidence -> `ledgr_calendar_us_equity()` defaults to one bar per day
but can represent minute bars through `bars_per_day` (`R/metric-context.R:6-7`,
`R/metric-context.R:50`). `ledgr_new_metric_context()` defaults to that daily
calendar (`R/metric-context.R:423-424`). Metric computation uses the resolved
context's `bars_per_year` for annualized return, volatility, and Sharpe
(`R/backtest.R:1651`, `R/backtest.R:1681`, `R/backtest.R:1693-1696`). A
cadence mismatch warning helper exists and explicitly points intraday users to
`ledgr_calendar_us_equity(bars_per_day = ...)`, but source search finds it only
as the helper definition and tests, not in the production metric path
(`R/metric-context.R:706-719`).

Why it matters for intraday -> a run over minute bars can execute correctly
while reporting annualized return, volatility, Sharpe, and risk-free-rate
normalization as if the series were daily unless the user explicitly supplies
the right metric context. That is a methodological footgun because the numbers
look valid and the evidence chain remains otherwise intact.

Current severity -> Medium. This does not corrupt fills, equity, retained
returns, or identity, but it can materially misstate headline metrics.

Refactor size -> Small to Medium. The helper and calendar model already exist;
the work is integrating observed-cadence checks into the run/metric/sweep
surfaces and deciding whether mismatch should warn or fail.

Recommended disposition -> schedule a guardrail ticket before any first-class
intraday claim. At minimum, compare observed pulse count/cadence against the
metric context and warn when daily defaults meet obviously intraday data. A
stricter future packet can decide whether this becomes fail-closed for
explicit intraday declarations.

### M-2 - Walk-forward degradation has an EOD-shaped short-window warning

Finding -> walk-forward degradation treats test windows shorter than 90
calendar days as a health warning regardless of bar frequency or fold intent.

Affected surface -> `ledgr_walk_forward()` print output and
`wf$degradation$warning_flags`.

Source evidence -> `ledgr_walk_forward_degradation_table()` computes
`test_days` from `test_start` to `test_end` and appends `short_test_window`
when it is below 90 (`R/walk-forward-inspection.R:576-583`). The print method
turns that flag into "one or more test windows are shorter than 90 calendar
days" (`R/walk-forward.R:179-180`). Fold constructors accept subdaily duration
units including seconds, minutes, and hours (`R/walk-forward-folds.R:12`,
`R/walk-forward-folds.R:29`, `R/walk-forward-folds.R:117`,
`R/walk-forward-folds.R:177`). Existing tests confirm fold-list display already
distinguishes intraday boundaries from day-aligned boundaries
(`tests/testthat/test-walk-forward-orchestrator.R:685-699`).

Why it matters for intraday -> deliberate intraday walk-forward folds can be
valid while every test window is shorter than 90 calendar days. The current
warning would become constant noise and teach users that the system is judging
an EOD window heuristic, not their actual intraday evidence design.

Current severity -> Medium. This is a diagnostic/UX defect, not an execution
or identity defect, but it directly affects walk-forward interpretation.

Refactor size -> Small. The degradation code already has fold timestamps and
warning flags; it needs a cadence-aware health rule or an explicit policy knob.

Recommended disposition -> make the warning cadence-aware before positioning
walk-forward as intraday-ready. Options include using pulse counts, requiring
an explicit minimum-test-window policy, or suppressing the 90-calendar-day
warning for subdaily fold schemes unless requested.

### M-3 - Fill timing and cost policy are valid for intraday bars but too
limited for first-class intraday execution

Finding -> the execution core is cadence-neutral for next-bar fills, but the
only public timing policy remains next-open with simple cost steps and no
liquidity/capacity policy.

Affected surface -> fill timing, cost modeling, future OMS/liquidity boundary,
and any claim that ledgr models realistic intraday execution.

Source evidence -> the fold pulse plan uses the next pulse's open/high/low/
close/volume as the execution bar (`R/fold-engine.R:99-107`). The next-open
fill proposal validates whole-second execution timestamps and uses the next
bar/open price (`R/fill-model.R:1-29`, `R/fill-model.R:80-86`). The public cost
resolver applies spread, fixed fee, notional bps, and rounding steps from the
fill context (`R/cost-model.R:396-425`). The contracts bind final-bar no-fill
and next-bar fill semantics rather than same-pulse execution
(`inst/design/contracts.md:180-182`).

Why it matters for intraday -> next-open at the next observed pulse is a
coherent intraday policy for bar data, but first-class intraday backtesting
usually needs explicit policy choices for market/limit behavior, mid/VWAP/next
touch, participation limits, volume constraints, slippage, and session
microstructure. ledgr carries enough execution-bar data to extend in that
direction, but the current public surface must not be described as modeling
those effects.

Current severity -> Medium as a future architecture risk. It is not a bug in
current behavior because the next-open contract is explicit.

Refactor size -> Medium to Large, depending on scope. Adding one more timing
model is smaller; adding liquidity/capacity/OMS semantics is RFC-scale.

Recommended disposition -> keep current next-open semantics as one explicit,
identity-bearing policy. Do not implement broader intraday execution in
v0.1.9.6. Route realistic intraday execution, liquidity, and OMS behavior
through a later RFC with cost/timing identity, test fixtures, and documentation
that separates bar-level modeling from live-order semantics.

### L-1 - Generated examples remain daily-midnight dominant

Finding -> examples and vignettes overwhelmingly use daily or day-aligned
timestamps.

Affected surface -> user teaching, examples, and generated reference pages.

Source evidence -> source search finds many examples constructing bars with
`as.POSIXct("YYYY-MM-DD", tz = "UTC") + 86400 * ...` or date strings across R
examples and vignettes. The runtime code can accept intraday POSIXct strings,
but the teaching surface mostly shows daily bars.

Why it matters for intraday -> users may not discover that whole-second
intraday timestamps are accepted, that metric context must match cadence, or
that fold display changes for non-day-aligned windows.

Current severity -> Low. This is teaching drift, not a runtime defect.

Refactor size -> Small documentation pass.

Recommended disposition -> add one compact intraday example after the metric
guardrail decision. It should show POSIXct timestamps, explicit metric context,
and a short fold/window display without claiming first-class intraday
execution.

### L-2 - Whole-second timestamp policy should be kept explicit

Finding -> ledgr is intraday-tolerant at whole-second precision, not subsecond
or tick-level tolerant.

Affected surface -> snapshots, runtime timestamps, retained panels, and
future intraday positioning language.

Source evidence -> timestamp parsing and validation normalize to UTC whole
seconds (`R/timestamp.R:139-172`). Snapshot sealing rejects subsecond bar
timestamps (`R/snapshots-seal.R:304`). Snapshot hash timestamp formatting also
requires strict POSIXct timestamp inputs (`R/snapshots-hash.R:1-40`).

Why it matters for intraday -> minute and second bars fit the current model;
subsecond feeds, exchange sequence numbers, and event-time ordering beyond
whole seconds do not. That boundary is a strength if documented, but a footgun
if "intraday" is interpreted as high-frequency or tick replay.

Current severity -> Low. This is a known constraint, not a defect.

Refactor size -> Documentation only unless a future packet intentionally
scopes subsecond support.

Recommended disposition -> preserve the whole-second policy for now. Any move
to subsecond timestamps should be a separate RFC because it touches snapshot
hashing, equality joins, retained-panel row labels, and generated docs.

## 4. Confirmed-As-Is Surfaces

### Snapshot sealing and timestamp precision

Confirmed -> not EOD-only. The snapshot path accepts POSIXct UTC timestamps and
enforces whole-second precision. Sealing rejects subsecond bars, which preserves
deterministic joins and hashes. This supports intraday bar intervals down to
one second, but not subsecond/tick semantics.

### Pulse calendar and no-lookahead execution

Confirmed -> cadence-neutral. `ledgr_backtest()` derives pulses from distinct
snapshot bar timestamps in range, not from calendar days
(`R/backtest-runner.R:827-842`). It requires at least two pulses for the
decision-pulse plus execution-pulse contract (`R/backtest-runner.R:845-848`)
and checks per-instrument coverage against the pulse grid
(`R/backtest-runner.R:858-866`). Feature hydration requires exact timestamp
alignment for the current pulse (`R/backtest-runner.R:1115-1123`).

### Feature warmup and feature no-lookahead checks

Confirmed -> row-count based. Feature warmup uses `requires_bars` /
`stable_after` and prior rows up to the current pulse, not days
(`R/backtest-runner.R:1575-1773`). `ledgr_check_no_lookahead()` compares
feature outputs before and after future data extension, making the leakage
check cadence-agnostic (`R/features-engine.R:330-432`).

### Target-risk boundary

Confirmed -> cadence-neutral. Target-risk steps transform target quantities
after strategy output and before fill planning. The contract is about target
vectors and risk-chain identity, not EOD assumptions.

### Retained returns and validation panels

Confirmed -> exact timestamp-grid based. Retained returns use the same adjacent
equity formula as single-run returns and store POSIXct `ts_utc` values
(`R/sweep-retention.R:64-104`). Panels validate structural first-row `NA`,
complete timestamp grids, deterministic candidate ordering, and ISO UTC row
labels (`R/sweep-retention.R:334-468`). The validation diagnostics consume
those panels rather than date-truncated data.

### Sweep, walk-forward, and run identity

Confirmed -> identity is not date-only. Run and walk-forward identity surfaces
carry snapshot, cost, risk, metric, and fold-boundary fields as content or
timestamp-derived values. No finding shows identity collapsing intraday folds
to dates.

### Fold display

Confirmed -> display is already intraday-aware. `print.ledgr_fold_list()`
prints date-only values only when all boundaries are day-aligned, and full ISO
timestamps when any boundary is intraday. Existing tests exercise the intraday
case.

## 5. Refactor Size Estimate

Small documentation fixes:

- document whole-second intraday tolerance and subsecond non-scope;
- add one intentionally bounded intraday example after metric guardrails land.

Small guardrails:

- call the existing calendar consistency warning helper, or equivalent, from
  metric-producing surfaces;
- make walk-forward short-window warnings cadence-aware.

Medium refactors:

- explicit intraday metric-context UX if the package wants a declared
  intraday mode rather than warning heuristics;
- one additional timing model, if scoped narrowly and identity-bound.

Architecture/RFC work:

- liquidity/capacity/participation modeling;
- OMS-like order semantics;
- subsecond/tick replay;
- exchange-session calendars and point-in-time universe membership for
  intraday ML/data pipelines.

## 6. Recommended Disposition

For v0.1.9.6:

- keep this audit as evidence only;
- do not implement intraday runtime behavior;
- do not change execution, snapshot, or identity contracts;
- allow the validation substrate and diagnostics to proceed because retained
  return panels are timestamp-grid based.

For the next planning cycle:

- schedule metric-context mismatch guardrails before any stronger intraday
  positioning;
- schedule the walk-forward short-window diagnostic cleanup as a small UX
  fix;
- open an RFC only if the roadmap wants first-class intraday execution beyond
  next-open bar semantics.

