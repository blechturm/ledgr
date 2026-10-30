.libPaths(c("C:/Users/maxth/AppData/Local/Temp/claude/c--Users-maxth-Documents-GitHub-ledgr/78383ced-ac83-4579-b480-65f39660106d/scratchpad/pmwr/lib",
            "C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages(library(ledgr))
out_dir <- "C:/Users/maxth/AppData/Local/Temp/claude/c--Users-maxth-Documents-GitHub-ledgr/78383ced-ac83-4579-b480-65f39660106d/scratchpad/json_count"
dir.create(out_dir, showWarnings = FALSE)
set.seed(1)
n_inst <- 20L; n_days <- 60L
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
  t[] <- if (day %% 2L == 0L) 10 else 0
  t
}

counts <- new.env()
counts$tab <- list()
record <- function(prim) {
  calls <- sys.calls()
  heads <- vapply(calls, function(cl) paste(deparse(cl[[1]], width.cutoff = 200L)[1], collapse = ""), "")
  heads <- sub("^ledgr:::", "", sub("^ledgr::", "", heads))
  heads <- sub("^digest::", "", heads)
  at <- utils::tail(which(heads == prim), 1L)
  if (length(at)) heads <- heads[seq_len(at - 1L)]
  skip <- c("canonical_json", "ledgr_canonical_json_encode", ".ledgr_json_cache_key",
            "ledgr_json_read_nested", "ledgr_json_read_config", "ledgr_json_write_canonical_v2",
            "digest::digest", "digest", "yyjsonr::read_json_str", "yyjsonr::write_json_str",
            "read_json_str", "write_json_str", "tryCatch", "tryCatchList", "tryCatchOne", "doTryCatch",
            "FUN", "lapply", "vapply", "Map", "mapply", "do.call", "eval", "withCallingHandlers",
            "force", "identity", "function(x) as.character(canonical_json(x))", ".doTrace", "record")
  keep <- heads[!heads %in% skip & !grepl("^function|^\\(|^record|\\.doTrace|^cmpfun", heads)]
  key <- paste(prim, paste(utils::tail(keep, 3L), collapse = " < "), sep = " | ")
  counts$tab[[key]] <- (counts$tab[[key]] %||% 0L) + 1L
}
`%||%` <- function(a, b) if (is.null(a)) b else a
ns <- asNamespace("ledgr")
tr <- function(name, where = ns) {
  suppressMessages(trace(name, where = where, print = FALSE,
    tracer = bquote(get("record", envir = .GlobalEnv)(.(name)))))
}
for (f in c("canonical_json", "ledgr_canonical_json_encode", ".ledgr_json_cache_key",
            "ledgr_json_read_nested", "ledgr_json_read_config")) tr(f)
tr("digest", asNamespace("digest"))

dump_phase <- function(label) {
  tab <- counts$tab
  df <- if (length(tab)) data.frame(phase = label, key = names(tab), n = unlist(tab), row.names = NULL) else
    data.frame(phase = label, key = "(none)", n = 0L)
  df <- df[order(-df$n), ]
  counts$tab <- list()
  df
}

results <- list()
run_case <- function(label, facts) {
  db <- file.path(out_dir, paste0(label, ".duckdb"))
  if (file.exists(db)) unlink(db)
  counts$tab <- list()
  ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = "s", price_basis = "split_adjusted", facts = facts)
  snap <- ledgr_snapshot_open(db, snapshot_id = "s")
  exp <- ledgr_experiment(snap, strategy, universe = ids,
    features = ledgr_feature_map(fast = ledgr_ind_sma(5L)),
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero())
  results[[paste0(label, "_setup")]] <<- dump_phase(paste0(label, "_setup"))
  bt <- suppressWarnings(ledgr_run(exp, run_id = paste0("r_", label)))
  results[[paste0(label, "_run")]] <<- dump_phase(paste0(label, "_run"))
  sw <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(a = list()), workers = 1L, seed = 1L, stop_on_error = TRUE))
  results[[paste0(label, "_sweep")]] <<- dump_phase(paste0(label, "_sweep"))
  for (w in c("equity", "fills", "trades", "ledger")) {
    invisible(ledgr_results(bt, w))
    results[[paste0(label, "_read_", w)]] <<- dump_phase(paste0(label, "_read_", w))
  }
  invisible(capture.output(print(bt)))
  results[[paste0(label, "_print")]] <<- dump_phase(paste0(label, "_print"))
  invisible(capture.output(summary(bt)))
  results[[paste0(label, "_summary")]] <<- dump_phase(paste0(label, "_summary"))
}
run_case("avail", ledgr_facts(sessions, lifetime))
invisible(NULL)
all <- do.call(rbind, results)
write.csv(all, file.path(out_dir, "counts_nostate.csv"), row.names = FALSE)
cat("pulses", n_days, "instruments", n_inst, "\n")
print(all[all$n >= 1, c("phase", "n", "key")], right = FALSE, row.names = FALSE)
