# Sweep Setup And Orchestration Optimization Note

Status: Revised after adversarial review; awaiting focused verification.
Non-binding. Not a ticket, specification, gate, or authorization to change
production code.

Written before the v0.2.0.1 release gate so that an adversarial review can
test the attribution and implications before the maintainer decides whether
the release scope should change. Batch 10 evidence continues to record what
was actually measured and is not superseded by this note.

Source basis: repository HEAD
`400a3e56ae49cc61256d0e7aaca66281626d4fe3`, plus the uncommitted peer-harness
correction that replaces the private ephemeral ledgr rows with public
one-candidate `ledgr_sweep()` rows. The corrected tracked report records
15.80 seconds of setup/orchestration for the canonical sweep and 15.52 seconds
for the compiled spot-FIFO sweep.

## 1. Question

Why does the public one-candidate sweep spend about 15.5 to 15.8 seconds in
the reported setup/orchestration phase at the registered 500-instrument by
1,260-pulse shape, and which parts are avoidable without changing execution,
timestamp, feature, or provenance semantics?

The reported phase is an arithmetic boundary. It contains experiment and grid
construction plus the `ledgr_sweep()` wall not covered by its candidate engine
and inline-results clocks. It therefore includes preparation before the fold
and small assembly work after it. It is not a single production timer.

## 2. Registered shape and method

The diagnostic used the peer benchmark's registered shared-bars record:

- 500 instruments;
- 1,260 pulses per instrument;
- 630,000 bars;
- one canonical TTR crossover candidate;
- public `ledgr_sweep()`;
- retained public returns and closed trades; and
- a sealed snapshot reused by the sweep.

The run used R 4.6.1 with collapse 2.1.8 and duckdb 1.5.5. Namespace-local
wrappers recorded inclusive `proc.time()` wall around the major preparation,
candidate, and retention functions. Rprof supplied mechanism evidence only.
On Windows it sampled 17.08 seconds of a 52.98-second profiled sweep, so its
shares are not treated as a complete wall partition.

The profiled candidate fold took 34.06 seconds rather than the report's
29.01 seconds. The inclusive wrappers ran under that profiler and are not
assumed immune to its overhead. The unprofiled scaling run in section 5 is the
primary wall measurement for the dominant validator; the profiled inventory is
mechanism and relative-attribution evidence.

## 3. Measured attribution

| Function or stage | Calls | Profiled inclusive wall seconds |
| --- | ---: | ---: |
| `ledgr_precompute_validate_static_coverage()` | 1 | 15.72 |
| `ledgr_strategy_preflight()` | 2 | 2.12 |
| `ledgr_projection_from_payload()` | 1 | 0.52 |
| `ledgr_precompute_payload()` | 1 | 0.49 |
| `ledgr_bars_pulse_views()` | 1 | 0.11 |
| `ledgr_resolve_feature_candidates()` | 1 | 0.11 |
| `ledgr_precompute_fetch_bars()` | 1 | 0.10 |
| `ledgr_strategy_source_info()` | 1 | 0.09 |
| `ledgr_sweep_normalize_bars_by_id()` | 1 | 0.08 |
| `ledgr_precompute_snapshot_meta()` | 1 | 0.07 |
| `ledgr_sweep_bars_matrix()` | 1 | 0.03 |
| retained-return and retained-trade assembly | 1 | 0.02 |

The profiled setup/orchestration residual was 18.89 seconds. Static coverage
validation was 83.2 percent of that profiled residual, but its 15.72-second
wrapper wall is likely profiler-inflated: the same function took 13.94 seconds
unprofiled. The official record runs the durable rows before the public sweep
rows and therefore enters the sweep with session caches warm.

The first strategy preflight in a fresh session took 2.03 seconds and the
second 0.09 seconds. A separate cold call to
`installed.packages(fields = "Priority")`, which the preflight caches, took
0.89 seconds; its immediate repeat was below the clock. This is a bounded
cold-session cost, not a data-scale cost.

The recorded 15.80 seconds reconciles without the cold preflight. Start with
the unprofiled 13.94-second validator, add about 0.09 seconds for the already
warm outer preflight and 0.09 seconds for `ledgr_strategy_source_info()`
(including its second warm preflight), then add the remaining unique measured
stages: approximately 15.65 seconds. The table contains inclusive wrappers and
must not be summed naively because `ledgr_strategy_source_info()` contains one
of the two preflight calls.

## 4. Dominant finding: scalar formatting in a data-scale validator

The dense/static sweep calls
`ledgr_precompute_validate_static_coverage()` at `R/sweep.R:246`. The function
at `R/precompute-features.R:301-326` correctly requires every instrument to
have a non-empty and identical timestamp axis.

The implementation derives each timestamp key through
`ledgr_precompute_ts_key()` at `R/precompute-features.R:328-330`:

```r
vapply(as.POSIXct(x, tz = "UTC"), ledgr_normalize_ts_utc, character(1))
```

`ledgr_normalize_ts_utc()` at `R/pulse-context.R:835-855` is a scalar
boundary validator and formatter. At this shape it is called 630,000 times.
Each call performs R dispatch, timestamp coercion, scalar validation,
`format.POSIXct()`, and character allocation merely to compare instants that
already came from a sealed snapshot.

Rprof agrees on the mechanism: the coverage validator and timestamp-key
function dominate captured setup samples, with `vapply()`, `format()`,
`format.POSIXct()`, `format.POSIXlt()`, and `as.POSIXct()` beneath them.

This is optimization-style shape 3: per-element work where a vector operation
exists. It violates the project's current hot-path rule to avoid R-level
iteration over collections that grow with bars or instruments times pulses.

## 5. Scaling and vector comparison probe

An unprofiled scaling probe ran the current validator over prefixes of the
same registered fixture:

| Instruments | Bars | Current wall seconds |
| ---: | ---: | ---: |
| 50 | 63,000 | 1.44 |
| 100 | 126,000 | 2.84 |
| 250 | 315,000 | 6.95 |
| 500 | 630,000 | 13.94 |

The curve is linear in bars. It is not quadratic, but its per-element R and
formatting constant is material.

A comparison prototype retained the same missing-instrument, empty-series,
length, order, and exact-axis checks but compared the numeric POSIXct epoch
vectors. Its inputs were already POSIXct, as they are after
`ledgr_precompute_fetch_bars()`; the 100-run micro-probe did not repeat the
current validator's redundant per-instrument `as.POSIXct()` coercion. One
hundred complete validations of all 630,000 bars took
0.49 seconds in total, or 0.0049 seconds each. The current validator and the
prototype both rejected a one-second mutation in the final timestamp of the
final instrument.

That is an approximately 2,800-fold mechanism difference for this fixture.
It is not yet an implementation result. The probe covered the registered
whole-second fixture and one deliberate misalignment; a production change
would need the semantic matrix in section 11.

The numeric route is plausible because snapshot sealing rejects sub-second
bars at `R/snapshots-seal.R:298-324`, and `ledgr_snapshot_open()` refuses a
snapshot whose status is not `SEALED` at `R/snapshots-list.R:212-218`. The
package contract is therefore whole-second UTC on the supported path. It must
nevertheless prove timezone-equivalent instants, class handling, missing
values, ordering, duplicates, and error behavior rather than assume them.

Two defensive semantics do differ under a naive numeric replacement. If both
axes contain `NA` at the same location, numeric `identical()` accepts them,
while the current scalar normalizer aborts. Supported persisted bars cannot
contain `NA` because `snapshot_bars.ts_utc` is `TIMESTAMP NOT NULL` at
`R/db-schema-create.R:259-269`, but a replacement validator must retain an
explicit fail-closed missing/non-finite guard. If two axes differ only within
the same second, the current `%Y-%m-%dT%H:%M:%SZ` formatting truncates the
difference and accepts them, while numeric comparison rejects them. Sealing
makes that case unreachable through supported entry points, but the stricter
direct-call behavior is a measured divergence that must be bound explicitly.

The dense-axis check itself is not redundant. A sealed snapshot need not be a
complete instrument by pulse rectangle. Only the scalar string materialization
is redundant.

## 6. Complexity findings

No quadratic cost is active in the registered setup/orchestration path.

Let `I` be instruments, `P` pulses, `B = I * P` bars, `F` unique features,
`C` candidates, and `W` feature window width.

| Work | Observed or structural complexity |
| --- | --- |
| bar query and split | `O(B)` after the ordered database query |
| current dense-axis validation | `O(B)` with scalar formatting |
| per-instrument re-sort | `O(I * P log P)` although input is ordered |
| bar matrices and pulse views | `O(B)` |
| vectorized feature preparation | normally `O(B * F)` |
| candidate resolution and tasks | approximately `O(C * features)` |

Two latent nonlinear paths exist outside the registered indicator shape:

1. `ledgr_compute_feature_series()` at `R/features-engine.R:247-284` creates
   and calls a data-frame window for every pulse when a feature has no
   `series_fn`. It is `O(I * P * W)` and becomes quadratic in pulses when
   `W` grows with `P`.
2. `ledgr_compute_feature_series_strict()` at
   `R/features-engine.R:286-344` has the same window-copying shape and can run
   both scalar and series functions for every complete window.

The registered TTR indicators provide series functions, so the two feature
stages together measured 1.01 seconds and did not activate those nonlinear
fallbacks. The fallback finding is a future feature-path design concern, not
evidence that it caused the current setup result.

## 7. Secondary inefficiencies

The remaining measured costs are small but show repeated representation work:

- DuckDB returns bars ordered by `(instrument_id, ts_utc)` at
  `R/precompute-features.R:274-298`; `ledgr_sweep_normalize_bars_by_id()` then
  sorts every instrument again at `R/sweep.R:2236-2249`.
- Bars move through ordered query rows, split data frames, field matrices, one
  combined data frame, and finally pulse data frames.
- Feature values move through per-instrument vectors in a payload list and are
  then copied into matrices by `ledgr_projection_from_payload()` at
  `R/runtime-projection.R:74-120`.
- Strategy preflight runs once explicitly at `R/sweep.R:176` and again through
  `ledgr_strategy_source_info()` at `R/strategy-provenance.R:59-78`.

These are real inefficiencies, but the measured evidence does not justify
treating them as release-material individually. After the coverage fix, their
combined importance must be remeasured rather than inferred from source shape.

## 8. collapse and DuckDB

Neither dependency is the primary answer to the dominant cost.

Base R can compare the already materialized POSIXct epoch vectors directly.
Using collapse for that check would add machinery without improving its
asymptotic or practical shape.

Possible later collapse uses include `gsplit()` for grouping, `fmatch()` for
instrument indexing, and vectorized rolling implementations for standard
features. The measured fetch, normalize, matrix, and pulse-view stages together
leave only a few tenths of a second at this fixture, so replacing them before
remeasurement would be optimization theater.

DuckDB already filters and returns all 630,000 ordered bars in 0.10 seconds.
A SQL check need not be complex: one aggregate can compare the selected
instrument count and total rows with the product of distinct instruments and
distinct timestamps, relying on the snapshot primary key to exclude duplicate
pairs. The reason not to prefer it is narrower: the vectors are already
materialized for the sweep and their direct comparison costs about five
milliseconds, so SQL cannot improve the wall meaningfully and would split the
coverage proof across query and R code. Per-pulse database work would be a
regression. Moving general feature functions into SQL would also fork the
existing feature contract for a stage that currently costs about one second.

## 9. Candidate optimization order

This is an observation order, not an accepted implementation plan:

1. Replace per-timestamp string normalization in the dense-axis validator with
   one vectorized instant comparison per instrument.
2. Preserve every fail-closed condition and the current classed coverage
   error; do not remove the rectangle check.
3. Rerun the public canonical and compiled sweep rows from accepted source.
4. Pass the already computed preflight into strategy source capture within the
   same sweep call.
5. Remeasure before considering feature payload/matrix fusion, redundant sort
   removal, collapse grouping, or prepared-snapshot caching.
6. Route scalar-feature fallback complexity to a separate feature-path
   decision. Plausible choices include requiring or strongly preferring a
   `series_fn` at data scale, optimized standard rolling features, and an
   explicit work estimate or warning for large `I * P * W` shapes.

A reusable prepared-snapshot cache could help many repeated sweeps, but it
would introduce identity, invalidation, memory, and worker-transfer questions.
The current evidence does not require it to solve the measured regression.

## 10. Orientation, not a performance promise

Subtracting the observed validator cost from the corrected public rows gives a
useful order-of-magnitude check only:

| Public row | Recorded warm | Orientation after dominant fix |
| --- | ---: | ---: |
| canonical sweep | 44.84 s | about 30 to 31 s |
| compiled spot-FIFO sweep | 30.38 s | about 16 to 17 s |

The corresponding cold orientations are about 50 to 51 seconds and 35 to
36 seconds because snapshot preparation remains outside the reusable warm
iteration. These numbers are arithmetic projections, not acceptance targets,
benchmarks, or release claims. Only a fresh record run after an accepted and
reviewed implementation could establish them.

The canonical fold itself is 29.01 seconds in the current record, so setup
cleanup alone cannot make that row materially faster than about 30 seconds.
Further canonical improvement would require a measured engine-path finding.

## 11. Minimum semantic matrix for any implementation

An accepted change would need tests showing that the old and new validation
decisions agree for at least:

- complete aligned daily, minute, and second axes;
- one missing instrument;
- an empty instrument series;
- unequal axis lengths;
- a missing middle timestamp;
- one duplicated timestamp;
- one reordered timestamp;
- one shifted timestamp at the beginning, middle, and end;
- POSIXct vectors with different timezone attributes representing the same
  instants;
- aligned `NA` values rejected explicitly rather than accepted by numeric
  `identical()`; persisted bars remain protected independently by the
  `TIMESTAMP NOT NULL` schema;
- other missing and non-finite timestamp input rejected fail-closed;
- the measured sub-second divergence bound deliberately: the current formatted
  key accepts axes that differ only below one second, numeric comparison
  rejects them, and supported entry points independently reject such bars at
  seal before `ledgr_snapshot_open()` accepts the snapshot;
- the existing error class and fail-closed behavior; and
- identical public sweep outputs for canonical and compiled accounting.

The post-change record should report the coverage-validator clock separately
from total setup/orchestration and should preserve the public boundary defined
in `results-path-and-benchmark-boundary-note.md`.

## 12. Questions for adversarial review

1. Does the wrapper evidence support the attribution despite incomplete
   Windows Rprof capture?
2. Is any material work missing from the setup/orchestration inventory?
3. Does numeric POSIXct comparison preserve the current whole-second UTC
   contract, or is a vectorized canonical-string comparison required?
4. Is the dense-axis validation enforcing a property not captured by the
   proposed semantic matrix?
5. Is there an active quadratic or super-linear cost in the registered path
   that this note missed?
6. Would a DuckDB-side check be simpler, safer, or faster for a reason not
   considered here?
7. Are the runtime orientations arithmetically and methodologically honest?
8. Does the confirmed production cost justify a v0.2.0.1 amendment, or should
   the release preserve the current result and route the fix to the next
   optimization cycle?

## 13. Scope boundary

This note changes no contract, source, dependency, ticket, batch status,
benchmark evidence, or release gate. It does not authorize broad loop cleanup,
a prepared-snapshot cache, a feature API change, or moving feature execution
into DuckDB.

The adversarial reviewer recommended parking implementation for the next
optimization cycle: the current record is honest, the public-boundary harness
correction remains uncommitted, and this review found defensive timestamp
semantics that need a proven matrix before production changes. The maintainer
has not yet accepted or rejected that scope recommendation.

Batch 11 should still treat the measured opportunity as a release-claim
constraint. The package may report the recorded public row literally, but it
should not generalize the current setup share as an intrinsic cost of ledgr
when a known, unexercised vector replacement removes most of that mechanism.
Governance work begins only if the maintainer accepts a reviewed recommendation
to change the current release scope.
