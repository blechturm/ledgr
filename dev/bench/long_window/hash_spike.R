lw_work <- Sys.getenv("LW_WORK", "C:/tmp/ledgr-lw-work")
# Snapshot hashing spike: current R hash versus hashing inside DuckDB.
# Rscript hash_spike.R <repo> <snapshot_db> <mode: check|time> [reps]
#   check: compare the row text R hashes with the same row rendered by DuckDB,
#          and the full bars block hash computed both ways (byte identity).
#   time:  time the current R hash (bars part and facts part separately), a
#          DuckDB reproduction of the bars hash, and part-wise verification of
#          one fact family and one universe-and-window bar subset.
args <- commandArgs(TRUE)
repo <- args[[1]]; db <- args[[2]]; mode <- args[[3]]
reps <- if (length(args) >= 4) as.integer(args[[4]]) else 1L
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
threads <- Sys.getenv("LW_DUCK_THREADS", "1")
con <- DBI::dbConnect(duckdb::duckdb(config = list(threads = threads)), db, read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
sid <- DBI::dbGetQuery(con, "SELECT snapshot_id FROM snapshots LIMIT 1")$snapshot_id[[1]]
q <- function(sql, ...) DBI::dbGetQuery(con, sql, params = list(...))

# R row text exactly as ledgr_snapshot_hash() builds it for bars.
fmt_num_vec <- function(x) { out <- rep(NA_character_, length(x)); ok <- !is.na(x); out[ok] <- sprintf("%.8f", round(x[ok], 8)); out }
token_vec <- function(x) { out <- as.character(x); out[is.na(out)] <- "NA"; out }
r_lines <- function(df) paste0(paste(
  token_vec(df$instrument_id), token_vec(ns$ledgr_snapshot_hash_format_distinct_ts_utc(df$ts_utc)),
  token_vec(fmt_num_vec(df$open)), token_vec(fmt_num_vec(df$high)), token_vec(fmt_num_vec(df$low)),
  token_vec(fmt_num_vec(df$close)), token_vec(fmt_num_vec(df$volume)), sep = "|"), "\n")

# DuckDB rendering of the same line.
num <- function(col) sprintf("coalesce(printf('%%.8f', round(%s, 8)), 'NA')", col)
duck_line <- paste0(
  "instrument_id || '|' || strftime(ts_utc, '%Y-%m-%dT%H:%M:%SZ') || '|' || ",
  paste(vapply(c("open", "high", "low", "close", "volume"), num, ""), collapse = " || '|' || "),
  " || chr(10)")
bars_sql <- function(where = "") sprintf("
  WITH r AS (
    SELECT %s AS line,
           (row_number() OVER (ORDER BY instrument_id, ts_utc) - 1) // 10000 AS blk,
           row_number() OVER (ORDER BY instrument_id, ts_utc) AS rn
    FROM snapshot_bars WHERE snapshot_id = ? %s),
  b AS (SELECT blk, sha256(string_agg(line, '' ORDER BY rn)) AS h FROM r GROUP BY blk)
  SELECT string_agg(h, '' ORDER BY blk) AS block_hashes, count(*) AS blocks FROM b", duck_line, where)

if (identical(mode, "check")) {
  ts_type <- q("SELECT data_type FROM information_schema.columns WHERE table_name = 'snapshot_bars' AND column_name = 'ts_utc'")
  cat("snapshot_bars.ts_utc type:", ts_type$data_type, "\n")
  n <- 200000L
  df <- q(sprintf("SELECT instrument_id, ts_utc, open, high, low, close, volume FROM snapshot_bars WHERE snapshot_id = ? ORDER BY instrument_id, ts_utc LIMIT %d", n), sid)
  dl <- q(sprintf("SELECT %s AS line FROM snapshot_bars WHERE snapshot_id = ? ORDER BY instrument_id, ts_utc LIMIT %d", duck_line, n), sid)$line
  rl <- r_lines(df)
  bad <- which(rl != dl)
  cat(sprintf("row text identical: %d of %d rows differ\n", length(bad), length(rl)))
  if (length(bad)) { cat("R:   ", rl[bad[1]]); cat("Duck:", dl[bad[1]]) }
  # Edge values: rounding ties, tiny and large magnitudes, negative zero.
  edge <- c(0.123456785, 0.123456775, 1e-9, -1e-9, 123456789.123456789, -0.0, 2.5e-8, 1/3, 1e15 + 0.5)
  re <- fmt_num_vec(edge)
  de <- vapply(edge, function(x) DBI::dbGetQuery(con, "SELECT printf('%.8f', round(?, 8)) AS s", params = list(x))$s, "")
  print(data.frame(value = format(edge, digits = 17), r = re, duckdb = de, same = re == de), row.names = FALSE)
  # Full bars block hashes both ways on this snapshot.
  r_blocks <- local({
    res <- DBI::dbSendQuery(con, "SELECT instrument_id, ts_utc, open, high, low, close, volume FROM snapshot_bars WHERE snapshot_id = ? ORDER BY instrument_id, ts_utc", params = list(sid))
    on.exit(DBI::dbClearResult(res)); out <- character(); buf <- character()
    repeat { ch <- DBI::dbFetch(res, n = 10000); if (!nrow(ch)) break; buf <- c(buf, r_lines(ch))
      while (length(buf) >= 10000) { out <- c(out, digest::digest(paste0(buf[1:10000], collapse = ""), algo = "sha256")); buf <- buf[-(1:10000)] } }
    if (length(buf)) out <- c(out, digest::digest(paste0(buf, collapse = ""), algo = "sha256"))
    paste(out, collapse = "")
  })
  d_blocks <- q(bars_sql(), sid)$block_hashes
  cat("bars block hashes identical:", identical(r_blocks, d_blocks), "\n")
  stored <- q("SELECT snapshot_hash FROM snapshots WHERE snapshot_id = ?", sid)$snapshot_hash
  cat("current ledgr_snapshot_hash() equals stored:", identical(ns$ledgr_snapshot_hash(con, sid), stored), "\n")
}

if (identical(mode, "time")) {
  clock <- function(f) { f(); v <- numeric(reps); for (r in seq_len(reps)) { t0 <- proc.time()[["elapsed"]]; f(); v[r] <- proc.time()[["elapsed"]] - t0 }; median(v) }
  bars_n <- q("SELECT count(*) AS n FROM snapshot_bars WHERE snapshot_id = ?", sid)$n
  fact_rows <- sum(vapply(c("snapshot_membership", "snapshot_lifetime", "snapshot_sessions", "snapshot_trading_status"),
                          function(t) as.numeric(q(sprintf("SELECT count(*) AS n FROM %s WHERE snapshot_id = ?", t), sid)$n), 0))
  t_full_r <- clock(function() ns$ledgr_snapshot_hash(con, sid))
  t_facts_r <- clock(function() ns$ledgr_snapshot_availability_hash_payload(con, sid))
  t_bars_duck <- clock(function() q(bars_sql(), sid))
  # Part-wise: one fact family hashed in DuckDB over ordered row text.
  t_family_duck <- clock(function() q("SELECT sha256(string_agg(concat_ws('|', fact_id, instrument_id, universe_id, set_id, strftime(effective_from, '%Y-%m-%dT%H:%M:%SZ'), coalesce(strftime(effective_to, '%Y-%m-%dT%H:%M:%SZ'), 'NA'), strftime(knowledge_time, '%Y-%m-%dT%H:%M:%SZ'), member::VARCHAR, coalesce(provenance_json, 'NA')), chr(10) ORDER BY universe_id, set_id, instrument_id, fact_id)) AS h FROM snapshot_membership WHERE snapshot_id = ?", sid))
  # Part-wise: bars of 500 instruments over the last 252 sessions.
  last_ts <- q("SELECT DISTINCT ts_utc FROM snapshot_bars WHERE snapshot_id = ? ORDER BY ts_utc DESC LIMIT 252", sid)$ts_utc
  ids <- q("SELECT DISTINCT instrument_id FROM snapshot_bars WHERE snapshot_id = ? ORDER BY instrument_id LIMIT 500", sid)$instrument_id
  win_where <- sprintf("AND ts_utc >= TIMESTAMP '%s' AND instrument_id IN (%s)",
                       format(min(last_ts), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
                       paste(sprintf("'%s'", ids), collapse = ","))
  t_window_duck <- clock(function() q(bars_sql(win_where), sid))
  out <- data.frame(db = basename(dirname(db)), duck_threads = threads, bars = bars_n, fact_rows = fact_rows,
                    r_full_hash_s = t_full_r, r_facts_payload_s = t_facts_r,
                    duck_bars_hash_s = t_bars_duck, duck_membership_family_s = t_family_duck,
                    duck_window_500x252_s = t_window_duck,
                    r_over_duck_bars = (t_full_r - t_facts_r) / t_bars_duck)
  print(out, row.names = FALSE)
  f <- paste0(lw_work, "/hash_spike_timing.csv")
  write.table(out, f, sep = ",", row.names = FALSE, col.names = !file.exists(f), append = file.exists(f))
}
