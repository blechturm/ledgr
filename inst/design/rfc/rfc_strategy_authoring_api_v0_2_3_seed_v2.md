# RFC Seed: Strategy Authoring API (v2)

**Status:** Seed v2 by Claude, 2026-10-28. Not binding. Supersedes
[seed v1](rfc_strategy_authoring_api_v0_2_3_seed.md). Next stage: a Type 2
response to v2 under a maintainer-written brief (the context layout and
declared state are new since the v1 response).
**What changed since v1:** the [v1 Type 2 response](rfc_strategy_authoring_api_v0_2_3_response.md)
(F1-F7, twelve answers); three maintainer cold reads; spike stages 4 and 5;
maintainer decisions of 2026-10-28 (Sections 4.2 and 4.3).
**Reviewed trees:** `v0.2.3` at `94e985d6` with the packet files in Section
9; `spike/strategy-grammar` at `ee377f31`.
**Roadmap anchor:** v0.2.3 "Research UX completion"; inventory X3, H3 (F8
naming), U3 (helper bundles), C2 (context frame retirement).

## 1. Problem

The standard is readability above everything else. v1 measured three
failures in today's API (36 frictions, hidden book policy, containers before
ideas). The maintainer's cold read of v1's own grammar found three more:

1. **Deep access.** `ctx$vec$feature("average")[["SPY"]]` is four steps to one
   number, and conditions and ranking used different readers.
2. **Exact but unmemorable.** `exit = !ctx$vec$member` is correct; nobody
   will remember it.
3. **Hand-kept records.** A trailing stop with a cooldown rebuilt in strategy
   state what the ledger already knows: when a position opened and closed.

## 2. What the evidence settled

Every claim here was executed; Section 9 gives the commands.

- **Expressiveness (stage 3).** Fifteen of sixteen strategies run without an
  escape hatch; Turtle still needs `fit_to_remaining` (Q2). Fills match
  today's API wherever the meaning is unchanged.
- **Peers.** Seven rules in ledgr, `bt` 1.4.1 and PMwR 1.3.0: `bt` reads best
  for recipes, PMwR for scalar state, ledgr for what changes and what stays
  (informed judgments, not reader scores).
- **Flat context (stages 4, 5).** Six cold-read strategies keep their fills
  exactly (91, 47, 90, 91, 2,031, 58). Stage 4 adapted the old context and
  missed a 5% gate on Turtle (+5.51%). Stage 5 followed the history panels
  (service prepared once, small view per pulse, values built on read) and
  is faster on all four 300-instrument workloads: momentum -1.2%, funnel
  -2.0%, Connors -9.8%, Turtle -2.0%. The clock excludes building the
  experiment object.
- **Position facts (stage 5).** Entry and exit bars, written only at fills,
  are rebuilt exactly by one pass over the fills; all 1,045 decisions match
  independent arithmetic. A view kept from an earlier pulse never shows
  later values.
- **Withdrawn v1 claims (F7):** "equal or faster end to end" (Connors 1.07);
  "zero cost flatters every result" (unmeasured); the quantstrat remark; the
  state timing as dense-state evidence (30 entries).

## 3. Principles

1. **Readability first.** Every word names part of the idea or a fact.
2. **One step to a fact.** Anything known at the decision is one `ctx$` away.
3. **Plain R first.** Conditions are logical vectors; the rank, pick, weight
   pipeline is for rules that rank.
4. **No hidden book policy.** The verb says what happens to unmentioned
   holdings; every exception is an argument at the call site.
5. **Fail closed, and teach.** A choice that changes results and has no safe
   default stops the run at the first decision that needs it, and the error
   names the choice.
6. **The ledger answers what it knows.** Facts the ledger answers exactly come
   from ledgr; what the strategy invents stays in strategy state. Facts count
   bars or carry timestamps, never calendar units: intraday is planned.
7. **Contracts unchanged underneath.** Full named quantity targets; no
   orders, shorting or leverage; `ctx` is decision-time only.

## 4. Proposal

### 4.1 The flat context

`ctx` is a view over a read service prepared once per run, like the history
panels (`R/history-frame.R`, `ledgr_history_view()`).

- **Per-asset columns, named by asset ID:** `open`, `high`, `low`, `close`,
  `volume`, `position`, `held`, `member`, `buyable` (today's `admissible`),
  `holding_value` (quantity times the permitted decision mark, zero when not
  held; response Q6), the position facts (4.2), and each declared feature
  under its feature-map name (`ctx$rsi_2`).
- **Portfolio facts** keep their names (`equity`, `cash`, `universe`,
  `ts_utc`, `hold()`, `flat()`); declared state is `ctx$state$name` (4.5).
- **View rules.** A column is built on first read and cached for the pulse.
  A kept view returns its own pulse's values. `names(ctx)` and `str(ctx)`
  list the columns; an unknown name is a classed error. Feature and state
  declarations reject names that collide with context fields.
- **Replaced:** `ctx$vec`, `ctx$feature()`, `ctx$features()`. The prepared
  frames (`ctx$bars`, `ctx$feature_table`, `ctx$features_wide`,
  `ctx$bar(id)`) become on-demand helpers built from these columns
  (maintainer, 2026-10-04 and 2026-10-28); the context frame retirement seed
  keeps their inspection obligations and takes this layout as input.

### 4.2 Position facts (maintainer decisions, 2026-10-28)

| Column | Meaning | When unknown |
| --- | --- | --- |
| `entry_price` | Remaining FIFO cost basis / quantity, the basis ledgr's P&L uses. Buy 100 at 10, 100 at 20, sell 100: 20. | `NA` when flat |
| `entry_at` | Timestamp of the bar whose fill opened the position from flat | `NA` when flat or inherited |
| `exit_at` | Timestamp of the bar whose fill last closed it to zero | `NA` if never exited |
| `bars_since_entry` | Run-calendar bars since the entry bar, skipped decisions included | `NA` when flat or inherited |
| `bars_since_exit` | Run-calendar bars since the last exit bar | `Inf` if never exited |

- Bars are the run's calendar, as in backtrader's `len(self)` and AmiBroker's
  padded portfolio mode. Timestamps are the recording bar's label, not the
  execution instant. Opening holdings have a basis but no entry time; ledgr
  does not invent one.
- Entry and exit bars are integer vectors written only by fills; the rest is
  derived on read. Resume, sweeps and walk-forward rebuild them with one pass
  over committed fills.
- Not provided: `peak_since_entry` (a price statistic; strategy state) and
  any day count.

### 4.3 The two target verbs

| Verb | Meaning |
| --- | --- |
| `ledgr_target_rebalance(ctx, weights, keep =, index_leavers =, invest_fraction =, capital_base =)` | Replace the eligible allocation. Eligible holdings not weighted or kept go to zero. |
| `ledgr_target_adjust(ctx, weights =, add_value =, exit =, invest_fraction =, capital_base =)` | Change only the named positions. Everything else keeps its quantity. |

- **`ctx` first in both** (cold read). A ranking pipeline ends at the weights.
- **Units in the argument name (F3).** `weights = c(SPY = 0.1)` sets SPY to
  10% and may sell; `add_value = c(SPY = 500)` buys 500 more.
- **Index leavers (decision 2, respelled 2026-10-28).** `index_leavers =
  "sell"` or `"keep"`, required only when a held asset has left the index;
  without it the run fails at that decision, naming the asset and both
  values. No verb sells leavers by default.
- **Capital base (decision 1; amended for `adjust` 2026-10-28).** `rebalance`
  requires it only where the bases differ and otherwise defaults to
  `"total_equity"`, disclosed. `adjust` defaults to `"total_equity"`,
  disclosed; `"remaining_equity"` is the override. Remaining equity is
  `max(0, equity - reserved_value - additions)`: the value preserved outside
  the weighted set, and each `add_value` reserved once (F5). It is a sizing
  budget, not settled cash. `invest_fraction` multiplies the named base and
  does not cap kept positions.
- **Sets.** `keep` takes asset IDs (`keep = "GLD"`) or a logical vector;
  `exit` a logical vector. `NA` in either is a classed error (F2): a missing
  decision never becomes a sale. An ID both weighted and kept, or both added
  to and exited, is an error.
- **Weights** are plain named numbers: known IDs, non-negative, summing to at
  most 1. No normalization, no leverage. Ineligible holdings stay held unless
  exited and are never bought.

### 4.4 Selection and weights

- `ledgr_select_top(score, n =, fraction =, within =)` and
  `ledgr_select_lowest()` take a plain column such as `ctx$rsi_2`.
  `within = ctx$buyable` names the pool (stage 4 preferred it to bracket
  subsetting and to a late error from the target verb).
- `NA` in a score or candidate set means "not selected"; `n` of zero or less
  selects nothing; fewer than `n` qualifying is allowed by default.
- `ledgr_weight_equal(selection)` splits the invested base evenly;
  `ledgr_weight_equal(selection, each = 0.2)` gives each selected asset 20%.
- Retired: `ledgr_select_top_n()`, `ledgr_signal_feature()` and the
  prototype's `ledgr_select_held()`, `ledgr_selection(missing =)` and
  `ledgr_weight_each()`. Sets are plain logical vectors.

### 4.5 State

```r
experiment <- ledgr_experiment(snapshot, strategy = trailing_stop,
  asset_state = c(peak = NA_real_), portfolio_state = c(hwm = NA_real_), ...)
```

- **Declared once, with defaults.** `ctx$state$peak` is a named vector over the
  universe, `ctx$state$hwm` one number. Reading an undeclared field is an
  error, so a typo never reads as a default.
- **Returned by name:** `ledgr_strategy_result(targets, peak = peak)`. Only
  declared names are accepted; `intent_reason =` is a result argument, not
  state (F1). A length-1 value for an asset field applies to every asset.
- **Fields not returned keep their values (F1).** `NA` resets a field to its
  default; `NaN` and infinite values are rejected.
- The declaration joins the experiment identity. The helper builds today's
  stored form; list-per-ID storage is unchanged (response Q12). The raw
  `list(targets, state_update)` return stays public (response Q2).

### 4.6 Schedule, features, setup and teaching order

- **The schedule is an experiment argument** (`schedule = month_end`),
  replacing the public `ledgr_strategy_schedule()`. The internal decorator,
  compiler, identity and skip semantics stay (F4); this amends scheduler D1's
  public construction rule only.
- **It gates the whole callback**, stops included. "Monthly allocation, daily
  stops" runs daily and checks the date inside the strategy.
- Time shape lives in features (`ledgr_ind_lag()`); params stay a list (F6).
- Teaching order: conditions and named weights; ranking with `within`;
  `keep`, `index_leavers` and `adjust`; schedules; position facts; state.

### 4.7 Two of the six cold-read strategies

All six, including Connors' `open_slots`, are in cold read v3 (Section 9).

```r
momentum <- function(ctx, params) {
  weights <- ctx$skip_month_return |>
    ledgr_select_top(fraction = 0.1, within = ctx$buyable) |>
    ledgr_weight_equal()
  ledgr_target_rebalance(ctx, weights, index_leavers = "sell")
}

trailing_stop <- function(ctx, params) {
  peak <- pmax(ctx$state$peak, ctx$close, na.rm = TRUE)
  sell <- ctx$held & ctx$close < 0.95 * peak
  buy  <- !ctx$held & ctx$bars_since_exit >= params$wait
  holding_after <- (ctx$held & !sell) | buy
  peak[!holding_after] <- NA                      # remember only what we hold
  ledgr_target_adjust(ctx, weights = ledgr_weight_equal(buy, each = 0.2), exit = sell) |>
    ledgr_strategy_result(peak = peak)
}
```

Spellings changed after stage 5 (`ctx` first, `each =`, declared state,
`Inf`, `n` of zero or less) are proposals; the implementation cut verifies
them against the stage 5 fills.

## 5. What it replaces

Pre-CRAN, nothing is kept in parallel: the readers and helpers of 4.1 and
4.4, `ledgr_strategy_schedule()`, weights-first `rebalance`. Vignettes and
tests are rewritten; results change where the policy changes.

## 6. Contract and RFC impact

**Contract rule groups needing amendments:**
[strategy outputs](../contracts.md#contract-strategy-outputs),
[context and state](../contracts.md#contract-availability-context-and-state),
[target semantics](../contracts.md#contract-availability-targets),
[decision axis](../contracts.md#contract-strategy-decision-axis),
[fold core](../contracts.md#contract-execution-fold-core) (schedule placement,
position-fact maintenance),
[public name shapes](../contracts.md#contract-public-name-shapes) (F8 allowlist
for `ledgr_select_*`; reconcile `ledgr_passed_warmup`, `ledgr_align_weights`).

**Accepted decisions amended:** the
[feature-map read-surface synthesis](rfc_feature_map_read_surface_v0_2_x_synthesis.md)
(features become columns instead of one resolver; its alias rule hosts the
reserved-name check); [scheduler synthesis](rfc_strategy_schedule_decorator_v0_1_9_x_synthesis.md)
D1, public construction only; maintainer decisions 1 (for `adjust`) and 2
(spelling) of 2026-10-27.

**Interacting work:** [context frame retirement](README.md#ctx-frame-retirement)
(follows this RFC); [execution policy](README.md#execution-policy);
[portfolio construction](README.md#portfolio-construction) (also owns
separate-capital composition, response Q10); asset precision; X1, U3, C9, X4.

## 7. Rejected alternatives

v1's rejections stand: one verb with switches or `otherwise =` (hides "sell
everything else"); mutable `self$x` state (breaks exact resume, parallel
equivalence, provenance); a rule-registration layer; value targets sized at
the fill price (targets are quantities); selling leavers by default. New:

| Alternative | Why rejected |
| --- | --- |
| A separate view object (`ledgr_today(ctx)`, `feat$x`) | A second object to learn; the flat `ctx` does it in one step. |
| `exit = !ctx$vec$member` as the leaver idiom | Exact but unmemorable; replaced by a teaching error. |
| `peak_since_entry` as a context fact | A price statistic, not a ledger fact; overfits one example. |
| Day counts (`days_since_exit`) | Lock ledgr into daily bars. |
| Each asset's own bar count | Multi-asset engines count a shared clock. |
| Average-cost entry price | Would disagree with ledgr's FIFO P&L. |
| Undeclared state read as `NA` | A typo would silently read a default. |

## 8. Questions for the response

1. **Experiment defaults (maintainer).** Claude and the v1 response: default
   the cash (100,000), disclosed; keep the cost model explicit. Or a
   disclosed zero-cost default, which fits "good defaults, disclosed"?
2. **Bounded sizing (F5).** What named step turns Turtle's risk units into
   bounded weights without levered weights or `fit_to_remaining`?
3. **Declared state.** Right spelling? How is every field cleared at once?
4. **Facts across runs.** Does a walk-forward fold start with fresh position
   facts or inherit them? The rebuild is shown; the plumbing is not.
5. **Lazy internals.** Stage 5 still builds a lazy `vec` for target helpers
   and legacy error fields. End state?
6. **Mixed cadence.** Is a calendar predicate needed before CRAN?
7. **Advisory preflight (response Q4).** Should `ledgr_experiment_plan()`
   warn when an inspected opening already needs `capital_base` or
   `index_leavers`, with the authoritative check kept at the decision?
8. **Recording (response Q8).** Confirm nothing here promises a decision
   graph beyond literal column names and explicit arguments.

## 9. Evidence and reproduction

**`spike/strategy-grammar`:** stage 1 `55511d2f`; stage 2 `90ecb22b`,
held-out `de0ab279`; Codex review `090ba226`; stage 3 `93369b94`,
`9c0476b8`; benchmark and flattening `5db564df`; stage 4 `a38a24e0`,
`ee1028af`; stage 5 `ee377f31`. The v1 response's probes are uncommitted in
`dev/spikes/strategy-grammar/rfc_response/`. Packet copies on `v0.2.3`:
stage 4 and 5 briefs and closeouts, cold reads v1-v3
(`ledgr_v0_2_3_spec_packet/strategy_grammar_*`).

```powershell
Rscript dev/spikes/strategy-grammar/stage3/check_stage3.R
Rscript dev/spikes/strategy-grammar/stage5/check.R
Rscript dev/spikes/strategy-grammar/stage5/gut.R
```

**Limits:** one human reader (the maintainer, three cold reads); stage 5
timing excludes experiment construction, one host; the prototype
(`R/zz_grammar_prototype.R`, spike only) uses temporary names.
