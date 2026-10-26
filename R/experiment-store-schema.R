ledgr_experiment_store_schema_version <- 124L
ledgr_saved_sweep_schema_version <- 6L
ledgr_sweep_provenance_version <- "ledgr_provenance_v2"
ledgr_candidate_reproduction_key_version <- "ledgr_candidate_reproduction_key_v2"

ledgr_experiment_store_version <- function(con) {
  ledgr_store_assert_current(con)
  ledgr_experiment_store_schema_version
}
