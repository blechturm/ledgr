# LDG-3130 demonstration (cut decision (5)): each relocated structural source
# assertion fails on a violation of its own original predicate, injected into
# the new owner it inspects. Mutations replace namespace bindings in this
# process only; no file is changed.
#
#   LTB-0188 forbidden storage  environment-held staging write in the handler
#                               and in the memory sink (legs)
#   LTB-0188 required writes    loss of the closure-local `<<-` staging write
#                               for rows (handler) and legs (memory sink)
#   LTB-0138                    a MAX(diagnostic_seq) query in the DuckDB sink
#   LTB-0055                    a transaction call in the memory sink
#
# Usage: Rscript dev/ws1/structural_relocation_demo.R [repo root]
structural_relocation_demo <- function(root) {
  pkgload::load_all(root, quiet = TRUE)
  ns <- asNamespace("ledgr")
  tests <- file.path(root, "tests", "testthat")
  run_block <- function(file, desc) {
    res <- testthat::test_file(file.path(tests, file), desc = desc, reporter = "silent",
      stop_on_failure = FALSE, load_package = "none")
    df <- as.data.frame(res)
    messages <- unlist(lapply(res[[1L]]$results, function(r) {
      if (inherits(r, "expectation_failure") || inherits(r, "expectation_error")) conditionMessage(r)
    }))
    list(bad = df$failed > 0 || df$error, first = if (length(messages)) strsplit(messages[[1L]], "\n")[[1L]][[1L]] else "")
  }
  with_binding <- function(name, fn, expr) {
    original <- get(name, envir = ns)
    unlockBinding(name, ns)
    assign(name, fn, envir = ns)
    on.exit({
      assign(name, original, envir = ns)
      lockBinding(name, ns)
    }, add = TRUE)
    force(expr)
  }
  prepend <- function(fn, stmt) {
    b <- body(fn)
    body(fn) <- as.call(c(as.name("{"), list(stmt), as.list(b)[-1L]))
    fn
  }
  # Rewrites `var[[i]] <<- value` into `var <<- `[[<-`(var, i, value)`: the
  # same write without the closure-local subassignment form.
  drop_local_write <- function(fn, var) {
    walk <- function(e) {
      if (is.call(e)) {
        if (identical(e[[1L]], as.name("<<-")) && is.call(e[[2L]]) &&
            identical(e[[2L]][[1L]], as.name("[[")) && identical(e[[2L]][[2L]], as.name(var))) {
          target <- as.name(var)
          return(call("<<-", target, as.call(list(as.name("[[<-"), target, e[[2L]][[3L]], walk(e[[3L]])))))
        }
        for (k in seq_along(e)[-1L]) if (!is.null(e[[k]])) e[[k]] <- walk(e[[k]])
      }
      e
    }
    body(fn) <- walk(body(fn))
    fn
  }

  handler <- get("ledgr_output_handler", envir = ns)
  memory_sink <- get("ledgr_output_sink_memory", envir = ns)
  duckdb_sink <- get("ledgr_output_sink_duckdb", envir = ns)
  ltb0188 <- "[LTB-0188] pulse staging writes do not copy with capacity"
  ltb0138 <- "[LTB-0138] diagnostic sequence is initialized once"
  ltb0055 <- "[LTB-0055] memory failure discards disposition artifacts only for that candidate"

  cases <- list(
    list("unchanged LTB-0188", NULL, NULL, "test-ledger-writer.R", ltb0188, FALSE),
    list("unchanged LTB-0138", NULL, NULL, "test-ledger-writer.R", ltb0138, FALSE),
    list("unchanged LTB-0055", NULL, NULL, "test-corporate-action-recovery.R", ltb0055, FALSE),
    list("rows: environment-held staging write in the handler", "ledgr_output_handler",
      prepend(handler, quote(if (FALSE) state$pulse_fill_rows <- NULL)), "test-ledger-writer.R", ltb0188, TRUE),
    list("legs: environment-held staging write in the memory sink", "ledgr_output_sink_memory",
      prepend(memory_sink, quote(if (FALSE) state$pulse_fill_legs <- NULL)), "test-ledger-writer.R", ltb0188, TRUE),
    list("rows: closure-local staging write lost in the handler", "ledgr_output_handler",
      drop_local_write(handler, "pulse_fill_rows"), "test-ledger-writer.R", ltb0188, TRUE),
    list("legs: closure-local staging write lost in the memory sink", "ledgr_output_sink_memory",
      drop_local_write(memory_sink, "pulse_fill_legs"), "test-ledger-writer.R", ltb0188, TRUE),
    list("MAX(diagnostic_seq) query in the DuckDB sink", "ledgr_output_sink_duckdb",
      prepend(duckdb_sink, quote(if (FALSE) DBI::dbGetQuery(con, "SELECT MAX(diagnostic_seq) FROM run_diagnostics"))),
      "test-ledger-writer.R", ltb0138, TRUE),
    list("transaction call in the memory sink", "ledgr_output_sink_memory",
      prepend(memory_sink, quote(if (FALSE) begin_transaction())), "test-corporate-action-recovery.R", ltb0055, TRUE)
  )
  ok <- logical(length(cases))
  for (k in seq_along(cases)) {
    case <- cases[[k]]
    res <- if (is.null(case[[2L]])) run_block(case[[4L]], case[[5L]]) else
      with_binding(case[[2L]], case[[3L]], run_block(case[[4L]], case[[5L]]))
    ok[[k]] <- identical(res$bad, case[[6L]])
    cat(sprintf("%-60s fails=%-5s %s\n", case[[1L]], res$bad, substr(res$first, 1L, 90L)))
  }
  stopifnot(all(ok))
  cat("DEMO PASS: every relocated structural assertion passes unchanged and fails on its own predicate\n")
  invisible(TRUE)
}

local({
  args <- commandArgs(trailingOnly = TRUE)
  structural_relocation_demo(normalizePath(if (length(args)) args[[1L]] else ".", winslash = "/", mustWork = TRUE))
})
