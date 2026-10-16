# H2 Indicator-History Evidence Inventory

**Baseline:** `a4fdce08a3269c75da11792754560055f5d6de9b`
**Question:** classify the current built-in and TTR outputs by observed history
dependence, prefix causality, gap behavior, and first-valid/convergence behavior.
**Product changes:** none.

## Runnable artifacts

- `runner.R` constructs the supported indicator census, runs three complete
  paths and two gap cases, and writes seven CSVs.
- `check.R` reruns the ordinary and gutted paths in temporary directories,
  diffs the ordinary evidence byte for byte, checks the frozen census and
  findings, and guards package scope.
- `gut.R` supplies the only deliberate fault: it substitutes the full-history
  value for the finite-restart value. This erases the measured evidence that
  distinguishes recursive outputs; `check.R` rejects that result.

## Recorded evidence

| File | Derived content |
| --- | --- |
| `metadata.csv` | baseline and package/runtime versions |
| `inventory.csv` | 34 current outputs, constructors, declared warmup and source classification |
| `raw_samples.csv` | 2,448 full, prefix and finite-restart comparisons |
| `conformance.csv` | output-by-fixture causality and restart summaries |
| `gap_samples.csv` | uninterrupted versus per-segment restart observations |
| `gap_recovery.csv` | admission, first-valid and convergence boundaries |
| `dense_oracle.csv` | public dense-run versus internal-engine parity |

The 34 outputs cover all four built-ins and every output of every family in
the current TTR warmup table. Multi-output families are expanded rather than
represented by one convenient column.

## Fork and gut

The first runnable fork showed that comparing the internal engine with the
caller's pre-seal data is not a valid parity oracle: the public run consumes
the stored snapshot representation. The retained fork queries the exact
stored bars and then obtains identical values and missingness for all 34
outputs.

In the ordinary evidence, each of the six source-classified
history-dependent outputs has a finite-restart scaled delta above `1e-7` on
at least one fixture. In the gutted evidence all six have a maximum delta of
zero. The checker therefore fails the gutted path for the intended reason.

## Demoted, deleted, and learned

- **Demoted:** source reading is a candidate classification, not an expected
  answer. The executable comparisons must corroborate it. The observed
  `1e-7` separator belongs only to this fixed corpus and is not a proposed
  product tolerance.
- **Demoted:** current availability admission is evidence about v0.2.2, not a
  design recommendation for the history surface.
- **Deleted:** no product machinery. Early scratch records that compared
  against pre-seal input were discarded because they used the wrong oracle.
- **Learned:** 28 outputs behave as finite dependencies and six retain
  material earlier-history state on these fixtures.
- **Learned:** every sampled prefix is byte-identical to the corresponding
  full-series prefix, and the public dense run is byte-identical to the
  internal engine over the stored bars.
- **Learned:** TTR Aroon's current `stable_after = 10` is a first-valid
  boundary, while exact finite dependency needs 11 observations on the
  sampled configuration. Warmup and dependency width are not interchangeable.
- **Learned:** all outputs become finite at their declared first-valid
  boundary after a reset, but recursive outputs can take tens or hundreds of
  additional observations to approach the uninterrupted result.
- **Learned:** feeding an aligned series containing missing expected sessions
  directly to current functions does not provide a general gap rule; all 68
  such attempts fail, through either ledgr validation or the underlying
  function.

## Explicitly unsupported

This evidence does not certify custom functions, unsupported TTR functions,
fitted or cross-sectional methods, a gap execution policy, convergence as a
readiness rule, or a product tolerance. Those remain design inputs for H2
Session D and the consolidated synthesis.
