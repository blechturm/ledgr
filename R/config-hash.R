config_hash <- function(config) {
  digest::digest(canonical_json(config_hash_payload(config)), algo = "sha256")
}

config_hash_payload <- function(config) {
  if (!identical(config$identity_rule_version, ledgr_identity_rule_version)) {
    rlang::abort(
      "Config identity_rule_version must equal 2.",
      class = "ledgr_invalid_config"
    )
  }
  snapshot_hash <- config$data$snapshot_hash
  if (!is.character(snapshot_hash) || length(snapshot_hash) != 1L ||
      is.na(snapshot_hash) || !nzchar(snapshot_hash)) {
    rlang::abort(
      "Config field data.snapshot_hash must be a non-empty character scalar.",
      class = "ledgr_invalid_config"
    )
  }
  payload <- unclass(config)
  payload <- ledgr_config_normalize_risk_identity(payload)
  payload$db_path <- NULL
  payload$run_id <- NULL
  payload$alias_map_order <- NULL
  payload$sweep_retention <- NULL
  if (is.list(payload$data)) {
    payload$data$snapshot_db_path <- NULL
    # Identity rule 2 binds the sealed content hash, not the store-local ID.
    payload$data$snapshot_id <- NULL
  }
  if (is.list(payload$sweep)) {
    payload$sweep$sweep_retention <- NULL
    payload$sweep$retention <- NULL
    if (length(payload$sweep) == 0L) {
      payload$sweep <- NULL
    }
  }
  if (is.list(payload$features)) {
    payload$features$feature_set_hash <- NULL
  }
  if (is.list(payload$features) && is.list(payload$features$defs) && length(payload$features$defs) > 0L) {
    feature_ids <- vapply(payload$features$defs, function(def) {
      if (is.list(def) && is.character(def$id) && length(def$id) == 1L && !is.na(def$id)) {
        return(def$id)
      }
      NA_character_
    }, character(1))
    if (all(!is.na(feature_ids))) {
      payload$features$defs <- payload$features$defs[order(feature_ids, method = "radix")]
    }
  }
  payload
}


# Run and session identity bind the sealed snapshot content hash.
ledgr_identity_rule_version <- 2L
