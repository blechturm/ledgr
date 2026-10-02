lw_work <- Sys.getenv("LW_WORK", "C:/tmp/ledgr-lw-work")
# Reader-path timings: ledgr_facts_resolve() / ledgr_facts_history() on a sealed
# snapshot, split into the full snapshot re-hash and the rest; plus session-fact
# construction with an exchange timezone (LFB-016).
# Rscript lw_readers.R <repo> <snapshot_db>
args <- commandArgs(TRUE)
repo <- args[[1]]; db <- args[[2]]
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
clock <- function(f) { t0 <- proc.time()[["elapsed"]]; v <- f(); list(v = v, s = proc.time()[["elapsed"]] - t0) }
snapshot <- ledgr_snapshot_open(db)
at <- as.POSIXct("2002-06-03 12:00:00", tz = "UTC")

res <- list()
res$resolve_membership <- clock(function() ledgr_facts_resolve(snapshot, "membership", "synthetic_members", at = at))$s
res$history_membership <- clock(function() ledgr_facts_history(snapshot, "membership", "synthetic_members"))$s
res$history_sessions <- clock(function() ledgr_facts_history(snapshot, "sessions", "SYNTH"))$s

# The same calls with the snapshot re-hash replaced by the stored hash, to
# attribute the remainder (prototype only, in this process).
stored <- local({ con <- ns$ledgr_snapshot_connection(snapshot)$con
  DBI::dbGetQuery(con, "SELECT snapshot_hash FROM snapshots LIMIT 1")$snapshot_hash[[1]] })
res$hash_only <- clock(function() ns$ledgr_snapshot_hash(ns$ledgr_snapshot_connection(snapshot)$con, snapshot$snapshot_id))$s
real_hash <- ns$ledgr_snapshot_hash
unlockBinding("ledgr_snapshot_hash", ns)
assign("ledgr_snapshot_hash", function(con, snapshot_id, ...) stored, envir = ns)
res$resolve_membership_nohash <- clock(function() ledgr_facts_resolve(snapshot, "membership", "synthetic_members", at = at))$s
res$history_membership_nohash <- clock(function() ledgr_facts_history(snapshot, "membership", "synthetic_members"))$s
res$history_sessions_nohash <- clock(function() ledgr_facts_history(snapshot, "sessions", "SYNTH"))$s
res$provider_data <- clock(function() ns$ledgr_availability_provider_data(ns$ledgr_snapshot_connection(snapshot)$con, snapshot$snapshot_id))$s
assign("ledgr_snapshot_hash", real_hash, envir = ns)
ledgr_snapshot_close(snapshot)

# LFB-016: sessions built over 1998-2026 civil dates with an exchange timezone.
civil <- seq(as.Date("1998-01-02"), as.Date("2026-09-04"), by = "day")
open <- as.POSIXlt(civil)$wday %in% 1:5
sessions <- data.frame(session_date = civil, status = ifelse(open, "open", "closed"),
                       session_open = ifelse(open, "09:30:00", NA), session_close = ifelse(open, "16:00:00", NA),
                       knowledge_time = as.POSIXct("1997-12-31", tz = "UTC"), source = "synthetic", stringsAsFactors = FALSE)
res$sessions_construct_ny_s <- clock(function() ledgr_facts_sessions(sessions, "XNYS", timezone = "America/New_York"))$s
res$sessions_construct_utc_s <- clock(function() ledgr_facts_sessions(sessions, "XNYS", timezone = "UTC"))$s
res$civil_dates <- length(civil)
print(unlist(res))
jsonlite::write_json(res, paste0(lw_work, "/readers.json"), auto_unbox = TRUE, pretty = TRUE)
