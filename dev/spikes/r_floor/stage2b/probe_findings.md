# Stage 2b probe findings, 2026-11-14

`probe.R` on the pin library (d5b3a151), both workloads, one run per arm in
its own process; Balanced plan, no pinning, so the clocks are indicative.

## The lean loop on the two workloads

| | 10x7200 (crossover) | slice2_10x7200 |
| --- | ---: | ---: |
| fills | 7,971 | 45,189 |
| explicit decision rows | 1 | 45,193 |
| sizing rows (plus one raw-sizing notice) | 0 (+1, pulse 1) | 24,000 (+1, pulse 2) |
| rejections | 1, final pulse | 4, final pulse |
| clean fills | 7,971 | 0 (`max_weight` trims every sized target) |
| loop, us per pulse, plain | 314 | 651 |

Stage clocks (`lean_clocks.R`, the loop text with clocks inserted at fixed
anchors; nanotime reads at about 0.2 us; clock cost 11 and 28 us per pulse;
records identical to the plain loop's):

| cell, us per pulse | 10x7200 | slice2 |
| --- | ---: | ---: |
| P1 valuation | 11 | 12 |
| P2 decide | 124 | 295 |
| of which context build | 35 | 39 |
| of which strategy call (helper included) | 69 | 152 |
| of which sizing helper | - | 118 |
| of which sizing-evidence check | 2 | 19 |
| of which risk plan | - | 34 |
| P3 plan | 74 | 141 |
| of which lean_plan_pulse() | 49 | 108 |
| P4 apply | 72 | 186 |
| of which FIFO kernel | 37 | 126 |
| of which position facts | 5 | 6 |
| P5 commit | 40 | 40 |
| of which declared-state update | 21 | 19 |
| E advance | 2 | 2 |

The clock cost is 11 to 28 us per pulse, of the same order as the smaller
cells, so cells below about 5 us are not resolved.

## What the sizing helper and the strategy read

On slice2, `ledgr_target_rebalance()` reads seven context fields once per
call (2,400 calls): `universe`, `close`, `equity`, `position`,
`holding_value`, `buyable`, `member`. The strategies read `state`, `hold()`,
`equity`, and on the crossover `fast` and `slow`. The helper accepts a plain
list carrying those seven fields and returns a `ledgr_target` with its
`sizing_evidence` attribute (executed with the pin, not inferred).

## Package functions the lean loop reaches per run

| function | 10x7200 | slice2 |
| --- | ---: | ---: |
| ledgr_call_strategy_fn, intent-reason check, sizing-evidence check, reconciliation check | 7,200 each | 7,200 each |
| ledgr_validate_strategy_targets (non-plain targets only) | 0 | 2,400 |
| ledgr_apply_risk_plan, post-risk admissibility | 0 | 7,200 each |
| ledgr_position_facts_apply, ledgr_cash_scan, segment text (pulses with fills) | about 4,900 | about 7,190 |
| ledgr_strategy_state_validate_value (one per patched field) | 14,400 | 7,200 |

## Exact formulas the reference must reproduce (read from the pin)

- Cost steps in order on whole columns: spread `price * (1 +/- bps/20000)`;
  fixed fee added; notional fee `abs(qty * price) * bps / 10000` on the
  spread-adjusted unrounded price; price rounded to 8 digits last.
- Cash effect: buy `-(qty * price + fee)`, sell `qty * price - fee`; cash is
  booked fill by fill.
- Affordability: sells that free cash first, then the rest, each group in
  radix order of the instrument IDs; a fill is accepted while virtual cash
  stays at or above minus the tolerance.
- max_weight: nonzero targets capped at `max_weight * equity / close`, sign
  kept; post-risk targets may only keep or reduce strategy exposure.
- A sizing evidence that disagrees with the targets, the position or the
  close is treated as absent (stale), not refused.

## Consequences for the reference

The reference can call the strategy and helper unchanged on a plain list
context. Costs, affordability, max_weight and the post-risk and short checks
are short formulas. The FIFO stays `dev/lean_core/fifo.R` (charter point 4).
