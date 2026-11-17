# Candidate 5's memory rule (Cut 22 decision 3a, LDG-3252), as declared in
# dev/bench/timing/protocols/cut22-feature-1/protocol.md before any run.
# Matched arms (installed libraries differing only by candidate 5); every
# observation is one fresh child process:
#
#   heap        peak R heap of sequential sweep feature preparation: the
#               arm's own sweep code (the precompute-free branch of
#               ledgr_sweep_impl(), taken from the loaded package and run with
#               workers = 1), fixtures prepared before the phase,
#               gc(reset = TRUE) at its start, the projection retained at its
#               end, then sum(gc()[, "max used"] * c(56, 8)) bytes. Not
#               process memory.
#   heap_extra  the same with an extra live 8 MiB raw vector inside the phase
#               (sensitivity).
#   bytes       the whole ledgr_precompute_features() object: object.size()
#               and length(serialize()).
#
# Cells 500x1260 and 1166x252 (the r_floor fixture of protocol
# cut22-feature-1, the six sweep definitions TTR SMA 3..40, a two-candidate
# grid). Heap: 8 children per arm and cell in alternating order (base first
# in odd pairs); heap_extra: 2 per arm and cell; bytes: 1 per arm and cell.
#
#   Rscript memory.R --base=<lib> --candidate=<lib> --work=<dir> --out=<dir>
#   Rscript memory.R --child --lib=<lib> --shape=<n x m> --measure=<heap|heap_extra|bytes> --work=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else NULL
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  if ("--child" %in% argv) {
    lib <- normalizePath(arg("lib"), winslash = "/")
    suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
    ns <- asNamespace("ledgr")
    work <- arg("work")
    dir.create(work, recursive = TRUE, showWarnings = FALSE)
    dims <- as.integer(strsplit(arg("shape"), "x", fixed = TRUE)[[1L]])
    bars <- ledgr::ledgr_sim_bars(dims[[1L]], dims[[2L]], seed = 20260530L, start = "2020-01-01",
                                  instrument_prefix = "P")
    bars$ts_utc <- bars$ts_utc + 21 * 3600
    for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
    bars <- bars[order(bars$instrument_id, bars$ts_utc, method = "radix"), ]
    store <- file.path(work, "store.duckdb")
    ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(bars, db_path = store, snapshot_id = "cut22m",
                                                              price_basis = "split_adjusted"))
    snapshot <- ledgr::ledgr_snapshot_open(store, "cut22m", verify = TRUE)
    widths <- c(3, 5, 8, 12, 20, 40)
    sma <- function(n) ledgr::ledgr_ind_ttr("SMA", input = "close", id = paste0("sma_", n), n = as.integer(n))
    exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
      features = do.call(ledgr::ledgr_feature_map, stats::setNames(lapply(widths, sma), paste0("sma_", widths))),
      opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero())
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(q = 1)), b = list(strategy = list(q = 2)))
    measure <- arg("measure")
    value <- if (identical(measure, "bytes")) {
      obj <- ledgr::ledgr_precompute_features(exp, grid)
      c(object_size = as.numeric(utils::object.size(obj)), serialized = length(serialize(obj, NULL)))
    } else {
      # The arm's own sweep feature preparation, from its ledgr_sweep_impl().
      find_branch <- function(x) {
        if (!is.call(x)) return(NULL)
        if (identical(x[[1L]], as.name("if")) && identical(x[[2L]], quote(is.null(precomputed_features)))) return(x[[3L]])
        for (part in as.list(x)[-1L]) {
          hit <- find_branch(part)
          if (!is.null(hit)) return(hit)
        }
        NULL
      }
      branch <- find_branch(body(ns$ledgr_sweep_impl))
      if (is.null(branch)) stop("memory.R: the sweep's feature branch was not found")
      meta <- ns$ledgr_precompute_snapshot_meta(snapshot)
      range <- ns$ledgr_precompute_scoring_range(meta, exp = exp)
      env <- new.env(parent = ns)
      env$exp <- exp
      env$param_grid <- ns$ledgr_executable_grid_normalize(grid)
      env$history_substrate <- ns$ledgr_history_substrate_for_experiment(exp, meta, end = range$scoring_end,
                                                                         coverage_start = range$scoring_start)
      env$history_axis <- env$history_substrate$axis
      env$range <- range
      env$workers <- 1L
      invisible(gc(reset = TRUE))
      extra <- if (identical(measure, "heap_extra")) raw(8L * 1024L * 1024L) else raw(0L)
      eval(branch, env)
      heap <- gc()
      stopifnot(inherits(env$runtime_projection, "ledgr_runtime_projection"), length(extra) >= 0L)
      c(peak_heap = sum(heap[, "max used"] * c(56, 8)))
    }
    ledgr::ledgr_snapshot_close(snapshot)
    cat(paste0("RESULT ", names(value), "=", sprintf("%.0f", value)), sep = "\n")
    return(invisible())
  }

  libs <- c(base = arg("base"), candidate = arg("candidate"))
  out <- arg("out")
  work <- arg("work")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  rows <- list()
  child <- function(arm, shape, measure, k) {
    wd <- file.path(work, paste(arm, shape, measure, k, sep = "_"))
    unlink(wd, recursive = TRUE)
    res <- system2(rscript, c(file.path(here, "memory.R"), "--child", paste0("--lib=", libs[[arm]]),
                              paste0("--shape=", shape), paste0("--measure=", measure), paste0("--work=", wd)),
                   stdout = TRUE, stderr = FALSE)
    hit <- grep("^RESULT ", res, value = TRUE)
    if (!length(hit)) stop("memory.R child failed: ", arm, " ", shape, " ", measure)
    kv <- strsplit(sub("^RESULT ", "", hit), "=", fixed = TRUE)
    for (p in kv) rows[[length(rows) + 1L]] <<- data.frame(arm = arm, lib = libs[[arm]], shape = shape,
      measure = measure, child = k, metric = p[[1L]], bytes = as.numeric(p[[2L]]), stringsAsFactors = FALSE)
    cat(arm, shape, measure, k, paste(sub("^RESULT ", "", hit), collapse = " "), "\n")
  }
  for (shape in c("500x1260", "1166x252")) {
    for (k in 1:8) {
      order <- if (k %% 2L == 1L) c("base", "candidate") else c("candidate", "base")
      for (arm in order) child(arm, shape, "heap", k)
    }
    for (k in 1:2) for (arm in c("base", "candidate")) child(arm, shape, "heap_extra", k)
    for (arm in c("base", "candidate")) child(arm, shape, "bytes", 1L)
  }
  raw_rows <- do.call(rbind, rows)
  utils::write.csv(raw_rows, file.path(out, "memory_raw.csv"), row.names = FALSE)
  med <- stats::aggregate(bytes ~ arm + shape + measure + metric, raw_rows, stats::median)
  wide <- stats::reshape(med, idvar = c("shape", "measure", "metric"), timevar = "arm", direction = "wide")
  names(wide) <- sub("^bytes[.]", "", names(wide))
  wide$change_pct <- round(100 * (wide$candidate / wide$base - 1), 2)
  utils::write.csv(wide, file.path(out, "memory_summary.csv"), row.names = FALSE)
  print(wide, row.names = FALSE)
  heap <- wide[wide$measure == "heap", ]
  bytes <- wide[wide$measure == "bytes", ]
  extra <- merge(wide[wide$measure == "heap_extra", c("shape", "base", "candidate")],
                 heap[, c("shape", "base", "candidate")], by = "shape", suffixes = c("_extra", ""))
  sensitive <- all(extra$base_extra - extra$base > 8e6 & extra$candidate_extra - extra$candidate > 8e6)
  # Spread of the 8 heap children per arm and cell, to judge noise.
  spread <- stats::aggregate(bytes ~ arm + shape, raw_rows[raw_rows$measure == "heap", ], function(x) diff(range(x)))
  names(spread)[[3L]] <- "heap_range_bytes"
  print(spread, row.names = FALSE)
  utils::write.csv(spread, file.path(out, "memory_spread.csv"), row.names = FALSE)
  keep <- all(bytes$candidate < bytes$base) && all(heap$candidate < heap$base)
  cat("sensitivity (extra 8 MiB raises the peak on every arm and cell):", sensitive, "\n")
  cat("object bytes lower on every cell:", all(bytes$candidate < bytes$base), "\n")
  cat("median peak R heap lower on every cell:", all(heap$candidate < heap$base), "\n")
  cat(if (keep && sensitive) "MEMORY KEEP" else "MEMORY NOT KEPT", "\n")
})
