canonical_json <- function(x) {
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

  jsonlite::toJSON(
    canonicalize(x),
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA,
    pretty = FALSE
  )
}
