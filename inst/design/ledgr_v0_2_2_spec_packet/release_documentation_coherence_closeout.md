# Workstream 65: public documentation coherence

**Ticket:** LDG-3116
**Candidate:** Cut 23 documentation tree after the accepted Workstream 68
correction
**Purpose:** verify one coherent reader journey over the shipped v0.2.2
surface without changing product behavior.

## Result

The public documentation now has one stable progression:

```text
fit and first run -> strategy and data primitives -> research validation
-> point-in-time evidence -> portfolio construction -> durable evidence
```

The audit found four bounded teaching drifts and one product defect:

1. README named interactive installed-help discovery but omitted the required
   browser-free `system.file("doc", package = "ledgr")` route.
2. the survivorship article implemented two decision dates inside its strategy
   even though v0.2.2 ships declarative schedules;
3. the scheduler's one-pulse-per-session boundary was present in help but not
   in the principal scheduling article; and
4. parallel workers were taught without the accepted memory boundary.

The public survivorship example also exposed a scheduler defect: a skipped
decision pulse advanced valuation correctly but did not retain the held stale
or frozen mark evidence consumed by valuation summaries and warnings. That
defect stopped this workstream, became LDG-3119 in Workstream 68, and was
corrected and independently reviewed before the documentation audit resumed.

Those four issues are corrected in the source and regenerated renders. No
export, signature, schema, identity or threshold changed under LDG-3116.
Workstream 68 made the bounded runtime and contract correction owned by
LDG-3119.

## Source-derived article matrix

The matrix follows `_pkgdown.yml` and accounts for README plus all 28 article
sources. "Next" records the principal handoff, not every optional cross-link.

| Source | Audience | Prerequisite | Promised outcome | Primary concepts | Primary public calls | Next |
| --- | --- | --- | --- | --- | --- | --- |
| `README.md` | first-time evaluator | R 4.6 and GitHub installation | understand ledgr's scope and run, inspect and reopen one backtest | sealed snapshot, experiment, ledger-derived result, explicit limits | `ledgr_snapshot_from_df()`, `ledgr_experiment()`, `ledgr_run()`, `ledgr_results()`, `ledgr_run_open()` | Quickstart |
| `articles/who-ledgr-is-for.qmd` | evaluator choosing a framework | none | decide whether ledgr's correctness-first daily research scope fits | audience, non-goals, alternatives | none | Quickstart |
| `quickstart.qmd` | new user | package installed | complete one run, sweep and promotion | experiment, candidate grid, sweep, promotion | `ledgr_experiment()`, `ledgr_run()`, `ledgr_sweep()`, `ledgr_candidate()`, `ledgr_promote()` | Data input or Strategy Basics |
| `data-input-and-snapshots.qmd` | researcher bringing bars | tabular OHLCV data | validate, seal, reopen and close a snapshot | bar schema, seal, snapshot identity, persistent store | `ledgr_snapshot_from_df()`, `ledgr_snapshot_from_csv()`, `ledgr_snapshot_open()`, `ledgr_snapshot_info()` | Strategy Basics; Point-In-Time Inputs for richer evidence |
| `strategy-development.qmd` | first strategy author | sealed snapshot | write and run causal strategies with explicit intent | `ctx`, signal, selection, weights, target, hold | `ledgr_signal_return()`, `ledgr_select_top_n()`, `ledgr_weight_equal()`, `ledgr_target_rebalance()`, `ledgr_run()` | Indicators or Strategy Authoring Tools |
| `indicators.qmd` | strategy author declaring features | Strategy Basics | declare, map, inspect and consume built-in and adapter-backed features | feature identity, aliases, first-valid warmup, gap contracts | `ledgr_ind_sma()`, `ledgr_ind_returns()`, `ledgr_ind_ttr()`, `ledgr_feature_map()`, `ledgr_pulse_features()` | Leakage; TTR or Custom Indicators for depth |
| `leakage.qmd` | researcher auditing causality | strategies and features | recognize strategy, feature and source-data leakage boundaries | decision-time context, captured data, point-in-time knowledge | `ledgr_selection()`, `ledgr_target_quantity()`, `ledgr_utc()` | Metrics and Accounting; Walk-Forward |
| `metrics-and-accounting.qmd` | result reader | one completed run | distinguish targets, fills, trades, equity and recomputed metrics | next-open execution, event ledger, metrics, final-bar behavior | `ledgr_results()`, `ledgr_compute_metrics()`, `ledgr_run_compare()` | Risk and Cost; Metric Contexts |
| `risk-and-cost.qmd` | researcher modelling implementability | strategy targets and execution timing | compose explicit risk, timing and cost policies | long-only filter, max weight, spread, fee, next open | `ledgr_risk_chain()`, `ledgr_cost_chain()`, `ledgr_timing_next_open()` | Execution Semantics; Experiment Store |
| `experiment-store.qmd` | researcher managing durable runs | sealed snapshot and completed runs | list, label, compare, archive, reopen and recover evidence | run identity, durable store, reconstruction, archive | `ledgr_run_list()`, `ledgr_run_info()`, `ledgr_run_compare()`, `ledgr_run_open()`, `ledgr_state_reconstruct()` | Reproducibility |
| `reproducibility.qmd` | researcher preserving a study | experiment and store basics | understand what ledgr identifies and what the author must freeze | config identity, strategy tiers, source capture, mutable state | `ledgr_strategy_preflight()`, `ledgr_run_info()`, `ledgr_run_strategy()` | Research Workflow |
| `research-workflow.qmd` | researcher iterating on a hypothesis | run and store basics | move from a named idea through revisions to explicit selection | project topology, labels, comparisons, research notes | `ledgr_run()`, `ledgr_run_compare()`, `ledgr_run_label()` | Sweeps; Selection Integrity |
| `sweeps.qmd` | researcher exploring parameters | one experiment and parameterized feature | run, inspect, persist and promote a complete candidate table | grid identity, retention, failures, compiled accounting, worker memory | `ledgr_sweep()`, `ledgr_sweep_review()`, `ledgr_sweep_save()`, `ledgr_candidate()`, `ledgr_promote()` | Selection Integrity; Walk-Forward |
| `selection-integrity.qmd` | researcher challenging a chosen candidate | retained sweep evidence | evaluate overfitting and minimum evidence without mistaking diagnostics for validation | PBO, DSR, MinTRL, business objectives | `ledgr_pbo()`, `ledgr_dsr()`, `ledgr_min_track_record()`, `ledgr_business_objective()` | Walk-Forward |
| `walk-forward.qmd` | researcher performing held-out evaluation | candidate grid and explicit selection rule | run rolling train/test selection and read degradation | folds, training sweep, selection rule, carried versus flat test state | `ledgr_folds_rolling()`, `ledgr_rule_argmax()`, `ledgr_walk_forward()` | Causal History for historical inputs |
| `causal-history.qmd` | strategy author needing historical panels | an existing sealed point-in-time snapshot | read causal frames or matrices, admit samples and use them across folds | lookback, selection metadata, carry evidence, bounded versus history-dependent inputs | `ledgr_history_frame()`, `ledgr_history_matrix()`, `ledgr_history_info()`, `ledgr_passed_warmup()`, `ledgr_align_weights()` | Point-In-Time Inputs; Minimum Variance |
| `point-in-time-inputs.qmd` | adapter or data author | bars and source facts | prepare effective-time and knowledge-time evidence and seal it | sessions, membership, trading status, lifetime, corporate actions | `ledgr_facts()`, `ledgr_facts_sessions()`, `ledgr_facts_membership_snapshots()`, `ledgr_snapshot_from_df()` | Missing Data; Survivorship Bias |
| `missing-data-and-sessions.qmd` | researcher facing holes or venue closures | point-in-time facts | distinguish closed sessions, missing bars, restrictions, stale marks and frozen assumptions | expected sessions, availability, mark ageing, refusal, quarantine | `ledgr_history_policy()`, `ledgr_valuation_stale()`, `ledgr_valuation_summary()`, `ledgr_run_explain()` | Corporate-Action Cash; Survivorship Bias |
| `corporate-action-cash.qmd` | researcher modelling dividends | bars plus a cash-distribution fact | compare modelled cash settlement with strict refusal | entitlement, effective time, payment evidence, policy | `ledgr_corporate_actions_research()`, `ledgr_corporate_actions_strict()`, `ledgr_corporate_action_summary()` | Adapter Authoring; Survivorship Bias |
| `survivorship-bias.qmd` | researcher comparing historical and survivor universes | point-in-time membership and session concepts | run the same scheduled strategy on survivor-only and historical universes and inspect valuation assumptions | membership, held nonmember, stale/frozen valuation, terminal limits, explicit schedule | `ledgr_universe_members()`, `ledgr_strategy_schedule()`, `ledgr_schedule_dates()`, `ledgr_valuation_summary()`, `ledgr_run_explain()` | Strategy Authoring Tools; Execution Semantics |
| `strategy-authoring-tools.qmd` | strategy author composing reusable rules | Strategy Basics and Indicators | build, pulse-test, schedule and run signal-to-target pipelines | signal, selection, weights, state, schedule, explicit hold | `ledgr_pulse_snapshot()`, `ledgr_signal_feature()`, `ledgr_weight_equal()`, `ledgr_strategy_schedule()` | Minimum Variance; Sweeps |
| `minimum-variance.qmd` | portfolio researcher | Causal History and `quadprog` | implement one complete scheduled long-only estimator without rebuilding identity | causal matrix, readiness, covariance, solver, aligned weights, full target | `ledgr_history_matrix()`, `ledgr_passed_warmup()`, `ledgr_align_weights()`, `ledgr_target_rebalance()`, `ledgr_schedule_month_start()` | Walk-Forward; Survivorship Bias |
| `ttr-indicators.qmd` | user integrating maintained TTR calculations | Indicators | declare supported TTR outputs and inspect warmup rules | adapter boundary, bundles, output columns, availability support | `ledgr_ind_ttr()`, `ledgr_ind_ttr_outputs()`, `ledgr_ind_ttr_warmup_rules()` | Custom Indicators |
| `custom-indicators.qmd` | feature author | Indicators and causal-boundary basics | implement scalar or series definitions with explicit contracts | `fn`, `series_fn`, required bars, stability, gap behavior | `ledgr_indicator()`, `ledgr_feature_contracts()`, `ledgr_adapter_r()`, `ledgr_adapter_csv()` | Leakage; Adapter Authoring |
| `corporate-action-adapter-authoring.qmd` | vendor-adapter author | Point-In-Time Inputs and cash actions | translate a source into canonical corporate-action facts with provenance | canonical header, units, validation flags, source identity | `ledgr_facts_equity_corporate_actions()`, `ledgr_snapshot_from_df()`, `ledgr_corporate_action_summary()` | Cash Distributions; Metric Contexts |
| `metric-contexts-and-conventions.qmd` | advanced metric consumer | Metrics and Accounting | make cadence, calendar and risk-free assumptions explicit and comparable | metric context, annualization, hash, promotion context | `ledgr_metric_context()`, `ledgr_metric_context_hash()`, `ledgr_compute_metrics()` | Sweeps or Selection Integrity |
| `execution-semantics.qmd` | strategy author debugging fills | targets and accounting basics | understand the target-to-fill boundary and common zero-fill outcomes | desired holdings, next-open fill, dense cash boundary, final bar | `ledgr_results()`, `ledgr_target_rebalance()`, `ledgr_run()` | Risk and Cost; Metrics |
| `research-to-production.qmd` | reader evaluating the longer architecture | core ledgr concepts | separate the shipped research layer from planned paper/live operations | ledger as bridge, durable evidence, operational boundary | `ledgr_experiment()`, `ledgr_cost_zero()` | Research Workflow; Reproducibility |
| `articles/why-r.qmd` | R or Python researcher evaluating the design culture | basic portfolio-research vocabulary | understand why ordinary R objects surround ledgr's causal and accounting boundaries | readable research code, ecosystem composition, portability | `ledgr_history_matrix()`, `ledgr_align_weights()`, `ledgr_target_rebalance()` | Quickstart |

## Six reader journeys

| Journey | Entry | Progression | Completion signal |
| --- | --- | --- | --- |
| First contact | README | Who ledgr is for -> Quickstart | one run, sweep and promoted candidate; limits understood |
| Strategy and indicator authoring | Strategy Basics | Indicators -> Strategy Authoring Tools -> custom/TTR depth as needed | a causal function returns explicit intent from declared features |
| Point-in-time evidence | Data Input | Point-In-Time Inputs -> Missing Data -> Corporate Actions -> Survivorship Bias | a sealed snapshot distinguishes source evidence, policy and recorded outcome |
| Research validation | Research Workflow | Sweeps -> Selection Integrity -> Walk-Forward | exploration is separated from explicit selection and held-out evaluation |
| Portfolio construction and scheduling | Causal History | Minimum Variance | a causal matrix feeds an ordinary R estimator, identified weights and targets on declared dates |
| Persistence and reproducibility | Experiment Store | Reproducibility -> Research Workflow | a run can be reopened and interpreted from stored identity and ledger-derived results |

## Corrections and claim boundaries

| Surface | Classification | Correction or disposition | Pin treatment |
| --- | --- | --- | --- |
| `README.md` | stale discovery wording | add the browser-free installed-documentation path | existing README example and documentation contracts retained |
| `README.md`, `sweeps.qmd` | omitted accepted limitation | disclose worker memory scaling and the retained one-/two-worker observations without generalizing them | no timing threshold or benchmark oracle changed |
| `survivorship-bias.qmd` | stale API example | move the two-date guard out of the callback into `ledgr_schedule_dates()` and `ledgr_strategy_schedule()`; use that same scheduled strategy in the terminal examples | rendered output changes only in the strategy definition and experiment wiring; the economic outputs remain unchanged |
| scheduler valuation evidence | product defect, routed blocker | LDG-3119 / Workstream 68 preserves held stale and frozen mark evidence on skipped pulses for run and sweep readers | LCL-0503/LTB-0512; independently reviewed after correction |
| `strategy-authoring-tools.qmd`, `articles/who-ledgr-is-for.qmd` | scope wording | state the one-pulse-per-session scheduler boundary and avoid claiming shipped intraday execution | scheduler help and contract remain unchanged |
| `sweeps.md` | stale rendered output | refresh the sweep ID, run IDs, timestamp and schema-6 output produced by unchanged executable chunks | the earlier freshness gate should have caught this pre-range drift; no source API or teaching claim changed beyond the worker-memory paragraph |
| `walk-forward.md` | stale rendered output | refresh the execution seed produced by the unchanged source example after the candidate-key change in `032e4c14` | the earlier freshness gate should have caught this pre-range drift; no source, API, identity rule or teaching claim changed |
| `ttr-indicators.qmd` versus Documentation Contract TR-1 | routed contradiction | retain the shipped page for v0.2.2; the accepted next-release documentation-roles work owns page roles, pin types and retirement | no pin or page-role reset in this cut |

The release claim boundary remains unchanged and visible in both required
articles:

> Halts and untraded sessions that a data source encodes as zero-volume bars
> carrying the previous close, as the reference Sharadar data does, are still
> read as observed prices: they can fill and they bypass valuation ageing and
> freezing.

Terminal settlement evidence, modelled terminal dispositions, stale marks,
frozen marks, refusal and the frozen-worthless bound remain distinct. The
minimum-variance example remains deliberately long-only. Scheduler teaching
states the one-pulse-per-session limit. Parallel-memory numbers are presented
only as retained workload-specific observations.

## Verification record

Verification on Windows 11 with R 4.6.1:

- `tools/render-vignettes-gfm.R --check --all` executed all 28 article
  sources and verified every tracked Markdown render in 201.9 seconds;
- `test-documentation-contracts.R` passed 1,102 expectations, and
  `tools/check-readme-example.R` installed the package and passed in 19
  seconds;
- `dev/build-site.R` completed with pkgdown 2.2.1 in 395.9 seconds, built 30
  articles and the complete reference index, and reported no DuckDB notice;
  local CI mode deliberately skipped the third-party favicon service while
  public frontend assets were downloaded from their declared CDN;
- `R CMD build` completed in 277.3 seconds after using the repository's
  documented Quarto and Pandoc paths; and
- `R CMD check --no-manual --no-build-vignettes` completed in 293.0 seconds
  with all tests, examples and 26 installed vignettes passing. Its status was
  the established single NOTE for unqualified `head`; the sandboxed check
  also reported unavailable CRAN and Bioconductor indexes, not package
  diagnostics.

The only changed registered pin is LCL-0116/LTB-0116. Its old assertion
required the manual two-date guard that this ticket removes. The replacement
requires both exact declared dates, `ledgr_schedule_dates()` and
`ledgr_strategy_schedule()`, and rejects `ctx$ts_utc` from the strategy chunk,
so removing either date or restoring a callback calendar branch fails. No
claim-boundary pin was removed or weakened.

Intentional tracked changes are confined to README; the four corrected QMD
sources and their Markdown renders; the walk-forward Markdown render whose
stable execution seed had become stale; LCL-0116/LTB-0116; this closeout; and
the Workstream 65/68 packet records. Generated cpp11 and pkgdown metadata were
restored after verification.

The independent close review returned `PASS_AFTER_PATCHES`. Correction
`efb29b78` applied its six bounded documentation and record fixes and replaced
the invalid whole-CPU timing characterization with the registered P-core
comparison. A fresh Claude Opus confirmation mutation-checked LTB-0116,
reran the documentation-contract suite and both fast-profile gates, recomputed
the timing record, and returned finding-free `PASS`.

The two other strategy callbacks with civil-date checks are bounded scenario
injections, not periodic rebalance calendars: `trim_twice` requests trades on
three named dates to put one fill into a missing-bar interval, and the
missing-data article makes one named request inside its constructed hole.
