# RFC Seed: Walk-Forward Evaluation For ledgr

**Status:** Draft RFC seed for maintainer review.
**Scope:** Walk-forward evaluation as a planned v0.1.9.x feature, between the v0.1.9 target-risk chain and the v0.2.x OMS data model.
**Non-scope:** Selection-integrity diagnostic implementation (PBO, CPCV, DSR), survivorship-aware universe construction, online/streaming walk-forward, state-based/regime-aware folds, automatic candidate ranking, multiplicity-correction inside the engine, paper/live walk-forward, cross-snapshot walk-forward, and per-fold OMS event-stream design.
**Working title:** `rfc_walk_forward_evaluation_v0_1_9_x_seed.md`
**Research input:** `inst/design/research/Walk-Forward.md` (deep-research artifact; non-binding, citation-opaque, used as design-space input).

---

## 0. Executive Summary

Walk-forward evaluation is a discipline for producing chronology-preserving out-of-sample evidence over multiple non-overlapping test periods, with parameter selection happening on training data that precedes each test period. ledgr's v0.1.8 sweep + promote workflow produces *exploratory* evidence with an audit trail; walk-forward extends that workflow into *selection-aware* evidence by making the per-fold train → select → test ordering explicit and non-negotiable.

This RFC proposes that walk-forward in ledgr be:

```text
a configuration-bound batch of runs
  over one deterministic fold core
  with first-class durable fold-definition artifacts
  emitting per-fold per-candidate evidence
  for both operational realism and later selection-integrity diagnostics
```

The strategy contract does not change. Strategies remain `function(ctx, params) -> named numeric target vector`. The fold core does not split into two engines. Walk-forward is a wrapper over the existing `ledgr_sweep` and `ledgr_run` execution path, not a parallel implementation.

The first walk-forward release is deliberately small: rolling and anchored windowing over a single sealed snapshot, calendar-time fold boundaries, per-fold sweep + immediate next-period test ordering, deterministic fold identity, and a per-fold-per-candidate score matrix preserved as durable evidence. Purged/embargoed folds, combinatorial purged CV, and selection-integrity diagnostics are explicitly future work; the v1 data model preserves enough information to make them implementable later without redesign.

This seed binds a few decisions now and routes the rest to spec-cut:

**Bind now:**

- Walk-forward is a wrapper over the existing fold core, not a second engine.
- Fold definitions are first-class durable artifacts with deterministic identity hashes.
- Honest OOS evidence is *procedural*: per-fold sweep on the train period followed by immediate test on the next period. Sweep-then-walk-forward-the-winner is the principal anti-pattern and must not be teachable in default workflows.
- The single-snapshot model is the v1 default: one sealed snapshot windowed by date, fold boundaries are config.
- Walk-forward sessions emit a per-fold per-candidate score matrix as a durable artifact; the matrix is sufficient input for downstream PBO/DSR/CPCV computation in a later RFC.
- Calendar-time fold boundaries are the v1 default.

**Defer now:**

- Selection-integrity diagnostic implementation (PBO/CSCV/CPCV/DSR/Holm-BH) → separate v0.1.9.x RFC.
- Purged/embargoed fold definitions → separate RFC; v1 data model reserves space.
- Trading-time and state-based fold boundaries → future RFC.
- Cross-snapshot walk-forward (one fold per snapshot) → future RFC.
- Per-fold OMS event-stream artifacts → covered by OMS RFC future obligation.
- Promotion semantics for "the walk-forward winner" → spec-cut decision; this seed records the three options without binding.
- Survivorship-aware universe construction → separate concern; not gated by this RFC.

---

## 1. Prior Art And Fit Assessment

This section is load-bearing rather than encyclopedic. It identifies the vocabulary and invariants ledgr should borrow, and the patterns it should reject.

### 1.1 Walk-forward as a family within time-series cross-validation

The cleanest framing across the literature is that walk-forward is *not a different idea from time-series cross-validation*; it is a particular family of chronology-preserving fold definitions. The split-object pattern in scikit-learn's `TimeSeriesSplit` and tidymodels' `rsample::rolling_origin()` / `sliding_*()` family formalizes this for general data; what finance adds is stricter handling of overlapping information sets, selection over many backtests, and strategy-search multiplicity.

For ledgr design, this matters because it means the fold-definition concept ports cleanly from existing R idioms (`rsample`-style split objects) without needing finance-specific vocabulary. The finance-specific layer sits *above* the fold definition, in the procedural ordering of sweep and selection.

### 1.2 The taxonomy that constrains the v1 design

The relevant scheme taxonomy is well-mapped in Tashman (2000, *International Journal of Forecasting*, "Out-of-sample tests of forecasting accuracy"), with finance-specific extensions in López de Prado's *Advances in Financial Machine Learning* (2018):

| Scheme | What defines a fold | Defensibility | v1 ledgr scope |
|---|---|---|---|
| Rolling / sliding | Fixed-width train + forward test | Deployment also retrains on a finite lookback | ✅ v1 default |
| Anchored / expanding | Fixed-origin train + rolling test | Older data still relevant; cumulative learning | ✅ v1 default |
| Gap / embargo | Buffer between train end and test start | Short-horizon label dependence | ⚠️ v1 data model reserves; binding deferred |
| Purged CV | Remove train observations whose info sets overlap test labels | Labels span forward intervals | ❌ Deferred |
| CPCV / CSCV | Combinatorial chronology-respecting partitions with purging | Selection-integrity diagnostics | ❌ Deferred |
| hv-block | Blocks removed around held-out observations | Local-dependence model selection | ❌ Deferred |
| Block bootstrap | Resampled blocks rather than deterministic folds | Sampling-distribution inference under dependence | ❌ Deferred |

The rolling/anchored pair is the minimum useful surface. Gap/embargo is the natural next extension because it requires only a fold-definition field, not a different execution model. Purged CV, CPCV, and block bootstrap require richer machinery and are best handled in follow-up RFCs after operational experience.

### 1.3 The narrow positive result for ordinary CV in time series

Bergmeir, Hyndman, and Koo (2018, *Computational Statistics and Data Analysis*) showed that ordinary k-fold cross-validation is valid for purely autoregressive settings with uncorrelated errors. This result does *not* generalize to arbitrary financial feature sets or overlapping labels. The design implication for ledgr is that chronology-preserving folds are the safe default; non-chronology-preserving folds require a justified case-by-case argument that the user, not ledgr, owns. Walk-forward defaults to chronology preservation.

### 1.4 The multiplicity literature

Bailey, Borwein, López de Prado, and Zhu's PBO paper (2017, *Journal of Computational Finance*) establishes that, once many strategy variants are tried, selecting the best backtest is itself a biasing operation. The Bailey–López de Prado "Pseudo-Mathematics and Financial Charlatanism" critique (2014, *Notices of the AMS*) adds that backtests which fail to report the number of trials attempted are materially incomplete. Harvey, Liu, and Zhu (2016, *Review of Financial Studies*, "...and the Cross-Section of Expected Returns") extend this to factor research: conventional thresholds such as `t ≈ 2` are too low under multiple testing.

The design implication for ledgr is that walk-forward outputs must preserve enough per-candidate per-fold evidence for downstream multiplicity diagnostics to be computable. A walk-forward session that emits only a single stitched OOS equity curve and aggregate statistics is insufficient evidence. The v1 data model preserves the full per-candidate per-fold score matrix.

### 1.5 Reference implementations: three architectural forms

Across the ecosystem, walk-forward appears in three distinct architectural forms:

1. **Strategy backtester wrapper.** `quantstrat::walk.forward()` is the clearest example. It computes endpoints, runs `apply.paramset()` on the training slice, picks one parameter combination from `tradeStats.list` via a user-specified `obj.func`, installs those parameters with `install.param.combo()`, and calls `applyStrategy()` on the next test slice. Single execution engine, repeated reuse, per-fold winner propagated to next test.

2. **ML/resampling toolkit splitter.** `rsample::rolling_origin()` and `sklearn.model_selection.TimeSeriesSplit` are exemplars. They emit train/test indices over time-ordered data and leave execution to the caller. PortfolioAnalytics' `optimize.portfolio.rebalancing()` is a hybrid: rolling rebalance dates inside one engine, but the user does not see the fold object explicitly.

3. **Optimization platform scheduler.** QuantConnect LEAN exposes walk-forward via `train()` with `DateRules` and `TimeRules`, scheduling parameter refresh inside an otherwise ordinary algorithm run. Bulk parameter optimization is a separate workflow that emits result surfaces for user review.

ledgr's "no second execution engine" invariant strongly favors form 1 (wrapper). Its "fold definitions as first-class durable artifacts" requirement borrows from form 2 (explicit split objects). Its sweep + promote workflow is already config-driven, which makes the config-object discipline of NautilusTrader's `BacktestRunConfig` + `BacktestNode` the closest spiritual analog. The v1 ledgr design is **a wrapper over the existing fold core, with explicit fold-definition objects as durable config artifacts.**

### 1.6 NautilusTrader as architectural analog

NautilusTrader does not ship a first-class walk-forward feature, but its architecture is the closest public match to ledgr's invariants: deterministic execution in timestamp order, configuration-bound runs (`BacktestRunConfig`, `BacktestNode`), explicit catalog/run separation, and structured post-run reporting (`ReportProvider`).

What to study from NautilusTrader:

- `BacktestRunConfig` and `BacktestNode` as the pattern for making a run spec a durable, hashable object that can be batched without inventing a second engine.
- `BacktestDataConfig` plus catalog slicing as the pattern for making fold boundaries live in config while data remains physically cataloged and reusable.
- The `ReportProvider` layer as the pattern for structured per-run artifacts (orders, fills, positions, account states) that ledgr can mirror per fold.

What *not* to copy:

- NautilusTrader's catalog is not a sealed immutable hashed snapshot in the ledgr sense. Its docs warn that careless writes can overwrite files. ledgr is stricter on snapshot identity; this difference is by design and should not be diluted.

### 1.7 Rejections

The reference-implementation review surfaces several patterns ledgr should reject:

- **Mutable optimization state with implicit fold boundaries** (quantstrat audit files have this character). ledgr's append-only event-log invariant means fold boundaries must be explicit config, not implicit run state.
- **Notebook-orchestrated honesty** (vectorbt's typical pattern). The "honest OOS evidence is procedural" rule cannot be enforced if the framework only provides splits and leaves selection ordering to user notebooks. ledgr must surface the procedural rule in the public API, not rely on user discipline.
- **Single-best-cell reporting from a parameter sweep heatmap** (the common backtrader/zipline pattern). Walk-forward reporting must default to per-fold-per-candidate evidence, with single-winner views as one of several reports, not the only one.
- **Selection by stitched OOS equity curve only** (recurring across frameworks). Stitched OOS is one useful artifact; it is not by itself sufficient evidence under the multiplicity literature.

### 1.8 The mlfinlab purge-logic warning

Public mlfinlab issue history shows that purge logic for overlapping labels is subtle enough to get wrong in practice. For ledgr's v1 (which does not implement purging), this is a future-obligation note: when purging lands in a follow-up RFC, the implementation must include explicit test fixtures for label-interval overlap cases that the mlfinlab issue trackers identified.

---

## 2. ledgr Constraints The Design Must Preserve

### 2.1 Strategy contract

```text
strategy: function(ctx, params) -> full named numeric target vector
```

Strategies do not see fold boundaries, do not retrain themselves, and do not know which fold they are running in. Per-fold parameter selection is engine work, not strategy work. The strategy contract is invariant across single runs, sweeps, and walk-forward sessions.

### 2.2 Single fold core

`ledgr_run()` and `ledgr_sweep()` share the existing fold core (see [R/fold-core.R](R/fold-core.R)). Walk-forward is an additional wrapper that composes sweep and run calls over fold-defined date windows. There is no second execution engine, no parallel pulse loop, no separate fill/cost/ledger semantics. Walk-forward identity becomes a wrapping config over existing run/sweep identity.

### 2.3 Sealed snapshots

A sealed snapshot is immutable, hashed input evidence. Walk-forward folds are date windows *into* one sealed snapshot, not multiple sealed fold-specific snapshots. The snapshot identity remains the upstream data-evidence anchor; fold identity is a layer above it.

### 2.4 Append-only event log

`ledger_events` continues to be accounting truth per run. A walk-forward session produces multiple runs (one per fold's test period at minimum) and therefore multiple `ledger_events` slices. Walk-forward must not invent new event types in the accounting ledger; per-fold artifacts live in their own table.

### 2.5 Deterministic replay

Walk-forward identity hashes must be reproducible. Per-fold seeds, fold-boundary timestamps, candidate-grid identity, objective/selection-rule identity, and execution version all participate in walk-forward identity. The hash story carries forward from sweep promotion (see `rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`).

### 2.6 Pre-CRAN policy

Proposed schemas in this RFC are pre-CRAN design sketches. They may change or break before public implementation. No compatibility promise is made until a v0.1.9.x spec packet binds the implementation contract.

---

## 3. Problem Statement

Current ledgr backtests can answer:

```text
Given a sealed snapshot, a strategy, a parameter set, and a seed,
what fills, equity, and metrics did this backtest produce?
```

Current ledgr sweeps can answer:

```text
Given a sealed snapshot, a strategy, a parameter grid, and a seed,
what is the exploratory evidence per candidate across the full data range?
```

Neither can answer:

```text
- If I selected parameters using data through year T, what would my out-of-sample
  evidence have looked like in year T+1?
- How does that selection-then-test pattern perform when rolled forward repeatedly?
- Per fold and per candidate, what was the train-vs-test gap, the OOS Sharpe,
  the OOS drawdown?
- Did the selection rule produce a stable parameter path across folds, or did
  the "winner" change identity every period?
- Is there enough per-fold per-candidate evidence to compute PBO, DSR, or
  CPCV diagnostics later without rerunning the whole study?
```

Sweep + promote alone cannot answer these because the candidate-selection step in promote happens *after* the candidate has seen all the data. Walk-forward closes that gap by binding the per-fold sweep → select → test order procedurally rather than by user discipline.

This gap is acceptable for exploratory research. It is not acceptable for the workflow that v0.1.8.5 documentation positions as "the foundation, not the complete research-method story." Walk-forward is the next conceptual layer that turns the workflow into selection-aware evidence.

---

## 4. Thesis

Walk-forward should be added as a procedural wrapper over the existing sweep and run path, with first-class durable fold-definition artifacts and per-fold per-candidate evidence preservation. The wrapper enforces the honest sweep ordering: per-fold train, per-fold select, immediate next-period test, then advance.

The strategy contract does not change. The fold core does not split. The sweep and promote machinery is reused. The new surface is:

- A fold-definition object that names the windowing scheme, boundaries, and optional gap.
- A walk-forward session that composes folds + experiment + sweep grid + selection rule into a batch of runs.
- A per-fold-per-candidate score matrix as the durable evidence artifact.
- A small set of inspection helpers for per-fold and aggregate views.

The first release is rolling + anchored windowing only, calendar-time boundaries only, single-snapshot only, no purging, no CPCV, no diagnostic computation. Each of those is reserved for a later RFC; the v1 data model leaves room for them.

---

## 5. Explicit Non-Goals

This seed does not define:

- **Selection-integrity diagnostic implementation.** PBO, CSCV, CPCV scoring, DSR, Holm/BH correction, Minimum Track Record Length computation, and Harvey-Liu-Zhu multiplicity thresholds are deferred to a separate v0.1.9.x RFC after walk-forward synthesis lands. The v1 walk-forward data model preserves enough information to make these computable later.
- **Purged or embargoed fold definitions.** v1 supports rolling and anchored only. The data model reserves space for a `gap` field but does not bind purging semantics.
- **Combinatorial purged cross-validation (CPCV).** Deferred. Requires purging + combinatorial path generation + per-path scoring; out of v1 scope.
- **Block bootstrap, hv-block, or other resampling-based schemes.** Deferred. Walk-forward in v1 is deterministic fold definitions only.
- **Trading-time fold boundaries.** v1 is calendar-time only. Trading-day-count, market-state, or regime-aware boundaries are future RFCs.
- **State-based or regime-aware folds.** Explicitly deferred. The regime-classifier-as-hidden-look-ahead hazard is real; v1 sidesteps it by not supporting state-based boundaries at all.
- **Online or streaming walk-forward.** v1 is batch fold execution. Incremental model-update patterns (common in production ML) are deferred indefinitely.
- **Cross-snapshot walk-forward.** v1 is one sealed snapshot windowed by date. Cross-snapshot folds (one fold = one snapshot) are deferred to a future RFC that interacts with snapshot lineage.
- **Survivorship-aware universe construction.** Adjacent hazard, not gated by this RFC. A future point-in-time data RFC will address universe definition at fold-window boundaries.
- **Per-fold OMS event-stream artifacts.** Covered by OMS RFC future obligation. The OMS synthesis already records walk-forward interaction as a future concern.
- **Paper or live walk-forward.** v0.3.0+ scope. v1 is research-only.
- **Automatic candidate ranking or `ledgr_tune()`.** ledgr does not pick winners automatically. The user supplies a selection rule per fold; the engine applies it deterministically.
- **Multiplicity correction inside the engine.** Multiplicity is a downstream analysis concern. The engine emits the per-candidate per-fold matrix; correction lives in user code or a downstream diagnostic RFC.

---

## 6. Core Vocabulary

### 6.1 Fold definition

A fold definition is an immutable description of the train and test windows for a single fold. It carries:

- a `fold_id` deterministic from its content;
- a windowing scheme (`rolling` or `anchored` for v1);
- the train window start and end timestamps;
- the test window start and end timestamps;
- an optional gap (reserved field, not bound for v1);
- a fold sequence number within its parent walk-forward session.

A fold definition is a value object. It does not own data, execution state, or results. It is independently hashable.

### 6.2 Walk-forward session

A walk-forward session is the engine-owned batch of runs that produces walk-forward evidence. It is parameterized by:

- a sealed snapshot;
- an experiment (strategy + features + universe + opening + execution options);
- a parameter grid (the candidates evaluated at each fold);
- a list of fold definitions;
- a selection rule (e.g., "argmax on train OOS Sharpe");
- a seed.

A session has a `session_id` deterministic from its content. The session is the artifact unit that promotion can refer to.

### 6.3 Fold run

A fold run is one execution of the existing fold core over one fold's train + test window pair. For v1 with a parameter grid, this expands to:

- a per-candidate train sweep over the train window,
- selection of one candidate via the selection rule,
- a single-candidate test run over the test window,
- emission of per-candidate train scores and the single test-run result.

The fold run is the execution unit. Multiple fold runs make a walk-forward session.

### 6.4 Selection rule

A selection rule is a deterministic function that, given the per-candidate train-window scores for one fold, returns the candidate identifier to test. For v1, ledgr ships at minimum:

- `ledgr_select_argmax(metric)` — pick the candidate with the highest value of the named metric;
- `ledgr_select_argmin(metric)` — pick the candidate with the lowest value (e.g., for drawdown).

The selection rule is part of walk-forward identity. Changing the rule changes the session hash.

### 6.5 Fold artifact

A fold artifact is the durable evidence record for one fold. It contains:

- the fold definition (including hashes);
- per-candidate train-window scores (the full matrix, not just the winner);
- the selected candidate identifier;
- the test-run result (metrics, fills, equity for the selected candidate over the test window).

A walk-forward session emits one fold artifact per fold.

### 6.6 Score matrix

The score matrix is the union of per-candidate train-window scores across all folds in a session. Its shape is `[n_folds × n_candidates × n_metrics]`. It is the load-bearing artifact for downstream selection-integrity diagnostics (PBO, DSR, CPCV). The v1 data model emits it as queryable rows; later diagnostic RFCs consume it without re-execution.

---

## 7. Bound Design Decisions

### 7.1 Walk-forward is a wrapper, not a second engine

```text
ledgr_walk_forward()
  -> for each fold:
       -> ledgr_sweep() on the train window
       -> selection_rule applied to sweep results
       -> ledgr_run() on the test window with the selected candidate
  -> aggregate fold artifacts into a session result
```

The fold core sees no walk-forward concept. Pulse causality, fill timing, cost resolution, and ledger writing are unchanged. Walk-forward identity composes over existing run and sweep identity.

**Rationale:** This is the strongest cross-framework pattern (quantstrat, PortfolioAnalytics, LEAN's `train()` scheduler) and the closest match to ledgr's "no second execution engine" invariant. The alternative — a separate walk-forward execution path — would duplicate fold-core semantics and break determinism guarantees.

### 7.2 Fold definitions are first-class durable artifacts

A fold definition has its own constructor (`ledgr_fold(...)`) and identity hash. It can be serialized, persisted, replayed, and inspected independently of any walk-forward session. Sessions reference folds by identity, not by inline boundary timestamps.

**Rationale:** The rsample/sklearn pattern of explicit split objects is the cleanest precedent for reproducibility. Inline boundaries inside a session config make it harder to reuse fold definitions across studies and harder to debug fold-boundary issues.

### 7.3 Honest OOS evidence is procedural

The engine enforces this ordering per fold:

```text
1. Sweep all candidates on the train window only.
2. Apply the selection rule to the train-window scores.
3. Run the single selected candidate on the test window.
4. The test-window result is the OOS evidence for this fold.
```

The engine does *not* expose a path that runs all candidates on the full snapshot and selects retrospectively. This is the principal anti-pattern in the literature (sweep-then-walk-forward-the-winner); it is rejected at the API level rather than via documentation warnings.

**Rationale:** The PBO and "Pseudo-Mathematics" literature show that the honesty of walk-forward depends on the procedural ordering, not just on calendar-time fold boundaries. ledgr's API must prevent the anti-pattern by construction, not by user discipline.

### 7.4 Single-snapshot model for v1

A walk-forward session is bound to one sealed snapshot. Fold boundaries are date windows into that snapshot. Cross-snapshot walk-forward (one fold = one snapshot) is deferred.

**Rationale:** This matches the cross-framework default (quantstrat, vectorbt, zipline, LEAN). The cross-snapshot model interacts with snapshot lineage (future RFC) and is non-essential for v1. Sealing each test fold separately would force fold construction into the data-artifact layer and complicate promotion.

### 7.5 Per-fold per-candidate score matrix is the durable evidence

The session-level artifact is the full `[n_folds × n_candidates × n_metrics]` matrix, not a stitched OOS equity curve. Stitched views are derived from the matrix; the matrix is the truth.

**Rationale:** PBO requires the full performance matrix. DSR requires per-candidate return series and search metadata. Holm/BH requires the family of p-values across candidates. A walk-forward release that emits only stitched OOS evidence is insufficient input for the strongest selection-integrity diagnostics. Reserving the matrix from v1 prevents a forced re-execution when diagnostics land.

### 7.6 Calendar-time fold boundaries for v1

Fold boundaries are timestamps in calendar time. Trading-day-count, market-state, and regime-aware boundaries are deferred to future RFCs.

**Rationale:** Calendar time is the universal default across all reviewed implementations. Trading-time requires a market-calendar abstraction that ledgr does not currently have; state-based requires a regime classifier that introduces its own look-ahead hazards. Both are valid future extensions; neither is essential for v1.

### 7.7 Strategy contract is invariant

Walk-forward does not extend `function(ctx, params)`. Strategies do not see fold boundaries, do not retrain, and do not know which fold they are running in. Selection is engine work.

**Rationale:** Strategy-contract preservation is a hard ledgr invariant (see OMS synthesis, target-risk synthesis). Walk-forward must not be the exception that creates the precedent for strategy-side state.

---

## 8. Proposed Data Model

### 8.1 `ledgr_fold` constructor

The v1 fold-definition constructor:

```r
ledgr_fold(
  scheme = c("rolling", "anchored"),
  train_start = NULL,    # NULL for anchored: bound to snapshot start
  train_end,
  test_start,
  test_end,
  gap = NULL,            # reserved; v1 must be NULL or 0
  fold_seq = NA_integer_
)
```

Returns a `ledgr_fold` object with deterministic `fold_id` derived from canonical JSON of its contents.

A helper constructor produces a list of folds from a windowing specification:

```r
ledgr_folds_rolling(
  snapshot,
  train_window = "1 year",   # or integer N bars
  test_window = "3 months",  # or integer N bars
  step = "3 months",         # how far to advance per fold
  start = NULL,              # default: snapshot start
  end = NULL                 # default: snapshot end
)

ledgr_folds_anchored(
  snapshot,
  origin_end = NULL,         # default: 1 year from snapshot start
  test_window = "3 months",
  step = "3 months",
  end = NULL
)
```

Both return a `ledgr_fold_list` carrying the individual fold objects plus a session-level identity hash over the full list.

### 8.2 `walk_forward_sessions` table

Proposed schema (semantic shape; SQL may evolve):

```text
session_id              TEXT  PRIMARY KEY, deterministic from session config
snapshot_id             TEXT  NOT NULL
experiment_hash         TEXT  NOT NULL
param_grid_hash         TEXT  NOT NULL
fold_list_hash          TEXT  NOT NULL
selection_rule_hash     TEXT  NOT NULL
master_seed             INTEGER
created_at_utc          TIMESTAMP NOT NULL
ledgr_version           TEXT  NOT NULL
meta_json               TEXT

UNIQUE(session_id)
```

### 8.3 `walk_forward_folds` table

```text
session_id              TEXT  NOT NULL, FK to walk_forward_sessions
fold_id                 TEXT  NOT NULL
fold_seq                INTEGER NOT NULL
scheme                  TEXT  NOT NULL
train_start_utc         TIMESTAMP NOT NULL
train_end_utc           TIMESTAMP NOT NULL
test_start_utc          TIMESTAMP NOT NULL
test_end_utc            TIMESTAMP NOT NULL
gap_value               TEXT  nullable
gap_unit                TEXT  nullable
selected_candidate_id   TEXT  nullable until test executes
selected_at_utc         TIMESTAMP nullable
test_run_id             TEXT  nullable; FK to runs

UNIQUE(session_id, fold_seq)
```

### 8.4 `walk_forward_scores` table (the score matrix)

```text
session_id              TEXT  NOT NULL
fold_id                 TEXT  NOT NULL
fold_seq                INTEGER NOT NULL
candidate_id            TEXT  NOT NULL
candidate_label         TEXT
params_hash             TEXT  NOT NULL
feature_set_hash        TEXT  NOT NULL
alias_map_hash          TEXT  nullable
window                  TEXT  NOT NULL CHECK (window IN ('train','test'))
metric_name             TEXT  NOT NULL
metric_value            DOUBLE
n_trades                INTEGER nullable
status                  TEXT  NOT NULL CHECK (status IN ('done','failed'))
error_class             TEXT  nullable
error_msg               TEXT  nullable
execution_seed          INTEGER

UNIQUE(session_id, fold_seq, candidate_id, window, metric_name)
```

This table is the load-bearing artifact for downstream selection-integrity diagnostics. Each row is one (fold, candidate, window, metric) triple. The shape supports PBO partitioning, DSR estimation, and Holm/BH correction without re-execution.

### 8.5 Test-window run artifacts

The test-window run for each fold is an ordinary ledgr run, written to `runs`, `ledger_events`, `equity_curve`, and `strategy_state` exactly as `ledgr_run()` would write them. The `walk_forward_folds.test_run_id` field links to the standard `runs.run_id`. Walk-forward does not invent new accounting artifacts; it reuses the existing schema.

This means existing inspection surfaces (`ledgr_results(bt, what = "equity")`, etc.) work on the test run for any given fold once that fold's `test_run_id` is resolved.

### 8.6 Promotion artifacts

Walk-forward promotion semantics are deferred to spec-cut (see Open Questions). The data model reserves a foreign-key relationship between promoted runs and walk-forward sessions but does not bind the promotion contract here.

---

## 9. Proposed Fold-Execution Semantics

### 9.1 Per-fold execution sequence

For each fold in a session, the engine executes:

```text
1. Resolve the fold's train window into snapshot bars.
2. Construct an ephemeral train-window experiment view (same snapshot,
   restricted scoring range).
3. Run ledgr_sweep over the parameter grid on the train view.
4. Write per-candidate train scores to walk_forward_scores.
5. Apply the selection rule to the train scores. The result is a
   candidate_id.
6. Resolve the fold's test window into snapshot bars.
7. Construct an ephemeral test-window experiment view.
8. Run ledgr_run on the test view with the selected candidate's
   feature_params and params.
9. Write the test run to runs and the standard accounting tables.
10. Write per-candidate test scores (one row for the selected candidate)
    to walk_forward_scores with window = 'test'.
11. Update walk_forward_folds with selected_candidate_id and test_run_id.
```

The train-window sweep is the same `ledgr_sweep` machinery that v0.1.8.4 ships. The selection rule is applied to the sweep results table. The test-window run is the same `ledgr_run` machinery. No new fold-core code is needed.

### 9.2 Failure handling

Per-candidate train failures are recorded in `walk_forward_scores` with `status = 'failed'`. The selection rule is applied to surviving candidates only. If no candidate survives, the fold itself is marked failed and the session continues unless `stop_on_fold_error = TRUE`.

A test-run failure marks the fold as failed but preserves the train-window scores. This mirrors `ledgr_sweep`'s `stop_on_error` semantics.

### 9.3 Determinism

Walk-forward determinism layers:

- **Session-level master seed** derives per-fold seeds via a deterministic function of (master_seed, fold_seq).
- **Per-fold seed** seeds both the train-window sweep and the test-window run.
- **Per-candidate seed within sweep** continues to use the existing sweep seeding contract.

Replay of a walk-forward session with identical session config produces identical per-fold IDs, identical score-matrix rows, and identical test-run artifacts.

### 9.4 Memory and persistence

The default walk-forward output handler writes:

- session metadata to `walk_forward_sessions`,
- fold metadata to `walk_forward_folds`,
- the score matrix to `walk_forward_scores`,
- test-window runs to the standard run tables.

Per-candidate train-window full equity curves and per-candidate fill records are *not* persisted by default. The score matrix is sufficient for selection-integrity diagnostics; full per-candidate per-fold equity would explode storage for any non-trivial grid × fold count.

A future diagnostic mode may opt into full per-candidate per-fold persistence; that is a retention-policy concern, not a data-model concern. The data model leaves room for opt-in expansion.

---

## 10. Fold-Core Integration

### 10.1 No fold-core changes for v1

The walk-forward feature does not modify [R/fold-core.R](R/fold-core.R). It composes the existing `ledgr_sweep()` and `ledgr_run()` entry points over fold-defined date windows.

### 10.2 Date-window experiment views

The train and test views are ephemeral experiment objects that share the underlying snapshot but restrict the scoring range. This requires a small helper:

```r
ledgr_experiment_window(exp, start_utc, end_utc) -> ledgr_experiment
```

The returned experiment carries the same snapshot, strategy, features, universe, opening, and execution options, but with the scoring range bound to the window. The snapshot identity does not change; the experiment-window identity is a derivative.

This helper is the only new fold-core-adjacent surface required for v1. It does not alter pulse causality, fill timing, or accounting.

### 10.3 Output-handler dispatch

The default `ledgr_run` and `ledgr_sweep` output handlers continue to write their respective artifacts. Walk-forward adds a session-level output handler that writes the session/fold/score-matrix tables. The session handler does not interfere with the run/sweep handlers; each handler owns its own tables.

---

## 11. Research, Sweep, And Future Paper/Live Mode Behavior

### 11.1 Research mode (v1 scope)

Walk-forward in research mode is the default v1 use case. Sealed snapshot, deterministic execution, reproducible from session identity, no broker interaction, no live data. The accepted OMS synthesis applies: research mode does not write `order_events` for walk-forward by default.

### 11.2 Sweep interaction

The walk-forward wrapper *uses* `ledgr_sweep` per fold. It does not replace it. Users who want exploratory sweep evidence over the full snapshot continue to call `ledgr_sweep()` directly. Walk-forward is the additional surface for selection-aware evidence.

A walk-forward session is not a sweep candidate. Sweeps and walk-forward sessions are sibling artifacts; promotion can come from either, with different evidentiary weight.

### 11.3 Promotion interaction (deferred)

The promotion semantics for walk-forward results are an open question (see §15). The data model reserves the foreign-key relationship; this seed does not bind the contract.

### 11.4 Paper/live mode (future)

Per the OMS synthesis, paper and live walk-forward are v0.3.0+ scope. The v1 walk-forward design must keep paper/live compatibility on record:

- Fold definitions translate naturally to "retraining schedule" in paper/live (LEAN's `train()` pattern).
- Per-fold per-candidate score artifacts translate to per-retraining-event audit records.
- The session-level identity translates to a deployment-policy identity.

No paper/live API is bound here. The note is on record so the v1 data model does not paint paper/live into a corner.

---

## 12. Selection-Integrity Machinery (Future)

### 12.1 The v1 walk-forward release does not compute diagnostics

PBO, CSCV, CPCV, DSR, Holm/BH correction, Harvey-Liu-Zhu thresholds, and Minimum Track Record Length are not computed by walk-forward in v1. They are downstream consumers of the score matrix.

### 12.2 The score matrix is sufficient input

The literature (Bailey/Borwein/Zhu, López de Prado, Harvey/Liu/Zhu) consistently requires a per-candidate per-fold or per-partition performance matrix to compute selection-integrity diagnostics. The v1 `walk_forward_scores` table is exactly that matrix. Future RFCs can implement diagnostics over it without re-execution.

### 12.3 The R ecosystem already has a PBO package

The CRAN `pbo` package implements PBO-style algorithms. Even if ledgr never ships PBO computation in core, emitting the score matrix in an R-tibble-friendly shape lets downstream `pbo::pbo()` or user code consume it directly. The v1 data model uses this as a constraint: the score matrix must be queryable as a long tibble.

### 12.4 Family definition

Per Harvey/Liu/Zhu, multiplicity correction requires defining the "family" of tested hypotheses. ledgr's session boundary is a natural candidate-family boundary: one session = one family. Cross-session correction is a user-judgment call. The data model records session identity per score row, so family boundaries are recoverable.

---

## 13. Public API Direction

### 13.1 v1 public surface (proposed)

```r
ledgr_fold(scheme, train_start, train_end, test_start, test_end, gap, fold_seq)
ledgr_folds_rolling(snapshot, train_window, test_window, step, start, end)
ledgr_folds_anchored(snapshot, origin_end, test_window, step, end)
ledgr_select_argmax(metric)
ledgr_select_argmin(metric)
ledgr_walk_forward(exp, grid, folds, selection_rule, seed, ...)
ledgr_walk_forward_results(session_id)
ledgr_walk_forward_scores(session_id)
ledgr_walk_forward_folds(session_id)
```

### 13.2 Constructor families

Fold constructors (`ledgr_fold`, `ledgr_folds_*`) parallel the v0.1.8.4 grid constructors (`ledgr_param_grid`, `ledgr_feature_grid`, `ledgr_strategy_grid`). Selection-rule constructors (`ledgr_select_*`) parallel the v0.1.9 risk-step constructors. This is a deliberate consistency choice.

### 13.3 Selection-rule extensibility

For v1, the selection-rule surface accepts only ledgr-classed objects. Arbitrary user-supplied selection functions are deferred until the function-fingerprinting story for risk and cost is settled (see chainable-risk synthesis). This matches the discipline applied to risk steps.

### 13.4 Inspection surfaces are read-only

`ledgr_walk_forward_results()`, `ledgr_walk_forward_scores()`, `ledgr_walk_forward_folds()` are read-only. They do not mutate session state, do not recompute, and do not re-execute folds. Re-execution requires constructing a new session.

---

## 14. Testing Implications

The v0.1.9.x implementation must include:

- **Determinism tests:** identical session configs produce identical session_id, fold_id, score-matrix row hashes, and test-run identities.
- **Honest-OOS tests:** verify that the engine does not expose a path that runs candidates on the full snapshot and selects retrospectively. Construct an attempt and verify it fails or that the resulting evidence is correctly marked.
- **Sweep parity tests:** verify that the per-fold train-window sweep produces the same results as a direct `ledgr_sweep()` call over the same window with the same grid and seed.
- **Run parity tests:** verify that the per-fold test-window run produces the same results as a direct `ledgr_run()` call over the same window with the same params and seed.
- **Score-matrix completeness tests:** verify that the matrix contains one row per (fold, candidate, window, metric) for every successful candidate.
- **Failure-row tests:** verify that train-window failures appear in the score matrix with `status = 'failed'` and do not prevent fold continuation.
- **Schema tests:** verify pre-CRAN schema versions; the score-matrix shape must remain queryable by canonical column names.
- **R-tibble compatibility:** verify that the score-matrix output is consumable by the CRAN `pbo` package's expected input shape.

---

## 15. Open Questions For Maintainer Review

Synthesis-stage decisions; not blockers for the seed:

1. **Public API shape.** Should `ledgr_walk_forward()` be the single entry point, or should walk-forward be expressed as a modifier passed into `ledgr_sweep()`/`ledgr_run()`? The wrapper approach is cleaner; the modifier approach is more compositional.
2. **Promotion semantics.** What does it mean to promote a walk-forward result? Three options: (a) promote one candidate that was selected for a single fold (the most recent? the most stable across folds?); (b) promote a parameter path (a schedule of "use these params in test period T"); (c) promote a selection rule that will choose future parameters when new data arrive. Existing frameworks mostly leave this ambiguous; ledgr must bind one or all three with explicit contracts.
3. **Calendar vs trading-time defaults.** Should v1 default to calendar time, trading-day count, or accept both with explicit choice required? Calendar is universal but doesn't match how strategies actually trade.
4. **Selection-rule contract for multi-metric selection.** Should `ledgr_select_argmax(metric)` accept only one metric, or composite selection (e.g., "argmax Sharpe subject to max_drawdown > -0.20")? Composite selection is the common case in practice but requires a small DSL.
5. **Top-N artifact retention.** Should the score matrix preserve only the selected candidate's test-window result, or the top-N candidates' test-window results for stability analysis? The literature supports top-N reporting (LEAN's parameter stability surfaces) but storage cost grows linearly in N × folds.
6. **Per-fold telemetry budget.** Walk-forward with a 50-candidate grid × 20 folds = 1000 train runs + 20 test runs. The telemetry pipeline must absorb this without per-pulse DB writes (per OMS synthesis). What's the bound?
7. **Score-matrix update on partial session failure.** If a session is interrupted partway, what's the recovery contract? Resume from last completed fold, or restart? The data model supports either; the contract is open.
8. **Failed-fold accounting.** If a fold's test run fails after the train sweep succeeds, what's the right artifact state? Score matrix has train rows, no test row, fold status is failed. Is the session itself "partial-success"?
9. **Gap field default.** Should the `gap` field on `ledgr_fold()` default to 0 (no gap) or NULL (gap unspecified)? Semantics differ; both have precedent.
10. **Fold-list identity vs fold identities.** Should `fold_list_hash` be derived from the ordered concatenation of `fold_id`s, or from canonical JSON of the construction call (`ledgr_folds_rolling(...)`)? The first is content-addressed; the second is call-addressed. PBO/CPCV correction will care about which.
11. **Reporting defaults.** The print method for a walk-forward result should show what? Per-fold equity strip, train-vs-test scatter, parameter path across folds, single-best-candidate equity? LEAN-style "show everything" risks visual noise; quantstrat-style "show winner" hides honesty signals.
12. **Cross-session comparison.** Two walk-forward sessions with different fold lists, same snapshot — comparable? The data model allows it; the user-facing semantics need to be bound.
13. **Walk-forward inside a sweep.** Could a user run `ledgr_sweep()` where each candidate is itself a walk-forward session over a different fold list? This is the inverse composition; the engine does not prevent it but the artifact growth is alarming. Should the API actively reject?
14. **Snapshot-window experiment helper as public or internal.** `ledgr_experiment_window()` is small and useful outside walk-forward (e.g., for ad-hoc backtests over a date range). Should it be public from v1, or internal until a separate need surfaces?

---

## 16. Future Obligations Recorded

For follow-up RFCs:

- **Selection-integrity diagnostics RFC** (v0.1.9.x or later) — implement PBO, CSCV, CPCV scoring, DSR, Holm/BH, MinTRL as consumers of the score matrix. Should not require walk-forward re-execution.
- **Purged and embargoed folds RFC** — extend `ledgr_fold()` with label-interval-aware purge logic. Reuse mlfinlab's identified failure modes as test fixtures.
- **Combinatorial purged CV RFC** — multi-path scoring as an alternative to single-path walk-forward; emits the same score-matrix shape with additional `path_id` columns.
- **Trading-time and state-based folds RFC** — extend fold-definition scheme vocabulary. State-based folds need explicit treatment of regime-classifier look-ahead hazards.
- **Cross-snapshot walk-forward RFC** — one fold per snapshot, coordinated with snapshot lineage RFC.
- **OMS interaction RFC** — per the OMS synthesis future-obligations list, walk-forward interaction with per-fold OMS event streams must be addressed before paper/live walk-forward.
- **Paper/live walk-forward RFC** — v0.3.0+ scope; uses the v1 data model as foundation.

---

## 17. Recommended First Ticket Packet

The exact LDG IDs should be assigned at v0.1.9.x ticket cut. Indicative packet:

1. Add `ledgr_fold()` constructor with rolling and anchored schemes; deterministic `fold_id`.
2. Add `ledgr_folds_rolling()` and `ledgr_folds_anchored()` list constructors with deterministic `fold_list_hash`.
3. Add `ledgr_experiment_window()` helper for ephemeral date-windowed experiments.
4. Add `ledgr_select_argmax()` and `ledgr_select_argmin()` selection-rule constructors.
5. Add `walk_forward_sessions`, `walk_forward_folds`, `walk_forward_scores` schema and schema-version handling.
6. Add `ledgr_walk_forward()` orchestrator composing per-fold sweep + selection + test run.
7. Add session-level output handler for walk-forward artifacts.
8. Add read-only inspection helpers: `ledgr_walk_forward_results()`, `ledgr_walk_forward_scores()`, `ledgr_walk_forward_folds()`.
9. Add determinism, parity, score-matrix completeness, and failure-row tests.
10. Add R-tibble compatibility tests against the CRAN `pbo` package input shape.
11. Add documentation: walk-forward vignette covering rolling and anchored windowing, the honest-OOS procedural rule, and the score matrix as evidence.
12. Forward-link from v0.1.8.5 workflow article to the new walk-forward vignette.
13. Update NEWS.md, design index, and roadmap with v0.1.9.x walk-forward status.

---

## 18. Final Recommendation

Add walk-forward as a procedural wrapper over the existing fold core. Keep the strategy contract unchanged. Make fold definitions and the score matrix first-class durable artifacts. Bind the honest sweep-select-test ordering in the API rather than in documentation. Defer selection-integrity diagnostics, purging, CPCV, and trading-time/state-based folds to follow-up RFCs.

The correct first walk-forward milestone is not a complete selection-integrity diagnostic suite. The correct first milestone is a deterministic rolling/anchored walk-forward over one sealed snapshot that produces a per-fold per-candidate score matrix rich enough to compute every downstream diagnostic the literature requires — without re-execution.

The architectural reference point is NautilusTrader's configuration-bound run-spec composition. The procedural reference point is quantstrat's per-fold train + select + immediate test pattern. The reporting reference point is LEAN's parameter-stability-aware surfaces. None of them ships exactly the right thing for ledgr; the v1 design borrows the right pieces from each.
