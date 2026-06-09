#' ledgr identity fields
#'
#' ledgr stores several hashes and JSON payloads so runs, sweeps, promotion
#' records, and later walk-forward artifacts can say what executed without
#' confusing runtime lookup details with concrete feature identity.
#'
#' @section Run and config identity:
#' `config_hash` identifies the execution config after removing store-local
#' paths, run-local IDs, and diagnostic declaration-order fields. It remains
#' sensitive to execution inputs such as snapshot identity, universe, strategy,
#' parameters, feature definitions, timing model, cost identity, opening state,
#' and seed.
#'
#' `feature_set_hash` identifies the resolved concrete feature definitions by
#' hashing the set of feature fingerprints. It changes when concrete feature
#' parameters change, even if user-facing aliases stay the same.
#'
#' `feature_params_hash` identifies the feature parameter list supplied to a
#' run or candidate. It records user parameter inputs; `feature_set_hash`
#' records the resolved feature definitions produced from those inputs.
#'
#' @section Alias identity:
#' `alias_map_json` stores the active alias map used for runtime lookup, plus
#' declaration-level identity mappings when available. The concrete lookup map
#' lets `ctx$features(id)` resolve aliases to feature IDs after reopening.
#'
#' `alias_map_hash` hashes declaration-level alias identity, not concrete
#' feature parameter values. Alias names and declaration semantics affect this
#' hash; resolved feature parameter values belong to `feature_set_hash`.
#'
#' `alias_map_order` records declaration order for diagnostics and display. It
#' is not part of `config_hash`.
#'
#' @section Cost identity:
#' `cost_plan_json` is the canonical serializable cost-model plan stored in the
#' execution config. `cost_model_hash` is the SHA-256 hash of that plan. These
#' fields are execution identity and are forward dependencies for
#' walk-forward candidate identity; they do not implement walk-forward by
#' themselves.
#'
#' @section Target-risk identity:
#' `risk_plan_json` is the canonical serializable target-risk plan stored in the
#' execution config. `risk_chain_hash` is the SHA-256 hash of that plan. Missing
#' pre-v0.1.9.3 risk fields reopen as the no-op risk plan in memory; stored
#' historical config JSON is not rewritten by the compatibility normalizer.
#'
#' @section Where to inspect:
#' In-session runs expose `feature_set_hash` at
#' `bt$config$features$feature_set_hash`. Durable stores expose it through
#' [ledgr_run_info()] and [ledgr_run_list()]. Sweep candidates expose
#' candidate-level feature identity in their row-level provenance and
#' reproduction keys.
#'
#' @name ledgr_identity_fields
#' @aliases ledgr_identity_fields ledgr_identity
NULL
