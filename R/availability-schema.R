ledgr_experiment_store_ensure_availability_tables <- function(con) {
  if (ledgr_experiment_store_table_exists(con, "snapshots")) {
    ledgr_experiment_store_add_column(con, "snapshots", "hash_rule_version", "INTEGER")
  }

  DBI::dbExecute(
    con,
    "
    CREATE TABLE IF NOT EXISTS snapshot_fact_families (
      snapshot_id TEXT NOT NULL,
      family TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      family_schema_version INTEGER NOT NULL,
      metadata_json TEXT NOT NULL,
      PRIMARY KEY (snapshot_id, family, scope_id)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    CREATE TABLE IF NOT EXISTS snapshot_membership_sets (
      snapshot_id TEXT NOT NULL,
      universe_id TEXT NOT NULL,
      set_id TEXT NOT NULL,
      effective_from TIMESTAMP NOT NULL,
      knowledge_time TIMESTAMP,
      complete BOOLEAN NOT NULL,
      provenance_json TEXT NOT NULL,
      PRIMARY KEY (snapshot_id, universe_id, set_id)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    CREATE TABLE IF NOT EXISTS snapshot_membership (
      snapshot_id TEXT NOT NULL,
      fact_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      universe_id TEXT NOT NULL,
      set_id TEXT,
      effective_from TIMESTAMP NOT NULL,
      effective_to TIMESTAMP,
      knowledge_time TIMESTAMP,
      member BOOLEAN NOT NULL,
      provenance_json TEXT NOT NULL,
      PRIMARY KEY (snapshot_id, fact_id)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    CREATE TABLE IF NOT EXISTS snapshot_trading_status (
      snapshot_id TEXT NOT NULL,
      fact_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      effective_from TIMESTAMP NOT NULL,
      effective_to TIMESTAMP,
      knowledge_time TIMESTAMP,
      status TEXT NOT NULL CHECK (status IN ('active','halted','quotation_only')),
      source TEXT NOT NULL,
      precedence INTEGER NOT NULL,
      revision_id TEXT,
      supersedes_fact_id TEXT,
      provenance_json TEXT NOT NULL,
      PRIMARY KEY (snapshot_id, fact_id)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    CREATE TABLE IF NOT EXISTS snapshot_lifetime (
      snapshot_id TEXT NOT NULL,
      fact_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      effective_from TIMESTAMP NOT NULL,
      effective_to TIMESTAMP,
      knowledge_time TIMESTAMP,
      assertion TEXT NOT NULL CHECK (assertion IN ('known_active','known_inactive','unknown')),
      terminal_event TEXT,
      provenance_json TEXT NOT NULL,
      PRIMARY KEY (snapshot_id, fact_id)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    CREATE TABLE IF NOT EXISTS snapshot_sessions (
      snapshot_id TEXT NOT NULL,
      venue_id TEXT NOT NULL,
      session_date DATE NOT NULL,
      effective_from TIMESTAMP NOT NULL,
      effective_to TIMESTAMP NOT NULL,
      knowledge_time TIMESTAMP,
      status TEXT NOT NULL CHECK (status IN ('open','closed')),
      session_open TIMESTAMP,
      session_close TIMESTAMP,
      provenance_json TEXT NOT NULL,
      PRIMARY KEY (snapshot_id, venue_id, session_date)
    )
    "
  )
  DBI::dbExecute(
    con,
    "
    CREATE TABLE IF NOT EXISTS snapshot_observation_quarantine (
      snapshot_id TEXT NOT NULL,
      quarantine_id TEXT NOT NULL,
      supplied_instrument_id TEXT,
      supplied_ts_utc TIMESTAMP,
      reason TEXT NOT NULL,
      original_row_json TEXT NOT NULL,
      provenance_json TEXT NOT NULL,
      PRIMARY KEY (snapshot_id, quarantine_id)
    )
    "
  )

  DBI::dbExecute(
    con,
    "CREATE INDEX IF NOT EXISTS idx_snapshot_membership_cutoff
     ON snapshot_membership (snapshot_id, universe_id, effective_from, knowledge_time)"
  )
  DBI::dbExecute(
    con,
    "CREATE INDEX IF NOT EXISTS idx_snapshot_status_cutoff
     ON snapshot_trading_status (snapshot_id, instrument_id, effective_from, knowledge_time)"
  )
  DBI::dbExecute(
    con,
    "CREATE INDEX IF NOT EXISTS idx_snapshot_lifetime_cutoff
     ON snapshot_lifetime (snapshot_id, instrument_id, effective_from, knowledge_time)"
  )
  DBI::dbExecute(
    con,
    "CREATE INDEX IF NOT EXISTS idx_snapshot_sessions_close
     ON snapshot_sessions (snapshot_id, venue_id, session_close)"
  )
  invisible(TRUE)
}
