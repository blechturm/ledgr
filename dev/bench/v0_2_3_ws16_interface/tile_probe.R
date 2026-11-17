# LDG-3211 tile probe: which stored planes the pinned history-read and
# feature-input services read, at what index shape, and which full-axis
# outputs they allocate. The answers fix the storage-access and
# output-allocation adaptations tiles need (skeleton Section 3).
#
#   Rscript tile_probe.R --pkg=<ledgr source at d5b3a151> --out=<dir>
#
# Pin-only since Cut 22 (decision 3, candidate 5): its payload note describes
# the pin's per-instrument split, which the package no longer builds.
#
# The access sites are wrapped in the pinned namespace; their semantics are
# untouched. Workloads: the WS42 public-history fixture (late-known lifetime
# fact, bar gap, price carry) with one read of every public request shape on
# every decision pulse, and the portable 40 x 504 momentum run with a
# 252-session feature window and an Inf bar read on its month-start pulses.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  entry <- file.path(here, "..", "v0_2_3_ws16_entry")
  source(file.path(entry, "common.R"))
  source(file.path(entry, "workloads.R"))
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
commit <- ws16_load_source(pkg)
if (!identical(commit, "d5b3a151")) stop("source tree is not the d5b3a151 pin", call. = FALSE)
source(file.path(pkg, "tests", "testthat", "helper-history-fixtures.R"))

rec <- new.env()
rec$workload <- NA_character_
rec$request <- "preparation"
rec$rows <- list()
note <- function(site, rows = NA, col_from = NA, col_to = NA, n_cols = NA, dims = "", detail = "") {
  rec$rows[[length(rec$rows) + 1L]] <- data.frame(
    workload = rec$workload, request = rec$request, site = site,
    n_rows = as.integer(rows), col_from = as.integer(col_from), col_to = as.integer(col_to),
    n_cols = as.integer(n_cols), dims = dims, detail = detail, stringsAsFactors = FALSE
  )
}
dims_of <- function(x) if (is.null(dim(x))) as.character(length(x)) else paste(dim(x), collapse = "x")
span <- function(cols) if (length(cols)) c(min(cols), max(cols), length(cols)) else c(NA, NA, 0L)

# Public request entry points set the request label for the sites they reach.
for (fn in c("ledgr_history_matrix", "ledgr_history_frame")) {
  local({
    f <- fn
    ws16_wrap(f, function(orig) {
      force(orig)
      function(x, feature = NULL, bar = NULL, lookback, instruments = "admissible", ...) {
        dots <- list(...)
        layout <- if (identical(f, "ledgr_history_frame")) (dots$layout %||% "wide")[[1L]] else "matrix"
        prev <- rec$request
        rec$request <- paste0(if (is.null(bar)) paste0("feature:", feature) else paste0("bar:", bar),
                              " lookback=", lookback, " layout=", layout,
                              " instruments=", paste(instruments, collapse = ","))
        on.exit(rec$request <- prev)
        orig(x, feature = feature, bar = bar, lookback = lookback, instruments = instruments, ...)
      }
    })
  })
}

# Preparation: bar hydration, bar planes, feature calculation and payload.
ws16_wrap("ledgr_precompute_fetch_bars_frame", function(orig) function(snapshot, universe, start, end) {
  res <- orig(snapshot, universe, start, end)
  note("bar_hydration_query", rows = nrow(res), dims = dims_of(res),
       detail = paste0("one long frame, ", length(universe), " instruments, all sessions"))
  res
})
ws16_wrap("ledgr_history_substrate_bar_matrices", function(orig) function(bars, instrument_ids, axis) {
  res <- orig(bars, instrument_ids, axis)
  note("bar_planes_alloc", rows = length(instrument_ids), col_from = 1L, col_to = length(axis),
       n_cols = length(axis), dims = dims_of(res$close),
       detail = paste0(length(res), " planes, instrument-major, full axis"))
  res
})
ws16_wrap("ledgr_history_substrate_bar_packet", function(orig) function(substrate, pulse_idx) {
  note("bar_packet_read", rows = length(substrate$instrument_ids), col_from = pulse_idx,
       col_to = pulse_idx, n_cols = 1L, dims = dims_of(substrate$bars$close),
       detail = "one column of each bar plane")
  orig(substrate, pulse_idx)
})
ws16_wrap("ledgr_history_feature_inputs", function(orig) function(substrate, instrument_idx, prefix_end, cutoff) {
  note("feature_input_read", rows = 1L, col_from = 1L, col_to = prefix_end, n_cols = prefix_end,
       dims = dims_of(substrate$bars$close), detail = "one instrument row, prefix from column 1")
  orig(substrate, instrument_idx, prefix_end, cutoff)
})
ws16_wrap("ledgr_history_compute_feature_series", function(orig) function(substrate, definitions, ...) {
  res <- orig(substrate, definitions, ...)
  note("feature_output_alloc", rows = length(substrate$instrument_ids), col_from = 1L,
       col_to = length(substrate$axis), n_cols = length(substrate$axis),
       dims = if (length(res)) dims_of(res[[1L]]) else "0",
       detail = paste0(length(res), " full-axis matrices, written by instrument and knowledge range"))
  res
})
ws16_wrap("ledgr_history_precompute_payload", function(orig) function(unique_defs, substrate, ...) {
  res <- orig(unique_defs, substrate, ...)
  note("feature_payload_split", rows = length(substrate$instrument_ids), n_cols = length(substrate$axis),
       detail = paste0(length(res), " definitions split into per-instrument vectors"))
  res
})
for (fn in c("ledgr_projection_from_payload", "ledgr_projection_from_feature_matrix")) {
  local({
    f <- fn
    ws16_wrap(f, function(orig) function(...) {
      res <- orig(...)
      v <- res$feature_values
      note("projection_alloc", dims = if (length(v)) dims_of(v[[1L]]) else "0",
           detail = paste0(sub("ledgr_projection_", "", f), ": ", length(v), " instrument x pulse matrices"))
      res
    })
  })
}

# Memoised mask and carry planes the read service prepares over the full axis.
ws16_wrap("ledgr_history_prepare_masks", function(orig) function(substrate, knowledge, instrument_idx, block = 64L) {
  res <- orig(substrate, knowledge, instrument_idx, block)
  note("memo_masks_alloc", rows = length(instrument_idx), col_from = 1L, col_to = ncol(res$expected),
       n_cols = ncol(res$expected), dims = dims_of(res$expected),
       detail = if (is.infinite(as.numeric(knowledge))) "base masks" else "late-knowledge overlay")
  res
})
ws16_wrap("ledgr_history_prepare_positions", function(orig) function(substrate, masks, instrument_idx, field, block = 128L) {
  res <- orig(substrate, masks, instrument_idx, field, block)
  note("memo_carry_source_alloc", rows = length(instrument_idx), n_cols = ncol(res$source),
       dims = dims_of(res$source), detail = paste0("field ", field, ", reads full plane rows"))
  res
})
ws16_wrap("ledgr_history_mask_barrier", function(orig) function(substrate, key, masks, block = 128L) {
  had <- !is.null(masks$last_barrier)
  res <- orig(substrate, key, masks, block)
  if (!had) note("memo_barrier_alloc", rows = nrow(res), n_cols = ncol(res), dims = dims_of(res), detail = key)
  res
})

# Read sites.
ws16_wrap("ledgr_history_value_slice", function(orig) function(stored, rows, columns, masks, ...) {
  s <- span(columns)
  note("bar_compact_cpp", rows = length(rows), col_from = s[[1L]], col_to = s[[2L]], n_cols = s[[3L]],
       dims = dims_of(stored),
       detail = paste0("whole plane and full masks ", dims_of(masks$expected),
                       " passed to C++; dependency_first=", masks$dependency_first))
  orig(stored, rows, columns, masks, ...)
})
ws16_wrap("ledgr_history_cutoff_planes", function(orig) function(substrate, field, rows, columns, cutoff_col) {
  res <- orig(substrate, field, rows, columns, cutoff_col)
  s <- span(columns)
  src <- res$source
  reach <- if (!is.null(src) && any(!is.na(src))) min(src, na.rm = TRUE) else NA
  note("bar_evidence_read", rows = length(rows), col_from = s[[1L]], col_to = s[[2L]], n_cols = s[[3L]],
       dims = dims_of(substrate$bars[[field %||% "close"]]),
       detail = paste0("carry source reaches column ", reach))
  res
})
ws16_wrap("ledgr_history_vintage_planes", function(orig) function(substrate, rows, columns) {
  s <- span(columns)
  note("feature_read", rows = length(rows), col_from = s[[1L]], col_to = s[[2L]], n_cols = s[[3L]],
       dims = dims_of(substrate$feature_projection$feature_values[[1L]]),
       detail = "projection values[rows, columns] and base-mask slice")
  orig(substrate, rows, columns)
})
ws16_wrap("ledgr_projection_feature_vector_accessor", function(orig) function(projection, pulse_idx, ...) {
  note("pulse_feature_read", rows = length(projection$instrument_index), col_from = pulse_idx,
       col_to = pulse_idx, n_cols = 1L,
       dims = if (length(projection$feature_values)) dims_of(projection$feature_values[[1L]]) else "0",
       detail = "one projection column per feature")
  orig(projection, pulse_idx, ...)
})

# WS42 fixture: every public request shape on every decision pulse.
reader <- function(ctx) {
  ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = 3)
  ledgr::ledgr_history_frame(ctx, bar = "close", lookback = Inf, layout = "wide")
  ledgr::ledgr_history_frame(ctx, bar = "close", lookback = Inf, layout = "long")
  ledgr::ledgr_history_matrix(ctx, feature = "fast", lookback = 2, min_observations = 1)
  ledgr::ledgr_history_frame(ctx, feature = "fast", lookback = Inf, layout = "long")
  ledgr::ledgr_history_frame(ctx, bar = "volume", lookback = 4, instruments = "decision_axis")
  ledgr::ledgr_history_frame(ctx, bar = "close", lookback = Inf, instruments = "CCC")
}
rec$workload <- "ws42_fixture"
cap <- ws42_capture_run(reader = reader, run_id = "ws16-tile-ws42")
close(cap$bt)

# Portable momentum: a 252-session feature window and an Inf bar read.
rec$workload <- "momentum_40x504"
work <- file.path(tempdir(), "ws16_tile_probe")
dir.create(work, showWarnings = FALSE)
snapshot <- ws16_momentum_snapshot(40L, 504L, file.path(work, "momentum.duckdb"), "ws16_momentum")
strategy <- function(ctx, params) {
  ledgr::ledgr_history_matrix(ctx, feature = "return_63", lookback = 252)
  ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = Inf)
  score <- ledgr::ledgr_signal_return(ctx, params$lookback)
  selected <- ledgr::ledgr_select_top(score, n = params$n, within = ctx$buyable)
  weights <- ledgr::ledgr_weight_equal(selected)
  list(targets = ledgr::ledgr_target_rebalance(ctx, weights = weights, invest_fraction = 0.95,
                                               index_leavers = "keep", capital_base = "remaining_equity"))
}
exp <- ledgr::ledgr_experiment(snapshot, strategy, features = list(ledgr::ledgr_ind_returns(63L)),
  schedule = ledgr::ledgr_schedule_month_start(), opening = ledgr::ledgr_opening(cash = 1e6),
  cost_model = ledgr::ledgr_cost_zero())
bt <- ledgr_run(exp, params = list(lookback = 63L, n = 10L), run_id = "ws16-tile-momentum", seed = 1L)
close(bt)
ledgr_snapshot_close(snapshot)

log <- do.call(rbind, rec$rows)
ws16_write(log, file.path(out, "tile_access_log.csv"))
# One row per workload, request and site with call counts and the widest shape.
key <- paste(log$workload, log$request, log$site, log$dims, sep = "\t")
agg <- do.call(rbind, lapply(split(log, key), function(d) {
  data.frame(workload = d$workload[[1L]], request = d$request[[1L]], site = d$site[[1L]],
             calls = nrow(d), max_rows = max(d$n_rows), min_col_from = suppressWarnings(min(d$col_from, na.rm = TRUE)),
             max_col_to = suppressWarnings(max(d$col_to, na.rm = TRUE)), max_cols = max(d$n_cols),
             dims = d$dims[[1L]], detail = d$detail[[length(d$detail)]], stringsAsFactors = FALSE)
}))
agg$min_col_from[!is.finite(agg$min_col_from)] <- NA
agg$max_col_to[!is.finite(agg$max_col_to)] <- NA
agg <- agg[order(agg$workload, agg$request != "preparation", agg$request, agg$site), ]
ws16_write(agg, file.path(out, "tile_access_by_site.csv"))
cat("tile probe written to", out, "\n")
