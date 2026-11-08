# Lean preparation (LDG-3216, whole-planes amendment 2026-11-08): the pinned
# substrate, fold reader and history reads over whole planes (interface table
# Section 12.3).
#
# Each bar field and `observed` is one instruments x sessions matrix,
# allocated once at full size and filled in place from one bar query per
# chunk of sessions, so no whole-history long bar frame is held. Everything
# after hydration (gap runs, masks, carry planes, barriers, feature series,
# fold-reader packets, history reads) is the pinned code over these matrices.
#
# The pinned substrate constructor runs as a copy whose environment is this
# lean environment (lean_pinned()), so its call to
# ledgr_history_substrate_bar_matrices() reaches the definition below.
# Nothing is written into the ledgr namespace except by
# lean_prepare_install(), which only harnesses call.

lean_prep <- new.env(parent = emptyenv())
lean_prep$chunk <- NULL  # sessions per bar query; NULL: lean_chunk_width() of the run

# Section 12.3: 4 x max(252, ceiling(126,000 / instruments)) sessions.
lean_chunk_width <- function(n_instruments) {
  4L * max(252L, as.integer(ceiling(126000 / max(1L, n_instruments))))
}

lean_pinned <- function(name) {
  f <- get(name, envir = asNamespace("ledgr"))
  environment(f) <- environment(lean_pinned)
  f
}

# The bar-native axis: the distinct bar times of the universe in range, read
# through the verified handle (the pin derives it from the long bar frame).
# With distinct = FALSE it only refuses, as the pin's bar query does, when no
# bar is in range.
lean_bar_axis <- function(snapshot, universe, start, end, distinct = TRUE) {
  release <- ledgr_snapshot_hold(snapshot)
  on.exit(release(), add = TRUE)
  con <- get_connection(snapshot)
  rows <- DBI::dbGetQuery(con, sprintf(
    "SELECT %s ts_utc FROM snapshot_bars WHERE snapshot_id = ? AND instrument_id IN (%s)
     AND ts_utc >= ? AND ts_utc <= ? %s",
    if (distinct) "DISTINCT" else "", paste(rep("?", length(universe)), collapse = ", "),
    if (distinct) "ORDER BY ts_utc" else "LIMIT 1"),
    params = c(list(snapshot$snapshot_id), as.list(universe), list(start, end)))
  if (nrow(rows) == 0L) {
    rlang::abort("No snapshot bars cover the requested precompute range.", class = "ledgr_precomputed_coverage_error")
  }
  as.POSIXct(rows$ts_utc, tz = "UTC")
}

# Fills the six bar planes in place, one query per chunk of sessions. Chunk
# [c0, c1] queries [its first session, the next chunk's first session), with
# whole-second times, the first chunk from `start` and the last to `end`, so
# every row of the pin's long query is fetched exactly once. A duplicate
# instrument/session bar is flagged and refused where the pin refuses it.
# Trusted inputs: `universe` is the experiment's character universe (the
# planes' rows, and the query's instrument filter), `axis` UTC POSIXct, and
# the fetched frame carries character ids, UTC POSIXct times and double
# fields (the sealed schema), so nothing is converted here.
lean_hydrate <- function(snapshot, universe, start, end, axis) {
  n <- length(universe)
  t <- length(axis)
  chunk <- lean_prep$chunk %||% lean_chunk_width(n)
  fields <- c("open", "high", "low", "close", "volume")
  # One binding per plane: taking a plane out, writing it and putting it back
  # leaves one reference, so each write modifies the matrix in place.
  planes <- new.env(parent = emptyenv())
  for (f in fields) assign(f, matrix(NA_real_, n, t), envir = planes)
  planes$observed <- matrix(FALSE, n, t)
  duplicate <- FALSE
  fetched <- 0L
  for (c0 in if (t > 0L) seq.int(1L, t, by = chunk) else integer()) {
    c1 <- min(t, c0 + chunk - 1L)
    from <- if (c0 == 1L) start else axis[[c0]]
    to <- if (c1 == t) end else axis[[c1 + 1L]] - 1
    rows <- tryCatch(ledgr_precompute_fetch_bars_frame(snapshot, universe, from, to),
                     ledgr_precomputed_coverage_error = function(e) NULL)
    if (is.null(rows)) next
    fetched <- fetched + nrow(rows)
    # The query filters to the universe, so every row has an instrument row;
    # a bar off a declared-session axis has no column and is dropped.
    r <- collapse::fmatch(rows$instrument_id, universe)
    c <- collapse::fmatch(rows$ts_utc, axis[c0:c1])
    keep <- !is.na(c)
    if (!any(keep)) next
    if (.lean_debug && anyNA(r)) stop("lean_hydrate: a fetched bar is outside the universe", call. = FALSE)
    lin <- r[keep] + (c[keep] + c0 - 2L) * n
    if (anyDuplicated(lin)) duplicate <- TRUE
    v <- planes$observed
    planes$observed <- NULL
    if (.lean_debug && any(v[lin])) stop("lean_hydrate: a chunk wrote a cell an earlier chunk wrote", call. = FALSE)
    v[lin] <- TRUE
    planes$observed <- v
    for (f in fields) {
      v <- planes[[f]]
      planes[[f]] <- NULL
      v[lin] <- rows[[f]][keep]
      planes[[f]] <- v
    }
    rm(v)
  }
  structure(list(planes = mget(c(fields, "observed"), envir = planes), duplicate = duplicate, fetched = fetched),
            class = "lean_bars")
}

# The axis and the hydrated bars, in the pin's order: the bar query's
# empty-range refusal first; then, on declared sessions, `declared_axis()`
# (the pinned coverage check and calendar); on the bar-native clock, the
# distinct bar times. The parity runner calls this with the captured
# calendar, so the axis it compares is the one lean builds.
lean_prepare_bars <- function(snapshot, universe, start, end, clock_kind, declared_axis) {
  bar_axis <- lean_bar_axis(snapshot, universe, start, end, identical(clock_kind, "bar_native"))
  axis <- if (identical(clock_kind, "declared_sessions")) declared_axis() else bar_axis
  list(axis = axis, bars = lean_hydrate(snapshot, universe, start, end, axis))
}

# The pinned ledgr_history_substrate_for_experiment (R/history-substrate.R:303)
# with chunked hydration in place of the long bar frame.
lean_history_substrate_for_experiment <- function(exp, meta = NULL, end = NULL, coverage_start = NULL) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("Execution-substrate preparation requires one ledgr experiment.",
                 class = c("ledgr_invalid_history_substrate", "ledgr_invalid_experiment"))
  }
  ledgr_snapshot_ensure_handle(exp$snapshot)
  if (is.null(meta)) meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  if (is.null(end)) end <- meta$end
  if (is.null(coverage_start)) coverage_start <- meta$start
  con <- get_connection(exp$snapshot)
  data <- ledgr_availability_provider_data(con, exp$snapshot$snapshot_id)
  config <- ledgr_execution_provider_config(exp)
  clock_kind <- if (isTRUE(exp$availability$active)) "declared_sessions" else "bar_native"
  prepared <- lean_prepare_bars(exp$snapshot, exp$universe, meta$start, end, clock_kind, function() {
    ledgr_availability_require_coverage(
      list(sessions = data$sessions),
      ledgr_snapshot_bar_range(con, exp$snapshot$snapshot_id, coverage_start, end)
    )
    ledgr_availability_calendar(list(sessions = data$sessions), meta$start, end)$pulses_posix
  })
  axis <- prepared$axis
  if (identical(clock_kind, "bar_native")) data$sessions <- ledgr_bar_native_sessions(axis)
  substrate <- ledgr_history_substrate(
    bars = prepared$bars, instrument_ids = exp$universe, axis = axis, availability_data = data,
    availability_config = config, snapshot_hash = meta$snapshot_hash,
    source_start_utc = meta$start, clock_kind = clock_kind
  )
  ledgr_history_substrate_require_rectangular(substrate, coverage_start = coverage_start)
  substrate
}

# Called by the pinned constructor; the pin's duplicate refusal, at its place.
ledgr_history_substrate_bar_matrices <- function(bars, instrument_ids, axis) {
  if (.lean_debug && !inherits(bars, "lean_bars")) stop("lean preparation takes bars from lean_hydrate()", call. = FALSE)
  if (bars$duplicate) {
    rlang::abort("History preparation found duplicate instrument/session bars.",
                 class = c("ledgr_history_duplicate_bar", "ledgr_invalid_snapshot"))
  }
  bars$planes
}

ledgr_history_substrate <- lean_pinned("ledgr_history_substrate")

# Harness only (end-to-end runs, intraday digests, the timing candidate arm):
# binds lean preparation into the ledgr namespace and returns a function
# that restores the pinned binding. Nothing in R/ calls it.
lean_prepare_install <- function() {
  ns <- asNamespace("ledgr")
  name <- "ledgr_history_substrate_for_experiment"
  pinned <- get(name, envir = ns)
  bind <- function(value) {
    unlockBinding(name, ns)
    assign(name, value, envir = ns)
    lockBinding(name, ns)
  }
  bind(lean_history_substrate_for_experiment)
  function() bind(pinned)
}
