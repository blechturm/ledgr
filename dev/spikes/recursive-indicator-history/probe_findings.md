# Probe findings: recursive-indicator history

**Ran:** 2026-10-07, revised 2026-10-08 after peer review;
`dev/spikes/recursive-indicator-history/probe.R` against `a807a9c`'s package
code. Evidence in `probe_evidence.csv`. **Purpose:** spike protocol section 1,
before the charter. Binds nothing; no package file changed. Observations come
from public `ledgr_run()` and `ledgr_experiment()` calls; strategy state is
decoded read-only from the run store.

**Fixture:** one instrument, 80 daily bars, close
`100 + 10 sin(d / 5) + 0.1 d`. Four indicators: `ledgr_ind_sma(5)`,
`ledgr_ind_ema(5)`, `ledgr_ind_ttr("EMA", input = "close", n = 5)`, and a
custom `running_max` (`series_fn = cummax`, `fn = max` of its one-bar
window). Under the Cut 9 rule a run's features start at its opening date, so
opening on day 1, 21 or 41 gives three history starts. The values each run saw
on the common days 41-80 are compared.

## P1. Declarations say when a value first exists, not when it settles

| Indicator | `requires_bars` | `stable_after` | `gap_contract` |
| --- | ---: | ---: | --- |
| SMA(5) | 5 | 5 | strict_window |
| ledgr EMA(5) | 6 | 6 | none |
| TTR EMA(5) | 5 | 5 | none |
| running max | 1 | 1 | none |

## P2. History start matters only for the recursive ones

| | SMA(5) | ledgr EMA(5) | TTR EMA(5) | running max |
| --- | --- | --- | --- | --- |
| Start 21 vs 1: largest gap on days 41-80 | 2.0e-13 | 0 | 8.9e-4 | 0 |
| Start 21: gap on day 80 | 0 | 0 | 1.2e-10 | 0 |
| Start 21: first day within 1e-6 / 1e-9 | 41 / 41 | 41 / 41 | 58 / 75 | 41 / 41 |
| Start 41 vs 1: largest gap | 2.0e-13 | 0 | 0.674 | 0.386 |
| Start 41: gap on day 80 | 0 | 0 | 4.6e-7 | 0 |
| Start 41: first day within 1e-6 / 1e-9 | 45 / 45 | 46 / 46 | 79 / not by 80 | 67 / 67 |
| Start 41: warmup `NA` days | 4 | 5 | 4 | 0 |

- **`ledgr_ind_ema()` is not recursive.** It is a bounded six-bar filter
  (`ledgr_bounded_ema_series()`), bit-identical across starts after warmup.
- **SMA is bounded but not bit-stable.** Its values differ by up to 2e-13
  between starts, so an exactness check needs a tolerance.
- **TTR EMA decays.** From the day-21 start it is within 1e-9 54 bars after
  that start (day 75); from the day-41 start it is within 1e-6 38 bars after
  it (day 79) and not yet within 1e-9 by day 80. Its `stable_after` of 5 marks
  the first value, not convergence. Decay of an EMA is known analytically, so
  these distances add nothing general.
- **A running maximum does not decay.** It agrees only once the price makes a
  new high (day 67). No finite warmup guarantees agreement.

## P3. Availability mode gates on a declaration, and can be silently wrong

An availability-aware experiment accepts an indicator only when it declares
`gap_contract = "strict_window"` (`R/availability-policy.R`), not by checking
whether it is recursive. SMA declares it and is accepted; ledgr EMA, TTR EMA
and the undeclared running max are refused with
`ledgr_indicator_gap_unsupported`.

**P3b.** The same running max declared `strict_window` is accepted, and an
availability-aware `ledgr_run()` finishes `DONE`. Over ten sessions the
strategy saw `fn`'s one-bar window value (the close: 110.638 and 110.093 on
days 9 and 10), not `series_fn`'s running maximum (110.796 on both days). No
condition was raised. A recursive indicator that declares the strict window
silently delivers different values from its own series definition.

## What a charter may consume

- At least three history models exist: bounded windows, decaying recursions
  and path-dependent recursions. Declarations (`requires_bars`,
  `stable_after`, `gap_contract`) do not say which one an indicator is.
- Whether history before a window changes values can be observed through
  public runs by varying the history start, with a tolerance near 1e-13 for
  bounded indicators.
- Availability mode trusts `gap_contract`; P3b shows the trust can produce
  wrong values without any diagnostic. This is the "fn/`series_fn`
  diagnostics" scope the roadmap's leakage row names.
- Cut 9's LTB-0196 already pins run, sweep, promotion, window and walk-forward
  parity for a recursive TTR EMA under the restart rule; pulse inspection
  (`ledgr_pulse_snapshot()`) was not probed.

**Scale:** one instrument and 80 bars are a behavioral fixture; per protocol
section 9 none of these numbers is a general convergence rate.
