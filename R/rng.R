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
