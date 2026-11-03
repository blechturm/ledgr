# Aggregate lifetime statistics only. Prints no tickers, dates or rows.
setwd("E:/ledgr-data/sharadar")
con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE),
                      "E:/ledgr-data/sharadar/catalog/sharadar.duckdb", read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

agg <- function(where_clause, label, TT = 252L) {
  sql <- sprintf("
    with s as (select date, row_number() over (order by date) as r
               from (select distinct date from raw.stocks_latest_acquisition)),
         life as (select ticker, min(s.r) as a, max(s.r) as b, count(*) as n_obs
                  from raw.stocks_latest_acquisition x join s using (date)
                  %s group by ticker)
    select count(*) as n_inst,
           (select count(*) from s) as n_sess,
           avg(b - a + 1) as mean_life,
           median(b - a + 1) as median_life,
           sum(n_obs) as total_obs,
           sum(b - a + 1) as ragged_cells,
           sum(((b - 1) // %d) - ((a - 1) // %d) + 1) * %d as tile_cells
    from life", where_clause, TT, TT, TT)
  x <- DBI::dbGetQuery(con, sql)
  x$dense_cells <- as.numeric(x$n_inst) * as.numeric(x$n_sess)
  data.frame(
    universe = label,
    instruments = x$n_inst,
    sessions = x$n_sess,
    mean_life = round(x$mean_life),
    median_life = round(x$median_life),
    alive_on_avg = round(as.numeric(x$ragged_cells) / x$n_sess),
    dense_MB = round(x$dense_cells * 8 / 2^20),
    tiles_MB = round(as.numeric(x$tile_cells) * 8 / 2^20),
    ragged_MB = round(as.numeric(x$ragged_cells) * 8 / 2^20),
    dense_over_tiles = round(x$dense_cells / as.numeric(x$tile_cells), 1)
  )
}

out <- rbind(
  agg("", "all stocks"),
  agg("where ticker in (select distinct ticker from raw.sp500_latest_acquisition)",
      "ever S&P 500 members")
)
print(out, row.names = FALSE)
