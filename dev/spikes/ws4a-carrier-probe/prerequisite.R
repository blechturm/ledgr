# WS4a prerequisite execution. No product patches; warm timing is not claimed.
args <- commandArgs(TRUE)
arg <- function(key, default) {
  x <- grep(paste0("^--", key, "="), args, value = TRUE)
  if (length(x)) sub(paste0("^--", key, "="), "", x[[1]]) else default
}
out <- arg("out", file.path(tempdir(), "ws4a"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(arg("lib", "C:/Users/maxth/AppData/Local/Temp/ws4a-lib"), .libPaths()))
library(ledgr)
bars <- read.csv(arg("csv", "C:/Users/maxth/AppData/Local/Temp/ledgr-peer-suite-cut3-normalized-inputs/500x1260.csv"))
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
strategy <- function(ctx, params) {
  fast <- ctx$vec$feature("fast"); slow <- ctx$vec$feature("slow")
  usable <- is.finite(fast) & is.finite(slow); above <- usable & fast > slow
  prior_above <- if (is.null(ctx$state_prev$above)) rep(FALSE, length(usable)) else as.logical(ctx$state_prev$above)
  prior_usable <- if (is.null(ctx$state_prev$usable)) rep(FALSE, length(usable)) else as.logical(ctx$state_prev$usable)
  targets <- ctx$hold()
  targets[prior_usable & usable & above & !prior_above] <- 1
  targets[prior_usable & usable & !above & prior_above] <- 0
  list(targets = targets, state_update = list(above = above, usable = usable))
}
ns <- asNamespace("ledgr")
original <- ns$ledgr_fold_stage_plan
active <- logical()
utils::assignInNamespace("ledgr_fold_stage_plan", function(fold_state, services, ...) {
  active <<- c(active, services$availability_active)
  original(fold_state, services, ...)
}, ns = "ledgr")
results <- list()
for (producer in c("dense", "availability")) {
  active <- logical()
  snapshot <- ledgr_snapshot_from_df(bars, db_path = file.path(out, paste0(producer, ".duckdb")),
    snapshot_id = "ws4a", price_basis = "split_adjusted",
    facts = if (producer == "availability") ledgr_facts(sessions, lifetime) else NULL)
  exp <- ledgr_experiment(snapshot, strategy, universe = ids,
    features = ledgr_feature_map(
      fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_none())
  bt <- suppressWarnings(ledgr_run(exp, run_id = "ws4a", seed = 20260530L))
  results[[producer]] <- list(fills = as.data.frame(ledgr_results(bt, "fills")),
    equity = as.data.frame(ledgr_results(bt, "equity")))
  write.csv(data.frame(producer, availability_active = unique(active), pulses = length(active),
    fills = nrow(results[[producer]]$fills), final_equity = tail(results[[producer]]$equity$equity, 1)),
    file.path(out, paste0(producer, ".csv")), row.names = FALSE)
  close(bt)
}
saveRDS(results, file.path(out, "prerequisite.rds"))
print(lapply(results, function(x) c(fills = nrow(x$fills), final_equity = tail(x$equity$equity, 1))))
print(all.equal(results$dense$fills, results$availability$fills))
print(all.equal(results$dense$equity, results$availability$equity))
fills_a <- results$dense$fills
fills_b <- results$availability$fills
comparison <- data.frame(surface = c(paste0("fills.", names(fills_a)), "equity"),
  identical = c(vapply(names(fills_a), function(nm) identical(fills_a[[nm]], fills_b[[nm]]), logical(1)),
    identical(results$dense$equity, results$availability$equity)))
write.csv(comparison, file.path(out, "producer_identity.csv"), row.names = FALSE)
print(comparison)
