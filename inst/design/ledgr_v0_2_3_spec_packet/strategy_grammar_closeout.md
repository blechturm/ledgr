# Strategy Grammar Spike: Closeout

2026-10-27, `spike/strategy-grammar`. Non-binding; feeds the strategy-API RFC.

**Verdict: GREEN.** The synthesized grammar runs all sixteen strategies with
no escape hatch or sentinel and with stage 1 fill parity wherever the meaning
is unchanged, and none of the charter's kill conditions fired: no unexplained
parity break, probe D needs no sentinel or per-field branching, and one
strategy (Connors, 2.47x), not three, exceeds 1.5 times its stage 1 callback.

## What ran

- **Stage 1** (`55511d2f`): nine published strategies in today's API on one
  simulated point-in-time snapshot; 36 frictions, 4 escape hatches.
- **Stage 2** (`90ecb22b`, `de0ab279`): one universal target verb removed the
  escape hatches (7 of 7 exact parities; 3 held-out oracles pass). The Codex
  Type 2 review (`stage2/review/`, USABLE_AFTER_CHANGES) found the verb hid
  "sell everything else", an omitted argument chose the capital base (358 vs
  459 shares), and forgetting one state field needed a sentinel.
- **Stage 3**: the synthesis in `R/zz_grammar_prototype.R` and sixteen
  rewrites with runner, checker, gut and timing scripts (`stage3/`). Results,
  each an assertion that can fail: stage 1 fidelity 10 of 10; exact parity 7
  of 7 (03-09); 01 and 02 differ by design (leavers exited and redeployed)
  and equal stage 2's fill counts; held-out oracles 3 of 3, stage 2 assertion
  code unchanged; each probe matches the fill count of the review's working
  variant (91, 1,024, 29, 58); 8 of 8 amendment assertions, among them the
  358/459 case rejecting an omitted base, an unreserved rebalance disclosing
  its default, a zero-value adjustment keeping unrelated holdings, a held
  index leaver plus an omitted base failing, and probe D keeping the
  cooldown while forgetting the peak; 3 of 3 gutted rewrites fail. Strategy
  lines for the nine: 160, 96, 92. Timings are descriptive (brief Section 5):
  callback ratios 0.49 to 1.33 except Connors 2.47; end to end 0.93, 0.97,
  1.07 and 0.53 for 01, 02, 08 and 09 on 300 stocks. The stage 2 runners
  call the retired `ledgr_target_size()` and run only at `090ba226` or before.

## What was learned about the package

- The helper spine `signal -> selection -> weights -> target` holds for all
  sixteen; each escape hatch was a missing verb, set operation or feature
  transform, not a missing execution feature.
- Which holdings a verb leaves alone decides the fills. Splitting rebalance
  from adjust shows it in the call; momentr is an adjustment and as one
  reproduces stage 2's book exactly. One version of each review probe
  reproduces the review's working variant, with no switch arguments.
- State as vectors removes the author's loops, not the hydration and
  serialization walk that list-per-ID storage forces. The view is still
  cheaper (132 us against 343 us for a 300-ID read and write), and Turtle
  halves end to end because stage 1's per-ID loops ran every pulse.
- Connors's extra callback time sits in today's context-mode helpers
  (`ledgr_signal_feature()`, `ledgr_selection(ctx, where = )`, about 290 us
  at 281 IDs) and in the prototype verbs (about 400 us): 7% end to end.
- Preflight resolves helpers through `NAMESPACE`, so prototypes must be
  exported under `pkgload::load_all()`; `ledgr_run()` without a `run_id`
  returns the finished run of an identical configuration.

## What the strategy-API RFC may consume

- The two verbs and their book policy (brief P5); the rebalance verb would
  take the name `ledgr_target_rebalance()`.
- **Maintainer decision 1 (2026-10-27):** the capital base is required only
  where ambiguous, including where automatically preserved ineligible
  holdings make remaining equity differ from total equity; a call without
  one fails there and never switches bases; an unreserved rebalance defaults
  to `"total_equity"` and discloses it.
- **Maintainer decision 2 (2026-10-27):** index leavers are exited
  explicitly with `exit = !ctx$vec$member`; no verb sells them by default.
- `ledgr_select_top(fraction = , within = )`, `ledgr_select_lowest()`,
  `ledgr_select_held()`, `ledgr_weight_each()`, plain named weights,
  `ledgr_ind_lag()`, `ledgr_holding_value()`, `ledgr_asset_state()` with `NA`
  forgetting, `ledgr_strategy_result(targets, ..., asset_state = )`, named
  setup intermediates and named-vector params; brief Sections 4 and 4.1.

## What remains open

- **Execution-policy RFC:** next-open affordability, the 2% buffer, and
  whether `fit_to_remaining` belongs there.
- **Current weights:** denominators, cash, stale marks, a `band` argument.
- **Entry price:** an RFC question only. A plane alone would not remove
  Turtle's state: an ATR stop needs the ATR at entry or the stop level, and
  entry price must define additions and partial exits.
- **Recording:** classed objects leave it possible, not guaranteed; plain
  weights and ordinary R lose ancestry.
- **State storage:** list per ID unchanged; planes are a Context Planes
  question.
- **A rebalance without a base fails mid-run** at its first preserved
  holding (gutted 01); whether preflight should warn is open.
- **Helper overhead at width:** context-mode signal and selection cost
  100-200 us each at 281 IDs.
