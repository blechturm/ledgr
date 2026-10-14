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
#' the bytewise order required by rule 3.
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
#' `ledgr_fill_timing_not_comparable` is raised by fill-equivalence validation
#' when selected runs have differing or unknown execution-timing conventions.
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
#' `ledgr_indicator_gap_unsupported` is raised before strategy use when an
#' availability-aware feature does not declare the supported strict-window gap
#' contract. `ledgr_indicator_gap_parity` is raised when the scalar and series
#' implementations disagree at the end of a finite strict window.
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
#' @aliases ledgr_fill_timing_not_comparable
#' @aliases ledgr_session_time_ambiguous ledgr_session_time_nonexistent
#' @aliases ledgr_fact_ambiguous_membership_shape ledgr_fact_invalid_membership_list
#' @aliases ledgr_facts_inspection_invalid_args ledgr_facts_scope_not_found
#' @aliases ledgr_facts_snapshot_not_sealed ledgr_facts_snapshot_hash_mismatch
#' @aliases ledgr_session_adapter_invalid ledgr_session_override_invalid
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
