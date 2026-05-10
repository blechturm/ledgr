On Leakage: ledgr Design Choices
================

A backtest is valid only if each decision uses information that was
knowable at that point in time – and nothing else.

Leakage is what happens when that boundary is violated. It can be
obvious, or it can be hidden inside preprocessing that looks harmless.

ledgr’s workflow is designed around this problem. The strategy
interface, sealed snapshots, and registered feature definitions each
reflect a deliberate choice to make common leakage patterns structurally
difficult – not just documented as bad practice. This article explains
where that protection applies and where your responsibility begins.

## The Obvious Leak

The blunt example is `lead(close)`: tomorrow’s close placed onto today’s
row.

``` r
leaky_signals <- bars |>
  dplyr::group_by(instrument_id) |>
  dplyr::arrange(ts_utc, .by_group = TRUE) |>
  dplyr::mutate(
    tomorrow_close = dplyr::lead(close),
    buy_signal = tomorrow_close > close
  )
```

The resulting `buy_signal` looks like an ordinary column, but it answers
a question the strategy could not have answered at today’s decision
time.

A strategy that trades on this signal will appear highly predictive in
backtesting – the signal answers the directional question by definition,
because it literally contains tomorrow’s outcome. The arithmetic is
correct; the inputs are not. Those numbers describe how well the
strategy would perform if it could read tomorrow’s close at today’s
open. That is not a question worth measuring.

## The Subtle Leak

Real leakage is often less cartoonish. A full-sample threshold can leak
without calling `lead()`.

``` r
leaky_features <- bars |>
  dplyr::group_by(instrument_id) |>
  dplyr::arrange(ts_utc, .by_group = TRUE) |>
  dplyr::mutate(
    ret_5 = close / dplyr::lag(close, 5) - 1,
    strong_return = ret_5 > stats::quantile(ret_5, 0.75, na.rm = TRUE)
  )
```

There is no future row reference in the final rule. The leak happened
earlier: the January rows are compared against a return distribution
that includes later months. Future information has been baked into a
normal-looking feature.

The gap is concrete. Suppose the first quarter of the sample has strong
returns and the remaining three quarters are weak:

``` r
set.seed(42)
ret_5 <- c(
  rnorm(63,  mean =  0.004, sd = 0.010),  # first quarter: strong
  rnorm(189, mean = -0.001, sd = 0.012)   # remaining three quarters: weak
)

full_sample <- stats::quantile(ret_5, 0.75, na.rm = TRUE)
early_window <- stats::quantile(ret_5[seq_len(63)], 0.75, na.rm = TRUE)

c(full_sample = round(full_sample, 4), early_window = round(early_window, 4))
#>  full_sample.75% early_window.75% 
#>           0.0077           0.0104
```

The full-sample threshold is lower because the later weak-return period
drags the distribution down. Early rows that would not have cleared the
honest threshold do clear the full-sample one. The strategy records more
`strong_return = TRUE` signals in the first quarter than it could have
generated in real time – and that inflated count flows directly into the
backtest’s apparent edge.

## The Strategy Boundary

At execution time, ledgr strategies receive one pulse context. The
strategy can read current bars, current registered features, current
positions, cash, equity, and helper functions such as `ctx$flat()` and
`ctx$hold()`.

The strategy does not receive the full future market-data table. It has
no market-data object from which it can casually index tomorrow’s bar.

``` r
strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    if (ctx$close(id) > ctx$open(id)) {
      targets[id] <- params$qty
    }
  }
  targets
}
```

This boundary prevents one common class of leakage. It does not cleanse
contaminated data that were already handed to ledgr.

## The Feature Boundary

Registered indicators are ledgr’s feature boundary. A feature is not
just a casual column added to a data frame. It has an ID, parameters,
required history, warmup/stability rules, and a deterministic place in
the pulse context.

Scalar indicator functions are evaluated on bounded historical windows
ending at the current bar. Vectorized `series_fn` functions must return
a numeric series aligned to the input bars, with valid warmup and
post-warmup values. Unknown feature IDs fail loudly at pulse time rather
than silently becoming missing values.

Those rules make accidental leakage harder than ad hoc full-sample
signal columns.

## The Sharp Edge: `series_fn`

Vectorized custom indicators are useful because many indicators are
naturally computed over a full series. They are also a residual risk.
Output shape and value checks can prove that a vector has the right
length and valid values. They cannot prove that the function avoided
future rows internally.

The [custom-indicator article](custom-indicators.html) explains this
boundary in more detail. The core warning is the same: full-series
custom feature code must be written with causal discipline.

## What Ledgr Enforces

| Boundary | ledgr behavior |
|----|----|
| Strategy reads future rows | Strategy receives a pulse context, not a future table. |
| Unknown feature ID | `ctx$feature()` fails loudly instead of returning warmup. |
| Known feature in warmup | Values are explicitly `NA_real_` until usable. |
| Invalid target shape | Missing or extra target instruments are rejected. |
| Tier 3 strategy dependency | Preflight stops execution before run artifacts are written. |

## What Remains Your Responsibility

ledgr does not certify that the dataset, event timestamps, universe
construction, parameter search, or custom vectorized feature code are
causally clean.

| Risk | Why ledgr cannot fully solve it |
|----|----|
| Survivorship-biased universe | A snapshot may already exclude dead or unavailable instruments. |
| Bad availability timestamps | Event, fundamental, or macro data may be timestamped by label date rather than when it was tradable information. |
| Restated data | Vendors may revise values after the simulated decision time. |
| Research-loop leakage | Trying many ideas and reporting the best one turns the sample into training data. |
| Semantically leaky `series_fn` | A shape-valid vector can still be future-aware internally. |

## Checklist Before Trusting A Run

- Was the snapshot built from data available at the simulated decision
  times?
- Was the universe chosen without future survival information?
- Are event or fundamental timestamps availability timestamps?
- Are features registered as indicators rather than full-sample signal
  columns?
- Does the strategy fill after the information it used?
- Did parameter choices survive out-of-sample or regime checks?
- Can the run be reopened and explained from stored provenance?

## What To Remember

ledgr protects the strategy boundary and makes the feature boundary
explicit. That is necessary, not sufficient. A causally honest backtest
still depends on clean data availability, disciplined feature
engineering, and honest research process.
