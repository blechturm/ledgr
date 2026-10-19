# Workstream 46 history representation sizes (LDG-3074)

Size evidence for `inst/design/ledgr_v0_2_2_spec_packet/history_representation_map.md`.
No vendor row is used.

## Files

- `representation_sizes.R`: measures `object.size()` and serialized length
  of every history representation the map lists, at the H1 shape, on one
  tree. It reuses `dev/bench/v0_2_2_public_history/fixture.R` (1,166
  instruments by 7,213 weekday sessions, 580 complete membership sets of 600
  members, 20 labelled delistings, 40 late-known inactive intervals, about
  0.5 percent missing member bars, five cash dividends).
- `evidence/representation_sizes_h1.csv` and `.log`: the recorded run.

## Reproduction

```sh
Rscript dev/bench/v0_2_2_history_simplification/representation_sizes.R \
  <tree> <h1.duckdb> <out.csv> [--build]
```

`--build` creates the fixture snapshot first (schema 122, about four minutes
and 1.5 GB). The recorded run used a snapshot built by the same fixture on
the Workstream 42 candidate tree and copied unchanged; the substrate,
features and staged invariants were then built by the measured tree.

## Recorded run (2026-10-18)

- Tree: branch `ws46/history-simplification` at `9b0b304d` (no product code
  changed before the measurement), loaded with `pkgload::load_all()`.
- Host: Windows 11, R 4.6.1, duckdb 1.5.6.9000, collapse 2.1.8; one R
  process, run alone. Sizes do not depend on host load; the one elapsed time
  in the log (substrate built in about 7.4 s) is disclosure only.
- Dense rows are synthetic complete matrices of the same shape.
- The provider row's serialized length includes environments captured by its
  closures, which reach the substrate; the provider is never serialized in
  production.

## Recorded run on the accepted Workstream 43 tree (2026-10-19)

- Tree: `b9d098c8` (integration merge of the accepted Workstream 43),
  extracted with `git archive` into a scratch directory and loaded with
  `pkgload::load_all()`. This is the LDG-3074 map's size record and the
  LDG-3075 "before" arm: `evidence/representation_sizes_h1_b9d098c8.csv`
  and `.log`.
- The fixture snapshot was rebuilt with `--build` by the same tree, because
  Workstream 43 added `ledgr_feature_history_rule_version` to the
  store-format bindings and older stores refuse at open.
- Same host and software as above. Another R process ran at the same time
  for part of the run; sizes do not depend on load and the substrate build
  time in the log (about 10 s) is disclosure only.

## Recorded run after LDG-3075 (2026-10-19)

- Tree: the `ws46/history-simplification` working tree with the LDG-3075
  product changes (before their commit), on the same snapshot as the
  `b9d098c8` run: `evidence/representation_sizes_h1_ldg3075.csv` and `.log`.
- Absent fields record zero bytes (`expected`, `halted`,
  `missing_expected_bar`, `inactive_print`, `families`, the plan's
  `sessions` and the staged `precomputed_features`).
- Same host and software. Sizes do not depend on load.
