# Workstream 8 Closeout: Built-In Strict-Feature Acceleration

**Status:** Agent-provisional; awaiting one Type 1 close review.
**Date:** 2026-10-04
**Implementation range:** `dcb3130..9bde734`
**Tickets:** LDG-2941 through LDG-2942

## Outcome

Both independently gated candidates passed and shipped. Availability-aware
hydration now evaluates canonical ledgr SMA and returns once per instrument
series, then applies one exact trailing-completeness mask. The pre-cut scalar
implementation remains as `ledgr_compute_feature_series_strict_scalar()` and
is the semantic oracle and the path for every other indicator.

No public API, indicator definition, gap contract, numerical tolerance,
snapshot identity, run identity, persistence rule or failure contract changed.
The availability feature-engine digest changed because its implementation
changed. The dense digest and public indicator fingerprints did not.

## Registered Gates

The baseline was accepted Workstream 7 commit `dcb3130`. Before production was
edited, an exact candidate was applied to a detached source fork of that
commit. Twenty-four fresh R 4.6.1 processes alternated baseline and candidate
arms over three repetitions for each feature and workflow. Each process built
the same sealed 50-instrument, 500-pulse availability fixture, then timed only
the public workflow. Every timing row recorded zero other R processes.

The public threshold was preregistered at five percent for cold `ledgr_run()`;
the internal strict-construction threshold was 10x. `ledgr_sweep()` was also
measured and compared exactly but was not needed to rescue either gate.

| Feature | Path | Baseline median | Candidate median | Saving |
| --- | --- | ---: | ---: | ---: |
| SMA | `ledgr_run()` | 6.121 s | 3.534 s | 42.3% |
| SMA | `ledgr_sweep()` | 5.298 s | 2.769 s | 47.7% |
| returns | `ledgr_run()` | 7.303 s | 4.904 s | 32.9% |
| returns | `ledgr_sweep()` | 6.188 s | 3.865 s | 37.5% |

At one 3,000-row instrument series, SMA construction measured 0.242 versus
0.003 seconds (80.7x), and returns measured 0.238 versus 0.001 seconds (238x).
These clocks support the structural result; the public table is the effect
estimate. All 24 public comparisons and both internal feature vectors were
identical. Evidence is under `ws8_strict_feature_evidence/`.

## Exact Semantics And Dispatch

SMA uses `rowMeans(embed(close, width))`. This was selected because it is
bit-identical to the retained per-window `mean(window$close)` result;
`ledgr_rolling_mean()` and cumsum are not. Returns uses its existing canonical
series function. Both are masked by one rolling count over finite, non-missing
open, high, low and close observations.

Dispatch recognizes only the base or availability-active fingerprint of the
canonical ledgr definition with the same parameters. It does not inspect ID or
source as authority. A custom definition that calls itself `sma_3` and labels
itself `ledgr` stays scalar and preserves its own value. Custom, adapted and
TTR-labelled definitions also stay scalar.

LTB-0142 covers dense input, a missing value in each OHLC column, isolated and
consecutive gaps, leading missing history, warmup and a history shorter than
the window. LTB-0143 counts two bounded-vector and three retained-scalar calls
over canonical and excluded definitions. LTB-0144 pins the dense and
availability engine digests, the two public indicator fingerprints, and every
new helper in the availability provenance payload.

The availability digest is now
`52f2c3ef901cdb0cfacd60c366978db5084a6249289b303e5d9ef5a3787f215a`.
The dense digest remains
`80d1ae6d2165196044db3f0d1944d69f21b76e264d2df16df49e23f448a7c681`.
An older precomputed availability object therefore fails the existing engine
version check rather than being reused under changed implementation code.

## Failure Probes

| Mutation | Result |
| --- | ---: |
| replace exact SMA with `ledgr_rolling_mean()` | 8 failures |
| inspect close only, omitting open/high/low from completeness | at least 13 failures before the reporter cap |
| dispatch from built-in-looking ID instead of fingerprint | 5 failures |

The mutations ran only in the detached worktree. The release checkout was
restored to none of them.

## Seven-Shape Walk

1. Repeated lookup: canonical-kind construction is once per instrument and
   feature, not per window. Its two-fingerprint comparisons are fixed size.
2. Growing scans: the trailing mask and series computation each scan the input
   once; no prior window is rescanned.
3. Per-element work with a batch replacement: one vector series replaces one
   frame slice, completeness pass, scalar call and parity call per window.
4. Scale-growing collections: output and mask are bounded by input rows. No
   history-growing list, frame or registry was added.
5. Recomputed discarded work: scalar-versus-series certification is retained
   only for definitions whose behavior ledgr does not own.
6. Frame construction: the vector path does not construct a frame per window;
   it consumes the already aligned input frame once.
7. Mutation and copy shape: helpers allocate bounded vectors and do not mutate
   the caller's bars or any shared cache object.

The remaining work is O(rows) per instrument and built-in feature.

## Evidence Incidents And Verification

Two initial in-process attempts are discarded. The first failed after writing
provisional CSVs because isolated Git metadata lookup was denied. The second
completed, but a newly added counter proved the namespace candidate had never
executed on the public path. Neither set is evidence. The source-fork record
replaced them completely and is the only timing record copied into the packet.

Focused strict-feature, availability-feature, fingerprint, control-plane and
claims checks pass. The committed-tree ordinary fast profile executed 503 of
503 blocks with zero failures or skips in 87.610 seconds. The checker returned
`LEDGR_TEST_GATE_OK` against the 112-second bound. Its record is
`C:/Users/maxth/ledgr-research/ws8-fast-9bde734`.

Before this request Cut 2 has five review invocations over eleven tickets: the
cut review, two Workstream 6 rounds and two Workstream 7 rounds. This required
close review is invocation six, 6/11 = 0.545, a historical review-gate breach.
It is recorded rather than hidden or repaired by padding the cut.
