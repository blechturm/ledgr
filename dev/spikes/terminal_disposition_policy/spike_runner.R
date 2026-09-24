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
  file.path(repo_root, "dev", "spikes", "terminal_disposition_policy", "evidence")
)
gut_disposition <- "--gut-disposition" %in% args
probe_only <- "--probe-only" %in% args
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

git_config <- tempfile("ledgr-terminal-policy-gitconfig-")
writeLines(c("[safe]", paste0("\tdirectory = ", repo_root)), git_config)
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

install_disposition_seam <- function(package_root, gutted = FALSE) {
  path <- file.path(package_root, "R", "fold-engine.R")
  lines <- readLines(path, warn = FALSE)
  marker <- which(lines == paste0(
    "        expired_ids <- setdiff(held_ids[!valuation$permissible[held_ids]], ",
    "terminal_ids)"
  ))
  if (length(marker) != 1L) {
    stop("The terminal disposition seam did not resolve exactly once.", call. = FALSE)
  }
  condition <- if (gutted) {
    "        if (FALSE && length(terminal_ids) > 0L && is.function(disposition_policy)) {"
  } else {
    "        if (length(terminal_ids) > 0L && is.function(disposition_policy)) {"
  }
  seam <- c(
    "        disposition_policy <- getOption(\"ledgr.spike_terminal_disposition\", NULL)",
    condition,
    "          proposals <- disposition_policy(",
    "            terminal_ids = terminal_ids, ts = ts, positions = full_positions,",
    "            valuation = valuation, availability_view = availability_view",
    "          )",
    "          if (is.data.frame(proposals) && nrow(proposals) > 0L) {",
    "            for (proposal_idx in seq_len(nrow(proposals))) {",
    "              proposal <- proposals[proposal_idx, , drop = FALSE]",
    "              instrument_id <- as.character(proposal$instrument_id[[1L]])",
    "              inst_idx <- match(instrument_id, instrument_ids)",
    "              cur_qty <- as.numeric(state$positions[[inst_idx]])",
    "              fill <- structure(list(",
    "                instrument_id = instrument_id,",
    "                side = if (cur_qty > 0) \"SELL\" else \"BUY\",",
    "                qty = abs(cur_qty),",
    "                fill_price = as.numeric(proposal$price[[1L]]),",
    "                fee = 0, ts_exec_utc = ts",
    "              ), class = \"ledgr_fill_intent\")",
    "              lot_res <- ledgr_lot_apply_fill(",
    "                state$lot_state, instrument_id, fill$side, fill$qty,",
    "                fill$fill_price, fill$fee",
    "              )",
    "              state$lot_state <- lot_res$state",
    "              write_res <- output_handler$write_fill_events(",
    "                fill_intent = fill, event_seq = event_seq,",
    "                use_transaction = identical(event_mode, \"live\")",
    "              )",
    "              event_seq <- write_res$next_event_seq",
    "              if (is.function(output_handler$record_accounting_fact)) {",
    "                output_handler$record_accounting_fact(",
    "                  write_res = write_res, lot_res = lot_res,",
    "                  lot_state = state$lot_state",
    "                )",
    "              }",
    "              state$positions[[inst_idx]] <- cur_qty + write_res$position_delta",
    "              state$cash <- state$cash + write_res$cash_delta",
    "              add_segment(list(",
    "                n = 1L, instrument_id = instrument_id, stage = \"settlement\",",
    "                outcome = \"approximated\",",
    "                reason_code = \"terminal_disposed_last_permissible_mark\",",
    "                quantity = fill$qty, price = fill$fill_price,",
    "                mark_source = as.character(proposal$mark_source[[1L]]),",
    "                mark_age = as.integer(proposal$mark_age[[1L]]),",
    "                event_seq = as.integer(write_res$event_seq),",
    "                position_before = cur_qty,",
    "                position_after = state$positions[[inst_idx]],",
    "                detail_json = canonical_json(list(",
    "                  policy_id = as.character(proposal$policy_id[[1L]]),",
    "                  terminal_event = as.character(",
    "                    availability_view$terminal_event[[instrument_id]]",
    "                  )",
    "                ))",
    "              ))",
    "            }",
    "            full_positions <- ledgr_fold_positions_snapshot(",
    "              state$positions, instrument_ids",
    "            )",
    "            availability_view <- availability_provider$decision_view(",
    "              ts, full_positions",
    "            )",
    "            context_ids <- as.character(availability_view$axis)",
    "            availability_view$priced <- valuation$priced[context_ids]",
    "            availability_view$mark_age <- valuation$age[context_ids]",
    "            availability_view$risk_mark <- valuation$mark[context_ids]",
    "            availability_view$mark_source <- valuation$source[context_ids]",
    "            held_ids <- context_ids[as.logical(availability_view$held)]",
    "            terminal_ids <- held_ids[nzchar(as.character(",
    "              availability_view$terminal_event[held_ids]",
    "            ))]",
    "            expired_ids <- setdiff(",
    "              held_ids[!valuation$permissible[held_ids]], terminal_ids",
    "            )",
    "          }",
    "        }"
  )
  lines <- append(lines, seam, after = marker)
  writeLines(lines, path, sep = "\r\n", useBytes = TRUE)
  invisible(path)
}

make_snapshot <- function(root, case_id, mark_shape = "current") {
  dates <- as.Date("2024-01-02") + 0:3
  pulses <- as.POSIXct(paste(dates, "21:00:00"), tz = "UTC")
  keep <- if (identical(mark_shape, "current")) 1:4 else c(1L, 3L, 4L)
  bars <- data.frame(
    ts_utc = pulses[keep],
    instrument_id = "AAA",
    open = 100, high = 100, low = 100, close = 100, volume = 1000,
    stringsAsFactors = FALSE
  )
  sessions <- ledgr_facts_sessions(data.frame(
    session_date = dates,
    status = "open",
    session_open = "14:30:00",
    session_close = "21:00:00",
    knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
    stringsAsFactors = FALSE
  ), venue_id = "XNYS")
  membership <- ledgr_facts_membership_snapshots(data.frame(
    instrument_id = "AAA",
    effective_from = pulses[[1L]],
    knowledge_time = pulses[[1L]] - 1,
    stringsAsFactors = FALSE
  ), universe_id = "research", complete = TRUE)
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = pulses[[2L]],
    knowledge_time = pulses[[2L]] - 1,
    assertion = "known_inactive",
    terminal_event = "delisted",
    stringsAsFactors = FALSE
  ))
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "AAA"),
    facts = ledgr_facts(sessions, membership, lifetime),
    db_path = file.path(root, paste0(case_id, ".duckdb"))
  )
  list(snapshot = snapshot, pulses = pulses)
}

last_permissible_policy <- function(terminal_ids,
                                    ts,
                                    positions,
                                    valuation,
                                    availability_view) {
  eligible <- terminal_ids[
    as.logical(valuation$permissible[terminal_ids]) &
      is.finite(as.numeric(valuation$reference[terminal_ids])) &
      as.numeric(positions[terminal_ids]) != 0
  ]
  if (length(eligible) == 0L) return(NULL)
  data.frame(
    instrument_id = eligible,
    price = as.numeric(valuation$reference[eligible]),
    mark_source = as.character(valuation$source[eligible]),
    mark_age = as.integer(valuation$age[eligible]),
    policy_id = "last_permissible_mark_v001",
    stringsAsFactors = FALSE
  )
}

read_tables <- function(bt) {
  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = bt$db_path, read_only = TRUE)
  on.exit({
    DBI::dbDisconnect(con, shutdown = FALSE)
    duckdb::duckdb_shutdown(drv)
  }, add = TRUE)
  list(
    run = DBI::dbGetQuery(
      con, "SELECT status FROM runs WHERE run_id = ?", params = list(bt$run_id)
    ),
    completion = DBI::dbGetQuery(
      con,
      "SELECT * FROM run_completion WHERE run_id = ?",
      params = list(bt$run_id)
    ),
    diagnostics = DBI::dbGetQuery(
      con,
      paste(
        "SELECT * FROM run_diagnostics WHERE run_id = ?",
        "ORDER BY diagnostic_seq"
      ),
      params = list(bt$run_id)
    ),
    events = DBI::dbGetQuery(
      con,
      "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq",
      params = list(bt$run_id)
    ),
    equity = DBI::dbGetQuery(
      con,
      "SELECT * FROM equity_curve WHERE run_id = ? ORDER BY ts_utc",
      params = list(bt$run_id)
    )
  )
}

strip_identity <- function(x) {
  drop <- intersect(names(x), c("run_id", "event_id", "created_at_utc"))
  x[setdiff(names(x), drop)]
}

case_row <- function(case_id,
                     first_status,
                     tables,
                     reopened,
                     reopen_error_class = "",
                     evidence_source = "public_ledgr_run") {
  settlement <- tables$diagnostics[
    tables$diagnostics$stage == "settlement" &
      tables$diagnostics$outcome == "approximated",
    ,
    drop = FALSE
  ]
  stopped <- tables$diagnostics[
    tables$diagnostics$outcome == "stopped",
    ,
    drop = FALSE
  ]
  sale <- tables$events[
    tables$events$event_type == "FILL" & tables$events$side == "SELL",
    ,
    drop = FALSE
  ]
  completion_reason <- if (nrow(tables$completion) == 0L) "" else {
    as.character(tables$completion$stop_reason[[1L]])
  }
  data.frame(
    case_id = case_id,
    first_status = first_status,
    final_status = as.character(tables$run$status[[1L]]),
    stop_reason = completion_reason,
    equity_rows = nrow(tables$equity),
    ledger_rows = nrow(tables$events),
    disposition_fill_rows = nrow(sale),
    settlement_diagnostic_rows = nrow(settlement),
    stopped_diagnostic_rows = nrow(stopped),
    quantity = if (nrow(settlement) == 1L) settlement$quantity[[1L]] else NA_real_,
    price = if (nrow(settlement) == 1L) settlement$price[[1L]] else NA_real_,
    mark_source = if (nrow(settlement) == 1L) {
      as.character(settlement$mark_source[[1L]])
    } else {
      ""
    },
    mark_age = if (nrow(settlement) == 1L) {
      as.integer(settlement$mark_age[[1L]])
    } else {
      NA_integer_
    },
    position_before = if (nrow(settlement) == 1L) {
      settlement$position_before[[1L]]
    } else {
      NA_real_
    },
    position_after = if (nrow(settlement) == 1L) {
      settlement$position_after[[1L]]
    } else {
      NA_real_
    },
    policy_id_recorded = nrow(settlement) == 1L && grepl(
      "last_permissible_mark_v001",
      settlement$detail_json[[1L]],
      fixed = TRUE
    ),
    final_cash = if (nrow(tables$equity) > 0L) {
      utils::tail(tables$equity$cash, 1L)
    } else {
      NA_real_
    },
    final_equity = if (nrow(tables$equity) > 0L) {
      utils::tail(tables$equity$equity, 1L)
    } else {
      NA_real_
    },
    reopen_error_class = reopen_error_class,
    reopen_events_identical = !is.null(reopened) &&
      identical(tables$events, reopened$events),
    reopen_equity_identical = !is.null(reopened) &&
      identical(tables$equity, reopened$equity),
    reopen_diagnostics_identical = identical(
      if (is.null(reopened)) NULL else tables$diagnostics,
      if (is.null(reopened)) FALSE else reopened$diagnostics
    ),
    evidence_source = evidence_source,
    stringsAsFactors = FALSE
  )
}

run_case <- function(root,
                     case_id,
                     policy = TRUE,
                     mark_shape = "current",
                     max_age = 1L,
                     interrupt = FALSE) {
  fixture <- make_snapshot(root, case_id, mark_shape)
  snapshot <- fixture$snapshot
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  previous <- options(
    ledgr.spike_terminal_disposition = if (policy) {
      last_permissible_policy
    } else {
      NULL
    },
    ledgr.interrupt = FALSE,
    ledgr.spike_interrupted_once = FALSE
  )
  on.exit(options(previous), add = TRUE)
  strategy <- if (interrupt) {
    function(ctx, params) {
      if (!isTRUE(getOption("ledgr.spike_interrupted_once", FALSE)) &&
          identical(ctx$ts_utc, "2024-01-02T21:00:00Z")) {
        options(
          ledgr.interrupt = TRUE,
          ledgr.spike_interrupted_once = TRUE
        )
      }
      ctx$hold()
    }
  } else {
    function(ctx, params) ctx$hold()
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    universe = ledgr_universe_members("research"),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 80)
    ),
    valuation_policy = ledgr_valuation_stale(max_age),
    cost_model = ledgr_cost_zero()
  )
  run_id <- paste0("terminal-disposition-", case_id)
  bt <- ledgr_run(experiment, run_id = run_id)
  first_status <- ledgr_backtest_terminal_evidence(bt)$status
  if (interrupt) {
    close(bt)
    options(ledgr.interrupt = FALSE)
    bt <- ledgr_run(experiment, run_id = run_id)
  }
  tables <- read_tables(bt)
  close(bt)
  reopened <- NULL
  reopen_error_class <- ""
  tryCatch({
    reopened_bt <- ledgr_run_open(snapshot, run_id)
    reopened <- read_tables(reopened_bt)
    close(reopened_bt)
  }, error = function(error) {
    reopen_error_class <<- class(error)[[1L]]
  })
  list(
    row = case_row(
      case_id,
      first_status,
      tables,
      reopened,
      reopen_error_class = reopen_error_class
    ),
    surfaces = lapply(tables, strip_identity)
  )
}

surface_max_abs_difference <- function(left, right) {
  if (!identical(names(left), names(right)) || nrow(left) != nrow(right)) {
    return(NA_real_)
  }
  numeric_names <- names(left)[vapply(left, is.numeric, logical(1))]
  values <- unlist(lapply(numeric_names, function(name) {
    abs(as.numeric(left[[name]]) - as.numeric(right[[name]]))
  }), use.names = FALSE)
  values <- values[is.finite(values)]
  if (length(values) == 0L) 0 else max(values)
}

scratch <- tempfile("ledgr-terminal-disposition-")
dir.create(scratch, recursive = TRUE)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
fork <- file.path(scratch, "package")
dir.create(fork)
copy_tracked_package(repo_root, fork)
install_disposition_seam(fork, gutted = gut_disposition)
pkgload::load_all(fork, quiet = TRUE, export_all = TRUE)

if (probe_only) {
  result <- run_case(scratch, "current_probe")
  row <- result$row
  cat(sprintf(
    "PROBE status=%s events=%d diagnostics=%d equity=%d cash=%.2f\n",
    row$final_status,
    row$ledger_rows,
    row$settlement_diagnostic_rows,
    row$equity_rows,
    row$final_cash
  ))
} else {
  case_spec <- list(
    strict_control = list(policy = FALSE, mark_shape = "current", max_age = 1L),
    current_mark = list(policy = TRUE, mark_shape = "current", max_age = 1L),
    stale_mark = list(policy = TRUE, mark_shape = "missing", max_age = 1L),
    no_permissible_mark = list(
      policy = TRUE, mark_shape = "missing", max_age = 0L
    ),
    resumed_current_mark = list(
      policy = TRUE, mark_shape = "current", max_age = 1L, interrupt = TRUE
    )
  )
  results <- lapply(names(case_spec), function(case_id) {
    do.call(run_case, c(list(root = scratch, case_id = case_id), case_spec[[case_id]]))
  })
  names(results) <- names(case_spec)
  cases <- do.call(rbind, lapply(results, `[[`, "row"))
  row.names(cases) <- NULL

  direct <- results$current_mark$surfaces
  resumed <- results$resumed_current_mark$surfaces
  parity <- do.call(rbind, lapply(names(direct), function(surface) {
    left <- direct[[surface]]
    right <- resumed[[surface]]
    data.frame(
      surface = surface,
      direct_rows = nrow(left),
      resumed_rows = nrow(right),
      identical_after_identity_exclusions = identical(left, right),
      max_abs_numeric_difference = surface_max_abs_difference(left, right),
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
    file.path(output_dir, "resume_parity.csv"),
    row.names = FALSE,
    na = ""
  )
  cat(sprintf("WROTE %d cases and %d parity rows\n", nrow(cases), nrow(parity)))
}
