# WS4a case harness (LDG-3163 scope c; ws4a_carrier_design.md Section 4).
#
# Shared by record.R, check.R and guts.R. Serialization, store and sweep
# collection, memory observation and namespace patching are the unchanged A0
# harness (dev/bench/v0_2_3_output_freeze/lib.R), sourced, not copied. Each
# case returns canonical tables, the facts that prove its precondition ran,
# and private observations that are written but never compared.
#
# Injection seams are bindings that exist on base 953338df; ws4a_seams names
# them. A later ticket that moves a seam adds its typed attachment beside the
# base one and keeps the case's frozen outputs.

ws_dir <- local({
  files <- Filter(is.character, lapply(seq_len(sys.nframe()), function(i) sys.frame(i)$ofile))
  dirname(normalizePath(files[[length(files)]], winslash = "/"))
})
ws_root <- normalizePath(file.path(ws_dir, "..", "..", ".."), winslash = "/")
ws_arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
suppressMessages(pkgload::load_all(ws_root, quiet = TRUE))
source(file.path(ws_root, "dev", "bench", "v0_2_3_output_freeze", "lib.R"))
a0_exclusions <- rbind(a0_exclusions, data.frame(table = "wf_folds", column = "selected_at_utc",
  reason = "wall clock at walk-forward selection", stringsAsFactors = FALSE))

ws4a_seams <- c(
  planner_return = "ledgr_fold_build_availability_pulse_plan",
  p3_return = "ledgr_fold_stage_plan",
  p4 = "ledgr_fold_stage_apply",
  p5 = "ledgr_fold_stage_commit",
  lot_fill = "ledgr_lot_apply_fill",
  lot_opening = "ledgr_lot_apply_opening",
  kahan = "ledgr_lot_add_realized",
  compiled_batch = "ledgr_run_compiled_spot_fifo_batch",
  compiled_unpack = "ledgr_compiled_spot_fifo_unpack_lots",
  handler = "ledgr_output_handler",
  diagnostic_writer = "ledgr_fold_diagnostic_writer",
  finalize = "ledgr_run_finalize",
  replay = "ledgr_replay_accounting_events",
  prefix_commit = "ledgr_run_equity_prefix_commit"
)

# --- Fixtures and paths ------------------------------------------------------

ws_day <- function(k) as.POSIXct(paste(as.Date("2020-01-01") + k - 1L, "16:00:00"), tz = "UTC")
ws_iso <- function(k) format(ws_day(k), "%Y-%m-%d")
ws_env <- new.env(parent = emptyenv())

# closes: named list of per-day closes, NA where an instrument has no bar.
ws_fixture <- function(id, closes, opens = closes, avail = TRUE, facts = list()) {
  n <- max(lengths(closes))
  bars <- do.call(rbind, lapply(names(closes), function(i) {
    k <- which(!is.na(closes[[i]]))
    cl <- closes[[i]][k]
    op <- opens[[i]][k]
    data.frame(ts_utc = ws_day(k), instrument_id = i, open = op, high = pmax(op, cl) + 1,
      low = pmin(op, cl) - 1, close = cl, volume = 1000, stringsAsFactors = FALSE)
  }))
  db <- file.path(ws_env$work, paste0(id, ".duckdb"))
  unlink(db)
  assign(normalizePath(db, winslash = "/", mustWork = FALSE), "<DB_PATH>", envir = a0_path_tokens)
  snap <- if (avail) {
    sessions <- a0_sessions(as.Date("2020-01-01") + seq_len(n) - 1L)
    ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = names(closes)), db_path = db,
      snapshot_id = id, facts = do.call(ledgr_facts, c(list(sessions), facts)), price_basis = "split_adjusted")
  } else {
    ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = id)
  }
  ws_env$snaps <- c(ws_env$snaps, list(snap))
  list(snap = snap, db = db)
}

# Targets by ISO day from params$plan; instruments not named are held.
ws_plan_strategy <- function(ctx, params) {
  target <- ctx$hold()
  set <- params$plan[[substr(ctx$ts_utc, 1L, 10L)]]
  for (id in intersect(names(set), names(target))) target[[id]] <- set[[id]]
  if (isTRUE(params$plan$state)) return(list(targets = target, state_update = list(ts = ctx$ts_utc, n = length(target))))
  target
}
ws_grid <- function(plan) ledgr_grid_named(c1 = list(strategy = list(plan = plan)))
ws_chain <- function() ledgr_cost_chain(ledgr_cost_spread_bps(7), ledgr_cost_fixed_fee(1.25), ledgr_cost_notional_bps_fee(3))
ws_exp <- function(fx, cost = ws_chain(), ...) {
  ledgr_experiment(fx$snap, ws_plan_strategy, cost_model = cost, ...)
}

ws_prefix <- function(x, prefix) stats::setNames(x, paste(prefix, names(x), sep = "."))

# A committed run: every run-store table, the public readers and conditions.
ws_durable <- function(fx, exp, rid, plan = NULL, prefix = "run", ...) {
  sink <- a0_new_sink()
  ok <- a0_run_or_record(ledgr_run(exp, params = list(plan = plan), run_id = rid, seed = 1L, ...), rid, sink)
  out <- c(a0_store_tables(fx$db, rid), if (ok) a0_reader_tables(fx$snap, rid),
    list(conditions = a0_canon(sink$rows, "run_conditions", "seq")))
  ws_prefix(out, prefix)
}

# A one-candidate sweep through the memory sink, observed as A0 observes it.
ws_memory <- function(exp, plan, prefix = "sweep", ...) {
  obs <- a0_observe_memory(ledgr_sweep(exp, ws_grid(plan), seed = 1L, retain = a0_retain(), ...))
  ws_prefix(c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value)), prefix)
}

ws_frame <- function(df, name, key) a0_canon(df, name, key)
ws_need <- function(ok, what) if (!isTRUE(all(ok))) stop("ws4a precondition failed: ", what, call. = FALSE)

# Named arguments of a call to `original`, matched as the product passed them.
ws_args <- function(original, ...) as.list(match.call(original, as.call(c(list(quote(f)), list(...)))))[-1L]

# a0_with_patches with each original forced at install time; A0 binds it
# lazily, which is only safe for one patch at a time.
ws_patches <- function(patches, expr) {
  a0_with_patches(lapply(patches, function(p) function(original) {
    force(original)
    p(original)
  }), expr)
}

# hooks: binding name -> function(args, value); runs after each call.
ws_trace <- function(hooks, expr) {
  patches <- lapply(hooks, function(hook) function(original) function(...) {
    value <- original(...)
    hook(ws_args(original, ...), value)
    value
  })
  ws_patches(patches, expr)
}
ws_counter <- function(names) {
  counts <- new.env(parent = emptyenv())
  for (n in names) counts[[n]] <- 0L
  hooks <- lapply(stats::setNames(names, names), function(n) function(args, value) counts[[n]] <- counts[[n]] + 1L)
  list(hooks = hooks, get = function() unlist(mget(names, counts)))
}

# Logical FIFO book: live lots per instrument plus exact aggregates.
ws_book <- function(state) {
  ids <- state$instrument_ids
  lots <- do.call(rbind, c(list(data.frame(instrument_id = character(), lot = integer(), qty = numeric(),
    price = numeric())), lapply(ids, function(id) {
    v <- ledgr_lot_values(state, id)
    data.frame(instrument_id = rep(id, length(v$qty)), lot = seq_along(v$qty), qty = v$qty, price = v$price)
  })))
  totals <- data.frame(field = c("total_cost_basis", "realized_pnl", "realized_comp"),
    value = c(state$total_cost_basis, state$realized_pnl, state$realized_comp))
  aggr <- data.frame(instrument_id = ids, net = unname(as.numeric(state$net_by_inst[ids])),
    basis = unname(as.numeric(state$cost_basis_by_inst[ids])))
  list(book_lots = ws_frame(lots, "book_lots", c("instrument_id", "lot")),
    book_totals = ws_frame(totals, "book_totals", "field"),
    book_aggregates = ws_frame(aggr, "book_aggregates", "instrument_id"))
}
ws_ledger <- function(db, rid) {
  a0_with_store(db, function(con) DBI::dbGetQuery(con,
    "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(rid)))
}
ws_replay_book <- function(db, rid, ids) ws_book(ledgr_lot_state_from_events(ws_ledger(db, rid), ids))
ws_hex <- function(x) sprintf("%a", x)
ws_fingerprint <- function(x) digest::digest(a0_flat(x), algo = "sha256")

ws_cases <- list()
ws_case <- function(id, owner, fn, typed = NULL) ws_cases[[id]] <<- list(owner = owner, fn = fn, typed = typed)

# Runs one case into canonical form. A case error becomes the case_error
# table, so check.R reports it as a difference rather than crashing.
ws_run_case <- function(id, work) {
  ws_env$work <- work
  ws_env$snaps <- list()
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  options(ledgr.interrupt = FALSE)
  on.exit(for (s in ws_env$snaps) try(ledgr_snapshot_close(s), silent = TRUE), add = TRUE)
  res <- tryCatch(ws_cases[[id]]$fn(), error = function(e) {
    list(tables = list(case_error = data.frame(class = paste(class(e), collapse = "/"),
      message = a0_detokenize(conditionMessage(e)))), facts = list())
  })
  facts <- res$facts %||% list()
  res$tables$facts <- data.frame(fact = names(facts), value = vapply(facts, a0_flat, character(1)),
    stringsAsFactors = FALSE)
  res
}

ws_write_case <- function(res, dir) {
  unlink(dir, recursive = TRUE)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  for (t in names(res$tables)) a0_write_table(res$tables[[t]], file.path(dir, paste0(t, ".csv")))
  saveRDS(res[c("tables", "facts")], file.path(dir, "case.rds"), version = 3L)
  if (!is.null(res$observed)) saveRDS(res$observed, file.path(dir, "observed_not_oracle.rds"), version = 3L)
}

source(file.path(ws_dir, "cases.R"))
