config_hash <- function(config) {
  digest::digest(canonical_json(config_hash_payload(config)), algo = "sha256")
}

config_hash_payload <- function(config) {
  payload <- unclass(config)
  payload <- ledgr_config_normalize_risk_identity(payload)
  payload$db_path <- NULL
  payload$run_id <- NULL
  payload$alias_map_order <- NULL
  payload$sweep_retention <- NULL
  if (is.list(payload$data)) {
    payload$data$snapshot_db_path <- NULL
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
      payload$features$defs <- payload$features$defs[order(feature_ids)]
    }
  }
  payload
}

