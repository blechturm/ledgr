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

Does `ledgr_compute_feature_series()` reproduce the feature values seen by one
ordinary public `ledgr_run()` when both consume the same stored bars? If not,
the probe stops: an internal engine cannot be the evidence oracle.

Dense execution is used only for that parity oracle. History remains targeted
at full-membership and changing-membership shapes on the availability path.

## Runnable core and cases

The runner constructs indicators only through exported constructors and uses
the real feature engine. It runs five cases, below the protocol cap:

1. a smooth trend/oscillation path;
2. a seeded volatile path;
3. a large-scale path exposing floating-point cancellation;
4. one missing expected session; and
5. five missing expected sessions.

For complete paths it compares the full series with every sampled prefix and
with the indicator restarted on its finite candidate window. For gaps it keeps
the expected-session rows, records current availability admission, and compares
the uninterrupted series with per-segment restart. Multi-output TTR families
are expanded through `ledgr_ind_ttr_outputs()`.

The source classification is deliberately factual and release-local:

- finite built-in formulas and finite TTR rolling/window functions are
  `bounded` candidates;
- TTR RSI, EMA, ATR's `atr`, and all MACD outputs are
  `history_dependent` candidates because their current implementations carry
  recursive state; and
- unsupported TTR functions that require a caller-supplied warmup, custom
  indicators, and fitted/cross-sectional functions are outside this census.

The executable comparisons corroborate or challenge that source reading; they
do not prove arbitrary custom code bounded.

## Evidence and gut

The runner writes:

- package/dependency metadata and a 34-output inventory;
- raw prefix/window samples and derived conformance summaries;
- raw gap samples and first-valid/convergence summaries; and
- public-run/internal-engine parity.

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

Numerical thresholds in the checker describe this fixed evidence corpus only.
Session D must justify any product tolerance independently.

## Non-goals

No product file, test, contract, ticket, decision register, or macro-plan entry
changes. The spike does not certify arbitrary custom indicators, implement
segment execution, make TTR available under gaps, establish convergence as a
readiness gate, or create a dense history feature.
