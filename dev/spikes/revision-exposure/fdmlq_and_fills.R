# Two bounded follow-throughs from review 2026-09-27, third round.
#
#   1. FDMLQ downstream. The attributed source correction affects one price session.
#      One input is not a measurement of downstream bias: it can affect several
#      outputs, through every window ending within W_f - 1 of it, or it can fall
#      outside every intended request. Settle which.
#
#   2. Realised rather than potential execution exposure. The previous revision
#      labelled 3,233 as "fills". They are eligible decision dates whose next
#      execution bar has no recorded volume, which is potential exposure. This joins
#      against the fills a real strategy actually executed, from the completed runs
#      already sealed in the baseline snapshots.
#
#   Rscript dev/spikes/revision-exposure/fdmlq_and_fills.R

library(DBI)

ROOT <- "C:/Users/maxth/ledgr-data/sharadar/ledgr-baselines"
LAKE <- "C:/Users/maxth/ledgr-data/sharadar/parquet"
OUT <- "dev/spikes/revision-exposure"
ACQ <- "20260905T092008Z"
TERMINAL_ADDED <- as.Date("2002-04-24")
if (!dir.exists(ROOT)) stop("No baselines at ", ROOT)

rows <- list()
record <- function(topic, key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    topic = topic, key = key, value = as.character(value), unit = unit,
    derived_from = how, stringsAsFactors = FALSE
  )
}

# ============================================ 1. FDMLQ, and every request scope
dbs <- list.files(ROOT, pattern = "[.]duckdb$", recursive = TRUE, full.names = TRUE)
in_universe <- 0L
fill_tally <- list()
for (db in dbs) {
  label <- sub("[.]duckdb$", "", substring(db, nchar(ROOT) + 2L))
  con <- tryCatch(dbConnect(duckdb::duckdb(), db, read_only = TRUE),
                  error = function(e) NULL)
  if (is.null(con)) next
  tabs <- DBI::dbListTables(con)
  if ("snapshot_instruments" %in% tabs) {
    n <- dbGetQuery(con, "SELECT count(*) n FROM snapshot_instruments
                          WHERE instrument_id = 'FDMLQ'")$n
    in_universe <- in_universe + as.integer(n > 0)
  }
  # Realised fills: a ledger event with a quantity and a price, joined to the bar
  # it executed against, so the bar's recorded volume can be read.
  if (all(c("ledger_events", "snapshot_bars") %in% tabs)) {
    ev <- dbGetQuery(con, "SELECT count(*) n FROM ledger_events")$n
    if (ev > 0L) {
      # A fill is stamped at the session OPEN it executed against (14:30 UTC) and
      # a bar at the session CLOSE (21:00 UTC), so the two timestamps never match
      # and the join must be on the civil date. Verified by the fill price equalling
      # that date's bar open.
      f <- dbGetQuery(con, "
        SELECT count(*) AS fills,
               count(b.volume) AS fills_matched_to_a_bar,
               sum(CASE WHEN b.volume = 0 THEN 1 ELSE 0 END) AS fills_on_zero_volume,
               sum(CASE WHEN b.volume IS NOT NULL AND abs(e.price - b.open) < 1e-8
                   THEN 1 ELSE 0 END) AS fills_priced_at_that_bars_open
        FROM ledger_events e
        LEFT JOIN snapshot_bars b
          ON b.instrument_id = e.instrument_id
         AND CAST(b.ts_utc AS DATE) = CAST(e.ts_utc AS DATE)
        WHERE e.qty IS NOT NULL AND e.price IS NOT NULL AND e.event_type = 'FILL'")
      fill_tally[[label]] <- f
    }
  }
  DBI::dbDisconnect(con, shutdown = TRUE)
}
record("fdmlq", "snapshots_examined", length(dbs), "count", "sealed baselines on this machine")
record("fdmlq", "snapshots_containing_fdmlq", in_universe, "count",
       "workloads whose declared instrument population includes it")

# Its own history, from the lake, so the affected cell can be located exactly.
con <- dbConnect(duckdb::duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
pq <- function(d) {
  sprintf("read_parquet('%s/%s/**/*.parquet', hive_partitioning=true)", LAKE, d)
}
h <- dbGetQuery(con, sprintf("
SELECT count(*) AS bars, min(try_cast(date AS DATE)) AS first_bar,
       max(try_cast(date AS DATE)) AS last_bar,
       sum(CASE WHEN try_cast(date AS DATE) >= DATE '%s' THEN 1 ELSE 0 END) AS bars_at_or_after_added_terminal
FROM %s WHERE acquisition_id = '%s' AND ticker = 'FDMLQ'",
  TERMINAL_ADDED, pq("stocks"), ACQ))
for (k in names(h)) {
  record("fdmlq", k, as.character(h[[k]]), if (grepl("bar$|bars", k)) "count" else "date",
         "FDMLQ price history in the capture")
}
cat("=== FDMLQ history\n"); print(h)

# The affected sessions, and every window end they reach, for realistic widths.
aff <- dbGetQuery(con, sprintf("
WITH b AS (
  SELECT try_cast(date AS DATE) AS d,
         row_number() OVER (ORDER BY try_cast(date AS DATE)) AS idx
  FROM %s WHERE acquisition_id = '%s' AND ticker = 'FDMLQ'
)
SELECT (SELECT max(idx) FROM b) AS total_sessions,
       (SELECT min(idx) FROM b WHERE d >= DATE '%s') AS first_affected_idx,
       (SELECT count(*) FROM b WHERE d >= DATE '%s') AS affected_inputs",
  pq("stocks"), ACQ, TERMINAL_ADDED, TERMINAL_ADDED))
cat("\n=== affected input position within its own history\n"); print(aff)
for (w in c(5L, 20L, 60L, 200L)) {
  # Windows ending from the affected input up to W-1 later, capped at the last
  # session the instrument has.
  reach <- if (is.na(aff$first_affected_idx)) 0L else
    max(0L, min(aff$total_sessions, aff$first_affected_idx + w - 1L) -
              aff$first_affected_idx + 1L)
  record("fdmlq_downstream", sprintf("indicator_cells_affected_w%d", w), reach, "count",
         "windows ending within W_f - 1 of the affected input, capped at its last session")
}

# ============================================ 2. realised execution exposure
cat("\n=== realised fills in the sealed baseline runs\n")
if (length(fill_tally) == 0L) {
  cat("No snapshot carries ledger events, so realised fills cannot be measured here.\n")
  record("realised_fills", "snapshots_with_ledger_events", 0, "count",
         "no completed run persisted fills into any baseline snapshot")
} else {
  agg <- do.call(rbind, lapply(names(fill_tally), function(n) {
    cbind(data.frame(snapshot = n, stringsAsFactors = FALSE), fill_tally[[n]])
  }))
  print(agg)
  record("realised_fills", "snapshots_with_ledger_events", nrow(agg), "count",
         "baselines carrying persisted fills")
  record("realised_fills", "fills_total", sum(agg$fills), "count", "executed fills")
  record("realised_fills", "fills_matched_to_a_bar", sum(agg$fills_matched_to_a_bar),
         "count", "fills joined to the bar they executed against")
  record("realised_fills", "fills_on_zero_volume_bar",
         sum(agg$fills_on_zero_volume, na.rm = TRUE), "count",
         "executed fills whose bar had no recorded volume")
  record("realised_fills", "fills_priced_at_that_bars_open",
         sum(agg$fills_priced_at_that_bars_open, na.rm = TRUE), "count",
         "join validation: fill price equals the matched bar's open")
}

evidence <- do.call(rbind, rows)
utils::write.csv(evidence, file.path(OUT, "fdmlq_and_fills_evidence.csv"), row.names = FALSE)
cat("\nrows recorded:", nrow(evidence), "\n")
