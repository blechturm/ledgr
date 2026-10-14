ledgr_experiment_store_schema_version <- 120L
ledgr_saved_sweep_schema_version <- 4L

ledgr_experiment_store_version <- function(con) {
  ledgr_store_assert_current(con)
  ledgr_experiment_store_schema_version
}
