# LDG-3263 gut (synthesis rule 12; Cut 24 LDG-3263 acceptance): the gate's
# full-coverage clause (every calculation column expected and every required
# raw field finite) is removed in this process only, so a cell is admitted
# whenever it is certified, has one knowledge range and no terminal in its
# prefix. Every corpus substrate and certified definition set is prepared:
#   debug on   the debug comparison must refuse (ledgr_feature_debug_mismatch)
#              wherever the gutted gate admits a cell the real gate rejects;
#   debug off  the gutted preparation's result is compared with the real
#              gate's, showing the wrong answers production would return.
# The complete output is written to stdout.
#
#   Rscript gut.R --lib=<installed ledgr library>
local({
  argv <- commandArgs(TRUE)
  lib <- sub("^--lib=", "", grep("^--lib=", argv, value = TRUE)[[1L]])
  suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(lib, winslash = "/")))
  ns <- asNamespace("ledgr")
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  source(file.path(here, "..", "..", "corpus.R"), local = TRUE)
  cat("ledgr", find.package("ledgr"), "engine", substr(ns$ledgr_feature_engine_version(), 1L, 16L), "\n")
  real_gate <- ns$ledgr_history_feature_gate
  gutted_gate <- function(substrate, certified, gated, gate_fields, masks, instrument_idx, calc) {
    admitted <- gated & FALSE
    if (any(masks$terminal_asserted)) return(admitted)
    gated
  }
  set_gate <- function(f) {
    unlockBinding("ledgr_history_feature_gate", ns)
    assign("ledgr_history_feature_gate", f, envir = ns)
    lockBinding("ledgr_history_feature_gate", ns)
  }
  admissions <- function(substrate, defs) {
    certified <- lapply(defs, ns$ledgr_feature_certify)
    gated <- vapply(certified, function(cert) cert$certification %in% c("builtin", "catalogue"), logical(1))
    fields <- unique(unlist(lapply(certified[gated], function(cert) cert$declarations$required_fields)))
    bounds <- ns$ledgr_history_feature_bounds(substrate, NULL, NULL)
    if (bounds$from > bounds$to || !any(gated)) return(c(real = 0L, gutted = 0L))
    n <- c(real = 0L, gutted = 0L)
    for (i in seq_along(substrate$instrument_ids)) {
      ranges <- ns$ledgr_history_feature_ranges(substrate, i, bounds$from, bounds$to)
      if (length(ranges$start) != 1L) next
      masks <- ns$ledgr_history_feature_masks(substrate, i, bounds$to, substrate$axis[[bounds$to]])
      calc <- seq.int(bounds$from, bounds$to)
      n[["real"]] <- n[["real"]] + sum(real_gate(substrate, certified, gated, fields, masks, i, calc))
      n[["gutted"]] <- n[["gutted"]] + sum(gutted_gate(substrate, certified, gated, fields, masks, i, calc))
    }
    n
  }
  outcome <- function(expr) {
    tryCatch({
      v <- suppressWarnings(expr)
      list(kind = "ok", value = v)
    }, error = function(e) list(kind = class(e)[[1L]], message = conditionMessage(e)))
  }
  substrates <- fx_substrates()
  sets <- fx_defs()
  certified_sets <- c("close", "hl", "hlc", "hlcv", "all_cert", "catalogue_rows", "stable_late",
                      "parameterized_single", "parameterized_bundle", "mixed")
  rows <- list()
  for (s in names(substrates)) {
    for (set in certified_sets) {
      defs <- sets[[set]]
      adm <- admissions(substrates[[s]], defs)
      set_gate(real_gate)
      real <- local({ ns$local_ledgr_debug(FALSE); outcome(ns$ledgr_history_compute_feature_series(substrates[[s]], defs)) })
      set_gate(gutted_gate)
      on <- local({ ns$local_ledgr_debug(TRUE); outcome(ns$ledgr_history_compute_feature_series(substrates[[s]], defs)) })
      off <- local({ ns$local_ledgr_debug(FALSE); outcome(ns$ledgr_history_compute_feature_series(substrates[[s]], defs)) })
      set_gate(real_gate)
      wrong <- if (identical(real$kind, "ok") && identical(off$kind, "ok")) {
        if (identical(real$value, off$value)) "same" else "differs"
      } else if (identical(real$kind, off$kind)) "same refusal" else paste("real", real$kind, "/ gutted", off$kind)
      rows[[length(rows) + 1L]] <- data.frame(
        substrate = s, set = set, admitted_real = adm[["real"]], admitted_gutted = adm[["gutted"]],
        debug_on = on$kind, debug_off_vs_real = wrong,
        message = if (is.null(on$message)) "" else substr(on$message, 1L, 120L), stringsAsFactors = FALSE)
    }
  }
  out <- do.call(rbind, rows)
  options(width = 250)
  print(out, row.names = FALSE, right = FALSE)
  extra <- out$admitted_gutted > out$admitted_real
  cat("\ncases where the gutted gate admits more cells:", sum(extra), "\n")
  cat("  of these, debug on refused with ledgr_feature_debug_mismatch:",
      sum(extra & out$debug_on == "ledgr_feature_debug_mismatch"), "\n")
  cat("  of these, debug off returned a different answer from the real gate:",
      sum(extra & out$debug_off_vs_real != "same"), "\n")
  cat("cases with no extra admission (gut cannot act):", sum(!extra),
      "; of these refusing with debug on:", sum(!extra & out$debug_on == "ledgr_feature_debug_mismatch"), "\n")
  ok <- all(out$debug_on[extra] == "ledgr_feature_debug_mismatch") && any(extra)
  cat(if (ok) "GUT PASS: every extra admission is refused by the debug comparison\n" else "GUT FAIL\n")
})
