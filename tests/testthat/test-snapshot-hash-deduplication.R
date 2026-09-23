stage_n_with_namespace_binding <- function(name, value, fn) {
  namespace <- asNamespace("ledgr")
  original <- get(name, envir = namespace, inherits = FALSE)
  unlockBinding(name, namespace)
  assign(name, value, envir = namespace)
  lockBinding(name, namespace)
  on.exit({
    unlockBinding(name, namespace)
    assign(name, original, envir = namespace)
    lockBinding(name, namespace)
  }, add = TRUE)
  fn()
}

stage_n_current_hash <- function(con, snapshot_id, chunk_size) {
  stage_n_with_namespace_binding(
    "ledgr_snapshot_hash_format_distinct_ts_utc",
    ledgr:::ledgr_snapshot_hash_format_ts_utc,
    function() ledgr:::ledgr_snapshot_hash(
      con,
      snapshot_id,
      chunk_size = chunk_size
    )
  )
}

stage_n_chunk_tokens <- function(x, chunk_size, formatter) {
  if (!length(x)) return(character())
  starts <- seq.int(1L, length(x), by = chunk_size)
  unlist(lapply(starts, function(start) {
    stop <- min(length(x), start + chunk_size - 1L)
    formatter(x[start:stop])
  }), use.names = FALSE)
}

stage_n_hash_source <- function(fn) {
  paste(deparse(body(fn), width.cutoff = 500L), collapse = "\n")
}

# ledgr-test-profile: review
testthat::test_that("within-chunk timestamp remapping is byte-identical", {
  base <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC")
  chunk_sizes <- c(1L, 2L, 17L, 9999L, 10000L, 10001L, 50000L)

  for (chunk_size in chunk_sizes) {
    row_counts <- unique(pmax(0L, chunk_size + c(-1L, 0L, 1L)))
    for (row_count in row_counts) {
      repeated <- base + ((seq_len(row_count) - 1L) %% 23L) * 86400
      unique_values <- base + (seq_len(row_count) - 1L) * 86400
      for (axis in list(repeated, unique_values)) {
        current <- stage_n_chunk_tokens(
          axis,
          chunk_size,
          ledgr_stage_l_snapshot_hash_ts_oracle
        )
        candidate <- stage_n_chunk_tokens(
          axis,
          chunk_size,
          ledgr:::ledgr_snapshot_hash_format_distinct_ts_utc
        )
        testthat::expect_identical(candidate, current)
        testthat::expect_identical(
          charToRaw(paste0(candidate, collapse = "\n")),
          charToRaw(paste0(current, collapse = "\n"))
        )
      }
    }
  }

  testthat::expect_error(
    ledgr:::ledgr_snapshot_hash_format_distinct_ts_utc(
      "2020-01-01T16:00:00Z"
    ),
    class = "ledgr_snapshot_hash_invalid_timestamp"
  )
})
# ledgr-test-profile: review
testthat::test_that("formatter-count gate detects restored per-row work", {
  axis <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") +
    seq.int(0L, 1259L) * 86400
  registered <- rep(axis, times = 500L)
  observed <- new.env(parent = emptyenv())
  observed$inputs <- 0L
  original <- ledgr:::ledgr_snapshot_hash_format_ts_utc

  testthat::local_mocked_bindings(
    ledgr_snapshot_hash_format_ts_utc = function(x) {
      observed$inputs <- observed$inputs + length(x)
      original(x)
    },
    .package = "ledgr"
  )
  candidate <- stage_n_chunk_tokens(
    registered,
    10000L,
    ledgr:::ledgr_snapshot_hash_format_distinct_ts_utc
  )
  testthat::expect_length(candidate, 630000L)
  testthat::expect_identical(observed$inputs, 79380L)
  testthat::expect_lte(observed$inputs / length(registered), 0.20)

  observed$inputs <- 0L
  mutant <- stage_n_chunk_tokens(
    registered,
    10000L,
    ledgr:::ledgr_snapshot_hash_format_ts_utc
  )
  testthat::expect_identical(mutant, candidate)
  testthat::expect_identical(observed$inputs, length(registered))
  testthat::expect_gt(observed$inputs / length(registered), 0.20)
})

testthat::test_that("hash deduplication source is bounded and singular", {
  helper_source <- stage_n_hash_source(
    ledgr:::ledgr_snapshot_hash_format_distinct_ts_utc
  )
  hash_source <- stage_n_hash_source(ledgr:::ledgr_snapshot_hash)

  testthat::expect_match(helper_source, "unique\\(x\\)")
  testthat::expect_match(helper_source, "match\\(x, distinct\\)")
  testthat::expect_match(
    helper_source,
    "ledgr_snapshot_hash_format_ts_utc\\(distinct\\)"
  )
  testthat::expect_false(grepl("option|Sys.getenv|cache", helper_source))
  testthat::expect_equal(
    lengths(regmatches(
      hash_source,
      gregexpr(
        "ledgr_snapshot_hash_format_distinct_ts_utc\\(",
        hash_source
      )
    )),
    1L
  )
})

testthat::test_that("rule 1 hashes remain exact across registered chunk sizes", {
  bars <- ledgr_test_make_bars(
    c("AAA", "BBB", "CCC"),
    as.Date("2020-01-01") + 0:19
  )
  bars$volume[c(1L, 17L, 41L)] <- NA_real_
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  id <- snapshot$snapshot_id
  stored <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]

  for (chunk_size in c(1L, 2L, 17L, 9999L, 10000L, 10001L, 50000L)) {
    current <- stage_n_current_hash(con, id, chunk_size)
    candidate <- ledgr:::ledgr_snapshot_hash(con, id, chunk_size)
    testthat::expect_identical(candidate, current)
    testthat::expect_identical(candidate, stored)
  }
})

testthat::test_that("availability rule 2 hashes retain the unchanged base hash", {
  snapshot <- availability_runtime_fixture(days = 4L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  id <- snapshot$snapshot_id
  testthat::expect_identical(
    ledgr:::ledgr_snapshot_hash_rule_version(con, id),
    2L
  )

  current <- stage_n_current_hash(con, id, 2L)
  candidate <- ledgr:::ledgr_snapshot_hash(con, id, chunk_size = 2L)
  testthat::expect_identical(candidate, current)
  testthat::expect_identical(
    candidate,
    ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  )
})

# ledgr-test-profile: review
testthat::test_that("a snapshot sealed by the old formatter reopens unchanged", {
  path <- tempfile(fileext = ".duckdb")
  bars <- ledgr_test_make_bars(
    c("AAA", "BBB"),
    as.Date("2020-01-01") + 0:5
  )
  old <- stage_n_with_namespace_binding(
    "ledgr_snapshot_hash_format_distinct_ts_utc",
    ledgr:::ledgr_snapshot_hash_format_ts_utc,
    function() ledgr_snapshot_from_df(bars, db_path = path)
  )
  id <- old$snapshot_id
  stored <- ledgr_snapshot_info(old)$snapshot_hash[[1L]]
  ledgr_snapshot_close(old)

  reopened <- ledgr_snapshot_open(path, id, verify = TRUE)
  on.exit(ledgr_snapshot_close(reopened), add = TRUE)
  testthat::expect_identical(
    ledgr_snapshot_info(reopened)$snapshot_hash[[1L]],
    stored
  )
  testthat::expect_silent(ledgr_snapshot_validate(reopened))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("run, timestamp, price, and stored-hash guards still detect tampering", {
  path <- tempfile(fileext = ".duckdb")
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:1)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  id <- snapshot$snapshot_id
  stored <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )

  DBI::dbExecute(
    con,
    "UPDATE snapshot_bars SET close = close + 0.01 WHERE snapshot_id = ?",
    params = list(id)
  )
  testthat::expect_error(ledgr_run(exp), class = "LEDGR_SNAPSHOT_CORRUPTED")
  DBI::dbExecute(
    con,
    "UPDATE snapshot_bars SET close = close - 0.01 WHERE snapshot_id = ?",
    params = list(id)
  )
  testthat::expect_silent(ledgr_snapshot_validate(snapshot))

  DBI::dbExecute(
    con,
    paste(
      "UPDATE snapshot_bars SET ts_utc = ts_utc + INTERVAL 1 SECOND",
      "WHERE snapshot_id = ? AND ts_utc =",
      "(SELECT MIN(ts_utc) FROM snapshot_bars WHERE snapshot_id = ?)"
    ),
    params = list(id, id)
  )
  testthat::expect_error(
    ledgr_snapshot_validate(snapshot),
    class = "ledgr_invalid_snapshot"
  )
  DBI::dbExecute(
    con,
    paste(
      "UPDATE snapshot_bars SET ts_utc = ts_utc - INTERVAL 1 SECOND",
      "WHERE snapshot_id = ? AND ts_utc =",
      "(SELECT MIN(ts_utc) FROM snapshot_bars WHERE snapshot_id = ?)"
    ),
    params = list(id, id)
  )
  testthat::expect_silent(ledgr_snapshot_validate(snapshot))

  DBI::dbExecute(
    con,
    "UPDATE snapshots SET snapshot_hash = ? WHERE snapshot_id = ?",
    params = list(strrep("0", 64L), id)
  )
  testthat::expect_error(
    ledgr_snapshot_validate(snapshot),
    class = "ledgr_invalid_snapshot"
  )
  DBI::dbExecute(
    con,
    "UPDATE snapshots SET snapshot_hash = ? WHERE snapshot_id = ?",
    params = list(stored, id)
  )
})
