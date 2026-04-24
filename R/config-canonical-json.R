.ledgr_json_cache <- new.env(parent = emptyenv())
.ledgr_json_cache_max <- 1024L
.ledgr_json_cache$count <- 0L

.ledgr_json_cache_get <- function(key) {
  if (!exists(key, envir = .ledgr_json_cache, inherits = FALSE)) return(NULL)
  get(key, envir = .ledgr_json_cache, inherits = FALSE)
}

.ledgr_json_cache_set <- function(key, value) {
  assign(key, value, envir = .ledgr_json_cache)
  .ledgr_json_cache$count <- .ledgr_json_cache$count + 1L
  if (.ledgr_json_cache$count > .ledgr_json_cache_max) {
    rm(list = ls(envir = .ledgr_json_cache, all.names = TRUE), envir = .ledgr_json_cache)
    .ledgr_json_cache$count <- 0L
  }
  invisible(TRUE)
}

.ledgr_json_cache_key <- function(x) {
  if (is.character(x) && length(x) == 1 && !is.na(x)) {
    return(digest::digest(x, algo = "sha256"))
  }
  digest::digest(x, algo = "sha256")
}

canonical_json <- function(x) {
  if (is.character(x) && length(x) == 1 && !is.na(x)) {
    if (isTRUE(attr(x, "ledgr_canonical_json"))) return(unname(x))
  }

  cache_key <- .ledgr_json_cache_key(x)
  cached <- .ledgr_json_cache_get(cache_key)
  if (!is.null(cached)) return(cached)

  if (is.character(x) && length(x) == 1 && !is.na(x)) {
    x <- tryCatch(
      jsonlite::fromJSON(x, simplifyVector = FALSE),
      error = function(e) {
        rlang::abort(
          "canonical_json() received a character input that is not valid JSON.",
          class = "ledgr_config_invalid_json"
        )
      }
    )
  }

  canonicalize <- function(obj) {
    if (is.null(obj)) {
      return(NULL)
    }

    if (is.environment(obj) || is.function(obj) || is.symbol(obj) || is.language(obj) || is.expression(obj) ||
      inherits(obj, "externalptr") || inherits(obj, "connection")) {
      rlang::abort(
        "canonical_json() received an unsupported value type in config; use only JSON-serializable scalars/vectors/lists.",
        class = "ledgr_config_non_deterministic"
      )
    }

    if (inherits(obj, "POSIXt")) {
      obj <- as.POSIXct(obj, tz = "UTC")
      return(format(obj, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
    }

    if (is.data.frame(obj)) {
      rlang::abort(
        "canonical_json() does not accept data.frames in config; use a list structure instead.",
        class = "ledgr_config_unsupported_type"
      )
    }

    if (is.factor(obj)) {
      return(as.character(obj))
    }

    if (is.atomic(obj)) {
      if (is.double(obj) && any(!is.finite(obj))) {
        rlang::abort(
          "canonical_json() does not allow non-finite numeric values in config (Inf/-Inf/NaN).",
          class = "ledgr_config_non_finite"
        )
      }

      if (!is.null(names(obj)) && length(obj) > 0) {
        nm <- names(obj)
        ord <- order(nm)
        obj <- as.list(obj)
        names(obj) <- nm
        obj <- obj[ord]
        return(lapply(obj, canonicalize))
      }

      return(obj)
    }

    if (is.list(obj)) {
      nm <- names(obj)
      if (!is.null(nm)) {
        ord <- order(nm)
        obj <- obj[ord]
        nm <- nm[ord]
        names(obj) <- nm
      }
      return(lapply(obj, canonicalize))
    }

    rlang::abort(
      sprintf("canonical_json() received an unsupported config value of class: %s", paste(class(obj), collapse = "/")),
      class = "ledgr_config_unsupported_type"
    )
  }

  payload <- canonicalize(x)
  out <- jsonlite::toJSON(
    payload,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA,
    pretty = FALSE
  )
  attr(out, "ledgr_canonical_json") <- TRUE
  .ledgr_json_cache_set(cache_key, out)
  out
}
