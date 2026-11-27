ws4a_d1_pub_allowed <- c(
  ledgr_fill_event_payload = ".POSIXct", "ledgr_output_handler/handler$flush_pulse_events" = ".POSIXct",
  "ledgr_output_handler/handler$write_fill_events" = ".POSIXct",
  "ledgr_output_handler/handler$write_fill_events" = "as.POSIXct",
  ledgr_write_fill_publication_row = ".POSIXct", ledgr_write_fill_publication_row = "as.POSIXct",
  ledgr_write_fill_publication_row = "lapply", ledgr_write_fill_publication_row = "structure",
  ledgr_fill_row_buffer_add_many = "as.POSIXct", ledgr_fill_meta_rows = "Map", ledgr_fill_meta_rows = "list",
  ledgr_fill_event_payload = "vapply", "ledgr_output_handler/handler$append_event_rows" = "lapply",
  "ledgr_output_handler/handler$append_event_rows" = "vapply",
  "ledgr_output_sink_duckdb/sink$write_fill_live" = "structure"
)
ws4a_d1_pub_loops <- c(
  ledgr_fold_fill_candidate = "while (failed - ok > 1L)",
  "ledgr_output_handler/stage_fill_block" = "for (name in setdiff(names(block), c(\"status\", \"next_event_seq\")))",
  "ledgr_output_handler/handler$flush_pulse_events" = "for (name in setdiff(ledgr_output_event_columns, \"ts_utc\"))",
  "ledgr_output_sink_memory/sink$stage_legs" = "for (name in names(legs))",
  "ledgr_output_handler/handler$append_event_rows" = "for (name in ledgr_output_event_columns)",
  "ledgr_output_sink_duckdb/sink$write_fill_live" = "for (k in seq_along(publication$event_seq))"
)
