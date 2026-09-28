# Zero-volume exposure under a liquidity filter known AT the decision.
#
# Review 2026-09-27 (second round): the decile split in no_trade_identifiability.R
# ranked instruments by median dollar volume over the WHOLE study window, which is
# not available at any decision inside it, and classified sessions by proximity to a
# FUTURE delisting, which is an explanatory label rather than a usable filter. Both
# overstate how easily the exposure is avoided.
#
# This uses only information available before the decision: a trailing median dollar
# volume over the previous 60 sessions, excluding the session being judged. It then
# asks the question that matters for execution rather than for description - given
# that ledgr fills at the NEXT session's open, how often does a decision that passes
# the filter get filled on a session where nothing traded.
#
#   Rscript dev/spikes/revision-exposure/pit_liquidity_filter.R

library(DBI)

LAKE <- "C:/Users/maxth/ledgr-data/sharadar/parquet"
OUT <- "dev/spikes/revision-exposure"
ACQ <- "20260905T092008Z"
FROM <- "2020-01-01"
TO <- "2024-12-31"
if (!dir.exists(LAKE)) stop("No lake at ", LAKE)
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

con <- dbConnect(duckdb::duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
dbExecute(con, "SET threads TO 8")
pq <- function(d) {
  sprintf("read_parquet('%s/%s/**/*.parquet', hive_partitioning=true)", LAKE, d)
}

rows <- list()
record <- function(topic, key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    topic = topic, key = key, value = as.character(value), unit = unit,
    derived_from = how, stringsAsFactors = FALSE
  )
}
record("provenance", "acquisition", ACQ, "id", "price vintage")
record("provenance", "window", paste(FROM, TO, sep = "/"), "range", "measured window")
record("provenance", "filter_basis", "trailing 60 sessions, excluding the judged session",
       "definition", "information available before the decision")

dbExecute(con, sprintf("
CREATE OR REPLACE TABLE p AS
SELECT ticker, try_cast(date AS DATE) AS d, try_cast(volume AS DOUBLE) AS v,
       try_cast(close AS DOUBLE) AS c, try_cast(open AS DOUBLE) AS o
FROM %s WHERE acquisition_id = '%s'
  AND try_cast(date AS DATE) BETWEEN DATE '%s' AND DATE '%s'", pq("stocks"), ACQ, FROM, TO))

# Trailing liquidity, and the next session's volume, which is the bar a decision at
# this session would actually fill against.
dbExecute(con, "
CREATE OR REPLACE TABLE s AS
SELECT ticker, d, v, c,
       median(v * c) OVER (PARTITION BY ticker ORDER BY d
                           ROWS BETWEEN 60 PRECEDING AND 1 PRECEDING) AS trail_dollar,
       count(*) OVER (PARTITION BY ticker ORDER BY d
                      ROWS BETWEEN 60 PRECEDING AND 1 PRECEDING) AS trail_n,
       lead(v) OVER (PARTITION BY ticker ORDER BY d) AS next_v
FROM p")

base <- dbGetQuery(con, "
SELECT count(*) AS sessions,
       sum(CASE WHEN trail_n >= 60 THEN 1 ELSE 0 END) AS sessions_with_full_history,
       sum(CASE WHEN v = 0 THEN 1 ELSE 0 END) AS zero_volume_today
FROM s")
for (k in names(base)) record("scope", k, base[[k]], "count", "before any filter")

cat("=== zero-volume exposure under a trailing liquidity filter known at the decision\n")
res <- dbGetQuery(con, "
WITH t AS (SELECT * FROM s WHERE trail_n >= 60)
SELECT thr.label, thr.min_dollar,
       count(*) AS decisions_passing_filter,
       round(100.0 * sum(CASE WHEN t.v = 0 THEN 1 ELSE 0 END) / count(*), 4) AS pct_today_zero_volume,
       sum(CASE WHEN t.next_v = 0 THEN 1 ELSE 0 END) AS fills_on_a_zero_volume_bar,
       round(100.0 * sum(CASE WHEN t.next_v = 0 THEN 1 ELSE 0 END)
             / nullif(sum(CASE WHEN t.next_v IS NOT NULL THEN 1 ELSE 0 END), 0), 4) AS pct_fill_bar_zero_volume
FROM t CROSS JOIN (
  SELECT 'no filter' AS label, 0 AS min_dollar UNION ALL
  SELECT '>= $100k', 100000 UNION ALL
  SELECT '>= $1M', 1000000 UNION ALL
  SELECT '>= $5M', 5000000 UNION ALL
  SELECT '>= $25M', 25000000
) thr
WHERE t.trail_dollar >= thr.min_dollar
GROUP BY 1, 2 ORDER BY thr.min_dollar")
print(res)
for (i in seq_len(nrow(res))) {
  tag <- gsub("[^a-z0-9]+", "_", tolower(res$label[[i]]))
  record("pit_filter", paste0(tag, "_decisions"), res$decisions_passing_filter[[i]],
         "count", "sessions passing a trailing-liquidity filter")
  record("pit_filter", paste0(tag, "_pct_today_zero_volume"),
         res$pct_today_zero_volume[[i]], "percent",
         "of those, share where nothing traded that session")
  record("pit_filter", paste0(tag, "_fills_on_zero_volume_bar"),
         res$fills_on_a_zero_volume_bar[[i]], "count",
         "next-session fill bar with no trading")
  record("pit_filter", paste0(tag, "_pct_fill_bar_zero_volume"),
         res$pct_fill_bar_zero_volume[[i]], "percent",
         "the execution-relevant rate: fill bar had no trading")
}

# How much of the panel a filter removes, so the exposure reduction is not read as
# free. A filter that discards most of the universe is a research decision.
cat("\n=== what each filter costs in universe coverage\n")
cov <- dbGetQuery(con, "
WITH t AS (SELECT * FROM s WHERE trail_n >= 60)
SELECT thr.label,
       round(100.0 * count(*) / (SELECT count(*) FROM t), 2) AS pct_sessions_retained,
       count(DISTINCT t.ticker) AS tickers_retained
FROM t CROSS JOIN (
  SELECT 'no filter' AS label, 0 AS min_dollar UNION ALL
  SELECT '>= $100k', 100000 UNION ALL
  SELECT '>= $1M', 1000000 UNION ALL
  SELECT '>= $5M', 5000000 UNION ALL
  SELECT '>= $25M', 25000000
) thr
WHERE t.trail_dollar >= thr.min_dollar
GROUP BY 1, thr.min_dollar ORDER BY thr.min_dollar")
print(cov)
for (i in seq_len(nrow(cov))) {
  tag <- gsub("[^a-z0-9]+", "_", tolower(cov$label[[i]]))
  record("filter_cost", paste0(tag, "_pct_sessions_retained"),
         cov$pct_sessions_retained[[i]], "percent", "coverage kept by this filter")
  record("filter_cost", paste0(tag, "_tickers_retained"), cov$tickers_retained[[i]],
         "count", "distinct tickers with at least one passing session")
}

evidence <- do.call(rbind, rows)
utils::write.csv(evidence, file.path(OUT, "pit_liquidity_evidence.csv"), row.names = FALSE)
cat("\nrows recorded:", nrow(evidence), "\n")
