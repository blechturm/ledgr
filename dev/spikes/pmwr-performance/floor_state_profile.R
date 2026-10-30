# Profile the no-fill floor on the availability producer (facts as in the WS4a probe).
args <- commandArgs(TRUE)
out <- args[[1]]; lib <- args[[2]]; producer <- args[[3]]
.libPaths(c(lib, "C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages(library(ledgr))
bars <- read.csv("C:/Users/maxth/AppData/Local/Temp/ledgr-peer-suite-cut3-normalized-inputs/500x1260.csv")
ids <- sort(unique(bars$instrument_id))
dates <- sort(unique(as.Date(substr(bars$ts_utc, 1, 10))))
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
db <- file.path(out, paste0("floor_", producer, ".duckdb"))
if (!file.exists(db)) {
  ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = "floor", price_basis = "split_adjusted",
    facts = if (producer == "availability") ledgr_facts(sessions, lifetime) else NULL)
}
snapshot <- ledgr_snapshot_open(db, snapshot_id = "floor")
strategy <- function(ctx, params) {
  fast <- ctx$vec$feature("fast"); slow <- ctx$vec$feature("slow")
  list(targets = ctx$hold(), state_update = list(above = is.finite(fast) & fast > slow, usable = is.finite(fast) & is.finite(slow)))
}
exp <- ledgr_experiment(snapshot, strategy, universe = ids,
  features = ledgr_feature_map(
    fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
    slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
  opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none())
run <- function() suppressWarnings(ledgr_sweep(exp,
  do.call(ledgr_grid_named, stats::setNames(list(list()), paste0("f", sample.int(1e6, 1)))),
  workers = 1L, seed = 20260530L, stop_on_error = TRUE))
invisible(run())  # warm
prof <- file.path(out, paste0("floorstate_", producer, ".rprof"))
t0 <- proc.time()[["elapsed"]]
utils::Rprof(prof, interval = 0.005, event = "elapsed")
invisible(run())
utils::Rprof(NULL)
cat(producer, "elapsed", proc.time()[["elapsed"]] - t0, "\n")
s <- utils::summaryRprof(prof)
tot <- s$by.total[grepl("ledgr|handler|canonical|json|all.equal|format|POSIX|vapply|lapply", rownames(s$by.total)), ]
write.csv(cbind(fn = rownames(tot), tot), file.path(out, paste0("floorstate_", producer, "_total.csv")), row.names = FALSE)
self <- s$by.self
write.csv(cbind(fn = rownames(self), self), file.path(out, paste0("floorstate_", producer, "_self.csv")), row.names = FALSE)
cat("sampled", s$sampling.time, "\n")
