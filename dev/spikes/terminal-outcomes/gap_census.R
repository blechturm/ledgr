# Gap census over the private Sharadar lake (read-only).
#
# Question: how often does a US equity have no daily price for more than N NYSE
# sessions, (a) inside its price history (prices resume later), and (b) at its
# end, before the vendor's delisting date? Broken down by point-in-time S&P 500
# membership, vendor category and all instruments.
#
# Rscript dev/spikes/terminal-outcomes/gap_census.R <out_dir> [threshold=5]
# Requires SHARADAR_DATA_ROOT (default E:/ledgr-data/sharadar). Writes only
# aggregate CSVs; no instrument-level vendor rows leave the lake.
args <- commandArgs(TRUE)
out_dir <- args[[1L]]
threshold <- if (length(args) >= 2L) as.integer(args[[2L]]) else 5L
root <- Sys.getenv("SHARADAR_DATA_ROOT", "E:/ledgr-data/sharadar")
build <- "canonical-20260906T055922734354Z-78941588416a97c6"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
setwd(root)
con <- DBI::dbConnect(duckdb::duckdb(), "lake/ledgr-research.duckdb", read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
q <- function(sql, ...) DBI::dbGetQuery(con, sql, ...)
x <- function(sql) invisible(DBI::dbExecute(con, sql))
x("SET memory_limit = '16GB'"); x("SET threads = 8")

# ---- NYSE session calendar (QuantLib via qlcal) --------------------------------
qlcal::setCalendar("UnitedStates/NYSE")
range <- q(sprintf("SELECT MIN(trade_date) d0, MAX(trade_date) d1 FROM core.daily_bars WHERE canonical_build_id = '%s'", build))
sessions <- qlcal::getBusinessDays(as.Date(range$d0), as.Date(range$d1))
duckdb::duckdb_register(con, "cal_raw", data.frame(d = sessions))
x("CREATE TEMP TABLE cal AS SELECT d, CAST(ROW_NUMBER() OVER (ORDER BY d) AS INTEGER) AS idx FROM cal_raw")
end_idx <- q("SELECT MAX(idx) m FROM cal")$m

x(sprintf("CREATE TEMP TABLE bars AS SELECT instrument_id, trade_date, volume FROM core.daily_bars WHERE canonical_build_id = '%s'", build))
cal_check <- q("SELECT
  (SELECT COUNT(*) FROM bars b ANTI JOIN cal c ON b.trade_date = c.d) AS bars_on_non_sessions,
  (SELECT COUNT(*) FROM cal c ANTI JOIN (SELECT DISTINCT trade_date FROM bars) b ON b.trade_date = c.d) AS sessions_without_any_bar,
  (SELECT COUNT(*) FROM cal) AS sessions, (SELECT COUNT(*) FROM bars) AS bars")
empty_sessions <- q("SELECT d FROM cal ANTI JOIN (SELECT DISTINCT trade_date FROM bars) b ON b.trade_date = cal.d ORDER BY d")

x("CREATE TEMP TABLE bi AS SELECT b.instrument_id, b.trade_date, b.volume, c.idx FROM bars b JOIN cal c ON b.trade_date = c.d")

# ---- instrument attributes ------------------------------------------------------
x(sprintf("CREATE TEMP TABLE inst AS
  SELECT i.instrument_id, i.is_delisted, t.category, t.exchange, t.scalemarketcap
  FROM core.instruments i
  LEFT JOIN (SELECT permaticker, ANY_VALUE(category) category, ANY_VALUE(exchange) exchange,
                    ANY_VALUE(scalemarketcap) scalemarketcap
             FROM raw.sharadar_tickers_20260905T092008Z WHERE \"table\" = 'SEP' GROUP BY permaticker) t
    ON t.permaticker = i.source_permaticker
  WHERE i.canonical_build_id = '%s'", build))
x(sprintf("CREATE TEMP TABLE sp AS SELECT instrument_id, effective_from, COALESCE(effective_to, DATE '9999-12-31') effective_to
  FROM core.reference_membership WHERE canonical_build_id = '%s' AND reference_id = 'sharadar_sp500'
  AND record_kind = 'interval' AND quality_status = 'accepted'", build))

# ---- interior gaps: consecutive bars more than `threshold` sessions apart --------
x(sprintf("CREATE TEMP TABLE gaps AS
  SELECT * FROM (
    SELECT instrument_id, trade_date AS last_before, idx,
           LEAD(idx) OVER w AS next_idx, LEAD(trade_date) OVER w AS next_date
    FROM bi WINDOW w AS (PARTITION BY instrument_id ORDER BY idx)) g
  WHERE next_idx - idx - 1 > %d", threshold))
x("ALTER TABLE gaps ADD COLUMN missing INTEGER"); x("UPDATE gaps SET missing = next_idx - idx - 1")

# ---- price-history spans and terminal tails --------------------------------------
x(sprintf("CREATE TEMP TABLE span AS SELECT instrument_id, MIN(idx) first_idx, MAX(idx) last_idx,
  MAX(trade_date) last_date, COUNT(*) n_bars FROM bi GROUP BY instrument_id"))
x(sprintf("CREATE TEMP TABLE delist AS SELECT instrument_id, MIN(effective_date) delist_date
  FROM core.corporate_actions WHERE canonical_build_id = '%s' AND quality_status = 'accepted'
  AND canonical_action_type = 'delisting' AND effective_date IS NOT NULL GROUP BY instrument_id", build))
x(sprintf("CREATE TEMP TABLE reason AS SELECT instrument_id, STRING_AGG(DISTINCT source_action_type, '+' ORDER BY source_action_type) reasons
  FROM core.corporate_actions WHERE canonical_build_id = '%s' AND source_action_type IN
  ('acquisitionby','acquisitioncash','acquisitionstock','acquisitionelectcash','acquisitionelectstock','mergerto',
   'bankruptcyliquidation','regulatorydelisting','voluntarydelisting','spacmerger') GROUP BY instrument_id", build))
x("CREATE TEMP TABLE tail AS
  SELECT s.*, i.is_delisted, d.delist_date,
         (SELECT MIN(idx) FROM cal WHERE cal.d >= d.delist_date) AS delist_idx,
         r.reasons
  FROM span s JOIN inst i USING (instrument_id) LEFT JOIN delist d USING (instrument_id)
  LEFT JOIN reason r USING (instrument_id)")
x("ALTER TABLE tail ADD COLUMN lag INTEGER")
x("UPDATE tail SET lag = delist_idx - last_idx - 1")  # sessions with no price before the delisting date

# ---- point-in-time S&P 500 flags ---------------------------------------------------
x("ALTER TABLE gaps ADD COLUMN sp500 BOOLEAN")
x("UPDATE gaps SET sp500 = EXISTS (SELECT 1 FROM sp WHERE sp.instrument_id = gaps.instrument_id
   AND sp.effective_from <= gaps.last_before AND gaps.last_before < sp.effective_to)")
x("ALTER TABLE tail ADD COLUMN sp500 BOOLEAN")
x("UPDATE tail SET sp500 = EXISTS (SELECT 1 FROM sp WHERE sp.instrument_id = tail.instrument_id
   AND sp.effective_from <= tail.last_date AND tail.last_date < sp.effective_to)")

# ---- exposure denominators (instrument-sessions inside the price history) --------
x("CREATE TEMP TABLE sp_sessions AS SELECT COUNT(*) n FROM bi JOIN sp ON sp.instrument_id = bi.instrument_id
   AND sp.effective_from <= bi.trade_date AND bi.trade_date < sp.effective_to")

bucket <- "CASE WHEN missing <= 10 THEN 'a 6-10' WHEN missing <= 20 THEN 'b 11-20' WHEN missing <= 60 THEN 'c 21-60'
  WHEN missing <= 250 THEN 'd 61-250' ELSE 'e >250' END"
group_expr <- "CASE WHEN category LIKE 'Domestic Common Stock%' THEN 'Domestic common'
  WHEN category LIKE 'ADR%' THEN 'ADR' WHEN category LIKE '%Preferred%' THEN 'Preferred'
  WHEN category LIKE 'Canadian%' THEN 'Canadian' ELSE COALESCE(category, '(none)') END"

res <- list()
res$calendar <- cbind(cal_check, threshold = threshold, first = range$d0, last = range$d1)
res$empty_sessions <- empty_sessions
res$exposure <- q(sprintf("SELECT 'all' universe, SUM(last_idx - first_idx + 1) inst_sessions, COUNT(*) instruments FROM span
  UNION ALL SELECT 'sp500', (SELECT n FROM sp_sessions), (SELECT COUNT(DISTINCT instrument_id) FROM sp)
  UNION ALL SELECT %s, SUM(last_idx - first_idx + 1), COUNT(*) FROM span JOIN inst USING (instrument_id) GROUP BY 1",
  sub("CASE", "CASE", group_expr)))
res$interior_by_universe <- q(sprintf("
  SELECT 'all' universe, COUNT(*) episodes, COUNT(DISTINCT instrument_id) instruments, MEDIAN(missing) median_missing, MAX(missing) max_missing FROM gaps
  UNION ALL SELECT 'sp500', COUNT(*), COUNT(DISTINCT instrument_id), MEDIAN(missing), MAX(missing) FROM gaps WHERE sp500
  UNION ALL SELECT %s, COUNT(*), COUNT(DISTINCT instrument_id), MEDIAN(missing), MAX(missing)
    FROM gaps JOIN inst USING (instrument_id) GROUP BY 1", group_expr))
res$interior_buckets <- q(sprintf("SELECT %s bucket, COUNT(*) all_episodes, COUNT(*) FILTER (WHERE sp500) sp500_episodes
  FROM gaps GROUP BY 1 ORDER BY 1", bucket))
res$interior_by_year <- q("SELECT YEAR(last_before) AS yr, COUNT(*) all_episodes, COUNT(*) FILTER (WHERE sp500) sp500_episodes
  FROM gaps GROUP BY 1 ORDER BY 1")
res$interior_sp500_detail <- q("SELECT YEAR(last_before) AS yr, missing, last_before, next_date FROM gaps WHERE sp500 ORDER BY last_before")
res$tail_summary <- q(sprintf("SELECT
  CASE WHEN is_delisted AND delist_idx IS NOT NULL THEN 'delisted, delisting date known'
       WHEN is_delisted THEN 'delisted, no delisting date'
       WHEN %d - last_idx > %d THEN 'active flag, prices stop early'
       ELSE 'active, prices to dataset end' END AS tail_class,
  COUNT(*) instruments, COUNT(*) FILTER (WHERE sp500) sp500_at_last_price
  FROM tail GROUP BY 1 ORDER BY 1", end_idx, threshold))
res$tail_lag <- q(sprintf("SELECT CASE WHEN lag IS NULL THEN 'z unknown' WHEN lag < 0 THEN 'a prices after delisting date'
  WHEN lag = 0 THEN 'b 0' WHEN lag <= %d THEN 'c 1-%d' WHEN lag <= 10 THEN 'd %d-10' WHEN lag <= 20 THEN 'e 11-20'
  WHEN lag <= 60 THEN 'f 21-60' WHEN lag <= 250 THEN 'g 61-250' ELSE 'h >250' END lag_sessions,
  COUNT(*) delisted, COUNT(*) FILTER (WHERE sp500) sp500_at_last_price
  FROM tail WHERE is_delisted GROUP BY 1 ORDER BY 1", threshold, threshold, threshold + 1L))
res$tail_lag_by_reason <- q(sprintf("SELECT COALESCE(reasons, '(no reason action)') reasons, COUNT(*) delisted,
  COUNT(*) FILTER (WHERE lag > %d) lag_over_threshold, MEDIAN(lag) median_lag,
  COUNT(*) FILTER (WHERE sp500) sp500, COUNT(*) FILTER (WHERE sp500 AND lag > %d) sp500_lag_over_threshold
  FROM tail WHERE is_delisted GROUP BY 1 HAVING COUNT(*) >= 20 ORDER BY delisted DESC", threshold, threshold))
res$tail_lag_by_year <- q(sprintf("SELECT YEAR(last_date) AS yr, COUNT(*) delisted, COUNT(*) FILTER (WHERE lag > %d) lag_over_threshold,
  COUNT(*) FILTER (WHERE sp500) sp500, COUNT(*) FILTER (WHERE sp500 AND lag > %d) sp500_lag_over_threshold
  FROM tail WHERE is_delisted GROUP BY 1 ORDER BY 1", threshold, threshold))
res$sp500_tail_detail <- q("SELECT YEAR(last_date) AS yr, lag, reasons FROM tail WHERE is_delisted AND sp500 ORDER BY lag DESC NULLS LAST")

# ---- zero-volume runs: the vendor carries the last price on no-trade sessions ----
# A run is a maximal block of consecutive sessions with volume = 0. Interior runs
# end in a traded session; terminal runs reach the instrument's last bar; leading
# runs start at its first bar.
x("CREATE TEMP TABLE zr AS
  WITH f AS (SELECT instrument_id, trade_date, idx, (volume = 0) AS z,
                    idx - ROW_NUMBER() OVER (PARTITION BY instrument_id, (volume = 0) ORDER BY idx) AS grp
             FROM bi)
  SELECT instrument_id, MIN(idx) start_idx, MAX(idx) end_idx, MIN(trade_date) start_date,
         MAX(trade_date) end_date, COUNT(*) missing
  FROM f WHERE z GROUP BY instrument_id, grp")
x("ALTER TABLE zr ADD COLUMN kind VARCHAR")
x("UPDATE zr SET kind = CASE WHEN zr.end_idx = s.last_idx AND zr.start_idx = s.first_idx THEN 'never traded'
  WHEN zr.end_idx = s.last_idx THEN 'terminal' WHEN zr.start_idx = s.first_idx THEN 'leading' ELSE 'interior' END
  FROM span s WHERE s.instrument_id = zr.instrument_id")
x("ALTER TABLE zr ADD COLUMN sp500 BOOLEAN")
x("UPDATE zr SET sp500 = EXISTS (SELECT 1 FROM sp WHERE sp.instrument_id = zr.instrument_id
   AND sp.effective_from <= zr.start_date AND zr.start_date < sp.effective_to)")
x("ALTER TABLE zr ADD COLUMN is_delisted BOOLEAN")
x("UPDATE zr SET is_delisted = i.is_delisted FROM inst i WHERE i.instrument_id = zr.instrument_id")
zbucket <- "CASE WHEN missing <= 5 THEN 'a 1-5' WHEN missing <= 10 THEN 'b 6-10' WHEN missing <= 20 THEN 'c 11-20'
  WHEN missing <= 60 THEN 'd 21-60' WHEN missing <= 250 THEN 'e 61-250' ELSE 'f >250' END"
over <- sprintf("missing > %d", threshold)
res$zero_volume_rows <- q("SELECT COUNT(*) FILTER (WHERE volume = 0) zero_volume_rows, COUNT(*) AS total_rows FROM bi")
res$zero_runs_by_kind <- q(sprintf("SELECT kind, COUNT(*) runs, COUNT(*) FILTER (WHERE %s) runs_over_threshold,
  COUNT(DISTINCT instrument_id) FILTER (WHERE %s) instruments_over_threshold,
  COUNT(*) FILTER (WHERE %s AND sp500) sp500_runs_over_threshold,
  COUNT(DISTINCT instrument_id) FILTER (WHERE %s AND sp500) sp500_instruments_over_threshold
  FROM zr GROUP BY 1 ORDER BY 1", over, over, over, over))
res$zero_runs_buckets <- q(sprintf("SELECT kind, %s bucket, COUNT(*) runs, COUNT(*) FILTER (WHERE sp500) sp500_runs
  FROM zr GROUP BY 1, 2 ORDER BY 1, 2", zbucket))
res$zero_runs_interior_by_group <- q(sprintf("SELECT %s grp, COUNT(*) runs_over_threshold,
  COUNT(DISTINCT instrument_id) instruments, MEDIAN(missing) median_missing
  FROM zr JOIN inst USING (instrument_id) WHERE kind = 'interior' AND %s GROUP BY 1 ORDER BY 2 DESC",
  group_expr, over))
res$zero_runs_interior_by_year <- q(sprintf("SELECT YEAR(start_date) AS yr, COUNT(*) runs_over_threshold,
  COUNT(*) FILTER (WHERE sp500) sp500_runs_over_threshold FROM zr WHERE kind = 'interior' AND %s GROUP BY 1 ORDER BY 1", over))
res$zero_runs_sp500_detail <- q(sprintf("SELECT kind, YEAR(start_date) AS yr, missing, start_date, end_date FROM zr
  WHERE sp500 AND %s ORDER BY start_date", over))
res$zero_runs_terminal_delisted <- q(sprintf("SELECT is_delisted, COUNT(*) terminal_runs, COUNT(*) FILTER (WHERE %s) over_threshold,
  COUNT(*) FILTER (WHERE %s AND sp500) sp500_over_threshold, MEDIAN(missing) median_missing
  FROM zr WHERE kind = 'terminal' GROUP BY 1", over, over))

for (n in names(res)) utils::write.csv(res[[n]], file.path(out_dir, paste0(n, ".csv")), row.names = FALSE)
for (n in setdiff(names(res), c("interior_sp500_detail", "sp500_tail_detail", "empty_sessions", "zero_runs_sp500_detail"))) { cat("\n##", n, "\n"); print(res[[n]], row.names = FALSE) }
cat("\n## empty sessions (first 20)\n"); print(head(res$empty_sessions, 20), row.names = FALSE)
cat("\n## sp500 interior detail rows:", nrow(res$interior_sp500_detail), " sp500 delisted rows:", nrow(res$sp500_tail_detail), "\n")
