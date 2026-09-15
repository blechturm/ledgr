# Prerequisite probe for a follow-up availability-provider preparation spike.
#
# This is spike_protocol.md section 1 work. It is not a Charter, comparison
# harness, candidate implementation, or semantic acceptance suite. Production
# R/ code is not modified.
#
# One question:
#   On the registered 757-pulse dense/static fixture, how much time does the
#   current provider spend rebuilding an unchanged decision view, and what
#   lower bound is exposed when that view is prepared once as primitive
#   vectors before the pulse loop?
#
# The prepared path is deliberately only a floor. It is valid for this fixture
# because all 60 complete membership lists are identical, all status/lifetime
# facts are constant and knowable before the first pulse, positions stay zero,
# and execution_view() is unreachable. It does not implement late knowledge,
# changing membership, supersession, terminal events, held non-members, or
# arbitrary cutoff order. Those are questions for a reviewed Charter.
#
# Run from the repository root:
#   Rscript dev/spikes/availability-provider-preparation/probe.R
# To select a tested isolated library explicitly, set LEDGR_PROBE_LIB to the
# directory containing collapse before running. The probe prepends that
# directory to .libPaths() and prints the version actually loaded.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 0L) stop("This probe takes no arguments.")

script_path <- local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg) == 0L) stop("Run this probe with Rscript.")
  normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/")
})
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."), winslash = "/")
probe_library <- Sys.getenv("LEDGR_PROBE_LIB", unset = "")
if (nzchar(probe_library)) {
  .libPaths(c(normalizePath(probe_library, winslash = "/"), .libPaths()))
}

SPEC <- list(
  n_instruments = 563L,
  n_members = 505L,
  n_sessions = 757L,
  n_lists = 60L,
  first_session = as.Date("2021-01-04"),
  universe_id = "synthetic_members"
)

fixture <- function(spec) {
  ids <- sprintf("I%03d", seq_len(spec$n_instruments))
  members <- ids[seq_len(spec$n_members)]
  n_civil <- as.integer(ceiling(spec$n_sessions * 7 / 5)) + 7L
  civil <- seq(spec$first_session, by = "day", length.out = n_civil)
  open <- as.POSIXlt(civil)$wday %in% 1:5
  civil <- civil[seq_len(which(cumsum(open) == spec$n_sessions)[[1L]])]
  open <- as.POSIXlt(civil)$wday %in% 1:5
  stopifnot(sum(open) == spec$n_sessions)
  session_dates <- civil[open]
  publish <- as.POSIXct("2021-01-01 00:00:00", tz = "UTC")

  sessions <- data.frame(
    session_date = civil,
    status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "14:30:00", NA_character_),
    session_close = ifelse(open, "21:00:00", NA_character_),
    knowledge_time = publish,
    source = "synthetic_calendar",
    stringsAsFactors = FALSE
  )
  list_index <- 1L + (seq_len(spec$n_lists) - 1L) *
    (spec$n_sessions %/% spec$n_lists)
  list_dates <- session_dates[list_index]
  membership <- data.frame(
    instrument_id = rep(members, times = spec$n_lists),
    effective_from = rep(
      as.POSIXct(paste(list_dates, "00:00:00"), tz = "UTC"),
      each = spec$n_members
    ),
    knowledge_time = rep(
      as.POSIXct(paste(list_dates - 1, "00:00:00"), tz = "UTC"),
      each = spec$n_members
    ),
    source = "synthetic_membership",
    stringsAsFactors = FALSE
  )
  window_start <- as.POSIXct(paste(session_dates[[1L]], "00:00:00"), tz = "UTC")
  status <- data.frame(
    instrument_id = ids,
    effective_from = window_start,
    knowledge_time = publish,
    status = "active",
    source = "synthetic_status",
    stringsAsFactors = FALSE
  )
  lifetime <- data.frame(
    instrument_id = ids,
    effective_from = window_start,
    knowledge_time = publish,
    assertion = "known_active",
    source = "synthetic_lifetime",
    stringsAsFactors = FALSE
  )
  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(sessions, "SYNTH", timezone = "UTC"),
    ledgr::ledgr_facts_membership_snapshots(
      membership,
      spec$universe_id,
      complete = TRUE
    ),
    ledgr::ledgr_facts_trading_status(status),
    ledgr::ledgr_facts_lifetime(lifetime)
  )
  list(
    ids = ids,
    facts = facts,
    cutoffs = as.POSIXct(paste(session_dates, "21:00:00"), tz = "UTC"),
    list_dates = list_dates
  )
}

provider_data <- function(facts) {
  get_family <- function(name) {
    which_name <- vapply(facts$families, `[[`, character(1), "family")
    hit <- which(which_name == name)
    if (length(hit) != 1L) stop("Missing or duplicate fact family: ", name)
    facts$families[[hit]]
  }
  membership <- get_family("membership")
  sessions <- get_family("sessions")
  status <- get_family("trading_status")
  lifetime <- get_family("lifetime")
  list(
    families = data.frame(
      family = c("membership", "sessions", "trading_status", "lifetime"),
      stringsAsFactors = FALSE
    ),
    membership_sets = membership$headers,
    membership = membership$rows,
    status = status$rows,
    lifetime = lifetime$rows,
    sessions = sessions$rows
  )
}

provider_config <- function(ids) {
  list(
    data = list(snapshot_id = "probe"),
    universe = list(instrument_ids = ids),
    availability = list(
      active = TRUE,
      universe_rule = list(universe_id = SPEC$universe_id),
      execution_timing_version = "probe",
      valuation_policy = NULL
    )
  )
}

prepared_floor <- function(seed_view) {
  primitive <- lapply(seed_view, function(value) {
    if (!is.atomic(value)) stop("Prepared floor accepts primitive vectors only.")
    value
  })
  force(primitive)
  function(cutoff, positions) {
    if (any(as.numeric(positions) != 0)) {
      stop("Prepared floor is registered only for zero positions.")
    }
    list(
      axis = primitive$axis,
      members = primitive$members,
      member = primitive$member,
      held = primitive$held,
      target_restricted = primitive$target_restricted,
      target_restriction_reason = primitive$target_restriction_reason,
      target_restriction_reasons = primitive$target_restriction_reasons,
      status = primitive$status,
      lifetime = primitive$lifetime,
      terminal_event = primitive$terminal_event
    )
  }
}

heap_peak_mib <- function(gc_result, kind) {
  as.numeric(gc_result[kind, ncol(gc_result)])
}

measure_floor <- function(fn, cutoffs, positions, repetitions = 5L, cycles = 100L) {
  invisible(fn(cutoffs[[1L]], positions))
  wall <- numeric(repetitions)
  for (run in seq_len(repetitions)) {
    invisible(gc())
    start <- proc.time()[["elapsed"]]
    for (cycle in seq_len(cycles)) {
      for (pulse in seq_along(cutoffs)) invisible(fn(cutoffs[[pulse]], positions))
    }
    wall[[run]] <- (proc.time()[["elapsed"]] - start) / cycles
  }
  wall
}

pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)
fx <- fixture(SPEC)
data <- provider_data(fx$facts)
config <- provider_config(fx$ids)
history_unreachable <- function(...) stop("history() is unreachable in this probe")
provider <- ledgr:::ledgr_availability_provider_build(
  data,
  config,
  snapshot_hash = "probe",
  history = history_unreachable
)
positions <- stats::setNames(numeric(length(fx$ids)), fx$ids)

# Prepare once, before the measured pulse loop. This preparation deliberately
# delegates semantic resolution to the current provider and caches only the
# resulting primitive vectors. It is a lower bound, not a proposed compiler.
prep_start <- proc.time()[["elapsed"]]
seed_view <- provider$decision_view(fx$cutoffs[[1L]], positions)
floor_view <- prepared_floor(seed_view)
preparation_wall <- proc.time()[["elapsed"]] - prep_start

invisible(gc(reset = TRUE))
current_call_wall <- numeric(length(fx$cutoffs))
parity <- logical(length(fx$cutoffs))
outer_start <- proc.time()[["elapsed"]]
for (pulse in seq_along(fx$cutoffs)) {
  call_start <- proc.time()[["elapsed"]]
  current <- provider$decision_view(fx$cutoffs[[pulse]], positions)
  current_call_wall[[pulse]] <- proc.time()[["elapsed"]] - call_start
  parity[[pulse]] <- identical(current, floor_view(fx$cutoffs[[pulse]], positions))
}
current_outer_wall <- proc.time()[["elapsed"]] - outer_start
current_gc <- gc()

floor_wall <- measure_floor(floor_view, fx$cutoffs, positions)
segments <- cut(
  seq_along(fx$cutoffs),
  breaks = c(0L, 40L, 189L, 379L, 757L),
  labels = c("1-40", "41-189", "190-379", "380-757")
)
segment_rows <- do.call(rbind, lapply(levels(segments), function(segment) {
  values <- current_call_wall[segments == segment]
  data.frame(
    pulse_segment = segment,
    pulses = length(values),
    total_seconds = sum(values),
    median_ms_per_pulse = 1000 * stats::median(values),
    stringsAsFactors = FALSE
  )
}))

summary_row <- data.frame(
  pulses = length(fx$cutoffs),
  instruments = length(fx$ids),
  members = length(seed_view$members),
  membership_headers = nrow(data$membership_sets),
  membership_rows = nrow(data$membership),
  status_rows = nrow(data$status),
  lifetime_rows = nrow(data$lifetime),
  preparation_seconds = preparation_wall,
  current_calls_seconds = sum(current_call_wall),
  current_outer_seconds = current_outer_wall,
  prepared_floor_median_seconds = stats::median(floor_wall),
  prepared_floor_min_seconds = min(floor_wall),
  exact_views = sum(parity),
  mismatched_views = sum(!parity),
  current_peak_vcells_mib = heap_peak_mib(current_gc, "Vcells"),
  current_peak_ncells_mib = heap_peak_mib(current_gc, "Ncells"),
  stringsAsFactors = FALSE
)

cat("PROBE_ENVIRONMENT\n")
cat("R=", R.version.string, "\n", sep = "")
cat("collapse=", as.character(utils::packageVersion("collapse")), "\n", sep = "")
cat("duckdb=", as.character(utils::packageVersion("duckdb")), "\n", sep = "")
cat("PROBE_SUMMARY\n")
utils::write.table(summary_row, row.names = FALSE, sep = ",", quote = TRUE)
cat("CURRENT_SEGMENTS\n")
utils::write.table(segment_rows, row.names = FALSE, sep = ",", quote = TRUE)
cat("PREPARED_FLOOR_REPETITIONS_SECONDS\n")
cat(paste(format(floor_wall, digits = 8), collapse = ","), "\n")

stopifnot(
  identical(sum(parity), length(fx$cutoffs)),
  identical(sum(!parity), 0L),
  identical(length(seed_view$axis), SPEC$n_members),
  identical(length(seed_view$members), SPEC$n_members),
  identical(nrow(data$membership_sets), SPEC$n_lists),
  identical(nrow(data$membership), SPEC$n_lists * SPEC$n_members)
)
cat("PROBE_STATUS=PASS\n")
