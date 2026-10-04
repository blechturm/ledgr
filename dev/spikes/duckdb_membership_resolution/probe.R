args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) >= 1L) args[[1L]] else "."

suppressPackageStartupMessages(
  pkgload::load_all(repo, quiet = TRUE, compile = FALSE)
)

ns <- asNamespace("ledgr")

clock <- function(code) {
  gc(FALSE)
  start <- proc.time()[["elapsed"]]
  value <- force(code)
  list(value = value, seconds = proc.time()[["elapsed"]] - start)
}

membership_family <- function(row_count) {
  rows_per_set <- 500L
  set_count <- as.integer(row_count / rows_per_set)
  set_number <- rep(seq_len(set_count), each = rows_per_set)
  effective <- as.POSIXct("2000-01-01", tz = "UTC") +
    86400 * (set_number - 1L)
  rows <- data.frame(
    fact_id = sprintf("fact_%07d", seq_len(row_count)),
    instrument_id = sprintf(
      "I%04d",
      rep(seq_len(rows_per_set), times = set_count)
    ),
    universe_id = "research",
    set_id = sprintf("set_%04d", set_number),
    effective_from = effective,
    effective_to = as.POSIXct(
      rep(NA_real_, row_count),
      origin = "1970-01-01",
      tz = "UTC"
    ),
    knowledge_time = effective - 86400,
    member = TRUE,
    provenance_json = "{}",
    source = "duckdb-probe",
    stringsAsFactors = FALSE
  )
  first <- !duplicated(rows$set_id)
  headers <- data.frame(
    universe_id = "research",
    set_id = rows$set_id[first],
    effective_from = effective[first],
    knowledge_time = effective[first] - 86400,
    complete = set_number[first] %% 100L == 1L,
    provenance_json = "{}",
    source = "duckdb-probe",
    stringsAsFactors = FALSE
  )
  ns$ledgr_new_fact_family(
    "membership",
    "research",
    rows,
    headers,
    metadata = list(shape = "snapshots", universe_id = "research")
  )
}

make_snapshot <- function(row_count) {
  instruments <- sprintf("I%04d", seq_len(500L))
  bars <- data.frame(
    instrument_id = instruments,
    ts_utc = as.POSIXct("2002-01-01", tz = "UTC"),
    open = 10,
    high = 10,
    low = 10,
    close = 10,
    volume = 100,
    stringsAsFactors = FALSE
  )
  instrument_rows <- data.frame(
    instrument_id = instruments,
    symbol = instruments,
    currency = "USD",
    asset_class = "equity",
    multiplier = 1,
    tick_size = 0.01,
    stringsAsFactors = FALSE
  )
  ledgr_snapshot_from_df(
    bars,
    instruments_df = instrument_rows,
    facts = ledgr_facts(membership_family(row_count))
  )
}

read_membership_slice <- function(con, snapshot_id, universe_id, cutoff) {
  headers <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT * EXCLUDE (snapshot_id)",
      "FROM snapshot_membership_sets",
      "WHERE snapshot_id = ? AND universe_id = ?",
      "AND effective_from <= ? AND knowledge_time <= ?",
      "ORDER BY effective_from, knowledge_time, set_id"
    ),
    params = list(snapshot_id, universe_id, cutoff, cutoff)
  )
  first <- 1L
  complete <- which(headers$complete)
  if (length(complete) > 0L) first <- complete[[length(complete)]]
  selected_headers <- if (nrow(headers) == 0L) {
    headers
  } else {
    headers[seq.int(first, nrow(headers)), , drop = FALSE]
  }
  if (nrow(selected_headers) > 0L) {
    placeholders <- paste(rep("?", nrow(selected_headers)), collapse = ",")
    set_rows <- DBI::dbGetQuery(
      con,
      sprintf(
        paste(
          "SELECT * EXCLUDE (snapshot_id)",
          "FROM snapshot_membership",
          "WHERE snapshot_id = ? AND universe_id = ?",
          "AND set_id IN (%s)",
          "ORDER BY effective_from, knowledge_time, fact_id"
        ),
        placeholders
      ),
      params = c(
        list(snapshot_id, universe_id),
        as.list(selected_headers$set_id)
      )
    )
  } else {
    set_rows <- ns$ledgr_empty_membership_rows()
  }
  intervals <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT * EXCLUDE (snapshot_id)",
      "FROM snapshot_membership",
      "WHERE snapshot_id = ? AND universe_id = ? AND set_id IS NULL",
      "AND effective_from <= ? AND knowledge_time <= ?",
      "AND (effective_to IS NULL OR ? < effective_to)",
      "ORDER BY effective_from, knowledge_time, fact_id"
    ),
    params = list(snapshot_id, universe_id, cutoff, cutoff, cutoff)
  )
  list(headers = selected_headers, rows = rbind(set_rows, intervals))
}

resolve_sql <- function(snapshot, cutoff, instruments) {
  con <- ns$get_connection(snapshot)
  info <- ledgr_snapshot_info(snapshot)
  computed <- ns$ledgr_snapshot_hash(con, snapshot$snapshot_id)
  stopifnot(identical(info$snapshot_hash[[1L]], computed))
  sliced <- read_membership_slice(
    con,
    snapshot$snapshot_id,
    "research",
    cutoff
  )
  data <- list(
    membership_sets = sliced$headers,
    membership = sliced$rows
  )
  resolved <- ns$ledgr_membership_resolve_at(
    data,
    "research",
    cutoff,
    instruments
  )
  all_evidence <- ns$ledgr_membership_evidence(data, "research")
  evidence_ids <- unique(unlist(strsplit(
    resolved$rows$evidence_ids[nzchar(resolved$rows$evidence_ids)],
    "\\|"
  )))
  evidence <- all_evidence[
    all_evidence$evidence_id %in% evidence_ids,
    ,
    drop = FALSE
  ]
  rownames(evidence) <- NULL
  list(
    rows = resolved$rows,
    evidence = evidence
  )
}

snapshot <- make_snapshot(300000L)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
cutoff <- as.POSIXct("2002-01-01", tz = "UTC")
instruments <- c("I0001", "I0250", "I0500", "UNKNOWN")

baseline <- clock(ledgr_facts_resolve(
  snapshot,
  "membership",
  "research",
  cutoff,
  instruments
))
candidate <- clock(resolve_sql(snapshot, cutoff, instruments))

cat(sprintf("baseline_seconds=%.6f\n", baseline$seconds))
cat(sprintf("candidate_seconds=%.6f\n", candidate$seconds))
cat(sprintf("speedup=%.6f\n", baseline$seconds / candidate$seconds))
cat(sprintf(
  "rows_identical=%s\n",
  identical(as.data.frame(baseline$value$rows), as.data.frame(candidate$value$rows))
))
cat(sprintf(
  "evidence_identical=%s\n",
  identical(
    as.data.frame(baseline$value$evidence),
    as.data.frame(candidate$value$evidence)
  )
))
