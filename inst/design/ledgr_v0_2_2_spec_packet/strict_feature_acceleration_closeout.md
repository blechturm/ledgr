# Workstream 8 Closeout: Built-In Strict-Feature Acceleration

**Status:** Agent-provisional; awaiting focused Type 1 correction review.
**Date:** 2026-10-04
**Implementation range:** `dcb3130..11bd294`
**Tickets:** LDG-2941 through LDG-2942

## Outcome

Both independently gated candidates passed and shipped. Availability-aware
hydration now accelerates canonical ledgr SMA and returns, then applies one
exact trailing-completeness mask. The pre-cut scalar implementation remains as
`ledgr_compute_feature_series_strict_scalar()` and is the semantic oracle and
the path for every other indicator.

No public API, indicator definition, gap contract, numerical tolerance,
snapshot identity, run identity, persistence rule or failure contract changed.
The availability feature-engine digest changed because its implementation
changed. The dense digest and public indicator fingerprints did not.

## Registered Gates

The corrected record compares two durable Git trees: baseline `dcb3130` and
candidate `11bd294`. Twenty-four fresh R 4.6.1 processes alternated baseline
and candidate arms over three repetitions for each feature and workflow. Each
process built the same sealed 50-instrument, 500-pulse availability fixture,
then timed only the public workflow. Every timing row recorded zero other R
processes.

The public threshold was preregistered at five percent for cold `ledgr_run()`;
the internal strict-construction threshold was 10x. `ledgr_sweep()` was also
measured and compared exactly but was not needed to rescue either gate.

| Feature | Path | Baseline median | Candidate median | Saving |
| --- | --- | ---: | ---: | ---: |
| SMA | `ledgr_run()` | 6.674 s | 3.958 s | 40.7% |
| SMA | `ledgr_sweep()` | 5.722 s | 3.241 s | 43.4% |
| returns | `ledgr_run()` | 7.604 s | 4.964 s | 34.7% |
| returns | `ledgr_sweep()` | 6.135 s | 3.842 s | 37.4% |

At one 3,000-row instrument series, SMA construction measured 0.321 versus
0.016 seconds (20.1x), and returns measured 0.361 versus 0.001 seconds (361x).
These clocks support the structural result; the public table is the effect
estimate. All 24 public comparisons and both internal feature vectors were
identical. Evidence is under `ws8_strict_feature_evidence/`.

## Exact Semantics And Dispatch

SMA uses one `mean()` over each numeric close slice. The first Type 1 review
proved that the original `rowMeans(embed(close, width))` candidate changed
summation order and differed from the scalar oracle by one or more ulps on
plausible inputs. Commit `11bd294` therefore retains the accelerated path but
uses the oracle's arithmetic exactly. A seeded 1,200-row, 20%-volatility,
500-row-window witness fails under `rowMeans(embed())` and passes under the
landed helper. `ledgr_rolling_mean()` and cumsum remain inexact alternatives.

Returns uses its existing canonical series function. Both indicators are
masked by one rolling count over finite, non-missing open, high, low and close
observations.

Dispatch recognizes only the base or availability-active fingerprint of the
canonical ledgr definition with the same parameters. It does not inspect ID or
source as authority. A custom definition that calls itself `sma_3` and labels
itself `ledgr` stays scalar and preserves its own value. Custom, adapted and
TTR-labelled definitions also stay scalar.

LTB-0142 covers dense input, a missing value in each OHLC column, isolated and
consecutive gaps, leading missing history, warmup, short history and the
hostile floating-point witness. LTB-0143 counts two accelerated and three
retained-scalar calls. LTB-0144 pins the dense and availability engine digests,
the public indicator fingerprints and every semantic helper in provenance.

The availability digest is now
`90e2932cc2794212119b60d7be4abd5ea7fd4ead28119adbc278247f2bad267e`.
The dense digest remains
`80d1ae6d2165196044db3f0d1944d69f21b76e264d2df16df49e23f448a7c681`.
An older precomputed availability object therefore fails the existing engine
version check rather than being reused under changed implementation code.

## Failure Probes

| Mutation | Result |
| --- | ---: |
| restore `rowMeans(embed())` for SMA | 2 failures: arithmetic and provenance |
| replace exact SMA with `ledgr_rolling_mean()` | 8 failures |
| inspect close only, omitting open/high/low | at least 13 failures |
| dispatch from built-in-looking ID | 5 failures |

The mutations ran only in detached worktrees. The release checkout retains
none of them.

## Seven-Shape Walk

1. Repeated lookup: canonical-kind construction is once per instrument and
   feature, not per window. Its fingerprint comparisons are fixed size.
2. Growing scans: returns and the trailing mask scan the input once. Exact SMA
   retains one bounded-width numeric slice and `mean()` per eligible window.
   This is O(rows x width), not O(rows), but removes the much larger frame,
   validation, scalar-dispatch and parity work and clears the registered 10x
   construction gate. A rolling reduction would change arithmetic.
3. Per-element work with a batch replacement: exact SMA deliberately retains
   per-window `mean()` because every tested batch replacement failed bit
   identity. It removes the per-window frame and dispatch work around that
   oracle operation. Returns uses one vector series.
4. Scale-growing collections: output and mask are bounded by input rows. No
   history-growing list, frame or registry was added.
5. Recomputed discarded work: scalar-versus-series certification is retained
   only for definitions whose behavior ledgr does not own.
6. Frame construction: the accelerated path constructs no frame per window;
   it consumes the aligned input frame once and numeric slices for exact SMA.
7. Mutation and copy shape: helpers allocate bounded vectors and do not mutate
   the caller's bars or any shared cache object.

Returns remains O(rows). SMA is O(rows x width) for the stated exactness
reason, with much lower constant work than the scalar frame path.

## Reproduction And Verification

Two initial in-process attempts are discarded. The first failed after writing
provisional CSVs because isolated Git metadata lookup was denied. The second
completed, but a counter proved the namespace candidate had never executed on
the public path. Neither set is evidence. The later source-fork record was
superseded after the first review found its SMA arithmetic was not universally
exact. Only the corrected two-commit record is copied into the packet.

Run one fresh process per public case:

```text
Rscript strict_feature_benchmark.R --native-only --repo <tree> \
  --out <case-directory> --feature <sma|returns> \
  --workflow <run|sweep>
```

Name cases `<feature>-<workflow>-rep<1..3>-<baseline|candidate>`. Odd
repetitions run baseline then candidate; even repetitions reverse the order.
Run the direct clocks and aggregate with:

```text
Rscript native_micro.R --repo <tree> --out <root> \
  --arm <baseline|candidate>
Rscript aggregate_native.R <root> \
  dcb31309c8b95dfd33d3ede5712105d2421bb5fb \
  11bd294906e4a00c0740198c6f532d3096980d49
```

The candidate blobs are
`6d5700810512dad7c3d39a1d32f05492c6cc30c3` for
`R/features-engine.R` and
`5edfb8686ea7f575e4a771a646612cafa59807f9` for
`R/feature-cache.R`.

Focused strict-feature, availability-feature, fingerprint, feature-cache,
control-plane and documentation-contract checks pass after correction. The
correction ordinary fast profile executed 503 of 503 blocks with zero failures
or skips in 83.680 seconds. The checker returned `LEDGR_TEST_GATE_OK` against
the 112-second bound. Its record is
`C:/Users/maxth/ledgr-research/ws8-correction-fast-11bd294`.

The first Workstream 8 close review was invocation six over eleven tickets and
returned `CHANGES_REQUIRED`. The focused correction review will be invocation
seven, 7/11 = 0.636, a historical review-gate breach. It is recorded rather
than hidden or repaired by padding the cut.
