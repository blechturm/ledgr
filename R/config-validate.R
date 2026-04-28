validate_ledgr_config <- function(config) {
  if (is.character(config) && length(config) == 1 && !is.na(config)) {
    config <- tryCatch(
      jsonlite::fromJSON(config, simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE),
      error = function(e) {
        rlang::abort("`config` is not valid JSON.", class = "ledgr_invalid_config")
      }
    )
  }

  if (!is.list(config)) {
    rlang::abort("`config` must be a list (or parsed JSON list).", class = "ledgr_invalid_config")
  }

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

  fill_type <- cfg_get(c("fill_model", "type"))
  assert_scalar_chr(fill_type, "fill_model.type")
  if (!identical(fill_type, "next_open")) {
    rlang::abort("Config field fill_model.type must be 'next_open'.", class = "ledgr_invalid_config")
  }

  spread_bps <- cfg_get(c("fill_model", "spread_bps"))
  commission_fixed <- cfg_get(c("fill_model", "commission_fixed"))
  assert_scalar_num(spread_bps, "fill_model.spread_bps")
  assert_scalar_num(commission_fixed, "fill_model.commission_fixed")
  if (spread_bps < 0) {
    rlang::abort("Config field fill_model.spread_bps must be >= 0.", class = "ledgr_invalid_config")
  }
  if (commission_fixed < 0) {
    rlang::abort("Config field fill_model.commission_fixed must be >= 0.", class = "ledgr_invalid_config")
  }

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

  # v0.1.1 snapshot integration: config$data$source == "snapshot" requires
  # config$data$snapshot_id.
  if (!is.null(config$data) && is.list(config$data)) {
    data_source <- config$data$source
    snapshot_id <- config$data$snapshot_id

    if (!is.null(data_source)) {
      assert_scalar_chr(data_source, "data.source")
      if (!identical(data_source, "snapshot")) {
        rlang::abort("Config field data.source must be 'snapshot' when provided.", class = "ledgr_invalid_config")
      }
    }

    if (!is.null(snapshot_id) || identical(data_source, "snapshot")) {
      assert_scalar_chr(snapshot_id, "data.snapshot_id")
    }

    if (!is.null(config$data$snapshot_db_path)) {
      assert_scalar_chr(config$data$snapshot_db_path, "data.snapshot_db_path")
    }
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
