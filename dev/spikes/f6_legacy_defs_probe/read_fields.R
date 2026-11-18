# F6 probe: every field a run reads from the rebuilt definition outside
# certification, old list against the modern built-in definition.
tree <- commandArgs(TRUE)[1]; if (is.na(tree)) tree <- "."
pkgload::load_all(tree, quiet = TRUE)
ns <- asNamespace("ledgr")
cmp <- function(label, old, new) {
  od <- ns$ledgr_feature_def_declarations(old)
  nd <- ns$ledgr_feature_def_declarations(new)
  cat(sprintf("%s: declarations identical %s; width old %s new %s; requires_bars %s/%s stable_after %s/%s\n",
    label, identical(od, nd), ns$ledgr_history_feature_width(old), ns$ledgr_history_feature_width(new),
    old$requires_bars, new$requires_bars, old$stable_after, new$stable_after))
  if (!identical(od, nd)) { str(od); str(nd) }
  cat("  fields only in old:", paste(setdiff(names(old), names(new)), collapse = ","),
      "| only in new:", paste(setdiff(names(new), names(old)), collapse = ","), "\n")
}
for (w in c(3L, 20L)) {
  ind <- ledgr_ind_sma(w)
  stored <- list(id = ind$id, fingerprint = ns$ledgr_indicator_fingerprint(ind))
  old <- ns$ledgr_feature_sma_n(w); old$fingerprint <- stored$fingerprint
  cmp(ind$id, old, ns$ledgr_precompute_feature_def_from_indicator(ind))
}
ind <- ledgr_ind_returns(1L)
old <- ns$ledgr_feature_return_1(); old$fingerprint <- ns$ledgr_indicator_fingerprint(ind)
cmp("return_1", old, ns$ledgr_precompute_feature_def_from_indicator(ind))
