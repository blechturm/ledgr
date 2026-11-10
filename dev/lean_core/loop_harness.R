# The harness side of the compact-state lean loop (LDG-3219; interface
# Sections 19.2 and 19.6): the install function, the entry record, the
# store-write detector, the backstop stubs and lean_loop_run(), the entry
# that reruns a workload on the pin after a mid-run coverage condition.
# Only harnesses call these; nothing in R/ does.

lean_pin_run_fold <- get("ledgr_run_fold", envir = asNamespace("ledgr"))

# The last fold's pulse-loop and publication seconds, for harness timing.
lean_loop_last_times <- new.env(parent = emptyenv())

# Entry records: folds run lean, features refused before the first pulse,
# coverage conditions raised mid-run, and whether the run carried a
# control$checkpoint_every key (D3 Section 2; set by lean_run_fold).
lean_entry <- new.env(parent = emptyenv())
lean_entry_reset <- function() {
  lean_entry$lean_folds <- 0L
  lean_entry$refused <- character()
  lean_entry$backstop <- character()
  lean_entry$control_checkpoint <- FALSE
  lean_entry$store_writes <- character()   # store-boundary calls while pulses run
  lean_entry$terminal_writes <- 0L         # store-boundary calls after the loop
  lean_entry$writes_before_fault <- NA_integer_
  lean_entry$uncovered <- character()      # stubs reached in this fold (sticky)
  lean_entry$committed <- NULL             # the running fold's committed-prefix reads
  lean_entry$capacity <- NULL              # witness seam: the fill-event limit
  lean_entry$hold_calls <- 0L              # hold-expansion calls and rows while pulses run
  lean_entry$hold_rows <- 0L
  lean_entry$batch_rows <- 65536L          # terminal batch bound (rows)
  lean_entry$mutation <- NULL              # a registered mutation or witness fault
  lean_entry$measure <- FALSE              # record the terminal-materialization peak
}
lean_entry_reset()

# The store-write detector (19.6, D3 Section 5), part 1: every handler
# method but the transaction itself records its name when called while
# pulses run.
lean_watch_handler <- function(h, live) {
  for (name in setdiff(names(h)[vapply(h, is.function, logical(1L))], "run_transaction")) {
    h[[name]] <- local({
      f <- h[[name]]
      nm <- name
      function(...) {
        if (isTRUE(live$in_pulses)) lean_entry$store_writes <- c(lean_entry$store_writes, nm)
        f(...)
      }
    })
  }
  h
}

# The store-write detector, part 2: the package writer and the DBI write
# generics, wrapped for the duration of a lean fold. A call while pulses
# run is recorded as a misplaced write; a call after the loop is counted
# as a terminal write. Returns the function that restores them.
lean_store_boundaries <- list(ledgr = "ledgr_store_append",
  DBI = c("dbExecute", "dbAppendTable", "dbWriteTable", "dbSendStatement"))
lean_watch_store <- function(live) {
  saved <- list()
  for (pkg in names(lean_store_boundaries)) {
    home <- asNamespace(pkg)
    for (name in lean_store_boundaries[[pkg]]) {
      original <- get(name, envir = home)
      saved[[length(saved) + 1L]] <- list(home = home, name = name, value = original)
      wrapper <- local({
        f <- original
        label <- paste0(pkg, "::", name)
        function(...) {
          if (isTRUE(live$in_pulses)) lean_entry$store_writes <- c(lean_entry$store_writes, label)
          else lean_entry$terminal_writes <- lean_entry$terminal_writes + 1L
          f(...)
        }
      })
      unlockBinding(name, home)
      assign(name, wrapper, envir = home)
      lockBinding(name, home)
    }
  }
  function() {
    for (s in rev(saved)) {
      unlockBinding(s$name, s$home)
      assign(s$name, s$value, envir = s$home)
      lockBinding(s$name, s$home)
    }
  }
}

lean_run_fold <- function(config, run_id = NULL, control = list(), metric_context = NULL, history_substrate = NULL) {
  lean_entry$control_checkpoint <- "checkpoint_every" %in% names(control)
  on.exit(lean_entry$control_checkpoint <- FALSE)
  lean_pin_run_fold(config, run_id, control, metric_context, history_substrate)
}

# Backstop stubs (19.2 point 1): while a lean fold runs, a sizing helper or
# history read the static scan missed signals the coverage condition.
lean_stubs <- lapply(stats::setNames(lean_loop_scan_names, lean_loop_scan_names), function(name) {
  force(name)
  function(...) {
    # Sticky: a strategy that catches the condition cannot keep the attempt.
    lean_entry$uncovered <- c(lean_entry$uncovered, sprintf("`%s()` in the strategy", name))
    lean_not_covered(sprintf("`%s()` in the strategy", name))
  }
})
lean_stub_homes <- function() {
  homes <- list(asNamespace("ledgr"))
  if ("package:ledgr" %in% search()) homes <- c(homes, list(as.environment("package:ledgr")))
  homes
}
lean_stub_saved <- new.env(parent = emptyenv())
# Binds `values` (a named list) in the namespace and the attached package,
# saving the originals; with no argument, restores them.
lean_stubs_bind <- function(values = NULL) {
  for (home in lean_stub_homes()) {
    key <- environmentName(home)
    if (is.null(values)) {
      if (is.null(lean_stub_saved[[key]])) next
      values_here <- lean_stub_saved[[key]]
      lean_stub_saved[[key]] <- NULL
    } else {
      names_here <- intersect(names(values), ls(home, all.names = TRUE))
      lean_stub_saved[[key]] <- mget(names_here, envir = home)
      values_here <- values[names_here]
    }
    for (name in names(values_here)) {
      unlockBinding(name, home)
      assign(name, values_here[[name]], envir = home)
      lockBinding(name, home)
    }
  }
}

# The harness entry (19.2 point 1): runs `fn` (a complete public workload)
# with the lean loop installed. If any lean fold raised a coverage
# condition mid-run, the attempt is discarded: the RNG state at entry is
# restored and the complete workload reruns on the pin. Returns fn()'s value
# with the entry record as attribute "lean".
lean_loop_run <- function(fn) {
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  seed <- if (had_seed) get(".Random.seed", envir = globalenv())
  lean_entry_reset()
  restore <- lean_loop_install()
  out <- tryCatch(fn(), ledgr_lean_coverage = function(c) c, finally = restore())
  record <- as.list(lean_entry)
  if (length(lean_entry$backstop) > 0L) {
    if (had_seed) assign(".Random.seed", seed, envir = globalenv())
    else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv())
    out <- fn()
  } else if (inherits(out, "condition")) {
    rlang::cnd_signal(out)
  }
  structure(list(value = out), lean = record)
}

# Binds the lean envelope, the two context read methods and the run-fold
# entry recorder over the pin; returns the function that restores the pin.
lean_loop_install <- function() {
  ns <- asNamespace("ledgr")
  lean <- list(ledgr_fold_envelope = lean_fold_envelope,
               "$.ledgr_pulse_context" = lean_ctx_dollar, "$.ledgr_strategy_state_view" = lean_state_dollar,
               ledgr_run_fold = lean_run_fold)
  pinned <- lapply(stats::setNames(names(lean), names(lean)), get, envir = ns)
  if (!identical(pinned[[2L]], lean_pin_ctx_dollar) || !identical(pinned[[3L]], lean_pin_state_dollar)) {
    stop("lean_loop_install: the pinned read methods are not bound (already installed?)", call. = FALSE)
  }
  bind <- function(values) {
    for (name in names(values)) {
      unlockBinding(name, ns)
      assign(name, values[[name]], envir = ns)
      lockBinding(name, ns)
    }
    registerS3method("$", "ledgr_pulse_context", values[[2L]], envir = ns)
    registerS3method("$", "ledgr_strategy_state_view", values[[3L]], envir = ns)
  }
  bind(lean)
  function() bind(pinned)
}
