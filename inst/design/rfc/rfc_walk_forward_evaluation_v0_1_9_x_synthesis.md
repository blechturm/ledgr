# RFC Synthesis: Walk-Forward Evaluation For ledgr

**Status:** Accepted synthesis - binding for the v0.1.9.x walk-forward ticket cut.
**Date:** 2026-05-27
**Source RFC v1:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed.md`
**Source RFC v2:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed_v2.md`
**Reviewer response:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_response.md`
**Predecessors:** `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`, `inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`, `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
**Roadmap anchor:** `inst/design/ledgr_roadmap.md` (walk-forward at v0.1.9.x, after target risk and before OMS/paper-live work)

**Process note:** This synthesis incorporates the v1 seed, Codex response,
maintainer review of that response, and revised v2 seed. It does not edit
earlier artifacts.

---

## 1. Decision Summary

Walk-forward evaluation is accepted as the v0.1.9.x design direction for
selection-aware research evidence. It extends the v0.1.8 sweep workflow without
changing strategy semantics:

```text
sealed snapshot
  -> fold definitions
  -> per-fold train sweep
  -> deterministic selection rule
  -> per-fold test run
  -> scalar score matrix and fold artifacts
```

The strategy contract remains:

```text
strategy: function(ctx, params) -> full named numeric target vector
```

The fold core does not split. Walk-forward is a wrapper over `ledgr_sweep()` and
`ledgr_run()`, but it requires a shared experiment-window contract across run,
sweep, precompute, and precomputed-feature validation.

Accepted v1 scope:

- rolling and anchored folds;
- calendar-time fold boundaries;
- one sealed snapshot windowed by fold config;
- classed ledgr selection rules only;
- scalar score matrix as default evidence;
- read-only inspection helpers;
- extraction of an explicit candidate for ordinary `ledgr_promote()`.

Deferred:

- PBO/CSCV/CPCV/DSR diagnostic implementation;
- richer diagnostic retention tiers;
- purging and embargoes;
- trading-time, state-based, and regime-aware folds;
- cross-snapshot walk-forward;
- walk-forward inside sweeps;
- paper/live walk-forward and OMS event streams;
- composite multi-metric selection rules;
- survivorship-aware universe construction.

---

## 2. Roadmap Sequencing

Bound sequencing:

```text
v0.1.8.5          canonical research workflow and teachability
v0.1.8.6          feature-storage / out-of-core measurement spike
v0.1.8.7          parallel sweep dispatch
v0.1.9            target-risk chain
v0.1.9.x          walk-forward evaluation
v0.1.9.x          selection-integrity diagnostics after walk-forward
v0.1.9.x/v0.2.0   public transaction-cost model API
v0.2.x            OMS semantics, PIT data, snapshot lineage, related data work
v0.3.0+           paper/live adapters
```

This synthesis does not authorize walk-forward before the v0.1.9 target-risk
chain lands. It does not authorize OMS, paper/live, public cost/liquidity work,
or selection-integrity diagnostics. The OMS synthesis remains v0.2.x planning
and records walk-forward interaction as a later obligation.

---

## 3. Accepted Architecture

### Wrapper, Not Engine

The v1 execution shape is:

```text
ledgr_walk_forward()
  -> for each fold:
       -> ledgr_sweep() on train scoring window
       -> selection_rule(train score rows) -> candidate_key
       -> ledgr_run() on test scoring window with selected params
  -> write session, fold, and score artifacts
```

`R/fold-core.R` must not gain a walk-forward-specific pulse loop. Pulse
causality, target validation, target risk after v0.1.9, fill timing, cost
resolution, and ledger writing remain shared run/sweep semantics.

### Experiment-Window Contract

V1 must establish one shared window contract for run, sweep, and precompute.
The contract carries:

```text
hydration_start
scoring_start
scoring_end
execution_start
opening_state_policy
```

The internal helper may be:

```r
ledgr_experiment_window(exp, start_utc, end_utc)
```

The helper is internal in v1. Public date-window experiments are deferred until
the shared contract is stable.

Ticket-cut must prove:

```text
fold train sweep == direct windowed ledgr_sweep()
fold test run    == direct windowed ledgr_run()
```

with identical snapshot, params, feature_params, metric context, risk chain
when present, and seed.

### Procedural Honesty

`ledgr_walk_forward()` enforces:

```text
1. evaluate all candidates on train window only;
2. select using train-window scalar scores only;
3. run exactly the selected candidate on the next test window;
4. record the test result as fold OOS evidence.
```

The walk-forward API must not accept a precomputed full-snapshot sweep result
as fold-local selection input. It must not accept a preselected candidate and
then report fold tests as if selection happened fold-locally.

`ledgr_sweep()` remains an exploratory full-snapshot API. The procedural rule
constrains walk-forward, not the whole package.

Walk-forward evidence is selection-aware exploration, not statistical
validation. Multiplicity correction and selection-integrity diagnostics remain
downstream tier work.

### Single Snapshot

V1 walk-forward is one sealed snapshot plus date windows. Fold definitions are
configuration layered over snapshot identity. Cross-snapshot walk-forward is
deferred to snapshot-lineage work.

### Calendar-Time Folds

V1 fold boundaries are calendar-time timestamps. Trading-day-count,
market-calendar-aware, and state-aware fold definitions are deferred.

### Hydration, Scoring, Execution, Opening

Each fold distinguishes hydration, scoring, execution, and opening-state
dimensions. V1 binds these defaults:

```text
train fold:
  hydration_start = snapshot_start
  scoring_start   = previous train scoring_end, or snapshot_start for first fold
  scoring_end     = train_window_end
  execution_start = scoring_start

test fold:
  hydration_start = snapshot_start
  scoring_start   = test_window_start
  scoring_end     = test_window_end
  execution_start = scoring_start
```

Indicator warmup may use bars between `hydration_start` and `execution_start`,
but those bars are not scored and are not visible as pre-window strategy
pulses. Existing `LEDGR_LAST_BAR_NO_FILL` semantics apply at `scoring_end`.

`opening_state_policy` is explicit session/fold metadata, not hidden behavior.
The exact v1 policy and default are spec-cut decisions before ticket
implementation. In v1, the policy is chosen at the session level and recorded
on each fold. Carrying positions from prior folds is not implicit, and per-fold
policy variation is future work.

### Selection Rules

V1 ships ledgr-owned classed rules:

```r
ledgr_select_argmax(metric)
ledgr_select_argmin(metric)
```

The binding contract:

1. Rules see only train-window rows for the current fold.
2. Rules declare one required metric.
3. Missing metric raises `ledgr_walk_forward_metric_missing`.
4. `NA`, `NaN`, and infinite values are dropped from eligibility.
5. If no finite candidates remain, raise `ledgr_walk_forward_no_selection`.
6. Metric ties break by ascending `candidate_key`.
7. Rule class and arguments participate in `session_id`.

Composite selection, stability-region selection, and top-N robust selection are
future DSL work.

### Public Surface

V1 public surface:

```r
ledgr_fold(...)
ledgr_folds_rolling(...)
ledgr_folds_anchored(...)
ledgr_select_argmax(metric)
ledgr_select_argmin(metric)
ledgr_walk_forward(exp, grid, folds, selection_rule, seed = NULL, ...)
ledgr_walk_forward_results(session_id)
ledgr_walk_forward_scores(session_id)
ledgr_walk_forward_folds(session_id)
ledgr_walk_forward_extract_candidate(session_id, fold_seq = "latest")
```

Inspection helpers are read-only. They do not mutate, recompute, or re-execute.

---

## 4. Data Model Decisions

`ledgr_fold()` returns an immutable value object. Required logical fields:

```text
fold_id, fold_seq, scheme, train_start_utc, train_end_utc,
test_start_utc, test_end_utc, gap_value, gap_unit
```

`gap = NULL` is the v1 binding. Non-NULL gap semantics are reserved for the
purged/embargoed folds RFC.

`walk_forward_sessions` logical fields:

```text
session_id, snapshot_hash, experiment_hash, param_grid_hash,
fold_list_hash, selection_rule_hash, metric_context_hash,
risk_chain_hash, master_seed, opening_state_policy,
created_at_utc, ledgr_version, meta_json
```

`walk_forward_folds` logical fields:

```text
session_id, fold_id, fold_seq, scheme,
train_start_utc, train_end_utc, test_start_utc, test_end_utc,
hydration_start_utc, train_scoring_start_utc, test_scoring_start_utc,
opening_state_policy, selected_candidate_key, selected_at_utc,
test_run_id, status
```

`walk_forward_scores` logical fields:

```text
session_id, fold_id, fold_seq,
candidate_key, candidate_label,
params_hash, feature_params_hash, feature_set_hash, alias_map_hash,
metric_context_hash, risk_chain_hash,
window, metric_name, metric_value, n_trades,
status, error_class, error_msg, execution_seed
```

`candidate_key` is identity. `candidate_label` is optional display metadata but
must be present as a nullable column. Train rows exist for all train candidates
or candidate failures. Test rows exist only for the selected candidate in v1.

`execution_seed` means:

- train rows: seed used for that candidate's train-window sweep execution;
- test rows: seed used for the selected candidate's test-window run;
- unseeded sessions: `NA_integer_`;
- non-selected candidates: no test rows in v1.

The v1 score matrix is sufficient for fold/candidate inspection, train/test
ranking, selected-candidate OOS review, scalar-metric PBO approximation, and a
CRAN `pbo`-compatible pivot helper. It is not sufficient for DSR, CPCV,
nonlinear metric recomputation, or per-candidate equity reconstruction.

Future retention tiers may add return payloads, equity payload references,
sufficient statistics, partition IDs, and path IDs. V1 must not preclude those,
but it does not bind their schema.

---

## 5. Lifecycle And Execution Decisions

For each fold:

```text
1. Build train experiment window.
2. Run ledgr_sweep() on train window.
3. Write train score rows for all candidates.
4. Apply selection rule to train rows only.
5. Build test experiment window.
6. Run ledgr_run() on test window with selected params and feature_params.
7. Write test run to ordinary run tables.
8. Write selected-candidate test score rows.
9. Mark fold status and selected_candidate_key.
```

The fold test run is an ordinary `ledgr_run()` artifact linked through
`test_run_id`. Walk-forward creates no new accounting tables.

Candidate train failures become score rows with `status = 'failed'`,
`error_class`, and `error_msg`. Selection uses surviving finite candidates. If
none remain, the fold fails with `ledgr_walk_forward_no_selection`. Test-run
failure marks the fold failed and preserves train rows.

V1 research mode writes ordinary run artifacts plus walk-forward artifacts. It
does not write `order_events`, `target_decisions`, or OMS lifecycle artifacts.

V1 does not add `ledgr_promote_walk_forward()`. The accepted path is:

```text
walk-forward inspection
  -> ledgr_walk_forward_extract_candidate(...)
  -> ledgr_promote(exp, candidate, run_id, note = ...)
```

The candidate object must carry params, feature_params, execution seed,
candidate_key, and walk-forward provenance. The promotion note should name the
`session_id` and human rationale. Parameter-path promotion and selection-rule
promotion are future RFCs.

---

## 6. Mode And Retention Decisions

V1 mode is research-only. Default retention is scalar: session metadata, fold
metadata, scalar score rows, and selected-candidate test runs. V1 does not
retain all-candidate test runs, per-candidate train equity curves,
per-candidate return series, sufficient-stat payloads, or CPCV path payloads by
default.

Top-N test retention and diagnostic retention tiers are future decisions. The
scalar default is a scope boundary, not a claim that scalar rows satisfy every
future diagnostic.

---

## 7. Identity, Provenance, And Replay

`fold_id` is deterministic from canonical JSON of:

```text
scheme, train_start_utc, train_end_utc, test_start_utc, test_end_utc,
gap_value, gap_unit, fold_seq, fold_schema_version
```

`fold_list_hash` is deterministic from the ordered vector of `fold_id`s plus
fold-list schema version and constructor metadata.

`candidate_key` is deterministic from canonical JSON of:

```text
params_hash, feature_params_hash, strategy_hash, feature_set_hash,
alias_map_hash, metric_context_hash, risk_chain_hash,
execution_seed, candidate_schema_version
```

It excludes `run_id`, row order, grid label, and current `sweep_id`.

`session_id` is deterministic from canonical JSON of:

```text
snapshot_hash, experiment_hash, param_grid_hash, fold_list_hash,
selection_rule_hash, metric_context_hash, risk_chain_hash,
master_seed, opening_state_policy, walk_forward_schema_version,
ledgr_version
```

Initial schema-version literals are `"v1"` for `fold_schema_version`,
`candidate_schema_version`, and `walk_forward_schema_version` unless the
v0.1.9.x spec deliberately changes them before implementation.

After v0.1.9, walk-forward must consume the risk identity defined by the
target-risk spec. It must not redesign risk identity. Replay must reconstruct
the same `session_id`, ordered `fold_id`s, `candidate_key`s, per-row seeds,
selected candidate per fold, and test-run results.

---

## 8. Implementation Constraints

The v0.1.9.x spec packet must include:

- experiment-window contract implementation across run, sweep, precompute, and
  precomputed-feature validation;
- run/sweep parity tests over identical fold windows;
- no fold-core-specific walk-forward pulse loop;
- a canonical `metric_context_hash` utility available before walk-forward
  consumes metric identity; walk-forward must use the shared utility, not a
  local hash implementation;
- worker-safe selection-rule and risk-plan value objects with no live DB
  connections, external pointers, mutable environments, or active bindings;
- batched writes at fold/session boundaries;
- no per-pulse DB writes in the walk-forward hot path;
- classed failures for missing metrics, no eligible selection, failed folds,
  interrupted sessions, and invalid fold windows;
- documentation that scalar scores are v1 evidence, not full
  selection-integrity diagnostics.

The precomputed-feature contract is load-bearing: if a fold window is used, the
payload must validate against that fold's requested scoring range and hydration
semantics.

---

## 9. Explicit Deferrals

Deferred to named future work:

- **Selection-integrity diagnostics RFC:** PBO/CSCV/CPCV scoring, DSR, Holm/BH,
  Harvey-Liu-Zhu thresholds, MinTRL.
- **Diagnostic retention tiers RFC:** return series, equity payload references,
  sufficient statistics, partition/path identity.
- **Purged and embargoed folds RFC:** non-NULL gap semantics and
  label-interval-aware purge logic.
- **CPCV RFC:** combinatorial path generation and pathwise scoring.
- **Trading-time/state-fold RFC:** market-calendar, trading-day-count, and
  regime-aware fold definitions.
- **Cross-snapshot walk-forward RFC:** coordinated with snapshot lineage.
- **OMS interaction RFC:** per-fold OMS event streams before paper/live
  walk-forward.
- **Paper/live walk-forward RFC:** v0.3.0+.
- **Selection-rule DSL RFC:** composite multi-metric and stability-region
  selection.
- **Survivorship-aware universe RFC:** coordinated with PIT data and instrument
  master work.

---

## 10. v0.1.9.x Minimum Scope

The first walk-forward ticket packet should include:

1. `ledgr_fold()`, rolling folds, anchored folds, and deterministic fold IDs.
2. Deterministic `fold_list_hash`.
3. Internal `ledgr_experiment_window()` and shared window contract.
4. Windowed `ledgr_run()` and `ledgr_sweep()` behavior with parity tests.
5. Window-aware `ledgr_precompute_features()` validation through sweep.
6. `ledgr_select_argmax()` and `ledgr_select_argmin()`.
7. `walk_forward_sessions`, `walk_forward_folds`, and `walk_forward_scores`.
8. `ledgr_walk_forward()` orchestrator.
9. Batched session/fold output handler.
10. Read-only inspection helpers and candidate extraction helper.
11. Determinism, identity-exclusion, hydration/scoring, failure, and selection-rule tests.
12. Tibble pivot helper or documented shape for CRAN `pbo` compatibility.
13. Walk-forward vignette and workflow forward-link.
14. NEWS, roadmap, and design index updates.

---

## 11. Open Questions Promoted To Spec-Cut

These must be resolved before ticket implementation:

1. Exact `opening_state_policy` values and default. The policy is explicit
   metadata; no hidden hardcoded behavior is allowed.
2. Telemetry budget for fold/candidate counts, including an overhead bound.
3. Restart-only versus resumable partial sessions.
4. Terminal session-status rules for `done`, `failed`, `partial`,
   `interrupted`.
5. Train/test metric naming convention: same `metric_name` plus `window`, or
   distinct names.
6. Exact calendar-time constructor spelling and behavior around weekends,
   holidays, and missing bars.
7. `ledgr_walk_forward_extract_candidate()` default behavior. `"latest"` is
   allowed; "most stable" requires future stability semantics.
8. Whether top-N or all-candidate test retention is admitted in v1 as opt-in,
   or deferred entirely to diagnostic retention.
9. Cross-session comparison surface, if any.
10. Reporting defaults for `print(walk_forward_results)`: per-fold equity
    strip, train-vs-test score view, parameter path, single-best-candidate
    equity, or another compact default. Defaults must expose honesty signals
    without visual noise.

Future-RFC questions, not spec-cut blockers:

- parameter-path promotion and selection-rule promotion;
- richer diagnostic retention tiers;
- per-fold universe restriction;
- public `ledgr_experiment_window()`;
- walk-forward inside sweep composition.

---

## 12. Future Obligations Recorded

Future RFCs must honor these obligations:

- Diagnostic RFCs must not assume scalar rows can recover DSR, CPCV, or
  nonlinear recomputation inputs.
- Purging/embargo work must include explicit tests for label-interval overlap.
- Paper/live walk-forward must revisit OMS streams and target-decision
  persistence per the OMS synthesis.
- Target-risk follow-up must make risk-chain identity available for
  walk-forward session and candidate keys.
- Parallel dispatch must use worker-safe fold/session plans and avoid shared
  mutable state.
- Snapshot-lineage work must revisit cross-snapshot fold identity.
- PIT/universe work must revisit survivorship-aware per-fold universes.

---

## 13. Acceptance

This synthesis is accepted as binding for the v0.1.9.x walk-forward ticket cut.
It does not modify the v0.1.9 target-risk synthesis, the v0.2.x OMS synthesis,
or the v0.1.8 sweep-promotion synthesis.

Spec-cut writers may resolve the open questions listed in Section 11 without a
new RFC. Changing a bound decision in Sections 1-10 requires a follow-up RFC or
explicit maintainer amendment.
