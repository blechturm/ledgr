# Cut 16 decision reconciliation

Role: record; LDG-3071 reconciliation of the Cut 16 decisions against what
shipped. `tickets.yml` (Cut 16 `decisions`) holds the decisions themselves and
remains the authority for their wording; this table does not restate or
reinterpret them. It records, for each decision, where `contracts.md` states
the shipped rule, which code carries it, which registered test block fails if
it regresses and which section of the accepted v12 synthesis it changed.

Tree: integration head `5efe10cc` plus the LDG-3071 reconciliation commits.
Every code owner below was read on that tree, and every cited block passed in
the full suite recorded in the LDG-3071 evidence. LTB-0416 checks this table:
each decision number in `tickets.yml` has exactly one row, each row cites a
`contracts.md` anchor that resolves or names a route, and each cited block is
registered and defined once.

Status values:

- `stated`: `contracts.md` already stated the shipped rule in present tense;
- `fixed here`: LDG-3071 added or corrected the contract sentence, without a
  behavior change (see Contract changes below);
- `routed: <owner>`: the decision binds no contract rule here, and its open
  part has the named owner.

"v12" is
[`rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md`](../rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md);
its appended "As implemented" section points each changed section back to
these rows. Decisions (1) to (9) bound v12 at the cut and change none of its
sections, apart from naming the helpers v12 left to the spec cut and
exercising its conditional snapshot-hash change.

## Decisions

| # | Decision, in one sentence | Contract | Code owner | Registered test | v12 section changed | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | History ships on the availability path only; dense execution stays frozen and has no history. | [Pulse Data](../contracts.md#contract-context-pulse-data); [Inspection](../contracts.md#contract-context-inspection) | `R/history-frame.R` `ledgr_history_context_view()`; `R/pulse-snapshot.R` `ledgr_pulse_snapshot()` | LTB-0297, LTB-0302 | none | stated |
| 2 | One preparation from the data start owns bars, facts, the venue axis, expected-session masks and feature inputs, with no second history reader or hidden fetch. | [Fold Core](../contracts.md#contract-execution-fold-core); [Scoring And Feature Start](../contracts.md#contract-execution-window-start) | `R/history-substrate.R` `ledgr_history_substrate()`; `R/backtest-runner.R` `ledgr_run_fold_impl()` | LTB-0293, LTB-0304, LTB-0196 | none | stated |
| 3 | The public surface is one immutable history result read by `ledgr_history_frame()`, with `ledgr_history_matrix()` as an adapter, defaulting to full lookback, admissible instruments, kept missing values and the wide layout. | [Pulse Data](../contracts.md#contract-context-pulse-data) | `R/history-frame.R` `ledgr_history_frame()`, `ledgr_history_matrix()` | LTB-0297, LTB-0298 | Section 3 (names the reader and adapter) | stated |
| 4 | `ledgr_history_policy()` is experiment-level config with price carry 5, output carry off and the default segment guard; missingness, carry, validity, readiness and admission stay distinct, and return and volatility rows never consume carried prices. | [Config Policies](../contracts.md#contract-config-policies); [Units, Price Basis And Universe](../contracts.md#contract-availability-units-and-universe); [Strict Features](../contracts.md#contract-context-strict-features) | `R/history-policy.R` `ledgr_history_policy()`; `R/history-treatment.R` `ledgr_history_input_carry_calculation()` | LTB-0287, LTB-0292, LTB-0311 | Section 5 (names the policy constructor) | stated |
| 5 | Indicators declare bounded or history-dependent behavior; bounded `fn` windows use `requires_bars`, recursive work restarts per treated-input segment and `stable_after` stays first-valid. | [Indicator Computation](../contracts.md#contract-context-indicator-computation); [Strict Features](../contracts.md#contract-context-strict-features) | `R/indicator.R` `ledgr_indicator()`; `R/indicator-history.R` `ledgr_indicator_history_catalogue()`; `R/history-features.R` `ledgr_history_feature_calculate()` | LTB-0307, LTB-0310 | none | stated |
| 6 | Config identity moves to rule 4, civil-time facts move the snapshot hash to rule 4, the store format advances to 121 and then 122, and older artifacts refuse with no compatibility code. | [Execution And Feature Identity](../contracts.md#contract-execution-identity); [Snapshot Identity](../contracts.md#contract-snapshot-identity-and-verification); [Current Store Format](../contracts.md#contract-persistence-current-format) | `R/config-hash.R` `ledgr_identity_rule_version`; `R/snapshots-hash.R` `ledgr_snapshot_content_hash_rule_version`; `R/experiment-store-schema.R` `ledgr_experiment_store_schema_version` | LTB-0250, LTB-0251, LTB-0260, LTB-0287, LTB-0290 | Section 9 (its conditional snapshot-hash change happened) | stated |
| 7 | Parallel history staging is ordinary R over one immutable substrate for one or two persistent local workers, larger counts run unmeasured, and shared memory stays rejected below the 10 percent trigger. | [Event Staging](../contracts.md#contract-execution-event-staging); [Release Gates](../contracts.md#contract-verification-release-gates) | `R/history-substrate.R` `ledgr_history_worker_stage()`, `ledgr_history_worker_take()`; `R/sweep.R` `ledgr_sweep_impl()` | LTB-0294, LTB-0295, LTB-0296 | none | stated |
| 8 | Under `carry_test_state` the test windows are one economic chain that keeps boundary decisions, fills, marks and entitlements, while flat and standalone windows keep their terminal rule. | [Walk-Forward Fold Lifecycle](../contracts.md#contract-execution-walk-forward-folds); [Fills And Sweep Restoration](../contracts.md#contract-result-fills-and-sweep-restoration) | `R/walk-forward.R` `ledgr_walk_forward_continue_windows()`, `ledgr_walk_forward_pending_entitlements()` | LTB-0303 | none | stated |
| 9 | The H6 resource gates are exact and separate for the single-run parent, the two-worker parent and the parent-plus-daemon private commit, and a miss needs a correction or a maintainer disposition. | [Release Gates](../contracts.md#contract-verification-release-gates) | no package code: ledgr-research `experiments/history-wave-h6/check_h6.R` recomputes the gates | none: an external empirical gate on the H1 workload, not a package test | none | stated |
| 10 | `ledgr_pulse_snapshot()` is external inspection derived from an experiment, its parameters and a cutoff; strategies read history only through `ledgr_history_frame()`, and the snapshot-and-universe form stays the dense branch. | [Inspection](../contracts.md#contract-context-inspection); [Pulse Data](../contracts.md#contract-context-pulse-data) | `R/pulse-snapshot.R` `ledgr_pulse_snapshot()`, `ledgr_pulse_inspection()` | LTB-0300, LTB-0302 | Section 8 (inspection takes its configuration from the experiment) | stated |
| 11 | A corporate action with an event clock and no knowledge clock is known when it becomes effective in every execution mode, which corrects dense dividend economics. | [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) | `R/availability-facts.R` `ledgr_corporate_action_assumed_knowledge()` | LTB-0286, LTB-0356 | Section 1 (a dense correction) | stated |
| 12 | A Date-valued corporate-action entitlement, effective or payment time names the session close, and a Date-valued knowledge time names the session open. | [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) | `R/availability-facts.R` `ledgr_fact_resolve_civil_frame()` | LTB-0292, LTB-0356 | Section 4 (corporate-action event Dates name the close) | stated |
| 13 | Catalogue return and volatility rows never consume a carried price, and a custom definition may declare `input_carry = "excluded"`, which enters rule-4 identity and refuses on catalogue rows. | [Indicator Computation](../contracts.md#contract-context-indicator-computation); [Strict Features](../contracts.md#contract-context-strict-features) | `R/indicator.R` `ledgr_indicator()`; `R/history-features.R` `ledgr_feature_certify()`; `R/indicator-history.R` `ledgr_indicator_history_catalogue()` | LTB-0314, LTB-0307, LTB-0309 | Sections 5 and 6 (adds the custom declaration) | stated |
| 14 | TTR `aroon` has an `n + 1` dependency width in both modes, and the resulting dense change is a catalogue bug fix. | [Indicator Computation](../contracts.md#contract-context-indicator-computation); [TTR Adapter](../contracts.md#contract-context-ttr-adapter); [Strict Features](../contracts.md#contract-context-strict-features) | `R/indicator-ttr.R` `ledgr_ttr_infer_requires_bars()`; `R/indicator-history.R` `ledgr_indicator_history_catalogue()` | LTB-0308, LTB-0307 | Sections 1 and 6 (a dense correction and a catalogue width) | stated |
| 15 | A bounded window counts the instrument's expected sessions and so spans a lifetime-inactive interval, history-dependent rows restart after it, readiness restarts per segment and output carry fills only a cell whose own input is missing. | [Strict Features](../contracts.md#contract-context-strict-features); [Pulse Data](../contracts.md#contract-context-pulse-data) | `R/history-features.R` `ledgr_history_feature_calculate()`, `ledgr_history_feature_planes()` | LTB-0093, LTB-0310, LTB-0311, LTB-0319 | Sections 5 and 6 (how windows, readiness and output carry meet an inactive interval) | stated |
| 16 | The single data-start rule and the carried walk-forward chain apply to availability experiments only, and dense runs keep their frozen restart. | [Scoring And Feature Start](../contracts.md#contract-execution-window-start); [Walk-Forward Fold Lifecycle](../contracts.md#contract-execution-walk-forward-folds) | `R/history-substrate.R` `ledgr_history_calculation_start()`; `R/walk-forward.R` `ledgr_walk_forward_eval_fold()`, `ledgr_walk_forward_continue_windows()` | LTB-0196, LTB-0306 | Sections 2 and 8 (narrowed to availability experiments) | stated |
| 17 | Simplify before proving: Workstream 46 maps and simplifies the history system before Workstream 44 measures it, and the deferred items keep named owners. | none: a sequencing decision; its product rules are decisions (22) to (24) | `history_representation_map.md`; `tools/codebase-structure.R` mode-branch census | LTB-0331, LTB-0332 | none | routed: execution-core consolidation for mode-branch removal and settlement state as data, and the maintainer for a lazy-evidence history result ([macro plan](macro_plan.md#deferred-history-simplification)) |
| 18 | A durable run registers before it prepares features, so a refused feature leaves one `FAILED` run row with no strategy call, ledger event or equity row, while sweep and precompute refusals write nothing. | [Feature Path](../contracts.md#contract-context-feature-path); [Fold Evidence And Early Exit](../contracts.md#contract-persistence-fold-evidence) | `R/backtest-runner.R` `ledgr_run_fold_impl()`; `R/history-features.R` `ledgr_history_feature_refuse_lookahead()` | LTB-0315 | Section 6 (a refusal before artifacts still records the run row) | stated |
| 19 | A custom indicator whose id matches a built-in runs its own function in both modes and is never replaced by the built-in. | [Strict Features](../contracts.md#contract-context-strict-features) | `R/backtest-runner.R` `ledgr_feature_defs_from_config()` | LTB-0321 | Section 1 (a dense correction) | stated |
| 20 | A terminal interval ends bounded windows as well as carry, so after a relisting a bounded definition needs `requires_bars` fresh rows before it is ready. | [Strict Features](../contracts.md#contract-context-strict-features) | `R/history-features.R` `ledgr_history_feature_inputs()`, `ledgr_history_feature_calculate()`, `ledgr_history_feature_planes()` | LTB-0320, LTB-0413 | Sections 5 and 6 (terminal barrier for bounded windows) | stated |
| 21 | A ready cell whose calculation is not finite reports `calculation_non_finite`, so every cell that is not `calculation_valid` carries a reason. | [Pulse Data](../contracts.md#contract-context-pulse-data) | `R/history-features.R` `ledgr_history_feature_planes()`; `R/history-frame.R` `ledgr_history_feature_evidence()` | LTB-0319 | Section 5 (adds an evidence reason) | stated |
| 22 | Membership and trading-status segments are counted for the guard but not stored, and lifetime and terminal segments stay stored for history reads. | [Provider, Knowledge And Timing](../contracts.md#contract-availability-provider-and-timing); [Fold Core](../contracts.md#contract-execution-fold-core) | `R/history-substrate.R` `ledgr_history_substrate()`, `ledgr_history_membership_segment_counts()`, `ledgr_history_segment_limit_check()` | LTB-0332, LTB-0335 | Section 7 (stored segments only for lifetime and terminal facts) | stated |
| 23 | Preparation refuses a membership, trading-status or lifetime fact without a knowledge time, classedly and before any side effect. | [Provider, Knowledge And Timing](../contracts.md#contract-availability-provider-and-timing) | `R/availability-provider.R` `ledgr_fact_knowledge_refuse()`, reached from `ledgr_availability_require_fact_knowledge()` and `ledgr_history_substrate()` | LTB-0336, LTB-0079 | Section 2 (the knowledge assumption now applies to corporate actions only) | stated |
| 24 | Every membership shape is counted by the canonical fact counter, so a family the removed same-clock counter undercounted may now refuse at its limit. | [Provider, Knowledge And Timing](../contracts.md#contract-availability-provider-and-timing) | `R/history-substrate.R` `ledgr_history_membership_fact_counts()`, `ledgr_history_membership_segment_counts()` | LTB-0337, LTB-0335 | Section 7 (one canonical count for the guard) | fixed here |
| 25 | The core architecture stays, Workstream 47 removes the four measured wastes with byte-identical results apart from the recorded availability feature-engine identity, and the output-sensitive fact compiler waits for the real-data fact census. | [Strict Features](../contracts.md#contract-context-strict-features); [Event Staging](../contracts.md#contract-execution-event-staging) | `R/sweep.R` `ledgr_sweep_impl()`; `R/pulse-snapshot.R` `ledgr_pulse_inspection()`; `R/availability-provider-prepared.R` `ledgr_availability_prepared_membership_plan()`; `R/history-treatment.R` `ledgr_history_input_carry_calculation()`, `ledgr_history_carry_last_barrier()`; `R/history-features.R` `ledgr_history_feature_inputs()` | LTB-0391, LTB-0392, LTB-0393, LTB-0144, LTB-0276 | none | fixed here |
| 26 | A fresh sweep that stages two or more workers runs one garbage collection right after it releases the feature payload, and sequential sweeps do not. | [Event Staging](../contracts.md#contract-execution-event-staging) | `R/sweep.R` `ledgr_sweep_impl()` | LTB-0393 | none | fixed here |
| 27 | A Date-valued corporate-action event without a knowledge time is known at the open of its venue session and stays effective at its close. | [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) | `R/availability-facts.R` `ledgr_corporate_action_assumed_knowledge()`, `ledgr_fact_resolve_civil_frame()` | LTB-0356 | Section 4 (an assumed Date knowledge time is the session open) | stated |
| 28 | A disposition or quantity-effect corporate action with an effective clock but no entitlement clock refuses classedly instead of acting on its effective date. | [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) | `R/corporate-action-settlement.R` `ledgr_corporate_action_plan()` | LTB-0357 | Section 4 (a refusal beside the three-way clock rule) | stated |
| 29 | A feature history read returns each earlier cell as computed at its own pulse, while bar history stays restated with the cutoff's knowledge. | [Pulse Data](../contracts.md#contract-context-pulse-data) | `R/history-frame.R` `ledgr_history_vintage_planes()`, `ledgr_history_feature_evidence()` | LTB-0409, LTB-0413 | Sections 3 and 7 (feature cells are a vintage view) | stated |
| 30 | Strategy preflight is a best-effort static check, not a sandbox, and ledgr guarantees only that its own history, feature and fact APIs return data known at the decision time. | [Reproducibility And Preflight](../contracts.md#contract-strategy-reproducibility); [Pulse Data](../contracts.md#contract-context-pulse-data) | `R/strategy-preflight.R` `ledgr_strategy_preflight()`, `ledgr_strategy_functional_target()`, `ledgr_pulse_context_private_fields()` | LTB-0371 | none | stated |
| 31 | A knowledge time supplied on a corporate-action row is kept and never replaced by a session open. | [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) | `R/availability-facts.R` `ledgr_corporate_action_assumed_knowledge()` | LTB-0356 | Section 4 | stated |
| 32 | For membership, trading-status and lifetime facts a supplied knowledge time is kept, and `knowledge = "assume_effective"` only fills a missing one. | [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts); [Provider, Knowledge And Timing](../contracts.md#contract-availability-provider-and-timing) | `R/availability-facts.R` `ledgr_fact_knowledge_time()` | LTB-0358 | none | stated |
| 33 | A cash-dividend row with an effective clock but no entitlement clock refuses with the decision (28) condition instead of never posting. | [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) | `R/corporate-action-settlement.R` `ledgr_corporate_action_entitled_subtypes()`, `ledgr_corporate_action_plan()` | LTB-0359 | Section 4 | stated |
| 34 | Membership-snapshot headers are ordered by resolved knowledge time after civil resolution, and the resulting hash changes for mixed Date and POSIXct inputs are intended. | [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) | `R/availability-facts.R` `ledgr_fact_family_settle()` | LTB-0360 | Section 4 (header order of mixed civil inputs) | stated |
| 35 | The decision (28) and (33) refusals also apply in dense runs, with no execution-mode branch. | [Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) | `R/corporate-action-settlement.R` `ledgr_corporate_action_plan()` | LTB-0357, LTB-0359 | Section 1 (a dense correction) | stated |

## Decisions recorded outside the numbered list

Maintainer, 2026-10-22, on the LDG-3071 STOP: contract wording fix,
pre-Cut-16 contradiction (Cut 6 sentence vs Cut 12 LDG-3014 default). [Config
Policies](../contracts.md#contract-config-policies) said that
`ledgr_valuation_stale()` has no default `max_sessions`, while
`R/availability-policy.R` `ledgr_valuation_stale()` defaults to 5 and
[Activation And Session Calendar](../contracts.md#contract-availability-activation-and-calendar)
states that default. The stale clause is deleted; no behavior changes. No v12
section is involved.

The maintainer decision of 2026-10-17 in the LDG-3060 evidence (the terminal
state follows the shared lifetime resolver, so a relisting clears it, while
the carry barrier stays sticky from the first knowable terminal column) is
stated in [Units, Price Basis And Universe](../contracts.md#contract-availability-units-and-universe),
carried by `R/history-substrate.R` `ledgr_history_substrate_terminal_planes()`
(its `sticky` plane) and pinned by LTB-0292 and LTB-0320. It
belongs to v12 Section 5, whose sticky terminal barrier it keeps.

## Gaps and owners

Fixed in LDG-3071 (contract sentences only, no behavior change):

- (24): Provider, Knowledge And Timing now says that one canonical count
  covers every membership shape.
- (25) and (26): Event Staging now states that a fresh sweep and pulse
  inspection release the feature payload once the runtime projection exists,
  and that only a sweep staging two or more workers collects garbage before
  staging.
- (22): Fold Core no longer says the substrate owns fact segments in general;
  it names the lifetime and terminal segments and the provider execution plan
  that holds membership and trading-status facts once.

Routed, each with an owner already recorded:

- (17): mode-branch removal, the two carry implementations and corporate-action
  settlement state as data belong to execution-core consolidation; a
  lazy-evidence history result would change v12 Section 3 and waits for a
  maintainer decision on the LDG-3069 measurement (8.79 times the value bytes
  at the H1 shape). Both are in
  [macro_plan.md](macro_plan.md#deferred-history-simplification).
- (7): LDG-3069 measured the shared-memory trigger at 0.1218, above
  10 percent. It is a maintainer question in the same macro-plan section;
  nothing is implemented, as decision (7) requires.
- (25): LDG-3080 found the output-sensitive fact compiler not material at the
  adapter-v003 density (fact compilation 3.9 percent of preparation). Adapter
  v003 sets knowledge equal to effective time, so a source with real
  knowledge clocks first needs the exposure assessment v12 Section 11
  ("Revision optimization") assigns before any compiler work.
- (30): cutoff-bound context internals or a strategy sandbox are parked in
  `horizon.md` ("2026-10-21 [execution] Cutoff-bound context internals or a
  strategy sandbox").

No registered package block, by design:

- (9): the resource gates run on the private H1 workload. The ledgr-research
  checker `check_h6.R` recomputes every peak from the raw samples and fails on
  a miss; a package test cannot run that workload.

## Contract changes

LDG-3071 made these `contracts.md` edits. None changes behavior; each makes a
sentence say what the code already does, in present tense, once:

- [Config Policies](../contracts.md#contract-config-policies): the stale
  "no default `max_sessions`" clause is deleted (maintainer, 2026-10-22).
- [Fold Core](../contracts.md#contract-execution-fold-core): the substrate's
  fact holdings are named (decision 22).
- [Event Staging](../contracts.md#contract-execution-event-staging): feature
  payload release and the two-worker collection (decisions 25 and 26).
- [Units, Price Basis And Universe](../contracts.md#contract-availability-units-and-universe):
  the return and volatility rule points to its section instead of naming a
  ticket as its owner, and the stray `max_sessions = 0` sentence moves to the
  valuation-horizon default in
  [Activation And Session Calendar](../contracts.md#contract-availability-activation-and-calendar).
- [Provider, Knowledge And Timing](../contracts.md#contract-availability-provider-and-timing):
  the missing-knowledge refusal is stated without "decision (27) keeps this
  refusal", and the canonical count is stated (decision 24).
- [Current Store Format](../contracts.md#contract-persistence-current-format):
  schema 122 is described by what it stores rather than by the ticket that
  removed a column.
- [Strict Features](../contracts.md#contract-context-strict-features): the
  terminal-interval rule no longer names a workstream.
- [Feature Path](../contracts.md#contract-context-feature-path): decision
  (18) is cited as a decision, not as a ticket-file location.
