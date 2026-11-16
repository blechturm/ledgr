# Cut 20 (LDG-3241): the re-anchored variants and the store negative control,
# each through loop_parity.R as loop_variants.R runs them. Every manifest row
# of store_append, store_bind, store_execute, store_query and
# zero_pulse_align, at debug 0 and 1, must be CAUGHT; control_wrong_store_path
# (which shares the re-anchored store helper) must be MISSED with status 1.
#
#   Rscript dev/lean_core/parity/cut20_reanchor.R --lib=<pinned library> --out=<dir>

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
lib <- arg("lib")
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
manifest <- utils::read.csv(file.path(here, "loop_variants.csv"), stringsAsFactors = FALSE)
names_v <- c("store_append", "store_bind", "store_execute", "store_query", "zero_pulse_align")
manifest <- manifest[manifest$mutation %in% names_v, ]
rscript <- file.path(R.home("bin"), "Rscript.exe")
run <- function(m, d, b, workloads, csv) {
  log <- suppressWarnings(system2(rscript, c(file.path(here, "loop_parity.R"), paste0("--lib=", lib),
    paste0("--debug=", d), paste0("--batch-rows=", b), paste0("--mutation=", m),
    paste0("--workloads=", paste(workloads, collapse = ",")), paste0("--out=", csv)), stdout = TRUE, stderr = TRUE))
  list(status = as.integer(attr(log, "status") %||% 0L),
       rows = if (file.exists(csv)) utils::read.csv(csv, stringsAsFactors = FALSE) else NULL)
}
rows <- list()
for (g in split(manifest, paste(manifest$mutation, manifest$debug, manifest$batch_rows))) {
  m <- g$mutation[[1L]]; d <- g$debug[[1L]]; b <- g$batch_rows[[1L]]
  r <- run(m, d, b, g$workload, file.path(out, sprintf("variant_%s_debug%d_b%d.csv", m, d, b)))
  got <- if (is.null(r$rows)) character() else stats::setNames(r$rows$verdict, r$rows$workload)
  for (w in g$workload) rows[[length(rows) + 1L]] <- data.frame(mutation = m, workload = w, debug = d, batch_rows = b,
    status = r$status, verdict = if (w %in% names(got)) unname(got[w])[[1L]] else "missing", expected = "CAUGHT")
}
r <- run("control_wrong_store_path", 0L, 8L, "crossover_3x40", file.path(out, "control_control_wrong_store_path.csv"))
rows[[length(rows) + 1L]] <- data.frame(mutation = "control_wrong_store_path", workload = "crossover_3x40", debug = 0L,
  batch_rows = 8L, status = r$status, verdict = if (is.null(r$rows)) "missing" else paste(unique(r$rows$verdict), collapse = ","),
  expected = "MISSED")
res <- do.call(rbind, rows)
res$ok <- res$verdict == res$expected & (res$expected == "CAUGHT" | res$status == 1L)
utils::write.csv(res, file.path(out, "reanchor_summary.csv"), row.names = FALSE)
print(res, row.names = FALSE)
cat(sprintf("%d rows, %d as expected\n", nrow(res), sum(res$ok)))
quit(status = if (all(res$ok)) 0L else 1L)
