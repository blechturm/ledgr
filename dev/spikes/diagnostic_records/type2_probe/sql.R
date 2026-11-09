# proto: one fixed-axis hold reconstruction query, never a runtime reader.
# Counts and axis are input relations; all sequence placement is derived from
# residuals. Positions deliberately use SQL SUM to test the proposed recipe.
hold_sql <- function(instrument = NULL, time = NULL) {
  filter <- if (is.null(instrument)) "" else paste0("WHERE a.instrument_id = '", instrument,
    "' AND g.ts_utc = TIMESTAMP '", format(time, "%Y-%m-%d %H:%M:%S", tz = "UTC"), "'")
  stamp <- if(is.null(time)) NULL else paste0("TIMESTAMP '",format(time,"%Y-%m-%d %H:%M:%S",tz="UTC"),"'")
  paste0("WITH stored0 AS (
    SELECT diagnostic_seq AS seq, ts_utc FROM run_diagnostics WHERE run_id='t2'
    UNION ALL SELECT decision_seq, ts_utc FROM run_diagnostic_implicit WHERE run_id='t2' AND execution_seq IS NOT NULL
    UNION ALL SELECT execution_seq, ts_utc FROM run_diagnostic_implicit WHERE run_id='t2' AND execution_seq IS NOT NULL
  ), stored AS (",
    if(is.null(time)) "SELECT * FROM stored0" else paste0(
      "SELECT * FROM stored0 WHERE ts_utc=",stamp,
      " UNION ALL SELECT * FROM stored0 WHERE seq=(SELECT max(seq) FROM stored0 WHERE ts_utc<",stamp,")"),
  "), gaps0 AS (
    SELECT seq, ts_utc, lag(seq, 1, 0) OVER (ORDER BY seq) AS prev FROM stored
  ), gaps AS (
    SELECT v.seq::INTEGER AS diagnostic_seq, g.ts_utc FROM gaps0 g,
      LATERAL range(g.prev+1, g.seq) v(seq) WHERE g.seq > g.prev+1
  ), decisions AS (
    SELECT diagnostic_seq AS seq, ts_utc, instrument_id FROM run_diagnostics
      WHERE run_id='t2' AND stage='decision' AND instrument_id<>''
    UNION ALL SELECT decision_seq, ts_utc, instrument_id FROM run_diagnostic_implicit
      WHERE run_id='t2' AND execution_seq IS NOT NULL
  ), bases AS (
    SELECT ts_utc, min(seq-a.k) AS base FROM decisions d JOIN t2_axis a USING(instrument_id) GROUP BY ts_utc
  ), gap_min AS (
    SELECT ts_utc, min(diagnostic_seq)-1 AS base FROM gaps GROUP BY ts_utc
  ), cells AS (
    SELECT g.diagnostic_seq, g.ts_utc, a.instrument_id FROM gaps g
    JOIN gap_min m USING(ts_utc) LEFT JOIN bases b USING(ts_utc)
    JOIN t2_axis a ON a.k=g.diagnostic_seq-coalesce(b.base,m.base) ", filter, "
  ), ep AS (
    SELECT instrument_id, ts_utc, event_seq,
      sum(position_delta) OVER (PARTITION BY instrument_id ORDER BY ts_utc,event_seq ROWS UNBOUNDED PRECEDING) AS pos
    FROM ledger_events WHERE run_id='t2'",
    if (is.null(instrument)) "" else paste0(" AND instrument_id='", instrument, "'"), "
  ), last_ep AS (
    SELECT instrument_id, ts_utc, pos FROM ep QUALIFY row_number() OVER
      (PARTITION BY instrument_id,ts_utc ORDER BY event_seq DESC)=1
  ), positions AS (
    SELECT c.*, coalesce(e.pos,0)::DOUBLE AS pos FROM cells c ASOF LEFT JOIN last_ep e
      ON c.instrument_id=e.instrument_id AND c.ts_utc>=e.ts_utc
  ) SELECT 't2'::VARCHAR AS run_id, p.diagnostic_seq, p.ts_utc, p.instrument_id,
    'decision'::VARCHAR AS stage, 'recorded'::VARCHAR AS outcome,
    'decision_recorded'::VARCHAR AS reason_code, 'decision_recorded'::VARCHAR AS reasons,
    pos AS target, pos AS quantity, b.close AS price, 'current_close'::VARCHAR AS mark_source,
    0::INTEGER AS mark_age, p.ts_utc AS decision_ts_utc, NULL::TIMESTAMP AS execution_ts_utc,
    NULL::INTEGER AS event_seq, pos AS target_before_risk, pos AS target_after_risk,
    pos AS position_before, pos AS position_after, NULL::VARCHAR AS feature_identity_json,
    '{}'::VARCHAR AS detail_json FROM positions p JOIN runs r ON r.run_id='t2'
    JOIN snapshot_bars b ON b.snapshot_id=r.snapshot_id AND b.instrument_id=p.instrument_id AND b.ts_utc=p.ts_utc")
}

certify <- function(con) {
  # Distinct, contiguous coverage plus per-pulse counts, before any filtering.
  bad <- DBI::dbGetQuery(con, "WITH s AS (
    SELECT diagnostic_seq AS seq, ts_utc FROM run_diagnostics WHERE run_id='t2'
    UNION ALL SELECT decision_seq,ts_utc FROM run_diagnostic_implicit WHERE run_id='t2' AND execution_seq IS NOT NULL
    UNION ALL SELECT execution_seq,ts_utc FROM run_diagnostic_implicit WHERE run_id='t2' AND execution_seq IS NOT NULL
  ), g AS (SELECT *,lag(seq,1,0) OVER(ORDER BY seq) AS prev FROM s),
  n AS (SELECT ts_utc,sum(seq-prev-1) AS n FROM g WHERE seq>prev+1 GROUP BY ts_utc)
  SELECT * FROM n FULL JOIN t2_counts c USING(ts_utc) WHERE coalesce(n.n,0)<>coalesce(c.n,0)")
  if (nrow(bad)) rlang::abort("hold count mismatch", class="ledgr_diagnostic_corrupt")
  invisible(TRUE)
}
