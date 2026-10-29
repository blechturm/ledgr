ledgr_seed_normalize <- function(seed, arg = "seed", allow_null = TRUE) {
  if (is.null(seed)) {
    if (isTRUE(allow_null)) {
      return(NULL)
    }
    rlang::abort(sprintf("`%s` must be an integer-like scalar.", arg), class = "ledgr_invalid_args")
  }

  if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) || !is.finite(seed) || (seed %% 1) != 0) {
    expected <- if (isTRUE(allow_null)) "NULL or an integer-like scalar" else "an integer-like scalar"
    rlang::abort(sprintf("`%s` must be %s.", arg, expected), class = "ledgr_invalid_args")
  }

  out <- suppressWarnings(as.integer(seed))
  if (is.na(out)) {
    rlang::abort(sprintf("`%s` must be a valid R integer seed.", arg), class = "ledgr_invalid_args")
  }
  out
}

ledgr_derive_seed <- function(base_seed, salt) {
  base_seed <- ledgr_seed_normalize(base_seed, arg = "base_seed", allow_null = FALSE)
  payload <- canonical_json(list(base_seed = base_seed, salt = salt))
  hash <- digest::digest(payload, algo = "sha256", serialize = FALSE)
  starts <- seq.int(1L, 31L, by = 6L)
  chunks <- substring(hash, starts, starts + 5L)
  values <- vapply(chunks, strtoi, integer(1), base = 16L)
  weights <- c(1, 17, 257, 4099, 65537, 104729)
  seed <- (sum(as.numeric(values) * weights) %% 2147483647) + 1
  as.integer(seed)
}

ledgr_derive_pulse_seed <- function(execution_seed, pulse_idx) {
  if (is.null(execution_seed)) {
    return(NULL)
  }
  execution_seed <- ledgr_seed_normalize(
    execution_seed,
    arg = "execution_seed",
    allow_null = FALSE
  )
  if (!is.numeric(pulse_idx) ||
      length(pulse_idx) != 1L ||
      is.na(pulse_idx) ||
      !is.finite(pulse_idx) ||
      pulse_idx < 1L ||
      pulse_idx %% 1 != 0) {
    rlang::abort(
      "`pulse_idx` must be a positive integer-like scalar.",
      class = "ledgr_invalid_args"
    )
  }
  ledgr_derive_seed(
    execution_seed,
    list(scope = "pulse", pulse_idx = as.integer(pulse_idx))
  )
}

# RNG isolation (v0.2.3 cut 4, LDG-3158; ws2_rng_design.md Sections 3-5).
#
# One seeding helper sets the seed and pins the kind in the same call. The
# state helpers capture and restore the caller's RNG kind and `.Random.seed`,
# or its absence. A pending Box-Muller normal is not part of that state.

ledgr_rng_seed_pinned <- function(seed) {
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
}

ledgr_rng_caller_state <- function() {
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  list(
    had_seed = had_seed,
    seed = if (had_seed) get(".Random.seed", envir = globalenv(), inherits = FALSE) else NULL,
    kind = RNGkind()
  )
}

# A present seed carries its kind in its first element. An absent seed is
# restored by setting the kind and then removing the seed the kind change
# created. That kind change is made from this function's own frame (the
# recursion only installs the warning muffler for a Rounding sample kind), so
# the mutation's immediate caller is always `ledgr_rng_restore`.
ledgr_rng_restore <- function(state, muffled = FALSE) {
  if (isTRUE(state$had_seed)) {
    assign(".Random.seed", state$seed, envir = globalenv())
    return(invisible(NULL))
  }
  if (!isTRUE(muffled)) {
    return(withCallingHandlers(
      ledgr_rng_restore(state, muffled = TRUE),
      warning = function(w) invokeRestart("muffleWarning")
    ))
  }
  RNGkind(state$kind[[1L]], state$kind[[2L]], state$kind[[3L]])
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  invisible(NULL)
}

# Step 2 of a wrapped export: save the caller's state, evaluate the
# implementation, restore after every inner cleanup on success, error and
# interrupt. Visibility of the implementation's value is kept.
ledgr_rng_preserve_caller <- function(expr) {
  state <- ledgr_rng_caller_state()
  on.exit(ledgr_rng_restore(state), add = TRUE)
  value <- withVisible(expr)
  if (isTRUE(value$visible)) value$value else invisible(value$value)
}

# Step 1 of a wrapped export (decision (15)): force the caller-supplied
# ordinary arguments and dots in the export's own frame, before the caller's
# state is saved, so draws in arguments are the caller's own. Missing
# arguments keep their lazy defaults; formals named in `lazy` (captured
# service expressions) are never forced.
ledgr_rng_force_args <- function(lazy = character(), env = parent.frame()) {
  frames <- sys.frames()
  at <- Position(function(frame) identical(frame, env), frames, right = TRUE)
  if (is.na(at)) {
    rlang::abort("`env` must be the frame of a calling function.", class = "ledgr_invalid_args")
  }
  for (name in names(formals(sys.function(at)))) {
    if (name %in% lazy) {
      next
    }
    if (identical(name, "...")) {
      if (eval(quote(...length()), env) > 0L) {
        eval(quote(list(...)), env)
      }
      next
    }
    if (!eval(call("missing", as.name(name)), env)) {
      get(name, envir = env, inherits = FALSE)
    }
  }
  invisible(NULL)
}

# Every DuckDB append goes through here (decision (3)). duckdb's nonempty
# dbAppendTable() names a temporary view with sample(), so the append keeps
# `.Random.seed`, or its absence, on normal and error exits. An append never
# changes the kind.
ledgr_store_append <- function(con, name, value) {
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = globalenv(), inherits = FALSE)
  on.exit(
    if (had) {
      assign(".Random.seed", old, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    },
    add = TRUE
  )
  DBI::dbAppendTable(con, name, value)
}
