# Stage recorder (LDG-3212): wraps the pinned functions of interface table
# Section 14 from outside and records frozen copies (pulse plumbing R13).
# Values are serialized; each environment they reach becomes a node whose
# bindings go one by one into a content-addressed store; large atomic
# leaves are stored once. Only prepared planes are remembered by address
# (lc_register); every other value is serialized at every boundary.
# Handler and writer calls are logged in order.

lc_leaf_min <- 2048L
lc_rec <- new.env(parent = emptyenv())
lc_rec$on <- FALSE

lc_boundaries <- c(
  E = "ledgr_fold_envelope", P1 = "ledgr_fold_stage_observe_settle",
  P2 = "ledgr_fold_stage_decide", P3 = "ledgr_fold_stage_plan", P4 = "ledgr_fold_stage_apply",
  P5 = "ledgr_fold_stage_commit", P2_skip = "ledgr_fold_scheduled_skip_decision",
  P3_skip = "ledgr_fold_scheduled_skip_plan", E_stop = "ledgr_fold_apply_stop",
  E_flush = "ledgr_fold_flush_pulse_block", E_skip_row = "ledgr_fold_staging_add",
  lot = "ledgr_lot_apply",
  hydrate = "ledgr_precompute_fetch_bars_frame", substrate = "ledgr_history_substrate",
  features = "ledgr_history_compute_feature_series", reader = "ledgr_history_substrate_fold_reader",
  packet = "ledgr_history_substrate_bar_packet", history_read = "ledgr_history_read_plan",
  history_frame = "ledgr_history_plan_frame", history_matrix = "ledgr_history_matrix_from_plan"
)
# Recorded inside and outside folds.
lc_preparation <- c("hydrate", "substrate", "features", "reader", "packet", "history_read", "history_frame", "history_matrix")
lc_stages <- c("P1", "P2", "P3", "P4", "P5", "P2_skip", "P3_skip")
# Captured slot by slot and field by field, or through their calls.
lc_live_args <- c("fold_state", "services", "output_handler", "diagnostic_writer")

lc_store_new <- function() {
  list2env(list(blob = new.env(parent = emptyenv()), seen = new.env(parent = emptyenv()), hits = 0L),
           parent = emptyenv())
}
# Format 2 writes an ALTREP vector's materialized data, so an in-place write
# to a compact sequence is captured (format 3 keeps the compact form). A
# digest starts after the 14-byte header, which records the R version.
lc_serialize <- function(x, hook = NULL) serialize(x, NULL, version = 2L, refhook = hook)
lc_digest <- function(raw) {
  skip <- if (identical(raw[1:2], charToRaw("X\n"))) 14L else 0L
  digest::digest(if (skip) raw[-seq_len(skip)] else raw, algo = "xxh3_128", serialize = FALSE)
}
lc_put <- function(store, raw) {
  key <- lc_digest(raw)
  if (!exists(key, envir = store$blob, inherits = FALSE)) assign(key, raw, envir = store$blob)
  key
}

# Rebuilds list x with f(element) where f returns non-NULL; NULL if unchanged.
lc_walk <- function(x, f) {
  out <- NULL
  for (i in seq_along(x)) {
    y <- f(.subset2(x, i))
    if (!is.null(y)) {
      if (is.null(out)) out <- unclass(x)
      out[i] <- list(y)
    }
  }
  if (!is.null(out)) class(out) <- oldClass(x)
  out
}

# The prepared planes the substrate, feature and projection producers return
# (Section 12.1: immutable; the pinned code never writes them in place). The
# recorder holds a reference, so an R-level change gives a new address; every
# `verify_every`-th reuse is re-serialized and a mismatch stops the capture.
lc_register <- function(x, store) {
  if (is.atomic(x) && length(x) >= lc_leaf_min) {
    a <- rlang::obj_address(x)
    if (is.null(store$seen[[a]])) assign(a, list(ref = x, key = NULL), envir = store$seen)
  } else if (is.list(x)) for (e in x) lc_register(e, store)
}

lc_leaf <- function(x, store) {
  a <- rlang::obj_address(x)
  hit <- store$seen[[a]]
  if (!is.null(hit$key)) {
    store$hits <- store$hits + 1L
    if (store$hits %% lc_rec$verify_every == 0L && !identical(lc_digest(lc_serialize(x)), hit$key)) {
      stop("lc_cache_stale: a registered plane (", typeof(x), " ", paste(dim(x) %||% length(x), collapse = "x"),
           ") changed in place", call. = FALSE)
    }
    return(structure(hit$key, class = "lc_leaf"))
  }
  key <- lc_put(store, lc_serialize(x))
  if (!is.null(hit)) assign(a, list(ref = x, key = key), envir = store$seen)
  structure(key, class = "lc_leaf")
}

lc_split <- function(x, store) {
  if (is.atomic(x)) {
    if (length(x) >= lc_leaf_min) lc_leaf(x, store)
  } else if (is.list(x)) lc_walk(x, function(e) lc_split(e, store))
}

# Thawing copies every leaf: no thaw shares a buffer with another.
lc_join <- function(x, store) {
  if (inherits(x, "lc_leaf")) return(unserialize(store$blob[[unclass(x)]]))
  if (is.list(x)) lc_walk(x, function(e) lc_join(e, store))
}

# The canonical form, for digests only: snapshot metadata$created_at (wall
# clock) is dropped, and a DBI object becomes a descriptor of the database it
# opens instead of its run-specific pointers and temporary paths.
lc_strip <- function(x) {
  if (isS4(x) && methods::is(x, "DBIObject")) {
    d <- if (methods::.hasSlot(x, "driver")) x@driver else x
    keep <- intersect(c("dbdir", "read_only", "bigint"), methods::slotNames(d))
    return(c(list(class = class(x)[[1L]]), lapply(stats::setNames(keep, keep), function(s) methods::slot(d, s))))
  }
  if (!is.list(x)) return(NULL)
  y <- if (inherits(x, "ledgr_snapshot") && !is.null(x$metadata$created_at)) {
    z <- unclass(x)
    z$metadata$created_at <- NULL
    structure(z, class = oldClass(x))
  }
  lc_walk(y %||% x, lc_strip) %||% y
}

# Timing locals at a clock owner path: the list's top level and P1's observation.
lc_unclock <- function(x) {
  if (!is.list(x) || is.null(names(x))) return(x)
  x <- unclass(x)
  if (is.list(x$observation)) x$observation <- unclass(x$observation)[!names(x$observation) %in% lc_rec$clock]
  x[!names(x) %in% lc_rec$clock]
}

lc_at <- function(x, path) {
  for (p in strsplit(sub("^\\$", "", path), "$", fixed = TRUE)[[1L]]) {
    x <- if (is.environment(x)) get0(p, envir = x, inherits = FALSE) else if (is.list(x)) .subset2(x, p)
  }
  x
}

# Freezes a named list of values with one environment map, so environments
# shared between the values stay shared after thawing. `clock` names the
# owner paths of the table's clock fields (lc_clock_paths()); they are left
# out of the canonical digest only there.
lc_freeze <- function(values, store, clock = character()) {
  values <- lc_named(values)
  ids <- new.env(parent = emptyenv())
  queue <- list()
  pointer <- FALSE
  hook <- function(x) {
    if (!is.environment(x)) {
      pointer <<- TRUE
      return(NULL)
    }
    a <- rlang::obj_address(x)
    if (is.null(ids[[a]])) {
      queue[[length(queue) + 1L]] <<- x
      assign(a, sprintf("lc_env_%d", length(queue)), envir = ids)
    }
    ids[[a]]
  }
  # External pointers serialize as null pointers; their contents stay out of the digest.
  canon_hook <- function(x) if (is.environment(x)) hook(x) else "lc_pointer"
  blob <- function(x, unclock = FALSE) {
    skeleton <- lc_split(x, store) %||% x
    pointer <<- FALSE
    key <- lc_put(store, lc_serialize(skeleton, hook))
    canonical <- lc_strip(skeleton)
    if (unclock) canonical <- lc_unclock(canonical %||% skeleton)
    if (!is.null(canonical) || pointer) key <- c(key, lc_digest(lc_serialize(canonical %||% skeleton, canon_hook)))
    c(key = key[[1L]], canon = key[[length(key)]])
  }
  blobs <- function(xs, unclock = rep(FALSE, length(xs))) {
    matrix(unlist(Map(blob, xs, unclock), use.names = FALSE) %||% character(), nrow = 2L,
           dimnames = list(c("key", "canon"), names(xs)))
  }
  roots <- blobs(values, paste0("$", names(values)) %in% clock & vapply(values, is.list, TRUE))
  clock_envs <- vapply(Filter(is.environment, lapply(clock, lc_at, x = values)), rlang::obj_address, "")
  nodes <- list()
  while (length(nodes) < length(queue)) {
    e <- queue[[length(nodes) + 1L]]
    nm <- sort(ls(e, all.names = TRUE), method = "radix")
    active <- vapply(nm, bindingIsActive, logical(1), env = e)
    # An unforced promise is not forced (that could run code early); replay
    # refuses to read it.
    lazy <- !active & rlang::env_binding_are_lazy(e, nm)
    vals <- lapply(nm, function(n) if (active[[n]]) activeBindingFunction(n, e) else if (!lazy[[n]]) get(n, envir = e))
    nodes[[length(nodes) + 1L]] <- list(
      names = nm, active = unname(active), lazy = unname(lazy), bindings = blobs(stats::setNames(vals, nm)),
      parent = blob(parent.env(e)), attrs = blob(attributes(e)), locked = environmentIsLocked(e),
      locked_bindings = unname(vapply(nm, bindingIsLocked, logical(1), env = e)),
      clock = rlang::obj_address(e) %in% clock_envs)
  }
  node_canon <- vapply(nodes, function(n) {
    k <- !(n$clock & n$names %in% lc_rec$clock)
    paste(c(n$names[k], n$bindings["canon", k], n$lazy[k], n$parent[["canon"]], n$attrs[["canon"]], n$locked,
            n$locked_bindings[k]), collapse = ",")
  }, character(1))
  # A scalar clock argument (sample_start, pulse_start) is left out whole.
  k <- !(paste0("$", names(values)) %in% clock) | vapply(values, function(v) is.list(v) || is.environment(v), TRUE)
  canon <- lc_digest(charToRaw(paste(c(names(values)[k], roots["canon", k], node_canon), collapse = "|")))
  list(roots = roots, nodes = nodes, canon = canon)
}

# Names every value; unnamed (positional) values get "..i".
lc_named <- function(values) {
  if (length(values) == 0L) return(list())
  nm <- names(values) %||% rep("", length(values))
  nm[!nzchar(nm)] <- paste0("..", which(!nzchar(nm)))
  stats::setNames(as.list(values), nm)
}

# A wrapper's `...` named by the pinned function's formals, as match.call()
# would for these exact-name and positional calls.
lc_match_args <- function(orig, a) {
  nm <- names(a) %||% rep("", length(a))
  free <- setdiff(names(formals(orig)), nm)
  nm[!nzchar(nm)] <- free[seq_len(sum(!nzchar(nm)))]
  stats::setNames(a, nm)
}

# Stands in for an unforced promise; its environment holds only the name, so
# two stand-ins compare equal.
lc_lazy_guard <- function(name) {
  f <- function(value) stop("lc_lazy_binding: replay read the unforced promise ", name, call. = FALSE)
  environment(f) <- list2env(list(name = name), parent = baseenv())
  f
}

# Fresh objects from a frozen capture; `only` limits the roots rebuilt.
lc_thaw <- function(frozen, store, only = colnames(frozen$roots)) {
  envs <- lapply(frozen$nodes, function(n) new.env(parent = emptyenv()))
  hook <- function(id) envs[[as.integer(sub("lc_env_", "", id, fixed = TRUE))]]
  get_blob <- function(b) {
    x <- unserialize(store$blob[[b[["key"]]]], refhook = hook)
    lc_join(x, store) %||% x
  }
  for (i in seq_along(envs)) {
    n <- frozen$nodes[[i]]
    e <- envs[[i]]
    parent.env(e) <- get_blob(n$parent)
    attributes(e) <- get_blob(n$attrs)
    for (j in seq_along(n$names)) {
      v <- if (n$lazy[[j]]) lc_lazy_guard(n$names[[j]]) else get_blob(n$bindings[, j])
      if (n$active[[j]] || n$lazy[[j]]) makeActiveBinding(n$names[[j]], v, e) else assign(n$names[[j]], v, envir = e)
      if (n$locked_bindings[[j]]) lockBinding(n$names[[j]], e)
    }
    if (n$locked) lockEnvironment(e)
  }
  stats::setNames(lapply(only, function(nm) get_blob(frozen$roots[, nm])), only)
}

# ---------------------------------------------------------------------------
# Handler and writer: logged calls

lc_log_call <- function(object, method, f, args) {
  if (!isTRUE(lc_rec$on) || lc_rec$depth > 0L) return(f())
  # run_transaction only runs the fold's body; calls inside it are top level.
  through <- identical(method, "run_transaction")
  i <- length(lc_rec$calls) + 1L
  lc_rec$calls[[i]] <- list(object = object, method = method,
                            args = if (!through) lc_freeze(args, lc_rec$store))
  if (!through) {
    lc_rec$depth <- 1L
    on.exit(lc_rec$depth <- 0L)
  }
  value <- withCallingHandlers(f(), error = function(e) lc_rec$calls[[i]]$cond <- lc_cond(e))
  if (!through) lc_rec$calls[[i]]$value <- lc_freeze(list(value = value), lc_rec$store)
  value
}

lc_proxy <- function(obj, object) {
  for (m in names(obj)) {
    if (is.function(obj[[m]])) local({
      f <- obj[[m]]
      method <- m
      obj[[method]] <<- function(...) lc_log_call(object, method, function() f(...), list(...))
    })
  }
  obj
}

# What replay needs to rebuild a stand-in: names, which are functions, and
# the frozen non-function fields.
lc_shape <- function(obj) {
  fn <- vapply(names(obj), function(m) is.function(obj[[m]]), logical(1))
  list(class = oldClass(obj), names = names(obj), fn = unname(fn),
       values = lc_freeze(unclass(obj)[!fn], lc_rec$store))
}

lc_cond <- function(e) list(class = class(e), message = conditionMessage(e))

# ---------------------------------------------------------------------------
# Boundary records

lc_inputs <- function(label, a) {
  args <- a[setdiff(names(a), lc_live_args)]
  values <- stats::setNames(args, paste0("arg:", names(args)))
  if (is.environment(a$fold_state)) {
    slots <- mget(lc_rec$slots, envir = a$fold_state)
    values <- c(values, stats::setNames(slots, paste0("state:", names(slots))))
  }
  if (!is.null(a$services)) {
    lc_fold_services(a$services)
    mut <- setdiff(intersect(lc_rec$mutable, names(a$services)), c(lc_rec$by_reference, "output_handler", "diagnostic_writer"))
    values <- c(values, stats::setNames(unclass(a$services)[mut], paste0("svc:", mut)))
  }
  if (identical(label, "P2")) values$seed <- get0(".Random.seed", envir = globalenv(), inherits = FALSE)
  values
}

# Fixed services fields, once per fold.
lc_fold_services <- function(services) {
  fold <- lc_rec$fold
  if (is.null(fold) || !is.null(fold$fixed)) return(invisible())
  lc_register(services$runtime_projection, lc_rec$store)
  fixed <- setdiff(names(services), c(lc_rec$mutable, lc_rec$by_reference))
  fold$fixed <- lc_freeze(unclass(services)[fixed], lc_rec$store)
  fold$live <- unclass(services)[intersect(lc_rec$by_reference, names(services))]
}

lc_record <- function(label, a, call) {
  lc_rec$stack <- c(lc_rec$stack, label)
  on.exit(lc_rec$stack <- lc_rec$stack[-length(lc_rec$stack)])
  clock <- lc_clock_paths(label)
  input <- lc_freeze(lc_inputs(label, a), lc_rec$store, clock)
  first <- length(lc_rec$calls) + 1L
  warnings <- list()
  result <- withCallingHandlers(
    tryCatch(list(value = call()), error = function(e) list(cond = lc_cond(e), error = e)),
    warning = function(w) warnings[[length(warnings) + 1L]] <<- lc_cond(w))
  if (label %in% c("substrate", "features")) lc_register(result$value, lc_rec$store)
  out <- lc_inputs(label, a)
  out <- out[!startsWith(names(out), "arg:")]
  if (is.null(result$cond)) out["value"] <- list(result$value)
  rec <- list(boundary = label, fold = lc_rec$fold$id %||% 0L, input = input,
              output = lc_freeze(out, lc_rec$store, clock), cond = result$cond, warnings = warnings,
              calls = lc_rec$calls[seq_len(length(lc_rec$calls) - first + 1L) + first - 1L])
  lc_rec$records[[length(lc_rec$records) + 1L]] <- rec
  if (!is.null(result$error)) stop(result$error)
  result$value
}

lc_install <- function() {
  if (isTRUE(lc_rec$installed)) return(invisible())
  # The pinned functions themselves, which replay calls.
  lc_rec$orig <- list()
  for (label in setdiff(names(lc_boundaries), "E")) local({
    lab <- label
    lc_rec$orig[[lab]] <- ws16_wrap(lc_boundaries[[lab]], function(orig) {
      force(orig)
      function(...) {
        stack <- lc_rec$stack
        skip <- !isTRUE(lc_rec$on) || is.null(lc_rec$fold) && !(lab %in% c("lot", lc_preparation)) ||
          !is.null(lc_rec$only) && !(lab %in% lc_rec$only) ||
          lab == "E_skip_row" && !identical(stack[length(stack)], "E")
        if (skip) return(orig(...))
        lc_record(lab, lc_match_args(orig, list(...)), function() orig(...))
      }
    })
  })
  lc_rec$orig$E <- ws16_wrap("ledgr_fold_envelope", function(orig) {
    force(orig)
    function(execution, output_handler) {
      if (!isTRUE(lc_rec$on)) return(orig(execution, output_handler))
      lc_rec$folds[[length(lc_rec$folds) + 1L]] <- lc_rec$fold <- new.env(parent = emptyenv())
      lc_rec$fold$id <- length(lc_rec$folds)
      on.exit(lc_rec$fold <- NULL)
      if (!is.null(lc_rec$only) && !("E" %in% lc_rec$only)) return(orig(execution, output_handler))
      proxy <- lc_proxy(output_handler, "output_handler")
      lc_rec$fold$handler_shape <- lc_shape(output_handler)
      lc_record("E", list(execution = execution, output_handler = proxy), function() orig(execution, proxy))
    }
  })
  # ledgr_feature_engine_version() fingerprints function bodies, among them
  # ledgr_history_compute_feature_series(); it runs on the pinned bindings so
  # the wrappers never change a value the pinned build computes.
  lc_rec$wrapped <- lapply(lc_boundaries[names(lc_rec$orig)], get, envir = asNamespace("ledgr"))
  ws16_wrap("ledgr_feature_engine_version", function(orig) {
    force(orig)
    function() {
      lc_bind(lc_rec$orig)
      on.exit(lc_bind(lc_rec$wrapped))
      orig()
    }
  })
  # E builds the writer from its handler; replay substitutes its stand-in here.
  ws16_wrap("ledgr_fold_diagnostic_writer", function(orig) {
    force(orig)
    function(run_id, output_handler, ...) {
      if (!is.null(lc_rec$replay_writer)) return(lc_rec$replay_writer)
      writer <- orig(run_id, output_handler, ...)
      if (!isTRUE(lc_rec$on) || is.null(lc_rec$fold)) return(writer)
      lc_rec$fold$writer_shape <- lc_shape(writer)
      lc_proxy(writer, "diagnostic_writer")
    }
  })
  lc_rec$installed <- TRUE
  invisible()
}

lc_bind <- function(functions) {
  ns <- asNamespace("ledgr")
  for (label in names(functions)) {
    name <- lc_boundaries[[label]]
    unlockBinding(name, ns)
    assign(name, functions[[label]], envir = ns)
    lockBinding(name, ns)
  }
}

# Starts recording one workload; `by_reference` names a mutable services
# field held live instead of frozen (an omission, never the default).
# `only` restricts capture to the named boundaries (a family's own); NULL is all.
lc_capture_begin <- function(by_reference = character(), verify_every = 25L, only = NULL) {
  lc_install()
  fields <- lc_table_fields()
  list2env(list(store = lc_store_new(), records = list(), calls = list(), folds = list(), fold = NULL,
                stack = character(), depth = 0L, verify_every = as.integer(verify_every),
                by_reference = by_reference, mutable = fields$field[fields$boundary == "services_mutable"],
                slots = lc_fold_slots(), clock = lc_clock_allowlist(), only = only, on = TRUE), envir = lc_rec)
  invisible()
}

lc_capture_end <- function() {
  lc_rec$on <- FALSE
  folds <- lapply(lc_rec$folds, function(f) as.list(f)[c("id", "fixed", "handler_shape", "writer_shape", "live")])
  list(records = lc_rec$records, folds = folds, store = lc_rec$store, clock = lc_rec$clock)
}

# The manifest: per boundary, captured calls, raised conditions, and one
# SHA-256 over every call's canonical digests in order: its fold's fixed
# services and handler and writer shapes, its input and output, condition
# and warnings, and each handler or writer call with its condition.
lc_manifest <- function(cap) {
  shape <- function(s) paste(c(s$class, s$names, s$fn, s$values$canon), collapse = ",")
  fold <- c("", vapply(cap$folds, function(f) paste(f$fixed$canon, shape(f$handler_shape), shape(f$writer_shape)), ""))
  cond <- function(k) paste(c(k$cond$class, k$cond$message), collapse = "/")
  per <- vapply(cap$records, function(r) {
    calls <- vapply(r$calls, function(k) paste(k$object, k$method, k$args$canon %||% "", k$value$canon %||% "", cond(k)), "")
    paste(c(fold[[r$fold + 1L]], r$input$canon, r$output$canon, cond(r),
            vapply(r$warnings, function(w) paste(c(w$class, w$message), collapse = "/"), ""), calls), collapse = "|")
  }, character(1))
  b <- vapply(cap$records, `[[`, character(1), "boundary")
  ids <- sort(unique(b), method = "radix")
  data.frame(boundary = ids, calls = vapply(ids, function(x) sum(b == x), integer(1)),
             conditions = vapply(ids, function(x) sum(vapply(cap$records[b == x], function(r) !is.null(r$cond), TRUE)), integer(1)),
             digest = vapply(ids, function(x) digest::digest(paste(per[b == x], collapse = "\n"), algo = "sha256", serialize = FALSE), ""),
             row.names = NULL)
}
