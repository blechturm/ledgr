# Step 1, continued: the absence measurement section 5.1 actually asked for.
#
# The earlier zero_volume_measurement.R defined a calendar from observed dates and
# coverage from each instrument's first and last print. Review found that this
# cannot see leading or trailing absence, nor an entirely absent instrument, and
# that section 5.1 asked for run lengths of missing expected sessions split across
# four lifecycle locations. This measures against DECLARED inputs instead:
#
#   calendar   snapshot_sessions where status = 'open' - the sealed declared venue
#              calendar, independent of what any instrument printed;
#   span       each instrument's declared known_active lifetime interval;
#   barrier    each instrument's declared known_inactive interval.
#
# Read-only. Not a spike: no fork, no candidate. An ordinary query.
#
#   Rscript dev/spikes/revision-exposure/declared_absence_census.R

library(DBI)

DB <- paste0("C:/Users/maxth/ledgr-data/sharadar/ledgr-baselines/",
             "v0.1.1-revalidation-v001/full/control.duckdb")
OUT <- "dev/spikes/revision-exposure"
if (!file.exists(DB)) stop("No baseline snapshot at ", DB)
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

con <- dbConnect(duckdb::duckdb(), DB, read_only = TRUE)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

rows <- list()
record <- function(topic, key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    topic = topic, key = key, value = as.character(value), unit = unit,
    derived_from = how, stringsAsFactors = FALSE
  )
}
record("provenance", "snapshot", basename(dirname(DB)), "path", "baseline snapshot")
record("provenance", "snapshot_id",
       dbGetQuery(con, "SELECT DISTINCT snapshot_id FROM snapshot_bars")[[1]][[1]],
       "id", "sealed identity")

# ------------------------------------------------- the declared venue calendar
dbExecute(con, "
CREATE OR REPLACE TEMP TABLE cal AS
SELECT session_close AS ts, row_number() OVER (ORDER BY session_close) AS idx
FROM snapshot_sessions WHERE status = 'open'")
dbExecute(con, "
CREATE OR REPLACE TEMP TABLE obs AS
SELECT b.instrument_id, c.idx
FROM snapshot_bars b JOIN cal c ON c.ts = b.ts_utc")

pop <- dbGetQuery(con, "
SELECT (SELECT count(*) FROM cal) AS declared_open_sessions,
       (SELECT count(*) FROM snapshot_instruments) AS instruments_declared,
       (SELECT count(DISTINCT instrument_id) FROM snapshot_bars) AS instruments_with_bars,
       (SELECT count(*) FROM snapshot_bars) AS bars,
       (SELECT count(*) FROM obs) AS bars_matched_to_a_session")
for (k in names(pop)) {
  record("scope", k, pop[[k]], "count", "declared inputs and observations")
}
record("scope", "bars_unmatched_to_a_session", pop$bars - pop$bars_matched_to_a_session,
       "count", "bars whose timestamp is not a declared open session close")

# ------------------------------------------------------- declared lifetimes
life <- dbGetQuery(con, "
SELECT instrument_id, assertion, effective_from, effective_to FROM snapshot_lifetime")
act <- life[life$assertion == "known_active", , drop = FALSE]
ina <- life[life$assertion == "known_inactive", , drop = FALSE]
record("scope", "instruments_with_a_declared_active_span",
       length(unique(act$instrument_id)), "count", "snapshot_lifetime known_active")
record("scope", "instruments_with_no_lifetime_assertion",
       pop$instruments_with_bars - length(unique(life$instrument_id)), "count",
       "declared span not derivable; resolves to unknown, unrestricted by gate 21")
record("scope", "instruments_with_a_declared_inactive_interval",
       length(unique(ina$instrument_id)), "count", "snapshot_lifetime known_inactive")

dbWriteTable(con, "act", act[, c("instrument_id", "effective_from", "effective_to")],
             temporary = TRUE, overwrite = TRUE)
dbWriteTable(con, "ina", ina[, c("instrument_id", "effective_from", "effective_to")],
             temporary = TRUE, overwrite = TRUE)

# Expected sessions: declared open sessions inside a declared active span. Only
# instruments carrying such a span are counted; the rest are reported separately
# rather than given an assumed span.
dbExecute(con, "
CREATE OR REPLACE TEMP TABLE expected AS
SELECT DISTINCT a.instrument_id, c.idx
FROM act a JOIN cal c
  ON c.ts >= a.effective_from
 AND (a.effective_to IS NULL OR c.ts < a.effective_to)")

dbExecute(con, "
CREATE OR REPLACE TEMP TABLE absent AS
WITH e AS (
  SELECT e.instrument_id, e.idx, (o.idx IS NOT NULL) AS observed
  FROM expected e LEFT JOIN obs o
    ON o.instrument_id = e.instrument_id AND o.idx = e.idx
), b AS (
  SELECT instrument_id, min(idx) AS first_obs, max(idx) AS last_obs
  FROM obs GROUP BY 1
)
SELECT e.instrument_id, e.idx,
       CASE
         WHEN EXISTS (
           SELECT 1 FROM ina i JOIN cal c ON c.idx = e.idx
           WHERE i.instrument_id = e.instrument_id
             AND c.ts >= i.effective_from
             AND (i.effective_to IS NULL OR c.ts < i.effective_to)
         ) THEN 'inside_declared_inactive'
         WHEN b.first_obs IS NULL THEN 'instrument_never_printed'
         WHEN e.idx < b.first_obs THEN 'before_first_observation'
         WHEN e.idx > b.last_obs THEN 'after_last_observation'
         ELSE 'inside_active_span'
       END AS location
FROM e LEFT JOIN b ON b.instrument_id = e.instrument_id
WHERE NOT e.observed")

tot <- dbGetQuery(con, "
SELECT (SELECT count(*) FROM expected) AS expected_sessions,
       (SELECT count(*) FROM absent) AS absent_sessions")
record("declared_absence", "expected_sessions", tot$expected_sessions, "count",
       "declared open sessions inside a declared active span")
record("declared_absence", "absent_sessions", tot$absent_sessions, "count",
       "expected with no bar")
record("declared_absence", "absent_pct",
       round(100 * tot$absent_sessions / tot$expected_sessions, 3), "percent",
       "against the declared denominator")

cat("=== absence by section 5.1's lifecycle location\n")
byloc <- dbGetQuery(con, "
SELECT location, count(*) AS sessions, count(DISTINCT instrument_id) AS instruments
FROM absent GROUP BY 1 ORDER BY sessions DESC")
print(byloc)
for (i in seq_len(nrow(byloc))) {
  record("by_location", paste0(byloc$location[[i]], "_sessions"), byloc$sessions[[i]],
         "count", "absent expected sessions at this lifecycle location")
  record("by_location", paste0(byloc$location[[i]], "_instruments"),
         byloc$instruments[[i]], "count", "instruments contributing")
}

# Run lengths, of the population section 5.1 names: absent expected sessions
# inside the active span. This is what a carry age would actually have to span.
cat("\n=== run lengths of absent expected sessions inside the active span\n")
runs <- dbGetQuery(con, "
WITH a AS (
  SELECT instrument_id, idx,
         idx - row_number() OVER (PARTITION BY instrument_id ORDER BY idx) AS grp
  FROM absent WHERE location = 'inside_active_span'
), r AS (SELECT instrument_id, grp, count(*) AS len FROM a GROUP BY 1, 2)
SELECT count(*) AS runs, median(len) AS p50, quantile_cont(len, 0.95) AS p95,
       max(len) AS max_len, sum(len) AS sessions,
       sum(CASE WHEN len <= 5 THEN len ELSE 0 END) AS sessions_in_runs_within_5,
       sum(greatest(len - 5, 0)) AS sessions_beyond_age_5
FROM r")
print(runs)
for (k in names(runs)) {
  record("interior_run_length", k, if (is.na(runs[[k]])) NA else runs[[k]],
         if (k %in% c("runs", "sessions", "sessions_in_runs_within_5",
                      "sessions_beyond_age_5")) "count" else "sessions",
         "consecutive absent expected sessions inside a declared active span")
}

evidence <- do.call(rbind, rows)
utils::write.csv(evidence, file.path(OUT, "declared_absence_evidence.csv"),
                 row.names = FALSE)
cat("\n=== scope\n")
print(evidence[evidence$topic %in% c("scope", "declared_absence"), c("key", "value")],
      right = FALSE)
