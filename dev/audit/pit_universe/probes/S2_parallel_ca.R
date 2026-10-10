# Stage 2 probe (analyst): parallel sweep parity with corporate actions
# (Gate 1 carried open item). One grid on the full-status fixture, run with
# workers = 1 and workers = 2 (mirai), research and next_open policies.
# Candidates: hold every tradable ID at qty 5 / 10 (exercises the HHH
# dividend, CCC and DDD scheduled dispositions, KKK/EEE/OOO lifetime
# terminals), and the S2_entitlement BUY / SELL cases.
#
# Harness note: workers load the frozen tree with pkgload::load_all(); the
# product's worker load expression uses the default compile = NA, which would
# rebuild the frozen tree's DLL (cpp11.cpp is newer than ledgr.dll there).
# The probe replaces that expression in this process only with an identical
# one passing compile = FALSE. No product file is changed.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_parallel_ca.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
ns <- asNamespace("ledgr")
patched <- function(source_path) {
  substitute({
    .libPaths(unique(c(LIB_PATHS, .libPaths())))
    pkgload::load_all(SOURCE_PATH, quiet = TRUE, compile = FALSE)
    TRUE
  }, list(SOURCE_PATH = source_path, LIB_PATHS = .libPaths()))
}
utils::assignInNamespace("ledgr_parallel_ledgr_load_expr", patched, ns = "ledgr")

iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
fx <- pit_audit_fixture("announcement", status_coverage = "full")
close_at <- function(k) pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
snap <- pit_audit_snapshot(fx, db_path = file.path(tempdir(), "S2_parallel.duckdb"))
strategy <- function(ctx, params) {
  t <- ctx$hold()
  if (identical(params$mode, "all")) {
    ids <- ctx$tradable()
    if (length(ids)) t[ids] <- params$qty
  } else {
    if (!is.null(params$buy_ts) && identical(ctx$ts_utc, params$buy_ts)) t[["HHH"]] <- 10
    if (!is.null(params$sell_ts) && identical(ctx$ts_utc, params$sell_ts)) t[["HHH"]] <- 0
  }
  t
}
grid <- ledgr_param_grid(
  all5 = list(mode = "all", qty = 5), all10 = list(mode = "all", qty = 10),
  buy = list(mode = "hhh", buy_ts = iso(close_at(13))),
  sell = list(mode = "hhh", buy_ts = iso(close_at(1)), sell_ts = iso(close_at(13)))
)
for (posting in c("effective_close", "next_open")) {
  exp <- ledgr_experiment(snap, strategy, universe = ledgr_universe_members(fx$universe_id),
                          valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1e5),
                          corporate_action_policy = ledgr_corporate_actions(cash_posting = posting))
  s1 <- ledgr_sweep(exp, grid, workers = 1L)
  t0 <- Sys.time()
  s2 <- tryCatch(ledgr_sweep(exp, grid, workers = 2L), error = function(e) e)
  if (inherits(s2, "error")) { cat("[", posting, "] parallel ERROR ", class(s2)[[1]], ": ", conditionMessage(s2), "\n", sep = ""); next }
  cat(sprintf("[%s] parallel elapsed %.1fs\n", posting, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cols <- intersect(c("candidate_label", "status", "final_equity", "total_return", "n_trades", "stop_reason", "completion_json"), names(s1))
  for (i in seq_len(nrow(s1))) {
    same <- vapply(cols, function(cl) identical(s1[[cl]][[i]], s2[[cl]][[i]]), logical(1))
    cat(sprintf("[%s] %s: status %s/%s final_equity %s/%s; identical columns: %s\n", posting,
                s1$candidate_label[[i]] %||% i, s1$status[[i]], s2$status[[i]],
                format(s1$final_equity[[i]], nsmall = 2), format(s2$final_equity[[i]], nsmall = 2),
                paste(names(same)[same], collapse = ",")))
    if (!all(same)) cat("   differing: ", paste(names(same)[!same], collapse = ","), "\n")
  }
}
ledgr_snapshot_close(snap)
