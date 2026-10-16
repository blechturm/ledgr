ledgr_snapshot_content_hash_rule_version <- 4L
ledgr_snapshot_hash_block_rows <- 10000L

ledgr_snapshot_hash_u32_le <- function(x) {
  if (length(x) != 1L || is.na(x) || !is.finite(x) || x < 0 ||
      x > 2^32 - 1 || x != floor(x)) {
    rlang::abort(
      "Snapshot hashing received an invalid uint32 value.",
      class = c("ledgr_snapshot_hash_encoding_invalid", "ledgr_invalid_state")
    )
  }
  as.raw(vapply(0:3, function(k) floor(x / 256^k) %% 256, numeric(1)))
}

ledgr_snapshot_hash_u64_vec_le <- function(x) {
  x <- as.numeric(x)
  if (anyNA(x) || any(!is.finite(x)) || any(x < 0) ||
      any(x > 2^53) || any(x != floor(x))) {
    rlang::abort(
      "Snapshot hashing received an invalid exactly representable uint64 value.",
      class = c("ledgr_snapshot_hash_encoding_invalid", "ledgr_invalid_state")
    )
  }
  out <- raw(8L * length(x))
  if (length(x) == 0L) return(out)
  if (all(x <= .Machine$integer.max)) {
    low <- writeBin(as.integer(x), raw(), size = 4L, endian = "little")
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

ledgr_snapshot_hash_i64_vec_le <- function(x) {
  x <- as.numeric(x)
  if (anyNA(x) || any(!is.finite(x)) || any(abs(x) > 2^53) ||
      any(x != floor(x))) {
    rlang::abort(
      "Snapshot timestamps must be finite whole seconds representable in R.",
      class = c("ledgr_snapshot_hash_invalid_timestamp", "ledgr_invalid_state")
    )
  }
  out <- raw(8L * length(x))
  if (length(x) == 0L) return(out)
  if (all(x >= 0) && all(x <= .Machine$integer.max)) {
    low <- writeBin(as.integer(x), raw(), size = 4L, endian = "little")
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

ledgr_snapshot_hash_sha256 <- function(bytes) {
  digest::digest(bytes, algo = "sha256", serialize = FALSE, raw = TRUE)
}

ledgr_snapshot_hash_hex <- function(bytes) {
  paste(sprintf("%02x", as.integer(bytes)), collapse = "")
}

ledgr_snapshot_hash_encode_text <- function(x) {
  x <- as.character(x)
  present <- !is.na(x)
  values <- enc2utf8(x[present])
  lengths <- numeric(length(x))
  if (length(values) > 0L) {
    lengths[present] <- nchar(values, type = "bytes", allowNA = FALSE)
  }
  payload <- if (length(values) == 0L) raw() else
    charToRaw(paste0(values, collapse = ""))
  c(
    as.raw(as.integer(present)),
    ledgr_snapshot_hash_u64_vec_le(lengths),
    payload
  )
}

ledgr_snapshot_hash_encode_number <- function(x) {
  x <- as.numeric(x)
  if (any(is.nan(x))) {
    rlang::abort(
      "NaN encountered while hashing snapshot.",
      class = c("ledgr_snapshot_hash_encoding_invalid", "ledgr_invalid_state")
    )
  }
  present <- !is.na(x)
  if (any(!is.finite(x[present]))) {
    rlang::abort(
      "Non-finite numeric encountered while hashing snapshot.",
      class = c("ledgr_snapshot_hash_encoding_invalid", "ledgr_invalid_state")
    )
  }
  x[present] <- round(x[present], 8L)
  zero <- present & x == 0
  if (any(zero)) x[zero] <- 0
  x[!present] <- 0
  c(
    as.raw(as.integer(present)),
    writeBin(x, raw(), size = 8L, endian = "little")
  )
}

ledgr_snapshot_hash_encode_time <- function(x) {
  if (!inherits(x, "POSIXct")) {
    rlang::abort(
      "Snapshot timestamps must be POSIXct while hashing.",
      class = c("ledgr_snapshot_hash_invalid_timestamp", "ledgr_invalid_state")
    )
  }
  x <- as.numeric(x)
  present <- !is.na(x)
  if (any(!is.finite(x[present])) || any(x[present] != floor(x[present]))) {
    rlang::abort(
      "Snapshot timestamps must be finite whole seconds.",
      class = c("ledgr_snapshot_hash_invalid_timestamp", "ledgr_invalid_state")
    )
  }
  payload <- x
  payload[!present] <- 0
  c(
    as.raw(as.integer(present)),
    ledgr_snapshot_hash_i64_vec_le(payload)
  )
}

ledgr_snapshot_hash_encode_field <- function(x, type) {
  switch(
    type,
    text = ledgr_snapshot_hash_encode_text(x),
    json = ledgr_snapshot_hash_encode_text(x),
    number = ledgr_snapshot_hash_encode_number(x),
    time = ledgr_snapshot_hash_encode_time(x),
    rlang::abort(
      sprintf("Unknown snapshot hash field type: %s.", type),
      class = c("ledgr_snapshot_hash_encoding_invalid", "ledgr_invalid_state")
    )
  )
}

ledgr_snapshot_hash_order_abort <- function(message) {
  rlang::abort(
    message,
    class = c("ledgr_snapshot_hash_order_invalid", "ledgr_invalid_state")
  )
}

ledgr_snapshot_hash_compare_order <- function(frame, keys,
                                              previous_last = NULL) {
  key_frame <- frame[keys]
  values <- lapply(key_frame, function(x) {
    if (is.character(x)) enc2utf8(x) else as.numeric(x)
  })
  if (any(vapply(values, anyNA, logical(1)))) {
    ledgr_snapshot_hash_order_abort(
      "Snapshot hash identity keys must not be missing."
    )
  }
  observed <- do.call(
    order,
    c(values, list(method = "radix", na.last = TRUE))
  )
  if (!identical(observed, seq_len(nrow(frame)))) {
    ledgr_snapshot_hash_order_abort(
      "Rows are not in canonical bytewise order."
    )
  }
  if (nrow(key_frame) > 1L) {
    adjacent_equal <- rep(TRUE, nrow(key_frame) - 1L)
    for (value in values) {
      adjacent_equal <- adjacent_equal &
        value[-length(value)] == value[-1L]
    }
    if (any(adjacent_equal)) {
      ledgr_snapshot_hash_order_abort(
        "Snapshot rows repeat a canonical identity key."
      )
    }
  }
  if (!is.null(previous_last) && nrow(key_frame) > 0L) {
    boundary <- rbind(previous_last, key_frame[1L, , drop = FALSE])
    boundary_values <- lapply(boundary, function(x) {
      if (is.character(x)) enc2utf8(x) else as.numeric(x)
    })
    boundary_order <- do.call(
      order,
      c(boundary_values, list(method = "radix", na.last = TRUE))
    )
    boundary_equal <- all(vapply(
      boundary_values,
      function(value) identical(value[[1L]], value[[2L]]),
      logical(1)
    ))
    if (!identical(boundary_order, 1:2) || boundary_equal) {
      ledgr_snapshot_hash_order_abort(
        "Snapshot hash block boundary is not in canonical bytewise order."
      )
    }
  }
  if (nrow(key_frame) == 0L) previous_last else
    key_frame[nrow(key_frame), , drop = FALSE]
}

ledgr_snapshot_hash_block <- function(frame, section_tag, block_index,
                                      fields, keys, previous_last = NULL) {
  previous_last <- ledgr_snapshot_hash_compare_order(
    frame,
    keys,
    previous_last
  )
  columns <- Map(
    function(name, type) {
      ledgr_snapshot_hash_encode_field(frame[[name]], type)
    },
    names(fields),
    unname(fields)
  )
  payload <- if (length(columns) == 0L) raw() else
    do.call(c, unname(columns))
  bytes <- c(
    charToRaw("LEDGR-R4-BLOCK"),
    as.raw(section_tag),
    ledgr_snapshot_hash_u64_vec_le(block_index),
    ledgr_snapshot_hash_u64_vec_le(nrow(frame)),
    ledgr_snapshot_hash_u64_vec_le(length(payload)),
    payload
  )
  list(
    digest = ledgr_snapshot_hash_sha256(bytes),
    last = previous_last
  )
}

ledgr_snapshot_hash_section_finish <- function(section_tag, total_rows,
                                               block_digests) {
  block_count <- length(block_digests) / 32L
  bytes <- c(
    charToRaw("LEDGR-R4-SECTION"),
    as.raw(section_tag),
    ledgr_snapshot_hash_u64_vec_le(total_rows),
    ledgr_snapshot_hash_u64_vec_le(block_count),
    block_digests
  )
  ledgr_snapshot_hash_sha256(bytes)
}

ledgr_snapshot_hash_stream_section <- function(con, sql, params, total_rows,
                                               section_tag, fields, keys,
                                               fetch_size) {
  total_rows <- as.numeric(total_rows)
  if (length(total_rows) != 1L || is.na(total_rows) ||
      !is.finite(total_rows) || total_rows < 0 ||
      total_rows != floor(total_rows)) {
    rlang::abort(
      "Snapshot hash query returned an invalid row count.",
      class = c("ledgr_snapshot_hash_encoding_invalid", "ledgr_invalid_state")
    )
  }
  block_rows <- ledgr_snapshot_hash_block_rows
  expected_blocks <- if (total_rows == 0) 0L else
    as.integer(ceiling(total_rows / block_rows))
  block_digests <- raw(32L * expected_blocks)

  # A section that fits one logical block needs no cursor or accumulator.
  # This preserves the same fixed memory bound while keeping tiny snapshots
  # cheap, which matters for interactive use and the fast contract lane.
  if (total_rows <= block_rows) {
    frame <- DBI::dbGetQuery(con, sql, params = params)
    if (!is.data.frame(frame) || nrow(frame) != total_rows) {
      rlang::abort(
        "Snapshot hash query row count changed during verification.",
        class = c("ledgr_snapshot_hash_encoding_invalid", "ledgr_invalid_state")
      )
    }
    if (total_rows == 0) {
      return(ledgr_snapshot_hash_section_finish(
        section_tag,
        0,
        raw()
      ))
    }
    encoded <- ledgr_snapshot_hash_block(
      frame,
      section_tag,
      0L,
      fields,
      keys
    )
    return(ledgr_snapshot_hash_section_finish(
      section_tag,
      total_rows,
      encoded$digest
    ))
  }

  result <- DBI::dbSendQuery(con, sql, params = params)
  on.exit(DBI::dbClearResult(result), add = TRUE)

  # At most one fixed logical block is retained. Preallocation avoids a
  # list-growing accumulator when a diagnostic fetch size is smaller than the
  # logical block.
  max_chunks <- as.integer(ceiling(
    block_rows / min(fetch_size, block_rows)
  ))
  pending <- vector("list", max_chunks)
  pending_count <- 0L
  pending_rows <- 0L
  emitted_blocks <- 0L
  seen_rows <- 0
  previous_last <- NULL

  emit_block <- function() {
    frame <- if (pending_count == 1L) {
      pending[[1L]]
    } else {
      do.call(rbind, pending[seq_len(pending_count)])
    }
    rownames(frame) <- NULL
    encoded <- ledgr_snapshot_hash_block(
      frame,
      section_tag,
      emitted_blocks,
      fields,
      keys,
      previous_last
    )
    digest_start <- emitted_blocks * 32L + 1L
    block_digests[digest_start:(digest_start + 31L)] <<- encoded$digest
    previous_last <<- encoded$last
    emitted_blocks <<- emitted_blocks + 1L
    seen_rows <<- seen_rows + nrow(frame)
    pending[seq_len(pending_count)] <<- list(NULL)
    pending_count <<- 0L
    pending_rows <<- 0L
    frame <- NULL
    invisible(NULL)
  }

  repeat {
    request <- min(fetch_size, block_rows - pending_rows)
    chunk <- DBI::dbFetch(result, n = request)
    if (!is.data.frame(chunk) || nrow(chunk) == 0L) break
    pending_count <- pending_count + 1L
    pending[[pending_count]] <- chunk
    pending_rows <- pending_rows + nrow(chunk)
    if (pending_rows > block_rows) {
      rlang::abort(
        "Snapshot hash query exceeded its fixed logical block.",
        class = c("ledgr_snapshot_hash_encoding_invalid", "ledgr_invalid_state")
      )
    }
    if (pending_rows == block_rows) emit_block()
  }
  if (pending_rows > 0L) emit_block()
  if (seen_rows != total_rows || emitted_blocks != expected_blocks) {
    rlang::abort(
      "Snapshot hash query row count changed during verification.",
      class = c("ledgr_snapshot_hash_encoding_invalid", "ledgr_invalid_state")
    )
  }
  ledgr_snapshot_hash_section_finish(
    section_tag,
    total_rows,
    block_digests
  )
}

ledgr_snapshot_hash_single_block_section <- function(frame, section_tag,
                                                     fields, keys) {
  encoded <- ledgr_snapshot_hash_block(
    frame,
    section_tag,
    0L,
    fields,
    keys
  )
  ledgr_snapshot_hash_section_finish(
    section_tag,
    nrow(frame),
    encoded$digest
  )
}

ledgr_snapshot_hash <- function(con, snapshot_id, chunk_size = 10000) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(snapshot_id) || length(snapshot_id) != 1L ||
      is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort(
      "`snapshot_id` must be a non-empty character scalar.",
      class = "ledgr_invalid_args"
    )
  }
  if (!is.numeric(chunk_size) || length(chunk_size) != 1L ||
      is.na(chunk_size) || !is.finite(chunk_size)) {
    rlang::abort(
      "`chunk_size` must be a finite numeric scalar.",
      class = "ledgr_invalid_args"
    )
  }
  chunk_size <- as.integer(chunk_size)
  if (chunk_size < 1L) {
    rlang::abort("`chunk_size` must be >= 1.", class = "ledgr_invalid_args")
  }
  fetch_size <- min(chunk_size, ledgr_snapshot_hash_block_rows)

  envelope <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT hash_rule_version,",
      "(SELECT COUNT(*) FROM snapshot_instruments i",
      " WHERE i.snapshot_id = snapshots.snapshot_id) AS instrument_rows,",
      "(SELECT COUNT(*) FROM snapshot_bars b",
      " WHERE b.snapshot_id = snapshots.snapshot_id) AS bar_rows,",
      ledgr_snapshot_availability_presence_sql(),
      "AS availability_rows",
      "FROM snapshots WHERE snapshot_id = ?"
    ),
    params = c(
      rep(
        list(snapshot_id),
        length(ledgr_snapshot_availability_tables())
      ),
      list(snapshot_id)
    )
  )
  if (nrow(envelope) != 1L) {
    rlang::abort(
      sprintf("Snapshot not found: %s", snapshot_id),
      class = "LEDGR_SNAPSHOT_NOT_FOUND"
    )
  }
  ledgr_snapshot_require_current_hash_rule(envelope$hash_rule_version[[1L]])

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

  instruments <- ledgr_snapshot_hash_stream_section(
    con,
    paste(
      "SELECT instrument_id, symbol, currency, asset_class,",
      "multiplier, tick_size, meta_json",
      "FROM snapshot_instruments",
      "WHERE snapshot_id = ? ORDER BY instrument_id"
    ),
    list(snapshot_id),
    envelope$instrument_rows[[1L]],
    1L,
    instrument_fields,
    "instrument_id",
    fetch_size
  )
  bars <- ledgr_snapshot_hash_stream_section(
    con,
    paste(
      "SELECT instrument_id, ts_utc, open, high, low, close, volume",
      "FROM snapshot_bars",
      "WHERE snapshot_id = ? ORDER BY instrument_id, ts_utc"
    ),
    list(snapshot_id),
    envelope$bar_rows[[1L]],
    2L,
    bar_fields,
    c("instrument_id", "ts_utc"),
    fetch_size
  )
  fact_frame <- data.frame(
    payload = as.character(ledgr_snapshot_availability_hash_payload(
      con,
      snapshot_id,
      has_rows = isTRUE(envelope$availability_rows[[1L]])
    )),
    stringsAsFactors = FALSE
  )
  facts <- ledgr_snapshot_hash_single_block_section(
    fact_frame,
    3L,
    c(payload = "json"),
    "payload"
  )

  ledgr_snapshot_hash_hex(ledgr_snapshot_hash_sha256(c(
    charToRaw("LEDGR-SNAPSHOT"),
    ledgr_snapshot_hash_u32_le(ledgr_snapshot_content_hash_rule_version),
    instruments,
    bars,
    facts
  )))
}

# The sealed hash as stored, without recomputing it.
ledgr_snapshot_stored_hash <- function(snapshot) {
  release <- ledgr_snapshot_hold(snapshot)
  on.exit(release(), add = TRUE)
  stored <- DBI::dbGetQuery(
    get_connection(snapshot),
    "SELECT snapshot_hash FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot$snapshot_id)
  )$snapshot_hash
  if (length(stored) != 1L || is.na(stored) || !nzchar(stored)) {
    rlang::abort(
      "Snapshot hash missing; snapshot may not be sealed.",
      class = "ledgr_invalid_snapshot"
    )
  }
  stored
}

ledgr_snapshot_validate <- function(snapshot) {
  ledgr_snapshot_ensure_handle(
    snapshot,
    force = TRUE,
    corruption_class = "ledgr_invalid_snapshot",
    corruption_message = "Snapshot hash mismatch; snapshot may be corrupted."
  )
  invisible(TRUE)
}
