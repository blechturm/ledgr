args <- commandArgs(trailingOnly = TRUE)
here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), winslash = "/")
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
source(file.path(here, "case.R"))
source(file.path(here, "prototype.R"))

output <- if (length(args) >= 1L) args[[1L]] else file.path(here, "evidence")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
events <- typed_accounting_case()

timings <- list()
for (layout in c("wide", "companion")) {
  for (iteration in seq_len(3L)) {
    path <- file.path(output, sprintf("%s_%d.duckdb", layout, iteration))
    row <- typed_accounting_measure(layout, events, path)
    row$iteration <- iteration
    timings[[length(timings) + 1L]] <- row
  }
}
timing <- do.call(rbind, timings)
timing <- timing[c(
  "layout", "iteration", "rows", "write_seconds", "read_seconds",
  "db_bytes", "mismatched_cells"
)]
utils::write.csv(timing, file.path(output, "timing.csv"), row.names = FALSE, na = "")

semantic <- aggregate(
  cbind(mismatched_cells, db_bytes) ~ layout + rows,
  data = timing,
  FUN = function(x) if (all(x == x[[1L]])) x[[1L]] else NA_real_
)
semantic$event_types <- length(unique(events$event_type))
semantic$sources <- length(unique(stats::na.omit(events$source)))
semantic <- semantic[c(
  "layout", "rows", "event_types", "sources", "mismatched_cells", "db_bytes"
)]
utils::write.csv(semantic, file.path(output, "semantic.csv"), row.names = FALSE, na = "")

gut_path <- file.path(output, "gut.duckdb")
gut <- typed_accounting_measure("companion", events, gut_path, gut = TRUE)
gut$expected_failure <- gut$mismatched_cells > 0L
utils::write.csv(
  gut[c("layout", "rows", "mismatched_cells", "expected_failure")],
  file.path(output, "gut.csv"), row.names = FALSE, na = ""
)

unlink(list.files(output, pattern = "\\.duckdb$", full.names = TRUE))
cat(sprintf("wrote typed-accounting evidence to %s\n", normalizePath(output, winslash = "/")))
