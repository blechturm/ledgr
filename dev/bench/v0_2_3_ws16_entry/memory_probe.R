# Resident memory by component at the pin, for one committed run and its
# reads, in a fresh process. Input to the WS16 memory-preparation workstream.
#
#   Rscript memory_probe.R --lib=<installed build> --mode=prepare --db=<path> --inst=500 --days=2520
#   Rscript memory_probe.R --lib=<installed build> --mode=measure --db=<path> --out=<dir> [--lookback=252] [--verify=false]
#   Rscript memory_probe.R --lib=<installed build> --mode=measure --state=<private build-state.json> --out=<dir>
#
# prepare builds and seals a portable momentum snapshot in its own process, so
# simulation and import never count. measure copies the sealed store, opens it
# with verify = TRUE, runs monthly top-20 momentum on one returns feature (the
# registered H1 strategy; with --state, the private H1 workload itself), and
# reads fills and equity. At each phase it records this process's current
# and lifetime-peak private commit and working set. At fold entry and exit it
# sizes the named components (utils::object.size; shared memory between
# components is counted in each) and every stack object of at least 1 MB.
# Private runs print and write aggregates only.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "common.R"))
  source(file.path(here, "workloads.R"))
})
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
commit <- ws16_load_installed(ws16_need("lib"))
mode <- ws16_need("mode")

if (identical(mode, "prepare")) {
  db <- ws16_need("db")
  inst <- as.integer(ws16_need("inst"))
  days <- as.integer(ws16_need("days"))
  if (file.exists(db)) stop("The store already exists.", call. = FALSE)
  # The store file is named after its snapshot.
  snap <- ws16_momentum_snapshot(inst, days, db, sub("\\.duckdb$", "", basename(db)))
  ledgr_snapshot_close(snap)
  cat("prepared", db, "\n")
  quit(save = "no")
}

out <- ws16_out(ws16_need("out"))
if (length(list.files(out))) stop("The output directory must be new and empty.", call. = FALSE)
state_path <- ws16_arg("state")
# H1 opens the sealed store with verify = TRUE; ledgr_snapshot_open() defaults to FALSE.
verify <- !identical(ws16_arg("verify", "true"), "false")
private <- !is.null(state_path)
me <- ps::ps_handle()
marks <- list()
mark <- function(phase) {
  m <- ps::ps_memory_info(me)
  marks[[length(marks) + 1L]] <<- data.frame(
    phase = phase, private_mib = m[["pagefile"]] / 2^20, wset_mib = m[["wset"]] / 2^20,
    peak_private_mib = m[["peak_pagefile"]] / 2^20, peak_wset_mib = m[["peak_wset"]] / 2^20)
}
mark("loaded")

# Bytes of an object, following environments once each.
seen <- new.env()
size_of <- function(x, depth = 0L) {
  if (is.environment(x)) {
    id <- format(x)
    if (!is.null(seen[[id]]) || depth > 4L || identical(x, globalenv()) ||
        isNamespace(x) || identical(x, emptyenv())) return(0)
    seen[[id]] <- TRUE
    return(sum(vapply(as.list.environment(x, all.names = TRUE), size_of, numeric(1), depth = depth + 1L)))
  }
  if (is.function(x)) return(0)
  as.numeric(utils::object.size(x))
}
fresh_size <- function(x) {
  rm(list = ls(seen), envir = seen)
  size_of(x)
}
components <- list()
record <- function(at, group, name, x) {
  components[[length(components) + 1L]] <<- data.frame(at = at, group = group, name = name,
                                                        mib = fresh_size(x) / 2^20)
}
stack_objects <- function(at) {
  frames <- sys.frames()
  calls <- sys.calls()
  for (i in seq_along(frames)) {
    fn <- calls[[i]][[1L]]
    fn <- if (is.symbol(fn)) as.character(fn) else if (is.call(fn) && length(fn) == 3L) as.character(fn[[3L]]) else "?"
    # Formals may be unevaluated promises; forcing them would change the
    # run, so only local variables are scanned (large arguments are locals
    # of a caller frame).
    args <- names(formals(sys.function(i)))
    for (nm in setdiff(ls(frames[[i]], all.names = TRUE), args)) {
      v <- tryCatch(get(nm, envir = frames[[i]]), error = function(e) NULL)
      if (is.function(v) || is.environment(v)) next
      b <- as.numeric(utils::object.size(v))
      if (b >= 2^20) record(at, paste0("stack:", fn), nm, v)
    }
  }
}

# Enter/exit marks around the preparation and publication steps, so a jump
# in the lifetime peak names the step that caused it.
marked <- c("ledgr_history_substrate", "ledgr_history_compute_feature_series",
            "ledgr_projection_from_feature_matrix", "ledgr_availability_provider_from_substrate",
            "ledgr_history_substrate_fold_reader", "ledgr_availability_valuation_state",
            "ledgr_diagnostic_decision_order_bad")
for (fn in marked) {
  local({
    name <- fn
    ws16_wrap(name, function(orig) {
      force(orig)
      function(...) {
        mark(paste("enter", name))
        on.exit(mark(paste("exit", name)))
        orig(...)
      }
    })
  })
}

ws16_wrap("ledgr_fold_envelope", function(orig) {
  force(orig)
  function(execution, output_handler) {
    if (is.function(output_handler$write_run_evidence)) {
      evidence <- output_handler$write_run_evidence
      output_handler$write_run_evidence <- function(...) {
        mark("enter write_run_evidence")
        on.exit(mark("exit write_run_evidence"))
        evidence(...)
      }
    }
    mark("fold entry")
    for (f in names(execution$history_substrate)) {
      record("fold entry", "history_substrate", f, execution$history_substrate[[f]])
    }
    for (f in setdiff(names(execution), "history_substrate")) record("fold entry", "execution", f, execution[[f]])
    stack_objects("fold entry")
    res <- orig(execution, output_handler)
    mark("fold exit")
    henv <- environment(output_handler$init_buffers)
    for (nm in ls(henv, all.names = TRUE)) {
      v <- get(nm, envir = henv)
      if (!is.function(v)) record("fold exit", "output_handler", nm, v)
    }
    for (f in names(res)) record("fold exit", "fold_result", f, res[[f]])
    res
  }
})

work <- file.path(out, "work")
dir.create(work)
store <- file.path(work, "store.duckdb")
if (private) {
  state <- jsonlite::read_json(state_path, simplifyVector = TRUE)
  if (!file.copy(state$snapshot_path, store)) stop("Could not copy the sealed snapshot.", call. = FALSE)
  snapshot <- ledgr::ledgr_snapshot_open(store, state$snapshot_id, verify = verify)
  mark("snapshot opened")
  exp <- ledgr::ledgr_experiment(snapshot, ws16_momentum_strategy, features = list(ledgr::ledgr_ind_returns(252L)),
                                 schedule = ledgr::ledgr_schedule_month_start(),
                                 universe = ledgr::ledgr_universe_members(state$universe_id),
                                 valuation_policy = ledgr::ledgr_valuation_stale(5L),
                                 cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6))
  params <- list(lookback = 252L, n = 20L)
  shape <- "private_h1"
} else {
  db <- ws16_need("db")
  if (!file.copy(db, store)) stop("Could not copy the prepared store.", call. = FALSE)
  id <- sub("\\.duckdb$", "", basename(db))
  snapshot <- ledgr::ledgr_snapshot_open(store, id, verify = verify)
  mark("snapshot opened")
  lookback <- as.integer(ws16_arg("lookback", "252"))
  exp <- ws16_momentum_experiment(snapshot, lookback)
  params <- list(lookback = lookback, n = 20L)
  shape <- id
}
mark("experiment built")
t0 <- proc.time()[["elapsed"]]
bt <- ledgr::ledgr_run(exp, params = params, run_id = "ws16-mem", seed = 1L)
t1 <- proc.time()[["elapsed"]]
mark("ledgr_run returned")
fills <- ledgr::ledgr_results(bt, "fills")
mark("fills read")
equity <- ledgr::ledgr_results(bt, "equity")
mark("equity read")
info <- data.frame(shape = shape, commit = commit, verify = verify, run_s = t1 - t0, n_fills = nrow(fills),
                   n_equity = nrow(equity), store_mib = file.size(store) / 2^20)
close(bt)
ledgr::ledgr_snapshot_close(snapshot)
mark("closed")

marks <- cbind(shape = shape, do.call(rbind, marks))
components <- cbind(shape = shape, do.call(rbind, components))
ws16_write(marks, file.path(out, "memory_phases.csv"))
ws16_write(components, file.path(out, "memory_components.csv"))
ws16_write(info, file.path(out, "memory_run.csv"))
unlink(work, recursive = TRUE)
print(info)
print(marks, row.names = FALSE)
