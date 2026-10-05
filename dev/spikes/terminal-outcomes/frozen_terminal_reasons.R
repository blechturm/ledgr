# Which delisted instruments go untraded for more than five sessions before
# their last price, by vendor reason? Evidence for the frozen-terminal default.
# Rscript dev/spikes/terminal-outcomes/frozen_terminal_reasons.R
# Reads the private Sharadar lake read-only; prints aggregates only.
setwd("E:/ledgr-data/sharadar")
con <- DBI::dbConnect(duckdb::duckdb(), "lake/ledgr-research.duckdb", read_only = TRUE)
b <- "'canonical-20260906T055922734354Z-78941588416a97c6'"
q <- function(s) DBI::dbGetQuery(con, s)
x <- q(paste0("
WITH bars AS (SELECT instrument_id, trade_date, volume FROM core.daily_bars WHERE canonical_build_id = ", b, "),
last AS (SELECT instrument_id, MAX(trade_date) last_date FROM bars GROUP BY 1),
lt AS (SELECT b.instrument_id, MAX(b.trade_date) last_traded FROM bars b WHERE b.volume > 0 GROUP BY 1),
tail AS (SELECT l.instrument_id, l.last_date, lt.last_traded,
  (SELECT COUNT(*) FROM bars b2 WHERE b2.instrument_id = l.instrument_id AND b2.trade_date > lt.last_traded) AS untraded_tail
  FROM last l JOIN lt USING (instrument_id)),
inst AS (SELECT instrument_id, is_delisted FROM core.instruments WHERE canonical_build_id = ", b, "),
rsn AS (SELECT instrument_id, STRING_AGG(DISTINCT source_action_type, '+' ORDER BY source_action_type) reasons
  FROM core.corporate_actions WHERE canonical_build_id = ", b, " AND source_action_type IN
  ('acquisitionby','acquisitioncash','acquisitionstock','acquisitionelectcash','acquisitionelectstock','mergerto',
   'bankruptcyliquidation','regulatorydelisting','voluntarydelisting','spacmerger') GROUP BY 1)
SELECT CASE WHEN reasons IS NULL THEN 'no reason action'
            WHEN reasons LIKE '%bankruptcy%' THEN 'bankruptcy or liquidation'
            WHEN reasons LIKE '%regulatory%' THEN 'regulatory delisting'
            WHEN reasons LIKE '%voluntary%' THEN 'voluntary delisting'
            WHEN reasons LIKE '%acquisition%' OR reasons LIKE '%merger%' THEN 'acquisition or merger'
            ELSE reasons END AS reason_group,
       COUNT(*) FILTER (WHERE untraded_tail > 5) AS frozen_before_delisting,
       COUNT(*) AS all_delisted,
       ROUND(100.0 * COUNT(*) FILTER (WHERE untraded_tail > 5) / COUNT(*), 2) AS pct_frozen,
       MEDIAN(untraded_tail) FILTER (WHERE untraded_tail > 5) AS median_untraded_sessions
FROM tail JOIN inst USING (instrument_id) LEFT JOIN rsn USING (instrument_id)
WHERE is_delisted GROUP BY 1 ORDER BY 2 DESC"))
print(x, row.names = FALSE)
cat("total frozen before delisting:", sum(x$frozen_before_delisting), "of", sum(x$all_delisted), "\n")
DBI::dbDisconnect(con, shutdown = TRUE)
