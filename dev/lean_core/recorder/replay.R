# Replay check (interface table Section 14): each captured call re-runs the
# pinned function on its frozen input, with fold state and services reduced
# to the table's fields for that boundary (lc_table_fields()), and the full
# captured output is compared with lc_compare(). Run it in an R process that
# holds only the pinned build and the captures (run.R --replay), so neither
# globals nor workload code are in reach; pinned namespace code is the oracle.

lc_unnamed <- function(object, field) {
  rlang::abort(paste0("replay read the unnamed ", object, " field `", field, "`"), class = "lc_unnamed_field")
}
lc_guard <- function(x, i) {
  bad <- setdiff(if (is.character(i)) i else names(unclass(x))[i], attr(x, "lc_named"))
  if (length(bad)) lc_unnamed("services", bad[[1L]])
}
`$.lc_services` <- function(x, name) {
  lc_guard(x, name)
  .subset2(x, name)
}
`[[.lc_services` <- function(x, i, ...) {
  lc_guard(x, i)
  .subset2(x, i)
}
`[.lc_services` <- function(x, i, ...) {
  lc_guard(x, i)
  unclass(x)[i]
}
.S3method("$", "lc_services", `$.lc_services`)
.S3method("[[", "lc_services", `[[.lc_services`)
.S3method("[", "lc_services", `[.lc_services`)

# A locked fold state holding the named slots; every other slot of the
# table's slot set is an active binding that refuses access.
lc_reduced_state <- function(values, named) {
  e <- new.env(parent = emptyenv())
  for (slot in lc_rec$slots %||% lc_fold_slots()) {
    if (slot %in% named) {
      if (!(slot %in% names(values))) stop("lc: the capture lacks named slot ", slot, call. = FALSE)
      assign(slot, values[[slot]], envir = e)
    } else local({
      s <- slot
      makeActiveBinding(s, function(v) lc_unnamed("fold state", s), e)
    })
  }
  lockEnvironment(e)
  e
}

# Stand-ins for the handler and writer: each call is checked against the
# capture's next call, a copy of its arguments kept, and the captured value
# returned or condition raised.
lc_play <- function(p, object, method, args) {
  p$pos <- p$pos + 1L
  through <- identical(method, "run_transaction")
  p$log[[p$pos]] <- list(object = object, method = method,
                         args = if (!through) unserialize(lc_serialize(lc_named(args))))
  want <- if (p$pos <= length(p$calls)) p$calls[[p$pos]]
  if (is.null(want) || !identical(c(want$object, want$method), c(object, method))) {
    rlang::abort(sprintf("replay call %d is %s$%s; the capture has %s", p$pos, object, method,
                         if (is.null(want)) "no more calls" else paste0(want$object, "$", want$method)),
                 class = "lc_replay_divergence")
  }
  if (through) return(args[[1L]]())
  if (!is.null(want$cond)) stop(structure(class = want$cond$class, list(message = want$cond$message, call = NULL)))
  lc_thaw(want$value, p$store)$value
}

lc_stand_in <- function(shape, object, p, store) {
  values <- lc_thaw(shape$values, store)
  out <- list()
  for (j in seq_along(shape$names)) {
    m <- shape$names[[j]]
    out[m] <- list(if (shape$fn[[j]]) local({
      method <- m
      function(...) lc_play(p, object, method, list(...))
    }) else values[[m]])
  }
  class(out) <- shape$class
  out
}

lc_part <- function(values, prefix) {
  out <- values[startsWith(names(values), prefix)]
  stats::setNames(out, substring(names(out), nchar(prefix) + 1L))
}
lc_prefix <- function(values, prefix) stats::setNames(values, paste0(rep(prefix, length(values)), names(values)))

# Re-runs one record. Returns the captured output and the replay's, each
# over the slots and services captured at input (never over what the replay
# produced), plus the captured input and output of every named slot the
# table does not let this boundary write.
lc_replay_record <- function(rec, cap, fields, omit = NULL) {
  store <- cap$store
  input <- lc_thaw(rec$input, store)
  args <- lc_part(input, "arg:")
  slots <- lc_part(input, "state:")
  mut <- lc_part(input, "svc:")
  fold <- if (rec$fold > 0L) cap$folds[[rec$fold]]
  p <- list2env(list(calls = rec$calls, pos = 0L, log = list(), store = store), parent = emptyenv())
  here <- fields[fields$boundary == rec$boundary, ]
  named_state <- setdiff(here$field[here$object == "state"], omit)
  named_svc <- here$field[here$object == "services"]
  state <- if (length(slots)) lc_reduced_state(slots, named_state)
  if (!is.null(state)) args <- c(list(fold_state = state), args)
  if (!is.null(fold)) {
    handler <- lc_stand_in(fold$handler_shape, "output_handler", p, store)
    writer <- lc_stand_in(fold$writer_shape, "diagnostic_writer", p, store)
  }
  if (rec$boundary %in% setdiff(lc_stages, "P3_skip")) {
    fixed <- intersect(colnames(fold$fixed$roots), named_svc)
    services <- c(lc_thaw(fold$fixed, store, fixed), fold$live, mut, list(output_handler = handler, diagnostic_writer = writer))
    services <- services[intersect(names(services), named_svc)]
    args <- c(list(services = structure(services, lc_named = named_svc, class = "lc_services")), args)
  }
  if (rec$boundary == "E_flush") args$diagnostic_writer <- writer
  if (rec$boundary == "E") {
    args$output_handler <- handler
    lc_rec$replay_writer <- writer
    on.exit(lc_rec$replay_writer <- NULL)
  }
  if (rec$boundary == "P2") {
    if (is.null(input$seed)) suppressWarnings(rm(".Random.seed", envir = globalenv())) else assign(".Random.seed", input$seed, envir = globalenv())
  }
  warnings <- list()
  result <- withCallingHandlers(
    tryCatch(list(value = do.call(lc_rec$orig[[rec$boundary]], args)), error = function(e) list(cond = lc_cond(e))),
    warning = function(w) {
      warnings[[length(warnings) + 1L]] <<- lc_cond(w)
      invokeRestart("muffleWarning")
    })
  # Bar hydration reopened the sealed snapshot from its frozen handle.
  if (inherits(args$snapshot, "ledgr_snapshot")) ledgr_snapshot_close(args$snapshot)
  after <- slots
  for (s in intersect(named_state, names(slots))) after[[s]] <- get(s, envir = state)
  actual <- c(list(cond = result$cond, warnings = warnings), lc_prefix(after, "state:"), lc_prefix(mut, "svc:"))
  if (rec$boundary == "P2") actual$seed <- get0(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (is.null(result$cond)) actual["value"] <- list(result$value)
  expected <- c(list(cond = rec$cond, warnings = rec$warnings), lc_thaw(rec$output, store), list(calls = lapply(rec$calls, function(k) {
    list(object = k$object, method = k$method, args = if (!is.null(k$args)) lc_thaw(k$args, store))
  })))
  read_only <- paste0("state:", setdiff(named_state, here$field[here$object == "state" & here$write %in% TRUE]))
  # A fresh thaw: the replay may have written the first one in place.
  read_only <- intersect(read_only, colnames(rec$input$roots))
  list(expected = expected, actual = c(actual, list(calls = p$log)),
       read_only_in = lc_thaw(rec$input, store, read_only), read_only_out = expected[intersect(read_only, names(expected))])
}

# Replays every record of a capture; one row per record.
lc_replay <- function(cap, fields = lc_table_fields(), omit = NULL, only = NULL) {
  lc_install()
  lc_rec$on <- FALSE
  lc_rec$slots <- lc_fold_slots()
  rows <- lapply(if (is.null(only)) seq_along(cap$records) else only, function(i) {
    rec <- cap$records[[i]]
    r <- lc_replay_record(rec, cap, fields, omit = if (identical(omit$boundary, rec$boundary)) omit$slot)
    owners <- lc_clock_paths(rec$boundary)
    d <- lc_compare(r$expected, r$actual, cap$clock, owners)
    if (!is.null(d) && is.null(rec$cond) && !is.null(r$actual$cond)) d <- paste0("replay raised ", r$actual$cond$class[[1L]], ": ", r$actual$cond$message)
    w <- lc_compare(r$read_only_in, r$read_only_out, cap$clock, owners)
    if (is.null(d) && !is.null(w)) d <- paste("captured a write the table does not declare:", w)
    data.frame(record = i, boundary = rec$boundary, fold = rec$fold, pass = is.null(d), difference = d %||% "")
  })
  do.call(rbind, rows)
}

lc_read_capture <- function(path) {
  x <- readRDS(path)
  store <- lc_store_new()
  store$blob <- list2env(x$blobs, parent = emptyenv())
  list(records = x$records, folds = x$folds, clock = x$clock, store = store)
}
