# Cut 27 amendment_test_inventory (1): can a public input reach the package
# fold's staging-capacity refusal ("Pulse diagnostic staging exceeded its
# capacity.", ledgr_fold_staging_write)? The pin's pulse staging is sized
# once to max(6N + 4, the most due dispositions of any pulse); the lean core
# has no staging buffer. This probe runs every gate workload on the pin only
# and records, per workload, the largest staged row count of any pulse and
# the staging's capacity. A margin above zero on the whole corpus is
# evidence, not proof, that the bound holds; a refusal would be a finding.
#
#   Rscript staging_reach_probe.R --lib=<pin library> --out=<csv> [--workloads=a,b]
local({
  argv <- commandArgs(TRUE)
  arg <- function(n, d = NULL) { v <- grep(paste0("^--", n, "="), argv, value = TRUE); if (length(v)) sub(paste0("^--", n, "="), "", v[[1L]]) else d }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  assign("probe_out", arg("out"), globalenv())
  assign("probe_only", arg("workloads", ""), globalenv())
  assign("probe_here", here, globalenv())
})
# loop_parity.R's definitions (its workloads and helpers), without its run loop.
exprs <- parse(file.path(probe_here, "loop_parity.R"), keep.source = FALSE)
stop_at <- which(vapply(exprs, function(e) is.call(e) && identical(e[[1L]], as.name("for")), logical(1)))
stop_at <- stop_at[stop_at > 50L][[1L]]
for (e in exprs[seq_len(stop_at - 1L)]) eval(e, globalenv())
ns <- asNamespace("ledgr")
seen <- new.env()
inner <- get("ledgr_fold_staging_write", envir = ns)
unlockBinding("ledgr_fold_staging_write", ns)
assign("ledgr_fold_staging_write", function(fold_state, rows, logical_offset) {
  used <- fold_state$pending_segments$n + rows$n
  seen$peak <- max(seen$peak, used)
  seen$capacity <- max(seen$capacity, fold_state$pending_segments$capacity)
  inner(fold_state, rows, logical_offset)
}, envir = ns)
lockBinding("ledgr_fold_staging_write", ns)
ids <- all_ids
if (nzchar(probe_only)) ids <- intersect(ids, strsplit(probe_only, ",")[[1L]])
rows <- list()
for (id in ids) {
  seen$peak <- 0L
  seen$capacity <- 0L
  (loop_entry_rng[[id]] %||% function() NULL)()
  err <- tryCatch({ run_tables(id); "" }, error = function(e) paste(class(e)[[1L]], conditionMessage(e)))
  rows[[id]] <- data.frame(workload = id, peak_staged = seen$peak, capacity = seen$capacity,
                           margin = seen$capacity - seen$peak, refused = grepl("staging exceeded", err), error = err,
                           stringsAsFactors = FALSE)
  cat(sprintf("%-36s peak %5d capacity %5d %s\n", id, seen$peak, seen$capacity, err))
}
out <- do.call(rbind, rows)
utils::write.csv(out, probe_out, row.names = FALSE)
staged <- out[out$capacity > 0L, ]
cat(sprintf("%d workloads, %d staged; smallest margin %d; refusals %d\n", nrow(out), nrow(staged),
            if (nrow(staged)) min(staged$margin) else NA_integer_, sum(out$refused)))
