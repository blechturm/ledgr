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

# Pulse-seed rule v2 (v0.2.3 cut 4, LDG-3159; ws2_rng_design.md Section 2).
#
# pulse_seed(s, p) = fmix32(fmix32(u32(s)) xor u32(p)) mod (2^31 - 1) + 1,
# with fmix32 the MurmurHash3 finalizer. Every value is an unsigned 32-bit
# integer held in a double. The 16-bit splits keep every intermediate below
# 2^33, so the arithmetic is exact on any IEEE-754 platform, and bitwXor only
# ever sees non-negative values below 2^16. The one constant names the rule
# in sweep attributes, candidate provenance, seeded run configurations and
# validation.
ledgr_pulse_seed_rule_version <- 2L

ledgr_seed_contract_current <- function() {
  paste0("ledgr_seed_v", ledgr_pulse_seed_rule_version)
}

ledgr_rng_u32 <- function(x) x %% 4294967296

ledgr_rng_xor32 <- function(a, b) {
  bitwXor(as.integer(a %/% 65536), as.integer(b %/% 65536)) * 65536 +
    bitwXor(as.integer(a %% 65536), as.integer(b %% 65536))
}

ledgr_rng_mul32 <- function(a, b) {
  al <- a %% 65536
  ah <- a %/% 65536
  bl <- b %% 65536
  bh <- b %/% 65536
  (al * bl + ((ah * bl + al * bh) %% 65536) * 65536) %% 4294967296
}

ledgr_rng_fmix32 <- function(h) {
  h <- ledgr_rng_xor32(h, h %/% 65536)
  h <- ledgr_rng_mul32(h, 2246822507)
  h <- ledgr_rng_xor32(h, h %/% 8192)
  h <- ledgr_rng_mul32(h, 3266489909)
  ledgr_rng_xor32(h, h %/% 65536)
}

# The one owner of the rule. Vectorised over `pulse_idx`, the positions on the
# run's own pulse calendar; the seed's mix is computed once per call. The fold
# calls it once per fold over the whole calendar and reads by index. A NULL
# execution seed returns NULL.
ledgr_pulse_seeds <- function(execution_seed, pulse_idx) {
  if (is.null(execution_seed)) {
    return(NULL)
  }
  execution_seed <- ledgr_seed_normalize(
    execution_seed,
    arg = "execution_seed",
    allow_null = FALSE
  )
  if (!is.numeric(pulse_idx) ||
      anyNA(pulse_idx) ||
      any(!is.finite(pulse_idx)) ||
      any(pulse_idx < 1) ||
      any(pulse_idx > 2147483647) ||
      any(pulse_idx %% 1 != 0)) {
    rlang::abort(
      "`pulse_idx` must hold positive integer-like values no larger than 2147483647.",
      class = "ledgr_invalid_args"
    )
  }
  seed_mix <- ledgr_rng_fmix32(ledgr_rng_u32(as.numeric(execution_seed)))
  mixed <- ledgr_rng_fmix32(ledgr_rng_xor32(seed_mix, ledgr_rng_u32(as.numeric(pulse_idx))))
  as.integer(mixed %% 2147483647 + 1)
}

# The context's one read of the fold's pulse-seed vector.
ledgr_pulse_seed_at <- function(services, pulse_idx) {
  seeds <- services$pulse_seeds
  if (is.null(seeds)) {
    return(NULL)
  }
  seeds[[pulse_idx]]
}

# Promotion inputs carry the current pulse-seed rule (decision (7)). A sweep
# candidate names it in `seed_contract`; a walk-forward candidate keeps its
# derivation marker in `seed_contract` and names the pulse rule in
# `pulse_seed_contract`, copied from its results object. Old and missing
# markers are refused, with no compatibility path.
ledgr_candidate_validate_seed_rule <- function(candidate) {
  provenance <- candidate$provenance
  if (!is.list(provenance)) {
    provenance <- list()
  }
  current <- ledgr_seed_contract_current()
  marker_text <- function(x) {
    if (is.character(x) && length(x) == 1L && !is.na(x)) x else "<missing>"
  }
  refuse <- function(field, observed, required) {
    rlang::abort(
      sprintf(
        paste(
          "Candidate '%s' records %s %s; this ledgr requires %s.",
          "Re-run the sweep or walk-forward session with this ledgr version before promoting."
        ),
        as.character(candidate$candidate_id %||% "<unknown>"),
        field, marker_text(observed), required
      ),
      class = c("ledgr_seed_rule_mismatch", "ledgr_invalid_args")
    )
  }
  if (identical(provenance$evaluation_scope, "walk_forward")) {
    if (!identical(provenance$seed_contract, "ledgr_walk_forward_seed_v1")) {
      refuse("seed_contract", provenance$seed_contract, "ledgr_walk_forward_seed_v1")
    }
    if (!identical(provenance$pulse_seed_contract, current)) {
      refuse("pulse_seed_contract", provenance$pulse_seed_contract, current)
    }
    return(invisible(TRUE))
  }
  if (!identical(provenance$seed_contract, current)) {
    refuse("seed_contract", provenance$seed_contract, current)
  }
  invisible(TRUE)
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
