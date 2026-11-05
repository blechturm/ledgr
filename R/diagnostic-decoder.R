# One logical diagnostic read boundary. Physical residual rows and certified
# implicit clean pairs are unioned here; no consumer may infer omitted rows.
ledgr_diagnostic_add_in <- function(where, params, column, values) {
  if (is.null(values)) return(list(where = where, params = params))
  values <- as.character(values)
  if (length(values) == 0L) return(list(where = c(where, "FALSE"), params = params))
  list(
    where = c(where, sprintf("%s IN (%s)", column, paste(rep("?", length(values)), collapse = ", "))),
    params = c(params, as.list(values))
  )
}

ledgr_diagnostic_logical_sql <- function() {
  paste(
    "SELECT * FROM run_diagnostics",
    "UNION ALL SELECT run_id, decision_seq AS diagnostic_seq, ts_utc,",
    "instrument_id, 'decision' AS stage, 'recorded' AS outcome,",
    "'decision_recorded' AS reason_code, 'decision_recorded' AS reasons,",
    '"target", position_before AS quantity, decision_price AS price,',
    "decision_mark_source AS mark_source, decision_mark_age AS mark_age,",
    "ts_utc AS decision_ts_utc, NULL::TIMESTAMP AS execution_ts_utc,",
    "NULL::INTEGER AS event_seq, \"target\" AS target_before_risk,",
    '"target" AS target_after_risk, position_before,',
    "position_before AS position_after, NULL::VARCHAR AS feature_identity_json,",
    "'{}' AS detail_json FROM run_diagnostic_implicit",
    "UNION ALL SELECT run_id, execution_seq AS diagnostic_seq, ts_utc,",
    "instrument_id, 'execution' AS stage, 'filled' AS outcome,",
    "'' AS reason_code, '' AS reasons, \"target\",",
    "fill_quantity AS quantity, fill_price AS price, '' AS mark_source,",
    "NULL::INTEGER AS mark_age, ts_utc AS decision_ts_utc, execution_ts_utc,",
    "event_seq, \"target\" AS target_before_risk, \"target\" AS target_after_risk,",
    "position_before, position_after, NULL::VARCHAR AS feature_identity_json,",
    "'{}' AS detail_json FROM run_diagnostic_implicit WHERE execution_seq IS NOT NULL"
  )
}

# The integrity query must not mutate a caller-owned DuckDB setting. DuckDB
# reports memory_limit in a rounded display form, so SET/restore cannot recover
# an arbitrary custom value losslessly. Keep the vectorized SQL plan and turn
# a resource refusal into a stable ledgr condition instead.
ledgr_diagnostic_query <- function(code) {
  tryCatch(
    force(code),
    error = function(cnd) {
      message <- conditionMessage(cnd)
      if (grepl(
        "out of memory|failed to pin block|could not allocate",
        message,
        ignore.case = TRUE
      )) {
        rlang::abort(
          paste(
            "Diagnostic integrity validation exhausted DuckDB's available",
            "memory."
          ),
          class = "ledgr_diagnostic_resource_exhausted",
          parent = cnd
        )
      }
      stop(cnd)
    }
  )
}

# Every DuckDB statement on the logical diagnostic read/validation path passes
# this boundary.  This keeps backend resource failures classed without
# changing the caller-owned memory limit or masking ordinary query errors.
ledgr_diagnostic_db_get_query <- function(con, statement, ...) {
  ledgr_diagnostic_query(DBI::dbGetQuery(con, statement, ...))
}

# DuckDB allocates one transaction id per statement outside an explicit
# transaction and reuses the id inside one. A cache hit therefore needs only
# this constant-size probe to refuse reuse while uncommitted state could be
# visible on the connection.
ledgr_diagnostic_explicit_transaction <- function(con) {
  first <- ledgr_diagnostic_db_get_query(
    con,
    "SELECT current_transaction_id() AS transaction_id"
  )$transaction_id[[1L]]
  second <- ledgr_diagnostic_db_get_query(
    con,
    "SELECT current_transaction_id() AS transaction_id"
  )$transaction_id[[1L]]
  identical(first, second)
}

ledgr_diagnostic_persisted_state <- function(con, coverage, summaries) {
  databases <- ledgr_diagnostic_db_get_query(
    con,
    paste(
      "SELECT database_name, path FROM duckdb_databases()",
      "ORDER BY database_name"
    )
  )
  current <- as.character(ledgr_diagnostic_db_get_query(
    con,
    "SELECT current_database() AS database_name"
  )$database_name[[1L]])
  user_database <- !(as.character(databases$database_name) %in% c("system", "temp"))
  databases <- databases[user_database, , drop = FALSE]
  db_paths <- as.character(databases$path)
  main <- which(as.character(databases$database_name) == current)
  durable <- length(main) == 1L && length(db_paths) > 0L &&
    all(!is.na(db_paths) & nzchar(db_paths) & db_paths != ":memory:") &&
    all(file.exists(db_paths))
  if (!durable) return(NULL)

  store_paths <- unique(c(db_paths, paste0(db_paths, ".wal")))
  store_info <- file.info(store_paths)
  list(
    coverage = coverage[
      order(as.character(coverage$run_id), method = "radix"),
      c("run_id", "logical_count", "codec_rule_version"),
      drop = FALSE
    ],
    summary = summaries[
      order(as.character(summaries$run_id), method = "radix"),
      c("run_id", "summary_hash"),
      drop = FALSE
    ],
    stores = data.frame(
      path = store_paths,
      exists = !is.na(store_info$size),
      size = as.numeric(store_info$size),
      mtime = as.numeric(store_info$mtime),
      stringsAsFactors = FALSE
    )
  )
}

# Validate the compact decision order wholly inside DuckDB. The only R-side
# inputs are one run's already-authoritative configuration axis and universe
# rule; the query returns at most one offending run/issue row. In particular,
# no implicit diagnostic row or per-row timestamp/string key crosses the DBI
# boundary.
ledgr_diagnostic_decision_order_bad <- function(con, run_ids) {
  if (length(run_ids) == 0L) {
    return(data.frame(run_id = character(), issue = character()))
  }
  marks <- paste(rep("?", length(run_ids)), collapse = ", ")
  metadata <- ledgr_diagnostic_db_get_query(
    con,
    paste0(
      "SELECT run_id, snapshot_id, config_json FROM runs WHERE run_id IN (",
      marks, ")"
    ),
    params = as.list(run_ids)
  )
  metadata <- metadata[match(run_ids, metadata$run_id), , drop = FALSE]
  if (nrow(metadata) != length(run_ids) || anyNA(metadata$run_id)) {
    missing <- run_ids[is.na(match(run_ids, metadata$run_id))]
    affected <- if (length(missing) > 0L) missing[[1L]] else run_ids[[1L]]
    return(data.frame(
      run_id = affected,
      issue = "decision_order",
      stringsAsFactors = FALSE
    ))
  }

  axis_rows <- lapply(seq_len(nrow(metadata)), function(row) {
    config <- ledgr_json_read_config(metadata$config_json[[row]])
    axis <- as.character(config$universe$instrument_ids)
    universe_rule <- config$availability$universe_rule %||% NULL
    uses_membership <- !is.null(universe_rule)
    n <- max(1L, length(axis))
    data.frame(
      run_id = rep(as.character(metadata$run_id[[row]]), n),
      snapshot_id = rep(as.character(metadata$snapshot_id[[row]]), n),
      universe_id = rep(
        if (uses_membership) as.character(universe_rule$universe_id) else NA_character_,
        n
      ),
      uses_membership = rep(uses_membership, n),
      instrument_id = if (length(axis) > 0L) axis else NA_character_,
      axis_pos = if (length(axis) > 0L) seq_along(axis) else NA_integer_,
      axis_size = rep(length(axis), n),
      stringsAsFactors = FALSE
    )
  })
  axis_rows <- do.call(rbind, axis_rows)
  relation_name <- basename(tempfile(pattern = "ledgr_diagnostic_axis_"))
  duckdb::duckdb_register(con, relation_name, axis_rows)
  on.exit(
    try(duckdb::duckdb_unregister(con, relation_name), silent = TRUE),
    add = TRUE
  )
  relation <- as.character(DBI::dbQuoteIdentifier(con, relation_name))

  query <- paste0(
    "WITH run_meta AS (SELECT DISTINCT run_id, snapshot_id, universe_id, ",
    "uses_membership, CAST(axis_size AS BIGINT) AS axis_size FROM ", relation,
    "), axis AS (SELECT run_id, instrument_id, CAST(axis_pos AS BIGINT) AS axis_pos, ",
    "CAST(axis_size AS BIGINT) AS axis_size FROM ", relation,
    " WHERE instrument_id IS NOT NULL), logical_decisions AS (",
    "SELECT run_id, ts_utc, instrument_id, diagnostic_seq AS decision_seq, ",
    "NULL::BIGINT AS decision_order, FALSE AS is_implicit FROM run_diagnostics ",
    "WHERE run_id IN (", marks,
    ") AND stage = 'decision' AND instrument_id <> '' UNION ALL ",
    "SELECT run_id, ts_utc, instrument_id, decision_seq, decision_order, TRUE ",
    "FROM run_diagnostic_implicit WHERE run_id IN (", marks,
    ")), decision_rows AS (SELECT * FROM logical_decisions), header_ranked AS (",
    "SELECT rm.run_id, rm.snapshot_id, rm.universe_id, h.set_id, h.complete, ",
    "h.effective_from, h.knowledge_time, ROW_NUMBER() OVER (PARTITION BY rm.run_id ",
    "ORDER BY h.effective_from, h.knowledge_time, h.set_id) AS header_rank ",
    "FROM run_meta rm JOIN snapshot_membership_sets h ON ",
    "h.snapshot_id = rm.snapshot_id AND h.universe_id = rm.universe_id ",
    "WHERE rm.uses_membership), headers AS (SELECT *, ",
    "GREATEST(effective_from, knowledge_time) AS available_from ",
    "FROM header_ranked WHERE knowledge_time IS NOT NULL), ",
    "member_event_points AS (SELECT h.run_id, m.instrument_id, h.available_from, ",
    "MAX(h.header_rank) AS event_rank FROM headers h JOIN snapshot_membership m ",
    "ON m.snapshot_id = h.snapshot_id AND m.universe_id = h.universe_id ",
    "AND m.set_id = h.set_id GROUP BY h.run_id, m.instrument_id, h.available_from), ",
    "member_states AS (SELECT run_id, instrument_id, available_from, ",
    "MAX(event_rank) OVER (PARTITION BY run_id, instrument_id ORDER BY available_from ",
    "ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS member_rank ",
    "FROM member_event_points), complete_event_points AS (SELECT run_id, ",
    "available_from, MAX(header_rank) AS event_rank FROM headers WHERE complete ",
    "GROUP BY run_id, available_from), complete_states AS (SELECT run_id, ",
    "available_from, MAX(event_rank) OVER (PARTITION BY run_id ORDER BY available_from ",
    "ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS complete_rank ",
    "FROM complete_event_points), decision_header AS (SELECT d.*, rm.snapshot_id, ",
    "rm.universe_id, COALESCE(m.member_rank, 0) AS member_rank, ",
    "COALESCE(c.complete_rank, 0) AS complete_rank FROM decision_rows d ",
    "JOIN run_meta rm USING (run_id) ASOF LEFT JOIN member_states m ON ",
    "m.run_id = d.run_id AND m.instrument_id = d.instrument_id ",
    "AND m.available_from <= d.ts_utc ASOF LEFT JOIN complete_states c ON ",
    "c.run_id = d.run_id AND c.available_from <= d.ts_utc ",
    "WHERE rm.uses_membership), interval_ranked AS (SELECT d.*, ",
    "m.fact_id AS interval_fact_id, m.member AS interval_member, ROW_NUMBER() OVER ",
    "(PARTITION BY d.run_id, d.ts_utc, d.instrument_id ORDER BY ",
    "m.effective_from DESC NULLS LAST, m.knowledge_time DESC NULLS LAST, ",
    "m.fact_id DESC NULLS LAST) AS interval_rank FROM decision_header d ",
    "LEFT JOIN snapshot_membership m ON m.snapshot_id = d.snapshot_id ",
    "AND m.universe_id = d.universe_id AND m.set_id IS NULL ",
    "AND m.instrument_id = d.instrument_id AND m.effective_from <= d.ts_utc ",
    "AND m.knowledge_time <= d.ts_utc AND ",
    "(m.effective_to IS NULL OR d.ts_utc < m.effective_to)), ",
    "dynamic_classified AS (SELECT *, CASE WHEN interval_rank = 1 ",
    "AND interval_fact_id IS NOT NULL THEN interval_member ELSE ",
    "member_rank > 0 AND member_rank >= complete_rank END AS is_member ",
    "FROM interval_ranked WHERE interval_rank = 1), dynamic_expected AS (",
    "SELECT run_id, ts_utc, instrument_id, decision_seq, decision_order, is_implicit, ",
    "ROW_NUMBER() OVER (PARTITION BY run_id, ts_utc ORDER BY ",
    "CASE WHEN is_member THEN 0 ELSE 1 END, instrument_id) AS expected_context ",
    "FROM dynamic_classified), fixed_expected AS (SELECT d.run_id, d.ts_utc, ",
    "d.instrument_id, d.decision_seq, d.decision_order, d.is_implicit, ",
    "a.axis_pos AS expected_context FROM decision_rows d JOIN run_meta rm ",
    "USING (run_id) LEFT JOIN axis a USING (run_id, instrument_id) ",
    "WHERE NOT rm.uses_membership), expected_rows AS (",
    "SELECT * FROM dynamic_expected UNION ALL SELECT * FROM fixed_expected), ",
    "decoded AS (SELECT i.*, e.expected_context, a.axis_pos, rm.axis_size, ",
    "CASE WHEN i.decision_order BETWEEN 1 AND rm.axis_size * rm.axis_size ",
    "THEN ((i.decision_order - 1) // rm.axis_size) + 1 END AS context_order, ",
    "CASE WHEN i.decision_order BETWEEN 1 AND rm.axis_size * rm.axis_size ",
    "THEN ((i.decision_order - 1) % rm.axis_size) + 1 END AS decoded_axis, ",
    "EXISTS (SELECT 1 FROM snapshot_sessions s WHERE ",
    "s.snapshot_id = rm.snapshot_id AND s.status = 'open' ",
    "AND s.session_close = i.ts_utc) OR EXISTS (SELECT 1 FROM snapshot_bars b ",
    "WHERE b.snapshot_id = rm.snapshot_id AND b.ts_utc = i.ts_utc) AS session_ok ",
    "FROM decision_rows i JOIN run_meta rm USING (run_id) LEFT JOIN expected_rows e ",
    "USING (run_id, ts_utc, instrument_id, decision_seq, decision_order, is_implicit) ",
    "LEFT JOIN axis a USING (run_id, instrument_id) WHERE i.is_implicit), ",
    "neighbors AS (SELECT *, COUNT(*) OVER ",
    "(PARTITION BY run_id, ts_utc, context_order) AS order_n, ",
    "LAG(decision_seq) OVER (PARTITION BY run_id, ts_utc ORDER BY context_order) ",
    "AS prior_seq FROM decoded), issues AS (SELECT *, CASE WHEN ",
    "axis_pos IS NULL OR expected_context IS NULL OR context_order IS NULL OR ",
    "decoded_axis IS NULL OR decoded_axis <> axis_pos OR ",
    "context_order <> expected_context OR order_n <> 1 OR NOT session_ok ",
    "THEN 'decision_order' WHEN prior_seq IS NOT NULL AND ",
    "decision_seq <= prior_seq THEN 'sequence' END AS issue FROM neighbors) ",
    "SELECT run_id, issue FROM issues WHERE issue IS NOT NULL ",
    "ORDER BY run_id, issue LIMIT 1"
  )
  bad <- ledgr_diagnostic_db_get_query(
    con,
    query,
    params = c(as.list(run_ids), as.list(run_ids))
  )
  bad[seq_len(min(1L, nrow(bad))), c("run_id", "issue"), drop = FALSE]
}

ledgr_diagnostic_require_coverage <- function(con, run_ids) {
  if (length(run_ids) == 0L) return(invisible(TRUE))
  marks <- paste(rep("?", length(run_ids)), collapse = ", ")
  coverage <- ledgr_diagnostic_db_get_query(
    con,
    paste0("SELECT run_id, logical_count, codec_rule_version FROM run_diagnostic_coverage WHERE run_id IN (", marks, ")"),
    params = as.list(run_ids)
  )
  state <- attr(con, "ledgr_diagnostic_validation_state", exact = TRUE)
  cache <- if (is.environment(state) &&
      as.integer(state$diagnostic_validation_depth %||% 0L) > 0L &&
      is.environment(state$diagnostic_validation_cache)) {
    state$diagnostic_validation_cache
  } else {
    NULL
  }
  cache_key <- paste(sort(unique(as.character(run_ids)), method = "radix"), collapse = "\r")
  validation_state <- NULL
  if (!is.null(cache)) {
    summaries <- ledgr_diagnostic_summary_read(con, run_ids)
    validation_state <- ledgr_diagnostic_persisted_state(
      con, coverage, summaries
    )
    if (is.null(validation_state)) {
      # A missing main path, missing store stat, or in-memory database exposes
      # no independent persisted-state token. Correctness wins over reuse.
      cache <- NULL
    } else {
      if (exists(cache_key, envir = cache, inherits = FALSE) &&
          identical(get(cache_key, envir = cache, inherits = FALSE), validation_state)) {
        if (!ledgr_diagnostic_explicit_transaction(con)) {
          return(invisible(TRUE))
        }
        # An uncommitted change can be visible only to this connection. Drop
        # the persisted-state proof and validate the transaction cold.
        rm(list = cache_key, envir = cache)
      }
    }
  }
  missing <- setdiff(run_ids, as.character(coverage$run_id))
  if (length(missing) > 0L ||
      any(coverage$codec_rule_version != ledgr_diagnostic_codec_rule_version)) {
    affected <- if (length(missing) > 0L) missing[[1L]] else {
      as.character(coverage$run_id[
        coverage$codec_rule_version != ledgr_diagnostic_codec_rule_version
      ][[1L]])
    }
    rlang::abort(
      sprintf(
        "Diagnostic codec coverage is missing or uses an unsupported rule for run `%s`.",
        affected
      ),
      class = "ledgr_diagnostic_corrupt"
    )
  }
  counts <- ledgr_diagnostic_db_get_query(
    con,
    paste0(
      "SELECT run_id, COUNT(*) AS n, COUNT(DISTINCT diagnostic_seq) AS distinct_n, ",
      "MIN(diagnostic_seq) AS first_seq, MAX(diagnostic_seq) AS last_seq FROM (",
      ledgr_diagnostic_logical_sql(), ") logical WHERE run_id IN (", marks,
      ") GROUP BY run_id"
    ),
    params = as.list(run_ids)
  )
  covered <- intersect(run_ids, as.character(coverage$run_id))
  expected <- as.integer(coverage$logical_count[match(covered, coverage$run_id)])
  row <- match(covered, as.character(counts$run_id))
  present <- !is.na(row)
  observed <- rep.int(NA_integer_, length(covered))
  distinct <- first <- last <- observed
  observed[present] <- as.integer(counts$n[row[present]])
  distinct[present] <- as.integer(counts$distinct_n[row[present]])
  first[present] <- as.integer(counts$first_seq[row[present]])
  last[present] <- as.integer(counts$last_seq[row[present]])
  ok <- (expected == 0L & !present) |
    (expected > 0L & present & observed == expected & distinct == expected &
       first == 1L & last == expected)
  if (any(!ok)) {
    rlang::abort(
      sprintf(
        "Diagnostic codec coverage is corrupt for run `%s`.",
        covered[which(!ok)[[1L]]]
      ),
      class = "ledgr_diagnostic_corrupt"
    )
  }
  association_params <- as.list(run_ids)
  association <- ledgr_diagnostic_db_get_query(
    con,
    paste0(
      "SELECT DISTINCT i.run_id FROM run_diagnostic_implicit i ",
      "JOIN runs r ON r.run_id = i.run_id ",
      "LEFT JOIN snapshot_bars b ON b.snapshot_id = r.snapshot_id ",
      "AND b.instrument_id = i.instrument_id AND b.ts_utc = i.ts_utc ",
      "LEFT JOIN ledger_events e ON e.run_id = i.run_id AND e.event_seq = i.event_seq ",
      "WHERE i.run_id IN (", marks, ") AND (",
      "i.decision_mark_source <> 'current_close' OR i.decision_mark_age <> 0 OR ",
      "b.ts_utc IS NULL OR b.close IS DISTINCT FROM i.decision_price OR ",
      "(i.execution_seq IS NOT NULL AND (",
      "e.event_seq IS NULL OR e.event_type <> 'FILL' OR ",
      "e.instrument_id IS DISTINCT FROM i.instrument_id OR ",
      "e.ts_utc IS DISTINCT FROM i.execution_ts_utc OR ",
      "e.qty IS DISTINCT FROM i.fill_quantity OR ",
      "e.price IS DISTINCT FROM i.fill_price OR ",
      "i.position_after IS DISTINCT FROM (i.position_before + e.position_delta) OR ",
      "i.target IS DISTINCT FROM i.position_after OR ",
      "i.decision_seq >= i.execution_seq)) OR ",
      "(i.execution_seq IS NULL AND (i.target IS DISTINCT FROM i.position_before OR ",
      "i.position_after IS DISTINCT FROM i.position_before))) ",
      "ORDER BY i.run_id LIMIT 1"
    ),
    params = association_params
  )
  if (nrow(association) != 0L) {
    rlang::abort(
      sprintf(
        "Diagnostic codec association evidence is corrupt for run `%s`.",
        as.character(association$run_id[[1L]])
      ),
      class = "ledgr_diagnostic_corrupt"
    )
  }
  order_bad <- ledgr_diagnostic_db_get_query(
    con,
    paste0(
      "SELECT run_id, COUNT(*) AS bad FROM (",
      "SELECT run_id, seq, ord, LAG(seq) OVER (PARTITION BY run_id, ts_utc ORDER BY ord) AS prior_seq, ",
      "COUNT(*) OVER (PARTITION BY run_id, ts_utc, ord) AS ord_n FROM (",
      "SELECT run_id, ts_utc, execution_seq AS seq, event_seq AS ord ",
      "FROM run_diagnostic_implicit WHERE run_id IN (", marks, ") AND execution_seq IS NOT NULL",
      ") evidence) x WHERE ord IS NULL OR ord <= 0 OR ord_n <> 1 OR ",
      "(prior_seq IS NOT NULL AND seq <= prior_seq) ",
      "GROUP BY run_id ORDER BY run_id LIMIT 1"
    ),
    params = as.list(run_ids)
  )
  if (nrow(order_bad) != 0L) {
    rlang::abort(
      sprintf(
        "Diagnostic codec sequence evidence is corrupt for run `%s`.",
        as.character(order_bad$run_id[[1L]])
      ),
      class = "ledgr_diagnostic_corrupt"
    )
  }
  order_bad <- ledgr_diagnostic_decision_order_bad(con, run_ids)
  if (nrow(order_bad) > 0L) {
    label <- if (identical(order_bad$issue[[1L]], "sequence")) {
      "sequence"
    } else {
      "decision-order"
    }
    rlang::abort(
      sprintf(
        "Diagnostic codec %s evidence is corrupt for run `%s`.",
        label,
        as.character(order_bad$run_id[[1L]])
      ),
      class = "ledgr_diagnostic_corrupt"
    )
  }
  if (!is.null(cache)) {
    # Validation registers and removes a temporary axis relation. Capture the
    # store token after that work so the proof describes the persisted state
    # that later public reads will observe.
    summaries <- ledgr_diagnostic_summary_read(con, run_ids)
    validation_state <- ledgr_diagnostic_persisted_state(
      con, coverage, summaries
    )
    if (!is.null(validation_state) &&
        !ledgr_diagnostic_explicit_transaction(con)) {
      assign(cache_key, validation_state, envir = cache)
    }
  }
  invisible(TRUE)
}

ledgr_diagnostic_decode <- function(con, run_ids, stage = NULL, outcome = NULL,
                                    reason_code = NULL, mark_source = NULL,
                                    instrument_id = NULL, explain_ts_utc = NULL,
                                    include_strategy_intent = FALSE) {
  run_ids <- unique(as.character(run_ids))
  ledgr_diagnostic_require_coverage(
    con,
    run_ids
  )
  where <- character()
  params <- list()
  add <- function(column, values) {
    result <- ledgr_diagnostic_add_in(where, params, column, values)
    where <<- result$where
    params <<- result$params
  }
  add("run_id", run_ids); add("stage", stage); add("outcome", outcome)
  add("reason_code", reason_code); add("mark_source", mark_source)
  if (!is.null(instrument_id)) {
    if (length(instrument_id) != 1L || is.na(instrument_id)) {
      rlang::abort("`instrument_id` must be one non-missing value.", class = "ledgr_internal_error")
    }
    if (isTRUE(include_strategy_intent)) {
      where <- c(where, paste(
        "((instrument_id = ? AND stage IN ('decision', 'execution'))",
        "OR (instrument_id = '' AND stage = 'decision'",
        "AND reason_code = 'strategy_intent'))"
      ))
    } else {
      where <- c(where, "instrument_id = ?", "stage IN ('decision', 'execution')")
    }
    params <- c(params, list(as.character(instrument_id)))
  }
  if (!is.null(explain_ts_utc)) {
    if (length(explain_ts_utc) != 1L || is.na(explain_ts_utc)) {
      rlang::abort("`explain_ts_utc` must be one non-missing time.", class = "ledgr_internal_error")
    }
    where <- c(where, "((stage = 'decision' AND ts_utc = ?) OR (stage = 'execution' AND decision_ts_utc = ?))")
    time <- as.POSIXct(explain_ts_utc, tz = "UTC")
    params <- c(params, list(time, time))
  }
  order <- if (length(run_ids) > 1L) "run_id, diagnostic_seq" else "diagnostic_seq"
  rows <- ledgr_diagnostic_db_get_query(
    con,
    paste(
      "SELECT * FROM (", ledgr_diagnostic_logical_sql(), ") logical",
      if (length(where) > 0L) paste("WHERE", paste(where, collapse = " AND ")) else "",
      paste("ORDER BY", order)
    ),
    params = params
  )
  absent_sizing_reason <- rows$stage == "sizing" & !nzchar(rows$reasons)
  rows$reasons[absent_sizing_reason] <- NA_character_
  tibble::as_tibble(rows)
}

ledgr_diagnostic_next_seq <- function(con, run_id) {
  row <- ledgr_diagnostic_db_get_query(
    con,
    paste0(
      "SELECT GREATEST(",
      "COALESCE((SELECT MAX(diagnostic_seq) FROM run_diagnostics WHERE run_id = ?), 0), ",
      "COALESCE((SELECT MAX(decision_seq) FROM run_diagnostic_implicit WHERE run_id = ?), 0), ",
      "COALESCE((SELECT MAX(execution_seq) FROM run_diagnostic_implicit WHERE run_id = ?), 0)",
      ") + 1 AS next_seq"
    ),
    params = list(run_id, run_id, run_id)
  )
  as.integer(row$next_seq[[1L]])
}

ledgr_diagnostic_flag_counts <- function(con, run_ids) {
  run_ids <- unique(as.character(run_ids))
  if (length(run_ids) == 0L) {
    return(data.frame(run_id = character(), decisions = integer(), stale = integer(),
                      frozen = integer(), assumed = integer(), stringsAsFactors = FALSE))
  }
  rows <- ledgr_diagnostic_summary_read(con, run_ids)
  rows[c("run_id", "decisions", "stale", "frozen", "assumed")]
}
