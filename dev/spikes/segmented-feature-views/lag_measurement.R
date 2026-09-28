# Empirical knowledge lags in the Sharadar lake.
#
# The ablation's blocks D and E showed the bias of not revising splits entirely by
# how late a fact becomes knowable against the feature's window. That makes the
# real lag distribution the one quantity that decides whether revision machinery
# is worth building, and the spike inventory named it as answerable without new
# machinery. This is that measurement.
#
# NOT part of the checker's reproducible set. It reads a 15 GB external lake at an
# absolute path that exists on one machine, so it cannot be a gate. Its output is
# committed beside it as the record.
#
# Read-only throughout: no acquisition is run and nothing in the lake is written.
#
#   Rscript dev/spikes/segmented-feature-views/lag_measurement.R

library(DBI)

LAKE <- "C:/Users/maxth/ledgr-data/sharadar/parquet"
OUT <- "dev/spikes/segmented-feature-views"
if (!dir.exists(LAKE)) {
  stop("Sharadar lake not present at ", LAKE, "; this script runs on one machine.")
}

con <- dbConnect(duckdb::duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
pq <- function(d) {
  sprintf("read_parquet('%s/%s/**/*.parquet', hive_partitioning=true)", LAKE, d)
}
vintages <- function(d) {
  dbGetQuery(con, sprintf("SELECT DISTINCT acquisition_id FROM %s ORDER BY 1",
                          pq(d)))[[1]]
}

rows <- list()
record <- function(family, key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    family = family, key = key, value = as.character(value), unit = unit,
    derived_from = how, stringsAsFactors = FALSE
  )
}

tv <- vintages("tickers")
newest_t <- tail(tv, 1)
record("provenance", "tickers_acquisition", newest_t, "id", "newest vintage used")

# ------------------------------------------------- 1. the two refuted proxies
# Both columns look like knowledge clocks and are not. Recorded because they are
# the obvious thing to reach for, and the numbers foreclose it rather than
# leaving the next reader to rediscover it.
q_listing <- sprintf("
  WITH t AS (
    SELECT try_cast(firstadded AS DATE) AS added,
           try_cast(firstpricedate AS DATE) AS firstpx
    FROM %s WHERE acquisition_id = '%s' AND \"table\" = 'SEP'
  ), d AS (SELECT datediff('day', firstpx, added) AS lag FROM t
           WHERE added IS NOT NULL AND firstpx IS NOT NULL)
  SELECT count(*) AS n, median(lag) AS p50, max(lag) AS max,
         sum(CASE WHEN lag <= 0 THEN 1 ELSE 0 END) AS n_nonpositive FROM d",
  pq("tickers"), newest_t)
l <- dbGetQuery(con, q_listing)
record("refuted_proxy", "firstadded_minus_firstpricedate_n", l$n, "count",
       "SEP tickers with both dates")
record("refuted_proxy", "firstadded_minus_firstpricedate_p50", l$p50, "days",
       "median; vendor onboarding, not market knowledge")
record("refuted_proxy", "firstadded_minus_firstpricedate_nonpositive",
       l$n_nonpositive, "count", "tickers added at or before their first price")

q_delist <- sprintf("
  WITH t AS (
    SELECT try_cast(lastupdated AS DATE) AS upd,
           try_cast(lastpricedate AS DATE) AS lastpx
    FROM %s WHERE acquisition_id = '%s' AND \"table\" = 'SEP' AND isdelisted = 'Y'
  ), d AS (SELECT datediff('day', lastpx, upd) AS lag FROM t
           WHERE upd IS NOT NULL AND lastpx IS NOT NULL)
  SELECT count(*) AS n, median(lag) AS p50, max(lag) AS max FROM d",
  pq("tickers"), newest_t)
d <- dbGetQuery(con, q_delist)
record("refuted_proxy", "lastupdated_minus_lastpricedate_n", d$n, "count",
       "delisted SEP tickers")
record("refuted_proxy", "lastupdated_minus_lastpricedate_p50", d$p50, "days",
       "median; last-modified stamp, not first publication")

# --------------------------------- 2. the one genuine lag: SF1 filing dates
# `date` is the filing clock and `reportperiod` the period end. The as-reported
# dimensions carry a real gap; the most-recent-reported ones are zero by
# construction, which is itself the check that `date` is the filing date.
fv <- vintages("fundamentals")
newest_f <- tail(fv, 1)
record("provenance", "fundamentals_acquisition", newest_f, "id",
       "newest vintage used")
q_f <- sprintf("
  WITH d AS (
    SELECT dimension,
           datediff('day', try_cast(reportperiod AS DATE),
                    try_cast(date AS DATE)) AS lag
    FROM %s WHERE acquisition_id = '%s'
  )
  SELECT dimension, count(*) AS n, median(lag) AS p50,
         quantile_cont(lag, 0.95) AS p95, max(lag) AS max
  FROM d WHERE lag IS NOT NULL GROUP BY 1 ORDER BY 1", pq("fundamentals"), newest_f)
f <- dbGetQuery(con, q_f)
for (i in seq_len(nrow(f))) {
  dim_i <- f$dimension[[i]]
  record("sf1_filing_lag", paste0(dim_i, "_n"), f$n[[i]], "count", "rows")
  record("sf1_filing_lag", paste0(dim_i, "_p50"), f$p50[[i]], "days",
         "median filing date minus period end")
  record("sf1_filing_lag", paste0(dim_i, "_p95"), f$p95[[i]], "days",
         "95th percentile")
  record("sf1_filing_lag", paste0(dim_i, "_max"), f$max[[i]], "days", "maximum")
}

# ----------------------- 3. first appearance, from this repo's own captures
# A row in the newer capture and absent from the older one became knowable
# between the two. The capture gap floors what this can resolve, so this detects
# arrivals and cannot estimate a distribution.
av <- vintages("actions")
old_a <- av[[1]]
new_a <- tail(av, 1)
record("provenance", "actions_vintage_old", old_a, "id", "older capture")
record("provenance", "actions_vintage_new", new_a, "id", "newer capture")
q_new <- sprintf("
  WITH o AS (SELECT date, action, ticker, value FROM %s WHERE acquisition_id = '%s'),
       n AS (SELECT date, action, ticker, value FROM %s WHERE acquisition_id = '%s'),
       newonly AS (SELECT * FROM n EXCEPT SELECT * FROM o)
  SELECT action, count(*) AS n_rows,
         median(datediff('day', try_cast(date AS DATE), DATE '2026-09-05')) AS p50,
         max(datediff('day', try_cast(date AS DATE), DATE '2026-09-05')) AS max
  FROM newonly GROUP BY 1 ORDER BY n_rows DESC",
  pq("actions"), old_a, pq("actions"), new_a)
n <- dbGetQuery(con, q_new)
for (i in seq_len(nrow(n))) {
  a <- n$action[[i]]
  record("first_appearance", paste0(a, "_rows"), n$n_rows[[i]], "count",
         "rows in the newer capture only")
  record("first_appearance", paste0(a, "_p50"), n$p50[[i]], "days",
         "median capture date minus action date")
  record("first_appearance", paste0(a, "_max"), n$max[[i]], "days", "maximum")
}

evidence <- do.call(rbind, rows)
utils::write.csv(evidence, file.path(OUT, "lag_measurement_evidence.csv"),
                 row.names = FALSE)
print(evidence, right = FALSE, max = 600)
