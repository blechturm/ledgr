# External Documentation Review, 2026-10-01

**Status:** Routing record. Each finding below was verified against the tree at
`207e760` before it was routed; the verdict column is ours, not the reviewer's.
**Source:** an outside reader's review of the README and all 27 pkgdown
articles of v0.2.1.0, passed to the maintainer on 2026-10-01 after the tag was
pushed and before the GitHub Release.
**Disposition:** the maintainer decided on 2026-10-01 that no version is tagged
with known defects. Every finding where the documentation states something the
code does not do is corrected in Cut 24 (Workstream 32), and the release tag
moves after it. Findings that need a behaviour change are parked in a scheduled
design session of the next version (`ledgr_roadmap.md`, rows marked
"external review 2026-10-01").

## Design Findings

| # | Finding | Verdict | Evidence | Routed to |
| --- | --- | --- | --- | --- |
| D1 | Dense runs permit shorts and negative cash although the README says long-only | True | README "long-only positions"; `contracts.md` calls negative targets outside the supported workflow; Risk And Cost's uncapped run shorts DEMO_02 under `ledgr_risk_none()`; How Targets Become Fills, "Cash Is Not Checked In A Dense Run". Availability-aware runs already refuse both (`short_exposure_unsupported`, `insufficient_cash`). | Docs: LDG-2921. Default: execution-intent design session |
| D2 | Incomplete runs leave selection, reintroducing survivorship one layer up | Mostly true | Incomplete candidates stay in sweep tables with their status and PBO refuses a panel with them, but they cannot be selected or promoted (`R/sweep.R`), and `ledgr_effective_trials()` builds its panel from completed candidates, so DSR counts fewer trials than were run. | Untradable-holdings and selection design session |
| D3 | Lookahead boundary leaks through captured objects | True | A strategy closing over a global data frame is Tier 2 and allowed, with only a "resolved external object" note (`R/strategy-preflight.R`). Leakage calls common patterns "structurally difficult". | Docs: LDG-2921. Check: leakage-boundary design session |
| D4 | No rounding step although Risk And Cost advises one | True | Risk steps are `none`, `long_only`, `max_weight`; `max_weight(0.5)` fills 54.632 shares; the article advises "a lot-size or rounding policy". | Docs: LDG-2921. Step: execution-intent design session |
| D5 | "Trades" means two things | True | `ledgr_closed_trade_rows()` (`R/backtest-fills.R`) keeps every closing fill, partial reductions included; README, Strategy Basics and Accounting say "closed round trips". | Docs: LDG-2921 |
| D6 | `stable_after` for recursive indicators is the first finite row, not convergence | True | EMA `n`, RSI `n + 1`, MACD `nSlow + nSig - 1` (`R/indicator-ttr.R`); values depend on the series start. Fold dependence is unverified: features compute over snapshot history. | Leakage-boundary and warmup design session |
| D7 | Promotion reruns over the full history and prints like fold evidence | True | Walk-Forward's promoted run prints Period 2019-01-01 to 2019-12-31; the caveat is prose only. | Print and result-surface chores |
| D8 | `series_fn` causality could be checked by prefix invariance | Proposal | Shape checks cannot prove causality (Leakage, Custom Indicators). | Leakage-boundary and warmup design session |
| D9 | Halt semantics: unknown halts, and "hold or exit" against a dropped zero target | True | Missing Data table "you may hold or exit it"; its prose says a zero target for a halted holding is not executed and is dropped. The unknown-halt case is undocumented. | Table wording: LDG-2921. Semantics: execution-intent design session |
| D10 | Split-adjusted bars carry future splits into historical price levels | True | Absolute-price rules see post-split levels. | Docs: LDG-2921. Leakage-boundary design session |
| D11 | PBO tie-breaking is silent | Plausible, unverified | Selection Integrity's rotating-winner example. | Untradable-holdings and selection design session |
| D12 | Deparse-based source hashes across R versions | Partly true | `hash_verified` re-hashes stored text and survives an R upgrade; the source hash of the same function can differ across R versions (`ledgr_strategy_source_info()`). | Leakage-boundary and warmup design session |

## Documentation Findings

| # | Article | Finding | Verdict | Routed to |
| --- | --- | --- | --- | --- |
| A1 | Strategy Basics | "Small one-share rows" prose, every row is qty 10 | True | LDG-2920 |
| A2 | Indicators | "Four Warmup-Adjacent Cases" over three | True | LDG-2920 |
| A3 | Accounting Model | `ledgr_results()` listed with four of seven tables | True | LDG-2920 |
| A4 | Metric Contexts | override uses the default `risk_free_rate = 0` | True | LDG-2920 |
| A5 | Cash Distributions | bars halve under a `split_adjusted` declaration; the headline is the price drop | True (the clock-order sub-claim is false) | LDG-2920 |
| A6 | Experiment Store | `ledgr_state_reconstruct()` return names | True | LDG-2920; argument order to print and result-surface chores |
| A7 | Experiment Store | curated prints show numeric columns as `<chr>`, including after a sentence promising raw numerics | True | LDG-2920; print types to print and result-surface chores |
| A8 | Experiment Store | `tags` is `<lgl>` until a tag exists | True, code | LDG-2922 |
| A9 | Survivorship Bias | `declare` masks base; `substr(ts_utc)`; January 7 sentence | True | LDG-2920 |
| A10 | Who ledgr Is For | `bt` labelled R | True | LDG-2920 |
| A11 | Sweeps | dplyr attach messages on the built site | True | LDG-2920 |
| A12 | Selection Integrity | hidden setup chunk | Disclosed choice | No change |
| A13 | several | result `ts_utc` `<date>` beside `<dttm>` | Print compaction, not run type | Print and result-surface chores |

## Ergonomics Findings

Helper reuse across strategies, per-instrument warmup gating, `ctx` passed twice
in the pipeline and an alias-aware whole-universe read go to the strategy
context surface design session; the last also belongs to the feature-map read
surface RFC. The R 4.6.0 floor's reach into institutional environments goes to
the CI strategy review, which owns the supported-version matrix.
