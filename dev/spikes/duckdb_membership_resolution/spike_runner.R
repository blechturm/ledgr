args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) >= 1L) normalizePath(args[[1L]], winslash = "/") else "."
out_dir <- if (length(args) >= 2L) args[[2L]] else file.path(tempdir(), "duckdb-membership")
gut <- any(args[-seq_len(min(2L, length(args)))] == "--gut")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

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

membership_family <- function(set_row_count) {
  rows_per_set <- 500L
  set_count <- as.integer(set_row_count / rows_per_set)
  set_number <- rep(seq_len(set_count), each = rows_per_set)
  fixed <- sprintf("I%04d", seq_len(499L))
  rotating <- sprintf("I%04d", 500L + ((seq_len(set_count) - 1L) %% 101L))
  instrument_id <- unlist(
    Map(function(extra) c(fixed, extra), rotating),
    use.names = FALSE
  )
  effective <- as.POSIXct("2000-01-01", tz = "UTC") +
    86400 * (set_number - 1L)
  rows <- data.frame(
    fact_id = sprintf("fact_%07d", seq_len(set_row_count)),
    instrument_id = instrument_id,
    universe_id = "research",
    set_id = sprintf("set_%04d", set_number),
    effective_from = effective,
    effective_to = as.POSIXct(
      rep(NA_real_, set_row_count),
      origin = "1970-01-01",
      tz = "UTC"
    ),
    knowledge_time = effective - 86400,
    member = TRUE,
    provenance_json = "{}",
    source = "duckdb-spike",
    stringsAsFactors = FALSE
  )
  interval_rows <- data.frame(
    fact_id = c("fact_interval_false", "fact_interval_true"),
    instrument_id = c("I0002", "I0595"),
    universe_id = "research",
    set_id = NA_character_,
    effective_from = as.POSIXct(
      c("2000-01-10", "2000-01-11"),
      tz = "UTC"
    ),
    effective_to = as.POSIXct(
      c(NA_real_, NA_real_),
      origin = "1970-01-01",
      tz = "UTC"
    ),
    knowledge_time = as.POSIXct(
      c("2000-01-09", "2000-01-10"),
      tz = "UTC"
    ),
    member = c(TRUE, TRUE),
    provenance_json = "{}",
    source = "duckdb-spike",
    stringsAsFactors = FALSE
  )
  rows <- rbind(rows, interval_rows)
  set_id <- sprintf("set_%04d", seq_len(set_count))
  header_effective <- as.POSIXct("2000-01-01", tz = "UTC") +
    86400 * (seq_len(set_count) - 1L)
  headers <- data.frame(
    universe_id = "research",
    set_id = set_id,
    effective_from = header_effective,
    knowledge_time = header_effective - 86400,
    complete = seq_len(set_count) %% 100L == 1L,
    provenance_json = "{}",
    source = "duckdb-spike",
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

make_snapshot_from_family <- function(family, instruments) {
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
  path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = instrument_rows,
    db_path = path,
    facts = ledgr_facts(family)
  )
  attr(snapshot, "spike_path") <- path
  snapshot
}

make_snapshot <- function(set_row_count) {
  make_snapshot_from_family(
    membership_family(set_row_count),
    sprintf("I%04d", seq_len(600L))
  )
}

tied_membership_family <- function() {
  event_time <- as.POSIXct("2000-01-01", tz = "UTC")
  rows <- data.frame(
    fact_id = c("tie_a", "tie_b"),
    instrument_id = c("A", "B"),
    universe_id = "research",
    set_id = c("set_a", "Set_B"),
    effective_from = event_time,
    effective_to = as.POSIXct(
      c(NA_real_, NA_real_), origin = "1970-01-01", tz = "UTC"
    ),
    knowledge_time = event_time,
    member = TRUE,
    provenance_json = "{}",
    source = "duckdb-spike",
    stringsAsFactors = FALSE
  )
  headers <- data.frame(
    universe_id = "research",
    set_id = c("set_a", "Set_B"),
    effective_from = event_time,
    knowledge_time = event_time,
    complete = TRUE,
    provenance_json = "{}",
    source = "duckdb-spike",
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
  if (nrow(headers) > 0L) {
    headers <- headers[
      order(
        headers$effective_from,
        headers$knowledge_time,
        headers$set_id
      ),
      ,
      drop = FALSE
    ]
  }
  complete <- which(headers$complete)
  first <- 1L
  if (length(complete) > 0L) {
    first <- complete[[length(complete)]] + if (gut) 1L else 0L
  }
  selected_headers <- if (nrow(headers) == 0L || first > nrow(headers)) {
    headers[FALSE, , drop = FALSE]
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
  list(
    headers = selected_headers,
    rows = rbind(set_rows, intervals),
    set_rows_read = nrow(set_rows)
  )
}

resolve_sql <- function(snapshot, cutoff, instruments) {
  con <- ns$get_connection(snapshot)
  info <- ledgr_snapshot_info(snapshot)
  if (!identical(info$status[[1L]], "SEALED")) {
    rlang::abort(
      "Facts inspection requires a SEALED snapshot.",
      class = c("ledgr_facts_snapshot_not_sealed", "LEDGR_SNAPSHOT_NOT_SEALED")
    )
  }
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
    evidence = evidence,
    set_rows_read = sliced$set_rows_read
  )
}

frame_digest <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  rownames(x) <- NULL
  digest::digest(ns$ledgr_fact_frame_payload_json(x), algo = "sha256")
}

sizes <- c(6000L, 30000L, 300000L)
modes <- c("explicit", "full")
requested <- c("I0001", "I0500", "I0594", "UNKNOWN")
cutoff <- as.POSIXct("2002-01-01", tz = "UTC")
timings <- list()
cases <- list()

for (size in sizes) {
  snapshot <- make_snapshot(size)
  for (mode in modes) {
    instruments <- if (identical(mode, "explicit")) requested else NULL
    baseline_value <- NULL
    candidate_value <- NULL
    for (replicate in seq_len(3L)) {
      arms <- if (replicate %% 2L) {
        c("current", "duckdb")
      } else {
        c("duckdb", "current")
      }
      for (arm in arms) {
        measured <- if (identical(arm, "current")) {
          clock(ledgr_facts_resolve(
            snapshot,
            "membership",
            "research",
            cutoff,
            instruments
          ))
        } else {
          clock(resolve_sql(snapshot, cutoff, instruments))
        }
        timings[[length(timings) + 1L]] <- data.frame(
          rows = size,
          mode = mode,
          replicate = replicate,
          arm = arm,
          seconds = measured$seconds,
          stringsAsFactors = FALSE
        )
        if (identical(arm, "current")) {
          baseline_value <- measured$value
        } else {
          candidate_value <- measured$value
        }
      }
    }
    baseline_rows <- as.data.frame(baseline_value$rows)
    candidate_rows <- as.data.frame(candidate_value$rows)
    baseline_evidence <- as.data.frame(baseline_value$evidence)
    candidate_evidence <- as.data.frame(candidate_value$evidence)
    rownames(baseline_rows) <- NULL
    rownames(candidate_rows) <- NULL
    rownames(baseline_evidence) <- NULL
    rownames(candidate_evidence) <- NULL
    cases[[length(cases) + 1L]] <- data.frame(
      rows = size,
      mode = mode,
      current_rows_hash = frame_digest(baseline_rows),
      duckdb_rows_hash = frame_digest(candidate_rows),
      current_evidence_hash = frame_digest(baseline_evidence),
      duckdb_evidence_hash = frame_digest(candidate_evidence),
      exact = identical(baseline_rows, candidate_rows) &&
        identical(baseline_evidence, candidate_evidence),
      set_rows_read = candidate_value$set_rows_read,
      transfer_fraction = candidate_value$set_rows_read / size,
      stringsAsFactors = FALSE
    )
  }
  path <- attr(snapshot, "spike_path")
  ledgr_snapshot_close(snapshot)
  unlink(path)
}

tie_snapshot <- make_snapshot_from_family(tied_membership_family(), c("A", "B"))
for (mode in modes) {
  instruments <- if (identical(mode, "explicit")) c("A", "B") else NULL
  baseline_value <- ledgr_facts_resolve(
    tie_snapshot,
    "membership",
    "research",
    cutoff,
    instruments
  )
  candidate_value <- resolve_sql(tie_snapshot, cutoff, instruments)
  baseline_rows <- as.data.frame(baseline_value$rows)
  candidate_rows <- as.data.frame(candidate_value$rows)
  baseline_evidence <- as.data.frame(baseline_value$evidence)
  candidate_evidence <- as.data.frame(candidate_value$evidence)
  rownames(baseline_rows) <- NULL
  rownames(candidate_rows) <- NULL
  rownames(baseline_evidence) <- NULL
  rownames(candidate_evidence) <- NULL
  cases[[length(cases) + 1L]] <- data.frame(
    rows = 2L,
    mode = paste0("tied_", mode),
    current_rows_hash = frame_digest(baseline_rows),
    duckdb_rows_hash = frame_digest(candidate_rows),
    current_evidence_hash = frame_digest(baseline_evidence),
    duckdb_evidence_hash = frame_digest(candidate_evidence),
    exact = identical(baseline_rows, candidate_rows) &&
      identical(baseline_evidence, candidate_evidence),
    set_rows_read = candidate_value$set_rows_read,
    transfer_fraction = candidate_value$set_rows_read / 2,
    stringsAsFactors = FALSE
  )
}
tie_path <- attr(tie_snapshot, "spike_path")
ledgr_snapshot_close(tie_snapshot)
unlink(tie_path)

timing_rows <- do.call(rbind, timings)
case_rows <- do.call(rbind, cases)
utils::write.csv(case_rows, file.path(out_dir, "cases.csv"), row.names = FALSE)
utils::write.csv(timing_rows, file.path(out_dir, "timings.csv"), row.names = FALSE)

medians <- stats::aggregate(
  seconds ~ rows + mode + arm,
  timing_rows,
  stats::median
)
large <- medians[medians$rows == 300000L, , drop = FALSE]
speedups <- vapply(modes, function(mode) {
  selected <- large[large$mode == mode, , drop = FALSE]
  selected$seconds[selected$arm == "current"] /
    selected$seconds[selected$arm == "duckdb"]
}, numeric(1))
large_cases <- case_rows[case_rows$rows == 300000L, , drop = FALSE]
passed <- !gut && all(case_rows$exact) && min(speedups) >= 1.5 &&
  max(large_cases$transfer_fraction) <= 0.2
summary <- data.frame(
  explicit_speedup = speedups[["explicit"]],
  full_speedup = speedups[["full"]],
  max_transfer_fraction = max(large_cases$transfer_fraction),
  gate_passed = passed,
  stringsAsFactors = FALSE
)
utils::write.csv(summary, file.path(out_dir, "summary.csv"), row.names = FALSE)
print(summary, row.names = FALSE)
