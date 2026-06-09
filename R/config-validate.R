ledgr_config_named_numeric <- function(x) {
  if (is.null(x)) {
    return(stats::setNames(numeric(), character()))
  }
  if (is.list(x) && !is.data.frame(x)) {
    x <- unlist(x, use.names = TRUE)
  }
  if (!is.numeric(x) || length(x) < 1L) {
    return(stats::setNames(numeric(), character()))
  }
  x_names <- names(x)
  if (is.null(x_names)) {
    return(stats::setNames(numeric(), character()))
  }
  valid <- !is.na(x_names) & nzchar(x_names) & !is.na(x) & is.finite(x)
  as.numeric(x[valid]) |>
    stats::setNames(x_names[valid])
}

validate_ledgr_config <- function(config) {
  if (is.character(config) && length(config) == 1 && !is.na(config)) {
    config <- tryCatch(
      ledgr_json_read_config(config),
      error = function(e) {
        rlang::abort("`config` is not valid JSON.", class = "ledgr_invalid_config")
      }
    )
  }

  if (!is.list(config)) {
    rlang::abort("`config` must be a list (or parsed JSON list).", class = "ledgr_invalid_config")
  }
  config <- ledgr_config_normalize_risk_identity(config)

  cfg_get <- function(path) {
    cur <- config
    for (key in path) {
      if (!is.list(cur) || is.null(cur[[key]])) {
        rlang::abort(
          sprintf("Missing required config field: %s", paste(path, collapse = ".")),
          class = "ledgr_invalid_config"
        )
      }
      cur <- cur[[key]]
    }
    cur
  }

  assert_scalar_chr <- function(x, path) {
    if (!is.character(x) || length(x) != 1 || is.na(x) || !nzchar(x)) {
      rlang::abort(
        sprintf("Config field %s must be a non-empty character scalar.", path),
        class = "ledgr_invalid_config"
      )
    }
    invisible(TRUE)
  }

  assert_scalar_num <- function(x, path) {
    if (!is.numeric(x) || length(x) != 1 || is.na(x) || !is.finite(x)) {
      rlang::abort(
        sprintf("Config field %s must be a finite numeric scalar.", path),
        class = "ledgr_invalid_config"
      )
    }
    invisible(TRUE)
  }

  db_path <- cfg_get(c("db_path"))
  assert_scalar_chr(db_path, "db_path")

  seed <- config$engine$seed
  if (!is.null(seed) &&
      (!is.numeric(seed) || length(seed) != 1 || is.na(seed) || !is.finite(seed) || (seed %% 1) != 0)) {
    rlang::abort(
      "Config field engine.seed must be NULL or an integer-like scalar.",
      class = "ledgr_invalid_config"
    )
  }
  ledgr_public_compiled_accounting_model(config$engine$compiled_accounting_model)

  tz <- cfg_get(c("engine", "tz"))
  assert_scalar_chr(tz, "engine.tz")
  if (!identical(tz, "UTC")) {
    rlang::abort("Config field engine.tz must be 'UTC'.", class = "ledgr_invalid_config")
  }

  instrument_ids <- cfg_get(c("universe", "instrument_ids"))
  if (!is.character(instrument_ids) || length(instrument_ids) < 1 || any(!nzchar(instrument_ids)) || anyNA(instrument_ids)) {
    rlang::abort(
      "Config field universe.instrument_ids must be a non-empty character vector of non-empty strings.",
      class = "ledgr_invalid_config"
    )
  }

  opening_positions <- ledgr_config_named_numeric(config$opening$positions)
  opening_positions <- opening_positions[opening_positions != 0]
  if (length(opening_positions) > 0L) {
    missing_opening <- setdiff(names(opening_positions), instrument_ids)
    if (length(missing_opening) > 0L) {
      rlang::abort(
        sprintf(
          "Config field opening.positions contains instruments outside universe.instrument_ids: %s.",
          paste(missing_opening, collapse = ", ")
        ),
        class = "ledgr_invalid_config"
      )
    }
  }

  start_ts <- cfg_get(c("backtest", "start_ts_utc"))
  end_ts <- cfg_get(c("backtest", "end_ts_utc"))
  assert_scalar_chr(start_ts, "backtest.start_ts_utc")
  assert_scalar_chr(end_ts, "backtest.end_ts_utc")

  iso8601_utc <- "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$"
  if (!grepl(iso8601_utc, start_ts)) {
    rlang::abort(
      "Config field backtest.start_ts_utc must be an ISO8601 UTC timestamp like 'YYYY-mm-ddTHH:MM:SSZ'.",
      class = "ledgr_invalid_config"
    )
  }
  if (!grepl(iso8601_utc, end_ts)) {
    rlang::abort(
      "Config field backtest.end_ts_utc must be an ISO8601 UTC timestamp like 'YYYY-mm-ddTHH:MM:SSZ'.",
      class = "ledgr_invalid_config"
    )
  }

  start_parsed <- as.POSIXct(start_ts, tz = "UTC")
  end_parsed <- as.POSIXct(end_ts, tz = "UTC")
  if (is.na(start_parsed) || is.na(end_parsed)) {
    rlang::abort(
      "Config fields backtest.start_ts_utc and backtest.end_ts_utc must be parseable timestamps.",
      class = "ledgr_invalid_config"
    )
  }
  if (start_parsed > end_parsed) {
    rlang::abort(
      "Config field backtest.start_ts_utc must be <= backtest.end_ts_utc.",
      class = "ledgr_invalid_config"
    )
  }

  pulse <- cfg_get(c("backtest", "pulse"))
  assert_scalar_chr(pulse, "backtest.pulse")
  if (!identical(pulse, "EOD")) {
    rlang::abort("Config field backtest.pulse must be 'EOD'.", class = "ledgr_invalid_config")
  }

  initial_cash <- cfg_get(c("backtest", "initial_cash"))
  assert_scalar_num(initial_cash, "backtest.initial_cash")
  if (initial_cash <= 0) {
    rlang::abort("Config field backtest.initial_cash must be > 0.", class = c("ledgr_invalid_args", "ledgr_invalid_config"))
  }

  if (!is.null(config$fill_model)) {
    rlang::abort(
      "Stored config uses legacy `fill_model`; recreate the experiment with `timing_model` and `cost_model`.",
      class = "ledgr_legacy_config_shape"
    )
  }

  timing_type <- cfg_get(c("timing_model", "type_id"))
  assert_scalar_chr(timing_type, "timing_model.type_id")
  if (!identical(timing_type, "next_open")) {
    rlang::abort("Config field timing_model.type_id must be 'next_open'.", class = "ledgr_invalid_config")
  }
  timing_version <- cfg_get(c("timing_model", "version"))
  assert_scalar_num(timing_version, "timing_model.version")
  if (as.integer(timing_version) != 1L) {
    rlang::abort("Config field timing_model.version must be 1.", class = "ledgr_invalid_config")
  }

  cost_model_hash <- cfg_get(c("cost_model", "cost_model_hash"))
  cost_plan_json <- cfg_get(c("cost_model", "cost_plan_json"))
  assert_scalar_chr(cost_model_hash, "cost_model.cost_model_hash")
  assert_scalar_chr(cost_plan_json, "cost_model.cost_plan_json")
  if (!grepl("^[0-9a-f]{64}$", cost_model_hash)) {
    rlang::abort("Config field cost_model.cost_model_hash must be a 64-character lowercase hex string.", class = "ledgr_invalid_config")
  }
  reconstructed_hash <- tryCatch(
    digest::digest(cost_plan_json, algo = "sha256"),
    error = function(e) NA_character_
  )
  if (!identical(reconstructed_hash, cost_model_hash)) {
    rlang::abort("Config field cost_model.cost_model_hash must match cost_model.cost_plan_json.", class = "ledgr_invalid_config")
  }
  tryCatch(
    ledgr_cost_plan_reconstruct(cost_plan_json),
    error = function(e) {
      rlang::abort("Config field cost_model.cost_plan_json is not a valid ledgr cost plan.", class = "ledgr_invalid_config", parent = e)
    }
  )

  risk_chain_hash <- cfg_get(c("risk_chain", "risk_chain_hash"))
  risk_plan_json <- cfg_get(c("risk_chain", "risk_plan_json"))
  assert_scalar_chr(risk_chain_hash, "risk_chain.risk_chain_hash")
  assert_scalar_chr(risk_plan_json, "risk_chain.risk_plan_json")
  if (!grepl("^[0-9a-f]{64}$", risk_chain_hash)) {
    rlang::abort("Config field risk_chain.risk_chain_hash must be a 64-character lowercase hex string.", class = "ledgr_invalid_config")
  }
  reconstructed_risk_hash <- tryCatch(
    digest::digest(risk_plan_json, algo = "sha256"),
    error = function(e) NA_character_
  )
  if (!identical(reconstructed_risk_hash, risk_chain_hash)) {
    rlang::abort("Config field risk_chain.risk_chain_hash must match risk_chain.risk_plan_json.", class = "ledgr_invalid_config")
  }
  tryCatch(
    ledgr_risk_plan_reconstruct(risk_plan_json),
    error = function(e) {
      rlang::abort("Config field risk_chain.risk_plan_json is not a valid ledgr risk plan.", class = "ledgr_invalid_config", parent = e)
    }
  )

  strategy_id <- cfg_get(c("strategy", "id"))
  assert_scalar_chr(strategy_id, "strategy.id")
  if (!is.null(config$strategy$params$call_signature)) {
    assert_scalar_chr(config$strategy$params$call_signature, "strategy.params.call_signature")
    if (!config$strategy$params$call_signature %in% c("ctx", "ctx_params")) {
      rlang::abort(
        "Config field strategy.params.call_signature must be 'ctx' or 'ctx_params'.",
        class = "ledgr_invalid_config"
      )
    }
  }
  if (!is.null(config$strategy_params) && (!is.list(config$strategy_params) || is.data.frame(config$strategy_params))) {
    rlang::abort("Config field strategy_params must be a list.", class = "ledgr_invalid_config")
  }
  if (!is.null(config$strategy_params_json)) {
    assert_scalar_chr(config$strategy_params_json, "strategy_params_json")
  }
  if (!is.null(config$strategy_params_hash)) {
    assert_scalar_chr(config$strategy_params_hash, "strategy_params_hash")
  }
  if (!is.null(config$feature_params) && (!is.list(config$feature_params) || is.data.frame(config$feature_params))) {
    rlang::abort("Config field feature_params must be a list.", class = "ledgr_invalid_config")
  }
  if (!is.null(config$feature_params_json)) {
    assert_scalar_chr(config$feature_params_json, "feature_params_json")
  }
  if (!is.null(config$feature_params_hash)) {
    assert_scalar_chr(config$feature_params_hash, "feature_params_hash")
  }
  if (!is.null(config$alias_map_json) && !is.na(config$alias_map_json)) {
    assert_scalar_chr(config$alias_map_json, "alias_map_json")
  }
  if (!is.null(config$alias_map_hash) && !is.na(config$alias_map_hash)) {
    assert_scalar_chr(config$alias_map_hash, "alias_map_hash")
  }
  if (!is.null(config$alias_map_version) && !is.na(config$alias_map_version)) {
    if (!is.numeric(config$alias_map_version) || length(config$alias_map_version) != 1L ||
        is.na(config$alias_map_version) || !is.finite(config$alias_map_version) ||
        config$alias_map_version %% 1 != 0) {
      rlang::abort("Config field alias_map_version must be an integer scalar.", class = "ledgr_invalid_config")
    }
  }
  if (!is.null(config$alias_map_order) && (!is.character(config$alias_map_order) || anyNA(config$alias_map_order))) {
    rlang::abort("Config field alias_map_order must be a character vector.", class = "ledgr_invalid_config")
  }

  # Modern execution is sealed-snapshot-only. `ledgr_backtest()` keeps its
  # data-frame convenience by converting bars to a sealed snapshot before this
  # config exists; low-level raw `bars` configs must fail before fold entry.
  if (is.null(config$data) || !is.list(config$data)) {
    rlang::abort(
      "Config field data must specify sealed snapshot data (`data.source = 'snapshot'` and `data.snapshot_id`).",
      class = "ledgr_snapshot_required"
    )
  }

  data_source <- config$data$source
  snapshot_id <- config$data$snapshot_id

  assert_scalar_chr(data_source, "data.source")
  if (!identical(data_source, "snapshot")) {
    rlang::abort("Config field data.source must be 'snapshot'.", class = "ledgr_snapshot_required")
  }

  assert_scalar_chr(snapshot_id, "data.snapshot_id")

  if (!is.null(config$data$snapshot_db_path)) {
    assert_scalar_chr(config$data$snapshot_db_path, "data.snapshot_db_path")
  }

  if (!is.null(config$features) && is.list(config$features) && isTRUE(config$features$enabled)) {
    defs <- config$features$defs
    if (is.null(defs) || !is.list(defs) || length(defs) < 1) {
      rlang::abort("Config field features.defs must be a non-empty list when features.enabled is TRUE.", class = "ledgr_invalid_config")
    }
    ids <- vapply(defs, function(d) {
      if (!is.list(d)) {
        return(NA_character_)
      }
      id <- d$id
      if (is.null(id)) id <- d$name
      if (is.null(id) || !is.character(id) || length(id) != 1L) NA_character_ else id
    }, character(1))
    if (anyNA(ids) || any(!nzchar(ids))) {
      rlang::abort("Each feature def must include `id` (or `name`) as a non-empty string.", class = "ledgr_invalid_config")
    }
    ledgr_abort_duplicate_feature_ids(ids)
  }

  invisible(TRUE)
}

ledgr_validate_config <- function(config) {
  validate_ledgr_config(config)
  invisible(TRUE)
}

ledgr_config_noop_risk_identity <- function() {
  list(
    risk_chain_hash = ledgr_risk_chain_hash(ledgr_risk_none()),
    risk_plan_json = ledgr_risk_plan_json(ledgr_risk_none())
  )
}

ledgr_config_normalize_risk_identity <- function(config) {
  if (!is.list(config)) {
    return(config)
  }
  if (is.null(config$risk_chain)) {
    config$risk_chain <- ledgr_config_noop_risk_identity()
  }
  config
}
