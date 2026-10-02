lw_work <- Sys.getenv("LW_WORK", "C:/tmp/ledgr-lw-work")
# Hash-free ledgr_facts_resolve() membership time versus number of membership sets.
args <- commandArgs(TRUE); repo <- args[[1]]
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr"); real <- ns$ledgr_snapshot_hash
out <- list()
for (sets in c(12, 60, 300, 600)) {
  src <- paste0(lw_work, sprintf("/snapshots/1514_1150_500_%d_0.02_0/snapshot.duckdb", sets))
  db <- paste0(lw_work, sprintf("/runs/resolve_%d.duckdb", sets)); file.copy(src, db, overwrite = TRUE)
  snap <- ledgr_snapshot_open(db)
  con <- ns$ledgr_snapshot_connection(snap)$con
  stored <- DBI::dbGetQuery(con, "SELECT snapshot_hash FROM snapshots LIMIT 1")$snapshot_hash[[1]]
  unlockBinding("ledgr_snapshot_hash", ns); assign("ledgr_snapshot_hash", function(con, snapshot_id, ...) stored, envir = ns)
  at_late <- as.POSIXct("2003-10-01 12:00:00", tz = "UTC")
  t0 <- proc.time()[["elapsed"]]; r <- ledgr_facts_resolve(snap, "membership", "synthetic_members", at = at_late); el <- proc.time()[["elapsed"]] - t0
  rows <- DBI::dbGetQuery(con, "SELECT count(*) AS n FROM snapshot_membership")$n
  assign("ledgr_snapshot_hash", real, envir = ns); ledgr_snapshot_close(snap); unlink(db)
  out[[length(out) + 1L]] <- data.frame(sets = sets, membership_rows = rows, resolve_nohash_s = el, members = nrow(r$rows))
}
x <- do.call(rbind, out); print(x, row.names = FALSE)
write.csv(x, paste0(lw_work, "/resolve_scaling.csv"), row.names = FALSE)
