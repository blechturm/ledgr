# Probe findings: recursive-indicator history

**Ran:** 2026-10-07, `dev/spikes/recursive-indicator-history/probe.R` at
`9452e9e`. Evidence in `probe_evidence.csv`. **Purpose:** spike protocol
section 1, before the charter. Binds nothing; no package file changed. Every
observation comes from public `ledgr_run()` and `ledgr_experiment()` calls;
strategy state is decoded read-only from the run store.

**Fixture:** one instrument, 80 daily bars, close
`100 + 10 sin(d / 5) + 0.1 d`. Four indicators: `ledgr_ind_sma(5)`,
`ledgr_ind_ema(5)`, `ledgr_ind_ttr("EMA", input = "close", n = 5)`, and a
custom `running_max` (`series_fn = cummax`). Under the Cut 9 rule a run's
features start at its opening date, so opening on day 1, 21 or 41 is three
different history starts. The values each run saw on the common days 41-80
are compared.

## P1. Declarations say when a value first exists, not when it settles

| Indicator | `requires_bars` | `stable_after` |
| --- | ---: | ---: |
| SMA(5) | 5 | 5 |
| ledgr EMA(5) | 6 | 6 |
| TTR EMA(5) | 5 | 5 |
| running max | 1 | 1 |

## P2. History start matters only for the recursive ones

| | SMA(5) | ledgr EMA(5) | TTR EMA(5) | running max |
| --- | --- | --- | --- | --- |
| Start 21 vs 1, largest gap on days 41-80 | 2.0e-13 | 0 | 8.9e-4 | 0 |
| Start 21: first day within 1e-9 | day 41 | day 41 | day 75 | day 41 |
| Start 41 vs 1, largest gap | 2.0e-13 | 0 | 0.674 | 0.386 |
| Start 41: first day within 1e-9 | day 45 | day 46 | never | day 67 |
| Start 41: warmup `NA` days | 4 | 5 | 4 | 0 |

- **`ledgr_ind_ema()` is not recursive.** It is a bounded six-bar filter
  (`ledgr_bounded_ema_series()`), bit-identical across starts after warmup.
  Cut 9 found the same; this run confirms it at a different shape.
- **SMA is bounded but not bit-stable.** Values differ by about 2e-13 between
  starts, so any exact-parity claim about hydrated SMA values must use a
  tolerance or a different summation.
- **TTR EMA decays.** Its gap shrinks with the bars elapsed since the later
  start: within 1e-9 34 days after day 41 for the day-21 start, and still 0.67
  away 40 days after day 41 for the day-41 start. Its `stable_after` of 5
  marks the first value, not convergence.
- **A running maximum does not decay.** It agrees only once the price makes a
  new high (day 67 here). No finite warmup guarantees agreement; it depends on
  the data path.

## P3. Availability-aware runs accept only the bounded SMA

`ledgr_experiment()` with a sealed session calendar and
`ledgr_valuation_stale(1)` accepted SMA(5) and refused ledgr EMA(5), TTR
EMA(5) and the custom running max with `ledgr_indicator_gap_unsupported`. So
today no recursive indicator, and not even ledgr's bounded EMA, runs in an
availability-aware experiment. Recursive gap transitions therefore cannot be
observed in that mode yet; only dense runs can exercise recursion.

## What a charter may consume

- There are at least three history models, not two: bounded windows (SMA,
  ledgr EMA), decaying recursions (TTR EMA), and path-dependent recursions
  (running max), whose convergence has no finite bound.
- `stable_after` cannot serve as a burn-in: it marks the first value.
- A decaying recursion's convergence is measurable through public runs by
  varying the history start; no package change is needed.
- Bounded exactness is about 1e-13, not bit-identity, for SMA.
- Availability-mode recursion is currently refused, so any hydration rule for
  recursive indicators is a dense-mode rule until that changes.

**Scale:** one instrument and 80 bars are a behavioral fixture. The decay
distances depend on this price path and `n = 5`; per protocol section 9 they
are not a general convergence rate.
