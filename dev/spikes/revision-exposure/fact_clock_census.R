# Step 1 of the empirical-need brief: do real workloads contain revision triggers?
#
# Read-only census over every sealed ledgr snapshot this machine holds. Not a
# spike: no fork, no candidate, no charter. An ordinary query, as the brief allows.
#
# A price-input-carry revision trigger requires a fact that becomes knowable AFTER
# an affected historical session. Under the accepted applicability rule
# (R/availability-provider.R:51-57) a fact is knowable once knowledge_time <= cutoff,
# so the necessary condition is knowledge_time > effective_from. This counts that
# directly in built snapshots, rather than inferring it from adapter source.
#
# What this can and cannot establish is stated in the emitted evidence:
#   - it CAN establish how many facts in these built workloads carry a positive lag;
#   - it CANNOT establish the lag a vendor's subscribers actually experienced, which
#     is not identifiable from a single capture. assume_effective records an
#     assumption, not an observed zero.
#
#   Rscript dev/spikes/revision-exposure/fact_clock_census.R

library(DBI)

ROOT <- "C:/Users/maxth/ledgr-data/sharadar/ledgr-baselines"
OUT <- "dev/spikes/revision-exposure"
if (!dir.exists(ROOT)) stop("No baseline snapshots at ", ROOT)
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

dbs <- list.files(ROOT, pattern = "[.]duckdb$", recursive = TRUE, full.names = TRUE)
cat("snapshots found:", length(dbs), "\n\n")

rows <- list()
record <- function(snapshot, family, key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    snapshot = snapshot, family = family, key = key,
    value = as.character(value), unit = unit, derived_from = how,
    stringsAsFactors = FALSE
  )
}

# Families whose facts can gate admissibility, per synthesis section 5.2.
FAMILIES <- c("snapshot_lifetime", "snapshot_trading_status", "snapshot_membership",
              "snapshot_membership_sets", "snapshot_corporate_actions")

for (db in dbs) {
  # Path relative to ROOT: basename(dirname()) collapsed distinct baselines that
  # share a subdirectory name, which merged two snapshots into one label.
  label <- sub("[.]duckdb$", "", substring(db, nchar(ROOT) + 2L))
  con <- tryCatch(
    dbConnect(duckdb::duckdb(), db, read_only = TRUE),
    error = function(e) NULL
  )
  if (is.null(con)) {
    record(label, "-", "unreadable", TRUE, "logical", "connection refused")
    cat("SKIP (unreadable):", label, "\n")
    next
  }
  tabs <- tryCatch(DBI::dbListTables(con), error = function(e) character())

  # Scope, so the census is not read as covering more than it does.
  if ("snapshot_bars" %in% tabs) {
    sc <- dbGetQuery(con, "SELECT count(*) n, count(DISTINCT instrument_id) inst,
                            min(ts_utc) lo, max(ts_utc) hi FROM snapshot_bars")
    record(label, "scope", "bars", sc$n, "count", "snapshot_bars")
    record(label, "scope", "instruments", sc$inst, "count", "snapshot_bars")
    record(label, "scope", "first_bar", as.character(sc$lo), "timestamp", "snapshot_bars")
    record(label, "scope", "last_bar", as.character(sc$hi), "timestamp", "snapshot_bars")
  }

  for (fam in intersect(FAMILIES, tabs)) {
    cols <- tryCatch(names(dbGetQuery(con, sprintf("SELECT * FROM %s LIMIT 0", fam))),
                     error = function(e) character())
    n <- dbGetQuery(con, sprintf("SELECT count(*) n FROM %s", fam))$n
    record(label, fam, "rows", n, "count", "family row count")
    if (!all(c("effective_from", "knowledge_time") %in% cols)) {
      record(label, fam, "has_both_clocks", FALSE, "logical",
             paste("columns:", paste(cols, collapse = " ")))
      next
    }
    # The necessary condition for a carry-revision trigger.
    q <- dbGetQuery(con, sprintf("
      SELECT
        sum(CASE WHEN knowledge_time IS NULL THEN 1 ELSE 0 END) AS knowledge_null,
        sum(CASE WHEN knowledge_time > effective_from THEN 1 ELSE 0 END) AS lagged,
        sum(CASE WHEN knowledge_time = effective_from THEN 1 ELSE 0 END) AS equal,
        sum(CASE WHEN knowledge_time < effective_from THEN 1 ELSE 0 END) AS early,
        max(CASE WHEN knowledge_time > effective_from
            THEN date_diff('day', effective_from, knowledge_time) END) AS max_lag_days
      FROM %s", fam))
    # An empty family returns NULL from sum() and would vanish from the totals as
    # NA, hiding that it has no rows at all. Record that explicitly.
    if (identical(as.numeric(n), 0)) {
      record(label, fam, "family_is_empty", TRUE, "logical",
             "table present with no rows: carries no facts to revise")
      next
    }
    record(label, fam, "knowledge_time_null", q$knowledge_null, "count",
           "no knowledge clock: never applicable under evidenced")
    record(label, fam, "knowledge_after_effective", q$lagged, "count",
           "necessary condition for a carry-revision trigger")
    record(label, fam, "knowledge_equals_effective", q$equal, "count",
           "two clocks coincide: no retroactive knowability")
    record(label, fam, "knowledge_before_effective", q$early, "count",
           "known in advance: no revision")
    if (!is.na(q$max_lag_days)) {
      record(label, fam, "max_lag_days", q$max_lag_days, "days",
             "largest positive effective-to-knowledge gap")
    }
  }
  DBI::dbDisconnect(con, shutdown = TRUE)
  cat("read:", label, "\n")
}

evidence <- do.call(rbind, rows)
utils::write.csv(evidence, file.path(OUT, "fact_clock_evidence.csv"), row.names = FALSE)

cat("
=== families present but empty
")
empty <- evidence[evidence$key == "family_is_empty", c("snapshot", "family")]
if (nrow(empty) > 0L) print(table(empty$family)) else cat("none
")

cat("\n=== totals across all readable snapshots, by family\n")
lag <- evidence[evidence$key %in% c("knowledge_after_effective",
                                    "knowledge_equals_effective",
                                    "knowledge_before_effective",
                                    "knowledge_time_null"), ]
if (nrow(lag) > 0L) {
  lag$value <- as.numeric(lag$value)
  print(stats::aggregate(value ~ family + key, data = lag, FUN = sum))
}
