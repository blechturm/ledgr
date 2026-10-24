# Workstream 55 closeout: direct estimator history and readiness

## Scope

Workstream 55 implements LDG-3099 and LDG-3100 at `7407c397`. It changes
only the causal-history read surface and its teaching. It does not add a
second history reader, an automatic hold, a scheduling abstraction or a
compatibility surface.

## Direct matrix read

`ledgr_history_frame()` and the context form of `ledgr_history_matrix()` now
prepare one private causal request plan and perform one substrate read. The
two public forms are manifestations of that shared result:

- the frame is the tidy inspection form, with cell evidence;
- the matrix is the ordinary estimator form, with values, dimnames,
  selection evidence and immutable history identity, but no retained frame
  or cell-evidence plane.

The existing `ledgr_history_matrix(history)` adapter remains. Direct and
adapter matrices agree on values, dimnames, selection, cutoff, policy and
requirements. The integrated proof exercises dense-shaped and
availability-aware run, sweep, explicit precompute, public walk-forward and
pulse-inspection contexts. Empty `0 x N` and `N x 0` shapes have explicit
dimname oracles.

Base matrix indexing and ordinary estimators work directly. `stats::cov()`
and the registered minimum-variance witness consume the result without an
extra conversion. `ledgr_history_info()` and `ledgr_align_weights()` accept
an intact frame or matrix. Arithmetic, mathematical transforms, replacement
and row or column subsets deliberately drop the ledgr history identity;
passing such a result to an identity-aware helper refuses with
`ledgr_invalid_history_result`.

## Requirements and readiness

Both output forms now share three explicit requirements:

- `lookback` is required, with `Inf` spelling all available causal history;
- `min_observations` counts finite values in the returned policy-treated
  plane and defaults to the requested finite lookback, or to the common
  returned-axis row count for `lookback = Inf`;
- `min_instruments` changes only the recorded panel-readiness result. It does
  not silently remove more columns.

Finite carried bar inputs and finite carried feature outputs count as
observations. Warmup, structural and inactive cells, expired carry, ordinary
missing cells and non-finite calculated values do not. The registered truth
table covers input and output carry separately.

`ledgr_passed_warmup()` keeps its vector and context-vector behavior and now
also accepts intact history frames and matrices. It returns their recorded
readiness bit without rescanning values. A valid but insufficient panel
returns `FALSE`; the strategy still chooses `ctx$hold()` explicitly.

`ledgr_history_sufficient()` and `na_action` are removed from exports, help,
examples and current package call sites, with no alias, parser or warning.

## Performance record

`dev/bench/v0_2_2_history_api_cleanup/` records three alternating 20-read
arms on one prepared, vendor-neutral 500-instrument by 252-session history.
The median direct read is 0.0190 seconds versus 0.0320 seconds through the
frame adapter, a ratio of 0.594 against the 1.05 no-regression boundary.

The R heap peak counter is effectively tied (97.2 MB direct, 97.1 MB
adapter) and is disclosed without a memory-saving claim. Retained object
size captures the intended structural difference: 1,164,664 bytes for the
direct matrix versus 10,554,672 bytes while the adapter frame and matrix are
both live. Snapshot construction and P1/P2 preparation are outside both
arms.

## Detecting evidence

LCL-0479/LTB-0488 detects the shared-plan and direct-matrix boundary. Its
structural pins reject a public frame call, a second substrate read and a
full frame allocation on the direct path; value and metadata oracles cover
the ordinary-matrix and transformed-object rules.

LCL-0480/LTB-0489 detects the requirement and readiness contract, including
finite and infinite lookbacks, empty shapes, finite-value counting, both
carry kinds, recorded readiness without a rescan, explicit strategy fallback
and removal of the old public surfaces. Existing history integration claims
were updated where their public calls acquired required arguments; their
economic oracles were not weakened.

## Seven-shape walk

1. No row-wise data-frame construction occurs inside a loop. The frame is
   materialized once at its public output boundary.
2. No loop repeatedly subsets a growing table.
3. No per-cell timestamp or scalar parsing was added.
4. No JSON serialization was added.
5. One shared request plan owns cutoff, axis, treatment and selection; the
   matrix path does not build a frame and readiness is not recomputed.
6. Validation is flat and outside value loops.
7. No environment-held scalar or vector is repeatedly rewritten.

The value work uses vectorized matrix operations. The small private helpers
either have multiple production consumers or provide the named structural
seam required to prove that both public forms use the same plan.

## Verification

Focused suites passed for the new API, frame and adapter behavior, integrated
run/sweep/precompute/walk-forward/inspection parity, substrate behavior,
teaching, indicator causality, the minimum-variance witness, private context,
feature maps, exports, documentation contracts and the test control plane.
Both changed vignettes rendered successfully. The benchmark record is
checked in, YAML inputs parse and `git diff --check` is clean.
