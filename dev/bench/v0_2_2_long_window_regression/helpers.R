lwreg_script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(file_arg)) return(normalizePath(getwd(), winslash = "/"))
  dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/"))
}

lwreg_manifest <- function(script_dir = lwreg_script_dir()) {
  utils::read.csv(
    file.path(script_dir, "manifest.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

lwreg_shape <- function(shape_id, script_dir = lwreg_script_dir()) {
  manifest <- lwreg_manifest(script_dir)
  row <- manifest[manifest$shape_id == shape_id, , drop = FALSE]
  if (nrow(row) != 1L) stop("Unknown or duplicated shape: ", shape_id)
  row
}

lwreg_utc_token <- function(x) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

lwreg_session_dates <- function(n) {
  first <- as.Date("1998-01-05")
  civil <- seq(first, by = "day", length.out = ceiling(n * 7 / 5) + 14L)
  open <- as.POSIXlt(civil)$wday %in% 1:5
  civil[open][seq_len(n)]
}

lwreg_parse_gaps <- function(value) {
  if (is.na(value) || !nzchar(value) || identical(value, "none")) {
    return(data.frame(
      instrument_id = character(), length = integer(), start = integer()
    ))
  }
  parts <- strsplit(value, ";", fixed = TRUE)[[1L]]
  rows <- lapply(parts, function(part) {
    match <- regexec("^held:([^:]+):([0-9]+)@([0-9]+)$", part)
    fields <- regmatches(part, match)[[1L]]
    if (length(fields) != 4L) stop("Invalid gap declaration: ", part)
    data.frame(
      instrument_id = fields[[2L]],
      length = as.integer(fields[[3L]]),
      start = as.integer(fields[[4L]]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

lwreg_build_fixture <- function(row, out_dir) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  sessions_n <- as.integer(row$sessions)
  instruments_n <- as.integer(row$instruments)
  members_n <- as.integer(row$members)
  sets_n <- as.integer(row$sets)
  terminals_n <- as.integer(row$terminals)
  churn <- as.numeric(row$churn)
  dates <- lwreg_session_dates(sessions_n)
  ids <- sprintf("I%04d", seq_len(instruments_n))
  terminal_idx <- if (terminals_n) {
    seq.int(instruments_n - terminals_n + 1L, instruments_n)
  } else integer()
  eligible <- setdiff(seq_len(instruments_n), terminal_idx)
  if (members_n > length(eligible)) stop("Members exceed non-terminal pool")

  set.seed(1L)
  ret <- matrix(
    stats::rnorm(sessions_n * instruments_n, 0.0003, 0.02),
    nrow = sessions_n
  )
  close <- 100 * exp(apply(ret, 2L, cumsum))
  keep <- matrix(TRUE, nrow = sessions_n, ncol = instruments_n)

  current <- eligible[seq_len(members_n)]
  n_swap <- as.integer(round(churn * members_n))
  set_idx <- if (identical(row$profile, "orientation")) {
    1L + (seq_len(sets_n) - 1L) * (sessions_n %/% sets_n)
  } else {
    unique(as.integer(round(seq(1, sessions_n, length.out = sets_n))))
  }
  if (length(set_idx) != sets_n) stop("Membership set schedule collapsed")
  member_rows <- vector("list", sets_n)
  ever_member <- rep(FALSE, instruments_n)
  for (k in seq_len(sets_n)) {
    if (k > 1L && n_swap > 0L) {
      outside <- setdiff(eligible, current)
      swap_n <- min(n_swap, length(outside))
      if (swap_n > 0L) {
        if (identical(row$profile, "orientation")) {
          current[sample.int(length(current), swap_n)] <-
            outside[sample.int(length(outside), swap_n)]
        } else {
          replace_at <- sample.int(length(current), swap_n)
          current[replace_at] <- sample(outside, swap_n)
        }
      }
    }
    ever_member[current] <- TRUE
    at <- dates[set_idx[[k]]]
    member_rows[[k]] <- data.frame(
      instrument_id = ids[current],
      effective_from = as.POSIXct(paste(at, "00:00:00"), tz = "UTC"),
      knowledge_time = as.POSIXct(paste(at - 1, "00:00:00"), tz = "UTC"),
      source = "long_window_regression",
      stringsAsFactors = FALSE
    )
  }
  membership <- do.call(rbind, member_rows)

  publish <- as.POSIXct(paste(dates[[1L]] - 3, "00:00:00"), tz = "UTC")
  window_start <- as.POSIXct(paste(dates[[1L]], "00:00:00"), tz = "UTC")
  lifetime <- data.frame(
    instrument_id = ids,
    effective_from = window_start,
    effective_to = as.POSIXct(NA, tz = "UTC"),
    knowledge_time = publish,
    assertion = "known_active",
    source = "long_window_regression",
    stringsAsFactors = FALSE
  )
  terminal_ids <- character()
  if (terminals_n > 0L) {
    at <- as.integer(round(seq(sessions_n / 4, 3 * sessions_n / 4,
                               length.out = terminals_n)))
    terminal_ids <- ids[terminal_idx]
    for (j in seq_along(terminal_idx)) {
      keep[(at[[j]] + 1L):sessions_n, terminal_idx[[j]]] <- FALSE
    }
    end_at <- as.POSIXct(paste(dates[at + 1L], "00:00:00"), tz = "UTC")
    lifetime$effective_to[terminal_idx] <- end_at
    lifetime <- rbind(lifetime, data.frame(
      instrument_id = terminal_ids,
      effective_from = end_at,
      effective_to = as.POSIXct(NA, tz = "UTC"),
      knowledge_time = as.POSIXct(paste(dates[at], "00:00:00"), tz = "UTC"),
      assertion = "known_inactive",
      source = "long_window_regression",
      stringsAsFactors = FALSE
    ))
  }

  gaps <- lwreg_parse_gaps(row$gap_pattern)
  if (nrow(gaps)) {
    for (i in seq_len(nrow(gaps))) {
      column <- match(gaps$instrument_id[[i]], ids)
      rows <- seq.int(gaps$start[[i]],
                      gaps$start[[i]] + gaps$length[[i]] - 1L)
      if (is.na(column) || max(rows) > sessions_n) stop("Gap outside fixture")
      keep[rows, column] <- FALSE
    }
  }

  status <- data.frame(
    instrument_id = ids,
    effective_from = window_start,
    knowledge_time = publish,
    status = "active",
    source = "long_window_regression",
    stringsAsFactors = FALSE
  )
  civil <- seq(dates[[1L]], dates[[length(dates)]], by = "day")
  is_open <- civil %in% dates
  sessions <- data.frame(
    session_date = civil,
    status = ifelse(is_open, "open", "closed"),
    session_open = ifelse(is_open, "14:30:00", NA_character_),
    session_close = ifelse(is_open, "21:00:00", NA_character_),
    knowledge_time = publish,
    source = "long_window_regression",
    stringsAsFactors = FALSE
  )
  facts <- ledgr_facts(
    ledgr_facts_sessions(sessions, "SYNTH", timezone = "UTC"),
    ledgr_facts_membership_snapshots(
      membership, "synthetic_members", complete = TRUE
    ),
    ledgr_facts_trading_status(status),
    ledgr_facts_lifetime(lifetime)
  )

  ts <- as.POSIXct(paste(dates, "21:00:00"), tz = "UTC")
  cl <- as.vector(close)
  bars <- data.frame(
    ts_utc = rep(ts, times = instruments_n),
    instrument_id = rep(ids, each = sessions_n),
    open = cl,
    high = cl * 1.005,
    low = cl * 0.995,
    close = cl,
    volume = 1e5,
    stringsAsFactors = FALSE
  )[as.vector(keep), , drop = FALSE]
  db <- file.path(out_dir, "snapshot.duckdb")
  unlink(c(db, paste0(db, ".wal")))
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = ids),
    db_path = db,
    snapshot_id = paste0("lwreg_", row$shape_id),
    facts = facts
  )
  ledgr_snapshot_close(snapshot)

  probe <- list(
    shape_id = row$shape_id,
    sessions = sessions_n,
    instruments = instruments_n,
    members = members_n,
    membership_sets = sets_n,
    membership_rows = nrow(membership),
    churn = churn,
    terminals = terminals_n,
    terminal_ownership = row$terminal_ownership,
    terminal_member_overlap = length(intersect(terminal_ids, ids[ever_member])),
    gap_instruments = gaps$instrument_id,
    gap_lengths = gaps$length,
    gap_starts = gaps$start,
    gaps_within_budget = !nrow(gaps) || all(gaps$length <= row$stale_budget),
    bar_rows = nrow(bars),
    first_session = as.character(dates[[1L]]),
    last_session = as.character(dates[[length(dates)]]),
    features = row$features,
    expected_status = row$expected_status
  )
  jsonlite::write_json(
    probe, file.path(out_dir, "fixture_probe.json"),
    auto_unbox = TRUE, pretty = TRUE, null = "null"
  )
  invisible(probe)
}

lwreg_features <- function(value) {
  if (identical(value, "none")) return(list())
  tokens <- strsplit(value, "+", fixed = TRUE)[[1L]]
  lapply(tokens, function(token) {
    fields <- strsplit(token, "_", fixed = TRUE)[[1L]]
    n <- as.integer(fields[[length(fields)]])
    if (startsWith(token, "returns_")) return(ledgr_ind_returns(n))
    if (startsWith(token, "sma_")) return(ledgr_ind_sma(n))
    stop("Unknown feature token: ", token)
  })
}

lwreg_strategy <- function(name, timing) {
  function(ctx, params) {
    now <- proc.time()[["elapsed"]]
    if (is.null(timing$first)) timing$first <- now
    timing$last <- now
    timing$calls <- timing$calls + 1L
    seen <- if (is.null(ctx$state_prev$pulses_seen)) 0L else {
      as.integer(ctx$state_prev$pulses_seen)
    }
    update <- list(
      pulses_seen = seen + 1L,
      variant = if (is.null(params$variant)) 0L else as.integer(params$variant)
    )
    if (identical(name, "flat_state")) {
      return(list(targets = ctx$flat(), state_update = update))
    }
    if (identical(name, "hold_state")) {
      return(list(targets = ctx$hold(), state_update = update))
    }
    if (!identical(name, "momentum")) stop("Unknown strategy: ", name)
    month <- format(ledgr_utc(ctx$ts_utc), "%Y-%m", tz = "UTC")
    update$month <- month
    if (identical(ctx$state_prev$month, month)) {
      return(list(targets = ctx$hold(), state_update = update))
    }
    signal <- ctx$vec$feature("return_252")
    if (sum(is.finite(signal)) < 20L) {
      return(list(targets = ctx$hold(), state_update = update))
    }
    targets <- ctx |>
      ledgr_signal_return(lookback = 252) |>
      ledgr_select_top_n(10, partial = "allow") |>
      ledgr_weight_equal() |>
      ledgr_target_rebalance(ctx, equity_fraction = 0.95)
    list(targets = targets, state_update = update)
  }
}

lwreg_opening <- function(row) {
  gaps <- lwreg_parse_gaps(row$gap_pattern)
  held <- unique(gaps$instrument_id)
  if (!length(held)) return(ledgr_opening(cash = 1e6))
  positions <- stats::setNames(rep(10, length(held)), held)
  basis <- stats::setNames(rep(100, length(held)), held)
  ledgr_opening(cash = 1e6, positions = positions, cost_basis = basis)
}

lwreg_normalize_frame <- function(x, keep = NULL) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  if (!is.null(keep)) x <- x[, intersect(keep, names(x)), drop = FALSE]
  drop <- intersect(
    c("run_id", "event_id", "created_at_utc", "recorded_at_utc"),
    names(x)
  )
  if (length(drop)) x[drop] <- NULL
  for (name in names(x)) {
    if (inherits(x[[name]], "POSIXt")) x[[name]] <- lwreg_utc_token(x[[name]])
    if (inherits(x[[name]], "Date")) x[[name]] <- as.character(x[[name]])
  }
  rownames(x) <- NULL
  x
}

lwreg_hash <- function(x) {
  digest::digest(serialize(x, NULL, version = 3L), algo = "sha256")
}

lwreg_identity <- function(x, keep = NULL) {
  value <- lwreg_normalize_frame(x, keep)
  list(rows = nrow(value), hash = lwreg_hash(value))
}

lwreg_strategy_state_identity <- function(bt) {
  con <- DBI::dbConnect(duckdb::duckdb(), bt$db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  rows <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT ts_utc, state_json FROM strategy_state",
      "WHERE run_id = ? ORDER BY ts_utc"
    ),
    params = list(bt$run_id)
  )
  decoded <- lapply(rows$state_json, function(value) {
    jsonlite::fromJSON(value, simplifyVector = FALSE)
  })
  value <- Map(
    function(ts, state) list(ts_utc = lwreg_utc_token(ts), state = state),
    rows$ts_utc,
    decoded
  )
  list(rows = nrow(rows), hash = lwreg_hash(value))
}

lwreg_run_identities <- function(bt) {
  list(
    equity = lwreg_identity(ledgr_results(bt, "equity")),
    fills = lwreg_identity(ledgr_results(bt, "fills")),
    trades = lwreg_identity(ledgr_results(bt, "trades")),
    diagnostics = lwreg_identity(
      ledgr_results(bt, "diagnostics"),
      c("ts_utc", "instrument_id", "reason_code")
    ),
    strategy_state = lwreg_strategy_state_identity(bt)
  )
}

lwreg_experiment <- function(snapshot, row, timing = NULL) {
  if (is.null(timing)) {
    timing <- new.env(parent = emptyenv())
    timing$first <- NULL
    timing$last <- NULL
    timing$calls <- 0L
  }
  ledgr_experiment(
    snapshot,
    lwreg_strategy(row$strategy, timing),
    features = lwreg_features(row$features),
    universe = ledgr_universe_members("synthetic_members"),
    valuation_policy = ledgr_valuation_stale(as.integer(row$stale_budget)),
    opening = lwreg_opening(row),
    cost_model = ledgr_cost_zero(),
    persist_features = FALSE
  )
}

lwreg_elapsed <- function(code) {
  start <- proc.time()[["elapsed"]]
  value <- force(code)
  list(value = value, seconds = proc.time()[["elapsed"]] - start)
}

lwreg_snapshot_info <- function(snapshot) {
  info <- ledgr_snapshot_info(snapshot)
  list(
    snapshot_id = info$snapshot_id,
    snapshot_hash = info$snapshot_hash,
    status = info$status
  )
}

lwreg_sweep_identity <- function(x) {
  keep <- intersect(
    c("candidate_id", "status", "score", "completion_json"), names(x)
  )
  list(
    candidates = lwreg_identity(x[, keep, drop = FALSE]),
    returns = lwreg_identity(ledgr_sweep_returns(x))
  )
}
