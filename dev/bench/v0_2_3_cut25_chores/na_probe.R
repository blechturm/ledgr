# Cut 25 measuring step: post-warmup NA, NaN and Inf in indicator output.
#
# For each path (scalar fn alone; series_fn with a matching fn) and each bad
# value, from the fourth session on, records what a durable run and a sweep
# do: completed or the refusal class, what the strategy read, the run
# status, and the frame-evidence missing_reason over the sessions.
#
#   Rscript dev/bench/v0_2_3_cut25_chores/na_probe.R --source=<tree> --out=<csv>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  tree <- arg("source")
  out <- arg("out")
  pkgload::load_all(tree, quiet = TRUE, helpers = FALSE)
  for (h in c("helper-availability-runtime.R", "helper-indicator-history.R")) {
    sys.source(file.path(tree, "tests", "testthat", h), envir = environment())
  }
  commit <- system2("git", c("-C", tree, "rev-parse", "HEAD"), stdout = TRUE)
  dirty <- length(system2("git", c("-C", tree, "status", "--porcelain", "--", "R"), stdout = TRUE)) > 0L

  bad_values <- list(na = NA_real_, nan = NaN, inf = Inf)
  definition <- function(path, bad) {
    scalar <- function(window, params) {
      x <- window$close[[nrow(window)]]
      if (x > 103) switch(params$bad, na = NA_real_, nan = NaN, inf = Inf) else x
    }
    if (identical(path, "fn")) {
      ledgr_indicator("probe", fn = scalar, requires_bars = 1L, params = list(bad = names(bad_values)[vapply(bad_values, identical, TRUE, bad)]))
    } else {
      ledgr_indicator("probe", fn = scalar, requires_bars = 1L, params = list(bad = names(bad_values)[vapply(bad_values, identical, TRUE, bad)]),
                      series_fn = function(bars, params) ifelse(bars$close > 103, switch(params$bad, na = NA_real_, nan = NaN, inf = Inf), bars$close))
    }
  }
  outcome <- function(expr) {
    r <- tryCatch(expr, error = identity)
    if (inherits(r, "error")) paste(class(r)[class(r) != "error" & class(r) != "rlang_error" & class(r) != "condition"], collapse = "/")
    else "completed"
  }
  rows <- list()
  for (path in c("fn", "series_fn")) {
    for (bad in names(bad_values)) {
      def <- definition(path, bad_values[[bad]])
      snapshot <- availability_runtime_fixture(days = 8L)
      seen <- new.env(parent = emptyenv())
      seen$x <- numeric()
      exp <- ledgr_experiment(
        opening = ledgr_opening(cash = 100000), snapshot,
        function(ctx, params) {
          seen$x <- c(seen$x, ctx[["probe"]][["AAA"]])
          ctx$hold()
        },
        features = list(def),
        valuation_policy = ledgr_valuation_stale(1L),
        cost_model = ledgr_cost_zero()
      )
      run_id <- paste(path, bad, sep = "-")
      run <- outcome({ bt <- ledgr_run(exp, run_id = run_id); close(bt); bt })
      status <- tryCatch(ledgr_run_info(snapshot, run_id)$status, error = function(e) "none")
      read <- paste(format(seen$x), collapse = " ")
      seen$x <- numeric()
      sweep <- outcome(ledgr_sweep(exp, ledgr_grid_named(one = list(strategy = list())), stop_on_error = TRUE))
      ledgr_snapshot_close(snapshot)
      levels <- ws43_history_substrate(c(100, 101, 102, 103, 104, 105))
      ev <- tryCatch({
        values <- ledgr_history_compute_feature_series(levels, list(feature = def), calculation_start = NULL)
        projection <- ledgr_projection_from_feature_matrix(values, universe = levels$instrument_ids,
          pulses_posix = levels$axis, feature_engine_version = "probe")
        bound <- ledgr_history_substrate_bind_features(levels, projection)
        n <- length(levels$axis)
        e <- ledgr_history_feature_evidence(bound, "feature", 1L, seq_len(n), n)
        paste(ifelse(nzchar(e$missing_reason), e$missing_reason, "-"), collapse = " ")
      }, error = function(e) paste("refused:", class(e)[[1L]]))
      rows[[length(rows) + 1L]] <- data.frame(
        commit = commit, r_dirty = dirty, path = path, bad = bad,
        run = run, run_status = status, strategy_read = read, sweep = sweep, evidence = ev
      )
    }
  }
  res <- do.call(rbind, rows)
  utils::write.csv(res, out, row.names = FALSE)
  print(res[, c("path", "bad", "run", "run_status", "sweep", "evidence")])
})
