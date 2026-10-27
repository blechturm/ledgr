# RFC Seed: Strategy Authoring API

**Status:** Seed v1, written 2026-10-28. Not binding. Next stage: a Type 2
response under a brief written by the maintainer.
**Author:** Claude. The evidence comes from a three-stage spike, a held-out
test, two adversarial Codex rounds and a cross-framework benchmark, all
listed in Section 9.
**Reviewed trees:**
- `v0.2.3` at `be7157be`: shipped API, contracts, roadmap;
- `spike/strategy-grammar` at `5db564df`: prototype and evidence.
**Roadmap anchor:** v0.2.3 "Research UX completion". The inventory
reconciliation rows are X3 (this RFC), H3 (F8 naming) and U3 (helper
bundles).
**Inputs:** the [spike closeout](../ledgr_v0_2_3_spec_packet/strategy_grammar_closeout.md),
the [UX brief](../ledgr_v0_2_3_spec_packet/strategy_grammar_ux_brief.md), its
[worked examples](../ledgr_v0_2_3_spec_packet/strategy_grammar_worked_examples.md),
the [Codex Type 2 review](../ledgr_v0_2_3_spec_packet/strategy_grammar_type2_review.md),
and the spike branch's `benchmark/findings.md` and `benchmark/flattening.md`.

## 1. Problem

The maintainer's standard is readability above everything else. An R user
who has never seen ledgr should be able to read a strategy aloud and
recognise its one-paragraph description. Today's helpers fail that standard
in three measured ways.

1. **The code fights the idea.** Nine published strategies were written in
   the v0.2.2 public API, and all of them run. The translation recorded 36
   frictions and 4 escape hatches, every escape hatch in sizing.
   - Ranking within a subset means masking with `NA` and re-wrapping a
     signal at every stage.
   - `ledgr_target_rebalance()` (`R/strategy-helpers.R:321`) keeps held
     non-members unless they are sold by hand.
   - Sleeves, equal slots and ATR units are sized outside the helper, which
     skips its reservation checks.
2. **Book policy is hidden.** A single sizing verb decides what happens to
   everything the strategy did not name. In the Codex probes:
   - an unknown signal sold two inherited holdings;
   - an "add nothing to SPY" call sold an unrelated AGG holding;
   - an omitted argument chose between two capital bases (358 against 459
     SPY shares).
3. **Containers come before ideas.**
   - State returns nest two envelopes:
     `list(targets = , state_update = list(asset_state = ))`.
   - Schedules wrap the strategy in constructors.
   - Params nest lists, and the strategy then calls `unlist()` on them.
   - Forgetting one state field while keeping another needed a sentinel.

## 2. What the evidence settled

Every claim in this section was executed. Section 9 gives the commands.

- **Expressiveness.**
  - The stage 3 grammar expresses all sixteen strategies with no escape
    hatch and no sentinel. The sixteen are nine published strategies, three
    held-out strategies written by an agent that saw only the brief, and four
    adversarial probes.
  - Fill parity with today's API is exact wherever the meaning is unchanged
    (seven of seven).
  - Strategy code fell from 160 lines to 92.
- **Readability against peers.** Seven rules were written in ledgr, Python
  `bt` (1.4.1) and R's PMwR (1.3.0), and all 21 versions executed.
  Expressiveness ties.
  - `bt` reads most directly for standard recipes.
  - PMwR has the lightest setup for small conditions and scalar state.
  - ledgr is strongest at stating what changes and what stays untouched.
- **Flattening.**
  - Teaching plain R first and passing the schedule to the experiment each
    removed a named indirection with fills unchanged (nine of nine).
  - A feature-view object removed nothing.
- **Speed.**
  - Per-decision time is lower than today's helpers for seven of nine
    strategies. Connors is 2.47 times slower, mostly in today's context-mode
    helpers; Faber is 1.33 times slower.
  - End to end on 300 instruments: equal or faster.
  - A 300-ID asset-state read and write costs 132 us against 343 us.

The design rule taken from the benchmark: **the grammar earns its allocation
and preservation vocabulary, provided the pipeline stays optional. It does
not earn mandatory wrappers around simple R.**

## 3. Principles

1. **Readability first.** Every word a strategy contains either names part of
   its idea or names a point-in-time fact. Words that do neither are cut.
2. **Plain R first.** Conditions, `ctx$hold()`, `ctx$flat()` and named
   weights come first. The score, select and weight pipeline is for rules
   that rank or filter.
3. **No hidden book policy.** The verb's name says what happens to holdings
   the strategy did not mention, and every exception is an argument at the
   call site.
4. **Fail closed.** Contradictory instructions, an ambiguous capital base,
   unknown IDs and missing decisions under `missing = "error"` raise classed
   errors. Nothing is guessed.
5. **Contracts unchanged underneath.** Strategies remain
   `function(ctx, params)` returning full named quantity targets
   ([strategy outputs](../contracts.md#contract-strategy-outputs)). There are
   no orders, no shorting and no leverage. `ctx` is decision-time only.
   Returned state keeps its stored form
   ([context and state](../contracts.md#contract-availability-context-and-state)).

## 4. Proposal

### 4.1 The two target verbs

| Verb | Meaning |
| --- | --- |
| `ledgr_target_rebalance(weights, ctx, keep =, exit =, invest_fraction =, capital_base =)` | Replace the eligible allocation. Eligible holdings not weighted or kept go to zero. |
| `ledgr_target_adjust(ctx, weights =, add_value =, exit =, invest_fraction =, capital_base =)` | Change only the named positions. Everything else keeps its quantity. |

- **Both** return complete quantity targets through the existing execution
  path, and share one sizing implementation.
- **No switch argument** turns one verb into the other.
- **Contradictions fail.** An ID that is both weighted and kept, or both
  added to and exited, raises an error.
- **Ineligible holdings** keep the contract's protection: they are held
  unless exited, and never bought
  ([target semantics](../contracts.md#contract-availability-targets)).
- **Maintainer decision 1 (2026-10-27): capital base.** It is required only
  where it changes the answer.
  - Required cases: `adjust` with weights, and `rebalance` whenever kept,
    exited-later or automatically preserved holdings make remaining equity
    differ from total equity.
  - In those cases, a call without a base fails at that decision. It never
    switches bases silently.
  - An unreserved rebalance defaults to `"total_equity"` and discloses it.
  - Values are `"total_equity"` and `"remaining_equity"`.
  - `equity_fraction` becomes `invest_fraction`.
- **Maintainer decision 2 (2026-10-27): index leavers.** They are exited
  explicitly with `exit = !ctx$vec$member`. No verb sells them by default.
- **Plain named numeric weights are accepted.** They are validated strictly:
  known IDs, non-negative, and summing to at most 1.
  `ledgr_weight_equal()` and the new `ledgr_weight_each(selection, w)` stay.

### 4.2 Selection

- `ledgr_select_top(score, n =, fraction =, within =)` replaces
  `ledgr_select_top_n()`. `within` ranks only inside an earlier selection,
  which is the funnel step.
- `ledgr_select_lowest()` is the literal opposite. Authors no longer negate
  scores.
- `ledgr_select_held(ctx, where =)` selects among holdings. A holding may be
  ineligible to buy and still be held or exited.
- `ledgr_selection(ctx, where =, missing =)` keeps its default
  `missing = "error"`. A data gap fails loudly unless the author chooses
  `"exclude"`, and then also states what to keep, for example
  `keep = is.na(signal)`.

### 4.3 State

```r
memory <- ledgr_asset_state(ctx, peak = NA_real_, cooldown = 0)
memory$peak[exits] <- NA_real_                # forget the peak
memory$cooldown[exits] <- params$cooldown_sessions
targets |> ledgr_strategy_result(hwm = hwm, asset_state = memory)
```

- `ledgr_asset_state()` returns named vectors over `ctx$universe`. A given
  initial value applies only where a field is unset.
- `NA` means "forget this field", and the result helper stores it as absent.
- Portfolio state travels in `...`.
- The helper builds today's `list(targets, state_update)` form, so resume,
  sweeps and provenance are unchanged.
- The view removes the author's loops. Hydration and serialization still
  walk the stored list per ID.

### 4.4 Features, schedule and setup

- Time shape lives in features: `ledgr_ind_lag(indicator, k)`.
- Declarations stay `ledgr_feature_map(name = indicator)`.
- Reads stay `ctx$vec$feature("name")`. Section 7 rejects the feature view.
- Setup is taught as named intermediates. For example,
  `skip_month_return <- ledgr_ind_lag(eleven_month_return, 21)` names the
  idea without new arguments.
- Params are named vectors, not nested lists.
- **The schedule is an experiment argument:**
  `ledgr_experiment(..., strategy = momentum, schedule = month_end)`. It
  replaces `ledgr_strategy_schedule()` (`R/strategy-schedule.R:44`), with no
  second way.
  - This amends the scheduler synthesis D1 ("representation is a classed
    function"). That synthesis did not reject an experiment-level argument
    (its Section 6).
  - The compiler, identity records and skip semantics stay as they are
    ([fold core](../contracts.md#contract-execution-fold-core)).
- `ledgr_holding_value(ctx)` is exposed for guards such as tolerance bands.

### 4.5 Teaching order

The brief and the articles teach in this order:
1. conditions and named weights;
2. ranking with `within`;
3. preservation with `keep`, `exit` and `adjust`;
4. state;
5. schedules.

Every example ends in one readable pipeline or one plain return.

## 5. What it replaces

This is pre-CRAN, so the change replaces rather than adds:
- `ledgr_select_top_n()` becomes `ledgr_select_top()`;
- `ledgr_target_rebalance()` keeps its name and gains the policy above;
- `ledgr_strategy_schedule()` is replaced by the experiment argument;
- the `ledgr_weights()` wrapper becomes optional.

Strategies that use the verbs change their results where the policy changes.
Vignettes and tests are rewritten. Strategies returning raw full targets are
unaffected.

## 6. Contract and RFC impact

**Contract rule groups that need amendment sentences:**
- [strategy outputs](../contracts.md#contract-strategy-outputs);
- [context and state](../contracts.md#contract-availability-context-and-state);
- [target semantics](../contracts.md#contract-availability-targets);
- [decision axis](../contracts.md#contract-strategy-decision-axis);
- [fold core](../contracts.md#contract-execution-fold-core) (schedule
  placement);
- [public name shapes](../contracts.md#contract-public-name-shapes) (F8).

**Interacting RFCs and v0.2.3 items:**
- **[execution policy](README.md#execution-policy):** what fills when cash
  runs short at the open. The spike kept a hand-written 2% buffer.
- **[portfolio construction](README.md#portfolio-construction):** current
  weights, bands and external estimators such as NMOF.
- **[asset precision](README.md#asset-precision-tradability):** quantity
  steps.
- **The RNG workstream (inventory X1):** stochastic strategies.
- **Strategy-helper bundles (U3, absorbing R4).**
- **Export tiering (C9).**

## 7. Rejected alternatives

| Alternative | Why rejected |
| --- | --- |
| One universal target verb with switches | It hid "sell everything else" (Codex finding 1). |
| `otherwise =` on the verbs | It would erase the difference between them. |
| Mutable strategy state, `self$x <- value` style | It breaks exact resume, parallel equivalence and provenance. |
| `skip =` arguments on indicators | It gives two ways to lag; named intermediates read better. |
| A feature-view object (`feat$x`) | It swaps one binding for another with no gain (flattening round). |
| A declarative registration layer | quantstrat shows the cost: labels and `arguments = list()` before the rule. |
| Value-based targets sized at the fill price | They violate "targets are quantities"; this is execution-policy or OMS territory. |
| Selling index leavers by default | Hidden policy; maintainer decision 2. |

## 8. Questions for the response

1. **Defaults** (maintainer). Should `ledgr_experiment()` default the opening
   (cash) and the cost model, disclosed in `print()`? Claude's position:
   default the cash, but keep the cost model required, or default it to a
   defensible nonzero value. A zero-cost default flatters every result.
2. Should the raw `list(targets, state_update)` return stay public beside
   `ledgr_strategy_result()`, or become internal?
3. Does `fit_to_remaining` (decision-time scaling to fit cash) belong here,
   or in the execution-policy RFC?
4. A rebalance without a base fails at its first ambiguous decision, possibly
   years into a run. Should preflight or `ledgr_experiment_plan()` warn
   earlier, and can it know?
5. Should the buy set and the holding set be distinct classes, or stay plain
   logical vectors with documented meaning?
6. Where is the boundary between `ledgr_holding_value()` and the
   portfolio-construction RFC's current-weights contract?
7. Should an entry-price plane be in scope? An ATR stop still needs the ATR
   at entry, and additions and partial exits need a definition.
8. Recording is possible, not guaranteed. What must classed intermediates
   preserve so a later recorder can explain a decision?
9. Names under the F8 decision: are verbs allowed for strategy helpers? And
   is the rebalance verb named `ledgr_target_rebalance` or a clearer word?
10. Composing several strategies with separate capital and state, as bt's
    portfolio trees do: out of scope, with a route?
11. Is a direct `ctx$features$name` reader worth a spike, given that the
    view object failed?
12. Asset-state storage stays a list per ID. Is a columnar form needed before
    CRAN for wide universes?

## 9. Evidence and reproduction

**Stages, all on `spike/strategy-grammar`:**
- stage 1: `55511d2f`;
- stage 2: `90ecb22b`; held-out test: `de0ab279`;
- Codex review: `090ba226`;
- stage 3: `93369b94` and `9c0476b8`;
- benchmark and flattening: `5db564df`.

**Commands, from the worktree root:**

```powershell
Rscript dev/spikes/strategy-grammar/stage3/check_stage3.R
Rscript dev/spikes/strategy-grammar/benchmark/flattened/check.R
```

**Limits:**
- Every reader of the grammar so far was a model.
- Timings are descriptive: High performance plan, no other R process, no
  core affinity set.
- The prototype lives in `R/zz_grammar_prototype.R` on the spike branch only,
  where the rebalance verb is named `ledgr_target_rebalance2()`.
