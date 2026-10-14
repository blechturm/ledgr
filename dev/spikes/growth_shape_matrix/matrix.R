# Growth-shape matrix spike (spike_protocol.md). Binds nothing.
#
# Times feature kind x execution mode x entry point at two or three sizes per growth
# axis (bars per instrument T, instruments N, sweep candidates C), one fresh
# process per (feature, mode, size point), and appends one row per measured
# phase to <out_dir>/timings.csv. check.R turns the rows into exponents.
#
#   Rscript matrix.R <repo> <out_dir> run [reps=2] [features=a,b] [modes=a,b] [points=a,b]
#   Rscript matrix.R <repo> <out_dir> child <feature> <mode> <point> <entries>
#   Rscript matrix.R <repo> <out_dir> profile <feature> <mode> <point>

`%||%` <- function(x, y) if (is.null(x)) y else x

GSM_CAP_S <- 60
GSM_POINTS <- list(
  base = c(T = 250L, N = 20L, C = 2L),
  T = c(T = 1000L, N = 20L, C = 2L),
  N = c(T = 250L, N = 80L, C = 2L),
  C = c(T = 250L, N = 20L, C = 8L),
  # Third sizes, added after the first runs showed no superlinear cell.
  T2 = c(T = 4000L, N = 20L, C = 2L),
  N2 = c(T = 250L, N = 320L, C = 2L),
  C2 = c(T = 250L, N = 20L, C = 32L)
)
GSM_FEATURES <- c("none", "builtin", "ttr", "ttr_bbands", "custom")
GSM_MODES <- c("dense", "availability")
# Entries per point; the C point only exercises the sweep.
GSM_ENTRIES <- list(base = c("run", "sweep", "wf"), T = c("run", "sweep", "wf"),
                    N = c("run", "sweep", "wf"), C = "sweep",
                    T2 = "run", N2 = "run", C2 = "sweep")

# ---- fixtures ---------------------------------------------------------------

gsm_bars <- function(T, N) {
  as.data.frame(ledgr_sim_bars(n_instruments = N, n_days = T, seed = 20261014L,
                               instrument_prefix = "G_"))
}

# Implied calendar copied from the one-execution-mode probe
# (oem_implied_sessions): one open session per bar timestamp, opening one
# second before it on the same civil date in `timezone`. Midnight-UTC sim
# bars need venue zone Etc/GMT+1 so the open precedes the close.
gsm_sessions <- function(bars, timezone = "Etc/GMT+1", open_lead = 1) {
  closes <- sort(unique(as.POSIXct(bars$ts_utc, tz = "UTC")))
  local_date <- as.Date(format(closes, "%Y-%m-%d", tz = timezone))
  civil <- seq(min(local_date), max(local_date), by = "day")
  at <- match(civil, local_date)
  close_ts <- closes[at]
  data.frame(session_date = civil, status = ifelse(is.na(at), "closed", "open"),
             session_open = close_ts - open_lead, session_close = close_ts,
             knowledge_time = as.POSIXct(paste(min(civil) - 3, "00:00:00"), tz = "UTC"),
             source = "implied_from_bar_timestamps", stringsAsFactors = FALSE)
}

gsm_seal <- function(bars, mode, db_path) {
  unlink(c(db_path, paste0(db_path, ".wal")))
  ids <- sort(unique(as.character(bars$instrument_id)))
  args <- list(bars, instruments_df = data.frame(instrument_id = ids),
               db_path = db_path, snapshot_id = paste0("gsm_", mode))
  if (identical(mode, "availability")) {
    args$facts <- ledgr_facts(ledgr_facts_sessions(gsm_sessions(bars), "IMPLIED",
                                                   timezone = "Etc/GMT+1"))
  }
  do.call(ledgr_snapshot_from_df, args)
}

# ---- feature kinds ----------------------------------------------------------

# Custom user indicator in the documented scalar-window form.
gsm_custom <- function(id, n) {
  ledgr_indicator(id = id, fn = function(window, params) mean(utils::tail(window$close, params$n)),
                  requires_bars = n, params = list(n = n), gap_contract = "strict_window")
}

# Gut: the same custom indicator plus a vectorised series_fn carrying a
# deliberately quadratic step (an n x n outer product per instrument).
gsm_custom_quad <- function(id, n) {
  ledgr_indicator(
    id = id, fn = function(window, params) mean(utils::tail(window$close, params$n)),
    series_fn = function(bars, params) {
      x <- bars$close
      junk <- 0
      for (k in seq_len(params$reps)) junk <- junk + sum(outer(x, x, "-") > 0)
      as.numeric(stats::filter(x, rep(1 / params$n, params$n), sides = 1)) + 0 * junk
    },
    requires_bars = n, params = list(n = n, reps = 6L), gap_contract = "strict_window")
}

# Returns list(features, fast, slow): the feature map and the ids the
# crossover strategy reads. "none" reads closes instead of features.
gsm_features <- function(kind) {
  switch(kind,
    none = list(features = list(), fast = NULL, slow = NULL),
    builtin = list(features = ledgr_feature_map(fast = ledgr_ind_sma(5L), slow = ledgr_ind_sma(10L),
                                                ret = ledgr_ind_returns(5L)),
                   fast = "sma_5", slow = "sma_10"),
    ttr = list(features = ledgr_feature_map(
      fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
      fast = "fast", slow = "slow"),
    ttr_bbands = list(features = ledgr_feature_map(
      fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr_ind_ttr("BBands", input = "close", output = "mavg", id = "slow", n = 10L)),
      fast = "fast", slow = "slow"),
    custom = list(features = ledgr_feature_map(fast = gsm_custom("fast", 5L), slow = gsm_custom("slow", 10L)),
                  fast = "fast", slow = "slow"),
    custom_quad = list(features = ledgr_feature_map(fast = gsm_custom("fast", 5L),
                                                    slow = gsm_custom_quad("slow", 10L)),
                       fast = "fast", slow = "slow"),
    stop("Unknown feature kind: ", kind))
}

# Peer-benchmark crossover (one-execution-mode probe, oem_peer_strategy) with
# a sweepable threshold. Without features it crosses close over the previous
# close, so the baseline trades too.
gsm_strategy <- function(fast_id, slow_id) {
  force(fast_id); force(slow_id)
  function(ctx, params) {
    targets <- ctx$hold()
    thr <- params$thr %||% 0
    if (is.null(fast_id)) {
      instruments <- names(targets)
      fast <- as.numeric(ctx$vec$close)
      prev <- ctx$state_prev$close %||% list()
      slow <- if (length(prev)) as.numeric(unlist(prev[instruments], use.names = FALSE)) else rep(NA_real_, length(fast))
    } else {
      fw <- ctx$features_wide
      instruments <- as.character(fw$instrument_id)
      fast <- suppressWarnings(as.numeric(fw[[fast_id]]))
      slow <- suppressWarnings(as.numeric(fw[[slow_id]]))
    }
    n <- length(instruments)
    current_above <- is.finite(fast) & is.finite(slow) & fast > slow * (1 + thr)
    prev_above <- ctx$state_prev$above %||% list()
    was_above <- rep(FALSE, n)
    if (length(prev_above)) {
      idx <- match(instruments, names(prev_above))
      ok <- !is.na(idx)
      was_above[ok] <- as.logical(unlist(prev_above[idx[ok]], use.names = FALSE))
      was_above[is.na(was_above)] <- FALSE
    }
    if (any(current_above & !was_above)) targets[instruments[current_above & !was_above]] <- 1
    if (any(!current_above & was_above)) targets[instruments[!current_above & was_above]] <- 0
    state <- list(above = as.list(stats::setNames(current_above, instruments)))
    if (is.null(fast_id)) state$close <- as.list(stats::setNames(fast, instruments))
    list(targets = targets, state_update = state)
  }
}

gsm_experiment <- function(snap, kind, mode, ids) {
  f <- gsm_features(kind)
  args <- list(snapshot = snap, strategy = gsm_strategy(f$fast, f$slow), features = f$features,
               opening = ledgr_opening(cash = 1e7), universe = ids, cost_model = ledgr_cost_zero())
  if (identical(mode, "availability")) args$valuation_policy <- ledgr_valuation_stale(0, "refuse")
  do.call(ledgr_experiment, args)
}

gsm_grid <- function(C) {
  do.call(ledgr_param_grid, lapply(seq_len(C), function(k) list(thr = (k - 1) * 0.0005)))
}

# Three contiguous rolling folds: train 40% of the calendar span, test 19%.
gsm_folds <- function(bars) {
  d <- sort(unique(as.Date(bars$ts_utc)))
  span <- as.numeric(max(d) - min(d))
  ledgr_folds_rolling(start = min(d), end = max(d),
                      train_window = sprintf("%d days", floor(span * 0.40)),
                      test_window = sprintf("%d days", floor(span * 0.19)))
}

# ---- one child: one (feature, mode, size point) -----------------------------

gsm_emit <- function(entry, phase, seconds, status = "ok", note = "") {
  cat(sprintf("GSM\t%s\t%s\t%.4f\t%s\t%s\n", entry, phase, seconds, status, gsub("[\t\n]", " ", note)))
}

# Times expr under the per-entry cap; returns list(value, s, status, note).
gsm_timed <- function(expr) {
  t0 <- proc.time()[["elapsed"]]
  setTimeLimit(elapsed = GSM_CAP_S, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf), add = TRUE)
  value <- tryCatch(suppressWarnings(force(expr)), error = identity)
  setTimeLimit(elapsed = Inf)
  s <- proc.time()[["elapsed"]] - t0
  if (inherits(value, "error")) {
    msg <- conditionMessage(value)
    status <- if (grepl("elapsed time limit", msg)) "CAP" else "ERROR"
    return(list(value = NULL, s = s, status = status, note = substr(msg, 1, 160)))
  }
  list(value = value, s = s, status = "ok", note = "")
}

gsm_run_entry <- function(exp, tag) {
  ledgr_feature_cache_clear()
  r <- gsm_timed(ledgr_run(exp, run_id = paste0("gsm_", tag)))
  gsm_emit("run", "total", r$s, r$status, r$note)
  if (!identical(r$status, "ok")) return(invisible())
  bt <- r$value
  on.exit(close(bt), add = TRUE)
  tel <- ledgr_get_run_telemetry(bt$run_id)
  for (p in c("t_pre", "t_loop", "t_post")) gsm_emit("run", p, tel[[p]] %||% NA_real_)
  for (what in c("equity", "fills", "trades", "ledger")) {
    rr <- gsm_timed(ledgr_results(bt, what))
    gsm_emit("readers", what, rr$s, rr$status,
             if (identical(rr$status, "ok")) paste0("rows=", NROW(rr$value)) else rr$note)
  }
}

gsm_child <- function(kind, mode, point, entries, work) {
  size <- GSM_POINTS[[point]]
  # JIT warm-up on a tiny fixture of the same kind and mode.
  wb <- gsm_bars(60L, 3L)
  wsnap <- gsm_seal(wb, mode, file.path(work, "warm.duckdb"))
  wexp <- tryCatch(gsm_experiment(wsnap, kind, mode, sort(unique(wb$instrument_id))), error = identity)
  if (inherits(wexp, "error")) {
    ledgr_snapshot_close(wsnap)
    return(gsm_emit("experiment", "total", NA_real_, "REFUSED", paste(class(wexp)[[1L]], conditionMessage(wexp))))
  }
  invisible(tryCatch(close(suppressWarnings(ledgr_run(wexp, run_id = "warm"))), error = identity))
  ledgr_snapshot_close(wsnap)

  bars <- gsm_bars(size[["T"]], size[["N"]])
  s <- gsm_timed(gsm_seal(bars, mode, file.path(work, "snap.duckdb")))
  gsm_emit("seal", "total", s$s, s$status, s$note)
  if (!identical(s$status, "ok")) return(invisible())
  snap <- s$value
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  exp <- gsm_experiment(snap, kind, mode, sort(unique(bars$instrument_id)))
  if ("run" %in% entries) gsm_run_entry(exp, "main")
  if ("sweep" %in% entries) {
    ledgr_feature_cache_clear()
    r <- gsm_timed(ledgr_sweep(exp, gsm_grid(size[["C"]])))
    gsm_emit("sweep", "total", r$s, r$status, r$note)
  }
  if ("wf" %in% entries) {
    ledgr_feature_cache_clear()
    r <- gsm_timed(ledgr_walk_forward(exp, gsm_grid(size[["C"]]), gsm_folds(bars),
                                      ledgr_rule_argmax("sharpe_ratio"), seed = 1L))
    note <- if (identical(r$status, "ok")) paste0("folds=", nrow(r$value$folds), " status=", r$value$status) else r$note
    if (identical(r$status, "ok")) lapply(r$value$test_runs, close)
    gsm_emit("wf", "total", r$s, r$status, note)
  }
}

# Rprof over one ledgr_run() of a cell; writes the top functions by total
# time to <out_dir>/profile_<feature>_<mode>_<point>.csv.
gsm_profile <- function(kind, mode, point, out_dir, work) {
  size <- GSM_POINTS[[point]]
  bars <- gsm_bars(size[["T"]], size[["N"]])
  snap <- gsm_seal(bars, mode, file.path(work, "prof.duckdb"))
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  exp <- gsm_experiment(snap, kind, mode, sort(unique(bars$instrument_id)))
  prof <- file.path(work, "rprof.out")
  ledgr_feature_cache_clear()
  utils::Rprof(prof, interval = 0.01)
  bt <- suppressWarnings(ledgr_run(exp, run_id = "gsm_prof"))
  utils::Rprof(NULL)
  close(bt)
  s <- utils::summaryRprof(prof)$by.total
  s <- data.frame(fn = rownames(s), total_s = s$total.time, total_pct = s$total.pct,
                  self_s = s$self.time, row.names = NULL)
  s <- utils::head(s[!grepl("^\"(gsm_|ledgr_run|do.call|tryCatch|withCallingHandlers|suppressWarnings)", s$fn), ], 25L)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(s, file.path(out_dir, sprintf("profile_%s_%s_%s.csv", kind, mode, point)), row.names = FALSE)
  print(s, row.names = FALSE)
}

# ---- parent -----------------------------------------------------------------

gsm_spawn <- function(repo, out_dir, kind, mode, point, entries) {
  rscript <- file.path(R.home("bin"), "Rscript")
  # Children run a frozen copy: Rscript reads its file lazily, so editing
  # matrix.R during a batch would otherwise change running processes.
  script <- file.path(out_dir, "matrix_frozen.R")
  out <- suppressWarnings(system2(rscript, c(shQuote(script), shQuote(repo), shQuote(out_dir), "child",
                                             kind, mode, point, paste(entries, collapse = ",")),
                                  stdout = TRUE, stderr = FALSE, timeout = 900))
  lines <- grep("^GSM\t", out, value = TRUE)
  if (!length(lines)) {
    return(data.frame(entry = "child", phase = "total", seconds = NA_real_, status = "CHILD_FAILED",
                      note = substr(paste(utils::tail(out, 3), collapse = " | "), 1, 200)))
  }
  parts <- strsplit(sub("^GSM\t", "", lines), "\t", fixed = TRUE)
  data.frame(entry = vapply(parts, `[`, "", 1L), phase = vapply(parts, `[`, "", 2L),
             seconds = as.numeric(vapply(parts, `[`, "", 3L)), status = vapply(parts, `[`, "", 4L),
             note = vapply(parts, function(p) if (length(p) >= 5L) p[[5L]] else "", ""),
             stringsAsFactors = FALSE)
}

gsm_parent <- function(repo, out_dir, reps = 2L, kinds = GSM_FEATURES, modes = GSM_MODES,
                       points = names(GSM_POINTS)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  file.copy(file.path(repo, "dev/spikes/growth_shape_matrix/matrix.R"),
            file.path(out_dir, "matrix_frozen.R"), overwrite = TRUE)
  path <- file.path(out_dir, "timings.csv")
  # Resumable: a (rep, feature, mode, point) already recorded is skipped.
  done <- if (file.exists(path)) {
    d <- utils::read.csv(path, stringsAsFactors = FALSE)
    unique(paste(d$rep, d$feature, d$mode, d$point))
  } else character()
  for (rep in seq_len(reps)) {
    # Alternate size order across repetitions.
    order_pts <- if (rep %% 2L) points else rev(points)
    for (kind in kinds) for (mode in modes) for (point in order_pts) {
      if (paste(rep, kind, mode, point) %in% done) next
      t0 <- proc.time()[["elapsed"]]
      rows <- gsm_spawn(repo, out_dir, kind, mode, point, GSM_ENTRIES[[point]])
      size <- GSM_POINTS[[point]]
      rows <- data.frame(rep = rep, feature = kind, mode = mode, point = point,
                         T = size[["T"]], N = size[["N"]], C = size[["C"]], rows)
      utils::write.table(rows, path, sep = ",", row.names = FALSE, col.names = !file.exists(path),
                         append = file.exists(path), qmethod = "double")
      cat(sprintf("rep %d %-11s %-12s %-4s %6.1fs  %s\n", rep, kind, mode, point,
                  proc.time()[["elapsed"]] - t0,
                  paste(sprintf("%s/%s=%.2f%s", rows$entry, rows$phase, rows$seconds,
                                ifelse(rows$status == "ok", "", paste0("[", rows$status, "]"))),
                        collapse = " ")))
    }
  }
  invisible(path)
}

gsm_main <- function(args = commandArgs(TRUE)) {
  repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
  out_dir <- args[[2L]]
  if (args[[3L]] %in% c("child", "profile")) {
    suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
    work <- file.path(tempdir(), "gsm")
    dir.create(work, recursive = TRUE, showWarnings = FALSE)
    if (identical(args[[3L]], "profile")) return(gsm_profile(args[[4L]], args[[5L]], args[[6L]], out_dir, work))
    return(gsm_child(args[[4L]], args[[5L]], args[[6L]], strsplit(args[[7L]], ",")[[1L]], work))
  }
  opt <- function(name, default) {
    hit <- grep(paste0("^", name, "="), args, value = TRUE)
    if (length(hit)) strsplit(sub(paste0("^", name, "="), "", hit[[1L]]), ",")[[1L]] else default
  }
  gsm_parent(repo, out_dir, reps = as.integer(opt("reps", "2")), kinds = opt("features", GSM_FEATURES),
             modes = opt("modes", GSM_MODES), points = opt("points", names(GSM_POINTS)))
}

if (sys.nframe() == 0L) gsm_main()
