# RFC Synthesis: Walk-Forward Evaluation For ledgr

**Status:** Accepted synthesis with Amendment 1 and Amendment 2 (both 2026-06-04), gated by Section 17 ticket-cut matrix - binding for the v0.1.9.x walk-forward ticket cut.
**Date:** 2026-05-27
**Source RFC v1:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed.md`
**Source RFC v2:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed_v2.md`
**Reviewer response:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_response.md`
**Final review:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_final_review.md`
**Amendment 1:** 2026-06-04 - see Section 14 (corrects Section 3 train-fold scoring; binds procedural constraints on Section 11 Q1/Q5/Q7/Q10; augments Section 10 items 11 and 13 and Section 12). Sections 14.2 and 14.3 superseded in part by Amendment 2.
**Amendment 2:** 2026-06-04 - see Section 16 (adds Section 14.1 trace verification; replaces Amendment 1 Sections 14.2 and 14.3 with substantive defaults for Q1/Q5/Q7/Q10; adds Section 12 path-dependency obligation). See Section 17 for ticket-cut gates.
**Ticket-cut gates:** See Section 17.
**Predecessors:** `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`, `inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`, `inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md`
**Roadmap anchor:** `inst/design/ledgr_roadmap.md` (walk-forward at v0.1.9.x, after target risk and before OMS/paper-live work)

**Process note:** This synthesis incorporates the v1 seed, Codex response,
maintainer review of that response, and revised v2 seed. It does not edit
earlier artifacts. Amendment 1 (Section 14) routes final-review findings
without opening a new RFC chain, as authorized by Section 13. Amendment 2
(Section 16) and the Section 17 ticket-cut gate matrix were added after a
post-Amendment-1 review identified that four of the seven Amendment 1
routings were procedural rather than substantive and that no ticket-cut
enforcement mechanism gated the obligations.

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
train fold (corrected by Amendment 1 Section 14.1):
  hydration_start = snapshot_start
  scoring_start   = train_start_utc
  scoring_end     = train_end_utc
  execution_start = scoring_start

test fold:
  hydration_start = snapshot_start
  scoring_start   = test_window_start
  scoring_end     = test_window_end
  execution_start = scoring_start
```

> **Amendment 1 note (2026-06-04):** the train-fold block above shows the
> corrected binding. The original v2-bound text described
> `scoring_start = previous train scoring_end, or snapshot_start for first
> fold` and `scoring_end = train_window_end`, which described an incremental
> non-overlapping slice that matched neither rolling nor anchored. See
> Section 14.1 for the rationale.

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
11. Determinism, identity-exclusion, hydration/scoring, failure, and selection-rule tests. (As augmented by Amendment 1 Section 14.4: add feature-windowing determinism and cross-fold train-score stability tests.)
12. Tibble pivot helper or documented shape for CRAN `pbo` compatibility.
13. Walk-forward vignette and workflow forward-link. (As augmented by Amendment 1 Section 14.4: vignette must include a bound sentence on survivorship-bias conditionality.)
14. NEWS, roadmap, and design index updates.

---

## 11. Open Questions Promoted To Spec-Cut

These must be resolved before ticket implementation:

1. Exact `opening_state_policy` values and default. The policy is explicit
   metadata; no hidden hardcoded behavior is allowed. (Bound by Amendment 2
   Section 16.2: v1 default is `carry_test_state`; `flat_test_state` is an
   explicit opt-in only and requires `ledgr_walk_forward_cold_start_warning`
   plus `cold_start_distorted` flag in the print method. Train sweeps always
   start from the experiment opening state. Spec-cut may only resolve the
   exact value names and the opt-in mechanism, not the default.)
2. Telemetry budget for fold/candidate counts, including an overhead bound.
3. Restart-only versus resumable partial sessions.
4. Terminal session-status rules for `done`, `failed`, `partial`,
   `interrupted`.
5. Train/test metric naming convention: same `metric_name` plus `window`, or
   distinct names. (Bound by Amendment 2 Section 16.3: selection rules fail
   closed with `ledgr_walk_forward_metric_class_invalid` for any metric not
   classified as `rate`, `annualized`, `ratio`, or `length_invariant` in its
   registration. The metric registry must carry a classification field. Level
   metrics including `total_return`, `final_equity`, `max_drawdown_depth`,
   `n_trades`, `trade_count`, and raw P&L are explicitly forbidden as
   selection inputs in v1. Spec-cut may only resolve the column-naming
   convention.)
6. Exact calendar-time constructor spelling and behavior around weekends,
   holidays, and missing bars.
7. `ledgr_walk_forward_extract_candidate()` default behavior. `"latest"` is
   allowed; "most stable" requires future stability semantics. (Bound by
   Amendment 2 Section 16.4: `fold_seq` has no default. The caller must pass
   an integer or the explicit sentinel `"latest"`. When `"latest"` is used,
   a non-empty `selection_rationale` is required and is captured in the
   extracted candidate's provenance; failure to provide one raises
   `ledgr_walk_forward_latest_without_rationale`. Spec-cut may only resolve
   the sentinel spelling and the rationale-arg surface.)
8. Whether top-N or all-candidate test retention is admitted in v1 as opt-in,
   or deferred entirely to diagnostic retention.
9. Cross-session comparison surface, if any.
10. Reporting defaults for `print(walk_forward_results)`: per-fold equity
    strip, train-vs-test score view, parameter path, single-best-candidate
    equity, or another compact default. Defaults must expose honesty signals
    without visual noise. (Bound by Amendment 2 Section 16.5: the data
    backing the print method must include a per-fold degradation table with
    fields `fold_seq`, `train_window`, `test_window`, `selected_candidate`,
    `selection_metric`, `train_metric_value`, `test_metric_value`,
    `metric_diff_abs`, `metric_diff_pct`, and `warning_flags` -- train and
    test values on the same scale, degradation table preceding any secondary
    surface in render order, short-test-window and cold-start-distorted
    flags surfaced per row. Spec-cut may choose visual compression but
    cannot drop fields or reorder the degradation table behind equity
    strips.)

Future-RFC questions, not spec-cut blockers:

- parameter-path promotion and selection-rule promotion;
- richer diagnostic retention tiers;
- per-fold universe restriction;
- public `ledgr_experiment_window()`;
- walk-forward inside sweep composition.

---

## 12. Future Obligations Recorded

Future RFCs must honor these obligations. See also Amendment 1 Section 14.5
(compute-scaling caveat) and Amendment 2 Section 16.6 (path-dependency
obligation), which add to this list.



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

---

## 14. Amendment 1 (Final Review)

**Date:** 2026-06-04
**Source:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_final_review.md`
**Authority:** Maintainer amendment per Section 13. Does not open new design space.

The final review surfaced one correctness bug in bound text, two validity-gate
constraints on currently-open spec-cut questions, one Section 10 disclosure
obligation, two Section 10 test-list additions, and one Section 12 caveat.
Each finding's resolution is bound below.

### 14.1 Correction to Section 3 train fold scoring (Finding #1)

The Section 3 binding for train-fold scoring is replaced. The original text
described scoring on the increment between successive `train_window_end`
values, which is incoherent for both rolling (a fixed-width 1yr window would
be scored on a 3mo slice for fold N>1) and anchored (an expanding window
would be scored on only the incremental delta). The stored `train_start_utc`
/ `train_end_utc` in `walk_forward_folds` describe the fold's full train
window; the scoring window must match.

The corrected train-fold binding:

```text
train fold:
  hydration_start = snapshot_start
  scoring_start   = train_start_utc
  scoring_end     = train_end_utc
  execution_start = scoring_start
```

This restores coherence with rolling (every fold scores its fixed-width train
window) and anchored (every fold scores its expanding train window). It also
restores a stable referent for the Section 3 parity gate: "fold train sweep
== direct windowed `ledgr_sweep()`" now refers to the same window on both
sides.

Overlap across folds for rolling is accepted as the natural consequence.
Aggregate non-overlapping train views, if needed, must be derived from the
score matrix at inspection time rather than by redefining the per-fold
scoring range.

The test-fold binding in Section 3 is unchanged.

### 14.2 Validity constraints on Section 11 Q1 and Q5 (Finding #2)

Section 11 Q1 (opening_state_policy values and default) and Q5 (train/test
metric naming convention) remain open for spec-cut. The following constraints
bind on whatever the spec-cut writer chooses:

**On Q1 (opening_state_policy).** The chosen policy and default must be
evaluated for systematic cold-start distortion of test-fold metrics. A
flat-start default (test folds begin with cash and flat positions) requires
the spec-cut to explicitly justify the choice and document the bias direction
it introduces; carrying-account policies (test fold starts from previous test
fold's terminal state) are equally acceptable provided the spec-cut writer
characterizes the trade-off. Parity tests are not sufficient to settle
validity; the spec-cut must address the bias question directly.

**On Q5 (metric naming).** Selection metrics (those that feed
`ledgr_select_argmax()` / `ledgr_select_argmin()`) must be rate or annualized
metrics -- Sharpe, annualized return, annualized drawdown, hit rate,
win-loss ratio, or equivalent length-invariant quantities. Level metrics
(total return, max drawdown depth, trade count) may exist in the score
matrix as additional columns but must not be the basis of selection unless
the spec-cut writer explicitly justifies length-invariant behavior. The
default print method bound by Section 11 Q10 must include a health-warning
when any test window is shorter than approximately one quarter (90 calendar
days as a v1 heuristic).

### 14.3 Validity constraints on Section 11 Q7 and Q10 (Finding #3)

Section 11 Q7 (extract_candidate default behavior) and Q10 (reporting
defaults for `print(walk_forward_results)`) remain open for spec-cut. The
following constraints bind:

**On Q7 (extract_candidate default).** If `"latest"` is retained as the
default for `ledgr_walk_forward_extract_candidate()`, the print method bound
by Q10 must make per-fold train-vs-test degradation visually unavoidable.
If the print method cannot meet that bar, `"latest"` must be dropped as a
default and `fold_seq` made an explicit argument with no default --
forcing the caller to record an explicit rationale at extraction time,
consistent with the package's existing treatment of promotion notes.

**On Q10 (default print).** The default `print(walk_forward_results)` must
expose train-vs-test degradation as a primary visual signal. Per-fold equity
strips, parameter paths, and single-best-candidate equity curves may appear
as secondary surfaces but must not be the primary teaching shape. The
default print is the package's teaching surface for the honesty thesis;
the design choice cannot postpone the responsibility.

### 14.4 Section 10 Minimum Scope augmentations (Findings #4 and #5a/b)

Section 10 item 11 is augmented to read:

> Determinism, identity-exclusion, hydration/scoring,
> **feature-windowing-determinism (a feature value at bar `t` must be
> identical whether the run starts at `hydration_start` or
> `snapshot_start`), cross-fold train-score stability (two fold definitions
> with the same train window must yield identical train scores),** failure,
> and selection-rule tests.

Section 10 item 13 is augmented to read:

> Walk-forward vignette **(must include a bound sentence on
> survivorship-bias conditionality: walk-forward OOS honesty is conditional
> on point-in-time-correct universe construction, which v1 does not
> provide)** and workflow forward-link.

### 14.5 Section 12 Future Obligations augmentation (Finding #5c)

Section 12 receives a new bullet:

> Compute-scaling caveat: rolling-overlap (~75% overlap at train = 1yr /
> step = 3mo) re-backtests each (candidate, bar) pair across roughly four
> consecutive folds; anchored-expanding train sweeps re-backtest each
> (candidate, bar) pair across every fold whose train window covers the
> bar (super-linear in fold count). Per-(candidate, bar) memoization is
> foreclosed by v1's "just call `ledgr_sweep()` per fold" architecture.
> This is an accepted trade-off for v1 simplicity, recorded so the
> no-cloud deployment target treats it as a known surface rather than a
> surprise at scale. Future RFCs on walk-forward performance may revisit
> memoization if real-world walk-forward costs become a binding
> constraint.

### 14.6 Sections unchanged

Sections 1, 2, 4, 5, 6, 7, 8, 9, 13 are unchanged. The architecture,
deferrals, scope boundaries, identity bindings, mode, retention, and
acceptance posture are unaltered. Amendment 1 closes the cycle by correcting
one bound text error and binding validity constraints plus small documentation
and test obligations onto the synthesis as accepted.

> **Superseded in part by Amendment 2 (Section 16) on 2026-06-04.** A post-Amendment-1
> review surfaced that Section 14.2 (Q1, Q5) and Section 14.3 (Q7, Q10) bound mostly
> procedural constraints ("must justify", "must address", "visually unavoidable") rather
> than substantive defaults, and that no ticket-cut enforcement mechanism gated the
> Amendment 1 obligations. Amendment 2 replaces the Section 14.2 and Section 14.3
> constraint text with substantive defaults and adds Section 17 ticket-cut gates.
> Section 14.1 (train-fold scoring correction), Section 14.4 (Section 10 augmentations),
> and Section 14.5 (Section 12 compute caveat) are unaffected, except that Section 14.1
> gains an explicit trace verification block in Section 16.1.

---

## 15. (Reserved)

This section number is reserved to preserve future amendment numbering. The
walk-forward synthesis skips from Section 14 (Amendment 1) directly to
Section 16 (Amendment 2) because Amendment 2 was authored in the same review
window and supersedes parts of Amendment 1; an empty Section 15 makes the
omission visible in the table of contents rather than silent.

---

## 16. Amendment 2 (Post-Amendment-1 Review)

**Date:** 2026-06-04
**Source:** Post-Amendment-1 review by Claude (online) and Codex review of that
critique. Routed via the same final-review mechanism Amendment 1 used.
**Authority:** Maintainer amendment per Section 13. Does not open new design space.
**Relationship to Amendment 1:** Amendment 2 strengthens Amendment 1 from procedural
constraints on open questions to substantive defaults and operational shapes.
Amendment 1 Sections 14.1, 14.4, and 14.5 stand; Sections 14.2 and 14.3 are
superseded in part by Sections 16.2 through 16.5.

The post-Amendment-1 review observed that Amendment 1 had routed seven findings
to mechanisms but, on closer inspection, four of those routings were procedural
("must be evaluated for cold-start distortion", "must address the bias question
directly", "visually unavoidable") rather than substantive. A ticket-cut writer
could satisfy each constraint with a justification paragraph and ship a default
the original finding was warning against. Amendment 2 replaces those procedural
routings with substantive defaults, operational data contracts, and (in Section
17) ticket-cut enforcement gates.

### 16.1 Trace verification for Section 14.1 train-fold scoring correction

Amendment 1 Section 14.1 bound the corrected train-fold scoring binding but
did not include the worked trace verifying that the original v2 binding was
in fact incoherent. This subsection records the trace.

**Original v2 binding** (seed v2 Section 7.8, line 412):

```text
train fold scoring_start = previous train scoring_end, or snapshot_start for first fold
train fold scoring_end   = train_window_end
```

**Stored fold window definitions** (seed v2 Sections 7.7 and 7.8, line 471, and
the rolling/anchored constructor contracts):

- `ledgr_folds_rolling(train_window = "1 year", step = "3 months")` defines
  each fold's stored window as `train_start_utc = train_end_utc - train_window`,
  i.e. a fixed-width 1yr window per fold.
- `ledgr_folds_anchored(train_window_initial = "1 year", step = "3 months")`
  defines each fold's stored window as `train_start_utc = snapshot_start`,
  `train_end_utc = train_end_utc_prior + step`, i.e. an expanding window per fold.

**Rolling, fold 2 under the original v2 binding.** The fold's stored window is
the 1yr range `[train_end_utc - 1yr, train_end_utc]`. The binding's
`scoring_start = previous train scoring_end = train_end_utc_fold_1`. The binding's
`scoring_end = train_window_end = train_end_utc_fold_2`. The scored range is
the 3-month increment between fold 1's and fold 2's train ends, not the full
1yr stored window. The sweep ranks 50 candidates over 3 months while the
stored window covers 12. The Section 3 parity gate "fold train sweep ==
direct windowed `ledgr_sweep()`" fails: the LHS ranges 3mo, the RHS ranges 1yr.

**Anchored, fold 2 under the original v2 binding.** The fold's stored window
is the expanding range `[snapshot_start, train_end_utc_fold_2]`. The binding's
`scoring_start = previous train scoring_end = train_end_utc_fold_1`, which is
*inside* the stored window by `step` months. The sweep ranks candidates over
only the newly-added increment, not the expanding window the fold definition
asserts. Anchored semantics require comparing candidates over progressively
larger histories; the binding contradicts that semantics.

**Conclusion.** The original v2 binding describes neither rolling nor
anchored. It would describe a non-overlapping incremental scoring scheme,
which is a third scheme v1 does not accept. The Amendment 1 Section 14.1
correction (`scoring_start = train_start_utc`) is the binding consistent with
both fold definitions. Overlap across folds in rolling and super-linear
scaling in anchored are accepted as the natural consequences (the latter is
recorded in Section 14.5).

### 16.2 Substantive default for Section 11 Q1 (supersedes Amendment 1 Section 14.2 Q1)

Amendment 1 Section 14.2 bound the constraint "the chosen policy must be
evaluated for cold-start distortion." This is procedural. Amendment 2 binds
a substantive v1 default.

**v1 default `opening_state_policy = carry_test_state`.** Concretely:

- Fold 1 test fold starts from the experiment opening state (cash, positions,
  and lot state as configured at experiment construction).
- Each later test fold starts from the prior test fold's terminal cash,
  positions, and lot state.
- Train sweeps in every fold always start from the experiment opening state.
  This is unchanged from the carry-test-state policy because train sweeps
  exist to compare candidates within a controlled window; carrying state
  across train sweeps would contaminate candidate comparison.

`flat_test_state` (every test fold starts with cash and flat positions) may
be admitted as an explicit opt-in only. When used, it must:

- Emit a `ledgr_walk_forward_cold_start_warning` at session start naming
  every test fold that begins flat.
- Surface a `cold_start_distorted = TRUE` flag in the default print method's
  per-fold degradation table (Section 16.5).
- Be referenced explicitly in the walk-forward vignette as the
  cold-start-distorted-evidence variant.

This default aligns with `quantstrat::walk.forward()`, which carries the
account across test slices to avoid the cold-start distortion the
post-Amendment-1 review identified.

**Path-dependency obligation.** `carry_test_state` introduces path dependency
across test folds: fold N's test outcome depends on fold N-1's terminal
state. This is intentional walk-forward semantics (the OOS evidence captures
path-dependent rebalancing behavior), but it means per-fold test metrics are
*not* statistically independent. Downstream diagnostic work (bootstrap, DSR,
CPCV) must not assume per-fold independence. This obligation is recorded in
Section 12.

### 16.3 Substantive constraint for Section 11 Q5 (supersedes Amendment 1 Section 14.2 Q5)

Amendment 1 Section 14.2 bound that selection metrics "must be rate or
annualized". Amendment 2 strengthens this to fail-closed enumeration with
metric-registration classification.

**Binding.** `ledgr_select_argmax()` and `ledgr_select_argmin()` may select
only metrics whose registered classification is `rate`, `annualized`,
`ratio`, or `length_invariant`. They fail closed with
`ledgr_walk_forward_metric_class_invalid` for level or count metrics,
including but not limited to `total_return`, `final_equity`,
`max_drawdown_depth`, `n_trades`, `trade_count`, and raw P&L.

**Metric-registration mechanism.** Metric classification is a property of
the metric's registration, not of selection-rule code. The v1 ticket cut
must include a metric-classification field on the metric registry (mechanism
to be specified in the ticket packet; the constraint here is that
classification must live with the metric definition, not with the selection
rule).

**Open extension path.** A future RFC may add an explicit
`ledgr_select_with_override()` rule class that allows selection on a level
or count metric with mandatory rationale capture. This is recorded as a
future-RFC item, not a v1 obligation.

**Short-test-window health warning.** Amendment 1's binding that the default
print method must include a short-test-window health warning (90 calendar
days as a v1 heuristic) is retained as a Section 16.5 obligation; see the
operational print contract there.

### 16.4 Substantive constraint for Section 11 Q7 (supersedes Amendment 1 Section 14.3 Q7)

Amendment 1 Section 14.3 made the `"latest"` extraction default conditional
on Q10's print method "making train-vs-test degradation visually
unavoidable". Amendment 2 binds the extraction surface unconditionally.

**Binding.** `ledgr_walk_forward_extract_candidate()` has no implicit default
for `fold_seq`. The signature is:

```r
ledgr_walk_forward_extract_candidate(
  session_id,
  fold_seq,
  selection_rationale = NULL
)
```

`fold_seq` is required. The caller must pass either an integer fold sequence
or the explicit sentinel string `"latest"`.

**`"latest"` sentinel rationale requirement.** When `fold_seq = "latest"` is
used, `selection_rationale` must be a non-empty character string. The
extraction path fails closed with `ledgr_walk_forward_latest_without_rationale`
when this condition is violated. The rationale is captured in the
extracted candidate's provenance and is required by `ledgr_promote()` as
the basis for the promotion note.

This converts `"latest"` from a silent default into an explicit,
audit-trail-bearing choice. It addresses the post-Amendment-1 review's
concern that the procedural Q7/Q10 coupling allowed `"latest"` to ship
without the operational discipline Amendment 1 intended to enforce.

### 16.5 Operational default print contract (supersedes Amendment 1 Section 14.3 Q10)

Amendment 1 Section 14.3 bound that the default print method "must expose
train-vs-test degradation as a primary visual signal". This is interpretive.
Amendment 2 binds an operational data contract.

**Data contract.** The data backing `print(walk_forward_results)` must
include a per-fold degradation table with the following fields:

- `fold_seq` -- integer fold index;
- `train_window` -- `train_start_utc` to `train_end_utc` formatted as
  human-readable interval;
- `test_window` -- `test_start_utc` to `test_end_utc` formatted as
  human-readable interval;
- `selected_candidate` -- `candidate_key` of the selected candidate per the
  fold's selection rule;
- `selection_metric` -- name of the metric used for selection;
- `train_metric_value` -- the selected candidate's train-window metric value;
- `test_metric_value` -- the same candidate's test-window metric value;
- `metric_diff_abs` -- `test_metric_value - train_metric_value`;
- `metric_diff_pct` -- `(test - train) / abs(train)` where defined; `NA`
  where undefined;
- `warning_flags` -- character vector or comma-joined string, including at
  least `short_test_window` (test window < ~90 calendar days; v1 heuristic)
  and `cold_start_distorted` (set when Section 16.2's flat-start opt-in is
  used).

**Scale contract.** Train and test metric values in the table must be on
the same metric scale (e.g., both annualized Sharpe, both annualized
return). The contract excludes mixing a length-dependent train aggregate
with a length-dependent test slice.

**Visual contract.** The print method's visual rendering may compress
columns, abbreviate headers, omit `train_window` and `test_window` strings
when terminal width is narrow, or use glyph summaries (e.g., arrows) for
`metric_diff_abs`. The data fields above must remain accessible to
programmatic inspection (e.g., via a `summary()` or accessor method)
regardless of visual compression.

**Secondary surfaces.** Per-fold equity strips, parameter paths, and
single-best-candidate equity curves may appear in the default print as
secondary surfaces below the degradation table. They must not precede or
visually dominate the degradation table.

**Short-test-window health warning.** When any fold's test window is
shorter than approximately 90 calendar days (v1 heuristic), the print
method must surface a `short_test_window` flag on every affected row and
include a one-line health warning above the degradation table.

This operational contract is the v1 teaching surface for the honesty
thesis. A spec-cut writer cannot now ship a default print whose primary
shape is per-fold equity; the degradation table must appear first.

### 16.6 Section 12 path-dependency obligation

Section 12 receives a new bullet (in addition to Amendment 1 Section 14.5's
compute-scaling caveat):

> Per-fold test metrics under `carry_test_state` (Section 16.2 v1 default) are
> not statistically independent because each fold's test starting state is
> the prior fold's test terminal state. Downstream diagnostic work
> (bootstrap-based confidence intervals, DSR, CPCV, fold-aggregated Sharpe)
> must not assume per-fold independence. Diagnostic-retention RFCs that
> compute such aggregates must either model the path dependence explicitly
> or operate on per-fold series rather than per-fold scalars.

### 16.7 Sections unchanged by Amendment 2

Sections 1, 2, 4, 5, 6, 7, 8, 9, 10, 13 and Amendment 1 Sections 14.1, 14.4,
14.5 are unchanged by Amendment 2. The architecture, scope, identity, and
acceptance posture remain as bound. Amendment 2 strengthens four routing
mechanisms into substantive defaults and one operational contract; it does
not re-open architecture.

---

## 17. Ticket-Cut Gates

Amendments 1 and 2 bind text into the synthesis but do not, by themselves,
guarantee that the v0.1.9.x ticket packet honors them. Section 17 records
the ticket-cut gate matrix: the v0.1.9.x walk-forward ticket packet may not
open, and may not pass release gate, except as specified below.

The matrix uses a two-gate lifecycle:

- **Spec-packet gate (packet-open):** the ticket packet's `tickets.yml` (or
  equivalent acceptance-criteria record) must include the named acceptance
  criterion before packet-open. Spec-packet review fails if any row's
  packet-open criterion is empty or absent.
- **Release gate (packet-close):** at v0.1.9.x release-gate review, each row's
  acceptance criterion must be marked complete in the spec packet or
  explicitly carried forward to a named follow-up RFC or follow-up ticket
  packet. Silent omission fails the release gate.

Both gates require maintainer sign-off; "owner" rows below name
`maintainer-signed-off` rather than individuals because the project has a
single maintainer.

### 17.1 Gate matrix

| Amendment item | Packet-open criterion | Release-gate criterion | Owner |
| --- | --- | --- | --- |
| Section 14.1 + 16.1 -- train-fold scoring correction | Spec packet names rolling and anchored parity tests asserting that `fold_train_sweep(fold_n) == ledgr_sweep(window = c(train_start_utc, train_end_utc))` over the full stored train window | Parity tests exist for both schemes and pass on the v1 deterministic fixture | maintainer-signed-off |
| Section 16.2 -- `carry_test_state` default and `flat_test_state` opt-in | Spec packet names the v1 default constant, the opt-in mechanism, and the `ledgr_walk_forward_cold_start_warning` condition class | Default behavior test asserts carry semantics; opt-in test asserts warning fire and `cold_start_distorted` flag in print | maintainer-signed-off |
| Section 16.3 -- fail-closed metric classification | Spec packet names the metric-classification field on the metric registry and the `ledgr_walk_forward_metric_class_invalid` condition class | Selection rule fails closed in test for at least one named level metric (`total_return`) and at least one named count metric (`n_trades`) | maintainer-signed-off |
| Section 16.4 -- no-default extraction and rationale arg | Spec packet names the `selection_rationale` arg and `ledgr_walk_forward_latest_without_rationale` condition class | Extraction test asserts failure when `fold_seq = "latest"` is passed without rationale; passes when rationale is present and is captured in provenance | maintainer-signed-off |
| Section 16.5 -- operational print contract | Spec packet names the per-fold degradation table fields, the scale contract, and the short-test-window warning condition | Print-method test asserts every data field is present and a structural test asserts the degradation table precedes secondary surfaces in default print order | maintainer-signed-off |
| Section 14.4 -- feature-windowing determinism + cross-fold train-score stability tests | Spec packet names both tests as v1 release blockers | Both tests exist and pass on the v1 deterministic fixture | maintainer-signed-off |
| Section 14.4 -- survivorship-bias vignette sentence | Spec packet names the vignette file and the binding sentence as required scope | Sentence is present in the walk-forward vignette at release-gate review | maintainer-signed-off |
| Section 14.5 + 16.6 -- compute-scaling caveat + path-dependency obligation | Spec packet names the walk-forward design doc or vignette location where both caveats are recorded | Both caveats appear in the named location at release-gate review | maintainer-signed-off |

### 17.2 Gate enforcement

The gate matrix is binding on the v0.1.9.x ticket packet. A maintainer
override of any row requires an explicit override note in the packet's
spec-cut log naming the row, the rationale, and the carry-forward target
(follow-up RFC or follow-up packet). Override without carry-forward target
fails release gate.

This converts Amendments 1 and 2 from "text the spec-cut writer should
honor" into "spec-cut packet contents the maintainer reviews against the
matrix at two named lifecycle points." It is the enforcement mechanism the
post-Amendment-1 review identified as missing.

### 17.3 Sections unchanged by Section 17

Section 17 adds an enforcement mechanism over Amendments 1 and 2. It does
not modify any bound text in Sections 1 through 16. Acceptance per Section
13 stands; the spec-cut writer's authority over the Section 11 open
questions is preserved, but is now bounded by the matrix above.
