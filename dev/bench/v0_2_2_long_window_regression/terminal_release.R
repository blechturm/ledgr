# Release-only terminal-outcome and freeze fixture (LDG-2961).
#
# A vendor-neutral two-year availability run crosses a freeze that resumes,
# a labeled terminal reached while frozen (default write-off), a declared
# last_mark terminal, a default last_permissible terminal, a short stale gap
# and a holding still frozen at the end. The same run is executed straight
# and interrupted then resumed, and reopened. Its normalized outputs must
# match each other, independent oracles from the fixture bars and ledger, and
# the checked-in record. Only run_release.R --release reaches this script.
#
# Usage: run_release.R --release terminal <repo> <out_dir> [--accept]

args <- commandArgs(TRUE)
if (!length(args) || !identical(args[[1L]], "--release")) {
  stop("Release-only cases require the explicit --release flag.")
}
args <- args[-1L]
accept <- "--accept" %in% args
args <- setdiff(args, "--accept")
if (length(args) != 2L) {
  stop("Usage: terminal_release.R --release <repo> <out_dir> [--accept]")
}
repo <- normalizePath(args[[1L]], winslash = "/")
out_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = FALSE)
script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
source(file.path(script, "helpers.R"), local = TRUE)
product_tree_status <- lwreg_product_tree_status(repo)
if (nzchar(product_tree_status)) {
  stop("Product tree is dirty:\n", product_tree_status)
}
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
expected_path <- file.path(script, "evidence", "terminal_release", "expected.json")

# Fixture -------------------------------------------------------------------

sessions_n <- 504L
ids <- sprintf("T%02d", seq_len(30L))
dates <- lwreg_session_dates(sessions_n)
ts <- as.POSIXct(paste(dates, "21:00:00"), tz = "UTC")
set.seed(20261005L)
steps <- matrix(stats::rnorm(sessions_n * length(ids), 3e-4, 0.015), sessions_n)
close <- round(50 * exp(apply(steps, 2L, cumsum)), 4)
colnames(close) <- ids
# Gaps and ends, by session index. max_sessions = 3, so a holding freezes
# from the fourth missing session.
close[120:160, "T05"] <- NA # freezes on 123, resumes on 161
close[200:202, "T30"] <- NA # stale only
close[251:sessions_n, "T10"] <- NA # frozen from 254; bankruptcy on 280
close[301:sessions_n, "T15"] <- NA # acquisition on 301, declared last_mark
close[331:sessions_n, "T20"] <- NA # merger on 332, default last_permissible
close[481:sessions_n, "T25"] <- NA # frozen from 484 to the end
terminal_at <- c(T10 = 280L, T15 = 301L, T20 = 332L)
terminal_label <- c(T10 = "bankruptcy", T15 = "acquisition", T20 = "merger")

work <- tempfile("ledgr-terminal-release-")
dir.create(work)
db_path <- file.path(work, "terminal.duckdb")
keep <- !is.na(as.vector(close))
bars <- data.frame(
  ts_utc = rep(ts, times = length(ids)),
  instrument_id = rep(ids, each = sessions_n),
  open = as.vector(close),
  high = as.vector(close) * 1.005,
  low = as.vector(close) * 0.995,
  close = as.vector(close),
  volume = 1e5,
  stringsAsFactors = FALSE
)[keep, , drop = FALSE]
civil <- seq(dates[[1L]], dates[[sessions_n]], by = "day")
is_open <- civil %in% dates
sessions <- data.frame(
  session_date = civil,
  status = ifelse(is_open, "open", "closed"),
  session_open = ifelse(is_open, "14:30:00", NA_character_),
  session_close = ifelse(is_open, "21:00:00", NA_character_),
  knowledge_time = as.POSIXct(dates[[1L]], tz = "UTC") - 86400,
  stringsAsFactors = FALSE
)
lifetime <- data.frame(
  instrument_id = names(terminal_at),
  effective_from = ts[terminal_at],
  knowledge_time = ts[terminal_at] - 1,
  assertion = "known_inactive",
  terminal_event = unname(terminal_label[names(terminal_at)]),
  stringsAsFactors = FALSE
)
snapshot <- ledgr_snapshot_from_df(
  bars,
  instruments_df = data.frame(instrument_id = ids),
  facts = ledgr_facts(
    ledgr_facts_sessions(sessions, "SYNTH", timezone = "UTC"),
    ledgr_facts_lifetime(lifetime)
  ),
  db_path = db_path,
  price_basis = "split_adjusted"
)
on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

rebalance_at <- lwreg_utc_token(ts[seq(1L, sessions_n, by = 21L)])
interrupt_at <- lwreg_utc_token(ts[[140L]]) # T05 is frozen here
strategy <- function(ctx, params) {
  if (isTRUE(params$interrupt) && identical(ctx$ts_utc, params$interrupt_at)) {
    options(ledgr.interrupt = TRUE)
  }
  if (!ctx$ts_utc %in% params$rebalance_at) return(ctx$hold())
  # Weight only eligible IDs with a current close; a stale mark may be
  # priced without being a sizing close.
  current <- ctx$vec$admissible & is.finite(ctx$vec$close)
  eligible <- ctx$universe[current]
  if (!length(eligible)) return(ctx$hold())
  weights <- stats::setNames(rep(1 / length(eligible), length(eligible)), eligible)
  ledgr_target_rebalance(ledgr_weights(weights), ctx, equity_fraction = 0.98)
}
exp <- ledgr_experiment(
  snapshot,
  strategy,
  opening = ledgr_opening(cash = 1e6),
  valuation_policy = ledgr_valuation_stale(3),
  corporate_action_policy = ledgr_corporate_actions(
    held_terminal_position = c(acquisition = "last_mark", default = "last_permissible")
  ),
  cost_model = ledgr_cost_zero()
)

# Normalized outputs -------------------------------------------------------

num <- function(x) sprintf("%.12g", as.numeric(x))
normalize <- function(bt) {
  events <- ledgr_results(bt, "ledger")
  equity <- tibble::as_tibble(bt, what = "equity")
  diagnostics <- tibble::as_tibble(bt, what = "diagnostics")
  valuation <- ledgr_valuation_summary(bt)
  corporate <- ledgr_corporate_action_summary(bt)
  outcomes <- corporate$terminal_outcomes
  info <- ledgr_run_info(bt$snapshot %||% snapshot, bt$run_id)
  diag_key <- paste(diagnostics$stage, diagnostics$outcome, diagnostics$reason_code, sep = "/")
  diag_counts <- table(diag_key)
  list(
    status = info$status,
    stop_reason = info$stop_reason %||% NA_character_,
    events = paste(
      events$event_type, events$instrument_id, events$side,
      lwreg_utc_token(events$ts_utc), num(events$qty), num(events$price),
      sep = "|"
    ),
    equity_rows = nrow(equity),
    equity = num(equity$equity),
    diagnostics = stats::setNames(as.list(as.integer(diag_counts)), names(diag_counts)),
    valuation = lapply(unclass(valuation)[c(
      "valuation_state", "stale_instrument_sessions", "frozen_instrument_sessions",
      "frozen_instruments", "longest_freeze_sessions", "max_frozen_gross_value",
      "max_frozen_equity_weight", "frozen_at_end_count", "frozen_at_end_value",
      "frozen_at_end_weight", "total_return", "total_return_if_frozen_worthless"
    )], function(v) if (is.numeric(v)) num(v) else v),
    terminal_outcomes = paste(
      outcomes$instrument_id, outcomes$source, outcomes$terminal_event,
      outcomes$choice, outcomes$assumption_label, num(outcomes$price),
      num(outcomes$quantity), num(outcomes$proceeds), sep = "|"
    ),
    warning = ledgr:::ledgr_result_assumption_warning(valuation, corporate)
  )
}

native_identity <- function(bt) lwreg_run_native_identity(snapshot, bt)

params <- list(rebalance_at = rebalance_at, interrupt_at = interrupt_at)
options(ledgr.interrupt = FALSE)
straight_bt <- ledgr_run(exp, params = c(params, interrupt = FALSE), run_id = "terminal-straight")
straight <- normalize(straight_bt)
straight_identity <- native_identity(straight_bt)
close(straight_bt)
reopened_bt <- ledgr_run_open(snapshot, "terminal-straight")
reopened <- normalize(reopened_bt)
reopened_identity <- native_identity(reopened_bt)
close(reopened_bt)
first <- ledgr_run(exp, params = c(params, interrupt = TRUE), run_id = "terminal-resumed")
interrupted_status <- ledgr_run_info(snapshot, "terminal-resumed")$status
interrupted_identity <- native_identity(first)
close(first)
options(ledgr.interrupt = FALSE)
resumed_bt <- ledgr_run(exp, params = c(params, interrupt = TRUE), run_id = "terminal-resumed")
resumed <- normalize(resumed_bt)
resumed_identity <- native_identity(resumed_bt)
close(resumed_bt)

# Checks --------------------------------------------------------------------

failures <- character()
check <- function(ok, label) {
  if (!isTRUE(ok)) failures <<- c(failures, label)
}
check(identical(interrupted_status, "RUNNING"), "the interrupted run did not stop RUNNING")
check(identical(reopened, straight), "reopened outputs differ from the straight run")
check(identical(resumed, straight), "resumed outputs differ from the straight run")
check(identical(reopened_identity, straight_identity),
      "reopened native identity differs from the straight run")
check(identical(resumed_identity, interrupted_identity),
      "resumed native identity differs from the interrupted run")

# Independent oracles from the fixture bars and the ledger.
events <- do.call(rbind, strsplit(straight$events, "|", fixed = TRUE))
events <- data.frame(
  type = events[, 1L], id = events[, 2L], side = events[, 3L], ts = events[, 4L],
  qty = as.numeric(events[, 5L]), price = as.numeric(events[, 6L]),
  stringsAsFactors = FALSE
)
position <- function(id) {
  rows <- events[events$id == id & events$type %in% c("FILL", "DISPOSITION"), , drop = FALSE]
  sum(ifelse(rows$side %in% "BUY", 1, -1) * abs(rows$qty))
}
dispositions <- events[events$type == "DISPOSITION", , drop = FALSE]
check(identical(dispositions$id, c("T10", "T15", "T20")), "dispositions are not T10, T15, T20 in order")
check(identical(dispositions$ts, lwreg_utc_token(ts[terminal_at])), "dispositions are not at the terminal pulses")
expected_prices <- c(0, close[300L, "T15"], close[330L, "T20"])
check(isTRUE(all.equal(dispositions$price, unname(expected_prices))),
      sprintf("disposition prices %s differ from write-off, last close and permissible close %s",
              paste(dispositions$price, collapse = ","), paste(expected_prices, collapse = ",")))
check(identical(straight$status, "DONE"), "the run did not finish DONE")
check(identical(straight$valuation$valuation_state, "frozen"), "valuation state is not frozen")
check(identical(straight$valuation$frozen_at_end_count, "1"), "frozen-at-end count is not 1")
check(isTRUE(all.equal(
  as.numeric(straight$valuation$frozen_at_end_value),
  position("T25") * unname(close[480L, "T25"])
)), "frozen-at-end value differs from the T25 position times its last close")
# T05 misses sessions 120-160; ages 1-3 are permissible, so it is frozen
# on sessions 123-160.
check(identical(straight$valuation$longest_freeze_sessions, "38"),
      "longest freeze is not the 38-session T05 freeze")
check(identical(straight$valuation$frozen_instrument_sessions, "85"),
      "frozen instrument-sessions are not T05 38 + T10 26 + T25 21")
check(any(grepl("default: assumed worthless", straight$terminal_outcomes, fixed = TRUE)),
      "the T10 write-off is not labeled as an assumed default")
check(length(straight$warning) > 0L, "the result warning is missing")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
expected_record <- list(
  snapshot = lwreg_snapshot_info(snapshot),
  native_identities = list(
    straight = straight_identity,
    reopened = reopened_identity,
    interrupted = interrupted_identity,
    resumed = resumed_identity
  ),
  outputs = straight
)
record <- c(list(
  commit = lwreg_git_commit(repo),
  package_version = as.character(utils::packageVersion("ledgr"))
), expected_record)
jsonlite::write_json(record, file.path(out_dir, "terminal_release.json"),
                     auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)
if (accept) {
  dir.create(dirname(expected_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(expected_record, expected_path, auto_unbox = TRUE,
                       pretty = TRUE, null = "null", digits = NA)
} else if (!file.exists(expected_path)) {
  failures <- c(failures, "no checked-in expected record")
} else {
  observed <- jsonlite::fromJSON(jsonlite::toJSON(
    expected_record, auto_unbox = TRUE, null = "null", digits = NA
  ), simplifyVector = FALSE)
  expected <- jsonlite::read_json(expected_path, simplifyVector = FALSE)
  check(identical(observed, expected), "outputs differ from the checked-in expected record")
}

if (length(failures)) {
  cat(paste0("FAIL: ", failures), sep = "\n")
  quit(status = 1L)
}
cat("LEDGR_TERMINAL_RELEASE_OK events=", length(straight$events),
    " dispositions=", nrow(dispositions), "\n", sep = "")
