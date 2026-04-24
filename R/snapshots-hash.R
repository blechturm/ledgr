ledgr_snapshot_hash <- function(con, snapshot_id, chunk_size = 10000) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort("`snapshot_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  if (!is.numeric(chunk_size) || length(chunk_size) != 1 || is.na(chunk_size) || !is.finite(chunk_size)) {
    rlang::abort("`chunk_size` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }
  chunk_size <- as.integer(chunk_size)
  if (chunk_size < 1L) {
    rlang::abort("`chunk_size` must be >= 1.", class = "ledgr_invalid_args")
  }

  exists <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$n[[1]] > 0
  if (!isTRUE(exists)) {
    rlang::abort(sprintf("Snapshot not found: %s", snapshot_id), class = "LEDGR_SNAPSHOT_NOT_FOUND")
  }

  fmt_ts_utc <- function(x) {
    if (inherits(x, "POSIXt")) {
      return(format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
    }
    if (is.character(x)) {
      return(x)
    }
    if (is.null(x) || (is.atomic(x) && length(x) == 1 && is.na(x))) {
      return(NA_character_)
    }
    as.character(x)
  }

  fmt_num <- function(x) {
    if (is.null(x)) return(NA_character_)
    if (is.atomic(x) && length(x) == 1 && is.na(x)) return(NA_character_)

    if (is.character(x)) {
      parsed <- suppressWarnings(as.numeric(x))
      if (!is.na(parsed) && is.finite(parsed)) {
        return(sprintf("%.8f", round(parsed, 8)))
      }
      return(x)
    }

    x <- as.numeric(x)
    if (is.na(x)) return(NA_character_)
    if (!is.finite(x)) {
      rlang::abort("Non-finite numeric encountered while hashing snapshot.", class = "ledgr_invalid_state")
    }
    sprintf("%.8f", round(x, 8))
  }

  token <- function(x) {
    if (is.null(x)) return("null")
    if (is.atomic(x) && length(x) == 1 && is.na(x)) return("NA")
    if (is.character(x)) return(x)
    as.character(x)
  }

  fmt_ts_utc_vec <- function(x) {
    if (inherits(x, "POSIXt")) {
      return(format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
    }
    if (is.character(x)) {
      return(x)
    }
    if (is.null(x)) {
      return(NA_character_)
    }
    as.character(x)
  }

  fmt_num_vec <- function(x) {
    if (is.null(x)) return(NA_character_)

    if (is.character(x)) {
      parsed <- suppressWarnings(as.numeric(x))
      out <- x
      ok <- !is.na(parsed) & is.finite(parsed)
      out[ok] <- sprintf("%.8f", round(parsed[ok], 8))
      out[is.na(out)] <- NA_character_
      return(out)
    }

    x_num <- as.numeric(x)
    bad <- !is.na(x_num) & !is.finite(x_num)
    if (any(bad)) {
      rlang::abort("Non-finite numeric encountered while hashing snapshot.", class = "ledgr_invalid_state")
    }
    out <- rep(NA_character_, length(x_num))
    ok <- !is.na(x_num)
    if (any(ok)) {
      out[ok] <- sprintf("%.8f", round(x_num[ok], 8))
    }
    out
  }

  token_vec <- function(x) {
    if (is.null(x)) return("null")
    out <- as.character(x)
    out[is.na(out)] <- "NA"
    out
  }

  hash_block_size <- 10000L

  hash_query_streaming <- function(sql, params, row_to_lines) {
    res <- DBI::dbSendQuery(con, sql, params = params)
    on.exit(DBI::dbClearResult(res), add = TRUE)

    block_hashes <- character(0)
    buffer <- character(0)
    repeat {
      chunk <- DBI::dbFetch(res, n = chunk_size)
      if (!is.data.frame(chunk) || nrow(chunk) == 0) break

      lines <- row_to_lines(chunk)

      if (length(buffer) == 0) {
        buffer <- lines
      } else {
        buffer <- c(buffer, lines)
      }

      while (length(buffer) >= hash_block_size) {
        block_lines <- buffer[seq_len(hash_block_size)]
        block_hashes <- c(block_hashes, digest::digest(paste0(block_lines, collapse = ""), algo = "sha256"))
        buffer <- buffer[-seq_len(hash_block_size)]
      }
    }

    if (length(buffer) > 0) {
      block_hashes <- c(block_hashes, digest::digest(paste0(buffer, collapse = ""), algo = "sha256"))
    }

    block_hashes
  }

  # Spec v0.1.1 section 7.3: per-chunk sha256, final = sha256(concat(chunk_hashes)).
  # Notes:
  # - `chunk_size` controls DB fetch size (performance), not the hashing block
  #   size. Hash blocks are always 10,000 rows so the output is invariant to
  #   `chunk_size` while keeping memory bounded.
  # - Combination rule: concatenate block-hashes from snapshot_instruments (in
  #   instrument_id order) followed by snapshot_bars (in instrument_id, ts_utc
  #   order), then sha256 over the concatenated string.
  # - The hash identifies the snapshot artifact contents only. The envelope
  #   row in `snapshots` is intentionally excluded so identical artifacts have
  #   the same hash across snapshot ids and metadata.
  inst_chunk_hashes <- hash_query_streaming(
    "
    SELECT instrument_id, symbol, currency, asset_class, multiplier, tick_size, meta_json
    FROM snapshot_instruments
    WHERE snapshot_id = ?
    ORDER BY instrument_id
    ",
    params = list(snapshot_id),
    row_to_lines = function(df) {
      lines <- paste(
        token_vec(df$instrument_id),
        token_vec(df$symbol),
        token_vec(df$currency),
        token_vec(df$asset_class),
        token_vec(fmt_num_vec(df$multiplier)),
        token_vec(fmt_num_vec(df$tick_size)),
        token_vec(df$meta_json),
        sep = "|"
      )
      paste0(lines, "\n")
    }
  )

  bars_chunk_hashes <- hash_query_streaming(
    "
    SELECT instrument_id, ts_utc, open, high, low, close, volume
    FROM snapshot_bars
    WHERE snapshot_id = ?
    ORDER BY instrument_id, ts_utc
    ",
    params = list(snapshot_id),
    row_to_lines = function(df) {
      lines <- paste(
        token_vec(df$instrument_id),
        token_vec(fmt_ts_utc_vec(df$ts_utc)),
        token_vec(fmt_num_vec(df$open)),
        token_vec(fmt_num_vec(df$high)),
        token_vec(fmt_num_vec(df$low)),
        token_vec(fmt_num_vec(df$close)),
        token_vec(fmt_num_vec(df$volume)),
        sep = "|"
      )
      paste0(lines, "\n")
    }
  )

  digest::digest(paste0(c(inst_chunk_hashes, bars_chunk_hashes), collapse = ""), algo = "sha256")
}

ledgr_snapshot_validate <- function(snapshot) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_snapshot")
  }

  con <- get_connection(snapshot)
  stored <- DBI::dbGetQuery(
    con,
    "SELECT snapshot_hash FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot$snapshot_id)
  )$snapshot_hash[[1]]
  if (is.null(stored) || is.na(stored) || !nzchar(stored)) {
    rlang::abort("Snapshot hash missing; snapshot may not be sealed.", class = "ledgr_invalid_snapshot")
  }

  computed <- ledgr_snapshot_hash(con, snapshot$snapshot_id)
  if (!identical(computed, stored)) {
    rlang::abort("Snapshot hash mismatch; snapshot may be corrupted.", class = "ledgr_invalid_snapshot")
  }

  invisible(TRUE)
}
