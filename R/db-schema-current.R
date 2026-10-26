ledgr_current_schema_definition <- function() {
  sql <- function(...) paste(..., collapse = " ")

  list(
    tables = c(
      instruments = sql(
        "CREATE TABLE instruments(",
        "instrument_id VARCHAR PRIMARY KEY, symbol VARCHAR,",
        "currency VARCHAR, asset_class VARCHAR DEFAULT('EQUITY'))"
      ),
      equity_curve = sql(
        "CREATE TABLE equity_curve(",
        "run_id VARCHAR, ts_utc TIMESTAMP, cash DOUBLE,",
        "positions_value DOUBLE, equity DOUBLE, realized_pnl DOUBLE,",
        "unrealized_pnl DOUBLE, PRIMARY KEY(run_id, ts_utc))"
      ),
      strategy_state = sql(
        "CREATE TABLE strategy_state(",
        "run_id VARCHAR, ts_utc VARCHAR, state_json VARCHAR NOT NULL,",
        "PRIMARY KEY(run_id, ts_utc))"
      ),
      snapshots = sql(
        "CREATE TABLE snapshots(",
        "snapshot_id VARCHAR PRIMARY KEY, status VARCHAR NOT NULL,",
        "created_at_utc TIMESTAMP NOT NULL, sealed_at_utc TIMESTAMP,",
        "snapshot_hash VARCHAR, hash_rule_version INTEGER, meta_json VARCHAR,",
        "error_msg VARCHAR,",
        "CHECK((status IN ('CREATED', 'SEALED', 'FAILED'))))"
      ),
      snapshot_instruments = sql(
        "CREATE TABLE snapshot_instruments(",
        "snapshot_id VARCHAR, instrument_id VARCHAR, symbol VARCHAR,",
        "currency VARCHAR, asset_class VARCHAR, multiplier DOUBLE,",
        "tick_size DOUBLE, meta_json VARCHAR,",
        "PRIMARY KEY(snapshot_id, instrument_id))"
      ),
      snapshot_bars = sql(
        "CREATE TABLE snapshot_bars(",
        "snapshot_id VARCHAR, instrument_id VARCHAR, ts_utc TIMESTAMP,",
        "open DOUBLE NOT NULL, high DOUBLE NOT NULL, low DOUBLE NOT NULL,",
        "\"close\" DOUBLE NOT NULL, volume DOUBLE,",
        "PRIMARY KEY(snapshot_id, instrument_id, ts_utc))"
      ),
      runs = sql(
        "CREATE TABLE runs(",
        "run_id VARCHAR PRIMARY KEY, created_at_utc TIMESTAMP NOT NULL,",
        "engine_version VARCHAR, config_json VARCHAR, config_hash VARCHAR,",
        "snapshot_id VARCHAR, status VARCHAR NOT NULL, error_msg VARCHAR,",
        "\"label\" VARCHAR,",
        "archived BOOLEAN DEFAULT(CAST('f' AS BOOLEAN)) NOT NULL,",
        "archived_at_utc TIMESTAMP, archive_reason VARCHAR,",
        "execution_mode VARCHAR,",
        "schema_version INTEGER DEFAULT(109) NOT NULL,",
        "metric_context_json VARCHAR, metric_context_hash VARCHAR,",
        "metric_context_version INTEGER,",
        "CHECK((status IN",
        "('CREATED', 'RUNNING', 'DONE', 'INCOMPLETE', 'FAILED'))),",
        "CHECK(((execution_mode IS NULL) OR",
        "(execution_mode IN ('audit_log', 'db_live')))))"
      ),
      bars = sql(
        "CREATE TABLE bars(",
        "instrument_id VARCHAR, ts_utc TIMESTAMP, open DOUBLE NOT NULL,",
        "high DOUBLE NOT NULL, low DOUBLE NOT NULL,",
        "\"close\" DOUBLE NOT NULL, volume DOUBLE,",
        "gap_type VARCHAR DEFAULT('NONE') NOT NULL,",
        "is_synthetic BOOLEAN DEFAULT(CAST('f' AS BOOLEAN)) NOT NULL,",
        "CHECK((gap_type IN",
        "('NONE', 'MISSING', 'SOURCE_ERROR', 'HOLIDAY_MISMATCH'))),",
        "PRIMARY KEY(instrument_id, ts_utc))"
      ),
      ledger_events = sql(
        "CREATE TABLE ledger_events(",
        "event_id VARCHAR PRIMARY KEY, run_id VARCHAR NOT NULL,",
        "ts_utc TIMESTAMP NOT NULL, event_type VARCHAR NOT NULL,",
        "instrument_id VARCHAR, side VARCHAR, qty DOUBLE, price DOUBLE,",
        "fee DOUBLE, meta_json VARCHAR, event_seq INTEGER NOT NULL,",
        "CHECK((event_type IN ('FILL', 'CASHFLOW', 'DISPOSITION'))),",
        "CHECK((side IN ('BUY', 'SELL'))), UNIQUE(run_id, event_seq))"
      ),
      ledgr_schema_metadata = sql(
        "CREATE TABLE ledgr_schema_metadata(",
        "\"key\" VARCHAR PRIMARY KEY, \"value\" VARCHAR NOT NULL,",
        "updated_at_utc TIMESTAMP NOT NULL)"
      ),
      run_promotion_context = sql(
        "CREATE TABLE run_promotion_context(",
        "run_id VARCHAR PRIMARY KEY,",
        "promotion_context_version VARCHAR NOT NULL,",
        "\"source\" VARCHAR NOT NULL, promoted_at_utc TIMESTAMP NOT NULL,",
        "note VARCHAR, selected_candidate_json VARCHAR NOT NULL,",
        "source_sweep_json VARCHAR NOT NULL,",
        "candidate_summary_json VARCHAR NOT NULL)"
      ),
      run_provenance = sql(
        "CREATE TABLE run_provenance(",
        "run_id VARCHAR PRIMARY KEY, strategy_type VARCHAR,",
        "strategy_source VARCHAR, strategy_source_hash VARCHAR,",
        "strategy_source_capture_method VARCHAR,",
        "strategy_params_json VARCHAR, strategy_params_hash VARCHAR,",
        "schedule_json VARCHAR, schedule_hash VARCHAR,",
        "reproducibility_level VARCHAR, ledgr_version VARCHAR,",
        "R_version VARCHAR, dependency_versions_json VARCHAR,",
        "created_at_utc TIMESTAMP)"
      ),
      run_telemetry = sql(
        "CREATE TABLE run_telemetry(",
        "run_id VARCHAR PRIMARY KEY, status VARCHAR, execution_mode VARCHAR,",
        "elapsed_sec DOUBLE, pulse_count INTEGER,",
        "decision_pulse_count INTEGER, scheduled_skip_count INTEGER,",
        "updated_at_utc TIMESTAMP,",
        "CHECK(((execution_mode IS NULL) OR",
        "(execution_mode IN ('audit_log', 'db_live')))))"
      ),
      run_tags = sql(
        "CREATE TABLE run_tags(",
        "run_id VARCHAR, tag VARCHAR, created_at_utc TIMESTAMP NOT NULL,",
        "PRIMARY KEY(run_id, tag))"
      ),
      sweeps = sql(
        "CREATE TABLE sweeps(",
        "sweep_id VARCHAR PRIMARY KEY, snapshot_id VARCHAR NOT NULL,",
        "snapshot_hash VARCHAR NOT NULL, created_at_utc TIMESTAMP NOT NULL,",
        "engine_version VARCHAR NOT NULL,",
        "sweep_schema_version INTEGER NOT NULL,",
        "identity_rule_version INTEGER NOT NULL, note VARCHAR,",
        "retention_json VARCHAR NOT NULL, metric_context_json VARCHAR NOT NULL,",
        "metric_context_hash VARCHAR NOT NULL,",
        "metric_context_version INTEGER NOT NULL,",
        "cost_model_hash VARCHAR NOT NULL, cost_plan_json VARCHAR NOT NULL,",
        "risk_chain_hash VARCHAR, risk_plan_json VARCHAR,",
        "execution_assumptions_json VARCHAR NOT NULL,",
        "feature_union_hash VARCHAR NOT NULL,",
        "feature_engine_version VARCHAR NOT NULL,",
        "candidate_features_json VARCHAR NOT NULL, grid_json VARCHAR NOT NULL)"
      ),
      sweep_candidates = sql(
        "CREATE TABLE sweep_candidates(",
        "sweep_id VARCHAR, candidate_id VARCHAR NOT NULL,",
        "candidate_row INTEGER, status VARCHAR NOT NULL,",
        "completion_json VARCHAR, final_equity DOUBLE,",
        "metrics_json VARCHAR NOT NULL, total_return DOUBLE,",
        "annualized_return DOUBLE, volatility DOUBLE, sharpe_ratio DOUBLE,",
        "max_drawdown DOUBLE, n_trades INTEGER, win_rate DOUBLE,",
        "avg_trade DOUBLE, time_in_market DOUBLE, execution_seed INTEGER,",
        "error_class VARCHAR, error_msg VARCHAR, params_json VARCHAR NOT NULL,",
        "feature_params_json VARCHAR NOT NULL, warnings_json VARCHAR NOT NULL,",
        "feature_set_hash VARCHAR NOT NULL,",
        "feature_fingerprints_json VARCHAR NOT NULL,",
        "provenance_json VARCHAR NOT NULL, cost_model_hash VARCHAR NOT NULL,",
        "metric_context_hash VARCHAR NOT NULL, risk_chain_hash VARCHAR,",
        "risk_plan_json VARCHAR,",
        "CHECK((status IN ('DONE', 'INCOMPLETE', 'FAILED'))),",
        "PRIMARY KEY(sweep_id, candidate_row),",
        "UNIQUE(sweep_id, candidate_id))"
      ),
      sweep_returns = sql(
        "CREATE TABLE sweep_returns(",
        "sweep_id VARCHAR, candidate_row INTEGER, pulse_index INTEGER,",
        "ts_utc TIMESTAMP NOT NULL, equity DOUBLE NOT NULL,",
        "period_return DOUBLE,",
        "PRIMARY KEY(sweep_id, candidate_row, pulse_index))"
      ),
      sweep_trades = sql(
        "CREATE TABLE sweep_trades(",
        "sweep_id VARCHAR, candidate_row INTEGER, trade_seq INTEGER,",
        "close_ts_utc TIMESTAMP NOT NULL, realized_pnl DOUBLE,",
        "win_loss VARCHAR,",
        "PRIMARY KEY(sweep_id, candidate_row, trade_seq))"
      ),
      walk_forward_sessions = sql(
        "CREATE TABLE walk_forward_sessions(",
        "session_id VARCHAR PRIMARY KEY, snapshot_hash VARCHAR NOT NULL,",
        "experiment_hash VARCHAR NOT NULL, param_grid_hash VARCHAR NOT NULL,",
        "fold_list_hash VARCHAR NOT NULL, selection_rule_hash VARCHAR NOT NULL,",
        "metric_context_hash VARCHAR NOT NULL, cost_model_hash VARCHAR NOT NULL,",
        "risk_chain_hash VARCHAR NOT NULL, master_seed INTEGER,",
        "opening_state_policy VARCHAR NOT NULL,",
        "created_at_utc TIMESTAMP NOT NULL, ledgr_version VARCHAR NOT NULL,",
        "meta_json VARCHAR NOT NULL,",
        "CHECK((opening_state_policy IN",
        "('carry_test_state', 'flat_test_state'))))"
      ),
      walk_forward_folds = sql(
        "CREATE TABLE walk_forward_folds(",
        "session_id VARCHAR, fold_id VARCHAR NOT NULL, fold_seq INTEGER,",
        "scheme VARCHAR NOT NULL, train_start_utc TIMESTAMP NOT NULL,",
        "train_end_utc TIMESTAMP NOT NULL, test_start_utc TIMESTAMP NOT NULL,",
        "test_end_utc TIMESTAMP NOT NULL,",
        "train_scoring_start_utc TIMESTAMP NOT NULL,",
        "test_scoring_start_utc TIMESTAMP NOT NULL,",
        "opening_state_policy VARCHAR NOT NULL,",
        "selected_candidate_key VARCHAR, selected_at_utc TIMESTAMP,",
        "test_run_id VARCHAR, status VARCHAR NOT NULL,",
        "selection_source VARCHAR,",
        "CHECK((opening_state_policy IN",
        "('carry_test_state', 'flat_test_state'))),",
        "CHECK((status IN ('DONE', 'FAILED', 'INTERRUPTED', 'PARTIAL'))),",
        "CHECK(((selection_source IS NULL) OR",
        "(selection_source IN ('train', 'previous', 'none')))),",
        "PRIMARY KEY(session_id, fold_seq), UNIQUE(session_id, fold_id))"
      ),
      walk_forward_scores = sql(
        "CREATE TABLE walk_forward_scores(",
        "session_id VARCHAR, fold_id VARCHAR NOT NULL, fold_seq INTEGER,",
        "candidate_key VARCHAR, candidate_label VARCHAR,",
        "params_hash VARCHAR NOT NULL, feature_params_hash VARCHAR NOT NULL,",
        "feature_set_hash VARCHAR NOT NULL, alias_map_hash VARCHAR NOT NULL,",
        "metric_context_hash VARCHAR NOT NULL, cost_model_hash VARCHAR NOT NULL,",
        "risk_chain_hash VARCHAR NOT NULL, \"window\" VARCHAR,",
        "metric_name VARCHAR, metric_value DOUBLE, n_trades INTEGER,",
        "status VARCHAR NOT NULL, completion_json VARCHAR, error_class VARCHAR,",
        "error_msg VARCHAR, execution_seed INTEGER,",
        "CHECK((\"window\" IN ('train', 'test'))),",
        "CHECK((status IN ('DONE', 'INCOMPLETE', 'FAILED'))),",
        "PRIMARY KEY(session_id, fold_seq, \"window\", candidate_key,",
        "metric_name))"
      ),
      snapshot_fact_families = sql(
        "CREATE TABLE snapshot_fact_families(",
        "snapshot_id VARCHAR, \"family\" VARCHAR, scope_id VARCHAR,",
        "family_schema_version INTEGER NOT NULL, metadata_json VARCHAR NOT NULL,",
        "PRIMARY KEY(snapshot_id, \"family\", scope_id))"
      ),
      snapshot_membership_sets = sql(
        "CREATE TABLE snapshot_membership_sets(",
        "snapshot_id VARCHAR, universe_id VARCHAR, set_id VARCHAR,",
        "effective_from TIMESTAMP NOT NULL, knowledge_time TIMESTAMP,",
        "complete BOOLEAN NOT NULL, civil_time_json VARCHAR NOT NULL,",
        "provenance_json VARCHAR NOT NULL,",
        "PRIMARY KEY(snapshot_id, universe_id, set_id))"
      ),
      snapshot_membership = sql(
        "CREATE TABLE snapshot_membership(",
        "snapshot_id VARCHAR, fact_id VARCHAR, instrument_id VARCHAR NOT NULL,",
        "universe_id VARCHAR NOT NULL, set_id VARCHAR,",
        "effective_from TIMESTAMP NOT NULL, effective_to TIMESTAMP,",
        "knowledge_time TIMESTAMP, member BOOLEAN NOT NULL,",
        "civil_time_json VARCHAR NOT NULL,",
        "provenance_json VARCHAR NOT NULL, PRIMARY KEY(snapshot_id, fact_id))"
      ),
      snapshot_trading_status = sql(
        "CREATE TABLE snapshot_trading_status(",
        "snapshot_id VARCHAR, fact_id VARCHAR, instrument_id VARCHAR NOT NULL,",
        "effective_from TIMESTAMP NOT NULL, effective_to TIMESTAMP,",
        "knowledge_time TIMESTAMP, status VARCHAR NOT NULL,",
        "\"source\" VARCHAR NOT NULL, precedence INTEGER NOT NULL,",
        "revision_id VARCHAR, supersedes_fact_id VARCHAR,",
        "civil_time_json VARCHAR NOT NULL,",
        "provenance_json VARCHAR NOT NULL,",
        "CHECK((status IN ('active', 'halted', 'quotation_only'))),",
        "PRIMARY KEY(snapshot_id, fact_id))"
      ),
      snapshot_lifetime = sql(
        "CREATE TABLE snapshot_lifetime(",
        "snapshot_id VARCHAR, fact_id VARCHAR, instrument_id VARCHAR NOT NULL,",
        "effective_from TIMESTAMP NOT NULL, effective_to TIMESTAMP,",
        "knowledge_time TIMESTAMP, \"assertion\" VARCHAR NOT NULL,",
        "terminal_event VARCHAR, civil_time_json VARCHAR NOT NULL,",
        "provenance_json VARCHAR NOT NULL,",
        "CHECK((\"assertion\" IN",
        "('known_active', 'known_inactive', 'unknown'))),",
        "PRIMARY KEY(snapshot_id, fact_id))"
      ),
      snapshot_equity_corporate_actions = sql(
        "CREATE TABLE snapshot_equity_corporate_actions(",
        "snapshot_id VARCHAR, fact_id VARCHAR, subtype VARCHAR NOT NULL,",
        "parent_instrument_id VARCHAR NOT NULL, entitlement_time TIMESTAMP,",
        "effective_time TIMESTAMP, knowledge_time TIMESTAMP,",
        "payment_time TIMESTAMP, complete BOOLEAN NOT NULL,",
        "refusal_reason VARCHAR, provenance_tier VARCHAR NOT NULL,",
        "upstream_build_id VARCHAR, bar_vintage_id VARCHAR,",
        "gross_cash_per_parent_unit DOUBLE,",
        "gross_cash_validated BOOLEAN NOT NULL,",
        "recipient_instrument_id VARCHAR,",
        "recipient_identity_validated BOOLEAN NOT NULL,",
        "recipient_quantity_per_parent_unit DOUBLE,",
        "recipient_quantity_validated BOOLEAN NOT NULL,",
        "civil_time_json VARCHAR NOT NULL,",
        "provenance_json VARCHAR NOT NULL,",
        "CHECK((provenance_tier IN",
        "('snapshot_bound', 'upstream_vintage_bound'))),",
        "PRIMARY KEY(snapshot_id, fact_id))"
      ),
      snapshot_sessions = sql(
        "CREATE TABLE snapshot_sessions(",
        "snapshot_id VARCHAR, venue_id VARCHAR, session_date DATE,",
        "effective_from TIMESTAMP NOT NULL, effective_to TIMESTAMP NOT NULL,",
        "knowledge_time TIMESTAMP, status VARCHAR NOT NULL,",
        "session_open TIMESTAMP, session_close TIMESTAMP,",
        "provenance_json VARCHAR NOT NULL,",
        "CHECK((status IN ('open', 'closed'))),",
        "PRIMARY KEY(snapshot_id, venue_id, session_date))"
      ),
      snapshot_observation_quarantine = sql(
        "CREATE TABLE snapshot_observation_quarantine(",
        "snapshot_id VARCHAR, quarantine_id VARCHAR,",
        "supplied_instrument_id VARCHAR, supplied_ts_utc TIMESTAMP,",
        "reason VARCHAR NOT NULL, original_row_json VARCHAR NOT NULL,",
        "provenance_json VARCHAR NOT NULL,",
        "PRIMARY KEY(snapshot_id, quarantine_id))"
      ),
      run_completion = sql(
        "CREATE TABLE run_completion(",
        "run_id VARCHAR PRIMARY KEY, intended_start_utc TIMESTAMP NOT NULL,",
        "intended_end_utc TIMESTAMP NOT NULL, achieved_start_utc TIMESTAMP,",
        "achieved_end_utc TIMESTAMP, intended_terminal_status VARCHAR NOT NULL,",
        "stop_reason VARCHAR, affected_exposure DOUBLE,",
        "affected_exposure_ts_utc TIMESTAMP, affected_exposure_basis VARCHAR,",
        "last_fully_valued_ts_utc TIMESTAMP, last_executed_ts_utc TIMESTAMP,",
        "complete_performance BOOLEAN NOT NULL,",
        "CHECK((intended_terminal_status IN ('DONE', 'INCOMPLETE'))))"
      ),
      run_diagnostics = sql(
        "CREATE TABLE run_diagnostics(",
        "run_id VARCHAR, diagnostic_seq INTEGER, ts_utc TIMESTAMP NOT NULL,",
        "instrument_id VARCHAR NOT NULL, stage VARCHAR NOT NULL,",
        "outcome VARCHAR NOT NULL, reason_code VARCHAR NOT NULL,",
        "reasons VARCHAR NOT NULL, \"target\" DOUBLE, quantity DOUBLE,",
        "price DOUBLE, mark_source VARCHAR, mark_age INTEGER,",
        "decision_ts_utc TIMESTAMP, execution_ts_utc TIMESTAMP,",
        "event_seq INTEGER, target_before_risk DOUBLE,",
        "target_after_risk DOUBLE, position_before DOUBLE,",
        "position_after DOUBLE, feature_identity_json VARCHAR,",
        "detail_json VARCHAR NOT NULL,",
        "PRIMARY KEY(run_id, diagnostic_seq))"
      )
    ),
    indexes = c(
      idx_sweep_returns_timestamp = paste(
        "CREATE INDEX idx_sweep_returns_timestamp ON sweep_returns",
        "(sweep_id, candidate_row, ts_utc)"
      ),
      idx_sweep_trades_close_ts = paste(
        "CREATE INDEX idx_sweep_trades_close_ts ON sweep_trades",
        "(sweep_id, candidate_row, close_ts_utc)"
      ),
      idx_walk_forward_scores_fold = paste(
        "CREATE INDEX idx_walk_forward_scores_fold ON walk_forward_scores",
        "(session_id, fold_seq, \"window\", status)"
      ),
      idx_snapshot_membership_cutoff = paste(
        "CREATE INDEX idx_snapshot_membership_cutoff ON snapshot_membership",
        "(snapshot_id, universe_id, effective_from, knowledge_time)"
      ),
      idx_snapshot_status_cutoff = paste(
        "CREATE INDEX idx_snapshot_status_cutoff ON snapshot_trading_status",
        "(snapshot_id, instrument_id, effective_from, knowledge_time)"
      ),
      idx_snapshot_lifetime_cutoff = paste(
        "CREATE INDEX idx_snapshot_lifetime_cutoff ON snapshot_lifetime",
        "(snapshot_id, instrument_id, effective_from, knowledge_time)"
      ),
      idx_snapshot_corporate_action_cutoff = paste(
        "CREATE INDEX idx_snapshot_corporate_action_cutoff",
        "ON snapshot_equity_corporate_actions",
        "(snapshot_id, parent_instrument_id, entitlement_time, knowledge_time)"
      ),
      idx_snapshot_sessions_close = paste(
        "CREATE INDEX idx_snapshot_sessions_close ON snapshot_sessions",
        "(snapshot_id, venue_id, session_close)"
      ),
      idx_snapshot_bars_ts = paste(
        "CREATE INDEX idx_snapshot_bars_ts ON snapshot_bars",
        "(snapshot_id, ts_utc)"
      )
    )
  )
}

ledgr_current_schema_statements <- function(definition = ledgr_current_schema_definition()) {
  unname(c(definition$tables, definition$indexes))
}

ledgr_schema_render_current <- function(con,
                                        definition = ledgr_current_schema_definition()) {
  statements <- ledgr_current_schema_statements(definition)
  vapply(statements, DBI::dbExecute, numeric(1), conn = con)
  invisible(TRUE)
}

ledgr_schema_normalized_catalogue <- function(con, schema = "main",
                                              catalog = NULL) {
  whitespace <- function(x) {
    x[is.na(x)] <- ""
    trimws(gsub("[[:space:]]+", " ", x))
  }
  catalog <- ledgr_store_catalog(catalog)
  catalog_predicate <- if (is.null(catalog)) "current_database()" else "?"
  query <- function(sql) {
    DBI::dbGetQuery(
      con,
      sql,
      params = if (is.null(catalog)) list(schema) else list(catalog, schema)
    )
  }

  tables <- query(
    "SELECT table_name
     FROM information_schema.tables
     WHERE table_catalog = %s AND table_schema = ?
       AND table_type = 'BASE TABLE'
     ORDER BY table_name" |>
      sprintf(catalog_predicate)
  )
  columns <- query(
    "SELECT table_name, column_name, ordinal_position, data_type,
            is_nullable, coalesce(column_default, '') AS column_default
     FROM information_schema.columns
     WHERE table_catalog = %s AND table_schema = ?
     ORDER BY table_name, ordinal_position" |>
      sprintf(catalog_predicate)
  )
  constraints <- query(
    "SELECT table_name, constraint_type,
            coalesce(array_to_string(constraint_column_names, '|'), '')
              AS column_names,
            coalesce(referenced_table, '') AS referenced_table,
            coalesce(array_to_string(referenced_column_names, '|'), '')
              AS referenced_column_names,
            coalesce(expression, '') AS expression,
            coalesce(constraint_text, '') AS constraint_text
     FROM duckdb_constraints()
     WHERE database_name = %s AND schema_name = ?
       AND constraint_type <> 'NOT NULL'
     ORDER BY table_name, constraint_type, column_names, referenced_table,
              referenced_column_names, expression, constraint_text" |>
      sprintf(catalog_predicate)
  )
  indexes <- query(
    "SELECT index_name, table_name, is_unique, is_primary,
            coalesce(expressions, '') AS expressions,
            coalesce(sql, '') AS sql
     FROM duckdb_indexes()
     WHERE database_name = %s AND schema_name = ?
     ORDER BY index_name" |>
      sprintf(catalog_predicate)
  )

  columns$data_type <- toupper(whitespace(columns$data_type))
  columns$is_nullable <- toupper(whitespace(columns$is_nullable))
  columns$column_default <- whitespace(columns$column_default)
  constraints$expression <- whitespace(constraints$expression)
  constraints$constraint_text <- whitespace(constraints$constraint_text)
  indexes$expressions <- whitespace(indexes$expressions)
  indexes$sql <- whitespace(indexes$sql)

  list(
    tables = tables,
    columns = columns,
    constraints = constraints,
    indexes = indexes
  )
}

ledgr_schema_catalogue_rows <- function(catalogue) {
  frame_rows <- function(dimension, frame, key_columns) {
    if (nrow(frame) == 0L) {
      return(data.frame(
        dimension = character(), object = character(), position = integer(),
        attribute = character(), value = character(),
        stringsAsFactors = FALSE
      ))
    }
    values <- lapply(names(frame), function(attribute) {
      value <- frame[[attribute]]
      if (is.logical(value)) value <- ifelse(value, "true", "false")
      value <- as.character(value)
      data.frame(
        dimension = dimension,
        object = do.call(paste, c(frame[key_columns], sep = ".")),
        position = seq_len(nrow(frame)),
        attribute = attribute,
        value = value,
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, values)
  }

  rows <- rbind(
    frame_rows("table", catalogue$tables, "table_name"),
    frame_rows(
      "column", catalogue$columns,
      c("table_name", "column_name")
    ),
    frame_rows(
      "constraint", catalogue$constraints,
      c(
        "table_name", "constraint_type", "column_names",
        "referenced_table", "referenced_column_names", "expression",
        "constraint_text"
      )
    ),
    frame_rows("index", catalogue$indexes, c("table_name", "index_name"))
  )
  rownames(rows) <- NULL
  rows
}

ledgr_schema_catalogue_difference <- function(expected, actual) {
  expected_rows <- ledgr_schema_catalogue_rows(expected)
  actual_rows <- ledgr_schema_catalogue_rows(actual)
  key <- function(x) {
    paste(
      x$dimension, x$object, x$attribute, x$value,
      sep = "\r"
    )
  }
  expected_key <- key(expected_rows)
  actual_key <- key(actual_rows)
  list(
    missing = expected_rows[is.na(match(expected_key, actual_key)), , drop = FALSE],
    extra = actual_rows[is.na(match(actual_key, expected_key)), , drop = FALSE]
  )
}

ledgr_schema_catalogue_digest <- function(catalogue) {
  rows <- ledgr_schema_catalogue_rows(catalogue)
  dimensions <- c("table", "column", "constraint", "index")
  data.frame(
    dimension = dimensions,
    rows = vapply(
      dimensions,
      function(dimension) sum(rows$dimension == dimension),
      integer(1)
    ),
    sha256 = vapply(dimensions, function(dimension) {
      payload <- rows[rows$dimension == dimension, , drop = FALSE]
      digest::digest(
        ledgr_json_write_canonical_ndjson(payload),
        algo = "sha256",
        serialize = FALSE
      )
    }, character(1)),
    stringsAsFactors = FALSE
  )
}
