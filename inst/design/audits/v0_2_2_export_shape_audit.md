# v0.2.2 Export Shape Audit

Type 1 audit, 2026-10-26. Question: does any of the 179 exports at HEAD
`8a00a3be` (branch `v0.2.2`) violate one of four named shapes in how the
public surface is cut, and what is the smallest repair? Read-only; no code,
tests, tickets, contracts, roadmap or horizon entries were changed. The
per-export census is `v0_2_2_export_shape_audit_exports.csv` beside this file.

The audit is about shape, not size and not usage. Two neighbouring questions
are already parked and are not reopened here:

- whether a thin block earns its keep (`horizon.md`, 2026-10-12 `[research]`
  "Prove or retire the thinly used product surfaces with real data":
  one maintainer decision per block after real Sharadar use, release after
  v0.2.2);
- whether an unused export becomes internal (`horizon.md`, 2026-10-12
  `[infrastructure]` "Structural gates deferred"; Cut 14 decision 8: "Export
  and unregistered-test enforcement remain deferred").

Usage counts appear below as signals of repair cost only, never as verdicts.

## 1. Method And Refs

- Baseline: `git show 8a00a3be:NAMESPACE`, 179 `export()` lines and 93
  `S3method()` lines. The R, man, vignette, test, README, `_pkgdown.yml`
  and `contracts.md` slices were extracted from that commit with
  `git archive`, so the dirty working tree played no part.
- The binding naming rules are `contracts.md` "Public Name Shapes"
  (`contract-public-name-shapes`), "Indicator And Rule Names"
  (`contract-public-indicator-and-rule-names`) and "Internal Names"
  (`contract-public-internal-names`), as bound by the accepted
  `rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md` (2026-06-12), whose
  Section 2 dispositioned 139 names one by one. 63 of today's 179 exports
  postdate that table and have never had an export-level naming disposition;
  5 of the 63 carry a finding below (the four newer sweep-return projections
  and `ledgr_align_weights`).
- Four shapes. S1 a layout or format choice expressed as a separate
  function name. S2 two public names for one operation, or dispatch on
  argument type written as two functions. S3 plumbing, fixtures or
  placeholders exported into user-facing groups. S4 a name that the bound
  naming rules forbid. A fifth, documentation-only observation (D) records
  family help topics named after one member, because the pkgdown reference
  index is built from topic names.
- Every finding was read in its enclosing function and its callers at the
  baseline commit; grep located, reading decided. No package was loaded
  and nothing was executed beyond the counting script; this is a reading
  audit of a surface, so no behavioural claim below rests on a probe.
- Counts per export (in the CSV): article use is the number of lines in
  `vignettes/**/*.qmd` and `README.md` calling the function; other-man use is
  the number of help pages other than its own that call it; test use is the
  number of lines in `tests/testthat/`; internal callers is the number of
  non-roxygen lines in `R/` outside its definition. The pkgdown group is the
  reference section listing the export's topic or alias, including the two
  `starts_with()` selectors for `ledgr_snapshot*` and `ledgr_ind_*`.

## 2. Findings

None of the findings is a correctness defect. All are surface shape. They
are ordered by how much of the surface they touch, not by severity.

| # | shape | exports | file:line at HEAD | evidence | smallest repair | consolidation | route |
| --- | --- | --- | --- | --- | --- | --- | --- |
| F1 | S1 | `ledgr_sweep_returns_wide`, `_panel`, `_matrix`, `_data_frame`, `_xts` | `R/sweep-retention.R:291`, `:413`, `:494`, `:510`, `:528` | Five names for layouts of one accessor. `_matrix`, `_data_frame` and `_xts` each call `ledgr_sweep_returns_panel()` and reshape its `$matrix`; `_wide` is a second normalization over the same resolver with its own `ts_utc` and hex-prefix column rules. The package already expresses layout as an argument elsewhere: `ledgr_history_frame(layout = c("wide", "long"))` (`R/history-frame.R:971`) with an `as.matrix()` method on the result. Article use 1, 1, 0, 0, 0; test use 6, 15, 5, 3, 1. `contract-result-return-panels` (L2610-2641) names `_panel()` and `_wide()`; the other three have no contract sentence. | One `ledgr_sweep_returns(x, candidates, value, layout = c("long", "wide", "panel"))`, with `as.matrix()` and `as.data.frame()` methods on the panel class; keep `xts` as a method under the existing optional-package pattern or drop it. Move the `_wide()` column-naming sentences to the `layout = "wide"` clause. | independent | next release, result-reader line of the deferred maintenance inventory; the earn-its-keep question for "the three sweep-retention projections" stays with the horizon entry |
| F2 | S1 | `ledgr_pulse_features`, `ledgr_pulse_wide` | `R/feature-inspection.R:348`, `:556` | Long and one-row-wide layouts of the same pulse inspection. `contract-context-inspection` (L2066-2074) names both and binds the wide `__` delimiter; `contract-context-feature-resolution` (L2013) names both as explicit-map consumers. Article use 4 and 2. | `ledgr_pulse_features(..., layout = c("long", "wide"))`; the `__` sentences move under the wide layout. | independent | next release, same line as F1 |
| F3 | S2 | `ledgr_promotion_context`, `ledgr_run_promotion_context` | `R/promotion-context.R:272`, `:296`; both end in `ledgr_fetch_promotion_context(con, run_id)` at `:308` | Dispatch on argument type written as two functions: one takes a `ledgr_backtest`, the other a `ledgr_experiment` plus `run_id`, and they differ only in how the store connection is opened. The first also reads a run artifact without the `ledgr_run_` family prefix that R1 requires and that its twin carries. No contract sentence names either. Article use 4 and 1; test use 21 and 2. Both were kept in the 2026-06 table without the duplication being noted. | One `ledgr_run_promotion_context(x, run_id = NULL)` accepting a backtest, or an experiment plus `run_id`; or an S3 generic in the `ledgr_candidate()` pattern. | independent | next release, symbol-surface line |
| F4 | S2 | `ledgr_run_fills` | `R/backtest-fills.R:57-58`; `R/backtest-results.R:1184-1201` | Second door to one implementation: `ledgr_run_fills(bt)` and `ledgr_results(bt, "fills")` both call `ledgr_extract_fills_impl()`. The 2026-06 synthesis unexported `ledgr_compute_equity_curve` as "a duplicate door to `ledgr_results(bt, 'equity')`" and kept `ledgr_run_fills` only for its "lazy / `stream_threshold` / `ledgr_fills_cursor` contract". That contract no longer exists: `contract-result-fills-and-sweep-restoration` (L2518) binds "exactly one public formal ... no public cursor, lazy-read, or row-threshold mode". Article use 0, other-man use 0, test use 26. `contract-result-reconstruction` (L2506) pairs the two names as user-facing read helpers. | Drop `ledgr_run_fills()` under the pre-CRAN policy and move the L2506 and L2518 sentences to `ledgr_results(bt, "fills")`; re-point the 26 test lines. | independent | next release, result-reader line |
| F5 | S2 | `ledgr_backtest`, `ledgr_backtest_bench` | `R/backtest.R:86-103`, `:148-160`; `R/backtest-results.R:322-329`; `R/backtest-runner.R:192-202` | Second execution entry beside `ledgr_run()`: 18 formals, data-first, builds a temporary snapshot, runs dense execution only and refuses point-in-time snapshots. `contract-execution-entry-points` (L84-90) already demotes it to "a lower-level compatibility surface"; its help title still reads "Run a backtest (v0.1.2)". It is the current short hello-world path: article use 7, other-man use 13, test use 112, the largest test footprint of any finding. Cut 14 decision 6 expressly did not authorize its removal. `ledgr_backtest_bench()` (allowlisted) reads the telemetry registry the shared runner fills for every run, yet its error text says "Run ledgr_backtest() to capture telemetry" (`:329`); article use 0. | Owned by the execution-core consolidation, whose bars-only acceptance reads "the short hello-world path stays short" and "consolidation removes the dense engine, not the dense use case": either `ledgr_backtest()` becomes sugar over `ledgr_experiment()` plus `ledgr_run()` on the one engine, or it goes and the quickstart uses the experiment path. Fix the bench message either way. | owned by consolidation | `macro_plan.md#execution-core-consolidation` |
| F6 | S3 | `ledgr_opening_from_broker` | `R/experiment.R:686-691` | An exported placeholder: the body is a single unconditional abort with `ledgr_broker_adapter_not_supported`, described as "a reserved adapter hook" since v0.1.7. Listed under pkgdown Experiment Workflow. Article use 0, other-man use 0, one test asserting that it fails. No horizon or roadmap entry schedules a broker adapter; the word appears only inside the parked OMS and live-trading cluster. The 2026-06 table kept it as "future-scoped". | Unexport or delete until an adapter exists. A missing function tells a reader more than a function that always fails. | independent | next release, symbol-surface line |
| F7 | S3 | `ledgr_state_reconstruct`, `ledgr_candidate_reproduction_key`, `ledgr_demo_sma_crossover_strategy` | `R/public-api.R:156`; `R/sweep.R:646`; `R/demo-strategies.R:35` | The package has a plumbing tier (pkgdown Low-Level Utilities: `ledgr_iso_utc`, `ledgr_utc`, `ledgr_db_init`, `ledgr_temp_store`, `ledgr_validate_schema`, `ledgr_backtest_bench`, `ledgr_sim_bars`, `ledgr_sim_pit_inputs`), but three names of the same kind sit in user groups. `ledgr_state_reconstruct()`, self-described as "a low-level DBI recovery helper", is under Backtests while its recovery twin `ledgr_db_init()` is Low-Level; the 2026-06 synthesis Section 4 bound them as one pair with one Recovery section. `ledgr_candidate_reproduction_key()` is an identity key with 0 internal callers under Experiment Workflow. `ledgr_demo_sma_crossover_strategy()` calls itself "a teaching fixture" and sits under Strategy Development. `ledgr_metric_context_hash()` under Metric Assumptions is taught in articles 3 times and stays. | Regroup the three in `_pkgdown.yml`; doc only. Consider `@keywords internal` for the reproduction key if no article needs it. | independent | the next-release documentation-surface input (macro plan, Section 5 inputs: "the documentation surface, paired with the export census") |
| F8 | S4 | `ledgr_select_top_n`, `ledgr_passed_warmup`, `ledgr_align_weights` | `R/strategy-helpers.R:179`; `R/feature-map.R:361`; `R/history-frame.R:1748`, origin token at `:1789` | `contract-public-name-shapes` (L44-47): "Verb-first exports are limited to" five names. These three are verb-first and not among them. The same 2026-06 synthesis that bound the rule kept the first two verb-first ("D1 resolved to prefix all six") without adding them to the allowlist, and its R1 opens with "Artifact-scoped exports", which these are not. `ledgr_align_weights` arrived with Cut 19 (2026-10-24). The contract names them 6, 7 and 4 times under `contract-strategy-outputs`, `contract-strategy-decision-axis`, `contract-strategy-feature-maps`, `contract-strategy-reproducibility` and `contract-context-pulse-data`; article use 10, 16, 6. The rule and the surfaces it governs disagree. | Maintainer choice, in order of size: (a) amend R1 to scope the prohibition to artifact-scoped exports and name the strategy-DSL helpers as outside it, which matches the synthesis's intent; (b) add the three to the allowlist; (c) rename (`ledgr_selection_top_n`, `ledgr_warmup_passed`, `ledgr_weights_align`), touching 17 contract sentences, the stored origin token and 32 article lines. | independent | next release; needs a contracts amendment, which the audit does not make |
| F9 | D | 24 exports in six families (listed below) | `man/ledgr_cost_spread_bps.Rd`, `ledgr_risk_chain.Rd`, `ledgr_sweep_save.Rd`, `ledgr_walk_forward_open.Rd`, `ledgr_feature_grid.Rd`, `ledgr_fold.Rd` | Family help topics named after one member, so the pkgdown reference index shows that member as the family's entry: the five cost constructors appear as `ledgr_cost_spread_bps`, the four risk helpers as `ledgr_risk_chain`, the four saved-sweep functions as `ledgr_sweep_save`, the three walk-forward readers as `ledgr_walk_forward_open`, the five grid constructors as `ledgr_feature_grid` (which also hides `ledgr_strategy_grid`), the three fold constructors as `ledgr_fold`. The package already has the other pattern: `ledgr_objective_criteria`, `ledgr_corporate_action_policy`, `ledgr_availability_policy`, `ledgr_facts_inspection`, `ledgr_metric_context`. | `@rdname` each family to a family-named topic (`ledgr_cost`, `ledgr_risk`, `ledgr_sweep_store`, `ledgr_walk_forward_evidence`, `ledgr_grid`, `ledgr_folds`) and update `_pkgdown.yml`; doc only, no export changes. | independent | the next-release documentation-surface input, as F7 |

F9 members: `ledgr_cost_spread_bps`, `ledgr_cost_fixed_fee`,
`ledgr_cost_notional_bps_fee`, `ledgr_cost_zero`, `ledgr_cost_chain`;
`ledgr_risk_chain`, `ledgr_risk_none`, `ledgr_risk_long_only`,
`ledgr_risk_max_weight`; `ledgr_sweep_save`, `ledgr_sweep_open`,
`ledgr_sweep_list`, `ledgr_sweep_info`; `ledgr_walk_forward_open`,
`ledgr_walk_forward_scores`, `ledgr_walk_forward_folds`; `ledgr_feature_grid`,
`ledgr_strategy_grid`, `ledgr_grid_cross`, `ledgr_grid_named`,
`ledgr_grid_add_baseline`; `ledgr_fold`, `ledgr_folds_rolling`,
`ledgr_folds_anchored`.

### Shape totals

| shape | exports | findings |
| --- | ---: | --- |
| S1 layout as a name | 7 | F1, F2 |
| S2 two names for one operation | 5 | F3, F4, F5 |
| S3 plumbing or placeholder in a user group | 8 | F6, F7 (the CSV also tags `ledgr_metric_context_hash` and the three Low-Level fixtures as S3 with no finding) |
| S4 forbidden name | 3 | F8 |
| D family topic named after a member | 24 | F9 |
| decided elsewhere | 7 | none (Section 3) |
| in flight, Cut 21 | 8 | none (Section 5) |
| note, not a violation | 6 | none (Section 4) |
| none | 111 | |

If every independent repair landed as written, the surface would lose
`ledgr_sweep_returns_wide`, `_panel`, `_matrix`, `_data_frame`, `_xts`,
`ledgr_pulse_wide`, `ledgr_promotion_context`, `ledgr_run_fills` and
`ledgr_opening_from_broker`: 9 exports, 179 to 170, with no capability
removed. F5 is decided by the consolidation and is not counted. F8 and F9
change names or help topics, not the export count.

## 3. Decided Elsewhere, Not Reopened

- `ledgr_history_frame()` and `ledgr_history_matrix()` are a layout pair, but
  Cut 19 decision 1 (2026-10-24) deliberately made the matrix a direct
  classed reader with the frame as an adapter. Not an S1 finding.
- `ledgr_db_init()` and `ledgr_state_reconstruct()` stay public as the
  recovery pair (naming synthesis Section 4; Cut 14 decision 2 keeps
  `ledgr_db_init()` as create-empty-or-open-current). Only their grouping is
  in F7.
- `ledgr_backtest_bench()`, `ledgr_compute_metrics()`,
  `ledgr_precompute_features()`, `ledgr_validate_schema()` and
  `ledgr_promote()` are the closed verb-first allowlist. Conformant.
- `ledgr_indicator()` is the custom-constructor root of the infrastructure
  prefix (synthesis Section 2.2, "Indicator infrastructure root/custom
  constructor"); R7's `ledgr_ind_*` versus `ledgr_indicator_*` split holds
  for all 13 indicator names.

## 4. Checked And Clean

- R2, one reopen verb: `ledgr_run_open()`, `ledgr_sweep_open()`,
  `ledgr_snapshot_open()`, `ledgr_walk_forward_open()`; no other reopen
  vocabulary.
- R3, no `extract_`, `get_` or `fetch_` public accessor. None.
- R5, every export prefixed. All 179.
- Constructor families conform to family-first naming and are the pattern to
  keep: cost 7, risk 5, objective 8, calendar 3, folds 3, grid 3, schedule
  7, facts 11, corporate 4, signal 4, target 3. `ledgr_grid_add_baseline` is a
  grid family action, as the synthesis recorded.
- Confusable pairs that break no rule and are recorded only so the next
  reviewer does not re-derive them: `ledgr_param()` declares and
  `ledgr_parameters()` inspects (the latter has 0 article use and 3 test
  lines); `ledgr_weights()` constructs and `ledgr_weight_equal()` derives;
  `ledgr_utc()` returns `POSIXct` and `ledgr_iso_utc()` returns strings (the
  latter has 0 article use, 15 internal callers and 26 test lines). Both
  timestamp utilities already sit in Low-Level Utilities.
- `ledgr_temp_store()` is tagged S3 in the CSV as a fixture but carries no
  finding: 11 article lines use it and it is already in Low-Level Utilities.

## 5. Observed In Passing, Routed Elsewhere

- The eight Cut 21 scheduler exports (`ledgr_strategy_schedule` and the seven
  `ledgr_schedule_*` constructors) conform to R1 but their topic
  `ledgr_strategy_schedule` is in no `_pkgdown.yml` reference section at
  `8a00a3be`; pkgdown fails a build on a topic missing from the index. For
  the open Cut 21 teaching workstream, not for this audit.
- `ledgr_sweep_returns_wide()` builds its columns in an R-level loop over
  candidates (`R/sweep-retention.R:304-310`) on a result-reader path. That
  is the optimization manual's concern, not this audit's; whoever picks up F1
  should rebuild the wide layout by index at the same time.

## 6. Routing

- Consumer: the next release's deferred maintenance inventory
  (`ledgr_roadmap.md`, "Deferred maintenance inventory": "the plotting,
  print/result-reader and symbol-surface work"), reconciled at packet
  preparation. F1 to F4 and F6 ride the result-reader and symbol-surface
  lines; F7 and F9 ride the documentation-surface input already listed in
  the macro plan's Section 5 next-release inputs; F8 needs a maintainer
  decision on a contracts amendment before any rename.
- F5 belongs to the execution-core consolidation
  (`macro_plan.md#execution-core-consolidation`), which already owns the
  bars-only happy path and the dense engine's removal.
- Nothing here is a cleanup ticket. Each repair touches contract sentences
  cited above, and F4, F6 and F8 change what a user can call; those are
  product decisions under the pre-CRAN policy, one each, recorded where the
  owning cut records them.
- This audit authorizes no removal, rename, unexport, contract amendment,
  ticket or release commitment. The parked earn-its-keep and usage-gate
  questions keep their horizon entries unchanged.
- Routed 2026-10-26 (maintainer): horizon entry "Export shape audit findings
  and their routes" and the roadmap's deferred maintenance inventory. The
  tiering follow-up from F7 is the carried roadmap commitment "Explicit
  export tiering", scheduled after the next release's cleanup work and before
  the first CRAN tag, with its own horizon entry "Explicit export tiering
  before CRAN".
