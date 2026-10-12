#!/usr/bin/env Rscript

# Standalone rule-3 candidate. This file intentionally does not source package
# production code; seed v2 Section 5 is its authority.

r3_stop <- function(message) stop(message, call. = FALSE)

r3_raw_concat <- function(parts) {
  if (length(parts) == 0L) return(raw())
  do.call(c, unname(parts))
}

r3_u32_le <- function(x) {
  if (length(x) != 1L || is.na(x) || x < 0 || x > 2^32 - 1 || x != floor(x)) {
    r3_stop("Invalid uint32 value.")
  }
  as.raw(vapply(0:3, function(k) floor(x / 256^k) %% 256, numeric(1)))
}

r3_u64_vec_le <- function(x) {
  x <- as.numeric(x)
  if (anyNA(x) || any(!is.finite(x)) || any(x < 0) ||
      any(x > 2^53) || any(x != floor(x))) {
    r3_stop("Invalid exactly representable uint64 value.")
  }
  out <- raw(8L * length(x))
  if (length(x) == 0L) return(out)
  if (all(x <= .Machine$integer.max)) {
    low <- writeBin(
      as.integer(x),
      raw(),
      size = 4L,
      endian = "little"
    )
    for (k in 0:3) {
      out[seq.int(k + 1L, length(out), by = 8L)] <-
        low[seq.int(k + 1L, length(low), by = 4L)]
    }
    return(out)
  }
  for (k in 0:7) {
    out[seq.int(k + 1L, length(out), by = 8L)] <-
      as.raw(floor(x / 256^k) %% 256)
  }
  out
}

r3_i64_vec_le <- function(x) {
  x <- as.numeric(x)
  if (anyNA(x) || any(!is.finite(x)) || any(abs(x) > 2^53) ||
      any(x != floor(x))) {
    r3_stop("Invalid exactly representable int64 value.")
  }
  out <- raw(8L * length(x))
  if (length(x) == 0L) return(out)
  if (all(x >= 0) && all(x <= .Machine$integer.max)) {
    low <- writeBin(
      as.integer(x),
      raw(),
      size = 4L,
      endian = "little"
    )
    for (k in 0:3) {
      out[seq.int(k + 1L, length(out), by = 8L)] <-
        low[seq.int(k + 1L, length(low), by = 4L)]
    }
    return(out)
  }
  for (k in 0:7) {
    out[seq.int(k + 1L, length(out), by = 8L)] <-
      as.raw(floor(x / 256^k) %% 256)
  }
  out
}

r3_sha256 <- function(bytes) {
  digest::digest(bytes, algo = "sha256", serialize = FALSE, raw = TRUE)
}

r3_hex <- function(bytes) {
  paste(sprintf("%02x", as.integer(bytes)), collapse = "")
}

r3_encode_text_column <- function(x) {
  x <- as.character(x)
  present <- !is.na(x)
  if (all(present)) {
    values <- enc2utf8(x)
    return(c(
      as.raw(rep.int(1L, length(x))),
      r3_u64_vec_le(nchar(values, type = "bytes", allowNA = FALSE)),
      if (length(values) == 0L) raw() else
        charToRaw(paste0(values, collapse = ""))
    ))
  }
  values <- enc2utf8(x[present])
  lengths <- numeric(length(x))
  lengths[present] <- nchar(values, type = "bytes", allowNA = FALSE)
  payload <- if (length(values) == 0L) raw() else
    charToRaw(paste0(values, collapse = ""))
  c(as.raw(as.integer(present)), r3_u64_vec_le(lengths), payload)
}

r3_encode_number_column <- function(x) {
  x <- as.numeric(x)
  present <- !is.na(x)
  if (all(present)) {
    if (any(!is.finite(x))) r3_stop("Non-finite number.")
    x <- round(x, 8L)
    zero <- x == 0
    if (any(zero)) x[zero] <- 0
    return(c(
      as.raw(rep.int(1L, length(x))),
      writeBin(x, raw(), size = 8L, endian = "little")
    ))
  }
  if (any(!is.finite(x[present]))) r3_stop("Non-finite number.")
  x[present] <- round(x[present], 8L)
  zero <- present & x == 0
  if (any(zero)) x[zero] <- 0
  x[!present] <- 0
  c(
    as.raw(as.integer(present)),
    writeBin(x, raw(), size = 8L, endian = "little")
  )
}

r3_encode_time_column <- function(x) {
  x <- as.numeric(x)
  present <- !is.na(x)
  if (all(present)) {
    if (any(!is.finite(x)) || any(x != floor(x))) {
      r3_stop("Timestamp must be finite whole seconds.")
    }
    return(c(
      as.raw(rep.int(1L, length(x))),
      r3_i64_vec_le(x)
    ))
  }
  if (any(!is.finite(x[present])) || any(x[present] != floor(x[present]))) {
    r3_stop("Timestamp must be finite whole seconds.")
  }
  payload <- x
  payload[!present] <- 0
  c(as.raw(as.integer(present)), r3_i64_vec_le(payload))
}

r3_encode_field <- function(x, type) {
  switch(
    type,
    text = r3_encode_text_column(x),
    json = r3_encode_text_column(x),
    number = r3_encode_number_column(x),
    time = r3_encode_time_column(x),
    r3_stop(sprintf("Unknown field type: %s", type))
  )
}

r3_compare_order <- function(frame, keys, previous_last = NULL) {
  key_frame <- frame[keys]
  values <- lapply(key_frame, function(x) {
    if (is.character(x)) enc2utf8(x) else as.numeric(x)
  })
  observed <- do.call(order, c(values, list(method = "radix", na.last = TRUE)))
  if (!identical(observed, seq_len(nrow(frame)))) {
    r3_stop("Rows are not in canonical bytewise order.")
  }
  if (nrow(key_frame) > 1L) {
    adjacent_equal <- rep(TRUE, nrow(key_frame) - 1L)
    for (value in values) {
      adjacent_equal <- adjacent_equal &
        value[-length(value)] == value[-1L]
    }
    if (any(adjacent_equal)) r3_stop("Duplicate canonical row key.")
  }
  if (!is.null(previous_last) && nrow(frame) > 0L) {
    boundary <- rbind(previous_last, key_frame[1L, , drop = FALSE])
    values <- lapply(boundary, function(x) {
      if (is.character(x)) enc2utf8(x) else as.numeric(x)
    })
    boundary_order <- do.call(
      order,
      c(values, list(method = "radix", na.last = TRUE))
    )
    boundary_equal <- all(vapply(
      values,
      function(value) identical(value[[1L]], value[[2L]]),
      logical(1)
    ))
    if (!identical(boundary_order, 1:2) || boundary_equal) {
      r3_stop("Block boundary is not in canonical bytewise order.")
    }
  }
  if (nrow(frame) == 0L) previous_last else
    key_frame[nrow(key_frame), , drop = FALSE]
}

r3_block_digest <- function(frame, section_tag, block_index, fields, keys,
                            previous_last = NULL) {
  previous_last <- r3_compare_order(frame, keys, previous_last)
  payload <- r3_raw_concat(Map(
    function(name, type) r3_encode_field(frame[[name]], type),
    names(fields),
    unname(fields)
  ))
  bytes <- c(
    charToRaw("LEDGR-R3-BLOCK"),
    as.raw(section_tag),
    r3_u64_vec_le(block_index),
    r3_u64_vec_le(nrow(frame)),
    r3_u64_vec_le(length(payload)),
    payload
  )
  list(digest = r3_sha256(bytes), last = previous_last)
}

r3_section_digest <- function(blocks, section_tag, fields, keys) {
  digests <- list()
  previous_last <- NULL
  total_rows <- 0
  for (i in seq_along(blocks)) {
    block <- blocks[[i]]
    if (nrow(block) > 10000L) r3_stop("Logical block exceeds 10,000 rows.")
    result <- r3_block_digest(
      block,
      section_tag,
      i - 1L,
      fields,
      keys,
      previous_last
    )
    digests[[i]] <- result$digest
    previous_last <- result$last
    total_rows <- total_rows + nrow(block)
  }
  bytes <- c(
    charToRaw("LEDGR-R3-SECTION"),
    as.raw(section_tag),
    r3_u64_vec_le(total_rows),
    r3_u64_vec_le(length(digests)),
    r3_raw_concat(digests)
  )
  r3_sha256(bytes)
}

r3_fact_table_names <- function() {
  c(
    "snapshot_fact_families",
    "snapshot_membership_sets",
    "snapshot_membership",
    "snapshot_trading_status",
    "snapshot_lifetime",
    "snapshot_equity_corporate_actions",
    "snapshot_sessions",
    "snapshot_observation_quarantine"
  )
}

r3_json_verbatim_options <- function() {
  yyjsonr::opts_write_json(
    pretty = FALSE,
    auto_unbox = TRUE,
    dataframe = "rows",
    digits = -1L,
    null = "null",
    num_specials = "null",
    json_verbatim = TRUE
  )
}

r3_json_options <- function() {
  yyjsonr::opts_write_json(
    pretty = FALSE,
    auto_unbox = TRUE,
    digits = -1L,
    null = "null",
    num_specials = "null"
  )
}

r3_canonicalize <- function(x) {
  if (is.null(x)) return(NULL)
  if (inherits(x, "POSIXt")) {
    return(format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  if (inherits(x, "Date")) return(as.character(x))
  if (is.factor(x)) return(as.character(x))
  if (is.atomic(x)) {
    if (is.double(x) && any(!is.finite(x))) r3_stop("Non-finite JSON value.")
    if (!is.null(names(x)) && length(x) > 0L) {
      out <- as.list(x)
      out <- out[order(names(out), method = "radix")]
      return(lapply(out, r3_canonicalize))
    }
    return(x)
  }
  if (is.list(x)) {
    if (!is.null(names(x))) x <- x[order(names(x), method = "radix")]
    return(lapply(x, r3_canonicalize))
  }
  r3_stop("Unsupported canonical JSON value.")
}

r3_canonical_json <- function(x) {
  as.character(yyjsonr::write_json_str(
    r3_canonicalize(x),
    opts = r3_json_options()
  ))
}

r3_fact_frame_json <- function(frame) {
  if (is.null(frame) || nrow(frame) == 0L) return("[]")
  out <- as.data.frame(frame, stringsAsFactors = FALSE)
  out <- out[order(names(out), method = "radix")]
  for (name in names(out)) {
    column <- out[[name]]
    if (inherits(column, "POSIXt")) {
      out[[name]] <- format(
        as.POSIXct(column, tz = "UTC"),
        "%Y-%m-%dT%H:%M:%SZ",
        tz = "UTC"
      )
    } else if (inherits(column, "Date") || is.factor(column)) {
      out[[name]] <- as.character(column)
    } else {
      out[[name]] <- unname(column)
    }
  }
  as.character(yyjsonr::write_json_str(
    out,
    opts = r3_json_verbatim_options()
  ))
}

r3_quarantine_project <- function(value) {
  opts <- yyjsonr::opts_read_json(
    obj_of_arrs_to_df = FALSE,
    arr_of_objs_to_df = FALSE,
    arr_of_arrs_to_matrix = FALSE,
    length1_array_asis = TRUE
  )
  parsed <- yyjsonr::read_json_str(value, opts = opts)
  keys <- c("instrument_id", "ts_utc", "open", "high", "low", "close", "volume")
  required <- keys[keys != "volume"]
  if (!is.list(parsed) || is.null(names(parsed)) ||
      any(!required %in% names(parsed))) {
    r3_stop("Invalid quarantine original row.")
  }
  keep <- intersect(keys, names(parsed))
  r3_canonical_json(parsed[keep])
}

r3_fact_payload <- function(tables) {
  all_names <- r3_fact_table_names()
  missing <- setdiff(all_names, names(tables))
  if (length(missing) > 0L) {
    for (name in missing) tables[[name]] <- data.frame()
  }
  tables <- tables[all_names]

  quarantine <- tables$snapshot_observation_quarantine
  if (nrow(quarantine) > 0L && "reason" %in% names(quarantine)) {
    quarantine <- quarantine[quarantine$reason != "off_session_bar", , drop = FALSE]
  }
  if (nrow(quarantine) > 0L) {
    quarantine$original_row_json <- vapply(
      quarantine$original_row_json,
      r3_quarantine_project,
      character(1)
    )
    order_by <- intersect(
      c(
        "supplied_instrument_id",
        "supplied_ts_utc",
        "reason",
        "original_row_json",
        "provenance_json"
      ),
      names(quarantine)
    )
    order_values <- c(
      unname(as.list(quarantine[order_by])),
      list(method = "radix")
    )
    quarantine <- quarantine[do.call(order, order_values), , drop = FALSE]
    rownames(quarantine) <- NULL
    quarantine <- quarantine[setdiff(names(quarantine), "quarantine_id")]
  }
  tables$snapshot_observation_quarantine <- quarantine

  normalized <- lapply(tables, function(frame) {
    structure(r3_fact_frame_json(frame), class = "json")
  })
  normalized <- normalized[order(names(normalized), method = "radix")]
  payload <- list(
    fact_schema_version = 1L,
    schema = "ledgr_snapshot_hash_rule_3",
    tables = normalized
  )
  as.character(yyjsonr::write_json_str(
    payload,
    opts = r3_json_verbatim_options()
  ))
}

r3_empty_fact_payload <- function() {
  tables <- rep(list(data.frame()), length(r3_fact_table_names()))
  names(tables) <- r3_fact_table_names()
  r3_fact_payload(tables)
}

r3_root <- function(instrument_blocks, bar_blocks, fact_payload) {
  instrument_fields <- c(
    instrument_id = "text",
    symbol = "text",
    currency = "text",
    asset_class = "text",
    multiplier = "number",
    tick_size = "number",
    meta_json = "text"
  )
  bar_fields <- c(
    instrument_id = "text",
    ts_utc = "time",
    open = "number",
    high = "number",
    low = "number",
    close = "number",
    volume = "number"
  )
  fact_fields <- c(payload = "json")
  fact_block <- data.frame(payload = fact_payload, stringsAsFactors = FALSE)

  instruments <- r3_section_digest(
    instrument_blocks,
    1L,
    instrument_fields,
    "instrument_id"
  )
  bars <- r3_section_digest(
    bar_blocks,
    2L,
    bar_fields,
    c("instrument_id", "ts_utc")
  )
  facts <- r3_section_digest(
    list(fact_block),
    3L,
    fact_fields,
    "payload"
  )

  r3_finish_root(instruments, bars, facts)
}

r3_finish_root <- function(instruments, bars, facts) {
  r3_hex(r3_sha256(c(
    charToRaw("LEDGR-SNAPSHOT"),
    r3_u32_le(3L),
    instruments,
    bars,
    facts
  )))
}

r3_bar_fields <- function() {
  c(
    instrument_id = "text",
    ts_utc = "time",
    open = "number",
    high = "number",
    low = "number",
    close = "number",
    volume = "number"
  )
}

r3_stream_section <- function(total_rows, section_tag, fields, keys,
                              make_block, block_size = 10000L) {
  digests <- list()
  previous_last <- NULL
  block_index <- 0L
  first <- 1
  while (first <= total_rows) {
    last <- min(total_rows, first + block_size - 1)
    block <- make_block(first, last)
    if (nrow(block) != last - first + 1L) {
      r3_stop("Streamed block has the wrong row count.")
    }
    result <- r3_block_digest(
      block,
      section_tag,
      block_index,
      fields,
      keys,
      previous_last
    )
    digests[[length(digests) + 1L]] <- result$digest
    previous_last <- result$last
    block_index <- block_index + 1L
    first <- last + 1
  }
  bytes <- c(
    charToRaw("LEDGR-R3-SECTION"),
    as.raw(section_tag),
    r3_u64_vec_le(total_rows),
    r3_u64_vec_le(length(digests)),
    r3_raw_concat(digests)
  )
  r3_sha256(bytes)
}

r3_stream_bar_block <- function(first, last) {
  value <- seq.int(first, last)
  open <- 100 + value / 100000
  data.frame(
    instrument_id = rep("AAA", length(value)),
    ts_utc = 946684800 + value,
    open = open,
    high = open + 1,
    low = open - 1,
    close = open + 0.25,
    volume = 1000 + value,
    stringsAsFactors = FALSE
  )
}

r3_stream_root <- function(total_rows) {
  instruments <- r3_section_digest(
    list(r3_make_instruments("AAA")),
    1L,
    c(
      instrument_id = "text",
      symbol = "text",
      currency = "text",
      asset_class = "text",
      multiplier = "number",
      tick_size = "number",
      meta_json = "text"
    ),
    "instrument_id"
  )
  bars <- r3_stream_section(
    total_rows,
    2L,
    r3_bar_fields(),
    c("instrument_id", "ts_utc"),
    r3_stream_bar_block
  )
  fact_block <- data.frame(
    payload = r3_empty_fact_payload(),
    stringsAsFactors = FALSE
  )
  facts <- r3_section_digest(
    list(fact_block),
    3L,
    c(payload = "json"),
    "payload"
  )
  r3_finish_root(instruments, bars, facts)
}

r3_core_case <- function() {
  instruments <- data.frame(
    instrument_id = "AAA",
    symbol = "AAA",
    currency = "USD",
    asset_class = "equity",
    multiplier = 1,
    tick_size = 0.01,
    meta_json = "{}",
    stringsAsFactors = FALSE
  )
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = 1577836800,
    open = 100,
    high = 102,
    low = 99,
    close = 101,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  data.frame(
    case = "core_dense_one_bar",
    root = r3_root(list(instruments), list(bars), r3_empty_fact_payload()),
    instrument_rows = nrow(instruments),
    bar_rows = nrow(bars),
    stringsAsFactors = FALSE
  )
}

r3_fetch_blocks <- function(result, fetch_size, block_size = 10000L) {
  blocks <- list()
  buffer <- NULL
  repeat {
    chunk <- DBI::dbFetch(result, n = fetch_size)
    if (!is.data.frame(chunk) || nrow(chunk) == 0L) break
    buffer <- if (is.null(buffer) || nrow(buffer) == 0L) chunk else
      rbind(buffer, chunk)
    while (nrow(buffer) >= block_size) {
      blocks[[length(blocks) + 1L]] <- buffer[seq_len(block_size), , drop = FALSE]
      buffer <- buffer[-seq_len(block_size), , drop = FALSE]
    }
  }
  if (!is.null(buffer) && nrow(buffer) > 0L) {
    blocks[[length(blocks) + 1L]] <- buffer
  }
  blocks
}

r3_query_blocks <- function(con, sql, fetch_size) {
  result <- DBI::dbSendQuery(con, sql)
  on.exit(DBI::dbClearResult(result), add = TRUE)
  r3_fetch_blocks(result, fetch_size)
}

r3_root_from_frames <- function(instruments, bars, fact_payload,
                                fetch_size = 10000L, threads = 1L) {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, sprintf("SET threads = %d", as.integer(threads)))
  DBI::dbWriteTable(con, "candidate_instruments", instruments)
  DBI::dbWriteTable(con, "candidate_bars", bars)
  instrument_blocks <- r3_query_blocks(
    con,
    paste(
      "SELECT instrument_id, symbol, currency, asset_class,",
      "multiplier, tick_size, meta_json",
      "FROM candidate_instruments ORDER BY instrument_id"
    ),
    fetch_size
  )
  bar_blocks <- r3_query_blocks(
    con,
    paste(
      "SELECT instrument_id, ts_utc, open, high, low, close, volume",
      "FROM candidate_bars ORDER BY instrument_id, ts_utc"
    ),
    fetch_size
  )
  r3_root(instrument_blocks, bar_blocks, fact_payload)
}

r3_make_instruments <- function(ids) {
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

r3_make_bars <- function(ids, times) {
  grid <- expand.grid(
    instrument_id = ids,
    ts_utc = times,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid <- grid[do.call(order, c(
    unname(as.list(grid[c("instrument_id", "ts_utc")])),
    list(method = "radix")
  )), , drop = FALSE]
  rownames(grid) <- NULL
  value <- seq_len(nrow(grid))
  grid$open <- 100 + value / 100
  grid$high <- grid$open + 1
  grid$low <- grid$open - 1
  grid$close <- grid$open + 0.25
  grid$volume <- 1000 + value
  grid
}

r3_all_fact_tables <- function(quarantine_extra = FALSE) {
  t0 <- as.POSIXct("2020-01-02 21:00:00", tz = "UTC")
  t1 <- as.POSIXct("2020-01-03 21:00:00", tz = "UTC")
  t2 <- as.POSIXct("2020-01-04 21:00:00", tz = "UTC")
  provenance <- "{}"
  families <- c(
    "membership",
    "trading_status",
    "lifetime",
    "equity_corporate_actions",
    "sessions",
    "observation_quarantine"
  )
  fact_families <- data.frame(
    family = families,
    scope_id = c("u", "status", "life", "corp", "venue", "invalid_observations"),
    family_schema_version = rep(1L, length(families)),
    metadata_json = rep("{}", length(families)),
    stringsAsFactors = FALSE
  )
  fact_families <- fact_families[order(
    fact_families$family,
    fact_families$scope_id,
    method = "radix"
  ), , drop = FALSE]

  original <- list(
    instrument_id = "AAA",
    ts_utc = "2020-01-02T21:00:00Z",
    open = 100,
    high = 102,
    low = 99,
    close = 101,
    volume = 1000
  )
  if (isTRUE(quarantine_extra)) original$ignored_vendor_column <- "ignored"

  list(
    snapshot_fact_families = fact_families,
    snapshot_membership_sets = data.frame(
      universe_id = "u",
      set_id = "set-1",
      effective_from = t0,
      knowledge_time = t0,
      complete = TRUE,
      provenance_json = provenance,
      stringsAsFactors = FALSE
    ),
    snapshot_membership = data.frame(
      fact_id = "m-1",
      instrument_id = "AAA",
      universe_id = "u",
      set_id = "set-1",
      effective_from = t0,
      effective_to = as.POSIXct(NA),
      knowledge_time = t0,
      member = TRUE,
      provenance_json = provenance,
      stringsAsFactors = FALSE
    ),
    snapshot_trading_status = data.frame(
      fact_id = "t-1",
      instrument_id = "AAA",
      effective_from = t0,
      effective_to = as.POSIXct(NA),
      knowledge_time = t0,
      status = "active",
      source = "spike",
      precedence = 1L,
      revision_id = NA_character_,
      supersedes_fact_id = NA_character_,
      provenance_json = provenance,
      stringsAsFactors = FALSE
    ),
    snapshot_lifetime = data.frame(
      fact_id = "l-1",
      instrument_id = "AAA",
      effective_from = t0,
      effective_to = t2,
      knowledge_time = t0,
      assertion = "bounded",
      terminal_event = "delisting",
      provenance_json = provenance,
      stringsAsFactors = FALSE
    ),
    snapshot_equity_corporate_actions = data.frame(
      fact_id = "c-1",
      subtype = "cash_dividend",
      parent_instrument_id = "AAA",
      entitlement_time = t0,
      effective_time = t1,
      knowledge_time = t0,
      payment_time = t2,
      complete = TRUE,
      refusal_reason = NA_character_,
      provenance_tier = "declared",
      upstream_build_id = "build-1",
      bar_vintage_id = "bars-1",
      gross_cash_per_parent_unit = 1.25,
      gross_cash_validated = TRUE,
      recipient_instrument_id = NA_character_,
      recipient_identity_validated = FALSE,
      recipient_quantity_per_parent_unit = NA_real_,
      recipient_quantity_validated = FALSE,
      provenance_json = provenance,
      stringsAsFactors = FALSE
    ),
    snapshot_sessions = data.frame(
      venue_id = "XNYS",
      session_date = as.Date("2020-01-02"),
      effective_from = t0,
      effective_to = t1,
      knowledge_time = t0,
      status = "open",
      session_open = as.POSIXct("2020-01-02 14:30:00", tz = "UTC"),
      session_close = t0,
      provenance_json = provenance,
      stringsAsFactors = FALSE
    ),
    snapshot_observation_quarantine = data.frame(
      quarantine_id = "q-1",
      supplied_instrument_id = "AAA",
      supplied_ts_utc = "2020-01-02T21:00:00Z",
      reason = "ohlc_non_positive",
      original_row_json = r3_canonical_json(original),
      provenance_json = provenance,
      stringsAsFactors = FALSE
    )
  )
}

r3_case_record <- function(case, root, comparison = NA_character_, relation,
                           detail) {
  data.frame(
    case = case,
    root = root,
    comparison_root = comparison,
    relation = relation,
    detail = detail,
    stringsAsFactors = FALSE
  )
}

r3_conformance_cases <- function() {
  empty_facts <- r3_empty_fact_payload()
  times <- as.POSIXct("2020-01-01", tz = "UTC") + 0:2 * 86400
  instruments <- r3_make_instruments(c("AAA", "BBB"))
  bars <- r3_make_bars(c("AAA", "BBB"), times)
  baseline <- r3_root_from_frames(instruments, bars, empty_facts, 10000L, 1L)

  shuffled_instruments <- instruments[c(2L, 1L), , drop = FALSE]
  shuffled_bars <- bars[c(6L, 2L, 5L, 1L, 4L, 3L), , drop = FALSE]
  insertion_variant <- r3_root_from_frames(
    shuffled_instruments,
    shuffled_bars,
    empty_facts,
    1L,
    2L
  )

  boundary_instruments <- r3_make_instruments("AAA")
  boundary_times <- as.POSIXct("2000-01-01", tz = "UTC") + 0:10000 * 60
  boundary_bars <- r3_make_bars("AAA", boundary_times)
  boundary_a <- r3_root_from_frames(
    boundary_instruments,
    boundary_bars,
    empty_facts,
    4096L,
    1L
  )
  boundary_b <- r3_root_from_frames(
    boundary_instruments,
    boundary_bars,
    empty_facts,
    7777L,
    2L
  )

  unicode_ids <- c("A", "B", "a", "b", "z", "\u00e9")
  unicode_instruments <- r3_make_instruments(unicode_ids)
  unicode_bars <- r3_make_bars(
    unicode_ids,
    as.POSIXct("2020-01-01", tz = "UTC")
  )
  unicode_root <- r3_root_from_frames(
    unicode_instruments[c(6L, 2L, 5L, 1L, 4L, 3L), , drop = FALSE],
    unicode_bars[c(3L, 6L, 1L, 5L, 2L, 4L), , drop = FALSE],
    empty_facts,
    2L,
    2L
  )

  dst_utc <- as.POSIXct("2020-11-01 05:30:00", tz = "UTC")
  dst_offset <- as.POSIXct(
    "2020-11-01 01:30:00 -0400",
    format = "%Y-%m-%d %H:%M:%S %z",
    tz = "UTC"
  )
  dst_a <- r3_root_from_frames(
    r3_make_instruments("AAA"),
    r3_make_bars("AAA", dst_utc),
    empty_facts
  )
  dst_b <- r3_root_from_frames(
    r3_make_instruments("AAA"),
    r3_make_bars("AAA", dst_offset),
    empty_facts
  )

  numeric_instruments <- r3_make_instruments("AAA")
  numeric_instruments$multiplier <- NA_real_
  numeric_instruments$tick_size <- -1e-10
  numeric_bars <- r3_make_bars(
    "AAA",
    as.POSIXct("2020-01-01", tz = "UTC")
  )
  numeric_bars$open <- 1.234567895
  numeric_bars$high <- 9e14 + 0.25
  numeric_bars$low <- 1.000000005
  numeric_bars$close <- 2.500000005
  numeric_bars$volume <- NA_real_
  numeric_root <- r3_root_from_frames(
    numeric_instruments,
    numeric_bars,
    empty_facts
  )

  fact_root <- r3_root_from_frames(
    r3_make_instruments("AAA"),
    r3_make_bars("AAA", times[[1L]]),
    r3_fact_payload(r3_all_fact_tables(FALSE))
  )
  quarantine_plain <- r3_root_from_frames(
    r3_make_instruments("AAA"),
    r3_make_bars("AAA", times[[1L]]),
    r3_fact_payload(r3_all_fact_tables(FALSE))
  )
  quarantine_extra <- r3_root_from_frames(
    r3_make_instruments("AAA"),
    r3_make_bars("AAA", times[[1L]]),
    r3_fact_payload(r3_all_fact_tables(TRUE))
  )

  mutated_bars <- bars
  mutated_bars$close[[1L]] <- mutated_bars$close[[1L]] + 0.01
  mutation_root <- r3_root_from_frames(
    instruments,
    mutated_bars,
    empty_facts
  )

  wrong_order <- tryCatch(
    {
      r3_root(
        list(instruments[c(2L, 1L), , drop = FALSE]),
        list(bars),
        empty_facts
      )
      "accepted"
    },
    error = function(e) paste0("refused: ", conditionMessage(e))
  )

  rbind(
    r3_case_record("dense_baseline", baseline, relation = "root", detail = "dense two-instrument root"),
    r3_case_record("insertion_fetch_threads", baseline, insertion_variant, "equal", "shuffled insertion; fetch 10000/1; threads 1/2"),
    r3_case_record("fixed_block_boundary", boundary_a, boundary_b, "equal", "10001 rows; fetch 4096/7777; threads 1/2"),
    r3_case_record("unicode_mixed_case", unicode_root, relation = "root", detail = "radix A B a b z non-ASCII"),
    r3_case_record("dst_same_instant", dst_a, dst_b, "equal", "UTC and -0400 labels resolve to one instant"),
    r3_case_record("numeric_edges", numeric_root, relation = "root", detail = "rounding ties, large value, negative zero, missing"),
    r3_case_record("all_fact_families", fact_root, relation = "root", detail = "all six fact families plus quarantine"),
    r3_case_record("quarantine_extra_column", quarantine_plain, quarantine_extra, "equal", "ignored vendor column excluded from projection"),
    r3_case_record("covered_value_mutation", baseline, mutation_root, "different", "first close changes by 0.01"),
    r3_case_record("wrong_order_refused", wrong_order, "refused: Rows are not in canonical bytewise order.", "equal", "encoder refuses hostile instrument order")
  )
}

r3_platform <- function() {
  if (identical(.Platform$OS.type, "windows")) "windows" else "ubuntu"
}

r3_encode_benchmark <- function(rows) {
  block <- r3_stream_bar_block(1, 10000)
  previous_last <- data.frame(
    instrument_id = "AAA",
    ts_utc = min(block$ts_utc) - 1,
    stringsAsFactors = FALSE
  )
  fields <- r3_bar_fields()
  keys <- c("instrument_id", "ts_utc")
  count <- rows %/% nrow(block)
  if (count * nrow(block) != rows) {
    r3_stop("Cost shape must be a multiple of the logical block size.")
  }
  digests <- vector("list", count)
  started <- proc.time()[["elapsed"]]
  for (i in seq_len(count)) {
    digests[[i]] <- r3_block_digest(
      block,
      2L,
      i - 1L,
      fields,
      keys,
      previous_last
    )$digest
  }
  checksum <- r3_hex(r3_sha256(r3_raw_concat(digests)))
  list(
    elapsed_seconds = proc.time()[["elapsed"]] - started,
    checksum = checksum
  )
}

r3_cost_evidence <- function() {
  sizes <- c(500000, 1000000, 2000000, 5000000)
  rows <- vector("list", length(sizes) * 3L)
  index <- 0L
  for (size in sizes) {
    for (replicate in 1:3) {
      gc(FALSE)
      result <- r3_encode_benchmark(size)
      elapsed <- result$elapsed_seconds
      index <- index + 1L
      rows[[index]] <- data.frame(
        platform = r3_platform(),
        rows = size,
        replicate = replicate,
        elapsed_seconds = elapsed,
        microseconds_per_row = elapsed * 1e6 / size,
        checksum = result$checksum,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

r3_fact_memory_tables <- function(rows) {
  tables <- rep(list(data.frame()), length(r3_fact_table_names()))
  names(tables) <- r3_fact_table_names()
  tables$snapshot_fact_families <- data.frame(
    family = "membership",
    scope_id = "memory",
    family_schema_version = 1L,
    metadata_json = "{}",
    stringsAsFactors = FALSE
  )
  sequence <- seq_len(rows)
  tables$snapshot_membership <- data.frame(
    fact_id = paste0("m-", sequence),
    instrument_id = paste0("I", sequence %% 10000L),
    universe_id = "u",
    set_id = paste0("s-", sequence %/% 500L),
    effective_from = as.POSIXct("2000-01-01", tz = "UTC") + sequence,
    effective_to = as.POSIXct(NA),
    knowledge_time = as.POSIXct("2000-01-01", tz = "UTC") + sequence,
    member = sequence %% 2L == 0L,
    provenance_json = "{}",
    stringsAsFactors = FALSE
  )
  tables
}

r3_memory_worker <- function(kind, rows, output_path) {
  gc(FALSE)
  started <- proc.time()[["elapsed"]]
  if (identical(kind, "bars")) {
    value <- r3_stream_root(rows)
    output_bytes <- nchar(value, type = "bytes")
  } else if (identical(kind, "facts")) {
    value <- r3_fact_payload(r3_fact_memory_tables(rows))
    output_bytes <- nchar(value, type = "bytes")
  } else {
    r3_stop("Unknown memory worker kind.")
  }
  result <- list(
    kind = kind,
    rows = rows,
    elapsed_seconds = proc.time()[["elapsed"]] - started,
    output_bytes = output_bytes
  )
  saveRDS(result, output_path)
}

r3_script_path <- function() {
  argument <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(argument) != 1L) r3_stop("Cannot identify spike runner path.")
  normalizePath(sub("^--file=", "", argument), winslash = "/")
}

r3_rscript <- function() {
  candidate <- file.path(
    R.home("bin"),
    if (identical(.Platform$OS.type, "windows")) "Rscript.exe" else "Rscript"
  )
  normalizePath(candidate, winslash = "/")
}

r3_measure_worker <- function(kind, rows) {
  result_path <- tempfile(fileext = ".rds")
  on.exit(unlink(result_path), add = TRUE)
  process <- processx::process$new(
    r3_rscript(),
    c(r3_script_path(), "--memory-worker", kind, rows, result_path),
    stdout = "|",
    stderr = "|"
  )
  peak <- 0
  while (process$is_alive()) {
    resident <- tryCatch(
      unname(ps::ps_memory_info(ps::ps_handle(process$get_pid()))[["rss"]]),
      error = function(e) NA_real_
    )
    if (is.finite(resident)) peak <- max(peak, resident)
    Sys.sleep(0.02)
  }
  process$wait()
  if (!identical(process$get_exit_status(), 0L)) {
    r3_stop(paste(
      "Memory worker failed:",
      process$read_all_error()
    ))
  }
  result <- readRDS(result_path)
  data.frame(
    platform = r3_platform(),
    case = result$kind,
    rows = result$rows,
    elapsed_seconds = result$elapsed_seconds,
    peak_rss_bytes = peak,
    output_bytes = result$output_bytes,
    stringsAsFactors = FALSE
  )
}

r3_memory_evidence <- function() {
  rbind(
    r3_measure_worker("bars", 5000000),
    r3_measure_worker("facts", 300000)
  )
}

r3_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

r3_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) == 4L && identical(args[[1L]], "--memory-worker")) {
    r3_memory_worker(args[[2L]], as.numeric(args[[3L]]), args[[4L]])
    return(invisible(NULL))
  }
  if (length(args) != 2L || !args[[1L]] %in%
      c("--core", "--cases", "--cost", "--memory", "--all")) {
    r3_stop(
      paste(
        "Usage: spike_runner.R",
        "--core|--cases|--cost|--memory|--all <output-directory>"
      )
    )
  }
  output_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = FALSE)
  if (identical(args[[1L]], "--core")) {
    r3_write_csv(r3_core_case(), file.path(output_dir, "core.csv"))
    cat("RULE3_CORE_OK\n")
  } else {
    if (identical(args[[1L]], "--cost")) {
      r3_write_csv(r3_cost_evidence(), file.path(output_dir, "cost.csv"))
      cat("RULE3_COST_OK\n")
      return(invisible(NULL))
    }
    if (identical(args[[1L]], "--memory")) {
      r3_write_csv(
        r3_memory_evidence(),
        file.path(output_dir, "memory.csv")
      )
      cat("RULE3_MEMORY_OK\n")
      return(invisible(NULL))
    }
    r3_write_csv(
      r3_conformance_cases(),
      file.path(output_dir, "cases.csv")
    )
    if (identical(args[[1L]], "--all")) {
      r3_write_csv(r3_cost_evidence(), file.path(output_dir, "cost.csv"))
      r3_write_csv(
        r3_memory_evidence(),
        file.path(output_dir, "memory.csv")
      )
      cat("RULE3_ALL_OK\n")
    } else {
      cat("RULE3_CASES_OK\n")
    }
  }
}

if (sys.nframe() == 0L) r3_main()
