args <- commandArgs(trailingOnly = TRUE)

value_arg <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) default else sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
root <- normalizePath(file.path(dirname(script), "..", "..", ".."), winslash = "/")
out_dir <- value_arg(
  "out",
  file.path(root, "inst", "design", "ledgr_v0_2_2_spec_packet",
            "ws6_diagnostic_sequence_evidence")
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

pkgload::load_all(root, quiet = TRUE, compile = FALSE)
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
ledgr_create_schema(con)

run_id <- "diagnostic-sequence-probe"
query <- paste0(
  "SELECT COALESCE(MAX(diagnostic_seq), 0) + 1 AS next_seq ",
  "FROM run_diagnostics WHERE run_id = ?"
)
insert_rows <- function(first, last) {
  if (last < first) return(invisible(TRUE))
  DBI::dbExecute(con, sprintf(
    paste0(
      "INSERT INTO run_diagnostics SELECT '%s', i::INTEGER, ",
      "TIMESTAMP '2024-01-01 00:00:00', 'AAA', 'context', 'passed', ",
      "'probe', '[]', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ",
      "NULL, NULL, NULL, NULL, NULL, '{}' FROM range(%d, %d) AS t(i)"
    ),
    run_id,
    as.integer(first),
    as.integer(last + 1L)
  ))
  invisible(TRUE)
}
clear_rows <- function() {
  DBI::dbExecute(con, "DELETE FROM run_diagnostics")
  invisible(TRUE)
}
query_once <- function() {
  DBI::dbGetQuery(con, query, params = list(run_id))$next_seq[[1L]]
}
query_batch_seconds <- function(repetitions) {
  invisible(gc())
  started <- proc.time()[["elapsed"]]
  for (i in seq_len(repetitions)) query_once()
  (proc.time()[["elapsed"]] - started) / repetitions
}

# Registered before the measurements below: implementation needs both at least
# one percent of the public denominator and cumulative query-work exponent >1.10.
public_denominator_seconds <- 58.381
wall_gate_seconds <- public_denominator_seconds * 0.01
superlinear_exponent_gate <- 1.10

counts <- c(0L, 50000L, 250000L, 750000L)
count_rows <- vector("list", length(counts))
for (count_index in seq_along(counts)) {
  n <- counts[[count_index]]
  clear_rows()
  insert_rows(1L, n)
  query_once()
  clocks <- vapply(seq_len(7L), function(i) query_batch_seconds(100L), numeric(1))
  count_rows[[count_index]] <- data.frame(
    rows = n,
    repetitions_per_clock = 100L,
    clocks = 7L,
    median_query_seconds = stats::median(clocks),
    q25_query_seconds = unname(stats::quantile(clocks, 0.25)),
    q75_query_seconds = unname(stats::quantile(clocks, 0.75)),
    stringsAsFactors = FALSE
  )
}
count_clocks <- do.call(rbind, count_rows)

clear_rows()
chunk_size <- 4096L
total_rows <- 750000L
ends <- unique(pmin(seq.int(chunk_size, total_rows, by = chunk_size), total_rows))
incremental <- vector("list", length(ends))
first <- 1L
for (i in seq_along(ends)) {
  last <- ends[[i]]
  insert_rows(first, last)
  query_once()
  seconds <- query_batch_seconds(10L)
  incremental[[i]] <- data.frame(
    rows = last,
    query_seconds = seconds,
    stringsAsFactors = FALSE
  )
  first <- last + 1L
}
incremental <- do.call(rbind, incremental)
incremental$cumulative_query_seconds <- cumsum(incremental$query_seconds)

positive <- count_clocks$rows > 0L
static_exponent <- unname(stats::coef(stats::lm(
  log(median_query_seconds) ~ log(rows),
  data = count_clocks[positive, , drop = FALSE]
))[[2L]])
fit_rows <- incremental$rows >= 50000L
cumulative_exponent <- unname(stats::coef(stats::lm(
  log(cumulative_query_seconds) ~ log(rows),
  data = incremental[fit_rows, , drop = FALSE]
))[[2L]])
total_query_seconds <- tail(incremental$cumulative_query_seconds, 1L)
summary <- data.frame(
  public_shape = "s1_release_shape: ledgr_run, 500 instruments x 1260 pulses",
  public_denominator_seconds = public_denominator_seconds,
  wall_gate_seconds = wall_gate_seconds,
  measured_query_seconds_750000_rows = total_query_seconds,
  measured_share_of_public_run = total_query_seconds / public_denominator_seconds,
  static_query_exponent = static_exponent,
  cumulative_query_exponent = cumulative_exponent,
  superlinear_exponent_gate = superlinear_exponent_gate,
  wall_gate_passed = total_query_seconds >= wall_gate_seconds,
  superlinear_gate_passed = cumulative_exponent > superlinear_exponent_gate,
  proceed = total_query_seconds >= wall_gate_seconds &&
    cumulative_exponent > superlinear_exponent_gate,
  stringsAsFactors = FALSE
)

utils::write.csv(count_clocks, file.path(out_dir, "query_count_clocks.csv"), row.names = FALSE)
utils::write.csv(incremental, file.path(out_dir, "incremental_query_clocks.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(out_dir, "summary.csv"), row.names = FALSE)
utils::write.csv(data.frame(
  key = c("r_version", "duckdb", "git_head", "chunk_size", "query_repetitions"),
  value = c(
    R.version.string,
    as.character(utils::packageVersion("duckdb")),
    system2("git", c("-C", shQuote(root), "rev-parse", "HEAD"), stdout = TRUE)[[1L]],
    as.character(chunk_size),
    "7 batches x 100 static; 10 per incremental point"
  ),
  stringsAsFactors = FALSE
), file.path(out_dir, "environment.csv"), row.names = FALSE)

print(summary)
