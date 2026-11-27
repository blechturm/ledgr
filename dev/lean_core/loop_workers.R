# Sweep workers run the lean fold (Cut 26 decision 5; interface Sections
# 19.2 point 3 and 19.14). Harness only: nothing in R/ calls this, and the
# switch retires it (workers then load the lean fold with the package).
#
# The pin starts a sweep's workers in ledgr_parallel_worker_setup(); each
# loads the pinned library. lean_loop_install() binds lean_worker_setup() over
# it (gate and inert modes alike): after the pin's own setup, every worker
# loads the lean core from the same pinned library with the parent's debug
# setting and any variant's registered edits, and installs the lean loop with
# the parent's hook mode. Each worker then wraps two bindings of its own:
# - the fold envelope, counting entries and whether each entered the lean
#   envelope (outside the fold hooks, so inert workers are witnessed too),
#   and recording the class of an error that ends an entry before its fold;
# - the candidate task, which resets the worker's entry record, watches
#   every store call over the whole candidate (a worker writes nothing
#   durable), and writes one record file per task, on every exit path.
# The parent records the tasks it dispatches (lean_worker_dispatch()); the
# restore of lean_loop_install() merges the records into `lean_entry`
# (counters by sum, bounds by maximum) after checking them: one record per
# dispatched task, none missing, duplicated, undispatched or from another
# attempt; every worker booted; every record from the pinned build, the lean
# envelope, the parent's debug setting and hook mode; with the harness hooks,
# every entry a lean fold, a coverage refusal or an error before the fold
# (an early exit without an error faults). A failed check is a
# worker fault (`lean_entry$worker_faults`), which loop_parity.R reports.

lean_workers <- new.env(parent = emptyenv())
lean_workers$opened <- 0L
lean_workers$edits <- list()        # a variant's registered edits, for its workers (loop_parity.R)
lean_workers$edits_file <- ""
lean_workers$marker <- NULL

# A fresh channel for one install (one workload attempt). `pinned` holds the
# bindings lean_loop_install() replaces; the worker setup and dispatch call
# the ones it found.
lean_workers_open <- function(hooks, pinned) {
  lean_workers$opened <- lean_workers$opened + 1L
  lean_workers$attempt <- paste(Sys.getpid(), lean_workers$opened, format(Sys.time(), "%Y%m%d%H%M%OS6"), sep = "-")
  lean_workers$channel <- tempfile("lean_worker_channel_")
  dir.create(lean_workers$channel)
  lean_workers$hooks <- if (hooks) "harness" else "inert"
  lean_workers$inner_setup <- pinned$ledgr_parallel_worker_setup
  lean_workers$inner_dispatch <- pinned$ledgr_sweep_eval_candidate_tasks_parallel
  lean_workers$sweep_seq <- 0L
  lean_workers$booted <- 0L
  lean_workers$dispatched <- character()
}

# Parent: the pin's setup, then the lean core in every worker it started.
lean_worker_setup <- function(workers = 1L, preflight, worker_packages = NULL, backend = "mirai",
                              backend_available = NULL, dry_run = TRUE) {
  plan <- lean_workers$inner_setup(workers = workers, preflight = preflight, worker_packages = worker_packages,
                                   backend = backend, backend_available = backend_available, dry_run = dry_run)
  n <- ledgr_parallel_workers_normalize(workers)
  if (isTRUE(dry_run) || n <= 1L) return(plan)
  lean_workers$sweep_seq <- lean_workers$sweep_seq + 1L
  lean_workers$booted <- lean_workers$booted + n
  spec <- list(load_r = file.path(.lean_home, "load.R"), lib = .lean_lib, debug = .lean_debug,
               hooks = lean_workers$hooks, attempt = lean_workers$attempt, channel = lean_workers$channel,
               sweep_seq = lean_workers$sweep_seq, batch_rows = lean_entry$batch_rows,
               capacity = lean_entry$capacity, backstop_after = lean_entry$backstop_after,
               mutation = lean_entry$mutation, edits = lean_workers$edits,
               edits_file = lean_workers$edits_file, marker = lean_workers$marker)
  ledgr_parallel_mirai_everywhere_expr(substitute({
    .lean_spec <- SPEC
    .lean_boot <- tryCatch({
      source(.lean_spec$load_r)
      .lean <- lean_core_load(.lean_spec$lib, debug = .lean_spec$debug)
      if (length(.lean_spec$edits)) {
        source(.lean_spec$edits_file)
        lean_load_edited(.lean, .lean$.lean_home, .lean_spec$edits, marker = .lean_spec$marker)
      }
      .lean$lean_worker_start(.lean_spec)
      ""
    }, error = function(e) conditionMessage(e))
    saveRDS(list(attempt = .lean_spec$attempt, sweep_seq = .lean_spec$sweep_seq, pid = Sys.getpid(), error = .lean_boot),
            file.path(.lean_spec$channel, paste0("boot_", .lean_spec$sweep_seq, "_", Sys.getpid(), ".rds")))
    TRUE
  }, list(SPEC = spec)), workers = n)
  plan
}

# Parent: the tasks the pin dispatches, by sweep and candidate run id.
lean_worker_dispatch <- function(tasks, workers, submit = NULL, value = NULL, cleanup = ledgr_parallel_mirai_stop) {
  ids <- vapply(tasks, function(t) as.character(t$run_id), character(1L))
  lean_workers$dispatched <- c(lean_workers$dispatched, paste(lean_workers$sweep_seq, ids, sep = "|"))
  lean_workers$inner_dispatch(tasks, workers, submit = submit, value = value, cleanup = cleanup)
}

# Worker: install the lean loop and the two counting bindings.
lean_worker_start <- function(spec) {
  lean_entry$variant_reached <- FALSE   # a variant's marker, once per worker
  lean_loop_install(hooks = identical(spec$hooks, "harness"))
  lean_workers$spec <- spec
  lean_workers$tasks <- 0L
  ns <- asNamespace("ledgr")
  lean_wrap_binding(ns, "ledgr_fold_envelope", function(f) function(execution, output_handler) {
    lean_workers$entries <- lean_workers$entries + 1L
    lean_workers$lean <- c(lean_workers$lean, identical(f, lean_fold_envelope))
    # An entry that an error ends before its fold starts, with no coverage
    # refusal (the pin's E-stage admission refusals, say), has that error as
    # its outcome: its class is recorded, and the condition passes on
    # unchanged (WS46 close review round 1, F1). An entry that leaves early
    # without an error records NA, which the parent faults.
    folds <- lean_entry$lean_folds
    refused <- length(lean_entry$refused)
    last <- NA_character_
    done <- FALSE
    on.exit(if (!done && lean_entry$lean_folds == folds && length(lean_entry$refused) == refused) {
      lean_workers$prefold <- c(lean_workers$prefold, last)
    })
    value <- withCallingHandlers(f(execution, output_handler), error = function(e) last <<- class(e)[[1L]])
    done <- TRUE
    value
  })
  lean_wrap_binding(ns, "ledgr_sweep_worker_eval_candidate_task", function(f) function(task) lean_worker_task(f, task))
  invisible(TRUE)
}

# The hook mode actually installed: the inert set, or the harness's.
lean_hooks_mode <- function() {
  inert <- lean_hooks_inert()
  if (identical(names(lean_hooks), names(inert)) && identical(lapply(lean_hooks, body), lapply(inert, body))) "inert"
  else "harness"
}

# Worker: one candidate task, with its record written on every exit path.
lean_worker_task <- function(inner, task) {
  spec <- lean_workers$spec
  lean_entry_reset()
  lean_entry$batch_rows <- spec$batch_rows
  lean_entry$capacity <- spec$capacity
  lean_entry$backstop_after <- spec$backstop_after
  lean_entry$mutation <- spec$mutation
  lean_workers$entries <- 0L
  lean_workers$lean <- logical()
  lean_workers$prefold <- character()
  lean_workers$store_any <- character()
  lean_workers$tasks <- lean_workers$tasks + 1L
  unwatch <- lean_watch_durable()
  on.exit({
    unwatch()
    rec <- c(list(attempt = spec$attempt, sweep_seq = spec$sweep_seq, run_id = as.character(task$run_id),
                  pid = Sys.getpid(), origin = normalizePath(getNamespaceInfo("ledgr", "path"), winslash = "/"),
                  entries = lean_workers$entries, envelope_lean = lean_workers$lean, prefold = lean_workers$prefold,
                  debug = .lean_debug,
                  hooks = lean_hooks_mode(), store_any = lean_workers$store_any),
             mget(c("lean_folds", "refused", "backstop", "store_access", "sink_calls", "terminal_appends",
                    "max_append_rows", "hold_calls", "hold_rows", "max_range_pulses", "variant_reached"),
                  envir = lean_entry))
    saveRDS(rec, file.path(spec$channel, sprintf("rec_%d_%d_%d.rds", spec$sweep_seq, Sys.getpid(), lean_workers$tasks)))
  }, add = TRUE)
  inner(task)
}

# Worker: every DuckDB backend bridge and the package writer, over the whole
# candidate (a worker candidate writes to its memory sink only).
lean_watch_durable <- function() {
  restores <- list()
  duckdb_ns <- asNamespace("duckdb")
  for (name in grep("^rapi_", ls(duckdb_ns), value = TRUE)) {
    restores[[length(restores) + 1L]] <- lean_wrap_binding(duckdb_ns, name, function(f) {
      label <- paste0("duckdb:::", name)
      function(...) {
        lean_workers$store_any <- c(lean_workers$store_any, label)
        f(...)
      }
    })
  }
  restores[[length(restores) + 1L]] <- lean_wrap_binding(asNamespace("ledgr"), "ledgr_store_append", function(f) {
    function(con, name, value) {
      lean_workers$store_any <- c(lean_workers$store_any, "ledgr::ledgr_store_append")
      f(con, name, value)
    }
  })
  function() for (r in rev(restores)) r()
}

# Parent, at restore: check the channel and merge its records.
lean_workers_merge <- function() {
  files <- list.files(lean_workers$channel, full.names = TRUE)
  boots <- lapply(files[startsWith(basename(files), "boot_")], readRDS)
  recs <- lapply(files[startsWith(basename(files), "rec_")], readRDS)
  faults <- character()
  fault <- function(...) faults <<- c(faults, sprintf(...))
  if (length(boots) != lean_workers$booted) fault("worker boots: %d of %d reported", length(boots), lean_workers$booted)
  for (b in boots) if (nzchar(b$error)) fault("worker %d failed to load the lean core: %s", b$pid, b$error)
  attempts <- vapply(c(boots, recs), function(r) as.character(r$attempt), character(1L))
  if (any(attempts != lean_workers$attempt)) fault("worker records from another attempt: %d", sum(attempts != lean_workers$attempt))
  keys <- vapply(recs, function(r) paste(r$sweep_seq, r$run_id, sep = "|"), character(1L))
  if (length(m <- setdiff(lean_workers$dispatched, keys))) fault("worker records missing: %s", paste(m, collapse = ", "))
  if (length(d <- unique(keys[duplicated(keys)]))) fault("worker records duplicated: %s", paste(d, collapse = ", "))
  if (length(x <- setdiff(keys, lean_workers$dispatched))) fault("worker records not dispatched: %s", paste(x, collapse = ", "))
  # the pinned build this lean environment was loaded over (load.R)
  declared <- if (file.exists(file.path(.lean_lib, "LEDGR_SOURCE_COMMIT"))) .lean_lib else file.path(.lean_lib, "ledgr")
  for (r in recs) {
    id <- paste(r$sweep_seq, r$run_id, sep = "|")
    if (!identical(r$origin, declared)) fault("worker %s loaded %s, not %s", id, r$origin, declared)
    if (!all(r$envelope_lean)) fault("worker %s entered the pinned envelope", id)
    if (!identical(r$debug, .lean_debug)) fault("worker %s ran with debug %s", id, r$debug)
    if (!identical(r$hooks, lean_workers$hooks)) fault("worker %s ran with %s hooks", id, r$hooks)
    if (identical(r$hooks, "harness") && r$lean_folds + length(r$refused) + length(r$prefold) != r$entries) {
      fault("worker %s: %d lean folds, %d refusals and %d errors before the fold for %d envelope entries",
            id, r$lean_folds, length(r$refused), length(r$prefold), r$entries)
    }
    if (anyNA(r$prefold)) fault("worker %s: an envelope entry left before its fold without an error", id)
  }
  for (f in c("lean_folds", "hold_calls", "hold_rows")) {
    lean_entry[[f]] <- lean_entry[[f]] + sum(vapply(recs, function(r) as.numeric(r[[f]]), 0))
  }
  for (f in c("max_append_rows", "max_range_pulses")) {
    lean_entry[[f]] <- max(c(lean_entry[[f]], vapply(recs, function(r) as.numeric(r[[f]]), 0)))
  }
  for (f in c("refused", "backstop", "store_access", "sink_calls", "terminal_appends")) {
    lean_entry[[f]] <- c(lean_entry[[f]], unlist(lapply(recs, `[[`, f)))
  }
  lean_entry$worker_store <- c(lean_entry$worker_store, unlist(lapply(recs, `[[`, "store_any")))
  if (any(vapply(recs, function(r) isTRUE(r$variant_reached), logical(1L)))) lean_entry$variant_reached <- TRUE
  lean_entry$worker_faults <- c(lean_entry$worker_faults, faults)
  lean_entry$worker_records <- lean_entry$worker_records + length(recs)
  lean_entry$worker_entries <- lean_entry$worker_entries + sum(vapply(recs, function(r) as.numeric(r$entries), 0))
  lean_entry$worker_table <- rbind(lean_entry$worker_table, do.call(rbind, lapply(recs, function(r) data.frame(
    attempt = r$attempt, sweep_seq = r$sweep_seq, run_id = r$run_id, pid = r$pid, origin = r$origin,
    entries = r$entries, lean = all(r$envelope_lean), prefold = paste(r$prefold, collapse = "; "),
    debug = r$debug, hooks = r$hooks, lean_folds = r$lean_folds,
    backstop = paste(r$backstop, collapse = "; "), store_any = length(r$store_any), stringsAsFactors = FALSE))))
  invisible(faults)
}
