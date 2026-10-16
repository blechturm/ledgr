# Charter: H2 Indicator-History Conformance Evidence

**Status:** Executable evidence charter; binds no product semantics.
**Protocol:** `inst/design/spike_protocol.md`.
**Package baseline:** `a4fdce08` on `integrate/cut15-v0.2.2`.
**Feeds:** history-wave H2 Session D and the consolidated v12 synthesis.

## One question

> Across every built-in indicator and every function/output admitted by the
> current TTR warmup table, what executable evidence distinguishes a finite
> dependency from a history-dependent one, and what numerical and gap behavior
> must Session D account for without mistaking first-valid for convergence?

This is an evidence question. The spike does not choose labels, a gap policy,
a readiness policy, a product tolerance, or identity/version consequences.

## Cheaper prerequisite

Does `ledgr_compute_feature_series()` reproduce the feature values seen through
one ordinary public dense `ledgr_run()` when both consume the same stored bars?
If not, the probe stops. This is a plumbing prerequisite, not independent
validation of an engine against itself.

The same plumbing comparison is recorded for the three currently admitted
outputs on a complete-membership, full-observation availability run. History
remains targeted at full-membership and changing-membership shapes on the
availability path.

## Runnable core and cases

The runner constructs indicators only through exported constructors and uses
the real feature engine. It runs ten cases, at the protocol cap:

1. a smooth trend/oscillation path;
2. a seeded volatile path;
3. a large-scale path exposing floating-point cancellation;
4. a hostile level shift from about `1e6` to about `1`; and
5. one and five missing expected sessions at each of three positions.

For complete paths it compares the full series with every sampled prefix and
with the indicator restarted at both `stable_after` and `stable_after + 1`
widths. For gaps it keeps the expected-session rows, records current
availability admission, and compares a segment restart that omits gap
observations with an uninterrupted full series that retains them. Multi-output
TTR families are expanded through `ledgr_ind_ttr_outputs()`.

The source classification is deliberately factual and release-local:

- the 34 default-argument outputs comprise 28 `bounded` and six
  `history_dependent` outputs;
- six algorithm-changing variants test that classification belongs to the
  family, output and arguments rather than the function name alone; their
  multi-output expansion produces eight additional output rows;
- BBands `mavg` and CCI become history-dependent with `maType = "EMA"`;
  RSI, ATR `atr`, and MACD become bounded with `maType = "SMA"`; and EMA with
  `wilder = TRUE` remains history-dependent; and
- unsupported TTR functions that require a caller-supplied warmup, custom
  indicators, and fitted/cross-sectional functions are outside this census.

The executable comparisons corroborate or challenge that source reading; they
do not prove arbitrary custom code bounded.

## Evidence and gut

The runner writes:

- package/dependency metadata and a 42-row default-plus-variant inventory;
- raw prefix/window samples, numerical conformance and width witnesses;
- raw backend first-finite rows beside ledgr's declared/masked boundaries;
- raw gap samples and fixture-local first-valid/convergence summaries; and
- dense and full-membership availability path-plumbing comparisons.

`check.R` reruns into scratch, diffs every CSV, checks the literal output
census, exercises the findings, and guards product scope. `gut.R` replaces the
finite-window restart value with the full-history value. It thereby erases the
only comparison that exposes recursive state; the checker requires the gut to
make all history-dependent restart deltas zero.

## Kill and recharter

Stop and return to the maintainer if:

- the public-run prerequisite fails;
- a supported output cannot be constructed or evaluated on the complete
  fixtures;
- prefix causality fails;
- bounded and recursive current implementations cannot be separated on these
  fixtures without indicator-specific thresholds; or
- the harness would need product code, a public API, or more than 1,500 R
  lines.

No numerical delta threshold classifies an output. Session D must justify any
product tolerance independently from the recorded drift distribution.

## Non-goals

No product file, test, contract, ticket, decision register, or macro-plan entry
changes. The spike does not certify arbitrary custom indicators, implement
segment execution, measure skip-gap recursion, make TTR available under gaps,
establish convergence as a readiness gate, or create a dense history feature.
