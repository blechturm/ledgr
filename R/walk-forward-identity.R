ledgr_walk_forward_candidate_schema_version <- "v1"

ledgr_walk_forward_hash_payload <- function(payload) {
  digest::digest(as.character(canonical_json(payload)), algo = "sha256")
}

ledgr_walk_forward_hash_scalar <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    rlang::abort(
      sprintf("%s must be a non-empty character scalar.", arg),
      class = c("ledgr_walk_forward_invalid_identity", "ledgr_invalid_args")
    )
  }
  x
}

ledgr_walk_forward_nullable_seed <- function(x, arg = "`execution_seed`") {
  if (is.null(x)) {
    return(NA_integer_)
  }
  if (length(x) != 1L || is.na(x)) {
    return(NA_integer_)
  }
  if (!is.numeric(x) || !is.finite(x) || x != as.integer(x)) {
    rlang::abort(
      sprintf("%s must be an integer scalar or NA.", arg),
      class = c("ledgr_walk_forward_invalid_identity", "ledgr_invalid_args")
    )
  }
  as.integer(x)
}

ledgr_walk_forward_candidate_payload <- function(params_hash,
                                                 feature_params_hash,
                                                 strategy_hash,
                                                 feature_set_hash,
                                                 alias_map_hash,
                                                 metric_context_hash,
                                                 cost_model_hash,
                                                 risk_chain_hash,
                                                 execution_seed = NA_integer_) {
  list(
    params_hash = ledgr_walk_forward_hash_scalar(params_hash, "`params_hash`"),
    feature_params_hash = ledgr_walk_forward_hash_scalar(feature_params_hash, "`feature_params_hash`"),
    strategy_hash = ledgr_walk_forward_hash_scalar(strategy_hash, "`strategy_hash`"),
    feature_set_hash = ledgr_walk_forward_hash_scalar(feature_set_hash, "`feature_set_hash`"),
    alias_map_hash = ledgr_walk_forward_hash_scalar(alias_map_hash, "`alias_map_hash`"),
    metric_context_hash = ledgr_walk_forward_hash_scalar(metric_context_hash, "`metric_context_hash`"),
    cost_model_hash = ledgr_walk_forward_hash_scalar(cost_model_hash, "`cost_model_hash`"),
    risk_chain_hash = ledgr_walk_forward_hash_scalar(risk_chain_hash, "`risk_chain_hash`"),
    execution_seed = ledgr_walk_forward_nullable_seed(execution_seed),
    candidate_schema_version = ledgr_walk_forward_candidate_schema_version
  )
}

ledgr_walk_forward_candidate_key <- function(params_hash,
                                             feature_params_hash,
                                             strategy_hash,
                                             feature_set_hash,
                                             alias_map_hash,
                                             metric_context_hash,
                                             cost_model_hash,
                                             risk_chain_hash,
                                             execution_seed = NA_integer_) {
  ledgr_walk_forward_hash_payload(ledgr_walk_forward_candidate_payload(
    params_hash = params_hash,
    feature_params_hash = feature_params_hash,
    strategy_hash = strategy_hash,
    feature_set_hash = feature_set_hash,
    alias_map_hash = alias_map_hash,
    metric_context_hash = metric_context_hash,
    cost_model_hash = cost_model_hash,
    risk_chain_hash = risk_chain_hash,
    execution_seed = execution_seed
  ))
}

ledgr_walk_forward_execution_seed <- function(master_seed,
                                              fold_seq,
                                              window,
                                              candidate_key) {
  if (is.null(master_seed)) {
    return(NA_integer_)
  }
  if (length(master_seed) == 0L || (length(master_seed) == 1L && is.na(master_seed))) {
    return(NA_integer_)
  }
  master_seed <- ledgr_seed_normalize(master_seed)
  fold_seq <- ledgr_walk_forward_validate_positive_integer(fold_seq, "`fold_seq`")
  window <- match.arg(window, c("train", "test"))
  candidate_key <- ledgr_walk_forward_hash_scalar(candidate_key, "`candidate_key`")
  ledgr_derive_seed(
    master_seed,
    list(
      fold_seq = fold_seq,
      window = window,
      candidate_key = candidate_key
    )
  )
}

ledgr_walk_forward_candidate_identity <- function(params_hash,
                                                  feature_params_hash,
                                                  strategy_hash,
                                                  feature_set_hash,
                                                  alias_map_hash,
                                                  metric_context_hash,
                                                  cost_model_hash,
                                                  risk_chain_hash,
                                                  master_seed = NULL,
                                                  fold_seq,
                                                  window) {
  unseeded_candidate_key <- ledgr_walk_forward_candidate_key(
    params_hash = params_hash,
    feature_params_hash = feature_params_hash,
    strategy_hash = strategy_hash,
    feature_set_hash = feature_set_hash,
    alias_map_hash = alias_map_hash,
    metric_context_hash = metric_context_hash,
    cost_model_hash = cost_model_hash,
    risk_chain_hash = risk_chain_hash,
    execution_seed = NA_integer_
  )
  execution_seed <- ledgr_walk_forward_execution_seed(
    master_seed = master_seed,
    fold_seq = fold_seq,
    window = window,
    candidate_key = unseeded_candidate_key
  )
  candidate_key <- ledgr_walk_forward_candidate_key(
    params_hash = params_hash,
    feature_params_hash = feature_params_hash,
    strategy_hash = strategy_hash,
    feature_set_hash = feature_set_hash,
    alias_map_hash = alias_map_hash,
    metric_context_hash = metric_context_hash,
    cost_model_hash = cost_model_hash,
    risk_chain_hash = risk_chain_hash,
    execution_seed = execution_seed
  )
  list(
    candidate_key = candidate_key,
    unseeded_candidate_key = unseeded_candidate_key,
    execution_seed = execution_seed
  )
}

ledgr_walk_forward_param_grid_hash <- function(param_grid) {
  if (!inherits(param_grid, "ledgr_param_grid") || !is.list(param_grid)) {
    rlang::abort(
      "`param_grid` must be a ledgr_param_grid object.",
      class = c("ledgr_walk_forward_invalid_identity", "ledgr_invalid_args")
    )
  }
  rows <- lapply(param_grid$params, function(params) {
    list(
      strategy_params = ledgr_grid_candidate_strategy_params(params),
      feature_params = ledgr_grid_candidate_feature_params(params)
    )
  })
  row_json <- vapply(rows, function(row) as.character(canonical_json(row)), character(1))
  ledgr_walk_forward_hash_payload(list(
    rows = as.list(sort(row_json)),
    param_grid_schema_version = "v1"
  ))
}

ledgr_walk_forward_experiment_hash <- function(config) {
  if (!inherits(config, "ledgr_config")) {
    rlang::abort(
      "`config` must be a ledgr_config object.",
      class = c("ledgr_walk_forward_invalid_identity", "ledgr_invalid_args")
    )
  }
  payload <- config_hash_payload(config)
  payload <- ledgr_walk_forward_experiment_payload_drop_separate_identity(payload)
  ledgr_walk_forward_hash_payload(payload)
}

ledgr_walk_forward_experiment_payload_drop_separate_identity <- function(payload) {
  payload$cost_model <- NULL
  payload$risk_chain <- NULL
  payload$metric_context <- NULL
  payload$metric_context_json <- NULL
  payload$metric_context_hash <- NULL
  payload$metric_context_version <- NULL
  if (is.list(payload$engine)) {
    payload$engine$seed <- NULL
  }
  payload
}

ledgr_walk_forward_session_payload <- function(snapshot_hash,
                                               experiment_hash,
                                               param_grid_hash,
                                               fold_list_hash,
                                               selection_rule_hash,
                                               metric_context_hash,
                                               cost_model_hash,
                                               risk_chain_hash,
                                               master_seed = NULL,
                                               opening_state_policy = "carry_test_state",
                                               ledgr_version = as.character(utils::packageVersion("ledgr"))) {
  list(
    snapshot_hash = ledgr_walk_forward_hash_scalar(snapshot_hash, "`snapshot_hash`"),
    experiment_hash = ledgr_walk_forward_hash_scalar(experiment_hash, "`experiment_hash`"),
    param_grid_hash = ledgr_walk_forward_hash_scalar(param_grid_hash, "`param_grid_hash`"),
    fold_list_hash = ledgr_walk_forward_hash_scalar(fold_list_hash, "`fold_list_hash`"),
    selection_rule_hash = ledgr_walk_forward_hash_scalar(selection_rule_hash, "`selection_rule_hash`"),
    metric_context_hash = ledgr_walk_forward_hash_scalar(metric_context_hash, "`metric_context_hash`"),
    cost_model_hash = ledgr_walk_forward_hash_scalar(cost_model_hash, "`cost_model_hash`"),
    risk_chain_hash = ledgr_walk_forward_hash_scalar(risk_chain_hash, "`risk_chain_hash`"),
    master_seed = ledgr_seed_normalize(master_seed),
    opening_state_policy = ledgr_walk_forward_opening_state_policy(opening_state_policy),
    walk_forward_schema_version = ledgr_walk_forward_schema_version,
    ledgr_version = ledgr_walk_forward_hash_scalar(ledgr_version, "`ledgr_version`")
  )
}

ledgr_walk_forward_session_id <- function(snapshot_hash,
                                          experiment_hash,
                                          param_grid_hash,
                                          fold_list_hash,
                                          selection_rule_hash,
                                          metric_context_hash,
                                          cost_model_hash,
                                          risk_chain_hash,
                                          master_seed = NULL,
                                          opening_state_policy = "carry_test_state",
                                          ledgr_version = as.character(utils::packageVersion("ledgr"))) {
  ledgr_walk_forward_hash_payload(ledgr_walk_forward_session_payload(
    snapshot_hash = snapshot_hash,
    experiment_hash = experiment_hash,
    param_grid_hash = param_grid_hash,
    fold_list_hash = fold_list_hash,
    selection_rule_hash = selection_rule_hash,
    metric_context_hash = metric_context_hash,
    cost_model_hash = cost_model_hash,
    risk_chain_hash = risk_chain_hash,
    master_seed = master_seed,
    opening_state_policy = opening_state_policy,
    ledgr_version = ledgr_version
  ))
}

ledgr_walk_forward_opening_state_policy <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    rlang::abort(
      "`opening_state_policy` must be a non-empty character scalar.",
      class = c("ledgr_walk_forward_invalid_identity", "ledgr_invalid_args")
    )
  }
  if (!x %in% c("carry_test_state", "flat_test_state")) {
    rlang::abort(
      "`opening_state_policy` must be \"carry_test_state\" or \"flat_test_state\" in v1.",
      class = c("ledgr_walk_forward_invalid_identity", "ledgr_invalid_args")
    )
  }
  x
}
