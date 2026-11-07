# Lean preparation (LDG-3216): the pinned substrate, fold reader and history
# reads over tiled planes (interface table Section 12.3).
#
# A lean_plane stands in for one instruments x sessions plane. It stores the
# plane as tiles of `width` sessions; each tile holds only its stored
# instruments (a bar or a non-missing cell in the tile's range), and an
# unstored cell reads as the plane's fill (NA, or FALSE for `observed`).
# `[`, `[<-` and dim() answer in the pinned orientation and in global
# coordinates, so pinned code that indexes planes runs unchanged.
#
# Pinned functions run as copies whose environment is this lean environment
# (lean_pinned()), so the names they call resolve to the lean definitions
# below first: tiled bar planes, merged gap runs, tile-column packets.
# Nothing is written into the ledgr namespace.

lean_prep <- new.env(parent = emptyenv())
lean_prep$width <- NULL     # NULL: the run's width from its instrument count
lean_prep$orient <- "time"  # tile storage: "time" (sessions x instruments) or "inst"

# Section 12.3: max(252, ceiling(126,000 / instruments)) sessions.
lean_tile_width <- function(n_instruments) {
  max(252L, as.integer(ceiling(126000 / max(1L, n_instruments))))
}

lean_pinned <- function(name) {
  f <- get(name, envir = asNamespace("ledgr"))
  environment(f) <- environment(lean_pinned)
  f
}

# ---------------------------------------------------------------------------
# Planes

lean_plane_new <- function(n, t, width, fill, dimnames = NULL) {
  p <- new.env(parent = emptyenv())
  p$n <- as.integer(n)
  p$t <- as.integer(t)
  p$width <- as.integer(width)
  p$fill <- fill
  p$dimnames <- dimnames
  p$orient <- lean_prep$orient
  k <- if (p$t > 0L) (p$t - 1L) %/% p$width + 1L else 0L
  p$tiles <- vector("list", k)   # tile values
  p$stored <- vector("list", k)  # global rows held by each tile, increasing
  p$rows <- vector("list", k)    # global row -> tile row, NA when not stored
  class(p) <- "lean_plane"
  p
}

lean_tile_cols <- function(p, k) ((k - 1L) * p$width + 1L):min(k * p$width, p$t)

# Installs tile k from `values`, rows `stored` x the tile's columns, given in
# the pinned orientation.
lean_plane_set <- function(p, k, stored, values) {
  rows <- rep(NA_integer_, p$n)
  rows[stored] <- seq_along(stored)
  p$stored[[k]] <- stored
  p$rows[[k]] <- rows
  p$tiles[[k]] <- if (p$orient == "time") t(values) else values
  invisible(p)
}

# Tile k as list(v = values in storage orientation, rows, stored), or NULL
# when it holds nothing. Source planes hold every tile. A working plane
# (p$build set) builds tile k on demand: it caches at most three, evicting
# the least recently used; a tile older than every cached one, once three
# are cached, is built into a transient buffer and not cached (Section 12.3).
lean_tile_get <- function(p, k) {
  if (!is.null(p$tiles[[k]])) {
    if (!is.null(p$build)) p$resident <- c(p$resident[p$resident != k], k)
    return(list(v = p$tiles[[k]], rows = p$rows[[k]], stored = p$stored[[k]]))
  }
  if (is.null(p$build)) return(NULL)
  v <- p$build(k)
  p$builds <- p$builds + 1L
  all_rows <- seq_len(p$n)
  if (length(p$resident) >= 3L && k < min(p$resident)) {
    p$transient <- p$transient + 1L
    return(list(v = if (p$orient == "time") t(v) else v, rows = all_rows, stored = all_rows))
  }
  lean_plane_set(p, k, all_rows, v)
  p$resident <- c(p$resident, k)
  while (length(p$resident) > 3L) {
    old <- p$resident[[1L]]
    p$resident <- p$resident[-1L]
    p$tiles[old] <- list(NULL)
    p$rows[old] <- list(NULL)
    p$stored[old] <- list(NULL)
  }
  list(v = p$tiles[[k]], rows = p$rows[[k]], stored = p$stored[[k]])
}

lean_working_plane <- function(n, t, width, fill, build) {
  p <- lean_plane_new(n, t, width, fill)
  p$build <- build
  p$resident <- integer()
  p$builds <- 0L
  p$transient <- 0L
  p
}

lean_plane_gather <- function(p, i, j) {
  out <- matrix(p$fill, length(i), length(j))
  if (!length(i) || !length(j)) return(out)
  tile <- (j - 1L) %/% p$width + 1L
  for (at in split(seq_along(j), tile)) {
    k <- tile[[at[[1L]]]]
    tl <- lean_tile_get(p, k)
    if (is.null(tl)) next
    m <- tl$rows[i]
    ok <- which(!is.na(m))
    if (!length(ok)) next
    lc <- j[at] - (k - 1L) * p$width
    out[ok, at] <- if (p$orient == "time") t(tl$v[lc, m[ok], drop = FALSE]) else tl$v[m[ok], lc, drop = FALSE]
  }
  out
}

lean_plane_points <- function(p, r, c) {
  out <- rep(p$fill, length(r))
  tile <- (c - 1L) %/% p$width + 1L
  for (at in split(seq_along(r), tile)) {
    k <- tile[[at[[1L]]]]
    tl <- lean_tile_get(p, k)
    if (is.null(tl)) next
    m <- tl$rows[r[at]]
    ok <- !is.na(m)
    lc <- c[at][ok] - (k - 1L) * p$width
    out[at[ok]] <- if (p$orient == "time") tl$v[cbind(lc, m[ok])] else tl$v[cbind(m[ok], lc)]
  }
  out
}

# One session column, unnamed (packets: two per pulse).
lean_plane_col <- function(p, c) {
  out <- rep(p$fill, p$n)
  k <- (c - 1L) %/% p$width + 1L
  tl <- lean_tile_get(p, k)
  if (is.null(tl)) return(out)
  lc <- c - (k - 1L) * p$width
  out[tl$stored] <- if (p$orient == "time") tl$v[lc, ] else tl$v[, lc]
  out
}

lean_plane_index <- function(i, n, names) {
  if (is.logical(i)) return(which(rep_len(i, n)))
  if (is.character(i)) return(match(i, names))
  as.integer(i)
}

`[.lean_plane` <- function(x, i, j, ..., drop = TRUE) {
  n_index <- nargs() - !missing(drop)
  if (n_index == 2L) {
    k <- if (is.logical(i)) which(i) else as.integer(i)
    return(lean_plane_points(x, (k - 1L) %% x$n + 1L, (k - 1L) %/% x$n + 1L))
  }
  ii <- if (missing(i)) seq_len(x$n) else lean_plane_index(i, x$n, x$dimnames[[1L]])
  jj <- if (missing(j)) seq_len(x$t) else lean_plane_index(j, x$t, x$dimnames[[2L]])
  out <- lean_plane_gather(x, ii, jj)
  if (!is.null(x$dimnames)) dimnames(out) <- list(x$dimnames[[1L]][ii], x$dimnames[[2L]][jj])
  out[, , drop = drop]
}

# Writes create a tile holding every instrument; lean_plane_compact() later
# keeps only the stored ones.
`[<-.lean_plane` <- function(x, i, j, value) {
  if (nargs() == 3L) stop("lean_plane: linear writes are not supported", call. = FALSE)
  ii <-if (missing(i)) seq_len(x$n) else lean_plane_index(i, x$n, x$dimnames[[1L]])
  jj <- if (missing(j)) seq_len(x$t) else lean_plane_index(j, x$t, x$dimnames[[2L]])
  value <- matrix(rep_len(value, length(ii) * length(jj)), length(ii), length(jj))
  tile <- (jj - 1L) %/% x$width + 1L
  for (at in split(seq_along(jj), tile)) {
    k <- tile[[at[[1L]]]]
    if (is.null(x$tiles[[k]])) {
      lean_plane_set(x, k, seq_len(x$n), matrix(x$fill, x$n, length(lean_tile_cols(x, k))))
    }
    m <- x$rows[[k]][ii]
    if (.lean_debug && anyNA(m)) stop("lean_plane: write to an unstored row", call. = FALSE)
    lc <- jj[at] - (k - 1L) * x$width
    if (x$orient == "time") {
      x$tiles[[k]][lc, m] <- t(value[, at, drop = FALSE])
    } else {
      x$tiles[[k]][m, lc] <- value[, at, drop = FALSE]
    }
  }
  x
}

dim.lean_plane <- function(x) c(x$n, x$t)
dimnames.lean_plane <- function(x) x$dimnames
length.lean_plane <- function(x) x$n * x$t
for (lean_m in c("[", "[<-", "dim", "dimnames", "length")) {
  registerS3method(lean_m, "lean_plane", get(paste0(lean_m, ".lean_plane")), envir = baseenv())
}
rm(lean_m)

# The whole plane as a matrix (parity and debug only).
lean_plane_full <- function(p) {
  out <- lean_plane_gather(p, seq_len(p$n), seq_len(p$t))
  if (!is.null(p$dimnames)) dimnames(out) <- p$dimnames
  out
}

# ---------------------------------------------------------------------------
# Hydration: one pinned bar query per tile session range (Section 12.3)

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

# Fills the six bar planes tile by tile. Tile k's query covers
# [its first session, the next tile's first session), with whole-second
# times, the first tile from `start` and the last to `end`, so every row of
# the pin's long query is fetched exactly once.
lean_hydrate <- function(snapshot, universe, start, end, instrument_ids, axis) {
  instrument_ids <- as.character(instrument_ids)
  axis <- as.POSIXct(axis, tz = "UTC")
  n <- length(instrument_ids)
  t <- length(axis)
  w <- lean_prep$width %||% lean_tile_width(n)
  fields <- c("open", "high", "low", "close", "volume")
  planes <- c(stats::setNames(lapply(fields, function(f) lean_plane_new(n, t, w, NA_real_)), fields),
              list(observed = lean_plane_new(n, t, w, FALSE)))
  duplicate <- FALSE
  fetched <- 0L
  k_all <- if (t > 0L) (t - 1L) %/% w + 1L else 0L
  first <- (seq_len(k_all) - 1L) * w + 1L
  for (k in seq_len(k_all)) {
    from <- if (k == 1L) start else axis[[first[[k]]]]
    to <- if (k == k_all) end else axis[[first[[k + 1L]]]] - 1
    rows <- tryCatch(ledgr_precompute_fetch_bars_frame(snapshot, universe, from, to),
                     ledgr_precomputed_coverage_error = function(e) NULL)
    if (is.null(rows)) next
    fetched <- fetched + nrow(rows)
    cols <- lean_tile_cols(planes$close, k)
    r <- collapse::fmatch(rows$instrument_id, instrument_ids)
    c <- collapse::fmatch(as.numeric(rows$ts_utc), as.numeric(axis[cols]))
    keep <- !is.na(r) & !is.na(c)
    if (!any(keep)) next
    r <- r[keep]
    c <- c[keep]
    if (anyDuplicated(r + (c - 1L) * n)) duplicate <- TRUE
    stored <- sort(unique(r))
    s <- collapse::fmatch(r, stored)
    lin <- s + (c - 1L) * length(stored)
    for (f in fields) {
      v <- matrix(NA_real_, length(stored), length(cols))
      v[lin] <- as.numeric(rows[[f]][keep])
      lean_plane_set(planes[[f]], k, stored, v)
    }
    v <- matrix(FALSE, length(stored), length(cols))
    v[lin] <- TRUE
    lean_plane_set(planes$observed, k, stored, v)
  }
  structure(list(planes = planes, duplicate = duplicate, fetched = fetched), class = "lean_bars")
}

# ---------------------------------------------------------------------------
# Substrate: the pinned builder, with lean planes and merged gap runs

# The pinned ledgr_history_substrate_for_experiment (R/history-substrate.R:303)
# with tile hydration in place of the long bar frame.
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
  bar_axis <- lean_bar_axis(exp$snapshot, exp$universe, meta$start, end, identical(clock_kind, "bar_native"))
  if (identical(clock_kind, "declared_sessions")) {
    ledgr_availability_require_coverage(
      list(sessions = data$sessions),
      ledgr_snapshot_bar_range(con, exp$snapshot$snapshot_id, coverage_start, end)
    )
  }
  axis <- if (identical(clock_kind, "declared_sessions")) {
    ledgr_availability_calendar(list(sessions = data$sessions), meta$start, end)$pulses_posix
  } else {
    bar_axis
  }
  if (identical(clock_kind, "bar_native")) data$sessions <- ledgr_bar_native_sessions(axis)
  bars <- lean_hydrate(exp$snapshot, exp$universe, meta$start, end, exp$universe, axis)
  substrate <- ledgr_history_substrate(
    bars = bars, instrument_ids = exp$universe, axis = axis, availability_data = data,
    availability_config = config, snapshot_hash = meta$snapshot_hash,
    source_start_utc = meta$start, clock_kind = clock_kind
  )
  ledgr_history_substrate_require_rectangular(substrate, coverage_start = coverage_start)
  substrate
}

# Called by the pinned builder; the pin's duplicate refusal, at its place.
ledgr_history_substrate_bar_matrices <- function(bars, instrument_ids, axis) {
  if (!inherits(bars, "lean_bars")) stop("lean preparation takes bars from lean_hydrate()", call. = FALSE)
  if (bars$duplicate) {
    rlang::abort("History preparation found duplicate instrument/session bars.",
                 class = c("ledgr_history_duplicate_bar", "ledgr_invalid_snapshot"))
  }
  bars$planes
}

# Maximal non-finite runs per row over the whole axis: the pinned C++ per
# tile, then runs that meet at a tile edge are joined.
ledgr_cpp_history_gap_runs <- function(stored) {
  if (!inherits(stored, "lean_plane")) return(get("ledgr_cpp_history_gap_runs", envir = asNamespace("ledgr"))(stored))
  cpp <- get("ledgr_cpp_history_gap_runs", envir = asNamespace("ledgr"))
  parts <- lapply(seq_along(stored$tiles), function(k) {
    cols <- lean_tile_cols(stored, k)
    r <- cpp(lean_plane_gather(stored, seq_len(stored$n), cols))
    list(row = rep.int(seq_len(stored$n), r$count), start = r$start + cols[[1L]] - 1L, end = r$end + cols[[1L]] - 1L)
  })
  lean_merge_runs(unlist(lapply(parts, `[[`, "row")), unlist(lapply(parts, `[[`, "start")),
                  unlist(lapply(parts, `[[`, "end")), stored$n)
}

lean_merge_runs <- function(row, start, end, n) {
  row <- as.integer(row)
  start <- as.integer(start)
  end <- as.integer(end)
  o <- order(row, start, method = "radix")
  row <- row[o]
  start <- start[o]
  end <- end[o]
  m <- length(row)
  new <- if (m) c(TRUE, row[-1L] != row[-m] | start[-1L] != end[-m] + 1L) else logical()
  count <- tabulate(row[new], nbins = n)
  list(off = as.integer(cumsum(c(0L, count))[seq_len(n)] + 1L), count = as.integer(count),
       start = start[new], end = end[c(new[-1L], TRUE)][seq_len(sum(new))])
}

# The pin checks bar-native coverage over the whole observed plane; per tile.
ledgr_history_substrate_require_rectangular <- function(substrate, coverage_start = NULL) {
  ledgr_history_substrate_require(substrate)
  if (!identical(substrate$clock_kind, "bar_native")) return(invisible(substrate))
  keep <- rep(TRUE, length(substrate$axis))
  if (!is.null(coverage_start)) keep <- substrate$axis >= ledgr_history_utc(coverage_start)
  observed <- substrate$bars$observed
  ok <- any(keep)
  for (k in seq_along(observed$tiles)) {
    cols <- lean_tile_cols(observed, k)
    if (!any(keep[cols])) next
    if (length(observed$stored[[k]]) < observed$n || !all(lean_plane_gather(observed, seq_len(observed$n), cols[keep[cols]]))) {
      ok <- FALSE
      break
    }
  }
  if (!ok) {
    rlang::abort(paste0("LEDGR_SNAPSHOT_COVERAGE_ERROR: per-instrument bars coverage is ",
                        "incomplete for requested range."),
                 class = c("LEDGR_SNAPSHOT_COVERAGE_ERROR", "ledgr_invalid_snapshot"))
  }
  invisible(substrate)
}

# ---------------------------------------------------------------------------
# Packets: one tile column per plane

ledgr_history_substrate_bar_packet <- function(substrate, pulse_idx) {
  ledgr_history_substrate_require(substrate)
  pulse_idx <- as.integer(pulse_idx)
  if (length(pulse_idx) != 1L || is.na(pulse_idx) || pulse_idx < 1L || pulse_idx > length(substrate$axis)) {
    rlang::abort("History bar pulse is outside the prepared axis.",
                 class = c("ledgr_history_outside_axis", "ledgr_invalid_args"))
  }
  bars <- substrate$bars
  list(
    ts_utc = substrate$axis[[pulse_idx]],
    instrument_id = substrate$instrument_ids,
    open = lean_plane_col(bars$open, pulse_idx),
    high = lean_plane_col(bars$high, pulse_idx),
    low = lean_plane_col(bars$low, pulse_idx),
    close = lean_plane_col(bars$close, pulse_idx),
    volume = lean_plane_col(bars$volume, pulse_idx),
    observed = lean_plane_col(bars$observed, pulse_idx)
  )
}

# ---------------------------------------------------------------------------
# Features: the pinned series with tiled output (Section 12.3)

# The pinned ledgr_history_compute_feature_series (R/history-features.R:447)
# with one change: each output is a lean plane, written range by range into
# its tiles, then compacted. Inputs are each instrument's prefix gathered
# across tiles (pinned ledgr_history_feature_inputs through `[`), so no
# calculation restarts at an edge.
ledgr_history_compute_feature_series <- function(substrate, definitions, calculation_start = NULL,
                                                 calculation_end = NULL) {
  ledgr_history_substrate_require(substrate)
  definitions <- lapply(definitions, function(def) {
    if (inherits(def, "ledgr_indicator")) ledgr_precompute_feature_def_from_indicator(def) else def
  })
  certified <- lapply(definitions, ledgr_feature_certify)
  n_inst <- length(substrate$instrument_ids)
  n_axis <- length(substrate$axis)
  w <- substrate$bars$close$width
  out <- lapply(certified, function(cert) lean_plane_new(n_inst, n_axis, w, NA_real_))
  names(out) <- names(definitions)
  bounds <- ledgr_history_feature_bounds(substrate, calculation_start, calculation_end)
  planes <- lapply(certified, function(cert) ledgr_feature_plane_chunks(n_inst))
  if (length(definitions) == 0L || bounds$from > bounds$to) {
    attr(out, "ledgr_feature_planes") <- ledgr_feature_plane_records(planes, substrate$instrument_ids, bounds)
    return(out)
  }
  output_carry <- substrate$history_policy$output_carry
  calculated_count <- matrix(0L, nrow = length(certified), ncol = n_inst)
  for (i in seq_len(n_inst)) {
    ranges <- ledgr_history_feature_ranges(substrate, i, bounds$from, bounds$to)
    for (r in seq_along(ranges$start)) {
      range_end <- ranges$end[[r]]
      inputs <- ledgr_history_feature_inputs(substrate, i, range_end, substrate$axis[[range_end]])
      keep <- seq.int(ranges$start[[r]], range_end)
      cache <- new.env(hash = TRUE, parent = emptyenv())
      for (d in seq_along(certified)) {
        calculated <- ledgr_history_feature_calculate(certified[[d]], inputs, bounds$from, output_carry, cache)
        out[[d]][i, keep] <- calculated$value[keep]
        calculated_count[d, i] <- calculated_count[d, i] + sum(calculated$calculated[keep])
        exceptions <- ledgr_feature_plane_exceptions(certified[[d]], inputs, calculated, ranges$start[[r]], keep)
        for (field in names(exceptions)) {
          if (length(exceptions[[field]]) > 0L) {
            planes[[d]][[field]][[i]] <- c(planes[[d]][[field]][[i]], exceptions[[field]])
          }
        }
      }
    }
  }
  ledgr_history_feature_causality(substrate, certified, bounds, calculated_count, out)
  for (p in out) lean_plane_compact(p)
  attr(out, "ledgr_feature_planes") <- ledgr_feature_plane_records(planes, substrate$instrument_ids, bounds)
  out
}

# Keeps, per tile, only the rows with a non-missing cell.
lean_plane_compact <- function(p) {
  for (k in seq_along(p$tiles)) {
    v <- p$tiles[[k]]
    if (is.null(v)) next
    held <- if (p$orient == "time") colSums(!is.na(v)) > 0L else rowSums(!is.na(v)) > 0L
    if (all(held)) next
    keep <- p$stored[[k]][held]
    lean_plane_set(p, k, keep, if (p$orient == "time") t(v[, held, drop = FALSE]) else v[held, , drop = FALSE])
  }
  invisible(p)
}

# The pinned ledgr_runtime_projection (R/runtime-projection.R:1) over lean
# planes: the same checks, with the dimnames set on the plane.
ledgr_runtime_projection <- function(feature_values, universe, pulses_posix,
                                     feature_engine_version = ledgr_feature_engine_version(),
                                     alias_index = NULL, feature_planes = NULL) {
  universe <- as.character(universe)
  pulses_posix <- as.POSIXct(pulses_posix, tz = "UTC")
  feature_values <- feature_values %||% list()
  if (!is.list(feature_values) || is.null(names(feature_values)) && length(feature_values) > 0L) {
    rlang::abort("`feature_values` must be a named list of feature matrices.", class = "ledgr_invalid_runtime_projection")
  }
  feature_ids <- names(feature_values)
  if (length(feature_ids) > 0L) {
    if (anyNA(feature_ids) || any(!nzchar(feature_ids))) {
      rlang::abort("`feature_values` names must be non-empty feature IDs.", class = "ledgr_invalid_runtime_projection")
    }
    ledgr_abort_duplicate_feature_ids(feature_ids)
  }
  pulse_names <- ledgr_projection_pulse_names(pulses_posix)
  for (value in feature_values) {
    if (!inherits(value, "lean_plane")) {
      rlang::abort("Each runtime projection feature value must be a matrix.", class = "ledgr_invalid_runtime_projection")
    }
    if (!identical(dim(value), c(length(universe), length(pulses_posix)))) {
      rlang::abort("Each runtime projection matrix must have dimensions instruments x pulses.",
                   class = "ledgr_invalid_runtime_projection")
    }
    value$dimnames <- list(universe, pulse_names)
  }
  structure(
    list(
      feature_values = feature_values,
      instrument_index = stats::setNames(seq_along(universe), universe),
      pulse_index = stats::setNames(seq_along(pulses_posix), pulse_names),
      pulses_posix = pulses_posix,
      pulses_iso = format(pulses_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      feature_engine_version = feature_engine_version,
      alias_index = alias_index,
      feature_planes = feature_planes
    ),
    class = c("ledgr_runtime_projection", "list")
  )
}

# The projection with every plane gathered whole (parity only).
lean_projection_full <- function(projection) {
  projection$feature_values <- lapply(projection$feature_values, lean_plane_full)
  projection
}

# ---------------------------------------------------------------------------
# Working tiles: masks, carry sources and last barriers (Section 12.3)

# The pinned ledgr_history_prepare_masks (R/history-frame.R:60) for the base
# masks of every instrument: `expected` becomes a working plane built per
# tile from the segments, terminal_first is summed per tile, and the barrier
# runs (FALSE runs of `expected`) are built per tile and joined at edges.
# Overlay masks (one late-known instrument) stay whole, as pinned.
ledgr_history_prepare_masks <- function(substrate, knowledge, instrument_idx, block = 64L) {
  n_axis <- length(substrate$axis)
  n <- length(instrument_idx)
  if (n == 0L || n_axis == 0L || n != length(substrate$instrument_ids)) {
    return(lean_pinned_ns("ledgr_history_prepare_masks")(substrate, knowledge, instrument_idx, block))
  }
  candidates <- function(family, test) {
    segments <- substrate$segments[[family]]
    if (is.null(segments) || length(segments$instrument) == 0L) return(integer())
    states <- segments$state_levels[segments$state]
    which(instrument_idx %in% unique(segments$instrument[test(states)]))
  }
  blocks <- function(rows) split(rows, ceiling(seq_along(rows) / block))
  inactive <- blocks(candidates("lifetime", function(x) x == "known_inactive"))
  ends <- blocks(candidates("lifetime_terminal", nzchar))
  w <- substrate$bars$close$width
  expected <- lean_working_plane(n, n_axis, w, TRUE, function(k) {
    cols <- lean_tile_cols(expected, k)
    e <- matrix(TRUE, nrow = n, ncol = length(cols))
    for (rows in inactive) {
      e[rows, ] <- ledgr_history_substrate_expected_at(substrate, knowledge, cols, instrument_idx[rows])
    }
    e
  })
  terminal_first <- rep.int(n_axis + 1L, n)
  false_runs <- get("ledgr_cpp_history_false_runs", envir = asNamespace("ledgr"))
  runs <- list()
  for (k in seq_along(expected$tiles)) {
    cols <- lean_tile_cols(expected, k)
    for (rows in ends) {
      terminal <- ledgr_history_substrate_terminal_at(substrate, knowledge, cols, instrument_idx[rows])
      terminal_first[rows] <- terminal_first[rows] - as.integer(rowSums(terminal))
    }
    r <- false_runs(expected$build(k))
    runs[[k]] <- list(row = rep.int(seq_len(n), r$count), start = r$start + cols[[1L]] - 1L,
                      end = r$end + cols[[1L]] - 1L)
  }
  list(
    expected = expected,
    terminal_first = as.integer(terminal_first),
    barrier_runs = lean_merge_runs(unlist(lapply(runs, `[[`, "row")), unlist(lapply(runs, `[[`, "start")),
                                   unlist(lapply(runs, `[[`, "end")), n)
  )
}

# A carry plane (pinned ledgr_history_carry_source / _carry_last_barrier,
# R/history-treatment.R:249-298) as a working plane. `seed(k)` gives tile k's
# seeds with absolute columns (0 at a barrier); a forward pass at preparation
# records each tile's carried-in column (the previous tile's last raw
# value), so any tile is rebuilt alone. 0 reads as NA, as pinned.
lean_carry_plane <- function(n, t, w, seed) {
  k_all <- if (t > 0L) (t - 1L) %/% w + 1L else 0L
  carry <- vector("list", k_all)
  fill <- function(k) {
    s <- seed(k)
    if (k > 1L) s <- cbind(carry[[k]], s)
    v <- matrix(as.integer(collapse::na_locf(as.vector(t(s)))), nrow = n, byrow = TRUE)
    if (k > 1L) v <- v[, -1L, drop = FALSE]
    v
  }
  for (k in seq_len(k_all - 1L)) {
    v <- fill(k)
    carry[[k + 1L]] <- v[, ncol(v)]
  }
  lean_working_plane(n, t, w, NA_integer_, function(k) {
    v <- fill(k)
    v[v == 0L] <- NA_integer_
    v
  })
}

# Tile k's seeds for one field's carry sources (pinned
# ledgr_history_carry_source): absolute column where observed, expected and
# before the terminal; 0 at a barrier; session 1 resets when unobserved.
lean_source_seed <- function(substrate, masks, field, k) {
  e <- masks$expected
  cols <- lean_tile_cols(e, k)
  n <- e$n
  observed <- is.finite(substrate$bars[[field]][, cols, drop = FALSE])
  expected <- e[, cols, drop = FALSE]
  terminal <- outer(masks$terminal_first, cols, "<=")
  dim(terminal) <- c(n, length(cols))
  seed <- matrix(rep(cols, each = n), nrow = n)
  seed[!(observed & expected & !terminal)] <- NA_integer_
  seed[!expected | terminal] <- 0L
  if (k == 1L) seed[!observed[, 1L], 1L] <- 0L
  seed
}

# Tile k's seeds for the last barrier (pinned ledgr_history_carry_last_barrier).
lean_barrier_seed <- function(masks, k) {
  e <- masks$expected
  cols <- lean_tile_cols(e, k)
  n <- e$n
  terminal <- outer(masks$terminal_first, cols, "<=")
  dim(terminal) <- c(n, length(cols))
  seed <- matrix(rep(cols, each = n), nrow = n)
  seed[!(!e[, cols, drop = FALSE] | terminal)] <- NA_integer_
  if (k == 1L) seed[is.na(seed[, 1L]), 1L] <- 0L
  seed
}

ledgr_history_prepare_positions <- function(substrate, masks, instrument_idx, field, block = 128L) {
  if (!inherits(masks$expected, "lean_plane")) {
    return(lean_pinned_ns("ledgr_history_prepare_positions")(substrate, masks, instrument_idx, field, block))
  }
  e <- masks$expected
  list(source = lean_carry_plane(e$n, e$t, e$width, function(k) lean_source_seed(substrate, masks, field, k)))
}

ledgr_history_mask_barrier <- function(substrate, key, masks, block = 128L) {
  if (!is.null(masks$last_barrier)) return(masks$last_barrier)
  if (!inherits(masks$expected, "lean_plane")) {
    return(lean_pinned_ns("ledgr_history_mask_barrier")(substrate, key, masks, block))
  }
  e <- masks$expected
  last_barrier <- lean_carry_plane(e$n, e$t, e$width, function(k) lean_barrier_seed(masks, k))
  masks$last_barrier <- last_barrier
  assign(key, masks, envir = ledgr_history_memo(substrate))
  last_barrier
}

# The pinned function itself, run in the namespace (overlays, empty inputs).
lean_pinned_ns <- function(name) get(name, envir = asNamespace("ledgr"))

# ---------------------------------------------------------------------------
# Compact bar reads: the pinned C++ on a gathered slice

# The pinned kernel takes whole planes with absolute coordinates. Lean passes
# the requested rows over [dependency_first - 1, last column] and shifts
# every coordinate by off = dependency_first - 2 (no shift when that is
# negative). Shifting keeps every comparison and age except where a gap's
# carry candidate lies before the slice; for those rows:
# - a gap starting at session 2 or later is clamped to start at slice
#   session 2, so its candidate is the sentinel (slice session 1). Its age
#   then exceeds the carry limit at every requested session, as the true
#   candidate's does, so it is expired and never read;
# - a leading gap (session 1) keeps a candidate before the slice, as the pin
#   does: no carry source;
# - a barrier run between the true candidate and the slice is replaced by
#   one synthetic barrier at the sentinel, which the kernel's barrier search
#   then reaches from the clamped candidate.
ledgr_history_value_slice <- function(stored, rows, columns, masks, gaps, max_carry_sessions, carry_allowed,
                                      min_observations, axis_names, instrument_ids,
                                      manifestation = "matrix", trace_access = FALSE) {
  rows <- as.integer(rows)
  columns <- as.integer(columns)
  dep <- as.integer(masks$dependency_first)
  off <- if (length(columns)) max(0L, dep - 2L) else 0L
  slice <- if (length(columns)) seq.int(off + 1L, columns[[length(columns)]]) else integer()
  k <- length(rows)
  # Gap runs of the requested rows, shifted; runs ending before the slice
  # never cover a requested session.
  g <- lean_runs_of(gaps, rows)
  keep <- g$end > off
  g <- lapply(g, `[`, keep)
  pre <- g$start <= off + 1L
  cand_first <- pmax(1L, g$start[pre] - 1L)  # first session of the true search, 1-based
  g$start <- g$start - off
  g$end <- g$end - off
  g$start[pre & g$start + off >= 2L] <- 2L
  # Barrier sets: base runs per row, override runs per override.
  over_at <- match(seq_len(k), as.integer(masks$override_row))
  b <- lean_runs_of(masks$barrier_runs, rows)
  ob <- lean_runs_of(masks$override_barrier_runs, seq_along(masks$override_row))
  synth <- function(runs, units, from) {
    if (!length(units)) return(rep(FALSE, 0L))
    hit <- runs$start <= off & runs$end >= from[match(runs$row, units)]
    units %in% runs$row[hit & runs$row %in% units]
  }
  pre_rows <- g$row[pre]
  is_over <- !is.na(over_at[pre_rows])
  base_synth <- pre_rows[!is_over][synth(b, pre_rows[!is_over], cand_first[!is_over])]
  over_synth <- over_at[pre_rows[is_over]][synth(ob, over_at[pre_rows[is_over]], cand_first[is_over])]
  shift <- function(runs, n, add) {
    lean_runs(c(runs$row, add), c(runs$start - off, rep.int(1L, length(add))),
              c(runs$end - off, rep.int(1L, length(add))), n, drop_before = 1L)
  }
  b <- shift(b, k, base_synth)
  ob <- shift(ob, length(masks$override_row), over_synth)
  g <- lean_runs(g$row, g$start, g$end, k)
  cpp <- get("ledgr_cpp_history_bar_compact", envir = asNamespace("ledgr"))
  cpp(
    stored[rows, slice, drop = FALSE], seq_len(k), columns - off,
    masks$expected[rows, slice, drop = FALSE], as.integer(masks$terminal_first[rows] - off),
    as.integer(dep - off), as.integer(masks$override_row),
    masks$override_expected, as.integer(masks$override_terminal - off),
    b$off, b$count, b$start, b$end, ob$off, ob$count, ob$start, ob$end,
    g$off, g$count, g$start, g$end,
    as.integer(max_carry_sessions), isTRUE(carry_allowed), as.integer(min_observations),
    as.character(axis_names), as.character(instrument_ids),
    identical(manifestation, "wide"), isTRUE(trace_access)
  )
}

# The runs of units `at` (rows of an off/count/start/end summary) as one
# table, units renumbered 1..length(at).
lean_runs_of <- function(runs, at) {
  counts <- runs$count[at]
  idx <- sequence(counts, runs$off[at])
  list(row = rep.int(seq_along(at), counts), start = runs$start[idx], end = runs$end[idx])
}

# An off/count/start/end summary over n units, ordered by end within a unit
# (the kernel's binary search); runs ending before `drop_before` dropped.
lean_runs <- function(row, start, end, n, drop_before = NULL) {
  if (!is.null(drop_before)) {
    keep <- end >= drop_before
    row <- row[keep]
    start <- start[keep]
    end <- end[keep]
  }
  o <- order(row, end, start, method = "radix")
  count <- tabulate(row, nbins = n)
  list(off = as.integer(cumsum(c(0L, count))[seq_len(n)] + 1L), count = as.integer(count),
       start = as.integer(start[o]), end = as.integer(end[o]))
}

# ---------------------------------------------------------------------------
# Pinned functions run over lean planes

ledgr_history_substrate <- lean_pinned("ledgr_history_substrate")
ledgr_history_substrate_fold_reader <- lean_pinned("ledgr_history_substrate_fold_reader")
ledgr_projection_from_feature_matrix <- lean_pinned("ledgr_projection_from_feature_matrix")
# Every pinned history-read function (R/history-frame.R) runs as a lean copy,
# so the masks, carry planes and compact slice above are the ones it reaches.
for (lean_f in c(
  "ledgr_history_bar_fields", "ledgr_history_memo", "ledgr_history_late_epochs", "ledgr_history_memo_value",
  "ledgr_history_base_masks", "ledgr_history_base_positions", "ledgr_history_overlay_key",
  "ledgr_history_overlay_masks", "ledgr_history_overlay_positions", "ledgr_history_cutoff_planes",
  "ledgr_history_vintage_planes", "ledgr_history_bar_evidence", "ledgr_history_plane_lookup",
  "ledgr_history_plane_run", "ledgr_history_feature_evidence", "ledgr_history_cell_fields",
  "ledgr_history_prepare_owner_summaries", "ledgr_history_read_service", "ledgr_history_view",
  "ledgr_history_feature_width", "ledgr_history_request_error", "ledgr_history_validate_lookback",
  "ledgr_history_bar_mask_view", "ledgr_history_bar_compact", "ledgr_history_feature_compact",
  "ledgr_history_compact_admission", "ledgr_history_validate_requirement", "ledgr_history_requirements",
  "ledgr_history_choice", "ledgr_history_context_view", "ledgr_history_frame", "ledgr_history_request_plan",
  "ledgr_history_selection_ids", "ledgr_history_read_plan", "ledgr_history_plan_frame",
  "ledgr_history_used_before_window", "ledgr_history_selection_table", "ledgr_history_time_names",
  "ledgr_history_wide", "ledgr_history_long", "ledgr_history_require_result", "ledgr_history_require_consistent",
  "ledgr_history_matrix", "ledgr_history_matrix_result", "ledgr_history_matrix_dimnames",
  "ledgr_history_matrix_from_plan", "ledgr_history_matrix_from_frame", "ledgr_history_matrix_drop_identity"
)) assign(lean_f, lean_pinned(lean_f))
rm(lean_f)

# The valuation cursor reads closes column by column through `[`; its shape
# check accepts a lean plane (a narrow environment, not lean-wide).
lean_valuation_env <- new.env(parent = environment(lean_pinned))
lean_valuation_env$is.matrix <- function(x) inherits(x, "lean_plane") || base::is.matrix(x)
lean_valuation_env$is.numeric <- function(x) {
  if (inherits(x, "lean_plane")) is.double(x$fill) else base::is.numeric(x)
}
ledgr_availability_valuation_state <- lean_pinned("ledgr_availability_valuation_state")
environment(ledgr_availability_valuation_state) <- lean_valuation_env

# Harness only (end-to-end runs, intraday digests, the timing candidate arm):
# binds lean preparation into the ledgr namespace and returns a function
# that restores the pinned bindings. Nothing in R/ calls it.
lean_prepare_install <- function() {
  ns <- asNamespace("ledgr")
  lean_env <- environment(lean_pinned)
  swap <- c(
    ledgr_history_substrate_for_experiment = "lean_history_substrate_for_experiment",
    ledgr_history_substrate_require_rectangular = "ledgr_history_substrate_require_rectangular",
    ledgr_history_compute_feature_series = "ledgr_history_compute_feature_series",
    ledgr_projection_from_feature_matrix = "ledgr_projection_from_feature_matrix",
    ledgr_history_substrate_fold_reader = "ledgr_history_substrate_fold_reader",
    ledgr_history_matrix = "ledgr_history_matrix",
    ledgr_history_frame = "ledgr_history_frame",
    ledgr_availability_valuation_state = "ledgr_availability_valuation_state"
  )
  pinned <- mget(names(swap), envir = ns)
  bind <- function(values) {
    for (name in names(values)) {
      unlockBinding(name, ns)
      assign(name, values[[name]], envir = ns)
      lockBinding(name, ns)
    }
  }
  bind(stats::setNames(mget(unname(swap), envir = lean_env), names(swap)))
  function() bind(pinned)
}

# The substrate with every plane gathered whole (parity only).
lean_substrate_full <- function(substrate) {
  substrate$bars <- lapply(substrate$bars, lean_plane_full)
  substrate
}
