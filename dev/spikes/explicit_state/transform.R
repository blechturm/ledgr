# Explicit-state fork of the lean fold (LDG-3278, Cut 27 decision 6).
#
# es_transform(fn, concerns) rewrites lean_fold_envelope_plain so that each
# concern's shared variables live in one environment created at the top of
# the envelope (`<concern> <- new.env(hash = TRUE, parent = emptyenv())`)
# and every stage reads and writes them by field (`commit_state$x`,
# `commit_state$x[i] <- v`) instead of envelope variables written with `<<-`.
# Scope is respected: inside a nested function a name that is a formal or a
# local (`<-`, `=`, for) is a different variable and is not rewritten; a
# `<<-` is rewritten only when no enclosing nested function holds the name.
#
# A name a nested function both reads from the envelope and assigns
# locally (a conditional shadow, `if (marked) pos <- pos[ctx_pos]`) gets a
# snapshot `pos <- <concern>$pos` as that function's first statement, only
# when neither the function nor any envelope function it calls by name
# writes the name; otherwise the transform refuses. Constructs it cannot
# rewrite (a concern name as a call head, a for variable at the envelope
# level, inside quote()/~, or as a string literal) are refused as findings.
#
# es_install(lean, set, gut) installs the fork into a lean environment as
# loop.R does: lean_fold_envelope_plain rebound and lean_envelope_code
# recompiled from it. `gut` leaves one named `<<-` write unrewritten (the
# gutted-path demonstration).

# The concern sets. "commit" is the prerequisite (P5's commit record);
# "all" groups every name a stage or helper writes with `<<-`.
es_sets <- list(
  commit = list(commit_state = c("hd_recon", "hd_has_recon", "n_committed", "strategy_state")),
  all = list(
    book_state = c("cash", "pos", "book", "position_facts", "event_seq", "last_executed", "last_fully_valued"),
    fill_state = c("fl", "fcap", "nf", "hd_fill_start", "hd_nfill", "hd_nrej", "rj"),
    record_state = c("dr", "dcap", "nd", "szr", "scap", "nsz", "hd_pre", "hd_intent", "hd_sizing",
                     "hd_all_explicit", "hd_stop_detail", "eq", "n_eq"),
    commit_state = c("hd_recon", "hd_has_recon", "n_committed", "strategy_state"),
    run_state = c("status", "stop_reason", "processed", "full_run", "n_done", "ctx_pos"))
)

es_missing <- function(x) identical(x, quote(expr = ))

# Innermost target symbol of an assignment's left side.
es_target <- function(lhs) {
  while (is.call(lhs)) lhs <- lhs[[2L]]
  if (is.symbol(lhs)) as.character(lhs) else NA_character_
}

# Names a function body binds locally: `<-`/`=` targets and for variables,
# not descending into nested functions.
es_locals <- function(e) {
  out <- character()
  walk <- function(x) {
    if (!is.call(x)) return(invisible())
    h <- x[[1L]]
    if (identical(h, as.name("function"))) return(invisible())
    if ((identical(h, as.name("<-")) || identical(h, as.name("="))) && length(x) == 3L) {
      t <- es_target(x[[2L]])
      if (!is.na(t)) out <<- c(out, t)
    }
    if (identical(h, as.name("for"))) out <<- c(out, as.character(x[[2L]]))
    for (k in seq_along(x)[-1L]) if (!es_missing(x[[k]])) walk(x[[k]])
  }
  walk(e)
  unique(out)
}

# Every `<<-` target and every call head symbol of an expression, nested
# functions included.
es_supers <- function(e) {
  out <- character()
  walk <- function(x) {
    if (!is.call(x)) return(invisible())
    if (identical(x[[1L]], as.name("<<-"))) out <<- c(out, es_target(x[[2L]]))
    for (k in seq_along(x)) if (!es_missing(x[[k]])) walk(x[[k]])
  }
  walk(e)
  unique(out)
}
es_heads <- function(e) {
  out <- character()
  walk <- function(x) {
    if (!is.call(x)) return(invisible())
    if (is.symbol(x[[1L]])) out <<- c(out, as.character(x[[1L]]))
    for (k in seq_along(x)) if (!es_missing(x[[k]])) walk(x[[k]])
  }
  walk(e)
  unique(out)
}
# Free reads of `names` in a function body (not counting assignment targets).
es_reads <- function(e, names) {
  out <- character()
  walk <- function(x, lhs = FALSE) {
    if (is.symbol(x)) { if (!lhs && as.character(x) %in% names) out <<- c(out, as.character(x)); return(invisible()) }
    if (!is.call(x)) return(invisible())
    h <- x[[1L]]
    if (identical(h, as.name("$")) || identical(h, as.name("@"))) return(walk(x[[2L]], lhs))
    if ((identical(h, as.name("<-")) || identical(h, as.name("=")) || identical(h, as.name("<<-"))) && length(x) == 3L) {
      l <- x[[2L]]
      # the target of a plain `x <- v` is not a read; of `x[i] <- v` it is
      walk(l, lhs = is.symbol(l))
      return(walk(x[[3L]]))
    }
    for (k in seq_along(x)) if (!es_missing(x[[k]])) walk(x[[k]])
  }
  walk(e)
  unique(out)
}

es_transform <- function(fn, concerns, gut = NULL) {
  map <- unlist(lapply(names(concerns), function(o) stats::setNames(rep(o, length(concerns[[o]])), concerns[[o]])))
  findings <- character()
  note <- function(...) findings <<- c(findings, paste0(...))
  counts <- new.env(parent = emptyenv())
  counts$reads <- 0L; counts$writes <- 0L; counts$top <- 0L; counts$gutted <- 0L
  visits <- character()      # concern-symbol visits in walk order, "r"/"w" + name (for rendering)
  supers <- character()      # every `<<-` visited, "1" rewritten / "0" kept, in walk order
  # envelope functions (name -> body) for the snapshot rule's callee check
  top <- as.list(body(fn))[-1L]
  env_fns <- list()
  for (x in top) if (is.call(x) && identical(x[[1L]], as.name("<-")) && is.symbol(x[[2L]]) &&
                     is.call(x[[3L]]) && identical(x[[3L]][[1L]], as.name("function"))) env_fns[[as.character(x[[2L]])]] <- x[[3L]]
  writers <- lapply(env_fns, es_supers)
  field <- function(name) call("$", as.name(map[[name]]), as.name(name))
  current_fn <- "<envelope>"

  # the left side with its innermost target replaced by `repl`; the other
  # parts (index arguments) rewritten in scope
  rw_lhs <- function(lhs, scopes, repl) {
    if (is.symbol(lhs)) {
      if (is.null(repl) && as.character(lhs) %in% names(map)) visits <<- c(visits, paste0("k", as.character(lhs)))
      return(if (is.null(repl)) lhs else repl)
    }
    args <- as.list(lhs)
    args[2L] <- list(rw_lhs(args[[2L]], scopes, repl))
    if (!(identical(args[[1L]], as.name("$")) || identical(args[[1L]], as.name("@")))) {
      for (k in seq_along(args)[-(1:2)]) if (!es_missing(args[[k]])) args[k] <- list(rw(args[[k]], scopes))
    }
    as.call(args)
  }
  shadowed <- function(name, scopes) any(vapply(scopes, function(s) name %in% s, logical(1L)))

  rw <- function(e, scopes) {
    if (is.symbol(e)) {
      nm <- as.character(e)
      if (nzchar(nm) && nm %in% names(map)) {
        if (shadowed(nm, scopes)) { visits <<- c(visits, paste0("k", nm)); return(e) }
        counts$reads <- counts$reads + 1L
        visits <<- c(visits, paste0("r", nm))
        return(field(nm))
      }
      return(e)
    }
    if (is.character(e) && length(e) == 1L && !is.na(e) && e %in% names(map)) note("string literal naming a concern variable: \"", e, "\" in ", current_fn)
    if (!is.call(e)) return(e)
    h <- e[[1L]]
    hn <- if (is.symbol(h)) as.character(h) else ""
    if (hn %in% c("quote", "bquote", "~", "substitute", "expression")) {
      if (length(intersect(all.names(e), names(map)))) note(hn, "() mentions a concern variable in ", current_fn)
      return(e)
    }
    if (hn %in% c("::", ":::")) return(e)
    if (hn %in% c("$", "@")) {
      args <- as.list(e)
      args[2L] <- list(rw(args[[2L]], scopes))
      return(as.call(args))
    }
    if (hn == "function") {
      args <- as.list(e)
      fm <- if (is.null(args[[2L]])) list() else as.list(args[[2L]])
      locals <- unique(c(names(fm), es_locals(args[[3L]])))
      inner <- c(scopes, list(locals))
      # conditional shadow: a local concern name also read free in the function
      cond <- setdiff(intersect(locals, names(map)), names(fm))
      cond <- cond[!vapply(cond, function(nm) shadowed(nm, scopes), logical(1L))]
      cond <- intersect(cond, es_reads(args[[3L]], cond))
      for (k in seq_along(fm)) if (!es_missing(fm[[k]]) && (is.call(fm[[k]]) || is.symbol(fm[[k]]))) fm[k] <- list(rw(fm[[k]], inner))
      if (length(fm)) args[2L] <- list(as.pairlist(fm))
      b <- rw(args[[3L]], inner)
      if (length(cond)) {
        callees <- intersect(es_heads(args[[3L]]), names(env_fns))
        for (nm in cond) {
          bad <- c(if (nm %in% es_supers(args[[3L]])) current_fn, callees[vapply(callees, function(f) nm %in% writers[[f]], logical(1L))])
          if (length(bad)) stop("conditional shadow of `", nm, "` in ", current_fn, " cannot take a snapshot: written by ",
                                paste(bad, collapse = ", "), call. = FALSE)
          note("snapshot `", nm, " <- ", map[[nm]], "$", nm, "` inserted in ", current_fn, " (a local assignment shadows it conditionally)")
          counts$reads <- counts$reads + 1L
          snap <- call("<-", as.name(nm), field(nm))
          b <- if (is.call(b) && identical(b[[1L]], as.name("{"))) as.call(c(list(b[[1L]], snap), as.list(b)[-1L])) else call("{", snap, b)
        }
      }
      args[3L] <- list(b)
      return(as.call(args))
    }
    if (hn %in% c("<-", "=") && length(e) == 3L) {
      # (left side first throughout: `visits` keeps source order for render.R)
      t <- es_target(e[[2L]])
      if (!is.na(t) && t %in% names(map) && length(scopes) == 0L) {
        counts$top <- counts$top + 1L
        visits <<- c(visits, paste0("w", t))
        lhs <- rw_lhs(e[[2L]], scopes, field(t))
      } else {
        lhs <- rw_lhs(e[[2L]], scopes, NULL)
      }
      return(as.call(list(h, lhs, rw(e[[3L]], scopes))))
    }
    if (hn == "<<-") {
      t <- es_target(e[[2L]])
      enclosing <- scopes[-length(scopes)]
      if (!is.na(t) && t %in% names(map) && !shadowed(t, enclosing)) {
        if (!is.null(gut) && identical(gut$name, t) && identical(gut$fn, current_fn) && counts$gutted == 0L) {
          counts$gutted <- 1L
          supers <<- c(supers, "0")
          lhs <- rw_lhs(e[[2L]], scopes, NULL)
          return(as.call(list(h, lhs, rw(e[[3L]], scopes))))
        }
        counts$writes <- counts$writes + 1L
        visits <<- c(visits, paste0("w", t))
        supers <<- c(supers, "1")
        lhs <- rw_lhs(e[[2L]], scopes, field(t))
        return(call("<-", lhs, rw(e[[3L]], scopes)))
      }
      supers <<- c(supers, "0")
      lhs <- rw_lhs(e[[2L]], scopes, NULL)
      return(as.call(list(h, lhs, rw(e[[3L]], scopes))))
    }
    if (hn == "for") {
      v <- as.character(e[[2L]])
      if (v %in% names(map)) {
        visits <<- c(visits, paste0("k", v))
        if (!shadowed(v, scopes)) note("for variable `", v, "` is a concern variable in ", current_fn)
      }
      return(as.call(list(h, e[[2L]], rw(e[[3L]], scopes), rw(e[[4L]], scopes))))
    }
    if (hn %in% names(map)) note("concern name `", hn, "` used as a call head in ", current_fn)
    args <- as.list(e)
    if (is.call(h)) args[1L] <- list(rw(h, scopes))
    for (k in seq_along(args)[-1L]) if (!es_missing(args[[k]])) args[k] <- list(rw(args[[k]], scopes))
    as.call(args)
  }

  # the envelope body, statement by statement (the name of the function a
  # statement defines labels findings and the gut)
  stmts <- as.list(body(fn))[-1L]
  out <- vector("list", length(stmts))
  for (k in seq_along(stmts)) {
    x <- stmts[[k]]
    current_fn <- if (is.call(x) && identical(x[[1L]], as.name("<-")) && is.symbol(x[[2L]]) && is.call(x[[3L]]) &&
                      identical(x[[3L]][[1L]], as.name("function"))) as.character(x[[2L]]) else "<envelope>"
    out[k] <- list(rw(x, list()))
  }
  if (!is.null(gut) && counts$gutted != 1L) stop("gut target not found: ", gut$fn, " ", gut$name, call. = FALSE)
  makes <- lapply(names(concerns), function(o) call("<-", as.name(o), quote(new.env(hash = TRUE, parent = emptyenv()))))
  clash <- intersect(names(concerns), all.names(body(fn)))
  if (length(clash)) stop("concern object names already used in the envelope: ", paste(clash, collapse = ", "), call. = FALSE)
  res <- fn
  body(res) <- as.call(c(list(as.name("{")), makes, out))
  attr(res, "es") <- list(findings = unique(findings), reads = counts$reads, writes = counts$writes,
                          top_assignments = counts$top, visits = visits, supers = supers, map = map)
  res
}

# Free concern names left in a transformed function: any symbol of `map`
# that resolves to the envelope frame (must be none).
es_residual <- function(fn, map) {
  left <- character()
  walk <- function(x, scopes) {
    if (is.symbol(x)) {
      nm <- as.character(x)
      if (nzchar(nm) && nm %in% names(map) && !any(vapply(scopes, function(s) nm %in% s, logical(1L)))) left <<- c(left, nm)
      return(invisible())
    }
    if (!is.call(x)) return(invisible())
    h <- x[[1L]]
    if (identical(h, as.name("$")) || identical(h, as.name("@"))) return(walk(x[[2L]], scopes))
    if (identical(h, as.name("function"))) {
      fm <- if (is.null(x[[2L]])) list() else as.list(x[[2L]])
      inner <- c(scopes, list(unique(c(names(fm), es_locals(x[[3L]])))))
      for (k in seq_along(fm)) if (!es_missing(fm[[k]])) walk(fm[[k]], inner)
      return(walk(x[[3L]], inner))
    }
    if (identical(h, as.name("<<-"))) {
      t <- es_target(x[[2L]])
      if (!is.na(t) && t %in% names(map) && !any(vapply(scopes[-length(scopes)], function(s) t %in% s, logical(1L)))) left <<- c(left, t)
    }
    if ((identical(h, as.name("<-")) || identical(h, as.name("="))) && length(x) == 3L && length(scopes) == 0L) {
      t <- es_target(x[[2L]])
      if (!is.na(t) && is.symbol(x[[2L]]) && t %in% names(map)) left <<- c(left, t)
    }
    for (k in seq_along(x)) if (!es_missing(x[[k]])) walk(x[[k]], scopes)
  }
  walk(body(fn), list())
  unique(left)
}

es_install <- function(lean, set, gut = NULL) {
  concerns <- es_sets[[set]]
  if (is.null(concerns)) stop("unknown explicit-state set: ", set, call. = FALSE)
  plain <- lean$lean_fold_envelope_plain
  fork <- es_transform(plain, concerns, gut)
  info <- attr(fork, "es")
  attr(fork, "es") <- NULL
  left <- es_residual(fork, info$map)
  if (is.null(gut) && length(left)) stop("explicit-state fork leaves envelope references: ", paste(left, collapse = ", "), call. = FALSE)
  lean$lean_fold_envelope_plain <- fork
  lean$lean_envelope_code <- local({
    op <- options(topLevelEnvironment = NULL)
    on.exit(options(op))
    compiler::compile(body(fork), env = environment(fork))
  })
  lean$es_installed <- c(list(set = set, gut = gut, residual = left), info[c("findings", "reads", "writes", "top_assignments")])
  invisible(info)
}
