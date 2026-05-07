# ledgr v0.1.7.5 Spec

**Status:** Draft
**Target Version:** v0.1.7.5
**Scope:** TTR adapter hardening, warmup diagnostics, result/CSV/indicator documentation, and contributor-facing adapter positioning
**Inputs:**

- `inst/design/ledgr_v0_1_7_5_spec_packet/curated_ledgr_issue_subset.md`
- `inst/design/ledgr_v0_1_7_5_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_7_5_spec_packet/cycle_retrospective.md`
- `inst/design/contracts.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/ledgr_v0_1_7_4_spec_packet/v0_1_7_4_spec.md`
- Raw auditr episode artifacts referenced by the curated subset

---

## 1. Purpose

v0.1.7.5 is a hardening and discoverability release.

v0.1.7.4 added feature maps, pulse inspection views, and a much stronger
indicator article. The next auditr cycle showed that the package is broadly
usable, but users still hit two kinds of friction:

- a suspected TTR-backed MACD warmup defect;
- documentation and diagnostics that do not yet make common first workflows
  obvious enough.

The release should improve ledgr's adapter confidence and first-contact UX
without changing the core execution model. ledgr remains a deterministic
snapshot-backed backtesting core with adapter boundaries to the R finance
ecosystem. Packages such as `TTR`, `quantmod`, and future indicator or
visualization integrations should plug into ledgr through explicit adapters;
they should not create alternate execution paths.

---

## 1.1 Evidence Classification Baseline

The generated triage report and retrospective are advisory. The curated subset
is the release-scope filter, but each item still needs raw episode verification
inside its implementation ticket.

| Candidate | Baseline classification | v0.1.7.5 handling |
| --- | --- | --- |
| LEDGR-UX-001 / THEME-010 MACD warmup | Suspected ledgr bug, unconfirmed pending parity evidence | Raw evidence: `episodes_v0.1.7.4/2026-05-06_006_bbands_macd/framework_feedback.md`. Deferred to LDG-1502. |
| LEDGR-UX-002 / THEME-003 zero-trade warmup | Expected behavior with weak user-facing diagnostics | Raw evidence: `episodes_v0.1.7.4/2026-05-06_009_edge_case_ten_bars/framework_feedback.md`. Deferred to LDG-1503. |
| LEDGR-UX-003 / THEME-006 result inspection | Documentation mismatch and example coverage gap | Raw evidence: `episodes_v0.1.7.4/2026-05-06_013_trades_fills_and_metrics/framework_feedback.md` and `episodes_v0.1.7.4/2026-05-06_018_manual_vs_helper_parity/framework_feedback.md`. Deferred to LDG-1504. |
| LEDGR-UX-004 / THEME-004 and THEME-005 helper/feature-map discovery | Documentation and discoverability mismatch | Raw evidence: `episodes_v0.1.7.4/2026-05-06_011_strategy_helper_introduction/framework_feedback.md`, `episodes_v0.1.7.4/2026-05-06_018_manual_vs_helper_parity/framework_feedback.md`, `episodes_v0.1.7.4/2026-05-06_023_feature_map_strategy_authoring/framework_feedback.md`, and `episodes_v0.1.7.4/2026-05-06_024_pulse_inspection_views/framework_feedback.md`. Deferred to LDG-1506. |
| LEDGR-UX-005 / THEME-001 low-level CSV workflow | Documentation mismatch over a working low-level path | Raw evidence: `episodes_v0.1.7.4/2026-05-06_025_low_level_csv_snapshot_seal_run/framework_feedback.md`. Deferred to LDG-1505. |
| THEME-008 and THEME-009 auditr friction | Auditr harness, environment, or task-brief issue unless raw evidence proves a ledgr package defect | Evidence source: second-run triage and retrospective. Out of ledgr package scope for v0.1.7.5. |
| `{talib}` adapter opportunity | Future integration opportunity, not a v0.1.7.5 defect | Out of scope for v0.1.7.5 unless promoted through a separate ticket. |

---

## 2. Release Shape

v0.1.7.5 has four coordinated tracks.

### Track A - TTR Adapter Parity And MACD Warmup

Build a table-driven parity test across every TTR indicator supported by
`ledgr_ttr_warmup_rules()` and every documented multi-output column. Use that
matrix to determine whether the reported MACD issue is isolated, version
dependent, or a broader adapter contract problem.

Do not assume the MACD rule is wrong before the parity test proves it. The
current tests and the auditr report disagree about whether
`output = "macd"` first becomes valid at `nSlow` or `nSlow + nSig - 1`; the
release must resolve that contradiction with direct evidence from the installed
TTR version.

### Track B - Warmup And Zero-Trade Diagnostics

Make impossible warmup visible. A run that registers `sma_20` against ten bars
should not leave a first-time user guessing whether the strategy failed, the
feature failed, or the signal simply never fired.

The run and/or summary diagnostics should connect registered feature contracts,
available bars per instrument, all-`NA` feature values, and zero-trade outcomes.

### Track C - Result, CSV, Indicator, And Helper Documentation

Address the documentation themes that appeared in both auditr runs:

- result inspection examples that distinguish fills, trades, ledger, equity,
  and metrics;
- a complete low-level CSV create/import/seal/load/run workflow;
- warmer indicator examples covering crossover, RSI, mixed built-in/TTR, and
  explicit feature IDs;
- strategy-helper and feature-map discoverability, including `ctx$features()`.

### Track D - Release Hygiene And Contributor Positioning

Keep release-gate discipline from v0.1.7.4 and record the adapter posture that
future contributors need to understand: ledgr should integrate with other R
finance packages through narrow adapters while preserving the single canonical
execution path.

---

## 3. Hard Requirements

### R1 - Raw Evidence Comes Before Fixes

Every issue promoted from the auditr packet must be checked against the raw
episode artifact before implementation.

The curated subset is the authoritative scope filter, but it is still evidence,
not proof. The implementation ticket must classify each candidate as:

- confirmed ledgr bug;
- documentation mismatch;
- expected user error with weak messaging;
- auditr harness or task-brief issue;
- no longer reproducible.

### R2 - TTR Parity Covers The Supported Adapter Surface

The TTR parity test must cover every row returned by
`ledgr_ttr_warmup_rules()`:

- `RSI`;
- `SMA`;
- `EMA`;
- `ATR`;
- `MACD`;
- `WMA`;
- `ROC`;
- `momentum`;
- `CCI`;
- `BBands`;
- `aroon`;
- `DonchianChannel`;
- `MFI`;
- `CMF`;
- `runMean`;
- `runSD`;
- `runVar`;
- `runMAD`.

For multi-output functions, the test must cover every documented output that
ledgr claims to support:

- `ATR`: `tr`, `atr`, `trueHigh`, `trueLow`;
- `BBands`: `dn`, `mavg`, `up`, `pctB`;
- `MACD`: `macd`, `signal`, and ledgr-derived `histogram`;
- `aroon`: every named column returned by `TTR::aroon()` for ledgr's supported
  `hl` input;
- `DonchianChannel`: every named column returned by `TTR::DonchianChannel()`
  for ledgr's supported `hl` input.

For each case, compare ledgr's series output to direct TTR output on the same
bars. The test must assert:

- first non-`NA` row from direct TTR output;
- `ledgr_ind_ttr()` inferred `requires_bars`;
- first non-`NA` row from ledgr feature precomputation;
- deterministic feature ID;
- TTR version in failure context or test diagnostics.

### R3 - MACD Warmup Is Decided By Parity Evidence

The MACD investigation must test the boundary around:

```text
nSlow
nSlow + nSig - 1
```

for all relevant combinations:

- `output = "macd"`;
- `output = "signal"`;
- `output = "histogram"`;
- `percent = TRUE`;
- `percent = FALSE`.

If direct TTR output proves that `macd` is not usable until
`nSlow + nSig - 1`, update the warmup rule, docs, examples, rendered vignette
output, and regression tests.

If direct TTR output proves that `macd` is usable at `nSlow`, keep the rule and
identify the path that produced the auditr failure before changing behavior.

### R4 - TTR Short-Sample Behavior Is Stable

For supported TTR indicators, samples shorter than `requires_bars` must not
produce confusing runtime errors in ordinary ledgr feature precomputation. The
expected ordinary precomputation outcome for a supported, validly constructed
TTR indicator is an aligned numeric series with warmup values normalized to
`NA_real_`. If TTR itself cannot compute on a short sample, ledgr should catch
that expected short-sample condition and return the all-warmup prefix rather
than leaking a low-level TTR error.

Construction-time errors are reserved for invalid adapter contracts: unsupported
functions or inputs, missing required arguments, unknown output columns, or
explicitly invalid warmup settings.

The release must include boundary tests around `requires_bars - 1`,
`requires_bars`, and `requires_bars + 1` for the MACD case and representative
single-output and multi-output non-MACD cases.

### R5 - Zero-Trade Warmup Diagnostics Are User-Facing

When a registered feature is all `NA` for an instrument because the instrument
does not have enough usable bars, ledgr must surface a diagnostic that includes:

- feature ID;
- instrument ID;
- required bars or stable-after threshold;
- available bars for that instrument;
- a clear statement that the strategy may never receive a finite value.

The diagnostic may be emitted during run finalization, surfaced through
`summary(bt)`, or exposed through an existing result-inspection path. The ticket
must choose one primary user-facing surface and test it.

The diagnostic must not alter fills, ledger events, equity, metrics, or run
identity.

### R6 - Result Inspection Docs Must Show The Result Lifecycle

The docs must include one compact example that opens and closes a position and
then shows:

- `ledgr_results(bt, what = "equity")`;
- `ledgr_results(bt, what = "fills")`;
- `ledgr_results(bt, what = "trades")`;
- `ledgr_results(bt, what = "ledger")`;
- `summary(bt)`;
- metric interpretation.

The example must explicitly state that:

- fills are executions;
- trades are closed trade rows;
- open-only positions can produce fills without closed trades;
- `ledgr_results(..., what = "metrics")` is not a supported result table;
- summary metrics are computed from equity rows and closed trades.

Cross-link this explanation from `?ledgr_results`,
`?summary.ledgr_backtest`, `?ledgr_compare_runs`, and
`metrics-and-accounting`.

### R7 - Low-Level CSV Workflow Has One Complete Bridge

The low-level CSV workflow must have one complete example:

```text
ledgr_snapshot_create()
-> ledgr_snapshot_import_bars_csv()
-> ledgr_snapshot_seal()
-> ledgr_snapshot_load(verify = TRUE)
-> ledgr_snapshot_info()
-> ledgr_experiment()
-> ledgr_run()
```

The example must make clear that:

- low-level import writes into a created snapshot;
- sealing derives missing basic metadata where supported;
- `meta_json` is snapshot envelope metadata, not part of the artifact hash;
- a sealed DBI snapshot should be bridged back into a `ledgr_snapshot` object
  with `ledgr_snapshot_load()` for the normal experiment path;
- the loaded snapshot remains the object passed to `ledgr_experiment()`.

### R8 - Indicator Docs Teach Common Strategy Shapes

The indicators article and relevant help pages must cover:

- SMA crossover semantics;
- RSI mean-reversion with experiment usage;
- mixed built-in and TTR-backed indicators in one feature map or feature list;
- expected feature IDs for TTR examples, including MACD;
- warmup troubleshooting through `ledgr_feature_contracts()`;
- the difference between feature-map aliases and engine feature IDs.

The article should not become a large strategy tutorial. It should teach the
feature contract and then link to `strategy-development` for strategy authoring.

### R9 - Strategy Helpers And `ctx$features()` Are Directly Discoverable

The following topics must have article links, local examples, or cross-links
that make them discoverable without first reading an entire vignette:

- `signal_return()`;
- `select_top_n()`;
- `weight_equal()`;
- `target_rebalance()`;
- `ledgr_feature_map()`;
- `passed_warmup()`;
- `ledgr_feature_contracts()`;
- `ledgr_pulse_features()`;
- `ledgr_pulse_wide()`;
- `ctx$features()`.

`ctx$features()` may be documented through the most appropriate existing help
page if ledgr does not yet have a context-method reference convention. The
preferred home is `?ledgr_feature_map`, with `?passed_warmup` as the secondary
cross-link. The docs must include a tiny strategy-body snippet showing:

```r
x <- ctx$features(id, features)
if (passed_warmup(x)) {
  ...
}
```

The docs must also state the v0.1.7.4 context naming boundary:
`ctx$feature_table` is the raw long feature table, while
`ctx$features(id, features)` is the mapped accessor function. Users who need to
inspect pulse feature rows should prefer `ledgr_pulse_features(ctx, features)`
over direct table access.

### R10 - Adapter Positioning Is Explicit

User-facing docs should state ledgr's ecosystem posture plainly:

```text
ledgr is a deterministic backtesting core with adapter boundaries to the R
finance ecosystem. Indicator, data, and visualization packages should plug into
ledgr rather than be replaced by it.
```

This belongs in the README or a positioning article and may be repeated in a
shorter form in the indicators article.

### R11 - Release-Gate Debugging Follows The Playbook

Any release-gate fix must follow
`inst/design/release_ci_playbook.md`:

- remote failed logs define the initial scope;
- write a one-sentence hypothesis before editing;
- reproduce narrowly before running broad gates;
- keep release-gate fixes small;
- expected DuckDB constraint probes must clear transaction state;
- stop and request review if the fix expands outside the initially failing
  subsystem.

---

## 4. Track A Scope - TTR Adapter Parity And MACD

### A1 - TTR Case Matrix

Create a table-driven test matrix for supported `ledgr_ind_ttr()` cases.

Acceptance points:

- every `ledgr_ttr_warmup_rules()` row has at least one parity case;
- every documented multi-output column has a parity case;
- generated IDs match documented expectations;
- missing TTR dependency skips cleanly;
- failures print the TTR version and case metadata.

### A2 - Direct TTR Comparison

For each case, compare direct TTR output to ledgr output on deterministic test
bars.

Normalization means:

- building the same ledgr input shape that `ledgr_ttr_build_input()` passes to
  TTR;
- selecting the documented output column by TTR column name;
- coercing matrix, xts, tibble, data-frame, or vector output to an unnamed
  numeric vector aligned to the input bars;
- normalizing warmup `NaN` to `NA_real_`;
- comparing numeric values with a small tolerance after matching `NA` positions.

For ledgr-derived outputs such as MACD `histogram`, the direct comparison target
is the documented derivation applied to direct TTR output. For MACD histogram,
that target is direct `macd - signal`, not a column returned directly by TTR.

Acceptance points:

- selected ledgr output equals selected direct TTR output after normalization;
- ledgr-derived output equals the direct-TTR derivation after normalization;
- first non-`NA` direct TTR row equals inferred `requires_bars`;
- first non-`NA` ledgr precomputed row equals inferred `requires_bars`;
- post-warmup `NA`, `NaN`, or infinite values fail in the existing feature
  validation path.

### A3 - MACD Boundary Regression

Add focused MACD tests around the reported failure.

Acceptance points:

- tests cover `nSlow - 1`, `nSlow`, `nSlow + nSig - 2`, and
  `nSlow + nSig - 1` length samples where meaningful;
- tests cover `percent = TRUE` and `percent = FALSE`;
- tests cover `macd`, `signal`, and `histogram`;
- expected behavior is derived from direct TTR output, not hard-coded from the
  auditr report alone.

### A4 - Rule And Documentation Update

If the parity evidence requires a rule change, update:

- `ledgr_ttr_warmup_rules()`;
- `ledgr_ttr_infer_requires_bars()`;
- `?ledgr_ind_ttr`;
- `?ledgr_ttr_warmup_rules`;
- `indicators.Rmd` and the checked-in rendered `indicators.md` companion;
- tests and expected rendered output.

If the rule does not change, record why the auditr report did not reproduce and
add a regression for the actual failing path if found.

---

## 5. Track B Scope - Warmup And Zero-Trade Diagnostics

### B1 - Available-Bar Accounting

Implement or reuse a helper that can determine available usable bars per
instrument for each registered feature in a completed run.

Acceptance points:

- handles multiple instruments with different sample starts;
- handles built-in, TTR-backed, and custom indicators;
- uses registered feature metadata, not string parsing;
- does not mutate persistent ledgr tables.

### B2 - All-Warmup Diagnostic

Surface a diagnostic when a feature is all warmup `NA` for an instrument.

Preferred user-facing surface: `summary(bt)` should include a compact warmup
diagnostic note because users already reach for summary output when a run
produces no trades. A classed warning during run finalization is acceptable as
an additional surface if it is not noisy for expected short samples.

Acceptance points:

- message includes feature ID, instrument ID, required bars, and available
  bars;
- diagnostic is visible from the selected user-facing surface;
- zero-trade runs remain valid runs;
- warnings or summary notes follow the package's `ledgr_*` condition or object
  class convention where programmatic handling is useful;
- tests cover at least one short-sample impossible-warmup run.

### B3 - Documentation Tie-In

Update the warmup troubleshooting docs to show how to interpret the diagnostic.

Acceptance points:

- docs connect `ledgr_feature_contracts()` to available bars per instrument;
- docs distinguish impossible warmup from early warmup;
- docs state that warmup is per instrument;
- docs preserve the final-bar no-fill distinction from v0.1.7.4.

---

## 6. Track C Scope - Documentation Improvements

### C1 - Result Inspection Lifecycle

Add the result lifecycle example required by R6.

Preferred home: `metrics-and-accounting`, with cross-links from result-related
help pages.

The example should be compact and deterministic. It should show a closed trade
without turning the article into a strategy tutorial.

### C2 - Low-Level CSV Bridge

Add the complete low-level CSV bridge required by R7.

Preferred home: `experiment-store` or the snapshot import help pages. If the
example is too long for a help page, put the full workflow in the vignette and
link all relevant help pages to it.

### C3 - Indicator Strategy Breadth

Extend indicator docs with common shapes from R8.

The article should preserve the v0.1.7.4 teaching model:

```text
feature contract -> pulse-known data -> strategy accessor
```

New examples should make the mental model clearer, not create a catalog of
every possible indicator strategy.

### C4 - Helper And Feature-Map Discovery

Improve direct discovery for helper pipelines and mapped feature access.

Acceptance points:

- helper pages name their warning/error classes where relevant;
- `select_top_n()` documents the empty-selection warning class;
- common helper mistakes have one compact negative example or diagnostic note;
- synthetic multi-asset helper setup is available from either
  `strategy-development` or helper help pages;
- `ctx$features()` is searchable or clearly reachable from help.

### C5 - Starter Path Consolidation

Review first-path navigation from README, package help, and installed articles.

Acceptance points:

- starter docs point to runnable examples;
- non-executable development artifacts, especially `examples/README.md` if it
  remains a placeholder, are not presented as the first path;
- no-browser installed documentation paths remain present for agents and
  headless users.

---

## 7. Track D Scope - Release Hygiene And Contributor Positioning

### D1 - Adapter Posture

Add a concise adapter-positioning statement to user-facing docs.

The statement should be cooperative, not defensive: ledgr is not trying to
replace the R finance ecosystem; it provides a deterministic execution core and
adapters to calculation, data, and visualization packages.

### D2 - Contracts And NEWS

Update:

- `inst/design/contracts.md`;
- `NEWS.md`;
- package help where relevant;
- documentation contract tests;
- `_pkgdown.yml` if new or moved reference links are needed.

Contracts must record any changed TTR warmup behavior and any new diagnostic
surface.

### D3 - Release Playbook

Carry forward the v0.1.7.4 release-gate post-mortem into the playbook.

This is the documentation task that makes R11 durable for future release
cycles.

Acceptance points:

- remote-log-first debugging guardrail is present;
- DuckDB constraint-probe rollback rule is present;
- stop rule for speculative release-gate debugging is present.

---

## 8. Non-Goals

v0.1.7.5 must stay focused:

- no sweep/tune implementation;
- no live/paper trading API;
- no second execution path;
- no changes to fill timing, ledger accounting, or target validation unless a
  confirmed bug requires it;
- no broad rewrite of the indicator system beyond TTR parity and documented
  examples;
- no `{talib}` adapter implementation unless explicitly promoted to a separate
  ticket and release scope;
- no visualization layer;
- no strategy optimizer or machine-learning training-frame API;
- no workaround APIs for auditr harness issues;
- no weakening of Ubuntu, coverage, or release-gate tests to pass CI.

Auditr THEME-008 and THEME-009 are out of ledgr scope unless raw artifacts
reveal a package defect. PowerShell quoting, task brief quality, browser
behavior in the harness, and discovery-helper implementation belong to auditr
or episode design.

---

## 9. Release Gate

The release is not ready until:

- every promoted auditr issue has been verified against raw episode artifacts
  or explicitly classified as advisory;
- the TTR parity matrix covers every supported rules-table entry;
- every documented multi-output TTR column has a parity case;
- MACD warmup behavior is resolved by direct TTR evidence and documented;
- short-sample TTR behavior is tested at boundary lengths;
- zero-trade impossible-warmup diagnostics are implemented, documented, and
  tested;
- result inspection docs include a closed-trade example covering equity, fills,
  trades, ledger, summary, and metric interpretation;
- low-level CSV create/import/seal/load/run has one complete bridge example;
- indicator docs cover SMA crossover, RSI mean-reversion, mixed built-in/TTR
  usage, explicit feature IDs, and alias-vs-feature-ID language;
- strategy helper and feature-map docs make `ctx$features()` discoverable;
- adapter-positioning language is present in user-facing docs;
- `contracts.md`, `NEWS.md`, package help, and documentation tests match the
  shipped behavior;
- release-gate playbook additions from the v0.1.7.4 post-mortem are present;
- release-gate playbook includes the DuckDB rollback rule,
  remote-log-first debugging, and stop-and-review rule;
- full Windows checks pass;
- local WSL/Ubuntu checks pass for executable R, DuckDB, docs, or CI-sensitive
  changes;
- remote branch CI is green before merge;
- `main` CI and tag-triggered CI are green before the release is considered
  valid.
