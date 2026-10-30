.libPaths(c("C:/Users/maxth/AppData/Local/Temp/claude/c--Users-maxth-Documents-GitHub-ledgr/78383ced-ac83-4579-b480-65f39660106d/scratchpad/pmwr/lib",
            "C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages(library(ledgr))
out_dir <- "C:/Users/maxth/AppData/Local/Temp/claude/c--Users-maxth-Documents-GitHub-ledgr/78383ced-ac83-4579-b480-65f39660106d/scratchpad/shape_audit"
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
strat_ids <- sprintf("I%02d", 1:7)
strategy <- function(ctx, params) {
  t <- ctx$hold()
  day <- as.integer(as.Date(substr(ctx$ts_utc, 1, 10)))
  t[strat_ids] <- if (day %% 2L == 0L) 10 else 0
  list(targets = t, state_update = list(day = day))
}
environment(strategy) <- list2env(list(strat_ids = strat_ids), parent = globalenv())

ns <- asNamespace("ledgr")
ledgr_names <- ls(ns, all.names = TRUE)
cnt <- new.env()
active <- new.env(); active$on <- FALSE
skip_heads <- c("FUN", "lapply", "vapply", "sapply", "Map", "mapply", "do.call", "tryCatch",
  "tryCatchList", "tryCatchOne", "doTryCatch", "withCallingHandlers", "eval", "force",
  "identity", "suppressWarnings", "suppressMessages", "withVisible", "Reduce", "Filter")
head_name <- function(cl) {
  h <- cl[[1]]
  if (is.symbol(h)) return(as.character(h))
  if (is.call(h) && (identical(h[[1]], as.name(":::")) || identical(h[[1]], as.name("::"))))
    return(as.character(h[[3]]))
  if (is.call(h) && identical(h[[1]], as.name("$"))) return(paste0("$", as.character(h[[3]])))
  "<anon>"
}
.rec <- function(prim) {
  if (!active$on) return(invisible())
  calls <- sys.calls()
  heads <- vapply(calls, head_name, "")
  at <- utils::tail(which(heads == prim), 1L)
  if (!length(at)) at <- length(heads)
  k <- at - 1L
  direct <- TRUE
  caller <- "<top>"
  while (k >= 1L) {
    h <- heads[[k]]
    if (h %in% skip_heads || h == "<anon>" || h == ".doTrace" || h == ".rec") { k <- k - 1L; next }
    if (h %in% ledgr_names || startsWith(h, "$")) { caller <- h; break }
    direct <- FALSE
    k <- k - 1L
  }
  key <- paste(prim, if (direct) "D" else "I", caller, sep = "|")
  v <- cnt[[key]]
  cnt[[key]] <- if (is.null(v)) 1L else v + 1L
}
targets <- list(
  base = c("[.data.frame", "[[.data.frame", "$<-.data.frame", "[<-.data.frame", "[[<-.data.frame",
           "data.frame", "rbind.data.frame", "as.data.frame.list", "merge.data.frame",
           "split.data.frame", "split.default", "unsplit", "structure", "inherits",
           "as.POSIXct", ".POSIXct", "format.POSIXct", "[.POSIXct", "[[.POSIXct", "as.POSIXlt",
           "strftime", "[<-.POSIXct", "c.POSIXct", "rbind", "cbind", "unlist", "ifelse", "paste", "unname", "setdiff", "intersect", "union", "match", "%in%", "unique.default",
           "do.call", "lapply", "vapply", "Map", "all.equal", "rep_len", "order", "paste0", "sprintf"),
  stats = c("setNames"),
  tibble = c("as_tibble", "tibble", "new_tibble"),
  collapse = c("setv"))
for (pkg in names(targets)) {
  env <- asNamespace(pkg)
  for (f in targets[[pkg]]) {
    r <- try(suppressMessages(trace(f, where = env, print = FALSE,
      tracer = bquote(.rec(.(f))))), silent = TRUE)
    if (inherits(r, "try-error")) cat("could not trace", pkg, f, "\n")
  }
}
results <- list()
dump_phase <- function(label) {
  nm <- ls(cnt, all.names = TRUE)
  df <- if (length(nm)) data.frame(phase = label, key = nm,
    n = vapply(nm, function(x) cnt[[x]], integer(1)), row.names = NULL) else
    data.frame(phase = label, key = "(none)", n = 0L)
  rm(list = nm, envir = cnt)
  results[[label]] <<- df
}
run_case <- function(label, facts) {
  db <- file.path(out_dir, paste0("c_", label, ".duckdb"))
  if (file.exists(db)) unlink(db)
  ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = "s", price_basis = "split_adjusted", facts = facts)
  snap <- ledgr_snapshot_open(db, snapshot_id = "s")
  exp <- ledgr_experiment(snap, strategy, universe = ids,
    features = ledgr_feature_map(fast = ledgr_ind_sma(5L)),
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero())
  active$on <- TRUE
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
  active$on <- FALSE
}
run_case("avail", ledgr_facts(sessions, lifetime))
run_case("dense", NULL)
all <- do.call(rbind, results)
write.csv(all, file.path(out_dir, "base_counts2.csv"), row.names = FALSE)
cat("done\n")
