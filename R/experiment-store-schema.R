ledgr_experiment_store_schema_version <- 122L
ledgr_saved_sweep_schema_version <- 5L

ledgr_experiment_store_version <- function(con) {
  ledgr_store_assert_current(con)
  ledgr_experiment_store_schema_version
}
