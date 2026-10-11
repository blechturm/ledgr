# Missing-bar runs on member sessions of a sealed availability snapshot
# (input to the LDG-3014 default stale horizon). Aggregates only: no
# instrument-level vendor rows are printed or written.
#
#   Rscript sharadar_gaps.R <snapshot.duckdb> <out_csv>
#
# For every instrument and open session on which it is a universe member and
# not yet known_inactive, a session without a bar is missing. Consecutive
# missing member sessions form a run; a run of L sessions leaves a held
# position stale for L sessions, so it exceeds a horizon h when L > h
# (frozen under exhausted = "freeze", a stop under "refuse"). Runs are
# classified as leading (before the instrument's first member bar), internal
# or trailing (after its last member bar). The counts are an upper bound for a
# strategy that holds every member.
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
args <- commandArgs(trailingOnly = TRUE)
con <- DBI::dbConnect(duckdb::duckdb(), args[[1L]], read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
runs <- DBI::dbGetQuery(con, "
  WITH s AS (
    SELECT session_close, row_number() OVER (ORDER BY session_close) AS k
    FROM snapshot_sessions WHERE status = 'open'
  ),
  term AS (
    SELECT instrument_id, MIN(effective_from) AS dead
    FROM snapshot_lifetime WHERE assertion = 'known_inactive' GROUP BY instrument_id
  ),
  m AS (
    SELECT DISTINCT mm.instrument_id, s.k, s.session_close
    FROM snapshot_membership mm
    JOIN s ON s.session_close >= mm.effective_from
          AND (mm.effective_to IS NULL OR s.session_close < mm.effective_to)
    LEFT JOIN term t ON t.instrument_id = mm.instrument_id
    WHERE mm.member AND (t.dead IS NULL OR s.session_close < t.dead)
  ),
  x AS (
    SELECT m.instrument_id, m.k, m.session_close, (b.ts_utc IS NOT NULL) AS has_bar
    FROM m LEFT JOIN snapshot_bars b ON b.instrument_id = m.instrument_id AND b.ts_utc = m.session_close
  ),
  bounds AS (
    SELECT instrument_id, MIN(k) FILTER (WHERE has_bar) AS first_bar, MAX(k) FILTER (WHERE has_bar) AS last_bar,
           COUNT(*) AS member_sessions
    FROM x GROUP BY instrument_id
  ),
  miss AS (
    SELECT instrument_id, k, session_close, k - row_number() OVER (PARTITION BY instrument_id ORDER BY k) AS grp
    FROM x WHERE NOT has_bar
  )
  SELECT miss.instrument_id AS inst, COUNT(*) AS len, MIN(miss.k) AS start_k, MIN(miss.session_close) AS start_ts,
         CASE WHEN MAX(miss.k) < MIN(bounds.first_bar) OR bounds.first_bar IS NULL THEN 'leading'
              WHEN MIN(miss.k) > MIN(bounds.last_bar) THEN 'trailing' ELSE 'internal' END AS kind
  FROM miss JOIN bounds USING (instrument_id)
  GROUP BY miss.instrument_id, miss.grp, bounds.first_bar
")
totals <- DBI::dbGetQuery(con, "
  WITH s AS (SELECT session_close FROM snapshot_sessions WHERE status = 'open')
  SELECT (SELECT COUNT(*) FROM s) AS open_sessions, (SELECT COUNT(DISTINCT instrument_id) FROM snapshot_membership WHERE member) AS member_instruments
")
cat(sprintf("open sessions %d; instruments ever a member %d\n", totals$open_sessions, totals$member_instruments))
cat(sprintf("missing-bar runs on member sessions: %d (internal %d, leading %d, trailing %d); missing member sessions %d\n",
            nrow(runs), sum(runs$kind == "internal"), sum(runs$kind == "leading"), sum(runs$kind == "trailing"), sum(runs$len)))
internal <- runs[runs$kind == "internal", , drop = FALSE]
breaks <- c(0, 1, 2, 3, 5, 10, 20, Inf)
labels <- c("1", "2", "3", "4-5", "6-10", "11-20", ">20")
cat("internal run lengths:\n")
print(table(cut(internal$len, breaks, labels)))
year <- as.integer(format(as.POSIXct(internal$start_ts, tz = "UTC"), "%Y"))
out <- do.call(rbind, lapply(c(0, 1, 2, 3, 5, 10, 20), function(h) {
  over <- internal$len > h
  data.frame(
    horizon = h,
    internal_runs_over = sum(over),
    instruments_over = length(unique(internal$inst[over])),
    first_over_year = if (any(over)) min(year[over]) else NA_integer_,
    years_with_any = length(unique(year[over])),
    frozen_member_sessions = sum(pmax(internal$len - h, 0)),
    trailing_runs_over = sum(runs$kind == "trailing" & runs$len > h)
  )
}))
print(out, row.names = FALSE)
utils::write.csv(out, args[[2L]], row.names = FALSE)
