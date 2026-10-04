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
    source = "integrity-probe",
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
    source = "integrity-probe",
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
distinct_time_token <- function(x) {
  out <- rep(NA_character_, length(x))
  keep <- !is.na(x)
  if (!any(keep)) return(out)
  values <- x[keep]
  distinct <- unique(values)
  tokens <- current_time_token(distinct)
  out[keep] <- tokens[match(values, distinct)]
  out
}

family <- membership_family(30000L)
facts <- ledgr_facts(family)
current <- clock(ns$ledgr_facts_assert(facts))
replace_binding("ledgr_fact_time_token", distinct_time_token)
on.exit(replace_binding("ledgr_fact_time_token", current_time_token), add = TRUE)
candidate <- clock(ns$ledgr_facts_assert(facts))

cat(sprintf("current_seconds=%.6f\n", current$seconds))
cat(sprintf("candidate_seconds=%.6f\n", candidate$seconds))
cat(sprintf(
  "speedup=%.6f\n",
  current$seconds / candidate$seconds
))
cat(sprintf(
  "bundle_identical=%s\n",
  identical(current$value$bundle_hash, candidate$value$bundle_hash)
))
cat(sprintf(
  "family_hash_valid=%s\n",
  identical(
    family$fact_hash,
    ns$ledgr_fact_family_hash(
      family$family,
      family$scope_id,
      family$rows,
      family$headers,
      family$metadata
    )
  )
))
