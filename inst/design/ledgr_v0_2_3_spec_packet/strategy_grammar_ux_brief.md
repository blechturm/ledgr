# Strategy Grammar UX Brief

**Status:** Spike output, stage 3 of the strategy-grammar spike. Non-binding.
It feeds the strategy-API RFC; it is not a contract, a ticket or
implementation authority. `contracts.md` stays authoritative.

**Date:** 2026-10-27

**Supersedes:** the stage 2 brief (`../stage2/strategy_grammar_ux_brief.md`,
freeze `90ecb22b`), after the Codex Type 2 review
(`../stage2/review/type2_review.md`, USABLE_AFTER_CHANGES) and its synthesis.

**Read with:** [`worked_examples.md`](worked_examples.md) (one section per
strategy, with its economics), the prototype `R/zz_grammar_prototype.R`, the
rewrites in this directory and [`../closeout.md`](../closeout.md).

## 1. Product direction

A strategy should read like the rule its author would write on paper:

1. score the instruments;
2. form the sets the rule talks about: candidates, holdings to sell;
3. weight the chosen instruments;
4. turn them into target quantities with one of two verbs whose meaning is
   fixed by their name: **rebalance** (replace the allocation) or **adjust**
   (change only what is named).

Stage 1 showed that ledgr's helper pipeline
(`signal -> selection -> weights -> target`) is the right spine; four of nine
translations left it for hand-computed quantities or capital. Stage 2 closed
those escape hatches with one universal target verb, `ledgr_target_size()`.
The review found that the universal verb hid its most consequential policy:
"size" also meant "sell everything else", and an omitted argument decided
whose capital a weight was a share of. Stage 3 splits the verb by meaning,
makes the capital base explicit wherever it is ambiguous, and turns asset
state into ordinary vectors.

The grammar adds no execution path. Every strategy still returns a full
named numeric target vector (as a `ledgr_target`), and the existing
validators, risk chain and execution judge it.

## 2. The grammar

### 2.1 Objects

| Object | Class | Domain | Ineligible IDs | Made by |
| --- | --- | --- | --- | --- |
| score | `ledgr_signal` | decision axis | raw value; `eligible` attribute | `ledgr_signal_feature()`, `ledgr_signal_return()`, arithmetic |
| buy set | `ledgr_selection` | decision axis | always `FALSE` | `ledgr_selection(ctx, where = )`, `ledgr_select_top()`, `ledgr_select_lowest()` |
| holding set | named logical | decision axis | may be `TRUE` | `ledgr_select_held()` |
| weights | named numeric | eligible IDs | a weight on one fails | `c(SPY = 0.6)`, `ledgr_weight_equal()`, `ledgr_weight_each()`, `ledgr_align_weights()` |
| target | `ledgr_target` | decision axis | held unless exited, never bought | `ledgr_target_rebalance2()`, `ledgr_target_adjust()` |
| asset state | list of named numeric vectors | decision axis | carried | `ledgr_asset_state()` |
| result | list | | | `ledgr_strategy_result(targets, ..., asset_state = )` |

The prototype spells the rebalance verb `ledgr_target_rebalance2()` only
because today's `ledgr_target_rebalance()` is the stage 1 baseline every
parity and timing comparison runs against, and a spike may not change it. In
the package the new verb would take the name `ledgr_target_rebalance()`.

### 2.2 Moves

New pieces against v0.2.2 are marked **new**.

| Move | Pieces |
| --- | --- |
| Shape a feature in time | **new** `ledgr_ind_lag(indicator, k)` |
| Read a score | `ledgr_signal_feature()`, `ledgr_signal_return()`, `+ - * /` on signals |
| Rank into a buy set | **new** `ledgr_select_top(score, n = , fraction = , within = )`, **new** `ledgr_select_lowest()` |
| Filter into a buy set | `ledgr_selection(ctx, where = , missing = "exclude")` |
| Pick holdings | **new** `ledgr_select_held(ctx, where = )` |
| Weight | a named numeric vector, `ledgr_weight_equal()`, **new** `ledgr_weight_each(set, w)`, `ledgr_align_weights()` |
| Replace the allocation | **new** `ledgr_target_rebalance2(weights, ctx, keep, exit, invest_fraction, capital_base, fit_to_remaining)` |
| Change named positions | **new** `ledgr_target_adjust(ctx, weights, add_value, exit, invest_fraction, capital_base, fit_to_remaining)` |
| Read current holdings | **new** `ledgr_holding_value(ctx)` |
| Carry per-asset memory | **new** `ledgr_asset_state(ctx, field = initial, ...)` |
| Return | **new** `ledgr_strategy_result(targets, ..., asset_state = )` |
| Decide when | `ledgr_strategy_schedule()`, `ledgr_passed_warmup()`, a guard returning `ctx$hold()` |

Retired from the stage 2 prototype: `ledgr_target_size()` (and its `of`,
`top_up`, `fit` and `equity_fraction`), `ledgr_asset_state_update()` and its
`clear`, and `frac`.

#### Rank into a buy set

```r
top   <- ledgr_select_top(score, fraction = 0.1)          # top decile of eligible IDs
best  <- ledgr_select_top(score, 1, within = offensive)   # best of a pool
pick2 <- ledgr_select_top(medium, 5, within = pick1)      # a cascade stage
calm  <- ledgr_select_lowest(rsi, free, within = setup)   # lowest RSI first
```

#### Replace the allocation, or change named positions

```r
weights |> ledgr_target_rebalance2(ctx, exit = !ctx$vec$member, invest_fraction = 0.98)

ledgr_target_adjust(ctx, weights = ledgr_weight_each(entries, 1 / 5), exit = exits,
                    capital_base = "total_equity")
ledgr_target_adjust(ctx, add_value = c(SPY = 500))
```

#### Carry per-asset memory

```r
memory <- ledgr_asset_state(ctx, peak = NA_real_, cooldown = 0)  # named vectors over ctx$universe
memory$peak[exits] <- NA                                         # forget one field
memory$cooldown[exits] <- 5                                      # keep another
targets |> ledgr_strategy_result(hwm = hwm, asset_state = memory)
```

#### Set up with named intermediates

```r
eleven_month_return <- ledgr_ind_returns(231)
skip_month_return <- ledgr_ind_lag(eleven_month_return, 21)
features <- ledgr_feature_map(skip_month_return = skip_month_return)
month_end <- ledgr_schedule_month_end()
monthly_momentum <- ledgr_strategy_schedule(momentum_12_1, month_end)
params <- list(weights = c(SPY = 0.6, AGG = 0.4), band = 0.05)
```

No new setup argument or configuration DSL: ordinary assignments name the
ideas, and params use named vectors rather than nested lists.

### 2.3 Principles

**P1. One decision axis; eligibility travels.** Scores carry the eligibility
plane; buy sets are `FALSE` for every ineligible ID; weights may name eligible
IDs only; both verbs refuse anything else. A point-in-time strategy never
masks with `ctx$vec$admissible` by hand.

**P2. A missing decision never acts, in a set.** `NA` in a `where`, `within`,
`keep` or `exit` condition is `FALSE`: a warming-up feature neither buys nor
sells through a set. The review showed that P2 alone did not make a composed
strategy safe, because the stage 2 verb sold every eligible holding it was
not told about. P5 is the fix: the verb now says whether unmentioned holdings
are replaced or untouched.

**P3. Sets compose with ordinary logic; rankings compose through `within`.**

```r
losers <- ledgr_select_held(ctx, where = stocks & !pick1 | !ctx$vec$member)
```

**P4. The capital base is named wherever it is ambiguous (maintainer
decision 1, 2026-10-27).** A weight is a share of total equity or of
remaining equity: total equity minus the holdings the call preserves (kept,
untouched, or ineligible and protected) and minus added money.

- `ledgr_target_adjust()` with weights requires `capital_base`.
- `ledgr_target_rebalance2()` defaults to `"total_equity"` and discloses the
  default in the target's origin (`capital_base = total_equity (default)`).
  At any decision where preserved holdings make remaining equity differ from
  total equity, including a held index leaver that the contract protects, a
  call without a base fails with `ledgr_capital_base_required`. It never
  switches bases silently as holdings change.

```r
ledgr_target_rebalance2(c(SPY = 0.2, AGG = 0.2), ctx, keep = "GLD",
                        capital_base = "total_equity")   # 459 SPY shares, not 358
```

The consequence: a rebalance that omits its base runs until the first
decision with a preserved holding and stops there with a classed error that
names the preserved value. That is the intended trade for never guessing.

**P5. Two target verbs, fixed meanings, no switch between them.**

- **Rebalance** replaces the eligible allocation. Every eligible ID that is
  not weighted or kept goes to zero; `exit` goes to zero; ineligible
  holdings not exited keep their quantity (contract protection).
- **Adjust** changes only the named positions. Everything keeps its
  quantity except `exit` (to zero), `add_value` (plus
  `floor(amount / close)` shares) and weighted IDs.
- In both, weighted IDs get `floor(w * invest_fraction * base / close)`;
  with `fit_to_remaining`, sized quantities that cost more than that fraction
  of remaining equity are scaled down together and floored again.
- Contradictory instructions for one instrument (weighted and exited, kept
  and exited, added and weighted) fail with `ledgr_contradictory_target`.
- Weights are plain named numeric vectors or `ledgr_weights`: known IDs,
  finite, non-negative, summing to at most 1 unless `fit_to_remaining` is
  given.

A momentum rebalance, a slot book and a cash-flow addition read differently
because they are different verbs:

```r
w |> ledgr_target_rebalance2(ctx, exit = !ctx$vec$member)                          # rebalance
ledgr_target_adjust(ctx, weights = slots, exit = exits, capital_base = "total_equity")  # slots
ledgr_target_adjust(ctx, add_value = c(SPY = 500))                                  # add money
```

**P6. Index leavers are exited explicitly (maintainer decision 2,
2026-10-27).** No verb sells a departed member by default. A point-in-time
rebalance writes `exit = !ctx$vec$member`; without it the leaver is held, as
the contract protects, and the rebalance needs a capital base at that
decision (P4).

**P7. Time shape belongs to features; "when" is a schedule or a guard.** A
skip, a lag or a prior-window extreme is declared once in the feature map,
where ledgr checks it for look-ahead. A data-dependent "do nothing today" is
an early `return(ctx$hold())`.

**P8. State is ordinary vectors.** `ledgr_asset_state(ctx, field = initial)`
returns one named vector per field over the decision axis; an unset field
reads its initial value. The author edits the vectors with ordinary R, and
`NA` means "forget this field": `ledgr_strategy_result(asset_state = )`
stores only non-`NA` fields. This removes the author's loops. It does not
remove loops from state hydration or serialization: the stored contract is
unchanged (a list per instrument ID, contracts.md "Context Planes And
Strategy State"), so the view walks that list once to read and builds it
once to write. That conversion is measured separately (Section 5). Fields not
named in the view are not carried forward.

**P9. Recording is possible, not guaranteed.** Grammar objects carry an
`origin`, and a recorder could keep parent references (a buy set its score
and `within`, a target its weights and sets). That leaves decision recording
possible. It does not guarantee complete reconstruction: plain numeric
weights (now accepted by both verbs) and ordinary R transformations drop
ancestry. Recording stays a contract change to "Strategy Outputs And Helper
Values", off by default, and nothing in the prototype records.

## 3. One complete worked flow

The Turtle breakout (System 1, long side; Faith 2007) uses a lagged feature,
a buy set, a holding set, risk-unit weights against total equity, a fitted
adjustment and asset state. Its fills equal stage 1's, all 741.

```r
high_20 <- ledgr_ind_ttr("DonchianChannel", input = "hl", output = "high", n = 20)
low_10 <- ledgr_ind_ttr("DonchianChannel", input = "hl", output = "low", n = 10)
features <- ledgr_feature_map(
  prior_high_20 = ledgr_ind_lag(high_20, 1),
  prior_low_10 = ledgr_ind_lag(low_10, 1),
  atr = ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 20)
)

turtle <- function(ctx, params) {
  close <- ctx$vec$close
  atr <- ctx$vec$feature("atr")
  memory <- ledgr_asset_state(ctx, stop = NA_real_)
  exits <- ledgr_select_held(ctx, where = close < ctx$vec$feature("prior_low_10") | close < memory$stop)
  entries <- ledgr_selection(ctx, missing = "exclude",
    where = !ctx$vec$held & close > ctx$vec$feature("prior_high_20") & atr > 0)
  memory$stop[entries] <- (close - 2 * atr)[entries]
  memory$stop[exits] <- NA

  ledgr_target_adjust(ctx, weights = ledgr_weight_each(entries, params$risk * close / atr), exit = exits,
                      capital_base = "total_equity", fit_to_remaining = params$invest) |>
    ledgr_strategy_result(asset_state = memory)
}
```

- The lags keep today's bar out of its own breakout level.
- `memory$stop` is an ordinary vector; an unset stop is `NA` and by P2 never
  fires. Setting it at entry and forgetting it at exit are two assignments.
- `exits` is a holding set, so a departed member that hits its stop is sold;
  `entries` is a buy set, so a departed member never breaks out.
- The rule is an adjustment: only exits and entries change. A unit risks
  `risk` of total equity per ATR; `fit_to_remaining = 0.98` scales new units
  down to 98% of the capital the untouched positions leave free. Leverage is
  outside the long-only contract; next-open affordability stays with the
  execution-policy RFC.
- The stop hangs off the entry decision's close (Section 6, entry price).

## 4. Friction mapping

Stage 1 recorded 36 frictions (`../frictions.csv`). **26 map to a grammar
element** and **10 are reasoned out**, as in stage 2; the elements now use
the stage 3 names.

| # | Friction (stage 1 file:line) | Category | Grammar element, or why not |
| --- | --- | --- | --- |
| 1 | 01:15 skip-month return rebuilt by arithmetic | signal | `ledgr_ind_lag(ledgr_ind_returns(231), 21)` |
| 2 | 01:16 decile count from `length(ctx$members)` | select | `ledgr_select_top(fraction = )` |
| 3 | 01:23 departed members zeroed by hand | universe | `exit = !ctx$vec$member` (P6) |
| 4 | 01:21 next-open gap rejects a 100% book | size | Out: execution-policy RFC; the 2% buffer stays |
| 5 | 01:45 `lookback = 252` vs `return_252` | naming | Out: historical-projection (WS3) route |
| 6 | snapshot.R:72 universe union needs a third universe | universe | Out: availability/universe route; `within` covers the strategy side |
| 7 | 02:20 skip scores rebuilt and stripped | signal | `ledgr_ind_lag()` |
| 8 | 02:23 sleeves masked out of the ranking | select | `ledgr_select_top(within = stocks)` |
| 9 | 02:25 cascade stage masks and re-wraps | select | `ledgr_select_top(within = pick1)` |
| 10 | 02:35 holding value rebuilt from position * close | weight | `ledgr_holding_value()` |
| 11 | 02:44 allocatable capital recomputed (escape hatch) | escape_hatch | `ledgr_target_adjust(capital_base = "remaining_equity")` reserves untouched holdings and `add_value` |
| 12 | 02:51 sleeve top-ups as share quantities (escape hatch) | escape_hatch | `ledgr_target_adjust(add_value = )` |
| 13 | 02:52 departed members zeroed by hand | universe | an `exit` holding set |
| 14 | 03:18 three helpers for one asset | weight | a plain named weight: `setNames(1, hold)` |
| 15 | 03:21 one-asset book rejected at the open | size | Out: execution-policy RFC |
| 16 | 04:8 month-end SMA approximated by 210 sessions | signal | Out: calendar sampling transform; strategy-API RFC with the indicator route |
| 17 | 04:13 fixed 20% slices built by hand | weight | `ledgr_weight_each(above, 0.2)` |
| 18 | 04:13 `%in% TRUE` on a warming comparison | combine | `ledgr_selection(ctx, where = , missing = "exclude")` |
| 19 | 05:20 best of a pool masks and re-wraps | select | `ledgr_select_top(within = pool)` |
| 20 | 05:26 one-asset book rejected at the open | size | Out: execution-policy RFC |
| 21 | 06:24 vol-scaled book rejected once | size | Out: execution-policy RFC |
| 22 | 07:11 current weights rebuilt by hand | weight | `ledgr_holding_value(ctx) / ctx$equity`; full current-weights contract with the portfolio-construction RFC |
| 23 | 07:12 band hand-coded as a drift test | rebalance | P7 guard; a `band` argument is an open choice |
| 24 | 07:15 60/40 book rejected once | size | Out: execution-policy RFC |
| 25 | 08:18 `%in% TRUE` on exit rules | combine | `ledgr_select_held(where = )` |
| 26 | 08:21 admissible mask applied by hand | universe | `ledgr_selection(ctx, where = )`; the verbs refuse ineligible weights |
| 27 | 08:26 ranking setups masks and re-wraps | select | `ledgr_select_lowest(within = setup)` |
| 28 | 08:25 most oversold as top of `-rsi` | select | `ledgr_select_lowest(rsi, ...)` |
| 29 | 08:30 equal slots as share quantities (escape hatch) | escape_hatch | `ledgr_target_adjust(weights = weight_each(entries, 1/slots), capital_base = "total_equity")` |
| 30 | 09:10 prior-N high/low as custom indicators | signal | `ledgr_ind_lag(DonchianChannel, 1)` |
| 31 | 09:29 stop read by `vapply` over IDs | state | `ledgr_asset_state(ctx, stop = NA_real_)` (author loop gone; hydration still walks the list, P8) |
| 32 | 09:48 stops written and cleared in loops | state | vector assignment, `NA` forgets; `ledgr_strategy_result(asset_state = )` |
| 33 | 09:49 no entry fill price | state | Out: an RFC question (Section 6); an entry-price plane alone would not remove the stop state |
| 34 | 09:40 ATR units and cash scale-down (escape hatch) | escape_hatch | `ledgr_weight_each(entries, risk * close / atr)` + `capital_base = "total_equity", fit_to_remaining = ` |
| 35 | 09:40 1% per ATR implies leverage | other | Out: Supported Strategy Surface; `fit_to_remaining` scales within cash |
| 36 | 09:35 `%in% TRUE` on exit and breakout | combine | `ledgr_select_held()` and `missing = "exclude"` |

Escape hatches: **4 before, 0 after**, in stage 2 and stage 3 alike.

### 4.1 Review findings and what stage 3 did

| Codex finding (type2_review.md) | Stage 3 |
| --- | --- |
| 1. "Size" conceals "sell everything else" | Split into rebalance and adjust; probe C's zero-value addition keeps every holding (asserted) |
| 2. Nested containers hide the rule | `ledgr_strategy_result(targets, ..., asset_state = )`; named setup intermediates; named-vector params |
| 3. "Twenty percent of what?" | Capital base required where ambiguous; the 358/459 case rejects an omitted base (asserted) |
| 4. Forget the peak, keep the cooldown | State as vectors, `NA` forgets one field; probe D runs without a sentinel (asserted) |
| Cut `top_up`, `fit`, `frac`, `-rsi` idiom | `add_value`, `fit_to_remaining`, `fraction`, `ledgr_select_lowest()` |
| Defer recorder ancestry and a holding-set class | Deferred (P9, Section 7) |

## 5. Evidence

`run_stage3.R` runs each stage 1 translation beside its stage 3 rewrite on
one simulated snapshot, reruns the stage 1 fidelity check against the
rewrite, compares the fill tables row by row, runs the four probes and the
amendment assertions (`probe_checks.R`) and the three held-out scripts, and
writes `evidence/*.csv`. `check_stage3.R` reruns into a scratch directory,
diffs every CSV and guards package scope. `gut_stage3.R` removes one
load-bearing argument from three rewrites; each gutted run fails.
`time_stage3.R` writes the descriptive timings.

| Result | Value |
| --- | --- |
| Stage 1 fidelity cases rerun on the nine rewrites | 10 of 10 pass |
| Exact fill parity, meaning unchanged | 7 of 7 (03-09) |
| Deliberate differences | 2 (01, 02), explained as in stage 2 and equal to stage 2's fill counts |
| Held-out oracles (stage 2 assertion code, unchanged) | 3 of 3 pass |
| Review probes, fill count equal to the review's working variant | 4 of 4 |
| Amendment assertions | 8 of 8 (`evidence/assertions.csv`) |
| Strategy lines (between the markers), nine designed strategies | 160 stage 1, 96 stage 2, 92 stage 3 |
| Gutted rewrites that fail | 3 of 3 (leaver `exit`, `capital_base`, stop write) |

**Timings** (`time_stage3.R`; descriptive, not a gate claim). Host: Windows
11, 24 cores, R 4.6.1, High performance power plan, no other R process
running (`evidence/timing_host.txt`, which records `de0ab279` because the
stage 3 files were uncommitted when it ran); no core affinity was set. Stock
strategies ran on a wide simulated universe (300 stocks over 2017-2021, 281
on the decision axis at the clocked date); the ETF strategies on their own
universes. The callback clock uses one pulse at 2021-06-30 with a flat
opening book and empty state: 200 calls per round, versions alternating, 3
rounds, median per call.

| Strategy | Axis | Stage 1 callback | Stage 3 callback | Ratio | End to end, stage 1 / stage 3 (median of 3) |
| --- | --- | --- | --- | --- | --- |
| 01 momentum | 281 | 700 us | 529 us | 0.76 | 3.04 s / 2.83 s (0.93) |
| 02 momentr | 283 | 1,541 us | 1,042 us | 0.68 | 4.07 s / 3.95 s (0.97) |
| 03 GEM | 4 | 410 us | 202 us | 0.49 | |
| 04 GTAA | 5 | 214 us | 285 us | 1.33 | |
| 05 VAA | 6 | 677 us | 573 us | 0.85 | |
| 06 risk parity | 5 | 744 us | 727 us | 0.98 | |
| 07 60/40 | 2 | 213 us | 116 us | 0.54 | |
| 08 Connors | 281 | 307 us | 759 us | 2.47 | 9.82 s / 10.50 s (1.07) |
| 09 Turtle | 281 | 1,225 us | 671 us | 0.55 | 27.09 s / 14.25 s (0.53) |

One strategy exceeds 1.5 times its stage 1 callback (the kill condition
needs three). Connors's stage 1 callback reads raw planes and builds one
signal; the stage 3 one spends about 290 us in today's context-mode helpers
(`ledgr_signal_feature()` 107 us, `ledgr_selection(ctx, where = )` 183 us)
and about 400 us in prototype pieces (`ledgr_select_lowest()` 135,
`ledgr_target_adjust()` 162, `ledgr_weight_each()` 64,
`ledgr_select_held()` 41). Over 1,260 daily decisions that is the 0.7 s (7%)
seen end to end. Turtle halves end to end because stage 1's per-ID state
loops ran on every pulse. On the wide universe the stage 1 and stage 3 fill
counts match for 02, 08 and 09; 01 differs by 2 fills (the deliberate
leaver difference).

**State conversion** (300-ID axis, 30 stored stops, 10 entries and 10 exits,
2,000 calls x 3 rounds): stage 1's `vapply` read and two `for` loops take
343 us; the stage 3 view read plus result write take 132 us (0.38), and both
store the same values. The view still walks the stored list once in each
direction (P8); that walk is what the list-per-ID storage forces, and it is
cheaper than the author loops it replaces.

Learned about the package in stage 3:

- momentr is an adjustment, not a rebalance: written with
  `ledgr_target_adjust()` it reproduces the stage 2 book exactly (649 fills),
  and the riders disappear from the code because they are what the
  adjustment leaves alone.
- A rebalance without a base can fail years into a run, at the first decision
  with a preserved holding; the gutted 01 shows it (P4).
- Every one of the review's "working" variants is reproduced by the single
  stage 3 version of its probe, fill for fill.

## 6. Ownership

| Open question | Owning route |
| --- | --- |
| Final names; replace `ledgr_target_rebalance()` and add `ledgr_target_adjust()` | Strategy-API RFC (this brief is its input) |
| The two verbs' book policy (precedence, reservation, contradictions, `fit_to_remaining`, `add_value`) | Strategy-API RFC, consistent with contracts.md "Execution And Target Semantics" |
| Capital base required only where ambiguous; fail, never switch (maintainer decision 1) | Strategy-API RFC records it; contract text with the target helpers |
| Index leavers exited explicitly, no default sale (maintainer decision 2) | Strategy-API RFC; the idle-cash input to the portfolio-construction RFC (Cut 17 decision 19) stands |
| Mid-run failure of a rebalance that omits its base (P4 consequence) | Strategy-API RFC: whether a preflight or first-decision warning should flag it |
| Codex 1: verb meaning and remainder policy | Settled in the prototype by the split; the RFC confirms |
| Codex 2: result and state envelopes | Strategy-API RFC (`ledgr_strategy_result()`) |
| Codex 3: implicit partial-book base | Settled by maintainer decision 1 |
| Codex 4: field-level state forgetting | Strategy-API RFC with Context Planes And Strategy State; stored contract unchanged here |
| State hydration and serialization cost (list per ID) | Strategy-API RFC (context planes); the view leaves the stored contract unchanged |
| What fills when buys exceed cash at the next open; the 2% buffer | Execution-policy RFC (`rfc/README.md#execution-policy`) |
| Current weights: denominators, cash, stale and frozen marks; a `band` argument | Portfolio-construction RFC |
| Whole-share flooring, quantity steps | Asset-precision RFC |
| Leverage and shorting for Turtle-style sizing | Supported Strategy Surface; no route opened |
| Entry price on `ctx` (an RFC question only: an entry-price plane alone does not remove Turtle's state, because an ATR-based stop needs the ATR at entry or the stop level, and entry price must define additions and partial exits) | Strategy-API RFC, as a Context Planes question |
| Lag identity, gap behaviour after restarts, month-end sampling | Strategy-API RFC with the indicator route |
| Decision recording (P9: possible, not guaranteed) | Strategy-API RFC; contract change to "Strategy Outputs And Helper Values" |
| Universe union at the experiment layer (momentr) | Availability/universe route |

## 7. Open choices

- **Base requirement timing.** P4 fails at the decision where the base
  becomes ambiguous. A static rule (require a base whenever `keep` is
  supplied) would fail earlier and more often, including where the answer
  does not change.
- **`fit_to_remaining`.** Only Turtle uses it. It may belong in the
  execution-policy RFC as a decision-time affordability rule.
- **`add_value` in rebalance.** Not offered; momentr needed adjust instead.
  A rebalance that also adds money elsewhere has no expression.
- **Fields not named in the view.** The view stores only the fields it was
  asked for. A strategy reading a subset of its state forgets the rest.
- **Holding sets as a class**, and **recorder ancestry** (Codex: defer).
- **Lag on history-dependent indicators**: gap restarts not designed.

## 8. What resisted the grammar

- momentr's high-water mark is still portfolio state the author keeps by
  hand, now through `ledgr_strategy_result(hwm = )`.
- Turtle's stop hangs off the decision close; its leverage is replaced by
  `fit_to_remaining`.
- The 60/40 and permanent-portfolio bands stay guards: current-weights
  semantics are not designed here.
- GTAA's month-end SMA is still a daily approximation.
