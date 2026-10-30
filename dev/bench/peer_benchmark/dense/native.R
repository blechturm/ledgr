# Fresh native recorder/comparator. No old harness code or private handler API.
dense_home <- function() {
  file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
  dirname(normalizePath(file, winslash = "/", mustWork = TRUE))
}

dense_arg <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- commandArgs(TRUE)[startsWith(commandArgs(TRUE), prefix)]
  if (length(hit) > 1L) stop("duplicate argument: ", name)
  if (length(hit)) substring(hit, nchar(prefix) + 1L) else default
}

dense_git <- function(root, args) {
  out <- system2("C:/Program Files/Git/cmd/git.exe",
    c("-C", root, args), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(out, "status"))) stop(paste(out, collapse = "\n"))
  out
}

dense_scope <- function(root) {
  paths <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
  c(dense_git(root, c("diff", "--no-ext-diff", "HEAD", "--", paths)),
    dense_git(root, c("status", "--porcelain", "--untracked-files=all", "--", paths)))
}

dense_load <- function(pkg) {
  suppressMessages(pkgload::load_all(pkg, quiet = TRUE))
  source(file.path(dense_home(), "recipes.R"), local = globalenv())
}

dense_run <- function(label, case, fixture, pkg) {
  snapshot <- ledgr_snapshot_from_df(fixture$bars, snapshot_id = paste0("native_", label),
    facts = fixture$facts, price_basis = "split_adjusted")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, fixture$strategy, features = fixture$features,
    opening = fixture$opening, cost_model = fixture$cost, risk_chain = ledgr_risk_none(),
    universe = if (case$facts) ledgr_universe_members("u") else NULL)
  warnings <- list()
  bt <- withCallingHandlers(
    ledgr_run(exp, run_id = paste0("native_", label), seed = 20260530L),
    warning = function(w) {
      warnings[[length(warnings) + 1L]] <<- list(
        classes = paste(class(w), collapse = ";"), message = conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  on.exit(close(bt), add = TRUE)
  con <- ledgr_db_init(bt$db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  order_by <- c(runs = "run_id", ledger_events = "event_seq",
    strategy_state = "ts_utc", equity_curve = "ts_utc",
    run_diagnostics = "diagnostic_seq", run_completion = "run_id",
    run_provenance = "run_id")
  tables <- lapply(names(order_by), function(table) DBI::dbGetQuery(con,
    paste("SELECT * FROM", table, "WHERE run_id = ? ORDER BY", order_by[[table]]),
    params = list(bt$run_id)))
  names(tables) <- names(order_by)
  tables$fills <- as.data.frame(ledgr_results(bt, "fills"))
  tables$trades <- as.data.frame(ledgr_results(bt, "trades"))
  rebuilt <- ledgr_state_reconstruct(bt$run_id, con)
  names(rebuilt) <- paste0("rebuilt_", names(rebuilt))
  tables <- c(tables, rebuilt)
  tables$conditions <- data.frame(
    classes = vapply(warnings, `[[`, character(1L), "classes"),
    message = vapply(warnings, `[[`, character(1L), "message"))
  f <- tables$fills
  stopifnot(nrow(f) > 0L, any(f$qty > 0), all(is.finite(tables$equity_curve$equity)),
    identical(tables$runs$status, "DONE"))
  if (!identical(label, "cost_final")) stopifnot(any(f$side == "BUY"), any(f$side == "SELL"))
  if (identical(label, "cost_final")) stopifnot(any(f$fee > 0),
    tables$rebuilt_positions$qty[tables$rebuilt_positions$instrument_id == "AAA"] == 1,
    any(grepl("LEDGR_LAST_BAR_NO_FILL", tables$conditions$message, fixed = TRUE)))
  list(tables = tables, provenance = list(
    source_commit = dense_git(pkg, c("rev-parse", "HEAD")), loaded_root = normalizePath(pkg),
    snapshot = ledgr_snapshot_info(snapshot), case = case,
    environment = capture.output(sessionInfo())))
}

dense_keys <- function(tables) {
  keys <- c(ledger_events = "event_seq", fills = "event_seq", trades = "event_seq",
    equity_curve = "ts_utc", strategy_state = "ts_utc", run_diagnostics = "diagnostic_seq",
    rebuilt_positions = "instrument_id", rebuilt_cash = "ts_utc", rebuilt_pnl = "ts_utc",
    rebuilt_equity_curve = "ts_utc")
  for (name in names(keys)) {
    x <- tables[[name]][[keys[[name]]]]
    if (anyNA(x) || anyDuplicated(x)) stop(name, ": missing or duplicate ", keys[[name]])
  }
  invisible(TRUE)
}

# Complete representation, with only declared locator/creation-time exclusions.
dense_representation <- function(record) {
  tables <- record$tables
  for (name in c("runs", "run_provenance")) tables[[name]]$created_at_utc <- NULL
  tables$runs$config_json <- lapply(tables$runs$config_json, function(text) {
    cfg <- jsonlite::fromJSON(text, simplifyVector = FALSE)
    cfg$db_path <- NULL
    cfg$data$snapshot_db_path <- NULL
    cfg
  })
  tables
}

# Native recording pulse and sequence are economic keys; execution stamps remain
# in the separate complete representation. No changed path is pre-accepted.
dense_economic <- function(record) {
  t <- record$tables
  ledger <- t$ledger_events
  ledger$run_id <- ledger$event_id <- ledger$ts_utc <- NULL
  ledger$recording_pulse_ts_utc <- t$fills$recording_pulse_ts_utc[
    match(ledger$event_seq, t$fills$event_seq)]
  if (anyNA(ledger$recording_pulse_ts_utc)) stop("new non-fill event needs a declared pulse key")
  fills <- t$fills
  trades <- t$trades
  fills$ts_utc <- trades$ts_utc <- NULL
  equity <- t$equity_curve
  equity$run_id <- NULL
  state <- t$strategy_state
  state$run_id <- NULL
  list(ledger = ledger, fills = fills, trades = trades, equity = equity,
    state = state, positions = t$rebuilt_positions, cash = t$rebuilt_cash,
    pnl = t$rebuilt_pnl, rebuilt_equity = t$rebuilt_equity_curve)
}

dense_projection <- function(record) {
  dense_keys(record$tables)
  list(economic = dense_economic(record), representation = dense_representation(record))
}

dense_write <- function(record, path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  saveRDS(record, file.path(path, "native.rds"), version = 3L)
  stopifnot(identical(record, readRDS(file.path(path, "native.rds"))))
  for (name in names(record$tables)) utils::write.csv(record$tables[[name]],
    file.path(path, paste0(name, ".csv")), row.names = FALSE, na = "NA")
}

dense_references <- function(pkg) {
  prefix <- "dev/bench/v0_2_3_output_freeze/records"
  controls <- c("dense_risk_features/run", "dense_dividend_state/run", "failures/run_abort")
  paths <- unlist(lapply(controls, function(control) {
    files <- list.files(file.path(pkg, prefix, control), pattern = "[.]csv$")
    if (!length(files)) stop("missing A0 reference: ", control)
    file.path(prefix, control, files)
  }), use.names = FALSE)
  data.frame(file = gsub("\\", "/", paths, fixed = TRUE), rows = vapply(paths,
    function(path) nrow(utils::read.csv(file.path(pkg, path), colClasses = "character")), integer(1L)),
    row.names = NULL)
}

dense_record <- function(out, pkg, cases = dense_cases()) {
  if (dir.exists(out) && length(list.files(out, all.files = TRUE, no.. = TRUE))) {
    stop("record destination is not empty; frozen evidence is never overwritten: ", out)
  }
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  summary <- lapply(names(cases), function(label) {
    cat("recording ", label, "\n", sep = "")
    r <- dense_run(label, cases[[label]], dense_fixture(cases[[label]]), pkg)
    dense_projection(r)
    dense_write(r, file.path(out, label))
    data.frame(case = label, fills = nrow(r$tables$fills),
      exits = sum(r$tables$fills$side == "SELL"), diagnostics = nrow(r$tables$run_diagnostics),
      state_rows = nrow(r$tables$strategy_state), warnings = nrow(r$tables$conditions),
      terminal_cash = tail(r$tables$equity_curve$cash, 1L),
      snapshot_hash = r$provenance$snapshot$snapshot_hash, config_hash = r$tables$runs$config_hash)
  })
  utils::write.csv(do.call(rbind, summary), file.path(out, "summary.csv"), row.names = FALSE)
  utils::write.csv(dense_references(pkg), file.path(out, "a0_references.csv"), row.names = FALSE)
  invisible(out)
}

# Small structural recursion, not an event/row replay. Values use identical:
# a one-ULP change fails. Reports keep a field path plus native key/row.
dense_diff <- function(expected, actual, path = "") {
  if (identical(expected, actual)) return(data.frame())
  row <- function(field, detail) data.frame(field = field, detail = detail)
  if (!identical(class(expected), class(actual)) || !identical(typeof(expected), typeof(actual))) {
    return(row(path, "class/type differs"))
  }
  if (is.list(expected)) {
    if (!identical(names(expected), names(actual)) || length(expected) != length(actual)) {
      return(row(path, "names/length differ"))
    }
    diffs <- lapply(seq_along(expected), function(i) dense_diff(expected[[i]], actual[[i]],
      paste0(path, if (nzchar(path)) "$" else "", if (is.null(names(expected))) paste0("[[", i, "]]") else names(expected)[i])))
    diffs <- diffs[vapply(diffs, nrow, integer(1L)) > 0L]
    if (length(diffs)) {
      d <- do.call(rbind, diffs)
      if (is.data.frame(expected)) {
        index <- suppressWarnings(as.integer(sub(".*\\[([0-9]+)\\]$", "\\1", d$field)))
        ok <- !is.na(index) & index >= 1L & index <= nrow(expected)
        keys <- intersect(c("event_seq", "diagnostic_seq", "ts_utc", "instrument_id"), names(expected))
        for (key in keys) d$detail[ok] <- paste0(d$detail[ok], "; ", key, "=",
          format(expected[[key]][index[ok]], digits = 17L))
      }
      return(d)
    }
    return(row(path, "attributes differ"))
  }
  if (!identical(attributes(expected), attributes(actual))) return(row(path, "attributes differ"))
  if (length(expected) != length(actual)) return(row(path, "length differs"))
  same <- (is.na(expected) & is.na(actual)) | (!is.na(expected) & !is.na(actual) & expected == actual)
  i <- which(!same)[1L]
  if (is.na(i)) return(row(path, "lossless identity differs (e.g. NA/NaN)"))
  row(paste0(path, "[", i, "]"), paste0("expected ", format(expected[i], digits = 17L),
    "; actual ", format(actual[i], digits = 17L)))
}

dense_compare <- function(records, scratch) {
  expected <- list.files(records, pattern = "^native[.]rds$", recursive = TRUE)
  actual <- list.files(scratch, pattern = "^native[.]rds$", recursive = TRUE)
  stopifnot(length(expected) == length(dense_cases()), identical(expected, actual))
  diffs <- lapply(expected, function(file) {
    e <- readRDS(file.path(records, file))
    a <- readRDS(file.path(scratch, file))
    d <- dense_diff(dense_projection(e), dense_projection(a))
    if (nrow(d)) d$case <- dirname(file)
    d
  })
  diffs <- diffs[vapply(diffs, nrow, integer(1L)) > 0L]
  if (length(diffs)) do.call(rbind, diffs) else data.frame(case = character(), field = character(), detail = character())
}


# Historical arms are observations beside each other, never an equality gate.
dense_history_difference <- function(records) {
  read <- function(label) readRDS(file.path(records, label, "native.rds"))$tables$fills
  first <- function(pair, view) {
    a <- read(paste0("historical_", pair, "_dense"))
    b <- read(paste0("historical_", pair, "_facts"))
    cols <- if (view == "economic") setdiff(names(a), "ts_utc") else names(a)
    n <- min(nrow(a), nrow(b))
    same <- Reduce(`&`, lapply(cols, function(name) {
      x <- a[[name]][seq_len(n)]; y <- b[[name]][seq_len(n)]
      (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & x == y)
    }))
    i <- which(!same)[1L]
    if (is.na(i) && nrow(a) != nrow(b)) i <- n + 1L
    field <- if (!is.na(i) && i <= n) cols[which(!vapply(cols, function(name)
      identical(a[[name]][i], b[[name]][i]), logical(1L)))[1L]] else NA_character_
    value <- function(x) if (is.na(i)) "equal" else if (i > nrow(x)) "<absent>" else
      if (is.na(field)) "<extra row>" else format(x[[field]][i], digits = 17L)
    data.frame(pair = pair, view = view, dense_fills = nrow(a), facts_fills = nrow(b),
      first_row = i, field = field, dense = value(a), facts = value(b))
  }
  do.call(rbind, lapply(c("start", "late"), function(pair)
    do.call(rbind, lapply(c("economic", "representation"), function(view) first(pair, view)))))
}
