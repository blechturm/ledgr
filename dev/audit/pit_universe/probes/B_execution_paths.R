# Stage 1 probe B: context, target and execution behavior on the shared
# fixture (subsystems 5, 7, 8). Description only: prints run status and the
# diagnostic reason codes per stage; asserts nothing.
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/B_execution_paths.R <log>
#
# The shared fixture declares trading status for FFF and EEE only. Probe
# B_provider_resolution.R shows that every other instrument then resolves to
# status "unknown" (restricted). Runs A to C therefore replace the status
# family with full "active" coverage plus the fixture's FFF halt and EEE
# quotation_only rows; run D keeps the fixture's own status family.
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE)
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)

fx <- pit_audit_fixture("announcement")
s <- fx$sessions
open_at <- function(k) pit_audit_at(s[k], "09:30:00")
close_at <- function(k) pit_audit_at(s[k], if (k == 30L) "13:00:00" else "16:00:00")
na_t <- as.POSIXct(NA, tz = "UTC")
others <- setdiff(fx$instruments$instrument_id, c("FFF", "EEE"))
full_status <- rbind(
  data.frame(instrument_id = others, effective_from = open_at(1), effective_to = na_t,
             status = "active", source = "probe", stringsAsFactors = FALSE),
  data.frame(instrument_id = c("FFF", "FFF", "FFF", "EEE", "EEE"),
             effective_from = c(open_at(1), open_at(14), open_at(16), open_at(1), open_at(23)),
             effective_to = c(open_at(14), open_at(16), na_t, open_at(23), na_t),
             status = c("active", "halted", "active", "active", "quotation_only"),
             source = "probe", stringsAsFactors = FALSE)
)
full_status$knowledge_time <- full_status$effective_from - 1
fx_full <- fx
fx_full$families$status <- ledgr_facts_trading_status(full_status, knowledge = "evidenced")

tmp <- tempdir()
snap_full <- pit_audit_snapshot(fx_full, db_path = file.path(tmp, "B_exec_full.duckdb"))
snap_fix <- pit_audit_snapshot(fx, db_path = file.path(tmp, "B_exec_fixture.duckdb"))

churn <- function(ctx, params) {
  t <- ctx$hold()
  if (length(t) == 0L) return(t)
  day <- as.integer(substr(ctx$ts_utc, 9, 10))
  t[ctx$vec$admissible] <- if (day %% 2L == 0L) 10 else 20
  t
}
buy_once <- function(ctx, params) {
  t <- ctx$hold()
  if (identical(ctx$ts_utc, params$buy_ts)) t[[params$id]] <- 10
  t
}
rebalance <- function(ctx, params) {
  ledgr_selection(ctx) |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = 0.5)
}

report <- function(label, snap, strategy, max_sessions, params = list()) {
  cat(sprintf("\n===== %s (max_sessions = %d) =====\n", label, max_sessions))
  exp <- ledgr_experiment(snap, strategy, universe = ledgr_universe_members(fx$universe_id),
                          valuation_policy = ledgr_valuation_stale(max_sessions),
                          cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5))
  bt <- tryCatch(ledgr_run(exp, params = params, run_id = paste0("B-", gsub("[^A-Za-z]", "", label))),
                 error = function(e) { cat("run error:", class(e)[[1L]], conditionMessage(e), "\n"); NULL })
  if (is.null(bt)) return(invisible(NULL))
  cat("status:", ledgr_run_info(snap, bt$run_id)$status, "\n")
  comp <- tryCatch(ledgr_run_completion(bt), error = function(e) NULL)
  if (!is.null(comp)) print(comp)
  d <- tibble::as_tibble(bt, what = "diagnostics")
  d$reason_code[is.na(d$reason_code) | !nzchar(d$reason_code)] <- "<empty>"
  agg <- stats::aggregate(list(n = rep(1L, nrow(d))),
                          list(stage = d$stage, outcome = d$outcome, reason_code = d$reason_code), sum)
  print(agg[order(agg$stage, agg$outcome, agg$reason_code), ], row.names = FALSE)
  ex <- d[d$stage %in% c("execution", "risk") & d$reason_code != "<empty>", ]
  if (nrow(ex) > 0L) {
    cat("first non-empty execution/risk rows:\n")
    ex$ts <- format(as.POSIXct(ex$ts_utc, tz = "UTC"), "%m-%d %H:%M")
    ex$exec <- format(as.POSIXct(ex$execution_ts_utc, tz = "UTC"), "%m-%d %H:%M")
    print(utils::head(ex[, c("ts", "exec", "instrument_id", "outcome", "reason_code", "reasons", "target", "quantity")], 14),
          row.names = FALSE)
  }
  fills <- tibble::as_tibble(bt, what = "fills")
  if (nrow(fills) > 0L) {
    cat("fill ts_utc sample (UTC):", paste(utils::head(format(fills$ts_utc, "%m-%d %H:%M"), 3), collapse = " "), "\n")
  }
  close(bt)
  invisible(NULL)
}

report("A churn full status", snap_full, churn, 3L)
report("B buy MMM at s8 no bar", snap_full, buy_once, 0L,
       params = list(buy_ts = format(close_at(8), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), id = "MMM"))
report("C rebalance full status", snap_full, rebalance, 3L)
report("D churn fixture status", snap_fix, churn, 3L)
ledgr_snapshot_close(snap_full)
ledgr_snapshot_close(snap_fix)
