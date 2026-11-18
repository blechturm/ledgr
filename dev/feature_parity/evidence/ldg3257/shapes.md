# LDG-3257: the seven optimization shapes on the changed code

Walked against inst/design/manual/optimization_coding_style.qmd, "The Seven
Shapes And Their Replacements". Changed production code (R/ at 68b505b9
against 6d12ef79): one branch of `ledgr_feature_defs_from_config()`
(R/backtest-runner.R) and three deleted functions in R/features-engine.R. The
rebuild runs once per committed run, promotion or walk-forward test run,
before the fold, over the stored feature definitions: a collection that grows
with features, not with bars, fact rows, instruments x pulses, events,
diagnostics or candidates.

1. One-row frame per element, bound at the end: none. The branch builds no
   data frame.
2. Full-table subset inside a loop over ids: none. The existing loop over
   stored definitions subsets nothing.
3. Per-element parsing or formatting where a vectorised call exists: the
   existing `sub("^sma_", "", id)` and `as.integer()` per definition stay;
   they run once per definition per run, outside every per-pulse path.
4. Per-row JSON on repetitive strings: none added; the deleted
   `ledgr_validate_feature_def()` encoded canonical JSON per definition and is
   gone.
5. Work computed and discarded, or recomputed on every call: reduced. The
   built-in is now constructed once per entry and reused for the shadow
   comparison and the conversion; before, the shadow test constructed it and
   the old list was then built separately and discarded at certification.
6. Quadratic validators: none.
7. Scalar writes into an environment-held vector: none.

Helper criterion: no new helper; three functions without a product caller are
deleted. No new loop needs a stated reason. No timing record (Cut 23
decision 6).
