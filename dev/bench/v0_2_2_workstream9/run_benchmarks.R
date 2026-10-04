args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) >= 1L) args[[1L]] else "."
out_dir <- if (length(args) >= 2L) args[[2L]] else file.path(repo, ".tmp", "ws9")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
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

candidate_session <- ns$ledgr_local_times_resolve
baseline_session <- function(labels, timezone) {
  resolved <- lapply(labels, ns$ledgr_local_time_resolve, timezone = timezone)
  counts <- lengths(resolved)
  values <- as.POSIXct(rep(NA_real_, length(labels)), origin = "1970-01-01", tz = "UTC")
  keep <- counts == 1L
  values[keep] <- as.POSIXct(
    vapply(resolved[keep], `[[`, numeric(1), 1L),
    origin = "1970-01-01",
    tz = "UTC"
  )
  list(values = values, counts = counts)
}

candidate_membership <- ns$ledgr_membership_resolve_at
baseline_membership <- function(data, universe_id, cutoff, instruments = NULL) {
  headers <- data$membership_sets
  headers <- headers[headers$universe_id == universe_id, , drop = FALSE]
  if (nrow(headers) > 0L) {
    eligible <- !is.na(headers$effective_from) & headers$effective_from <= cutoff &
      !is.na(headers$knowledge_time) & headers$knowledge_time <= cutoff
    headers <- headers[eligible, , drop = FALSE]
  }
  state <- logical()
  reason <- character()
  support <- list()
  last_complete <- NULL
  if (nrow(headers) > 0L) {
    headers <- headers[order(headers$effective_from, headers$knowledge_time, headers$set_id), , drop = FALSE]
    rows <- data$membership
    for (i in seq_len(nrow(headers))) {
      set_rows <- rows[
        rows$universe_id == universe_id & rows$set_id == headers$set_id[[i]],
        ,
        drop = FALSE
      ]
      set_ids <- as.character(set_rows$instrument_id)
      header_ref <- paste0("set:", headers$set_id[[i]])
      if (isTRUE(headers$complete[[i]])) {
        if (length(state) > 0L) {
          state[] <- FALSE
          reason[] <- "omitted_from_complete_set"
          support <- stats::setNames(rep(list(header_ref), length(state)), names(state))
        }
        last_complete <- list(header = headers[i, , drop = FALSE], reference = header_ref)
      }
      for (id in set_ids) {
        state[[id]] <- TRUE
        reason[[id]] <- "member_asserted"
        fact_ref <- paste0("fact:", set_rows$fact_id[set_rows$instrument_id == id][[1L]])
        support[[id]] <- c(header_ref, fact_ref)
      }
    }
  }
  rows <- data$membership
  rows <- rows[rows$universe_id == universe_id & is.na(rows$set_id), , drop = FALSE]
  rows <- rows[ns$ledgr_availability_applicable(rows, cutoff), , drop = FALSE]
  if (nrow(rows) > 0L) {
    rows <- rows[order(rows$effective_from, rows$knowledge_time, rows$fact_id), , drop = FALSE]
    for (i in seq_len(nrow(rows))) {
      id <- as.character(rows$instrument_id[[i]])
      state[[id]] <- isTRUE(rows$member[[i]])
      reason[[id]] <- if (state[[id]]) "member_asserted" else "nonmember_asserted"
      support[[id]] <- paste0("fact:", rows$fact_id[[i]])
    }
  }
  members <- ns$ledgr_availability_stable_ids(names(state)[state])
  requested <- if (is.null(instruments)) members else unique(as.character(instruments))
  resolved <- lapply(requested, function(id) {
    if (id %in% names(state)) {
      return(list(
        instrument_id = id,
        member = unname(state[[id]]),
        reason = unname(reason[[id]]),
        evidence_ids = support[[id]] %||% character()
      ))
    }
    if (!is.null(last_complete)) {
      return(list(instrument_id = id, member = FALSE,
        reason = "omitted_from_complete_set", evidence_ids = last_complete$reference))
    }
    list(instrument_id = id, member = NA,
      reason = "unknown_no_usable_evidence", evidence_ids = character())
  })
  resolution_rows <- data.frame(
    instrument_id = vapply(resolved, `[[`, character(1), "instrument_id"),
    member = vapply(resolved, function(x) x$member, logical(1)),
    reason = vapply(resolved, `[[`, character(1), "reason"),
    evidence_ids = vapply(resolved, function(x) paste(x$evidence_ids, collapse = "|"), character(1)),
    stringsAsFactors = FALSE
  )
  list(members = members, rows = resolution_rows,
    applicable_headers = headers, applicable_rows = rows)
}

dates <- seq(as.Date("1998-01-02"), as.Date("2026-09-04"), by = "day")
weekday <- as.POSIXlt(dates)$wday %in% 1:5
sessions <- data.frame(
  session_date = dates,
  status = ifelse(weekday, "open", "closed"),
  session_open = ifelse(weekday, "09:30:00", NA_character_),
  session_close = ifelse(weekday, "16:00:00", NA_character_),
  knowledge_time = as.POSIXct("1997-01-01", tz = "UTC"),
  source = "workstream9",
  stringsAsFactors = FALSE
)
session_rows <- list()
for (timezone in c("UTC", "America/New_York")) {
  values <- list()
  for (replicate in seq_len(3L)) {
    arms <- if (replicate %% 2L) c("baseline", "candidate") else c("candidate", "baseline")
    for (arm in arms) {
      replace_binding("ledgr_local_times_resolve",
        if (arm == "baseline") baseline_session else candidate_session)
      measured <- clock(ledgr_facts_sessions(sessions, "XNYS", timezone = timezone))
      values[[arm]] <- measured$value
      session_rows[[length(session_rows) + 1L]] <- data.frame(
        timezone = timezone, replicate = replicate, arm = arm,
        rows = nrow(sessions), seconds = measured$seconds)
    }
    stopifnot(identical(values$baseline$rows, values$candidate$rows))
    stopifnot(identical(values$baseline$fact_hash, values$candidate$fact_hash))
  }
}
replace_binding("ledgr_local_times_resolve", candidate_session)
session_results <- do.call(rbind, session_rows)
utils::write.csv(session_results, file.path(out_dir, "session_timings.csv"), row.names = FALSE)

membership_family <- function(row_count) {
  rows_per_set <- 500L
  set_count <- as.integer(row_count / rows_per_set)
  set_number <- rep(seq_len(set_count), each = rows_per_set)
  set_id <- sprintf("set_%04d", set_number)
  effective <- as.POSIXct("2000-01-01", tz = "UTC") + 86400 * (set_number - 1L)
  rows <- data.frame(
    fact_id = sprintf("fact_%07d", seq_len(row_count)),
    instrument_id = sprintf("I%04d", rep(seq_len(rows_per_set), times = set_count)),
    universe_id = "research", set_id = set_id, effective_from = effective,
    effective_to = as.POSIXct(rep(NA_real_, row_count), origin = "1970-01-01", tz = "UTC"),
    knowledge_time = effective - 86400, member = TRUE,
    provenance_json = "{}", source = "workstream9", stringsAsFactors = FALSE
  )
  first <- !duplicated(set_id)
  headers <- data.frame(
    universe_id = "research", set_id = set_id[first], effective_from = effective[first],
    knowledge_time = effective[first] - 86400,
    complete = set_number[first] %% 100L == 1L,
    provenance_json = "{}", source = "workstream9", stringsAsFactors = FALSE
  )
  ns$ledgr_new_fact_family("membership", "research", rows, headers,
    metadata = list(shape = "snapshots", universe_id = "research"))
}

membership_rows <- list()
hash_rows <- list()
for (row_count in c(6000L, 30000L, 300000L)) {
  family <- membership_family(row_count)
  hash_clock <- clock(ns$ledgr_facts_assert(ledgr_facts(family)))
  hash_rows[[length(hash_rows) + 1L]] <- data.frame(rows = row_count, seconds = hash_clock$seconds)
  values <- list()
  cutoff <- max(family$headers$effective_from) + 86400
  for (replicate in seq_len(3L)) {
    arms <- if (replicate %% 2L) c("baseline", "candidate") else c("candidate", "baseline")
    for (arm in arms) {
      replace_binding("ledgr_membership_resolve_at",
        if (arm == "baseline") baseline_membership else candidate_membership)
      measured <- clock(ledgr_facts_resolve(
        family, "membership", "research", cutoff,
        c("I0001", "I0250", "I0500", "UNKNOWN")
      ))
      values[[arm]] <- measured$value
      membership_rows[[length(membership_rows) + 1L]] <- data.frame(
        rows = row_count, replicate = replicate, arm = arm,
        seconds = measured$seconds)
    }
    stopifnot(identical(values$baseline$rows, values$candidate$rows))
    stopifnot(identical(values$baseline$evidence, values$candidate$evidence))
  }
}
replace_binding("ledgr_membership_resolve_at", candidate_membership)
membership_results <- do.call(rbind, membership_rows)
utils::write.csv(membership_results, file.path(out_dir, "membership_timings.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, hash_rows),
  file.path(out_dir, "membership_rehash_timings.csv"), row.names = FALSE)

membership_medians <- aggregate(seconds ~ arm + rows, membership_results, stats::median)
candidate_table <- membership_medians[membership_medians$arm == "candidate", ]
candidate_exponent <- coef(stats::lm(log(seconds) ~ log(rows), candidate_table))[[2L]]
session_medians <- aggregate(seconds ~ timezone + arm, session_results, stats::median)
membership_300k <- membership_medians[membership_medians$rows == 300000L, ]
summary <- list(
  session_gate = min(session_medians$seconds[session_medians$arm == "baseline"] /
    session_medians$seconds[session_medians$arm == "candidate"]),
  membership_candidate_exponent = unname(candidate_exponent),
  membership_300k_reduction = 1 -
    membership_300k$seconds[membership_300k$arm == "candidate"] /
      membership_300k$seconds[membership_300k$arm == "baseline"],
  sessions_pass = all(session_medians$seconds[session_medians$arm == "baseline"] /
    session_medians$seconds[session_medians$arm == "candidate"] >= 5),
  membership_pass = candidate_exponent <= 1.15 &&
    1 - membership_300k$seconds[membership_300k$arm == "candidate"] /
      membership_300k$seconds[membership_300k$arm == "baseline"] >= 0.5
)
jsonlite::write_json(summary, file.path(out_dir, "summary.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = 8)
print(session_medians, row.names = FALSE)
print(membership_medians, row.names = FALSE)
print(summary)
