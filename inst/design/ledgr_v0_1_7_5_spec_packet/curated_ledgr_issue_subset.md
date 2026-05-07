# Curated ledgr Issue Subset From v0.1.7.4 First Run

Source run: `episodes_v0.1.7.4`

This is a maintainer-curated handoff subset. It intentionally excludes auditr
runner friction, Windows shell quoting, parser/categorizer noise, and positive
confirmation rows from the generated reports.

## Scope Notes

- Treat the generated `ledgr_triage_report.md` as advisory evidence only.
- Verify each candidate against raw episode artifacts before implementation.
- The first run still contains auditr-originated noise, especially missing
  `source_docs`, broad categorizer themes, and Windows runner friction.

## LEDGR-UX-001: MACD `output = "macd"` warmup contract may be too short

Evidence:

- Episode: `2026-05-06_006_bbands_macd`
- File: `episodes_v0.1.7.4/2026-05-06_006_bbands_macd/framework_feedback.md`
- Observed failure: `Error in EMA(...): not enough non-NA values`
- Documented/inferred contract: `requires_bars = 26` for
  `ttr_macd_12_26_9_false_macd`
- Workaround: manually set `requires_bars = 34`

Why this looks like a ledgr issue:

The agent reports that direct `TTR::MACD()` produced the expected `macd` output,
but ledgr's adapter path failed with the documented warmup. The likely contract
mismatch is that TTR computes the signal EMA internally even when only the
`macd` output is requested.

Recommended action:

Create an isolated regression test for `ledgr_ind_ttr(TTR::MACD, output =
"macd")` on a dataset around the `nSlow`/`nSlow + nSig - 1` boundary. Either fix
the inferred warmup or document/validate the larger required history.

## LEDGR-UX-002: Zero-trade runs need a warmup/sample-size diagnostic

Evidence:

- Episode: `2026-05-06_009_edge_case_ten_bars`
- File: `episodes_v0.1.7.4/2026-05-06_009_edge_case_ten_bars/framework_feedback.md`
- Scenario: `ledgr_ind_sma(20)` registered against a 10-bar snapshot
- Result: run completed with zero trades and no diagnostic connecting the
  outcome to impossible warmup

Why this looks like a ledgr UX issue:

The behavior may be technically valid, but a first-time user can easily mistake
the result for a strategy outcome rather than a feature contract mismatch.

Recommended action:

When all values for a registered feature are warmup `NA` for an instrument, add
a run diagnostic or summary note such as: `feature sma_20 requires 20 bars but
only 10 bars were available for SYNTH_01; strategy may never receive a finite
value`.

## LEDGR-UX-003: Result inspection docs should distinguish fills, trades, ledger, and metrics

Evidence:

- Episodes: `2026-05-06_013_trades_fills_and_metrics`,
  `2026-05-06_018_manual_vs_helper_parity`
- Files:
  - `episodes_v0.1.7.4/2026-05-06_013_trades_fills_and_metrics/framework_feedback.md`
  - `episodes_v0.1.7.4/2026-05-06_018_manual_vs_helper_parity/framework_feedback.md`

Observed friction:

- `ledgr_results(..., what = "trades")` can be empty for examples that do not
  close a position.
- `ledgr_results(..., what = "metrics")` is a plausible but unsupported path.
- Annualization matching depends on documented cadence assumptions, but the
  detected cadence is not directly exposed in the raw result accessor.

Recommended action:

Add a compact result-inspection example that opens and closes a position, then
shows `equity`, `fills`, `trades`, `ledger`, `summary(bt)`, and metric
interpretation side by side. Cross-link this from `ledgr_results()`,
`summary.ledgr_backtest`, `ledgr_compare_runs()`, and the metrics article.

## LEDGR-UX-004: Strategy helper and feature-map discovery should be more direct

Evidence:

- Episodes: `2026-05-06_011_strategy_helper_introduction`,
  `2026-05-06_018_manual_vs_helper_parity`,
  `2026-05-06_023_feature_map_strategy_authoring`,
  `2026-05-06_024_pulse_inspection_views`
- Files:
  - `episodes_v0.1.7.4/2026-05-06_011_strategy_helper_introduction/framework_feedback.md`
  - `episodes_v0.1.7.4/2026-05-06_018_manual_vs_helper_parity/framework_feedback.md`
  - `episodes_v0.1.7.4/2026-05-06_023_feature_map_strategy_authoring/framework_feedback.md`
  - `episodes_v0.1.7.4/2026-05-06_024_pulse_inspection_views/framework_feedback.md`

Observed friction:

- The core helper topics are discoverable eventually, but first-time users need
  a clearer path to `signal_return`, `select_top_n`, `weight_equal`,
  `target_rebalance`, `ledgr_feature_map`, `passed_warmup`,
  `ledgr_feature_contracts`, `ledgr_pulse_features`, and `ledgr_pulse_wide`.
- `ctx$features()` is discoverable from articles but lacks a direct help topic.

Recommended action:

Improve help-page cross-links and examples around strategy-helper pipelines and
feature maps. Add a tiny `ctx$features()` strategy snippet to the most relevant
feature-map or warmup help page, or add an explicit context-method reference
page if that fits ledgr documentation conventions.

## LEDGR-UX-005: Low-level CSV snapshot workflow needs a full bridge example

Evidence:

- Episode: `2026-05-06_025_low_level_csv_snapshot_seal_run`
- File: `episodes_v0.1.7.4/2026-05-06_025_low_level_csv_snapshot_seal_run/framework_feedback.md`

Observed friction:

The low-level CSV path works, but the docs require stitching together separate
help pages:

`ledgr_snapshot_create()` -> `ledgr_snapshot_import_bars_csv()` ->
`ledgr_snapshot_seal()` -> `ledgr_snapshot_load()` -> `ledgr_experiment()` ->
`ledgr_run()`.

The agent also had to infer that metadata such as start/end dates lives in
`meta_json`, and that a sealed DBI snapshot hash must be bridged back to a
`ledgr_snapshot` object with `ledgr_snapshot_load()`.

Recommended action:

Add one end-to-end low-level CSV example that seals, reloads/verifies, inspects
metadata via `ledgr_snapshot_info()`, parses `meta_json`, and runs a backtest
or experiment from the loaded snapshot.

## AUDITR Noise Explicitly Excluded

- PowerShell quoting, `$` escaping, UTF-8 BOMs, locked logs, and stderr wrapping.
- `DOC_DISCOVERY.R` task-intent map omissions.
- `ledgr_save_help()` output filename confusion.
- Feedback parser/categorizer source attribution and broad theme grouping.
- Positive confirmation rows such as "bugs observed: none".
