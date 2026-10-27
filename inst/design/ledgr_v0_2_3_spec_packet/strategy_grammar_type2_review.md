**USABLE_AFTER_CHANGES** — the selection pipeline is usable, but hidden portfolio policy and nested bookkeeping prevent this grammar from reading like the strategy it describes.

Type 2; non-binding; 2026-10-27; source `de0ab279`. Ranked by readability damage. “After” code sketches proposed authoring APIs; every target helper still returns full named quantities through the existing execution path.

**1. “Size” conceals “sell everything else.”** [probes.R](probes.R):15–19,29; prototype:259–261. An unknown average sold both inherited 100-share holdings. A zero-dollar SPY top-up preserved SPY but targeted AGG to zero. P2’s “missing decision never acts” is therefore false for the composed strategy, although the behavior matches today’s contract. Separate rebalance from adjustment, expose the remainder policy, and preserve unknown holdings explicitly.

```r
# Before: a conditional addition needs empty weights and an unrelated keep set.
ledgr_weights(numeric()) |>
  ledgr_target_size(ctx, top_up = c(SPY = addition), keep = "AGG")

# After: a complete target vector, with the whole-book policy visible.
ledgr_target_adjust(ctx, add_value = c(SPY = addition), otherwise = "hold")

# A rebalance that preserves holdings with an unknown signal:
ledgr_target_rebalance(weights, ctx,
  keep = is.na(average), otherwise = "exit_eligible")
```

**2. The reader must unpack containers before recognizing the rule.** `09_turtle_donchian.R:26`, `01_momentum_12_1.R:7,19–25`, `07_sixty_forty_band.R:17`. State has two nested envelopes; feature, schedule and opening constructors bury named ideas. Flatten the result API. For declarations and parameters, ordinary assignments already suffice; another configuration DSL would add vocabulary without improving the reading.

```r
# Before:
list(targets = targets, state_update = list(asset_state = state))
features <- ledgr_feature_map(
  momentum = ledgr_ind_lag(ledgr_ind_returns(231), 21))
params <- list(weights = list(SPY = 0.6, AGG = 0.4), band = 0.05)
exp <- ledgr_experiment(snapshot,
  strategy = ledgr_strategy_schedule(strategy, ledgr_schedule_month_end()),
  opening = ledgr_opening(cash = 100000))

# After: the result helper is proposed; the declarations use existing pieces.
ledgr_strategy_result(targets, asset_state = state)
eleven_month_return <- ledgr_ind_returns(231)
momentum <- ledgr_ind_lag(eleven_month_return, 21)
features <- ledgr_feature_map(momentum = momentum)
params <- list(stock_weight = 0.6, bond_weight = 0.4, band = 0.05)
month_end <- ledgr_schedule_month_end()
monthly_strategy <- ledgr_strategy_schedule(strategy, month_end)
opening <- ledgr_opening(cash = 100000)
exp <- ledgr_experiment(snapshot, strategy = monthly_strategy, opening = opening)
```

**3. Twenty percent of what?** [probes.R](probes.R):8; prototype:214,281–282. Beside untouched gold, residual sizing produced 358 SPY shares; twenty percent of total equity produced 459. Both are legitimate rules. An omitted argument must not decide which paragraph the reader is reading. Require a capital base for partial-book sizing; `equity_fraction` also misnames a fraction that can apply to residual capital.

```r
# Before:
weights |> ledgr_target_size(ctx, keep = "GLD")
# After:
weights |> ledgr_target_rebalance(ctx, keep = "GLD",
  capital_base = "total_equity", invest_fraction = 1)
```

**4. “Forget the peak; remember the cooldown” becomes storage surgery.** [probes.R](probes.R):43–48; prototype:340–347. Clearing an asset while updating its cooldown fails; writing an NA peak instead fails serialization. The working version requires a finite sentinel and per-field branching. Offer field-specific forgetting and require an explicit update set.

```r
# Before:
ledgr_asset_state_update(ctx, cooldown = 5, where = exits, clear = exits)
# After:
ledgr_asset_state_update(ctx, cooldown = 5, where = exits, forget = "peak")
```

**What to cut.** Cut the universal target verb, empty-weight ceremony, nested state envelope, implicit partial-book base, whole-asset `clear`, and silently inactive `where = NULL`. Move `top_up` to adjustment as `add_value`; rename `fit` to `fit_to_remaining` and retain its decision-time cap. Prefer `select_lowest(rsi)` to `select_top(-rsi)`; spell out `fraction`. Defer recorder ancestry and a holding-set class. Keep `within`, lag, equal/fixed weights and ordinary guards.

**Own probes.** Partial sleeves expressed cleanly with explicit equity sizing (91 fills). Unknown-signal preservation worked only with a separate keep mask. Conditional accumulation worked with explicit preservation (29 fills, no AGG sale). Trailing stop plus five-session cooldown worked only with field branching and a sentinel (58 fills; minimum exit-to-reentry gap six sessions). Seven variants completed; two retained failures expose the state boundary.

**Evidence.** [Runner](run_probes.R), [checker](check_probes.R), [targets](evidence/pulse_targets.csv), [runs](evidence/runs.csv), [gut diff](evidence/gut_diff.csv), [environment/input identity](evidence/environment.txt). The checker reproduced both CSVs, caught the gutted capital base, and preserved package scope. Run from the worktree root:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" dev/spikes/strategy-grammar/stage2/review/check_probes.R
```

Boundaries: [full targets](../../../../../inst/design/contracts.md#contract-strategy-outputs), [context/state](../../../../../inst/design/contracts.md#contract-availability-context-and-state), [target semantics](../../../../../inst/design/contracts.md#contract-availability-targets). Next-open affordability is outside this review.
