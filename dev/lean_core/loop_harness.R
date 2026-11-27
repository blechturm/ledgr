# The harness side of the compact-state lean loop (interface Sections 19.1,
# 19.2 and 19.6). The fold (loop.R) reaches it only through
# `lean_hooks`; lean_loop_install() replaces the inert default with
# lean_harness_hooks() and binds the lean envelope, the context read
# method and the entry recorders over the pin. Only harnesses call these;
# nothing in R/ does.
#
# What the harness adds around a lean fold:
# - the entry record (`lean_entry`): folds run lean, refusals, attempt marks;
# - the entry refusal the fold cannot see: a control$checkpoint_every key
#   (D3 Section 2); walk-forward and sweep workers run lean (sweep workers
#   through loop_workers.R);
# - the attempt mark and whole-workload retry (19.2 point 1): a coverage
#   condition raised mid-run (lean_abort_attempt()) marks the attempt, and
#   the complete workload reruns on the pin with the entry RNG restored.
#   Slice 3 removed the history-name backstop stubs (Section 19.11): no
#   strategy call is scanned any more. A test seam marks the
#   attempt after a set number of strategy calls (`backstop_after`);
# - two detectors while pulses run: every call into the DuckDB backend
#   bridges (any store statement, registration or relation) and every call
#   to the fold's output handler (the terminal sink);
# - witness seams: a lower fill-event limit, the terminal batch bound, a
#   memory measurement around the terminal transfer.

lean_pin_run_fold <- get("ledgr_run_fold", envir = asNamespace("ledgr"))

# The last fold's pulse-loop and transfer seconds and record statistics.
lean_loop_last_times <- new.env(parent = emptyenv())

lean_entry <- new.env(parent = emptyenv())
lean_entry_reset <- function() {
  lean_entry$lean_folds <- 0L
  lean_entry$refused <- character()           # features refused before a first pulse
  lean_entry$backstop <- character()          # attempt marks: features that force a rerun on the pin
  lean_entry$uncovered <- character()         # stubs reached during the current fold
  lean_entry$control_checkpoint <- FALSE      # the run carries a control$checkpoint_every key
  lean_entry$store_access <- character()      # backend or package-writer calls while pulses run
  lean_entry$sink_calls <- character()        # output-handler calls while pulses run
  lean_entry$terminal_appends <- character()  # tables of completed nonempty appends after the loop
  lean_entry$max_append_rows <- 0L            # largest such append
  lean_entry$hold_calls <- 0L                 # hold expansions while pulses run
  lean_entry$hold_rows <- 0L
  lean_entry$committed <- NULL                # the running fold's committed-prefix reader
  lean_entry$batch_rows <- 65536L             # seam: terminal batch bound (rows)
  lean_entry$capacity <- NULL                 # seam: a lower fill-event limit
  lean_entry$measure <- FALSE                 # seam: record the terminal-transfer peak
  lean_entry$mutation <- ""                   # the text mutation loaded, for the record only
  lean_entry$max_range_pulses <- 0L           # widest expanded pulse range
  lean_entry$backstop_after <- NULL           # seam: mark the attempt after this many strategy calls
  lean_entry$seam_calls <- 0L
  lean_entry$worker_records <- 0L             # sweep-worker records merged (loop_workers.R)
  lean_entry$worker_entries <- 0              # envelope entries the workers observed
  lean_entry$worker_faults <- character()     # failed channel checks
  lean_entry$worker_store <- character()      # store calls in a worker candidate, at any time
  lean_entry$worker_table <- NULL             # one row per worker record
}
lean_entry_reset()

lean_mark <- function(feature) lean_entry$backstop <- c(lean_entry$backstop, feature)

lean_harness_hooks <- function() list(
  entry_refusal = function() {
    if (isTRUE(lean_entry$control_checkpoint)) return("a checkpoint_every control")
    NULL
  },
  refused = function(feature) lean_entry$refused <- c(lean_entry$refused, feature),
  fold_start = function(live) {
    lean_entry$lean_folds <- lean_entry$lean_folds + 1L
    lean_entry$uncovered <- character()
    lean_watch_backend(live)
  },
  handler = function(h, live) lean_watch_handler(h, live),
  uncovered = function() {
    if (!is.null(lean_entry$backstop_after)) {
      lean_entry$seam_calls <- lean_entry$seam_calls + 1L
      if (lean_entry$seam_calls > lean_entry$backstop_after) {
        lean_mark("test seam: backstop")
        return("test seam: backstop")
      }
    }
    lean_entry$uncovered
  },
  mark = lean_mark,
  committed = function(reader) lean_entry$committed <- reader,
  capacity = function(default) lean_entry$capacity %||% default,
  batch_rows = function() lean_entry$batch_rows,
  hold_expansion = function(in_pulses, rows) {
    if (in_pulses) {
      lean_entry$hold_calls <- lean_entry$hold_calls + 1L
      lean_entry$hold_rows <- lean_entry$hold_rows + rows
    }
  },
  publish = function(fn) {
    if (!isTRUE(lean_entry$measure)) return(fn())
    invisible(gc(reset = TRUE))
    fn()
    lean_loop_last_times$publish_peak_mb <- sum(gc()[, 6L])
  },
  fold_end = function(stats) {
    for (name in names(stats)) assign(name, stats[[name]], envir = lean_loop_last_times)
    lean_entry$max_range_pulses <- max(lean_entry$max_range_pulses, stats$capacity[["max_range_pulses"]])
  }
)

# Wraps `name` in `home` for as long as the returned function is not called.
lean_wrap_binding <- function(home, name, make) {
  original <- get(name, envir = home)
  unlockBinding(name, home); assign(name, make(original), envir = home); lockBinding(name, home)
  function() { unlockBinding(name, home); assign(name, original, envir = home); lockBinding(name, home) }
}

# Detector, store side (D3 Section 5): every DuckDB backend bridge (the
# rapi_* functions every DBI statement, bind, registration and relation
# goes through) and the package writer. A call while pulses run is store
# access; slice 1 makes none. After the loop, completed nonempty package
# appends are recorded with their table and size.
lean_watch_backend <- function(live) {
  restores <- list()
  duckdb_ns <- asNamespace("duckdb")
  for (name in grep("^rapi_", ls(duckdb_ns), value = TRUE)) {
    restores[[length(restores) + 1L]] <- lean_wrap_binding(duckdb_ns, name, function(f) {
      label <- paste0("duckdb:::", name)
      function(...) {
        if (isTRUE(live$in_pulses)) lean_entry$store_access <- c(lean_entry$store_access, label)
        f(...)
      }
    })
  }
  restores[[length(restores) + 1L]] <- lean_wrap_binding(asNamespace("ledgr"), "ledgr_store_append", function(f) {
    function(con, name, value) {
      if (isTRUE(live$in_pulses)) lean_entry$store_access <- c(lean_entry$store_access, "ledgr::ledgr_store_append")
      out <- f(con, name, value)
      if (!isTRUE(live$in_pulses) && NROW(value) > 0L) {
        lean_entry$terminal_appends <- c(lean_entry$terminal_appends, as.character(name))
        lean_entry$max_append_rows <- max(lean_entry$max_append_rows, NROW(value))
      }
      out
    }
  })
  function() for (r in rev(restores)) r()
}

# Detector, sink side: every method of the fold's output handler but the
# transaction itself records its name when called while pulses run.
lean_watch_handler <- function(h, live) {
  for (name in setdiff(names(h)[vapply(h, is.function, logical(1L))], "run_transaction")) {
    h[[name]] <- local({
      f <- h[[name]]
      nm <- name
      function(...) {
        if (isTRUE(live$in_pulses)) lean_entry$sink_calls <- c(lean_entry$sink_calls, nm)
        f(...)
      }
    })
  }
  h
}

# Entry recorder: the run's control list, which the fold cannot see, becomes
# an entry refusal (D3 Section 2). Walk-forward runs lean.
lean_run_fold <- function(config, run_id = NULL, control = list(), metric_context = NULL, history_substrate = NULL) {
  lean_entry$control_checkpoint <- "checkpoint_every" %in% names(control)
  on.exit(lean_entry$control_checkpoint <- FALSE)
  lean_pin_run_fold(config, run_id, control, metric_context, history_substrate)
}
# The harness entry (19.2 point 1): runs `fn` (a complete public workload)
# with the lean loop installed. If the attempt was marked, however it ended
# (returned, failed, or failed inside a caller's own handler), it is
# discarded: the entry RNG state is restored and the complete workload
# reruns on the pin. An unmarked error is re-signalled unchanged. Returns
# fn()'s value with the entry record as attribute "lean".
lean_loop_run <- function(fn) {
  # The pin's caller-state pair: the seed or its absence, and the kinds.
  rng <- ledgr_rng_caller_state()
  lean_entry_reset()
  restore <- lean_loop_install()
  out <- tryCatch(fn(), error = function(e) e, finally = restore())
  record <- as.list(lean_entry)
  if (length(lean_entry$backstop) > 0L) {
    ledgr_rng_restore(rng)
    out <- fn()
  } else if (inherits(out, "error")) {
    rlang::cnd_signal(out)
  }
  structure(list(value = out), lean = record)
}

# Binds the lean envelope, the context read method, the sweep-worker loader
# and dispatch recorder (loop_workers.R) and the entry recorder over the pin
# and installs the harness hooks; returns the function that restores the pin
# and the inert hooks and merges the workers' records. With hooks = FALSE the
# entry recorder is not bound and the hooks stay inert, as the fold would run
# in production (checklist row 15); workers still load the lean fold.
lean_loop_install <- function(hooks = TRUE) {
  ns <- asNamespace("ledgr")
  lean <- list(ledgr_fold_envelope = lean_fold_envelope,
               "$.ledgr_pulse_context" = lean_ctx_dollar,
               ledgr_parallel_worker_setup = lean_worker_setup,
               ledgr_sweep_eval_candidate_tasks_parallel = lean_worker_dispatch,
               ledgr_run_fold = lean_run_fold)
  if (!hooks) lean <- lean[1:4]
  pinned <- lapply(stats::setNames(names(lean), names(lean)), get, envir = ns)
  if (!identical(pinned[[2L]], lean_pin_ctx_dollar)) {
    stop("lean_loop_install: the pinned read method is not bound (already installed?)", call. = FALSE)
  }
  bind <- function(values) {
    for (name in names(values)) {
      unlockBinding(name, ns)
      assign(name, values[[name]], envir = ns)
      lockBinding(name, ns)
    }
    registerS3method("$", "ledgr_pulse_context", values[[2L]], envir = ns)
  }
  lean_workers_open(hooks, pinned)
  bind(lean)
  if (hooks) lean_hooks <<- lean_harness_hooks()
  function() {
    bind(pinned)
    lean_hooks <<- lean_hooks_inert()
    lean_workers_merge()
  }
}
