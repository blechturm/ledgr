# Cut 24 synthesis rule 4 (LDG-3258): where certification's cost goes on the
# cut base, measured before any refactoring. Descriptive, not a record. For
# the run (TTR SMA 5, 10) and sweep (TTR SMA 3..40) definition sets of
# protocols/cut24-feature-1, median seconds per definition of:
#   certify        ledgr_feature_certify(def), integrated;
#   candidates     ledgr_feature_catalogue_candidates(def): every candidate
#                  constructed (four built-ins per width, then the TTR row);
#   builtin_ctor   the four built-in constructors at the definition's width;
#   ttr_ctor       ledgr_ind_ttr() for the definition's TTR row;
#   ttr_synthetic  ledgr_ttr_validate_output_contract(), the synthetic TTR
#                  call inside ttr_ctor;
#   canonical_def  the candidates constructed and each turned into a definition
#                  with ledgr_precompute_feature_def_from_indicator() over the
#                  candidates (with the definition's ID), as certify does;
#   fingerprints   ledgr_feature_def_fingerprint() and
#                  ledgr_active_feature_fingerprint() of those definitions.
# Each sample repeats the call until it lasts at least 0.25 s; 7 samples.
#
#   Rscript cert_split.R --lib=<cut base library> --out=<csv>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(arg("lib"), winslash = "/")))
  ns <- asNamespace("ledgr")
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  wl <- new.env()
  sys.source(file.path(here, "..", "timing", "protocols", "cut24-feature-1", "workloads.R"), envir = wl)
  time_median <- function(f, reps = 7L) {
    t0 <- proc.time()[["elapsed"]]; f(); first <- proc.time()[["elapsed"]] - t0
    inner <- max(1L, as.integer(ceiling(0.25 / max(first, 0.001))))
    stats::median(vapply(seq_len(reps), function(r) {
      t0 <- proc.time()[["elapsed"]]
      for (k in seq_len(inner)) f()
      (proc.time()[["elapsed"]] - t0) / inner
    }, 0))
  }
  rows <- list()
  for (path in c("run", "sweep")) {
    defs <- wl$cut24_sma_defs(ns, path)
    per <- function(f) mean(vapply(defs, function(d) time_median(function() f(d)), 0))
    candidates_of <- function(d) ns$ledgr_feature_catalogue_candidates(d)
    canonical <- function(d) lapply(candidates_of(d), function(cand) {
      ind <- cand$indicator
      ind$id <- d$id
      ns$ledgr_precompute_feature_def_from_indicator(ind)
    })
    built <- lapply(defs, canonical)
    comp <- c(
      certify = per(function(d) ns$ledgr_feature_certify(d)),
      candidates = per(candidates_of),
      builtin_ctor = per(function(d) {
        n <- as.integer(d$params$args$n)
        list(ledgr::ledgr_ind_sma(n), ledgr::ledgr_ind_ema(n), ledgr::ledgr_ind_rsi(n), ledgr::ledgr_ind_returns(n))
      }),
      ttr_ctor = per(function(d) ledgr::ledgr_ind_ttr(d$params$ttr_fn, input = d$params$input, id = d$id,
                                                     n = as.integer(d$params$args$n))),
      ttr_synthetic = per(function(d) ns$ledgr_ttr_validate_output_contract(d$params, d$requires_bars)),
      canonical_def = per(canonical),
      fingerprints = mean(vapply(seq_along(defs), function(i) time_median(function() lapply(built[[i]], function(x) {
        list(ns$ledgr_feature_def_fingerprint(x), ns$ledgr_active_feature_fingerprint(x))
      })), 0)))
    rows[[path]] <- data.frame(set = path, definitions = length(defs), component = names(comp),
                               seconds_per_definition = unname(comp), share_of_certify = unname(comp / comp[["certify"]]),
                               stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  utils::write.csv(out, arg("out"), row.names = FALSE)
  print(out, row.names = FALSE, digits = 4)
})
