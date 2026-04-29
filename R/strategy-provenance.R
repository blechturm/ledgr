ledgr_strategy_signature <- function(fn) {
  if (!is.function(fn)) {
    rlang::abort("`strategy` must be a function.", class = "ledgr_invalid_strategy_signature")
  }

  args <- names(formals(fn))
  if (is.null(args)) args <- character()

  if (identical(args, c("ctx", "params"))) {
    return("ctx_params")
  }

  rlang::abort(
    paste0(
      "Functional strategies must have signature function(ctx, params) in v0.1.7. ",
      "Use `params` as the second argument; `ctx$params` is not part of the strategy context. ",
      "Unsupported signature: function(",
      paste(args, collapse = ", "),
      ")."
    ),
    class = "ledgr_invalid_strategy_signature"
  )
}

ledgr_call_strategy_fn <- function(fn, ctx, params = list(), signature = NULL) {
  if (is.null(signature)) {
    signature <- ledgr_strategy_signature(fn)
  }
  if (identical(signature, "ctx_params")) {
    return(fn(ctx, params))
  }
  rlang::abort("Unknown functional strategy signature.", class = "ledgr_invalid_strategy_signature")
}

ledgr_strategy_params_info <- function(strategy_params = list()) {
  if (is.null(strategy_params)) strategy_params <- list()
  if (!is.list(strategy_params) || is.data.frame(strategy_params)) {
    rlang::abort("`strategy_params` must be a JSON-safe list.", class = "ledgr_invalid_strategy_params")
  }

  json <- tryCatch(
    canonical_json(strategy_params),
    error = function(e) {
      rlang::abort(
        "`strategy_params` must be canonical-JSON serializable. Use scalars, vectors, and lists; avoid functions, environments, connections, and non-finite numbers.",
        class = "ledgr_invalid_strategy_params",
        parent = e
      )
    }
  )

  list(
    value = strategy_params,
    json = unname(json),
    hash = digest::digest(unname(json), algo = "sha256")
  )
}

ledgr_strategy_source_info <- function(fn) {
  source <- tryCatch(ledgr_deparse_one(fn), error = function(e) NA_character_)
  globals <- tryCatch(ledgr_strategy_external_symbols(fn), error = function(e) character())
  if (!is.character(source) || length(source) != 1 || is.na(source) || !nzchar(source)) {
    return(list(
      source = NA_character_,
      hash = NA_character_,
      capture_method = "functional_no_source",
      external_symbols = globals
    ))
  }

  list(
    source = source,
    hash = digest::digest(source, algo = "sha256"),
    capture_method = "deparse_function",
    external_symbols = globals
  )
}

ledgr_strategy_external_symbols <- function(fn) {
  globals <- codetools::findGlobals(fn, merge = FALSE)
  functions <- globals$functions
  variables <- globals$variables

  syntax_functions <- c(
    "{", "(", "<-", "=", "if", "else", "for", "while", "repeat",
    "break", "next", "return", "[", "[[", "$", "[<-", "[[<-", "$<-",
    "::", ":", "+", "-", "*", "/", "^", "<", ">", "<=", ">=", "==",
    "!=", "&&", "||", "!", "&", "|", "%in%", "c", "list"
  )
  base_namespaces <- c("base", "stats", "utils", "methods", "grDevices", "graphics")
  is_base_or_recommended <- function(sym) {
    if (sym %in% syntax_functions) {
      return(TRUE)
    }
    any(vapply(
      base_namespaces,
      function(pkg) exists(sym, envir = asNamespace(pkg), inherits = FALSE),
      logical(1)
    ))
  }

  external_functions <- functions[!vapply(functions, is_base_or_recommended, logical(1))]

  sort(unique(c(
    external_functions,
    setdiff(variables, c("ctx", "params"))
  )))
}

ledgr_strategy_reproducibility_level <- function(strategy_type, signature = NULL, source_info = NULL) {
  if (identical(strategy_type, "functional")) {
    if (identical(signature, "ctx_params") &&
        is.list(source_info) &&
        is.character(source_info$source) &&
        length(source_info$source) == 1 &&
        !is.na(source_info$source) &&
        nzchar(source_info$source) &&
        length(source_info$external_symbols) == 0L) {
      return("tier_1")
    }
    return("tier_2")
  }
  if (identical(strategy_type, "R6_object")) {
    return("tier_2")
  }
  "tier_3"
}

ledgr_dependency_versions_json <- function() {
  packages <- c("ledgr", "duckdb", "DBI", "digest", "jsonlite", "tibble", "TTR")
  versions <- list(R = as.character(getRversion()))

  for (pkg in packages) {
    versions[[pkg]] <- if (requireNamespace(pkg, quietly = TRUE)) {
      as.character(utils::packageVersion(pkg))
    } else {
      NA_character_
    }
  }

  unname(canonical_json(versions))
}

ledgr_write_strategy_provenance <- function(con, run_id, cfg, created_at_utc = NULL) {
  provenance <- cfg$strategy$provenance
  params_json <- cfg$strategy_params_json
  params_hash <- cfg$strategy_params_hash
  fallback <- function(x, default) {
    if (is.null(x)) default else x
  }

  if (is.null(provenance) || !is.list(provenance)) {
    provenance <- list(
      strategy_type = "legacy",
      strategy_source = NA_character_,
      strategy_source_hash = NA_character_,
      strategy_source_capture_method = "legacy_pre_provenance",
      reproducibility_level = "legacy"
    )
  }

  DBI::dbExecute(
    con,
    "
    INSERT OR REPLACE INTO run_provenance (
      run_id,
      strategy_type,
      strategy_source,
      strategy_source_hash,
      strategy_source_capture_method,
      strategy_params_json,
      strategy_params_hash,
      reproducibility_level,
      ledgr_version,
      R_version,
      dependency_versions_json,
      created_at_utc
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ",
    params = list(
      run_id,
      fallback(provenance$strategy_type, "legacy"),
      fallback(provenance$strategy_source, NA_character_),
      fallback(provenance$strategy_source_hash, NA_character_),
      fallback(provenance$strategy_source_capture_method, "legacy_pre_provenance"),
      fallback(params_json, unname(canonical_json(list()))),
      fallback(params_hash, digest::digest(unname(canonical_json(list())), algo = "sha256")),
      fallback(provenance$reproducibility_level, "legacy"),
      as.character(utils::packageVersion("ledgr")),
      as.character(getRversion()),
      ledgr_dependency_versions_json(),
      fallback(created_at_utc, as.POSIXct(Sys.time(), tz = "UTC"))
    )
  )

  invisible(TRUE)
}
