# Cut 25 (LDG-3269): LTB-0567 stops at its first failure on the base, so this
# runs its series-path expectations one by one on a given ledgr and prints
# each outcome: the series_fn post-warmup NA, TTR runSD with n = 1, the
# all-NA series and the finite/NA/gap carry fixture.
#
#   Rscript na_base_witness.R --tests=<tree> (--lib=<library> | --source=<tree>)
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    h <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(h)) sub(paste0("^--", name, "="), "", h[[1L]]) else NULL
  }
  if (!is.null(arg("lib"))) {
    suppressPackageStartupMessages(library(ledgr, lib.loc = normalizePath(arg("lib"), winslash = "/")))
    cat("ledgr from library", arg("lib"), "\n")
  } else {
    pkgload::load_all(arg("source"), quiet = TRUE, compile = FALSE)
    cat("ledgr from source", arg("source"), "\n")
  }
  sys.source(file.path(arg("tests"), "tests", "testthat", "helper-indicator-history.R"), envir = environment())
  ns <- asNamespace("ledgr")
  show <- function(label, expr) {
    r <- tryCatch(suppressWarnings(expr), error = identity)
    cat(sprintf("%-28s %s\n", label, if (inherits(r, "error")) paste("refused", class(r)[[1L]]) else paste(format(as.numeric(r)), collapse = " ")))
  }
  levels <- ws43_history_substrate(c(100, 101, 102, 103, 104, 105))
  series_na <- ledgr_indicator("probe", fn = function(window) 0, requires_bars = 1L,
    series_fn = function(bars) ifelse(bars$close > 103, NA_real_, bars$close))
  show("series_fn post-warmup NA", ns$ledgr_history_compute_feature_series(levels, list(feature = series_na))[[1L]])
  show("TTR runSD n = 1", ns$ledgr_history_compute_feature_series(levels,
    list(feature = ledgr_ind_ttr("runSD", input = "close", n = 1L)))[[1L]])
  all_na <- ledgr_indicator("all_na", fn = function(window) 0, requires_bars = 1L, gap_contract = "strict_window",
    required_fields = "close", series_fn = function(bars) rep(NA_real_, nrow(bars)))
  show("all-NA series", ns$ledgr_history_compute_feature_series(ws43_history_substrate(10:15), list(feature = all_na))[[1L]])
  gap <- ws43_history_substrate(c(10, 11, 12, 13, NA, 16, 17),
                                policy = ledgr_history_policy(price_carry = NULL, output_carry = 3L))
  carry <- ledgr_indicator("carry", requires_bars = 1L, gap_contract = "strict_window", required_fields = "close",
    fn = function(window) if (utils::tail(window$close, 1L) == 13) NA_real_ else utils::tail(window$close, 1L),
    series_fn = function(bars) ifelse(bars$close == 13, NA_real_, bars$close))
  show("finite/NA/gap carry", ns$ledgr_history_compute_feature_series(gap, list(feature = carry))[[1L]])
})
