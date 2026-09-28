# Source-change attribution between two saved captures, and its consequence.
#
# Review 2026-09-27 (second round) found that lag_measurement.R used EXCEPT over
# (date, action, ticker, value), which conflates a genuinely ADDED row with a
# CHANGED value on a row that was already there. Its "newer-capture-only delisting
# and bankruptcyliquidation rows" are therefore candidates, not established late
# additions.
#
# This adopts the decomposition the research package's comparator uses - added keys,
# removed keys, changed values on stable keys
# (ledgr-research/packages/ledgr.sharadar/R/vintage-comparison.R, sharadar_compare_
# vintage_rows) - applied directly to the parquet rather than through its view
# plumbing, which is bound to the research lake's `raw` schema.
#
# Then it traces the consequence: whether any attributed change would alter a
# requested historical input under the proposed carry policy, or the expected-session
# set under instrument narrowing.
#
# What two captures can and cannot establish, stated because the previous revision
# blurred it: they establish what this saved source contained at two acquisition
# points. They do NOT establish when the market first knew anything, nor how
# representative a 17-hour interval is.
#
#   Rscript dev/spikes/revision-exposure/source_change_attribution.R

library(DBI)

LAKE <- "C:/Users/maxth/ledgr-data/sharadar/parquet"
OUT <- "dev/spikes/revision-exposure"
OLD <- "20260904T164505Z"
NEW <- "20260905T092008Z"
BARRIER_ACTIONS <- c("dividend", "split", "delisted", "regulatorydelisting",
                     "voluntarydelisting", "bankruptcyliquidation")
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
record("provenance", "baseline_capture", OLD, "id", "older acquisition")
record("provenance", "comparison_capture", NEW, "id", "newer acquisition")
record("provenance", "capture_interval_hours", 17, "hours",
       "bounds nothing about representativeness")

for (v in c(OLD, NEW)) {
  dbExecute(con, sprintf("
    CREATE OR REPLACE TABLE a_%s AS
    SELECT ticker, action, try_cast(date AS DATE) AS d, value
    FROM %s WHERE acquisition_id = '%s'",
    substr(v, 1, 8), pq("actions"), v))
}
OLDT <- paste0("a_", substr(OLD, 1, 8))
NEWT <- paste0("a_", substr(NEW, 1, 8))

# ------------------------------------------ 1. is the candidate key unique?
# A decomposition into added/removed/changed is only meaningful on a unique key.
cat("=== key uniqueness on (ticker, action, date)\n")
for (tb in c(OLDT, NEWT)) {
  k <- dbGetQuery(con, sprintf("
    SELECT count(*) AS rows, count(DISTINCT (ticker, action, d)) AS keys FROM %s", tb))
  cat(sprintf("%-12s rows %7d  distinct keys %7d  duplicate excess %d\n",
              tb, k$rows, k$keys, k$rows - k$keys))
  record("key_uniqueness", paste0(tb, "_duplicate_excess"), k$rows - k$keys, "count",
         "rows minus distinct (ticker, action, date)")
  g <- dbGetQuery(con, sprintf("
    SELECT count(*) AS dup_groups,
           sum(CASE WHEN nv > 1 THEN 1 ELSE 0 END) AS groups_with_differing_values
    FROM (SELECT ticker, action, d, count(*) n, count(DISTINCT value) nv
          FROM %s GROUP BY 1,2,3 HAVING n > 1) x", tb))
  record("key_uniqueness", paste0(tb, "_duplicate_groups"), g$dup_groups, "count",
         "keys appearing more than once")
  record("key_uniqueness", paste0(tb, "_duplicate_groups_differing_values"),
         g$groups_with_differing_values, "count",
         "why a dedup by any_value would be unsafe and multiset semantics are used")
}

# ------------------------------------------------------- 2. the decomposition
# The candidate key is NOT unique: 1,363 groups repeat, and 398 of those hold
# differing values. A dedup by any_value() would silently pick one and could report
# a changed value as stable, so the comparison uses MULTISET semantics instead.
# Per key, the values are bags; a value present more often in one capture than the
# other is a real difference. A key with both an added and a removed value is a
# change; only-added is an addition; only-removed a removal.
dbExecute(con, sprintf("
CREATE OR REPLACE TABLE bags AS
WITH o AS (SELECT ticker, action, d, value, count(*) AS n FROM %s GROUP BY 1,2,3,4),
     n AS (SELECT ticker, action, d, value, count(*) AS n FROM %s GROUP BY 1,2,3,4)
SELECT coalesce(o.ticker, n.ticker) AS ticker,
       coalesce(o.action, n.action) AS action,
       coalesce(o.d, n.d) AS d,
       coalesce(o.value, n.value) AS value,
       coalesce(o.n, 0) AS n_old,
       coalesce(n.n, 0) AS n_new
FROM o FULL OUTER JOIN n
  ON n.ticker = o.ticker AND n.action = o.action AND n.d = o.d
 AND coalesce(n.value, chr(1)) = coalesce(o.value, chr(1))", OLDT, NEWT))

dbExecute(con, "
CREATE OR REPLACE TABLE attrib AS
WITH per_key AS (
  SELECT ticker, action, d,
         sum(greatest(n_new - n_old, 0)) AS added_values,
         sum(greatest(n_old - n_new, 0)) AS removed_values
  FROM bags GROUP BY 1,2,3
)
SELECT ticker, action, d, added_values, removed_values,
       CASE WHEN added_values > 0 AND removed_values > 0 THEN 'changed'
            WHEN added_values > 0 THEN 'added'
            WHEN removed_values > 0 THEN 'removed'
            ELSE 'stable' END AS attribution
FROM per_key")

cat("
=== attribution over all action kinds, multiset semantics
")
tot <- dbGetQuery(con, "SELECT attribution, count(*) AS keys,
  sum(added_values) AS added_rows, sum(removed_values) AS removed_rows
  FROM attrib GROUP BY 1 ORDER BY keys DESC")
print(tot)
for (i in seq_len(nrow(tot))) {
  record("attribution_all", paste0(tot$attribution[[i]], "_keys"), tot$keys[[i]],
         "count", "keyed decomposition under multiset semantics")
}

cat("
=== attribution restricted to barrier-relevant kinds, excluding stable
")
bar <- dbGetQuery(con, sprintf("
SELECT action, attribution, count(*) AS keys,
       min(d) AS earliest_action_date, max(d) AS latest_action_date
FROM attrib
WHERE attribution <> 'stable' AND action IN ('%s')
GROUP BY 1,2 ORDER BY keys DESC", paste(BARRIER_ACTIONS, collapse = "','")))
if (nrow(bar) == 0L) {
  cat("none
")
  record("attribution_barrier", "changes", 0, "count", "no barrier-relevant change")
} else {
  print(bar)
  for (i in seq_len(nrow(bar))) {
    record("attribution_barrier",
           paste(bar$action[[i]], bar$attribution[[i]], sep = "_"), bar$keys[[i]],
           "count", "keys differing, barrier-relevant kinds, multiset semantics")
    record("attribution_barrier",
           paste(bar$action[[i]], bar$attribution[[i]], "earliest", sep = "_"),
           as.character(bar$earliest_action_date[[i]]), "date", "earliest action date")
  }
}

# --------------------------------------------- 3. consequence of each change
# A change alters a requested historical input only if it moves a barrier across a
# session whose value a run would read. Two mechanisms, measured separately.
dbExecute(con, sprintf("
CREATE OR REPLACE TABLE px AS
SELECT ticker, try_cast(date AS DATE) AS d, try_cast(volume AS DOUBLE) AS v
FROM %s WHERE acquisition_id = '%s'", pq("stocks"), NEW))
dbExecute(con, "CREATE OR REPLACE TABLE cal AS
  SELECT DISTINCT d FROM px")

aff <- dbGetQuery(con, sprintf("
WITH ch AS (
  SELECT ticker, action, d, attribution FROM attrib
  WHERE attribution IN ('added','removed','changed') AND action IN ('%s')
)
SELECT ch.attribution, ch.action, count(*) AS changes,
       count(DISTINCT ch.ticker) AS instruments,
       sum(CASE WHEN p.ticker IS NULL THEN 1 ELSE 0 END) AS instruments_absent_from_prices
FROM ch LEFT JOIN (SELECT DISTINCT ticker FROM px) p ON p.ticker = ch.ticker
GROUP BY 1,2 ORDER BY changes DESC", paste(BARRIER_ACTIONS, collapse = "','")))
cat("\n=== do the changed instruments even appear in the price panel?\n")
if (nrow(aff) == 0L) cat("no barrier-relevant changes to trace\n") else print(aff)
for (i in seq_len(nrow(aff))) {
  record("consequence", paste(aff$action[[i]], aff$attribution[[i]], "instruments", sep = "_"),
         aff$instruments[[i]], "count", "distinct instruments carrying such a change")
  record("consequence", paste(aff$action[[i]], aff$attribution[[i]], "not_in_panel", sep = "_"),
         aff$instruments_absent_from_prices[[i]], "count",
         "of those, instruments with no price rows at all")
}

# Carry mechanism: a forbidden carry needs an absent session to fill. Count absent
# sessions on or after each changed action date, within the changed instrument's
# own observed span.
carry <- dbGetQuery(con, sprintf("
WITH ch AS (
  SELECT DISTINCT ticker, d AS action_d FROM attrib
  WHERE attribution IN ('added','removed','changed') AND action IN ('%s')
), sp AS (SELECT ticker, min(d) AS lo, max(d) AS hi FROM px GROUP BY 1),
   grid AS (
     SELECT ch.ticker, c.d FROM ch JOIN sp ON sp.ticker = ch.ticker
       JOIN cal c ON c.d >= greatest(ch.action_d, sp.lo) AND c.d <= sp.hi
   )
SELECT count(*) AS sessions_at_or_after_a_change,
       sum(CASE WHEN p.ticker IS NULL THEN 1 ELSE 0 END) AS absent_sessions
FROM grid LEFT JOIN px p ON p.ticker = grid.ticker AND p.d = grid.d",
  paste(BARRIER_ACTIONS, collapse = "','")))
cat("\n=== carry mechanism: absent sessions a moved barrier could have blocked\n")
print(carry)
record("consequence", "sessions_at_or_after_a_change",
       carry$sessions_at_or_after_a_change, "count",
       "sessions in scope of an attributed barrier change")
record("consequence", "absent_sessions_in_scope", carry$absent_sessions, "count",
       "of those, sessions with no bar: the only cells a carry rule could change")

# Narrowing mechanism: sessions that WOULD leave the expected set if a terminal or
# inactive change narrowed the axis. Present sessions, not absent ones.
narrow <- dbGetQuery(con, sprintf("
WITH ch AS (
  SELECT DISTINCT ticker, d AS action_d FROM attrib
  WHERE attribution IN ('added','removed','changed')
    AND action IN ('delisted','regulatorydelisting','voluntarydelisting',
                   'bankruptcyliquidation')
)
SELECT count(*) AS present_sessions_at_or_after_a_terminal_change
FROM ch JOIN px p ON p.ticker = ch.ticker AND p.d >= ch.action_d"))
cat("\n=== narrowing mechanism: present sessions at or after a terminal change\n")
print(narrow)
record("consequence", "present_sessions_after_terminal_change",
       narrow$present_sessions_at_or_after_a_terminal_change, "count",
       "cells narrowing would move out of the expected set")

cat("
=== the individual terminal changes, and the sessions each reaches
")
each <- dbGetQuery(con, "
SELECT a.ticker, a.action, a.d AS action_date, a.attribution,
       count(p.d) AS present_sessions_at_or_after
FROM attrib a LEFT JOIN px p ON p.ticker = a.ticker AND p.d >= a.d
WHERE a.attribution <> 'stable'
  AND a.action IN ('delisted','regulatorydelisting','voluntarydelisting',
                   'bankruptcyliquidation')
GROUP BY 1,2,3,4 ORDER BY present_sessions_at_or_after DESC")
print(each)
for (i in seq_len(nrow(each))) {
  record("terminal_change_detail",
         paste(each$ticker[[i]], each$action[[i]], each$attribution[[i]], sep = "_"),
         each$present_sessions_at_or_after[[i]], "count",
         sprintf("action dated %s; present sessions at or after it",
                 as.character(each$action_date[[i]])))
}

evidence <- do.call(rbind, rows)
utils::write.csv(evidence, file.path(OUT, "source_change_attribution_evidence.csv"),
                 row.names = FALSE)
cat("\nrows recorded:", nrow(evidence), "\n")
