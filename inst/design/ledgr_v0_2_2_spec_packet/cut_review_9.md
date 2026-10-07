# Cut 9 Review: Scoring Boundaries And Temporary Feature Starts

**Reviewer:** Claude, independent Type 1 then Type 2, 2026-10-07.
**Subject:** uncommitted Cut 9 draft on `2639949`: Workstreams 18 and 19,
LDG-2968 to LDG-2971, and the matching README, macro-plan, roadmap, RFC-index
and UX-brief edits. **Probe:** clean clone at `2639949`, R 4.6.1.

## Type 1: Coverage And Checkability

**Probe:** ten daily bars, closes 1-10; SMA(3); 1000 cash; zero cost; target
one share once SMA is finite; opening or scoring start on day 6.

| Arm | Observed |
| --- | --- |
| `ledgr_run()`, opening day 6 | days 6-10; SMA NA, NA, 7, 8, 9; one fill (day 9); final 1001 |
| internal `ledgr_run_window()`, 6-10 | identical to the run; final 1001 |
| `ledgr_sweep()`, same experiment | final 1006; `scoring_range` day 1 to day 10 |
| internal `ledgr_sweep_window()`, 6-10 | final 1006, although `scoring_range` records day 6 to day 10 |
| `ledgr_promote()` of that candidate | days 6-10, one fill, final 1001 |
| `ledgr_walk_forward()`, train 6-8, test 9-10 | fold row: hydration day 1, train scoring day 6, test day 9; train final 1004, Sharpe 16.97, time in market 0.625; test run days 9-10, no fill, final 1000 |
| `ledgr_backtest(start = day 6)` | identical to the run; final 1001 |
| `ledgr_precompute_features(start = day 6)` | records `warmup_range` day 1 to day 6 |

All four recorded observations are confirmed. The training time in market,
0.625, is five of eight pulses, so training metrics span days 1-8 rather than
scoring days 6-8. That directly witnesses metric input before the scoring
start.

**Mapping.** Each decision has one owner:
- decisions (1) and (5), the boundary: LDG-2969;
- decisions (2) to (4), the temporary rule: registered by LDG-2970, applied
  by LDG-2971;
- decisions (6) to (8): LDG-2971, which owns contracts, help, NEWS, the
  LDG-2615 handover, the stale comment and the memory-baseline input;
- the byte-unchanged archive: LDG-2971 acceptance 3, re-checked by the
  Workstream 18 review.

LDG-2970 acceptance 2 owns both hydration storage clauses: an omitted value
normalizes in the window object, fold rows and precompute coverage, and an
explicit earlier value refuses. LDG-2970 acceptance 3 owns no hidden earlier
precompute state. LDG-2971 acceptance 2 owns the train-only-hydration
mutation.

**Gaps:**
1. **`execution_start_utc` is a dead internal field.** Only the internal
   `ledgr_experiment_window()` sets it. Fold windows never pass it, it is not
   persisted, no export accepts it, and no production code reads it. Binding
   fills to it, as decision (1) and LDG-2969 do, invents new semantics for
   targets returned between the two clocks. No criterion tests a window where
   the two clocks differ.
2. **LDG-2969 acceptance 1 names observables sweeps don't expose.** It asks
   for no pre-scoring invocation, fill or event across five entry points, but
   a sweep exposes none of those. Its public observables are `scoring_range`,
   candidate `time_in_market`, `total_return` and `final_equity`, and retained
   return timestamps (`ledgr_sweep_returns()` under
   `ledgr_sweep_retention(returns = "completed")`). An invocation that trades
   nothing is invisible on a sweep, so that clause cannot fail there.
3. **Workstream 18 cannot close independently as written.** LDG-2968
   acceptance 2 lists three current failures. Only the first, sweeps acting
   on pre-scoring history, is a boundary claim. Promotion reproduction and the
   walk-forward training/test difference are value claims. They stay red after
   LDG-2969, because sweeps still hydrate features from day 1: on this fixture
   I predict, without having measured it, 1003 against the promoted 1001. The
   checker does not assign checks to groups.
4. **`ledgr_backtest()` is missing.** It is exported and takes `start`; no arm.
5. **Promotion is absent from Workstream 19's value table.** LDG-2970 acc. 1
   and LDG-2971 acc. 2 omit `ledgr_promote()`, the user-visible disagreement.
6. **The recursive witness is unnamed.** A feature whose value doesn't change
   with its start date cannot fail. Name `ledgr_ind_ema()`, derive its values
   from the fixture, and require day-6-start values to differ from
   day-1-start values.

## Type 2: Is This The Right Cut?

1. **Shape.** Yes. The boundary is a defect with one answer; feature
   initialization is a semantic choice with its own oracle.
2. **LDG-2969.** It changes only which pulses are executed and scored, chooses
   no hydration and claims no value parity. The intermediate tree is neither
   the old behavior nor the final one. That is acceptable because nothing is
   released between the workstreams, once gap 3 makes the intermediate state
   explicit.
3. **The restart rule.** It is the safest bounded rule. v11 Section 3 forbids
   hidden fetches of earlier history and a second warm-up rule, and only
   permits declared hydration, so no accepted obligation breaks. The cost is
   real: every walk-forward fold re-warms long lookbacks. LDG-2971's teaching
   must say so and keep it distinct from `cold_start_distorted`, which
   concerns opening positions.
4. **Keep and refuse rather than remove.** Retaining `hydration_start_utc`
   while refusing earlier values is more honest than an ignored value, and
   cheaper than removing a persisted column that WS3/WS4 will want back. A
   stored column equal to the training scoring start is redundant but true.
   The same rule settles gap 1.
5. **Coverage.** With gaps 4 and 5 patched, the rule covers run, backtest,
   sweep, promotion, explicit windows, precompute, training and testing. One
   shared range boundary in LDG-2971 avoids a second feature engine. Since the
   refusal is reachable only through internal constructors, its class belongs
   in contracts, not exported help.
6. **Units.** Two oracle-first pairs are honest units; nothing is padding or
   missing beyond gap 1.
7. **The breach is chosen, not inherent.** One workstream with one close
   review would hold 2/4 = 0.500. The split is defensible, because Workstream
   19 is a product-semantic choice reviewed apart from a defect repair, but
   the record should say so plainly.
8. **Exclusions.** Permanent hydration, recursive convergence and gaps,
   two-clock history, missingness, narrowing and the history APIs are all
   excluded, and no ticket adds them.
9. **`ledgr_history_matrix()`.** The UX-brief edit states that the adapter
   "is not a second reader and owns no cutoff, axis or missingness logic". The
   brief is non-binding, so the WS3 amendment must carry that sentence.

## Required Patches

- **Cut 9 decision (1), LDG-2968 and LDG-2969.** Treat `execution_start_utc`
  like hydration: omitted means scoring start, and a different explicit value
  refuses before execution. LDG-2968 adds the refusal arm. If distinct clocks
  are wanted instead, define how targets between them are handled and test a
  window where they differ.
- **LDG-2969 acceptance 1.** Name the observables per arm:
  - durable arms (run, backtest, promotion, walk-forward test): state,
    timestamps, fills, events, equity;
  - sweep arms: the metadata, metrics and retained returns in gap 2;
  - walk-forward training: fold and score rows.
- **LDG-2968 acceptance 2 and LDG-2969 acceptance 1.** Split the checker:
  - a boundary group that LDG-2969 turns green;
  - a value group (promotion reproduction, training versus testing, run/sweep
    values) that stays red until LDG-2971.
  State that Workstream 18 closes with the value group red.
- **LDG-2968, LDG-2970 and LDG-2971.** Add a `ledgr_backtest(start = ...)` arm.
- **LDG-2970 acceptance 1, LDG-2971 acceptance 2.** Require a sweep candidate's
  final equity to equal its promoted durable run.
- **LDG-2970 acceptance 1.** Name the recursive witness as in gap 6.
- **Cut 9 sequencing and the packet README.** Replace "inherent small-cut
  breach" with the chosen grain and its reason.

**Non-blocking:** a public `ledgr_sweep()` refuses `ledgr_precompute_features(start
= day 6)` today, so the LDG-2970 detector must consume it through a path that
accepts it.

PASS_AFTER_PATCHES
