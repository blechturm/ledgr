# Is a no-trade session identifiable from the source data, and how big is it?
#
# Two questions, kept apart:
#
#   A. IDENTIFIABILITY. Can a consumer tell, from the shipped fields alone, that no
#      trading occurred on a session? `volume = 0` is the candidate flag. A second,
#      independent signal is OHLC degeneracy: with no trades there is no range, so
#      open = high = low = close. Agreement between two independent signals is what
#      makes the condition identifiable rather than merely suspected.
#
#   B. MAGNITUDE, where it matters. A rate over the whole panel is not the exposure
#      of a research universe. Reported by in-window liquidity decile, by year, by
#      concentration across instruments, and around terminal events.
#
# Read-only. No mechanism is asserted: a zero-volume session with a repeated close
# is consistent with vendor imputation and with an official close published without
# trading. This measures what is identifiable, not what produced it.
#
#   Rscript dev/spikes/revision-exposure/no_trade_identifiability.R

library(DBI)

LAKE <- "C:/Users/maxth/ledgr-data/sharadar/sharadar" # placeholder, replaced below
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
record("provenance", "acquisition", ACQ, "id", "price and action vintage")
record("provenance", "window", paste(FROM, TO, sep = "/"), "range", "measured window")

dbExecute(con, sprintf("
CREATE OR REPLACE TABLE p AS
SELECT ticker, try_cast(date AS DATE) AS d, try_cast(volume AS DOUBLE) AS v,
       try_cast(open AS DOUBLE) AS o, try_cast(high AS DOUBLE) AS h,
       try_cast(low AS DOUBLE) AS lo, try_cast(close AS DOUBLE) AS c
FROM %s WHERE acquisition_id = '%s'
  AND try_cast(date AS DATE) BETWEEN DATE '%s' AND DATE '%s'", pq("stocks"), ACQ, FROM, TO))

# ===================================================== A. identifiability
cat("=== A. is the no-trade condition identifiable from shipped fields?\n")
a <- dbGetQuery(con, "
WITH s AS (
  SELECT ticker, d, v, o, h, lo, c,
         lag(c) OVER (PARTITION BY ticker ORDER BY d) AS prev_c
  FROM p
)
SELECT count(*) AS rows_total,
       sum(CASE WHEN v IS NULL THEN 1 ELSE 0 END) AS volume_null,
       sum(CASE WHEN v = 0 THEN 1 ELSE 0 END) AS volume_zero,
       sum(CASE WHEN v = 0 AND o = h AND h = lo AND lo = c THEN 1 ELSE 0 END) AS zerovol_degenerate,
       sum(CASE WHEN v = 0 AND h > lo THEN 1 ELSE 0 END) AS zerovol_with_range,
       sum(CASE WHEN v = 0 AND o = h AND h = lo AND lo = c AND c = prev_c THEN 1 ELSE 0 END) AS zerovol_degenerate_and_repeated,
       sum(CASE WHEN v > 0 AND o = h AND h = lo AND lo = c THEN 1 ELSE 0 END) AS traded_degenerate
FROM s")
print(a)
for (k in names(a)) record("identifiability", k, a[[k]], "count", "shipped-field signals")
record("identifiability", "zerovol_degenerate_pct_of_zerovol",
       round(100 * a$zerovol_degenerate / a$volume_zero, 2), "percent",
       "zero-volume sessions that also show no intraday range")
record("identifiability", "traded_degenerate_pct_of_traded",
       round(100 * a$traded_degenerate / (a$rows_total - a$volume_zero), 3), "percent",
       "control: traded sessions that happen to be degenerate")

# ===================================================== B. magnitude, stratified
# In-window liquidity, computed from traded sessions only, so a name that never
# trades does not define its own liquidity from its zero rows.
dbExecute(con, "
CREATE OR REPLACE TABLE liq AS
WITH t AS (SELECT ticker, median(v * c) AS med_dollar, count(*) AS traded_sessions
           FROM p WHERE v > 0 GROUP BY 1)
SELECT ticker, med_dollar, traded_sessions,
       ntile(10) OVER (ORDER BY med_dollar) AS decile
FROM t")

cat("\n=== B1. zero-volume rate by in-window dollar-volume decile (10 = most liquid)\n")
b1 <- dbGetQuery(con, "
SELECT l.decile, count(DISTINCT p.ticker) AS tickers, count(*) AS sessions,
       sum(CASE WHEN p.v = 0 THEN 1 ELSE 0 END) AS zero_volume,
       round(100.0 * sum(CASE WHEN p.v = 0 THEN 1 ELSE 0 END) / count(*), 3) AS pct,
       round(median(l.med_dollar), 0) AS median_dollar_volume
FROM p JOIN liq l USING (ticker) GROUP BY 1 ORDER BY 1")
print(b1)
for (i in seq_len(nrow(b1))) {
  record("by_liquidity_decile", paste0("d", b1$decile[[i]], "_pct"), b1$pct[[i]],
         "percent", "zero-volume share of sessions in this decile")
  record("by_liquidity_decile", paste0("d", b1$decile[[i]], "_sessions"),
         b1$sessions[[i]], "count", "sessions in this decile")
}

cat("\n=== B2. concentration: how few instruments hold the exposure\n")
b2 <- dbGetQuery(con, "
WITH z AS (SELECT ticker, sum(CASE WHEN v = 0 THEN 1 ELSE 0 END) AS n
           FROM p GROUP BY 1 HAVING n > 0),
     r AS (SELECT ticker, n, sum(n) OVER (ORDER BY n DESC ROWS UNBOUNDED PRECEDING) AS cum,
                  (SELECT sum(n) FROM z) AS total,
                  row_number() OVER (ORDER BY n DESC) AS rk FROM z)
SELECT (SELECT count(*) FROM z) AS tickers_with_any,
       min(CASE WHEN cum >= 0.5 * total THEN rk END) AS tickers_for_half,
       min(CASE WHEN cum >= 0.9 * total THEN rk END) AS tickers_for_ninety
FROM r")
print(b2)
for (k in names(b2)) record("concentration", k, b2[[k]], "count",
                            "instruments ranked by zero-volume session count")

cat("\n=== B3. by year\n")
b3 <- dbGetQuery(con, "
SELECT year(d) AS yr, count(*) AS sessions,
       round(100.0 * sum(CASE WHEN v = 0 THEN 1 ELSE 0 END) / count(*), 3) AS pct
FROM p GROUP BY 1 ORDER BY 1")
print(b3)
for (i in seq_len(nrow(b3))) {
  record("by_year", paste0("y", b3$yr[[i]], "_pct"), b3$pct[[i]], "percent",
         "zero-volume share of sessions in this year")
}

cat("\n=== B4. proximity to a terminal action\n")
dbExecute(con, sprintf("
CREATE OR REPLACE TABLE term AS
SELECT ticker, min(try_cast(date AS DATE)) AS term_d FROM %s
WHERE acquisition_id = '%s'
  AND action IN ('delisted','regulatorydelisting','voluntarydelisting',
                 'bankruptcyliquidation')
GROUP BY 1", pq("actions"), ACQ))
b4 <- dbGetQuery(con, "
SELECT CASE WHEN t.term_d IS NULL THEN 'no terminal action'
            WHEN p.d > t.term_d - INTERVAL 90 DAY THEN 'within 90d before terminal'
            ELSE 'earlier, same ticker' END AS bucket,
       count(*) AS sessions,
       round(100.0 * sum(CASE WHEN p.v = 0 THEN 1 ELSE 0 END) / count(*), 3) AS pct
FROM p LEFT JOIN term t USING (ticker) GROUP BY 1 ORDER BY pct DESC")
print(b4)
for (i in seq_len(nrow(b4))) {
  record("terminal_proximity", gsub("[^a-z0-9]+", "_", tolower(b4$bucket[[i]])),
         b4$pct[[i]], "percent", "zero-volume share of sessions in this bucket")
}

evidence <- do.call(rbind, rows)
utils::write.csv(evidence, file.path(OUT, "no_trade_identifiability_evidence.csv"),
                 row.names = FALSE)
cat("\nrows recorded:", nrow(evidence), "\n")
