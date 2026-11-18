# Shared helpers for the stage 2-3 measuring probe (CHARTER.md). Loads one
# installed ledgr build (--lib) and reads only its own internals; nothing here
# is called from R/.

arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
.libPaths(c(normalizePath(arg("lib"), winslash = "/"), .libPaths()))
suppressPackageStartupMessages(library(ledgr))
ns <- asNamespace("ledgr")
work <- normalizePath(arg("work", file.path(tempdir(), "feature_stage23")), winslash = "/", mustWork = FALSE)
dir.create(work, recursive = TRUE, showWarnings = FALSE)
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))

provenance <- function() data.frame(
  ledgr_path = find.package("ledgr"), ledgr_version = as.character(utils::packageVersion("ledgr")),
  engine_version = substr(ns$ledgr_feature_engine_version(), 1L, 16L),
  r = R.version.string, plan = tryCatch(paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " "),
                                        error = function(e) NA_character_),
  stringsAsFactors = FALSE)

ttr_sma <- function(n) ledgr::ledgr_ind_ttr("SMA", input = "close", id = paste0("sma_", n), n = as.integer(n))

# The published crossover fixture as Cut 22's measuring step built it.
crossover_snapshot <- function(shape) {
  dims <- as.integer(strsplit(sub("^crossover_", "", shape), "x")[[1L]])
  db <- file.path(work, paste0(shape, ".duckdb"))
  if (!file.exists(db)) {
    ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(r_floor_fixture(dims[[1L]], dims[[2L]])$bars,
      db_path = db, snapshot_id = "p", price_basis = "split_adjusted"))
  }
  ledgr::ledgr_snapshot_open(db, "p", verify = TRUE)
}
crossover_exp <- function(snapshot, widths, indicator = ttr_sma) {
  ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    features = do.call(ledgr::ledgr_feature_map, stats::setNames(lapply(widths, indicator), paste0("sma_", widths))),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero())
}

defs_for <- function(exp) {
  d <- ns$ledgr_experiment_materialize_feature_result(exp, params = list(), feature_params = list())$features
  d <- lapply(d, function(x) if (inherits(x, "ledgr_indicator")) ns$ledgr_precompute_feature_def_from_indicator(x) else x)
  stats::setNames(d, vapply(d, function(x) x$id, ""))
}

# ---- the stage-3 gate (RFC seed v2, Stage 3) --------------------------------
# One predicate per (certified definition, instrument, bounds, cutoff, policy).
# conservative: one knowledge range; every calculation column expected; every
#   required field finite there (so nothing is carried); no terminal
#   assertion anywhere in the prefix.
# relaxed: one knowledge range; the expected-and-finite columns of the
#   calculation slice form one contiguous block (leading or trailing inactive
#   or missing columns allowed); no terminal assertion in the prefix.
gate_cells <- function(substrate, certified, bounds) {
  calc <- seq.int(bounds$from, bounds$to)
  prefix <- seq_len(bounds$to)
  n_inst <- length(substrate$instrument_ids)
  cutoff <- substrate$axis[[bounds$to]]
  expected <- ns$ledgr_history_substrate_expected_at(substrate, cutoff, prefix, seq_len(n_inst))
  term <- ns$ledgr_history_substrate_terminal_planes(substrate, cutoff, prefix, seq_len(n_inst))
  one_range <- vapply(seq_len(n_inst), function(i)
    length(ns$ledgr_history_feature_ranges(substrate, i, bounds$from, bounds$to)$start) == 1L, TRUE)
  no_terminal <- !apply(term$asserted, 1L, any) & !apply(term$sticky[, calc, drop = FALSE], 1L, any)
  out <- list()
  for (d in seq_along(certified)) {
    cert <- certified[[d]]
    fields <- cert$declarations$required_fields
    finite <- Reduce(`&`, lapply(fields, function(f) is.finite(substrate$bars[[f]][, calc, drop = FALSE])))
    avail <- expected[, calc, drop = FALSE] & finite
    full <- apply(avail, 1L, all)
    block <- apply(avail, 1L, function(a) { w <- which(a); length(w) > 0L && (max(w) - min(w) + 1L) == length(w) })
    certified_row <- cert$certification %in% c("builtin", "catalogue")
    out[[d]] <- data.frame(def = names(certified)[[d]], instrument = seq_len(n_inst),
      certification = cert$certification, one_range = one_range, no_terminal = no_terminal,
      full = full, block = block,
      conservative = certified_row & one_range & no_terminal & full,
      relaxed = certified_row & one_range & no_terminal & block, stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}

# ---- the direct calculation for admitted cells --------------------------------
# One adapter call per (definition, instrument) over the admitted block, the
# segment record derived from the block. No segment machinery, no treatment.
direct_cell <- function(substrate, cert, i, cols) {
  def <- cert$def
  stable_after <- as.integer(def$stable_after)
  width <- as.integer(def$requires_bars)
  m <- length(cols)
  if (m == 0L) return(list(value = numeric(), segment = NULL))
  # A block shorter than stable_after never becomes ready: the general path
  # makes no adapter call for it, and TTR refuses a window longer than its
  # input (found by the first gate_count run on the corpus short substrate).
  if (m < stable_after) {
    return(list(value = rep(NA_real_, m), segment = c(start = cols[[1L]], ready = NA_integer_, end = cols[[m]])))
  }
  x <- as.numeric(substrate$bars$close[i, cols])
  v <- if (identical(cert$kind, "sma")) {
    ns$ledgr_strict_sma_series(x, width)
  } else if (identical(cert$kind, "ttr")) {
    raw <- ns$ledgr_ttr_raw_call(NULL, def$params, cert$ttr_fn, x)
    ns$ledgr_normalize_feature_series_output(
      ns$ledgr_ttr_select_output(raw, def$params$output, def$params$ttr_fn), m, stable_after, def$id)
  } else stop("direct path covers sma and ttr close rows only: ", cert$kind)
  v[seq_len(m) < stable_after] <- NA_real_
  list(value = v, segment = c(start = cols[[1L]], ready = if (m >= stable_after) cols[[stable_after]] else NA_integer_,
                              end = cols[[m]]))
}

# The direct path over every admitted cell: value matrices and segment records.
direct_compute <- function(substrate, certified, bounds, cells, rule = "conservative") {
  n_inst <- length(substrate$instrument_ids); n_axis <- length(substrate$axis)
  calc <- seq.int(bounds$from, bounds$to)
  out <- lapply(certified, function(cert) matrix(NA_real_, nrow = n_inst, ncol = n_axis))
  segs <- list()
  for (d in seq_along(certified)) {
    adm <- cells$instrument[cells$def == names(certified)[[d]] & cells[[rule]]]
    if (!length(adm)) next
    fields <- certified[[d]]$declarations$required_fields
    finite <- Reduce(`&`, lapply(fields, function(f) is.finite(substrate$bars[[f]][adm, calc, drop = FALSE])))
    for (k in seq_along(adm)) {
      i <- adm[[k]]
      cols <- calc[finite[k, ]]
      r <- direct_cell(substrate, certified[[d]], i, cols)
      if (is.null(r$segment)) next
      out[[d]][i, cols] <- r$value
      segs[[length(segs) + 1L]] <- c(def = d, instrument = i, r$segment)
    }
  }
  list(values = out, segments = if (length(segs)) do.call(rbind, segs) else NULL)
}

# The general path's answer for one cell: value row and segment records, from
# the package's own calculate and plane-exception code.
general_cell <- function(substrate, cert, i, bounds) {
  fields <- ns$ledgr_history_feature_fields(list(cert))
  inputs <- ns$ledgr_history_feature_inputs(substrate, i, bounds$to, substrate$axis[[bounds$to]], fields)
  calculated <- ns$ledgr_history_feature_calculate(cert, inputs, bounds$from, substrate$history_policy$output_carry,
                                                   new.env(hash = TRUE, parent = emptyenv()))
  keep <- seq.int(bounds$from, bounds$to)
  ex <- ns$ledgr_feature_plane_exceptions(cert, inputs, calculated, bounds$from, keep)
  list(value = calculated$value, exceptions = ex)
}

# Median seconds per call. Each sample repeats the call until it lasts at least
# 0.25 s, so the ~10 ms Windows timer does not dominate short calls.
time_median <- function(f, reps) {
  t0 <- proc.time()[["elapsed"]]; f(); first <- proc.time()[["elapsed"]] - t0
  inner <- max(1L, as.integer(ceiling(0.25 / max(first, 0.002))))
  stats::median(vapply(seq_len(reps), function(r) {
    t0 <- proc.time()[["elapsed"]]
    for (k in seq_len(inner)) f()
    (proc.time()[["elapsed"]] - t0) / inner
  }, 0))
}
