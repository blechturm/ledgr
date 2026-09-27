# How much of the carry has the vendor already done?
#
# The lag measurement showed nothing revises, because Sharadar's barrier facts
# have no knowledge clock. This asks the next question: what is the magnitude of
# the bias that IS present. It turns out not to be where the synthesis is looking.
#
# ledgr's carry policy fills a session that has no observation. That presumes the
# vendor omits such sessions. This measures whether it does.
#
# NOT part of the checker's reproducible set: reads a 15 GB external lake at an
# absolute path on one machine. Read-only; nothing in the lake is written.
#
#   Rscript dev/spikes/segmented-feature-views/vendor_carry_measurement.R

library(DBI)

LAKE <- "C:/Users/maxth/ledgr-data/sharadar/parquet"
OUT <- "dev/spikes/segmented-feature-views"
ACQ <- "20260905T092008Z"
FROM <- "2020-01-01"
TO <- "2024-12-31"
if (!dir.exists(LAKE)) stop("Sharadar lake not present at ", LAKE)

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

dbExecute(con, sprintf("
CREATE OR REPLACE TABLE p AS
SELECT ticker, try_cast(date AS DATE) AS d, try_cast(volume AS DOUBLE) AS v,
       try_cast(close AS DOUBLE) AS c
FROM %s WHERE acquisition_id = '%s'
  AND try_cast(date AS DATE) BETWEEN DATE '%s' AND DATE '%s'",
  pq("stocks"), ACQ, FROM, TO))

# --------------------------------------------- 1. are there gaps to carry into?
# Venue axis proxy: the dates on which anything traded. Coverage: each ticker's
# own first and last print inside the window.
dbExecute(con, "CREATE OR REPLACE TABLE cal AS
  SELECT d, row_number() OVER (ORDER BY d) AS idx FROM (SELECT DISTINCT d FROM p)")
dbExecute(con, "CREATE OR REPLACE TABLE oi AS
  SELECT p.ticker, c.idx FROM p JOIN cal c USING (d)")
g <- dbGetQuery(con, "
WITH cov AS (SELECT ticker, min(idx) lo, max(idx) hi FROM oi GROUP BY 1),
     grid AS (SELECT cov.ticker, c.idx FROM cov JOIN cal c ON c.idx BETWEEN cov.lo AND cov.hi)
SELECT (SELECT count(*) FROM cal) AS trading_days,
       (SELECT count(*) FROM cov) AS instruments,
       count(*) AS instrument_sessions,
       count(*) - (SELECT count(*) FROM oi) AS absent_sessions
FROM grid")
record("gaps", "trading_days", g$trading_days, "count", "distinct session dates")
record("gaps", "instruments", g$instruments, "count", "tickers with coverage in window")
record("gaps", "instrument_sessions", g$instrument_sessions, "count",
       "sessions inside each ticker's own coverage")
record("gaps", "absent_sessions", g$absent_sessions, "count",
       "sessions inside coverage with no row at all")

# ---------------------------- 2. the vendor prints a row; does anything trade?
z <- dbGetQuery(con, "
WITH s AS (SELECT ticker, d, v, c, lag(c) OVER (PARTITION BY ticker ORDER BY d) AS prev_c FROM p)
SELECT count(*) AS rows_total,
       sum(CASE WHEN v = 0 THEN 1 ELSE 0 END) AS zero_volume,
       count(DISTINCT CASE WHEN v = 0 THEN ticker END) AS tickers_affected,
       sum(CASE WHEN v = 0 AND c = prev_c THEN 1 ELSE 0 END) AS zero_vol_close_repeats,
       sum(CASE WHEN v = 0 AND prev_c IS NOT NULL THEN 1 ELSE 0 END) AS zero_vol_comparable,
       sum(CASE WHEN v > 0 AND c = prev_c THEN 1 ELSE 0 END) AS traded_close_repeats,
       sum(CASE WHEN v > 0 AND prev_c IS NOT NULL THEN 1 ELSE 0 END) AS traded_comparable
FROM s")
record("silent_carry", "rows_total", z$rows_total, "count", "price rows in window")
record("silent_carry", "zero_volume_rows", z$zero_volume, "count",
       "sessions printed with no shares traded")
record("silent_carry", "zero_volume_pct",
       round(100 * z$zero_volume / z$rows_total, 3), "percent", "of all price rows")
record("silent_carry", "tickers_affected", z$tickers_affected, "count",
       "tickers with at least one such session")
record("silent_carry", "zero_volume_close_repeats_pct",
       round(100 * z$zero_vol_close_repeats / z$zero_vol_comparable, 2), "percent",
       "zero-volume sessions whose close equals the previous close")
record("silent_carry", "traded_close_repeats_pct",
       round(100 * z$traded_close_repeats / z$traded_comparable, 2), "percent",
       "same for traded sessions: the control")

# ------------------- 3. run lengths, against the carry age a policy would allow
dbExecute(con, "
CREATE OR REPLACE TABLE runs AS
WITH s AS (
  SELECT ticker, d, v,
         row_number() OVER (PARTITION BY ticker ORDER BY d)
       - row_number() OVER (PARTITION BY ticker, (v = 0) ORDER BY d) AS grp
  FROM p
)
SELECT ticker, min(d) AS d0, max(d) AS d1, count(*) AS len
FROM s WHERE v = 0 GROUP BY ticker, grp")
r <- dbGetQuery(con, "
SELECT count(*) AS runs, median(len) AS p50, quantile_cont(len, 0.95) AS p95,
       max(len) AS max_len,
       sum(CASE WHEN len > 5 THEN len ELSE 0 END) AS sessions_in_runs_over_5,
       sum(CASE WHEN len > 20 THEN len ELSE 0 END) AS sessions_in_runs_over_20
FROM runs")
for (k in names(r)) {
  record("run_length", k, r[[k]],
         if (grepl("^runs$|sessions", k)) "count" else "sessions",
         "consecutive zero-volume sessions")
}
record("run_length", "pct_of_panel_in_runs_over_5",
       round(100 * r$sessions_in_runs_over_5 / z$rows_total, 3), "percent",
       "sessions a five-session carry age would have refused")

# ------------------------------- 4. what the barrier rule could protect, if any
dbExecute(con, sprintf("
CREATE OR REPLACE TABLE ev AS
SELECT ticker, action, try_cast(date AS DATE) AS d FROM %s
WHERE acquisition_id = (SELECT max(acquisition_id) FROM %s)
  AND action IN ('dividend','split','delisted','regulatorydelisting',
                 'voluntarydelisting','bankruptcyliquidation')",
  pq("actions"), pq("actions")))
b <- dbGetQuery(con, "
WITH j AS (
  SELECT r.ticker, r.d0, r.d1, r.len,
         count(*) FILTER (WHERE e.action = 'dividend') AS n_div,
         count(*) FILTER (WHERE e.action <> 'dividend') AS n_other
  FROM runs r JOIN ev e ON e.ticker = r.ticker AND e.d >= r.d0 AND e.d <= r.d1
  GROUP BY 1, 2, 3, 4
)
SELECT count(*) AS runs_spanning_an_event, sum(len) AS sessions_in_them,
       sum(CASE WHEN n_div > 0 THEN 1 ELSE 0 END) AS via_dividend,
       sum(CASE WHEN n_other > 0 THEN 1 ELSE 0 END) AS via_split_or_terminal
FROM j")
for (k in names(b)) {
  record("barrier_reach", k, b[[k]], "count",
         "zero-volume runs whose span contains a barrier event")
}

# ------------------------------------ 5. does the vendor print past a delisting?
t <- dbGetQuery(con, "
WITH t AS (
  SELECT ticker, min(d) AS term_d FROM ev
  WHERE action IN ('delisted','regulatorydelisting','voluntarydelisting',
                   'bankruptcyliquidation') GROUP BY 1
)
SELECT count(*) AS rows_after_terminal, count(DISTINCT p.ticker) AS tickers
FROM p JOIN t USING (ticker) WHERE p.d > t.term_d")
record("post_terminal", "rows_after_terminal", t$rows_after_terminal, "count",
       "price rows dated after the ticker's terminal action")
record("post_terminal", "tickers", t$tickers, "count", "tickers affected")

evidence <- do.call(rbind, rows)
utils::write.csv(evidence, file.path(OUT, "vendor_carry_evidence.csv"),
                 row.names = FALSE)
print(evidence, right = FALSE, max = 400)
