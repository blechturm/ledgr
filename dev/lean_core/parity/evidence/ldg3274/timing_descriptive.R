# LDG-3274 (Cut 26 decision 10, cut review 26 R8): descriptive timing, not
# gated. One sweep selecting compiled_accounting_model = "spot_fifo" and one
# two-worker sweep, the pin against the lean loop (debug off, inert hooks as
# in production), alternating arms, from a directory outside any source
# package. The worker sweep's harness worker-loading cost (every worker
# sourcing and installing the lean core) is timed on its own.
#
#   Rscript timing_descriptive.R --lib=<pin library> --out=<csv> [--reps=5]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (!length(hit)) return(default)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  repo <- normalizePath(file.path(here, "..", "..", "..", "..", ".."), winslash = "/")
  lib <- normalizePath(arg("lib"), winslash = "/", mustWork = TRUE)
  out <- normalizePath(arg("out"), winslash = "/", mustWork = FALSE)
  reps <- as.integer(arg("reps", "5"))
  source(file.path(repo, "dev", "lean_core", "load.R"))
  lean <- lean_core_load(lib, debug = FALSE)
  ns <- asNamespace("ledgr")
  source(file.path(repo, "dev", "spikes", "r_floor", "fixture.R"), local = TRUE)
  wd <- tempfile("ldg3274_timing_")
  dir.create(wd)
  setwd(wd)
  db <- file.path(wd, "t.duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(r_floor_fixture(10L, 2000L)$bars, db_path = db,
    snapshot_id = "t", price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(db, "t", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- r_floor_transition
  environment(strategy) <- ns
  exp <- ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
  grid <- ledgr::ledgr_grid_named(a = list(strategy = list(k = 1)), b = list(strategy = list(k = 2)),
                                  c = list(strategy = list(k = 3)), d = list(strategy = list(k = 4)))
  pre <- ledgr::ledgr_precompute_features(exp, grid)
  shapes <- list(
    selected = function() ledgr::ledgr_sweep(exp, grid, precomputed_features = pre, seed = 1L,
                                            compiled_accounting_model = "spot_fifo"),
    workers = function() ledgr::ledgr_sweep(exp, grid, precomputed_features = pre, seed = 1L, workers = 2L))
  # The worker-loading cost: each worker times the expression
  # lean_worker_setup() sends it (sourcing and installing the lean core) and
  # writes the seconds to its own file; everywhere() returns before the
  # workers finish, so the parent cannot time it. Only the lean environment
  # is shadowed (the pin's own setup calls the namespace binding).
  boot <- new.env()
  boot$dir <- file.path(wd, "boot")
  dir.create(boot$dir)
  boot_seconds <- function() {
    f <- list.files(boot$dir, full.names = TRUE)
    # the slowest worker: the wall-clock delay before every worker can run
    s <- max(c(0, vapply(f, function(x) as.numeric(readLines(x, warn = FALSE)), 0)))
    file.remove(f)
    s
  }
  inner_everywhere <- get("ledgr_parallel_mirai_everywhere_expr", envir = ns)
  lean$ledgr_parallel_mirai_everywhere_expr <- function(expr, workers = 1L) {
    inner_everywhere(substitute({
      .boot_t0 <- proc.time()[["elapsed"]]
      EXPR
      writeLines(format(proc.time()[["elapsed"]] - .boot_t0, digits = 6), tempfile(tmpdir = DIR))
    }, list(EXPR = expr, DIR = boot$dir)), workers = workers)
  }
  rows <- list()
  digest_of <- function(x) digest::digest(as.data.frame(x)[, c("candidate_id", "status", "final_equity", "n_trades")],
                                          algo = "sha256")
  for (shape in names(shapes)) for (r in seq_len(reps)) for (arm in if (r %% 2L) c("pin", "lean") else c("lean", "pin")) {
    restore <- if (arm == "lean") lean$lean_loop_install(hooks = FALSE) else function() NULL
    invisible(boot_seconds())
    t0 <- proc.time()[["elapsed"]]
    res <- tryCatch(shapes[[shape]](), finally = restore())
    s <- proc.time()[["elapsed"]] - t0
    rows[[length(rows) + 1L]] <- data.frame(shape = shape, rep = r, arm = arm, seconds = s,
      worker_loading_s = boot_seconds(), result = substr(digest_of(res), 1L, 12L),
      stringsAsFactors = FALSE)
    cat(sprintf("%s rep %d %s: %.2f s (worker loading %.2f s)\n", shape, r, arm, s, rows[[length(rows)]]$worker_loading_s))
  }
  res <- do.call(rbind, rows)
  utils::write.csv(res, out, row.names = FALSE)
  agg <- stats::aggregate(cbind(seconds, worker_loading_s) ~ shape + arm, res, stats::median)
  print(agg)
  same <- tapply(res$result, res$shape, function(x) length(unique(x)) == 1L)
  cat("results identical across arms:", paste(names(same), same, collapse = ", "), "\n")
})
