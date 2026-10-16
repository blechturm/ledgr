# H2 Indicator-History Evidence Inventory

**Baseline:** `a4fdce08a3269c75da11792754560055f5d6de9b`
**Question:** classify current built-in and TTR outputs by family, output and
algorithm-changing arguments, then record causality, restart, gap and warmup
evidence without choosing product semantics.
**Product changes:** none.

## Runnable artifacts

- `runner.R` builds the 34 default outputs and eight outputs from six
  algorithm variants. It runs four complete fixtures and one/five-session
  gaps at three positions, for ten cases total.
- `check.R` reruns ordinary and gutted paths in temporary directories, diffs
  the ordinary evidence byte for byte, checks the literal census and findings,
  and guards package scope.
- `gut.R` supplies the deliberate fault: it substitutes the full-history value
  for each finite-restart value. The checker rejects the erased recursive-state
  evidence.

## Recorded evidence

| File | Derived content |
| --- | --- |
| `metadata.csv` | baseline and package/runtime versions |
| `inventory.csv` | 34 defaults plus eight variant outputs, raw first-finite and width witness |
| `raw_samples.csv` | full, prefix and two finite-restart widths |
| `conformance.csv` | causality, numerical drift and masked first-valid summaries |
| `width_witness.csv` | attempted two-row ATR range-output witness |
| `gap_samples.csv` | uninterrupted-retained-gap versus segment-restart observations |
| `gap_recovery.csv` | admission and fixture-local convergence boundaries |
| `path_plumbing.csv` | dense and full-membership availability integration parity |

The default 34 outputs cover all four built-ins and every output of every
family in the current TTR warmup table. The variant rows demonstrate that a
function name is not a history class:

- BBands `mavg` and CCI with `maType = "EMA"`, and EMA with
  `wilder = TRUE`, are history-dependent on this implementation;
- RSI and ATR `atr` with `maType = "SMA"` are bounded; and
- MACD with `maType = "SMA"` is bounded for its three expanded outputs.

## Fork and gut

The first fork compared the internal engine with caller-side pre-seal data.
That is the wrong plumbing oracle because the public run consumes stored bars.
The retained comparison uses exact stored bars. Dense values and missingness
are byte-identical for all 42 rows. The complete-membership availability path
runs the three currently admitted outputs successfully with identical
missingness; its SMA paths differ from the ordinary engine by about `1e-15`
scaled because they use the strict implementation. This is recorded
integration behavior, not an independent algorithm oracle.

Every history-dependent default and variant has a nonzero finite-restart
delta. The gut makes all those deltas zero, so the checker fails it for the
intended reason. No delta threshold assigns either class.

## Demoted, deleted, and learned

- **Demoted:** `28/6` describes default-argument outputs, not whole function
  families. Algorithm-changing arguments can reverse a classification.
- **Demoted:** numerical differences are a distribution to design against,
  not a classifier. The level-shift fixture raises bounded drift materially;
  a product tolerance still needs an independent basis.
- **Demoted:** `stable_after` is neither a general dependency width nor a raw
  backend first-finite oracle. ledgr masks the engine series before that row.
- **Demoted:** current availability admission is v0.2.2 evidence, not a design
  recommendation.
- **Deleted:** no product machinery. Pre-seal path comparisons and the earlier
  hard-coded Aroon dependency-width claim were discarded.
- **Learned:** every sampled prefix is byte-identical to the corresponding
  full-series prefix.
- **Learned:** executing Aroon at `stable_after = 10` differs from the full
  series, while `stable_after + 1 = 11` is exact on all four fixtures. Eleven
  is an observed upper-bound witness, not a proven minimum.
- **Learned:** raw TTR ATR `tr`, `trueHigh` and `trueLow` first become finite
  at row 2 despite ledgr's declared 11. A two-row scalar call through the ATR
  wrapper fails because the wrapper also computes the 10-row `atr`; a smaller
  output dependency therefore cannot be claimed through that wrapper.
- **Learned:** raw MACD `macd` first becomes finite at row 10 while ledgr masks
  it to row 13; raw `signal` and `histogram` first become finite at row 13.
- **Learned:** recursive first-valid and convergence are separate. Recovery
  varies with gap position and length, and the recorded comparison is exactly
  segment restart omitting the gap versus an uninterrupted series retaining
  the gap observations.

## Explicitly unsupported

The spike does not certify custom functions, unsupported TTR functions,
fitted or cross-sectional methods, minimal dependency widths, a gap/reset or
skip-gap execution policy, convergence as readiness, identity consequences,
or a numerical tolerance. Those remain inputs for H2 Session D and the
consolidated synthesis.
