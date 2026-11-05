args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("Usage: measure_plan.R <source-root> <build.csv> <output.txt>")
}
source_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
meta <- utils::read.csv(args[[2L]], stringsAsFactors = FALSE)
output <- args[[3L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(source_root, quiet = TRUE)
snapshot <- ledgr_snapshot_open(meta$store[[1L]], meta$snapshot_id[[1L]])
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
bt <- ledgr_run_open(snapshot, meta$run_id[[1L]])
on.exit(close(bt), add = TRUE)
opened <- ledgr:::ledgr_backtest_read_connection(bt)
on.exit(opened$close(), add = TRUE)

plan <- NULL
capturing <- FALSE
trace(
  DBI::dbGetQuery,
  tracer = quote({
    if (!capturing && is.character(statement) && length(statement) == 1L &&
        grepl("WITH run_meta", statement, fixed = TRUE)) {
      capturing <<- TRUE
      result <- DBI::dbSendQuery(conn, paste("EXPLAIN", statement))
      dots <- list(...)
      query_params <- dots[["params"]]
      if (!is.null(query_params) && length(query_params) > 0L) {
        DBI::dbBind(result, query_params)
      }
      plan <<- DBI::dbFetch(result)
      DBI::dbClearResult(result)
      capturing <<- FALSE
    }
  }),
  print = FALSE
)
on.exit(untrace(DBI::dbGetQuery), add = TRUE)
invisible(
  ledgr:::ledgr_diagnostic_decision_order_bad(opened$con, bt$run_id)
)
if (is.null(plan) || nrow(plan) == 0L) stop("Decision-order EXPLAIN was not captured.")
plan_rows <- apply(plan, 1L, paste, collapse = "\t")
plan_rows <- gsub("[^ -~\\t]", "", plan_rows, perl = TRUE)
lines <- c(
  paste0("source_commit=", meta$source_commit[[1L]]),
  paste0("fixture_sha256=", meta$fixture_sha256[[1L]]),
  paste0("decision_shape_rows=", meta$decision_shape_rows[[1L]]),
  paste0("membership_sets=", meta$membership_sets[[1L]]),
  "",
  paste(plan_rows, collapse = "\n")
)
writeLines(lines, output, useBytes = TRUE)
