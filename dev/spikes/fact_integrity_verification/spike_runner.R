args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) >= 1L) normalizePath(args[[1L]], winslash = "/") else "."
out_dir <- if (length(args) >= 2L) args[[2L]] else file.path(tempdir(), "fact-integrity")
gut <- any(args[-seq_len(min(2L, length(args)))] == "--gut")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages(
  pkgload::load_all(repo, quiet = TRUE, compile = FALSE)
)
ns <- asNamespace("ledgr")

clock <- function(code) {
  gc(FALSE)
  start <- proc.time()[["elapsed"]]
  value <- tryCatch(
    list(status = "ok", value = force(code), condition_class = ""),
    error = function(e) list(
      status = "error",
      value = NULL,
      condition_class = class(e)[[1L]]
    )
  )
  value$seconds <- proc.time()[["elapsed"]] - start
  value
}

replace_binding <- function(name, value) {
  was_locked <- bindingIsLocked(name, ns)
  if (was_locked) unlockBinding(name, ns)
  assign(name, value, envir = ns)
  if (was_locked) lockBinding(name, ns)
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
    source = "integrity-spike",
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
    source = "integrity-spike",
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

current_time_token <- ns$ledgr_fact_time_token
candidate_time_token <- function(x) {
  out <- rep(NA_character_, length(x))
  keep <- !is.na(x)
  if (!any(keep)) return(out)
  values <- x[keep]
  distinct <- unique(values)
  tokens <- current_time_token(distinct)
  if (gut && length(tokens) > 0L) {
    tokens[[1L]] <- "1970-01-01T00:00:00Z"
  }
  out[keep] <- tokens[match(values, distinct)]
  out
}

families <- lapply(c(6000L, 30000L, 300000L), membership_family)
names(families) <- vapply(families, function(x) nrow(x$rows), integer(1))

timings <- list()
cases <- list()
for (size in names(families)) {
  family <- families[[size]]
  facts <- ledgr_facts(family)
  baseline_hash <- family$fact_hash
  candidate_hash <- NA_character_
  candidate_status <- ""
  candidate_class <- ""
  for (replicate in seq_len(3L)) {
    arms <- if (replicate %% 2L) {
      c("current", "candidate")
    } else {
      c("candidate", "current")
    }
    for (arm in arms) {
      replace_binding(
        "ledgr_fact_time_token",
        if (identical(arm, "current")) current_time_token else candidate_time_token
      )
      measured <- clock(ns$ledgr_facts_assert(facts))
      timings[[length(timings) + 1L]] <- data.frame(
        boundary = "in_memory_bundle",
        rows = as.integer(size),
        replicate = replicate,
        arm = arm,
        seconds = measured$seconds,
        stringsAsFactors = FALSE
      )
      if (identical(arm, "candidate")) {
        candidate_status <- measured$status
        candidate_class <- measured$condition_class
        if (identical(measured$status, "ok")) {
          candidate_hash <- ns$ledgr_fact_family_hash(
            family$family,
            family$scope_id,
            family$rows,
            family$headers,
            family$metadata
          )
        }
      }
    }
  }
  cases[[length(cases) + 1L]] <- data.frame(
    case = paste0("bundle_", size),
    rows = as.integer(size),
    current_hash = baseline_hash,
    candidate_hash = candidate_hash,
    candidate_status = candidate_status,
    condition_class = candidate_class,
    exact = identical(baseline_hash, candidate_hash),
    stringsAsFactors = FALSE
  )
}

replace_binding("ledgr_fact_time_token", current_time_token)
largest <- families[["300000"]]
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
snapshot_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  bars,
  instruments_df = instrument_rows,
  db_path = snapshot_path,
  facts = ledgr_facts(largest)
)
stored_snapshot_hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
candidate_snapshot_hash <- NA_character_
candidate_snapshot_status <- ""
candidate_snapshot_class <- ""
for (replicate in seq_len(3L)) {
  arms <- if (replicate %% 2L) {
    c("current", "candidate")
  } else {
    c("candidate", "current")
  }
  for (arm in arms) {
    replace_binding(
      "ledgr_fact_time_token",
      if (identical(arm, "current")) current_time_token else candidate_time_token
    )
    measured <- clock(ns$ledgr_snapshot_hash(
      ns$get_connection(snapshot),
      snapshot$snapshot_id
    ))
    timings[[length(timings) + 1L]] <- data.frame(
      boundary = "sealed_snapshot",
      rows = 300000L,
      replicate = replicate,
      arm = arm,
      seconds = measured$seconds,
      stringsAsFactors = FALSE
    )
    if (identical(arm, "candidate")) {
      candidate_snapshot_status <- measured$status
      candidate_snapshot_class <- measured$condition_class
      if (identical(measured$status, "ok")) {
        candidate_snapshot_hash <- measured$value
      }
    }
  }
}
cases[[length(cases) + 1L]] <- data.frame(
  case = "sealed_snapshot_300000",
  rows = 300000L,
  current_hash = stored_snapshot_hash,
  candidate_hash = candidate_snapshot_hash,
  candidate_status = candidate_snapshot_status,
  condition_class = candidate_snapshot_class,
  exact = identical(stored_snapshot_hash, candidate_snapshot_hash),
  stringsAsFactors = FALSE
)
ledgr_snapshot_close(snapshot)
unlink(snapshot_path)

replace_binding("ledgr_fact_time_token", candidate_time_token)
tampered <- ledgr_facts(families[["6000"]])
tampered$families[[1L]]$rows$member[[1L]] <- FALSE
tamper <- clock(ns$ledgr_facts_assert(tampered))
cases[[length(cases) + 1L]] <- data.frame(
  case = "tampered_bundle",
  rows = 6000L,
  current_hash = tampered$families[[1L]]$fact_hash,
  candidate_hash = NA_character_,
  candidate_status = tamper$status,
  condition_class = tamper$condition_class,
  exact = identical(tamper$status, "error") &&
    identical(tamper$condition_class, "ledgr_invalid_facts"),
  stringsAsFactors = FALSE
)
replace_binding("ledgr_fact_time_token", current_time_token)

timing_rows <- do.call(rbind, timings)
case_rows <- do.call(rbind, cases)
utils::write.csv(case_rows, file.path(out_dir, "cases.csv"), row.names = FALSE)
utils::write.csv(timing_rows, file.path(out_dir, "timings.csv"), row.names = FALSE)

bundle_300k <- timing_rows[
  timing_rows$boundary == "in_memory_bundle" & timing_rows$rows == 300000L,
  ,
  drop = FALSE
]
medians <- stats::aggregate(seconds ~ arm, bundle_300k, stats::median)
speedup <- medians$seconds[medians$arm == "current"] /
  medians$seconds[medians$arm == "candidate"]
passed <- !gut && all(case_rows$exact) && is.finite(speedup) && speedup >= 2
summary <- data.frame(
  current_median_seconds = medians$seconds[medians$arm == "current"],
  candidate_median_seconds = medians$seconds[medians$arm == "candidate"],
  speedup = speedup,
  gate_passed = passed,
  stringsAsFactors = FALSE
)
utils::write.csv(summary, file.path(out_dir, "summary.csv"), row.names = FALSE)
print(summary, row.names = FALSE)

