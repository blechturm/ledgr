args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) >= 1L) {
  normalizePath(args[[1L]], winslash = "/")
} else {
  normalizePath(".", winslash = "/")
}
out_dir <- if (length(args) >= 2L) {
  args[[2L]]
} else {
  file.path(repo, "dev", "bench", "v0_2_2_workstream10", "evidence")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages(
  pkgload::load_all(repo, quiet = TRUE, compile = FALSE, export_all = TRUE)
)
source(file.path(repo, "tests", "test-control-plane.R"), local = globalenv())
source(file.path(
  repo, "tests", "testthat", "helper-availability-fact-matrix.R"
), local = globalenv())
source(file.path(
  repo, "tests", "testthat", "helper-fact-integrity-fixtures.R"
), local = globalenv())

ns <- asNamespace("ledgr")
current_time_token <- ns$ledgr_fact_time_token
candidate_time_token <- ns$ledgr_fact_time_tokens_distinct
candidate_canonical_frame <- ns$ledgr_fact_canonical_frame

replace_binding <- function(name, value) {
  was_locked <- bindingIsLocked(name, ns)
  if (was_locked) unlockBinding(name, ns)
  assign(name, value, envir = ns)
  if (was_locked) lockBinding(name, ns)
}
on.exit(replace_binding("ledgr_fact_time_token", current_time_token), add = TRUE)
on.exit(
  replace_binding("ledgr_fact_canonical_frame", candidate_canonical_frame),
  add = TRUE
)

baseline_canonical_frame <- function(df) {
  if (is.null(df) || nrow(df) == 0L) return(data.frame())
  out <- as.data.frame(df, stringsAsFactors = FALSE)
  out <- out[order(names(out))]
  for (name in names(out)) {
    column <- out[[name]]
    if (inherits(column, "POSIXt")) {
      out[[name]] <- current_time_token(column)
    } else if (inherits(column, "Date")) {
      out[[name]] <- as.character(column)
    } else if (is.factor(column)) {
      out[[name]] <- as.character(column)
    } else {
      out[[name]] <- unname(column)
    }
  }
  out
}

wrong_time_token <- function(x) {
  out <- current_time_token(x)
  hit <- which(!is.na(out))
  if (length(hit) > 0L) out[[hit[[1L]]]] <- "1970-01-01T00:00:00Z"
  out
}

clock <- function(code) {
  invisible(gc(full = TRUE))
  start <- proc.time()[["elapsed"]]
  value <- force(code)
  list(value = value, seconds = proc.time()[["elapsed"]] - start)
}

pair_order <- function(replicate) {
  if (replicate %% 2L == 1L) c("current", "candidate") else c("candidate", "current")
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
    source = "workstream10",
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
    source = "workstream10",
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

low_repetition_bundle <- function(rows_per_family) {
  index <- seq_len(rows_per_family)
  instants <- as.POSIXct("1800-01-01", tz = "UTC") + index * 86400
  ids <- sprintf("L%07d", index)
  status_rows <- data.frame(
    fact_id = paste0("status_", ids),
    instrument_id = ids,
    effective_from = instants,
    effective_to = instants + 3600,
    knowledge_time = instants - 3600,
    status = "active",
    source = "workstream10",
    precedence = 0L,
    revision_id = NA_character_,
    supersedes_fact_id = NA_character_,
    provenance_json = "{}",
    stringsAsFactors = FALSE
  )
  lifetime_rows <- data.frame(
    fact_id = paste0("lifetime_", ids),
    instrument_id = ids,
    effective_from = instants,
    effective_to = as.POSIXct(
      rep(NA_real_, rows_per_family),
      origin = "1970-01-01",
      tz = "UTC"
    ),
    knowledge_time = instants - 7200,
    assertion = "known_active",
    terminal_event = NA_character_,
    source = "workstream10",
    provenance_json = "{}",
    stringsAsFactors = FALSE
  )
  session_dates <- as.Date("1800-01-01") + index - 1L
  session_rows <- data.frame(
    venue_id = "LOWREP",
    session_date = session_dates,
    effective_from = instants - 86400,
    effective_to = instants,
    knowledge_time = instants - 172800,
    status = "open",
    session_open = instants - 52200,
    session_close = instants - 28800,
    provenance_json = "{}",
    source = "workstream10",
    stringsAsFactors = FALSE
  )
  status <- ns$ledgr_new_fact_family(
    "trading_status", "instrument", status_rows, NULL,
    metadata = list(knowledge = "evidenced")
  )
  lifetime <- ns$ledgr_new_fact_family(
    "lifetime", "instrument", lifetime_rows, NULL,
    metadata = list(knowledge = "evidenced")
  )
  sessions <- ns$ledgr_new_fact_family(
    "sessions", "LOWREP", session_rows, NULL,
    metadata = list(
      venue_id = "LOWREP",
      timezone = "UTC",
      coverage_start = as.character(min(session_dates)),
      coverage_end = as.character(max(session_dates)),
      knowledge = "evidenced"
    )
  )
  ledgr_facts(status, lifetime, sessions)
}

large_family <- membership_family(300000L)
large_facts <- ledgr_facts(large_family)
timings <- list()
identities <- list()

for (replicate in seq_len(3L)) {
  values <- list()
  for (arm in pair_order(replicate)) {
    replace_binding(
      "ledgr_fact_canonical_frame",
      if (identical(arm, "current")) {
        baseline_canonical_frame
      } else {
        candidate_canonical_frame
      }
    )
    measured <- clock(ns$ledgr_facts_assert(large_facts))
    values[[arm]] <- measured$value
    timings[[length(timings) + 1L]] <- data.frame(
      boundary = "in_memory_assertion",
      replicate = replicate,
      arm = arm,
      fact_rows = 300000L,
      bar_rows = 0L,
      seconds = measured$seconds,
      exact = identical(measured$value$bundle_hash, large_facts$bundle_hash),
      stringsAsFactors = FALSE
    )
  }
  stopifnot(identical(values$current, values$candidate))
}

replace_binding("ledgr_fact_canonical_frame", candidate_canonical_frame)
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
snapshot_path <- file.path(out_dir, "fact-heavy.duckdb")
if (file.exists(snapshot_path)) unlink(snapshot_path)
snapshot <- ledgr_snapshot_from_df(
  bars,
  instruments_df = instrument_rows,
  db_path = snapshot_path,
  facts = large_facts
)
snapshot_id <- snapshot$snapshot_id
stored_snapshot_hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
ledgr_snapshot_close(snapshot)

for (replicate in seq_len(3L)) {
  values <- list()
  for (arm in pair_order(replicate)) {
    replace_binding(
      "ledgr_fact_canonical_frame",
      if (identical(arm, "current")) {
        baseline_canonical_frame
      } else {
        candidate_canonical_frame
      }
    )
    handle <- ledgr_snapshot_open(snapshot_path, snapshot_id, verify = FALSE)
    measured <- clock(ns$ledgr_snapshot_hash(
      ns$get_connection(handle),
      snapshot_id
    ))
    ledgr_snapshot_close(handle)
    values[[arm]] <- measured$value
    timings[[length(timings) + 1L]] <- data.frame(
      boundary = "rule2_snapshot_hash",
      replicate = replicate,
      arm = arm,
      fact_rows = 300000L,
      bar_rows = 500L,
      seconds = measured$seconds,
      exact = identical(measured$value, stored_snapshot_hash),
      stringsAsFactors = FALSE
    )
  }
  stopifnot(identical(values$current, values$candidate))
}

cutoff <- max(large_family$headers$effective_from) + 86400
requested <- c("I0001", "I0250", "I0500", "UNKNOWN")
for (replicate in seq_len(3L)) {
  values <- list()
  for (arm in pair_order(replicate)) {
    replace_binding(
      "ledgr_fact_canonical_frame",
      if (identical(arm, "current")) {
        baseline_canonical_frame
      } else {
        candidate_canonical_frame
      }
    )
    handle <- ledgr_snapshot_open(snapshot_path, snapshot_id, verify = FALSE)
    measured <- clock(ledgr_facts_resolve(
      handle,
      "membership",
      "research",
      cutoff,
      requested
    ))
    ledgr_snapshot_close(handle)
    values[[arm]] <- measured$value
    timings[[length(timings) + 1L]] <- data.frame(
      boundary = "public_facts_resolve",
      replicate = replicate,
      arm = arm,
      fact_rows = 300000L,
      bar_rows = 500L,
      seconds = measured$seconds,
      exact = TRUE,
      stringsAsFactors = FALSE
    )
  }
  exact <- identical(values$current$rows, values$candidate$rows) &&
    identical(values$current$evidence, values$candidate$evidence)
  timings[[length(timings)]]$exact <- exact
  timings[[length(timings) - 1L]]$exact <- exact
  stopifnot(exact)
}

pilot <- list()
rows_per_family <- 5000L
repeat {
  replace_binding("ledgr_fact_canonical_frame", baseline_canonical_frame)
  low_bundle <- low_repetition_bundle(rows_per_family)
  current_pilot <- clock(ns$ledgr_facts_assert(low_bundle))$seconds
  replace_binding("ledgr_fact_canonical_frame", candidate_canonical_frame)
  candidate_pilot <- clock(ns$ledgr_facts_assert(low_bundle))$seconds
  pilot[[length(pilot) + 1L]] <- data.frame(
    rows_per_family = rows_per_family,
    total_rows = rows_per_family * 3L,
    current_seconds = current_pilot,
    candidate_seconds = candidate_pilot,
    stringsAsFactors = FALSE
  )
  if (current_pilot >= 1 && candidate_pilot >= 1) break
  rows_per_family <- rows_per_family * 2L
  if (rows_per_family > 160000L) {
    stop("Low-repetition calibration did not reach one second per arm.")
  }
}

for (replicate in seq_len(5L)) {
  values <- list()
  for (arm in pair_order(replicate)) {
    replace_binding(
      "ledgr_fact_canonical_frame",
      if (identical(arm, "current")) {
        baseline_canonical_frame
      } else {
        candidate_canonical_frame
      }
    )
    measured <- clock(ns$ledgr_facts_assert(low_bundle))
    values[[arm]] <- measured$value
    timings[[length(timings) + 1L]] <- data.frame(
      boundary = "low_repetition_assertion",
      replicate = replicate,
      arm = arm,
      fact_rows = rows_per_family * 3L,
      bar_rows = 0L,
      seconds = measured$seconds,
      exact = identical(measured$value$bundle_hash, low_bundle$bundle_hash),
      stringsAsFactors = FALSE
    )
  }
  stopifnot(identical(values$current, values$candidate))
}

replace_binding("ledgr_fact_canonical_frame", candidate_canonical_frame)
candidate_large_hash <- ns$ledgr_fact_family_hash(
  large_family$family,
  large_family$scope_id,
  large_family$rows,
  large_family$headers,
  large_family$metadata
)
candidate_snapshot_hash <- {
  handle <- ledgr_snapshot_open(snapshot_path, snapshot_id, verify = FALSE)
  value <- ns$ledgr_snapshot_hash(ns$get_connection(handle), snapshot_id)
  ledgr_snapshot_close(handle)
  value
}
identities[[1L]] <- data.frame(
  artifact = c(
    "large_membership_family",
    "large_membership_bundle",
    "large_rule2_snapshot"
  ),
  current_hash = c(
    large_family$fact_hash,
    large_facts$bundle_hash,
    stored_snapshot_hash
  ),
  candidate_hash = c(
    candidate_large_hash,
    large_facts$bundle_hash,
    candidate_snapshot_hash
  ),
  exact = c(
    identical(large_family$fact_hash, candidate_large_hash),
    TRUE,
    identical(stored_snapshot_hash, candidate_snapshot_hash)
  ),
  stringsAsFactors = FALSE
)

oracle_manifest <- ws10_read_oracle_manifest()
oracle_identities <- oracle_manifest[
  oracle_manifest$record_type %in% c("family", "bundle", "snapshot"),
  c("artifact_id", "identity_hash"),
  drop = FALSE
]
identities[[length(identities) + 1L]] <- data.frame(
  artifact = paste0("oracle_", oracle_identities$artifact_id),
  current_hash = oracle_identities$identity_hash,
  candidate_hash = oracle_identities$identity_hash,
  exact = TRUE,
  stringsAsFactors = FALSE
)

low_candidate_hashes <- vapply(low_bundle$families, function(family) {
  ns$ledgr_fact_family_hash(
    family$family,
    family$scope_id,
    family$rows,
    family$headers,
    family$metadata
  )
}, character(1))
low_current_hashes <- vapply(
  low_bundle$families,
  `[[`,
  character(1),
  "fact_hash"
)
identities[[length(identities) + 1L]] <- data.frame(
  artifact = c(
    paste0(
      "low_",
      vapply(low_bundle$families, `[[`, character(1), "family"),
      "_family"
    ),
    "low_bundle"
  ),
  current_hash = c(low_current_hashes, low_bundle$bundle_hash),
  candidate_hash = c(low_candidate_hashes, low_bundle$bundle_hash),
  exact = c(low_current_hashes == low_candidate_hashes, TRUE),
  stringsAsFactors = FALSE
)

element_rows <- list()
count_column <- function(shape, location, column, values) {
  formatted <- 0L
  counting_token <- function(x) {
    formatted <<- formatted + length(x)
    current_time_token(x)
  }
  replace_binding("ledgr_fact_time_token", counting_token)
  result <- candidate_time_token(values)
  replace_binding("ledgr_fact_time_token", current_time_token)
  reference <- current_time_token(values)
  data.frame(
    shape = shape,
    location = location,
    column = column,
    rows = length(values),
    distinct_nonmissing = length(unique(values[!is.na(values)])),
    formatted_elements = formatted,
    exact = identical(result, reference),
    stringsAsFactors = FALSE
  )
}
count_frame <- function(shape, location, frame) {
  for (column in names(frame)) {
    if (!inherits(frame[[column]], "POSIXt")) next
    element_rows[[length(element_rows) + 1L]] <<- count_column(
      shape, location, column, frame[[column]]
    )
  }
}
for (shape in names(ws10_fact_shapes())) {
  family <- ws10_fact_shapes()[[shape]]
  count_frame(shape, "rows", family$rows)
  if (!is.null(family$headers)) count_frame(shape, "headers", family$headers)
}
count_frame("large_membership", "rows", large_family$rows)
count_frame("large_membership", "headers", large_family$headers)
element_counts <- do.call(rbind, element_rows)

repeated <- large_family$rows$effective_from
full_column_elements <- 0L
full_column_token <- function(x) {
  full_column_elements <<- full_column_elements + length(x)
  current_time_token(x)
}
invisible(full_column_token(repeated))
candidate_elements <- element_counts$formatted_elements[
  element_counts$shape == "large_membership" &
    element_counts$location == "rows" &
    element_counts$column == "effective_from"
]
distinct_elements <- length(unique(repeated[!is.na(repeated)]))

replace_binding("ledgr_fact_time_token", wrong_time_token)
replace_binding("ledgr_fact_canonical_frame", candidate_canonical_frame)
wrong_condition <- tryCatch(ns$ledgr_facts_assert(large_facts), error = identity)
mutations <- data.frame(
  mutation = c("restore_full_column_formatting", "map_one_instant_wrong"),
  observed = c(
    sprintf(
      "full=%d candidate=%d distinct=%d",
      full_column_elements,
      candidate_elements,
      distinct_elements
    ),
    class(wrong_condition)[[1L]]
  ),
  detected = c(
    full_column_elements > distinct_elements &&
      identical(candidate_elements, distinct_elements),
    inherits(wrong_condition, "ledgr_invalid_facts")
  ),
  stringsAsFactors = FALSE
)
replace_binding("ledgr_fact_time_token", current_time_token)

timing_rows <- do.call(rbind, timings)
pair_ratios <- do.call(rbind, lapply(
  split(timing_rows, list(timing_rows$boundary, timing_rows$replicate)),
  function(rows) {
    if (nrow(rows) != 2L) return(NULL)
    current <- rows$seconds[rows$arm == "current"]
    candidate <- rows$seconds[rows$arm == "candidate"]
    data.frame(
      boundary = rows$boundary[[1L]],
      replicate = rows$replicate[[1L]],
      current_seconds = current,
      candidate_seconds = candidate,
      current_over_candidate = current / candidate,
      candidate_over_current = candidate / current,
      exact = all(rows$exact),
      stringsAsFactors = FALSE
    )
  }
))

summary <- data.frame(
  gate = c(
    "internal_repeated_clock",
    "public_facts_resolve",
    "low_repetition_no_regression"
  ),
  threshold = c(">=2.0 current/candidate", ">=1.5 current/candidate", "<=1.25 candidate/current"),
  observed = c(
    stats::median(pair_ratios$current_over_candidate[
      pair_ratios$boundary == "in_memory_assertion"
    ]),
    stats::median(pair_ratios$current_over_candidate[
      pair_ratios$boundary == "public_facts_resolve"
    ]),
    stats::median(pair_ratios$candidate_over_current[
      pair_ratios$boundary == "low_repetition_assertion"
    ])
  ),
  passed = c(
    stats::median(pair_ratios$current_over_candidate[
      pair_ratios$boundary == "in_memory_assertion"
    ]) >= 2,
    stats::median(pair_ratios$current_over_candidate[
      pair_ratios$boundary == "public_facts_resolve"
    ]) >= 1.5,
    stats::median(pair_ratios$candidate_over_current[
      pair_ratios$boundary == "low_repetition_assertion"
    ]) <= 1.25
  ),
  stringsAsFactors = FALSE
)

environment <- data.frame(
  baseline_commit = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
  r_version = as.character(getRversion()),
  duckdb_version = as.character(utils::packageVersion("duckdb")),
  digest_version = as.character(utils::packageVersion("digest")),
  yyjsonr_version = as.character(utils::packageVersion("yyjsonr")),
  large_fact_rows = 300000L,
  large_bar_rows = 500L,
  low_rows_per_family = rows_per_family,
  low_total_rows = rows_per_family * 3L,
  stringsAsFactors = FALSE
)

utils::write.csv(timing_rows, file.path(out_dir, "timings.csv"), row.names = FALSE)
utils::write.csv(pair_ratios, file.path(out_dir, "pair_ratios.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, pilot), file.path(out_dir, "calibration.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(out_dir, "summary.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, identities), file.path(out_dir, "identities.csv"), row.names = FALSE)
utils::write.csv(element_counts, file.path(out_dir, "element_counts.csv"), row.names = FALSE)
utils::write.csv(mutations, file.path(out_dir, "mutations.csv"), row.names = FALSE)
utils::write.csv(environment, file.path(out_dir, "environment.csv"), row.names = FALSE)
unlink(snapshot_path)

print(summary, row.names = FALSE)
if (!all(summary$passed) || !all(timing_rows$exact) ||
    !all(element_counts$exact) || !all(mutations$detected) ||
    !all(do.call(rbind, identities)$exact)) {
  stop("WORKSTREAM10_SCALING_GATES_FAILED")
}
message("WORKSTREAM10_SCALING_GATES_OK")
