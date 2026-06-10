# ledgr v0.1.9.4 Spec

**Status:** Draft for Claude / maintainer review.
**Target Branch:** `v0.1.9.4`.
**Scope:** Fourth packet in the v0.1.9.x four-tick arc. Ship the first
walk-forward evaluation surface: calendar-time rolling and anchored folds,
fold-local train sweeps, ledgr-owned scalar selection rules, selected-candidate
test runs, walk-forward session identity, and compact fold/score evidence.
**Ticket state:** Draft tickets `LDG-2612` through `LDG-2626` are cut for
Claude / maintainer review. Implementation has not started.
**Non-scope for this pass:** Selection-integrity diagnostics, PBO/CSCV/CPCV,
DSR, purging and embargo, randomized or blocked slice protocols, cross-snapshot
walk-forward, walk-forward inside sweep composition, ML-first training hooks,
selection-session archive / evaluation registry, candidate clustering,
benchmark-relative metrics, top-N or all-candidate test retention,
gross-vs-net attribution, signal decay, implementation/cost decay,
PerformanceAnalytics adapters, liquidity/capacity policy, OMS behavior,
paper/live walk-forward, target-construction helper expansion, risk-chain
constraint expansion, crypto-readiness work, and compiled-core architecture
changes.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `inst/design/rfc_cycle.md`
- `inst/design/release_ci_playbook.md`

Accepted walk-forward design:

- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed_v2.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_response.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_final_review.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`

Cross-cycle identity handoffs:

- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`
- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`

Relevant horizon entries:

- `2026-06-05 [planning] v0.1.9.x line sequencing -- four-tick arc culminating in walk-forward`
- `2026-06-05 [planning] v0.1.9.4 walk-forward Section 17 gate-row obligations from the v0.1.9.x arc`
- `2026-06-09 [research] Selection-session archive / evaluation registry is parked, not committed`
- `2026-06-09 [research] ML-first capability shape for v0.2.x`
- `2026-06-09 [research] Post-sweep candidate clustering as selection-integrity input`
- `2026-05-27 [execution] Cost-model post-v0.1.9.x direction`
- `2026-05-28 [execution] RNG resume is non-deterministic for stochastic strategies`

Completed packet inputs:

- `inst/design/ledgr_v0_1_8_11_spec_packet/`
- `inst/design/ledgr_v0_1_9_1_spec_packet/`
- `inst/design/ledgr_v0_1_9_2_spec_packet/`
- `inst/design/ledgr_v0_1_9_3_spec_packet/`

---

## 1. Thesis

v0.1.9.4 turns ledgr's sweep and run evidence into a first walk-forward
research workflow without creating a new execution engine.

The execution shape is:

```text
sealed snapshot
  -> explicit fold definitions
  -> for each fold:
       ledgr_sweep() on the fold's train scoring window
       selection_rule(train score rows only) -> candidate_key
       ledgr_run() on the fold's test scoring window with selected params
  -> compact session, fold, score, and selected-run evidence
```

Walk-forward is a wrapper over the same fold core used by `ledgr_run()` and
`ledgr_sweep()`. It does not add a walk-forward pulse loop, does not reinterpret
events, and does not turn provenance into statistical validation.

The release exists because the package now has the three identity dependencies
walk-forward needs:

- v0.1.9.1 cost identity through `cost_model_hash` and `cost_plan_json`;
- v0.1.9.2 sweep persistence machinery for fold-local sweep dispatch;
- v0.1.9.3 risk-chain identity through `risk_chain_hash` and `risk_plan_json`.

The first implementation is intentionally scalar and procedural. It answers:

```text
which candidate was selected in each train window,
why was it eligible,
what happened when that candidate was run out of sample,
and can that evidence be reopened and promoted explicitly?
```

It does not answer the downstream selection-integrity question:

```text
after seeing this family of candidates and folds, how much should I distrust
the selected result because of multiple testing?
```

That diagnostic layer is deferred until the walk-forward session shape is
implemented and measured.

---

## 2. Release Goals

v0.1.9.4 has nine planning goals.

### Fold And Window Contract

1. Add immutable fold objects plus rolling and anchored fold-list constructors
   over calendar-time boundaries. V1 uses one sealed snapshot and explicit date
   windows; cross-snapshot, market-calendar-aware, state-aware, randomized,
   blocked, purged, and embargoed folds are deferred.

2. Add a shared internal experiment-window contract consumed by run, sweep,
   precompute, and precomputed-feature validation. The contract carries:

```text
hydration_start
scoring_start
scoring_end
execution_start
opening_state_policy
```

The shared window contract is consumed through an internal helper, working name
`ledgr_experiment_window()`. It is not exported in v1.

3. Prove fold-window parity:

```text
fold train sweep == direct windowed ledgr_sweep()
fold test run    == direct windowed ledgr_run()
```

with identical snapshot, params, feature params, metric context, cost model,
risk chain, and seed.

### Walk-Forward Orchestration

4. Add `ledgr_walk_forward()` as an orchestrator over fold-local train sweeps,
   classed selection rules, and selected-candidate test runs. Train sweeps see
   train-window scalar scores only. Test execution runs exactly the selected
   candidate for the next test window.

5. Make opening-state policy explicit. V1 default is
   `opening_state_policy = "carry_test_state"`:

   - fold 1 test starts from the experiment opening state;
   - later test folds start from the previous test fold's terminal cash,
     positions, and lot state;
   - every train sweep starts from the experiment opening state.

   V1 admits `opening_state_policy = "flat_test_state"` as an explicit opt-in.
   The opt-in emits `ledgr_walk_forward_cold_start_warning` and sets
   `cold_start_distorted = TRUE` in the degradation table.

### Selection Rules And Metric Eligibility

6. Add ledgr-owned selection rules:

```r
ledgr_select_argmax(metric)
ledgr_select_argmin(metric)
```

Selection rules use the current fold's train-window score rows only. They drop
`NA`, `NaN`, and infinite values from eligibility, fail when no finite
candidate remains, and break ties by ascending `candidate_key`.

7. Add metric classification to the metric definition or metric metadata
substrate. Selection rules may select only metrics classified as `rate`,
`annualized`, `ratio`, or `length_invariant`. Level and count metrics fail closed with
`ledgr_walk_forward_metric_class_invalid`, including at least `total_return`
and `n_trades` in the release-blocking tests.

### Identity, Persistence, And Inspection

8. Persist compact walk-forward artifacts:

```text
walk_forward_sessions
walk_forward_folds
walk_forward_scores
```

The selected test run for each fold is an ordinary `ledgr_run()` artifact
linked by `test_run_id`. Walk-forward creates no new accounting-event,
ledger, fill, trade, or equity-table semantics.

9. Add read-only inspection and extraction helpers. Candidate extraction is
explicit and promotion-ready:

```text
walk-forward inspection
  -> ledgr_walk_forward_extract_candidate(..., fold_seq = <integer or "latest">)
  -> ledgr_promote(exp, candidate, run_id, note = ...)
```

`fold_seq` has no default. Passing `fold_seq = "latest"` requires a non-empty
`selection_rationale`; otherwise extraction fails with
`ledgr_walk_forward_latest_without_rationale`.

---

## 3. Binding Boundaries

### 3.1 Synthesis Authority

`rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` is binding for this packet,
including Amendment 1, Amendment 2, and Section 17. If this spec and the
synthesis conflict, the synthesis wins unless a maintainer decision explicitly
amends it before implementation starts.

### 3.2 Wrapper, Not Engine

`ledgr_walk_forward()` must call existing run and sweep machinery over explicit
windows. `R/fold-core.R` must not gain walk-forward-specific pulse semantics.
The fold core remains the owner of pulse order, strategy invocation, target
validation, risk application, fill timing, cost resolution, state mutation,
event emission, accounting, and metric inputs.

### 3.3 Procedural Honesty

Walk-forward must enforce:

1. evaluate all candidates on the train window only;
2. select using train-window scalar scores only;
3. run exactly the selected candidate on the next test window;
4. record the test result as out-of-sample fold evidence.

The API must not accept a full-snapshot sweep result as fold-local selection
input. It must not accept a preselected candidate and then report fold tests as
if selection happened fold-locally.

### 3.4 Single Snapshot

V1 walk-forward uses one sealed snapshot and date windows layered over that
snapshot. Cross-snapshot walk-forward waits for snapshot-lineage work.

### 3.5 Scalar Evidence, Not Validation

The v1 score matrix is enough for fold/candidate inspection, train/test
ranking, selected-candidate out-of-sample review, and later PBO-compatible
pivot helpers. It is not enough for DSR, CPCV, nonlinear metric recomputation,
bootstrap confidence intervals, or full selection-integrity diagnostics.

### 3.6 No Evaluation Registry

This packet does not add an always-on selection-session archive or generic
evaluation registry. Walk-forward persists its own compact session artifacts;
saved sweeps remain explicit v0.1.9.2 artifacts. A future registry may index
those artifacts after the walk-forward MVP and selection-diagnostics scoping
stabilize.

---

## 4. Public API

The public v1 surface is:

```r
ledgr_fold(...)
ledgr_folds_rolling(...)
ledgr_folds_anchored(...)
ledgr_select_argmax(metric)
ledgr_select_argmin(metric)
ledgr_walk_forward(
  exp,
  grid,
  folds,
  selection_rule,
  seed = NULL,
  opening_state_policy = c("carry_test_state", "flat_test_state"),
  ...
)
ledgr_walk_forward_results(session_id)
ledgr_walk_forward_scores(session_id)
ledgr_walk_forward_folds(session_id)
ledgr_walk_forward_extract_candidate(
  session_id,
  fold_seq,
  selection_rationale = NULL
)
```

Ticket cutting may refine argument names for fold constructors, but the public
names above and the logical fields in Sections 5 and 6 are bound.

Inspection helpers are read-only. They do not mutate, recompute, or re-execute.

Example:

```r
folds <- ledgr_folds_rolling(
  train_window = "1 year",
  test_window = "3 months",
  step = "3 months"
)

wf <- ledgr_walk_forward(
  exp,
  grid = ledgr_param_grid(fast = c(10, 20), slow = c(50, 100)),
  folds = folds,
  selection_rule = ledgr_select_argmax("sharpe_ratio"),
  seed = 42L
)

scores <- ledgr_walk_forward_scores(wf$session_id)
candidate <- ledgr_walk_forward_extract_candidate(
  wf$session_id,
  fold_seq = "latest",
  selection_rationale = "Use the latest OOS-selected parameterization for a manual holdout check."
)
```

---

## 5. Fold And Window Model

`ledgr_fold()` returns an immutable value object with these logical fields:

```text
fold_id
fold_seq
scheme
train_start_utc
train_end_utc
test_start_utc
test_end_utc
gap_value
gap_unit
```

`gap = NULL` is the only accepted v1 behavior. Non-NULL gap semantics are
reserved for purged and embargoed folds.

V1 supports two fold schemes:

- `rolling`: each fold has a fixed-width train window and fixed-width test
  window;
- `anchored`: each fold's train window begins at the anchor and expands as the
  fold sequence advances.

V1 fold boundaries are calendar-time timestamps. Constructor behavior around
weekends, holidays, and missing bars is fail-closed:

- fold boundaries are converted to UTC POSIXct values;
- each scoring window must contain at least two scoring pulses after snapshot
  alignment;
- empty train/test windows fail with `ledgr_walk_forward_invalid_fold_window`;
- missing bars continue to follow the sealed-snapshot dense-panel contract;
- market-calendar-aware adjustment is deferred.

For every fold:

```text
train fold:
  hydration_start = snapshot_start
  scoring_start   = train_start_utc
  scoring_end     = train_end_utc
  execution_start = scoring_start

test fold:
  hydration_start = snapshot_start
  scoring_start   = test_start_utc
  scoring_end     = test_end_utc
  execution_start = scoring_start
```

Indicator warmup may use bars between `hydration_start` and
`execution_start`; those bars are not scored and are not exposed as pre-window
strategy pulses. Existing final-bar no-fill semantics apply at `scoring_end`.
Precomputed feature validation must cover snapshot hash, feature identities,
scoring range coverage, and hydration range coverage for each fold window.

---

## 6. Data Model

`walk_forward_sessions` logical fields:

```text
session_id
snapshot_hash
experiment_hash
param_grid_hash
fold_list_hash
selection_rule_hash
metric_context_hash
cost_model_hash
risk_chain_hash
master_seed
opening_state_policy
created_at_utc
ledgr_version
meta_json
```

`walk_forward_folds` logical fields:

```text
session_id
fold_id
fold_seq
scheme
train_start_utc
train_end_utc
test_start_utc
test_end_utc
hydration_start_utc
train_scoring_start_utc
test_scoring_start_utc
opening_state_policy
selected_candidate_key
selected_at_utc
test_run_id
status
```

`walk_forward_scores` logical fields:

```text
session_id
fold_id
fold_seq
candidate_key
candidate_label
params_hash
feature_params_hash
feature_set_hash
alias_map_hash
metric_context_hash
cost_model_hash
risk_chain_hash
window
metric_name
metric_value
n_trades
status
error_class
error_msg
execution_seed
```

Train rows exist for all train candidates or candidate failures. Test rows
exist only for the selected candidate in v1.

Walk-forward tables store identity hashes only for cost and risk. Cost and risk
plan JSON bytes are not duplicated into walk-forward tables; reconstruction
goes through the linked selected test run's stored config. Reopen must verify
that the linked test run is readable and schema-compatible before completing
plan reconstruction.

`status` values for sessions and folds are:

```text
DONE
FAILED
INTERRUPTED
PARTIAL
```

V1 is restart-only, not resumable. An interrupted walk-forward session may be
inspected as partial evidence, but `ledgr_walk_forward()` does not resume from
the partial artifact. An interrupted session has status `INTERRUPTED` when no
fold completed its train-selection-test write sequence, and `PARTIAL` when at
least one fold has complete train rows, selected-candidate test rows, and fold
metadata. Re-running the same session inputs must reproduce the same
`session_id`, fold IDs, candidate keys, seeds, selected candidates, and
test-run results.

Per-row `execution_seed` is derived deterministically from `master_seed`,
`fold_seq`, `window`, and `candidate_key` using the existing sweep
candidate-seed derivation rule. Unseeded sessions record `NA_integer_`.

---

## 7. Identity And Provenance

`fold_id` is deterministic from canonical JSON of:

```text
scheme
train_start_utc
train_end_utc
test_start_utc
test_end_utc
gap_value
gap_unit
fold_seq
fold_schema_version
```

`fold_list_hash` is deterministic from the ordered vector of `fold_id`s plus
fold-list schema version and constructor metadata.

`selection_rule_hash` is deterministic from canonical JSON of:

```text
type_id
schema_version
metric
direction
```

`candidate_key` is deterministic from canonical JSON of:

```text
params_hash
feature_params_hash
strategy_hash
feature_set_hash
alias_map_hash
metric_context_hash
cost_model_hash
risk_chain_hash
execution_seed
candidate_schema_version
```

It excludes `run_id`, row order, display label, and transient `sweep_id`.

`session_id` is deterministic from canonical JSON of:

```text
snapshot_hash
experiment_hash
param_grid_hash
fold_list_hash
selection_rule_hash
metric_context_hash
cost_model_hash
risk_chain_hash
master_seed
opening_state_policy
walk_forward_schema_version
ledgr_version
```

`experiment_hash` is a walk-forward base-experiment hash derived from the same
normalized payload family as `config_hash_payload(config)`, including the same
store-local exclusions. V1 removes cost identity, risk identity, metric-context
identity, and execution-seed fields before hashing because `session_id` carries
those components independently. The derivation rule lives beside the existing
identity helpers and is covered by deterministic hash tests.

Initial schema-version literals are `"v1"` for `fold_schema_version`,
`fold_list_schema_version`, `selection_rule_schema_version`,
`candidate_schema_version`, and `walk_forward_schema_version`.

Walk-forward consumes cost and risk identity. It must not redesign
`cost_model_hash`, `cost_plan_json`, `risk_chain_hash`, or `risk_plan_json`.

---

## 8. Lifecycle

For each fold:

```text
1. Build the train experiment window.
2. Run ledgr_sweep() on the train scoring window.
3. Write train score rows for all candidates.
4. Apply the selection rule to train rows only.
5. Build the test experiment window.
6. Run ledgr_run() on the test scoring window with selected params and feature_params.
7. Link the selected test run through test_run_id.
8. Write selected-candidate test score rows.
9. Mark fold status and selected_candidate_key.
```

Train candidate failures become score rows with `status = "FAILED"`,
`error_class`, and `error_msg`. Selection uses surviving finite candidate rows.
If no finite candidate remains, the fold fails with
`ledgr_walk_forward_no_selection`.

Test-run failure marks the fold failed and preserves train rows. Session status
is `FAILED` if a required fold fails, `INTERRUPTED` if the user interrupts
before any fold completes its train-selection-test write sequence, `PARTIAL` if
the user interrupts after at least one fold has complete train rows,
selected-candidate test rows, and fold metadata, and `DONE` only when all folds
complete.

Walk-forward output writes are batched at fold/session boundaries. No
per-pulse DB writes are added to the walk-forward hot path.

---

## 9. Metric Classification

Metric classification is a property of the metric definition, not the selection
rule. v0.1.9.4 adds a metric-classification field on the metric definition. If
ledgr does not currently have a registered-metrics substrate that supports
per-metric metadata, the ticket cut must specify whether classification is
added to the metric kernel, the metric-context resolution path, or a new
lightweight metric-metadata table. The synthesis Section 16.3 leaves the
mechanism to the packet; this spec preserves that decision.

Allowed selection classifications:

```text
rate
annualized
ratio
length_invariant
```

Forbidden selection classifications:

```text
level
count
path_dependent_level
unknown
```

The exact internal enum names may be refined during ticket cut, but tests must
prove:

- `ledgr_select_argmax("total_return")` or equivalent level metric fails with
  `ledgr_walk_forward_metric_class_invalid`;
- `ledgr_select_argmax("n_trades")` fails with
  `ledgr_walk_forward_metric_class_invalid`;
- a permitted metric such as `sharpe_ratio` can be selected.

Future work may add an explicit override rule with required rationale capture.
There is no override in v1.

---

## 10. Print And Inspection Contract

The data backing `print(walk_forward_results)` must include a per-fold
degradation table with:

```text
fold_seq
train_window
test_window
selected_candidate
selection_metric
train_metric_value
test_metric_value
metric_diff_abs
metric_diff_pct
warning_flags
```

Train and test metric values must be on the same metric scale. The print method
may visually compress this table, but it must render the degradation table
before secondary surfaces.

Secondary surfaces may include parameter paths, selected test run IDs, compact
equity strips, or session metadata. They must not precede or dominate the
degradation table.

When any test window is shorter than 90 calendar days, the print method sets a
`short_test_window` flag for affected rows and emits a one-line health warning.
When `opening_state_policy = "flat_test_state"` is used, every affected row
sets `cold_start_distorted`.

Programmatic access to the degradation table must be available even when the
visual print is compressed.

---

## 11. Promotion

v0.1.9.4 does not add `ledgr_promote_walk_forward()`.

The accepted path is:

```text
ledgr_walk_forward_extract_candidate()
  -> ledgr_promote()
```

The extracted candidate carries:

- params and feature params;
- execution seed;
- candidate key;
- selected fold sequence;
- selected train metric and test metric;
- `session_id`, `fold_id`, and `test_run_id`;
- cost and risk identity;
- `selection_rationale` when `fold_seq = "latest"`.

Promotion respects the extracted candidate's cost and risk identity even when
the target experiment passes different cost or risk objects. The candidate's
cost and risk identity win; the target experiment's other surfaces, including
strategy, features, metric context, and opening state, are honored as supplied.

Parameter-path promotion and selection-rule promotion are future RFCs.

---

## 12. Section 17 Packet-Open Gates

The ticket cut must include acceptance criteria for every row below. Spec review
fails if the later tickets omit any row without a maintainer override and
named carry-forward target.

| Gate | Packet-open binding |
| --- | --- |
| Train-fold scoring correction | Tickets name rolling and anchored parity tests asserting `fold_train_sweep(fold_n) == ledgr_sweep(window = c(train_start_utc, train_end_utc))` over the full stored train window. |
| `carry_test_state` default and `flat_test_state` opt-in | Tickets name the default constant, the opt-in argument, `ledgr_walk_forward_cold_start_warning`, carry-state behavior tests, and the `cold_start_distorted` print flag. |
| Fail-closed metric classification | Tickets name the metric-classification substrate and `ledgr_walk_forward_metric_class_invalid`; tests include a level metric (`total_return`) and count metric (`n_trades`). |
| No-default extraction and rationale arg | Tickets name `selection_rationale`, required `fold_seq`, the `"latest"` sentinel, and `ledgr_walk_forward_latest_without_rationale`. |
| Operational print contract | Tickets name all degradation-table fields, same-scale train/test metric rule, `short_test_window` warning flag, and default print ordering tests. |
| Feature-windowing determinism | Tickets name feature-windowing determinism and cross-fold train-score stability tests as release blockers. |
| Survivorship-bias vignette sentence | Tickets name the walk-forward vignette and require this sentence or a maintainer-approved equivalent: "Walk-forward evidence is only as survivorship-safe as the sealed snapshot and universe semantics it evaluates." |
| Compute-scaling and path-dependency caveats | Tickets name the walk-forward design doc or vignette location where anchored-fold compute scaling and `carry_test_state` path dependency are recorded. |

---

## 13. Tests And Release Gates

Minimum release-blocking test families:

- fold constructor validation and deterministic `fold_id` / `fold_list_hash`;
- rolling and anchored direct-window parity for train sweeps;
- direct-window parity for selected test runs;
- slice-aware precomputed feature validation with hydration/scoring separation;
- feature-windowing determinism and cross-fold train-score stability;
- selection rule missing metric, invalid metric class, no finite candidates,
  tie break, and deterministic hash behavior;
- `carry_test_state` default and `flat_test_state` warning/flag behavior;
- deterministic `candidate_key` and `session_id`, including `cost_model_hash`
  and `risk_chain_hash`;
- failure capture for train candidate failure, no selection, test-run failure,
  and user interrupt;
- extraction failure when `fold_seq` is missing or `"latest"` lacks rationale;
- promotion-ready extracted candidate provenance;
- print/degradation-table field presence, same-scale metric behavior, warning
  flags, and print ordering;
- persistence/reopen parity for sessions, folds, scores, and linked test runs;
- deterministic-session replay proving the same inputs reproduce `session_id`,
  ordered `fold_id`s, selected candidates per fold, per-row seeds, and selected
  test-run results;
- no walk-forward-specific pulse loop or second execution engine, enforced by
  run/sweep parity tests plus a structural code-search guard that rejects
  walk-forward-specific pulse-loop logic in the fold-core implementation.

The release gate must run the standard package checks, targeted walk-forward
tests, documentation checks, and the release playbook diff-size sanity checks.

---

## 14. Documentation

v0.1.9.4 documentation scope is deliberately narrow:

- NEWS entry naming walk-forward MVP scope and explicit non-scope;
- help pages for fold constructors, selection rules, walk-forward execution,
  inspection helpers, and extraction helper;
- a walk-forward vignette or article teaching the procedural shape:

```text
train sweep -> scalar selection -> test run -> explicit candidate extraction
```

The vignette must state:

- reproducibility and selection integrity are orthogonal;
- walk-forward evidence is not PBO/CSCV/DSR;
- scalar v1 score rows do not support every future diagnostic;
- anchored folds can scale super-linearly because each train window expands;
- under `carry_test_state`, per-fold test metrics are path-dependent and not
  statistically independent;
- walk-forward evidence is only as survivorship-safe as the sealed snapshot
  and universe semantics it evaluates.

Broader user-facing teaching, contract restructuring, identity-reference v2,
and maintainer manual synthesis are deferred to v0.1.9.5.

---

## 15. Explicit Deferrals

Deferred to named future work:

- **Selection-integrity diagnostics:** PBO, CSCV, CPCV, DSR, Holm/BH,
  Harvey-Liu-Zhu thresholds, MinTRL, and effective trial-count diagnostics.
- **Diagnostic retention tiers:** return-series retention by fold/path,
  sufficient statistics, cost detail tables, path IDs, and partition IDs.
- **Selection-session archive / evaluation registry:** an optional index over
  saved sweeps, walk-forward sessions, and promotion lineage.
- **Candidate clustering:** post-sweep or post-walk-forward clustering over
  retained return streams.
- **Purged and embargoed folds:** non-NULL gap semantics and label-overlap
  logic.
- **CPCV and randomized/blocked protocols:** combinatorial path generation and
  blocked slice semantics.
- **Trading-time and state-aware folds:** market-calendar, trading-day-count,
  intraday-session, regime-aware, or state-triggered fold definitions.
- **Cross-snapshot walk-forward:** coordinated with snapshot lineage.
- **Selection-rule DSL:** composite multi-metric, plateau/stability-region, and
  robust top-N selectors.
- **Promotion extensions:** parameter-path promotion and selection-rule
  promotion.
- **ML-first support:** model artifact identity, train/predict strategy
  wrappers, prediction-table provenance, and PIT leakage instrumentation.
- **OMS and paper/live walk-forward:** future OMS event streams and retraining
  schedules.

---

## 16. Spec-Cut Decisions

This spec resolves the RFC Section 11 questions as follows:

1. `opening_state_policy = "carry_test_state"` is the default;
   `"flat_test_state"` is an explicit opt-in with warning and print flag.
2. Telemetry is limited to session, fold, candidate count, selected candidate,
   status, and timing metadata at setup/fold/session boundaries. No per-pulse
   telemetry is added.
3. V1 is restart-only, not resumable partial sessions.
4. Terminal statuses are `DONE`, `FAILED`, `INTERRUPTED`, and `PARTIAL`.
5. Scores use the pair `window` plus `metric_name`; train and test rows share
   metric names where they are on the same scale.
6. Calendar-time constructors align supplied timestamps to snapshot pulses and
   fail closed for empty or undersized scoring windows; market-calendar
   adjustment is deferred.
7. `ledgr_walk_forward_extract_candidate()` requires `fold_seq`; `"latest"` is
   an explicit sentinel requiring `selection_rationale`.
8. Top-N and all-candidate test retention are deferred.
9. Cross-session comparison is deferred.
10. Default print is led by the degradation table named in Section 10.

Changing these decisions after ticket cut requires a maintainer amendment or a
follow-up RFC, depending on blast radius.

---

## 17. Acceptance

v0.1.9.4 is accepted only when:

1. the ticket packet includes every Section 17 gate-row acceptance criterion;
2. `ledgr_walk_forward()` is implemented as a wrapper over run/sweep windows,
   not a new pulse loop;
3. rolling and anchored parity tests pass;
4. cost identity, sweep infrastructure, and risk-chain identity are consumed
   in walk-forward candidate/session identity;
5. the default print and programmatic degradation table make train-vs-test
   degradation visible before secondary surfaces;
6. docs state the survivorship, compute-scaling, path-dependency, and
   selection-integrity caveats;
7. release-gate checks pass under the repository release playbook.

Until those are true, v0.1.9.4 remains an open implementation packet.
