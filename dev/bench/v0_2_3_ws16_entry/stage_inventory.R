# Stage boundary inventory at the pin: what each fold stage receives, which
# fold-state slots it changes, what it returns, which output-handler methods
# it calls, and its stops and errors. Input to the WS16 stage recorder.
#
#   Rscript stage_inventory.R --pkg=<ledgr source at the pin> --out=<dir>
#
# Dynamic rows come from running every A0 workload (committed runs and
# in-process sweeps; worker processes are not observed) plus one portable
# momentum run. Read lists are static: fields named in each stage body and in
# its direct callees that take the same carrier.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "common.R"))
  source(file.path(here, "workloads.R"))
  assign("ws16_dir", here, envir = globalenv())
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
ws16_load_source(pkg)
ns <- asNamespace("ledgr")

stages <- c(
  P1 = "ledgr_fold_stage_observe_settle", P2 = "ledgr_fold_stage_decide",
  P3 = "ledgr_fold_stage_plan", P4 = "ledgr_fold_stage_apply",
  P5 = "ledgr_fold_stage_commit", P2_skip = "ledgr_fold_scheduled_skip_decision",
  P3_skip = "ledgr_fold_scheduled_skip_plan", E_stop = "ledgr_fold_apply_stop",
  E_flush = "ledgr_fold_flush_pulse_block"
)

# Static reads and assignments, taken before any wrapping: the stage body
# and its direct callees that take one of the same carriers.
carriers <- c("fold_state", "services", "observation", "decision", "plan", "apply", "execution", "observed")
pattern <- paste0("\\b(", paste(carriers, collapse = "|"), ")\\$([A-Za-z_.][A-Za-z0-9_.]*)(\\s*(<-|\\[\\[|\\[))?")
fields_of <- function(fn) {
  txt <- paste(deparse(get(fn, envir = ns), width.cutoff = 500L), collapse = "\n")
  m <- regmatches(txt, gregexpr(pattern, txt, perl = TRUE))[[1L]]
  if (!length(m)) return(NULL)
  obj <- sub("\\$.*", "", m)
  field <- sub("^[^$]*\\$([A-Za-z0-9_.]+).*", "\\1", m)
  data.frame(object = obj, field = field, assign = grepl("<-$", m), stringsAsFactors = FALSE)
}
callees_of <- function(fn) {
  txt <- paste(deparse(get(fn, envir = ns), width.cutoff = 500L), collapse = "\n")
  called <- unique(regmatches(txt, gregexpr("\\bledgr_[A-Za-z0-9_.]+(?=\\()", txt, perl = TRUE))[[1L]])
  called <- called[vapply(called, function(f) exists(f, envir = ns, inherits = FALSE) &&
                            is.function(get(f, envir = ns)), logical(1))]
  called[vapply(called, function(f) any(names(formals(get(f, envir = ns))) %in% carriers), logical(1))]
}
static <- list()
for (lab in names(stages)) {
  fn <- stages[[lab]]
  for (via in c(fn, setdiff(callees_of(fn), stages))) {
    f <- fields_of(via)
    if (is.null(f)) next
    f <- unique(f)
    static[[length(static) + 1L]] <- data.frame(stage = lab, via = via, f, stringsAsFactors = FALSE)
  }
}
static <- unique(do.call(rbind, static))
static <- static[order(static$stage, static$object, static$field, static$via), ]
ws16_write(static, file.path(out, "stage_fields_static.csv"))


rec <- new.env()
rec$workload <- NA_character_
rec$stage <- "outside"
tabs <- c("calls", "args", "slots", "returns", "stops", "errors", "handler", "sizes")
for (t in tabs) assign(t, new.env(), envir = rec)
bump <- function(tab, ...) {
  key <- paste(rec$workload, ..., sep = "\t")
  e <- rec[[tab]]
  e[[key]] <- (e[[key]] %||% 0) + 1
}
snap <- function(fs) {
  x <- as.list.environment(fs, all.names = TRUE)
  lapply(x, function(v) if (is.environment(v)) as.list.environment(v, all.names = TRUE) else v)
}

for (label in names(stages)) {
  local({
    lab <- label
    ws16_wrap(stages[[lab]], function(orig) {
      force(orig)
      function(...) {
        a <- list(...)
        fs <- a[["fold_state"]] %||% a[[1L]]
        before <- if (is.environment(fs)) snap(fs) else NULL
        prev <- rec$stage
        rec$stage <- lab
        on.exit(rec$stage <- prev)
        first <- paste(rec$workload, lab)
        if (is.null(rec$seen[[first]])) {
          rec$seen[[first]] <- TRUE
          for (nm in names(a)) bump("sizes", lab, nm, format(ws16_bytes(a[[nm]]), scientific = FALSE))
        }
        for (nm in names(a)) bump("args", lab, nm, ws16_shape(a[[nm]]))
        res <- withCallingHandlers(orig(...), error = function(e) {
          bump("errors", lab, class(e)[[1L]])
        })
        bump("calls", lab)
        if (!is.null(before)) {
          after <- snap(fs)
          for (s in names(after)) {
            if (!identical(before[[s]], after[[s]])) bump("slots", lab, s, ws16_shape(get(s, envir = fs)))
          }
        }
        if (ledgr_is_fold_stop_result(res)) {
          bump("stops", lab, res$status, res$reason_code)
        } else if (is.list(res)) {
          for (nm in names(res)) bump("returns", lab, nm, ws16_shape(res[[nm]]))
        } else {
          bump("returns", lab, "<value>", ws16_shape(res))
        }
        res
      }
    })
  })
}
rec$seen <- new.env()

# Output-handler calls, attributed to the active stage.
ws16_wrap("ledgr_fold_envelope", function(orig) {
  force(orig)
  function(execution, output_handler) {
    for (nm in names(output_handler)) {
      # A reused handler environment is wrapped once.
      if (!is.function(output_handler[[nm]]) || isTRUE(attr(output_handler[[nm]], "ws16"))) next
      local({
        m <- nm
        f <- output_handler[[m]]
        output_handler[[m]] <<- structure(function(...) {
          bump("handler", rec$stage, m)
          f(...)
        }, ws16 = TRUE)
      })
    }
    prev <- rec$stage
    rec$stage <- "E"
    on.exit(rec$stage <- prev)
    orig(execution, output_handler)
  }
})

# A0 workloads.
source(file.path(ws16_dir, "..", "v0_2_3_output_freeze", "lib.R"))
work <- file.path(tempdir(), "ws16_stage_inventory")
dir.create(work, showWarnings = FALSE)
status <- list()
for (id in names(a0_workloads)) {
  rec$workload <- id
  status[[id]] <- tryCatch({ a0_run_workload(id, work); "ok" },
                           error = function(e) paste("error:", conditionMessage(e)))
  cat(id, status[[id]], "\n")
}

# Portable momentum run (month-start schedule, so scheduled skips appear).
rec$workload <- "momentum_40x504"
snapshot <- ws16_momentum_snapshot(40L, 504L, file.path(work, "momentum.duckdb"), "ws16_momentum")
bt <- ledgr_run(ws16_momentum_experiment(snapshot, 63L), params = list(lookback = 63L, n = 10L),
                run_id = "ws16-momentum", seed = 1L)
close(bt)
ledgr_snapshot_close(snapshot)
status$momentum_40x504 <- "ok"

table_of <- function(tab, cols) {
  e <- rec[[tab]]
  keys <- ls(e)
  if (!length(keys)) return(NULL)
  parts <- do.call(rbind, strsplit(keys, "\t", fixed = TRUE))
  df <- as.data.frame(parts, stringsAsFactors = FALSE)
  names(df) <- c("workload", cols)
  df$n <- vapply(keys, function(k) e[[k]], numeric(1), USE.NAMES = FALSE)
  df[do.call(order, unname(as.list(df[, setdiff(names(df), "n"), drop = FALSE]))), , drop = FALSE]
}
ws16_write(table_of("calls", "stage"), file.path(out, "stage_calls.csv"))
ws16_write(table_of("args", c("stage", "arg", "shape")), file.path(out, "stage_args.csv"))
ws16_write(table_of("slots", c("stage", "slot", "shape_after")), file.path(out, "stage_slot_changes.csv"))
ws16_write(table_of("returns", c("stage", "element", "shape")), file.path(out, "stage_returns.csv"))
ws16_write(table_of("stops", c("stage", "status", "reason_code")), file.path(out, "stage_stops.csv"))
ws16_write(table_of("errors", c("stage", "class")) %||% data.frame(), file.path(out, "stage_errors.csv"))
ws16_write(table_of("handler", c("stage", "method")), file.path(out, "stage_handler_calls.csv"))
ws16_write(table_of("sizes", c("stage", "arg", "bytes_first_call")), file.path(out, "stage_arg_bytes.csv"))
ws16_write(data.frame(workload = names(status), status = unlist(status), row.names = NULL),
           file.path(out, "stage_workloads.csv"))

cat("stage inventory written to", out, "\n")
