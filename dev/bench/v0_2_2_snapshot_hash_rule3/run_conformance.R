args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: run_conformance.R <output-directory>", call. = FALSE)
}

.libPaths(c(
  "C:/Users/maxth/AppData/Local/R/win-library/4.6",
  .libPaths()
))

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]),
  winslash = "/"
)
repo <- normalizePath(file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/"
)
output_dir <- normalizePath(args[[1L]], winslash = "/", mustWork = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

pkgload::load_all(repo, quiet = TRUE)
spike_path <- file.path(
  repo,
  "dev", "spikes", "snapshot_hash_rule_3_conformance", "spike_runner.R"
)
oracle <- new.env(parent = globalenv())
candidate <- new.env(parent = globalenv())
sys.source(spike_path, envir = oracle)
sys.source(spike_path, envir = candidate)

production_section <- function(blocks, tag, fields, keys) {
  previous <- NULL
  digests <- raw(32L * length(blocks))
  rows <- 0
  for (index in seq_along(blocks)) {
    encoded <- ledgr:::ledgr_snapshot_hash_block(
      blocks[[index]],
      tag,
      index - 1L,
      fields,
      keys,
      previous
    )
    first <- (index - 1L) * 32L + 1L
    digests[first:(first + 31L)] <- encoded$digest
    previous <- encoded$last
    rows <- rows + nrow(blocks[[index]])
  }
  ledgr:::ledgr_snapshot_hash_section_finish(tag, rows, digests)
}

production_root <- function(instrument_blocks, bar_blocks, fact_payload) {
  instruments <- production_section(
    instrument_blocks,
    1L,
    c(
      instrument_id = "text", symbol = "text", currency = "text",
      asset_class = "text", multiplier = "number", tick_size = "number",
      meta_json = "text"
    ),
    "instrument_id"
  )
  bars <- production_section(
    bar_blocks,
    2L,
    c(
      instrument_id = "text", ts_utc = "time", open = "number",
      high = "number", low = "number", close = "number", volume = "number"
    ),
    c("instrument_id", "ts_utc")
  )
  facts <- production_section(
    list(data.frame(payload = fact_payload, stringsAsFactors = FALSE)),
    3L,
    c(payload = "json"),
    "payload"
  )
  ledgr:::ledgr_snapshot_hash_hex(ledgr:::ledgr_snapshot_hash_sha256(c(
    charToRaw("LEDGR-SNAPSHOT"),
    ledgr:::ledgr_snapshot_hash_u32_le(3L),
    instruments,
    bars,
    facts
  )))
}

fixed_blocks <- function(frame, rows = 10000L) {
  if (nrow(frame) == 0L) return(list())
  starts <- seq.int(1L, nrow(frame), by = rows)
  lapply(starts, function(first) {
    frame[first:min(nrow(frame), first + rows - 1L), , drop = FALSE]
  })
}

production_root_from_frames <- function(instruments, bars, fact_payload,
                                        fetch_size = 10000L, threads = 1L) {
  instruments <- instruments[order(
    enc2utf8(instruments$instrument_id),
    method = "radix"
  ), , drop = FALSE]
  bars <- bars[do.call(order, c(
    list(enc2utf8(bars$instrument_id), as.numeric(bars$ts_utc)),
    list(method = "radix")
  )), , drop = FALSE]
  production_root(
    fixed_blocks(instruments),
    fixed_blocks(bars),
    fact_payload
  )
}

candidate$r3_root <- production_root
candidate$r3_root_from_frames <- production_root_from_frames
expected <- oracle$r3_conformance_cases()
actual <- candidate$r3_conformance_cases()
if (!identical(expected, actual)) {
  stop("Production encoder does not reproduce the spike corpus.", call. = FALSE)
}
utils::write.csv(actual, file.path(output_dir, "production_cases.csv"),
  row.names = FALSE, na = ""
)

seal_root <- function(instruments, bars) {
  con <- ledgr_db_init(":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, "SET threads = 1")
  id <- ledgr_snapshot_create(con, meta = list())
  instruments$snapshot_id <- id
  instruments <- instruments[c(
    "snapshot_id", "instrument_id", "symbol", "currency", "asset_class",
    "multiplier", "tick_size", "meta_json"
  )]
  bars$snapshot_id <- id
  bars <- bars[c(
    "snapshot_id", "instrument_id", "ts_utc", "open", "high", "low",
    "close", "volume"
  )]
  DBI::dbAppendTable(con, "snapshot_instruments", instruments)
  DBI::dbAppendTable(con, "snapshot_bars", bars)
  ledgr_snapshot_seal(con, id)
}

times <- as.POSIXct("2020-01-01", tz = "UTC") + 0:2 * 86400
base_instruments <- oracle$r3_make_instruments(c("AAA", "BBB"))
base_bars <- oracle$r3_make_bars(c("AAA", "BBB"), times)
baseline <- seal_root(base_instruments, base_bars)
insertion <- seal_root(
  base_instruments[c(2L, 1L), , drop = FALSE],
  base_bars[c(6L, 2L, 5L, 1L, 4L, 3L), , drop = FALSE]
)
boundary_bars <- oracle$r3_make_bars(
  "AAA",
  as.POSIXct("2000-01-01", tz = "UTC") + 0:10000 * 60
)
boundary <- seal_root(oracle$r3_make_instruments("AAA"), boundary_bars)
unicode_ids <- c("A", "B", "a", "b", "z", "\u00e9")
unicode <- seal_root(
  oracle$r3_make_instruments(unicode_ids)[c(6L, 2L, 5L, 1L, 4L, 3L), ],
  oracle$r3_make_bars(
    unicode_ids,
    as.POSIXct("2020-01-01", tz = "UTC")
  )[c(3L, 6L, 1L, 5L, 2L, 4L), ]
)
dst <- seal_root(
  oracle$r3_make_instruments("AAA"),
  oracle$r3_make_bars(
    "AAA",
    as.POSIXct("2020-11-01 05:30:00", tz = "UTC")
  )
)
mutated <- base_bars
mutated$close[[1L]] <- mutated$close[[1L]] + 0.01
mutation <- seal_root(base_instruments, mutated)

seal_cases <- data.frame(
  case = c(
    "dense_baseline", "insertion_fetch_threads", "fixed_block_boundary",
    "unicode_mixed_case", "dst_same_instant", "covered_value_mutation"
  ),
  root = c(baseline, insertion, boundary, unicode, dst, mutation),
  expected = c(
    expected$root[expected$case == "dense_baseline"],
    expected$root[expected$case == "insertion_fetch_threads"],
    expected$root[expected$case == "fixed_block_boundary"],
    expected$root[expected$case == "unicode_mixed_case"],
    expected$root[expected$case == "dst_same_instant"],
    expected$comparison_root[expected$case == "covered_value_mutation"]
  ),
  stringsAsFactors = FALSE
)
seal_cases$identical <- seal_cases$root == seal_cases$expected
if (!all(seal_cases$identical)) {
  stop("A schema-valid production seal moved a golden root.", call. = FALSE)
}
utils::write.csv(seal_cases, file.path(output_dir, "production_seals.csv"),
  row.names = FALSE, na = ""
)
cat("RULE3_PRODUCTION_CONFORMANCE_OK\n")
