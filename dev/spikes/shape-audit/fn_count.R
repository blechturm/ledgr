.libPaths(c("C:/Users/maxth/AppData/Local/Temp/claude/c--Users-maxth-Documents-GitHub-ledgr/78383ced-ac83-4579-b480-65f39660106d/scratchpad/pmwr/lib",
            "C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages(library(ledgr))
out_dir <- "C:/Users/maxth/AppData/Local/Temp/claude/c--Users-maxth-Documents-GitHub-ledgr/78383ced-ac83-4579-b480-65f39660106d/scratchpad/shape_audit"
set.seed(1)
# 20 instruments x 60 pulses; the strategy trades only the first 7 instruments
# every pulse, so fills (7 x 59 = 413) separate from instrument-pulses (1200)
# and pulses (60).
n_inst <- 20L; n_days <- 60L; n_trade <- 7L
ids <- sprintf("I%02d", seq_len(n_inst))
dates <- seq(as.Date("2020-01-01"), by = "day", length.out = n_days * 2)
dates <- dates[!weekdays(dates) %in% c("Saturday", "Sunday")][seq_len(n_days)]
bars <- do.call(rbind, lapply(ids, function(id) {
  p <- 100 * cumprod(1 + rnorm(n_days, 0, 0.01))
  data.frame(instrument_id = id, ts_utc = as.POSIXct(paste(dates, "21:00:00"), tz = "UTC"),
             open = p, high = p * 1.01, low = p * 0.99, close = p, volume = 1e6)
}))
calendar <- seq(min(dates), max(dates), by = "day")
opened <- calendar %in% dates
sessions <- ledgr_facts_sessions(data.frame(session_date = calendar,
  status = ifelse(opened, "open", "closed"),
  session_open = ifelse(opened, "14:30:00", NA_character_),
  session_close = ifelse(opened, "21:00:00", NA_character_),
  knowledge_time = as.POSIXct(calendar, tz = "UTC") - 1), "probe", timezone = "UTC")
lifetime <- ledgr_facts_lifetime(data.frame(instrument_id = ids,
  effective_from = as.POSIXct(min(dates), tz = "UTC"),
  knowledge_time = as.POSIXct(min(dates), tz = "UTC") - 1,
  assertion = "known_active"))

strategy <- function(ctx, params) {
  t <- ctx$hold()
  day <- as.integer(as.Date(substr(ctx$ts_utc, 1, 10)))
  k <- intersect(names(t), sprintf("I%02d", 1:7))
  t[k] <- if (day %% 2L == 0L) 10 else 0
  list(targets = t, state_update = list(day = day))
}

cnt <- new.env()
.cnt_inc <- function(name) {
  v <- cnt[[name]]
  cnt[[name]] <- if (is.null(v)) 1L else v + 1L
}
ns <- asNamespace("ledgr")
fns <- ls(ns, all.names = TRUE)
fns <- fns[vapply(fns, function(f) {
  g <- get(f, envir = ns)
  is.function(g) && !is.primitive(g)
}, logical(1))]
skip <- c("%||%")
fns <- setdiff(fns, skip)
ok <- 0L
for (f in fns) {
  r <- try(suppressMessages(trace(f, where = ns, print = FALSE,
    tracer = bquote(.cnt_inc(.(f))))), silent = TRUE)
  if (!inherits(r, "try-error")) ok <- ok + 1L
}
cat("traced", ok, "of", length(fns), "\n")

results <- list()
dump_phase <- function(label) {
  nm <- ls(cnt, all.names = TRUE)
  df <- if (length(nm)) data.frame(phase = label, fn = nm,
    n = vapply(nm, function(x) cnt[[x]], integer(1)), row.names = NULL) else
    data.frame(phase = label, fn = "(none)", n = 0L)
  rm(list = nm, envir = cnt)
  results[[label]] <<- df
}
run_case <- function(label, facts) {
  db <- file.path(out_dir, paste0(label, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = "s", price_basis = "split_adjusted", facts = facts)
  snap <- ledgr_snapshot_open(db, snapshot_id = "s")
  exp <- ledgr_experiment(snap, strategy, universe = ids,
    features = ledgr_feature_map(fast = ledgr_ind_sma(5L)),
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero())
  dump_phase(paste0(label, "_setup"))
  bt <- suppressWarnings(ledgr_run(exp, run_id = paste0("r_", label)))
  dump_phase(paste0(label, "_run"))
  sw <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(a = list()), workers = 1L, seed = 1L, stop_on_error = TRUE))
  dump_phase(paste0(label, "_sweep"))
  for (w in c("equity", "fills", "trades", "ledger")) {
    invisible(ledgr_results(bt, w))
    dump_phase(paste0(label, "_read_", w))
  }
  invisible(capture.output(print(bt)))
  dump_phase(paste0(label, "_print"))
  invisible(capture.output(summary(bt)))
  dump_phase(paste0(label, "_summary"))
  f <- ledgr_results(bt, "fills")
  cat(label, "fills:", nrow(f), "\n")
}
run_case("avail", ledgr_facts(sessions, lifetime))
run_case("dense", NULL)
all <- do.call(rbind, results)
write.csv(all, file.path(out_dir, "fn_counts.csv"), row.names = FALSE)
w <- reshape(all, idvar = "fn", timevar = "phase", direction = "wide")
names(w) <- sub("^n\\.", "", names(w))
w[is.na(w)] <- 0L
write.csv(w, file.path(out_dir, "fn_counts_wide.csv"), row.names = FALSE)
cat("done\n")
