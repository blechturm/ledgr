# RFC: Multi-Output Indicator UX And Contract

**Status:** Request for comment — pre-design, no implementation started.
**Author:** ledgr maintainer
**Reviewer:** Codex
**Date:** 2026-05-15
**Context files:**
- `R/indicator.R` — `ledgr_indicator()` constructor and indicator contract
- `R/feature-map.R` — `ledgr_feature_map()` and feature registration
- `R/indicator-ttr.R` — TTR adapter, reference implementation of `series_fn`
- `inst/design/horizon.md` — multi_series_fn and optimization sprint entries

---

## Background

ledgr precomputes all feature series before a run starts. Each named feature in
a `ledgr_feature_map` is backed by an indicator object carrying a `series_fn`:

```r
series_fn(bars, params) -> numeric vector, length == nrow(bars)
```

`series_fn` is a hard contract: it returns exactly one numeric vector, aligned
to `nrow(bars)`, with `NA_real_` for warmup rows. Strategies receive bar-by-bar
scalar slices from the cache — the indicator is never called at runtime.

This contract is clean for single-output indicators (RSI, SMA, EMA). It becomes
awkward for indicators that produce multiple time series in one computation:
BBANDS (upper band, middle band, lower band), MACD (macd, signal, histogram),
ATR (atr, trueHigh, trueLow), aroon (aroonUp, aroonDn, oscillator).

---

## Current Pattern

Multi-output indicators require one constructor call per output. For the TTR
adapter today:

```r
features <- ledgr_feature_map(
  macd   = ledgr_ind_ttr("MACD", input = "close", output = "macd",
                          nFast = 12, nSlow = 26, nSig = 9, percent = FALSE),
  signal = ledgr_ind_ttr("MACD", input = "close", output = "signal",
                          nFast = 12, nSlow = 26, nSig = 9, percent = FALSE)
)
```

Each call becomes an independent `ledgr_indicator` with its own fingerprint.
`output` is part of the fingerprint, so `macd` and `signal` occupy separate
cache slots. The execution engine calls `series_fn` independently for each,
computing MACD twice.

In a feature factory, this multiplies:

```r
features <- function(params) list(
  bb_up  = ledgr_ind_talib("BBANDS", input = "ohlc", output = "UpperBand", n = params$n),
  bb_mid = ledgr_ind_talib("BBANDS", input = "ohlc", output = "MiddleBand", n = params$n),
  bb_low = ledgr_ind_talib("BBANDS", input = "ohlc", output = "LowerBand", n = params$n)
)
```

---

## The Problems

### 1. Param repetition and silent inconsistency risk

All outputs of a multi-output indicator share the same params. The current
pattern requires the user to repeat those params N times. A typo or partial
update produces N indicators with diverging fingerprints — no error is raised,
but the feature cache holds silently inconsistent series.

In a parameter factory the risk compounds: changing `params$n` or `params$input`
requires updating every output line.

### 2. Redundant computation at precompute time

BBANDS computed three times produces identical intermediate work — three calls
to the same underlying function with the same bars and params. For a sweep grid
with 30 candidates and 3 instruments, BBANDS runs 270 times instead of 90.

This is precompute-time cost only (strategies pay zero at runtime), but it is
wasteful and grows linearly with output count.

### 3. Output discovery

A user writing a BBANDS strategy must look up the available output column names
before registering the indicator. There is no ledgr-level API to enumerate valid
outputs for a given indicator without constructing it. The error path (wrong
output name) surfaces only at precompute time.

### 4. Naming burden

The user must invent feature names for every output. For a TTR BBANDS study:
`bb_up`, `bb_mid`, `bb_low`. For MACD: `macd_line`, `macd_signal`,
`macd_hist`. These names are arbitrary and not enforced by the indicator.

---

## The Concern

The talib adapter PR (open, contributor-driven) will introduce a new multi-output
surface: BBANDS, MACD, and potentially others. If no ergonomic multi-output
pattern exists before or alongside that adapter, the awkward one-call-per-output
pattern becomes the established idiom for both TTR and talib. Retrofitting it
later is harder once users have written feature factories around it.

The right time to decide this is before the talib adapter ships, not after.

---

## Design Options (Sketches — Not Decisions)

### Option A: Multi-output constructor shorthand (UX layer only)

A convenience function produces N consistent `ledgr_indicator` objects in one
call, guaranteeing identical params across all outputs:

```r
ledgr_ind_ttr("BBANDS", input = "close", n = 20,
  outputs = c(bb_up = "up", bb_mid = "mavg", bb_low = "dn"))
```

Returns a named list of ordinary single-output `ledgr_indicator` objects.
`ledgr_feature_map` accepts them inline (requires either native list support or
user splat). No change to `series_fn` contract. Does not fix redundant
computation.

Consistency guarantee: enforced at construction time — one params set, N
output-specific indicators derived from it.

### Option B: `multi_series_fn` contract extension

Extend `ledgr_indicator` with an optional `multi_series_fn` slot:

```r
multi_series_fn(bars, params) -> named list of numeric vectors
```

The precomputation engine detects `multi_series_fn` and registers all returned
series into the feature cache in one call:

```r
ledgr_ind_talib("BBANDS", input = "ohlc", n = 20,
  outputs = c(bb_up = "UpperBand", bb_mid = "MiddleBand", bb_low = "LowerBand"))
```

This fixes both the UX repetition and the redundant computation. It requires
changes to:
- `ledgr_indicator()` constructor (new optional `multi_series_fn` slot)
- Feature precomputation loop (detect and dispatch `multi_series_fn`)
- Feature cache (register N slots from one computation)
- `ledgr_feature_map()` (accept multi-output indicator objects)
- Fingerprinting (shared base fingerprint + per-output suffix, or N separate
  fingerprints derived from a shared params hash)

### Option C: Shorthand now, `multi_series_fn` later

Ship Option A as the UX fix alongside the talib adapter. `multi_series_fn` is
added as a performance optimization in a later cycle. The shorthand guarantees
param consistency; the batching is transparent to the user and can be adopted
without any user-facing API change.

The risk: Option A establishes a list-of-indicators pattern that `multi_series_fn`
would eventually replace. If the two patterns coexist, users may have both in
their feature factories without a clear migration path.

---

## Open Questions

**Q1. Is the UX problem acute enough to need a solution before the talib adapter ships?**
The TTR adapter already has the one-call-per-output pattern. If the talib adapter
ships the same way without a shorthand, that pattern becomes established idiom
for both adapters. What is the cost of deferring further?

**Q2. Should `ledgr_feature_map` natively accept a named list of indicators?**
Option A requires `ledgr_feature_map` to accept either a named list inline, or
the user to splat it. Does `ledgr_feature_map` currently accept list inputs? If
not, does adding that support constitute a meaningful API extension that deserves
its own design pass?

**Q3. Is the consistency guarantee the right primitive?**
The core value of a multi-output constructor is guaranteeing that all outputs
share identical params. Is there a case where a user legitimately wants outputs
from the same indicator with slightly different params (e.g., BBANDS with
`n = 20` for upper and `n = 10` for lower)? If so, the consistency guarantee
should be opt-in, not enforced.

**Q4. Fingerprint shape for `multi_series_fn`.**
If the precomputation engine calls `multi_series_fn` once and registers N cache
slots, how are those slots fingerprinted? Options:
- N separate fingerprints, each including the output name (same as current
  one-call-per-output, but derived from shared params)
- A shared "computation fingerprint" plus a per-output suffix

The first option is more consistent with the existing model. The second enables
future deduplication across feature maps (two feature maps referencing the same
multi-output indicator share one computation).

**Q5. Roadmap placement.**
Three options:
- Alongside the talib adapter (requires design decision before the adapter PR merges)
- v0.1.8.x sweep stabilization cycle (reactive, small surface)
- v0.1.8.2 optimization sprint (natural fit for the performance angle, but may
  delay the UX fix)

If the UX and performance concerns are separable (Option C), do they need to
land in the same milestone?

**Q6. TTR adapter retrofit.**
If a multi-output constructor or `multi_series_fn` ships, should `ledgr_ind_ttr`
be retrofitted immediately, or left as-is until a user-facing migration path is
clear? A half-retrofitted state (talib supports multi-output shorthand, TTR does
not) may be more confusing than deferring both.

---

## What We Are Not Asking

- We are not asking whether to change the `series_fn` contract for single-output
  indicators. That contract remains unchanged regardless of the option chosen.
- We are not asking about the talib adapter implementation itself — the one-call-
  per-output pattern is correct for the initial adapter PR. This RFC addresses
  what comes after.
- We are not asking about sweep parallelism. Multi-output indicator batching
  at the precompute level is orthogonal to parallel candidate dispatch.
- We are not asking about output enumeration or indicator metadata APIs more
  broadly. Those are a separate discoverability question.
