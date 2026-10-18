# Indicator history declarations (historical projection synthesis v12,
# Section 6). Every concrete definition is either `bounded` or
# `history_dependent`. Package built-ins and registered TTR forms take their
# declarations from one package catalogue; any other definition follows the
# custom rules: an undeclared history class is disclosed as
# `history_dependent`, and bounded is declared, never inferred.

ledgr_feature_history_rule_version <- 1L

ledgr_indicator_bar_fields <- function() {
  c("open", "high", "low", "close", "volume")
}

ledgr_indicator_default_required_fields <- function() {
  c("open", "high", "low", "close")
}

ledgr_indicator_history_classes <- function() {
  c("bounded", "history_dependent")
}

ledgr_indicator_abort_declaration <- function(message,
                                              contradiction = FALSE,
                                              ...) {
  rlang::abort(
    message,
    class = c(
      if (isTRUE(contradiction)) "ledgr_indicator_history_contradiction",
      "ledgr_invalid_indicator_declaration",
      "ledgr_invalid_args"
    ),
    ...
  )
}

ledgr_indicator_normalize_required_fields <- function(required_fields, id = NULL) {
  label <- if (is.null(id)) "" else sprintf(" (indicator `%s`)", id)
  allowed <- ledgr_indicator_bar_fields()
  if (!is.character(required_fields) || length(required_fields) < 1L ||
      anyNA(required_fields) || any(!nzchar(required_fields)) ||
      anyDuplicated(required_fields) ||
      !all(required_fields %in% allowed)) {
    ledgr_indicator_abort_declaration(
      sprintf(
        "`required_fields` must be a non-empty set of unique bar fields from %s%s.",
        paste(allowed, collapse = ", "),
        label
      )
    )
  }
  allowed[allowed %in% required_fields]
}

ledgr_indicator_declare <- function(history_class = NULL,
                                    gap_contract = NULL,
                                    required_fields = NULL,
                                    tolerance = NULL,
                                    input_carry = NULL,
                                    has_series_fn = FALSE,
                                    id = NULL,
                                    history_source = NULL,
                                    required_fields_source = NULL,
                                    input_carry_source = NULL) {
  label <- if (is.null(id)) "" else sprintf(" (indicator `%s`)", id)
  if (!is.null(gap_contract) &&
      (!is.character(gap_contract) || length(gap_contract) != 1L ||
       is.na(gap_contract) || !identical(gap_contract, "strict_window"))) {
    ledgr_indicator_abort_declaration(
      sprintf("`gap_contract` must be NULL or \"strict_window\"%s.", label)
    )
  }
  if (!is.null(history_class) &&
      (!is.character(history_class) || length(history_class) != 1L ||
       is.na(history_class) ||
       !history_class %in% ledgr_indicator_history_classes())) {
    ledgr_indicator_abort_declaration(
      sprintf(
        "`history_class` must be NULL, \"bounded\" or \"history_dependent\"%s.",
        label
      )
    )
  }
  if (identical(gap_contract, "strict_window") &&
      identical(history_class, "history_dependent")) {
    ledgr_indicator_abort_declaration(
      sprintf(
        paste0(
          "`gap_contract = \"strict_window\"` declares a bounded window and ",
          "contradicts `history_class = \"history_dependent\"`%s."
        ),
        label
      ),
      contradiction = TRUE
    )
  }
  declared_class <- !is.null(history_class) || !is.null(gap_contract)
  if (is.null(history_class)) {
    history_class <- if (identical(gap_contract, "strict_window")) {
      "bounded"
    } else {
      "history_dependent"
    }
  }
  if (is.null(history_source)) {
    history_source <- if (declared_class) "declared" else "default"
  }
  if (is.null(required_fields)) {
    required_fields <- ledgr_indicator_default_required_fields()
    if (is.null(required_fields_source)) required_fields_source <- "default"
  } else if (is.null(required_fields_source)) {
    required_fields_source <- "declared"
  }
  required_fields <- ledgr_indicator_normalize_required_fields(required_fields, id)
  if (is.null(tolerance)) tolerance <- 0
  if (!is.numeric(tolerance) || length(tolerance) != 1L || is.na(tolerance) ||
      !is.finite(tolerance) || tolerance < 0) {
    ledgr_indicator_abort_declaration(
      sprintf("`tolerance` must be NULL or one finite number >= 0%s.", label)
    )
  }
  tolerance <- as.numeric(tolerance)
  if (tolerance > 0 &&
      (!identical(history_class, "bounded") || !isTRUE(has_series_fn))) {
    ledgr_indicator_abort_declaration(
      sprintf(
        paste0(
          "A nonzero `tolerance` applies only to a bounded definition that ",
          "supplies `series_fn`%s."
        ),
        label
      ),
      contradiction = TRUE
    )
  }
  # `input_carry = "excluded"` marks a return or volatility definition: it
  # never consumes a policy-carried price. Undeclared definitions consume the
  # policy-treated input, and that default is disclosed.
  if (is.null(input_carry)) {
    input_carry <- "eligible"
    if (is.null(input_carry_source)) input_carry_source <- "default"
  } else if (is.null(input_carry_source)) {
    input_carry_source <- "declared"
  }
  if (!is.character(input_carry) || length(input_carry) != 1L ||
      is.na(input_carry) || !input_carry %in% c("eligible", "excluded")) {
    ledgr_indicator_abort_declaration(
      sprintf("`input_carry` must be NULL, \"eligible\" or \"excluded\"%s.", label)
    )
  }
  list(
    history_class = history_class,
    history_source = history_source,
    gap_contract = if (identical(history_class, "bounded")) "strict_window" else NULL,
    gap_behavior = if (identical(history_class, "bounded")) {
      "strict_window"
    } else {
      "segment_restart"
    },
    required_fields = required_fields,
    required_fields_source = required_fields_source,
    tolerance = tolerance,
    input_carry = input_carry,
    input_carry_source = input_carry_source
  )
}

# Declarations for an indicator object or a feature definition list. Legacy
# definition lists without declarations follow the custom rules.
ledgr_feature_def_declarations <- function(def) {
  ledgr_indicator_declare(
    history_class = def$history_class,
    gap_contract = def$gap_contract,
    required_fields = def$required_fields,
    tolerance = def$tolerance,
    input_carry = def$input_carry,
    # A stored config definition carries no functions; its tolerance was
    # validated against `series_fn` when the indicator was constructed.
    has_series_fn = if (is.function(def$fn)) is.function(def$series_fn) else TRUE,
    id = def$id,
    history_source = def$history_source,
    required_fields_source = def$required_fields_source,
    input_carry_source = def$input_carry_source
  )
}

ledgr_indicator_apply_declarations <- function(indicator, declarations) {
  indicator$history_class <- declarations$history_class
  indicator$history_source <- declarations$history_source
  indicator["gap_contract"] <- list(declarations$gap_contract)
  indicator$required_fields <- declarations$required_fields
  indicator$required_fields_source <- declarations$required_fields_source
  indicator$tolerance <- declarations$tolerance
  indicator$input_carry <- declarations$input_carry
  indicator$input_carry_source <- declarations$input_carry_source
  indicator
}

# Package catalogue rows. The certification of every row is a registered
# package test on fixed hostile fixtures (LTB-0297); no row carries a runtime
# product tolerance. `input_carry = "excluded"` marks the return and
# volatility families: definitions whose value depends on session-to-session
# price changes or on price dispersion never consume policy-carried prices.
ledgr_indicator_history_catalogue <- function() {
  row <- function(source, family, output, variant, history_class,
                  required, input_carry, width) {
    data.frame(
      source = source,
      family = family,
      output = output,
      variant = variant,
      history_class = history_class,
      required_fields = required,
      input_carry = input_carry,
      width = width,
      stringsAsFactors = FALSE
    )
  }
  close <- "close"
  hl <- "high,low"
  hlc <- "high,low,close"
  hlcv <- "high,low,close,volume"
  rows <- list(
    row("ledgr", "sma", "value", "default", "bounded", close, "eligible", "n"),
    row("ledgr", "ema", "value", "default", "bounded", close, "eligible", "n + 1"),
    row("ledgr", "rsi", "value", "default", "bounded", close, "excluded", "n + 1"),
    row("ledgr", "returns", "value", "default", "bounded", close, "excluded", "n + 1"),
    row("TTR", "RSI", "value", "default", "history_dependent", close, "excluded", "n + 1"),
    row("TTR", "RSI", "value", "maType=SMA", "bounded", close, "excluded", "n + 1"),
    row("TTR", "SMA", "value", "default", "bounded", close, "eligible", "n"),
    row("TTR", "EMA", "value", "default", "history_dependent", close, "eligible", "n"),
    row("TTR", "EMA", "value", "wilder=TRUE", "history_dependent", close, "eligible", "n")
  )
  for (output in c("tr", "trueHigh", "trueLow")) {
    rows[[length(rows) + 1L]] <- row("TTR", "ATR", output, "default", "bounded", hlc, "excluded", "n + 1")
    rows[[length(rows) + 1L]] <- row("TTR", "ATR", output, "maType=SMA", "bounded", hlc, "excluded", "n + 1")
  }
  rows[[length(rows) + 1L]] <- row("TTR", "ATR", "atr", "default", "history_dependent", hlc, "excluded", "n + 1")
  rows[[length(rows) + 1L]] <- row("TTR", "ATR", "atr", "maType=SMA", "bounded", hlc, "excluded", "n + 1")
  for (output in c("macd", "signal", "histogram")) {
    rows[[length(rows) + 1L]] <- row("TTR", "MACD", output, "default", "history_dependent", close, "eligible", "nSlow + nSig - 1")
    rows[[length(rows) + 1L]] <- row("TTR", "MACD", output, "maType=SMA", "bounded", close, "eligible", "nSlow + nSig - 1")
  }
  rows <- c(rows, list(
    row("TTR", "WMA", "value", "default", "bounded", close, "eligible", "n"),
    row("TTR", "ROC", "value", "default", "bounded", close, "excluded", "n + 1"),
    row("TTR", "momentum", "value", "default", "bounded", close, "excluded", "n + 1"),
    row("TTR", "CCI", "value", "default", "bounded", hlc, "excluded", "n"),
    row("TTR", "CCI", "value", "maType=EMA", "history_dependent", hlc, "excluded", "n")
  ))
  for (output in c("dn", "mavg", "up", "pctB")) {
    carry <- if (identical(output, "mavg")) "eligible" else "excluded"
    rows[[length(rows) + 1L]] <- row("TTR", "BBands", output, "default", "bounded", close, carry, "n")
    rows[[length(rows) + 1L]] <- row("TTR", "BBands", output, "maType=EMA", "history_dependent", close, carry, "n")
  }
  for (output in c("aroonUp", "aroonDn", "oscillator")) {
    rows[[length(rows) + 1L]] <- row("TTR", "aroon", output, "default", "bounded", hl, "eligible", "n + 1")
  }
  for (output in c("high", "mid", "low")) {
    rows[[length(rows) + 1L]] <- row("TTR", "DonchianChannel", output, "default", "bounded", hl, "eligible", "n")
  }
  rows <- c(rows, list(
    row("TTR", "MFI", "value", "default", "bounded", hlcv, "excluded", "n + 1"),
    row("TTR", "CMF", "value", "default", "bounded", hlcv, "eligible", "n"),
    row("TTR", "runMean", "value", "default", "bounded", close, "eligible", "n"),
    row("TTR", "runSD", "value", "default", "bounded", close, "excluded", "n"),
    row("TTR", "runVar", "value", "default", "bounded", close, "excluded", "n"),
    row("TTR", "runMAD", "value", "default", "bounded", close, "excluded", "n")
  ))
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

ledgr_indicator_catalogue_row <- function(source, family, output = "value", variant = "default") {
  catalogue <- ledgr_indicator_history_catalogue()
  hit <- catalogue$source == source & catalogue$family == family &
    catalogue$output == output & catalogue$variant == variant
  if (sum(hit) != 1L) return(NULL)
  catalogue[hit, , drop = FALSE]
}

ledgr_indicator_catalogue_declarations <- function(row) {
  list(
    history_class = row$history_class[[1L]],
    required_fields = strsplit(row$required_fields[[1L]], ",", fixed = TRUE)[[1L]],
    input_carry = row$input_carry[[1L]]
  )
}

ledgr_indicator_apply_catalogue <- function(indicator, row) {
  declared <- ledgr_indicator_catalogue_declarations(row)
  declarations <- ledgr_indicator_declare(
    history_class = declared$history_class,
    required_fields = declared$required_fields,
    input_carry = declared$input_carry,
    has_series_fn = is.function(indicator$series_fn),
    id = indicator$id,
    history_source = "catalogue",
    required_fields_source = "catalogue",
    input_carry_source = "catalogue"
  )
  ledgr_indicator_apply_declarations(indicator, declarations)
}

# Required-field admission over treated inputs. `fields` is a named list of
# aligned numeric vectors; only the declared required fields are tested, and
# the evidence names every required field that blocks a calculation.
ledgr_history_required_field_admission <- function(fields, required_fields) {
  required_fields <- ledgr_indicator_normalize_required_fields(required_fields)
  missing_fields <- setdiff(required_fields, names(fields))
  if (length(missing_fields) > 0L) {
    rlang::abort(
      sprintf(
        "Required bar field(s) are absent from the history input: %s.",
        paste(missing_fields, collapse = ", ")
      ),
      class = c("ledgr_invalid_feature_input", "ledgr_invalid_args")
    )
  }
  n <- length(fields[[required_fields[[1L]]]])
  blocking <- rep("", n)
  available <- rep(TRUE, n)
  for (field in required_fields) {
    value <- as.numeric(fields[[field]])
    if (length(value) != n) {
      rlang::abort(
        "Required bar fields must align on one history axis.",
        class = c("ledgr_invalid_feature_input", "ledgr_invalid_args")
      )
    }
    blocked <- !is.finite(value)
    available <- available & !blocked
    blocking[blocked] <- ifelse(
      nzchar(blocking[blocked]),
      paste(blocking[blocked], field, sep = ","),
      field
    )
  }
  list(available = available, blocking_field = blocking)
}
