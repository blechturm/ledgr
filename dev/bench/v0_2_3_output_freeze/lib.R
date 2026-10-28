# A0 output freeze: shared library for record.R, check.R, gut.R and timing.R.
#
# Each workload builds a small synthetic snapshot through public constructors,
# runs it through the committed-run path (ledgr_run -> persistent output
# handler) and the sweep path (ledgr_sweep -> memory output handler), and
# returns every output table in canonical character form. Records are compared
# byte for byte, so formatting here is the oracle's precision.

a0_script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg) == 0L) return(normalizePath(getwd(), winslash = "/"))
  normalizePath(dirname(sub("^--file=", "", file_arg[[1L]])), winslash = "/")
}

a0_arg <- function(name, default = NULL) {
  args <- commandArgs(trailingOnly = TRUE)
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}

a0_load <- function() {
  pkg <- a0_arg("pkg", normalizePath(file.path(a0_script_dir(), "..", "..", ".."), winslash = "/"))
  suppressMessages(pkgload::load_all(pkg, quiet = TRUE))
  invisible(pkg)
}

# ---------------------------------------------------------------------------
# Canonical form
# ---------------------------------------------------------------------------

# Doubles use %.17g, which round-trips every IEEE double, so a one-ulp change
# is visible. Whole-second timestamps print as ISO UTC; any fractional
# timestamp falls back to its %.17g epoch value instead of being truncated.
a0_fmt_atomic <- function(x) {
  if (inherits(x, "POSIXct")) {
    n <- as.numeric(x)
    out <- format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    frac <- !is.na(n) & n != floor(n)
    out[frac] <- sprintf("%.17g", n[frac])
    out[is.na(n)] <- "NA"
    return(out)
  }
  if (inherits(x, "Date")) {
    out <- format(x, "%Y-%m-%d")
    out[is.na(x)] <- "NA"
    return(out)
  }
  if (is.factor(x)) x <- as.character(x)
  if (is.logical(x)) return(ifelse(is.na(x), "NA", ifelse(x, "TRUE", "FALSE")))
  if (is.integer(x)) return(ifelse(is.na(x), "NA", sprintf("%d", x)))
  if (is.double(x)) {
    out <- sprintf("%.17g", x)
    out[is.na(x) & !is.nan(x)] <- "NA"
    return(out)
  }
  if (is.character(x)) {
    out <- enc2utf8(x)
    out <- gsub("\r", "\\r", gsub("\n", "\\n", out, fixed = TRUE), fixed = TRUE)
    out[is.na(x)] <- "NA"
    return(out)
  }
  if (is.null(x)) return("NULL")
  stop(sprintf("a0: no canonical form for class %s", paste(class(x), collapse = "/")), call. = FALSE)
}

# Nested values (list columns, attributes) flatten to path=value pairs.
a0_flat <- function(x, prefix = "") {
  if (inherits(x, "condition")) {
    return(sprintf("%s<%s>%s", prefix, class(x)[[1L]], a0_fmt_atomic(conditionMessage(x))))
  }
  if (is.function(x)) return(sprintf("%s<function>", prefix))
  if (is.environment(x)) return(sprintf("%s<environment>", prefix))
  if (is.data.frame(x)) x <- as.list(x)
  if (is.list(x)) {
    if (length(x) == 0L) return(sprintf("%s[]", prefix))
    nm <- names(x)
    if (is.null(nm)) nm <- rep("", length(x))
    nm[!nzchar(nm)] <- sprintf("[%d]", which(!nzchar(nm)))
    parts <- unlist(Map(function(v, n) a0_flat(v, paste0(prefix, "/", n)), x, nm), use.names = FALSE)
    return(paste(parts, collapse = ";"))
  }
  vals <- if (length(x) == 0L) "" else paste(a0_fmt_atomic(x), collapse = ",")
  nm <- names(x)
  if (!is.null(nm) && length(x) > 0L) vals <- paste(paste0(nm, ":", a0_fmt_atomic(x)), collapse = ",")
  sprintf("%s=%s", prefix, vals)
}

a0_fmt_col <- function(x) {
  if (is.list(x) && !inherits(x, "POSIXlt")) return(vapply(x, a0_flat, character(1)))
  a0_fmt_atomic(x)
}

# Fields that legitimately vary between runs or environments. They are
# removed before canonical writing; the reason is written to the record.
a0_exclusions <- local({
  version <- "package version string; changes with a version bump, not with handler behavior"
  sweep_id <- "random sweep identifier drawn per call"
  rows <- list(
    c("runs", "created_at_utc", "wall clock at registration"),
    c("runs", "engine_version", version),
    c("run_provenance", "created_at_utc", "wall clock at registration"),
    c("run_provenance", "ledgr_version", version),
    c("run_provenance", "R_version", "R build of the host, not handler behavior"),
    c("run_provenance", "dependency_versions_json", "installed dependency versions of the host, not handler behavior"),
    c("run_telemetry", "elapsed_sec", "wall-clock telemetry"),
    c("run_telemetry", "updated_at_utc", "wall clock of the last telemetry write"),
    c("run_tags", "created_at_utc", "wall clock"),
    c("sweep", "t_engine", "wall-clock telemetry"),
    c("sweep", "t_results", "wall-clock telemetry"),
    c("sweep", "t_fills_extract", "wall-clock telemetry"),
    c("sweep_attrs", "sweep_id", sweep_id),
    c("sweep_returns", "sweep_id", sweep_id),
    c("sweep_trades", "sweep_id", sweep_id)
  )
  m <- do.call(rbind, rows)
  data.frame(table = m[, 1L], column = m[, 2L], reason = m[, 3L], stringsAsFactors = FALSE)
})

# Absolute temp paths are embedded in config JSON; replace them with a token.
a0_path_tokens <- new.env(parent = emptyenv())
a0_detokenize <- function(x) {
  if (!is.character(x)) return(x)
  # Separators may be stored as /, \ or JSON-escaped \\ in any mix.
  for (path in ls(a0_path_tokens)) {
    parts <- strsplit(path, "[/\\\\]+")[[1L]]
    parts <- gsub("([][{}()+*^$|?.\\\\])", "\\\\\\1", parts)
    x <- gsub(paste(parts, collapse = "[/\\\\]+"), a0_path_tokens[[path]], x, perl = TRUE)
  }
  x
}

# A canonical table: excluded columns dropped, rows ordered by a declared
# unique key (radix order, locale independent), every cell a string.
a0_canon <- function(df, table, key) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  drop <- a0_exclusions$column[a0_exclusions$table == table]
  df <- df[, setdiff(names(df), drop), drop = FALSE]
  missing <- setdiff(key, names(df))
  if (length(missing)) {
    stop(sprintf("a0: table %s lacks key column(s) %s; columns: %s", table,
      paste(missing, collapse = ","), paste(names(df), collapse = ",")), call. = FALSE)
  }
  if (nrow(df) > 0L) {
    ord <- do.call(order, c(unname(lapply(key, function(k) df[[k]])), list(method = "radix")))
    df <- df[ord, , drop = FALSE]
    if (anyDuplicated(df[, key, drop = FALSE])) stop(sprintf("a0: key (%s) is not unique in %s", paste(key, collapse = ","), table), call. = FALSE)
  }
  out <- lapply(df, function(col) a0_detokenize(a0_fmt_col(col)))
  out <- as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
  attr(out, "a0_key") <- key
  out
}

a0_csv_text <- function(df) {
  quote <- function(v) ifelse(v == "NA", "NA", paste0("\"", gsub("\"", "\"\"", v, fixed = TRUE), "\""))
  header <- paste(quote(names(df)), collapse = ",")
  if (nrow(df) == 0L) return(paste0(header, "\n"))
  body <- do.call(paste, c(unname(lapply(df, quote)), list(sep = ",")))
  paste0(paste(c(header, body), collapse = "\n"), "\n")
}

a0_write_table <- function(df, file) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  con <- file(file, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(enc2utf8(a0_csv_text(df))), con)
}

# Writes every canonical table of every workload under out_dir and a manifest
# with one SHA-256 per file. Returns the manifest.
a0_write_records <- function(results, out_dir) {
  files <- character()
  for (w in names(results)) for (p in names(results[[w]])) for (t in names(results[[w]][[p]])) {
    rel <- file.path(w, p, paste0(t, ".csv"))
    a0_write_table(results[[w]][[p]][[t]], file.path(out_dir, rel))
    files <- c(files, rel)
  }
  excl <- a0_canon(a0_exclusions, "exclusions", c("table", "column"))
  a0_write_table(excl, file.path(out_dir, "excluded_fields.csv"))
  files <- sort(c(files, "excluded_fields.csv"), method = "radix")
  manifest <- data.frame(
    file = files,
    bytes = vapply(file.path(out_dir, files), function(f) sprintf("%d", as.integer(file.size(f))), character(1)),
    sha256 = vapply(file.path(out_dir, files), function(f) digest::digest(file = f, algo = "sha256"), character(1)),
    stringsAsFactors = FALSE
  )
  a0_write_table(manifest, file.path(out_dir, "manifest.csv"))
  manifest
}

# ---------------------------------------------------------------------------
# Output collection per handler path
# ---------------------------------------------------------------------------

a0_run_keys <- list(
  runs = "run_id", run_provenance = "run_id", run_telemetry = "run_id",
  run_completion = "run_id", run_promotion_context = "run_id",
  run_tags = c("run_id", "tag"), ledger_events = c("run_id", "event_seq"),
  equity_curve = c("run_id", "ts_utc"), strategy_state = c("run_id", "ts_utc"),
  run_diagnostics = c("run_id", "diagnostic_seq")
)

# Every run-store table with a run_id column, rows of the given runs. A table
# the key list does not know fails loudly so a new output is never skipped.
a0_store_tables <- function(db_path, run_ids) {
  opened <- ledgr:::ledgr_run_store_open(db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  con <- opened$con
  tabs <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT table_name FROM information_schema.columns",
    "WHERE column_name = 'run_id' ORDER BY table_name"
  ))$table_name
  unknown <- setdiff(tabs, names(a0_run_keys))
  if (length(unknown)) stop(sprintf("a0: run-store table(s) without a declared key: %s", paste(unknown, collapse = ",")), call. = FALSE)
  marks <- paste(rep("?", length(run_ids)), collapse = ",")
  out <- lapply(tabs, function(t) {
    df <- DBI::dbGetQuery(con, sprintf("SELECT * FROM %s WHERE run_id IN (%s)", t, marks), params = as.list(run_ids))
    a0_canon(df, t, a0_run_keys[[t]])
  })
  stats::setNames(out, tabs)
}

# Public readers over a run: fills, closed trades, metrics, and warnings the
# run raised. Bound across runs with run_id.
a0_reader_tables <- function(snapshot, run_ids, warnings) {
  fills <- list(); trades <- list(); metrics <- list()
  for (id in run_ids) {
    bt <- ledgr_run_open(snapshot, id)
    f <- as.data.frame(ledgr_results(bt, "fills")); f$run_id <- rep(id, nrow(f))
    tr <- as.data.frame(ledgr_results(bt, "trades")); tr$run_id <- rep(id, nrow(tr))
    m <- tryCatch(unclass(ledgr_compute_metrics(bt)), error = function(e) list(metric_error = conditionMessage(e)))
    attributes(m) <- list(names = names(m))
    metrics[[id]] <- data.frame(run_id = id, metric = names(m), value = vapply(m, a0_flat, character(1)), stringsAsFactors = FALSE)
    fills[[id]] <- f; trades[[id]] <- tr
    close(bt)
  }
  bind <- function(x) do.call(rbind, unname(x))
  list(
    fills = a0_canon(bind(fills), "fills", c("run_id", "event_seq", "action")),
    trades = a0_canon(bind(trades), "trades", c("run_id", "event_seq", "action")),
    metrics = a0_canon(bind(metrics), "metrics", c("run_id", "metric")),
    run_warnings = a0_canon(warnings, "run_warnings", c("run_id", "seq"))
  )
}

a0_capture_warnings <- function(expr, run_id, sink) {
  withCallingHandlers(expr, warning = function(w) {
    n <- nrow(sink$rows) + 1L
    sink$rows <- rbind(sink$rows, data.frame(
      run_id = run_id, seq = n, class = class(w)[[1L]],
      message = conditionMessage(w), stringsAsFactors = FALSE
    ))
    invokeRestart("muffleWarning")
  })
}

a0_new_warning_sink <- function() {
  sink <- new.env(parent = emptyenv())
  sink$rows <- data.frame(run_id = character(), seq = integer(), class = character(), message = character(), stringsAsFactors = FALSE)
  sink
}

a0_sweep_tables <- function(sw) {
  df <- as.data.frame(sw)
  attrs <- attributes(sw)
  skip <- c("names", "row.names", "class", "sweep_returns", "sweep_trades", "ledgr_complete_names")
  attrs <- attrs[setdiff(names(attrs), skip)]
  attrs <- attrs[setdiff(names(attrs), a0_exclusions$column[a0_exclusions$table == "sweep_attrs"])]
  attr_df <- data.frame(attribute = names(attrs), value = vapply(attrs, a0_flat, character(1)), stringsAsFactors = FALSE)
  returns <- as.data.frame(ledgr_sweep_returns(sw))
  trades <- as.data.frame(ledgr_sweep_trades(sw))
  trades$seq <- stats::ave(seq_len(nrow(trades)), trades$candidate_id, FUN = seq_along)
  list(
    sweep = a0_canon(df, "sweep", "candidate_id"),
    sweep_attrs = a0_canon(attr_df, "sweep_attrs", "attribute"),
    sweep_returns = a0_canon(returns, "sweep_returns", c("candidate_id", "ts_utc")),
    sweep_trades = a0_canon(trades, "sweep_trades", c("candidate_id", "seq"))
  )
}

# Today-only observation of the memory handler's internal buffers (events
# and kept diagnostics). Used for the agreement report, never for records:
# WS1 removes this factory. Returns NULL when the factory is absent.
a0_with_memory_capture <- function(expr) {
  ns <- asNamespace("ledgr")
  name <- "ledgr_memory_output_handler"
  if (!exists(name, envir = ns, inherits = FALSE)) {
    return(list(value = force(expr), internal = NULL))
  }
  original <- get(name, envir = ns)
  registry <- new.env(parent = emptyenv())
  wrapped <- function(run_id, ...) {
    handler <- original(run_id, ...)
    registry[[run_id]] <- handler
    handler
  }
  unlockBinding(name, ns)
  assign(name, wrapped, envir = ns)
  on.exit({ assign(name, original, envir = ns); lockBinding(name, ns) }, add = TRUE)
  value <- force(expr)
  internal <- lapply(stats::setNames(ls(registry), ls(registry)), function(id) {
    h <- registry[[id]]
    list(events = as.data.frame(h$events()), diagnostics = h$diagnostics(), completion = h$completion())
  })
  list(value = value, internal = internal)
}

# ---------------------------------------------------------------------------
# Fixtures (synthetic; adapted from the parity tests named in inventory.md)
# ---------------------------------------------------------------------------

a0_sessions <- function(dates) {
  ledgr_facts_sessions(data.frame(
    session_date = dates, status = "open", session_open = "09:30:00", session_close = "16:00:00",
    knowledge_time = as.POSIXct(dates, tz = "UTC") - 1, stringsAsFactors = FALSE
  ), venue_id = "XNYS")
}

a0_dense_bars <- function() {
  dates <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:7
  rbind(
    data.frame(instrument_id = "AAA", ts_utc = dates,
      open = c(100, 101, 103, 102, 104, 107, 106, 108), high = c(101, 103, 104, 103, 106, 108, 108, 109),
      low = c(99, 100, 101, 101, 103, 106, 105, 107), close = c(100, 102, 103, 102, 105, 107, 106, 108),
      volume = 1000, stringsAsFactors = FALSE),
    data.frame(instrument_id = "BBB", ts_utc = dates,
      open = c(50, 51, 50, 49, 48, 50, 52, 51), high = c(51, 52, 51, 50, 49, 51, 53, 52),
      low = c(49, 50, 49, 48, 47, 49, 51, 50), close = c(50, 51, 50, 49, 48, 50, 52, 51),
      volume = 2000, stringsAsFactors = FALSE)
  )
}

a0_fx_dense_cost <- function(db_path) {
  snapshot <- ledgr_snapshot_from_df(a0_dense_bars(), db_path = db_path, snapshot_id = "a0_dense_cost")
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    day <- substr(ctx$ts_utc, 1L, 10L)
    if (identical(day, "2020-01-01")) {
      targets["AAA"] <- params$aaa_qty
      targets["BBB"] <- params$bbb_qty
    } else if (identical(day, "2020-01-03")) {
      targets["AAA"] <- params$aaa_partial_qty
    } else if (identical(day, "2020-01-05") && isTRUE(params$close_day5)) {
      targets["AAA"] <- 0
      targets["BBB"] <- 0
    } else if (identical(day, "2020-01-08")) {
      targets["AAA"] <- params$last_bar_qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 10000),
    universe = c("AAA", "BBB"),
    cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1)))
  grid <- ledgr_grid_named(
    flat = list(strategy = list(aaa_qty = 0, aaa_partial_qty = 0, bbb_qty = 0, close_day5 = TRUE, last_bar_qty = 0)),
    partial = list(strategy = list(aaa_qty = 4, aaa_partial_qty = 2, bbb_qty = 2, close_day5 = TRUE, last_bar_qty = 0)),
    open_end = list(strategy = list(aaa_qty = 1, aaa_partial_qty = 1, bbb_qty = 0, close_day5 = FALSE, last_bar_qty = 3))
  )
  # ledgr_backtest() arguments for the db_live persistent mode (live writes).
  backtest <- list(snapshot = snapshot, strategy = strategy, universe = c("AAA", "BBB"), initial_cash = 10000,
    cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1)), execution_mode = "db_live")
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 2591L, backtest = backtest)
}

a0_fx_dense_risk_features <- function(db_path) {
  snapshot <- ledgr_snapshot_from_df(a0_dense_bars(), db_path = db_path, snapshot_id = "a0_dense_risk_features")
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    sma <- ctx$feature("AAA", "sma_3")
    targets["AAA"] <- if (!is.na(sma) && ctx$close("AAA") > sma) params$qty else 0
    if (!is.null(ctx$pulse_seed) && (ctx$pulse_seed %% 2L) == 0L) targets["BBB"] <- params$qty_b
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy,
    features = list(ledgr_ind_sma(3)),
    opening = ledgr_opening(cash = 10000, positions = c(AAA = 5), cost_basis = c(AAA = 99)),
    universe = c("AAA", "BBB"),
    risk_chain = ledgr_risk_chain(ledgr_risk_long_only(), ledgr_risk_max_weight(ledgr_param("cap"))),
    cost_model = ledgr_cost_spread_bps(10),
    metric_context = ledgr_metric_context(risk_free_rate = ledgr_risk_free_rate(0.04, label = "a0 policy")))
  grid <- ledgr_grid_named(
    tight = list(strategy = list(qty = 30, qty_b = 40, cap = 0.3)),
    loose = list(strategy = list(qty = 30, qty_b = -5, cap = 0.6))
  )
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 77L)
}

a0_fx_dense_dividend_state <- function(db_path) {
  ts <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
  bars <- data.frame(instrument_id = "AAA", ts_utc = ts, open = c(100, 90, 45, 46),
    high = c(100, 90, 45, 46), low = c(100, 90, 45, 46), close = c(100, 90, 45, 46),
    volume = 1000, stringsAsFactors = FALSE)
  dividend <- data.frame(fact_id = "dividend-1", subtype = "ordinary_cash_dividend",
    parent_instrument_id = "AAA", entitlement_time = ts[[2L]], effective_time = ts[[4L]],
    knowledge_time = ts[[1L]], complete = TRUE, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 1.25, gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE,
    source = "a0_fixture", stringsAsFactors = FALSE)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "a0_dense_dividend_state",
    facts = ledgr_facts(ledgr_facts_equity_corporate_actions(dividend)), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1L, 10L), "2020-01-02")) targets["AAA"] <- params$qty
    list(targets = targets, state_update = list(observed_cash = ctx$cash))
  }
  exp <- ledgr_experiment(snapshot, strategy,
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2), cost_basis = c(AAA = 100)),
    cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(hold = list(strategy = list(qty = 2)), add = list(strategy = list(qty = 5)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 11L)
}

a0_fx_avail_terminal_resume <- function(db_path) {
  day <- function(d) as.POSIXct(paste(as.Date("2020-01-01") + d - 1L, "16:00:00"), tz = "UTC")
  closes <- list(AAA = c(100, NA, NA, NA, 90, 91), BBB = c(50, NA, NA, NA, NA, NA), CLK = rep(10, 6L))
  bars <- do.call(rbind, lapply(names(closes), function(id) {
    keep <- which(!is.na(closes[[id]])); cl <- closes[[id]][keep]
    data.frame(ts_utc = day(keep), instrument_id = id, open = cl, high = cl + 1, low = cl - 1,
      close = cl, volume = 1000, stringsAsFactors = FALSE)
  }))
  lifetime <- ledgr_facts_lifetime(data.frame(instrument_id = "BBB", effective_from = day(5L),
    knowledge_time = day(5L) - 1, assertion = "known_inactive", terminal_event = "bankruptcy",
    stringsAsFactors = FALSE))
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = names(closes)),
    db_path = db_path, snapshot_id = "a0_avail_terminal_resume",
    facts = ledgr_facts(a0_sessions(as.Date("2020-01-01") + 0:5), lifetime), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    if (isTRUE(params$interrupt) && identical(ctx$ts_utc, "2020-01-03T16:00:00Z")) {
      options(ledgr.interrupt = TRUE)
    }
    target <- ctx$hold()
    if (ctx$ts_utc >= "2020-01-03T16:00:00Z" && "AAA" %in% names(target)) target[["AAA"]] <- 0
    target
  }
  exp <- ledgr_experiment(snapshot, strategy,
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2, BBB = 4), cost_basis = c(AAA = 100, BBB = 100)),
    valuation_policy = ledgr_valuation_stale(1), corporate_action_policy = ledgr_corporate_actions_research(),
    cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(straight = list(strategy = list(interrupt = FALSE)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 169L)
}

a0_fx_avail_acquisition <- function(db_path) {
  dates <- as.Date("2020-01-01") + 0:2
  pulses <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = pulses, open = c(100, 90, 91), high = c(100, 90, 91),
      low = c(100, 90, 91), close = c(100, 90, 91), volume = 1000),
    data.frame(instrument_id = "BBB", ts_utc = pulses, open = c(49, 50, 51), high = c(49, 50, 51),
      low = c(49, 50, 51), close = c(49, 50, 51), volume = 1000))
  lifetime <- ledgr_facts_lifetime(data.frame(instrument_id = "AAA", effective_from = pulses[[2L]],
    knowledge_time = pulses[[2L]] - 1, assertion = "known_inactive", terminal_event = "acquired",
    stringsAsFactors = FALSE))
  action <- ledgr_facts_equity_corporate_actions(data.frame(fact_id = "a0-acquisition",
    subtype = "cash_acquisition", parent_instrument_id = "AAA", entitlement_time = pulses[[2L]],
    effective_time = pulses[[2L]], knowledge_time = pulses[[1L]], complete = TRUE,
    provenance_tier = "snapshot_bound", gross_cash_per_parent_unit = 120, gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE, stringsAsFactors = FALSE))
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    db_path = db_path, snapshot_id = "a0_avail_acquisition",
    facts = ledgr_facts(a0_sessions(dates), lifetime, action), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(ctx$ts_utc, "2020-01-01T16:00:00Z")) target[["BBB"]] <- params$qty
    target
  }
  exp <- ledgr_experiment(snapshot, strategy,
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2), cost_basis = c(AAA = 100)),
    valuation_policy = ledgr_valuation_stale(1L), cost_model = ledgr_cost_zero(),
    corporate_action_policy = ledgr_corporate_actions_research())
  grid <- ledgr_grid_named(none = list(strategy = list(qty = 0)), some = list(strategy = list(qty = 3)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 54L)
}

a0_fx_avail_incomplete <- function(db_path) {
  dates <- as.Date("2020-01-01") + 0:3
  bar_days <- c(1L, 2L, 4L)
  bars <- data.frame(ts_utc = as.POSIXct(paste(dates[bar_days], "16:00:00"), tz = "UTC"),
    instrument_id = "AAA", open = 100 + bar_days, high = 101 + bar_days, low = 99 + bar_days,
    close = 100 + bar_days, volume = 1000, stringsAsFactors = FALSE)
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = "AAA"),
    db_path = db_path, snapshot_id = "a0_avail_incomplete",
    facts = ledgr_facts(a0_sessions(dates)), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[["AAA"]] <- params$qty
    target
  }
  exp <- ledgr_experiment(snapshot, strategy,
    valuation_policy = ledgr_valuation_stale(0, exhausted = "refuse"), cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(one = list(strategy = list(qty = 1)), two = list(strategy = list(qty = 2)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 31L)
}

a0_fx_walk_forward <- function(db_path) {
  dates <- as.Date("2020-01-01") + 0:9
  make_bars <- function(id, keep, offset) {
    data.frame(instrument_id = id, ts_utc = as.POSIXct(paste(dates[keep], "16:00:00"), tz = "UTC"),
      open = 100 + offset + keep, high = 101 + offset + keep, low = 99 + offset + keep,
      close = 100 + offset + keep, volume = 1000, stringsAsFactors = FALSE)
  }
  bars <- rbind(make_bars("AAA", setdiff(1:10, 5L), 0), make_bars("BBB", setdiff(1:10, 8L), 20))
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    db_path = db_path, snapshot_id = "a0_walk_forward",
    facts = ledgr_facts(a0_sessions(dates)), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[["BBB"]] <- params$qty
    target
  }
  exp <- ledgr_experiment(snapshot, strategy, universe = c("AAA", "BBB"),
    opening = ledgr_opening(cash = 10000, positions = c(AAA = 1, BBB = 1), cost_basis = c(AAA = 101, BBB = 121)),
    valuation_policy = ledgr_valuation_stale(3, exhausted = "refuse"), cost_model = ledgr_cost_fixed_fee(0.5))
  grid <- ledgr_grid_named(small = list(strategy = list(qty = 2)), large = list(strategy = list(qty = 4)))
  folds <- ledgr:::ledgr_fold_list(list(
    ledgr_fold("2020-01-01T16:00:00Z", "2020-01-03T16:00:00Z", "2020-01-04T16:00:00Z", "2020-01-06T16:00:00Z", fold_seq = 1L),
    ledgr_fold("2020-01-04T16:00:00Z", "2020-01-06T16:00:00Z", "2020-01-07T16:00:00Z", "2020-01-10T16:00:00Z", fold_seq = 2L)
  ), constructor = list(type_id = "explicit"))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 24L, folds = folds)
}

# ---------------------------------------------------------------------------
# Workloads
# ---------------------------------------------------------------------------

a0_workloads <- list(
  dense_cost = list(fixture = a0_fx_dense_cost, paths = c("run", "run_db_live", "sweep_w1", "sweep_w2", "sweep_compiled"),
    why = "parity-suite base case: two instruments, cost chain (spread + fixed fee), flat/partial/open-end candidates, last-bar no-fill warning; one and two workers; compiled spot-FIFO memory path; db_live persistent mode via ledgr_backtest()"),
  dense_risk_features = list(fixture = a0_fx_dense_risk_features, paths = c("run", "sweep_w1", "sweep_w2"),
    why = "risk chain (long_only + max_weight with a grid parameter), SMA feature warmup, opening lot, pulse_seed-driven targets, non-default metric context"),
  dense_dividend_state = list(fixture = a0_fx_dense_dividend_state, paths = c("run", "sweep_w1"),
    why = "dense mode corporate action (ordinary cash dividend posting CASHFLOW) and strategy_state writes via state_update"),
  avail_terminal_resume = list(fixture = a0_fx_avail_terminal_resume, paths = c("run", "run_resumed", "sweep_w1", "sweep_w2"),
    why = "availability mode: stale-mark freeze, bankruptcy terminal write-off (DISPOSITION), diagnostics and completion; ledgr.interrupt soft stop then resume; one and two workers"),
  avail_acquisition = list(fixture = a0_fx_avail_acquisition, paths = c("run", "sweep_w1"),
    why = "availability mode cash acquisition: held terminal position disposed at the deal price"),
  avail_incomplete = list(fixture = a0_fx_avail_incomplete, paths = c("run", "sweep_w1", "sweep_w2"),
    why = "availability INCOMPLETE terminal outcome (valuation horizon exhausted): completion evidence and stopped diagnostics; one and two workers"),
  walk_forward = list(fixture = a0_fx_walk_forward, paths = c("run", "sweep_w1", "walk_forward"),
    why = "walk-forward: train sweeps (memory) and carried test runs (persistent) on a gapped session calendar with fees")
)

a0_retain <- function() ledgr_sweep_retention(returns = "completed", trades = "closed")

a0_run_id <- function(workload, candidate_id, suffix = NULL) {
  paste(c("a0", workload, candidate_id, suffix), collapse = "-")
}

# Runs one workload through its handler paths. `gut` (see a0_guts) corrupts
# raw product output before canonicalization: `store(con, run_ids)` edits the
# run store after the committed runs, `sweep(sw)` edits the sweep result.
# Internal memory buffers come back separately and never enter records.
a0_run_workload <- function(id, work_dir, gut = NULL) {
  w <- a0_workloads[[id]]
  paths <- w$paths
  if (!is.null(gut) && !identical(gut$workload, id)) gut <- NULL
  db_path <- file.path(work_dir, paste0(id, ".duckdb"))
  if (file.exists(db_path)) unlink(db_path)
  assign(normalizePath(db_path, winslash = "/", mustWork = FALSE), "<DB_PATH>", envir = a0_path_tokens)
  fx <- w$fixture(db_path)
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  out <- list()
  options(ledgr.interrupt = FALSE)
  captured <- a0_with_memory_capture(ledgr_sweep(fx$exp, fx$grid, seed = fx$seed, retain = a0_retain()))
  sw <- captured$value
  out$sweep_w1 <- a0_sweep_tables(if (is.function(gut$sweep)) gut$sweep(sw) else sw)
  if ("sweep_w2" %in% paths) {
    out$sweep_w2 <- a0_sweep_tables(ledgr_sweep(fx$exp, fx$grid, seed = fx$seed, retain = a0_retain(), workers = 2L))
  }
  if ("sweep_compiled" %in% paths) {
    out$sweep_compiled <- a0_sweep_tables(ledgr_sweep(fx$exp, fx$grid, seed = fx$seed, retain = a0_retain(),
      compiled_accounting_model = "spot_fifo"))
  }
  if ("run" %in% paths) {
    sink <- a0_new_warning_sink()
    run_ids <- character()
    # Candidate rows are read directly: ledgr_candidate() refuses INCOMPLETE
    # rows, which this harness must still run.
    for (i in seq_len(nrow(sw))) {
      cid <- as.character(sw$candidate_id[[i]])
      rid <- a0_run_id(id, cid)
      bt <- a0_capture_warnings(ledgr_run(fx$exp, params = sw$params[[i]], feature_params = sw$feature_params[[i]],
        run_id = rid, seed = sw$execution_seed[[i]]), rid, sink)
      close(bt)
      run_ids <- c(run_ids, rid)
    }
    if (is.function(gut$store)) a0_with_store(db_path, function(con) gut$store(con, run_ids))
    out$run <- c(a0_store_tables(db_path, run_ids), a0_reader_tables(fx$snapshot, run_ids, sink$rows))
  }
  if ("run_db_live" %in% paths) {
    sink <- a0_new_warning_sink()
    live_ids <- character()
    for (i in seq_len(nrow(sw))) {
      rid <- a0_run_id(id, as.character(sw$candidate_id[[i]]), "db_live")
      args <- c(fx$backtest, list(strategy_params = sw$params[[i]], run_id = rid))
      bt <- a0_capture_warnings(do.call(ledgr_backtest, args), rid, sink)
      close(bt)
      live_ids <- c(live_ids, rid)
    }
    out$run_db_live <- c(a0_store_tables(db_path, live_ids), a0_reader_tables(fx$snapshot, live_ids, sink$rows))
  }
  if ("run_resumed" %in% paths) {
    sink <- a0_new_warning_sink()
    params <- utils::modifyList(sw$params[[1L]], list(interrupt = TRUE))
    rid <- a0_run_id(id, "resumed")
    for (attempt in 1:2) {
      bt <- a0_capture_warnings(ledgr_run(fx$exp, params = params, run_id = rid, seed = sw$execution_seed[[1L]]), rid, sink)
      close(bt)
      options(ledgr.interrupt = FALSE)
    }
    out$run_resumed <- c(a0_store_tables(db_path, rid), a0_reader_tables(fx$snapshot, rid, sink$rows))
  }
  if ("walk_forward" %in% paths) {
    wf <- ledgr_walk_forward(fx$exp, grid = fx$grid, folds = fx$folds,
      selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = fx$seed)
    test_ids <- vapply(wf$test_runs, function(bt) bt$run_id, character(1))
    lapply(wf$test_runs, close)
    out$walk_forward <- c(
      list(
        wf_folds = a0_canon(as.data.frame(wf$folds), "wf_folds", "fold_seq"),
        wf_scores = a0_canon(as.data.frame(wf$scores), "wf_scores", c("fold_seq", "window", "candidate_key", "metric_name")),
        wf_status = a0_canon(data.frame(status = wf$status, test_run_ids = paste(test_ids, collapse = ","),
          stringsAsFactors = FALSE), "wf_status", "status")
      ),
      a0_store_tables(db_path, test_ids),
      a0_reader_tables(fx$snapshot, test_ids, a0_new_warning_sink()$rows)
    )
  }
  list(tables = out, internal = captured$internal)
}

a0_run_all <- function(work_dir, gut = NULL, ids = names(a0_workloads)) {
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  res <- lapply(stats::setNames(ids, ids), function(id) a0_run_workload(id, work_dir, gut = gut))
  list(tables = lapply(res, `[[`, "tables"), internal = lapply(res, `[[`, "internal"))
}

a0_with_store <- function(db_path, fn) {
  opened <- ledgr:::ledgr_run_store_open(db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  fn(opened$con)
}

# ---------------------------------------------------------------------------
# Gut corruptions (gut.R): each edits raw product output the way a regressed
# handler would have written it, before the harness canonicalizes anything.
# ---------------------------------------------------------------------------

a0_next_ulp <- function(x) x + 2^(floor(log2(abs(x))) - 52)

a0_guts <- list(
  fill_qty = list(workload = "dense_cost", expect = "ledger_events",
    what = "one FILL quantity in ledger_events increased by 1 share (partial candidate, first fill)",
    store = function(con, run_ids) {
      DBI::dbExecute(con, paste(
        "UPDATE ledger_events SET qty = qty + 1 WHERE run_id = ? AND event_seq =",
        "(SELECT MIN(event_seq) FROM ledger_events WHERE run_id = ? AND event_type = 'FILL')"
      ), params = list("a0-dense_cost-partial", "a0-dense_cost-partial"))
    }),
  equity_ulp = list(workload = "dense_risk_features", expect = "equity_curve",
    what = "one equity_curve equity value moved by one unit in the last place",
    store = function(con, run_ids) {
      row <- DBI::dbGetQuery(con, "SELECT ts_utc, equity FROM equity_curve WHERE run_id = ? ORDER BY ts_utc LIMIT 1 OFFSET 4",
        params = list(run_ids[[1L]]))
      DBI::dbExecute(con, "UPDATE equity_curve SET equity = ? WHERE run_id = ? AND ts_utc = ?",
        params = list(a0_next_ulp(row$equity[[1L]]), run_ids[[1L]], row$ts_utc[[1L]]))
    }),
  drop_diagnostic = list(workload = "avail_terminal_resume", expect = "run_diagnostics",
    what = "one run_diagnostics row deleted",
    store = function(con, run_ids) {
      DBI::dbExecute(con, paste(
        "DELETE FROM run_diagnostics WHERE run_id = ? AND diagnostic_seq =",
        "(SELECT MIN(diagnostic_seq) + 5 FROM run_diagnostics WHERE run_id = ?)"
      ), params = list(run_ids[[1L]], run_ids[[1L]]))
    }),
  swap_events = list(workload = "dense_dividend_state", expect = "ledger_events",
    what = "two adjacent ledger events (dividend CASHFLOW, FILL) written in swapped order",
    store = function(con, run_ids) {
      rid <- "a0-dense_dividend_state-add"
      rows <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ? AND event_seq IN (2, 3) ORDER BY event_seq",
        params = list(rid))
      rows$event_seq <- rev(rows$event_seq)
      DBI::dbExecute(con, "DELETE FROM ledger_events WHERE run_id = ? AND event_seq IN (2, 3)", params = list(rid))
      DBI::dbAppendTable(con, "ledger_events", rows)
    }),
  sweep_return_ulp = list(workload = "dense_cost", expect = "sweep_returns",
    what = "memory path: one retained sweep equity value moved by one unit in the last place",
    sweep = function(sw) {
      returns <- attr(sw, "sweep_returns")
      i <- which(returns$candidate_id == "partial")[[3L]]
      returns$equity[[i]] <- a0_next_ulp(returns$equity[[i]])
      attr(sw, "sweep_returns") <- returns
      sw
    })
)
