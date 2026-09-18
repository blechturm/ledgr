# v0.2.0.1 availability timestamp prerequisite.
#
# Question:
#   Can observation-time normalization and primitive session-close comparison
#   preserve the complete availability-validation result, while the latter
#   reaches the preregistered 0.20 same-session ratio?
#
# This probe changes no package source. Candidate functions are installed in
# the loaded namespace only around explicit comparison calls and are restored
# on exit.

script_path <- local({
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg) != 1L) stop("Run with Rscript.")
  normalizePath(sub("^--file=", "", arg), winslash = "/")
})
probe_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(probe_dir, "..", "..", ".."),
                           winslash = "/")
user_lib <- "C:/Users/maxth/Documents/R/win-library/4.6"
collapse_lib <- Sys.getenv(
  "LEDGR_PROBE_LIB",
  unset = "C:/tmp/ledgr-collapse-218-lib"
)
probe_libs <- c(collapse_lib, user_lib)
probe_libs <- probe_libs[dir.exists(probe_libs)]
if (length(probe_libs) > 0L) {
  .libPaths(c(normalizePath(probe_libs, winslash = "/"), .libPaths()))
}
options(keep.source = TRUE, keep.source.pkgs = TRUE, warn = 1)
pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)

writer_runner <- file.path(
  repo_root,
  "dev/spikes/availability-hot-path-representation/spike_runner.R"
)
fixture_env <- new.env(parent = globalenv())
for (expr in parse(writer_runner)) {
  if (is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
      is.name(expr[[2L]]) &&
      as.character(expr[[2L]]) %in% c("FIXTURES", "spike_fixture")) {
    eval(expr, fixture_env)
  }
}
fixture <- fixture_env$spike_fixture(fixture_env$FIXTURES$envelope757)

candidate_observation_times <- function(x, facts) {
  session_family <- ledgr:::ledgr_session_family(facts)
  date_labels <- inherits(x, "Date") ||
    (is.character(x) &&
       all(is.na(x) | grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)))
  if (isTRUE(date_labels) && !is.null(session_family)) {
    dates <- suppressWarnings(as.Date(as.character(x), format = "%Y-%m-%d"))
    rows <- session_family$rows
    idx <- match(as.character(dates), as.character(rows$session_date))
    out <- as.POSIXct(
      rep(NA_real_, length(dates)),
      origin = "1970-01-01",
      tz = "UTC"
    )
    mapped <- !is.na(idx) & rows$status[idx] == "open"
    out[mapped] <- rows$session_close[idx[mapped]]
    return(out)
  }

  distinct <- unique(x)
  parsed <- as.POSIXct(
    rep(NA_real_, length(distinct)),
    origin = "1970-01-01",
    tz = "UTC"
  )
  for (i in seq_along(distinct)) {
    parsed[[i]] <- tryCatch(
      ledgr:::ledgr_fact_time(
        distinct[i],
        "ts_utc",
        allow_missing = TRUE
      )[[1L]],
      error = function(e) as.POSIXct(
        NA_real_,
        origin = "1970-01-01",
        tz = "UTC"
      )
    )
  }
  parsed[match(x, distinct)]
}

candidate_session_closes <- function(ts, facts) {
  rows <- ledgr:::ledgr_session_open_rows(facts)
  if (is.null(rows)) return(rep(TRUE, length(ts)))
  observed_second <- floor(as.numeric(as.POSIXct(ts, tz = "UTC")))
  close_second <- floor(as.numeric(as.POSIXct(
    rows$session_close,
    tz = "UTC"
  )))
  observed_second %in% close_second
}

with_namespace_bindings <- function(replacements, fn) {
  ns <- asNamespace("ledgr")
  old <- lapply(names(replacements), get, envir = ns, inherits = FALSE)
  names(old) <- names(replacements)
  locked <- vapply(
    names(replacements),
    bindingIsLocked,
    logical(1),
    env = ns
  )
  restore <- function() {
    for (name in names(old)) {
      if (bindingIsLocked(name, ns)) unlockBinding(name, ns)
      assign(name, old[[name]], envir = ns)
      if (locked[[name]]) lockBinding(name, ns)
    }
  }
  on.exit(restore(), add = TRUE)
  for (name in names(replacements)) {
    if (bindingIsLocked(name, ns)) unlockBinding(name, ns)
    assign(name, replacements[[name]], envir = ns)
    if (locked[[name]]) lockBinding(name, ns)
  }
  fn()
}

same_or_error <- function(current_fn, candidate_fn) {
  capture <- function(fn) {
    tryCatch(
      list(value = fn(), error = NULL),
      error = function(e) list(
        value = NULL,
        error = list(
          class = class(e),
          message = conditionMessage(e)
        )
      )
    )
  }
  identical(capture(current_fn), capture(candidate_fn))
}

simple_sessions <- function() {
  dates <- as.Date("2024-01-01") + 0:7
  open <- as.POSIXlt(dates)$wday %in% 1:5
  ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(
      data.frame(
        session_date = dates,
        status = ifelse(open, "open", "closed"),
        session_open = ifelse(open, "09:30:00", NA_character_),
        session_close = ifelse(open, "16:00:00", NA_character_),
        knowledge_time = as.POSIXct("2023-12-01", tz = "UTC"),
        stringsAsFactors = FALSE
      ),
      venue_id = "XNYS",
      timezone = "America/New_York"
    )
  )
}

facts_small <- simple_sessions()
facts_none <- ledgr::ledgr_facts(
  ledgr::ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA",
    effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
    status = "active",
    source = "probe"
  ))
)

observation_cases <- list(
  posix_mixed = list(
    x = structure(
      c(
        as.numeric(as.POSIXct("2024-01-02 21:00:00", tz = "UTC")),
        NA_real_,
        as.numeric(as.POSIXct("2024-01-03 21:00:00", tz = "UTC")) + 0.5
      ),
      class = c("POSIXct", "POSIXt"),
      tzone = "UTC"
    ),
    facts = facts_small
  ),
  character_mixed = list(
    x = c(
      "2024-01-02T21:00:00Z",
      "2024-01-03T21:00:00",
      "2024-01-04 21:00:00",
      "2024-01-05",
      "",
      "not-a-time",
      NA_character_
    ),
    facts = facts_small
  ),
  date_with_sessions = list(
    x = as.Date(c("2024-01-02", "2024-01-06", NA)),
    facts = facts_small
  ),
  date_without_sessions = list(
    x = as.Date(c("2024-01-02", NA)),
    facts = facts_none
  ),
  equivalent_timezones = list(
    x = as.POSIXct(
      c("2024-01-02 16:00:00", "2024-01-03 16:00:00"),
      tz = "America/New_York"
    ),
    facts = facts_small
  )
)

session_cases <- list(
  registered = list(ts = fixture$bars$ts_utc, facts = fixture$facts),
  boundary = list(
    ts = structure(
      c(
        as.numeric(as.POSIXct("2024-01-02 21:00:00", tz = "UTC")),
        as.numeric(as.POSIXct("2024-01-02 21:00:00", tz = "UTC")) + 0.5,
        as.numeric(as.POSIXct("2024-01-02 21:00:01", tz = "UTC")),
        NA_real_
      ),
      class = c("POSIXct", "POSIXt"),
      tzone = "UTC"
    ),
    facts = facts_small
  ),
  unsorted_duplicates = list(
    ts = as.POSIXct(
      c(
        "2024-01-04 21:00:00",
        "2024-01-02 21:00:00",
        "2024-01-02 21:00:00",
        "2024-01-07 21:00:00"
      ),
      tz = "UTC"
    ),
    facts = facts_small
  ),
  no_sessions = list(
    ts = as.POSIXct(c("2024-01-02", NA), tz = "UTC"),
    facts = facts_none
  )
)

case_rows <- list()
for (name in names(observation_cases)) {
  case <- observation_cases[[name]]
  exact <- same_or_error(
    function() ledgr:::ledgr_availability_observation_times(
      case$x,
      case$facts
    ),
    function() candidate_observation_times(case$x, case$facts)
  )
  case_rows[[length(case_rows) + 1L]] <- data.frame(
    case = name,
    surface = "observation_times",
    exact = exact,
    stringsAsFactors = FALSE
  )
}
for (name in names(session_cases)) {
  case <- session_cases[[name]]
  exact <- same_or_error(
    function() ledgr:::ledgr_availability_times_are_session_closes(
      case$ts,
      case$facts
    ),
    function() candidate_session_closes(case$ts, case$facts)
  )
  case_rows[[length(case_rows) + 1L]] <- data.frame(
    case = name,
    surface = "session_closes",
    exact = exact,
    stringsAsFactors = FALSE
  )
}

current_full <- ledgr:::ledgr_availability_validate_inputs(
  fixture$facts,
  fixture$bars,
  fixture$instruments,
  "quarantine"
)
candidate_full <- with_namespace_bindings(
  list(
    ledgr_availability_observation_times = candidate_observation_times,
    ledgr_availability_times_are_session_closes = candidate_session_closes
  ),
  function() ledgr:::ledgr_availability_validate_inputs(
    fixture$facts,
    fixture$bars,
    fixture$instruments,
    "quarantine"
  )
)
case_rows[[length(case_rows) + 1L]] <- data.frame(
  case = "registered_complete_result",
  surface = "validate_inputs",
  exact = identical(current_full, candidate_full),
  stringsAsFactors = FALSE
)
cases <- do.call(rbind, case_rows)

elapsed <- function(fn) {
  invisible(gc(full = TRUE))
  t0 <- proc.time()[["elapsed"]]
  value <- fn()
  list(seconds = proc.time()[["elapsed"]] - t0, value = value)
}

current_observation <- function() {
  ledgr:::ledgr_availability_observation_times(
    fixture$bars$ts_utc,
    fixture$facts
  )
}
candidate_observation <- function() {
  candidate_observation_times(fixture$bars$ts_utc, fixture$facts)
}
current_session <- function() {
  ledgr:::ledgr_availability_times_are_session_closes(
    fixture$bars$ts_utc,
    fixture$facts
  )
}
candidate_session <- function() {
  candidate_session_closes(fixture$bars$ts_utc, fixture$facts)
}

invisible(current_observation())
invisible(candidate_observation())
invisible(current_session())
invisible(candidate_session())

measurements <- list()
operations <- list(
  observation_times = list(
    current = current_observation,
    candidate = candidate_observation
  ),
  session_closes = list(
    current = current_session,
    candidate = candidate_session
  )
)
for (rep in seq_len(3L)) {
  arm_order <- if (rep %% 2L == 1L) {
    c("current", "candidate")
  } else {
    c("candidate", "current")
  }
  for (operation in names(operations)) {
    for (arm in arm_order) {
      result <- elapsed(operations[[operation]][[arm]])
      measurements[[length(measurements) + 1L]] <- data.frame(
        operation = operation,
        arm = arm,
        repetition = rep,
        seconds = result$seconds,
        stringsAsFactors = FALSE
      )
    }
  }
}
measurements <- do.call(rbind, measurements)

median_for <- function(operation, arm) {
  stats::median(measurements$seconds[
    measurements$operation == operation & measurements$arm == arm
  ])
}
observation_exact <- all(cases$exact[cases$surface %in% c(
  "observation_times",
  "validate_inputs"
)])
session_exact <- all(cases$exact[cases$surface %in% c(
  "session_closes",
  "validate_inputs"
)])
session_ratio <- median_for("session_closes", "candidate") /
  median_for("session_closes", "current")
outcome <- if (session_exact && session_ratio <= 0.20) {
  if (observation_exact) "COMBINED_EXACT" else "SESSION_CLOSE_ONLY"
} else {
  "NEITHER"
}

utils::write.csv(
  cases,
  file.path(probe_dir, "cases.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  measurements,
  file.path(probe_dir, "measurements.csv"),
  row.names = FALSE,
  na = ""
)

cat("PROBE_ENVIRONMENT\n")
cat("R=", R.version.string, "\n", sep = "")
cat("ledgr=", as.character(utils::packageVersion("ledgr")), "\n", sep = "")
cat("duckdb=", as.character(utils::packageVersion("duckdb")), "\n", sep = "")
cat("collapse=", as.character(utils::packageVersion("collapse")), "\n", sep = "")
cat("fixture_rows=", nrow(fixture$bars), "\n", sep = "")
cat("fixture_instruments=", nrow(fixture$instruments), "\n", sep = "")
cat("fixture_sessions=", length(fixture$session_dates), "\n", sep = "")
cat("semantic_cases=", nrow(cases), "\n", sep = "")
cat("semantic_exact=", all(cases$exact), "\n", sep = "")
cat(
  "observation_current_median=",
  sprintf("%.6f", median_for("observation_times", "current")),
  "\n",
  sep = ""
)
cat(
  "observation_candidate_median=",
  sprintf("%.6f", median_for("observation_times", "candidate")),
  "\n",
  sep = ""
)
cat(
  "session_current_median=",
  sprintf("%.6f", median_for("session_closes", "current")),
  "\n",
  sep = ""
)
cat(
  "session_candidate_median=",
  sprintf("%.6f", median_for("session_closes", "candidate")),
  "\n",
  sep = ""
)
cat("session_ratio=", sprintf("%.6f", session_ratio), "\n", sep = "")
cat("PREREQUISITE_OUTCOME=", outcome, "\n", sep = "")

if (!identical(outcome, "COMBINED_EXACT")) quit(status = 2L)
