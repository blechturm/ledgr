# F6 probe: the stored-config rebuild of built-in ids

Measured on release/v0.2.3 at 6d12ef79 (R/ as at 39ac4ba4, Cut 22 final).
Each script takes the source tree as its one argument and loads it with
pkgload; outputs are in results/.

    Rscript dev/spikes/f6_legacy_defs_probe/bare_refusal.R .
    Rscript dev/spikes/f6_legacy_defs_probe/run_certification.R .
    Rscript dev/spikes/f6_legacy_defs_probe/read_fields.R .

Question (WS41 close review round 1, F6; maintainer disposition 2026-11-18):
which runs reach the old v0.1.4 list definitions that
`ledgr_feature_defs_from_config()` builds for the ids `sma_<n>` and
`return_1` (`ledgr_feature_sma_n()`, `ledgr_feature_return_1()`), and do
realistic inputs refuse?

Findings:

1. Every run with `ledgr_ind_sma(n)` or `ledgr_ind_returns(1)` rebuilds its
   definition from the old list, with the built-in's stored fingerprint.
2. Certification (`ledgr_feature_certify()`) recognises that fingerprint and
   computes the feature with the built-in constructor's own functions
   (run_certification.txt: `sma_3`, `sma_5` and `return_1` certify as
   `builtin` inside real runs). The old `fn` and `series_fn` never run on
   the run path.
3. The only other read of the rebuilt definition is the history-read width
   (`ledgr_history_feature_width()`): history class, `requires_bars` and
   `stable_after`. They are the same for the old list and the built-in
   (read_fields.txt; the declarations differ in required fields, input
   carry and sources, which only certification reads, and certification
   replaces them).
4. On the reviewer's fixture (dev/feature_parity/corpus.R `fx_empty`), the
   bare old `sma_3` and `sma_5`, with no fingerprint, certify as custom and
   refuse with `ledgr_indicator_gap_parity` (fn and series_fn differ in the
   last bit at tolerance 0); the built-ins pass (bare_refusal.txt). A real
   run on the same bars passes, and the rebuilt definition with its stored
   fingerprint passes preparation on that substrate; without the stored
   fingerprint it refuses (run_certification.txt).

So no stored config written by `ledgr_config()` reaches the old functions.
They are reached only by a stored definition without a fingerprint, which
the package never writes. The old lists are dead code in practice, and the
one residual route runs other code than the built-in it is named after.
