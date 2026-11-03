# WS6 pre-change inventory

Baseline: `74015f96` (product tree unchanged through `4342c39b`).

This record freezes the source population owned by LDG-3194 before the
context-frame implementation changes. It is an inventory and detecting-test
plan, not a new semantic authority.

## Runtime seams

- `R/fold-engine.R`: `ledgr_fold_stage_decide()` constructs `bars_current`,
  `features_current` and `features_wide_current`; service preparation supplies
  `empty_feature_table`, `availability_feature_name_state` and
  `availability_feature_lookup_state`.
- `R/pulse-context.R`: `ledgr_pulse_context()`,
  `ledgr_attach_feature_helpers()`, `ledgr_update_pulse_context_helpers()`,
  `ledgr_refresh_pulse_context_lookup()` and
  `ledgr_filter_pulse_context_features()` store or reconstruct the old frames.
  `ledgr_pulse_context_bar()`, `ledgr_feature_table_ready()`,
  `ledgr_feature_names()`, `ledgr_features_wide()` and the attached
  `.feature_table_current` closure are representation machinery to retire.
- `R/runtime-projection.R`: `ledgr_projection_feature_table()`,
  `ledgr_projection_feature_table_schema()`,
  `ledgr_projection_features_wide()` and
  `ledgr_projection_features_wide_columns()` are the projection frame
  builders. The projection feature matrices, prepared name lookup and vector
  accessor remain authoritative primitives.
- `R/feature-inspection.R`: `ledgr_pulse_features()` and
  `ledgr_pulse_wide()` currently read the retired long frame and rebuild rows
  with nested loops and `rbind()`.
- `R/pulse-snapshot.R`: snapshot-form inspection forces the lazy long table,
  adds five inspection-only metadata fields and an alias hash, and `print()`
  reads `ctx$bars`.
- `R/backtest-runner.R` and `R/strategy-preflight.R`: strategy error and
  preflight readers mention the retired representation.

## Direct registered-test population

The representation-facing population is in `test-indicator-tools.R`,
`test-pulse-context-accessors.R`, `test-strategy-context-entrances.R`,
`test-strategy-context-projection.R`, `test-feature-map-read-surface.R`,
`test-feature-inspection.R`, `test-workstream8-exact-parity.R`,
`test-flat-lazy-context.R`, `test-backtest-s3.R`,
`test-documentation-contracts.R` and `test-ws4a-carrier.R`. Helper-inspection
tests must move to a real run or `ledgr_pulse_snapshot()` context;
representation-only oracles are deleted.

## Maintained non-test and teaching population

- `dev/bench/shared/run_benchmarks.R` has three `ctx$features_wide` reads.
- The affected contract groups are Pulse data, Feature resolution, Prepared
  views, Inspection, Strategy reproducibility/preflight and Strategy teaching.
- Source and rendered context references, the execution-fold-core, features
  and observability/determinism manuals, helper help pages and NEWS are owned
  by WS21, not this workstream.

## Baseline controls and expected differences

`dev/spikes/ctx_frame_views/response_probe.R .` was rerun on the unchanged
product tree on 2026-11-03. The real declared-session run completed, the held
nonmember and missing bar were present, runtime and experiment-form inspection
agreed, retained helper results stayed frozen, and the 600 x 3 descriptive
timings completed. The registered expected differences are:

1. `bars`, `bar`, `feature_table` and `features_wide` leave `names()`/`str()`
   and refuse through `$`/`[[`.
2. Runtime and experiment-form helper output gains active aliases; unmapped
   long rows use Daxis order; a mapped empty Daxis returns typed output.
3. `feature_params`, `active_alias_map`, `alias_map_json`, `alias_map_hash`
   and `alias_map_version` leave snapshot-form contexts, and no alias hash is
   computed there.

Condition comparisons pin class and feature-ID set rather than prose. Every
other value, target, fill, public result and frozen-context control remains
unchanged.

## Failure-sensitive mutation matrix

WS20 registers one detector for each of these independent changes:

1. restore either P2 frame constructor;
2. hide a frame beneath the context or `.pulse_lookup`;
3. rebuild readable names at a pulse or read;
4. introduce an explicit-map memo/cache;
5. restore one retired public name or a compatibility alias;
6. bypass prepared alias, Daxis/map/radix order or typed mapped-empty output;
7. restore snapshot metadata or alias hashing;
8. expose a reusable fold buffer through a retained context/helper result;
9. make print or strategy-error handling read a frame or compute a hash;
10. restore per-row timestamp normalization in the fixture adapter.

The response probe stays descriptive. Registered test blocks, not this file,
own failure sensitivity.
