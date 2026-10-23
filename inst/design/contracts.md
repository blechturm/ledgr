# ledgr Contracts

This file is the normative current-release source for shipped public behavior
and preserved internal invariants. Code and tests are implementation evidence;
they do not silently change these rules. When code disagrees with a clause,
the clause stands provisionally while the defect or an authorized contract
change is routed.

Accepted rules or direction not yet consolidated remain authoritative in their
exact accepted source. An affected clause links to that source through an
`Accepted change pending` entry in the design-decision bridge. The implementing
packet removes that link only when it rewrites the clause under the accepted
authority. Historical packets explain how rules arose; they are not the
current contract merely because they are newer or nearby.

**Contents**

- [Public Naming Contract](#public-naming-contract)
- [Execution Contract](#execution-contract)
- [Sweep Promotion Contract](#sweep-promotion-contract)
- [Config Contract](#config-contract)
- [Snapshot Contract](#snapshot-contract)
- [Availability Contract](#availability-contract)
- [Persistence Contract](#persistence-contract)
- [Canonical JSON Contract](#canonical-json-contract)
- [Strategy Contract](#strategy-contract)
- [Context Contract](#context-contract)
- [Result Contract](#result-contract)
- [Documentation Contract](#documentation-contract)
- [Verification Contract](#verification-contract)

## Public Naming Contract

<a id="contract-public-name-shapes"></a>
### Export And Family Name Shapes

- Exported user-facing helpers must use `ledgr_` prefixes. No unprefixed public
  helper exports remain. S3 method registrations such as `print.*`,
  `summary.*`, `close.*`, and `as_tibble.*` follow dispatch naming and are not
  user-facing helper exceptions to the prefix rule.
- Public names are family-first whenever a durable artifact family exists:
  run helpers use `ledgr_run_*`, snapshot helpers use `ledgr_snapshot_*`, sweep
  helpers use `ledgr_sweep_*`, and walk-forward helpers use
  `ledgr_walk_forward_*`.
- Verb-first exports are limited to:
  `ledgr_compute_metrics()`, `ledgr_precompute_features()`,
  `ledgr_validate_schema()`, `ledgr_backtest_bench()`, and
  `ledgr_promote()`. Execution entry points such as `ledgr_run()`,
  `ledgr_sweep()`, and `ledgr_walk_forward()` are family roots, not allowlist
  cases.
- Reopen surfaces for durable evidence use `open`, for example
  `ledgr_run_open()`, `ledgr_sweep_open()`, and `ledgr_walk_forward_open()`.
- Public evidence accessors must not use `extract_`, `get_`, or `fetch_` as
  their primary naming shape. Promotion-ready candidate extraction uses the
  `ledgr_candidate()` generic.

<a id="contract-public-indicator-and-rule-names"></a>
### Indicator And Rule Names

- Public indicator names distinguish constructors from infrastructure:
  `ledgr_ind_*` names are indicator constructors, constructor bundles, or
  constructor-family support helpers such as `ledgr_ind_ttr_warmup_rules()`;
  `ledgr_indicator_*` names are registry, lookup, development, and
  infrastructure surfaces.
- Candidate-selection rule constructors use the `ledgr_rule_*` family.
  `ledgr_rule_argmax()` and `ledgr_rule_argmin()` construct the unchanged
  `ledgr_selection_rule` payload; `ledgr_select_argmax()` and
  `ledgr_select_argmin()` are not public aliases.

<a id="contract-public-internal-names"></a>
### Internal Names

- Internal helpers may keep implementation-oriented names, but they must not be
  exported merely to avoid writing a narrow public wrapper.

## Execution Contract

<a id="contract-execution-entry-points"></a>
### Entry Points And One Execution Path

Accepted change pending: [OMS order lifecycle](decisions.md#oms-order-lifecycle).

- `ledgr_run()` is the public single-run API over a
  `ledgr_experiment` object. `ledgr_backtest()` is demoted from the recommended
  public workflow to a lower-level compatibility surface. It runs dense
  execution only: on a snapshot that declares point-in-time facts (sessions,
  membership, trading status, or lifetime) it refuses with
  `ledgr_backtest_availability_unsupported` and points to `ledgr_experiment()`
  plus `ledgr_run()` (Cut 12 LDG-3001). Corporate-action-only snapshots still
  run.
- There is still one canonical execution path. Public convenience APIs must
  build canonical config and delegate to the existing runner; they must not
  implement alternate pulse, fill, ledger, feature, or replay semantics.
- Convenience APIs may reduce setup friction, but must not implement alternate
  execution semantics.
- ledgr is a deterministic backtesting core with adapter boundaries to the R
  finance ecosystem. Indicator, data, and visualization packages should plug
  into ledgr through explicit adapters rather than replacing or bypassing the
  canonical execution path.
- The runner owns pulse order, fills, strategy state, ledger events, features,
  and equity output.

<a id="contract-execution-fold-core"></a>
### Fold Core And Output Handlers

- The fold-core/output-handler boundary is a required architecture
  contract before sweep mode. The fold core is the deterministic per-pulse
  execution engine: pulse calendar order, context construction, feature lookup,
  strategy invocation, target validation, target-risk transformation,
  fill timing, cost resolution, final-bar no-fill behavior,
  cash/position/state transitions, and the canonical in-memory event stream.
  The output handler is the persistence or accumulation layer that materializes
  fold outputs into `ledger_events`, `features`, `strategy_state`,
  `equity_curve`, telemetry, summaries, comparison rows, or future in-memory
  sweep result objects.
- `ledgr_run()` and `ledgr_sweep()` must call the same fold core. Sweep
  mode may use a cheaper output handler, skip DuckDB persistence, batch
  materialization, or keep only summary/ranking output. It must not change
  strategy semantics, target validation, feature values, pulse order, fill
  timing, cost semantics, state transitions, random-state semantics, final-bar
  behavior, or event-stream meaning.
- Output handlers may differ only after the fold has produced the same semantic
  result for the same experiment, params, seed, snapshot, universe, feature
  definitions, and date range. A persisted run's ledger rows and a sweep
  candidate's in-memory event stream must be semantically equivalent even when
  one is written to DuckDB and the other is accumulated in memory.
- Availability-aware execution prepares one immutable causal-history
  substrate from the first session of the experiment snapshot through the
  requested end. That substrate alone owns the common venue axis, canonical
  instrument index, bars, facts (stored lifetime and terminal segments, and
  the provider execution plan that holds membership and trading-status facts
  once), expected-session masks and feature inputs. It replaces `bars_by_id`,
  `bars_mat` and `static_bars_views` on that path; dense execution retains its
  pre-cut representation.
- P1 (observe and settle) is the sole fold-stage substrate reader. P2 (decide)
  adapts the primitive packet returned by P1 into the strategy context and
  feature views. P3 through P5 receive neither a history frame nor a substrate
  reference. Cursor-bearing provider and history readers are declared fold
  services and remain local to one daemon/consumer; they are not stored in or
  shared through the immutable substrate.

<a id="contract-execution-window-start"></a>
### Scoring And Feature Start

- **Scoring start (Cut 9).** Every entry point evaluates the strategy, fills,
  writes equity and contributes metric input only from its scoring start: the
  experiment's opening date for `ledgr_run()`, `ledgr_sweep()`,
  `ledgr_promote()` and `ledgr_precompute_features()` (the snapshot start when
  the opening is undated or dated earlier; a run records that clamped start as
  its config start, Cut 12 LDG-3004), `start` for `ledgr_backtest()`,
  and the window start for walk-forward training and test windows. A distinct
  `execution_start_utc` refuses with `ledgr_unsupported_execution_start`; a
  scoring range with fewer than two pulses refuses with
  `ledgr_run_window_too_short` in runs and sweeps alike. A sweep's
  `scoring_range` names the first and last pulse it scored, in memory and
  after reopening.
- **History start (Cut 16, LDG-3064).** History has one start, the data
  start: the first session of the experiment's snapshot. Every
  availability-aware run, sweep, promotion, run or sweep window, walk-forward
  training and test window, explicit precompute and experiment-derived pulse
  inspection reads feature, mark and entitlement history from it through one
  shared causal preparation; the scoring start bounds decisions, fills, equity
  and metric input only. A window, stored fold row, precomputed payload or
  condition carries no second history start: `hydration_start_utc`,
  `ledgr_unsupported_hydration_start`, `ledgr_precomputed_hydration_mismatch`
  and the payload `warmup_range` no longer exist. An availability payload
  records its causal axis (data start, first calculated session, cutoff and
  session stamps) and a sweep or sweep window reuses it only when that axis,
  the cutoff, the history policy, the snapshot and every candidate's feature
  identity match exactly; otherwise it refuses before any candidate runs with
  `ledgr_precomputed_range_mismatch` (cutoff or calculation start),
  `ledgr_precomputed_history_mismatch` (policy or axis),
  `ledgr_precomputed_snapshot_mismatch` or
  `ledgr_precomputed_feature_mismatch`, and a dense payload never serves an
  availability sweep nor the reverse. Dense experiments keep the frozen dense
  rule: their feature state starts at the scoring start, and a dense payload
  serves only a range or window scoring from its own start
  (`ledgr_precomputed_range_mismatch`). When no candidate trades in a
  walk-forward training window, volatility-based selection metrics have no
  finite value and that fold has no selection; see No selection.

<a id="contract-execution-walk-forward-folds"></a>
### Walk-Forward Fold Lifecycle

- No selection (Cut 10, LDG-2974). `ledgr_walk_forward(no_selection = )`
  decides what a fold does when no training candidate has a finite, `DONE`
  selection metric. Under the default `"previous"` the fold runs its test
  window with the parameters most recently selected from a training window;
  its `selected_candidate_key` is this fold's train key for those parameters,
  and its train selection metric is reported as `NA` in degradation, selected
  rows and candidate provenance while the stored train score row is unchanged.
  Before any training window has selected, the fold runs no test window,
  carries the opening it received and is `DONE`. A previous fold follows the
  train-fold status rules (`DONE`, `PARTIAL` on an `INCOMPLETE` test run,
  `FAILED` on a failed test run). `"fail"` keeps the session-ending
  `ledgr_walk_forward_no_selection`. Every fold row records `selection_source`
  (`train`, `previous`, `none`, or `NULL` for a failed fold without a
  selection; current experiment-store schema). None folds are omitted from
  selected rows and refuse candidate extraction; a previous fold's candidate
  provenance names its source and source fold. The policy is stored in
  session meta, a session without it reads as `"fail"`, and the printed
  session counts folds by source.
- Contiguous carry (Cut 11, LDG-2979; maintainer Type 2 decision 2026-10-09).
  Under `opening_state_policy = "carry_test_state"`, consecutive test windows
  must be chronologically ordered and contiguous: each test window starts
  strictly after the previous one ends, and no pulse lies strictly between
  them. `ledgr_walk_forward()` checks this before any training sweep or store
  write. A window that does not start after the previous one ends (overlap or
  reverse order) would open from state the previous window reached later in
  time and refuses with `ledgr_walk_forward_overlapping_carry`; a pulse
  between windows would be carried across unvalued and refuses with
  `ledgr_walk_forward_gapped_carry`. Both also carry
  `ledgr_walk_forward_invalid_fold_window`, and each message names the first
  offending pair and both remedies: contiguous folds (`step` equal to
  `test_window`) or `"flat_test_state"`. The pulses are the open-session
  closes of an availability-aware experiment, otherwise the universe's bar
  timestamps. Single folds and contiguous fold lists are unchanged.
  `"flat_test_state"` accepts gapped, overlapping and reverse-ordered fold
  lists, because no state crosses fold boundaries. Reconstructing carried
  state at an overlapping window's start is not supported.
- Continuous carry (Cut 16, LDG-3064). In an availability-aware session
  under `"carry_test_state"`, the test windows are one economic chain. Every
  test window except the last executes its final decision in the same run at
  the following session's open, preserving the decision-to-fill join; the run
  records that instant as its final execution and its completion may report
  it as the last execution. The next window opens from the resulting cash and
  positions, its FIFO lots (one opening row per lot), every corporate-action
  row the previous window bound but one run would settle later (cash
  entitlements, dispositions and quantity effects, with the bound quantity),
  and the holdings frozen at the previous window's last pulse. The carried
  rows come from the previous window's own settlement plan, rebuilt from its
  ledger over its pulses and the next window's first pulse; in the next
  window a passed posting or effective clock counts as reached on its first
  pulse and the knowledge clock is resolved as in one run, so each row
  becomes due on the pulse one run uses. Feature, mark and entitlement history come from the shared
  data-start preparation and are never window-local. Strategy state does not
  cross a window. The concatenated test runs equal one public run whose
  strategy switches parameters at the same decision pulses on fills,
  corporate-action postings, marks, equity and decision diagnostics; each run
  reports realized profit and loss from its own opening lots. The last window,
  `"flat_test_state"` windows and standalone runs keep the terminal rule: the
  final decision is recorded as `final_pulse_no_execution` and nothing
  crosses. Dense sessions keep their per-window behavior.
- Calendar-month folds (Cut 16, LDG-3064). `ledgr_folds_rolling()` and
  `ledgr_folds_anchored()` derive every boundary from the original anchor plus
  whole multiples of the train, test and step periods. Months and years apply
  to the anchor's civil date and clamp to the last day of the result month;
  fixed durations are then added exactly. No boundary is derived from a
  preceding clamped boundary, so a monthly chain anchored on 2019-12-31 has
  neither day drift nor a pulse gap.
- Test-run resume (Cut 11, LDG-2980). When a walk-forward session is rerun, a
  test run that already exists with status `DONE` or `INCOMPLETE` is opened as
  recorded and not re-executed. Any other existing test run, such as one an
  interruption left `FAILED`, resumes through the ordinary run path with the
  same window, parameters and seed, so rerunning an interrupted session with
  the same arguments completes with the uninterrupted session's folds,
  selections and test results. A resumed run whose configuration no longer
  matches refuses with `ledgr_run_hash_mismatch`.
- Sealed-date boundaries (Cut 11, LDG-2991). Window and precompute boundaries
  are checked against the sealed snapshot range by calendar date (UTC). A
  start on the first sealed date before its first bar resolves to that bar's
  timestamp, and an end on the last sealed date after its last bar resolves
  to that bar's timestamp; boundaries already inside the range are kept as
  given, so fold identity and in-range windows are unchanged. A boundary on
  a date outside the range refuses (`ledgr_walk_forward_invalid_fold_window`
  for windows, `ledgr_invalid_precompute_range` for precompute) with a
  message naming the requested window and the sealed first and last dates.

<a id="contract-execution-event-staging"></a>
### Event Staging And Parallel Sweeps

- The canonical R fold stages successful fill-event rows inside the output
  handler until `flush_pulse_events()` publishes the complete pulse. No code
  may read a staged row before that flush except the handler-local
  `record_accounting_fact()` patch for that same fill. A handler with no staged
  canonical rows treats the flush as a no-op; this preserves live database and
  compiled-accounting behavior while keeping event order and meaning common.
- Parallel sweep is candidate-level dispatch over the same fold core. Workers
  return compact candidate result rows to the orchestrator; they must not write
  candidate ledgers, equity curves, feature panels, run telemetry, or promotion
  artifacts. The orchestrator owns row ordering, warning/error association,
  result binding, and any durable writes.
- Parallel sweep interruption is discard-all. If a worker-backed
  sweep is interrupted before all candidate results return, ledgr must stop the
  worker backend where possible and throw a structured
  `ledgr_parallel_sweep_interrupted` error. It must not return a partial sweep
  table or partially promotable candidate result; partial-result recovery
  requires a future explicit contract.
- Availability-aware local sweeps stage the immutable causal-history input
  once on each persistent daemon. Candidate tasks carry an owner-scoped
  descriptor key for the staged substrate plus candidate-varying fields. A
  missing or different descriptor refuses with `ledgr_staged_history_mismatch`
  before strategy invocation, fills or result writes. Daemons rebuild only
  consumer-local pulse text and cursors. One and two local workers are the
  measured history envelope;
  larger counts remain runnable but are labelled unmeasured. Worker count and
  resource settings never enter experiment, candidate or run identity.
- A sweep that computes its own features, and experiment-derived pulse
  inspection, release the feature payload once the runtime projection that
  holds every value they read exists. When that sweep stages two or more
  workers it then runs one garbage collection before staging, so the
  released payload does not stay resident through serialization; sequential
  sweeps and pulse inspection do not collect (Cut 16 decisions 25 and 26).

<a id="contract-execution-snapshot-trust"></a>
### Snapshot Trust Boundary

- Production entry into the fold core must be guarded by the Snapshot Contract
  trust boundary. Production run and sweep setup must enforce the accepted
  sealed-snapshot guard before fold construction. Committed runs ensure a
  current-process verified entry for the snapshot; a miss recomputes the
  complete current-rule root and compares it with the stored root. Sweep and
  walk-forward evaluation ensure once at their first content-dependent outer
  read, before candidate or fold execution; inner guards reuse that entry.
  Compact candidate provenance still carries the stored root. Primitive fold
  hot paths may then rely on trusted normalized snapshot inputs.

<a id="contract-execution-accounting-events"></a>
### Cost Resolution And Accounting Events

Accepted change pending: [OMS order lifecycle](decisions.md#oms-order-lifecycle).

- Cost resolution belongs inside the fold before any output handler sees
  events. Output handlers must not compute, reinterpret, or rewrite fill prices,
  fees, cash deltas, or cost metadata.
- Pulse plans declare every economic-event kind they carry. Each accounting
  arm must handle every declared kind or fail closed before accounting; neither
  canonical nor compiled execution may complete after silently dropping one.
- A terminal outcome, modeled or evidenced, posts one `DISPOSITION` event at
  the effective pulse before the strategy decision. It is not a fill and uses
  no fill timing or cost model. The event, its lot close, its cash change and
  its policy summary commit together: an error raised before the append
  leaves none of them. The event's quantity and price equal those recorded in
  its canonical `meta_json`, which also names the source
  (`corporate_action_disposition` or `lifetime_terminal_disposition`), source
  fact, terminal event, matched label, choice, basis (`label`, `default`,
  `frozen_fallback` or `evidence`), policy identity, haircut fraction, mark
  provenance, cash delta and realized P&L. Replay rejects a disposition whose
  event fields disagree with that record.

<a id="contract-execution-compiled-accounting"></a>
### Compiled Accounting Dispatch

- Compiled accounting dispatch is closed by accounting model. The
  only scoped public opt-in model is
  `compiled_accounting_model = "spot_fifo"` for memory-backed sweep execution;
  `NULL` means the canonical R fold path and remains the default. Unsupported
  accounting-model values must fail closed with a named
  unsupported-accounting-model error before compiled work runs. The spot-FIFO
  accelerator is not a derivatives, margin, options, or general instrument
  accounting engine. Committed durable `ledgr_run()` execution must fail closed
  for `"spot_fifo"` until a separate durable compiled-integration gate lands.
  The `ledgr.internal.compiled_accounting_model` option is an internal legacy
  hook and must not influence public `compiled_accounting_model = NULL`
  execution.

<a id="contract-execution-decision-and-fill-contexts"></a>
### Decision And Fill Contexts

- Strategy contexts carry decision-time information only. Future cost/fill
  contexts may carry execution-bar data for pricing, but those objects must
  remain separate so next-bar execution data cannot leak into strategy
  decisions.
- Fill timing and cost application are separate execution-contract layers.
  The public timing surface exposes `timing_model = ledgr_timing_next_open()`
  and requires an
  explicit classed `cost_model`, such as `ledgr_cost_zero()` when the caller
  wants zero transaction costs.

<a id="contract-execution-cost-model"></a>
### Cost-Model Identity And Arithmetic

- Cost-model identity is part of execution identity. `cost_plan_json` is the
  canonical serialized cost plan, and `cost_model_hash` is the SHA-256 hash of
  that plan. Sweep persistence and walk-forward candidate/session identity
  consume these fields. Cost-grid sweep composition remains separate future
  work.
- Cost resolution applies price transforms first. Notional fees use the
  spread-adjusted, unrounded execution price; the exposed `fill_price` is then
  rounded separately to eight digits by default for ledger cash arithmetic.
  Fill price, fee, cash delta and event metadata retain those distinct,
  deterministic values.

<a id="contract-execution-target-risk"></a>
### Target-Risk Transformation

Accepted change pending: [OMS order lifecycle](decisions.md#oms-order-lifecycle).

- Target risk is a target-vector transformation layer. Strategies still return
  full named numeric target quantities. The fold applies the normalized
  `risk_chain` after strategy target validation and before fill timing, cost
  resolution, and event emission. The public surface exposes only classed ledgr risk
  objects: `ledgr_risk_none()`, `ledgr_risk_chain()`,
  `ledgr_risk_long_only()`, and `ledgr_risk_max_weight()`. Arbitrary
  user-supplied risk callbacks are not part of the public contract.
- Target-risk identity is part of execution identity. `risk_plan_json` is the
  canonical serialized risk plan, and `risk_chain_hash` is the SHA-256 hash of
  that plan. Omitted `risk_chain`, `risk_chain = NULL`, and
  `risk_chain = ledgr_risk_none()` normalize to the same no-op risk plan for
  new configs. Parameterized risk arguments use `ledgr_param()` and resolve
  through ordinary candidate params; there is no separate risk-parameter grid.
- Target risk does not implement affordability enforcement, cash-floor checks,
  silent buy scaling, portfolio optimization, margin, shorting or borrow
  policy, liquidity/capacity modeling, OMS lifecycle behavior, broker-grade
  risk controls, cost estimation, or automatic candidate selection. Those
  remain separate future layers or RFC topics.
- Risk-enabled sweep rows expose `risk_chain_hash`, and row-level provenance
  carries `risk_plan_json`. Saved sweep schema 5 stores `risk_chain_hash` and
  `risk_plan_json` on `sweeps` and `sweep_candidates`; any other saved-sweep
  schema value refuses with `ledgr_sweep_schema_incompatible`.
  Promotion must preserve the selected candidate's risk identity and re-execute
  through `ledgr_run()`; retained return rows are not replayed as committed
  evidence.

<a id="contract-execution-identity"></a>
### Execution And Feature Identity

Accepted change pending:
[objective-filtered walk-forward identity](decisions.md#objective-filtered-walk-forward-identity).

- Walk-forward evidence adds two identity layers over existing run and sweep
  identity. `candidate_key` identifies one fold/window/candidate evaluation and
  includes strategy, feature, alias, metric-context, cost, risk, seed, fold, and
  window-role inputs. `session_id` identifies the walk-forward session envelope
  and includes snapshot, experiment, grid, fold-list, selection-rule,
  metric-context, cost, risk, seed, and opening-state policy identity, plus
  the no-selection policy when it is not `"fail"`. A `"fail"` policy is
  omitted from the identity payload; every other no-selection policy is
  included.
  Locator attributes on `ledgr_walk_forward_results` objects (`db_path`,
  `snapshot_id`, and `snapshot_hash`) are recovery and resolve-at-call
  verification metadata. They are not identity bytes and must not enter
  `config_hash`, `candidate_key`, or `session_id`.
- A caller-supplied snapshot override for a walk-forward candidate must match
  both the recorded `snapshot_id` and `snapshot_hash`; `db_path` may differ.
  A mismatch refuses with `ledgr_walk_forward_snapshot_override_mismatch`
  before promotion or execution.
- Config and feature identity fields must keep their layers distinct.
  `config_hash` identifies the logical execution config after removing
  store-local and run-local fields such as DuckDB paths, `run_id`, and
  declaration-order diagnostics. Every run records `identity_rule_version`.
  Under identity rule 4 the config carries the sealed
  `data.snapshot_hash` and `config_hash` drops the store-local
  `data.snapshot_id`, so identical content sealed under two snapshot IDs gives
  equal identity and different content under one reused ID does not; the
  walk-forward `experiment_hash` and `session_id` follow, and each session
  records the rule in its `meta_json`. Rule 4 retains rule 3's removal of the
  feature-retention switch and deterministic direct captures of indicator
  functions. It additionally binds the causal-history policy, axis, cutoff and
  treatment rule versions. Declared and assumed price bases remain distinct;
  worker and resource controls are excluded. Every config and session carries
  identity rule 4 as the exact integer `4L`; a missing, differently typed or
  different rule is refused rather than coerced, inferred or migrated.
  `feature_set_hash` identifies resolved
  concrete feature definitions by feature fingerprints. `feature_params_hash`
  identifies user-supplied feature parameter values. `alias_map_hash`
  identifies alias declarations and must not change solely because a
  parameterized feature declaration resolves to a different concrete parameter
  value; that concrete identity belongs in `feature_set_hash`.

<a id="contract-execution-preflight"></a>
### Strategy Preflight

- Strategy preflight runs before entering the fold core. Sweep mode inherits
  the public preflight semantics: Tier 1 and Tier 2 strategies may execute, and
  Tier 3 strategies must stop before any fold execution or output handler side
  effects.

<a id="contract-execution-fills-and-lots"></a>
### Fill And Lot Validity

- The default fill model is `next_open` with zero spread and zero fixed
  commission. A target emitted at pulse `t` is filled at the next available bar;
  a target emitted on the final pulse has no next bar and is not filled.
- FIFO lot accounting must pop machine-epsilon-scale fractional dust that
  remains after a close operation in both the canonical R replay path and the
  compiled spot-FIFO path. This tolerance is only a representation cleanup for
  arithmetic residue after matched close quantities; it is not a new
  affordability rule, quantity granularity, liquidity policy, or identity
  component.
- `ledgr_lot_apply_fill()` accepts only a known side, finite positive quantity
  and finite non-negative fee. Ordinary fills require a finite positive price.
  A terminal `DISPOSITION` alone may close lots at a finite zero price through
  the internal `allow_zero_price = TRUE` path; a negative or non-finite price
  always fails. Invalid transitions fail closed with a classed condition
  aligned with the compiled lot kernel on its supported fill subset.

## Sweep Promotion Contract

<a id="contract-promotion-candidate-evidence"></a>
### Candidate Evidence

- Sweep results are summary outputs, not committed run artifacts. They
  must still carry enough compact candidate identity for deliberate promotion:
  candidate label, params, status, standard summary metrics, warnings, error
  fields, candidate-specific feature fingerprints, row-level `execution_seed`,
  and row-level `provenance`.
- `execution_seed` is the actual fold seed used by the candidate. It is
  `NA_integer_` for unseeded candidates and maps to `seed = NULL` when
  promoted. A non-`NA` value must be passed to `ledgr_run(seed = ...)` during
  promotion so stochastic candidates can be replayed exactly on the same
  snapshot and config.
- Row-level `provenance` is compact lineage, not full durable run provenance.
  Its structure is versioned by
  `provenance_version = "ledgr_provenance_v1"` and includes snapshot hash,
  `strategy_hash`, feature-set hash, master seed, seed contract, and
  evaluation scope.
- `ledgr_candidate()` is the canonical extraction helper for a promotion-ready
  candidate. `ledgr_promote()` is the canonical commit helper and must call
  `ledgr_run()` with the candidate params and execution seed. Users should not
  need to manually extract `params[[1]]` or seed values from a sweep row.

<a id="contract-promotion-commit"></a>
### Promotion Commit And Audit

- Runs created through `ledgr_promote()` store durable selection-audit metadata
  in `run_promotion_context` with
  `promotion_context_version = "ledgr_promotion_v2"`. Promotion context records
  the selected candidate, `sweep_id`, source sweep metadata, user note, and the
  compact selection-view summary passed to `ledgr_candidate()`. Version 2 adds
  `identity_check` (Cut 12 LDG-3005): the candidate's strategy, feature-set,
  universe, valuation-policy, corporate-action-policy and opening identity
  hashes, recorded by the sweep in its execution assumptions, beside the
  promoting run's, with the fields that differ and those the sweep did not
  record (a walk-forward candidate records only strategy and feature-set
  identity). A difference warns with `ledgr_promote_identity_mismatch`; it does
  not refuse. Current promotion records always carry version 2.
- Promotion context is written only after the committed run succeeds. If the
  promotion-context write fails, ledgr warns and returns the committed run; it
  must not roll back a successful run.
- Direct `ledgr_run()` calls have no promotion context. Promotion context is
  distinct from full run provenance and compact saved-sweep persistence through
  the family-first sweep surfaces.

<a id="contract-promotion-selection-status"></a>
### Selection Status And Eligibility

- Every selection surface reports attempted, done, incomplete and failed
  counts: run-list and comparison prints, sweep prints, `ledgr_sweep_review()`
  (as `counts`) and walk-forward prints, per window. Typed `stop_reason` and
  `affected_instrument_ids` stay inspectable: sweep tables and walk-forward
  score rows derive them, with the five valuation flags, from
  `completion_json` into the columns directly after it, and review issue rows
  show them. Counts are disclosure only.
- A frozen or assumed-terminal `DONE` candidate or run stays eligible for
  ranking, filtering, extraction and promotion under its declared model; its
  valuation flags travel beside ranking output in review and comparison.
  `INCOMPLETE` and `FAILED` candidates stay visible in inventory and review
  issues but never enter ranking, filtering, promotion or full-run
  comparison. An `INCOMPLETE` candidate is never extracted. A `FAILED`
  candidate is extractable only through explicit
  `ledgr_candidate(..., allow_failed = TRUE)`, for diagnosis.

## Config Contract

<a id="contract-config-construction"></a>
### Construction And Validation

- `ledgr_config()` is an internal construction helper. It returns an
  S3 object of class `ledgr_config`, validates the object before returning, and
  has a concise print method for diagnostics.
- `validate_ledgr_config()` is the internal validator used by execution code.
- Direct config construction is not exported. Public workflows start with
  `ledgr_experiment()` and run with `ledgr_run()`.
- Every current config carries the canonical causal-history identity produced
  by `ledgr_history_policy()`. Missing or non-current history identity refuses;
  it is not inferred from other config fields.

<a id="contract-config-policies"></a>
### Corporate-Action And Valuation Policies

- Corporate-action and valuation policies use schema 2 (terminal-outcomes
  synthesis, accepted 2026-10-05). `ledgr_corporate_actions()` takes
  `held_terminal_position` as one choice or as an ordered named map of exact
  sealed `terminal_event` labels to choices with a required `default` entry.
  The choices are `last_permissible` (research default), `last_mark`,
  `haircut`, `write_off` and `refuse`. `haircut` requires one finite fraction
  in `[0, 1]`, accepted only when an entry selects it.
  `frozen_terminal_position` is `write_off` (research default), `last_mark` or
  `refuse` (strict preset). Map order, labels, choices, the haircut fraction
  and the frozen fallback enter identity. Every terminal choice carries a
  `v002` identity because its trigger widened to lifetime terminal facts;
  `v001` keeps its earlier meaning. Every `unsupported_quantity` choice
  carries a `v002` identity because its trigger widened to held refused
  facts (Corporate Actions And Valuation; Cut 17 LDG-3089); `v001` keeps its
  earlier meaning.
- `ledgr_valuation_stale(max_sessions, exhausted = "freeze")` records
  `schema_version = 2` with `exhausted` of `"freeze"` or `"refuse"`. The field
  is invalid under any other schema.
- Every executable or inspectable current config carries schema-2
  corporate-action and valuation policy records. Missing or different policy
  schemas are invalid rather than inferred, translated or migrated.
- `ledgr_history_policy()` is the canonical experiment-level history policy.
  It defaults to `price_carry = 5L`, `output_carry = NULL` and
  `segment_limit = NULL`. `NULL` disables each carry stage independently; a
  supplied carry age or segment limit is a finite positive whole number that
  fits in an R integer.
  Omission and an explicit default policy have identical behavior and identity.

## Snapshot Contract

<a id="contract-snapshot-identity-and-verification"></a>
### Identity And Verification

- Backtests run against sealed snapshots.
- Snapshot hash rule 4 is the sole executable content-identity rule. It retains
  the rule-3 bytes defined by
  `rfc/rfc_snapshot_verification_policy_v0_2_2_seed_v2.md`, Section 5:
  R-owned column-major binary blocks of 10,000 logical rows; bytewise UTF-8
  composite-key order asserted in R; little-endian typed payloads with a
  presence byte per field; the exact fact projection; and domain-separated
  block, section and root SHA-256. Rule 4 adds the hashed civil-time evidence
  columns and its own block, section and root domains. Snapshot IDs and
  envelope metadata remain excluded.
- Every newly sealed snapshot records `hash_rule_version = 4`. In a current
  store, a snapshot row whose marker is missing or is not 4 is invalid stored
  evidence and refuses with `ledgr_snapshot_hash_rule_unsupported`. No legacy
  root, fallback encoder or missing-marker default remains executable.
- Snapshot content reads have three classes. Metadata-only reads may return
  status, root, rule, counts and timestamp ranges without proving rows.
  Durable-result-only reads use persisted run-store evidence and compare its
  recorded root without proving snapshot rows. Every snapshot-dependent read
  ensures a current-process verified entry before row values affect execution,
  identity, metrics, marks, reports or returned data. Row values, including
  instrument IDs returned by snapshot summary, are not metadata.
- Content identity, a successful complete verification, a current-process
  verified entry and possession of a stored root are distinct. The verified
  entry is private, process-local, PID-guarded and keyed by snapshot-store key,
  snapshot ID, stored root and rule. Only a committed seal or a successful
  complete recomputation may establish it. A failed status or verification
  check removes every entry for the matching snapshot store and snapshot ID,
  so restoring an older root cannot reactivate a stale proof. The entry is
  never serialized. In-memory or unresolved stores are never entered.

<a id="contract-snapshot-off-session-bars"></a>
### Off-Session Bars

- A valid bar that falls on no declared open-session close is sealed in
  `snapshot_bars` and never becomes a pulse (every run on a snapshot with
  sessions is availability-aware; `ledgr_backtest()` refuses such snapshots,
  Cut 12 LDG-3001). Ingest records each one in the quarantine table under reason
  `off_session_bar` (in either `invalid_observations` mode);
  `ledgr_snapshot_quarantine()` lists it with `disposition`
  `sealed_not_a_pulse` (quarantined rows read `excluded`),
  `ledgr_snapshot_info()` counts it as `off_session_bar_count` (0 when there
  is none), and `summary()` of an availability-aware result reports the
  snapshot-wide count when it is not zero. The record is derived from hashed
  bars and sessions, so it is outside the snapshot hash and the quarantine
  acknowledgement; rule 4 continues to exclude that derived record (Cut 12
  LDG-3011).

<a id="contract-snapshot-bar-validation"></a>
### Bar Validation

- Snapshot hash timestamp inputs must be POSIXct values. Non-POSIXct `ts_utc`
  vectors fail closed during hashing rather than being string-formatted through
  an implicit representation that could silently re-key a snapshot.
- Sealing validates referential integrity and OHLC consistency before writing a
  snapshot hash or transitioning to `SEALED`. Every stored open, high, low and
  close is positive (after rounding to 8 digits): a dense snapshot refuses a
  zero or negative price at its seal check (`ledgr_ohlc_non_positive`), and a
  fact-bearing ingest treats the row as an invalid observation with reason
  `ohlc_non_positive` (refused, or quarantined under
  `invalid_observations = "quarantine"`), so no non-positive price becomes a
  mark. Zero volume with positive prices is valid (Cut 12 LDG-2999).

<a id="contract-snapshot-point-in-time-facts"></a>
### Point-In-Time Facts

- Point-in-time fact intervals are half-open and knowledge-bounded. Session
  facts form a complete venue calendar with one open/closed row per civil date;
  daily vendor labels are mapped explicitly to declared session closes. The
  expected-session clock is independent of observation presence.
- Effective and knowledge clocks remain separate through construction,
  persistence and preparation. A Date-backed fact stores its original civil
  date together with the resolved UTC instant, venue zone and calendar
  identity; it must resolve to exactly one declared open venue session.
  A Date-valued fact interval bound resolves to its session open, for the
  inclusive start and the exclusive end alike, as does a Date-valued
  knowledge time; run, sweep, window and fold ends given as Dates resolve
  to the session close, as stated for availability-aware entry points
  below. A Date-valued corporate-action entitlement,
  effective or payment event resolves to that session's close, while its
  Date-valued knowledge time resolves to session open. POSIXct boundaries
  remain exact instants. Interval bounds, corporate-action clock order,
  correction order and family row order are checked on resolved instants, so
  a Date field is never compared through a UTC-midnight stand-in: a mixed
  Date and POSIXct row is accepted or refused by its resolved session
  instants (Cut 16 LDG-3073). Membership-snapshot headers are ordered by
  resolved effective and knowledge times after resolution (Cut 16 decision
  34).
- A fact family carries the hash of its own rows, headers and metadata.
  `ledgr_facts()` resolves and rehashes only a family that still holds civil
  labels, and checks that family's recorded hash first; every other family
  keeps its hash. A family edited after construction is therefore refused,
  with `ledgr_invalid_facts`, whatever else its bundle holds.
- Trading-status corrections form an acyclic supersession forest within one
  source and instrument. A successor cannot become knowable before its
  predecessor, may start earlier, and must cover the predecessor through its
  end. Supersession removes every ancestor before precedence resolves the
  remaining assertions. Tied contradictory siblings or unrelated descendants
  refuse; same-assertion components and later revivals remain valid.
- A corporate-action row with an event clock and no knowledge clock is known
  when its event becomes effective; the event clock is the effective time,
  else the entitlement time (Cut 16 decision 11). A POSIXct event is known at
  that instant. A Date-valued event is known at the declared open of its
  venue session, so a strategy can act on it during that session, and stays
  effective at that session's close (Cut 16 decisions 12 and 27). Each such
  filled row's provenance records knowledge `assumed` with reason
  `knowledge_assume_effective`, and a family holding one records
  `knowledge = "assume_effective"` in its metadata (Cut 17 LDG-3085). A
  supplied knowledge time, Date or POSIXct, is never replaced and its
  provenance records knowledge `evidenced` (Cut 16 decision 31).
  For membership, trading-status and lifetime facts,
  `knowledge = "assume_effective"` fills only a missing knowledge time from
  the effective time (and a Date effective time's civil label); a supplied
  knowledge time is always kept (Cut 16 decision 32). A row with no event or
  knowledge clock is audit-only and is never due. A row with knowledge time
  but neither entitlement nor effective time refuses, at that knowledge cutoff
  and not before, with `ledgr_corporate_action_clock_missing` carrying its
  fact and clock fields.
- A complete `ordinary_cash_dividend`, `cash_acquisition`,
  `stock_acquisition`, `mixed_acquisition` or `spin_off` row with an effective
  clock but no entitlement clock does not act or post: it refuses with `ledgr_corporate_action_entitlement_missing` at the
  pulse it would act on (its effective clock, or its knowledge clock when
  later), carrying its fact and instrument IDs, subtype and effective and
  knowledge clocks, in every execution mode. A carried walk-forward chain
  refuses on the same pulse as one run, including when the effective clock
  falls in an earlier test window than the knowledge clock (Cut 16 decisions
  28, 33 and 35). The user supplies the entitlement time.
- Local session wall times must resolve to exactly one UTC instant. Ambiguous
  fall-back and nonexistent spring-forward labels fail closed; an explicit
  POSIXct instant is already disambiguated and remains valid. An open
  session's open and close instants must fall on its `session_date` in the
  venue zone (`ledgr_session_instant_off_date`), and no two open sessions
  share an open or a close instant (`ledgr_session_instant_duplicate`);
  both are refused when the sessions family is built (Cut 12 LDG-3000).
- `ledgr_facts_membership_snapshots()` accepts either row-per-member evidence
  or a `members` list-column, never both. Both shapes normalize to the same set
  headers and member assertions before hashing. `character(0)` is an empty set;
  complete sets establish omission for their knowable effective state, while
  partial sets never fabricate negative assertions.
- Invalid observations fail snapshot creation by default. The dataframe adapter
  may exclude them only through explicit
  `invalid_observations = "quarantine"` with declared sessions. Excluded rows,
  reasons, original payloads, provenance, and the acknowledgement are hashed,
  reopenable audit evidence and never runtime bars. Structural duplicates,
  malformed facts, and an empty valid partition still fail closed.

<a id="contract-snapshot-open-and-trust"></a>
### Open, List And Trust Boundary

- Split snapshot/run DB mode must ensure the source snapshot from the snapshot
  DB while writing run artifacts to the run DB. Any reusable entry is keyed by
  the snapshot store, never the run store.
- `ledgr_snapshot_open(db_path, snapshot_id)` may reopen an existing sealed
  snapshot. It must never create, silently overwrite, or silently reseal a
  snapshot. `verify = TRUE` always recomputes the complete rule-4 root before
  returning, even when the snapshot is already verified in the process.
- Snapshot sealing, loading, and fold-entry guards form the trust boundary for
  normalized market data. After a production caller has accepted a sealed
  snapshot under its execution mode's guard, fold-core hot paths may treat bars,
  pulses, timestamps, instruments, and universe membership as trusted normalized
  primitives. They should not repeatedly revalidate OHLC shape, POSIXct/UTC
  status, or sealed-snapshot invariants per pulse, feature, or instrument.
- `ledgr_snapshot_open()` is the normal new-session resumption path. After
  loading a snapshot handle, ordinary
  run-management APIs should use the snapshot object rather than a `db_path`
  argument.
- `ledgr_snapshot_list()` accepts either a DBI connection or a DuckDB file path.
  Path inputs are opened read-style for discovery and closed before returning.
- Explicit custom snapshot IDs are allowed. The generated `snapshot_` pattern is
  a convention for generated IDs, not a ban on durable user names; warn only
  when a user-supplied ID starts with `snapshot_` but is malformed.
- Snapshot-backed workflows use sealed `snapshot_hash` values plus
  explicit selector bounds; run/resume and snapshot adapters must not rehash
  run-window bar values.

## Availability Contract

<a id="contract-availability-activation-and-calendar"></a>
### Activation And Session Calendar

- Availability-aware execution activates when a snapshot declares membership,
  sessions, trading-status, or lifetime facts, or when an experiment declares a
  valuation policy. There is no mode flag. Canonical omission preserves the
  dense experiment, config, execution-spec, context, and feature-identity
  payloads.
- Every availability-aware experiment requires a complete declared session
  calendar over the requested range and runs under a
  `ledgr_valuation_stale()` policy. A run, sweep, run window or
  walk-forward fold whose first or last sealed bar inside its requested range
  falls outside the declared calendar's civil days in the venue zone refuses
  with `ledgr_sessions_incomplete` instead of running over the shorter
  calendar (Cut 12 LDG-2998). The check runs at those execution
  entry points; reading or reconstructing a stored run does not repeat it.
  `ledgr_valuation_stale()` defaults to `max_sessions = 5` (decided from
  Sharadar gap data) and `exhausted = "freeze"`; `max_sessions = 0` means
  that only a current-session mark is permissible. When snapshot facts make an
  experiment availability-aware and it supplies no `valuation_policy`, it runs
  under `ledgr_valuation_stale()`; that policy is the same record, with the
  same config identity, as declaring it explicitly. A defaulted policy never
  activates availability: a snapshot without availability fact families stays
  dense. `ledgr_experiment_plan()`, `ledgr_valuation_summary()`, `summary()`
  and `print()` of a result mark a horizon of 5 sessions as the default; the
  marker follows the value, as for every plan assumption (Cut 12 LDG-3014).
- On availability-aware entry points a Date is a venue civil-session label,
  not UTC midnight. Opening, run, sweep, window and fold starts resolve to the
  unique declared session open; ends resolve to its close. Zero or multiple
  matching open sessions refuse. POSIXct inputs retain their exact instants.

<a id="contract-availability-units-and-universe"></a>
### Units, Price Basis And Universe

- ledgr accounts in split-adjusted share units: no split event acts on a
  position, so quantities, fills and marks are consistent only when bars are
  back-adjusted for splits. An availability-aware experiment on a snapshot
  sealed without a price basis runs on that model as an assumed default:
  identity keeps the basis undeclared (`data_identity$price_basis` and the
  run config's `data.price_basis` stay `NULL`), so it stays distinguishable
  from a declared `split_adjusted`, while every disclosure surface shows
  `split_adjusted` labeled as an assumed default. `distribution_adjusted` stays
  refused for execution. Under
  `split_adjusted`, level rules and integer sizing read back-adjusted price
  levels, so a quantity or price threshold before a split is in post-split
  units, and as-traded bars across a split would book a phantom loss.
  Corporate-action per-parent-unit terms use the same units:
  `gross_cash_per_parent_unit` and `recipient_quantity_per_parent_unit` are
  per split-adjusted parent share, and `recipient_quantity_per_parent_unit`
  counts recipient shares in the recipient's own split-adjusted units. A cash
  entitlement posts the cash term times the held split-adjusted quantity,
  and nothing converts at a split, so a cash amount declared per as-traded
  share before a later parent split must be divided by the parent's
  cumulative split factor from the entitlement to the bars' adjustment
  reference before it is supplied; supplied unconverted, it is credited that
  factor too large. A recipient ratio declared in as-traded shares is
  supplied as that ratio times the recipient's cumulative split factor over
  the same span, divided by the parent's (the term currently feeds only the
  reported estimated consideration, since quantity effects refuse). The
  source adapter owns both conversions (Cut 16 LDG-3068). The
  basis appears in `ledgr_experiment_plan()`, in
  `ledgr_corporate_action_summary()` (`price_basis`, `price_basis_default`)
  and in `print()` of a result, labeled declared or assumed default. A dense
  experiment may still run undeclared and shows `undeclared` (Cut 12 LDG-3012).
- A character-vector universe remains a fixed basket even when it consumes
  session, trading-status, or lifetime facts. Dynamic membership is explicit
  through `ledgr_universe_members(universe_id)` and must name a membership
  universe declared by the snapshot.
- Trading-status coverage is all or nothing. Without a trading-status family
  no instrument is restricted by status. Once the family holds any row, every
  instrument-time without an applicable status assertion is `status_unknown`:
  target-restricted, allowing hold or exit only (Cut 12 LDG-3009, audit
  S2-018).
- The history-treatment primitive does not change the universe or execution
  planes. It keeps structural expectedness, observed/raw missingness, input
  carry, calculation validity, output carry, readiness and estimator admission
  as distinct evidence. The public selectors (`instruments`, `na_action =
  "drop_instruments"`) and the boundary between estimation exclusion and
  target intent are bound under Pulse Data And Axis-Aligned Accessors and
  Strategy Outputs And Helper Values.
- Under the default history policy the treatment primitive carries an observed
  price level forward for at most five later expected sessions. Carry is causal
  and field-local: it never fills backward, never fabricates a leading value,
  never carries volume, retains the original source timestamp and age, and
  stops at lifetime or terminal barriers. The terminal state follows the shared
  lifetime resolver, so a later relisting clears it, but the carry barrier is
  sticky: once a terminal assertion is knowable at the cutoff, carry stays
  blocked from its boundary onward, even after a relisting (maintainer,
  2026-10-17). It exposes raw missingness and
  carried price levels separately; return- and volatility-family features
  consume no carried price (Availability-Aware Strict Features). Output carry is separately
  declared and disabled by default. A valid declared carry may make an
  instrument complete enough for the admission primitive; ledgr imposes no
  carried-share threshold.

<a id="contract-availability-disclosure"></a>
### Plan And Result Disclosure

- `ledgr_experiment_plan()` is read-only disclosure of effective availability,
  universe, valuation, and fact-family checks. It distinguishes disabled,
  omitted, declared, and assumption-backed families without executing a
  strategy or writing evidence. Its `assumption_reasons` keep assumed
  knowledge time separate from generated schedule content. Its `assumptions`
  table lists the declared valuation horizon, exhaustion choice, held
  terminal map entries in order and frozen fallback, marking each value that
  equals its constructor default.
- Results of an availability-aware run state what their point-in-time view
  rested on. `ledgr_valuation_summary()` records `universe_kind`
  (`"membership"` with `universe_id`, or `"fixed"`), `membership_declared`,
  and the applied fact families whose knowledge clocks or schedules were
  assumed (`assumption_backed_families`, `assumption_reasons`, read from the
  sealed fact headers as the plan reads them; a fixed basket applies no
  membership facts, so membership is never among them). Sealed
  corporate-action facts apply to every run, so `equity_corporate_actions`
  is among them, with reason `knowledge_assume_effective`, whenever its
  family holds a knowledge time filled known-when-effective (Cut 17
  LDG-3085). `print()` of a result
  shows one `Point in time:` line and `summary()` lists the same fields with
  the valuation evidence. A run whose applied facts are all evidenced shows no
  assumption label (Cut 12 LDG-3010).
- The valuation horizon is disclosed under its name: `print()` reads
  `valuation stale-mark horizon N sessions`, `summary()` reads
  `Stale-mark horizon`, and the plan and the experiment print a `Valuation:`
  line, each value marked `default` or `declared`. The experiment's history
  policy appears on the same surfaces as the price basis: a `History policy:`
  line in `print()` of an availability-aware result, a `History Policy`
  section in `summary()`, a `History:` line in `print()` of the experiment
  and of `ledgr_experiment_plan()`, whose `assumptions` table adds
  `history.price_carry`, `history.output_carry` and `history.segment_limit`.
  Each field is marked `default` when it equals the `ledgr_history_policy()`
  constructor default (omission and an explicit default share identity) and
  `declared` otherwise. Dense results, experiments and plans show no history
  policy (Cut 16 LDG-3081).

<a id="contract-availability-fact-inspection"></a>
### Fact Inspection And Calendar Adapters

- `ledgr_facts_history()` is a retrospective audit of supplied membership or
  session assertions. `ledgr_facts_resolve()` is a separate decision-cutoff
  view using only evidence both effective and knowable at its required `at`.
  Both accept normalized facts or a sealed snapshot and return eager classed
  lists with `rows`, supporting `evidence`, and serializable `metadata`.
  Snapshot calls ensure a current-process verified entry before reading fact
  rows, close only connections they opened, perform no persistent write, and
  invoke no callback. Explicit membership IDs retain true, false, and unknown
  states in request order; default resolution enumerates current members only
  and never discovers future members. Complete-set omission cites the set
  header rather than fabricating a negative fact. Neither result is a strategy
  context.
- Default fact-inspection prints are curated by family and operation while the
  complete programmatic evidence remains unchanged in `$rows` and `$evidence`.
  Membership history exposes evidence type, membership state, effective time,
  knowledge time, and completeness; membership resolution exposes state and
  reason at the printed cutoff. Session history exposes its civil date, state,
  opening, close, and knowledge time. Session resolution exposes the same
  session fields plus reason and a knowledge time derived only from applicable
  supporting evidence. That derived knowledge time is presentation-only and is
  disclosed as coming from `$evidence`, not as a value stored in `$rows`. Every
  print states the full row count and names omitted stored columns.
- `ledgr_facts_sessions_qlcal()` is an optional preparation adapter over an
  explicit qlcal calendar object. It materializes every civil date, applies
  complete per-date replacements, then delegates to
  `ledgr_facts_sessions()`. Hashed metadata records generated schedule basis,
  provider and version, calendar ID, declared hours, canonical overrides, and
  provenance, but no generation time or external pointer. qlcal remains in
  `Suggests`; materialized snapshots run, reopen, and inspect without it.

<a id="contract-availability-provider-and-timing"></a>
### Provider, Knowledge And Timing

- Availability-aware execution uses one internal provider with `facts`,
  `decision_view`, `execution_view` and `identity` operations; history is
  read only from the shared causal-history substrate. Its
  decision axis preserves declared member order for character-vector universes.
  For membership-rule universes, members are ordered by C-locale stable ID;
  nonzero held nonmembers then follow in the same stable-ID order. The provider
  resolves point-in-time evidence and shapes context only; target enforcement,
  risk, valuation economics, affordability, fills, and writes remain in the
  shared fold and its output handlers.
- Facts become applicable only after both effective time and knowledge time.
  Preparation refuses any membership, trading-status or lifetime fact whose
  knowledge time is missing with `ledgr_fact_knowledge_missing`, before any
  run, sweep, precompute, walk-forward or inspection side effect (Cut 16
  decision 23). A missing knowledge time is assumed for these families only
  under `knowledge = "assume_effective"`, which fills it from the effective
  time and never replaces a supplied one (Cut 16 decision 32); corporate
  actions follow the known-when-effective rule in Point-In-Time Facts.
  A higher-precedence assertion that is effective but not yet knowable cannot
  shadow a lower-precedence tie. Future facts may change snapshot and descendant
  identity but must not rewrite earlier context, errors, features, or supported
  telemetry.
- Availability-aware decisions occur at declared session closes. Each
  non-terminal decision resolves execution-time facts and records accepted
  fills and events at the next declared session opening. Membership remains
  frozen from the decision; the terminal decision has no execution opportunity.
  Dense execution declares no independent opening clock and is unchanged.
- New availability-aware configs record `execution_timing_version = 2L` in the
  availability payload. It participates in canonical config identity,
  walk-forward descendant identity, sweep execution assumptions, and candidate
  reproduction keys. Dense configs omit the field and retain their recorded
  dense timing model.
- Every stored active config carries execution-timing version 2 and the
  `availability_open_v2` convention. A missing or different version is
  refused; no timing convention is inferred from stored rows.
- The provider and history preparation share the existing family resolvers as
  the only precedence implementation. Prepared lifetime state, including its
  terminal label, is stored as flat bitemporal segments over separate
  observation and knowledge clocks; membership and trading-status state is
  counted as such segments for the segment guard and is not stored, its facts
  being held once, in the provider execution plan (Cut 16 decision 22).
  Adjacent segments merge only when state,
  winning fact and reason all match; active, inactive, unknown and conflicting
  membership remain distinct, while family declaration and set completeness
  remain separate metadata.
- Preparation counts segments for every instrument and family, with one
  canonical two-clock count for every membership shape (Cut 16 decision 24),
  so a family is refused at its limit whatever its clock layout. The default
  limit is `max(4 * fact_count, 16)`; a declared experiment-level
  `segment_limit` replaces it and participates in config identity. Exceeding
  the limit never truncates: it raises
  `ledgr_history_segment_limit_exceeded` with the instrument, family, fact and
  segment counts, ratio and limit. Reads may move forward, backward or out of
  order without mutating shared storage or changing their answers.

<a id="contract-availability-context-and-state"></a>
### Context Planes And Strategy State

- Availability-aware contexts expose `ctx$members` and universe-aligned
  `ctx$vec$member`, `held`, `target_restricted`,
  `target_restriction_reason`, `admissible`, `priced`, `mark_age`, `risk_mark`
  and `mark_source` planes. `risk_mark` is the close a holding is valued and
  risk-checked at (`NA` without a permissible or frozen mark) and
  `mark_source` names it: `current_close`, `stale_close`, `frozen_close`,
  `expired_close` or `missing`.
  The decision axis Daxis is `ctx$universe` in its existing order. The
  allocation membership M is Daxis in dense contexts and `ctx$members` in
  availability contexts; Daxis may additionally contain held nonmembers.
  Context-mode helpers keep the full Daxis and apply eligibility as
  "Decision Axis And Eligibility" in the Strategy Contract states. An empty Daxis still invokes the strategy and
  accepts a named numeric zero-length target while preserving portfolio-level
  state. Empty M with nonempty Daxis is a holdings-only decision, not an empty
  portfolio.
- Asset-scoped strategy state lives at `ctx$state_prev$asset_state` as a named
  list keyed by stable instrument ID. Entries outside the current axis are
  removed before callback, newly visible and re-entering IDs receive `list()`,
  returned keys outside the current axis fail closed with
  `ledgr_invalid_strategy_state`, and non-asset portfolio state remains under
  the existing replacement semantics.

<a id="contract-availability-targets"></a>
### Execution And Target Semantics

- Availability-aware execution is canonical R only. An explicit
  compiled spot-FIFO request fails before execution with
  `ledgr_compiled_availability_unsupported`; dense compiled behavior is
  unchanged.
- Availability-aware strategy targets may hold or exit a restricted ID.
  Unrestricted held nonmembers may also reduce without reversing sign.
  Post-risk targets must be zero or preserve the strategy target's sign while
  not increasing its magnitude. New or enlarged short exposure fails before
  any fill from that pulse is accepted; existing short quantities remain
  algebraically holdable and coverable without defining short financing.
- Availability-aware rebalance helpers initialize every ineligible axis ID,
  held nonmember or target-restricted member, at its current quantity,
  reserve its absolute marked exposure, and size only eligible IDs from
  accepted current closes. Helper weights and
  `equity_fraction` apply to allocatable capital A, where dense A is NAV and
  availability-aware A is
  `max(0, NAV - sum(abs(quantity * mark)))` over preserved ineligible holdings. A
  positive member weight targets
  `floor(weight * equity_fraction * A / close)`. For NAV 100, held-nonmember
  exposure 40 and member close 10, full member weight targets 6 shares and
  weight 0.6 targets 3; these are residual-budget weights, not total-NAV
  weights. An explicit zero member weight targets zero without consulting a
  sizing close. Raw full named numeric target vectors remain literal.
- Unpriced members (Cut 10, LDG-2973). In an availability-aware rebalance, an
  eligible member with a positive weight but no positive accepted current
  close is skipped for that rebalance: it keeps its current quantity, zero if
  unheld, and its weight is never redistributed. Let A be allocatable capital,
  V the sum of `weight * equity_fraction * A` over priced positive-weight
  members and E the sum of `abs(quantity * risk_mark)` over held skipped
  members. Priced targets are `floor(s * weight * equity_fraction * A / close)`
  with `s = 1` when `V + E <= A` and `s = max(0, A - E) / V` otherwise. A held
  skipped member, or a preserved holding, without a finite mark fails with
  `ledgr_target_sizing_unavailable`. Each skip is written to the fold's
  per-pulse note slot and recorded as the instrument's decision diagnostic
  with reason `sizing_unavailable`, whatever the strategy does to the returned
  target; memory sweep candidates and walk-forward training keep these rows in
  their in-memory diagnostics only. Dense runs keep the positive-weight
  warn-and-zero path, so dense and availability-aware runs now diverge on an
  unpriced member: dense targets zero with a warning, availability-aware skips.

<a id="contract-availability-valuation"></a>
### Valuation And Terminal Outcomes

- Fresh and policy-permitted stale closes may value holdings and feed target
  risk through the separate risk-mark plane. Stale marks never become observed
  closes or execution prices. Held marks age on the declared venue-open-session
  clock, including during known inactivity. An exhausted mark follows the
  declared exhaustion choice before the next decision.
- Terminal triggers are distinct (terminal-outcomes synthesis Sections 3.1 to
  3.4). A modeled terminal disposition is eligible only for a held instrument
  with an effective and knowable `known_inactive` lifetime row whose
  `terminal_event` is nonempty, when no supported settlement fact resolves it
  and the declared policy does not refuse it. An empty label is never
  normalized to a reason; it stops `terminal_settlement_unsupported`. Labels
  match map keys byte for byte; ledgr interprets no vendor synonym.
- Settlement evidence runs first. A supported settlement fact pre-empts every
  modeled terminal choice. A scheduled corporate-action disposition row is
  evidence: it disposes at the permissible mark, or at the frozen last close
  when the holding is frozen. Only an explicit `last_mark` default, which uses
  the last observed close of any age, or `refuse` changes that; `haircut`,
  `write_off` and `frozen_terminal_position` never apply to it. A scheduled
  row is a precedence barrier: when its settlement is refused or has no usable
  mark, the run stops typed and the lifetime path does not dispose that
  holding on that pulse.
- Valuation-horizon exhaustion proves no economic event. It never creates a
  fill, a disposition, cash or a quantity change. Under `exhausted = "refuse"`
  it stops `valuation_horizon_exhausted` with affected IDs, age and last
  reference, and no frozen state exists. Under `exhausted = "freeze"`, a
  holding whose last mark crosses `max_sessions` freezes: quantity and cash
  are unchanged, its last close stays the risk mark, `mark_source` becomes
  `frozen_close` while age keeps increasing, it becomes target-restricted with
  reason `valuation_frozen`, and the next traded bar restores
  `current_close`. A holding with no mark at all still stops
  `valuation_horizon_exhausted`. A holding covered by an effective
  `known_inactive` row never freezes: a labeled terminal resolves under the
  terminal policy and an unlabeled one stops.
- A terminal reached while frozen consults `frozen_terminal_position` only
  when the matched choice needs a currently permissible mark
  (`last_permissible` or `haircut`). An explicit `write_off`, `last_mark` or
  `refuse` choice applies directly, and `haircut` is never a frozen fallback.
  A choice whose mark does not exist stops `terminal_mark_unavailable` with the
  accepted prefix; it never aborts the run.

<a id="contract-availability-affordability"></a>
### Affordability And Reason Codes

- Active affordability evaluates accepted cash-generating reductions first,
  then cash-consuming fills in C-locale stable-ID order against the fixed
  `1e-8` tolerance. Rejected sales fund nothing. Accepted fills remain emitted
  in decision-axis order, and recorded cash must reconcile with the virtual
  ledger without implying an intrapulse cash floor.
- The durable availability reason-code vocabulary is closed for this schema.
  The table binds each exact token to its stage and public interpretation:

  | Exact reason token | Stage | Action / interpretation |
  | --- | --- | --- |
  | `decision_recorded` | decision | record an unrestricted decision |
  | `empty_public_domain` | decision | invoke the strategy on an empty axis; emit no targets |
  | `trading_halted` | decision restriction | allow hold or exit only |
  | `quotation_only` | decision restriction | allow hold or exit only |
  | `status_unknown` | decision restriction | allow hold or exit only |
  | `status_unknown_or_conflicting` | decision restriction | allow hold or exit only |
  | `lifetime_inactive` | decision restriction / terminal detail | allow hold or exit; never fabricate settlement |
  | `stale_mark_reduction` | risk | accept a reducing target evaluated with a permissible stale mark |
  | `stale_mark_pass_through` | risk | accept an unchanged target evaluated with a permissible stale mark |
  | `risk_mark_unavailable` | risk stop | preserve the accepted prefix and finalize incomplete |
  | `restricted_target` | target validation | raise the classed strategy-result failure |
  | `nonmember_exposure_increase` | target validation | raise the classed strategy-result failure |
  | `post_risk_inadmissible` | post-risk validation | raise the classed risk failure |
  | `short_exposure_unsupported` | target validation | raise the classed strategy-result failure |
  | `insufficient_cash` | execution | reject the cash-consuming fill |
  | `execution_bar_missing` | execution | record no fill; never carry a standing order |
  | `membership_changed_before_execution` | execution diagnostic | report the change without making membership an execution gate |
  | `final_pulse_no_execution` | execution | record no fill because no later execution pulse exists |
  | `affordability_reconciled` | reconciliation | apply accepted fills and record reconciliation |
  | `affordability_reconciliation_failed` | reconciliation stop | preserve the accepted prefix and finalize incomplete |
  | `valuation_horizon_exhausted` | valuation stop | under `exhausted = "refuse"`, or for a holding with no mark at all, preserve the accepted prefix and finalize incomplete |
  | `valuation_frozen` | valuation / restriction | under `exhausted = "freeze"`, carry the holding at its last close; hold or exit only, no transaction |
  | `valuation_freeze_exited` | valuation diagnostic | record that a frozen holding resumed, was exited or was disposed |
  | `terminal_disposition` | valuation | post one modeled `DISPOSITION` before the strategy decision |
  | `terminal_settlement_unsupported` | valuation stop | unlabeled or refused terminal; preserve the holding and never fabricate cash settlement |
  | `terminal_mark_unavailable` | valuation stop | the terminal choice needs a mark that does not exist; preserve the accepted prefix and finalize incomplete |
  | `corporate_action_cash_refused` | valuation stop | the policy refuses a held corporate-action cash settlement (`cash_amount` or `cash_posting = "refuse"`); post nothing, preserve the accepted prefix and finalize incomplete (Cut 12 LDG-2997) |
  | `corporate_action_quantity_refused` | valuation stop | the policy refuses a held quantity effect or unmodeled fact (`unsupported_quantity = "refuse"`); preserve the accepted prefix and finalize incomplete (Cut 12 LDG-2997) |
  | `fold_exception` | error | finalize failed after the fold transaction rolls back |

  An uncomplicated accepted fill has an empty reason code.

## Persistence Contract

<a id="contract-persistence-connections"></a>
### Connections And Cross-Connection Durability

- ledgr-owned DuckDB drivers explicitly use session-local extension and secret
  storage when the installed DuckDB exposes that control. This avoids shared-home
  startup notices on affected versions without suppressing package messages,
  warnings, errors, or rendered example output. Older DuckDB versions retain their
  native driver behavior.
- Runner-owned DuckDB write connections must issue `CHECKPOINT` before
  disconnect/shutdown when a later fresh connection is expected to read the
  same database file.
- Cross-connection read-back is part of the persistence contract: completed
  runs and their `ledger_events` and `equity_curve` rows must be visible from a
  newly opened connection. Runtime feature values are ephemeral and are not a
  durable result table.

<a id="contract-persistence-current-format"></a>
### Current Store Format

- Experiment-store schema 123 is the sole current store schema; it stores no
  `walk_forward_folds.hydration_start_utc` column, and its sealed
  corporate-action provenance distinguishes assumed from evidenced knowledge
  (Cut 17 LDG-3085). Schema-120, schema-121 and schema-122 stores are older
  stores. One opener and
  one gate compare its version and canonical format fingerprint before any
  package-owned persistent read or write. `mode = "create"` may initialize an
  empty file transactionally with the marker written last; every non-empty
  older, newer, unmarked, invalid or fingerprint-mismatched store refuses with
  `ledgr_store_rebuild_required`. The current DDL is defined once, validation
  compares normalized DuckDB catalogues, and no migration path is supported
  before the first CRAN release.
- Runtime schema creation and validation must not write data rows in ledgr
  tables. They may create current DDL and inspect DuckDB metadata to verify
  table shape and constraints, but must not prove constraints by writing
  invalid probe rows into ledgr tables.
  Constraint enforcement belongs in isolated tests with disposable database
  connections.
- Current stores carry normalized point-in-time fact and quarantine evidence.
  Existing sealed snapshots retain their stored hashes and are never resealed
  in place.

<a id="contract-persistence-fold-evidence"></a>
### Fold Evidence And Early Exit

- Availability-aware direct runs persist one decision trace row per invoked
  axis ID plus ordered risk, execution, reconciliation, and stop evidence.
  Expected valuation exhaustion, unavailable risk marks, unsupported terminal
  settlement, and reconciliation stops return through the normal fold
  transaction and finalize as `INCOMPLETE`, preserving only accepted prefix
  economics. Unexpected fold exceptions remain `FAILED`, roll back the fold
  transaction, and record error diagnostics only after that rollback.
  Deliberately interrupted `RUNNING` invocations retain their decision trace;
  resumed invocations append rather than replace those diagnostic rows.
- Early exit (Cut 10, LDG-2975). Once a run row exists, an invocation that
  ends by an error or an interrupt condition without having written a terminal
  status records the row `FAILED`, with the condition's message or
  `Run interrupted before completion.` as `error_msg`, and the condition still
  reaches the caller. This applies to rows that are `CREATED`, `RUNNING` or
  already `FAILED` from an earlier attempt; `DONE` and `INCOMPLETE` rows are
  never changed. The `ledgr.interrupt` soft stop still returns normally and
  leaves the row `RUNNING`. A `FAILED` row resumes like any non-`DONE` row with
  a matching configuration. A resumed row that has no ledger event yet (it
  stopped before its opening append) posts its configured opening positions
  before execution, as a first attempt does (Cut 11 close-review correction).
  A resumed run binds each corporate-action entitlement at or before its
  restart pulse from the ledger exactly as the fresh fold binds it: the
  position after every event at or before the pulse before the entitlement
  pulse, so a fill executed at the entitlement session's open is not
  entitled; an entitlement on the run's first pulse binds the opening
  positions. The acquisition and spin-off composition in
  `ledgr_corporate_action_summary()` counts the same way and, like the fold,
  binds no fact entitled before the run's first pulse or after the last pulse
  it processed (an INCOMPLETE run's stop pulse, whose facts the fold binds
  before it stops) (Cut 12 LDG-2993). An
  availability run whose invocation values no pulse (a stop on its first
  pulse, a stop on the first pulse of a resume, or a resume after its last
  pulse) still finalizes through its equity prefix: a first-pulse stop stores
  no equity rows and its run opens and reruns; a resumed run keeps the
  prefix, achieved end and last execution its earlier invocations committed,
  so its equity, completion row, ledger and diagnostics equal the
  uninterrupted run's (Cut 12 LDG-2994). An interrupt inside the durable fold
  transaction
  rolls the transaction back and is then re-raised, so the invocation ends
  `FAILED` rather than finalizing the rolled-back pulses as a completed run.
- Pulse-level fill staging does not create a partial-flush persistence promise.
  The fold transaction remains the durable atomicity boundary: an unexpected
  exception before or after a pulse flush rolls back all fill rows from that
  invocation, and a failed in-memory sweep candidate exposes none of its
  staged rows to another candidate.

<a id="contract-persistence-completion-evidence"></a>
### Completion And Resume Evidence

- Sweep-candidate and walk-forward score evidence carries nullable canonical
  `completion_json` and admits `INCOMPLETE` on those rows. Saved-sweep schema 5
  and candidate, sweep, run, and walk-forward identity formats remain
  distinct.
- Availability-aware `DONE` and `INCOMPLETE` completion rows are terminal
  evidence. Repeating an achieved `INCOMPLETE` run ID verifies identity and
  validates the exact stored equity timestamp prefix and recorded stop
  diagnostic before returning without invoking strategy code, deleting a
  tail, changing status, or rewriting projections. A `RUNNING` or `FAILED`
  row with valid committed completion evidence performs finalization only and
  commits the intended terminal status without replaying the fold or
  duplicating evidence. Malformed or inconsistent terminal evidence fails
  closed with `ledgr_run_terminal_evidence_invalid`.
- Availability-aware sweep-candidate and walk-forward score
  `completion_json` records `affected_instrument_ids` as an array and an
  `assumptions` object holding the five valuation flags. Freeze and terminal
  state is never stored as separate accounting state. Freeze entry and exit
  are diagnostics; resume and replay rebuild the frozen set from sealed bars,
  facts, policy identity and committed ledger events. Memory, durable reopen
  and an interrupted resume therefore agree on events, equity, diagnostics
  and summary fields.

<a id="contract-persistence-durability"></a>
### Constraint Metadata And Artifact Durability

- DuckDB constraint metadata is an introspection contract. If a runtime
  validator or create-side compatibility check cannot interpret expected
  constraint metadata, it must fail loudly rather than mutate user rows or
  silently recreate durable tables.
- Completed run artifacts are durable when `ledgr_run()` returns. User-facing
  `close(bt)` and `ledgr_snapshot_close(snapshot)` calls are resource-management
  tools for long sessions and explicit opens; documentation must not frame them
  as data-loss prevention. Public result readers are eager and do not require a
  cursor cleanup lifecycle.
- A durable `ledgr_backtest` handle is a locator identified by its `run_id` and
  `db_path`. `close(bt)` releases resources owned by that handle without
  deleting evidence or changing locator identity. Later reads may use the
  closed handle, or a new session may reopen the snapshot and completed run
  with `ledgr_snapshot_open()` and `ledgr_run_open()` without executing the
  strategy, recomputing fills, or writing persistent rows.
- User-facing metadata mutations such as run labels, archives, and tags promise
  immediate fresh-connection visibility. They must use strict checkpointing or
  an equivalent durable-read guarantee before returning.
- Best-effort checkpointing is reserved for cleanup paths where a secondary
  checkpoint error would mask the primary run or cleanup error. It must not be
  used as the only durability mechanism for public mutating APIs.

<a id="contract-persistence-snapshot-workflows"></a>
### Snapshot Workflows

- CSV snapshot workflows must survive close and reopen:
  `ledgr_snapshot_from_csv()` followed by `ledgr_snapshot_open(verify = TRUE)`
  must preserve hash verification, seal-time metadata, and subsequent
  `ledgr_run()` execution. `ledgr_snapshot_create()` and
  `ledgr_snapshot_seal()` remain public and keep their CREATED and SEALED
  status rules.
- Public experiment-store APIs are snapshot-first. A `db_path` appears
  in normal workflows only at snapshot creation or snapshot loading.

<a id="contract-persistence-run-discovery"></a>
### Run Discovery And Summaries

- `ledgr_run_list()` and `ledgr_run_info()` are read-only experiment-store
  discovery APIs. In a current store, row absence for unfinished telemetry is
  missing/`NA`, not corruption.
- `ledgr_run_list()` appends the recorded completion projection in this order:
  `completion_evidence_available`, `completion_status`,
  `requested_start_utc`, `requested_end_utc`, `achieved_start_utc`,
  `achieved_end_utc`, `stop_reason`, `last_fully_valued_ts_utc`,
  `last_executed_ts_utc`, `complete_performance`, and
  `affected_instrument_ids`, then the valuation flags `valuation_state`,
  `frozen_instrument_sessions`, `max_frozen_equity_weight`,
  `frozen_at_end_value`, and `assumed_terminal_outcomes`, read from stored
  diagnostics in one grouped query. Status does not gate real completion evidence,
  including evidence retained by a `FAILED` run. Missing evidence stays typed
  unknown. The affected-ID list column distinguishes unavailable, known-empty,
  and known sets. Inventory printing places completion beside raw metrics and
  labels an `INCOMPLETE` row's metrics as achieved-prefix evidence only.
- `summary.ledgr_backtest()` follows recorded completion evidence rather than
  run status. When complete performance is false, the metrics heading names
  the achieved window, total return and maximum drawdown remain visible as
  prefix-only evidence, and annualized return, annualized volatility, and
  Sharpe ratio are withheld with an explanation. Complete performance keeps
  the established metric content and order. `ledgr_compute_metrics()` follows
  the same completion evidence: those three fields are `NA` with a `withheld`
  attribute and print as withheld, and total return and maximum drawdown stay
  (Cut 12 LDG-3003). Walk-forward test-window metrics inherit the rule.
- `print.ledgr_run_info()` presents status and any recorded completion evidence
  before identity and telemetry fields without removing any field from the
  record.
- The backtest summary labels `n_trades` as `Closed Trades`, because that
  statistic counts closed trade rows rather than fill rows. The computation is
  unchanged.
- `ledgr_run_info()` exposes the committed run's `risk_chain_hash` by reading
  recorded config identity. Current configs always carry the field; inspection
  must not infer a plan, substitute current experiment state, add a top-level
  `risk_plan_json` field, execute recovered strategy code, or write persistent
  rows.

<a id="contract-persistence-telemetry-and-recovery"></a>
### Telemetry And Recovery

- Completed and failed runs persist compact `run_telemetry`:
  `status`, `execution_mode`, elapsed seconds, and pulse count. Detailed per-component telemetry remains
  session-scoped through `ledgr_backtest_bench()`.
- A failure after the fold has committed but before equity and `DONE`
  finalization records `FAILED` with the original error and preserves committed
  ledger and strategy-state evidence. Resuming the same run identity
  after that failure performs finalization only: it must not delete or duplicate
  committed fold rows, and its ordered economic evidence must equal a clean run.
  Best-effort failed telemetry must not mask the original error; successful
  `DONE` finalization precedes non-transactional telemetry persistence.
- Infrastructure-owned temporary names used by snapshot ingestion and eager
  result reads must preserve the caller's `.Random.seed`, including its
  absence, and must not change the caller's next random draw.

<a id="contract-persistence-run-lifecycle"></a>
### Run Open And Metadata Lifecycle

- `ledgr_run_open()` returns a `ledgr_backtest` handle for terminal `DONE` and
  availability-aware `INCOMPLETE` runs. Opening validates incomplete bounds
  and must not execute strategy code, recompute fills, or mutate persistent
  run artifacts.
- `ledgr_run_label()` and `ledgr_run_archive()` mutate only run metadata.
  They must never rename `run_id`, delete artifacts, or change experiment
  identity hashes. Archive is non-destructive and idempotent.
- Run comparison, run tags, and strategy-source recovery are available. Hard
  delete is not available and must not be documented as such.

## Canonical JSON Contract

<a id="contract-json-durable-bytes"></a>
### Durable Canonical Bytes

- Canonical JSON is produced by `canonical_json()`.
- Named vectors and named lists are sorted by key with radix ordering before
  serialization, independent of `LC_COLLATE`.
- Serialization uses `yyjsonr::write_json_str()` with
  `yyjsonr::opts_write_json(pretty = FALSE, auto_unbox = TRUE,
  digits = -1L, null = "null", num_specials = "null")`.
- The canonical JSON byte format is version 2.
  Whole-number doubles serialize with a decimal suffix, full-precision doubles
  keep yyjsonr's shortest round-trippable representation, and exponent notation
  follows the current yyjsonr surface.
- The current canonical-identity ordering rule is recorded by
  `ledgr_canonical_json_rule_version = 1L` in the store format fingerprint.
  Stores written without that rule marker are rebuilt; there is no
  compatibility fallback.
- Config hashes, strategy-state JSON, snapshot metadata JSON, and ledger
  `meta_json` must use this canonical path when deterministic identity matters.

<a id="contract-json-session-local-keys"></a>
### Session-Local Keys

- Session-local, non-persisted lookup keys are not durable identity artifacts
  and are not required to use canonical JSON or cryptographic hashes. They must
  remain deterministic and unambiguous within the session, and this exemption
  must not weaken snapshot hashes, config hashes, strategy-state JSON,
  snapshot metadata JSON, ledger `meta_json`, or any other persisted provenance
  surface.

<a id="contract-json-feature-map-objects"></a>
### Feature-Map Authoring Objects

- Feature-map authoring objects are wrappers around existing indicator
  definitions. Equivalent feature maps and plain feature lists must preserve
  feature-related config identity for equivalent indicator definitions unless a
  later contract deliberately changes run identity semantics.

## Strategy Contract

<a id="contract-strategy-outputs"></a>
### Strategy Outputs And Helper Values

- Strategy output is a full named numeric target vector, a `ledgr_target`, or a
  list containing `targets`.
- History estimation exclusion is not a target. An instrument that
  `ledgr_history_frame(na_action = "drop_instruments")` excludes from an
  estimator sample still receives a target like every decision-axis
  instrument; the exclusion alone creates no zero target, liquidation,
  position change or fill. Keeping, exiting or refusing a held excluded
  instrument is the strategy's separate target choice.
- Names must exactly match `ctx$universe`; missing, extra, duplicate, unnamed,
  or non-finite targets fail with `ledgr_invalid_strategy_result`.
- Target values are desired instrument quantities after the next fill, not
  portfolio weights, order sizes, or signals. `ledgr_target` is a thin wrapper
  around those same target quantities and is unwrapped before execution.
- Ordinary target inspection uses the numeric-vector contract:
  `target[[instrument_id]]` extracts one named quantity and `c(target)` returns
  the full named numeric vector. No separate target-values reader is required.
- Strategy helper pipelines may use `ledgr_signal`, `ledgr_selection`, and
  `ledgr_weights` as intermediate value types, but those objects are invalid
  direct strategy outputs. Helper pipelines must terminate in `ledgr_target` or
  a plain full named numeric target vector.
- `ledgr_signal()` and `ledgr_selection()` accept either their established
  value forms or a `ledgr_pulse_context` first argument. In context mode,
  signals require named `values`; selections accept no payload, named `ids`, or
  named `where`. Supplying `universe`, combining payloads, passing explicit
  `NULL`, or supplying a context payload in value mode fails with
  `ledgr_invalid_strategy_helper`. Malformed contexts fail closed with the same
  family rather than falling through to value mode.
- Context payloads, context-mode results and eligibility follow
  "Decision Axis And Eligibility" below. Numeric values admit finite numbers
  and missing scores but reject infinity anywhere. Context-mode
  `missing = "exclude"` treats a missing decision on an eligible ID as not
  selected, which means a later rebalance targets that held member to zero
  rather than preserving it. Type, length, name, coverage, score and ID
  failures use `ledgr_invalid_strategy_type`; a selected or weighted
  ineligible ID in a target helper uses `ledgr_invalid_strategy_helper`.
- The four helper value types admit an explicit `character()` universe.
  Zero-length numeric and logical values receive `character()` names, empty
  signals and targets retain their existing classes, and final target
  completeness remains strict whenever the allowed axis is nonempty.
- Helper weights are public authoring helpers only. They do not alter
  the execution contract, and target constructors must reject negative weights
  or leverage until explicit short-selling and leverage semantics are specified.
- The reference helper pipeline is deliberately small:
  `ledgr_signal_return()` reads already-registered `return_<lookback>` features,
  `ledgr_select_top_n()` ignores missing signals and breaks ties by instrument ID
  in C-locale (radix) order, the provider's id order, whatever the session
  collation (Cut 12 LDG-3002),
  `ledgr_weight_equal()` creates long-only equal weights, and `ledgr_target_rebalance()`
  converts weights into full-universe `ledgr_target` quantities using
  decision-time equity and close prices. These helpers must not auto-register
  indicators, silently normalize weights, or add a second execution path.
- The helper composition contract is
  `signal -> selection -> weights -> target quantities -> existing execution
  path`. A fixed-quantity rule may skip the weights: `ledgr_target_quantity()`
  maps `selection -> target quantities`, giving each selected eligible ID
  the same non-negative quantity, every other eligible ID zero, and every
  ineligible decision-axis ID its current quantity, as
  `ledgr_target_rebalance()` does. It performs no sizing and needs no price. Signal, selection, and weight objects are research objects with origin
  metadata; `ledgr_target` is the only helper value type that may unwrap into
  executable target quantities.
- `ledgr_target_rebalance()` floors share quantities to whole numbers after sizing
  long-only positive weights from allocatable capital and current close prices.
  A validated zero member weight becomes a zero target without a price lookup.
  IDs named in `keep` preserve their current quantities and reserve their
  absolute marked exposure exactly once; weights and `equity_fraction` apply
  to the remaining capital. A kept ID must not also occur in the weights.
  Dense sizing without `keep` does not require a position plane. Availability
  sizing or an explicit `keep` requires one position per decision-axis ID and
  fails with `ledgr_invalid_strategy_helper` when that plane is absent.
  It must not silently create fractional share targets, and ranking, leverage,
  negative-weight and final-target rules are unchanged.
- `ledgr_signal_feature()` reads one active alias or registered feature ID over
  the decision axis through the same alias-first resolver as the strategy
  context. It records the literal author-supplied name as origin.
  `ledgr_signal_return()` is the exact-ID specialization for one concrete
  return lookback; a parameterized return map is read through its stable alias
  with `ledgr_signal_feature()`.
  Neither masks: ineligible IDs keep their raw score, and eligibility travels
  in the signal's `eligible` attribute, so ineligible is never reported as
  missing. `ledgr_select_top_n()` ranks only eligible, non-missing scores with
  its stable tie policy. A short ranking warns by default, counting eligible
  usable scores only; `partial = "allow"` explicitly accepts fewer than `n`
  usable scores without changing the selection.

<a id="contract-strategy-decision-axis"></a>
### Decision Axis And Eligibility

One decision axis and one eligibility plane hold in dense and
availability-aware contexts alike, so a strategy written as named-vector
manipulation, or as a helper pipeline, means the same thing in both.

- **Eligibility.** An ID is eligible when it is a member and not
  target-restricted. `ctx$vec$admissible` is that plane in every context:
  availability folds, dense folds, `ledgr_pulse_snapshot()` and interactive
  contexts. Dense contexts expose `ctx$members` as `ctx$universe`, and
  `member` (all `TRUE`), `target_restricted` (all `FALSE`),
  `target_restriction_reason` (all `""`) and `admissible` (all `TRUE`),
  allocated once per run and reused on every pulse. No second eligibility
  plane exists: a context helper never rebuilds eligibility from
  `ctx$members`. An availability context without a logical, axis-length,
  non-missing `admissible` plane, or any context whose plane is present but
  malformed, fails with `ledgr_invalid_strategy_helper`
  (`ledgr_invalid_strategy_result` in the `ledgr_signal_strategy()` wrapper);
  a dense context without the plane treats every ID as eligible.
  `ctx$tradable()` stays a character vector of IDs that also requires a
  price.
- **Context payloads.** An unnamed `values`, `where` or warmup payload has
  exactly length(Daxis) and aligns by position. A named payload uses unique
  Daxis IDs in any order and covers every eligible ID; an uncovered ineligible
  ID is `NA`. Unnamed input of any other length, a named ID off the axis, and a
  classed, list, factor or dimensioned payload fail with
  `ledgr_invalid_strategy_type` in both kinds of run. The entrance rules are
  unchanged: `universe` in context mode, an unknown, duplicated, combined or
  `NULL` payload, a missing required payload and an invalid `missing` value
  fail with `ledgr_invalid_strategy_helper`.
- **Signals.** `ledgr_signal_feature()`, `ledgr_signal_return()` and
  `ledgr_signal(ctx, values = ...)` return one value per Daxis ID in
  `ctx$universe` order, with the raw value for every ID including ineligible
  ones, and carry `ctx$vec$admissible` as the `eligible` attribute. The origin
  is the feature ID, or the supplied `origin`. Arithmetic on a signal keeps
  its class and `eligible` attribute. Comparison, subsetting, `rank()` and
  `c()` return plain named vectors without them. Helpers that take `ctx`
  derive eligibility from `ctx`, never from the attribute. Only
  `ledgr_select_top_n()` reads the attribute, and it refuses anything that is
  not a `ledgr_signal`. A transformed vector becomes a signal again through
  `ledgr_signal(ctx, values = ...)`.
- **Selections and rankings.** A context selection covers the axis and is
  `FALSE` for every ineligible ID, whatever the payload: no payload selects
  every eligible ID, `where` decides eligible IDs only, and `ids` naming an
  ineligible axis ID leave it unselected. The `missing` policy covers
  eligible IDs only. `ledgr_select_top_n()` ranks eligible, non-missing scores
  with its stable tie policy, counts only those in its short-ranking warning,
  and returns a selection over the signal's axis; with nothing usable it
  returns an all-`FALSE` `ledgr_empty_selection` over that axis. Its `n` and
  `partial` validation is unchanged.
- **Target helpers.** `ledgr_target_rebalance()`, `ledgr_target_quantity()`
  and `ledgr_signal_strategy()` keep every ineligible axis ID at its current
  quantity, whether a held nonmember or a target-restricted member, and
  rebalancing reserves its absolute marked exposure exactly once, `keep`
  included. They size or assign eligible IDs only. A selection that selects,
  or weights that weight, an ineligible ID fail with
  `ledgr_invalid_strategy_helper`; unselected ineligible names are accepted.
  `ledgr_signal_strategy()` requires a signal for every eligible ID, may omit
  or include ineligible ones, and fails with `ledgr_invalid_strategy_result`
  otherwise. A frozen holding is a target-restricted member: the helpers keep
  its quantity and reserve its absolute exposure at its frozen risk mark, so
  reported equity includes that value but allocation never spends it a second
  time. No second equity basis exists. Hand-written targets may hold a frozen
  quantity or request zero; a zero target is an attempted exit, and no order
  is queued or filled until an execution bar exists.
- **Literal targets and today's behaviour.** Raw named targets,
  `ledgr_target()`, `ctx$flat()` and `ctx$hold()` are literal. A strategy
  states intent; ledgr's later steps judge and execute it (Cut 22 decision
  4). The current consequences are these. Every target is attempted at the
  next open and is never queued. A rule starting from `ctx$flat()` sells a
  departed holding at
  the next open. A zero target for a halted holding is recorded as not
  executed (`trading_halted`) and discarded; the holding is sold only if the
  strategy states zero again on a pulse whose next open can fill. A rule
  starting from `ctx$flat()` does that on every pulse, so it sells at the first
  open after the halt; a rule that states zero once during the halt does not
  sell. Increasing a held nonmember fails with
  `ledgr_nonmember_exposure_increase`. Changing a restricted holding other
  than holding or exiting fails with `ledgr_restricted_target`. Exiting or
  reducing an ineligible holding is a valid target, so the validators do not
  catch a hand-built rule that does so without meaning to; that is what
  masking with `ctx$vec$admissible` is for.
- **Empty axis.** Every context helper returns a zero-length named result.
  `ledgr_signal_strategy()` still invokes its function and returns a named
  zero-length target; a zero-length signal is valid whenever no ID is
  eligible.
- **Warmup.** `ledgr_passed_warmup(ctx, values)` takes a context payload or a
  signal (aligned by its names). It returns `TRUE` when every eligible value
  is non-missing, and `TRUE` when no ID is eligible. Non-numeric `values`, or
  `values` without a context, fail with `ledgr_invalid_warmup_input`. The
  one-argument form is unchanged, including its zero-length failure.
- **Dense results.** Every dense ID is eligible, so dense results of the
  existing helper pipelines do not change.
- **History selection.** `ledgr_history_frame()` selects from this plane at
  its cutoff. `instruments = "admissible"` requests the `ctx$universe` IDs
  whose `ctx$vec$admissible` is `TRUE`, `"decision_axis"` requests every
  `ctx$universe` ID, and an explicit vector requests known instrument IDs in
  its own order. An explicit ID is never dropped for current
  inadmissibility; its selection row records `admissible` and an
  `admissibility_reason` (the target-restriction reason, `not_member` or
  `not_on_decision_axis`). Membership at a past session does not by itself
  remove an otherwise admissible observation from the returned history.

Domains, for a decision axis `BBB, CCC, AAA` where `BBB` is a halted member
and `AAA` a held nonmember, each holding 5:

| Object | Type | Domain | Names | Ineligible entries | Example |
|---|---|---|---|---|---|
| `ctx$vec` planes | numeric, logical or character | Daxis | unnamed, positional | marked by `admissible` | `ctx$vec$admissible` is `FALSE, TRUE, FALSE` |
| `ctx$members` | character IDs | allocation membership M | not applicable | not applicable | `BBB, CCC`; dense: `ctx$universe` |
| context signals | `ledgr_signal` (numeric) | Daxis | named | raw value; `eligible` attribute | `ledgr_signal_return(ctx, 1)` is `BBB=0.02 CCC=-0.01 AAA=0.01` |
| context selections | `ledgr_selection` (logical) | Daxis | named | always `FALSE` | `ledgr_selection(ctx)` is `BBB=FALSE CCC=TRUE AAA=FALSE` |
| rankings | `ledgr_selection` (logical) | the signal's Daxis | named | never selected or counted | `ledgr_select_top_n(signal, 2)` selects `CCC` and warns `ledgr_partial_selection` |
| weights | `ledgr_weights` (numeric) | selected IDs | named | a weight on one fails | `ledgr_weight_equal()` gives `CCC=1` |
| helper targets | `ledgr_target` (numeric) | Daxis | named | current quantity | `ledgr_selection(ctx) \|> ledgr_target_quantity(ctx, 10)` is `BBB=5 CCC=10 AAA=5` |
| raw targets, `ctx$flat()`, `ctx$hold()` | named numeric | Daxis | named | literal | `ctx$flat()` sells `AAA` at the next open |
| value-mode signals, selections, weights | their class | their `universe` | named | none: every entry is eligible | unchanged |

<a id="contract-strategy-feature-maps"></a>
### Feature Maps

- Feature maps are authoring UX over the existing feature registry and pulse
  context. They may make feature registration and pulse-time lookup easier, but
  they must not add a second strategy path: strategies still return full named
  numeric target vectors, `ledgr_target`, or `list(targets = ...)`.
- `ledgr_feature_map()` may bundle aliases, indicator objects, and resolved
  feature IDs for registration and lookup. Existing
  `ledgr_experiment(features = list(...))` workflows remain valid.
- Feature-map aliases are readable names for strategy authors. They are not
  roles, selectors, recipes-style preprocessing groups, or execution
  instructions.
- `ledgr_passed_warmup()` is a guard used inside strategy logic after feature values
  have been read. It is not a helper-pipeline transformation and must not imply
  a second signal/selection/weight/target execution path.

<a id="contract-strategy-supported-surface"></a>
### Supported Strategy Surface

- ledgr does not define a supported broker-style short-selling contract.
  Negative target quantities are outside the supported public workflow until
  explicit shorting semantics are specified.
- Raw signal strings such as `"LONG"` and `"FLAT"` are invalid core outputs.
  `ledgr_signal_strategy()` is an explicit convenience wrapper that maps signals
  to normal targets before validation. It maps eligible IDs only and holds
  every ineligible ID at its current quantity (see "Decision Axis And
  Eligibility").
- Functional strategies and configured strategy-list compatibility surfaces use
  the same target validator. Legacy R6 strategy objects are not reauthorized by
  this contract.
- Public experiment workflows accept only functional strategies with
  signature `function(ctx, params)`. `params` defaults to `list()` and is passed
  as the second argument. `ctx$params` is not part of the public contract.

<a id="contract-strategy-reproducibility"></a>
### Reproducibility And Preflight

- Strategy reproducibility is tiered:
  - Tier 1: self-contained `function(ctx, params)` style logic with explicit
    parameters and no unresolved external objects.
  - Tier 2: logic that can be inspected but not fully replayed without external
    context, including package-qualified calls outside the active R
    distribution and resolved immutable non-function closure objects. Tier 2 is allowed,
    but users own package installation, package version parity, and non-ledgr
    environment management.
  - Tier 3: environment-dependent logic whose execution identity cannot be
    recovered from stored metadata.
- Strategy preflight classifies functional strategies before execution. Tier 3
  is a classed error in ordinary runs and sweep mode. Current public APIs do not
  include a force override; Tier 3 must not be accepted silently or downgraded
  to warning-only behavior. If a later explicit override is added, forced Tier 3
  runs must still record `tier_3` in provenance.
- Base R references are Tier 1-compatible when they are ordinary function calls
  or constants and do not introduce hidden mutable state. This classification is
  based on packages distributed with the active R installation, discovered from
  package metadata such as `Priority: base` or `Priority: recommended`, not from
  a hand-maintained package-name allowlist.
- Package-qualified calls to packages outside the active R distribution, such
  as `pkg::fn()`, and resolved immutable non-function closure objects are
  Tier 2-compatible. Unqualified user helper calls such as `my_helper(ctx)` are
  Tier 3 unless a later dependency-declaration contract records them
  explicitly.
- Forbidden nondeterministic calls that cannot be represented safely in
  execution identity, including `Sys.time()`, `Sys.Date()`, `date()`, `get()`,
  `eval()`, `assign()`, and `Sys.getenv()`, are Tier 3 in preflight and must
  fail before `ledgr_run()` or `ledgr_sweep()` creates execution artifacts.
- A strategy reads the pulse context only through its public fields, its
  public functions and exported ledgr helpers. Strategy preflight is a
  best-effort static check, not a sandbox (Cut 16 decision 30). It refuses as
  Tier 3, before any run, sweep or walk-forward side effect, accidental and
  common deliberate access to private context carriers, non-exported ledgr
  internals and environment-reaching functions (Cut 16 LDG-3072):
  - a `$`, `@`, `[[` or `[` extraction, on any object, of a literal private
    context field name (`ledgr_pulse_context_private_fields()`: `.history`,
    `.pulse_lookup`, `.feature_vector`, `.feature_table_current`, `.notes`,
    `.positions`, `.safety_state`);
  - a field that holds prepared data beyond the pulse (`.history`,
    `.pulse_lookup`, `.feature_vector`, `.feature_table_current`) named
    anywhere, as a string or as a symbol, including inside `quote()`,
    `bquote()` or `substitute()`;
  - a non-exported ledgr object, named as a symbol (also inside `quote()`)
    other than as the member after `$` or `@` and other than a name the
    strategy binds itself, or referenced as `ledgr:::name`; only the
    exported namespace is Tier 1-compatible;
  - an environment-reaching function: closure, call, frame and namespace
    access (`environment()`, `parent.frame()`, the `sys.*()` frame
    functions, `asNamespace()`, `getFromNamespace()`, `get0()`, `mget()` and
    their `rlang` equivalents) and rebuilding a function inside an existing
    enclosure (`body<-`, `formals<-`, `as.function()`, `unserialize()`,
    rlang `fn_body<-` and `fn_fmls<-`), when it is called (unqualified,
    including through an attached package, or qualified), assigned through
    (`body(f) <-`, `base::body(f) <-`, `rlang::fn_body(f) <-`), passed as a
    value, extracted as a member and called directly
    (`baseenv()$environment(...)`), or named as a string or member in the
    function slot of a functional (`FUN`, `f` or `what`: `lapply(x,
    "environment")`, `match.fun("environment")`, `do.call("environment",
    ...)`);
  - `substitute()` with an environment or list, and `bquote()` with
    `where`, by name or by position.

  An ordinary name that is data keeps its tier: a dot-prefixed name that is
  not a private context field (a model's `$.fitted`, a `.pred` column), a
  field, column or label called `environment` (also as data handed to a
  functional, such as `tapply(d$environment, ...)` or `sapply(s, "[[",
  "environment")`), and a strategy's own name that happens to equal a ledgr
  internal (a local `config_hash`, `res$config_hash`). R offers no private
  memory: the context's carriers, the closures behind its public functions
  and ledgr's namespace hold prepared data beyond the pulse, and preflight
  is static. Outside ledgr's guarantee is a strategy that deliberately
  subverts R evaluation by a route preflight does not recognise: for
  example, a function reached through an alias, parentheses or
  `getElement()` before it is called, another package's replacement
  function (`methods::functionBody<-`), `trace()`, names built at run time,
  iteration over the context, code evaluated in the context or in a
  function's enclosure by other means, objects supplied from outside the
  body, or a future-data file. ledgr guarantees that its own public
  history, feature and fact APIs return only data known at the decision
  time.
- Ledgr's exported public namespace is Tier 1-compatible because ledgr itself
  is the required execution environment for ledgr experiments. Documented
  strategy helpers such as `ledgr_signal_return()`, `ledgr_select_top_n()`,
  `ledgr_weight_equal()`, `ledgr_target_rebalance()`, and `ledgr_passed_warmup()` must not be
  treated as unresolved Tier 3 symbols merely because examples omit the
  `ledgr::` qualifier.
- Static analysis is not a proof of semantic reproducibility. The preflight may
  use `codetools::findGlobals()` or a similar mechanism, but it must document
  limits around dynamic dispatch, `do.call()`, dynamically constructed
  strategies, S3/S4/R6 runtime state, `<<-`, and closures that mutate captured
  environments.
- The minimum `ledgr_strategy_preflight` result contract contains `tier`,
  `allowed`, `reason`, `unresolved_symbols`, `package_dependencies`,
  `ambient_rng_symbols`, and `notes`, and has class
  `ledgr_strategy_preflight`. `allowed` is `TRUE` for
  `tier_1` and `tier_2`, and `FALSE` for `tier_3`.
- Strategy preflight may include additive worker-dependency metadata.
  `qualified_package_dependencies` identifies packages used through
  `pkg::fn`, `attached_package_dependencies` identifies packages needed for
  unqualified package calls on workers, and `worker_dependencies` carries the
  `require_namespace` and `attach` sets consumed by parallel setup.
- Ambient strategy RNG calls such as `runif()`, `rnorm()`, and `sample()` are
  Tier 2 for ordinary sequential runs, but they are not certified for resume
  or parallel equivalence. Resume and parallel equivalence are guaranteed only
  for strategies deterministic in `(ctx, params)`. Strategies needing
  pulse-specific stochastic inputs in those paths should derive them from
  `ctx$pulse_seed`, not from ambient `.Random.seed`.
- Sweep mode inherits the public preflight semantics. Sweep may accept Tier 1
  and Tier 2 strategies, but Tier 3 strategies must be rejected before
  execution.

<a id="contract-strategy-provenance"></a>
### Provenance And Recovery

- Run provenance stores `strategy_source_hash`,
  `strategy_params_hash`, captured strategy source where available,
  dependency versions, R version, and reproducibility tier. Experiment
  execution must not treat R6 strategy objects as supported Tier 2 strategies.
- `strategy_source_hash` is R-version-sensitive and should be compared directly
  only between runs created under the same `R_version`.
- `ledgr_run_strategy(trust = FALSE)` is inspection-only: it returns stored
  source text and metadata without parsing, evaluating, or executing source.
  `trust = TRUE` verifies the stored source hash before parsing/evaluating the
  source into a function object. Hash verification proves stored-text identity,
  not safety.
- Canonical JSON currently serializes both `NULL` and `NA` as JSON `null`;
  users who need to distinguish those parameter values must encode that
  distinction explicitly.

## Context Contract

<a id="contract-context-pulse-data"></a>
### Pulse Data And Axis-Aligned Accessors

- Runtime and interactive pulse contexts expose data-frame-compatible
  `ctx$bars` and long-table `ctx$feature_table`.
- Ergonomic helpers such as `ctx$feature()`, `ctx$features()`, `ctx$idx()`,
  and `ctx$vec` are derived views over pulse-known data; they do not change
  feature computation semantics or no-lookahead boundaries.
- `ctx$idx(instrument_id, missing = c("error", "na"))` returns the 1-based
  universe position for an instrument. Unknown IDs fail loudly by default and
  return `NA_integer_` only when `missing = "na"` is requested explicitly.
- `ctx$vec` exposes universe-aligned vector views for cross-sectional strategy
  logic. The bound fields are `id`, `open`, `high`, `low`, `close`, `volume`,
  `position`, and `feature`, and in every context the eligibility planes
  `member`, `target_restricted`, `target_restriction_reason`, and
  `admissible`; availability-aware contexts add `held`, `priced`, `mark_age`,
  `risk_mark` and `mark_source`. `ctx$vec$feature(feature_id)` returns the current
  universe-aligned vector for one active alias or registered engine feature
  ID. Active aliases resolve before concrete IDs; an unknown name fails with
  `ledgr_unknown_feature_id` and lists both namespaces separately.
- Availability-aware pulse contexts restrict bars, feature tables, scalar
  feature access, vector feature access, positions, and errors to the current
  decision axis. Dense contexts retain the existing fixed-universe fields and
  shape.
- `ctx$position(instrument_id)` and unnamed `ctx$vec$position` are the scalar
  and Daxis-aligned reads of pulse-start position state. Cross scalar reads to
  the plane with `ctx$idx()`. There is no public `ctx$positions` snapshot.
  `ctx$hold()` copies the state into full named portfolio intent; editing that
  target does not mutate either state read.
- `ctx$flat(default = 0)` constructs a full target vector initialized to a
  scalar quantity. `ctx$hold()` constructs a full target vector initialized to
  current positions. Strategies choose between them based on whether the default
  behavior is flat-unless-signal or hold-unless-signal.
- Availability-aware pulse contexts carry the causal history of their pulse.
  `ledgr_history_frame(ctx, feature = NULL, bar = NULL, lookback = Inf,
  instruments = "admissible", na_action = "keep", layout = "wide")` reads
  exactly one numeric series, a sealed bar field (`open`, `high`, `low`,
  `close`, `volume`) or one feature resolved active-alias-first then by
  concrete ID, and returns a fresh classed `ledgr_history` data frame. Every
  returned value is observed at or before the pulse, with facts knowable at
  it; later-known facts change only later reads and never an earlier
  returned object. Dense contexts and the snapshot-and-universe
  `ledgr_pulse_snapshot()` form have no history and refuse with
  `ledgr_history_unavailable`; malformed requests refuse with
  `ledgr_invalid_history_request`, `ledgr_invalid_history_field`,
  `ledgr_unknown_feature_id` or `ledgr_history_unknown_instrument`, and a
  cutoff outside the prepared axis with `ledgr_history_outside_axis`.
- The history axis is the declared venue's expected sessions from the data
  start (the first session of the experiment's snapshot) through the cutoff,
  with one cutoff-resolved expected-session mask per instrument for bar
  reads. `lookback = Inf` returns the whole axis; a finite lookback returns the last `lookback`
  sessions and is the exact values-and-evidence suffix of the `Inf` result.
  `lookback = 0` returns the empty axis. Bar values follow the experiment's
  history policy: open, high, low and close carry forward within the declared
  expected-session horizon from their original source, volume never carries,
  nothing fills backward or across a lifetime or terminal barrier, and a
  print inside a knowable lifetime-inactive interval stays readable with its
  structural flag. Bar history is restated with the cutoff's knowledge;
  feature history is a vintage view (Cut 16 decision 29): each cell keeps the
  value and the evidence it had at its own pulse, its masks being the
  lifetime and terminal state knowable then, so a fact that becomes known
  later changes feature cells only from its knowledge pulse on. For example,
  when an inactive interval at sessions 5 and 6 becomes known at session 7, a
  read at session 7 shows those sessions' bar prints as inactive-interval
  prints, while their feature cells keep the valid values they were computed
  with at sessions 5 and 6, and the session-7 feature cell is computed with
  the interval known. Feature values are the shared feature preparation's
  values on the same axis, and feature cell evidence is the evidence that
  preparation produced, with the column meanings of the availability-aware
  feature planes: `calculated` means the required inputs were admitted after
  treatment, `ready` means an admitted cell at or after its segment's
  `stable_after` row, `calculation_valid` means ready with a finite
  calculated value, `input_carried` marks a cell whose own required input was
  policy-carried (never for a definition excluded from input carry), and
  `output_carried` marks a value carried from an earlier valid cell with that
  cell's `source_ts_utc` and `carry_age_sessions`. `missing_reason` is one of
  `not_expected`, `outside_calculation`, `required_input_missing`,
  `carried_input_excluded`, `not_ready` (warm-up or re-warming),
  `calculation_non_finite` (a ready cell whose calculation is not finite,
  Cut 16 decision (21)), `output_carry_expired` or `output_carried`, so every
  cell that is not `calculation_valid` carries a reason. Preparation retains
  segment spans, reason runs and carry exceptions; a read derives warm-up and
  `calculation_non_finite` by index and locates its cells by binary search;
  nothing is recomputed per read.
- Wide results have `ts_utc` plus one numeric column per included
  instrument; long results have `ts_utc`, `instrument_id`, `source`
  (`bar:<field>` or `feature:<id>`), `value` and the cell evidence columns.
  The `ledgr_history` attribute records the data start, returned-window start,
  cutoff, requested and available lookback, source and policy identity, the
  selection table, `used_before_window` (whether any returned value used an
  observation or calculation state before the returned window; for a
  feature this includes an output-carried value whose source precedes the
  window, a bounded value whose reach of `stable_after` expected sessions
  (its window and the segment readiness it depends on) reaches a leading
  run of input-carried sessions or does not fit inside the window's
  expected sessions, for example across a lifetime-inactive interval, and
  any history-dependent
  value when the window does not start at the data start) and, for the
  wide layout, the cell evidence as sessions-by-instruments matrices. Cell
  evidence uses `expected`, `observed`, `is_missing`, `input_carried`,
  `calculated`, `output_carried`, `source_ts_utc`, `carry_age_sessions`,
  `ready`, `calculation_valid`, `missing_reason` and `barrier_reason`;
  selection evidence uses `requested`, `included`, `exclusion_reason`,
  `required_input_count`, `carried_input_count` and `carried_input_share`
  plus the cutoff admissibility of each instrument. Empty results keep their
  typed columns: an empty wide axis has zero rows and one numeric column per
  included instrument, a zero-instrument wide result keeps its sessions with
  only `ts_utc`, and an empty long result keeps all typed columns.
- `ledgr_history_matrix()` adapts an existing result to a sessions-by-
  instruments numeric matrix whose row names are the result's ISO 8601 UTC
  session stamps and whose column names are its included instrument IDs (R
  stores a zero-length dimension's names as `NULL`). It owns no cutoff, axis,
  treatment or missingness logic and refuses a value that no longer matches
  its recorded axis with `ledgr_invalid_history_result`.
  `ledgr_history_sufficient(x, lookback = NULL, min_instruments = 1L)` is the
  structural completeness query: at least `lookback` returned sessions and at
  least `min_instruments` included instruments. Without `lookback` it uses
  the result's requested lookback and refuses an infinite one with
  `ledgr_invalid_history_request`. It is not indicator readiness, warm-up or
  convergence and inspects no value.
- `ledgr_history_info()` returns a result's recorded metadata as a
  `ledgr_history_info` list (source, cutoff, data and window starts,
  requested and available lookback, selector, `na_action`, layout,
  `used_before_window`, included and excluded instrument IDs, the selection
  table as a tibble, policy identity, snapshot hash and, for the wide layout,
  the cell evidence) after the same consistency check as
  `ledgr_history_matrix()`; `print()` of a `ledgr_history` names it in a
  footer. `ledgr_align_weights(solution, history)` turns estimator output
  into `ledgr_weights` with origin `ledgr_align_weights`, named by the
  history result's included instruments: an unnamed vector is read in the
  matrix column order, a named vector is matched by name, and a one-column
  or one-row matrix is read as a vector; a non-numeric value, a wider
  matrix, a length that differs from the included instruments, or wrong,
  duplicated or missing names refuse with `ledgr_weight_alignment_mismatch`
  (also `ledgr_invalid_args`), and a missing or non-finite weight refuses
  through `ledgr_weights()` with `ledgr_invalid_strategy_type`. Both read no
  data. (Cut 16 LDG-3071 API items.)
- History reads add no public context field, durable artifact or snapshot
  row. The history view is a private carrier, `ctx$.history`, that holds the
  read service and therefore the whole substrate; strategies read history
  only through `ledgr_history_frame()`, and the strategy preflight refuses,
  as a best-effort static check, direct access to private context
  internals, non-exported ledgr objects and environment-reaching functions
  as Tier 3 (Reproducibility And Preflight, Cut 16 LDG-3072 and decision
  30). P1
  issues the cutoff-bound history view; P2 places it on the context, and the
  strategy's `ledgr_history_frame()` call reads prepared planes shared by the
  owning run, sweep or walk-forward session. Treatment planes are prepared
  once per substrate and history policy; no read rematerializes the causal
  prefix.

<a id="contract-context-feature-resolution"></a>
### Feature Resolution And Explicit Maps

- `ctx$feature(instrument_id, feature_id)` uses the same alias-first singular
  resolver as `ctx$vec$feature()`. It fails loudly for unknown names, including
  the requested feature, instrument, active aliases and concrete feature IDs.
  A known feature whose current value is warmup `NA` remains a normal `NA`
  lookup, not an error.
- `ctx$features(instrument_id, feature_map)` is a pulse-scoped bundled view
  over `ctx$feature()`. It must preserve no-lookahead semantics, fail loudly
  for unregistered mapped feature IDs, and return warmup `NA` for known
  features that are not usable yet.
- Every explicit-map consumer (`ctx$features()`, `ledgr_pulse_features()` and
  `ledgr_pulse_wide()`) may add a call-local alias but may not redefine an
  active alias or registered engine ID to mean another feature. A conflict
  fails with `ledgr_invalid_feature_map`, naming the alias, requested feature
  and existing feature. An own-name same-feature mapping remains valid.
- The decision-time guarantee concerns supported context operations. Public
  accessors may retain engine-owned prepared state internally only when every
  supported operation enforces the invoking pulse and permitted axis.
  Instrument, universe and feature-ID indexes and the active alias map are
  prepared once for one run-local context factory. The active alias map is
  fixed for that run and prepared state is never shared across runs or sweep
  candidates. A bundled accessor may retain only its last successfully
  resolved explicit feature map, whether supplied as a character map or a
  concrete feature-map object, and may reuse that lookup only when the next
  map is `identical()`; a non-identical or failed feature-map input clears the
  memo.
  Dot-prefixed context fields are not API and carry no guarantees; deliberate
  R introspection of closure environments, call stacks or internal bindings is
  outside this contract.
- The prepared singular resolver is owned by one run or sweep candidate and is
  reused by dense and availability reads. Resolution precedes decision-axis
  restriction. No package-global resolver cache or plural feature plane is
  part of this contract.

<a id="contract-context-prepared-views"></a>
### Prepared Views And Eligibility

- `ctx$bars`, `ctx$feature_table`, and `ctx$features_wide` remain available.
  The long feature table may be a schema-only zero-row frame while registered
  feature accessors and the wide view carry current values. No equivalence is
  promised between these representations and none is materialized merely to
  make another look complete.
- `ctx$tradable()` is a non-default convenience predicate. In availability
  mode it returns `admissible & priced`; in dense mode it returns IDs with a
  finite positive close. A permissible stale mark may satisfy `priced` while
  still failing current-close sizing, so this helper guarantees neither a
  current sizing close nor execution at the next open.
- A frozen holding stays on the decision axis with its position. Its
  `risk_mark` is its last close, `mark_source` is `frozen_close`, `priced` is
  `TRUE` and `mark_age` keeps increasing. It is `target_restricted` with
  reason `valuation_frozen` unless an earlier restriction reason applies, so
  `admissible` is `FALSE` and `ctx$tradable()` excludes it. The frozen close
  is not an observed close and is never an execution price.
- `ledgr_passed_warmup()` is a strategy-authoring guard for named numeric vectors
  produced by `ctx$features()`. It is not a helper-pipeline transformation and
  zero-length input must fail loudly rather than returning vacuous success.
  The context-aware form `ledgr_passed_warmup(ctx, values)` reads a
  decision-axis vector and considers eligible IDs only; there, no eligible ID
  is a pass.

<a id="contract-context-inspection"></a>
### Inspection And Signal Views

- `ledgr_feature_contracts()`, `ledgr_pulse_features()`, and
  `ledgr_pulse_wide()` are read-only inspection views over declared features
  and pulse-known data. They must not precompute unavailable data, mutate
  persistent ledgr tables, or change strategy execution semantics.
- `ledgr_pulse_wide()` uses stable names
  `{instrument_id}__ohlcv_{field}` and
  `{instrument_id}__feature_{key}`. A mapped view uses its stable alias as
  `key`; an unmapped view uses the engine feature ID. The long
  `ledgr_pulse_features()` view retains both `alias` and `feature_id`.
- `ledgr_signal_feature()` uses the singular alias-first resolver, keeps raw
  decision-axis values and eligibility unchanged, and records the literal
  author-supplied name as signal origin. `ledgr_signal_return()` remains the
  exact-ID convenience for one concrete return lookback; parameterized return
  maps are read through a stable alias with `ledgr_signal_feature()`.
- `ledgr_feature_contracts()` and `ledgr_feature_contract_check()` accept
  `feature_params` and resolve parameterized maps through the same validator
  and resolver as execution. Without concrete parameters they retain a classed
  refusal; no general map materializer is exported.
- On an axis of at least 100 instruments, scalar and active-map bundle loops
  warn once per run when calls in one pulse reach the axis size. The warning
  names singular `ctx$vec$feature()` reads as the replacement. Explicit-map
  bundle loops remain unrecorded.
- Feature maps do not add a new `ctx$features_wide()` contract; the
  public wide pulse inspection API is `ledgr_pulse_wide()`.
- `ledgr_pulse_snapshot()` is an external development and inspection helper;
  no strategy callback calls it, receives an experiment or supplies a history
  policy. Called with an availability-aware `ledgr_experiment`, its concrete
  `params` and `feature_params`, and a cutoff `ts_utc` naming one session
  close (a `Date` names that session's close), it takes snapshot, universe,
  features, history policy, data start and opening state from that experiment
  alone and accepts no other configuration argument. It prepares what a run of
  the experiment starting at the cutoff prepares and drives the shared fold
  core through P1 observe-and-settle and P2 context construction for that
  first pulse only: due facts settle exactly as in execution, no strategy is
  called, P3 through P5 never run, and no fill, event, run row or other
  durable state is written. The returned context is the one that run passes
  to its strategy, so its data-dependent planes and `ledgr_history_frame()`
  reads equal that run's first pulse. A cutoff off the prepared venue axis
  refuses with `ledgr_history_outside_axis`, a pulse whose P1 stops before the
  context is built refuses with `ledgr_pulse_inspection_stopped`, and a dense
  experiment refuses with `ledgr_pulse_snapshot_availability_required`. The
  snapshot-and-universe form remains the dense inspection branch until the
  execution-core consolidation and carries no history.
- Strategy evaluation errors are wrapped with pulse context while preserving the
  original condition as the parent. The wrapper must name the run, timestamp,
  instruments, and available feature IDs so users can distinguish strategy
  logic failures from feature ID and warmup behavior.

<a id="contract-context-indicator-computation"></a>
### Indicator Computation And Identity

- Every indicator definition is `bounded` or `history_dependent`.
  `gap_contract = "strict_window"` declares a bounded window; combined with
  `history_class = "history_dependent"` it refuses with
  `ledgr_indicator_history_contradiction`. A custom definition without a
  history declaration is disclosed as `history_dependent`; bounded is
  declared, never inferred.
- A definition declares the bar fields it requires (`required_fields`, from
  `open`, `high`, `low`, `close` and `volume`); an undeclared custom
  definition requires the four price fields. Required-field admission tests
  exactly those fields and records every field that blocks a calculation.
  Invalid declarations refuse with `ledgr_invalid_indicator_declaration`.
- For a bounded definition `requires_bars` is the dependency width and the
  window handed to `fn`; `stable_after`, at least `requires_bars`, is the
  first-valid boundary and implies no convergence. No other width field
  exists.
- Package built-ins and registered TTR forms take exact declarations from one
  package catalogue keyed by function, selected output and algorithm-changing
  argument. Registered package tests certify every row on fixed hostile
  fixtures; rows carry no runtime tolerance. A TTR form outside the catalogue,
  including a known function with an unregistered argument or a different
  `requires_bars`, follows the custom rules. Catalogue rows also mark the
  return and volatility families: a row whose value depends on
  session-to-session price changes or price dispersion has
  `input_carry = "excluded"`; a level row is eligible. TTR `aroon` declares
  its `n + 1` dependency width in every execution mode.
- A custom definition may declare `input_carry = "excluded"` to mark itself a
  return or volatility definition; an undeclared one consumes the
  policy-treated input, disclosed as the default. The declaration enters
  rule-4 feature identity. A built-in or registered TTR row takes its family
  from the catalogue, and declaring another family on it refuses with
  `ledgr_indicator_history_contradiction`.
- A custom bounded definition that supplies both `fn` and `series_fn` is
  compared exactly unless it declares a nonzero scaled `tolerance`; a
  tolerance on any other definition refuses as a contradiction.
- Indicators may provide an optional `series_fn(bars, params)` for full-series
  precomputation. The input is one instrument's full bar series in ascending
  time order, and the output must be a numeric vector aligned to `nrow(bars)`.
- Full-series precomputation may return warmup `NA_real_` directly without
  calling `series_fn()` when `nrow(bars) < stable_after`; strategy-visible
  output remains an aligned all-`NA_real_` series for that feature/instrument.
- Feature warmup `NA_real_` and warmup `NaN` are normalized to `NA_real_`.
  Infinite values, post-warmup `NA`, and post-warmup `NaN` values are invalid.
- Indicator fingerprints include `series_fn` when present and bind deterministic
  direct captures of `fn` and `series_fn`. Changing either function, its direct
  atomic/list captures, parameters, or warmup requirements changes the
  fingerprint. Unsupported direct captures refuse as non-deterministic. A
  captured function is represented by its function identity without recursively
  including that function's own captures. The CSV adapter represents its
  constructor-owned captured values through `params$data_hash`; public source or
  adapter labels do not authorize that private route.
- Dense indicator fingerprints omit the history declarations. Under identity
  rule 4 an availability-aware feature fingerprint binds the dense
  fingerprint (functions, captures, `id`, `requires_bars`, `stable_after` and
  `params`, which carry the TTR version and algorithm arguments) together with
  the history class, gap behavior, required fields, input-carry family,
  tolerance and the feature-history rule version. The stored availability
  config definition carries the same declarations, so each changes config
  identity. Declaration provenance and display labels do not enter identity.

<a id="contract-context-strict-features"></a>
### Availability-Aware Strict Features

- Availability-aware features are calculated over the shared causal-history
  substrate. Every bounded and history-dependent definition runs; no
  declaration is refused for its class. Each instrument's price fields are
  treated once per preparation under the experiment's history policy: by
  default each open, high, low and close field is carried for at most five
  expected sessions, volume is never carried and
  `ledgr_history_policy(price_carry = NULL)` keeps raw inputs.
- Admission tests only a definition's required fields after treatment. A
  bounded definition's value at a session is a function of its last
  `requires_bars` expected sessions on the instrument's mask; sessions on which
  the instrument is lifetime-inactive are not counted. `fn` receives exactly
  that window and an incomplete window is `NA_real_`. A terminal interval ends
  bounded windows as well as carry (Cut 16 decision (20)): after a relisting a
  bounded definition restarts at every relisting (a run breaks at each row
  that follows a column inside a terminal interval, read from the same
  per-column terminal assertion the sticky carry barrier is derived from;
  the carry barrier itself stays sticky), needs
  `requires_bars` treated rows from the relisting and is ready again at its
  `stable_after` row, so no window mixes pre-delisting and post-relisting
  prices.
- A history-dependent definition runs once per contiguous segment of available
  input on the common axis. A missing input beyond the carry horizon or a
  lifetime-inactive interval ends the segment; the next segment restarts and
  warms up again. Restart, not skip, is the gap policy. `stable_after` is the
  first-valid position after each start or restart.
- Return- and volatility-family catalogue rows never consume a carried price:
  their calculated output is `NA_real_` wherever a required input is missing
  or would have been carried; optional output carry may still fill such a
  session from an earlier valid value, disclosed as `output_carried`.
  A custom definition declaring `input_carry = "excluded"` follows the same
  rule; an undeclared custom definition consumes the policy-treated input.
- A real print inside a knowable lifetime-inactive interval enters no
  calculation. Valuation marks never enter feature computation. Each pulse's
  value uses the lifetime and terminal facts knowable at that pulse; a
  later-known fact changes only later pulses. Features are calculated from
  the data start through each window's scoring end (see
  [Scoring And Feature Start](#contract-execution-window-start)).
- Raw missingness, input carry, required-field admission, readiness,
  calculation validity and optional output carry remain separate planes.
  Output carry fills only a session whose own required input is unavailable,
  from an earlier valid output and within the policy's output age; warm-up and
  re-warming sessions are never filled.
- Built-ins and catalogue rows are computed with the package constructor's own
  functions, so a definition that claims their identity cannot execute other
  code. A custom bounded definition that supplies `fn` and `series_fn` takes
  its values from `series_fn` per segment; the sampled causality checks under
  [Feature Path](#contract-context-feature-path) refute it against `fn`. A
  history-dependent pair is not refuted.
- Dense indicator fingerprints and the dense feature-engine identity omit the
  availability declarations. Two accepted corrections change dense results:
  TTR `aroon` declares its `n + 1` width in both modes, which changes its
  dense fingerprint and adds one dense warm-up row (Cut 16 decision (14));
  and a custom indicator whose id matches a built-in pattern (`sma_<n>`,
  `return_1`) runs its own function in both modes, in any session and
  call order, and is never replaced by the built-in (Cut 16 decision
  (19)). A run resolves each feature from the experiment's own
  definitions, which travel with its config outside config identity and the
  stored config; runs, sweeps, walk-forward and config building never write
  the session indicator registry, which a run reads only for an id its
  config does not carry. A stored fingerprint that matches neither the
  built-in nor a resolvable indicator refuses with `ledgr_run_hash_mismatch`.
  The availability feature-engine
  identity binds every helper of this calculation.

<a id="contract-context-ttr-adapter"></a>
### TTR Adapter

- TTR indicators created by `ledgr_ind_ttr()` store TTR function name, TTR
  version, input shape, output column, and forwarded TTR arguments in indicator
  params. Only `params$args` are forwarded to TTR; metadata fields are identity
  fields for fingerprints and diagnostics.
- TTR warmup inference is allowed only for functions listed by
  `ledgr_ind_ttr_warmup_rules()`. Each listed rule must be deterministic from
  explicit arguments alone and is the catalogue dependency width. Aroon depends
  on `n + 1` rows even though TTR returns a partial-window value at row `n`.
- Registered TTR forms are package catalogue rows keyed by function, output and
  algorithm-changing argument (`maType`, `wilder`); each row declares its
  history class, required fields and input-carry family and is certified by
  package tests. Any other argument combination or a different
  `requires_bars` follows the custom rules. Multi-output bundles flatten to
  ordinary catalogue rows, one per output.
- TTR adapter parity tests must cover every listed warmup rule and every
  documented multi-output column. Derived outputs such as MACD `histogram` are
  verified against the documented derivation applied to direct TTR output, not
  against a nonexistent TTR column.
- Supported TTR indicators must handle short samples consistently: validly
  constructed indicators should produce aligned warmup `NA_real_` values rather
  than leaking low-level TTR errors from ordinary feature precomputation.
- TTR input mappings are adapter contracts: `close` maps to `bars$close`, `hl`
  maps to `High/Low`, `hlc` maps to `High/Low/Close`, `ohlc` maps to
  `Open/High/Low/Close`, and `hlcv` maps to `High/Low/Close/Volume`. The
  mapped fields are the definition's required fields.
- TTR-backed generated IDs use rules-table `id_args` first and then any other
  supplied scalar arguments in sorted order before the optional output suffix.
  Users must provide `id` explicitly when non-scalar TTR arguments would make a
  generated ID ambiguous.
- `ledgr_feature_id()` is a discovery helper over existing `ledgr_indicator`
  IDs. It must not generate aliases, rename indicators, or change fingerprint
  semantics; list input returns IDs in list order.

<a id="contract-context-feature-path"></a>
### Feature Path And Intent Constructors

- Fn-only indicators remain supported. `fn` receives exactly the last
  `requires_bars` calculation rows ending at the current session (expected
  sessions for a bounded definition), never an expanding full-history window.
- Availability-aware feature preparation checks causality before it returns,
  so a refusal precedes the fold or sweep candidates it prepares for and any
  precompute payload.
  Each concrete definition, including built-ins, catalogue rows and fn-only
  definitions, is probed once on the instrument with the most calculated
  cells, at no more than four fixed positions among its calculated cells with
  later history in their calculation range (the first, the last and the two
  interior thirds). The value recomputed on the history ending at a position
  must equal the prepared value exactly, or preparation refuses with
  `ledgr_feature_lookahead_detected`, naming the definition, instrument and
  session. A custom bounded definition that supplies both `fn` and
  `series_fn` is also refuted at the same positions: `fn` on its window must
  equal the `series_fn` value on the full causal prefix exactly, or within a
  declared nonzero tolerance that enters its fingerprint, or preparation
  refuses with `ledgr_indicator_gap_parity`. History-dependent pairs are not
  refuted, and built-ins and catalogue rows are certified by package tests,
  not runtime refutation. The checks never recompute all prefixes: their cost
  is a fixed number of recomputations of one instrument per definition.
  Passing them does not prove a definition causal.
- A durable `ledgr_run()` prepares features after it registers the run, so a
  refused definition leaves that run recorded `FAILED` with no strategy call,
  ledger event or equity row (Cut 16 decision 18); sweep and precompute
  refusals write nothing. Dense
  execution is frozen and runs no causality check.
- Feature computation follows one uncached production path. Explicit
  `ledgr_precomputed_features` payloads are validated against current feature
  identity before reuse; a mismatch refuses before candidate execution.
- In public workflows, `ctx$flat()` creates a full named target vector
  initialized to flat positions. It is appropriate when unspecified instruments
  should go flat.
- In public workflows, `ctx$hold()` creates a full named target vector
  initialized from current holdings. It is appropriate for hold-unless-signal
  strategies and rebalance throttling.
- Interactive pulse and indicator tools are read-only against persistent ledgr
  tables.

## Result Contract

<a id="contract-result-read-surfaces"></a>
### Result Reads And Explanations

- Results are derived from ledger and equity tables.
- `print()`, `summary()`, `plot()`, and `tibble::as_tibble()` must not mutate the
  backtest object or persistent run state.
- Warmup and zero-trade diagnostics may appear on result-inspection surfaces
  such as `summary(bt)`, but they must not mutate the backtest object,
  persistent run state, result tables, metrics, or run identity.
- Ordinary result-access APIs over durable `ledgr_backtest` handles should use
  per-operation read connections where practical so inspecting results does not
  leave a DuckDB connection open and block a later write in the same session.
- `tibble::as_tibble(bt, what = ...)` supports the closed result set:
  `equity`, `returns`, `fills`, `trades`, `ledger`, `diagnostics`, and
  `availability`.
- `ledgr_results(bt, what = ...)` is the package-prefixed wrapper over that
  same result path. It must delegate to `tibble::as_tibble()` and must not
  duplicate reconstruction logic.
- `ledgr_results(bt, what = ...)` may return a ledgr-owned tibble subclass for
  display. That subclass must remain tibble-compatible, and
  `tibble::as_tibble()` must expose the raw result table.
- `diagnostics` is the ordered durable trace recorded by availability-aware
  runs; dense runs return its typed zero-row schema. `availability` is derived
  from sealed facts, the stored effective plan, and ledger holdings. Neither
  view executes strategy code, reconstructs a strategy target, writes durable
  rows, or changes run identity.
- Availability result reads derive marks from history starting at the data
  start, as the fold does, so a run's first pulse may report a stale mark from
  before its scoring start. A continued carry window's final decision is
  executed and recorded by that run at the following session's open; its
  results, explanations and completion evidence read that execution from the
  run's own configured final execution instant.
- `ledgr_run_explain(bt, instrument_id, ts_utc)` joins one retained decision
  trace to its availability, execution, valuation, feature-identity, position,
  and terminal evidence. It consumes `diagnostics` and `availability` through
  the same `tibble::as_tibble()` result-table path and returns the same row
  after close/reopen. Missing decision trace fails
  `ledgr_run_explanation_unavailable`; the function must not invent an intent
  from positions, facts, or current strategy code.
- The explanation row exposes its run, decision, availability, target,
  execution, valuation, resulting-position, and completion fields directly.
  When an unchanged target has no execution diagnostic, `execution_outcome`
  is `no_action` and `execution_reason` plus `execution_reasons` are
  `no_target_change`. Those values are explain-time defaults, not durable
  diagnostic reason codes, and are never persisted.

<a id="contract-result-completion-and-valuation"></a>
### Completion And Valuation Disclosure

- `ledgr_run_info()` and `summary()` project existing terminal completion
  evidence read-only. Availability-aware runs expose requested and achieved
  windows, terminal status and stop reason, last fully valued and executed
  times, complete or incomplete performance, and affected instrument IDs from
  recorded stop diagnostics. Dense runs without that evidence report it as
  unknown; inspection must not reconstruct or persist it.
- `ledgr_results(bt, what = "fills")` returns execution fill rows, including
  opening and closing actions. `ledgr_results(bt, what = "trades")` returns
  closed trade rows only. Public `n_trades` and `win_rate` metrics are computed
  from closed trade rows, so open-only fills do not count as trades until
  quantity is closed.
- Public fill `ts_utc` is economic execution time. Availability-aware version-2
  fills use the next declared session opening, while equity remains stamped at
  the close pulse. The read-only `recording_pulse_ts_utc` column is derived from
  recorded fill association and sealed session facts; it is not persisted and
  remains `NA` when the association is missing or ambiguous. Dense alignment is
  the existing fill timestamp. Align fills to equity only after grouping fills
  by recording pulse, so multiple fills cannot duplicate equity rows.
- Timestamp display options are print-only. `options(ledgr.print_ts_utc =
  "auto")` may compact all-midnight UTC timestamps to dates in ledgr-owned
  print paths, but returned and stored `ts_utc` values remain POSIXct UTC.
- `ledgr_run_compare()` reads stored completed-run artifacts only. It must not
  rerun strategy code, evaluate recovered source, or mutate the experiment
  store while producing comparison tables.
- With explicit `run_ids`, `ledgr_run_compare()` rejects every non-`DONE` run
  with `ledgr_run_not_complete`. Without `run_ids`, it excludes non-`DONE`
  rows and discloses the attempted, done, incomplete and failed counts in its
  `selection_counts` attribute and print. An incomplete horizon changes the meaning of return, Sharpe,
  and drawdown rather than merely qualifying those metrics. The completion-aware
  run inventory is the supported side-by-side view of runs with different
  horizons.
- `ledgr_run_compare()` returns raw numeric metric columns for ranking and
  filtering. Percentage formatting is a print-only concern; users must not need
  to parse display strings such as `"+5.2%"` to rank runs.
- Run information, reopened summaries, and comparisons expose timing version
  and convention provenance. Comparison metadata reports selected-set-wide
  `fill_timing_comparable` and `fill_timing_comparability_reason` without
  filtering or changing recorded metrics. Differing conventions cannot
  support fill equivalence; matching conventions establish timing
  compatibility only, not economic equivalence.
- `ledgr_run_tag()`, `ledgr_run_untag()`, and `ledgr_run_tags()` manage mutable
  run grouping metadata in `run_tags`. Tags must not alter run identity hashes,
  stored artifacts, comparison semantics, or strategy provenance.
- Metrics are descriptive only and must never feed back into strategy execution.

<a id="contract-result-corporate-actions"></a>
### Corporate Actions And Valuation

- Terminal outcomes extend `ledgr_corporate_action_summary()` and
  `corporate_action_fidelity`; there is no separate terminal headline. Its
  `terminal_outcomes` table lists every scheduled and lifetime `DISPOSITION`
  with source, terminal event, matched label, choice, whether the choice was
  `declared` or `default`, an assumption label, price, quantity, proceeds and
  realized model P&L. A defaulted frozen-fallback write-off reads exactly
  `default: assumed worthless`. Settlement evidence is reported as evidence,
  not as an assumption.
- A corporate-action fact whose effect ledgr does not represent takes the
  unsupported-quantity route when its parent is held at entitlement: a
  complete fact of a subtype outside `ordinary_cash_dividend`,
  `cash_acquisition`, `stock_acquisition`, `mixed_acquisition` and
  `spin_off`, a complete acquisition in a dense run, where no disposition
  acts, and a refused fact (`complete = FALSE`) of any subtype. Under
  `unsupported_quantity = "refuse"` (the strict preset) an availability run
  stops `INCOMPLETE` with `corporate_action_quantity_refused` at the fact's
  effective pulse and a dense run raises
  `ledgr_corporate_action_quantity_unsupported`; a held fact with no
  effective clock has no effective pulse, so under either value it only
  counts in `unsupported_facts` and makes `corporate_action_fidelity` read
  `unsupported`; otherwise nothing posts, the
  fact counts in `unsupported_facts` and `corporate_action_fidelity` is
  `unsupported`. Ingest keeps the subtype
  vocabulary open (Cut 12 LDG-2996; Cut 17 LDG-3089).
- `ledgr_corporate_action_summary()` discloses refused facts in two counts
  keyed by sealed `refusal_reason`: `sealed_refusal_counts` counts every
  sealed refused fact, and `refusal_counts` counts those whose parent the run
  held at entitlement, with `refusal_entitled_quantity` summing their
  absolute entitled parent quantities. `print()` and `summary()` show both
  counts. An unheld refused fact changes neither fidelity nor the run outcome
  (Cut 17 LDG-3089).
- `ledgr_valuation_summary(bt)` reports one run's valuation state (`current`,
  `stale`, `frozen`, or `not_applicable` for dense runs), stale and frozen
  instrument-sessions and holdings, longest stale age and longest freeze,
  maximum frozen gross value and equity weight, frozen-at-end count, value
  and weight, and `total_return_if_frozen_worthless`. That field subtracts
  the frozen-at-end marked value from final equity before computing endpoint
  return; it is a long-only bound, not a corrected return, Sharpe or
  drawdown. Stored equity and standard metrics are unchanged.
- During a freeze, cash, quantity and ledger accounting are exact under the
  declared model, but equity is an assumption-backed estimate. Endpoint
  return converges once every freeze resolves, provided the carried marks
  changed no decision in between; path statistics may remain distorted
  because the price move books on the resumption date.
- `print()` and `summary()` of an availability-aware run show one valuation
  headline (`CURRENT`, `STALE` or `FROZEN`). Whenever the run entered frozen
  valuation or used an assumed terminal outcome, they print one warning before
  any metric that names each assumption and the argument that declared it.
  The warning has no materiality threshold. Refused exhaustion, settlement
  evidence alone and a clean run do not warn, and a dense run shows no
  valuation output.

<a id="contract-result-reconstruction"></a>
### State Reconstruction

- `ledgr_state_reconstruct()` is the public reconstruction entry point for a
  run id and DBI connection. It delegates to the shared derived-state rebuild
  path, which ensures snapshot-backed sources before rebuilding derived
  artifacts. A dense run is rebuilt on its bar timestamps and requires every
  close. An availability-aware run (Cut 11, LDG-2978) is rebuilt on its
  open-session calendar through its last fully valued pulse, with each held
  instrument valued at its last observed close in the run window, which is
  the current, stale or frozen mark the fold used; members may miss bars. The
  rebuilt equity equals the stored equity exactly. The rebuild and its cash
  and position identities cover the ledger events at or before that pulse; a
  fill an INCOMPLETE run executed after its last fully valued pulse
  (disclosed by `last_executed_ts_utc`) stays in the ledger and the fills
  reader but outside the rebuilt state (Cut 12 LDG-2995).
- `ledgr_run_fills()` and `ledgr_results(bt, "equity")` are user-facing
  read helpers over existing run artifacts; they must not become alternate
  reconstruction implementations.
- Current runs retain their recorded config, hashes, events, diagnostics,
  projections, completion evidence, and fill timestamps byte for byte. Reads
  may classify timing provenance and derive unambiguous pulse alignment, but
  must not write it back, replay strategy code, recompute fill eligibility, or
  restamp recorded events.

<a id="contract-result-fills-and-sweep-restoration"></a>
### Fills And Sweep Restoration

- `ledgr_run_fills(bt)` has exactly one public formal and eagerly returns the
  full fills-schema tibble for empty and populated runs. It has no public
  cursor, lazy-read, or row-threshold mode. A continued carry window's
  boundary fill belongs to the deciding run and is returned by it with its
  next-session execution timestamp; the next window's run does not repeat it.
  Training sweeps never continue a window.
- When one source fill reverses a position and projects to derived CLOSE and
  OPEN rows, its fee is allocated pro rata by the non-negative absolute leg
  quantities. The derived fees for that event must sum to its source fee in
  durable, reconstructed, memory-backed, and compiled spot-FIFO projections.
  This projection rule must not change cash, lot state, realized PnL, or closed
  trade metrics.
- For classed sweep input, `ledgr_sweep_review()` restores `review$ranked` as a
  `ledgr_sweep_results` view with applicable source and risk lineage, including
  `risk_chain_hash` and `risk_plan_json`. Compatible plain input must not gain
  invented lineage. `review$top` is a lineage-free presentation table, not a
  promotion-ready candidate surface.
- Sweep-result restoration preserves `risk_chain_hash` and `risk_plan_json`
  when present and preserves their absence on compatible plain input as `NULL`
  rather than
  synthesizing provenance.

<a id="contract-result-standard-metrics"></a>
### Standard Metrics

- Public standard metrics use the equity rows returned by
  `ledgr_results(bt, what = "equity")` and the closed trade rows returned by
  `ledgr_results(bt, what = "trades")`.
- `initial_equity` is the `equity` value in the first public equity row for the
  completed run. Total return is `final_equity / initial_equity - 1`, where
  `final_equity` is the `equity` value in the last public equity row. If no
  equity row exists or `initial_equity` is zero, total return is `NA`.
- Annualized return is the geometric annualized return from the same first and
  last public equity rows: `(final_equity / initial_equity)^(1 / years) - 1`,
  where `years = (n_equity_rows - 1) / bars_per_year`. If fewer than two equity
  rows exist, `bars_per_year` is invalid, or `initial_equity` is zero, the
  metric is `NA`.
- Max drawdown is the maximum peak-to-trough decline in public equity rows:
  `min(equity / cummax(equity) - 1)`.
- Annualized volatility is `sd(period_returns) * sqrt(bars_per_year)`, where
  `period_returns` are adjacent public equity-row returns
  `equity[t] / equity[t - 1] - 1`. If fewer than two period returns exist, the
  metric is `NA`.
- The standard metric set ships `sharpe_ratio`.
- Sharpe-style metrics are computed from period excess returns:
  `excess_return[t] = equity_return[t] - rf_period_return[t]`. The annualized
  ratio is `mean(excess_return) / sd(excess_return) * sqrt(bars_per_year)`.
  The formula consumes a pulse-aligned per-period risk-free return vector; the
  source of that vector must not change the formula.
- The risk-free-rate provider is a scalar annual rate expressed
  as a decimal, so `0.02` means two percent per year. The default is `0`.
  Conversion to a per-period return is geometric:
  `(1 + rf_annual)^(1 / bars_per_year) - 1`. Non-finite rates, rates less than
  or equal to `-1`, or invalid `bars_per_year` values make the metric `NA`
  rather than producing misleading values.
- Time-varying risk-free-rate series and real data providers such as FRED,
  Treasury, ECB, or central-bank adapters are not supported. The metric formula
  consumes only the pulse-aligned `rf_period_return` vector described above.
- Risk-adjusted metrics must not silently assume daily bars. They reuse the
  documented `bars_per_year` cadence contract and must either snap known
  cadences, accept an explicit provider value, or fail/defer loudly when
  cadence is unknown.
- Run, sweep, comparison, and walk-forward metric surfaces emit the classed
  `ledgr_metric_context_cadence_mismatch` warning when a daily calendar is
  applied to evidence whose observed median interval is clearly subdaily. An
  explicit intraday calendar stays quiet. This is an honesty guardrail only:
  it must not change metric values, metric recipes, stored evidence,
  metric-context hashes, or run, sweep, candidate, session, promotion, or
  walk-forward identity, and it does not authorize first-class intraday
  execution behavior.
- Sharpe-style metrics return `NA_real_` for short samples, all-missing return
  inputs, invalid adjacent equity returns, flat equity, and constant-return
  cases. Near-zero excess-return volatility is defined as
  `sd(excess_return) <= .Machine$double.eps`. Infinite Sharpe values must not
  be emitted silently.
- Sortino, Calmar, Omega, information ratio, alpha/beta, benchmark-relative
  metrics, VaR, and tail-risk metrics are deferred until the standard
  risk-metric contract is stable.
- Optional PerformanceAnalytics parity tests are external evidence only. They
  must name the exact PerformanceAnalytics functions, annualization scale, and
  risk-free-rate units used for comparison, and they must not redefine ledgr's
  owned metric formulas or become a runtime dependency.

<a id="contract-result-return-panels"></a>
### Return Panels And Retained Evidence

- `ledgr_return_panel()` constructs source-neutral return evidence from clean
  candidate period returns. `ledgr_sweep_returns_panel()` is the sweep-sourced
  accessor into the same `ledgr_return_panel` contract. Diagnostic panels must
  preserve deterministic row-label ordering, deterministic candidate-column
  ordering, explicit structural first-row handling for retained
  `period_return`, and completed/excluded candidate reporting when sourced
  from a sweep. Complete-panel consumers must fail closed when selected
  completed candidates do not share a common timestamp grid after first-row
  handling. Every panel carries a source-neutral `panel_hash` over normalized
  evidence only: schema tag, value, ordered candidate ids, ordered labels, and
  the return matrix. `panel_hash` is evidence provenance only and must not
  participate in execution, sweep, candidate, promotion, run, config, or
  walk-forward identity. Optional package projections such as `xts` are
  external evidence only and must remain `Suggests`-only with no `NAMESPACE`
  imports.
- Retained return rows carry their candidate terminal status. Achieved
  `INCOMPLETE` prefixes may remain visible as explicitly incomplete evidence,
  but complete-panel projections, selection, candidate extraction, and
  promotion exclude or reject them even through `allow_failed` paths.
  Candidate extraction fails with `ledgr_incomplete_sweep_candidate`, and
  promotion fails with `ledgr_promote_incomplete_candidate`.
  Sequential and parallel sweeps carry the same canonical completion payload;
  the parent remains the only parallel persistence owner.
- A continued carry window's equity rows cover only its own scoring pulses;
  the cash and position effect of its boundary fill first appears in the next
  window's first equity row, exactly where one continuous run records it.
- Walk-forward training selection admits only `DONE` candidates. An
  `INCOMPLETE` selected test run records its canonical completion payload,
  marks the fold and session `PARTIAL`, preserves the achieved evidence, and
  ends a carry-state chain without constructing a later opening state or fold.
  Candidate and session identity formats remain unchanged.
- `ledgr_sweep_returns_wide()` reserves `ts_utc` as its structural timestamp
  column. A candidate ID equal to `ts_utc` or beginning with
  `..ledgr_candidate_` is represented by that prefix followed by the lowercase
  hexadecimal form of its UTF-8 bytes. The column name is intrinsically
  reversible without a persisted mapping registry. Long, matrix, panel, and
  candidate-extraction surfaces retain the original candidate ID, and this
  presentation encoding participates in no execution or artifact identity.
- Retained sweep closed-trade evidence is derived at sweep time from
  `ledgr_closed_trade_rows()` / `ledgr_results(bt, what = "trades")` and is
  exposed through `ledgr_sweep_trades()`. It is opt-in via
  `ledgr_sweep_retention(trades = "closed")`, defaults to unretained, and
  persists only the minimal evidence columns `candidate_row`, `trade_seq`,
  `close_ts_utc`, `realized_pnl`, and `win_loss` plus stable candidate/sweep
  identifiers. Saved-sweep reopen must never reconstruct retained trade
  evidence from fills; consumers that require trade evidence must fail closed
  with retained-trade condition classes when the evidence is unretained or
  missing. Retained trade evidence is not execution, candidate, run, config, or
  walk-forward identity.

<a id="contract-result-validation-diagnostics"></a>
### Validation Diagnostics

- `ledgr_pbo()` is a native PBO/CSCV diagnostic over a `ledgr_return_panel` or
  retained sweep returns. It uses the same panel gates, reports
  completed/used/excluded candidate ids where available, prevalidates even `S`
  partitions, carries `panel_hash`, and carries native diagnostic schema
  metadata. It is evidence only: it must not select, promote, filter candidates
  through a business objective, mutate sweep artifacts, or change walk-forward
  identity. CRAN `pbo` may be used only as optional reference evidence, never
  as a required runtime dependency.
- `ledgr_min_track_record()` is a native minimum track record length diagnostic
  over a `ledgr_return_panel` or retained sweep returns. It reports
  per-candidate observed Sharpe, skewness, kurtosis, minimum required return
  observations, significance, and extra observations needed. It uses the same
  panel gates and is evidence only: it must not select, promote, filter
  candidates through a business objective, mutate sweep artifacts, or change
  walk-forward identity. PerformanceAnalytics may be used only as optional
  reference evidence, never as a required runtime dependency.
- `ledgr_k_ratio()` is a native Kestner (2013) compounded-return K-Ratio
  diagnostic over a `ledgr_return_panel` or retained sweep returns. It fits an
  ordinary least-squares trend to cumulative log wealth and applies the
  published observation-count and periodicity adjustment. Callers must supply
  `periods_per_year` explicitly; panel labels do not silently determine
  annualization. The result reports the fitted slope, slope standard error,
  raw ratio, adjusted K-Ratio, `panel_hash`, nullable sweep provenance, and
  input identity when sweep-sourced. Other K-Ratio variants are non-scope.
  K-Ratio is evidence only and independent of the `positive_trajectory`
  business-objective criterion: it must not select, promote, filter candidates,
  mutate sweep artifacts, or change execution or walk-forward identity.
- `ledgr_effective_trials()` is a native deterministic effective-trial-count
  diagnostic over a `ledgr_return_panel` or retained sweep returns. V1 uses
  exactly one method: hierarchical complete-linkage clustering over `1 -
  correlation` distance. It has no RNG, no seed argument, and no method menu.
  The output reports cluster membership, effective independent trial count,
  method parameters, `panel_hash`, nullable sweep provenance, and input
  identity when sweep-sourced. It is evidence only: it must not select,
  promote, filter candidates through a business objective, mutate sweep
  artifacts, or change walk-forward identity.
- `ledgr_dsr()` is a native Deflated Sharpe Ratio diagnostic over a
  `ledgr_return_panel` or retained sweep returns. It uses observed per-period
  Sharpe, skewness, kurtosis, candidate-Sharpe variance, sample length, and an
  effective independent trial count. When `effective_trials` is omitted, the
  count comes from `ledgr_effective_trials()`. DSR is independent of PBO/CSCV
  and remains evidence only: it must not select, promote, filter candidates
  through a business objective, mutate sweep artifacts, or change walk-forward
  identity. quantstrat may be used only as optional reference evidence through
  `dev/manual/verify-dsr-quantstrat.R`, never as an automated-test or runtime
  dependency.

<a id="contract-result-business-objectives"></a>
### Business Objectives

Accepted change pending:
[objective-filtered walk-forward identity](decisions.md#objective-filtered-walk-forward-identity).

- `ledgr_business_objective()` composes an ordered, non-empty set of
  ledgr-owned `ledgr_objective_*()` criterion steps with one v1 rule: all
  criteria must pass. Criterion steps are classed, hashed, canonically
  serializable objects with a stable criterion id, declared evidence key,
  normalized parameters, and one internal evaluation closure. Bare functions,
  arbitrary lists, unclassed or unknown criteria, duplicate criterion ids, and
  non-serializable parameters fail closed. Validation reconstructs the
  evaluator from the ledgr-owned criterion id and normalized payload; a stored
  replacement closure is never trusted as criterion authority. The internal
  criterion-step shape is not a public third-party extension contract.
- Every business objective carries canonical `plan_json` and a deterministic
  `business_objective_hash` over its ordered criterion-step payloads. Changing
  a threshold, embedded diagnostic source, or criterion order changes the
  hash. The hash is objective provenance only: constructing an objective must
  not alter run, config, snapshot, sweep, candidate, promotion, session, or
  walk-forward identity. V1 objectives do not evaluate a sweep, rank
  candidates, select a winner, promote a candidate, or persist evidence.
- `ledgr_sweep_filter()` evaluates a business objective over completed
  candidates and returns an all-candidates, candidate-by-criterion tear-down
  table. The default `as_tibble()` and `print()` surfaces preserve every
  evaluated candidate and criterion row, including failed criteria and
  ineligible candidates, in sweep order. Rows report the measured value,
  threshold, pass/fail, reason, evidence source, criterion parameters,
  `business_objective_hash`, `sweep_id`, and available metric, cost, risk, and
  snapshot provenance. The candidate-level `eligible` flag is an all-pass
  summary, not a rank or pick. The result contains no chosen candidate and is
  rejected explicitly by `ledgr_candidate()`, `ledgr_promote()`, and
  walk-forward selection. The filter is not a dplyr replacement, writes no
  persisted artifact, and changes no execution, sweep, candidate, promotion,
  run, session, config, snapshot, or walk-forward identity.
- The v1 ledgr-owned criteria threshold already-computed evidence. Maximum
  drawdown and minimum trades consume sweep-summary `max_drawdown` and
  `n_trades`; the canonical signed drawdown metric is exposed by the criterion
  as a positive loss magnitude before thresholding. Positive trajectory
  regresses cumulative log equity on the
  zero-based retained-row index; `slope_min` is measured in log-equity units
  per retained observation and is independent of K-Ratio. Even trades uses the
  largest closed-trade count share across four equal-duration bins of the
  sweep scoring interval. Even profit uses the largest absolute
  `realized_pnl` share of total absolute closed-trade realized P&L. Stable runs
  uses the longest consecutive WIN or LOSS run in deterministic `trade_seq`
  order, with BREAKEVEN resetting a run and an all-BREAKEVEN history reporting
  a longest run of zero. Missing, invalid, or indeterminate evidence fails
  closed with classed objective conditions; no criterion reconstructs evidence
  from fills or positions.
- Stable region is ledgr's strict-lattice operationalization of Pardo's broad
  parameter-plateau idea, not a transcription of a Pardo formula. It requires
  a complete factorial grid whose axes are numeric, logical, Date/POSIXct, or
  explicitly ordered factors. Plain factors, unsupported or collapsed axes,
  duplicate tuples, and sparse grids fail closed. Adjacency is Manhattan
  distance one in level-index space. The tolerance is the median absolute
  score difference over adjacent unordered pairs; a neighbor supports a
  candidate when its normalized score is at least the candidate score minus
  that tolerance. `min_neighbors` is the only eligibility control; support
  ratio and local smoothness are audit evidence only. Boundary candidates have
  fewer available neighbors and cannot pass when `min_neighbors` exceeds that
  available count; `available_neighbors` remains visible as audit evidence.
- `ledgr_objective_diagnostic_threshold()` embeds a hashed, serializable
  snapshot of a named candidate-level output from an already-computed
  `ledgr_dsr()` or `ledgr_min_track_record()` result. Admissible v1 fields are
  DSR `dsr_probability` / `status` and MinTRL
  `min_track_record_length` / `status`. The criterion records the source
  diagnostic metadata and source hash, recomputes no diagnostic, and makes no
  profitability endorsement. Numeric diagnostic thresholds preserve `Inf` and
  `-Inf` as determinate boundary evidence, while `NA` and `NaN` fail closed.
  PBO/CSCV is sweep-level evidence and is not an admissible candidate-level
  threshold criterion.

<a id="contract-result-trade-statistics"></a>
### Trade Statistics

- `n_trades` is the number of closed trade rows. It is not the number of fill
  rows.
- `win_rate` is the share of closed trade rows with strict `realized_pnl > 0`.
  Breakeven trades are not wins. If no closed trade rows exist, `win_rate` is
  `NA`.
- `avg_trade` is the mean `realized_pnl` across closed trade rows. If no closed
  trade rows exist, `avg_trade` is `NA`.
- `time_in_market` is the share of public equity rows with absolute
  `positions_value > 1e-6`.

## Documentation Contract

<a id="contract-documentation-example-style"></a>
### Example Style And Article Placement

- README and narrative vignettes use the base pipe `|>` in canonical examples.
- README and narrative vignettes prefer `filter()` / `between()` over
  `subset()` for applied data preparation examples.
- First-path examples avoid raw `as.POSIXct(..., tz = "UTC")` boilerplate when
  `ledgr_utc()` or an equivalent clearer pattern is available.
- Narrative run-list and comparison examples should demonstrate curated print
  defaults directly. Full-column access belongs in explicit tibble-compatible
  "dig deeper" examples.
- Background and positioning articles such as "Who ledgr is for" and "Why
  ledgr is built in R" live under `vignettes/articles/` for pkgdown. They must
  not be installed vignettes, copied into `inst/doc/`, or mixed into the
  operational vignette set.

<a id="contract-documentation-discovery"></a>
### Installed Documentation Discovery

- README must document noninteractive installed-documentation discovery for
  `Rscript` and agent workflows, including `vignette(package = "ledgr")` and
  `system.file("doc", package = "ledgr")`.
- Core function-level help pages must point to relevant installed articles with
  both interactive and browser-free lookup paths. The browser-free form is
  `system.file("doc", "<article>.html", package = "ledgr")`.
- Feature-map and pulse-inspection help pages must point to the installed
  articles that teach them: `strategy-development` for strategy authoring and
  `indicators` for indicator contracts and pulse views.
- Package help (`?ledgr` / `?ledgr-package`) must include a compact "Start
  here" spine with `vignette(package = "ledgr")`,
  `system.file("doc", package = "ledgr")`, and direct paths for core installed
  articles such as `strategy-development`, `metrics-and-accounting`, and
  `experiment-store`.

<a id="contract-documentation-indicators"></a>
### Indicator Teaching

- Indicator concepts must have one installed teaching article, `indicators`,
  covering built-in indicators, TTR-backed indicators, feature IDs, and warmup
  `NA`. `ttr-indicators` must not remain as a parallel installed teaching
  vignette unless the contract explicitly documents why both are needed.
- TTR-specific reference facts, including multi-output column names and
  detailed warmup formulas, belong in function help such as `?ledgr_ind_ttr`
  and `?ledgr_ind_ttr_warmup_rules`.
- Indicator documentation should make the adapter boundary explicit: ledgr owns
  feature contracts and execution semantics, while calculation packages such as
  TTR and future adapters supply indicator computations through normal
  `ledgr_indicator` objects.
- README and package help should describe ledgr as a deterministic backtesting
  core that connects to the R finance ecosystem through adapters. This
  positioning must not claim unshipped adapters or frame ledgr as replacing
  existing finance packages.
- Help pages must not present pkgdown-only background articles as installed
  vignettes.
- Visible vignette code must not depend on hidden setup helpers. Prefer
  exported helpers such as `ledgr_utc()` or show local helpers before first
  visible use.
- Installed documentation must not expose stale retired article paths such as
  `ttr-indicators` after `indicators` is the single installed indicator
  article, unless the contract explicitly documents why both are needed.
- Indicator teaching distinguishes bounded and history-dependent definitions,
  teaches `stable_after` as first-valid rather than converged, and cites the
  measured gap-recovery ranges as evidence instead of promising convergence.
  It states that availability-aware preparation runs sampled causality and
  `fn`/`series_fn` checks, that a passing check is not a proof of causality,
  and that dense execution runs neither.

<a id="contract-documentation-strategy-context"></a>
### Strategy Context Teaching

- `man/ledgr_strategy_context.Rd` owns one explicit reference table for every
  public runtime context member and plane. It records dense and availability
  applicability, shape, axis, units, missingness and counterpart, and
  distinguishes metadata, state reads and intent constructors. A documentation
  contract compares the authored table in both directions against real dense
  and availability callbacks; it is not generated from the observed fixture.
- Strategy-authoring documentation teaches both allocation pipelines and
  hold-and-edit intent. Representative executed examples cover equal-member
  allocation, a predicate with a held nonmember, momentum with an explicit
  missing-input hold guard, deliberate zero weights, and stateful entry and
  exit. They state that helper weights use allocatable rather than total NAV
  when held nonmembers are reserved, and that hold does not bypass risk or
  guarantee an absence of fills.
- The causal-history article (`vignettes/causal-history.qmd`) opens with a
  short path that opens an existing sealed snapshot and completes a run
  before any point-in-time ingestion, which the next article in the reading
  flow teaches. With executed output it then teaches the default
  `ledgr_history_frame()` read, the matrix adapter, `ledgr_history_info()`,
  explicit instrument-selection and missing-value choices, structural
  sufficiency (never presented as indicator warm-up or convergence), the
  bounded and history-dependent indicator classes, carry evidence including
  `carried_input_share`, reading return features rather than differencing
  carried closes, the vintage feature view against restated bar history,
  one continuous history across walk-forward windows, the advice to read a
  finite lookback, and the boundary that ledgr guarantees causal access
  through its own history, feature and fact readers while strategy code
  outside them is the author's responsibility, checked best-effort by
  preflight.
- One executed portfolio-estimation example goes from a history read through
  an estimator and `ledgr_align_weights()` to `ledgr_target_rebalance()`
  with no manual timestamp removal, column-name reconstruction or second
  history reader. It explains estimation exclusion separately from execution
  intent: an instrument the estimate drops receives a zero target from the
  rebalance unless its held position is passed in `keep`.

<a id="contract-documentation-terminal-disclosure"></a>
### Terminal And Release Disclosure

- Public documentation distinguishes settlement evidence, a modeled terminal
  disposition, stale valuation, frozen valuation, refusal and the
  frozen-at-end bound, and never calls assumption-backed equity exact.
- Release claim boundary (terminal-outcomes synthesis Section 6). Until
  accepted upstream untraded-bar
  evidence (ledgr-research LFB-027) and a passing end-to-end record are
  linked, no release note, README, article or record may claim that the
  reference Sharadar workflow ages halted or untraded carried prices or
  prevents fills on them. The survivorship-bias and missing-data-and-sessions
  articles and the current release notes state this boundary verbatim: "Halts and untraded sessions that a data source encodes as zero-volume bars carrying the previous close, as the reference Sharadar data does, are still read as observed prices: they can fill and they bypass valuation ageing and freezing." A documentation-contract
  test pins the sentence. It is removed only together with linking that
  evidence.

## Verification Contract

<a id="contract-verification-release-gates"></a>
### Release Gates

- Full regression tests must pass before release-ticket completion.
- Package check target:
  `R CMD check --no-manual --no-build-vignettes ledgr_*.tar.gz`.
- Coverage gate target: at least 80% total coverage via `tools/check-coverage.R`.
- CI must run acceptance tests before the full package check and include at
  least Ubuntu and Windows R CMD check coverage appropriate to the release,
  with coverage-threshold enforcement where configured.
- For tickets that touch executable R code, package metadata, vignettes,
  pkgdown, DuckDB persistence, snapshots, file paths, time zones, encodings, or
  other OS-sensitive behavior, a local WSL/Ubuntu gate should run before push.
  At minimum this gate runs package tests and `R CMD check` under Linux; docs
  and pkgdown changes also require a local pkgdown build where practical.
- Release-ticket execution should follow `inst/design/release_ci_playbook.md`.
  Main-branch CI and tag-triggered CI are separate gates; a release tag is not
  valid until the tag workflow is green.
- A change to causal-history preparation, worker transport or fold memory is
  measured with the paired history resource protocol (v12 Section 10, Cut 16
  decision (9)) on the registered H1 Sharadar workload and host: one
  full-history `ledgr_run()` and one two-candidate `ledgr_sweep()` on two
  local workers, a baseline arm built fresh from the pre-change code and the
  candidate arm run alternately three times each, the worker and every
  descendant process sampled about every 0.2 seconds, and medians compared.
  Single-run parent working set and private commit, two-worker parent working
  set and private commit, and summed parent-plus-daemon private commit each
  pass at no more than 1.10 times the paired baseline; summed working set is
  disclosed as a lower bound and is not gated. A miss is corrected or receives
  an explicit maintainer exception with a user-visible limit and a routed
  follow-up.
- The same record shows that sequential, current-dispatch and
  staged-dispatch sweeps agree on final equity, trade count, execution seed
  and the snapshot, strategy and reproduction-key hashes; reports
  `(workers - 1) * staged_invariant_bytes / total_private_commit`, below
  10 percent of which shared-memory transport stays rejected and at or above
  which it is routed to a maintainer decision rather than implemented; and
  records the read-side peak of the full decision trace through
  `ledgr_results(bt, "diagnostics")` and `ledgr_run_explain()`; a material
  read cost is routed as performance work and never answered by weakening
  the trace.

<a id="contract-verification-diagnostic-inputs"></a>
### Diagnostic Input Gates

- Effective-trial and DSR inputs remain completed comparable panels.
  Attempted, incomplete and failed counts never become trials, raw-trial
  counts or return columns, and naming an incomplete or failed candidate in a
  panel, effective-trial or DSR input fails with
  `ledgr_sweep_returns_candidate_not_completed`. On a mixed sweep these
  diagnostics equal those of a sweep over its completed candidates only,
  apart from sweep identity and the excluded-ID disclosure.

<a id="contract-verification-terminal-and-snapshot-gates"></a>
### Terminal And Snapshot Gates

- The terminal-outcomes gate is one registry. Each of the eight synthesis
  Section 7 cases has one owning ticket and one failure-sensitive block, as
  mapped in the v0.2.2 packet's `terminal_outcomes_reconciliation.md`. A
  vendor-neutral release fixture crossing a held terminal, freeze, resume and
  frozen-at-end case runs only through the long-window suite's
  `run_release.R --release` entry point.
- Fold-core trust-boundary work must include regression coverage proving that
  public production run/sweep paths cannot reach fold execution without the
  accepted sealed-snapshot guard. The guard belongs at entry/setup boundaries,
  not inside per-cell, per-feature, or per-pulse hot loops.
- The production rule-4 encoder must reproduce its re-derived conformance
  roots on both Windows and Ubuntu CI. Hosted-CI clocks are advisory;
  the registered one-thread local benchmark host owns the absolute cost and
  growth gates.

<a id="contract-verification-store-and-codebase-gates"></a>
### Store And Codebase Gates

- Package code obtains a persistent store connection through
  `ledgr_store_open(path, mode)` or passes a borrowed, cached or
  caller-supplied connection through its one existing-connection check. The
  connection census must fail if a package entry opens, accepts, borrows or
  attaches a persistent ledgr store without checking the current store version
  and format fingerprint first.
- The format fingerprint enumerates every namespace binding matching
  `^ledgr_[a-z_]+_(schema|rule)_version$` whose value is a length-one atomic
  scalar. A dedicated serializer applies radix key order without depending on
  locale collation. Its independent literal oracle fails when a matching
  binding is omitted, an extra binding appears or either replacement constant
  keeps its former name.
- The fast codebase-contract gate parses package and test source once. Its
  private-helper detector fails when a top-level, non-exported, non-S3 helper
  has no static or resolved string reference in `R/` or `tests/testthat`; hooks
  are classified separately. This is the executable no-uncalled-function
  floor, not a claim that every one-caller helper is justified.
- The same gate derives literal elements of `rlang::abort()` and
  `rlang::warn()` class vectors, including positional class arguments,
  resolvable class-builder calls and statically resolvable package wrappers.
  Every public `ledgr_` element must have both an alias and prose description
  in the condition reference. A newly introduced wholly private class uses
  the `ledgr_internal_` prefix. Dynamic class expressions remain visible in
  the source census and require explicit review disposition.
- A zero-row source-census family is a valid typed table with its declared
  columns. The fast boundary block runs every empty family through the shared
  summary arithmetic and pins the report to that boundary; the full populated
  census remains a report/check tool rather than running inside the test lane.
- A structural check fails if availability run, sweep or fold code builds a
  per-instrument bar list, aligned bar matrices or static bar views beside the
  causal-history substrate, or gives a fold stage other than observe-and-settle
  a substrate reader (LTB-0293). A daemon refuses a missing, stale or altered
  staged-invariant identity before any strategy call, fill or result write
  (LTB-0294).
