# Diagnostic writer at the Sharadar shape (Cut 11 LDG-2986, F7 and the
# character-column write measured apart).
#
#   Rscript writer_probe.R <tree> <out_csv> [pulses] [rows_per_pulse] [reps]
#
# Drives the production columnar writer with one typed block per pulse (the
# Sharadar momentum run writes about 3.6 million diagnostic rows over 7,213
# pulses, about 500 per pulse) into a file-backed DuckDB table inside one
# transaction, as a durable run does. Four variants: character columns written
# by copy-on-write replacement (the pre-cut code, rebuilt from the production
# function by replacing its one write line) or in place, at 4,096-row (pre-cut)
# and 65,536-row (final) chunks. Variants alternate within each repetition.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]; out_csv <- args[[2L]]
pulses <- if (length(args) > 2L) as.integer(args[[3L]]) else 7213L
per_pulse <- if (length(args) > 3L) as.integer(args[[4L]]) else 500L
reps <- if (length(args) > 4L) as.integer(args[[5L]]) else 2L
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")

in_place <- ns$ledgr_columnar_diagnostic_writer
src <- deparse(in_place, width.cutoff = 500L)
line <- grep("collapse::setv(get(nm, envir = cols), dest, value, vind1 = TRUE)", src, fixed = TRUE)
stopifnot(length(line) == 1L)
src[[line]] <- paste(
  "col <- get(nm, envir = cols);",
  "if (is.character(col)) { col[dest] <- value; assign(nm, col, envir = cols) }",
  "else collapse::setv(col, dest, value, vind1 = TRUE)"
)
copy_on_write <- eval(parse(text = src))
environment(copy_on_write) <- environment(in_place)

template <- ns$ledgr_availability_diagnostic_columns(per_pulse)
template$run_id[] <- "probe"
template$instrument_id <- sprintf("INST%04d", seq_len(per_pulse))
template$stage[] <- "decision"
template$outcome[] <- "recorded"
template$reason_code[] <- "decision_recorded"
template$mark_source[] <- "current_close"
template$detail_json[] <- "{}"
template$target <- stats::runif(per_pulse)
template$price <- stats::runif(per_pulse) * 100

run_variant <- function(writer_fn, chunk_rows) {
  db <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), db)
  on.exit({ DBI::dbDisconnect(con, shutdown = TRUE); unlink(db) }, add = TRUE)
  DBI::dbCreateTable(con, "diag", as.data.frame(template, stringsAsFactors = FALSE))
  handler <- list(write_run_diagnostics = function(df) DBI::dbAppendTable(con, "diag", df))
  writer <- writer_fn("probe", handler, chunk_rows = chunk_rows)
  t0 <- Sys.time()
  DBI::dbBegin(con)
  for (p in seq_len(pulses)) {
    block <- template
    block$diagnostic_seq <- (p - 1L) * per_pulse + seq_len(per_pulse)
    block$ts_utc <- .POSIXct(rep(1e9 + 86400 * p, per_pulse), tz = "UTC")
    writer$append_block(block)
  }
  handler$write_run_diagnostics(writer$drain())
  DBI::dbCommit(con)
  as.numeric(difftime(Sys.time(), t0, units = "secs"))
}

variants <- list(
  copy_on_write_4096 = list(copy_on_write, 4096L),
  in_place_4096 = list(in_place, 4096L),
  in_place_65536 = list(in_place, 65536L),
  copy_on_write_65536 = list(copy_on_write, 65536L)
)
rows <- list()
for (r in seq_len(reps)) {
  order <- if (r %% 2L == 1L) names(variants) else rev(names(variants))
  for (v in order) {
    s <- run_variant(variants[[v]][[1L]], variants[[v]][[2L]])
    rows[[length(rows) + 1L]] <- data.frame(rep = r, variant = v, seconds = round(s, 2))
    cat(sprintf("rep %d %-22s %7.2f s\n", r, v, s))
  }
}
out <- do.call(rbind, rows)
utils::write.csv(out, out_csv, row.names = FALSE)
print(stats::aggregate(seconds ~ variant, out, stats::median))
