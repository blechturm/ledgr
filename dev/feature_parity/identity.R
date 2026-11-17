# Cut 22 decision 6 (LDG-3255): the identities a feature-engine change must
# leave unchanged, recorded on fixed inputs by one arm; identity_check.R
# compares two arms. Recorded (identities.csv, one name and value per row):
#   - base fingerprints, declared-session active fingerprints and stored
#     declarations of built-in, concrete TTR, parameterised TTR and bundled
#     TTR definitions;
#   - the emitted TTR fn and series_fn: deparsed bodies, formals, captures
#     (ledgr_function_fingerprint with captures), params and IDs;
#   - a bar-native and a declared-session experiment: each candidate's
#     feature_set_hash, alias_map_hash and feature params hash, the sweep's
#     feature_union_hash, a run's config_hash and the stored run's identity
#     columns;
#   - a walk-forward session: session_id, its candidate keys and fold keys;
#   - the engine version (expected to change: reported, not compared).
# --save-store also writes the bar-native explicit precompute object and
# keeps the store (with a durable sweep) at that path, for the other arm:
# --old=<dir> reads them back: the old precompute must refuse with
# ledgr_precomputed_engine_mismatch before any candidate, and the stored
# sweep and run stay readable with their recorded engine version.
#
#   Rscript identity.R --lib=<library> --out=<dir> [--save-store=1] [--old=<dir of the other arm>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
  }
  suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(arg("lib"), winslash = "/")))
  ns <- asNamespace("ledgr")
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  out <- arg("out")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  ns_env <- environment()
  source(file.path(here, "corpus.R"), local = TRUE)
  rows <- list()
  rec <- function(name, value) rows[[length(rows) + 1L]] <<- data.frame(name = name, value = paste(value, collapse = ";"),
                                                                       stringsAsFactors = FALSE)
  dig <- function(x) digest::digest(x, algo = "sha256")

  # ---- definitions and emitted closures ------------------------------------
  defs <- c(
    list(sma_20 = ledgr::ledgr_ind_sma(20), ema_5 = ledgr::ledgr_ind_ema(5), rsi_14 = ledgr::ledgr_ind_rsi(14),
         returns_5 = ledgr::ledgr_ind_returns(5),
         ttr_rsi = ledgr::ledgr_ind_ttr("RSI", input = "close", n = 14),
         ttr_atr = ledgr::ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 20),
         ttr_atr_sma = ledgr::ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 20, maType = "SMA"),
         ttr_mfi = ledgr::ledgr_ind_ttr("MFI", input = "hlcv", n = 14),
         ttr_unreg = ledgr::ledgr_ind_ttr("SMA", input = "close", n = 3L, requires_bars = 5L, id = "ttr_sma_unreg")),
    stats::setNames(ns$ledgr_indicator_bundle_indicators(ledgr::ledgr_ind_ttr_outputs("MACD", input = "close",
      nFast = 12, nSlow = 26, nSig = 9, percent = FALSE)), c("macd", "macd_signal", "macd_histogram")))
  for (k in names(defs)) {
    ind <- defs[[k]]
    def <- ns$ledgr_precompute_feature_def_from_indicator(ind)
    rec(paste0("fingerprint:", k), ns$ledgr_indicator_fingerprint(ind))
    rec(paste0("active_fingerprint:", k), ns$ledgr_active_feature_fingerprint(def))
    rec(paste0("declarations:", k), dig(ns$ledgr_feature_def_declarations(def)))
    rec(paste0("id:", k), ind$id)
    rec(paste0("params:", k), dig(ind$params))
    for (slot in c("fn", "series_fn")) {
      f <- ind[[slot]]
      if (!is.function(f)) next
      rec(paste0(slot, "_body:", k), dig(ns$ledgr_deparse_one(body(f))))
      rec(paste0(slot, "_formals:", k), dig(as.list(formals(f))))
      rec(paste0(slot, "_with_captures:", k), ns$ledgr_function_fingerprint(f, include_captures = TRUE))
    }
  }
  # A parameterised TTR form resolved through a feature map.
  param_map <- ledgr::ledgr_feature_map(fast = ledgr::ledgr_ind_ttr("SMA", input = "close", n = ledgr::ledgr_param("n")))
  resolved <- ns$ledgr_resolve_feature_map(param_map, feature_params = list(n = 7L))
  for (ind in ns$ledgr_feature_map_indicators(resolved)) {
    rec(paste0("fingerprint:param_", ind$id), ns$ledgr_indicator_fingerprint(ind))
    rec(paste0("active_fingerprint:param_", ind$id),
        ns$ledgr_active_feature_fingerprint(ns$ledgr_precompute_feature_def_from_indicator(ind)))
  }

  # ---- experiments ------------------------------------------------------------
  db_dir <- file.path(out, "db")
  unlink(db_dir, recursive = TRUE)
  dir.create(db_dir)
  strategy <- function(ctx, params) ctx$hold()
  features <- function(params) {
    list(ledgr::ledgr_ind_sma(params$n), ledgr::ledgr_ind_ttr("RSI", input = "close", n = 3L),
         ledgr::ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 3L))
  }
  # The declared-session experiment reads an aliased feature map (alias_map_hash).
  feature_map <- ledgr::ledgr_feature_map(fast = ledgr::ledgr_ind_sma(3),
                                          vol = ledgr::ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 3L))
  grid <- ledgr::ledgr_grid_named(a = list(strategy = list(q = 1, n = 3)),
                                  b = list(strategy = list(q = 2, n = 5)))
  experiments <- list(
    bar_native = fx_bar_native(file.path(db_dir, "bar_native.duckdb"), strategy, features),
    declared = fx_declared(file.path(db_dir, "declared.duckdb"), strategy, feature_map))
  for (k in names(experiments)) {
    fx <- experiments[[k]]
    pg <- ns$ledgr_executable_grid_normalize(grid)
    cand <- ns$ledgr_resolve_feature_candidates(fx$exp, pg, stop_on_error = TRUE)$candidate_features
    rec(paste0(k, ":feature_set_hash"), cand$feature_set_hash)
    rec(paste0(k, ":alias_map_hash"), cand$alias_map_hash)
    rec(paste0(k, ":params_hash"), cand$params_hash)
    rec(paste0(k, ":feature_fingerprints"), unlist(cand$feature_fingerprints))
    rec(paste0(k, ":feature_params"), dig(cand$feature_params))
    sweep <- ledgr::ledgr_sweep(fx$exp, grid)
    rec(paste0(k, ":feature_union_hash"), attr(sweep, "feature_union_hash", exact = TRUE))
    rec(paste0(k, ":sweep_candidates"), dig(as.data.frame(sweep)[, c("candidate_id", "status", "final_equity")]))
    bt <- ledgr::ledgr_run(fx$exp, params = list(q = 1, n = 3), run_id = "identity")
    close(bt)
    info <- ledgr::ledgr_run_info(fx$snapshot, "identity")
    for (field in intersect(c("config_hash", "params_hash", "feature_params_hash", "feature_set_hash",
                              "alias_map_hash", "strategy_hash"), names(info))) {
      rec(paste0(k, ":run_", field), as.character(info[[field]]))
    }
  }
  # Walk-forward on the bar-native experiment.
  fx <- experiments$bar_native
  folds <- ns$ledgr_fold_list(list(
    ledgr::ledgr_fold(fx$axis[[1L]], fx$axis[[12L]], fx$axis[[13L]], fx$axis[[18L]], fold_seq = 1L),
    ledgr::ledgr_fold(fx$axis[[7L]], fx$axis[[18L]], fx$axis[[19L]], fx$axis[[24L]], fold_seq = 2L)),
    constructor = list(type_id = "explicit"))
  wf <- ledgr::ledgr_walk_forward(fx$exp, grid = grid, folds = folds,
                                  selection_rule = ledgr::ledgr_rule_argmax("sharpe_ratio"), seed = 101L)
  lapply(wf$test_runs, close)
  rec("walk_forward:session_id", wf$session_id)
  rec("walk_forward:selected_candidate_key", wf$folds$selected_candidate_key)
  if (!is.null(wf$scores$candidate_key)) rec("walk_forward:score_candidate_keys", sort(unique(wf$scores$candidate_key)))
  rec("engine_version (expected to change)", ns$ledgr_feature_engine_version())

  # ---- the other arm's precompute and store -----------------------------------
  pre_grid <- ledgr::ledgr_grid_named(a = list(strategy = list(q = 1, n = 3)))
  if (identical(arg("save-store"), "1")) {
    saveRDS(ledgr::ledgr_precompute_features(fx$exp, pre_grid), file.path(out, "precompute.rds"))
    saved <- ledgr::ledgr_sweep(fx$exp, pre_grid)
    ledgr::ledgr_sweep_save(saved, fx$snapshot, sweep_id = "identity_sweep")
    rec("saved_sweep:engine", ns$ledgr_feature_engine_version())
    rec("saved_sweep:snapshot_id", fx$snapshot$snapshot_id)
  }
  old <- arg("old")
  if (!is.null(old)) {
    old_pre <- readRDS(file.path(old, "precompute.rds"))
    calls <- new.env()
    calls$n <- 0L
    counting <- function(ctx, params) { calls$n <- calls$n + 1L; ctx$hold() }
    exp2 <- fx_bar_native(file.path(db_dir, "bar_native_old.duckdb"), counting, features)
    refusal <- tryCatch({ ledgr::ledgr_sweep(exp2$exp, pre_grid, precomputed_features = old_pre); "none" },
                        error = function(e) class(e)[[1L]])
    rec("old_precompute:refusal", refusal)
    rec("old_precompute:strategy_calls", calls$n)
    old_ids <- utils::read.csv(file.path(old, "identities.csv"), stringsAsFactors = FALSE)
    snap <- ledgr::ledgr_snapshot_open(file.path(old, "db", "bar_native.duckdb"),
                                       old_ids$value[old_ids$name == "saved_sweep:snapshot_id"])
    listed <- tryCatch(ledgr::ledgr_sweep_list(snap), error = function(e) conditionMessage(e))
    rec("old_store:sweep_list", if (is.data.frame(listed)) nrow(listed) else listed)
    reopened <- tryCatch(ledgr::ledgr_sweep_open(snap, "identity_sweep"), error = function(e) conditionMessage(e))
    rec("old_store:sweep_engine", if (is.character(reopened)) reopened else attr(reopened, "feature_engine_version", exact = TRUE))
    run <- tryCatch(ledgr::ledgr_run_open(snap, "identity"), error = function(e) conditionMessage(e))
    rec("old_store:run_open", if (inherits(run, "ledgr_backtest")) "readable" else run)
    if (inherits(run, "ledgr_backtest")) {
      rec("old_store:equity_rows", nrow(ledgr::ledgr_results(run, "equity")))
      close(run)
    }
    ledgr::ledgr_snapshot_close(snap)
  }
  for (fx in experiments) ledgr::ledgr_snapshot_close(fx$snapshot)
  utils::write.csv(do.call(rbind, rows), file.path(out, "identities.csv"), row.names = FALSE)
  cat("identity rows:", length(rows), "\n")
})
