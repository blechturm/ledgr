# Workstream 42 history-read probe (LDG-3062): prepared-plane cost, per-call
# read cost by lookback and layout, late-known epoch overlays, and the
# whole-prefix WS41 primitive for contrast.
#   Rscript frame_probe.R <tree> <n_inst> <n_days>
args <- commandArgs(TRUE)
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(args[[1]], quiet = TRUE))
n_inst <- as.integer(args[[2]]); n_axis <- as.integer(args[[3]])
set.seed(42)
axis <- as.POSIXct("1998-01-02 21:00:00", tz = "UTC") + seq_len(n_axis) * 86400
ids <- sprintf("I%04d", seq_len(n_inst))
# Ragged listing: each instrument starts at a random column; 2% random gaps.
start <- sample.int(n_axis %/% 2, n_inst, replace = TRUE)
t0 <- Sys.time()
inst <- rep(seq_len(n_inst), times = n_axis - start + 1L)
col <- unlist(lapply(start, function(s) s:n_axis))
keep <- runif(length(col)) > 0.02
inst <- inst[keep]; col <- col[keep]
bars <- data.frame(instrument_id = ids[inst], ts_utc = axis[col], close = 10 + runif(length(col)))
bars$open <- bars$high <- bars$low <- bars$close; bars$volume <- 1000
# Lifetime: each instrument known_active from its start; 5% late-known inactive interval.
late <- sample.int(n_inst, n_inst %/% 20)
lt <- data.frame(instrument_id = ids, effective_from = axis[start] - 3600, effective_to = as.POSIXct(NA, tz = "UTC"),
                 knowledge_time = axis[start] - 3600, assertion = "known_active", source = "s")
li <- data.frame(instrument_id = ids[late], effective_from = axis[n_axis - 300] - 3600, effective_to = axis[n_axis - 200] - 3600,
                 knowledge_time = axis[n_axis - 250] - 3600, assertion = "known_inactive", source = "s")
lt$effective_to[late] <- axis[n_axis - 300] - 3600
lt2 <- lt[late, ]; lt2$effective_from <- axis[n_axis - 200] - 3600; lt2$effective_to <- as.POSIXct(NA, tz = "UTC"); lt2$knowledge_time <- lt2$effective_from
lifetime <- ledgr_facts_lifetime(rbind(lt, li, lt2))
data <- list(families = data.frame(family = c("lifetime", "sessions")), lifetime = lifetime$rows,
  sessions = data.frame(venue_id = "V", session_date = as.Date(axis), status = "open", session_open = axis - 6.5*3600,
                        session_close = axis, knowledge_time = axis - 6.5*3600))
config <- list(universe = list(instrument_ids = ids), availability = list(valuation_policy = unclass(ledgr_valuation_stale())),
               history_policy = ledgr_history_policy())
cat("fixture", format(Sys.time() - t0), "\n")
gc(reset = TRUE)
t0 <- Sys.time()
sub <- ledgr_history_substrate(bars, ids, axis, data, config, "probe")
cat("substrate", format(Sys.time() - t0), "\n"); rm(bars); g0 <- gc(reset = TRUE)
cat("used after substrate Mb:", sum(g0[, 2]), " substrate MB:", round(as.numeric(object.size(sub))/2^20), "\n")
svc <- ledgr_history_read_service(sub)
planes <- list(member = rep(TRUE, n_inst), admissible = rep(TRUE, n_inst), target_restriction_reason = rep("", n_inst))
read <- function(col, lookback, layout = "wide") ledgr_history_read(ledgr_history_view(svc, col), "bar", "close", lookback,
  "decision_axis", "keep", layout, ids, planes)
t0 <- Sys.time(); x <- read(n_axis, 252L); t1 <- Sys.time()
cat("first read (prepares base planes) lookback 252:", format(t1 - t0), "\n")
g1 <- gc(); cat("memo MB:", round(sum(vapply(as.list(sub$history_memo), function(o) as.numeric(object.size(o)), 0)) / 2^20, 1), " peak Mb since reset:", g1[2, 6], "\n")
time_reads <- function(lookback, layout = "wide", cols = seq(n_axis - 99L, n_axis)) {
  t0 <- Sys.time(); for (c in cols) x <- read(c, lookback, layout); as.numeric(Sys.time() - t0, units = "secs") / length(cols)
}
cat("per-call 252 wide (after every late epoch):", round(1000 * time_reads(252L), 1), "ms\n")
cat("per-call 252 long:", round(1000 * time_reads(252L, "long"), 1), "ms\n")
cat("per-call 21 wide:", round(1000 * time_reads(21L), 1), "ms\n")
cat("per-call Inf wide (10 calls):", round(1000 * time_reads(Inf, cols = seq(n_axis - 9L, n_axis)), 1), "ms\n")
cat("overlay builds:", sub$history_memo$builds_overlay, " base builds:", sub$history_memo$builds_base, "\n")
# WS41 primitive per call (prefix rematerialization) for contrast, 3 calls.
t0 <- Sys.time(); for (c in seq(n_axis - 2L, n_axis)) y <- ledgr_history_substrate_treated_field(sub, "close", axis[[c]], observation_idx = (c - 251L):c)
cat("WS41 treated_field per call (252 window):", round(1000 * as.numeric(Sys.time() - t0, units = "secs") / 3, 1), "ms\n")
cat("per-call 252 wide across late epochs:", round(1000 * time_reads(252L, cols = seq(n_axis - 299L, n_axis - 200L)), 1), "ms\n")
cat("overlay builds after:", sub$history_memo$builds_overlay, "\n")
