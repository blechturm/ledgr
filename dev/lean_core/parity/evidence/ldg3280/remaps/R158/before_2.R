ws4a_pub_fns <- c("ledgr_fold_stage_apply", "ledgr_fold_fill_candidate", "ledgr_fill_event_payload",
  "ledgr_fill_leg_block", "ledgr_fill_leg_fees", "ledgr_fill_row_buffer_add_many",
  "ledgr_write_fill_publication_row")
ws4a_pub_closures <- c(
  ledgr_output_handler = "stage_fill_block", ledgr_output_handler = "handler$write_fill_events",
  ledgr_output_handler = "handler$flush_pulse_events", ledgr_output_handler = "handler$record_accounting_fact",
  ledgr_output_handler = "handler$append_event_rows", ledgr_output_sink_memory = "sink$stage_legs",
  ledgr_output_sink_memory = "add_legs", ledgr_output_sink_memory = "sink$flush_legs",
  ledgr_output_sink_duckdb = "sink$write_fill_live"
)
