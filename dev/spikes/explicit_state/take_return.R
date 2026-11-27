# One stage takes and returns explicit state (LDG-3278, Cut 27 decision 6,
# the specified prerequisite).
#
# tr_install(lean, gut) forks lean_fold_envelope_plain so that P5
# (lean_p5_commit) takes its commit record as one explicit list value,
#   state = list(hd_recon, hd_has_recon, n_committed, strategy_state),
# and returns the new value. Inside the stage every read of those four names
# becomes `state$x` and every `x <<- v` becomes `state$x <- v`; the stage
# ends with `state`. The call site in run_loop builds the list from the
# envelope's variables, calls the stage and assigns the returned fields back
# (`hd_recon <<- p5$hd_recon`, ...). Everything else is loop.R as it stands.
#
# The stage is derived from loop.R's own P5 by es_transform (transform.R) on
# a one-statement envelope, so no economic rule is copied: the capacity
# refusal, the reconciliation checks and the state update are the tracked
# code, read at load time.
#
# gut = "<name>" leaves that one write out of the returned state: the stage
# writes it to a local copy (`hd_recon[i, ] <- recon`) instead of `state`.

tr_names <- c("hd_recon", "hd_has_recon", "n_committed", "strategy_state")

tr_install <- function(lean, gut = NULL) {
  plain <- lean$lean_fold_envelope_plain
  stmts <- as.list(body(plain))
  is_def <- function(x, nm) is.call(x) && identical(x[[1L]], as.name("<-")) && identical(x[[2L]], as.name(nm))
  k5 <- which(vapply(stmts, is_def, logical(1L), nm = "lean_p5_commit"))
  if (length(k5) != 1L) stop("lean_p5_commit definition not found once in the envelope", call. = FALSE)
  if ("state" %in% all.names(stmts[[k5]])) stop("`state` is already a name in lean_p5_commit", call. = FALSE)
  if ("return" %in% all.names(stmts[[k5]])) stop("lean_p5_commit has an early return; the stage would not return its state", call. = FALSE)

  # 1. the stage: reads -> state$x, `<<-` -> `state$x <- v` (es_transform's
  #    scope rules), then the `state` formal and the returned value
  gut_name <- if (is.null(gut)) NULL else gut
  fake <- function() NULL
  body(fake) <- call("{", stmts[[k5]])
  tf <- es_transform(fake, list(state = tr_names))
  info <- attr(tf, "es")
  def <- body(tf)[[3L]]                       # [[2L]] is es_transform's `state <- new.env()`
  fn <- def[[3L]]
  fm <- as.list(fn[[2L]])
  fn[[2L]] <- as.pairlist(c(fm, alist(state = )))
  b <- as.list(fn[[3L]])
  if (!identical(b[[length(b)]], quote(invisible(NULL)))) stop("lean_p5_commit no longer ends with invisible(NULL)", call. = FALSE)
  b[[length(b)]] <- as.name("state")
  stage <- as.call(b)
  if (!is.null(gut_name)) {
    hits <- 0L
    ungut <- function(x) {
      if (!is.call(x)) return(x)
      if (identical(x[[1L]], as.name("<-")) && is.call(x[[2L]]) && hits == 0L) {
        lhs <- x[[2L]]
        inner <- lhs
        while (is.call(inner) && !identical(inner[[1L]], as.name("$"))) inner <- inner[[2L]]
        if (is.call(inner) && identical(inner, call("$", as.name("state"), as.name(gut_name)))) {
          hits <<- hits + 1L
          rep_in <- function(l) if (identical(l, inner)) as.name(gut_name) else { l[[2L]] <- rep_in(l[[2L]]); l }
          x[[2L]] <- rep_in(lhs)
          return(x)
        }
      }
      if (identical(x[[1L]], as.name("<-")) && identical(x[[2L]], call("$", as.name("state"), as.name(gut_name))) && hits == 0L) {
        hits <<- hits + 1L
        x[[2L]] <- as.name(gut_name)
        return(x)
      }
      for (j in seq_along(x)) if (!es_missing(x[[j]])) x[j] <- list(ungut(x[[j]]))
      x
    }
    stage <- ungut(stage)
    if (hits != 1L) stop("gut target not found in the stage: ", gut_name, call. = FALSE)
  }
  fn[[3L]] <- stage
  def[[3L]] <- fn
  stmts[[k5]] <- def

  # no `<<-` to the four names may remain in the stage
  left <- intersect(es_supers(fn[[3L]]), tr_names)
  if (length(left)) stop("the stage still writes the envelope: ", paste(left, collapse = ", "), call. = FALSE)

  # 2. the call site: pass the state in, assign the returned fields back
  site <- quote(lean_p5_commit(i, v1, v2, v3$batch, n_fill))
  repl <- c(
    list(call("<-", as.name("p5"), as.call(c(as.list(site),
      list(as.call(c(list(as.name("list")), stats::setNames(lapply(tr_names, as.name), tr_names)))))))),
    lapply(tr_names, function(nm) call("<<-", as.name(nm), call("$", as.name("p5"), as.name(nm)))))
  found <- 0L
  splice <- function(x) {
    if (!is.call(x)) return(x)
    if (identical(x[[1L]], as.name("{"))) {
      parts <- as.list(x)[-1L]
      out <- list()
      for (p in parts) {
        if (identical(p, site)) { found <<- found + 1L; out <- c(out, repl) } else out <- c(out, list(splice(p)))
      }
      return(as.call(c(list(as.name("{")), out)))
    }
    for (j in seq_along(x)) if (!es_missing(x[[j]])) x[j] <- list(splice(x[[j]]))
    x
  }
  kr <- which(vapply(stmts, is_def, logical(1L), nm = "run_loop"))
  if (length(kr) != 1L) stop("run_loop not found once in the envelope", call. = FALSE)
  stmts[[kr]] <- splice(stmts[[kr]])
  if (found != 1L) stop("P5 call site found ", found, " times in run_loop", call. = FALSE)
  # no other caller of the stage
  others <- vapply(stmts[-c(k5, kr)], function(x) "lean_p5_commit" %in% all.names(x), logical(1L))
  if (any(others)) stop("lean_p5_commit is called outside run_loop", call. = FALSE)

  fork <- plain
  body(fork) <- as.call(stmts)
  lean$lean_fold_envelope_plain <- fork
  lean$lean_envelope_code <- local({
    op <- options(topLevelEnvironment = NULL)
    on.exit(options(op))
    compiler::compile(body(fork), env = environment(fork))
  })
  lean$es_installed <- list(set = "p5", gut = if (is.null(gut)) NULL else list(fn = "lean_p5_commit", name = gut),
    residual = character(), findings = info$findings, reads = info$reads, writes = info$writes,
    top_assignments = length(tr_names))
  lean$tr_stage <- fn
  invisible(info)
}
