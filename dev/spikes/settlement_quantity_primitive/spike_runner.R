#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
gut_mode <- "--gut-operation3" %in% args
git_config <- tempfile("ledgr-spike-gitconfig-")
writeLines(
  c("[safe]", paste0("\tdirectory = ", repo_root)),
  con = git_config,
  sep = "\n",
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
  tracked <- tracked[nzchar(tracked)]
  for (relative in tracked) {
    from <- file.path(source, relative)
    to <- file.path(destination, relative)
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(from, to, overwrite = TRUE, copy.mode = TRUE)) {
      stop(sprintf("Could not copy tracked file: %s", relative), call. = FALSE)
    }
  }
  invisible(destination)
}

install_injection_seam <- function(package_root) {
  path <- file.path(package_root, "R", "fold-engine.R")
  lines <- readLines(path, warn = FALSE)
  marker <- which(lines == '      current_fold_stage <<- "accounting"')
  after_accounting <- which(
    seq_along(lines) > marker & lines == "      if (availability_active) {"
  )
  if (length(marker) != 1L || length(after_accounting) < 1L) {
    stop("The fold accounting marker did not resolve exactly once.", call. = FALSE)
  }
  at <- after_accounting[[1L]] - 1L
  seam <- c(
    "      spike_injector <- getOption(\"ledgr.spike_operation3_injector\", NULL)",
    "      if (is.function(spike_injector) && !use_compiled_spot_fifo) {",
    "        injected <- spike_injector(i, ts, run_id, event_seq, state)",
    "        if (!is.null(injected) && length(injected) > 0L) {",
    "          for (injected_row in injected) {",
    "            prepared <- ledgr_prepare_accounting_events(",
    "              injected_row, instrument_ids = instrument_ids",
    "            )",
    "            replayed <- ledgr_replay_accounting_events(",
    "              prepared, initial_cash = state$cash,",
    "              initial_positions = state$positions, lot_state = state$lot_state",
    "            )",
    "            state$cash <- replayed$cash",
    "            state$positions <- unname(replayed$positions[instrument_ids])",
    "            state$lot_state <- replayed$lot_state",
    "            state <<- state",
    "            output_handler$append_event_rows(injected_row)",
    "            event_seq <- max(prepared$event_seq) + 1L",
    "          }",
    "        }",
    "      }"
  )
  lines <- append(lines, seam, after = at)
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeLines(lines, con = con, sep = "\r\n", useBytes = TRUE)
  invisible(path)
}

gut_operation3_branch <- function(package_root) {
  path <- file.path(package_root, "R", "accounting-replay.R")
  lines <- readLines(path, warn = FALSE)
  target <- '      if (identical(meta[[i]]$source, "opening_position")) {'
  at <- which(lines == target)
  if (length(at) != 1L) {
    stop("The operation-3 branch did not resolve exactly once.", call. = FALSE)
  }
  lines[[at]] <- paste0(
    "      if (FALSE && identical(meta[[i]]$source, ",
    '"opening_position")) {'
  )
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeLines(lines, con = con, sep = "\r\n", useBytes = TRUE)
  invisible(path)
}

make_rows <- function(run_id, ts_utc, instrument_id, position_delta,
                      cost_basis, event_seq, source_identity) {
  meta <- list(
    source = "opening_position",
    cash_delta = 0,
    position_delta = as.numeric(position_delta),
    cost_basis = as.numeric(cost_basis),
    opening_position = TRUE,
    source_identity = as.character(source_identity)
  )
  data.frame(
    event_id = paste0("proto:settlement:", source_identity, ":", event_seq),
    run_id = run_id,
    ts_utc = as.POSIXct(ts_utc, tz = "UTC"),
    event_type = "CASHFLOW",
    instrument_id = instrument_id,
    side = NA_character_,
    qty = NA_real_,
    price = NA_real_,
    fee = 0,
    meta_json = canonical_json(meta),
    event_seq = as.integer(event_seq),
    stringsAsFactors = FALSE
  )
}

make_execution <- function(run_id, initial_state, event_seq_start = 1L,
                           compiled_accounting_model = NULL,
                           strategy = NULL, start_idx = 1L,
                           max_pulses = Inf) {
  pulses <- as.POSIXct(
    c("2024-01-02 21:00:00", "2024-01-03 21:00:00", "2024-01-04 21:00:00"),
    tz = "UTC"
  )
  pulses_iso <- vapply(pulses, ledgr_normalize_ts_utc, character(1))
  ids <- c("PARENT", "CHILD")
  close <- matrix(
    c(10, 11, 12, 20, 21, 22),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(ids, pulses_iso)
  )
  bars_mat <- list(
    open = close,
    high = close,
    low = close,
    close = close,
    volume = matrix(1000, 2L, 3L, dimnames = dimnames(close)),
    gap_type = matrix("", 2L, 3L, dimnames = dimnames(close)),
    is_synthetic = matrix(FALSE, 2L, 3L, dimnames = dimnames(close))
  )
  bars_by_id <- stats::setNames(lapply(ids, function(id) {
    data.frame(
      instrument_id = id,
      ts_utc = pulses,
      open = close[id, ],
      high = close[id, ],
      low = close[id, ],
      close = close[id, ],
      volume = 1000,
      gap_type = "",
      is_synthetic = FALSE,
      stringsAsFactors = FALSE
    )
  }), ids)
  if (is.null(strategy)) {
    strategy <- function(ctx, params) ctx$hold()
  }
  resolver <- ledgr_cost_resolver_from_model(
    ledgr_cost_chain(ledgr_cost_spread_bps(0), ledgr_cost_fixed_fee(0))
  )
  spec <- ledgr_execution_spec(
    run_id = run_id,
    instrument_ids = ids,
    strategy_fn = strategy,
    strategy_params = list(),
    strategy_call_signature = ledgr_strategy_signature(strategy),
    strategy_is_functional = TRUE,
    pulses_posix = pulses,
    pulses_iso = pulses_iso,
    start_idx = as.integer(start_idx),
    max_pulses = max_pulses,
    checkpoint_every = 0L,
    telemetry_stride = 0L,
    state = initial_state,
    state_prev = NULL,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = NULL,
    static_feature_views = NULL,
    feature_defs = list(),
    runtime_projection = ledgr_projection_from_feature_matrix(
      feature_matrix = list(), universe = ids, pulses_posix = pulses
    ),
    active_alias_map = NULL,
    risk_plan = NULL,
    cost_resolver = resolver,
    event_seq_start = as.integer(event_seq_start),
    telemetry = ledgr_sweep_telemetry_env(),
    seed = 1L,
    event_mode = "buffered",
    use_fast_context = TRUE,
    compiled_accounting_model = compiled_accounting_model
  )
  list(spec = spec, pulses = pulses, bars_mat = bars_mat)
}

initial_state <- function(parent = 0, child = 0,
                          parent_basis = 10, child_basis = 20,
                          cash = 1000) {
  positions <- c(PARENT = parent, CHILD = child)
  nonzero <- positions[positions != 0]
  basis <- c(PARENT = parent_basis, CHILD = child_basis)[names(nonzero)]
  list(
    cash = as.numeric(cash),
    positions = positions,
    lot_state = ledgr_lot_state_from_opening(
      c("PARENT", "CHILD"), nonzero, basis
    )
  )
}

operation_sequence <- function(events) {
  if (nrow(events) == 0L) {
    return(list(prepared = ledgr_prepare_accounting_events(events), text = ""))
  }
  prepared <- ledgr_prepare_accounting_events(
    events, instrument_ids = c("PARENT", "CHILD")
  )
  list(prepared = prepared, text = paste(prepared$operation, collapse = "|"))
}

summarize_case <- function(case_id, arm, events, state, error = NULL,
                           processed = NA_integer_, reopened = FALSE) {
  ids <- c("PARENT", "CHILD")
  positions <- as.numeric(state$positions)
  if (is.null(names(state$positions))) names(positions) <- ids
  else names(positions) <- names(state$positions)
  positions <- positions[ids]
  lots <- state$lot_state
  ops <- operation_sequence(events)
  sources <- vapply(ops$prepared$meta, function(meta) {
    as.character(meta$source_identity %||% "")
  }, character(1))
  data.frame(
    case_id = case_id,
    arm = arm,
    fold_status = if (is.null(error)) "DONE" else "ERROR",
    error_class = if (is.null(error)) "" else class(error)[[1L]],
    processed = as.integer(processed),
    event_count = nrow(events),
    operation_sequence = ops$text,
    operation3_count = sum(ops$prepared$operation == 3L),
    fill_count = sum(ops$prepared$operation == 1L),
    source_identities = paste(sources[nzchar(sources)], collapse = "|"),
    parent_position = unname(positions[["PARENT"]]),
    child_position = unname(positions[["CHILD"]]),
    parent_lot_net = unname(lots$net_by_inst[["PARENT"]]),
    child_lot_net = unname(lots$net_by_inst[["CHILD"]]),
    parent_lot_count = ledgr_lot_count(lots, "PARENT"),
    child_lot_count = ledgr_lot_count(lots, "CHILD"),
    total_cost_basis = as.numeric(lots$total_cost_basis),
    position_lot_agree = isTRUE(all.equal(
      as.numeric(positions), as.numeric(lots$net_by_inst[ids])
    )),
    reopened = isTRUE(reopened),
    evidence_source = "fold_output",
    literal_excluded = FALSE,
    stringsAsFactors = FALSE
  )
}

make_injector <- function(case_id) {
  force(case_id)
  function(i, ts, run_id, event_seq, state) {
    if (i != 2L) return(NULL)
    if (case_id %in% c("case_2", "case_3")) {
      return(list(make_rows(
        run_id, ts, "PARENT", 3, 11, event_seq, case_id
      )))
    }
    if (case_id == "case_4") {
      return(list(make_rows(
        run_id, ts, "CHILD", 2, 21, event_seq, case_id
      )))
    }
    if (case_id == "case_5") {
      return(list(make_rows(
        run_id, ts, "PARENT", -5, 10, event_seq, case_id
      )))
    }
    if (case_id == "case_6") {
      return(list(
        make_rows(run_id, ts, "CHILD", 1, 21, event_seq,
                  "multi-leg-source"),
        make_rows(run_id, ts, "PARENT", -2, 10, event_seq + 1L,
                  "multi-leg-source")
      ))
    }
    if (case_id == "case_7") {
      malformed <- make_rows(
        run_id, ts, "PARENT", -2, 10, event_seq + 1L,
        "malformed-source"
      )
      malformed$meta_json <- canonical_json(list(
        source = "opening_position",
        cash_delta = 0,
        position_delta = -2,
        cost_basis = "bad",
        opening_position = TRUE,
        source_identity = "malformed-source"
      ))
      return(list(
        make_rows(run_id, ts, "CHILD", 1, 21, event_seq,
                  "malformed-source"),
        malformed
      ))
    }
    if (case_id == "case_8") {
      return(list(make_rows(
        run_id, ts, "PARENT", 3, 11, event_seq, case_id
      )))
    }
    if (case_id == "case_9") {
      return(list(make_rows(
        run_id, ts, "CHILD", 2, 21, event_seq, case_id
      )))
    }
    NULL
  }
}

run_direct_case <- function(case_id, start_state,
                            compiled_accounting_model = NULL,
                            strategy = NULL, pre_fold_rows = NULL,
                            replay_start_state = start_state) {
  run_id <- paste0("proto-", case_id)
  handler <- ledgr_memory_output_handler(run_id)
  if (!is.null(pre_fold_rows)) handler$append_event_rows(pre_fold_rows)
  execution <- make_execution(
    run_id,
    start_state,
    event_seq_start = if (is.null(pre_fold_rows)) 1L else nrow(pre_fold_rows) + 1L,
    compiled_accounting_model = compiled_accounting_model,
    strategy = strategy
  )
  old_injector <- getOption("ledgr.spike_operation3_injector")
  on.exit(options(ledgr.spike_operation3_injector = old_injector), add = TRUE)
  options(ledgr.spike_operation3_injector = if (case_id == "case_1") {
    NULL
  } else {
    make_injector(case_id)
  })
  fold <- NULL
  error <- NULL
  tryCatch(
    fold <- ledgr_execute_fold(execution$spec, handler),
    error = function(e) error <<- e
  )
  events <- handler$typed_events()
  prepared <- ledgr_prepare_accounting_events(
    events, instrument_ids = c("PARENT", "CHILD")
  )
  replay <- ledgr_replay_accounting_events(
    prepared,
    initial_cash = replay_start_state$cash,
    initial_positions = replay_start_state$positions,
    lot_state = replay_start_state$lot_state
  )
  state <- list(
    cash = replay$cash,
    positions = replay$positions,
    lot_state = replay$lot_state
  )
  processed <- if (is.null(fold)) NA_integer_ else fold$processed
  summarize_case(
    case_id, if (is.null(compiled_accounting_model)) "canonical_r" else
      compiled_accounting_model,
    events, state, error, processed
  )
}

run_case_1 <- function() {
  run_id <- "proto-case_1"
  rows <- make_rows(
    run_id, as.POSIXct("2024-01-02 21:00:00", tz = "UTC"),
    "PARENT", 5, 10, 1L, "baseline"
  )
  prepared <- ledgr_prepare_accounting_events(
    rows, instrument_ids = c("PARENT", "CHILD")
  )
  replay <- ledgr_replay_accounting_events(prepared, initial_cash = 1000)
  state <- list(
    cash = replay$cash,
    positions = replay$positions,
    lot_state = replay$lot_state
  )
  evidence <- run_direct_case(
    "case_1", state, pre_fold_rows = rows,
    replay_start_state = initial_state()
  )
  if (!gut_mode && (!identical(prepared$operation, 3L) ||
      !isTRUE(all.equal(evidence$parent_position, 5)) ||
      !isTRUE(all.equal(evidence$parent_lot_net, 5)) ||
      evidence$operation3_count != 1L)) {
    stop("CASE_1_PREMISE_FAILED", call. = FALSE)
  }
  evidence
}

run_case_9 <- function(scratch_root) {
  prior <- options(
    ledgr.interrupt = FALSE,
    ledgr.spike_interrupt_done = FALSE,
    ledgr.spike_operation3_injector = make_injector("case_9")
  )
  on.exit(options(prior), add = TRUE)
  pulses <- as.POSIXct("2024-01-02 21:00:00", tz = "UTC") + 86400 * 0:2
  bars <- expand.grid(
    instrument_id = c("PARENT", "CHILD"),
    ts_utc = pulses,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  bars <- bars[order(bars$instrument_id, bars$ts_utc), , drop = FALSE]
  bars$open <- ifelse(bars$instrument_id == "PARENT", 10, 20)
  bars$high <- bars$open
  bars$low <- bars$open
  bars$close <- bars$open
  bars$volume <- 1000
  db_path <- file.path(scratch_root, "case-9.duckdb")
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    if (!isTRUE(getOption("ledgr.spike_interrupt_done", FALSE))) {
      options(
        ledgr.interrupt = TRUE,
        ledgr.spike_interrupt_done = TRUE
      )
    }
    ctx$hold()
  }
  experiment <- ledgr_experiment(
    snapshot, strategy, cost_model = ledgr_cost_zero()
  )
  first <- ledgr_run(experiment, run_id = "proto-case_9")
  close(first)
  options(ledgr.interrupt = FALSE)
  resumed <- ledgr_run(experiment, run_id = "proto-case_9")
  close(resumed)
  reopened <- ledgr_run_open(snapshot, "proto-case_9")
  on.exit(close(reopened), add = TRUE)
  equity <- ledgr_compute_equity_curve(reopened)
  store <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(store), add = TRUE)
  events <- DBI::dbGetQuery(
    store$con,
    paste(
      "SELECT event_id, run_id, ts_utc, event_type, instrument_id,",
      "side, qty, price, fee, meta_json, event_seq",
      "FROM ledger_events WHERE run_id = ? ORDER BY event_seq"
    ),
    params = list("proto-case_9")
  )
  prepared <- ledgr_prepare_accounting_events(
    events, instrument_ids = c("PARENT", "CHILD")
  )
  replay <- ledgr_replay_accounting_events(prepared, initial_cash = 100000)
  state <- list(
    cash = replay$cash,
    positions = replay$positions,
    lot_state = replay$lot_state
  )
  out <- summarize_case(
    "case_9", "canonical_r", events, state,
    processed = nrow(equity), reopened = TRUE
  )
  out
}

scratch <- tempfile("ledgr-settlement-fork-")
dir.create(scratch, recursive = TRUE)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
copy_tracked_package(repo_root, scratch)
install_injection_seam(scratch)
if (gut_mode) gut_operation3_branch(scratch)
pkgload::load_all(scratch, quiet = TRUE, export_all = TRUE)

baseline <- run_case_1()
if (!gut_mode) message("CASE_1_BASELINE_OK")

fill_calls <- 0L
fill_strategy <- function(ctx, params) {
  fill_calls <<- fill_calls + 1L
  targets <- ctx$hold()
  if (fill_calls == 1L) targets[["PARENT"]] <- 2
  targets
}
cases <- list(
  baseline,
  run_direct_case("case_2", initial_state()),
  run_direct_case("case_3", initial_state(), strategy = fill_strategy),
  run_direct_case("case_4", initial_state()),
  run_direct_case("case_5", initial_state(parent = 5)),
  run_direct_case("case_6", initial_state(parent = 2)),
  run_direct_case("case_7", initial_state(parent = 2)),
  run_direct_case(
    "case_8", initial_state(), compiled_accounting_model = "spot_fifo"
  ),
  run_case_9(scratch)
)
evidence <- do.call(rbind, cases)
row.names(evidence) <- NULL
output_arg <- match("--output-dir", args)
output_dir <- if (!is.na(output_arg) && length(args) >= output_arg + 1L) {
  args[[output_arg + 1L]]
} else {
  file.path(repo_root, "dev", "spikes", "settlement_quantity_primitive", "evidence")
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
  evidence,
  file.path(output_dir, "cases.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
print(evidence)
message("SETTLEMENT_QUANTITY_PRIMITIVE_RUN_COMPLETE")
