# Cut 24 stage 2 (LDG-3259): the certification witnesses. Every package
# catalogue row and the hostile definitions of synthesis rules 3 and 12, as
# feature definitions; cut24_certification_outcomes() records what
# ledgr_feature_certify() makes of each (certification, kind, canonical
# fingerprints and declarations, or the refusal class and message). The
# expected outcomes were recorded on the cut base ea580bc6
# (dev/feature_parity/certification_outcomes.R) in
# fixtures/cut24-certification-outcomes.csv. Shared by that recorder and
# test-feature-adapters.R; reads only the loaded ledgr namespace.

cut24_ns <- function() asNamespace("ledgr")

cut24_def <- function(x) cut24_ns()$ledgr_precompute_feature_def_from_indicator(x)

# One definition per catalogue row, keyed by its row.
cut24_catalogue_witnesses <- function() {
  ns <- cut24_ns()
  rows <- ns$ledgr_indicator_history_catalogue()
  rules <- ledgr::ledgr_ind_ttr_warmup_rules()
  builtin <- list(sma = ledgr::ledgr_ind_sma, ema = ledgr::ledgr_ind_ema,
                  rsi = ledgr::ledgr_ind_rsi, returns = ledgr::ledgr_ind_returns)
  out <- lapply(seq_len(nrow(rows)), function(r) {
    row <- rows[r, ]
    if (row$source == "ledgr") return(cut24_def(builtin[[row$family]](3L)))
    args <- if (row$family == "MACD") list(nFast = 2L, nSlow = 3L, nSig = 2L) else list(n = 3L)
    if (row$variant != "default") {
      kv <- strsplit(row$variant, "=", fixed = TRUE)[[1L]]
      args[[kv[[1L]]]] <- if (kv[[2L]] %in% c("TRUE", "FALSE")) as.logical(kv[[2L]]) else kv[[2L]]
    }
    output <- if (row$output == "value") NULL else row$output
    cut24_def(do.call(ledgr::ledgr_ind_ttr, c(list(row$family, input = rules$input[match(row$family, rules$ttr_fn)],
                                                   output = output), args)))
  })
  names(out) <- paste("row", rows$source, rows$family, rows$output, rows$variant, sep = ":")
  out
}

# ledgr_ind_ttr() with its synthetic output validation suppressed: builds a
# definition the public constructor refuses (synthesis rule 3's hostile
# domain witnesses).
cut24_unvalidated_ttr <- function(...) {
  ns <- cut24_ns()
  f <- ns$ledgr_ind_ttr
  environment(f) <- list2env(list(ledgr_ttr_validate_output_contract = function(...) invisible(NULL)), parent = ns)
  cut24_def(f(...))
}

cut24_hostile_witnesses <- function() {
  ns <- cut24_ns()
  sma3 <- function() cut24_def(ledgr::ledgr_ind_sma(3L))
  list(
    wrong_width = { d <- sma3(); d$params$n <- 5L; d },
    edited_id = { d <- sma3(); d$id <- "renamed_sma"; d },
    copied_functions = cut24_def(ledgr::ledgr_indicator(
      "copy_sma", fn = ledgr::ledgr_ind_sma(3L)$fn, series_fn = ledgr::ledgr_ind_sma(3L)$series_fn,
      requires_bars = 3L, params = list(n = 3L))),
    forged_functions = {
      d <- sma3()
      d$fn <- function(window) stop("forged fn must not run")
      d$series_fn <- function(bars, params) stop("forged series_fn must not run")
      d
    },
    # RSI3's identity under the SMA's ID: the claim matches the RSI candidate,
    # whose catalogue carry family contradicts the SMA's declaration.
    sma3_rsi3_claim = {
      d <- sma3()
      rsi <- ledgr::ledgr_ind_rsi(3L)
      rsi$id <- d$id
      d$fingerprint <- cut24_def(rsi)$fingerprint
      d
    },
    # RSI3's identity under its own ID: matches no candidate of this ID.
    sma3_rsi3_claim_other_id = { d <- sma3(); d$fingerprint <- cut24_def(ledgr::ledgr_ind_rsi(3L))$fingerprint; d },
    carry_contradiction = { d <- cut24_def(ledgr::ledgr_ind_ttr("SMA", input = "close", n = 3L)); d$input_carry <- "excluded"; d },
    unregistered_argument = cut24_def(ledgr::ledgr_ind_ttr("SMA", input = "close", n = 3L, requires_bars = 5L,
                                                           id = "ttr_sma_unregistered")),
    unregistered_output = cut24_def(ledgr::ledgr_ind_ttr("ATR", input = "hlc", output = "atr", n = 3L, maType = "EMA")),
    roc_invalid_type = cut24_unvalidated_ttr("ROC", input = "close", n = 3L, type = "invalid"),
    macd_100_3_2 = cut24_unvalidated_ttr("MACD", input = "close", output = "macd", nFast = 100L, nSlow = 3L, nSig = 2L),
    sma_max = cut24_def(ledgr::ledgr_ind_sma(.Machine$integer.max)),
    sma3_renamed_max = { d <- sma3(); d$id <- "sma_2147483647"; d },
    sma3_renamed_0 = { d <- sma3(); d$id <- "sma_0"; d },
    runsd_1 = cut24_def(ledgr::ledgr_ind_ttr("runSD", input = "close", n = 1L))
  )
}

cut24_certification_witnesses <- function() {
  c(cut24_catalogue_witnesses(), cut24_hostile_witnesses())
}

# One row per witness: the certification outcome, or the refusal.
cut24_certification_outcomes <- function(witnesses = cut24_certification_witnesses()) {
  ns <- cut24_ns()
  sha <- function(x) digest::digest(x, algo = "sha256")
  rows <- lapply(names(witnesses), function(k) {
    cert <- tryCatch(suppressWarnings(ns$ledgr_feature_certify(witnesses[[k]])), error = function(e) e)
    if (inherits(cert, "error")) {
      return(data.frame(witness = k, outcome = "refused", certification = NA_character_, kind = NA_character_,
                        fingerprint = NA_character_, active_fingerprint = NA_character_, declarations = NA_character_,
                        refusal_class = class(cert)[[1L]], refusal_message = conditionMessage(cert),
                        stringsAsFactors = FALSE))
    }
    data.frame(witness = k, outcome = "certified", certification = cert$certification,
               kind = if (is.null(cert$kind)) NA_character_ else cert$kind,
               fingerprint = ns$ledgr_feature_def_fingerprint(cert$def),
               active_fingerprint = ns$ledgr_active_feature_fingerprint(cert$def),
               declarations = sha(cert$declarations), refusal_class = NA_character_, refusal_message = NA_character_,
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}
