# ledgr-test-file-profile: fast

ledgr_test_old_candidate_feature_rows <- function(candidate_features,
                                                  candidate_rows) {
  lapply(seq_along(candidate_rows), function(i) {
    candidate_row <- candidate_rows[[i]]
    if ("candidate_row" %in% names(candidate_features)) {
      candidate_features[
        candidate_features$candidate_row == candidate_row,
        ,
        drop = FALSE
      ]
    } else {
      candidate_features[i, , drop = FALSE]
    }
  })
}

ledgr_test_old_equity_stats <- function(equity, run_ids) {
  stats <- lapply(run_ids, function(id) {
    rows <- equity[as.character(equity$run_id) == id, , drop = FALSE]
    if (nrow(rows) == 0L) {
      return(data.frame(
        run_id = id,
        first_equity = NA_real_,
        final_equity = NA_real_,
        max_drawdown = NA_real_
      ))
    }
    eq <- as.numeric(rows$equity)
    running_max <- cummax(eq)
    drawdown <- ifelse(
      is.na(running_max) | running_max == 0,
      NA_real_,
      eq / running_max - 1
    )
    data.frame(
      run_id = id,
      first_equity = eq[[1L]],
      final_equity = eq[[length(eq)]],
      max_drawdown = suppressWarnings(min(drawdown, na.rm = TRUE))
    )
  })
  stats <- do.call(rbind, stats)
  stats$max_drawdown[is.infinite(stats$max_drawdown)] <- NA_real_
  stats
}

ledgr_test_body_occurrences <- function(fun, token) {
  text <- paste(deparse(body(fun)), collapse = "\n")
  hits <- gregexpr(token, text, fixed = TRUE)[[1L]]
  if (hits[[1L]] == -1L) 0L else length(hits)
}

testthat::test_that("[LTB-0484] candidate features are grouped once with exact rows", {
  for (n_candidates in c(1L, 7L, 31L)) {
    candidate_rows <- rep(seq_len(n_candidates), each = 2L)
    candidate_features <- data.frame(
      candidate_row = rev(candidate_rows),
      feature_id = paste0("feature-", seq_along(candidate_rows)),
      stringsAsFactors = FALSE
    )
    requested <- c(seq_len(n_candidates), 1L)
    testthat::expect_identical(
      ledgr:::ledgr_sweep_storage_candidate_feature_rows(
        candidate_features,
        requested
      ),
      ledgr_test_old_candidate_feature_rows(candidate_features, requested),
      info = paste("candidate scale", n_candidates)
    )
  }

  positional <- data.frame(value = c("first", "second"))
  testthat::expect_identical(
    ledgr:::ledgr_sweep_storage_candidate_feature_rows(positional, c(2L, 1L)),
    ledgr_test_old_candidate_feature_rows(positional, c(2L, 1L))
  )
  empty <- data.frame(candidate_row = integer(), value = character())
  testthat::expect_identical(
    ledgr:::ledgr_sweep_storage_candidate_feature_rows(empty, integer()),
    list()
  )
  testthat::expect_identical(
    ledgr_test_body_occurrences(
      ledgr:::ledgr_sweep_storage_candidate_rows,
      "ledgr_sweep_storage_candidate_feature_rows"
    ),
    1L
  )
})

testthat::test_that("[LTB-0485] run equity is grouped once with exact statistics", {
  for (n_runs in c(1L, 7L, 31L)) {
    run_ids <- paste0("run-", seq_len(n_runs))
    equity <- data.frame(
      run_id = rep(run_ids, each = 4L),
      ts_utc = rep(seq_len(4L), times = n_runs),
      equity = rep(c(100, 110, NA, 90), times = n_runs),
      stringsAsFactors = FALSE
    )
    requested <- c(run_ids, "empty-run")
    testthat::expect_identical(
      ledgr:::ledgr_run_store_equity_stats(equity, requested),
      ledgr_test_old_equity_stats(equity, requested),
      info = paste("equity scale", n_runs)
    )
  }
  testthat::expect_identical(
    ledgr_test_body_occurrences(
      ledgr:::ledgr_run_store_fetch,
      "ledgr_run_store_equity_stats"
    ),
    1L
  )
})

testthat::test_that("[LTB-0486] latest bars use one query and restore request order", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  instruments <- paste0("I", seq_len(31L))
  at <- as.POSIXct("2020-03-29 01:30:00", tz = "UTC")
  bars <- data.frame(
    snapshot_id = "snapshot",
    instrument_id = instruments,
    ts_utc = at,
    open = seq_along(instruments),
    high = seq_along(instruments) + 1,
    low = seq_along(instruments) - 1,
    close = seq_along(instruments) + 0.5,
    volume = seq_along(instruments) * 10,
    stringsAsFactors = FALSE
  )
  DBI::dbWriteTable(con, "snapshot_bars", bars)

  original_query <- ledgr:::ledgr_fetch_latest_bars_query
  query_calls <- 0L
  testthat::local_mocked_bindings(
    ledgr_fetch_latest_bars_query = function(...) {
      query_calls <<- query_calls + 1L
      original_query(...)
    },
    .package = "ledgr"
  )
  for (requested in list(
    "I1",
    instruments[7:1],
    rev(instruments),
    c("I3", "I1", "I3")
  )) {
    before <- query_calls
    out <- ledgr:::ledgr_fetch_latest_bars(
      con,
      "snapshot",
      requested,
      at
    )
    testthat::expect_identical(query_calls - before, 1L)
    testthat::expect_identical(out$instrument_id, requested)
    testthat::expect_identical(
      out$close,
      bars$close[match(requested, bars$instrument_id)]
    )
  }
  testthat::expect_null(
    ledgr:::ledgr_fetch_latest_bars(con, "snapshot", character(), at)
  )
  testthat::expect_error(
    ledgr:::ledgr_fetch_latest_bars(
      con,
      "snapshot",
      c("missing-first", "missing-second"),
      at
    ),
    "No bars available for instrument 'missing-first' at ts_utc.",
    fixed = TRUE,
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("[LTB-0487] composition timestamps use one vector formatter", {
  for (n in c(1L, 7L, 31L)) {
    value <- as.POSIXct("1969-10-26 01:30:00", tz = "UTC") + seq_len(n) * 3600
    expected <- vapply(
      seq_along(value),
      function(i) ledgr:::ledgr_normalize_ts_utc(value[[i]]),
      character(1)
    )
    testthat::expect_identical(
      ledgr:::ledgr_corporate_action_time_tokens(value),
      expected,
      info = paste("timestamp scale", n)
    )
  }
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_time_tokens(as.POSIXct(character(), tz = "UTC")),
    character()
  )
  testthat::expect_error(
    ledgr:::ledgr_corporate_action_time_tokens(as.POSIXct(NA, tz = "UTC")),
    "`ts_utc` could not be converted to UTC POSIXct.",
    fixed = TRUE,
    class = "ledgr_invalid_pulse_context"
  )
  testthat::expect_identical(
    ledgr_test_body_occurrences(
      ledgr:::ledgr_corporate_action_composition_report,
      "ledgr_corporate_action_time_tokens"
    ),
    1L
  )
})
