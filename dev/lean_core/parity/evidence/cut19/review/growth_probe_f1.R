source("C:/Users/maxth/Documents/GitHub/ledgr/dev/lean_core/load.R")
lean <- lean_core_load("C:/Users/maxth/AppData/Local/Temp/claude/a337d437c6e22de3/78383ced-ac83-4579-b480-65f39660106d/scratchpad/ws16/lib-d5b3a151")
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/lean_core/parity/loop_edits.R")
e <- lean_edit("marks.R", "lean_marks_add_rows",
  "    xr <- lapply(xr, function(v) { length(v) <- s3$xcap; v })", "    xr <- lapply(xr, function(v) { v[[s3$nx]] <- v[[length(v)]]; v })", "after")
lean_load_edited(lean, lean_core_home, list(e), marker = "lean_entry$variant_reached <- TRUE")
s <- lean$lean_marks_run_state(list(observed = TRUE, close = matrix(1, 1, 1)), "A", NULL, NULL, NULL, NULL)
g <- function(ids) lean$lean_marks_group(ids, "valuation", "exited", "valuation_freeze_exited")
lean$lean_marks_add_rows(s, 1L, 1L, g(sprintf("old%02d", 1:60)))
prefix <- lapply(s$xr, function(v) v[1:60])
lean$lean_marks_add_rows(s, 2L, 1L, g(sprintf("new%02d", 1:10)))
res <- c(paste("marker", lean$lean_entry$variant_reached), paste("used", s$nx, "allocated", s$xcap),
  paste("all_existing_prefix_columns_identical", identical(prefix, lapply(s$xr, function(v) v[1:60]))),
  paste("existing_rows_lost", paste(setdiff(sprintf("old%02d", 1:60), s$xr$instrument_id[seq_len(s$nx)]), collapse = ",")),
  paste("incoming_rows_lost", paste(setdiff(sprintf("new%02d", 1:10), s$xr$instrument_id[seq_len(s$nx)]), collapse = ",")),
  paste("physical_row70", s$xr$instrument_id[[70L]]))
writeLines(res, "C:/Users/maxth/AppData/Local/Temp/claude/a337d437c6e22de3/78383ced-ac83-4579-b480-65f39660106d/scratchpad/cut19/growth_probe_f1.txt")
cat(paste(res, collapse = "\n"), "\n")
