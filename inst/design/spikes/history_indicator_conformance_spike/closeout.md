# Closeout: H2 Indicator-History Conformance Evidence

**Verdict:** GREEN for the chartered evidence question. The harness separates
the current finite and history-dependent implementations without changing the
package, and the public-run prerequisite, prefix-causality check, fixed census,
gut and scope guard all pass. GREEN binds no product semantics.

## What ran

At package commit `a4fdce08a3269c75da11792754560055f5d6de9b`, the runner
constructed all four built-in indicators and every family in the current TTR
warmup table. Multi-output families were expanded, yielding 34 outputs. It ran
three complete fixtures (smooth, volatile and large-scale) and two expected-
session gap cases (one and five missing sessions).

The complete-path evidence contains 2,448 sampled full-series, prefix and
finite-restart comparisons. Every sampled prefix was byte-identical to the
same prefix of the full calculation. A public `ledgr_run()` using the exact
bars read back from its sealed snapshot matched the internal feature engine
for values and missingness on all 34 outputs.

The checker reran the ordinary evidence byte for byte, ran the deliberate gut,
checked the literal 34-output census and guarded product paths. It reports:

```text
H2_D_CHECK_PASS outputs=34 prefix=causal dense=identical gut=detected scope=clean
```

The recorded environment is R 4.6.1, ledgr 0.2.1.0, TTR 0.24.4, duckdb
1.5.6.9000, DBI 1.3.0 and pkgload 1.5.3 on Windows x86-64.

## What was learned

The release-local source classification and the executable evidence agree:
28 outputs have a finite dependency on these fixtures; six retain material
earlier-history state: TTR RSI, TTR EMA, ATR's `atr`, and MACD's `macd`,
`signal` and `histogram` outputs. Their maximum scaled finite-restart deltas
range from `4.06e-6` to `85.83`, depending on output and fixture. The largest
bounded delta was TTR CCI on the large-scale fixture: absolute `2.36e-8`,
scaled `5.17e-9`. These numbers describe the corpus; they do not set a product
tolerance.

First-valid and convergence are different facts. After a one-session gap,
the recursive outputs first become finite after 10 to 15 observations, matching
their declared `stable_after` values. Reaching a scaled delta below `1e-6`
took 51 observations for TTR EMA, 113 for ATR, 70 to 76 for the three MACD
outputs, and 205 for TTR RSI. RSI had not reached `1e-9` by the end of the
fixture. A first finite value therefore cannot stand in for convergence.

TTR Aroon exposes a separate boundary: with `n = 10`, it declares
`stable_after = 10`, but exact current finite-window parity requires 11
observations. This is evidence that first-valid warmup and dependency width
must be represented separately if Session D needs both.

Current gap behavior is narrow. Across the two gap cases, availability admits
only built-in SMA, built-in returns and exact TTR SMA (six admitted rows); it
refuses the other 62 rows with `ledgr_indicator_gap_unsupported`. Directly
passing aligned missing-session input does not supply a general alternative:
all 68 attempts fail, 12 with `ledgr_invalid_feature_output` and 56 with an
underlying error. The history design therefore needs an explicit execution
rule rather than treating current function behavior as that rule.

## What the spec may consume

Session D may consume the 34-output census, the 28/6 release-local
classification, prefix-causality and dense-oracle results, numerical delta
distributions, first-valid/convergence measurements, the Aroon boundary, and
the observed current availability admission matrix. The evidence supports a
distinction among dependency width, first-valid readiness and convergence; it
does not choose their public names or policies.

## What remains open

The spike does not choose gap/reset semantics, a readiness policy, numerical
tolerances, identity consequences, or support for arbitrary custom, fitted or
cross-sectional functions. It does not make recursive indicators availability-
safe and does not implement history panels. Those remain for H2 Session D and
the consolidated history-wave synthesis.
