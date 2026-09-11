#' ledgr condition classes
#'
#' ledgr uses stable top-level condition classes for public cost-model,
#' timing-model, execution-window, saved-sweep, retained-series, and
#' legacy-shape failures. User tests should assert on these classes instead of
#' parsing message text.
#'
#' @section Legacy shape classes:
#' `ledgr_legacy_fill_model_shape` is raised when callers pass the v0.1.8
#' `fill_model` shape or legacy scalar cost fields to public entry points.
#' ledgr fails closed; it does not translate the legacy shape.
#'
#' `ledgr_legacy_config_shape` is raised when reopening a stored config whose
#' execution shape still contains legacy fill/cost fields.
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
#' @section Availability classes:
#' `ledgr_invalid_valuation_policy` is raised for malformed stale-valuation
#' policies or constructor arguments.
#'
#' `ledgr_availability_inactive` is raised when a membership-universe rule is
#' requested without the fact families needed to activate availability-aware
#' execution.
#'
#' `ledgr_availability_sessions_required` and
#' `ledgr_valuation_policy_required` are raised when availability-aware
#' execution lacks a complete session calendar or an explicit valuation
#' policy, respectively.
#'
#' `ledgr_membership_universe_not_found` is raised when a membership-universe
#' rule names a universe that is not declared by the snapshot.
#'
#' `ledgr_compiled_availability_unsupported` is raised before execution when
#' availability-aware execution is combined with the compiled spot-FIFO path.
#'
#' `ledgr_indicator_gap_unsupported` is raised before strategy use when an
#' availability-aware feature does not declare the supported strict-window gap
#' contract. `ledgr_indicator_gap_parity` is raised when the scalar and series
#' implementations disagree at the end of a finite strict window.
#'
#' `ledgr_invalid_strategy_state` is raised when availability-aware asset state
#' is not a named list keyed only by instruments on the current public axis.
#'
#' `ledgr_target_sizing_unavailable` is raised when an availability-aware
#' rebalance helper cannot obtain a positive accepted current close or a
#' permissible mark needed to reserve held nonmember exposure.
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
#' requested selection metric are missing, `NA`, `NaN`, or infinite.
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
#' @section Related existing classes:
#' `ledgr_run_not_found` is raised when run-store inspection helpers cannot
#' find the requested run. `ledgr_unresolved_feature_id` is raised when callers
#' ask for a concrete feature ID before parameterized feature declarations have
#' been resolved.
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
#' @aliases ledgr_condition_classes ledgr_legacy_fill_model_shape
#' @aliases ledgr_legacy_config_shape ledgr_cost_model_unspecified
#' @aliases ledgr_invalid_cost_chain_order ledgr_invalid_cost_model
#' @aliases ledgr_invalid_timing_model ledgr_invalid_fill_proposal
#' @aliases ledgr_invalid_fill_context ledgr_run_not_found
#' @aliases ledgr_unresolved_feature_id ledgr_run_window_too_short
#' @aliases ledgr_invalid_lot_fill
#' @aliases ledgr_snapshot_hash_invalid_timestamp
#' @aliases ledgr_invalid_valuation_policy ledgr_availability_inactive
#' @aliases ledgr_availability_sessions_required ledgr_valuation_policy_required
#' @aliases ledgr_membership_universe_not_found
#' @aliases ledgr_compiled_availability_unsupported
#' @aliases ledgr_indicator_gap_unsupported ledgr_indicator_gap_parity
#' @aliases ledgr_invalid_strategy_state
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
#' @aliases ledgr_walk_forward_candidate_key_missing
#' @aliases ledgr_walk_forward_test_run_failed
#' @aliases ledgr_walk_forward_session_not_found
#' @aliases ledgr_walk_forward_snapshot_hash_mismatch
#' @aliases ledgr_walk_forward_snapshot_override_mismatch
#' @aliases ledgr_walk_forward_invalid_session
#' @aliases ledgr_walk_forward_latest_without_rationale
#' @aliases ledgr_walk_forward_candidate_not_found
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
