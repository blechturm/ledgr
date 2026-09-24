args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

arg_value <- function(flag, default = NULL) {
  at <- match(flag, args)
  if (is.na(at)) return(default)
  if (at == length(args)) stop(sprintf("%s needs a value", flag), call. = FALSE)
  args[[at + 1L]]
}

output_dir <- arg_value(
  "--output-dir",
  file.path(repo_root, "dev", "spikes", "settlement_axis_density", "evidence")
)
gut_injection <- "--gut-injection" %in% args
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

git_config <- tempfile("ledgr-density-gitconfig-")
writeLines(
  c("[safe]", paste0("\tdirectory = ", repo_root)),
  con = git_config,
  useBytes = TRUE
)
Sys.setenv(GIT_CONFIG_GLOBAL = git_config)
on.exit(unlink(git_config, force = TRUE), add = TRUE)

copy_tracked_package <- function(source, destination) {
  tracked <- system2(
    "git",
    c("-C", shQuote(source), "ls-files"),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(tracked, "status")
  if (!is.null(status) && status != 0L) {
    stop(paste(tracked, collapse = "\n"), call. = FALSE)
  }
  for (relative in tracked[nzchar(tracked)]) {
    from <- file.path(source, relative)
    to <- file.path(destination, relative)
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(from, to, overwrite = TRUE, copy.mode = TRUE)) {
      stop(sprintf("Could not copy tracked file: %s", relative), call. = FALSE)
    }
  }
  invisible(destination)
}

install_injection_seam <- function(package_root, gutted = FALSE) {
  path <- file.path(package_root, "R", "fold-engine.R")
  lines <- readLines(path, warn = FALSE)
  marker <- which(lines == "      availability_view <- NULL")
  if (length(marker) != 1L) {
    stop("The valuation seam marker did not resolve exactly once.", call. = FALSE)
  }
  condition <- if (gutted) {
    "      if (FALSE && is.function(density_injector)) {"
  } else {
    "      if (is.function(density_injector)) {"
  }
  seam <- c(
    "      density_injector <- getOption(\"ledgr.spike_density_injector\", NULL)",
    condition,
    "        injected <- density_injector(i, ts, run_id, event_seq, state)",
    "        if (!is.null(injected)) {",
    "          prepared <- ledgr_prepare_accounting_events(",
    "            injected, instrument_ids = instrument_ids",
    "          )",
    "          replayed <- ledgr_replay_accounting_events(",
    "            prepared, initial_cash = state$cash,",
    "            initial_positions = state$positions, lot_state = state$lot_state",
    "          )",
    "          state$cash <- replayed$cash",
    "          state$positions <- unname(replayed$positions[instrument_ids])",
    "          state$lot_state <- replayed$lot_state",
    "          state <<- state",
    "          output_handler$append_event_rows(injected)",
    "          event_seq <- max(prepared$event_seq) + 1L",
    "        }",
    "      }"
  )
  lines <- append(lines, seam, after = marker - 1L)
  writeLines(lines, path, sep = "\r\n", useBytes = TRUE)
  invisible(path)
}

make_injected_row <- function(run_id, ts, event_seq) {
  meta <- list(
    source = "opening_position",
    cash_delta = 0,
    position_delta = 2,
    cost_basis = 20,
    opening_position = TRUE,
    source_identity = "proto:settlement-axis-density"
  )
  data.frame(
    event_id = paste0("proto:settlement-axis-density:", event_seq),
    run_id = run_id,
    ts_utc = as.POSIXct(ts, tz = "UTC"),
    event_type = "CASHFLOW",
    instrument_id = "CHILD",
    side = NA_character_,
    qty = NA_real_,
    price = NA_real_,
    fee = 0,
    meta_json = canonical_json(meta),
    event_seq = as.integer(event_seq),
    stringsAsFactors = FALSE
  )
}

case_bars <- function(pulses, case_id) {
  keep <- switch(
    case_id,
    complete_control = seq_along(pulses),
    late_start_at_entitlement = 3:5,
    missing_at_entitlement = 4:5,
    stop("Unknown case", call. = FALSE)
  )
  parent <- data.frame(
    ts_utc = pulses,
    instrument_id = "PARENT",
    open = 10,
    high = 10,
    low = 10,
    close = 10,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  child <- data.frame(
    ts_utc = pulses[keep],
    instrument_id = "CHILD",
    open = 20,
    high = 20,
    low = 20,
    close = 20,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  rbind(parent, child)
}

make_snapshot <- function(root, case_id) {
  dates <- as.Date("2024-01-02") + 0:4
  pulses <- as.POSIXct(paste(dates, "21:00:00"), tz = "UTC")
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "14:30:00",
      session_close = "21:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = "PARENT",
      effective_from = pulses[[1L]],
      knowledge_time = pulses[[1L]] - 1,
      stringsAsFactors = FALSE
    ),
    universe_id = "research",
    complete = TRUE
  )
  snapshot <- ledgr_snapshot_from_df(
    case_bars(pulses, case_id),
    instruments_df = data.frame(
      instrument_id = c("PARENT", "CHILD"),
      stringsAsFactors = FALSE
    ),
    facts = ledgr_facts(sessions, membership),
    db_path = file.path(root, paste0(case_id, ".duckdb"))
  )
  list(snapshot = snapshot, pulses = pulses)
}

empty_case_row <- function(case_id, error) {
  data.frame(
    case_id = case_id,
    status = "ERROR",
    stop_reason = "",
    error_class = class(error)[[1L]],
    error_message = conditionMessage(error),
    equity_rows = NA_integer_,
    final_positions_value = NA_real_,
    final_equity = NA_real_,
    child_ledger_rows = NA_integer_,
    child_position = NA_real_,
    child_view_rows = NA_integer_,
    child_pre_entitlement_view_rows = NA_integer_,
    child_member_any = NA,
    child_held_at_entitlement = NA,
    child_priced_at_entitlement = NA,
    child_mark_source_at_entitlement = "",
    child_first_view_ts_utc = "",
    reopen_equity_identical = FALSE,
    reopen_availability_identical = FALSE,
    evidence_source = "public_ledgr_run",
    stringsAsFactors = FALSE
  )
}

strip_identity <- function(x) {
  drop <- intersect(names(x), c("run_id", "event_id", "created_at_utc"))
  x[setdiff(names(x), drop)]
}

run_case <- function(root, case_id) {
  fixture <- make_snapshot(root, case_id)
  snapshot <- fixture$snapshot
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  entitlement <- fixture$pulses[[3L]]
  injector <- function(i, ts, run_id, event_seq, state) {
    if (i != 3L) return(NULL)
    make_injected_row(run_id, ts, event_seq)
  }
  prior <- options(ledgr.spike_density_injector = injector)
  on.exit(options(prior), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    universe = ledgr_universe_members("research"),
    valuation_policy = ledgr_valuation_stale(0),
    cost_model = ledgr_cost_zero()
  )
  run_id <- paste0("proto-density-", case_id)
  bt <- NULL
  error <- NULL
  tryCatch(
    bt <- ledgr_run(experiment, run_id = run_id),
    error = function(e) error <<- e
  )
  if (!is.null(error)) {
    return(list(row = empty_case_row(case_id, error), surfaces = NULL))
  }
  terminal <- ledgr_backtest_terminal_evidence(bt)
  completion <- terminal$completion
  equity <- ledgr_results(bt, "equity")
  availability <- ledgr_results(bt, "availability")
  ledger <- ledgr_results(bt, "ledger")
  child_view <- availability[
    as.character(availability$instrument_id) == "CHILD",
    ,
    drop = FALSE
  ]
  at_entitlement <- child_view[
    as.POSIXct(child_view$ts_utc, tz = "UTC") == entitlement,
    ,
    drop = FALSE
  ]
  prepared <- ledgr_prepare_accounting_events(
    ledger,
    instrument_ids = c("PARENT", "CHILD")
  )
  replay <- ledgr_replay_accounting_events(prepared, initial_cash = 100000)
  close(bt)
  reopened <- ledgr_run_open(snapshot, run_id)
  reopened_equity <- ledgr_results(reopened, "equity")
  reopened_availability <- ledgr_results(reopened, "availability")
  close(reopened)
  stop_reason <- if (is.null(completion) || nrow(completion) == 0L) {
    ""
  } else {
    as.character(completion$stop_reason[[1L]])
  }
  first_view <- if (nrow(child_view) == 0L) "" else {
    ledgr_normalize_ts_utc(min(as.POSIXct(child_view$ts_utc, tz = "UTC")))
  }
  row <- data.frame(
    case_id = case_id,
    status = terminal$status,
    stop_reason = stop_reason,
    error_class = "",
    error_message = "",
    equity_rows = nrow(equity),
    final_positions_value = utils::tail(equity$positions_value, 1L),
    final_equity = utils::tail(equity$equity, 1L),
    child_ledger_rows = sum(as.character(ledger$instrument_id) == "CHILD"),
    child_position = unname(replay$positions[["CHILD"]]),
    child_view_rows = nrow(child_view),
    child_pre_entitlement_view_rows = sum(
      as.POSIXct(child_view$ts_utc, tz = "UTC") < entitlement
    ),
    child_member_any = any(as.logical(child_view$member)),
    child_held_at_entitlement = nrow(at_entitlement) == 1L &&
      isTRUE(at_entitlement$held[[1L]]),
    child_priced_at_entitlement = nrow(at_entitlement) == 1L &&
      isTRUE(at_entitlement$priced[[1L]]),
    child_mark_source_at_entitlement = if (nrow(at_entitlement) == 1L) {
      as.character(at_entitlement$mark_source[[1L]])
    } else {
      ""
    },
    child_first_view_ts_utc = first_view,
    reopen_equity_identical = identical(equity, reopened_equity),
    reopen_availability_identical = identical(
      availability,
      reopened_availability
    ),
    evidence_source = "public_ledgr_run",
    stringsAsFactors = FALSE
  )
  list(
    row = row,
    surfaces = list(
      equity = strip_identity(equity),
      availability = strip_identity(availability),
      ledger = strip_identity(ledger)
    )
  )
}

surface_max_abs_diff <- function(left, right) {
  if (!identical(names(left), names(right)) || nrow(left) != nrow(right)) {
    return(NA_real_)
  }
  numeric_names <- names(left)[vapply(left, is.numeric, logical(1))]
  if (length(numeric_names) == 0L) return(0)
  values <- unlist(lapply(numeric_names, function(name) {
    abs(as.numeric(left[[name]]) - as.numeric(right[[name]]))
  }), use.names = FALSE)
  values <- values[is.finite(values)]
  if (length(values) == 0L) 0 else max(values)
}

scratch <- tempfile("ledgr-settlement-axis-density-")
dir.create(scratch, recursive = TRUE)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
fork <- file.path(scratch, "package")
dir.create(fork)
copy_tracked_package(repo_root, fork)
install_injection_seam(fork, gutted = gut_injection)
pkgload::load_all(fork, quiet = TRUE, export_all = TRUE)

case_ids <- c(
  "complete_control",
  "late_start_at_entitlement",
  "missing_at_entitlement"
)
results <- lapply(case_ids, function(case_id) run_case(scratch, case_id))
cases <- do.call(rbind, lapply(results, `[[`, "row"))
row.names(cases) <- NULL

control <- results[[match("complete_control", case_ids)]]$surfaces
late <- results[[match("late_start_at_entitlement", case_ids)]]$surfaces
parity <- do.call(rbind, lapply(names(control), function(surface) {
  left <- control[[surface]]
  right <- late[[surface]]
  data.frame(
    surface = surface,
    complete_rows = nrow(left),
    late_start_rows = nrow(right),
    identical_after_identity_exclusions = identical(left, right),
    max_abs_numeric_difference = surface_max_abs_diff(left, right),
    stringsAsFactors = FALSE
  )
}))
row.names(parity) <- NULL

utils::write.csv(
  cases,
  file.path(output_dir, "cases.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  parity,
  file.path(output_dir, "parity.csv"),
  row.names = FALSE,
  na = ""
)
cat(sprintf("WROTE %d cases and %d parity rows\n", nrow(cases), nrow(parity)))
