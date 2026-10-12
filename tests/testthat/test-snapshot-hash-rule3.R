rule3_test_instruments <- function(ids) {
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

rule3_test_bars <- function(ids, times) {
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

rule3_test_snapshot <- function(instruments, bars, callback,
                                fact_payload = NULL, threads = 1L) {
  path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, sprintf("SET threads = %d", as.integer(threads)))
  id <- ledgr_snapshot_create(con, "rule3-golden")
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

# ledgr-test-profile: review
testthat::test_that("[LTB-0249] production rule 3 matches the spike corpus", {
  roots <- c(
    dense = "35d334c6526fc7b619a84084865a31d09f9ba5bd092a68bce8fed0b9f3c511db",
    boundary = "65daa3f64cb3c7c266048647736176a5e2e2a0a27df4560c9283860579152ef5",
    unicode = "2b21728cf9bd8f77aea3cec9e3f2f2faaf5a8f4c9224223d6c407cfb300d3583",
    dst = "57e5d461f4e54d80fced636020010bf68a3e8c9972eb25f258c78b6a8db6e79b",
    numeric = "7a7bd5b5bccbc6e601150cb83622a7a6a5e666426a5db7b0679df72909c74f49",
    facts = "6df946b7736a40d73e299509f559b5b35cd25e616e77d43cefc24293889d42c0",
    mutation = "c50473fb29bc868b0c5ae3e62f3039cd6a4475f8469cbe50d64b0cb0fc672b2a"
  )
  times <- as.POSIXct("2020-01-01", tz = "UTC") + 0:2 * 86400
  instruments <- rule3_test_instruments(c("AAA", "BBB"))
  bars <- rule3_test_bars(c("AAA", "BBB"), times)

  baseline <- rule3_test_snapshot(
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

  insertion <- rule3_test_snapshot(
    instruments[c(2L, 1L), , drop = FALSE],
    bars[c(6L, 2L, 5L, 1L, 4L, 3L), , drop = FALSE],
    function(con, id, root) root,
    threads = 2L
  )
  testthat::expect_identical(insertion, roots[["dense"]])

  boundary <- rule3_test_snapshot(
    rule3_test_instruments("AAA"),
    rule3_test_bars(
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
  unicode <- rule3_test_snapshot(
    rule3_test_instruments(unicode_ids)[c(6L, 2L, 5L, 1L, 4L, 3L), ],
    rule3_test_bars(
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
    dst <- rule3_test_snapshot(
      rule3_test_instruments("AAA"),
      rule3_test_bars("AAA", instant),
      function(con, id, root) root
    )
    testthat::expect_identical(dst, roots[["dst"]])
  }

  numeric_instruments <- rule3_test_instruments("AAA")
  numeric_instruments$multiplier <- NA_real_
  numeric_instruments$tick_size <- -1e-10
  numeric_bars <- rule3_test_bars(
    "AAA",
    as.POSIXct("2020-01-01", tz = "UTC")
  )
  numeric_bars$open <- 1.234567895
  numeric_bars$high <- 9e14 + 0.25
  numeric_bars$low <- 1.000000005
  numeric_bars$close <- 2.500000005
  numeric_bars$volume <- NA_real_
  numeric <- rule3_test_snapshot(
    numeric_instruments,
    numeric_bars,
    function(con, id, root) root
  )
  testthat::expect_identical(numeric, roots[["numeric"]])

  fact_payload <- paste0(
    readLines(
      testthat::test_path("fixtures", "rule3_all_fact_payload.json"),
      warn = FALSE,
      encoding = "UTF-8"
    ),
    collapse = ""
  )
  facts <- rule3_test_snapshot(
    rule3_test_instruments("AAA"),
    rule3_test_bars("AAA", times[[1L]]),
    function(con, id, root) root,
    fact_payload = fact_payload
  )
  testthat::expect_identical(facts, roots[["facts"]])

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
  mutation <- rule3_test_snapshot(
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
