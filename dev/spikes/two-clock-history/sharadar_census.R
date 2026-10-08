# Two-clock history: Sharadar census (read-only, aggregates only).
#
# Rscript dev/spikes/two-clock-history/sharadar_census.R <ledgr_repo> <out_dir>
#
# Asks what the restatement cases of the spike look like on the private
# Sharadar lake: which families carry a knowledge clock, how late facts become
# known, how many facts each instrument has, how often a later-known fact
# overlaps an earlier-known one, and how many bitemporal segments the spike
# core writes for every real S&P 500 membership history. Requires
# SHARADAR_DATA_ROOT (default E:/ledgr-data/sharadar). Writes one aggregate
# CSV; no instrument-level vendor rows leave the lake.
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- args[[2L]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
source(file.path(repo, "dev/spikes/two-clock-history/spike_core.R"))

root <- Sys.getenv("SHARADAR_DATA_ROOT", "E:/ledgr-data/sharadar")
build <- "canonical-20260906T055922734354Z-78941588416a97c6"
con <- DBI::dbConnect(duckdb::duckdb(), file.path(root, "lake/ledgr-research.duckdb"), read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
q <- function(sql) DBI::dbGetQuery(con, sprintf(sql, build))
out <- list()
put <- function(family, metric, value) {
  out[[length(out) + 1L]] <<- data.frame(family = family, metric = metric, value = as.character(value),
                                         stringsAsFactors = FALSE)
}

# Acquisitions: one download means no restatement can be observed by diffing.
put("all", "raw acquisitions registered", DBI::dbGetQuery(con,
  "SELECT COUNT(DISTINCT acquisition_id) n FROM audit.raw_source_registrations")$n)

# Membership: the only family with a knowledge column.
iv <- q("SELECT instrument_id, effective_from, effective_to, available_at_utc, end_available_at_utc, availability_basis
  FROM core.reference_membership WHERE canonical_build_id = '%s' AND reference_id = 'sharadar_sp500'
  AND record_kind = 'interval' AND quality_status = 'accepted'")
put("sp500 membership", "intervals", nrow(iv))
put("sp500 membership", "instruments", length(unique(iv$instrument_id)))
put("sp500 membership", "availability basis", paste(unique(iv$availability_basis), collapse = " "))
lag_start <- as.numeric(as.Date(iv$available_at_utc) - iv$effective_from)
ended <- !is.na(iv$effective_to)
lag_end <- as.numeric(as.Date(iv$end_available_at_utc[ended]) - iv$effective_to[ended])
put("sp500 membership", "start knowledge lag days (min/max)", paste(range(lag_start), collapse = "/"))
put("sp500 membership", "end knowledge lag days (min/max)", paste(range(lag_end), collapse = "/"))
per_inst <- table(table(iv$instrument_id))
put("sp500 membership", "intervals per instrument (count:instruments)",
    paste(names(per_inst), per_inst, sep = ":", collapse = " "))
# Restatement: a later-known interval overlapping an earlier-known one for the
# same instrument (the shape that makes segments grow as n * k).
pairs <- merge(iv, iv, by = "instrument_id")
later <- pairs$available_at_utc.y > pairs$available_at_utc.x
end_x <- pairs$effective_to.x; end_x[is.na(end_x)] <- as.Date("9999-12-31")
end_y <- pairs$effective_to.y; end_y[is.na(end_y)] <- as.Date("9999-12-31")
overlap <- pairs$effective_from.y < end_x & pairs$effective_from.x < end_y
put("sp500 membership", "later-known intervals overlapping earlier-known ones", sum(later & overlap))

# Families without a knowledge clock.
put("corporate actions", "rows with any knowledge or announcement time", 0L)
put("corporate actions", "actions per instrument (median/p99/max)", paste(unlist(q(
  "SELECT quantile_cont(n, 0.5) a, quantile_cont(n, 0.99) b, MAX(n) c FROM (SELECT instrument_id, COUNT(*) n
   FROM core.corporate_actions WHERE canonical_build_id = '%s' GROUP BY 1)")), collapse = "/"))
put("lifetime", "instruments (knowledge time absent; firstpricedate/lastpricedate only)",
    q("SELECT COUNT(*) n FROM core.instruments WHERE canonical_build_id = '%s'")$n)
put("trading status", "facts", 0L)

# Can an interval whose end becomes known later be expressed honestly? Member
# from day 1 (known day 2), removed day 10 (known day 11): the removal is a
# FALSE fact from day 10, open until re-entry.
day <- function(d) as.POSIXct(as.Date("2020-01-01") + d - 1L, tz = "UTC")
honest <- tryCatch({
  ledgr_facts_membership_intervals(data.frame(instrument_id = "X", effective_from = day(c(1, 10)),
    effective_to = as.POSIXct(c(NA, NA), tz = "UTC"), knowledge_time = day(c(2, 11)), member = c(TRUE, FALSE),
    source = "census"), universe_id = "sp500")
  "accepted"
}, error = function(e) paste("refused:", class(e)[[1L]]))
put("sp500 membership", "open TRUE then open FALSE (end known later)", honest)

# Segments the spike core writes per real membership history. Encoding: each
# interval is a TRUE fact known at its start availability; a FALSE fact covers
# the gap after it, known at its end availability. The TRUE fact carries its
# end date from the start (one interval row holds one knowledge time).
iv <- iv[order(iv$instrument_id, iv$effective_from), , drop = FALSE]
counts <- vapply(split(iv, iv$instrument_id), function(h) {
  to <- h$effective_to
  next_from <- c(h$effective_from[-1L], NA)
  gap <- !is.na(to)
  rows <- data.frame(instrument_id = "X",
    effective_from = as.POSIXct(c(h$effective_from, to[gap]), tz = "UTC"),
    effective_to = as.POSIXct(c(to, next_from[gap]), tz = "UTC"),
    knowledge_time = as.POSIXct(c(h$available_at_utc, h$end_available_at_utc[gap]), tz = "UTC"),
    member = c(rep(TRUE, nrow(h)), rep(FALSE, sum(gap))), source = "census")
  facts <- ledgr_facts(ledgr_facts_membership_intervals(rows, universe_id = "sp500"))
  data <- ledgr:::ledgr_facts_inspection_data(facts)
  c(nrow(rows), nrow(spike_build(data, "membership", "sp500", "X")))
}, numeric(2))
put("sp500 membership", "fact rows encoded", sum(counts[1L, ]))
put("sp500 membership", "segments written", sum(counts[2L, ]))
put("sp500 membership", "segments per fact row (overall/max per instrument)",
    sprintf("%.2f/%.2f", sum(counts[2L, ]) / sum(counts[1L, ]), max(counts[2L, ] / counts[1L, ])))

census <- do.call(rbind, out)
utils::write.csv(census, file.path(out_dir, "sharadar_census.csv"), row.names = FALSE)
print(census, row.names = FALSE, right = FALSE)
