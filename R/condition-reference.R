#' ledgr condition classes
#'
#' ledgr uses stable top-level condition classes for public cost-model,
#' timing-model, execution-window, saved-sweep, and retained-series failures.
#' User tests should assert on these classes instead of parsing message text.
#'
#' @section Cost and timing classes:
#' `ledgr_cost_model_unspecified` is raised when a public execution entry point
#' omits `cost_model` or supplies `NULL`. Use [ledgr_cost_zero()] for explicit
#' zero-cost execution.
#'
#' `ledgr_invalid_cost_model` is raised for invalid cost-model objects,
#' malformed cost plans, unsupported cost-plan steps, or invalid cost-model
#' constructor arguments.
#'
#' `ledgr_invalid_cost_chain_order` is raised when a cost chain violates the
#' required order: price-transform steps before explicit-fee steps.
#'
#' `ledgr_invalid_timing_model` is raised for non-ledgr timing-model objects or
#' malformed ledgr timing-model payloads.
#'
#' @section Fill seam classes:
#' `ledgr_invalid_fill_proposal` and `ledgr_invalid_fill_context` are raised at
#' the internal proposal/resolver seam when a cost resolver receives the wrong
#' object shape. They are stable top-level classes for tests that exercise that
#' seam directly.
#'
#' @section Execution window classes:
#' `ledgr_run_window_too_short` is raised when a run window contains fewer than
#' two executable pulses. Next-bar fill semantics require a decision pulse and a
#' later execution pulse.
#'
#' @section Accounting classes:
#' `ledgr_invalid_lot_fill` is raised when the lot-accounting layer receives an
#' invalid fill side, quantity, price, fee, or instrument id. Invalid lot input
#' fails closed because the ledger event stream and lot state must not diverge.
#'
#' @section Snapshot hash classes:
#' `ledgr_snapshot_hash_invalid_timestamp` is raised when snapshot hashing sees
#' a non-POSIXct `ts_utc` representation. Snapshot hashes fail closed on driver
#' timestamp representation drift instead of silently re-keying sealed data.
#'
#' `ledgr_snapshot_hash_rule_unsupported` is raised when a snapshot does not
#' carry the current content-hash rule.
#' `ledgr_snapshot_hash_order_invalid` is raised when source rows are not in
#' the bytewise order required by the current snapshot-hash rule.
#'
#' `ledgr_fact_civil_date_unresolved` is raised when a fact Date does not map
#' to exactly one declared open venue session. `ledgr_session_boundary_unresolved`
#' applies the same refusal to an availability-aware execution boundary.
#' `ledgr_corporate_action_clock_missing` is raised, at its knowledge cutoff,
#' for a knowable corporate action with neither entitlement nor effective time.
#' `ledgr_invalid_history_policy` is raised for malformed history-policy
#' constructor arguments or a non-current policy object.
#' `ledgr_history_identity_mismatch` and `ledgr_precomputed_history_mismatch`
#' refuse non-current causal-history identity in configs and precomputed data.
#' `ledgr_invalid_history_substrate` refuses a substrate owned by a different
#' snapshot, policy, universe, range or representation version.
#' `ledgr_history_duplicate_bar`, `ledgr_history_outside_axis` and
#' `ledgr_history_unknown_instrument` refuse ambiguous or out-of-domain history
#' preparation and reads. `ledgr_history_segment_missing` refuses an invalid
#' internal segment plane rather than returning fabricated state.
#' `ledgr_history_segment_limit_exceeded` reports an instrument, fact family,
#' fact count, segment count, ratio and limit when causal preparation exceeds
#' its declared bound. `ledgr_invalid_history_treatment` and
#' `ledgr_invalid_history_field` refuse malformed treatment evidence or an
#' unsupported bar field. `ledgr_history_unavailable` refuses a history read
#' from a dense or snapshot-and-universe pulse context, which has no causal
#' history. `ledgr_invalid_history_request` refuses malformed
#' [ledgr_history_frame()] and [ledgr_history_sufficient()] arguments, and
#' `ledgr_invalid_history_result` refuses a matrix or sufficiency query on a
#' value that is not, or no longer matches, a `ledgr_history` result.
#' `ledgr_pulse_snapshot_availability_required` refuses experiment-derived
#' [ledgr_pulse_snapshot()] inspection of a dense experiment, and
#' `ledgr_pulse_inspection_stopped` refuses an inspection cutoff whose
#' observe-and-settle stage stops before the strategy context is built.
#' `ledgr_staged_history_mismatch` refuses a worker task
#' before candidate execution when its staged immutable input is absent or has
#' a different identity.
#'
#' @section Store-format classes:
#' `ledgr_store_rebuild_required` is raised when a persistent store is older,
#' newer, unmarked, malformed, or carries a format fingerprint different from
#' this ledgr build. Before the first CRAN release ledgr does not migrate old
#' stores: rebuild them with the current package.
#'
#' @section Availability classes:
#' `ledgr_invalid_valuation_policy` is raised for malformed stale-valuation
#' policies or constructor arguments.
#'
#' `ledgr_availability_inactive` is raised when a membership-universe rule is
#' requested without the fact families needed to activate availability-aware
#' execution.
#'
#' `ledgr_availability_sessions_required` is raised when availability-aware
#' execution lacks a complete session calendar.
#'
#' `ledgr_backtest_availability_unsupported` is raised when `ledgr_backtest()`
#' receives a snapshot that declares point-in-time facts; use
#' `ledgr_experiment()` and `ledgr_run()`.
#'
#' `ledgr_promote_identity_mismatch` is a warning raised when a promoted
#' candidate's recorded identities differ from the promoting experiment's.
#'
#' `ledgr_sessions_incomplete` is raised when the declared session calendar
#' does not cover the requested start and end of a run, sweep, run window or
#' walk-forward fold.
#'
#' `ledgr_membership_universe_not_found` is raised when a membership-universe
#' rule names a universe that is not declared by the snapshot.
#'
#' `ledgr_compiled_availability_unsupported` is raised before execution when
#' availability-aware execution is combined with the compiled spot-FIFO path.
#'
#' `ledgr_policy_schema_mismatch` is raised when a config or stored run carries
#' a non-current corporate-action or valuation policy schema. Current stores
#' carry schema 2; ledgr does not infer, migrate, or reinterpret older policy
#' records.
#'
#' `ledgr_strategy_provenance_missing` is raised when a current run row exists
#' but its required strategy-provenance row is absent.
#'
#' `ledgr_session_time_ambiguous` and `ledgr_session_time_nonexistent` are
#' raised when a local session wall time resolves to multiple UTC instants or
#' no UTC instant. Supply an explicit POSIXct instant to disambiguate a real
#' fall-back time.
#'
#' `ledgr_fact_ambiguous_membership_shape` and
#' `ledgr_fact_invalid_membership_list` are raised for mixed row/list
#' membership input or malformed constituent lists.
#'
#' `ledgr_facts_inspection_invalid_args` is raised for incompatible history or
#' resolution arguments. `ledgr_facts_scope_not_found` is raised when the
#' requested family and scope are not declared. Snapshot inspection raises
#' `ledgr_facts_snapshot_not_sealed` or
#' `ledgr_facts_snapshot_hash_mismatch` before returning evidence from an
#' unsealed or corrupted artifact.
#'
#' `ledgr_session_adapter_invalid` and `ledgr_session_override_invalid` are
#' raised for malformed qlcal adapter inputs or replacement rows.
#'
#' `ledgr_indicator_gap_parity` is raised when a custom bounded indicator's
#' `fn` on its window disagrees with its `series_fn` value beyond the declared
#' tolerance at a sampled causality position; its fields name the feature,
#' instrument and session. `ledgr_feature_lookahead_detected` is raised when a
#' feature recomputed from the history ending at a sampled session differs
#' from its prepared value; its fields name the feature, instrument and
#' session and carry both values.
#'
#' `ledgr_invalid_indicator_declaration` (parent `ledgr_invalid_args`) is
#' raised for an invalid indicator history class, required-field set or
#' tolerance. `ledgr_indicator_history_contradiction` is its subclass for
#' contradictory declarations: a strict window declared history-dependent, a
#' tolerance without a bounded `fn`/`series_fn` pair, or a registered TTR form
#' declared against its catalogue row.
#'
#' `ledgr_invalid_strategy_state` is raised when availability-aware asset state
#' is not a named list keyed only by instruments on the current public axis.
#'
#' `ledgr_target_sizing_unavailable` is raised when an availability-aware
#' rebalance helper needs a permissible mark it cannot obtain: to reserve the
#' exposure of a preserved holding, or to keep a held member that has no
#' current close. A member without a current close is otherwise skipped for
#' that rebalance and recorded, not an error.
#'
#' `ledgr_restricted_target` and `ledgr_nonmember_exposure_increase` are raised
#' when availability-aware strategy output violates the decision-time target
#' contract. `ledgr_post_risk_inadmissible` is raised when a risk step does not
#' preserve or reduce the strategy target. These conditions carry the affected
#' instrument IDs.
#'
#' `ledgr_short_exposure_unsupported` is raised before fill acceptance when an
#' availability-aware target would open or enlarge short exposure. Existing
#' short quantities may be held or reduced; this does not define short-account
#' financing.
#'
#' `ledgr_affordability_reconciliation_failed` is raised when recorded active
#' cash diverges from the bounded-affordability virtual ledger beyond the
#' engine's fixed tolerance.
#'
#' `ledgr_run_terminal_evidence_invalid` is raised when persisted terminal
#' completion evidence is malformed, disagrees with the run calendar or stored
#' status, or does not match the finalized equity prefix and stop diagnostic.
#'
#' `ledgr_run_explanation_unavailable` is raised when a run has no retained
#' decision trace for the requested instrument and timestamp. ledgr does not
#' infer the missing intent from current strategy code or other artifacts.
#'
#' @section Saved sweep classes:
#' `ledgr_invalid_sweep_id` is raised when a saved sweep id is not a non-empty,
#' non-whitespace ASCII character scalar of at most 256 bytes.
#'
#' `ledgr_sweep_id_exists` is raised when `ledgr_sweep_save()` would overwrite
#' an existing saved sweep id.
#'
#' `ledgr_sweep_not_found` is raised when `ledgr_sweep_open()` is called with
#' a structurally valid saved sweep id that is not present in the experiment
#' store.
#'
#' `ledgr_sweep_snapshot_not_found` is raised when a saved sweep's snapshot is
#' not present in the provided experiment store.
#'
#' `ledgr_sweep_snapshot_hash_mismatch` is raised when the snapshot id exists
#' but its hash differs from the hash stored on the saved sweep.
#'
#' `ledgr_sweep_schema_incompatible` is raised when saved sweep tables,
#' columns, or artifact schema versions are not compatible with the current
#' ledgr version.
#'
#' `ledgr_invalid_sweep_retention` is raised when `ledgr_sweep_retention()` or
#' `ledgr_sweep(..., retain = )` receives an invalid retention policy.
#'
#' `ledgr_sweep_returns_unretained` is raised when callers ask for retained
#' return rows from a scalar-only sweep.
#'
#' `ledgr_sweep_returns_candidate_not_found` is raised when retained returns are
#' requested for an unknown `candidate_id`.
#'
#' `ledgr_sweep_returns_candidate_not_completed` is raised when retained
#' returns are requested for a failed candidate or for a completed candidate
#' whose retained rows are missing.
#'
#' `ledgr_sweep_returns_first_row_invalid` is raised when retained return rows
#' do not carry the required structural first-row `NA_real_` period return.
#'
#' `ledgr_sweep_returns_incomplete_panel` is raised when callers request a
#' complete retained-return panel but selected completed candidates do not share
#' one common timestamp grid after first-row handling.
#' `ledgr_validation_pbo_incomplete_panel` is a compatibility alias on the same
#' condition for future PBO/CSCV adapters.
#'
#' `ledgr_sweep_trades_unretained` is raised when callers ask for retained
#' closed-trade evidence from a sweep that did not opt into trade retention.
#'
#' `ledgr_sweep_trades_candidate_not_found` is raised when retained trades are
#' requested for an unknown `candidate_id`.
#'
#' `ledgr_sweep_trades_candidate_not_completed` is raised when retained trades
#' are requested for a failed candidate.
#'
#' `ledgr_sweep_trades_candidate_not_retained` is raised when retained trades
#' are missing for a completed candidate that reports closed trades.
#'
#' `ledgr_incomplete_sweep_candidate` is raised when candidate extraction is
#' requested for an `INCOMPLETE` sweep row. `ledgr_promote_incomplete_candidate`
#' is raised when promotion receives an incomplete candidate. Incomplete
#' prefixes remain evidence and never become executable candidates.
#'
#' `ledgr_validation_pbo_invalid_s` is raised when a PBO/CSCV request supplies
#' an invalid `S` subset count.
#'
#' `ledgr_validation_pbo_too_few_candidates` is raised when PBO/CSCV has fewer
#' than two completed candidates.
#'
#' `ledgr_validation_pbo_too_few_observations` is raised when PBO/CSCV has too
#' few post-first-row observations for the requested partitioning.
#'
#' `ledgr_validation_pbo_invalid_metric` is raised when a PBO/CSCV metric is not
#' callable or does not return one finite numeric score per candidate.
#'
#' `ledgr_validation_pbo_invalid_panel` is raised when PBO/CSCV receives a
#' non-finite retained-return panel after the structural first-row handling.
#'
#' `ledgr_validation_pbo_invalid_threshold` is raised when a PBO/CSCV threshold
#' is not a finite numeric scalar.
#'
#' `ledgr_validation_min_trl_invalid_reference` is raised when a minimum track
#' record length request supplies an invalid reference Sharpe ratio.
#'
#' `ledgr_validation_min_trl_invalid_confidence` is raised when a minimum track
#' record length request supplies a confidence level outside `(0, 1)`.
#'
#' `ledgr_validation_min_trl_invalid_risk_free` is raised when a minimum track
#' record length request supplies an invalid per-period risk-free return.
#'
#' `ledgr_validation_min_trl_too_few_observations` is raised when minimum track
#' record length has too few post-first-row observations.
#'
#' `ledgr_validation_min_trl_invalid_returns` is raised when minimum track
#' record length receives non-finite or constant retained returns.
#'
#' `ledgr_validation_k_ratio_invalid_periods_per_year` is raised when a K-Ratio
#' request omits or supplies an invalid expected observations-per-year value.
#'
#' `ledgr_validation_k_ratio_invalid_risk_free` is raised when K-Ratio receives
#' an invalid per-period risk-free return.
#'
#' `ledgr_validation_k_ratio_too_few_observations` is raised when K-Ratio has
#' fewer than three return observations.
#'
#' `ledgr_validation_k_ratio_invalid_returns` is raised when K-Ratio receives
#' non-finite returns, an excess return at or below `-1`, or a cumulative
#' log-wealth path whose slope standard error is zero or non-finite.
#'
#' `ledgr_validation_cluster_invalid_threshold` is raised when retained-return
#' clustering receives an invalid correlation-distance threshold.
#'
#' `ledgr_validation_cluster_too_few_candidates` is raised when retained-return
#' clustering has fewer than two completed candidates.
#'
#' `ledgr_validation_cluster_too_few_observations` is raised when retained-return
#' clustering has too few post-first-row observations.
#'
#' `ledgr_validation_cluster_invalid_returns` is raised when retained-return
#' clustering receives non-finite or constant retained returns.
#'
#' `ledgr_validation_dsr_invalid_effective_trials` is raised when DSR receives
#' an invalid effective independent trial count.
#'
#' `ledgr_validation_dsr_too_few_candidates` is raised when DSR has fewer than
#' two completed candidates.
#'
#' `ledgr_validation_dsr_invalid_confidence` is raised when DSR receives a
#' confidence level outside `(0, 1)`.
#'
#' `ledgr_validation_dsr_invalid_risk_free` is raised when DSR receives an
#' invalid per-period risk-free return.
#'
#' `ledgr_validation_dsr_too_few_observations` is raised when DSR has too few
#' post-first-row observations.
#'
#' `ledgr_validation_dsr_invalid_returns` is raised when DSR receives
#' non-finite, constant, or otherwise unsupported retained returns.
#'
#' @section Business-objective classes:
#' `ledgr_invalid_business_objective` is raised when an objective is empty or
#' does not have the required classed, serialized, all-pass shape.
#'
#' `ledgr_duplicate_objective_criterion` is raised when an objective contains
#' duplicate criterion ids.
#'
#' `ledgr_business_objective_hash_mismatch` is raised when an objective's
#' canonical plan JSON or hash does not match its criterion steps.
#'
#' `ledgr_invalid_objective_criterion` is raised when a criterion is unclassed,
#' malformed, or has invalid parameters. `ledgr_unknown_objective_criterion`
#' is raised for criterion ids that ledgr does not own in v1.
#'
#' `ledgr_objective_non_serializable_params` is raised when criterion
#' parameters cannot be represented by the canonical objective plan.
#' `ledgr_objective_criterion_hash_mismatch` is raised when a criterion hash
#' does not match its serialized payload.
#'
#' `ledgr_invalid_objective_verdict` is raised when an internal criterion
#' evaluator returns a malformed verdict. `ledgr_objective_missing_evidence`,
#' `ledgr_objective_non_finite_evidence`, and
#' `ledgr_objective_invalid_evidence` fail closed on unusable criterion input.
#'
#' `ledgr_invalid_diagnostic_threshold` is raised for unsupported diagnostic
#' result classes, columns, comparisons, or malformed embedded evidence.
#' `ledgr_diagnostic_source_hash_mismatch` is raised when an embedded
#' diagnostic snapshot does not match its source hash.
#'
#' `ledgr_stable_region_invalid_min_neighbors` is raised for an invalid
#' support-neighbor threshold. `ledgr_stable_region_invalid_grid` and
#' `ledgr_stable_region_invalid_metric` cover malformed lattice or score input.
#' More specific lattice classes are `ledgr_stable_region_unordered_axis`,
#' `ledgr_stable_region_unsupported_axis`, `ledgr_stable_region_collapsed_axis`,
#' `ledgr_stable_region_duplicate_tuple`,
#' `ledgr_stable_region_incomplete_grid`, and
#' `ledgr_stable_region_no_adjacent_pairs`.
#'
#' `ledgr_invalid_sweep_filter_input` and
#' `ledgr_sweep_filter_no_completed_candidates` cover malformed or empty
#' sweep-filter inputs. `ledgr_sweep_filter_diagnostic_source_mismatch` is
#' raised when embedded diagnostic evidence came from a different return
#' panel. `ledgr_sweep_filter_parameter_missing` and
#' `ledgr_sweep_filter_ambiguous_parameter` cover strict-lattice parameter
#' extraction failures. `ledgr_invalid_sweep_filter_result` covers malformed
#' filter evidence. `ledgr_sweep_filter_not_candidate`,
#' `ledgr_sweep_filter_promotion_forbidden`, and
#' `ledgr_sweep_filter_walk_forward_forbidden` explicitly prevent the
#' all-candidates evidence result from entering selection surfaces; all three
#' inherit from `ledgr_sweep_filter_evidence_only`.
#'
#' `ledgr_missing_package` is raised when a public optional-package adapter is
#' requested but the package is not installed.
#'
#' @section Metric-context warning classes:
#' `ledgr_metric_context_cadence_mismatch` is emitted when a daily metric
#' context is applied to evidence whose observed median interval is clearly
#' subdaily. The warning identifies a possible annualization mismatch; it does
#' not change metric values, metric recipes, stored evidence, or identity.
#'
#' @section Walk-forward classes:
#' `ledgr_walk_forward_metric_missing` is raised when a selection rule requests
#' a metric column that is absent from the train-window score rows.
#'
#' `ledgr_walk_forward_metric_class_invalid` is raised when a selection metric
#' is not classified as valid for v1 scalar selection.
#'
#' `ledgr_walk_forward_no_selection` is raised when all candidate values for the
#' requested selection metric are missing, `NA`, `NaN`, or infinite. Inside
#' `ledgr_walk_forward()` it ends the session only under
#' `no_selection = "fail"`; the default `"previous"` reuses the latest
#' training selection, or runs no test window before the first one.
#'
#' `ledgr_walk_forward_gapped_carry` (also
#' `ledgr_walk_forward_invalid_fold_window`) is raised by
#' `ledgr_walk_forward()` under `opening_state_policy = "carry_test_state"`
#' when a pulse lies between two consecutive test windows, before any work
#' runs. Its message names the first gap; use contiguous folds or
#' `"flat_test_state"`.
#'
#' `ledgr_walk_forward_overlapping_carry` (also
#' `ledgr_walk_forward_invalid_fold_window`) is raised by
#' `ledgr_walk_forward()` under `opening_state_policy = "carry_test_state"`
#' when a test window does not start after the previous one ends (overlap or
#' reverse order), before any work runs. Its message names the first such pair;
#' use contiguous folds or `"flat_test_state"`.
#'
#' `ledgr_walk_forward_candidate_key_missing` is raised when the train-window
#' score rows passed to a selection rule do not include a `candidate_key` column.
#'
#' `ledgr_walk_forward_test_run_failed` is raised when a selected test run
#' cannot produce a usable test score row.
#'
#' `ledgr_walk_forward_session_not_found` is raised when walk-forward
#' inspection helpers cannot find the requested session.
#'
#' `ledgr_walk_forward_snapshot_hash_mismatch` is raised when the supplied
#' snapshot does not match the persisted walk-forward session identity.
#'
#' `ledgr_walk_forward_snapshot_override_mismatch` is raised when an explicit
#' snapshot override for candidate extraction has a different `snapshot_id` or
#' `snapshot_hash` than the walk-forward result locator.
#'
#' `ledgr_walk_forward_invalid_session` is raised when persisted walk-forward
#' session rows, linked test runs, or identity fields cannot be reopened
#' safely.
#'
#' `ledgr_walk_forward_latest_without_rationale` is raised when extracting
#' `fold_seq = "latest"` without an explicit `selection_rationale`.
#'
#' `ledgr_walk_forward_candidate_not_found` is raised when a requested
#' walk-forward fold does not contain a completed selected candidate.
#'
#' @section Availability reason codes:
#' Availability-aware diagnostics use this closed vocabulary. An accepted fill
#' without a complication uses an empty reason code.
#'
#' | Exact token | Stage | Action / interpretation |
#' | --- | --- | --- |
#' | `decision_recorded` | decision | unrestricted decision recorded |
#' | `empty_public_domain` | decision | empty axis; no targets emitted |
#' | `trading_halted` | restriction | hold or exit only |
#' | `quotation_only` | restriction | hold or exit only |
#' | `status_unknown` | restriction | hold or exit only |
#' | `status_unknown_or_conflicting` | restriction | hold or exit only |
#' | `lifetime_inactive` | restriction / terminal | hold or exit until the terminal resolves under the declared policy |
#' | `stale_mark_reduction` | risk | reducing target accepted with a stale mark |
#' | `stale_mark_pass_through` | risk | unchanged target accepted with a stale mark |
#' | `risk_mark_unavailable` | risk stop | accepted prefix finalized incomplete |
#' | `restricted_target` | target validation | classed strategy-result failure |
#' | `nonmember_exposure_increase` | target validation | classed strategy-result failure |
#' | `post_risk_inadmissible` | post-risk validation | classed risk failure |
#' | `short_exposure_unsupported` | target validation | classed strategy-result failure |
#' | `insufficient_cash` | execution | cash-consuming fill rejected |
#' | `execution_bar_missing` | execution | no fill; no standing order |
#' | `membership_changed_before_execution` | execution diagnostic | report only; never an execution gate |
#' | `final_pulse_no_execution` | execution | no fill without a later pulse |
#' | `affordability_reconciled` | reconciliation | accepted fills applied and reconciled |
#' | `affordability_reconciliation_failed` | reconciliation stop | accepted prefix finalized incomplete |
#' | `valuation_horizon_exhausted` | valuation stop | under `exhausted = "refuse"`, or a holding with no mark at all; accepted prefix finalized incomplete |
#' | `valuation_frozen` | valuation / restriction | under `exhausted = "freeze"`, carried at its last close; hold or exit only, no transaction |
#' | `valuation_freeze_exited` | valuation diagnostic | a frozen holding resumed, was exited or was disposed |
#' | `terminal_disposition` | valuation | modeled terminal outcome posted as one `DISPOSITION` before the strategy decision |
#' | `terminal_settlement_unsupported` | valuation stop | unlabeled or refused terminal; holding preserved, no fabricated settlement |
#' | `terminal_mark_unavailable` | valuation stop | the terminal choice needs a mark that does not exist; accepted prefix finalized incomplete |
#' | `corporate_action_cash_refused` | valuation stop | a held corporate-action cash settlement refused by policy; accepted prefix finalized incomplete |
#' | `corporate_action_quantity_refused` | valuation stop | a held quantity effect or unmodeled fact refused by policy; accepted prefix finalized incomplete |
#' | `fold_exception` | error | failed after transaction rollback |
#'
#' For the connected workflow and interpretation, see
#' `vignette("survivorship-bias", package = "ledgr")` and
#' `system.file("doc", "survivorship-bias.html", package = "ledgr")`.
#'
#' @section Evidence, assumptions and refusals:
#' Availability-aware results keep six cases apart.
#'
#' - **Settlement evidence.** A supported settlement fact or a scheduled
#'   corporate-action row disposes a holding as recorded. It is evidence, not
#'   an assumption, and it pre-empts every modeled choice.
#' - **Modeled terminal disposition** (`terminal_disposition`). A labeled
#'   `known_inactive` holding without settlement evidence is disposed under the
#'   declared `held_terminal_position` choice. The result names the choice and
#'   whether it was declared or a default, for example
#'   `default: assumed worthless`.
#' - **Stale valuation** (`stale_close`). A holding is valued at a close no
#'   older than `max_sessions`. Cash and quantity stay exact.
#' - **Frozen valuation** (`valuation_frozen`, `frozen_close`). Under
#'   `exhausted = "freeze"` a holding is carried at its last close beyond
#'   `max_sessions`. Cash and quantity stay exact, but equity during the freeze
#'   is an assumption-backed estimate, not an exact value.
#' - **Refusal.** `valuation_horizon_exhausted`,
#'   `terminal_settlement_unsupported`, `terminal_mark_unavailable`,
#'   `corporate_action_cash_refused` and `corporate_action_quantity_refused`
#'   stop the run `INCOMPLETE` and keep the accepted prefix. Nothing is
#'   fabricated. A dense run has no typed stop: its corporate-action refusals
#'   raise `ledgr_corporate_action_unsupported`.
#' - **Frozen-at-end bound.** `total_return_if_frozen_worthless` in
#'   [ledgr_valuation_summary()] restates endpoint return with holdings still
#'   frozen at the end valued at zero. It is a bound, not a corrected return,
#'   Sharpe ratio or drawdown.
#'
#' @section Related existing classes:
#' `ledgr_run_not_found` is raised when run-store inspection helpers cannot
#' find the requested run. `ledgr_unresolved_feature_id` is raised when callers
#' ask for a concrete feature ID before parameterized feature declarations have
#' been resolved. `ledgr_strategy_error` wraps an error raised by user strategy
#' code while preserving the original error as its parent.
#'
#' @examples
#' err <- try(ledgr_cost_spread_bps(-1), silent = TRUE)
#' inherits(attr(err, "condition"), "ledgr_invalid_cost_model")
#'
#' err <- try(
#'   ledgr_cost_chain(ledgr_cost_fixed_fee(1), ledgr_cost_spread_bps(5)),
#'   silent = TRUE
#' )
#' inherits(attr(err, "condition"), "ledgr_invalid_cost_chain_order")
#'
#' @name ledgr_condition_classes
#' @aliases ledgr_condition_classes ledgr_cost_model_unspecified
#' @aliases ledgr_invalid_cost_chain_order ledgr_invalid_cost_model
#' @aliases ledgr_invalid_timing_model ledgr_invalid_fill_proposal
#' @aliases ledgr_invalid_fill_context ledgr_run_not_found
#' @aliases ledgr_unresolved_feature_id ledgr_run_window_too_short
#' @aliases ledgr_invalid_lot_fill
#' @aliases ledgr_snapshot_hash_invalid_timestamp
#' @aliases ledgr_snapshot_hash_rule_unsupported
#' @aliases ledgr_snapshot_hash_order_invalid
#' @aliases ledgr_store_rebuild_required ledgr_invalid_store
#' @aliases ledgr_invalid_valuation_policy ledgr_availability_inactive
#' @aliases ledgr_availability_sessions_required ledgr_backtest_availability_unsupported
#' @aliases ledgr_sessions_incomplete ledgr_promote_identity_mismatch
#' @aliases ledgr_membership_universe_not_found
#' @aliases ledgr_compiled_availability_unsupported
#' @aliases ledgr_policy_schema_mismatch
#' @aliases ledgr_strategy_provenance_missing
#' @aliases ledgr_session_time_ambiguous ledgr_session_time_nonexistent
#' @aliases ledgr_fact_ambiguous_membership_shape ledgr_fact_invalid_membership_list
#' @aliases ledgr_facts_inspection_invalid_args ledgr_facts_scope_not_found
#' @aliases ledgr_facts_snapshot_not_sealed ledgr_facts_snapshot_hash_mismatch
#' @aliases ledgr_session_adapter_invalid ledgr_session_override_invalid
#' @aliases ledgr_indicator_gap_parity
#' @aliases ledgr_invalid_indicator_declaration ledgr_indicator_history_contradiction
#' @aliases ledgr_invalid_strategy_state ledgr_strategy_error
#' @aliases ledgr_target_sizing_unavailable ledgr_restricted_target
#' @aliases ledgr_nonmember_exposure_increase ledgr_post_risk_inadmissible
#' @aliases ledgr_short_exposure_unsupported
#' @aliases ledgr_affordability_reconciliation_failed
#' @aliases ledgr_run_terminal_evidence_invalid ledgr_run_explanation_unavailable
#' @aliases ledgr_invalid_sweep_id ledgr_sweep_id_exists
#' @aliases ledgr_sweep_not_found
#' @aliases ledgr_sweep_snapshot_not_found ledgr_sweep_snapshot_hash_mismatch
#' @aliases ledgr_sweep_schema_incompatible
#' @aliases ledgr_invalid_sweep_retention ledgr_sweep_returns_unretained
#' @aliases ledgr_sweep_returns_candidate_not_found
#' @aliases ledgr_sweep_returns_candidate_not_completed
#' @aliases ledgr_sweep_returns_first_row_invalid
#' @aliases ledgr_sweep_returns_incomplete_panel
#' @aliases ledgr_sweep_trades_unretained
#' @aliases ledgr_sweep_trades_candidate_not_found
#' @aliases ledgr_sweep_trades_candidate_not_completed
#' @aliases ledgr_sweep_trades_candidate_not_retained
#' @aliases ledgr_incomplete_sweep_candidate ledgr_promote_incomplete_candidate
#' @aliases ledgr_validation_pbo_incomplete_panel ledgr_missing_package
#' @aliases ledgr_validation_pbo_invalid_s
#' @aliases ledgr_validation_pbo_too_few_candidates
#' @aliases ledgr_validation_pbo_too_few_observations
#' @aliases ledgr_validation_pbo_invalid_metric
#' @aliases ledgr_validation_pbo_invalid_panel
#' @aliases ledgr_validation_pbo_invalid_threshold
#' @aliases ledgr_validation_min_trl_invalid_reference
#' @aliases ledgr_validation_min_trl_invalid_confidence
#' @aliases ledgr_validation_min_trl_invalid_risk_free
#' @aliases ledgr_validation_min_trl_too_few_observations
#' @aliases ledgr_validation_min_trl_invalid_returns
#' @aliases ledgr_invalid_business_objective
#' @aliases ledgr_duplicate_objective_criterion
#' @aliases ledgr_business_objective_hash_mismatch
#' @aliases ledgr_invalid_objective_criterion
#' @aliases ledgr_unknown_objective_criterion
#' @aliases ledgr_objective_non_serializable_params
#' @aliases ledgr_objective_criterion_hash_mismatch
#' @aliases ledgr_invalid_objective_verdict
#' @aliases ledgr_objective_missing_evidence
#' @aliases ledgr_objective_non_finite_evidence
#' @aliases ledgr_objective_invalid_evidence
#' @aliases ledgr_invalid_diagnostic_threshold
#' @aliases ledgr_diagnostic_source_hash_mismatch
#' @aliases ledgr_stable_region_invalid_min_neighbors
#' @aliases ledgr_stable_region_invalid_grid
#' @aliases ledgr_stable_region_invalid_metric
#' @aliases ledgr_stable_region_unordered_axis
#' @aliases ledgr_stable_region_unsupported_axis
#' @aliases ledgr_stable_region_collapsed_axis
#' @aliases ledgr_stable_region_duplicate_tuple
#' @aliases ledgr_stable_region_incomplete_grid
#' @aliases ledgr_stable_region_no_adjacent_pairs
#' @aliases ledgr_invalid_sweep_filter_input
#' @aliases ledgr_sweep_filter_no_completed_candidates
#' @aliases ledgr_sweep_filter_diagnostic_source_mismatch
#' @aliases ledgr_sweep_filter_parameter_missing
#' @aliases ledgr_sweep_filter_ambiguous_parameter
#' @aliases ledgr_invalid_sweep_filter_result
#' @aliases ledgr_sweep_filter_evidence_only
#' @aliases ledgr_sweep_filter_not_candidate
#' @aliases ledgr_sweep_filter_promotion_forbidden
#' @aliases ledgr_sweep_filter_walk_forward_forbidden
#' @aliases ledgr_metric_context_cadence_mismatch
#' @aliases ledgr_walk_forward_metric_missing
#' @aliases ledgr_walk_forward_metric_class_invalid
#' @aliases ledgr_walk_forward_no_selection
#' @aliases ledgr_walk_forward_gapped_carry
#' @aliases ledgr_walk_forward_overlapping_carry
#' @aliases ledgr_walk_forward_candidate_key_missing
#' @aliases ledgr_walk_forward_test_run_failed
#' @aliases ledgr_walk_forward_session_not_found
#' @aliases ledgr_walk_forward_snapshot_hash_mismatch
#' @aliases ledgr_walk_forward_snapshot_override_mismatch
#' @aliases ledgr_walk_forward_invalid_session
#' @aliases ledgr_walk_forward_latest_without_rationale
#' @aliases ledgr_walk_forward_candidate_not_found
#'
#' @section Additional public condition classes:
#' The classes below complete the public condition index. Each message carries
#' the concrete field, identity, or operation that failed; callers should assert
#' on the class rather than parse that message.
#'
#' - `ledgr_ambiguous_bundle_output` reports the ambiguous bundle output
#'   boundary.
#' - `ledgr_availability_validation_failed` reports the availability
#'   validation failed boundary.
#' - `ledgr_availability_valuation_out_of_order` reports the availability
#'   valuation out of order boundary.
#' - `ledgr_broker_adapter_not_supported` reports the broker adapter not
#'   supported boundary.
#' - `ledgr_candidate_cost_identity_mismatch` reports the candidate cost
#'   identity mismatch boundary.
#' - `ledgr_candidate_missing_snapshot_hash` reports the candidate missing
#'   snapshot hash boundary.
#' - `ledgr_candidate_risk_identity_mismatch` reports the candidate risk
#'   identity mismatch boundary.
#' - `ledgr_candidate_snapshot_mismatch` reports the candidate snapshot
#'   mismatch boundary.
#' - `ledgr_checkpoint_failed` reports the checkpoint failed boundary.
#' - `ledgr_compiled_spot_fifo_invalid_input` reports the compiled spot fifo
#'   invalid input boundary.
#' - `ledgr_compiled_spot_fifo_unavailable` reports the compiled spot fifo
#'   unavailable boundary.
#' - `ledgr_config_invalid_json` reports the config invalid json boundary.
#' - `ledgr_config_non_deterministic` reports the config non deterministic
#'   boundary.
#' - `ledgr_config_non_finite` reports the config non finite boundary.
#' - `ledgr_config_unsupported_type` reports the config unsupported type
#'   boundary.
#' - `ledgr_corporate_action_clock_mismatch` reports the corporate action
#'   clock mismatch boundary.
#' - `ledgr_corporate_action_double_credit` reports the corporate action
#'   double credit boundary.
#' - `ledgr_corporate_action_quantity_unsupported` reports the corporate
#'   action quantity unsupported boundary.
#' - `ledgr_db_not_found` reports db was not found.
#' - `ledgr_distribution_adjusted_bars_unsupported` reports the distribution
#'   adjusted bars unsupported boundary.
#' - `ledgr_duplicate_corporate_action_event` reports duplicate corporate
#'   action event evidence.
#' - `ledgr_duplicate_corporate_action_fact` reports duplicate corporate
#'   action fact evidence.
#' - `ledgr_duplicate_executable_grid_labels` reports duplicate executable
#'   grid labels evidence.
#' - `ledgr_duplicate_fact_family` reports duplicate fact family evidence.
#' - `ledgr_duplicate_feature_id` reports duplicate feature id evidence.
#' - `ledgr_duplicate_grid_labels` reports duplicate grid labels evidence.
#' - `ledgr_duplicate_param_grid_labels` reports duplicate param grid labels
#'   evidence.
#' - `ledgr_empty_warmup_input` reports the empty warmup input boundary.
#' - `ledgr_event_buffer_capacity_exceeded` reports the event buffer capacity
#'   exceeded boundary.
#' - `ledgr_fact_identity_conflict` reports the fact identity conflict
#'   boundary.
#' - `ledgr_fact_invalid_clock_order` reports the fact invalid clock order
#'   boundary.
#' - `ledgr_fact_invalid_complete` reports the fact invalid complete
#'   boundary.
#' - `ledgr_fact_invalid_completeness` reports the fact invalid completeness
#'   boundary.
#' - `ledgr_fact_invalid_id` reports the fact invalid id boundary.
#' - `ledgr_fact_invalid_instrument` reports the fact invalid instrument
#'   boundary.
#' - `ledgr_fact_invalid_instrument_master` reports the fact invalid
#'   instrument master boundary.
#' - `ledgr_fact_invalid_interval` reports the fact invalid interval
#'   boundary.
#' - `ledgr_fact_invalid_lifetime` reports the fact invalid lifetime
#'   boundary.
#' - `ledgr_fact_invalid_logical` reports the fact invalid logical boundary.
#' - `ledgr_fact_invalid_membership_set` reports the fact invalid membership
#'   set boundary.
#' - `ledgr_fact_invalid_precedence` reports the fact invalid precedence
#'   boundary.
#' - `ledgr_fact_invalid_provenance` reports the fact invalid provenance
#'   boundary.
#' - `ledgr_fact_invalid_provenance_tier` reports the fact invalid provenance
#'   tier boundary.
#' - `ledgr_fact_invalid_shape` reports the fact invalid shape boundary.
#' - `ledgr_fact_invalid_source` reports the fact invalid source boundary.
#' - `ledgr_fact_invalid_status` reports the fact invalid status boundary.
#' - `ledgr_fact_invalid_subtype` reports the fact invalid subtype boundary.
#' - `ledgr_fact_invalid_supersession` reports the fact invalid supersession
#'   boundary.
#' - `ledgr_fact_invalid_time` reports the fact invalid time boundary.
#' - `ledgr_fact_structural_conflict` reports the fact structural conflict
#'   boundary.
#' - `ledgr_fact_unvalidated_term` reports the fact unvalidated term
#'   boundary.
#' - `ledgr_failed_sweep_candidate` reports the failed sweep candidate
#'   boundary.
#' - `ledgr_feature_factory_requires_params` reports the feature factory
#'   requires params boundary.
#' - `ledgr_feature_lookahead_detected` reports the feature lookahead
#'   detected boundary.
#' - `ledgr_grid_filter_invalid` reports the grid filter invalid boundary.
#' - `ledgr_invalid_accounting_event` reports invalid accounting event input.
#' - `ledgr_invalid_alias_map` reports invalid alias map input.
#' - `ledgr_invalid_args` reports invalid args input.
#' - `ledgr_invalid_backtest` reports invalid backtest input.
#' - `ledgr_invalid_con` reports invalid con input.
#' - `ledgr_invalid_config` reports invalid config input.
#' - `ledgr_invalid_corporate_action_event` reports invalid corporate action
#'   event input.
#' - `ledgr_invalid_corporate_action_fidelity` reports invalid corporate
#'   action fidelity input.
#' - `ledgr_invalid_corporate_action_policy` reports invalid corporate action
#'   policy input.
#' - `ledgr_invalid_event_order` reports invalid event order input.
#' - `ledgr_invalid_executable_grid` reports invalid executable grid input.
#' - `ledgr_invalid_execution_spec` reports invalid execution spec input.
#' - `ledgr_invalid_experiment` reports invalid experiment input.
#' - `ledgr_invalid_experiment_features` reports invalid experiment features
#'   input.
#' - `ledgr_invalid_experiment_strategy` reports invalid experiment strategy
#'   input.
#' - `ledgr_invalid_facts` reports invalid facts input.
#' - `ledgr_invalid_feature_def` reports invalid feature def input.
#' - `ledgr_invalid_feature_input` reports invalid feature input input.
#' - `ledgr_invalid_feature_map` reports invalid feature map input.
#' - `ledgr_invalid_feature_output` reports invalid feature output input.
#' - `ledgr_invalid_feature_params` reports invalid feature params input.
#' - `ledgr_invalid_feature_resolution` reports invalid feature resolution
#'   input.
#' - `ledgr_invalid_feature_value` reports invalid feature value input.
#' - `ledgr_invalid_fill_input` reports invalid fill input input.
#' - `ledgr_invalid_fill_intent` reports invalid fill intent input.
#' - `ledgr_invalid_fold_execution` reports invalid fold execution input.
#' - `ledgr_invalid_grid` reports invalid grid input.
#' - `ledgr_invalid_indicator_bundle` reports invalid indicator bundle input.
#' - `ledgr_invalid_ledger_event` reports invalid ledger event input.
#' - `ledgr_invalid_ledger_meta` reports invalid ledger meta input.
#' - `ledgr_invalid_metric_context` reports invalid metric context input.
#' - `ledgr_invalid_opening` reports invalid opening input.
#' - `ledgr_invalid_option` reports invalid option input.
#' - `ledgr_invalid_parallel_backend` reports invalid parallel backend input.
#' - `ledgr_invalid_parallel_workers` reports invalid parallel workers input.
#' - `ledgr_invalid_param_constructor` reports invalid param constructor
#'   input.
#' - `ledgr_invalid_param_grid` reports invalid param grid input.
#' - `ledgr_invalid_param_reference` reports invalid param reference input.
#' - `ledgr_invalid_parameterized_bundle` reports invalid parameterized
#'   bundle input.
#' - `ledgr_invalid_post_risk_targets` reports invalid post risk targets
#'   input.
#' - `ledgr_invalid_precompute_range` reports invalid precompute range input.
#' - `ledgr_invalid_precomputed_features` reports invalid precomputed
#'   features input.
#' - `ledgr_invalid_price_basis` reports invalid price basis input.
#' - `ledgr_invalid_promotion_context_summary` reports invalid promotion
#'   context summary input.
#' - `ledgr_invalid_pulse_context` reports invalid pulse context input.
#' - `ledgr_invalid_pulse_plan` reports invalid pulse plan input.
#' - `ledgr_invalid_pulse_wide_names` reports invalid pulse wide names input.
#' - `ledgr_invalid_result_table` reports invalid result table input.
#' - `ledgr_invalid_return_panel` reports invalid return panel input.
#' - `ledgr_invalid_return_panel_input` reports invalid return panel input
#'   input.
#' - `ledgr_invalid_risk_context` reports invalid risk context input.
#' - `ledgr_invalid_risk_model` reports invalid risk model input.
#' - `ledgr_invalid_risk_plan` reports invalid risk plan input.
#' - `ledgr_invalid_run` reports invalid run input.
#' - `ledgr_invalid_runtime_projection` reports invalid runtime projection
#'   input.
#' - `ledgr_invalid_snapshot` reports invalid snapshot input.
#' - `ledgr_invalid_state` reports invalid state input.
#' - `ledgr_invalid_store` reports invalid store input.
#' - `ledgr_invalid_strategy` reports invalid strategy input.
#' - `ledgr_invalid_strategy_helper` reports invalid strategy helper input.
#' - `ledgr_invalid_strategy_params` reports invalid strategy params input.
#' - `ledgr_invalid_strategy_preflight` reports invalid strategy preflight
#'   input.
#' - `ledgr_invalid_strategy_result` reports invalid strategy result input.
#' - `ledgr_invalid_strategy_signature` reports invalid strategy signature
#'   input.
#' - `ledgr_invalid_strategy_type` reports invalid strategy type input.
#' - `ledgr_invalid_sweep_candidate_input` reports invalid sweep candidate
#'   input input.
#' - `ledgr_invalid_sweep_projection` reports invalid sweep projection input.
#' - `ledgr_invalid_sweep_review_input` reports invalid sweep review input
#'   input.
#' - `ledgr_invalid_sweep_review_rank` reports invalid sweep review rank
#'   input.
#' - `ledgr_invalid_target_price` reports invalid target price input.
#' - `ledgr_invalid_timestamp` reports invalid timestamp input.
#' - `ledgr_invalid_warmup_input` reports invalid warmup input input.
#' - `ledgr_invalid_worker_dependencies` reports invalid worker dependencies
#'   input.
#' - `ledgr_invalid_worker_packages` reports invalid worker packages input.
#' - `ledgr_invariant_violation` reports the invariant violation boundary.
#' - `ledgr_legacy_feature_factory_feature_params_unsupported` reports the
#'   legacy feature factory feature params unsupported boundary.
#' - `ledgr_levered_weights` reports the levered weights boundary.
#' - `ledgr_lot_state_invariant` reports the lot state invariant boundary.
#' - `ledgr_missing_bars` reports missing bars evidence.
#' - `ledgr_missing_dependency` reports missing dependency evidence.
#' - `ledgr_missing_metric_context` reports missing metric context evidence.
#' - `ledgr_missing_optional_dependency` reports missing optional dependency
#'   evidence.
#' - `ledgr_missing_precomputed_features_warning` reports missing precomputed
#'   features warning evidence.
#' - `ledgr_mixed_metric_cadence` reports the mixed metric cadence boundary.
#' - `ledgr_negative_weights` reports the negative weights boundary.
#' - `ledgr_no_active_alias_map` reports the no active alias map boundary.
#' - `ledgr_observation_invalid_shape` reports the observation invalid shape
#'   boundary.
#' - `ledgr_observation_quarantine_duplicate` reports the observation
#'   quarantine duplicate boundary.
#' - `ledgr_ohlc_non_positive` reports the ohlc non positive boundary.
#' - `ledgr_opening_cost_basis_missing` reports the opening cost basis
#'   missing boundary.
#' - `ledgr_parallel_backend_missing` reports the parallel backend missing
#'   boundary.
#' - `ledgr_parallel_error` reports the parallel error boundary.
#' - `ledgr_parallel_strategy_not_allowed` reports the parallel strategy not
#'   allowed boundary.
#' - `ledgr_parallel_sweep_interrupted` reports the parallel sweep
#'   interrupted boundary.
#' - `ledgr_parallel_worker_failed` reports the parallel worker failed
#'   boundary.
#' - `ledgr_parallel_worker_package_missing` reports the parallel worker
#'   package missing boundary.
#' - `ledgr_param_missing` reports the param missing boundary.
#' - `ledgr_param_non_scalar` reports the param non scalar boundary.
#' - `ledgr_partial_selection` reports the partial selection boundary.
#' - `ledgr_precomputed_coverage_error` reports the precomputed coverage
#'   error boundary.
#' - `ledgr_precomputed_engine_mismatch` reports the precomputed engine
#'   mismatch boundary.
#' - `ledgr_precomputed_feature_mismatch` reports the precomputed feature
#'   mismatch boundary.
#' - `ledgr_precomputed_grid_mismatch` reports the precomputed grid mismatch
#'   boundary.
#' - `ledgr_precomputed_range_mismatch` reports the precomputed range
#'   mismatch boundary.
#' - `ledgr_precomputed_snapshot_mismatch` reports the precomputed snapshot
#'   mismatch boundary.
#' - `ledgr_precomputed_universe_mismatch` reports the precomputed universe
#'   mismatch boundary.
#' - `ledgr_promote_failed_candidate` reports the promote failed candidate
#'   boundary.
#' - `ledgr_promotion_context_write_failed` reports the promotion context
#'   write failed boundary.
#' - `ledgr_purity_violation` reports the purity violation boundary.
#' - `ledgr_quarantine_requires_sessions` reports the quarantine requires
#'   sessions boundary.
#' - `ledgr_return_panel_ambiguous_shape` reports the return panel ambiguous
#'   shape boundary.
#' - `ledgr_return_panel_invalid_ts` reports the return panel invalid ts
#'   boundary.
#' - `ledgr_return_panel_missing_candidate_ids` reports the return panel
#'   missing candidate ids boundary.
#' - `ledgr_risk_application_error` reports the risk application error
#'   boundary.
#' - `ledgr_risk_plan_parameter_missing` reports the risk plan parameter
#'   missing boundary.
#' - `ledgr_run_hash_mismatch` reports the run hash mismatch boundary.
#' - `ledgr_run_lookup_mismatch` reports the run lookup mismatch boundary.
#' - `ledgr_run_not_complete` reports the run not complete boundary.
#' - `ledgr_run_registration_failed` reports the run registration failed
#'   boundary.
#' - `ledgr_run_telemetry_failed` reports the run telemetry failed boundary.
#' - `ledgr_scalar_accessor_loop` reports the scalar accessor loop boundary.
#' - `ledgr_session_coverage_incomplete` reports the session coverage
#'   incomplete boundary.
#' - `ledgr_session_instant_duplicate` reports the session instant duplicate
#'   boundary.
#' - `ledgr_session_instant_off_date` reports the session instant off date
#'   boundary.
#' - `ledgr_session_invalid` reports the session invalid boundary.
#' - `ledgr_session_invalid_timezone` reports the session invalid timezone
#'   boundary.
#' - `ledgr_session_knowledge_late` reports the session knowledge late
#'   boundary.
#' - `ledgr_session_multiple_venues` reports the session multiple venues
#'   boundary.
#' - `ledgr_sim_pit_insufficient_shape` reports the sim pit insufficient
#'   shape boundary.
#' - `ledgr_sim_pit_invalid` reports the sim pit invalid boundary.
#' - `ledgr_snapshot_exists` reports the snapshot exists boundary.
#' - `ledgr_snapshot_fact_family_invalid` reports the snapshot fact family
#'   invalid boundary.
#' - `ledgr_snapshot_fact_family_missing` reports the snapshot fact family
#'   missing boundary.
#' - `ledgr_snapshot_fact_interval_invalid` reports the snapshot fact
#'   interval invalid boundary.
#' - `ledgr_snapshot_fact_json_invalid` reports the snapshot fact json
#'   invalid boundary.
#' - `ledgr_snapshot_fact_referential_integrity` reports the snapshot fact
#'   referential integrity boundary.
#' - `ledgr_snapshot_fact_timestamp_invalid` reports the snapshot fact
#'   timestamp invalid boundary.
#' - `ledgr_snapshot_hash_encoding_invalid` reports the snapshot hash
#'   encoding invalid boundary.
#' - `ledgr_snapshot_id_noncanonical` reports the snapshot id noncanonical
#'   boundary.
#' - `ledgr_snapshot_id_required` reports snapshot id is required.
#' - `ledgr_snapshot_membership_set_invalid` reports the snapshot membership
#'   set invalid boundary.
#' - `ledgr_snapshot_membership_set_missing` reports the snapshot membership
#'   set missing boundary.
#' - `ledgr_snapshot_not_found` reports snapshot was not found.
#' - `ledgr_snapshot_not_sealed` reports the snapshot not sealed boundary.
#' - `ledgr_snapshot_quarantine_unacknowledged` reports the snapshot
#'   quarantine unacknowledged boundary.
#' - `ledgr_snapshot_required` reports snapshot is required.
#' - `ledgr_snapshot_sessions_invalid` reports the snapshot sessions invalid
#'   boundary.
#' - `ledgr_strategy_ambient_rng_not_supported` reports the strategy ambient
#'   rng not supported boundary.
#' - `ledgr_strategy_ambient_rng_parallel` reports the strategy ambient rng
#'   parallel boundary.
#' - `ledgr_strategy_ambient_rng_resume` reports the strategy ambient rng
#'   resume boundary.
#' - `ledgr_strategy_eval_failed` reports the strategy eval failed boundary.
#' - `ledgr_strategy_hash_mismatch` reports the strategy hash mismatch
#'   boundary.
#' - `ledgr_strategy_hash_unverified` reports the strategy hash unverified
#'   boundary.
#' - `ledgr_strategy_not_function` reports the strategy not function
#'   boundary.
#' - `ledgr_strategy_parse_failed` reports the strategy parse failed
#'   boundary.
#' - `ledgr_strategy_preflight_error` reports the strategy preflight error
#'   boundary.
#' - `ledgr_strategy_source_unavailable` reports the strategy source
#'   unavailable boundary.
#' - `ledgr_strategy_tier3` reports the strategy tier3 boundary.
#' - `ledgr_sweep_candidate_not_found` reports sweep candidate was not found.
#' - `ledgr_sweep_storage_identity_mismatch` reports the sweep storage
#'   identity mismatch boundary.
#' - `ledgr_sweep_storage_invalid_identity` reports the sweep storage invalid
#'   identity boundary.
#' - `ledgr_sweep_storage_invalid_provenance` reports the sweep storage
#'   invalid provenance boundary.
#' - `ledgr_temp_store_unlink_failed` reports the temp store unlink failed
#'   boundary.
#' - `ledgr_unknown_feature_id` reports an unknown feature id.
#' - `ledgr_unsupported_accounting_model` reports unsupported accounting
#'   model use.
#' - `ledgr_unsupported_execution_start` reports unsupported execution start
#'   use.
#' - `ledgr_unsupported_param_placement` reports unsupported param placement
#'   use.
#' - `ledgr_unsupported_risk_step` reports unsupported risk step use.
#' - `ledgr_walk_forward_cold_start_warning` reports the walk forward cold
#'   start warning boundary.
#' - `ledgr_walk_forward_gap_not_supported` reports the walk forward gap not
#'   supported boundary.
#' - `ledgr_walk_forward_invalid_fold` reports the walk forward invalid fold
#'   boundary.
#' - `ledgr_walk_forward_invalid_identity` reports the walk forward invalid
#'   identity boundary.
#' - `ledgr_walk_forward_invalid_opening_state` reports the walk forward
#'   invalid opening state boundary.
#' - `ledgr_walk_forward_invalid_selection_rule` reports the walk forward
#'   invalid selection rule boundary.
#' @aliases ledgr_ambiguous_bundle_output
#' @aliases ledgr_availability_validation_failed
#' @aliases ledgr_availability_valuation_out_of_order
#' @aliases ledgr_broker_adapter_not_supported
#' @aliases ledgr_candidate_cost_identity_mismatch
#' @aliases ledgr_candidate_missing_snapshot_hash
#' @aliases ledgr_candidate_risk_identity_mismatch
#' @aliases ledgr_candidate_snapshot_mismatch
#' @aliases ledgr_checkpoint_failed
#' @aliases ledgr_compiled_spot_fifo_invalid_input
#' @aliases ledgr_compiled_spot_fifo_unavailable
#' @aliases ledgr_config_invalid_json
#' @aliases ledgr_config_non_deterministic
#' @aliases ledgr_config_non_finite
#' @aliases ledgr_config_unsupported_type
#' @aliases ledgr_corporate_action_clock_mismatch
#' @aliases ledgr_corporate_action_clock_missing
#' @aliases ledgr_corporate_action_double_credit
#' @aliases ledgr_corporate_action_quantity_unsupported
#' @aliases ledgr_corporate_action_unsupported
#' @aliases ledgr_db_not_found
#' @aliases ledgr_distribution_adjusted_bars_unsupported
#' @aliases ledgr_duplicate_corporate_action_event
#' @aliases ledgr_duplicate_corporate_action_fact
#' @aliases ledgr_duplicate_executable_grid_labels
#' @aliases ledgr_duplicate_fact_family
#' @aliases ledgr_duplicate_feature_id
#' @aliases ledgr_duplicate_grid_labels
#' @aliases ledgr_duplicate_param_grid_labels
#' @aliases ledgr_empty_warmup_input
#' @aliases ledgr_event_buffer_capacity_exceeded
#' @aliases ledgr_fact_civil_date_unresolved
#' @aliases ledgr_fact_identity_conflict
#' @aliases ledgr_fact_invalid_clock_order
#' @aliases ledgr_fact_invalid_complete
#' @aliases ledgr_fact_invalid_completeness
#' @aliases ledgr_fact_invalid_id
#' @aliases ledgr_fact_invalid_instrument
#' @aliases ledgr_fact_invalid_instrument_master
#' @aliases ledgr_fact_invalid_interval
#' @aliases ledgr_fact_invalid_lifetime
#' @aliases ledgr_fact_invalid_logical
#' @aliases ledgr_fact_invalid_membership_set
#' @aliases ledgr_fact_invalid_precedence
#' @aliases ledgr_fact_invalid_provenance
#' @aliases ledgr_fact_invalid_provenance_tier
#' @aliases ledgr_fact_invalid_shape
#' @aliases ledgr_fact_invalid_source
#' @aliases ledgr_fact_invalid_status
#' @aliases ledgr_fact_invalid_subtype
#' @aliases ledgr_fact_invalid_supersession
#' @aliases ledgr_fact_invalid_time
#' @aliases ledgr_fact_structural_conflict
#' @aliases ledgr_fact_unvalidated_term
#' @aliases ledgr_failed_sweep_candidate
#' @aliases ledgr_feature_factory_requires_params
#' @aliases ledgr_feature_lookahead_detected
#' @aliases ledgr_grid_filter_invalid
#' @aliases ledgr_history_identity_mismatch
#' @aliases ledgr_invalid_accounting_event
#' @aliases ledgr_invalid_alias_map
#' @aliases ledgr_invalid_args
#' @aliases ledgr_invalid_backtest
#' @aliases ledgr_invalid_con
#' @aliases ledgr_invalid_config
#' @aliases ledgr_invalid_corporate_action_event
#' @aliases ledgr_invalid_corporate_action_fidelity
#' @aliases ledgr_invalid_corporate_action_policy
#' @aliases ledgr_invalid_event_order
#' @aliases ledgr_invalid_executable_grid
#' @aliases ledgr_invalid_execution_spec
#' @aliases ledgr_invalid_experiment
#' @aliases ledgr_invalid_experiment_features
#' @aliases ledgr_invalid_experiment_strategy
#' @aliases ledgr_invalid_facts
#' @aliases ledgr_invalid_feature_def
#' @aliases ledgr_invalid_feature_input
#' @aliases ledgr_invalid_feature_map
#' @aliases ledgr_invalid_feature_output
#' @aliases ledgr_invalid_feature_params
#' @aliases ledgr_invalid_feature_resolution
#' @aliases ledgr_invalid_feature_value
#' @aliases ledgr_invalid_fill_input
#' @aliases ledgr_invalid_fill_intent
#' @aliases ledgr_invalid_fold_execution
#' @aliases ledgr_invalid_grid
#' @aliases ledgr_invalid_history_policy
#' @aliases ledgr_invalid_history_substrate
#' @aliases ledgr_invalid_history_treatment
#' @aliases ledgr_invalid_history_field
#' @aliases ledgr_invalid_history_request
#' @aliases ledgr_invalid_history_result
#' @aliases ledgr_invalid_indicator_bundle
#' @aliases ledgr_invalid_ledger_event
#' @aliases ledgr_invalid_ledger_meta
#' @aliases ledgr_invalid_metric_context
#' @aliases ledgr_invalid_opening
#' @aliases ledgr_invalid_option
#' @aliases ledgr_invalid_parallel_backend
#' @aliases ledgr_invalid_parallel_workers
#' @aliases ledgr_invalid_param_constructor
#' @aliases ledgr_invalid_param_grid
#' @aliases ledgr_invalid_param_reference
#' @aliases ledgr_invalid_parameterized_bundle
#' @aliases ledgr_invalid_post_risk_targets
#' @aliases ledgr_invalid_precompute_range
#' @aliases ledgr_invalid_precomputed_features
#' @aliases ledgr_invalid_price_basis
#' @aliases ledgr_invalid_promotion_context_summary
#' @aliases ledgr_invalid_pulse_context
#' @aliases ledgr_invalid_pulse_plan
#' @aliases ledgr_invalid_pulse_wide_names
#' @aliases ledgr_invalid_result_table
#' @aliases ledgr_invalid_return_panel
#' @aliases ledgr_invalid_return_panel_input
#' @aliases ledgr_invalid_risk_context
#' @aliases ledgr_invalid_risk_model
#' @aliases ledgr_invalid_risk_plan
#' @aliases ledgr_invalid_run
#' @aliases ledgr_invalid_runtime_projection
#' @aliases ledgr_invalid_snapshot
#' @aliases ledgr_invalid_state
#' @aliases ledgr_invalid_strategy
#' @aliases ledgr_invalid_strategy_helper
#' @aliases ledgr_invalid_strategy_params
#' @aliases ledgr_invalid_strategy_preflight
#' @aliases ledgr_invalid_strategy_result
#' @aliases ledgr_invalid_strategy_signature
#' @aliases ledgr_invalid_strategy_type
#' @aliases ledgr_invalid_sweep_candidate_input
#' @aliases ledgr_invalid_sweep_projection
#' @aliases ledgr_invalid_sweep_review_input
#' @aliases ledgr_invalid_sweep_review_rank
#' @aliases ledgr_invalid_target_price
#' @aliases ledgr_invalid_timestamp
#' @aliases ledgr_invalid_warmup_input
#' @aliases ledgr_invalid_worker_dependencies
#' @aliases ledgr_invalid_worker_packages
#' @aliases ledgr_invariant_violation
#' @aliases ledgr_legacy_feature_factory_feature_params_unsupported
#' @aliases ledgr_levered_weights
#' @aliases ledgr_lot_state_invariant
#' @aliases ledgr_missing_bars
#' @aliases ledgr_missing_dependency
#' @aliases ledgr_missing_metric_context
#' @aliases ledgr_missing_optional_dependency
#' @aliases ledgr_missing_precomputed_features_warning
#' @aliases ledgr_mixed_metric_cadence
#' @aliases ledgr_negative_weights
#' @aliases ledgr_no_active_alias_map
#' @aliases ledgr_observation_invalid_shape
#' @aliases ledgr_observation_quarantine_duplicate
#' @aliases ledgr_ohlc_non_positive
#' @aliases ledgr_opening_cost_basis_missing
#' @aliases ledgr_parallel_backend_missing
#' @aliases ledgr_parallel_error
#' @aliases ledgr_parallel_strategy_not_allowed
#' @aliases ledgr_parallel_sweep_interrupted
#' @aliases ledgr_parallel_worker_failed
#' @aliases ledgr_parallel_worker_package_missing
#' @aliases ledgr_param_missing
#' @aliases ledgr_param_non_scalar
#' @aliases ledgr_partial_selection
#' @aliases ledgr_precomputed_coverage_error
#' @aliases ledgr_precomputed_engine_mismatch
#' @aliases ledgr_precomputed_feature_mismatch
#' @aliases ledgr_precomputed_grid_mismatch
#' @aliases ledgr_precomputed_history_mismatch
#' @aliases ledgr_precomputed_range_mismatch
#' @aliases ledgr_precomputed_snapshot_mismatch
#' @aliases ledgr_precomputed_universe_mismatch
#' @aliases ledgr_promote_failed_candidate
#' @aliases ledgr_promotion_context_write_failed
#' @aliases ledgr_purity_violation
#' @aliases ledgr_quarantine_requires_sessions
#' @aliases ledgr_return_panel_ambiguous_shape
#' @aliases ledgr_return_panel_invalid_ts
#' @aliases ledgr_return_panel_missing_candidate_ids
#' @aliases ledgr_risk_application_error
#' @aliases ledgr_risk_plan_parameter_missing
#' @aliases ledgr_run_hash_mismatch
#' @aliases ledgr_run_lookup_mismatch
#' @aliases ledgr_run_not_complete
#' @aliases ledgr_run_registration_failed
#' @aliases ledgr_run_telemetry_failed
#' @aliases ledgr_scalar_accessor_loop
#' @aliases ledgr_session_boundary_unresolved
#' @aliases ledgr_session_coverage_incomplete
#' @aliases ledgr_session_instant_duplicate
#' @aliases ledgr_session_instant_off_date
#' @aliases ledgr_session_invalid
#' @aliases ledgr_session_invalid_timezone
#' @aliases ledgr_session_knowledge_late
#' @aliases ledgr_session_multiple_venues
#' @aliases ledgr_sim_pit_insufficient_shape
#' @aliases ledgr_sim_pit_invalid
#' @aliases ledgr_snapshot_exists
#' @aliases ledgr_snapshot_fact_family_invalid
#' @aliases ledgr_snapshot_fact_family_missing
#' @aliases ledgr_snapshot_fact_interval_invalid
#' @aliases ledgr_snapshot_fact_json_invalid
#' @aliases ledgr_snapshot_fact_referential_integrity
#' @aliases ledgr_snapshot_fact_timestamp_invalid
#' @aliases ledgr_snapshot_hash_encoding_invalid
#' @aliases ledgr_snapshot_id_noncanonical
#' @aliases ledgr_snapshot_id_required
#' @aliases ledgr_snapshot_membership_set_invalid
#' @aliases ledgr_snapshot_membership_set_missing
#' @aliases ledgr_snapshot_not_found
#' @aliases ledgr_snapshot_not_sealed
#' @aliases ledgr_snapshot_quarantine_unacknowledged
#' @aliases ledgr_snapshot_required
#' @aliases ledgr_snapshot_sessions_invalid
#' @aliases ledgr_strategy_ambient_rng_not_supported
#' @aliases ledgr_strategy_ambient_rng_parallel
#' @aliases ledgr_strategy_ambient_rng_resume
#' @aliases ledgr_strategy_eval_failed
#' @aliases ledgr_strategy_hash_mismatch
#' @aliases ledgr_strategy_hash_unverified
#' @aliases ledgr_strategy_not_function
#' @aliases ledgr_strategy_parse_failed
#' @aliases ledgr_strategy_preflight_error
#' @aliases ledgr_strategy_source_unavailable
#' @aliases ledgr_strategy_tier3
#' @aliases ledgr_sweep_candidate_not_found
#' @aliases ledgr_sweep_storage_identity_mismatch
#' @aliases ledgr_sweep_storage_invalid_identity
#' @aliases ledgr_sweep_storage_invalid_provenance
#' @aliases ledgr_temp_store_unlink_failed
#' @aliases ledgr_unknown_feature_id
#' @aliases ledgr_unsupported_accounting_model
#' @aliases ledgr_unsupported_execution_start
#' @aliases ledgr_unsupported_param_placement
#' @aliases ledgr_unsupported_risk_step
#' @aliases ledgr_validation_cluster_invalid_returns
#' @aliases ledgr_validation_cluster_invalid_threshold
#' @aliases ledgr_validation_cluster_too_few_candidates
#' @aliases ledgr_validation_cluster_too_few_observations
#' @aliases ledgr_validation_dsr_invalid_confidence
#' @aliases ledgr_validation_dsr_invalid_effective_trials
#' @aliases ledgr_validation_dsr_invalid_returns
#' @aliases ledgr_validation_dsr_invalid_risk_free
#' @aliases ledgr_validation_dsr_too_few_candidates
#' @aliases ledgr_validation_dsr_too_few_observations
#' @aliases ledgr_validation_k_ratio_invalid_periods_per_year
#' @aliases ledgr_validation_k_ratio_invalid_returns
#' @aliases ledgr_validation_k_ratio_invalid_risk_free
#' @aliases ledgr_validation_k_ratio_too_few_observations
#' @aliases ledgr_walk_forward_cold_start_warning
#' @aliases ledgr_walk_forward_gap_not_supported
#' @aliases ledgr_walk_forward_invalid_fold
#' @aliases ledgr_walk_forward_invalid_fold_window
#' @aliases ledgr_walk_forward_invalid_identity
#' @aliases ledgr_walk_forward_invalid_opening_state
#' @aliases ledgr_walk_forward_invalid_selection_rule
#' @aliases ledgr_history_duplicate_bar
#' @aliases ledgr_history_outside_axis
#' @aliases ledgr_history_unavailable
#' @aliases ledgr_pulse_snapshot_availability_required
#' @aliases ledgr_pulse_inspection_stopped
#' @aliases ledgr_history_segment_limit_exceeded
#' @aliases ledgr_history_segment_missing
#' @aliases ledgr_history_unknown_instrument
#' @aliases ledgr_staged_history_mismatch
NULL

#' LEDGR_LAST_BAR_NO_FILL warning code
#'
#' `LEDGR_LAST_BAR_NO_FILL` is the warning code emitted when a strategy changes
#' targets on the final pulse of a next-open run. The strategy output is valid,
#' but there is no later bar where ledgr can simulate the fill.
#'
#' No fill is emitted for that final target change, and the ledger is left
#' unchanged for the missing execution. Extend the snapshot by one executable
#' bar and rerun if the final target change is meant to execute.
#'
#' `ledgr_sweep()` preserves the warning as a candidate-row warning rather than
#' converting it into a failed candidate. Committed runs emit the warning during
#' execution. User tests may assert on the warning code in the message.
#'
#' See `vignette("execution-semantics", package = "ledgr")` or
#' `system.file("doc", "execution-semantics.html", package = "ledgr")` for a
#' runnable final-bar example.
#'
#' @name LEDGR_LAST_BAR_NO_FILL
#' @aliases LEDGR_LAST_BAR_NO_FILL ledgr_last_bar_no_fill
#' @aliases ledgr_final_bar_no_fill
NULL
