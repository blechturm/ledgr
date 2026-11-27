# LDG-3281: the feature routes end to end on the new pin

Cut 27 decision 2. The pin is 7f65733f. Every run starts from
`C:/Users/maxth/ledgr-wt/cut27-scratch/run`, outside any source package.

## Workloads (`parity/loop_workloads_features.R`)

`fe_bar_native` and `fe_declared` run, lean against the pin, the routes of
the retired `feature_bridge.R`, on the feature oracle's fixtures
(`dev/feature_parity/corpus.R`):
- **Clocks:** the bar-native basket, and the declared-session universe
  with gaps and a late known_inactive fact.
- **Features:** the oracle's e2e indicators, plus two parameterised aliases
  (`signal` = RSI(`rsi_n`), and the BBands dn/up outputs with `bb_n`).
- **Candidates:** two, with `rsi_n` 3 and 5.
- **Routes:** four. They are implicit preparation, implicit on two workers,
  an explicit `ledgr_precompute_features()` reused through
  `precomputed_features`, and that reuse on two workers.

The strategy reads every current feature (`ledgr_pulse_features()`). Each
instrument's finite values, weighted by their alias's rank, are summed, and
the target is `floor(|s| * 13) %% 3` shares. So a wrong value, a swapped
alias or an unused feature changes the trades.

The oracle's builders let ledgr stamp the snapshot id with the time, so the
two arms' stores got different ids. The first run showed this as a
`sweep_attrs` difference. The workload now fixes the id with a temporary
binding around `ledgr_snapshot_from_df()`. `corpus.R` is unchanged and no
field is dropped from the comparison.

The reach predicates are checked on the pin's tables:
- both worker routes dispatched four tasks;
- every route ended both candidates with trades, and with the fixture's
  status;
- the four routes agree.

On the bar-native fixture the two candidates also end differently, so the
parameterised alias reaches the targets. The declared fixture's late fact
stops both candidates INCOMPLETE before RSI 3 and 5 diverge there; the
variants below show its features drive the outputs.

## Results

`routes_debug0.csv` and `routes_debug1.csv`, with `--freeze`: 2 workloads,
32 tables, 0 different, PASS 2, 2 of 2 frozen paths checked, debug off and
on. Each worker route's records come from `pin-lib-7f65733f/ledgr` and the
lean envelope (`routes_debug*_workers.csv`). The freeze rows (8 lean folds
each) are in `loop_freeze_changes.R`.

## Faults (`loop_parity.R`, `loop_variant_changes.csv`)

| variant | fault | caught |
| --- | --- | --- |
| feat_value_perturbed | one projected value doubled in the lean consumer (`feature_fn`) | debug 0 on the table difference; debug 1 also by the context comparator ("Lean context field ... differs from the pin's"), declared as its expected condition |
| feat_alias_swapped | a candidate's first two aliases mapped to each other's features (`active_alias_map`) | on the table difference, debug off and on |

The variant driver with `--workloads=fe_bar_native,fe_declared`
(`variants_debug0.log`, `_debug1.log`, `variants/`): 4 manifest rows, 2
variants, 0 failures in each debug setting. At debug 0 the five negative
controls fail closed.

## Retirement

`feature_bridge.R` is retired. Its routes and its two faults are now
end-to-end workloads and variants, and its evidence stays in
`../ldg3273/bridge/`. `lean_core_interface.md` Section 19.14 marks
obligation 4 (the integrated feature path) discharged.
