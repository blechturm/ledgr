# ledgr-test-file-profile: review
#
# LDG-2800. The registered compatibility matrix for the ingestion CSV reader.
#
# Every row records what the reader and the public file surface actually do
# for one input shape, by exact condition class and message, so that a change
# to the reader has to declare what it moves instead of inheriting it. A row
# that changes must be listed with a reason in the cut 5 closeout; an
# undeclared change fails here.
#
# Strengthened after close review W9-F1, W9-F2, W9-F3 and W9-O1, which found
# the first version asserted classes loosely, covered only the bars CSV, and
# had no null-token or sniff-boundary row.

csvc_file <- function(lines, bom = FALSE) {
  path <- tempfile(fileext = ".csv")
  if (isTRUE(bom) && length(lines) > 0L) {
    lines[[1]] <- paste0("﻿", lines[[1]])
  }
  writeLines(lines, path, useBytes = TRUE)
  path
}

csvc_header <- "instrument_id,ts_utc,open,high,low,close,volume"

csvc_bars <- c(
  csvc_header,
  "AAA,2020-01-01T00:00:00Z,1,1,1,1,10",
  "AAA,2020-01-02T00:00:00Z,1,1,1,1,10"
)

csvc_read <- function(lines, bom = FALSE, path = NULL) {
  p <- if (is.null(path)) csvc_file(lines, bom = bom) else path
  ledgr:::ledgr_read_csv_strict(p, encoding = "UTF-8", strict = TRUE)
}

csvc_classes <- function(d) {
  unname(vapply(d, function(x) class(x)[[1L]], character(1)))
}

csvc_seal <- function(lines, instruments = NULL, bom = FALSE) {
  bars_path <- csvc_file(lines, bom = bom)
  inst_path <- if (is.null(instruments)) NULL else csvc_file(instruments)
  snap <- ledgr_snapshot_from_csv(bars_path, instruments_csv_path = inst_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  con <- ledgr_db_init(snap$db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  list(
    hash = ledgr_snapshot_info(con, snap$snapshot_id)$snapshot_hash,
    bars = DBI::dbGetQuery(
      con,
      "SELECT DISTINCT instrument_id FROM snapshot_bars WHERE snapshot_id = ? ORDER BY 1",
      params = list(snap$snapshot_id)
    ),
    instruments = DBI::dbGetQuery(
      con,
      "SELECT * FROM snapshot_instruments WHERE snapshot_id = ? ORDER BY instrument_id",
      params = list(snap$snapshot_id)
    ),
    start = snap$metadata$start_date,
    n_bars = snap$metadata$n_bars
  )
}

# -------------------------------------------------------------- reader shape

test_that("the reader returns the recorded names and classes", {
  chr <- "character"
  num <- "numeric"

  full <- csvc_read(c(csvc_header, "AAA,2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5,10.5"))
  expect_identical(
    names(full),
    c("instrument_id", "ts_utc", "open", "high", "low", "close", "volume")
  )
  expect_identical(csvc_classes(full), c(chr, chr, num, num, num, num, num))

  no_volume <- csvc_read(c(
    "instrument_id,ts_utc,open,high,low,close", "AAA,2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5"
  ))
  expect_identical(
    names(no_volume),
    c("instrument_id", "ts_utc", "open", "high", "low", "close")
  )
  expect_identical(csvc_classes(no_volume), c(chr, chr, num, num, num, num))

  extra <- csvc_read(c(
    paste0(csvc_header, ",junk"), "AAA,2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5,10.5,hello"
  ))
  expect_identical(names(extra)[[8L]], "junk")
  expect_identical(csvc_classes(extra)[[8L]], chr)

  quoted <- csvc_read(c(csvc_header, "\"A,B\",2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5,10.5"))
  expect_identical(quoted$instrument_id, "A,B")

  bom <- csvc_read(c(csvc_header, "AAA,2020-01-01T00:00:00Z,1.5,2.5,0.5,1.5,10.5"), bom = TRUE)
  expect_identical(names(bom)[[1L]], "instrument_id")
  expect_identical(csvc_classes(bom), c(chr, chr, num, num, num, num, num))

  # Whole-number prices are double, not integer. Before LDG-2801 the reader
  # inferred integer here and LDG-2788 coerced it afterwards; the reader now
  # provides the contract directly.
  whole <- csvc_read(c(csvc_header, "AAA,2020-01-01T00:00:00Z,100,100,100,100,10"))
  expect_identical(csvc_classes(whole)[3:7], rep(num, 5L))

  # A malformed numeric inside the type sample leaves the column text; ledgr
  # rejects it later. See the sniff-boundary block for a value past the sample.
  malformed <- csvc_read(c(csvc_header, "AAA,2020-01-01T00:00:00Z,abc,2.5,0.5,1.5,10.5"))
  expect_identical(csvc_classes(malformed)[[3L]], chr)

  # Every persisted instrument text column reads as text; the two numeric ones
  # stay inferred.
  inst <- csvc_read(c(
    "instrument_id,symbol,currency,asset_class,multiplier,tick_size,meta_json",
    "AAA,0001,0002,0003,2,0.05,0004"
  ))
  expect_identical(csvc_classes(inst), c(chr, chr, chr, chr, num, num, chr))
})

test_that("the reader rejects a bad path and a non-UTF-8 encoding", {
  expect_error(
    csvc_read(NULL, path = file.path(tempdir(), "no-such-ledgr-file.csv")),
    "CSV file not found",
    class = "ledgr_invalid_args"
  )
  expect_error(
    ledgr:::ledgr_read_csv_strict(csvc_file(csvc_bars), encoding = "latin1"),
    "ledgr reads CSV files as UTF-8",
    class = "ledgr_invalid_args"
  )
})

# ------------------------------------------------------ public surface: pass

test_that("every accepted timestamp form seals to the same start date", {
  forms <- list(
    iso_z = c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"),
    date_only = c("2020-01-01", "2020-01-02"),
    no_z = c("2020-01-01T00:00:00", "2020-01-02T00:00:00"),
    mixed = c("2020-01-01", "2020-01-02T00:00:00Z")
  )
  for (nm in names(forms)) {
    out <- csvc_seal(c(
      csvc_header,
      sprintf("AAA,%s,1,1,1,1,10", forms[[nm]][[1L]]),
      sprintf("AAA,%s,1,1,1,1,10", forms[[nm]][[2L]])
    ))
    expect_identical(out$start, "2020-01-01T00:00:00Z", info = nm)
    expect_equal(out$n_bars, 2L, info = nm)
  }
})

# W9-F2. Before LDG-2801 these columns were inferred, so an all-numeric value
# lost its leading zeros and the snapshot hash was computed over the wrong
# string. The first version of this matrix had no instruments-CSV row at all,
# which is why the cut 5 closeout wrongly claimed only instrument ids moved.
test_that("every persisted instrument text column keeps an all-numeric value verbatim", {
  out <- csvc_seal(
    csvc_bars,
    instruments = c(
      "instrument_id,symbol,currency,asset_class,multiplier,tick_size,meta_json",
      "AAA,0001,0002,0003,2,0.05,0004"
    )
  )
  expect_identical(out$instruments$symbol, "0001")
  expect_identical(out$instruments$currency, "0002")
  expect_identical(out$instruments$asset_class, "0003")
  expect_identical(out$instruments$meta_json, "0004")
  expect_equal(out$instruments$multiplier, 2)
  expect_equal(out$instruments$tick_size, 0.05)
})

# The bars-side half of the same defect, and the row LDG-2801 was cut for.
test_that("leading-zero instrument ids survive to the sealed snapshot", {
  out <- csvc_seal(c(
    csvc_header,
    "0001,2020-01-01T00:00:00Z,1,1,1,1,10",
    "0002,2020-01-01T00:00:00Z,2,2,2,2,10"
  ))
  expect_identical(out$bars$instrument_id, c("0001", "0002"))
  expect_identical(out$instruments$instrument_id, c("0001", "0002"))
})

# W9-F3. The declared null-token rule: an empty field is missing, a literal
# NA is the two-character string. utils::read.csv() read "NA" as missing, so
# this widens the accepted domain, deliberately, because NA is a real ticker
# and CSV says missing with an empty field.
test_that("an empty field is missing and a literal NA is text", {
  expect_error(
    csvc_seal(c(
      csvc_header,
      ",2020-01-01T00:00:00Z,1,1,1,1,10",
      ",2020-01-02T00:00:00Z,1,1,1,1,10"
    )),
    "must be non-empty strings",
    fixed = TRUE,
    class = "ledgr_invalid_args"
  )

  literal_na <- csvc_seal(c(
    csvc_header,
    "NA,2020-01-01T00:00:00Z,1,1,1,1,10",
    "NA,2020-01-02T00:00:00Z,1,1,1,1,10"
  ))
  expect_identical(literal_na$bars$instrument_id, "NA")

  # A numeric column is inferred, so its NA token is still missing and the
  # finite-value check rejects it.
  expect_error(
    csvc_seal(c(
      csvc_header,
      "AAA,2020-01-01T00:00:00Z,NA,1,1,1,10",
      "AAA,2020-01-02T00:00:00Z,1,1,1,1,10"
    )),
    "must be finite numeric values",
    fixed = TRUE,
    class = "ledgr_invalid_args"
  )
})

# ------------------------------------------------------ public surface: fail

test_that("each malformed file fails with its recorded class and message", {
  cases <- list(
    list(nm = "missing_required_column",
         lines = c("instrument_id,ts_utc,open,high,low", "AAA,2020-01-01T00:00:00Z,1,1,1"),
         cls = "ledgr_invalid_args", msg = "bars_df missing required column"),
    list(nm = "no_instrument_id_column",
         lines = c("ts_utc,open,high,low,close", "2020-01-01T00:00:00Z,1,1,1,1"),
         cls = "ledgr_invalid_args", msg = "bars_df missing required column"),
    list(nm = "no_ts_utc_column",
         lines = c("instrument_id,open,high,low,close", "AAA,1,1,1,1"),
         cls = "ledgr_invalid_args", msg = "bars_df missing required column"),
    list(nm = "empty_file", lines = character(0),
         cls = "ledgr_invalid_args", msg = "bars_df missing required column"),
    list(nm = "ragged_row", lines = c(csvc_header, "AAA,2020-01-01T00:00:00Z,1"),
         cls = "ledgr_invalid_args", msg = "bars_df missing required column"),
    list(nm = "malformed_numeric_in_sample",
         lines = c(csvc_header, "AAA,2020-01-01T00:00:00Z,abc,1,1,1,10"),
         cls = "ledgr_invalid_args", msg = "OHLC columns must be finite numeric values"),
    list(nm = "ohlc_violation",
         lines = c(csvc_header, "AAA,2020-01-01T00:00:00Z,10,5,9,10,1"),
         cls = "ledgr_invalid_args", msg = "OHLC violation"),
    list(nm = "duplicate_key",
         lines = c(csvc_header, "AAA,2020-01-01T00:00:00Z,1,1,1,1,10",
                   "AAA,2020-01-01T00:00:00Z,1,1,1,1,10"),
         cls = "ledgr_invalid_args", msg = "duplicate (instrument_id, ts_utc) rows"),
    list(nm = "unparseable_timestamp",
         lines = c(csvc_header, "AAA,not-a-time,1,1,1,1,10"),
         cls = "ledgr_invalid_timestamp", msg = "must be a UTC timestamp"),
    list(nm = "header_only", lines = csvc_header,
         cls = "LEDGR_SNAPSHOT_EMPTY", msg = "at least one bar")
  )
  for (case in cases) {
    expect_error(
      suppressWarnings(csvc_seal(case$lines)),
      case$msg,
      fixed = TRUE,
      class = case$cls,
      info = case$nm
    )
  }
})

# W9-O1. DuckDB infers column types from a sample of roughly 20,480 rows. A
# malformed numeric inside the sample makes the column text and ledgr's own
# finite-value check rejects it, which the block above pins. Past the sample
# DuckDB raises a conversion error instead, which the reader re-raises with
# the same condition class but a different message. Both reject. The two
# stages are recorded so the difference is a declared consequence of the
# reader rather than an undetected change in error timing.
test_that("a malformed numeric past the type sample still fails, at the reader", {
  n <- 40000L
  stamps <- format(
    as.POSIXct("2000-01-01", tz = "UTC") + (seq_len(n) - 1L) * 86400,
    "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  opens <- rep("1", n)
  opens[[35000L]] <- "abc"

  expect_error(
    csvc_seal(c(csvc_header, paste0("AAA,", stamps, ",", opens, ",1,1,1,10"))),
    "Failed to read CSV",
    fixed = TRUE,
    class = "ledgr_invalid_args"
  )
})
