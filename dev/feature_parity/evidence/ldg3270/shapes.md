# LDG-3270: the seven optimization shapes over Cut 25's changed code

The changed production code is `ledgr_utc()`'s character branch with its new
helper `ledgr_utc_parse_character()` (R/timestamp.R) and three removed lines
in `ledgr_normalize_feature_series_output()` (R/features-engine.R). Shapes
from `inst/design/manual/optimization_coding_style.qmd`, The Seven Shapes
And Their Replacements:

1. One-row frame per element, bound at the end: none; neither function
   builds a data frame.
2. Full-table subset inside a loop over ids: none.
3. Per-element parsing or formatting where a vectorised call exists:
   removed. The old character branch ran `vapply()` over a closure that
   called `grepl()`, `ledgr_iso_utc()` and `as.POSIXct()` per string; the
   new one classifies, parses and formats each subset with one vectorised
   call each (500 strings 67 to 7 ms, `results/final/utc_timing.csv`).
   `ledgr_utc()` stays off every per-pulse, per-fill and per-event path.
4. Per-row JSON on repetitive strings: none.
5. Work computed and discarded, or recomputed on every call: none added; the
   normaliser does one vector test less per series.
6. Quadratic validators: none.
7. Scalar writes into an environment-held vector: none.

No loop over a collection that grows with bars, rows, instruments, events
or candidates is added.
