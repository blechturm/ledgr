# ledgr-test-file-profile: review
#
# LDG-2800. The registered compatibility matrix for the ingestion CSV reader.
#
# Every row records what the reader and the public file surface actually do
# for one input shape, by condition class and by a stable ledgr-owned message
# or prefix, so that a change to the reader has to declare what it moves
# instead of inheriting it. A row that changes must be listed with a reason in
# the cut 5 closeout; an undeclared change fails here.
#
# On message pinning, per re-review W9-O3: these are not complete condition
# strings. Fragments ledgr owns are pinned; for a failure that originates in
# DuckDB only the reader's own wrapper prefix is pinned, because the
# dependency's diagnostic tail can drift between versions and would produce
# false failures without telling us anything about ledgr.
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

# W9-F6. The rule above is stated generally, so it is pinned generally: every
# forced text name, in both CSV inputs. Each row was missing before the
# re-review, which pinned only the bars instrument_id instance.
test_that("the null-token rule holds for every forced text column", {
  # The bars side. ts_utc is forced text too, so its NA token reaches the
  # timestamp parser as the string "NA" and is rejected there.
  expect_error(
    csvc_seal(c(csvc_header, "AAA,NA,1,1,1,1,10", "AAA,NA,1,1,1,1,10")),
    "must be a UTC timestamp",
    fixed = TRUE,
    class = "ledgr_invalid_timestamp"
  )

  # The instruments side. Four columns store the literal token; the metadata
  # spelling rejects it, because "NA" is not valid JSON.
  stored <- function(col) {
    persisted <- if (identical(col, "metadata")) "meta_json" else col
    csvc_seal(
      csvc_bars,
      instruments = c(paste0("instrument_id,", col), "AAA,NA")
    )$instruments[[persisted]]
  }
  for (col in c("symbol", "currency", "asset_class", "meta_json")) {
    expect_identical(stored(col), "NA", info = col)
  }
  expect_error(
    stored("metadata"),
    "not valid JSON",
    fixed = TRUE,
    class = "ledgr_config_invalid_json"
  )
})

# from_df accepts `metadata` as an alternative spelling of `meta_json` and
# runs canonical_json() over it. Forcing the column to text, which the W9-F2
# patch did, changed what that accepts: an all-numeric value with leading
# zeros used to be inferred as a number and stored as one, and is now the
# string it was written as, which is not valid JSON and fails loudly. That is
# the intended direction, since the old path silently changed 0001 into 1,
# but it is a third behaviour change in this cut and is pinned here.
#
# meta_json is stored verbatim and has no JSON requirement on this path.
test_that("the metadata spelling requires valid JSON, the meta_json spelling does not", {
  meta <- function(col, value) {
    csvc_seal(
      csvc_bars,
      instruments = c(paste0("instrument_id,", col), paste0("AAA,", value))
    )$instruments$meta_json
  }

  expect_identical(meta("metadata", "42"), "42")
  expect_identical(meta("metadata", "\"{}\""), "{}")
  expect_error(
    meta("metadata", "0001"),
    "not valid JSON",
    fixed = TRUE,
    class = "ledgr_config_invalid_json"
  )

  expect_identical(meta("meta_json", "0001"), "0001")
  expect_identical(meta("meta_json", "abc"), "abc")
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

# W9-F5, maintainer decision 2026-09-22. A quarantined row's saved copy is a
# diagnostic, not part of the snapshot's identity. Both ingestion surfaces
# document that extra columns "are ignored and do not become part of the
# sealed snapshot or its hash", and hashing original_row_json made that false:
# a stray spreadsheet column moved the hash whenever a row was quarantined.
# quarantine_id carried the same content, being a digest of the whole row, and
# was the ORDER BY key as well. Both are now excluded from the hashed view and
# the rows are ordered on stable fields. The copy itself is unchanged.
test_that("a quarantined row's extra columns do not reach the snapshot hash", {
  sessions <- data.frame(
    session_date = as.Date("2024-01-01") + 0:4,
    status = c("closed", "open", "open", "open", "open"),
    session_open = c(NA_character_, rep("09:30:00", 4L)),
    session_close = c(NA_character_, rep("16:00:00", 4L)),
    knowledge_time = as.POSIXct("2023-12-01", tz = "UTC"),
    stringsAsFactors = FALSE
  )
  facts <- ledgr_facts(ledgr_facts_sessions(
    sessions, venue_id = "XNYS", timezone = "America/New_York"
  ))

  seal <- function(extra_header = NULL, extra_values = NULL) {
    header <- "instrument_id,ts_utc,open,high,low,close,volume"
    rows <- c("AAA,2024-01-02,10,11,9,10,100",
              "AAA,2024-01-03,11,8,10,11,100",   # high below open: quarantined
              "AAA,2024-01-04,12,13,11,12,100")
    if (!is.null(extra_header)) {
      header <- paste0(header, ",", extra_header)
      rows <- paste0(rows, ",", extra_values)
    }
    snap <- ledgr_snapshot_from_csv(
      csvc_file(c(header, rows)), facts = facts, invalid_observations = "quarantine"
    )
    on.exit(ledgr_snapshot_close(snap), add = TRUE)
    con <- ledgr_db_init(snap$db_path)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    list(
      hash = ledgr_snapshot_info(con, snap$snapshot_id)$snapshot_hash,
      saved = DBI::dbGetQuery(
        con,
        "SELECT original_row_json FROM snapshot_observation_quarantine WHERE snapshot_id = ?",
        params = list(snap$snapshot_id)
      )$original_row_json
    )
  }

  baseline <- seal()
  expect_equal(length(baseline$saved), 1L)

  for (case in list(
    list(h = "extra", v = "1"),
    list(h = "extra", v = "0001"),
    list(h = "extra", v = "NA"),
    list(h = "note", v = "anything")
  )) {
    got <- seal(case$h, case$v)
    expect_identical(got$hash, baseline$hash, info = paste(case$h, case$v))
    # The copy still carries the column; only the hash ignores it.
    expect_true(grepl(case$h, got$saved, fixed = TRUE), info = case$h)
  }

  # The quarantine itself still changes the hash, so this has not simply
  # stopped hashing the availability tables.
  clean <- ledgr_snapshot_from_csv(
    csvc_file(c("instrument_id,ts_utc,open,high,low,close,volume",
                "AAA,2024-01-02,10,11,9,10,100",
                "AAA,2024-01-03,11,12,10,11,100",
                "AAA,2024-01-04,12,13,11,12,100")),
    facts = facts, invalid_observations = "quarantine"
  )
  on.exit(ledgr_snapshot_close(clean), add = TRUE)
  con <- ledgr_db_init(clean$db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  expect_false(identical(
    ledgr_snapshot_info(con, clean$snapshot_id)$snapshot_hash, baseline$hash
  ))
})
