# Closeout: H2 Indicator-History Conformance Evidence

**Verdict:** GREEN for the chartered evidence question. The harness records a
default and algorithm-variant census without changing the package, and the
path prerequisite, prefix check, fixed census, gut and scope guard pass. GREEN
binds no product semantics.

## What ran

At package commit `a4fdce08a3269c75da11792754560055f5d6de9b`, the runner
constructed the 34 default-argument outputs from all four built-ins and every
family in the TTR warmup table. It added six algorithm variants, expanded to
eight output rows, for 42 rows total. Four complete fixtures covered smooth,
volatile, large-scale and hostile `1e6`-to-`1` level-shift paths. One- and
five-session gaps ran at three positions, making ten cases overall.

Every sampled prefix was byte-identical to the same prefix of the full
calculation. The public dense path matched the current engine exactly for all
42 outputs over exact stored bars. A complete-membership, full-observation
availability run also completed for built-in SMA, built-in returns and exact
TTR SMA. Its missingness
matched; returns were byte-identical and the two strict SMA paths differed by
about `1e-15` scaled. These are plumbing comparisons, not independent engine
validation.

The checker reruns and diffs all eight CSVs, runs the gut, freezes the census
and findings, and guards product paths. It reports:

```text
H2_D_CHECK_PASS defaults=34 variants=8 prefix=causal paths=recorded gut=detected scope=clean
```

The environment is R 4.6.1, ledgr 0.2.1.0, TTR 0.24.4, duckdb 1.5.6.9000,
DBI 1.3.0 and pkgload 1.5.3 on Windows x86-64.

## What was learned

The default-argument census is 28 bounded and six history-dependent outputs:
TTR RSI, TTR EMA, ATR `atr`, and MACD `macd`, `signal` and `histogram` retain
earlier state. That ratio does not classify whole functions. BBands `mavg` and
CCI become history-dependent with `maType = "EMA"`; RSI, ATR `atr` and all
three MACD outputs become bounded with `maType = "SMA"`; EMA with
`wilder = TRUE` remains history-dependent. The classification key is therefore
family plus output plus algorithm-changing arguments.

No numerical threshold assigns those classes. The hostile level shift records
bounded scaled restart drift of `7.64e-6` for CCI, `1.22e-7` for BBands
`pctB`, and `2.07e-9` for built-in SMA. The earlier smooth/large-scale corpus
understated this boundary. These values remain fixture-local; choosing a
product tolerance needs an independent numerical basis.

Warmup has three distinct meanings. TTR Aroon with `n = 10` differs when
executed on 10 rows (up to 80 points) but is exact on 11 rows across all four
fixtures. Eleven is an observed upper-bound witness, not a proven minimum.
Raw TTR ATR `tr`, `trueHigh` and `trueLow` first become finite at row 2 while
ledgr declares and masks to row 11. Raw MACD `macd` first becomes finite at row
10 while ledgr masks it to row 13; raw `signal` and `histogram` first become
finite at row 13. The engine's first finite row matching `stable_after` is by
normalization, not independent confirmation.

First-valid also differs from convergence. Across three gap positions, the
one-gap scaled-`1e-6` recovery ranges were 40-47 observations for TTR EMA,
101-109 for ATR, 59-72 across MACD outputs, and 157-190 for RSI. Five-gap
ranges were 48-50, 106-114, 68-75 and 181-207 respectively. Variant recovery
is retained in the CSV. The precise counterfactual is segment restart omitting
gap observations versus an uninterrupted full series retaining them; skip-gap
recursive behavior remains unmeasured.

Current admission remains narrow. Across six gap cases, availability admits
only built-in SMA, built-in returns and exact TTR SMA (18 admitted rows) and
refuses the other 234 with `ledgr_indicator_gap_unsupported`. Passing aligned
missing-session input directly to current functions does not define a general
gap rule; all 252 attempts fail through ledgr validation or the backend.

## What the spec may consume

Session D may consume the 34-default and eight-variant census, prefix and path
results, drift distribution, raw/declaration/masked warmup distinctions, the
Aroon width witness, fixture-local restart convergence, and current admission
matrix. It may not promote the observed deltas into a tolerance or treat the
restart counterfactual as a chosen gap policy.

## What remains open

The spike does not choose gap reset or skip semantics, readiness, tolerances,
minimal dependency widths, identity consequences, or support for arbitrary
custom, fitted or cross-sectional functions. It does not make recursive
indicators availability-safe and does not implement history panels. Those
remain for H2 Session D and the consolidated synthesis.
