# A0 output freeze: shared library for record.R, check.R, gut.R and timing.R.
#
# Each workload builds a small synthetic snapshot through public constructors,
# runs it through the committed-run path (ledgr_run -> persistent output
# handler) and the sweep path (ledgr_sweep -> memory output handler), and
# returns every output table in canonical character form. Records are compared
# byte for byte, so formatting here is the oracle's precision. Fixtures live in
# fixtures.R, corruptions for gut.R in guts.R.

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

# Missing values stay NA_character_ through formatting and are written as an
# unquoted NA; every present value is written quoted, so literal text "NA"
# stays distinct from SQL NULL. Doubles use %.17g, which round-trips every
# IEEE double, so a one-ulp change is visible. Whole-second timestamps print
# as ISO UTC; a fractional timestamp prints its %.17g epoch value. Text
# escapes backslash first, then newline and carriage return.
a0_fmt_atomic <- function(x) {
  if (is.factor(x)) x <- as.character(x)
  miss <- is.na(x)
  if (is.double(x)) miss <- miss & !is.nan(unclass(x))
  out <- if (inherits(x, "POSIXct")) {
    n <- as.numeric(x)
    o <- format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    frac <- !is.na(n) & n != floor(n)
    o[frac] <- sprintf("%.17g", n[frac])
    o
  } else if (inherits(x, "Date")) {
    format(x, "%Y-%m-%d")
  } else if (is.logical(x)) {
    ifelse(x, "TRUE", "FALSE")
  } else if (is.integer(x)) {
    sprintf("%d", x)
  } else if (is.double(x)) {
    sprintf("%.17g", x)
  } else if (is.character(x)) {
    o <- gsub("\\", "\\\\", enc2utf8(x), fixed = TRUE)
    gsub("\r", "\\r", gsub("\n", "\\n", o, fixed = TRUE), fixed = TRUE)
  } else {
    stop(sprintf("a0: no canonical form for class %s", paste(class(x), collapse = "/")), call. = FALSE)
  }
  out <- as.character(out)
  out[miss] <- NA_character_
  out
}

# Nested values (list columns, attributes) use a prefix-free encoding, so
# distinct structures can never share bytes:
#   string    <nchar>:<text>, or ~ when missing (no escaping needed)
#   NULL      N         function F        environment E
#   condition C(<classes><message>)
#   atomic    A<class>[n](<entries>)      list  L<class>[n](<entries>)
#   entry     @<name><value> when the object has names, #<value> in a list
#             without names, <value> in an atomic vector without names.
# Every list boundary is explicit and every name is length-prefixed, so
# list(a = list(b = 1)), list("a/b" = 1), list(1) and list("[1]" = 1) differ.
a0_str <- function(s) ifelse(is.na(s), "~", paste0(nchar(s, type = "chars"), ":", s))

a0_flat <- function(x) {
  if (inherits(x, "condition")) {
    return(paste0("C(", a0_str(paste(class(x), collapse = "/")), a0_str(a0_fmt_atomic(conditionMessage(x))), ")"))
  }
  if (is.null(x)) return("N")
  if (is.function(x)) return("F")
  if (is.environment(x)) return("E")
  cls <- a0_str(class(x)[[1L]])
  if (is.list(x)) {
    items <- if (is.data.frame(x)) as.list(x) else unclass(x)
    keys <- if (is.null(names(items))) rep("#", length(items)) else paste0("@", a0_str(a0_fmt_atomic(names(items))))
    vals <- vapply(items, a0_flat, character(1), USE.NAMES = FALSE)
    return(paste0("L", cls, "[", length(items), "](", paste0(keys, vals, collapse = ""), ")"))
  }
  keys <- if (is.null(names(x))) "" else paste0("@", a0_str(a0_fmt_atomic(names(x))))
  paste0("A", cls, "[", length(x), "](", paste0(keys, a0_str(a0_fmt_atomic(x)), collapse = ""), ")")
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
  size <- "object.size() of serialized worker payloads: R representation and transport detail, not handler output"
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
    c("sweep_trades", "sweep_id", sweep_id),
    c("sweep_attrs", "staged_invariant_bytes", size),
    c("sweep_attrs", "staged_payload_census", size)
  )
  m <- do.call(rbind, rows)
  data.frame(table = m[, 1L], column = m[, 2L], reason = m[, 3L], stringsAsFactors = FALSE)
})

# Text normalization applied to every string cell: absolute temp DB paths
# become <DB_PATH>; source references that rlang appends to error messages
# ("at R/file.R:30:5:") become <SRCREF> because they move with any product
# edit and name the worktree, not handler behavior.
a0_path_tokens <- new.env(parent = emptyenv())
a0_detokenize <- function(x) {
  if (!is.character(x)) return(x)
  # Separators may be stored as /, \ or JSON-escaped \\ in any mix.
  for (path in ls(a0_path_tokens)) {
    parts <- strsplit(path, "[/\\\\]+")[[1L]]
    parts <- gsub("([][{}()+*^$|?.\\\\])", "\\\\\\1", parts)
    x <- gsub(paste(parts, collapse = "[/\\\\]+"), a0_path_tokens[[path]], x, perl = TRUE)
  }
  gsub(" at [^ \"]+[.][Rr]:[0-9]+(:[0-9]+)?:", " at <SRCREF>:", x, perl = TRUE)
}

# A canonical table: excluded columns dropped, rows ordered by a declared
# unique key (radix order, locale independent), every cell a string or NA,
# column classes kept for the header.
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
  types <- vapply(df, function(col) paste(class(col), collapse = "/"), character(1))
  out <- lapply(df, function(col) a0_detokenize(a0_fmt_col(col)))
  out <- as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
  attr(out, "a0_types") <- unname(types)
  out
}

a0_csv_text <- function(df) {
  quote <- function(v) ifelse(is.na(v), "NA", paste0("\"", gsub("\"", "\"\"", v, fixed = TRUE), "\""))
  heads <- names(df)
  types <- attr(df, "a0_types")
  if (!is.null(types)) heads <- paste0(heads, ":", types)
  header <- paste(quote(heads), collapse = ",")
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
# Persistent output: run store and public readers
# ---------------------------------------------------------------------------

a0_run_keys <- list(
  runs = "run_id", run_provenance = "run_id", run_telemetry = "run_id",
  run_completion = "run_id", run_promotion_context = "run_id",
  run_tags = c("run_id", "tag"), ledger_events = c("run_id", "event_seq"),
  equity_curve = c("run_id", "ts_utc"), strategy_state = c("run_id", "ts_utc"),
  run_diagnostics = c("run_id", "diagnostic_seq")
)

a0_with_store <- function(db_path, fn) {
  opened <- ledgr:::ledgr_run_store_open(db_path)
  on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
  fn(opened$con)
}

# Every run-store table with a run_id column, rows of the given runs. A table
# the key list does not know fails loudly so a new output is never skipped.
a0_store_tables <- function(db_path, run_ids) {
  a0_with_store(db_path, function(con) {
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
  })
}

# Public readers over completed runs: fills, closed trades and metrics. Bound
# across runs with run_id.
a0_reader_tables <- function(snapshot, run_ids) {
  fills <- list(); trades <- list(); metrics <- list()
  for (id in run_ids) {
    bt <- ledgr_run_open(snapshot, id)
    f <- as.data.frame(ledgr_results(bt, "fills")); f$run_id <- rep(id, nrow(f))
    tr <- as.data.frame(ledgr_results(bt, "trades")); tr$run_id <- rep(id, nrow(tr))
    m <- tryCatch(unclass(ledgr_compute_metrics(bt)), error = function(e) e)
    metrics[[id]] <- if (inherits(m, "error")) {
      data.frame(run_id = id, metric = "<error>", value = NA_real_, error = conditionMessage(m), stringsAsFactors = FALSE)
    } else {
      data.frame(run_id = id, metric = names(m), value = vapply(names(m), function(k) as.numeric(m[[k]])[[1L]], numeric(1)),
        error = NA_character_, stringsAsFactors = FALSE)
    }
    fills[[id]] <- f; trades[[id]] <- tr
    close(bt)
  }
  bind <- function(x) do.call(rbind, unname(x))
  if (length(run_ids) == 0L) return(list())
  list(
    fills = a0_canon(bind(fills), "fills", c("run_id", "event_seq", "action")),
    trades = a0_canon(bind(trades), "trades", c("run_id", "event_seq", "action")),
    metrics = a0_canon(bind(metrics), "metrics", c("run_id", "metric"))
  )
}

# Conditions raised by a path, in order: warnings (muffled) and, for expected
# failures, the error that ended a run.
a0_new_sink <- function() {
  sink <- new.env(parent = emptyenv())
  sink$rows <- data.frame(run_id = character(), seq = integer(), kind = character(), class = character(),
    message = character(), stringsAsFactors = FALSE)
  sink
}

a0_sink_add <- function(sink, run_id, kind, cnd) {
  sink$rows <- rbind(sink$rows, data.frame(run_id = run_id, seq = nrow(sink$rows) + 1L, kind = kind,
    class = paste(class(cnd), collapse = "/"), message = conditionMessage(cnd), stringsAsFactors = FALSE))
}

a0_capture_warnings <- function(expr, run_id, sink) {
  withCallingHandlers(expr, warning = function(w) {
    a0_sink_add(sink, run_id, "warning", w)
    invokeRestart("muffleWarning")
  })
}

# Runs a committed run; an error is recorded and the run's durable rows are
# still collected. Returns TRUE when the run returned.
a0_run_or_record <- function(expr, run_id, sink) {
  done <- tryCatch({
    bt <- a0_capture_warnings(expr, run_id, sink)
    close(bt)
    TRUE
  }, error = function(e) {
    a0_sink_add(sink, run_id, "error", e)
    FALSE
  })
  done
}

# ---------------------------------------------------------------------------
# Memory output: sweep result and the memory sink's own buffers
# ---------------------------------------------------------------------------

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

# Temporarily replaces ledgr namespace bindings: patches is a named list of
# function(original) -> replacement. Used by the memory observer and guts.
a0_with_patches <- function(patches, expr) {
  ns <- asNamespace("ledgr")
  originals <- lapply(stats::setNames(names(patches), names(patches)), get, envir = ns)
  locked <- vapply(names(patches), bindingIsLocked, logical(1), env = ns)
  on.exit(for (name in names(originals)) {
    assign(name, originals[[name]], envir = ns)
    if (locked[[name]]) lockBinding(name, ns)
  }, add = TRUE)
  for (name in names(patches)) {
    if (locked[[name]]) unlockBinding(name, ns)
    assign(name, patches[[name]](originals[[name]]), envir = ns)
  }
  force(expr)
}

# Memory-sink observation boundary: the only part of the harness the WS1 cut
# may adapt. Per sweep candidate (run_id = candidate label) it must deliver
# the sink's native output: events() with the typed attributes
# ledgr_event_{cash_delta,position_delta,realized,cost_basis,meta}, the
# retained diagnostics() (NULL when none), completion() (NULL in dense mode)
# and the inline_summary() equity and fills. Today it wraps the memory handler
# factory. Without an observation point it stops, so check.R fails rather
# than silently dropping the memory records.
a0_memory_factory <- "ledgr_memory_output_handler"
a0_observe_memory <- function(expr, gut = NULL) {
  factory <- gut$memory_factory %||% a0_memory_factory
  if (!exists(factory, envir = asNamespace("ledgr"), inherits = FALSE)) {
    stop(paste0("a0: no memory-sink observation point on this tree (", factory, " is gone). ",
      "Adapt a0_observe_memory() in lib.R to the replacement sink so it returns the same per-candidate ",
      "events, diagnostics, completion and summary; do not edit canonicalization or records."), call. = FALSE)
  }
  registry <- new.env(parent = emptyenv())
  summaries <- new.env(parent = emptyenv())
  patch <- stats::setNames(list(function(original) function(run_id, ...) {
    handler <- original(run_id, ...)
    summarize <- handler$inline_summary
    handler$inline_summary <- function(...) {
      s <- summarize(...)
      summaries[[run_id]] <- s
      s
    }
    registry[[run_id]] <- handler
    handler
  }), factory)
  value <- a0_with_patches(patch, expr)
  ids <- ls(registry)
  observed <- lapply(stats::setNames(ids, ids), function(rid) {
    h <- registry[[rid]]
    if (is.function(gut$memory)) gut$memory(rid, h)
    list(events = h$events(), diagnostics = h$diagnostics(), completion = h$completion(),
      summary = summaries[[rid]])
  })
  list(value = value, observed = observed)
}

# Canonical memory tables. A FAILED candidate's buffers are discarded by
# contract (LTB-0055) and not recorded; its failure is in the sweep row.
a0_memory_tables <- function(observed, sw) {
  keep <- intersect(as.character(sw$candidate_id[sw$status != "FAILED"]), names(observed))
  ev <- list(); dg <- list(); cp <- list(); eq <- list(); fl <- list(); st <- list()
  for (rid in keep) {
    o <- observed[[rid]]
    e <- o$events
    n <- nrow(e)
    typed <- function(name, empty) { v <- attr(e, name); if (is.null(v)) rep(empty, n) else v }
    df <- as.data.frame(e)
    df$cash_delta <- typed("ledgr_event_cash_delta", NA_real_)
    df$position_delta <- typed("ledgr_event_position_delta", NA_real_)
    df$event_realized <- typed("ledgr_event_realized", NA_real_)
    df$event_cost_basis <- typed("ledgr_event_cost_basis", NA_real_)
    df$meta <- vapply(typed("ledgr_event_meta", list(NULL)), a0_flat, character(1))
    ev[[rid]] <- df
    if (!is.null(o$diagnostics)) dg[[rid]] <- as.data.frame(o$diagnostics)
    if (!is.null(o$completion)) cp[[rid]] <- as.data.frame(o$completion)
    if (!is.null(o$summary)) {
      eq[[rid]] <- as.data.frame(o$summary$equity)
      f <- as.data.frame(o$summary$fills); f$run_id <- rep(rid, nrow(f)); fl[[rid]] <- f
    }
    st[[rid]] <- data.frame(run_id = rid, events = n, diagnostics_null = is.null(o$diagnostics),
      completion_null = is.null(o$completion), summary_null = is.null(o$summary), stringsAsFactors = FALSE)
  }
  bind <- function(x, key) {
    if (length(x)) return(do.call(rbind, unname(x)))
    as.data.frame(stats::setNames(rep(list(character()), length(key)), key), stringsAsFactors = FALSE)
  }
  list(
    memory_state = a0_canon(bind(st, "run_id"), "memory_state", "run_id"),
    memory_events = a0_canon(bind(ev, c("run_id", "event_seq")), "memory_events", c("run_id", "event_seq")),
    memory_diagnostics = a0_canon(bind(dg, c("run_id", "diagnostic_seq")), "memory_diagnostics", c("run_id", "diagnostic_seq")),
    memory_completion = a0_canon(bind(cp, "run_id"), "memory_completion", "run_id"),
    memory_equity = a0_canon(bind(eq, c("run_id", "ts_utc")), "memory_equity", c("run_id", "ts_utc")),
    memory_fills = a0_canon(bind(fl, c("run_id", "event_seq", "action")), "memory_fills", c("run_id", "event_seq", "action"))
  )
}

# ---------------------------------------------------------------------------
# Workload driver
# ---------------------------------------------------------------------------

a0_retain <- function() ledgr_sweep_retention(returns = "completed", trades = "closed")

a0_run_id <- function(workload, candidate_id, suffix = NULL) {
  paste(c("a0", workload, candidate_id, suffix), collapse = "-")
}

# Runs one workload through its handler paths, then collects. `gut` (see
# guts.R) corrupts raw product output before canonicalization: `patch` swaps
# namespace bindings during `patch_paths`, `memory(run_id, handler)` edits the
# memory sink's buffers, `sweep(sw)` the sweep result and `store(con)` the run
# store after every path has executed.
a0_run_workload <- function(id, work_dir, gut = NULL) {
  w <- a0_workloads[[id]]
  paths <- w$paths
  if (!is.null(gut) && !identical(gut$workload, id)) gut <- NULL
  in_path <- function(p, expr) if (p %in% gut$patch_paths) a0_with_patches(gut$patch, expr) else expr
  db_path <- file.path(work_dir, paste0(id, ".duckdb"))
  if (file.exists(db_path)) unlink(db_path)
  assign(normalizePath(db_path, winslash = "/", mustWork = FALSE), "<DB_PATH>", envir = a0_path_tokens)
  fx <- w$fixture(db_path)
  on.exit(for (s in c(list(fx$snapshot), fx$close)) ledgr_snapshot_close(s), add = TRUE)
  out <- list()
  persisted <- list()
  options(ledgr.interrupt = FALSE)
  sweep <- function(...) ledgr_sweep(fx$exp, fx$grid, seed = fx$seed, retain = a0_retain(), ...)

  obs <- in_path("sweep_w1", a0_observe_memory(sweep(), gut))
  sw <- obs$value
  out$sweep_w1 <- c(a0_sweep_tables(if (is.function(gut$sweep)) gut$sweep(sw) else sw), a0_memory_tables(obs$observed, sw))
  if ("sweep_w2" %in% paths) out$sweep_w2 <- a0_sweep_tables(in_path("sweep_w2", sweep(workers = 2L)))
  if ("sweep_compiled" %in% paths) {
    compiled <- a0_observe_memory(sweep(compiled_accounting_model = "spot_fifo"))
    out$sweep_compiled <- c(a0_sweep_tables(compiled$value), a0_memory_tables(compiled$observed, compiled$value))
  }
  # Candidate rows are read directly: ledgr_candidate() refuses INCOMPLETE and
  # FAILED rows, which this harness must still run.
  committed <- function(path, suffix, call) {
    sink <- a0_new_sink()
    ids <- character(); done <- character()
    for (i in seq_len(nrow(sw))) {
      rid <- a0_run_id(id, as.character(sw$candidate_id[[i]]), suffix)
      if (in_path(path, a0_run_or_record(call(i, rid), rid, sink))) done <- c(done, rid)
      ids <- c(ids, rid)
    }
    list(ids = ids, done = done, sink = sink)
  }
  if ("run" %in% paths) {
    persisted$run <- committed("run", NULL, function(i, rid) ledgr_run(fx$exp, params = sw$params[[i]],
      feature_params = sw$feature_params[[i]], run_id = rid, seed = sw$execution_seed[[i]]))
  }
  if ("run_db_live" %in% paths) {
    persisted$run_db_live <- committed("run_db_live", "db_live", function(i, rid) {
      do.call(ledgr_backtest, c(fx$backtest, list(strategy_params = sw$params[[i]], run_id = rid)))
    })
  }
  if ("run_abort" %in% paths) {
    sink <- a0_new_sink()
    rid <- a0_run_id(id, "abort")
    ok <- a0_run_or_record(ledgr_run(fx$abort_exp, params = fx$abort_params, run_id = rid), rid, sink)
    persisted$run_abort <- list(ids = rid, done = if (ok) rid else character(), sink = sink)
  }
  if ("run_resumed" %in% paths) {
    params <- utils::modifyList(sw$params[[1L]], list(interrupt = TRUE))
    rid <- a0_run_id(id, "resumed")
    resume <- function() ledgr_run(fx$exp, params = params, run_id = rid, seed = sw$execution_seed[[1L]])
    # The soft-stopped run's durable state is frozen before the resume
    # overwrites it (status, telemetry, ledger, state, equity, diagnostics).
    sink <- a0_new_sink()
    in_path("run_interrupted", a0_run_or_record(resume(), rid, sink))
    options(ledgr.interrupt = FALSE)
    out$run_interrupted <- c(a0_store_tables(db_path, rid),
      list(run_conditions = a0_canon(sink$rows, "run_conditions", "seq")))
    sink <- a0_new_sink()
    a0_run_or_record(resume(), rid, sink)
    persisted$run_resumed <- list(ids = rid, done = rid, sink = sink)
  }
  if ("walk_forward" %in% paths) {
    # Warnings raised anywhere inside walk-forward (train sweeps, test runs)
    # are kept in order; the API does not say which run raised them.
    sink <- a0_new_sink()
    wf <- in_path("walk_forward", a0_capture_warnings(ledgr_walk_forward(fx$exp, grid = fx$grid, folds = fx$folds,
      selection_rule = ledgr_rule_argmax("sharpe_ratio"), seed = fx$seed), "<walk_forward>", sink))
    test_ids <- vapply(wf$test_runs, function(bt) bt$run_id, character(1))
    lapply(wf$test_runs, close)
    persisted$walk_forward <- list(ids = test_ids, done = test_ids, sink = sink, extra = list(
      wf_folds = a0_canon(as.data.frame(wf$folds), "wf_folds", "fold_seq"),
      wf_scores = a0_canon(as.data.frame(wf$scores), "wf_scores", c("fold_seq", "window", "candidate_key", "metric_name")),
      wf_status = a0_canon(data.frame(status = wf$status, test_run_ids = paste(test_ids, collapse = ","),
        stringsAsFactors = FALSE), "wf_status", "status")
    ))
  }
  if (is.function(gut$store)) a0_with_store(db_path, gut$store)
  for (p in names(persisted)) {
    x <- persisted[[p]]
    out[[p]] <- c(x$extra, a0_store_tables(db_path, x$ids), a0_reader_tables(fx$snapshot, x$done),
      list(run_conditions = a0_canon(x$sink$rows, "run_conditions", c("seq"))))
  }
  list(tables = out)
}

a0_run_all <- function(work_dir, gut = NULL, ids = names(a0_workloads)) {
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  res <- lapply(stats::setNames(ids, ids), function(id) a0_run_workload(id, work_dir, gut = gut))
  list(tables = lapply(res, `[[`, "tables"))
}

# fixtures.R and guts.R sit next to this file; find it through source().
local({
  here <- a0_script_dir()
  for (i in rev(seq_len(sys.nframe()))) {
    f <- sys.frame(i)$ofile
    if (is.character(f)) { here <- dirname(normalizePath(f, winslash = "/")); break }
  }
  source(file.path(here, "fixtures.R"))
  source(file.path(here, "guts.R"))
})
