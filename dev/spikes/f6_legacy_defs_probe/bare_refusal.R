# F6 probe: the bare old list against the built-in on the reviewer fixture.
# Does the built-in ledgr_ind_sma(3) pass the causality check where the bare
# old ledgr_feature_sma_n(3), with no fingerprint, refuses?
tree <- commandArgs(TRUE)[1]; if (is.na(tree)) tree <- "."
pkgload::load_all(tree, quiet = TRUE)
ns <- asNamespace("ledgr")
source(file.path(tree, "dev/feature_parity/corpus.R"))
sub <- fx_empty(ledgr_history_policy())
try_def <- function(label, def) {
  r <- tryCatch({ ns$ledgr_history_compute_feature_series(sub, list(def)); "success" },
    error = function(e) paste(class(e)[1], "-", conditionMessage(e)))
  cat(label, ":", substr(r, 1, 220), "\n")
}
for (w in c(3L, 5L, 20L)) {
  try_def(sprintf("legacy ledgr_feature_sma_n(%d)", w), ns$ledgr_feature_sma_n(w))
  try_def(sprintf("built-in ledgr_ind_sma(%d)   ", w), ns$ledgr_precompute_feature_def_from_indicator(ledgr_ind_sma(w)))
}
try_def("legacy ledgr_feature_return_1()", ns$ledgr_feature_return_1())
try_def("built-in ledgr_ind_returns(1)  ", ns$ledgr_precompute_feature_def_from_indicator(ledgr_ind_returns(1L)))
