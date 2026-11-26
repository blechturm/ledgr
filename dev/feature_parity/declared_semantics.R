# Cut 25 (LDG-3269, cut review 25 R3): verifies the declared cases' values
# independently of candidate output, before declared_expected.csv is written.
# The maintainer's decision (2026-11-04) is that series_fn output follows the
# fn path, which already accepts post-warmup NA on the pin. So each declared
# case is computed twice:
#   --arm=pin_fn_twin: on the pin library, every definition of the case's set
#     replaced by an fn-only twin with the same id, width and required fields
#     (runSD with n = 1 and custom_na: NA at every cell; custom_volume_strict:
#     the window's last volume);
#   --arm=candidate: on the candidate library with the corpus definitions.
# --compare requires the two value lists identical per case, and prints how
# many cells are NA and finite, so the check is not vacuous.
#
#   Rscript declared_semantics.R --arm=<pin_fn_twin|candidate> --lib=<library> --out=<dir>
#   Rscript declared_semantics.R --compare --out=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    h <- grep(paste0("^--", name, "(=|$)"), argv, value = TRUE)
    if (!length(h)) return(NULL)
    if (!grepl("=", h[[1L]], fixed = TRUE)) return(TRUE)
    sub(paste0("^--", name, "="), "", h[[1L]])
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  out <- arg("out")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  if (isTRUE(arg("compare"))) {
    a <- readRDS(file.path(out, "pin_fn_twin.rds"))
    b <- readRDS(file.path(out, "candidate.rds"))
    stopifnot(identical(names(a), names(b)), length(a) == 52L)
    same <- vapply(names(a), function(k) identical(a[[k]], b[[k]]), logical(1))
    cells <- unlist(lapply(b, function(v) unlist(lapply(v, as.vector))))
    set <- sub("^.*[|]", "", names(b))
    for (s in sort(unique(set))) {
      v <- unlist(lapply(b[set == s], function(x) unlist(lapply(x, as.vector))))
      cat(sprintf("%-22s cases %2d  cells %4d  NA %4d  finite %4d\n", s, sum(set == s), length(v), sum(is.na(v)), sum(is.finite(v))))
    }
    cat("cases", length(a), "identical", sum(same), "\n")
    if (!all(same)) cat("DIFFERENT:", names(a)[!same], sep = "\n  ")
    # Once declared_expected.csv exists, its values entries must be the
    # digests of the pin's fn-twin values (the runner digests values so).
    file_ok <- TRUE
    declared_file <- file.path(here, "declared_expected.csv")
    if (file.exists(declared_file)) {
      d <- utils::read.csv(declared_file, comment.char = "#", colClasses = "character")
      d <- d[d$component == "values", ]
      want <- d$value[match(names(a), d$case)]
      got <- vapply(a, function(v) digest::digest(v, algo = "sha256"), "")
      file_ok <- identical(unname(got), want)
      cat("declared_expected.csv values equal the pin fn-twin digests:", sum(got == want, na.rm = TRUE), "of", length(a), "\n")
    }
    ok <- all(same) && file_ok
    cat(if (ok) "SEMANTICS PASS\n" else "SEMANTICS FAIL\n")
    quit(save = "no", status = if (ok) 0L else 1L)
  }
  arm <- arg("arm")
  lib <- normalizePath(arg("lib"), winslash = "/")
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  source(file.path(here, "corpus.R"), local = TRUE)
  keys <- utils::read.csv(file.path(here, "declared_cases.csv"), comment.char = "#", stringsAsFactors = FALSE)
  twin <- function(def) {
    id <- def$id
    fn <- if (identical(id, "custom_volume_strict")) {
      function(bars) as.numeric(bars$volume[[nrow(bars)]])
    } else {
      function(bars) NA_real_
    }
    fx_def(ledgr::ledgr_indicator(id, fn = fn, requires_bars = as.integer(def$requires_bars),
                                  stable_after = as.integer(def$stable_after),
                                  required_fields = def$required_fields %||% "close"))
  }
  substrates <- fx_substrates()
  sets <- fx_defs()
  res <- list()
  for (i in seq_len(nrow(keys))) {
    parts <- strsplit(keys$case[[i]], "|", fixed = TRUE)[[1L]]
    sub <- substrates[[parts[[1L]]]]
    n_axis <- length(sub$axis)
    starts <- list(data_start = NULL, late_start = sub$axis[[max(1L, floor(n_axis / 3))]],
                   past_end = sub$axis[[n_axis]] + 86400)
    defs <- sets[[parts[[3L]]]]
    if (identical(arm, "pin_fn_twin")) defs <- lapply(defs, twin)
    names(defs) <- vapply(defs, function(d) d$id, "")
    values <- suppressWarnings(ns$ledgr_history_compute_feature_series(sub, defs, calculation_start = starts[[parts[[2L]]]]))
    attr(values, "ledgr_feature_planes") <- NULL
    res[[keys$case[[i]]]] <- values
  }
  saveRDS(res, file.path(out, paste0(arm, ".rds")))
  cat("arm", arm, "library", lib, "cases", length(res), "\n")
})
