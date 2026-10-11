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
    # Identity rule 2 binds the sealed content hash, not the store-local
    # snapshot ID (LDG-3004). A config without the field keeps rule 1.
    if (identical(ledgr_config_identity_rule(payload), 2L)) payload$data$snapshot_id <- NULL
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


# Run and session identity rules. Rule 1 hashed the store-local snapshot ID;
# rule 2 hashes the sealed snapshot content hash instead (LDG-3004). Stored
# runs keep the rule they were recorded under and stay readable.
ledgr_identity_rule_version <- 2L

ledgr_config_identity_rule <- function(config) {
  version <- config$identity_rule_version
  if (is.null(version)) return(1L)
  as.integer(version)
}

# A run or session recorded under an earlier identity rule is inspection-only:
# resuming it or rerunning it under the current rule would hash differently.
ledgr_identity_rule_retired_abort <- function(subject, rule) {
  rlang::abort(
    paste0(
      subject, " was recorded under identity rule ", rule, ", which bound the store-local snapshot ID. ",
      "It remains readable, but cannot be resumed or rerun under identity rule ", ledgr_identity_rule_version,
      ", which binds the snapshot content hash. Start a new run_id or session."
    ),
    class = c("ledgr_identity_rule_retired", "ledgr_run_hash_mismatch")
  )
}
