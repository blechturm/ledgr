ledgr_run_prepare_config <- function(config) {
  validate_ledgr_config(config)

  cfg <- if (is.character(config)) {
    ledgr_json_read_config(config)
  } else {
    config
  }
  if (!is.list(cfg)) {
    rlang::abort(
      "`config` must be a list (or JSON string).",
      class = "ledgr_invalid_config"
    )
  }
  cfg <- ledgr_config_normalize_risk_identity(cfg)

  opening_positions <- ledgr_config_opening_positions(cfg)
  list(
    config = cfg,
    db_path = cfg$db_path,
    instrument_ids = cfg$universe$instrument_ids,
    start_ts_utc = cfg$backtest$start_ts_utc,
    end_ts_utc = cfg$backtest$end_ts_utc,
    initial_cash = as.numeric(cfg$backtest$initial_cash),
    opening_positions = opening_positions,
    opening_cost_basis = ledgr_config_opening_cost_basis(
      cfg,
      opening_positions
    ),
    seed = cfg$engine$seed,
    compiled_accounting_model = ledgr_public_compiled_accounting_model(
      cfg$engine$compiled_accounting_model
    )
  )
}

ledgr_run_prepare_engine <- function(cfg, db_path) {
  persist_features <- TRUE
  if (!is.null(cfg$features) &&
    is.list(cfg$features) &&
    !is.null(cfg$features$persist)) {
    persist_features <- isTRUE(cfg$features$persist)
  }

  execution_mode <- "audit_log"
  checkpoint_every <- 10000L
  if (!is.null(cfg$engine) && is.list(cfg$engine)) {
    if (!is.null(cfg$engine$execution_mode)) {
      execution_mode <- cfg$engine$execution_mode
    }
    if (!is.null(cfg$engine$checkpoint_every)) {
      checkpoint_every <- as.integer(cfg$engine$checkpoint_every)
    }
  }
  if (!execution_mode %in% c("db_live", "audit_log")) {
    rlang::abort(
      "engine.execution_mode must be \"db_live\" or \"audit_log\".",
      class = "ledgr_invalid_config"
    )
  }

  list(
    persist_features = persist_features,
    execution_mode = execution_mode,
    checkpoint_every = checkpoint_every,
    snapshot_id = cfg$data$snapshot_id,
    snapshot_db_path = ledgr_snapshot_db_path_from_config(cfg, db_path)
  )
}

ledgr_run_prepare_control <- function(control) {
  fast_context <- control$fast_context
  if (is.null(fast_context)) fast_context <- FALSE
  if (!is.logical(fast_context) ||
    length(fast_context) != 1L ||
    is.na(fast_context)) {
    rlang::abort(
      "`control$fast_context` must be TRUE or FALSE.",
      class = "ledgr_invalid_args"
    )
  }

  max_pulses <- control$max_pulses
  if (is.null(max_pulses)) max_pulses <- Inf

  list(
    fast_context = fast_context,
    max_pulses = max_pulses
  )
}

ledgr_run_prepare_telemetry_stride <- function(control) {
  telemetry_stride <- control$telemetry_stride
  if (is.null(telemetry_stride)) telemetry_stride <- 100L
  if (!is.numeric(telemetry_stride) ||
    length(telemetry_stride) != 1L ||
    is.na(telemetry_stride) ||
    !is.finite(telemetry_stride) ||
    telemetry_stride < 0 ||
    (telemetry_stride %% 1) != 0) {
    rlang::abort(
      "`control$telemetry_stride` must be an integer >= 0.",
      class = "ledgr_invalid_args"
    )
  }
  telemetry_stride
}
