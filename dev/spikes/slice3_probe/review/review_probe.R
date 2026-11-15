repo <- "C:/Users/maxth/ledgr-wt/slice3-probe"
out <- "C:/Users/maxth/ledgr-wt/slice3-probe-review-out"
lib <- "C:/Users/maxth/AppData/Local/Temp/claude/a337d437c6e22de3/78383ced-ac83-4579-b480-65f39660106d/scratchpad/ws16/lib-d5b3a151"
source(file.path(repo, "dev/lean_core/load.R"))
debug <- identical(commandArgs(TRUE)[1L], "1")
lean <- lean_core_load(lib, debug = debug)
source(file.path(repo, "dev/bench/v0_2_3_output_freeze/lib.R"))
gut <- length(commandArgs(TRUE)) > 2L && identical(commandArgs(TRUE)[3L], "gut")
if (gut) lean$ledgr_availability_validate_strategy_targets <- function(...) invisible(NULL)
sink(file.path(out, paste0("review_probe_debug", as.integer(debug), if (gut) "_gut" else if (length(commandArgs(TRUE)) > 1L) "_extra" else "", ".txt")), split = TRUE)
dates <- as.Date("2020-01-01") + 0:19
make_snapshot <- function(db, drop, all_gap = FALSE, declared = TRUE, closed = FALSE) {
  closes <- list(A = 30 + sin(1:20), B = 45 + sin(2:21), C = 12 + sin(3:22))
  for (id in names(drop)) closes[[id]][drop[[id]]] <- NA_real_
  if (all_gap) for (id in names(closes)) closes[[id]][8L] <- NA_real_
  closed_days <- if (closed) c(4:5, 11:12, 18:19) else integer()
  for (id in names(closes)) closes[[id]][closed_days] <- NA_real_
  bars <- do.call(rbind, lapply(names(closes), function(id) {
    k <- which(is.finite(closes[[id]]))
    data.frame(ts_utc = as.POSIXct(paste(dates[k], "16:00:00"), tz = "UTC"), instrument_id = id,
      open = closes[[id]][k], high = closes[[id]][k] + 1, low = closes[[id]][k] - 1,
      close = closes[[id]][k], volume = 1000)
  }))
  session_rows <- data.frame(session_date = dates, status = "open",
    session_open = "09:30:00", session_close = "16:00:00", knowledge_time = as.POSIXct(dates, tz = "UTC") - 1)
  session_rows$status[closed_days] <- "closed"
  session_rows$session_open[closed_days] <- NA_character_
  session_rows$session_close[closed_days] <- NA_character_
  sessions <- ledgr::ledgr_facts_sessions(session_rows, venue_id = "XNYS")
  ledgr::ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = names(closes)),
    facts = if (declared) ledgr::ledgr_facts(sessions) else NULL, price_basis = "split_adjusted", db_path = db, snapshot_id = "review")
}
make_strategy <- function(mode) {
  force(mode)
  function(ctx, params) {
    day <- as.integer(substr(ctx$ts_utc, 9L, 10L))
    t <- ctx$hold()
    if (day == 2L) t[c("A", "B")] <- 10
    if (mode == "increase" && day == 10L) t["B"] <- 20
    if (mode == "liquidate" && day %in% c(10L, 14L)) t["B"] <- 0
    if (mode == "sizing_exit" && day == 10L) return(ledgr::ledgr_target_adjust(ctx, exit = c(A = FALSE, B = TRUE, C = FALSE)))
    if (mode == "sizing_stale" && day == 8L) return(ledgr::ledgr_target_adjust(ctx, exit = c(A = FALSE, B = TRUE, C = FALSE)))
    if (mode == "query") t["A"] <- if (ledgr::ledgr_schedule_due(ctx, ledgr::ledgr_schedule_weekday("friday"))) 20 else 0
    if (mode == "missing_mark" && day == 2L) t["C"] <- 5
    if (mode == "history_feature") {
      m <- ledgr::ledgr_history_matrix(ctx, feature = "fast", lookback = 4L)
      f <- ledgr::ledgr_history_frame(ctx, feature = "fast", lookback = 3L, layout = "long")
      t["A"] <- if ((floor(sum(m, na.rm = TRUE)) + nrow(f)) %% 2) 10 else 0
    }
    if (mode == "risk_stop" && day == 10L) t["C"] <- 5
    t
  }
}
cases <- list(
  frozen_increase = list(mode = "increase", drop = list(B = 8:14)),
  frozen_liquidate = list(mode = "liquidate", drop = list(B = 8:14)),
  skip_stop = list(mode = "hold", drop = list(B = 8:20), exhausted = "refuse", schedule = "dates"),
  declared_prefix = list(mode = "hold", drop = list(B = 8:14), max = 11L),
  scheduled_prefix = list(mode = "hold", drop = list(B = 8:14), max = 11L, schedule = "dates"),
  sizing_frozen = list(mode = "sizing_exit", drop = list(B = 8:14)),
  sizing_stale = list(mode = "sizing_stale", drop = list(B = 8:14)),
  history_feature = list(mode = "history_feature", drop = list(B = 8:14), features = TRUE),
  scheduled_sweep = list(mode = "hold", drop = list(B = 8:14), schedule = "param", sweep = TRUE),
  all_missing_session = list(mode = "hold", drop = list(), all_gap = TRUE),
  risk_stop = list(mode = "risk_stop", drop = list(C = 4:12)),
  skip_stop_first_missing = list(mode = "hold", drop = list(B = 8:20), exhausted = "refuse", schedule = "dates", horizon = 0L),
  schedule_query = list(mode = "query", drop = list()),
  schedule_no_decisions = list(mode = "hold", drop = list(), schedule = "empty"),
  risk_never_marked = list(mode = "missing_mark", drop = list(C = 1:12)),
  closed_sessions = list(mode = "hold", drop = list(B = 8:14), closed = TRUE)
)
run_arm <- function(name, cfg, arm) {
  fold_records <- list()
  undo_fold <- lean$lean_wrap_binding(asNamespace("ledgr"), "ledgr_fold_envelope", function(f) function(...) {
    r <- f(...)
    fold_records[[length(fold_records) + 1L]] <<- list(status = r$status, processed = r$processed, full_run = r$full_run)
    r
  })
  on.exit(undo_fold(), add = TRUE)
  db <- tempfile(paste0(name, "_", arm, "_", as.integer(debug), "_"), tmpdir = out, fileext = ".duckdb")
  a0_path_tokens[[db]] <- "<DB_PATH>"
  snapshot <- make_snapshot(db, cfg$drop, isTRUE(cfg$all_gap), closed = isTRUE(cfg$closed))
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  strategy <- make_strategy(cfg$mode)
  schedule <- if (is.null(cfg$schedule)) NULL else if (cfg$schedule == "param") ledgr::ledgr_schedule_from_param("cadence") else if (cfg$schedule == "empty") ledgr::ledgr_schedule_month_start() else ledgr::ledgr_schedule_dates(dates[2L])
  exp <- ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 1e4),
    cost_model = ledgr::ledgr_cost_zero(), valuation_policy = ledgr::ledgr_valuation_stale(
      max_sessions = if (is.null(cfg$horizon)) 2L else cfg$horizon,
      exhausted = if (is.null(cfg$exhausted)) "freeze" else cfg$exhausted), schedule = schedule,
    features = if (isTRUE(cfg$features)) ledgr::ledgr_feature_map(fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 3L)) else list())
  if (!is.null(cfg$max)) exp$control <- list(max_pulses = cfg$max)
  if (isTRUE(cfg$sweep)) {
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(cadence = "week_start")), b = list(strategy = list(cadence = "month_end")))
    obs <- a0_observe_memory(ledgr::ledgr_sweep(exp, grid, seed = 11L, retain = a0_retain()))
    cat(arm, "fold results:"); print(fold_records)
    return(c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value)))
  }
  conditions <- a0_new_sink()
  a0_run_or_record(ledgr::ledgr_run(exp, run_id = "review_run", seed = 11L), "review_run", conditions)
  cat(arm, "fold results:"); print(fold_records)
  c(a0_store_tables(db, "review_run"), list(conditions = a0_canon(conditions$rows, "run_conditions", "seq")))
}
selected <- if (length(commandArgs(TRUE)) > 1L) strsplit(commandArgs(TRUE)[2L], ",", fixed = TRUE)[[1L]] else names(cases)
for (name in selected) {
  cat("\nCASE", name, "debug", debug, "\n")
  pin <- tryCatch(run_arm(name, cases[[name]], "pin"), error = function(e) e)
  restore <- lean$lean_loop_install(hooks = FALSE)
  candidate <- tryCatch(run_arm(name, cases[[name]], "lean"), error = function(e) e)
  restore()
  if (inherits(pin, "error") || inherits(candidate, "error")) {
    cat("TOP ERROR pin:", if (inherits(pin, "error")) conditionMessage(pin) else "none", "lean:", if (inherits(candidate, "error")) conditionMessage(candidate) else "none", "\n")
    next
  }
  different <- names(pin)[!vapply(names(pin), function(tab) identical(pin[[tab]], candidate[[tab]]), logical(1))]
  cat("DIFFERENT:", paste(different, collapse = ","), "\n")
  if (!is.null(pin$sweep)) print(pin$sweep[, intersect(c("label", "status", "error_msg", "decision_pulse_count", "scheduled_skip_count"), names(pin$sweep)), drop = FALSE])
  for (tab in different) {
    cat("TABLE", tab, "\n")
    a <- pin[[tab]]; b <- candidate[[tab]]
    if (identical(dim(a), dim(b)) && identical(names(a), names(b))) {
      cols <- names(a)[!vapply(names(a), function(col) identical(a[[col]], b[[col]]), logical(1))]
      cat("columns:", paste(cols, collapse = ","), "\n")
      print(utils::head(a[, unique(c(intersect(c("diagnostic_seq", "ts_utc", "instrument_id", "reason_code"), names(a)), cols)), drop = FALSE], 3L))
      print(utils::head(b[, unique(c(intersect(c("diagnostic_seq", "ts_utc", "instrument_id", "reason_code"), names(b)), cols)), drop = FALSE], 3L))
    } else cat("pin rows", nrow(a), "lean rows", nrow(b), "\n")
  }
  if (!is.null(pin$conditions)) print(pin$conditions)
  if (!is.null(pin$run_completion)) print(pin$run_completion)
  d <- pin$run_diagnostics
  if (!is.null(d)) {
    cat("PIN REASONS:"); print(table(d$reason_code))
    pick <- d$reason_code %in% c("valuation_freeze_exited", "risk_mark_unavailable", "valuation_horizon_exhausted", "sizing_liquidation", "sizing_unavailable") |
      (d$instrument_id == "B" & substr(d$ts_utc, 9L, 10L) %in% c("08", "10", "14", "15") & d$stage == "execution")
    print(d[pick, intersect(c("diagnostic_seq", "ts_utc", "instrument_id", "stage", "reason_code", "quantity", "price", "mark_source", "mark_age"), names(d)), drop = FALSE])
  }
  saveRDS(list(pin = pin, lean = candidate), file.path(out, paste0(name, "_debug", as.integer(debug), if (gut) "_gut" else "", ".rds")))
}
sink()
