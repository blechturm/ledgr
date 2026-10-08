# Two-clock history: what Sharadar rewrites between two acquisitions
# (read-only, aggregates only).
#
# Rscript dev/spikes/two-clock-history/sharadar_vintage_diff.R <out_dir> [baseline] [comparison]
#
# Compares two raw acquisitions in the private catalog (defaults: the 4 and
# 5 September 2026 full downloads, about 16 hours apart) and classifies every
# changed row as a rolling update (latest date) or a historical revision, per
# family. Requires SHARADAR_DATA_ROOT (default E:/ledgr-data/sharadar). Writes
# one aggregate CSV; no instrument-level vendor rows leave the lake.
args <- commandArgs(trailingOnly = TRUE)
out_dir <- args[[1L]]
A <- if (length(args) >= 2L) args[[2L]] else "20260904T164505Z"
B <- if (length(args) >= 3L) args[[3L]] else "20260905T092008Z"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
root <- Sys.getenv("SHARADAR_DATA_ROOT", "E:/ledgr-data/sharadar")
con <- DBI::dbConnect(duckdb::duckdb(), file.path(root, "catalog/sharadar.duckdb"), read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
x <- function(sql) invisible(DBI::dbExecute(con, sql))
q <- function(sql) DBI::dbGetQuery(con, sql)
x(sprintf("SET file_search_path = '%s'", root))
x("SET memory_limit = '16GB'")
# Rows dated on or after the day before the baseline download are rolling
# updates; anything earlier is a revision of history.
recent <- format(as.Date(substr(A, 1L, 8L), "%Y%m%d") - 1L)
old <- function(col = "date") sprintf("CAST(%s AS DATE) < DATE '%s'", col, recent)
out <- list()
put <- function(family, metric, value) {
  out[[length(out) + 1L]] <<- data.frame(family = family, metric = metric, value = as.character(value),
                                         stringsAsFactors = FALSE)
}
diff_tables <- function(t, cols) {
  x(sprintf("CREATE OR REPLACE TEMP TABLE %1$s_rm AS SELECT %2$s FROM raw.%1$s_%3$s EXCEPT ALL SELECT %2$s FROM raw.%1$s_%4$s",
            t, cols, A, B))
  x(sprintf("CREATE OR REPLACE TEMP TABLE %1$s_ad AS SELECT %2$s FROM raw.%1$s_%4$s EXCEPT ALL SELECT %2$s FROM raw.%1$s_%3$s",
            t, cols, A, B))
}
put("all", "acquisitions compared", paste(A, B, sep = " -> "))

# Membership.
diff_tables("sp500", "date, action, ticker, name, contraticker, contraname, note")
sp <- q(sprintf("SELECT action, COUNT(*) n, SUM(CASE WHEN %s THEN 1 ELSE 0 END) historical
  FROM (SELECT * FROM sp500_rm UNION ALL SELECT * FROM sp500_ad) GROUP BY 1", old()))
put("sp500 membership", "changed rows by action (n/historical)", paste0(sp$action, ":", sp$n, "/", sp$historical, collapse = " "))

# Corporate actions: rows added or removed outright, by action and period.
diff_tables("actions", "date, action, ticker, name, value, contraticker, contraname")
for (side in c("ad", "rm")) {
  other <- if (side == "ad") "rm" else "ad"
  a <- q(sprintf("SELECT action, COUNT(*) n, SUM(CASE WHEN %s THEN 1 ELSE 0 END) historical,
    MIN(date) dmin, MAX(date) dmax FROM (SELECT * FROM actions_%s ANTI JOIN actions_%s USING (date, action, ticker))
    GROUP BY 1 HAVING SUM(CASE WHEN %s THEN 1 ELSE 0 END) > 0 ORDER BY 2 DESC", old(), side, other, old()))
  put("corporate actions", sprintf("historical rows %s outright (action:n dmin..dmax)",
      if (side == "ad") "added" else "removed"),
      paste0(a$action, ":", a$historical, " ", a$dmin, "..", a$dmax, collapse = "; "))
}
m <- q("SELECT COUNT(*) n, SUM(CASE WHEN r.contraticker IS DISTINCT FROM a.contraticker THEN 1 ELSE 0 END) contra
  FROM actions_rm r JOIN actions_ad a USING (date, action, ticker)")
put("corporate actions", "same date/action/ticker with a changed field (n/contraticker)", paste0(m$n, "/", m$contra))

# Lifetime inputs in tickers.
lt <- q(sprintf("SELECT
  SUM(CASE WHEN a.isdelisted IS DISTINCT FROM b.isdelisted THEN 1 ELSE 0 END) isdelisted,
  SUM(CASE WHEN a.firstpricedate IS DISTINCT FROM b.firstpricedate THEN 1 ELSE 0 END) firstpricedate,
  SUM(CASE WHEN a.lastpricedate IS DISTINCT FROM b.lastpricedate THEN 1 ELSE 0 END) lastpricedate,
  SUM(CASE WHEN a.lastpricedate IS DISTINCT FROM b.lastpricedate AND (a.isdelisted = 'Y' OR %s) THEN 1 ELSE 0 END) lastpricedate_historical
  FROM raw.tickers_%s a JOIN raw.tickers_%s b USING (\"table\", permaticker, ticker)",
  sprintf("CAST(b.lastpricedate AS DATE) < DATE '%s'", recent), A, B))
put("lifetime", "tickers rows changed (isdelisted/firstpricedate/lastpricedate)",
    paste(lt$isdelisted, lt$firstpricedate, lt$lastpricedate, sep = "/"))
put("lifetime", "lastpricedate changes that are not a forward roll of an active ticker", lt$lastpricedate_historical)

# Prices.
diff_tables("stocks", "ticker, date, open, high, low, close, volume, closeadj, closeunadj, lastupdated")
p <- q(sprintf("SELECT CASE WHEN %s THEN 'historical' ELSE 'latest' END period,
  SUM(CASE WHEN r.close IS DISTINCT FROM a.close THEN 1 ELSE 0 END) close_n,
  SUM(CASE WHEN r.open IS DISTINCT FROM a.open OR r.high IS DISTINCT FROM a.high OR r.low IS DISTINCT FROM a.low THEN 1 ELSE 0 END) ohl_n,
  SUM(CASE WHEN r.volume IS DISTINCT FROM a.volume THEN 1 ELSE 0 END) volume_n,
  SUM(CASE WHEN r.closeadj IS DISTINCT FROM a.closeadj THEN 1 ELSE 0 END) closeadj_n,
  COUNT(DISTINCT CASE WHEN r.closeadj IS DISTINCT FROM a.closeadj THEN r.ticker END) closeadj_tickers
  FROM stocks_rm r JOIN stocks_ad a USING (ticker, date) GROUP BY 1", old("r.date")))
for (i in seq_len(nrow(p))) {
  put("prices", sprintf("%s bars revised (close/ohl/volume/closeadj; closeadj tickers)", p$period[[i]]),
      sprintf("%d/%d/%d/%d; %d", p$close_n[[i]], p$ohl_n[[i]], p$volume_n[[i]], p$closeadj_n[[i]], p$closeadj_tickers[[i]]))
}
o <- q(sprintf("SELECT side, CASE WHEN %s THEN 'historical' ELSE 'latest' END period, COUNT(*) n, COUNT(DISTINCT ticker) tickers
  FROM (SELECT 'added' side, * FROM stocks_ad ANTI JOIN stocks_rm USING (ticker, date)
        UNION ALL SELECT 'removed', * FROM stocks_rm ANTI JOIN stocks_ad USING (ticker, date)) GROUP BY ALL ORDER BY 1, 2", old()))
for (i in seq_len(nrow(o))) {
  put("prices", sprintf("%s bars %s outright (rows/tickers)", o$period[[i]], o$side[[i]]), paste0(o$n[[i]], "/", o$tickers[[i]]))
}

diff <- do.call(rbind, out)
utils::write.csv(diff, file.path(out_dir, "sharadar_vintage_diff.csv"), row.names = FALSE)
print(diff, row.names = FALSE, right = FALSE)
