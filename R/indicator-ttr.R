#' Inspect supported TTR warmup inference rules
#'
#' @return A tibble with columns:
#'   - `ttr_fn`: TTR function name.
#'   - `input`: ledgr input shape.
#'   - `formula`: human-readable warmup formula.
#'   - `required_args`: list column of arguments required for inference.
#'   - `id_args`: list column giving deterministic ID argument order.
#'
#' @examples
#' ledgr_ttr_warmup_rules()
#' @export
ledgr_ttr_warmup_rules <- function() {
  rules <- tibble::tibble(
    ttr_fn = c(
      "RSI", "SMA", "EMA", "ATR", "MACD",
      "WMA", "ROC", "momentum", "CCI", "BBands",
      "aroon", "DonchianChannel", "MFI", "CMF",
      "runMean", "runSD", "runVar", "runMAD"
    ),
    input = c(
      "close", "close", "close", "hlc", "close",
      "close", "close", "close", "hlc", "close",
      "hl", "hl", "hlcv", "hlcv",
      "close", "close", "close", "close"
    ),
    formula = c(
      "n + 1", "n", "n", "n + 1", "nSlow + nSig - 1",
      "n", "n + 1", "n + 1", "n", "n",
      "n", "n", "n + 1", "n",
      "n", "n", "n", "n"
    )
  )
  rules$required_args <- list(
    "n", "n", "n", "n", c("nFast", "nSlow", "nSig"),
    "n", "n", "n", "n", "n",
    "n", "n", "n", "n",
    "n", "n", "n", "n"
  )
  rules$id_args <- list(
    "n", "n", "n", "n", c("nFast", "nSlow", "nSig"),
    "n", "n", "n", "n", "n",
    "n", "n", "n", "n",
    "n", "n", "n", "n"
  )
  rules
}

#' Construct a ledgr indicator from a supported TTR indicator
#'
#' `ledgr_ind_ttr()` requires the suggested `TTR` package at construction time.
#' Install TTR before creating TTR-backed indicators. For interactive debugging
#' with `ledgr_pulse_snapshot()`, pass an active snapshot handle and the same
#' TTR-backed feature declarations used by the experiment. For multi-column TTR
#' functions where you want several outputs, prefer
#' `ledgr_ind_ttr_outputs()`.
#'
#' @param ttr_fn TTR function name, for example `"RSI"`, `"ATR"`, or `"MACD"`.
#' @param input ledgr input shape. Supported values are `"close"`, `"hl"`,
#'   `"hlc"`, `"ohlc"`, and `"hlcv"`.
#' @param output Output column for multi-column TTR functions. Vector outputs
#'   use `NULL`. For common multi-output functions, use TTR's column names:
#'   `BBands` exposes `dn`, `mavg`, `up`, and `pctB`; `MACD` exposes `macd`
#'   and `signal`, and ledgr also supports derived `histogram`.
#' @param id Optional indicator identifier. If omitted, ledgr builds a stable ID
#'   from the TTR function, explicit arguments, and output column.
#' @param requires_bars Explicit warmup length. Required for unknown TTR
#'   functions. For known functions this is inferred from explicit arguments.
#' @param stable_after First stable row. Defaults to `requires_bars`.
#' @param ... Explicit arguments forwarded to the TTR function.
#'
#' @return A `ledgr_indicator` object.
#' @examples
#' if (requireNamespace("TTR", quietly = TRUE)) {
#'   rsi_14 <- ledgr_ind_ttr("RSI", input = "close", n = 14)
#'   rsi_14$id
#'
#'   atr_20 <- ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 20)
#'   atr_20$id
#'
#'   bb_up <- ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
#'   ledgr_feature_id(bb_up)
#'
#'   macd <- ledgr_ind_ttr(
#'     "MACD",
#'     input = "close",
#'     output = "macd",
#'     nFast = 12,
#'     nSlow = 26,
#'     nSig = 9,
#'     percent = FALSE
#'   )
#'   macd_signal <- ledgr_ind_ttr(
#'     "MACD",
#'     input = "close",
#'     output = "signal",
#'     nFast = 12,
#'     nSlow = 26,
#'     nSig = 9,
#'     percent = FALSE
#'   )
#'   ledgr_feature_id(list(macd, macd_signal))
#' }
#'
#' @section Articles:
#' Indicators, feature IDs, and warmup:
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_ind_ttr <- function(ttr_fn,
                          input,
                          output = NULL,
                          id = NULL,
                          requires_bars = NULL,
                          stable_after = requires_bars,
                          ...) {
  if (!requireNamespace("TTR", quietly = TRUE)) {
    rlang::abort(
      "Package 'TTR' is required for ledgr_ind_ttr(). Install TTR or use ledgr_indicator() directly.",
      class = "ledgr_missing_optional_dependency"
    )
  }

  ttr_fn <- ledgr_ttr_normalize_fn(ttr_fn)
  input <- ledgr_ttr_normalize_input(input)
  output <- ledgr_ttr_normalize_output(output)
  args <- ledgr_ttr_normalize_args(list(...))
  rule <- ledgr_ttr_match_rule(ttr_fn, input)

  if (!is.null(rule)) {
    missing_args <- setdiff(rule$required_args[[1]], names(args))
    if (length(missing_args) > 0) {
      rlang::abort(
        sprintf(
          "TTR::%s requires explicit `%s` for ledgr warmup inference and stable indicator IDs.\nExample: %s",
          ttr_fn,
          paste(missing_args, collapse = "`, `"),
          ledgr_ttr_example_call(ttr_fn, input, rule$required_args[[1]])
        ),
        class = "ledgr_invalid_args"
      )
    }
    inferred_requires <- ledgr_ttr_infer_requires_bars(ttr_fn, args, output = output)
    id_args <- rule$id_args[[1]]
  } else {
    known_rule_inputs <- ledgr_ttr_inputs_for_known_function(ttr_fn)
    if (length(known_rule_inputs) > 0L) {
      rlang::abort(
        sprintf(
          "TTR::%s is a known ledgr TTR function but does not support input = \"%s\". Use input = %s.",
          ttr_fn,
          input,
          paste(sprintf("\"%s\"", known_rule_inputs), collapse = " or ")
        ),
        class = "ledgr_invalid_args"
      )
    }
    if (is.null(requires_bars)) {
      rlang::abort(
        sprintf(
          paste0(
            "No deterministic ledgr warmup rule is available for TTR::%s with input = \"%s\". ",
            "Provide `requires_bars` explicitly. To measure it, run the TTR function on 50+ bars ",
            "and count the leading NA values in the selected output, then add one."
          ),
          ttr_fn,
          input
        ),
        class = "ledgr_invalid_args"
      )
    }
    inferred_requires <- as.integer(requires_bars)
    id_args <- sort(names(args))
  }

  if (is.null(requires_bars)) {
    requires_bars <- inferred_requires
  }
  requires_bars <- ledgr_ttr_validate_positive_integer(requires_bars, "`requires_bars`")
  if (is.null(stable_after)) {
    stable_after <- requires_bars
  }
  stable_after <- ledgr_ttr_validate_positive_integer(stable_after, "`stable_after`")
  if (stable_after < requires_bars) {
    rlang::abort("`stable_after` must be an integer >= `requires_bars`.", class = "ledgr_invalid_args")
  }

  if (is.null(id)) {
    id <- ledgr_ttr_default_id(ttr_fn, id_args, args, output)
  }

  params <- list(
    ttr_fn = ttr_fn,
    ttr_version = as.character(utils::packageVersion("TTR")),
    input = input,
    output = output,
    args = args
  )
  ledgr_ttr_validate_output_contract(params, requires_bars)
  indicator_params <- params

  ledgr_indicator(
    id = id,
    fn = function(window, params = indicator_params) {
      selected <- ledgr_ttr_call(window, params)
      as.numeric(utils::tail(selected, 1L))
    },
    series_fn = function(bars, params = indicator_params) {
      ledgr_ttr_call(bars, params)
    },
    requires_bars = requires_bars,
    stable_after = stable_after,
    params = params,
    source = "TTR"
  )
}

#' Construct a bundle from all or selected outputs of a TTR indicator
#'
#' `ledgr_ind_ttr_outputs()` is an authoring convenience for multi-column TTR
#' functions such as `BBands`, `MACD`, `ATR`, `aroon`, and
#' `DonchianChannel`. It returns a `ledgr_indicator_bundle` containing ordinary
#' single-output `ledgr_indicator` objects. The bundle is flattened before
#' runtime feature computation, so strategies still read scalar feature IDs.
#'
#' @param ttr_fn TTR function name, for example `"BBands"` or `"MACD"`.
#' @param input ledgr input shape. Supported values are `"close"`, `"hl"`,
#'   `"hlc"`, `"ohlc"`, and `"hlcv"`.
#' @param outputs Optional character vector of backend output columns to keep.
#'   `NULL` keeps all discovered outputs. For `MACD`, ledgr also exposes a
#'   derived `histogram` output.
#' @param prefix Feature-ID prefix. The default derives a normalized prefix from
#'   `ttr_fn`, for example `"BBands"` becomes `bbands_`. Use a character scalar
#'   such as `"bb"` for concise IDs, or `NULL` to opt into raw output names.
#' @param naming Optional advanced rename escape hatch. Supply a named character
#'   vector whose names are backend outputs and whose values are feature IDs.
#' @param requires_bars Explicit warmup length. Required for unknown TTR
#'   functions. For known functions this is inferred from explicit arguments.
#' @param stable_after First stable row. Defaults to `requires_bars`.
#' @param ... Explicit arguments forwarded to the TTR function.
#'
#' @return A `ledgr_indicator_bundle` object.
#' @examples
#' if (requireNamespace("TTR", quietly = TRUE)) {
#'   bb <- ledgr_ind_ttr_outputs("BBands", input = "close", n = 20)
#'   ledgr_feature_id(bb)
#'
#'   bb_short <- ledgr_ind_ttr_outputs(
#'     "BBands",
#'     input = "close",
#'     outputs = c("dn", "up"),
#'     prefix = "bb",
#'     n = 20
#'   )
#'   ledgr_feature_id(bb_short)
#' }
#'
#' @section Articles:
#' Indicators, feature IDs, and warmup:
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_ind_ttr_outputs <- function(ttr_fn,
                                  input,
                                  ...,
                                  outputs = NULL,
                                  prefix = ledgr_ttr_id_token(ttr_fn),
                                  naming = NULL,
                                  requires_bars = NULL,
                                  stable_after = requires_bars) {
  if (!requireNamespace("TTR", quietly = TRUE)) {
    rlang::abort(
      "Package 'TTR' is required for ledgr_ind_ttr_outputs(). Install TTR or use ledgr_indicator() directly.",
      class = "ledgr_missing_optional_dependency"
    )
  }

  ttr_fn <- ledgr_ttr_normalize_fn(ttr_fn)
  input <- ledgr_ttr_normalize_input(input)
  args <- ledgr_ttr_normalize_args(list(...))
  rule <- ledgr_ttr_match_rule(ttr_fn, input)

  if (!is.null(rule)) {
    missing_args <- setdiff(rule$required_args[[1]], names(args))
    if (length(missing_args) > 0) {
      rlang::abort(
        sprintf(
          "TTR::%s requires explicit `%s` for ledgr warmup inference and stable indicator IDs.\nExample: %s",
          ttr_fn,
          paste(missing_args, collapse = "`, `"),
          ledgr_ttr_example_call(ttr_fn, input, rule$required_args[[1]])
        ),
        class = "ledgr_invalid_args"
      )
    }
    inferred_requires <- ledgr_ttr_infer_requires_bars(ttr_fn, args, output = NULL)
  } else {
    known_rule_inputs <- ledgr_ttr_inputs_for_known_function(ttr_fn)
    if (length(known_rule_inputs) > 0L) {
      rlang::abort(
        sprintf(
          "TTR::%s is a known ledgr TTR function but does not support input = \"%s\". Use input = %s.",
          ttr_fn,
          input,
          paste(sprintf("\"%s\"", known_rule_inputs), collapse = " or ")
        ),
        class = "ledgr_invalid_args"
      )
    }
    if (is.null(requires_bars)) {
      rlang::abort(
        sprintf(
          paste0(
            "No deterministic ledgr warmup rule is available for TTR::%s with input = \"%s\". ",
            "Provide `requires_bars` explicitly."
          ),
          ttr_fn,
          input
        ),
        class = "ledgr_invalid_args"
      )
    }
    inferred_requires <- as.integer(requires_bars)
  }

  if (is.null(requires_bars)) {
    requires_bars <- inferred_requires
  }
  requires_bars <- ledgr_ttr_validate_positive_integer(requires_bars, "`requires_bars`")
  if (is.null(stable_after)) {
    stable_after <- requires_bars
  }
  stable_after <- ledgr_ttr_validate_positive_integer(stable_after, "`stable_after`")
  if (stable_after < requires_bars) {
    rlang::abort("`stable_after` must be an integer >= `requires_bars`.", class = "ledgr_invalid_args")
  }

  params <- list(
    ttr_fn = ttr_fn,
    ttr_version = as.character(utils::packageVersion("TTR")),
    input = input,
    output = NULL,
    args = args
  )
  available_outputs <- ledgr_ttr_discover_outputs(params, requires_bars)
  selected_outputs <- ledgr_ttr_normalize_outputs(outputs, available_outputs, ttr_fn)
  ids <- ledgr_ttr_bundle_ids(
    ttr_fn = ttr_fn,
    outputs = selected_outputs,
    prefix = prefix,
    naming = naming
  )

  indicators <- Map(function(output, id) {
    do.call(
      ledgr_ind_ttr,
      c(
        list(
          ttr_fn = ttr_fn,
          input = input,
          output = output,
          id = id,
          requires_bars = requires_bars,
          stable_after = stable_after
        ),
        args
      )
    )
  }, selected_outputs, ids)

  ledgr_new_indicator_bundle(
    indicators,
    metadata = list(
      source = "TTR",
      family = ttr_fn,
      input = input,
      outputs = selected_outputs,
      prefix = if (is.null(prefix)) NULL else ledgr_ttr_id_token(prefix)
    )
  )
}

ledgr_ttr_normalize_fn <- function(ttr_fn) {
  if (!is.character(ttr_fn) || length(ttr_fn) != 1L || is.na(ttr_fn) || !nzchar(ttr_fn)) {
    rlang::abort("`ttr_fn` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  exports <- getNamespaceExports("TTR")
  exact <- exports[exports == ttr_fn]
  if (length(exact) == 1L) return(exact)
  insensitive <- exports[tolower(exports) == tolower(ttr_fn)]
  if (length(insensitive) == 1L) return(insensitive)
  rlang::abort(sprintf("TTR does not export a function named `%s`.", ttr_fn), class = "ledgr_invalid_args")
}

ledgr_ttr_normalize_input <- function(input) {
  allowed <- c("close", "hl", "hlc", "ohlc", "hlcv")
  if (!is.character(input) || length(input) != 1L || is.na(input) || !nzchar(input)) {
    rlang::abort("`input` must be one of: close, hl, hlc, ohlc, hlcv.", class = "ledgr_invalid_args")
  }
  input <- tolower(input)
  if (!input %in% allowed) {
    rlang::abort("`input` must be one of: close, hl, hlc, ohlc, hlcv.", class = "ledgr_invalid_args")
  }
  input
}

ledgr_ttr_normalize_output <- function(output) {
  if (is.null(output)) return(NULL)
  if (!is.character(output) || length(output) != 1L || is.na(output) || !nzchar(output)) {
    rlang::abort("`output` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  output
}

ledgr_ttr_normalize_args <- function(args) {
  if (!is.list(args)) {
    rlang::abort("TTR arguments must be supplied as named arguments.", class = "ledgr_invalid_args")
  }
  if (length(args) == 0L) return(list())
  nms <- names(args)
  if (is.null(nms) || any(is.na(nms)) || any(!nzchar(nms))) {
    rlang::abort("All TTR arguments must be explicitly named.", class = "ledgr_invalid_args")
  }
  args
}

ledgr_ttr_match_rule <- function(ttr_fn, input) {
  rules <- ledgr_ttr_warmup_rules()
  idx <- which(rules$ttr_fn == ttr_fn & rules$input == input)
  if (length(idx) != 1L) return(NULL)
  rules[idx, , drop = FALSE]
}

ledgr_ttr_inputs_for_known_function <- function(ttr_fn) {
  rules <- ledgr_ttr_warmup_rules()
  unique(rules$input[rules$ttr_fn == ttr_fn])
}

ledgr_ttr_infer_requires_bars <- function(ttr_fn, args, output = NULL) {
  integer_arg <- function(name) ledgr_ttr_validate_positive_integer(args[[name]], sprintf("`%s`", name))
  switch(
    ttr_fn,
    RSI = integer_arg("n") + 1L,
    SMA = integer_arg("n"),
    EMA = integer_arg("n"),
    ATR = integer_arg("n") + 1L,
    WMA = integer_arg("n"),
    ROC = integer_arg("n") + 1L,
    momentum = integer_arg("n") + 1L,
    CCI = integer_arg("n"),
    BBands = integer_arg("n"),
    aroon = integer_arg("n"),
    DonchianChannel = integer_arg("n"),
    MFI = integer_arg("n") + 1L,
    CMF = integer_arg("n"),
    runMean = integer_arg("n"),
    runSD = integer_arg("n"),
    runVar = integer_arg("n"),
    runMAD = integer_arg("n"),
    MACD = {
      integer_arg("nSlow") + integer_arg("nSig") - 1L
    },
    rlang::abort(sprintf("No warmup rule for TTR::%s.", ttr_fn), class = "ledgr_invalid_args")
  )
}

ledgr_ttr_validate_positive_integer <- function(value, label) {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) || !is.finite(value) || value < 1 || (value %% 1) != 0) {
    rlang::abort(sprintf("%s must be an integer >= 1.", label), class = "ledgr_invalid_args")
  }
  as.integer(value)
}

ledgr_ttr_example_call <- function(ttr_fn, input, required_args) {
  examples <- c(
    RSI = "ledgr_ind_ttr(\"RSI\", input = \"close\", n = 14)",
    SMA = "ledgr_ind_ttr(\"SMA\", input = \"close\", n = 20)",
    EMA = "ledgr_ind_ttr(\"EMA\", input = \"close\", n = 20)",
    ATR = "ledgr_ind_ttr(\"ATR\", input = \"hlc\", output = \"atr\", n = 20)",
    MACD = "ledgr_ind_ttr(\"MACD\", input = \"close\", output = \"macd\", nFast = 12, nSlow = 26, nSig = 9, percent = FALSE)",
    WMA = "ledgr_ind_ttr(\"WMA\", input = \"close\", n = 10)",
    ROC = "ledgr_ind_ttr(\"ROC\", input = \"close\", n = 10)",
    momentum = "ledgr_ind_ttr(\"momentum\", input = \"close\", n = 10)",
    CCI = "ledgr_ind_ttr(\"CCI\", input = \"hlc\", n = 20)",
    BBands = "ledgr_ind_ttr(\"BBands\", input = \"close\", output = \"up\", n = 20)",
    aroon = "ledgr_ind_ttr(\"aroon\", input = \"hl\", output = \"oscillator\", n = 20)",
    DonchianChannel = "ledgr_ind_ttr(\"DonchianChannel\", input = \"hl\", output = \"mid\", n = 20)",
    MFI = "ledgr_ind_ttr(\"MFI\", input = \"hlcv\", n = 14)",
    CMF = "ledgr_ind_ttr(\"CMF\", input = \"hlcv\", n = 20)",
    runMean = "ledgr_ind_ttr(\"runMean\", input = \"close\", n = 20)",
    runSD = "ledgr_ind_ttr(\"runSD\", input = \"close\", n = 20)",
    runVar = "ledgr_ind_ttr(\"runVar\", input = \"close\", n = 20)",
    runMAD = "ledgr_ind_ttr(\"runMAD\", input = \"close\", n = 20)"
  )
  if (ttr_fn %in% names(examples)) return(examples[[ttr_fn]])
  arg_bits <- paste(sprintf("%s = ?", required_args), collapse = ", ")
  sprintf("ledgr_ind_ttr(\"%s\", input = \"%s\", %s)", ttr_fn, input, arg_bits)
}

ledgr_ttr_default_id <- function(ttr_fn, id_args, args, output) {
  id_args <- c(id_args, sort(setdiff(names(args), id_args)))
  arg_values <- character(0)
  if (length(id_args) > 0L) {
    arg_values <- vapply(id_args, function(name) {
      if (!name %in% names(args)) {
        rlang::abort(sprintf("Missing `%s` for deterministic TTR indicator ID.", name), class = "ledgr_invalid_args")
      }
      value <- args[[name]]
      if (!is.atomic(value) || length(value) != 1L || is.na(value)) {
        rlang::abort(sprintf("`%s` must be a scalar value for deterministic TTR indicator IDs.", name), class = "ledgr_invalid_args")
      }
      ledgr_ttr_id_token(value)
    }, character(1))
  }
  parts <- c("ttr", tolower(ttr_fn), arg_values)
  if (!is.null(output)) parts <- c(parts, ledgr_ttr_id_token(output))
  paste(parts, collapse = "_")
}

ledgr_ttr_id_token <- function(value) {
  out <- tolower(as.character(value))
  out <- gsub("[^a-z0-9]+", "_", out)
  out <- gsub("^_+|_+$", "", out)
  if (!nzchar(out)) "x" else out
}

ledgr_ttr_build_input <- function(bars, input) {
  if (!is.data.frame(bars)) {
    rlang::abort("TTR input bars must be a data.frame.", class = "ledgr_invalid_feature_input")
  }
  required <- switch(
    input,
    close = "close",
    hl = c("high", "low"),
    hlc = c("high", "low", "close"),
    ohlc = c("open", "high", "low", "close"),
    hlcv = c("high", "low", "close", "volume")
  )
  missing <- setdiff(required, names(bars))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("TTR input `%s` requires bars columns: %s.", input, paste(missing, collapse = ", ")),
      class = "ledgr_invalid_feature_input"
    )
  }
  switch(
    input,
    close = as.numeric(bars$close),
    hl = structure(
      cbind(as.numeric(bars$high), as.numeric(bars$low)),
      dimnames = list(NULL, c("High", "Low"))
    ),
    hlc = structure(
      cbind(as.numeric(bars$high), as.numeric(bars$low), as.numeric(bars$close)),
      dimnames = list(NULL, c("High", "Low", "Close"))
    ),
    ohlc = structure(
      cbind(as.numeric(bars$open), as.numeric(bars$high), as.numeric(bars$low), as.numeric(bars$close)),
      dimnames = list(NULL, c("Open", "High", "Low", "Close"))
    ),
    hlcv = structure(
      cbind(as.numeric(bars$high), as.numeric(bars$low), as.numeric(bars$close), as.numeric(bars$volume)),
      dimnames = list(NULL, c("High", "Low", "Close", "Volume"))
    )
  )
}

ledgr_ttr_call <- function(bars, params) {
  result <- ledgr_ttr_raw_call(bars, params)
  ledgr_ttr_select_output(result, params$output, params$ttr_fn)
}

ledgr_ttr_raw_call <- function(bars, params) {
  if (!requireNamespace("TTR", quietly = TRUE)) {
    rlang::abort("Package 'TTR' is required to compute this TTR indicator.", class = "ledgr_missing_optional_dependency")
  }
  x <- ledgr_ttr_build_input(bars, params$input)
  ttr_fn <- getExportedValue("TTR", params$ttr_fn)
  if (identical(params$input, "hlcv") && params$ttr_fn %in% c("MFI", "CMF")) {
    do.call(ttr_fn, c(list(x[, c("High", "Low", "Close"), drop = FALSE], x[, "Volume"]), params$args))
  } else {
    do.call(ttr_fn, c(list(x), params$args))
  }
}

ledgr_ttr_validate_output_contract <- function(params, requires_bars) {
  bars <- ledgr_ttr_synthetic_bars(requires_bars)
  invisible(ledgr_ttr_call(bars, params))
}

ledgr_ttr_synthetic_bars <- function(requires_bars) {
  n <- max(50L, as.integer(requires_bars) + 5L)
  x <- seq_len(n)
  data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (x - 1L),
    instrument_id = "TTR_CHECK",
    open = 100 + x,
    high = 101 + x,
    low = 99 + x,
    close = 100 + x,
    volume = 1000 + x,
    stringsAsFactors = FALSE
  )
}

ledgr_ttr_discover_outputs <- function(params, requires_bars) {
  bars <- ledgr_ttr_synthetic_bars(requires_bars)
  result <- ledgr_ttr_raw_call(bars, params)
  if (is.null(dim(result))) {
    rlang::abort(
      sprintf("TTR::%s returned a vector; use ledgr_ind_ttr() for single-output TTR indicators.", params$ttr_fn),
      class = "ledgr_invalid_args"
    )
  }
  cols <- colnames(result)
  if (is.null(cols) || any(!nzchar(cols))) {
    cols <- as.character(seq_len(ncol(result)))
  }
  cols <- as.character(cols)
  if (identical(params$ttr_fn, "MACD") && all(c("macd", "signal") %in% cols)) {
    cols <- c(cols, "histogram")
  }
  cols
}

ledgr_ttr_normalize_outputs <- function(outputs, available, ttr_fn) {
  if (is.null(outputs)) {
    return(available)
  }
  if (!is.character(outputs) || length(outputs) < 1L || anyNA(outputs) || any(!nzchar(outputs))) {
    rlang::abort("`outputs` must be NULL or a non-empty character vector.", class = "ledgr_invalid_args")
  }
  if (anyDuplicated(outputs)) {
    dup <- unique(outputs[duplicated(outputs)])
    rlang::abort(sprintf("`outputs` must be unique; duplicate output: %s.", dup[[1L]]), class = "ledgr_invalid_args")
  }
  missing <- setdiff(outputs, available)
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf(
        "Unknown `outputs` for TTR::%s: %s. Available outputs: %s.",
        ttr_fn,
        paste(missing, collapse = ", "),
        paste(available, collapse = ", ")
      ),
      class = "ledgr_invalid_args"
    )
  }
  outputs
}

ledgr_ttr_bundle_ids <- function(ttr_fn, outputs, prefix, naming = NULL) {
  if (!is.null(naming)) {
    if (!is.character(naming) || length(naming) < 1L || anyNA(naming) || any(!nzchar(naming))) {
      rlang::abort("`naming` must be NULL or a named character vector of feature IDs.", class = "ledgr_invalid_args")
    }
    nms <- names(naming)
    if (is.null(nms) || anyNA(nms) || any(!nzchar(nms))) {
      rlang::abort("`naming` must be named by backend output.", class = "ledgr_invalid_args")
    }
    missing <- setdiff(outputs, nms)
    if (length(missing) > 0L) {
      rlang::abort(
        sprintf("`naming` is missing feature ID(s) for output(s): %s.", paste(missing, collapse = ", ")),
        class = "ledgr_invalid_args"
      )
    }
    ids <- unname(as.character(naming[outputs]))
    ledgr_abort_duplicate_feature_ids(ids)
    return(ids)
  }

  output_tokens <- vapply(outputs, ledgr_ttr_id_token, character(1))
  if (is.null(prefix)) {
    ids <- output_tokens
  } else {
    prefix <- ledgr_ttr_id_token(prefix)
    ids <- paste(prefix, output_tokens, sep = "_")
  }
  ledgr_abort_duplicate_feature_ids(ids)
  ids
}

ledgr_ttr_select_output <- function(result, output, ttr_fn) {
  if (is.null(dim(result))) {
    if (!is.null(output)) {
      rlang::abort(
        sprintf("TTR::%s returned a vector; `output` must be NULL.", ttr_fn),
        class = "ledgr_invalid_args"
      )
    }
    return(as.numeric(result))
  }

  cols <- colnames(result)
  if (is.null(cols) || any(!nzchar(cols))) {
    cols <- as.character(seq_len(ncol(result)))
  }
  if (is.null(output)) {
    if (ncol(result) == 1L) return(as.numeric(result[, 1L]))
    rlang::abort(
      sprintf(
        "TTR::%s returned multiple columns; choose `output`. Available outputs: %s.",
        ttr_fn,
        paste(cols, collapse = ", ")
      ),
      class = "ledgr_invalid_args"
    )
  }
  if (identical(ttr_fn, "MACD") && identical(output, "histogram") && all(c("macd", "signal") %in% cols)) {
    return(as.numeric(result[, "macd"] - result[, "signal"]))
  }
  if (!output %in% cols) {
    available <- cols
    if (identical(ttr_fn, "MACD") && all(c("macd", "signal") %in% cols)) {
      available <- c(available, "histogram")
    }
    rlang::abort(
      sprintf(
        "Unknown `output` for TTR::%s: %s. Available outputs: %s.",
        ttr_fn,
        output,
        paste(available, collapse = ", ")
      ),
      class = "ledgr_invalid_args"
    )
  }
  as.numeric(result[, output])
}
