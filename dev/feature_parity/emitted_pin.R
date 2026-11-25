# Cut 24 (synthesis rule 13, cut review R4; LDG-3258): the emitted-function
# pin. Before stage 2 refactors anything, the identities of every built-in and
# of concrete, parameterised and bundled TTR forms, as identity.R records them
# (base and declared-session fingerprints, stored declarations, IDs, params,
# and the emitted fn and series_fn bodies, formals and captures), are frozen in
# emitted_pin_expected.csv. The check compares one identity.R record with the
# pin: every value equal, and the population checked independently of both
# files, so a form or component lost from the record and the pin alike still
# fails.
#
# Required population (fixed here, not read from either file): the twelve
# forms identity.R records (the four built-ins sma_20, ema_5, rsi_14,
# returns_5; the concrete TTR forms ttr_rsi, ttr_atr, ttr_atr_sma, ttr_mfi,
# ttr_unreg; the bundled MACD outputs macd, macd_signal, macd_histogram), each
# with fingerprint, active_fingerprint, declarations, id, params and both fn
# and series_fn body, formals and captures; and the parameterised TTR form
# param_ttr_sma_7 with fingerprint and active_fingerprint.
#
#   Rscript emitted_pin.R --record=<identity.R out dir> [--write-expected] [--pin=<csv>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    hit <- grep(paste0("^--", name, "(=|$)"), argv, value = TRUE)
    if (!length(hit)) return(NULL)
    if (!grepl("=", hit[[1L]], fixed = TRUE)) return(TRUE)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  pin_file <- if (is.character(arg("pin"))) arg("pin") else file.path(here, "emitted_pin_expected.csv")
  forms <- c("sma_20", "ema_5", "rsi_14", "returns_5", "ttr_rsi", "ttr_atr", "ttr_atr_sma", "ttr_mfi", "ttr_unreg",
             "macd", "macd_signal", "macd_histogram")
  components <- c("fingerprint", "active_fingerprint", "declarations", "id", "params",
                  paste0(rep(c("fn", "series_fn"), each = 3L), c("_body", "_formals", "_with_captures")))
  required <- c(as.vector(outer(components, forms, paste, sep = ":")),
                "fingerprint:param_ttr_sma_7", "active_fingerprint:param_ttr_sma_7")
  pattern <- paste0("^(", paste(c(components), collapse = "|"), "):")
  rec <- utils::read.csv(file.path(arg("record"), "identities.csv"), stringsAsFactors = FALSE, colClasses = "character")
  rec <- rec[grepl(pattern, rec$name), c("name", "value")]
  bad <- 0L
  report <- function(...) { cat(..., "\n"); bad <<- bad + 1L }
  check_population <- function(x, what) {
    dup <- unique(x$name[duplicated(x$name)])
    if (length(dup)) report("DUPLICATE in", what, ":", paste(dup, collapse = ", "))
    missing <- setdiff(required, x$name)
    extra <- setdiff(x$name, required)
    if (length(missing)) report("MISSING in", what, ":", paste(missing, collapse = ", "))
    if (length(extra)) report("UNEXPECTED in", what, ":", paste(extra, collapse = ", "))
  }
  check_population(rec, "record")
  if (isTRUE(arg("write-expected"))) {
    if (bad) { cat("EMITTED PIN NOT WRITTEN\n"); quit(save = "no", status = 1L) }
    utils::write.csv(rec[match(required, rec$name), ], pin_file, row.names = FALSE)
    cat("emitted pin written:", nrow(rec), "rows to", pin_file, "\n")
    return(invisible())
  }
  pin <- utils::read.csv(pin_file, stringsAsFactors = FALSE, colClasses = "character")
  check_population(pin, "pin")
  both <- intersect(required, intersect(rec$name, pin$name))
  same <- vapply(both, function(n) identical(rec$value[rec$name == n], pin$value[pin$name == n]), logical(1))
  cat(sprintf("emitted identities required: %d, compared: %d, equal: %d\n", length(required), length(both), sum(same)))
  if (!all(same)) report("DIFFER:", paste(both[!same], collapse = ", "))
  if (bad) { cat("EMITTED PIN FAIL\n"); quit(save = "no", status = 1L) }
  cat("EMITTED PIN PASS\n")
})
