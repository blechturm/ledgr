# Strategy grammar stage 4: flat context probe

**DRAFT brief written by Claude, 2026-10-28. Provisional until the maintainer
accepts or edits it.** Spike under `inst/design/spike_protocol.md`.

## 1. Why

The maintainer cold-read six strategies written in seed v1's grammar
(`strategy_grammar_cold_read.md`) and marked three problems:

1. **Deep access paths.** `ctx$vec$feature("average")[["SPY"]]` is four
   steps to one number, and conditions and ranking use different readers.
2. **Exact but unmemorable.** `exit = !ctx$vec$member` is correct, but
   nobody will remember it.
3. **Hand-kept records.** Connors and the trailing stop are confusing. The
   trailing stop rebuilds facts the ledger already knows (peak since entry,
   days since exit) through `ledgr_asset_state()`, `NA` as forget and a
   countdown.

The verbs and the rank, pick, weight, target pipeline were not marked.

## 2. Question

Can a flat `ctx` with two ledger facts and a fail-closed index-leaver rule
express the six cold-read strategies in plain R, with the same fills,
without slowing the run?

## 3. Inputs

- Spike branch `spike/strategy-grammar` at `5db564df`, worktree
  `C:/Users/maxth/ledgr-wt/strategy-grammar`. The prototype is
  `R/zz_grammar_prototype.R`. Do not touch the uncommitted
  `dev/spikes/strategy-grammar/rfc_response/`.
- Seed v1: `inst/design/rfc/rfc_strategy_authoring_api_v0_2_3_seed.md`.
- Codex's Type 2 response:
  `inst/design/rfc/rfc_strategy_authoring_api_v0_2_3_response.md`. Apply
  F2 (`NA` in `keep` or `exit` is an error) and F3 (the `adjust` argument
  names its unit: `weights =` sets, `add_value =` adds).
- Current context construction: `R/pulse-context.R`, `ledgr_pulse_context_vec()`
  at about line 935. Its vectors carry no asset names today.
- Baselines (the executed files the cold-read page adapted from):

  | Cold read | Baseline |
  | --- | --- |
  | 1 60/40 | `benchmark/flattened/02_sixty_forty.R` |
  | 2 Trend | `benchmark/flattened/03_trend.R` |
  | 3 Momentum | `stage3/01_momentum_12_1.R` |
  | 4 Sleeve beside gold | `stage3/probes.R`, probe A |
  | 5 Connors RSI-2 | `stage3/08_connors_rsi2.R` |
  | 6 Trailing stop | `stage3/probes.R`, probe D |

## 4. What to build (prototype only, not product)

1. **Flat `ctx`.** Per-asset columns named by asset ID directly on `ctx`:
   `close`, `open`, `high`, `low`, `volume`, `position`, `held`, `member`,
   `buyable` (today's `admissible`), and one column per declared feature
   under its feature-map name. Portfolio facts (`equity`, `cash`,
   `universe`, `hold()`, `flat()`, `state_prev`) keep their names. Build
   the feature columns two ways and time both: filled every pulse, and
   lazy (active bindings).
2. **Reserved names.** `ledgr_feature_map()` rejects a feature name that
   collides with a `ctx` field, with a classed error, at declaration time.
3. **Two ledger facts.**
   - `ctx$peak_since_entry`: the highest close since the position was last
     opened from flat, including today's. `NA` when not held.
   - `ctx$days_since_exit`: sessions since the position last went to zero.
     `Inf` if never held.

   Both must come from decision-time ledger data and be maintained by index
   per pulse, with no R loop over instruments (optimization coding style).
   Write down each definition and whether it equals what the baseline
   strategy tracked by hand. Schedules that skip pulses may make "sessions"
   and "pulses" differ: state which one each fact counts.
4. **Index leavers.** `ledgr_target_rebalance(..., index_leavers =)` takes
   `"sell"` or `"keep"`. With no value and a held non-member, the run fails
   at that decision with a classed error that names the asset and both
   values. This replaces `exit = !ctx$vec$member` and keeps maintainer
   decision 2 (no default sale).
5. **Plain sets.** Sells, keeps and candidate buys are plain logical
   vectors. Under F2, `NA` in a sell, `exit` or `keep` set is an error.
   `ledgr_select_top()` and `ledgr_select_lowest()` take a plain named
   column. Compare at most three ways to stop ranking from picking an asset
   that cannot be bought, and report which reads best:
   (a) `within = ctx$buyable`; (b) the target verb fails with a teaching
   error; (c) a third option you find. Do not pick by speed.
6. **`adjust` capital base (maintainer decision, 2026-10-28).**
   `adjust(weights =)` defaults to a fraction of total equity, disclosed in
   the target's origin; `capital_base = "remaining_equity"` stays available
   as an explicit override (the momentr funnel uses it). This amends
   maintainer decision 1 for `adjust` only. `rebalance` keeps decision 1
   unchanged.

## 5. Deliverables

Under `dev/spikes/strategy-grammar/stage4/`:

- the six strategies rewritten against the flat `ctx`;
- a runner that runs the six and the baselines;
- a diff-based checker comparing fills against the baselines. A definition
  difference counts only if the findings name it and show the fills it
  moves;
- a gut demonstration: break the leaver rule, one ledger fact and one
  reserved name, and show the checker or the run fails each time;
- a timing run: flat `ctx` (both fill modes) against the current `ctx` on
  the stage 3 300-instrument workload (`stage3/time_stage3.R`), following
  the timing-gate host rules (High performance plan, P-core affinity,
  alternating runs);
- `cold_read_v2.md`: the six strategies only, in the cold-read format, for
  the maintainer to read;
- a one-page closeout: answer, numbers, definitions, open points.

Commit on `spike/strategy-grammar` with `git commit --only <paths>`. Do not
merge, do not push.

## 6. Kill conditions and budgets

Stop and report if:
- a strategy's fills differ from its baseline for a reason that is not a
  named definition difference;
- either ledger fact needs future data or a per-instrument R loop;
- the faster flat `ctx` mode is more than 5% slower end to end than the
  current `ctx` on the 300-instrument workload;
- the harness passes 1,500 R lines.

## 7. Authority this probe would amend

The probe only produces evidence. If accepted, these need explicit
amendments in seed v2:

- **Feature-map read-surface synthesis**
  (`rfc/rfc_feature_map_read_surface_v0_2_x_synthesis.md`, accepted): it
  makes `ctx$vec$feature()` the single feature resolver, and its alias rule
  is where the reserved-name check belongs.
- **Context frame retirement** (`rfc/README.md#ctx-frame-retirement`,
  inventory C2): the maintainer said on 2026-10-28 that `ctx$feature_table`
  and `ctx$features_wide` go this release and are built on demand like the
  history matrix. The flat layout is that seed's input; that seed follows
  this probe rather than running beside it.
- **Contracts:** context and state, decision axis, target semantics.
- **Maintainer decision 1**, for `adjust` only (amended 2026-10-28: total
  equity is the disclosed default).

## 8. Out of scope

Recording, entry-price accounting beyond the two facts, state storage,
schedule redesign, cash-shortfall fill policy, product code outside the
prototype file.
