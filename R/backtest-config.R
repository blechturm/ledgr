ledgr_backtest_config <- function(start, end, initial_cash = 100000, final_execution = NULL) {
  start_iso <- ledgr_iso_utc(start)
  end_iso <- ledgr_iso_utc(end)

  start_ts <- as.POSIXct(start_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  end_ts <- as.POSIXct(end_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(start_ts) || is.na(end_ts)) {
    rlang::abort("`start` and `end` must be parseable timestamps.", class = "ledgr_invalid_args")
  }
  if (start_ts > end_ts) {
    rlang::abort("`start` must be before or equal to `end`.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(initial_cash) || length(initial_cash) != 1 || is.na(initial_cash) || !is.finite(initial_cash)) {
    rlang::abort("`initial_cash` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }
  if (initial_cash <= 0) {
    rlang::abort("`initial_cash` must be > 0.", class = "ledgr_invalid_args")
  }

  out <- list(start = start_iso, end = end_iso, initial_cash = as.numeric(initial_cash))
  if (!is.null(final_execution)) {
    # A continued carry window executes its final decision at this session
    # open, after its last scoring pulse (LDG-3064).
    final_iso <- ledgr_iso_utc(final_execution)
    final_ts <- as.POSIXct(final_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
    if (is.na(final_ts) || final_ts <= end_ts) {
      rlang::abort("`final_execution` must be a timestamp after `end`.", class = "ledgr_invalid_args")
    }
    out$final_execution <- final_iso
  }
  out
}

ledgr_strategy_spec <- function(strategy) {
  if (is.function(strategy)) {
    signature <- ledgr_strategy_signature(strategy)
    source_info <- ledgr_strategy_source_info(strategy)
    if (!isTRUE(source_info$preflight$allowed)) {
      ledgr_abort_strategy_preflight(source_info$preflight)
    }
    key <- ledgr_register_strategy_fn(strategy)
    return(list(
      id = "functional",
      params = list(strategy_key = key, call_signature = signature),
      provenance = list(
        strategy_type = "functional",
        strategy_source = source_info$source,
        strategy_source_hash = source_info$hash,
        strategy_source_capture_method = source_info$capture_method,
        reproducibility_level = ledgr_strategy_reproducibility_level("functional", signature, source_info)
      )
    ))
  }

  if (is.list(strategy) && is.character(strategy$id)) {
    params <- strategy$params
    if (is.null(params)) params <- list()
    if (!is.list(params)) {
      rlang::abort("strategy.params must be a list.", class = "ledgr_invalid_args")
    }
    return(list(
      id = strategy$id,
      params = params,
      provenance = list(
        strategy_type = "configured",
        strategy_source = NA_character_,
        strategy_source_hash = NA_character_,
        strategy_source_capture_method = "configured_strategy",
        reproducibility_level = "tier_2"
      )
    ))
  }

  rlang::abort(
    "`strategy` must be a function or configured strategy list.",
    class = "ledgr_invalid_args"
  )
}

ledgr_config <- function(snapshot,
                         universe,
                         strategy,
                         strategy_params = list(),
                         backtest,
                         features = list(),
                         feature_params = list(),
                         alias_map = NULL,
                         alias_identity_map = NULL,
                         execution_mode = "audit_log",
                         checkpoint_every = 10000L,
                         timing_model = ledgr_timing_next_open(),
                         cost_model_hash = NULL,
                         cost_plan_json = NULL,
                         risk_chain_hash = NULL,
                         risk_plan_json = NULL,
                         db_path = NULL,
                         control = list(),
                         run_id = NULL,
                          opening = NULL,
                          seed = NULL,
                          compiled_accounting_model = NULL,
                          availability = NULL,
                          universe_rule = NULL,
                          valuation_policy = NULL,
                          corporate_action_policy = ledgr_corporate_actions_research(),
                          history_policy = ledgr_history_policy(),
                          price_basis = ledgr_snapshot_execution_price_basis(snapshot),
                          snapshot_hash = ledgr_snapshot_stored_hash(snapshot)) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_args")
  }
  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("`universe` must be a non-empty character vector.", class = "ledgr_invalid_args")
  }
  if (!is.list(backtest)) {
    rlang::abort("`backtest` must be a list from ledgr_backtest_config().", class = "ledgr_invalid_args")
  }
  if (is.null(db_path)) db_path <- snapshot$db_path
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!ledgr_same_db_path(db_path, snapshot$db_path) && identical(ledgr_db_path_key(snapshot$db_path), ":memory:")) {
    rlang::abort(
      "`db_path` cannot point to a separate run database when `snapshot` is backed by :memory:.",
      class = "ledgr_invalid_args"
    )
  }
  features <- ledgr_flatten_feature_list(features, context = "`features`")
  if (!is.character(execution_mode) || length(execution_mode) != 1 || is.na(execution_mode) || !nzchar(execution_mode)) {
    rlang::abort("`execution_mode` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!execution_mode %in% c("db_live", "audit_log")) {
    rlang::abort("`execution_mode` must be \"db_live\" or \"audit_log\".", class = "ledgr_invalid_args")
  }
  if (!is.numeric(checkpoint_every) || length(checkpoint_every) != 1 || is.na(checkpoint_every) ||
      !is.finite(checkpoint_every) || checkpoint_every < 1 || (checkpoint_every %% 1) != 0) {
    rlang::abort("`checkpoint_every` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  if (!is.list(control)) {
    rlang::abort("`control` must be a list.", class = "ledgr_invalid_args")
  }
  seed <- ledgr_seed_normalize(seed)
  compiled_accounting_model <- ledgr_public_compiled_accounting_model(compiled_accounting_model)
  ledgr_validate_corporate_action_policy(corporate_action_policy)
  history_policy <- ledgr_history_policy_normalize(history_policy)
  # Experiments pass the basis they already read, so the snapshot is not reopened.
  force(price_basis)
  force(snapshot_hash)

  if (!is.null(control$execution_mode)) {
    execution_mode <- control$execution_mode
    if (!is.character(execution_mode) || length(execution_mode) != 1 || is.na(execution_mode) || !nzchar(execution_mode)) {
      rlang::abort("control$execution_mode must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (!execution_mode %in% c("db_live", "audit_log")) {
      rlang::abort("control$execution_mode must be \"db_live\" or \"audit_log\".", class = "ledgr_invalid_args")
    }
  }
  if (!is.null(control$checkpoint_every)) {
    checkpoint_every <- control$checkpoint_every
    if (!is.numeric(checkpoint_every) || length(checkpoint_every) != 1 || is.na(checkpoint_every) ||
        !is.finite(checkpoint_every) || checkpoint_every < 1 || (checkpoint_every %% 1) != 0) {
      rlang::abort("control$checkpoint_every must be an integer >= 1.", class = "ledgr_invalid_args")
    }
  }

  timing_model <- ledgr_experiment_normalize_timing_model(timing_model)
  cost_identity <- ledgr_config_cost_identity(cost_model_hash, cost_plan_json)
  risk_identity <- ledgr_config_risk_identity(risk_chain_hash, risk_plan_json)

  strategy_params_info <- ledgr_strategy_params_info(strategy_params)
  feature_params_info <- ledgr_strategy_params_info(feature_params)
  alias_map_info <- ledgr_alias_map_storage(alias_map, identity_map = alias_identity_map)
  strat <- ledgr_strategy_spec(strategy)
  opening <- ledgr_config_normalize_opening(opening, backtest$initial_cash)

  engine <- list(
    seed = seed,
    tz = "UTC",
    execution_mode = execution_mode,
    checkpoint_every = as.integer(checkpoint_every),
    control = control
  )
  if (!is.null(compiled_accounting_model)) {
    engine$compiled_accounting_model <- compiled_accounting_model
  }

  config <- list(
    identity_rule_version = ledgr_identity_rule_version,
    db_path = db_path,
    engine = engine,
    universe = list(instrument_ids = universe),
    history = ledgr_history_policy_identity(history_policy),
    backtest = c(
      list(
        start_ts_utc = backtest$start,
        end_ts_utc = backtest$end,
        pulse = "EOD",
        initial_cash = backtest$initial_cash
      ),
      if (!is.null(backtest$final_execution)) {
        list(final_execution_ts_utc = backtest$final_execution)
      }
    ),
    timing_model = list(
      timing_schema_version = timing_model$timing_schema_version,
      type_id = timing_model$type_id,
      version = timing_model$version,
      args = timing_model$args
    ),
    cost_model = list(
      cost_model_hash = cost_identity$cost_model_hash,
      cost_plan_json = cost_identity$cost_plan_json
    ),
    risk_chain = list(
      risk_chain_hash = risk_identity$risk_chain_hash,
      risk_plan_json = risk_identity$risk_plan_json
    ),
    features = if (length(features) > 0) {
      defs <- lapply(features, function(feat) {
        if (inherits(feat, "ledgr_indicator")) {
          def <- list(
            id = feat$id,
            params = feat$params,
            requires_bars = feat$requires_bars,
            stable_after = feat$stable_after,
            fingerprint = ledgr_indicator_fingerprint(feat)
          )
          if (isTRUE(availability$active)) {
            # Only calculation-affecting declarations enter the stored
            # definition and therefore config identity.
            declarations <- ledgr_feature_def_declarations(feat)
            if (!is.null(declarations$gap_contract)) {
              def$gap_contract <- declarations$gap_contract
            }
            def$history_class <- declarations$history_class
            def$required_fields <- declarations$required_fields
            def$input_carry <- declarations$input_carry
            def$tolerance <- declarations$tolerance
            def$fingerprint <- ledgr_active_feature_fingerprint(def)
          }
          return(def)
        }
        feat
      })
      fingerprints <- vapply(defs, function(def) def$fingerprint, character(1))
      list(
        enabled = TRUE,
        defs = defs,
        feature_set_hash = ledgr_feature_set_hash(fingerprints)
      )
    } else {
      list(
        enabled = FALSE,
        defs = list(),
        feature_set_hash = ledgr_feature_set_hash(character())
      )
    },
    strategy = list(
      id = strat$id,
      params = strat$params,
      provenance = strat$provenance
    ),
    strategy_params = strategy_params_info$value,
    strategy_params_json = strategy_params_info$json,
    strategy_params_hash = strategy_params_info$hash,
    feature_params = feature_params_info$value,
    feature_params_json = feature_params_info$json,
    feature_params_hash = feature_params_info$hash,
    alias_map_json = alias_map_info$alias_map_json,
    alias_map_hash = alias_map_info$alias_map_hash,
    alias_map_version = alias_map_info$alias_map_version,
    alias_map_order = alias_map_info$alias_map_order,
    opening = opening,
    data = list(
      source = "snapshot",
      snapshot_id = snapshot$snapshot_id,
      snapshot_hash = snapshot_hash,
      snapshot_db_path = snapshot$db_path,
      price_basis = price_basis
    ),
    corporate_actions = ledgr_corporate_action_policy_identity(
      corporate_action_policy
    )
  )

  if (isTRUE(availability$active)) {
    config$availability <- list(
      active = TRUE,
      declared_families = as.character(availability$declared_families),
      universe_rule = if (is.null(universe_rule)) NULL else unclass(universe_rule),
      valuation_policy = unclass(valuation_policy),
      provider_version = ledgr_availability_provider_version(),
      execution_timing_version = ledgr_availability_execution_timing_rule_version
    )
  }

  if (!is.null(run_id)) config$run_id <- run_id

  class(config) <- c("ledgr_config", class(config))
  # The experiment's own indicator objects travel with the config for run
  # dispatch; two different definitions under one id refuse. The session
  # registry is not written, and the attribute enters neither config
  # identity nor the stored config.
  attr(config, "ledgr_feature_indicators") <- ledgr_feature_indicator_index(features)
  validate_ledgr_config(config)
  config
}

ledgr_config_cost_identity <- function(cost_model_hash = NULL, cost_plan_json = NULL) {
  if (is.null(cost_model_hash) || is.null(cost_plan_json)) {
    rlang::abort("`cost_model_hash` and `cost_plan_json` are required.", class = "ledgr_invalid_args")
  }
  if (!is.character(cost_model_hash) || length(cost_model_hash) != 1L ||
      is.na(cost_model_hash) || !grepl("^[0-9a-f]{64}$", cost_model_hash)) {
    rlang::abort("`cost_model_hash` must be NULL or a 64-character lowercase hex string.", class = "ledgr_invalid_args")
  }
  if (!is.character(cost_plan_json) || length(cost_plan_json) != 1L ||
      is.na(cost_plan_json) || !nzchar(cost_plan_json)) {
    rlang::abort("`cost_plan_json` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  list(
    cost_model_hash = cost_model_hash,
    cost_plan_json = cost_plan_json
  )
}

ledgr_config_risk_identity <- function(risk_chain_hash = NULL, risk_plan_json = NULL) {
  if (is.null(risk_chain_hash) && is.null(risk_plan_json)) {
    risk_chain_hash <- ledgr_risk_chain_hash(ledgr_risk_none())
    risk_plan_json <- ledgr_risk_plan_json(ledgr_risk_none())
  }
  if (is.null(risk_chain_hash) || is.null(risk_plan_json)) {
    rlang::abort("`risk_chain_hash` and `risk_plan_json` must be supplied together.", class = "ledgr_invalid_args")
  }
  if (!is.character(risk_chain_hash) || length(risk_chain_hash) != 1L ||
      is.na(risk_chain_hash) || !grepl("^[0-9a-f]{64}$", risk_chain_hash)) {
    rlang::abort("`risk_chain_hash` must be a 64-character lowercase hex string.", class = "ledgr_invalid_args")
  }
  if (!is.character(risk_plan_json) || length(risk_plan_json) != 1L ||
      is.na(risk_plan_json) || !nzchar(risk_plan_json)) {
    rlang::abort("`risk_plan_json` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  list(
    risk_chain_hash = risk_chain_hash,
    risk_plan_json = risk_plan_json
  )
}

ledgr_config_normalize_opening <- function(opening, initial_cash) {
  if (is.null(opening)) {
    return(list(
      cash = as.numeric(initial_cash),
      date = NULL,
      positions = stats::setNames(numeric(), character()),
      cost_basis = NULL
    ))
  }
  if (!inherits(opening, "ledgr_opening")) {
    rlang::abort("`opening` must be NULL or a ledgr_opening object.", class = "ledgr_invalid_args")
  }
  if (!isTRUE(all.equal(as.numeric(opening$cash), as.numeric(initial_cash), tolerance = 0))) {
    rlang::abort("`opening$cash` must match `backtest$initial_cash`.", class = "ledgr_invalid_args")
  }
  out <- list(
    cash = as.numeric(opening$cash),
    date = opening$date,
    positions = opening$positions,
    cost_basis = opening$cost_basis
  )
  if (!is.null(opening$carried)) {
    out$carried <- ledgr_opening_carried_storage(opening$carried)
  }
  out
}

#' Print a ledgr config
#'
#' @param x A `ledgr_config` object.
#' @param ... Unused.
#' @return The input config, invisibly.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102),
#'   high = c(101, 102, 103),
#'   low = c(99, 100, 101),
#'   close = c(100, 101, 102),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) ctx$flat()
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' if (interactive()) print(bt$config)
#' close(bt)
#' @export
print.ledgr_config <- function(x, ...) {
  cat("ledgr_config\n")
  cat("============\n")
  cat("Database:    ", x$db_path, "\n", sep = "")
  snapshot_id <- if (is.list(x$data) && !is.null(x$data$snapshot_id)) x$data$snapshot_id else NA_character_
  cat("Snapshot ID: ", snapshot_id, "\n", sep = "")
  cat("Universe:    ", paste(x$universe$instrument_ids, collapse = ", "), "\n", sep = "")
  cat("Backtest:    ", x$backtest$start_ts_utc, " to ", x$backtest$end_ts_utc, "\n", sep = "")
  cat("Initial Cash:", x$backtest$initial_cash, "\n")
  cat("Timing Model:", x$timing_model$type_id, "\n")
  cat("Strategy:    ", x$strategy$id, "\n", sep = "")
  invisible(x)
}

# Normalize the carried part of a walk-forward opening (LDG-3064). It holds
# only economic state: FIFO lots, corporate-action rows bound but settled
# later (cash entitlements, dispositions and quantity effects) and frozen
# holdings. JSON round trips may turn vectors into lists, so every
# field is coerced to its atomic type.
ledgr_opening_carried_normalize <- function(carried) {
  if (is.null(carried)) {
    return(list(lots = NULL, pending = NULL, frozen = character()))
  }
  if (!is.list(carried)) {
    rlang::abort("A carried opening must be a list.", class = c("ledgr_invalid_opening", "ledgr_invalid_config"))
  }
  atomic <- function(x, as) as(unlist(x, use.names = FALSE) %||% as(character()))
  lots <- carried$lots
  lots <- if (is.null(lots) || length(unlist(lots$instrument_id)) == 0L) {
    NULL
  } else {
    list(
      instrument_id = atomic(lots$instrument_id, as.character),
      qty = atomic(lots$qty, as.numeric),
      price = atomic(lots$price, as.numeric)
    )
  }
  if (!is.null(lots) && (
    length(unique(lengths(lots))) != 1L || anyNA(lots$instrument_id) ||
      any(!is.finite(lots$qty)) || any(lots$qty <= 0) || any(!is.finite(lots$price))
  )) {
    rlang::abort(
      "A carried opening's lots must be aligned, positive and finite.",
      class = c("ledgr_invalid_opening", "ledgr_invalid_config")
    )
  }
  pending <- carried$pending
  pending <- if (is.null(pending) || length(unlist(pending$fact_id)) == 0L) {
    NULL
  } else {
    data.frame(
      fact_id = atomic(pending$fact_id, as.character),
      quantity = atomic(pending$quantity, as.numeric),
      posting_ts_utc = atomic(pending$posting_ts_utc, as.character),
      stringsAsFactors = FALSE
    )
  }
  # A posting instant is recorded for a cash row whose posting already has a
  # pulse; "" marks a row settled by its effective or knowledge clock.
  if (!is.null(pending)) {
    pending$posting_ts_utc[is.na(pending$posting_ts_utc)] <- ""
  }
  if (!is.null(pending) && (anyNA(pending$fact_id) || any(!is.finite(pending$quantity)) ||
      (any(nzchar(pending$posting_ts_utc)) &&
        anyNA(ledgr_history_utc(pending$posting_ts_utc[nzchar(pending$posting_ts_utc)]))))) {
    rlang::abort(
      "A carried opening's pending rows must name facts, finite quantities and valid posting instants.",
      class = c("ledgr_invalid_opening", "ledgr_invalid_config")
    )
  }
  list(
    lots = lots,
    pending = pending,
    frozen = sort(unique(atomic(carried$frozen, as.character)), method = "radix")
  )
}

# The stored form of a carried opening: plain vectors in a fixed order, so the
# run config and its identity are deterministic.
ledgr_opening_carried_storage <- function(carried) {
  carried <- ledgr_opening_carried_normalize(carried)
  list(
    lots = if (is.null(carried$lots)) NULL else carried$lots,
    pending = if (is.null(carried$pending)) NULL else list(
      fact_id = carried$pending$fact_id,
      quantity = carried$pending$quantity,
      posting_ts_utc = carried$pending$posting_ts_utc
    ),
    frozen = carried$frozen
  )
}
