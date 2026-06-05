config_hash <- function(config) {
  digest::digest(canonical_json(config_hash_payload(config)), algo = "sha256")
}

config_hash_payload <- function(config) {
  payload <- unclass(config)
  payload$db_path <- NULL
  payload$run_id <- NULL
  payload$alias_map_order <- NULL
  if (is.list(payload$data)) {
    payload$data$snapshot_db_path <- NULL
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

