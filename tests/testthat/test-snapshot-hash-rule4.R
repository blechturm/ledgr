rule4_test_instruments <- function(ids) {
  data.frame(
    instrument_id = ids,
    symbol = ids,
    currency = rep("USD", length(ids)),
    asset_class = rep("equity", length(ids)),
    multiplier = rep(1, length(ids)),
    tick_size = rep(0.01, length(ids)),
    meta_json = rep("{}", length(ids)),
    stringsAsFactors = FALSE
  )
}

rule4_test_bars <- function(ids, times) {
  out <- expand.grid(
    instrument_id = ids,
    ts_utc = times,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  out <- out[do.call(order, c(
    unname(as.list(out[c("instrument_id", "ts_utc")])),
    list(method = "radix")
  )), , drop = FALSE]
  rownames(out) <- NULL
  value <- seq_len(nrow(out))
  out$open <- 100 + value / 100
  out$high <- out$open + 1
  out$low <- out$open - 1
  out$close <- out$open + 0.25
  out$volume <- 1000 + value
  out
}

rule4_test_snapshot <- function(instruments, bars, callback,
                                fact_payload = NULL, threads = 1L) {
  path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, sprintf("SET threads = %d", as.integer(threads)))
  id <- ledgr_snapshot_create(con, "rule4-golden")
  DBI::dbAppendTable(
    con,
    "snapshot_instruments",
    cbind(snapshot_id = id, instruments, stringsAsFactors = FALSE)
  )
  DBI::dbAppendTable(
    con,
    "snapshot_bars",
    cbind(snapshot_id = id, bars, stringsAsFactors = FALSE)
  )
  if (is.null(fact_payload)) {
    root <- ledgr_snapshot_seal(con, id)
  } else {
    root <- testthat::with_mocked_bindings(
      ledgr_snapshot_availability_hash_payload = function(con, snapshot_id,
                                                          ...) {
        structure(fact_payload, ledgr_canonical_json = TRUE)
      },
      ledgr_snapshot_seal(con, id),
      .package = "ledgr"
    )
  }
  callback(con, id, root)
}

rule4_civil_snapshot_root <- function(timezone, venue_id, open, close) {
  date <- as.Date("2020-01-02")
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = date,
      status = "open",
      session_open = open,
      session_close = close
    ),
    venue_id = venue_id,
    timezone = timezone,
    knowledge = "assume_effective"
  )
  membership <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = "AAA",
      effective_from = date,
      knowledge_time = date,
      member = TRUE,
      source = "fixture"
    ),
    universe_id = "u"
  )
  facts <- ledgr_facts(sessions, membership)
  row <- ledgr:::ledgr_facts_family(facts, "membership")[[1L]]$rows
  testthat::expect_true(any(row$civil_time_json != "{}"))
  snapshot <- ledgr_snapshot_from_df(
    data.frame(
      instrument_id = "AAA",
      ts_utc = sessions$rows$session_close,
      open = 100,
      high = 101,
      low = 99,
      close = 100,
      volume = 1000
    ),
    facts = facts,
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0249] production rule 4 matches the registered corpus", {
  roots <- c(
    dense = "d451fb533a8ac3f688624e6e28cb653efe16f416a5e66331fcd8f3d0d9dde488",
    boundary = "912a40fce4cf9612ea0174ae5a51e9e849004b9abca62452ab69166cfd41611c",
    unicode = "23a8f85b8b93e6eecb0f3814e8294c9c914cbbea4d1e86707c25d5070677153f",
    dst = "13604d26dfde93d715cdbbdcdb46e667d1cbd71748efaa1961367fdcb2ae185b",
    numeric = "2bdd5f74f6969e1b620119a02ceea9424c496978cff967eff2e1932b1e53d06e",
    facts = "def99ec0c09f0b733685c9f5ae714ff5317c99b23a8f7a69e39071d3b6c4a9e8",
    civil_sydney = "3f26b87b1d2759c27127b4cadfa0593344493447cb2573e6b037ad5d6fcc193b",
    civil_new_york = "47ec2b5d06895af6dd38f2cc12149e12733480afc77a8033c6695c582d7086c7",
    mutation = "ed03f6ea6d2c794df0bba6c902eaeaac52c95d6fbe8bc1797033156220954ed1"
  )
  times <- as.POSIXct("2020-01-01", tz = "UTC") + 0:2 * 86400
  instruments <- rule4_test_instruments(c("AAA", "BBB"))
  bars <- rule4_test_bars(c("AAA", "BBB"), times)

  baseline <- rule4_test_snapshot(
    instruments,
    bars,
    function(con, id, root) {
      testthat::expect_identical(root, roots[["dense"]])
      testthat::expect_identical(
        ledgr:::ledgr_snapshot_hash(con, id, chunk_size = 1L),
        roots[["dense"]]
      )
      root
    }
  )
  testthat::expect_identical(baseline, roots[["dense"]])

  insertion <- rule4_test_snapshot(
    instruments[c(2L, 1L), , drop = FALSE],
    bars[c(6L, 2L, 5L, 1L, 4L, 3L), , drop = FALSE],
    function(con, id, root) root,
    threads = 2L
  )
  testthat::expect_identical(insertion, roots[["dense"]])

  boundary <- rule4_test_snapshot(
    rule4_test_instruments("AAA"),
    rule4_test_bars(
      "AAA",
      as.POSIXct("2000-01-01", tz = "UTC") + 0:10000 * 60
    ),
    function(con, id, root) {
      testthat::expect_identical(root, roots[["boundary"]])
      testthat::expect_identical(
        ledgr:::ledgr_snapshot_hash(con, id, chunk_size = 4096L),
        roots[["boundary"]]
      )
      testthat::expect_identical(
        ledgr:::ledgr_snapshot_hash(con, id, chunk_size = 7777L),
        roots[["boundary"]]
      )
      root
    },
    threads = 2L
  )
  testthat::expect_identical(boundary, roots[["boundary"]])

  unicode_ids <- c("A", "B", "a", "b", "z", "\u00e9")
  unicode <- rule4_test_snapshot(
    rule4_test_instruments(unicode_ids)[c(6L, 2L, 5L, 1L, 4L, 3L), ],
    rule4_test_bars(
      unicode_ids,
      as.POSIXct("2020-01-01", tz = "UTC")
    )[c(3L, 6L, 1L, 5L, 2L, 4L), ],
    function(con, id, root) root,
    threads = 2L
  )
  testthat::expect_identical(unicode, roots[["unicode"]])

  dst_utc <- as.POSIXct("2020-11-01 05:30:00", tz = "UTC")
  dst_offset <- as.POSIXct(
    "2020-11-01 01:30:00 -0400",
    format = "%Y-%m-%d %H:%M:%S %z",
    tz = "UTC"
  )
  for (instant in list(dst_utc, dst_offset)) {
    dst <- rule4_test_snapshot(
      rule4_test_instruments("AAA"),
      rule4_test_bars("AAA", instant),
      function(con, id, root) root
    )
    testthat::expect_identical(dst, roots[["dst"]])
  }

  numeric_instruments <- rule4_test_instruments("AAA")
  numeric_instruments$multiplier <- NA_real_
  numeric_instruments$tick_size <- -1e-10
  numeric_bars <- rule4_test_bars(
    "AAA",
    as.POSIXct("2020-01-01", tz = "UTC")
  )
  numeric_bars$open <- 1.234567895
  numeric_bars$high <- 9e14 + 0.25
  numeric_bars$low <- 1.000000005
  numeric_bars$close <- 2.500000005
  numeric_bars$volume <- NA_real_
  numeric <- rule4_test_snapshot(
    numeric_instruments,
    numeric_bars,
    function(con, id, root) root
  )
  testthat::expect_identical(numeric, roots[["numeric"]])

  fact_payload <- paste0(
    readLines(
      testthat::test_path("fixtures", "rule4_all_fact_payload.json"),
      warn = FALSE,
      encoding = "UTF-8"
    ),
    collapse = ""
  )
  facts <- rule4_test_snapshot(
    rule4_test_instruments("AAA"),
    rule4_test_bars("AAA", times[[1L]]),
    function(con, id, root) root,
    fact_payload = fact_payload
  )
  testthat::expect_identical(facts, roots[["facts"]])

  testthat::expect_identical(
    rule4_civil_snapshot_root(
      "Australia/Sydney", "XASX", "10:00:00", "16:00:00"
    ),
    roots[["civil_sydney"]]
  )
  testthat::expect_identical(
    rule4_civil_snapshot_root(
      "America/New_York", "XNYS", "09:30:00", "16:00:00"
    ),
    roots[["civil_new_york"]]
  )

  fact_snapshot <- availability_runtime_fixture(days = 3L)
  on.exit(ledgr_snapshot_close(fact_snapshot), add = TRUE)
  fact_con <- ledgr:::get_connection(fact_snapshot)
  DBI::dbExecute(
    fact_con,
    paste(
      "UPDATE snapshot_sessions SET status = 'closed'",
      "WHERE snapshot_id = ? AND session_date = DATE '2020-01-02'"
    ),
    params = list(fact_snapshot$snapshot_id)
  )
  testthat::expect_error(
    ledgr_snapshot_validate(fact_snapshot),
    class = "ledgr_invalid_snapshot"
  )

  civil_sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = as.Date("2020-01-02"),
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00"
    ),
    venue_id = "XNYS",
    timezone = "America/New_York",
    knowledge = "assume_effective"
  )
  civil_membership <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = "AAA",
      effective_from = as.Date("2020-01-02"),
      knowledge_time = as.Date("2020-01-02"),
      member = TRUE,
      source = "fixture"
    ),
    universe_id = "u"
  )
  civil_snapshot <- ledgr_snapshot_from_df(
    data.frame(
      instrument_id = "AAA",
      ts_utc = civil_sessions$rows$session_close,
      open = 100,
      high = 101,
      low = 99,
      close = 100,
      volume = 1000
    ),
    facts = ledgr_facts(civil_sessions, civil_membership),
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(civil_snapshot), add = TRUE)
  civil_con <- ledgr:::get_connection(civil_snapshot)
  DBI::dbExecute(
    civil_con,
    paste(
      "UPDATE snapshot_membership SET civil_time_json = '{}'",
      "WHERE snapshot_id = ?"
    ),
    params = list(civil_snapshot$snapshot_id)
  )
  testthat::expect_error(
    ledgr_snapshot_validate(civil_snapshot),
    class = "ledgr_invalid_snapshot"
  )

  original <- list(
    instrument_id = "AAA",
    ts_utc = "2020-01-02T21:00:00Z",
    open = 100,
    high = 102,
    low = 99,
    close = 101,
    volume = 1000
  )
  plain <- as.character(ledgr:::canonical_json(original))
  original$ignored_vendor_column <- "ignored"
  extra <- as.character(ledgr:::canonical_json(original))
  testthat::expect_identical(
    ledgr:::ledgr_snapshot_quarantine_parse_hashed_row(plain),
    ledgr:::ledgr_snapshot_quarantine_parse_hashed_row(extra)
  )

  mutated <- bars
  mutated$close[[1L]] <- mutated$close[[1L]] + 0.01
  mutation <- rule4_test_snapshot(
    instruments,
    mutated,
    function(con, id, root) root
  )
  testthat::expect_identical(mutation, roots[["mutation"]])
  testthat::expect_false(identical(mutation, baseline))

  guarded <- ledgr_snapshot_from_df(
    data.frame(
      instrument_id = "AAA",
      ts_utc = as.POSIXct("2020-01-01", tz = "UTC"),
      open = 100,
      high = 102,
      low = 99,
      close = 101,
      volume = 1000
    )
  )
  on.exit(ledgr_snapshot_close(guarded), add = TRUE)
  DBI::dbExecute(
    ledgr:::get_connection(guarded),
    "UPDATE snapshot_bars SET close = close + 0.01 WHERE snapshot_id = ?",
    params = list(guarded$snapshot_id)
  )
  testthat::expect_error(
    ledgr_snapshot_validate(guarded),
    class = "ledgr_invalid_snapshot"
  )

  hostile <- instruments[c(2L, 1L), , drop = FALSE]
  testthat::expect_error(
    ledgr:::ledgr_snapshot_hash_block(
      hostile,
      1L,
      0L,
      c(
        instrument_id = "text", symbol = "text", currency = "text",
        asset_class = "text", multiplier = "number",
        tick_size = "number", meta_json = "text"
      ),
      "instrument_id"
    ),
    class = "ledgr_snapshot_hash_order_invalid"
  )
})
