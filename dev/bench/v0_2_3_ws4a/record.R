# WS4a case recorder (LDG-3163 scope c): records every design-note Section 4
# case on the current tree into records/<case>/ (canonical %.17g CSV per
# table, case.rds with the same tables and the raw facts, and, where a case
# observes private state, observed_not_oracle.rds, which check.R ignores).
#
# Usage: Rscript record.R [--out=<dir>] [--cases=C1,C2]
#   --out    defaults to records/ next to this script

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])), "lib.R"))
out_dir <- ws_arg("out", file.path(ws_dir, "records"))
ids <- ws_arg("cases")
ids <- if (is.null(ids)) names(ws_cases) else strsplit(ids, ",", fixed = TRUE)[[1L]]
for (id in ids) {
  res <- ws_run_case(id, file.path(tempdir(), "ws4a_record", id))
  if (!is.null(res$tables$case_error)) stop(sprintf("%s failed: %s", id, res$tables$case_error$message), call. = FALSE)
  ws_write_case(res, file.path(out_dir, id))
  cat(sprintf("%-6s %-10s %d tables\n", id, ws_cases[[id]]$owner, length(res$tables)))
}
base <- system2("git", c("-C", ws_root, "rev-parse", "HEAD"), stdout = TRUE)
writeLines(c(paste("recorded_on", base), paste("product_base 953338df"), paste("cases", paste(names(ws_cases), collapse = ","))),
  file.path(out_dir, "base.txt"))
