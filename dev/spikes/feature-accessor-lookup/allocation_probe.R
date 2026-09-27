# Allocation probe for the feature-accessor lookup spike (supplementary to the
# runner). For each universe width it captures the real fast-context accessor
# inputs from a run that stops as soon as the context is built, builds both
# arms' accessors, and records R-heap allocation with Rprofmem for:
#   build     constructing ctx$feature() and ctx$features() once;
#   features  ctx$features(id) for every instrument on 10 pulses;
#   feature   ctx$feature(id, feature_id) for every instrument and both features on 10 pulses.
# Rprofmem sees R-heap allocations only; it is not peak memory.
#
# Usage, from the repository root:
#   Rscript dev/spikes/feature-accessor-lookup/allocation_probe.R [--out <dir>]

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
spike_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
out_dir <- arg_value("--out", file.path(spike_dir, "evidence"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
source(file.path(spike_dir, "seam.R"))
arms <- list(base = NULL, prepared = fl_prepared_functions(ns))
stopifnot(capabilities("profmem"))

capture_inputs <- function(n) {
  bars <- as.data.frame(ledgr_sim_bars(n_instruments = n, n_days = 100L, seed = 20260530L))
  path <- tempfile(fileext = ".duckdb")
  snap <- ledgr_snapshot_from_df(bars, db_path = path, snapshot_id = "alloc")
  on.exit({ ledgr_snapshot_close(snap); unlink(path) }, add = TRUE)
  exp <- ledgr_experiment(snap, ledgr_demo_sma_crossover_strategy(),
    features = ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n"))),
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero())
  holder <- new.env()
  original <- get("ledgr_projection_feature_bundle_accessor_state", envir = ns)
  capture <- function(projection, state, universe, feature_ids = NULL, active_alias_map = NULL) {
    holder$args <- list(projection = projection, universe = universe, feature_ids = feature_ids, active_alias_map = active_alias_map)
    stop(structure(class = c("allocation_probe_captured", "error", "condition"), list(message = "captured", call = NULL)))
  }
  tryCatch(suppressWarnings(suppressMessages(fl_with(ns, list(ledgr_projection_feature_bundle_accessor_state = capture),
    ledgr_run(exp, params = list(qty = 1, threshold = 0), feature_params = list(fast_n = 5L, slow_n = 10L),
      run_id = "alloc", seed = 1L)))), error = function(e) if (is.null(holder$args)) stop(e))
  holder$args
}
profile_bytes <- function(fun) {
  invisible(gc()); tf <- tempfile()
  utils::Rprofmem(tf, threshold = 0)
  t0 <- Sys.time(); res <- fun(); t1 <- Sys.time()
  utils::Rprofmem(NULL)
  lines <- readLines(tf); unlink(tf)
  big <- grep("^[0-9]+ :", lines, value = TRUE)
  invisible(gc()); u0 <- Sys.time(); invisible(fun()); u1 <- Sys.time()   # unprofiled pass for the clock
  list(bytes = sum(as.numeric(sub(" :.*$", "", big))), events = length(big),
    pages = sum(grepl("^new page", lines)), seconds = as.numeric(u1 - u0, units = "secs"), value = res)
}

rows <- list()
for (n in c(10L, 50L, 150L, 500L)) {
  a <- capture_inputs(n)
  u <- a$universe; fids <- a$feature_ids
  pulses <- unique(round(seq(20L, ncol(a$projection$feature_values[[fids[[1L]]]]), length.out = 10L)))
  for (arm in names(arms)) {
    built <- NULL
    build <- profile_bytes(function() fl_with(ns, arms[[arm]], {
      state <- new.env(parent = emptyenv()); state$pulse_idx <- 1L
      built <<- list(state = state,
        feature = get("ledgr_projection_feature_accessor_state", envir = ns)(a$projection, state, a$feature_ids),
        features = get("ledgr_projection_feature_bundle_accessor_state", envir = ns)(a$projection, state, u,
          a$feature_ids, a$active_alias_map))
      NULL
    }))
    features <- profile_bytes(function() {
      out <- 0
      for (p in pulses) { built$state$pulse_idx <- p; for (id in u) out <- out + sum(built$features(id), na.rm = TRUE) }
      out
    })
    feature <- profile_bytes(function() {
      out <- 0
      for (p in pulses) { built$state$pulse_idx <- p; for (id in u) for (f in fids) out <- out + sum(built$feature(id, f), na.rm = TRUE) }
      out
    })
    calls <- c(build = 1, features = length(pulses) * length(u), feature = length(pulses) * length(u) * length(fids))
    for (what in names(calls)) {
      m <- list(build = build, features = features, feature = feature)[[what]]
      rows[[length(rows) + 1L]] <- data.frame(instruments = n, arm = arm, operation = what, calls = calls[[what]],
        allocated_bytes = m$bytes, bytes_per_call = round(m$bytes / calls[[what]], 1), allocation_events = m$events,
        small_vector_pages = m$pages, microseconds_per_call = round(1e6 * m$seconds / calls[[what]], 2),
        checksum = if (is.null(m$value)) NA_real_ else round(m$value, 6))
    }
  }
}
out <- do.call(rbind, rows)
utils::write.csv(out, file.path(out_dir, "allocation.csv"), row.names = FALSE)
print(out, row.names = FALSE)
