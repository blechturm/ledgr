#' ledgr condition classes
#'
#' ledgr uses stable top-level condition classes for public cost-model,
#' timing-model, and legacy-shape failures. User tests should assert on these
#' classes instead of parsing message text.
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
#' @section Saved sweep classes:
#' `ledgr_invalid_sweep_id` is raised when a saved sweep id is not a non-empty,
#' non-whitespace ASCII character scalar of at most 256 bytes.
#'
#' `ledgr_sweep_id_exists` is raised when `ledgr_sweep_save()` would overwrite
#' an existing saved sweep id.
#'
#' `ledgr_sweep_not_found` is raised when a structurally valid saved sweep id
#' does not exist in the snapshot's experiment store.
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
#' @aliases ledgr_unresolved_feature_id
#' @aliases ledgr_invalid_sweep_id ledgr_sweep_id_exists
#' @aliases ledgr_sweep_not_found
#' @aliases ledgr_sweep_snapshot_not_found ledgr_sweep_snapshot_hash_mismatch
#' @aliases ledgr_sweep_schema_incompatible
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
