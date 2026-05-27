# RFC Seed v2: Walk-Forward Evaluation For ledgr

**Status:** Draft RFC seed (v2) for maintainer review.
**Scope:** Walk-forward evaluation as a planned v0.1.9.x feature, between the v0.1.9 target-risk chain and the v0.2.x OMS data model.
**Non-scope:** Selection-integrity diagnostic implementation (PBO, CPCV, DSR), survivorship-aware universe construction, online/streaming walk-forward, state-based/regime-aware folds, automatic candidate ranking, multiplicity-correction inside the engine, paper/live walk-forward, cross-snapshot walk-forward, per-fold OMS event-stream design, walk-forward-inside-sweep composition, and composite selection rules.
**Working title:** `rfc_walk_forward_evaluation_v0_1_9_x_seed_v2.md`
**Research input:** `inst/design/research/Walk-Forward.md` (deep-research artifact; non-binding, citation-opaque, used as design-space input).

**Revision note (v2):** This is a post-response revision of `rfc_walk_forward_evaluation_v0_1_9_x_seed.md` (v1). It incorporates findings from `rfc_walk_forward_evaluation_v0_1_9_x_response.md` (Codex, 6 blocking corrections + non-blocking findings) and the maintainer-side review of that response (4 additional findings + open-question dispositions). The v1 seed remains the historical artifact. Material changes from v1: §7.3 anti-pattern claim narrowed to walk-forward-API scope; §7.5 score-matrix overclaim narrowed across §12.2, §17, §18; new §7.8 binds warmup/hydration/scoring/opening-state dimensions; new §7.9 binds identity composition and risk-chain inclusion; §10.1-10.2 acknowledge experiment-window contract scope; §6.4 expanded with v1 selection-rule contract; `candidate_id` renamed to `candidate_key` (deterministic) plus separate `candidate_label`; open-question list bound/narrowed/extended per response-review dispositions.

---

## 0. Executive Summary

Walk-forward evaluation is a discipline for producing chronology-preserving out-of-sample evidence over multiple non-overlapping test periods, with parameter selection happening on training data that precedes each test period. ledgr's v0.1.8 sweep + promote workflow produces *exploratory* evidence with an audit trail; walk-forward extends that workflow into *selection-aware* evidence by making the per-fold train → select → test ordering explicit and non-negotiable.

This RFC proposes that walk-forward in ledgr be:

```text
a configuration-bound batch of runs
  over one deterministic fold core
  with first-class durable fold-definition artifacts
  emitting per-fold per-candidate scalar evidence sufficient for inspection
  and simple PBO-style diagnostics
  while reserving room for richer diagnostic retention without forcing
  destructive migration
```

The strategy contract does not change. Strategies remain `function(ctx, params) -> named numeric target vector`. The fold core does not split into two engines. Walk-forward is a wrapper over the existing `ledgr_sweep` and `ledgr_run` execution path, but enabling that wrapper requires a shared experiment-window contract spanning `ledgr_run`, `ledgr_sweep`, `ledgr_precompute_features`, and precomputed-feature validation — not just one helper.

The first walk-forward release is deliberately small: rolling and anchored windowing over a single sealed snapshot, calendar-time fold boundaries, per-fold sweep + immediate next-period test ordering, deterministic fold identity, and a per-fold-per-candidate scalar score matrix preserved as durable evidence. Purged/embargoed folds, combinatorial purged CV, selection-integrity diagnostics, and richer per-candidate retention are explicitly future work; the v1 data model preserves room for them without forcing destructive migration.

This seed binds a few decisions now and routes the rest to spec-cut.

**Bind now:**

- Walk-forward is a wrapper over the existing fold core, not a second engine.
- The wrapper requires a shared experiment-window contract across run / sweep / precompute surfaces.
- Fold definitions are first-class durable artifacts with deterministic identity hashes.
- Honest OOS evidence is *procedural at the walk-forward API*: per-fold sweep on the train period followed by immediate test on the next period. `ledgr_walk_forward()` does not accept precomputed full-snapshot sweep results as fold-local selection inputs.
- `ledgr_sweep()` remains an exploratory full-snapshot API; the procedural rule constrains walk-forward, not sweep.
- The single-snapshot model is the v1 default: one sealed snapshot windowed by date, fold boundaries are config.
- Walk-forward sessions emit a per-fold per-candidate scalar score matrix sufficient for inspection, ranking, selected-candidate OOS review, and scalar-metric PBO approximation. Richer diagnostic retention (return series, sufficient stats, path identity) is reserved without binding the schema.
- Calendar-time fold boundaries are the v1 default.
- Per-fold execution distinguishes hydration, scoring, execution, and opening-state dimensions explicitly.
- Walk-forward identity composes from content hashes (strategy, snapshot, features, alias map, params, feature_params, metric context, risk chain when present, execution seed) and excludes the current ephemeral `sweep_id`.
- Selection rules in v1 are ledgr-classed objects with a minimal deterministic contract (train-window-only inputs, named metric, NA/NaN/inf policy, tie-breaking, classed failure).
- `ledgr_walk_forward()` is the v1 public entry point.

**Defer now:**

- Selection-integrity diagnostic implementation (PBO/CSCV/CPCV/DSR/Holm-BH) → separate v0.1.9.x RFC.
- Purged/embargoed fold definitions → separate RFC; v1 data model reserves the `gap` field semantically but binds it as `NULL` for v1.
- Combinatorial purged cross-validation (CPCV) → separate RFC.
- Richer diagnostic retention tiers (per-candidate return series, equity payloads, sufficient stats, path identity) → future RFC; v1 reserves room.
- Trading-time and state-based fold boundaries → future RFC.
- Cross-snapshot walk-forward → future RFC.
- Per-fold OMS event-stream artifacts → covered by OMS RFC future obligation.
- Promotion semantics for "the walk-forward winner" beyond `ledgr_promote()` of an explicitly extracted candidate → spec-cut decision.
- Composite multi-metric selection rules → future selection-rule DSL.
- Walk-forward sessions as candidates inside `ledgr_sweep()` → future composition concern.
- Survivorship-aware universe construction → separate concern; not gated by this RFC.

---

## 1. Prior Art And Fit Assessment

This section is load-bearing rather than encyclopedic. It identifies the vocabulary and invariants ledgr should borrow, and the patterns it should reject.

### 1.1 Walk-forward as a family within time-series cross-validation

The cleanest framing across the literature is that walk-forward is *not a different idea from time-series cross-validation*; it is a particular family of chronology-preserving fold definitions. The split-object pattern in scikit-learn's `TimeSeriesSplit` and tidymodels' `rsample::rolling_origin()` / `sliding_*()` family formalizes this for general data; what finance adds is stricter handling of overlapping information sets, selection over many backtests, and strategy-search multiplicity.

For ledgr design, this means the fold-definition concept ports cleanly from existing R idioms (`rsample`-style split objects) without needing finance-specific vocabulary. The finance-specific layer sits *above* the fold definition, in the procedural ordering of sweep and selection.

### 1.2 The taxonomy that constrains the v1 design

Per Tashman (2000, *International Journal of Forecasting*, "Out-of-sample tests of forecasting accuracy") and López de Prado's *Advances in Financial Machine Learning* (2018):

| Scheme | What defines a fold | Defensibility | v1 ledgr scope |
|---|---|---|---|
| Rolling / sliding | Fixed-width train + forward test | Deployment also retrains on a finite lookback | ✅ v1 default |
| Anchored / expanding | Fixed-origin train + rolling test | Older data still relevant; cumulative learning | ✅ v1 default |
| Gap / embargo | Buffer between train end and test start | Short-horizon label dependence | ⚠️ schema reserves; v1 binds `gap = NULL` |
| Purged CV | Remove train observations whose info sets overlap test labels | Labels span forward intervals | ❌ Deferred |
| CPCV / CSCV | Combinatorial chronology-respecting partitions with purging | Selection-integrity diagnostics | ❌ Deferred |
| hv-block | Blocks removed around held-out observations | Local-dependence model selection | ❌ Deferred |
| Block bootstrap | Resampled blocks rather than deterministic folds | Sampling-distribution inference under dependence | ❌ Deferred |

Rolling + anchored is the minimum useful surface. Gap/embargo requires only a fold-definition field, not different execution mechanics, so it is the natural next extension. Purged CV, CPCV, and block bootstrap require richer machinery and belong to follow-up RFCs.

### 1.3 The narrow positive result for ordinary CV in time series

Bergmeir, Hyndman, and Koo (2018) showed that ordinary k-fold cross-validation is valid for purely autoregressive settings with uncorrelated errors. This does *not* generalize to arbitrary financial feature sets or overlapping labels. ledgr's design implication: chronology-preserving folds are the safe default; non-chronology-preserving folds require a case-by-case argument the user owns. Walk-forward defaults to chronology preservation.

### 1.4 The multiplicity literature

Bailey, Borwein, López de Prado, and Zhu's PBO paper (2017, *Journal of Computational Finance*) establishes that selecting the best backtest from many trials is itself a biasing operation. The Bailey–López de Prado "Pseudo-Mathematics and Financial Charlatanism" critique (2014) adds that backtests which fail to report the number of trials attempted are materially incomplete. Harvey, Liu, and Zhu (2016) extend this to factor research: conventional thresholds such as `t ≈ 2` are too low under multiple testing.

The design implication for ledgr is that walk-forward outputs must preserve enough per-candidate per-fold evidence for downstream multiplicity diagnostics to be computable. The v1 score matrix is *sufficient for scalar-metric PBO approximation* (Bailey/Borwein/Zhu's CSCV procedure operates on a candidate-by-partition score matrix). It is *not by itself sufficient* for DSR (which requires return moments, skewness, kurtosis, effective trial count) or CPCV (which requires path identity and pathwise return series). v1 reserves room for richer retention without binding the schema.

### 1.5 Reference implementations: three architectural forms

Across the ecosystem, walk-forward appears in three forms:

1. **Strategy backtester wrapper.** `quantstrat::walk.forward()` — wraps `apply.paramset()` and `applyStrategy()` over train/test slices, single engine, repeated reuse.
2. **ML/resampling toolkit splitter.** `rsample::rolling_origin()`, `sklearn TimeSeriesSplit` — emit train/test indices, leave execution to the caller.
3. **Optimization platform scheduler.** QuantConnect LEAN — schedules parameter refresh inside an algorithm via `train()` with `DateRules`/`TimeRules`.

ledgr's "no second execution engine" invariant favors form 1. Its "fold definitions as first-class durable artifacts" requirement borrows from form 2. Its sweep + promote workflow is already config-driven, which makes the config-object discipline of NautilusTrader's `BacktestRunConfig` + `BacktestNode` the closest spiritual analog. The v1 design is **a wrapper over the existing fold core, with explicit fold-definition objects as durable config artifacts and a shared experiment-window contract.**

### 1.6 NautilusTrader as architectural analog

NautilusTrader does not ship a first-class walk-forward feature, but its architecture is the closest public match to ledgr's invariants: deterministic execution in timestamp order, configuration-bound runs (`BacktestRunConfig`, `BacktestNode`), explicit catalog/run separation, and structured post-run reporting (`ReportProvider`).

What to study from NautilusTrader: `BacktestRunConfig` and `BacktestNode` as the pattern for hashable run-spec objects batched without a second engine; `BacktestDataConfig` plus catalog slicing as the pattern for fold boundaries in config; the `ReportProvider` layer for structured per-run artifacts.

What *not* to copy: NautilusTrader's catalog is not a sealed immutable hashed snapshot in the ledgr sense. ledgr is stricter on snapshot identity; this difference is by design.

### 1.7 Rejections

- **Mutable optimization state with implicit fold boundaries** (quantstrat audit-file character). ledgr's append-only event-log invariant means fold boundaries must be explicit config.
- **Notebook-orchestrated honesty** (vectorbt pattern). The procedural anti-pattern must be rejected by the walk-forward API surface itself, not relegated to user documentation.
- **Single-best-cell reporting** (common backtrader/zipline pattern). Per-fold per-candidate evidence must be the default, not a single-winner heatmap cell.
- **Stitched OOS equity as the only artifact**. The literature requires per-candidate per-fold matrices for multiplicity diagnostics; stitched curves are derivative views.

### 1.8 The mlfinlab purge-logic warning

Public mlfinlab issue history shows purge logic for overlapping labels is subtle enough to get wrong in practice. For ledgr v1 (no purging), this is a future-obligation note: when purging lands, the implementation must include explicit test fixtures for label-interval overlap cases.

---

## 2. ledgr Constraints The Design Must Preserve

### 2.1 Strategy contract

```text
strategy: function(ctx, params) -> full named numeric target vector
```

Strategies do not see fold boundaries, do not retrain themselves, and do not know which fold they are running in. Per-fold parameter selection is engine work, not strategy work.

### 2.2 Single fold core

`ledgr_run()` and `ledgr_sweep()` share the existing fold core (see [R/fold-core.R](R/fold-core.R)). Walk-forward composes sweep and run calls over fold-defined date windows. The fold core itself does not change; the public and internal *wrapper surface* does change to accept date windows.

### 2.3 Sealed snapshots

A sealed snapshot is immutable, hashed input evidence. Walk-forward folds are date windows *into* one sealed snapshot in v1. Snapshot identity remains the upstream data-evidence anchor.

### 2.4 Append-only event log

`ledger_events` continues to be accounting truth per run. Walk-forward sessions produce multiple runs and therefore multiple `ledger_events` slices. Walk-forward does not invent new event types in the accounting ledger.

### 2.5 Deterministic replay

Walk-forward identity hashes must be reproducible. Per-fold seeds, fold-boundary timestamps, candidate-grid identity, objective/selection-rule identity, execution version, and (after v0.1.9) risk-chain identity all participate.

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
- Is there enough per-fold per-candidate evidence to compute simple PBO-style
  diagnostics later without rerunning the whole study?
```

Sweep + promote alone cannot answer these because the candidate-selection step in promote happens *after* the candidate has seen all the data. Walk-forward closes that gap by binding the per-fold sweep → select → test order procedurally rather than by user discipline.

This gap is acceptable for exploratory research. It is not acceptable for the workflow that v0.1.8.5 documentation positions as "the foundation, not the complete research-method story." Walk-forward is the next conceptual layer that turns the workflow into selection-aware evidence.

---

## 4. Thesis

Walk-forward should be added as a procedural wrapper over the existing sweep and run path, with first-class durable fold-definition artifacts and per-fold per-candidate scalar evidence preservation. The wrapper enforces the honest sweep ordering at its own API surface: per-fold train, per-fold select, immediate next-period test, then advance.

The strategy contract does not change. The fold core does not split. The sweep and promote machinery is reused. Enabling the wrapper requires a shared experiment-window contract across `ledgr_run`, `ledgr_sweep`, `ledgr_precompute_features`, and precomputed-feature validation.

The new surface is:

- A fold-definition object that names the windowing scheme, boundaries, and (reserved) gap.
- A walk-forward session that composes folds + experiment + sweep grid + selection rule into a batch of runs.
- A per-fold-per-candidate scalar score matrix as the durable v1 evidence artifact, with explicit room reserved for richer retention tiers.
- A small set of read-only inspection helpers for per-fold and aggregate views.

The first release is rolling + anchored windowing only, calendar-time boundaries only, single-snapshot only, no purging, no CPCV, no diagnostic computation. Each is reserved for a later RFC; the v1 data model leaves room for them.

---

## 5. Explicit Non-Goals

This seed does not define:

- **Selection-integrity diagnostic implementation.** PBO, CSCV, CPCV scoring, DSR, Holm/BH correction, and MinTRL are deferred to a separate v0.1.9.x RFC.
- **Richer diagnostic retention tiers.** Per-candidate per-fold return series, equity curves, sufficient-statistics rows, path identity, and partition metadata are deferred. The v1 schema must not preclude them.
- **Purged or embargoed fold definitions.** v1 supports rolling and anchored only.
- **Combinatorial purged cross-validation (CPCV).**
- **Block bootstrap, hv-block, or other resampling schemes.**
- **Trading-time fold boundaries.** v1 is calendar-time only.
- **State-based or regime-aware folds.** The regime-classifier-as-hidden-look-ahead hazard is real; v1 sidesteps it.
- **Online or streaming walk-forward.** v1 is batch.
- **Cross-snapshot walk-forward.**
- **Survivorship-aware universe construction.** Adjacent hazard, not gated by this RFC. v1 uses the experiment's universe across all folds; the user owns universe correctness.
- **Per-fold OMS event-stream artifacts.** Covered by OMS RFC future obligation. v1 research walk-forward does not write `order_events` or `target_decisions`.
- **Paper or live walk-forward.** v0.3.0+ scope.
- **Automatic candidate ranking or `ledgr_tune()`.**
- **Multiplicity correction inside the engine.**
- **Composite multi-metric selection rules.** Future selection-rule DSL.
- **Walk-forward sessions nested inside `ledgr_sweep()` candidates.** Future composition concern; v1 explicitly rejects.
- **`ledgr_promote_walk_forward()` or parameter-path / selection-rule promotion.** v1 users may extract a candidate from walk-forward inspection and promote it via existing `ledgr_promote()` with an explicit note.

---

## 6. Core Vocabulary

### 6.1 Fold definition

A fold definition is an immutable description of the train and test windows for a single fold. It carries:

- a `fold_id` deterministic from its content;
- a windowing scheme (`rolling` or `anchored` for v1);
- the train window start and end timestamps;
- the test window start and end timestamps;
- an optional gap (reserved field; v1 binds to `NULL`);
- a fold sequence number within its parent session.

A fold definition is a value object. It is independently hashable.

### 6.2 Walk-forward session

A walk-forward session is the engine-owned batch of runs that produces walk-forward evidence. It is parameterized by:

- a sealed snapshot;
- an experiment (strategy + features + universe + opening + execution options + metric context + optional risk chain);
- a parameter grid;
- a list of fold definitions;
- a selection rule;
- a master seed.

A session has a `session_id` deterministic from its content. The session is the artifact unit walk-forward inspection refers to.

### 6.3 Fold run

A fold run is one execution of the existing fold core over one fold's train + test window pair. For v1 with a parameter grid, this expands to a per-candidate train sweep, selection of one candidate via the selection rule, and a single-candidate test run.

### 6.4 Selection rule and its v1 contract

A selection rule is a ledgr-classed object that, given per-candidate train-window scores for one fold, returns the `candidate_key` to test. For v1, ledgr ships at minimum:

- `ledgr_select_argmax(metric)` — pick the candidate with the highest value of the named metric.
- `ledgr_select_argmin(metric)` — pick the candidate with the lowest value.

**v1 binding contract for selection rules:**

1. **Train-window-only inputs.** Selection rules see only the train-window score rows for the current fold. They have no access to test-window rows, future-fold rows, or rows from other sessions.
2. **Named metric.** Each rule declares its required metric name. Missing metric in the score rows is a classed failure (`ledgr_walk_forward_metric_missing`).
3. **Non-finite policy.** `NA`, `NaN`, and infinite metric values are dropped from the eligible-candidate set. If the policy is configurable in future versions, the v1 default is "drop."
4. **Tie-breaking.** Ties on the metric are broken by ascending `candidate_key` lexicographic order. Deterministic and stable across replays.
5. **Empty eligible set.** If no candidate has a finite metric value, the rule raises a classed failure (`ledgr_walk_forward_no_selection`); the fold is marked failed; the session may continue or abort per `stop_on_fold_error`.
6. **Identity contribution.** The selection rule's class name and parameters participate in session identity. Two sessions with different selection rules produce different `session_id` hashes.

Composite selection (multi-metric, stability-region, top-N robust) is deferred to a future selection-rule DSL.

### 6.5 Fold artifact

A fold artifact is the durable evidence record for one fold: the fold definition (with hashes), per-candidate train-window scalar scores, the selected `candidate_key`, and the test-run reference. A walk-forward session emits one fold artifact per fold.

### 6.6 Score matrix (v1 scalar form)

The score matrix is the union of per-candidate train-window scores plus per-fold selected-candidate test-window scores across all folds. Its v1 shape is scalar: one row per `(session_id, fold_seq, candidate_key, window, metric_name)`.

**v1 scope:** sufficient for fold/candidate inspection, train/test ranking, selected-candidate OOS review, and scalar-metric PBO approximation per Bailey/Borwein/López de Prado/Zhu.

**v1 explicit non-scope:** the v1 score matrix is *not* sufficient input for DSR (requires return moments), CPCV (requires path identity and pathwise series), or any nonlinear-metric recomputation over different partitions. Diagnostic retention tiers that need these inputs are reserved as a future RFC; v1 must not preclude them via schema choices.

### 6.7 Candidate key vs candidate label

Two distinct concepts:

- **`candidate_key`** is a deterministic content hash over `(params, feature_params, strategy_hash, feature_set_hash, alias_map_hash, metric_context_hash, risk_chain_hash if present, execution_seed)`. It identifies a candidate independently of grid-row order, run_id, or sweep_id.
- **`candidate_label`** is the human-readable label from the parameter grid (e.g., `"qty_10"` or a `grid_<hash>` auto-label). It is for display, not identity.

The v1 score matrix uses `candidate_key` as the identity column. `candidate_label` is preserved as a metadata column for inspection.

---

## 7. Bound Design Decisions

### 7.1 Walk-forward is a wrapper, not a second engine

```text
ledgr_walk_forward()
  -> for each fold:
       -> ledgr_sweep() on the train window
       -> selection_rule applied to train-window score rows
       -> ledgr_run() on the test window with the selected candidate
  -> aggregate fold artifacts into a session result
```

The fold core sees no walk-forward concept. Pulse causality, fill timing, cost resolution, and ledger writing are unchanged.

**Rationale:** This is the strongest cross-framework pattern (quantstrat, PortfolioAnalytics, LEAN's `train()` scheduler) and the closest match to ledgr's "no second execution engine" invariant.

### 7.2 Fold definitions are first-class durable artifacts

A fold definition has its own constructor (`ledgr_fold(...)`) and identity hash. It can be serialized, persisted, and inspected independently of any session. Sessions reference folds by identity.

**Rationale:** The rsample/sklearn pattern of explicit split objects is the cleanest precedent for reproducibility.

### 7.3 Honest OOS evidence is procedural at the walk-forward API

Within `ledgr_walk_forward()`, the engine enforces:

```text
1. Sweep all candidates on the train window only.
2. Apply the selection rule to the train-window scores.
3. Run the single selected candidate on the test window.
4. The test-window result is the OOS evidence for this fold.
```

The walk-forward API does not facilitate or accept sweep-then-test-the-winner as walk-forward evidence. Specifically:

- `ledgr_walk_forward()` does not accept precomputed full-snapshot sweep results as fold-local selection inputs.
- `ledgr_walk_forward()` does not accept a preselected candidate and report fold tests as if it had been chosen fold-locally.

`ledgr_sweep()` remains an exploratory full-snapshot API and is unaffected by this rule. Users running independent sweeps outside walk-forward continue to receive exploratory evidence; the framework does not pretend to prevent that. The procedural rule constrains walk-forward, not the package as a whole.

**Rationale:** The literature (Bailey/Borwein/Zhu PBO, "Pseudo-Mathematics") shows the honesty of walk-forward depends on procedural ordering. The walk-forward API rejects the anti-pattern by construction; the rest is documentation discipline that v0.1.8.5 already covers.

### 7.4 Single-snapshot model for v1

A walk-forward session is bound to one sealed snapshot. Cross-snapshot walk-forward (one fold = one snapshot) is deferred.

**Rationale:** Matches the cross-framework default. Cross-snapshot interacts with snapshot lineage (future RFC).

### 7.5 v1 score matrix is scalar and sufficient for scalar diagnostics only

The session-level artifact is a per-`(fold, candidate_key, window, metric_name)` scalar score matrix. Derived stitched views (per-fold equity strips, parameter paths across folds, train-vs-test scatter) are computed from the matrix on demand.

**What the v1 matrix is sufficient for:**

- per-fold candidate inspection and ranking;
- selected-candidate OOS review;
- scalar-metric PBO approximation per the CSCV procedure;
- the CRAN `pbo` package's input shape after a tibble-pivot helper.

**What it is not sufficient for:**

- DSR (requires return moments, sample length, effective trial count).
- CPCV (requires path identity and pathwise return series).
- Any nonlinear-metric recomputation over different partitions.
- Per-fold per-candidate equity-curve reconstruction.

**Future diagnostic retention tiers** (return-series storage, sufficient-statistics rows, path identity, equity payload references) are reserved as a future RFC. The v1 schema must leave room for them without forcing destructive migration.

**Rationale:** The seed v1 overclaimed sufficiency. Bailey/Borwein/Zhu's CSCV is the strongest claim the literature supports for a scalar matrix; DSR and CPCV need more. Per-CRAN policy, the v1 schema can be revised when richer retention lands, but the design must not pretend richer artifacts are already covered.

### 7.6 Calendar-time fold boundaries for v1

Fold boundaries are timestamps in calendar time. Trading-day count, market-state, and regime-aware boundaries are deferred to future RFCs.

**Rationale:** Calendar time is the universal default. Trading-time requires a market-calendar abstraction ledgr does not currently have. State-based requires a regime classifier that introduces look-ahead hazards.

### 7.7 Strategy contract is invariant

Walk-forward does not extend `function(ctx, params)`. Strategies do not see fold boundaries, do not retrain, do not know which fold they are running in.

**Rationale:** Strategy-contract preservation is a hard ledgr invariant.

### 7.8 Hydration, scoring, execution, and opening-state dimensions are explicit

Each fold's execution distinguishes four dimensions:

```text
hydration_start    earliest bar used to warm indicators (within snapshot)
scoring_start      first bar that counts toward fold metrics
scoring_end        last bar that counts toward fold metrics
execution_start    first bar at which the strategy receives a pulse
opening_state      cash, positions, and lot state at execution_start
```

**v1 bindings:**

- **Train fold:** `scoring_start = scoring_end_of_previous_train_or_snapshot_start; scoring_end = train_window_end`. `execution_start = scoring_start`. `hydration_start = snapshot_start` (full prior snapshot bars available for indicator warmup, not visible as strategy pulses). `opening_state` = experiment's configured opening (cash, flat positions or experiment-defined positions).
- **Test fold:** `scoring_start = test_window_start; scoring_end = test_window_end`. `execution_start = scoring_start`. `hydration_start = snapshot_start` (full prior snapshot bars available for indicator warmup, not visible as strategy pulses before `execution_start`). `opening_state` = experiment's configured opening.
- **Both:** indicator warmup uses bars between `hydration_start` and `execution_start`, but those bars do not trigger strategy pulses, do not contribute to metrics, and do not trigger fills. The fold core's existing `LEDGR_LAST_BAR_NO_FILL` warning semantics apply at `scoring_end`.

**Opening-position policy is an open question for spec-cut** (see §15). The three honest options — flat positions, experiment-configured positions, or carry-from-prior-fold — have different research-method implications and the synthesis writer should bind one explicitly.

**Rationale:** Without dimensional separation, fold execution leaks training-window state into test windows or produces incomparable cold-start folds. The current `ledgr_precompute_scoring_range()` already distinguishes `warmup_start`/`scoring_start`/`scoring_end` (where `warmup_start = meta$start`); walk-forward names the same dimensions explicitly at the fold level.

### 7.9 Walk-forward identity composition

```text
session_id = hash(
  snapshot_id,
  experiment_hash,
  param_grid_hash,
  fold_list_hash,
  selection_rule_hash,
  metric_context_hash,
  risk_chain_hash (when present, after v0.1.9 lands),
  master_seed,
  ledgr_version
)

candidate_key = hash(
  params,
  feature_params,
  strategy_hash,
  feature_set_hash,
  alias_map_hash,
  metric_context_hash,
  risk_chain_hash (when present),
  execution_seed
)

fold_id = hash(
  scheme,
  train_start_utc, train_end_utc,
  test_start_utc, test_end_utc,
  gap,
  fold_seq
)

fold_list_hash = hash over ordered fold_ids + constructor metadata
```

Walk-forward identity **does not depend on** the current ephemeral `sweep_id` (which uses pid + counter + Sys.time() and is non-deterministic). It does depend on the same content hashes that sweep candidate provenance uses (strategy, snapshot, feature_set, alias_map, params, feature_params).

After v0.1.9 target risk lands, `risk_chain_hash` participates in both `session_id` and `candidate_key` whenever the experiment has a risk chain. The chainable-risk synthesis binds risk identity into execution identity; walk-forward inherits this automatically once the seed names the dependency.

**Rationale:** The seed v1 left identity composition implicit ("carries forward from sweep promotion"). The current `sweep_id` is not a deterministic identity component; the v1 walk-forward design must compose from content hashes directly.

---

## 8. Proposed Data Model

### 8.1 `ledgr_fold` constructor

```r
ledgr_fold(
  scheme = c("rolling", "anchored"),
  train_start = NULL,    # NULL for anchored: bound to snapshot start
  train_end,
  test_start,
  test_end,
  gap = NULL,            # reserved; v1 must be NULL
  fold_seq = NA_integer_
)
```

Returns a `ledgr_fold` object with deterministic `fold_id` from canonical JSON of contents.

List constructors:

```r
ledgr_folds_rolling(
  snapshot,
  train_window = "1 year",
  test_window = "3 months",
  step = "3 months",
  start = NULL,
  end = NULL
)

ledgr_folds_anchored(
  snapshot,
  origin_end = NULL,
  test_window = "3 months",
  step = "3 months",
  end = NULL
)
```

Both return a `ledgr_fold_list` carrying individual fold objects plus `fold_list_hash` over the ordered `fold_id`s plus constructor metadata (content-addressed).

### 8.2 `walk_forward_sessions` table

```text
session_id              TEXT  PRIMARY KEY
snapshot_id             TEXT  NOT NULL
experiment_hash         TEXT  NOT NULL
param_grid_hash         TEXT  NOT NULL
fold_list_hash          TEXT  NOT NULL
selection_rule_hash     TEXT  NOT NULL
metric_context_hash     TEXT  NOT NULL
risk_chain_hash         TEXT  nullable (post-v0.1.9 when present)
master_seed             INTEGER
status                  TEXT  NOT NULL CHECK (status IN ('done','failed','partial','interrupted'))
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
hydration_start_utc     TIMESTAMP NOT NULL
train_scoring_start_utc TIMESTAMP NOT NULL
train_scoring_end_utc   TIMESTAMP NOT NULL
test_scoring_start_utc  TIMESTAMP NOT NULL
test_scoring_end_utc    TIMESTAMP NOT NULL
gap_value               TEXT  nullable
gap_unit                TEXT  nullable
opening_state_policy    TEXT  NOT NULL CHECK (...)  -- spec-cut bound enum
selected_candidate_key  TEXT  nullable until test executes
selected_at_utc         TIMESTAMP nullable
test_run_id             TEXT  nullable; FK to runs
status                  TEXT  NOT NULL CHECK (status IN ('done','failed','skipped'))

UNIQUE(session_id, fold_seq)
```

### 8.4 `walk_forward_scores` table (v1 scalar score matrix)

```text
session_id              TEXT  NOT NULL
fold_id                 TEXT  NOT NULL
fold_seq                INTEGER NOT NULL
candidate_key           TEXT  NOT NULL  -- deterministic content hash
candidate_label         TEXT             -- human-readable grid label
params_hash             TEXT  NOT NULL
feature_set_hash        TEXT  NOT NULL
alias_map_hash          TEXT  nullable
risk_chain_hash         TEXT  nullable
window                  TEXT  NOT NULL CHECK (window IN ('train','test'))
metric_name             TEXT  NOT NULL
metric_value            DOUBLE
n_trades                INTEGER nullable
status                  TEXT  NOT NULL CHECK (status IN ('done','failed'))
error_class             TEXT  nullable
error_msg               TEXT  nullable
execution_seed          INTEGER  -- per-row; equals the fold seed for test-window rows;
                                 -- equals the per-candidate-per-fold derived seed for train-window rows

UNIQUE(session_id, fold_seq, candidate_key, window, metric_name)
```

**Retention policy:**

- **train window:** all candidates (full matrix).
- **test window:** selected candidate only by default.

Top-N test-window retention and full per-candidate test-window storage are open spec-cut questions framed as retention tiers, not implicit core-schema promises.

### 8.5 Test-window run artifacts

Each fold's test-window run is an ordinary ledgr run, written to `runs`, `ledger_events`, `equity_curve`, and `strategy_state` exactly as `ledgr_run()` would write them. `walk_forward_folds.test_run_id` links to the standard `runs.run_id`. Walk-forward does not invent new accounting artifacts.

Existing inspection surfaces (`ledgr_results(bt, what = "equity")`, etc.) work on each fold's test run once `test_run_id` is resolved.

### 8.6 Promotion artifacts (v1 = use existing `ledgr_promote`)

v1 does not add `ledgr_promote_walk_forward()`. Users extract a candidate from walk-forward inspection (typically the latest fold's selected candidate, or a manually justified stable candidate) and promote it via existing `ledgr_promote()` with an explicit note describing the walk-forward evidence basis.

Parameter-path promotion (a schedule of candidates per future period) and selection-rule promotion (commit the rule, not a candidate) remain future RFC scope.

### 8.7 Future retention tiers (reserved, not bound)

The v1 schema reserves room for richer retention without binding:

```text
walk_forward_score_payloads (future)
  -- per-candidate per-fold return series, equity payload refs, sufficient stats
walk_forward_paths (future, CPCV-era)
  -- path identity for combinatorial partitions
walk_forward_diagnostic_metadata (future)
  -- family definitions, effective trial counts, multiplicity context
```

These tables do not exist in v1. The v1 schema must not preclude them; specifically, `walk_forward_scores.candidate_key` must remain stable across retention-tier expansions.

---

## 9. Proposed Fold-Execution Semantics

### 9.1 Per-fold execution sequence

```text
1. Resolve hydration, scoring, execution, and opening_state per §7.8.
2. Construct an ephemeral train-window experiment view (same snapshot,
   restricted scoring range, full snapshot hydration).
3. Run ledgr_sweep over the parameter grid on the train view.
4. Write per-candidate train-window scalar scores to walk_forward_scores
   with window = 'train'.
5. Apply the selection rule to train-window rows for this fold per §6.4
   contract. Result is a candidate_key.
6. Construct an ephemeral test-window experiment view.
7. Run ledgr_run on the test view with the selected candidate's params
   and feature_params (and risk chain, when present).
8. Write the test run to runs and the standard accounting tables.
9. Write the selected candidate's test-window scalar scores to
   walk_forward_scores with window = 'test'.
10. Update walk_forward_folds with selected_candidate_key, test_run_id,
    and status.
```

### 9.2 Failure handling

Per-candidate train failures → `walk_forward_scores` row with `status = 'failed'`. Selection rule sees only successful candidates per §6.4.5. If no candidate survives or selection raises, the fold is marked `failed`. Session continues unless `stop_on_fold_error = TRUE`.

Test-run failure marks the fold `failed` but preserves train-window scores. Session status becomes `partial` if any fold failed but at least one completed; `failed` if all folds failed.

### 9.3 Determinism

```text
session master_seed
  -> per-fold seed = deterministic_derive(master_seed, fold_seq)
  -> per-candidate-per-fold seed = deterministic_derive(per_fold_seed, candidate_key)
```

Replay of a session with identical config produces identical `session_id`, `fold_id`, `candidate_key` values, identical `walk_forward_scores` rows, and identical test-run artifacts.

### 9.4 Persistence and batching

Default output:

- Session metadata → `walk_forward_sessions`.
- Fold metadata → `walk_forward_folds`.
- Scalar scores → `walk_forward_scores`.
- Test-window runs → standard run tables.

**Not persisted by default:**

- Per-candidate per-fold full equity curves.
- Per-candidate per-fold fill records.
- Per-candidate per-fold return series.

These are reserved for future retention tiers (§8.7). v1 binds the scalar-only default.

**Batching invariant** (mirrors v0.1.8.5 spec): no per-pulse DB writes in the walk-forward hot path. The session output handler batches writes per fold completion.

---

## 10. Fold-Core Integration

### 10.1 No fold-core changes; a shared experiment-window contract is required

The walk-forward feature does not modify [R/fold-core.R](R/fold-core.R). However, enabling fold-scoped sweep + run requires a **shared experiment-window contract** consumed by `ledgr_run()`, `ledgr_sweep()`, `ledgr_precompute_features()`, and precomputed-feature validation.

The current public surfaces do not expose this contract:

- `ledgr_run(exp, ...)` ([R/backtest.R:320](R/backtest.R#L320)) has no `start` or `end` argument.
- `ledgr_run_experiment()` ([R/backtest.R:333](R/backtest.R#L333)) derives `start` from `exp$opening$date %||% exp$snapshot$metadata$start_date` and `end` from `exp$snapshot$metadata$end_date`.
- `ledgr_sweep()` ([R/sweep.R:59](R/sweep.R#L59)) calls `ledgr_precompute_scoring_range(meta)` with no start/end, defaulting to the full snapshot.
- `ledgr_precompute_features(exp, param_grid, start, end)` ([R/precompute-features.R:41](R/precompute-features.R#L41)) does accept start/end, but `ledgr_sweep()` does not pass them.
- Precomputed-feature validation does not currently check against a requested fold window.

**v1 implementation must establish:**

1. A windowed call signature accepted by `ledgr_run()` and `ledgr_sweep()` (either explicit `start`/`end` arguments or via the experiment-window value object below).
2. A parity test that a fold-window walk-forward call produces identical results to a direct windowed `ledgr_run()` call over the same window with the same params, feature_params, risk chain, and seed.

The fold core itself does not change. The wrapper surface does. This is more than a single helper.

### 10.2 Experiment-window helper (internal for v1)

```r
ledgr_experiment_window(exp, start_utc, end_utc) -> ledgr_experiment
```

The returned experiment carries the same snapshot, strategy, features, universe, opening, execution options, and metric context, with scoring range bound to the window and hydration range bound to snapshot start. Snapshot identity is unchanged; experiment-window identity is a derivative.

**v1 keeps this helper internal.** It is part of the experiment-window contract surface and should not be exposed until that contract stabilizes. Public exposure is a future-RFC decision.

### 10.3 Output-handler dispatch

`ledgr_run` and `ledgr_sweep` output handlers continue to write their respective artifacts. Walk-forward adds a session-level output handler for `walk_forward_sessions` / `walk_forward_folds` / `walk_forward_scores`. Handlers own their own tables; no interference.

---

## 11. Research, Sweep, And Future Paper/Live Mode Behavior

### 11.1 Research mode (v1 scope)

Walk-forward in research mode is the default v1 use case. Sealed snapshot, deterministic execution, reproducible from session identity, no broker, no live data.

**OMS-synthesis alignment:** Research-mode walk-forward writes ordinary run artifacts and walk-forward diagnostic artifacts only. It does not write `order_events`, `target_decisions`, or any OMS lifecycle artifacts. A future OMS/paper/live walk-forward RFC may bind that behavior; v1 does not.

### 11.2 Sweep interaction

`ledgr_walk_forward()` uses `ledgr_sweep()` per fold. It does not replace it. Users who want exploratory sweep evidence over the full snapshot continue to call `ledgr_sweep()` directly.

A walk-forward session is not a sweep candidate. Walk-forward sessions cannot be nested inside `ledgr_sweep()` as candidate inputs in v1; this is an explicit non-goal.

### 11.3 Promotion interaction (v1 = use existing `ledgr_promote`)

v1 does not add walk-forward-specific promotion machinery. Users extract a candidate from walk-forward inspection and promote it via `ledgr_promote()`. The promotion note should reference the walk-forward `session_id` and the basis for selecting that specific candidate.

Parameter-path promotion (commit a schedule) and selection-rule promotion (commit a process) are future RFC scope.

### 11.4 Paper/live mode (future)

Per the OMS synthesis, paper and live walk-forward are v0.3.0+ scope. Specific v1 forward-compat commitments:

- v1 research walk-forward writes no OMS lifecycle artifacts.
- A future paper/live walk-forward RFC will decide whether each fold's test run emits its own `order_events` stream (with the artifact-multiplication concerns the OMS synthesis named).
- The v1 score-matrix schema does not preclude per-fold `order_events` linkage in the future; `walk_forward_folds.test_run_id` provides the join point.
- Fold definitions translate naturally to "retraining schedule" in paper/live (LEAN's `train()` pattern).

No paper/live API is bound here.

---

## 12. Selection-Integrity Machinery (Future)

### 12.1 v1 does not compute diagnostics

PBO, CSCV, CPCV, DSR, Holm/BH, Harvey-Liu-Zhu thresholds, and MinTRL are not computed by walk-forward in v1. They are downstream consumers of the score matrix (and, for some, of future richer retention).

### 12.2 What the v1 scalar score matrix supports

**Sufficient for** (without re-execution):

- Bailey/Borwein/López de Prado/Zhu CSCV PBO approximation when implemented over scalar fold metrics.
- The CRAN `pbo` package's input shape after a tibble-pivot helper.
- Per-fold candidate inspection, ranking, train-vs-test gap analysis.
- Selected-candidate OOS review.

**Insufficient for** (would require richer retention):

- DSR (needs return moments, sample length, effective trial count).
- CPCV (needs path identity, pathwise return series).
- Nonlinear-metric recomputation over different partitions.
- Per-candidate per-fold equity-curve reconstruction.

### 12.3 Future retention tiers

Future RFCs may add diagnostic-retention tiers that preserve return series, sufficient statistics, path identity, or equity payload references. v1's job is to **not preclude** these via schema choices, not to **define** them.

### 12.4 Family definition for multiplicity

Per Harvey/Liu/Zhu, multiplicity correction requires defining the "family" of tested hypotheses. ledgr's session boundary is the natural candidate-family boundary: one session = one family. The data model records session identity per score row; family boundaries are recoverable.

---

## 13. Public API Direction

### 13.1 v1 public surface

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
ledgr_walk_forward_extract_candidate(session_id, fold_seq = "latest")
```

The last helper supports the §11.3 promotion path: it returns the params, feature_params, candidate_key, and walk-forward provenance for the candidate the user wants to promote via `ledgr_promote()`.

### 13.2 `ledgr_walk_forward()` is the v1 entry point

Walk-forward is exposed as a dedicated entry point, not as a modifier on `ledgr_sweep()` or `ledgr_run()`. The dedicated surface makes procedural ordering visible at the API level.

### 13.3 Selection-rule extensibility

v1 accepts only ledgr-classed selection-rule objects (`ledgr_select_*`). Arbitrary user-supplied selection functions are deferred until the function-fingerprinting story for risk and cost is settled. Composite multi-metric selection is deferred to a future selection-rule DSL.

### 13.4 Inspection surfaces are read-only

All `ledgr_walk_forward_*()` helpers are read-only. They do not mutate session state, do not recompute, and do not re-execute folds.

### 13.5 Internal helpers

```r
ledgr_experiment_window(exp, start_utc, end_utc)  # internal v1
ledgr_walk_forward_derive_seed(master_seed, fold_seq, candidate_key)  # internal
```

---

## 14. Testing Implications

The v0.1.9.x implementation must include:

- **Determinism tests:** identical session configs produce identical `session_id`, `fold_id`, `candidate_key` values, identical `walk_forward_scores` rows, and identical test-run identities.
- **Identity exclusion tests:** `session_id` and `candidate_key` do not change when only the ephemeral `sweep_id` changes (verify by running the same session twice and checking IDs match while sweep_id differs).
- **Risk-chain identity tests** (after v0.1.9 lands): adding a risk chain changes `session_id` and `candidate_key`; removing it changes them back.
- **Honest-OOS tests:** `ledgr_walk_forward()` rejects a precomputed full-snapshot sweep result as fold-local selection input with a classed error.
- **Sweep-window parity tests:** per-fold train-window sweep produces identical results to a direct windowed `ledgr_sweep()` call over the same window with the same grid and seed.
- **Run-window parity tests:** per-fold test-window run produces identical results to a direct windowed `ledgr_run()` call over the same window with the same params and seed.
- **Score-matrix completeness tests:** one row per `(fold_seq, candidate_key, window, metric_name)` for successful candidates; failed candidates have rows with `status = 'failed'` and no metric_value.
- **Selection-rule contract tests:** NA/NaN/inf candidates are dropped; ties broken by `candidate_key` ascending; empty eligible set raises `ledgr_walk_forward_no_selection`; missing metric raises `ledgr_walk_forward_metric_missing`.
- **Hydration / scoring separation tests:** indicators with lookback longer than the test window produce sensible values from `test_scoring_start` (because hydration uses pre-test bars); strategies receive their first pulse at `execution_start = test_scoring_start`, not before.
- **Schema tests:** pre-CRAN schema versions queryable by canonical column names.
- **R-tibble compatibility:** `walk_forward_scores` is consumable by the CRAN `pbo` package's expected input shape after a documented pivot helper.
- **Batching invariant test:** no per-pulse DB writes in the walk-forward hot path.

---

## 15. Open Questions For Maintainer Review

Synthesis-stage decisions; not blockers for the seed.

### Bound away from open (recorded as no-longer-open):

The following were open in seed v1 and are now bound:

- Public API shape → bound as `ledgr_walk_forward()` (§13.2).
- Calendar vs trading-time defaults → bound as calendar (§7.6).
- Multi-metric selection → bound as single-metric for v1 (§6.4).
- Gap field default → bound as `NULL` (§8.1).
- Fold-list identity → bound as content-addressed (§7.9).
- Walk-forward inside sweep → bound as explicit non-goal (§5).
- Experiment-window helper visibility → bound as internal v1 (§10.2).

### Remaining open for spec-cut:

1. **Promotion semantics beyond v1 baseline.** v1 binds "use existing `ledgr_promote()` of an extracted candidate." Parameter-path promotion (commit a schedule) and selection-rule promotion (commit a process) remain future RFC scope; what's the trigger for opening them?

2. **Top-N retention.** Should the test-window persist top-N candidates (not just the selected one) to support stability-region analysis and PBO with richer per-fold evidence? Framed as retention tier, not core schema.

3. **Diagnostic retention tier definitions.** Which future-RFC tier brings return series? Sufficient statistics? Equity payload references? Path identity? The seed reserves room; tier-by-tier specification is open.

4. **Opening-state policy for test folds.** v1 names the dimension (§7.8) but does not bind the policy. Three honest options: flat positions, experiment-configured positions, carry-from-prior-fold. Which is the v1 default and which are user-configurable?

5. **Per-fold telemetry budget.** A 50-candidate × 20-fold session = 1000 train runs + 20 test runs. What's the per-pulse and per-fold overhead bound? §9.4 binds "no per-pulse DB writes"; absolute bounds remain spec-cut.

6. **Partial session recovery.** Restart-only is simpler; resumable sessions need idempotent write semantics. v1 default?

7. **Failed-fold accounting and session-status vocabulary.** `done / failed / partial / interrupted` is named in §8.2; the rules for which terminal status applies in which combinations need binding.

8. **Reporting defaults.** What does `print(walk_forward_results)` show by default: per-fold equity strip, train-vs-test scatter, parameter path across folds, single-best-candidate equity? LEAN-style "show everything" vs quantstrat-style "show winner" both have failure modes.

9. **Train vs test metric naming convention.** Stored under same `metric_name` with `window` distinguishing, or distinct names per window?

10. **Universe handling across folds.** v1 default is "experiment universe applies to every fold; user owns universe correctness." Should the API support per-fold universe restriction (e.g., for survivorship-bias-aware research)? Defer to future RFC or open now?

11. **Cross-session comparison contract.** Two walk-forward sessions with different fold lists, same snapshot — what's the comparison surface? Beyond raw inspection helpers.

12. **Calendar-time API spelling.** How do fold constructors handle weekends, holidays, and missing bars? `"3 months"` literal duration vs first-of-month boundaries vs trading-day count adjacencies?

13. **`ledgr_experiment_window()` promotion to public.** When does it stop being internal? After how many users hit the date-range need outside walk-forward?

14. **`ledgr_walk_forward_extract_candidate()` ergonomics.** What's the right default for which fold's candidate to extract? "Latest" is one choice; "most stable" is another but requires defining stability.

---

## 16. Future Obligations Recorded

- **Selection-integrity diagnostics RFC** (v0.1.9.x or later) — implement PBO, CSCV, CPCV scoring, DSR, Holm/BH, MinTRL as consumers of the score matrix and (where required) future retention tiers.
- **Diagnostic retention tiers RFC** — schema for return series, sufficient statistics, path identity, equity payload references. The v1 walk-forward schema must not preclude this; the future RFC binds the actual storage.
- **Purged and embargoed folds RFC** — extend `ledgr_fold()` with label-interval-aware purge logic. Reuse mlfinlab's identified failure modes as test fixtures.
- **Combinatorial purged CV RFC** — multi-path scoring; emits the same score-matrix shape with additional `path_id` column from a future path table.
- **Trading-time and state-based folds RFC** — extend fold-definition scheme vocabulary. State-based folds need explicit treatment of regime-classifier look-ahead hazards.
- **Cross-snapshot walk-forward RFC** — coordinated with snapshot lineage RFC.
- **OMS interaction RFC** — per the OMS synthesis, walk-forward interaction with per-fold OMS event streams must be addressed before paper/live walk-forward.
- **Paper/live walk-forward RFC** — v0.3.0+ scope.
- **Selection-rule DSL RFC** — composite multi-metric selection, stability-region selection, top-N robust selection.
- **Survivorship-aware universe construction RFC** — adjacent to PIT data RFC; will revisit walk-forward universe handling.

---

## 17. Recommended First Ticket Packet

Indicative; LDG IDs assigned at v0.1.9.x ticket cut.

1. Add `ledgr_fold()` constructor with rolling and anchored schemes; deterministic `fold_id`.
2. Add `ledgr_folds_rolling()` and `ledgr_folds_anchored()` with deterministic `fold_list_hash`.
3. Add `ledgr_experiment_window()` (internal) and the shared experiment-window contract on `ledgr_run()`, `ledgr_sweep()`, `ledgr_precompute_features()`, plus precomputed-feature validation.
4. Add `ledgr_select_argmax()` and `ledgr_select_argmin()` with the §6.4 contract.
5. Add `walk_forward_sessions`, `walk_forward_folds`, `walk_forward_scores` schema and schema-version handling.
6. Add `ledgr_walk_forward()` orchestrator composing per-fold sweep + selection + test run per §9.1.
7. Add session-level output handler for walk-forward artifacts; verify batching invariant.
8. Add read-only inspection helpers: `ledgr_walk_forward_results()`, `_scores()`, `_folds()`, `_extract_candidate()`.
9. Add determinism, identity-exclusion, parity, score-matrix completeness, hydration-separation, and selection-rule contract tests.
10. Add tibble-pivot helper for CRAN `pbo` package compatibility; documentation contract test for shape.
11. Add documentation: walk-forward vignette covering rolling/anchored windowing, the procedural rule (at walk-forward API level), the score matrix as v1 evidence, the diagnostic-tier roadmap, and extraction-for-promotion.
12. Forward-link from v0.1.8.5 workflow article to the walk-forward vignette.
13. Update NEWS.md, design index, and roadmap with v0.1.9.x walk-forward status.

---

## 18. Final Recommendation

Add walk-forward as a procedural wrapper over the existing fold core. Keep the strategy contract unchanged. Make fold definitions, the scalar score matrix, and walk-forward sessions first-class durable artifacts. Bind the honest sweep-select-test ordering at the walk-forward API surface (not at the engine surface) and leave `ledgr_sweep()` as an exploratory peer. Defer selection-integrity diagnostics, purging, CPCV, trading-time/state-based folds, and richer retention tiers to follow-up RFCs; the v1 data model reserves room for them without binding their schemas.

The correct first walk-forward milestone is not a complete selection-integrity diagnostic suite. The correct first milestone is a deterministic rolling/anchored walk-forward over one sealed snapshot that produces a per-fold per-candidate scalar score matrix sufficient for inspection and scalar-metric PBO approximation — while explicitly reserving the richer retention needed for DSR, CPCV, and nonlinear-metric recomputation as future work.

The architectural reference point is NautilusTrader's configuration-bound run-spec composition (study `BacktestRunConfig`/`BacktestNode`/`BacktestDataConfig`/`ReportProvider`; do not copy the catalog semantics). The procedural reference point is quantstrat's per-fold train + select + immediate test pattern. The reporting reference point is LEAN's parameter-stability-aware surfaces. None of them ships exactly the right thing for ledgr; v1 borrows the right pieces from each and stays narrower than any of them.
