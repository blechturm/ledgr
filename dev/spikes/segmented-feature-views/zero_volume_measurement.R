# Row coverage, and sessions printed with no recorded volume.
#
# The lag measurement showed nothing revises, because Sharadar's barrier facts
# have no knowledge clock. This asks what magnitude of effect IS present.
#
# Renamed and rescoped after adversarial review 2026-09-27. It previously asserted
# that the vendor had performed a carry. It measures an association - zero recorded
# volume alongside a close equal to the previous close - which is consistent with
# vendor imputation, with an official or reference close published without trading,
# and with other publication conventions. This file measures the association and
# names nothing as a carry. Reviewers must not read a mechanism out of it.
#
# ledgr's carry policy fills a session that has no observation. That presumes a
# source omits such sessions. Section 5.1 asks for run lengths of missing expected
# sessions split across four lifecycle locations: before the first observation,
# inside the active span, inside an accepted inactive interval, and after the last
# observation. This measures internal row coverage only, which speaks to the second
# location and, by defining coverage from observed endpoints, cannot see the first
# or the fourth. It is narrower than section 5.1's request.
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
       try_cast(open AS DOUBLE) AS o, try_cast(high AS DOUBLE) AS h,
       try_cast(low AS DOUBLE) AS lo, try_cast(close AS DOUBLE) AS c
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
record("row_coverage", "trading_days", g$trading_days, "count", "distinct session dates")
record("row_coverage", "instruments", g$instruments, "count", "tickers with coverage in window")
record("row_coverage", "instrument_sessions", g$instrument_sessions, "count",
       "sessions inside each ticker's own coverage")
record("row_coverage", "absent_sessions", g$absent_sessions, "count",
       "sessions inside coverage with no row at all")

# ------------- 1b. two qualifications the review raised, checked not assumed
# A row-count difference only measures absence if keys are unique, and a present
# row is only usable if its fields are.
q <- dbGetQuery(con, "
SELECT count(*) - count(DISTINCT (ticker, d)) AS duplicate_excess,
       sum(CASE WHEN o IS NULL OR h IS NULL OR lo IS NULL OR c IS NULL THEN 1 ELSE 0 END) AS any_ohlc_null,
       sum(CASE WHEN o <= 0 OR c <= 0 THEN 1 ELSE 0 END) AS nonpositive_px
FROM p")
record("row_coverage", "duplicate_ticker_date_excess", q$duplicate_excess, "count",
       "rows minus distinct keys; non-zero would let duplicates mask absence")
record("row_coverage", "rows_with_any_ohlc_null", q$any_ohlc_null, "count",
       "present rows that are not field-complete")
record("row_coverage", "rows_with_nonpositive_price", q$nonpositive_px, "count",
       "present rows whose open or close is not usable")

# ---------------------------- 2. a row is printed; does anything trade?
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
record("zero_volume", "rows_total", z$rows_total, "count", "price rows in window")
record("zero_volume", "zero_volume_rows", z$zero_volume, "count",
       "sessions printed with no shares traded")
record("zero_volume", "zero_volume_pct",
       round(100 * z$zero_volume / z$rows_total, 3), "percent", "of all price rows")
record("zero_volume", "tickers_affected", z$tickers_affected, "count",
       "tickers with at least one such session")
record("zero_volume", "zero_volume_close_repeats_pct",
       round(100 * z$zero_vol_close_repeats / z$zero_vol_comparable, 2), "percent",
       "zero-volume sessions whose close equals the previous close")
record("zero_volume", "traded_close_repeats_pct",
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
# Corrected after review: sessions IN runs over the age is not the number BEYOND
# the age. A seven-session run exceeds an age of five by two, not by seven.
e <- dbGetQuery(con, "
SELECT sum(greatest(len - 5, 0)) AS beyond_5, sum(greatest(len - 20, 0)) AS beyond_20
FROM runs")
record("run_length", "sessions_beyond_age_5", e$beyond_5, "count",
       "sum of max(run length - 5, 0); what an age of five would leave unfilled")
record("run_length", "sessions_beyond_age_20", e$beyond_20, "count",
       "sum of max(run length - 20, 0)")
record("run_length", "pct_of_panel_beyond_age_5",
       round(100 * e$beyond_5 / z$rows_total, 3), "percent",
       "corrected: not the share in runs over five")

# ------------------------------- 4. what the barrier rule could protect, if any
# Pinned, not max(): review 2026-09-27 found an unrecorded latest actions vintage
# paired with a pinned price vintage, so provenance was not reproducible.
ACQ_ACTIONS <- "20260905T092008Z"
record("provenance", "actions_acquisition", ACQ_ACTIONS, "id", "actions vintage")
dbExecute(con, sprintf("
CREATE OR REPLACE TABLE ev AS
SELECT ticker, action, try_cast(date AS DATE) AS d FROM %s
WHERE acquisition_id = '%s'
  AND action IN ('dividend','split','delisted','regulatorydelisting',
                 'voluntarydelisting','bankruptcyliquidation')",
  pq("actions"), ACQ_ACTIONS))
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
         paste("zero-volume runs whose span contains a selected action date;",
               "applies no price-basis rule, knowledge cutoff, carry path or",
               "lifecycle barrier, so this is an upper envelope and not the set",
               "the proposed controls would govern"))
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
utils::write.csv(evidence, file.path(OUT, "zero_volume_evidence.csv"),
                 row.names = FALSE)
print(evidence, right = FALSE, max = 400)
