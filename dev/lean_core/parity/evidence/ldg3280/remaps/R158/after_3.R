ws4a_d1_pub_allowed <- c(
  ledgr_fill_event_payload = ".POSIXct", "ledgr_output_handler/handler$flush_pulse_events" = ".POSIXct",
  "ledgr_output_handler/handler$write_fill_events" = ".POSIXct",
  "ledgr_output_handler/handler$write_fill_events" = "as.POSIXct",
  ledgr_write_fill_publication_row = ".POSIXct", ledgr_write_fill_publication_row = "as.POSIXct",
  ledgr_write_fill_publication_row = "lapply", ledgr_write_fill_publication_row = "structure",
  ledgr_fill_row_buffer_add_many = "as.POSIXct", ledgr_fill_meta_rows = "Map", ledgr_fill_meta_rows = "list",
  ledgr_fill_event_payload = "vapply", "ledgr_output_handler/handler$append_event_rows" = "lapply",
  "ledgr_output_handler/handler$append_event_rows" = "vapply",
  "ledgr_output_sink_duckdb/sink$write_fill_live" = "structure",
  # The terminal transfer works per batch of at most `bound` rows, never per
  # fill: the batch ranges (pieces()), the explicit and implicit blocks cut
  # column by column with lapply(), each implicit batch's row count, the
  # completion row's two epochs, and one applied-columns list per fill batch.
  lean_loop_publish = "lapply", lean_loop_publish = "list", lean_loop_publish = ".POSIXct",
  lean_facts_emit = "list"
)
ws4a_d1_pub_loops <- c(
  lean_lot_first_failure = "while (failed - ok > 1L)",
  "ledgr_output_handler/stage_fill_block" = "for (name in setdiff(names(block), c(\"status\", \"next_event_seq\")))",
  "ledgr_output_handler/handler$flush_pulse_events" = "for (name in setdiff(ledgr_output_event_columns, \"ts_utc\"))",
  "ledgr_output_sink_memory/sink$stage_legs" = "for (name in names(legs))",
  "ledgr_output_handler/handler$append_event_rows" = "for (name in ledgr_output_event_columns)",
  "ledgr_output_sink_duckdb/sink$write_fill_live" = "for (k in seq_along(publication$event_seq))",
  # Lean P4 grows its fill records by doubling; the terminal transfer loops
  # over pulse ranges, batches and contiguous event-sequence runs.
  lean_p4_apply = "while (nf + n_fill > fcap)",
  lean_loop_publish = "while (a <= lay$np)",
  lean_loop_publish = "for (r in pieces(length(ex$explicit$diagnostic_seq)))",
  lean_loop_publish = "for (r in pieces(if (is.null(imp)) 0L else imp$n))",
  lean_facts_emit = "for (r in split(seq_along(fr), cumsum(c(TRUE, diff(ev) != 1L))))",
  lean_facts_emit = "for (s in seq.int(1L, length(r), by = bound))",
  lean_facts_emit_ca = "while (cur <= last)"
)
