# ledgr UX Triage Report

Source: `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.2/categorized_feedback.yml`

This is a maintainer-review artifact. It does not create GitHub issues,
does not execute ledgr workflows, and does not decide final defect truth.

## Validation

- well formed: yes
- errors: 0
- warnings: 0
- themes: 10
- item classifications: 88

## Bucket Counts

| bucket | items |
| --- | --- |
| docs_gap | 63 |
| unclear | 18 |
| expected_user_error | 4 |
| ledgr_bug | 2 |
| model_error | 1 |

## Severity Counts

| severity | items |
| --- | --- |
| high | 2 |
| medium | 68 |
| low | 18 |

## Theme Priority Table

| theme_id | severity | bucket | episode_count | feedback_count | title | recommended_action |
| --- | --- | --- | --- | --- | --- | --- |
| THEME-007 | high | ledgr_bug | 4 | 7 | Trades, fills, equity metrics, and summaries need triage | Maintainer should verify accounting semantics, then either fix result state or document metric/table definitions with examples. |
| THEME-001 | medium | docs_gap | 12 | 10 | Headless documentation discovery is weak | Add CLI-friendly documentation discovery examples, installed-vignette paths, and package overview links to runnable first workflows. |
| THEME-005 | medium | docs_gap | 8 | 7 | Shell quoting and captured logs confuse Windows users | Prefer script-file examples for Windows and add notes for escaping $, suppressing startup messages, and checking exit status. |
| THEME-002 | medium | docs_gap | 7 | 7 | Helper pipeline examples are too fragmented | Add complete runnable helper-pipeline examples for single-asset, multi-asset, parametric comparison, and manual/helper parity. |
| THEME-003 | medium | docs_gap | 6 | 9 | Warmup and all-NA behavior needs diagnostics | Document warmup timing, add quiet/diagnostic patterns for expected warmup, and consider run-level feature availability/no-trade diagnostics. |
| THEME-004 | medium | docs_gap | 6 | 5 | Feature IDs and indicator outputs are easy to miss | Emphasize ledgr_feature_id() in examples, cross-link built-in/TTR indicator pages, and show failure/recovery paths for unregistered or mismatched feature IDs. |
| THEME-006 | medium | docs_gap | 4 | 4 | Final-bar next-open fill semantics need clearer guidance | Add a concise warning explanation and examples that set end to the penultimate bar when using next_open. |
| THEME-009 | medium | docs_gap | 4 | 5 | Strategy context and helper contracts need reference clarity | Add a compact strategy context reference and align helper contract wording across help pages. |
| THEME-008 | medium | docs_gap | 1 | 1 | Snapshot manual import and sealing path diverges from convenience path | Clarify manual versus convenience snapshot metadata behavior and show explicit seal/backtest examples with start/end. |
| THEME-010 | low | unclear | 5 | 6 | Resolved and positive rows are not independent defects | Use these rows as supporting context only; do not file standalone issues from them without a linked defect row. |

## High Priority Themes

### THEME-007 - Trades, fills, equity metrics, and summaries need triage

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 4
- feedback rows: 7
- evidence: High-priority episode 013 reports final position without corresponding fill, total_return versus realized P&L disagreement, and time_in_market affected by equity state; other episodes show confusion around zero closed trades and surprising equity/drawdown output.
- recommended action: Maintainer should verify accounting semantics, then either fix result state or document metric/table definitions with examples.
- uncertainty: Some findings may be expected open-position or closed-trade semantics; raw evidence does not prove every item is a bug.

## Maintainer Analysis

This section converts the generated auditr theme grouping into release-planning
judgment for v0.1.7.3.

### Confirmed Defect: Equity Curve Can Diverge From Fills

THEME-007 contains one confirmed ledgr defect, not just documentation
confusion. The reproducible script from
`2026-05-02_013_trades_fills_and_metrics` still reproduces against the current
checkout:

- fills: BUY 1 AAA on 2020-01-02 at 101, then SELL 1 AAA on 2020-01-03 at 102;
- trades: one closed trade with realized P&L of 1;
- final equity row: `cash = 899`, `positions_value = 105`, `equity = 1004`;
- metrics: `total_return = 0.004`, while closed-trade realized P&L divided by
  initial cash is `0.001`.

The position is flat according to the ledger events, but the final equity row
marks one open share. That means portfolio state persisted in `equity_curve`
can disagree with the event-sourced fill history. The likely defect boundary is
the runner's in-loop equity recording in `R/backtest-runner.R`: the equity row
is built from a mixture of pre-fill and post-fill state around target execution
and next-open fill timing. The derived-state rebuild path in `R/derived-state.R`
is a useful oracle because it reconstructs cash, positions, and equity from
ledger event deltas.

Recommended v0.1.7.3 action:

1. Add the episode-013 script as a focused regression test.
2. Assert that cumulative `position_delta` implies zero final position.
3. Assert that final `equity_curve$positions_value` is zero for the flat final
   ledger state.
4. Assert that `ledgr_compute_metrics(bt)$total_return` agrees with the final
   equity curve after the state fix.
5. Run the same scenario in audit-log mode and standard mode, because the bug
   may live in one execution-mode equity writer or in shared fill timing
   assumptions.

Do not solve this as documentation. The result tables and summary metrics must
not contradict the ledger.

### Semantics That Are Valid But Under-Explained

Several THEME-007 rows are not independent bugs:

- `ledgr_results(bt, what = "trades")` showing only closed round trips is
  intended. Open-only buy-and-hold runs can have fills but zero trades.
- `win_rate = NA` for zero closed trades is intended.
- A final `LEDGR_LAST_BAR_NO_FILL` warning is expected under `next_open` when
  the strategy changes target on the last pulse and no later bar exists.
- `summary(bt)` returning the original backtest object is not a correctness
  defect, but it is surprising enough to document or revisit as an S3 UX
  improvement.

These should become documentation or ergonomics tickets only after the equity
curve defect is fixed, otherwise the docs would be explaining around a real
state inconsistency.

### Items Already Mostly Addressed In v0.1.7.2

Some generated themes reflect friction that the v0.1.7.2 release work already
improved:

- THEME-002: `strategy-development` now gives an end-to-end helper pipeline:
  `signal_return()` -> `select_top_n()` -> `weight_equal()` ->
  `target_rebalance()`.
- THEME-006: the strategy-development article now explains that examples use
  next-open fills and that final-pulse targets have no next bar.
- THEME-008: experiment-store documentation now distinguishes temporary example
  paths from durable project paths, persistent `snapshot_id`s, and CSV
  snapshot creation/reload.
- THEME-009: the strategy-development article now introduces the pulse context,
  target vectors, helper value types, and the policy-not-orders mental model.

These themes should not be blindly copied into v0.1.7.3 as if untouched. They
need spot review against current docs before ticketing more work.

THEME-001 is different. LDG-1208 improved README-level noninteractive
discovery, but the auditr pattern shows a deeper entry-point problem: cold
agents often start from `?ledgr_run`, `?ledgr_experiment`, `?ledgr_backtest`,
`help(package = "ledgr")`, or package-index output, not from the README. Those
help pages should point directly to the strategy-development article and include
an offline path such as `system.file("doc", "strategy-development.html",
package = "ledgr")`. This should remain an open v0.1.7.3 documentation ticket,
not be closed as addressed by LDG-1208.

### Helper Layer Documentation Debt

Episode 018 adds a concrete helper-layer finding: `target_rebalance()` floors
share quantities to whole numbers, but the help page does not state that. The
flooring behavior is correct and architecturally important, because it is what
makes helper-built targets and hand-written whole-share strategies line up. It
is currently discoverable only by probing runtime behavior.

The fix should be small but explicit:

- document whole-share floor sizing in `target_rebalance()` help;
- show the pre-floor weight-to-dollar allocation and post-floor target quantity
  in `strategy-development`;
- add one compact helper composition contract explaining what is preserved from
  `signal_return()` -> `select_top_n()` -> `weight_equal()` ->
  `target_rebalance()` and where execution semantics begin.

### Episode 006 Ingestion Gap

Episode 006 had a structural parse miss. Its raw `framework_feedback.md`
contains six distinct findings, while the categorized summary understates the
evidence base for THEME-004:

- multi-output TTR names are not discoverable until construction is attempted
  or the user finds the TTR vignette;
- `BBands` requires an explicit output such as `dn`, `mavg`, `up`, or `pctB`;
- the MACD example can be copied with mismatched explicit/default `percent`
  arguments;
- feature IDs are exact and should be obtained with `ledgr_feature_id()`;
- warmup `NA` handling remains easy to omit;
- noninteractive help and vignette capture was awkward.

Before finalizing THEME-004 priority, read episode 006 directly and decide
whether multi-output `ledgr_ind_ttr()` deserves its own ticket or belongs in a
broader feature-ID documentation ticket.

### Remaining v0.1.7.3 Candidates

The triage themes point to these concrete candidates:

| priority | source themes | candidate |
| --- | --- | --- |
| P0 | THEME-007 | Fix equity/positions/metrics inconsistency against ledger fills. |
| P1 | THEME-001 | Add function-level `\seealso` or article references on `ledgr_run()`, `ledgr_experiment()`, `ledgr_backtest()`, and other entry points so headless users can discover installed articles without reading the README first. |
| P1 | THEME-009, episode 018 evidence | Document `target_rebalance()` whole-share floor sizing and add the helper composition contract to strategy-development. |
| P1 | THEME-004, episode 006 evidence | Read episode 006 raw markdown before finalizing feature/TTR ticket scope; the parser understated BBands/MACD multi-output findings. |
| P2 | THEME-003, episode 019 evidence | Add a no-trade or no-fill diagnostic path that distinguishes expected warmup from never-usable signals. |
| P2 | THEME-003 | Add a helper-level way to suppress expected empty-selection warmup without hiding all empty-signal diagnostics. A `warn_empty = FALSE` option or more specific warning class is preferable to teaching broad `suppressWarnings()`. |
| P2 | THEME-005 | Prefer `.R` script snippets over PowerShell `Rscript -e` examples anywhere strategy code contains `$`. |
| P2 | THEME-007 | Expand result-table docs with fills versus trades, open-only runs, realized P&L, and why zero trades can be valid. |
| P2 | THEME-009 | Align `ledgr_signal_strategy()` help text with the actual function signature and the broader `function(ctx, params)` strategy convention. |
| P3 | THEME-007 | Decide whether `summary(bt)` should return a summary object or continue returning `bt` invisibly with clearer docs. |

### Auditr Data Quality Notes

The auditr corpus is useful, but the generated classifications need human
filtering:

- Episodes 005, 006, and 009 had structural parse failures or collapsed
  feedback rows. Their raw `framework_feedback.md` files should be read before
  ticket creation. Episode 006 is especially important because its raw feedback
  contains the strongest BBands/MACD and multi-output TTR evidence.
- THEME-010 is explicitly not a defect bucket. It contains resolved
  workarounds, positive observations, and parser artifacts.
- Windows shell quoting issues are real user friction, but not ledgr runtime
  defects. They belong in docs/examples rather than core code.

## Issue Candidate Themes

These are grouped findings suitable for maintainer review. They are not GitHub issues yet.
### THEME-007 - Trades, fills, equity metrics, and summaries need triage

- bucket: `ledgr_bug`
- severity: `high`
- episodes: 4
- feedback rows: 7
- evidence: High-priority episode 013 reports final position without corresponding fill, total_return versus realized P&L disagreement, and time_in_market affected by equity state; other episodes show confusion around zero closed trades and surprising equity/drawdown output.
- recommended action: Maintainer should verify accounting semantics, then either fix result state or document metric/table definitions with examples.
- uncertainty: Some findings may be expected open-position or closed-trade semantics; raw evidence does not prove every item is a bug.

### THEME-001 - Headless documentation discovery is weak

- bucket: `docs_gap`
- severity: `medium`
- episodes: 12
- feedback rows: 10
- evidence: Many episodes report help(), vignette(), package help, or help.search() being blank, browser-bound, or awkward from Rscript/headless Windows shells.
- recommended action: Add CLI-friendly documentation discovery examples, installed-vignette paths, and package overview links to runnable first workflows.
- uncertainty: Some friction is base R or Windows shell behavior rather than ledgr-specific, but it repeatedly affected ledgr UX episodes.

### THEME-005 - Shell quoting and captured logs confuse Windows users

- bucket: `docs_gap`
- severity: `medium`
- episodes: 8
- feedback rows: 7
- evidence: PowerShell $ expansion, Rscript -e brittleness, stderr startup messages, and NativeCommandError-looking logs recurred across episodes.
- recommended action: Prefer script-file examples for Windows and add notes for escaping $, suppressing startup messages, and checking exit status.
- uncertainty: This is mostly environment and documentation friction, not ledgr runtime behavior.

### THEME-002 - Helper pipeline examples are too fragmented

- bucket: `docs_gap`
- severity: `medium`
- episodes: 7
- feedback rows: 7
- evidence: Users repeatedly stitched signal_return(), select_top_n(), weight_equal(), target_rebalance(), features, params, and result comparison from separate pages.
- recommended action: Add complete runnable helper-pipeline examples for single-asset, multi-asset, parametric comparison, and manual/helper parity.
- uncertainty: Most pieces worked once discovered; the gap is end-to-end composition rather than missing individual functions.

### THEME-003 - Warmup and all-NA behavior needs diagnostics

- bucket: `docs_gap`
- severity: `medium`
- episodes: 6
- feedback rows: 9
- evidence: Warmup warnings repeat per pulse, start/end behavior was unclear, long lookbacks can produce all-flat or zero-trade runs, and users had to inspect pulses manually.
- recommended action: Document warmup timing, add quiet/diagnostic patterns for expected warmup, and consider run-level feature availability/no-trade diagnostics.
- uncertainty: Repeated warnings may be intentional, but evidence supports a UX issue around separating expected warmup from never-usable signals.

### THEME-004 - Feature IDs and indicator outputs are easy to miss

- bucket: `docs_gap`
- severity: `medium`
- episodes: 6
- feedback rows: 5
- evidence: Episodes highlight exact feature ID strings, multi-output TTR indicator names, RSI ID variants, and helper feature registration as recurring discovery points.
- recommended action: Emphasize ledgr_feature_id() in examples, cross-link built-in/TTR indicator pages, and show failure/recovery paths for unregistered or mismatched feature IDs.
- uncertainty: Raw parsed CSV collapsed the detailed RSI and BBands/MACD numbered issues, so theme evidence includes raw markdown headings and diagnostic context.

### THEME-006 - Final-bar next-open fill semantics need clearer guidance

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 4
- evidence: Several runs emitted LEDGR_LAST_BAR_NO_FILL or required penultimate end-date workarounds because next_open fills cannot occur on the final pulse.
- recommended action: Add a concise warning explanation and examples that set end to the penultimate bar when using next_open.
- uncertainty: The underlying behavior appears documented in ledgr_backtest() help, but not discoverable enough in experiment/helper workflows.

### THEME-009 - Strategy context and helper contracts need reference clarity

- bucket: `docs_gap`
- severity: `medium`
- episodes: 4
- feedback rows: 5
- evidence: Reports include ledgr_signal_strategy() fn(ctx) vs function(ctx, params) inconsistency, ctx$equity field versus method confusion, and ledgr_weights universe exact-name behavior confusion.
- recommended action: Add a compact strategy context reference and align helper contract wording across help pages.
- uncertainty: Some exact-name behavior may be intentional; the docs should make the contract explicit.

### THEME-008 - Snapshot manual import and sealing path diverges from convenience path

- bucket: `docs_gap`
- severity: `medium`
- episodes: 1
- feedback rows: 1
- evidence: Raw framework feedback reports manual create/import/seal snapshots did not provide usable start/end metadata while ledgr_snapshot_from_csv() did, and explicit sealing was hidden by the convenience path.
- recommended action: Clarify manual versus convenience snapshot metadata behavior and show explicit seal/backtest examples with start/end.
- uncertainty: Parsed CSV only retained status/workaround headings, so this theme relies on raw framework_feedback.md details.

### THEME-010 - Resolved and positive rows are not independent defects

- bucket: `unclear`
- severity: `low`
- episodes: 5
- feedback rows: 6
- evidence: Several parsed feedback rows are status, outcome, positive observation, or workaround summaries rather than direct maintenance findings.
- recommended action: Use these rows as supporting context only; do not file standalone issues from them without a linked defect row.
- uncertainty: Parser heading granularity caused some raw issue lists to collapse into workaround/status rows.

