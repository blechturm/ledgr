# v0.1.8.3 Residual Hot-Path Report

**Status:** Final LDG-2414 measurement pass.
**Measured commit:** `e1820d7`
**Measured at:** 2026-05-25T20:42:05Z

This report is the post-LDG-2413 evidence handoff for the remaining
v0.1.8.3 optimization decisions. It compares the LDG-2402 baseline against
the final post-change protocol run, records prebuilt pulse-view memory evidence,
and recommends the disposition of LDG-2410 typed memory events and LDG-2412
single-pass sweep summary reconstruction.

## Wall-Clock Result

| workload | path | baseline | post-change | result |
| --- | --- | ---: | ---: | ---: |
| smoke_3_candidates | sweep_plain | 1.320s | 1.190s | 1.11x faster |
| smoke_3_candidates | sweep_precomputed | 1.000s | 0.680s | 1.47x faster |
| smoke_3_candidates | run_loop | 5.245s | 5.440s | 3.7% slower |
| reference_50_candidates | sweep_plain | 45.585s | 30.275s | 1.51x faster |
| reference_50_candidates | sweep_precomputed | 45.490s | 30.525s | 1.49x faster |
| wider_feature_payload | sweep_plain | 65.360s | 33.405s | 1.96x faster |
| wider_feature_payload | sweep_precomputed | 65.345s | 33.100s | 1.97x faster |
| persistent_comparison | sweep_plain | 4.415s | 3.025s | 1.46x faster |
| persistent_comparison | run_loop | 9.420s | 8.650s | 1.09x faster |
| metric_context_non_default | sweep_plain | 4.350s | 3.010s | 1.45x faster |
| metric_context_non_default | sweep_precomputed | 4.315s | 3.300s | 1.31x faster |

The cycle now delivers a material wall-clock improvement on the target sweep
workloads. The reference workload improved from 45.585s to 30.275s
(`sweep_plain`) and from 45.490s to 30.525s (`sweep_precomputed`). The wider
feature-payload workload improved by almost 2x, which is the clearest evidence
that runtime projection plus prebuilt static pulse views paid off where the
feature/context surface is larger.

The repeated `ledgr_run()` watch item is no longer a material regression on the
persistent comparison workload: 9.420s baseline to 8.650s post-change. The small
smoke run-loop regression is 0.195s across three small runs and is not the
release-blocking shape that appeared at the LDG-2409 checkpoint. The smoke
run-loop regression of 3.7% is accepted as a small-workload setup-cost artifact:
prebuilt views have fixed setup cost, and ledgr's optimization target is sweep
and wider fold workloads where that setup is amortized.

Standalone precompute timings are slightly slower in the small absolute sense
(for example 0.280s to 0.310s on the reference workload), but the sweep paths
that consume the precompute are materially faster. This is acceptable for
v0.1.8.3 because the optimization target is fold/runtime execution, not the
sub-second preparation call in isolation.

## Residual Profile

The final reference Rprof profile records:

| frame | total.pct | interpretation |
| --- | ---: | --- |
| `ledgr_execute_fold` | 70.1% | fold still dominates, but less than the 79.8% baseline sample |
| `output_handler$run_transaction` / `fn` | 63.8% | event execution and strategy callback boundary dominate remaining time |
| `data.frame` | 22.2% | mostly event-row / output-buffer data-frame boundaries now |
| `ledgr_fills_from_events` | 20.6% | post-fold fill reconstruction is now material |
| `ledgr_fill_event_row` | 18.2% | typed memory events target this path |
| `output_handler$buffer_event` | 15.9% | typed memory events target this path |
| `handler$append_event_rows` | 15.8% | typed memory events target this path |
| `as.data.frame` | 15.6% | mostly output/event-row boundary work |

The profile no longer shows `ledgr_features_wide()`,
`ledgr_projection_features_wide()`, or `ledgr_projection_pulse_views()` as
dominant top frames. Fast context B1 also moved helper churn out of the top
frames; `ledgr_update_fast_pulse_context_helpers()` appears in the by-self
profile at 2.6%, not as the 20-30% wall seen before B1.

The fold share moved from 79.8% in the LDG-2402 baseline sample to 70.1% in
the final post-change sample. That 10 percentage point reduction confirms the
structural intent of LDG-2408, LDG-2409, LDG-2411, and LDG-2413: move
pulse-context feature/view work out of the hot fold loop and expose the next
dominant bottleneck.

The dominant remaining inefficiency pocket is therefore not pulse-context view
construction. It is memory event output and downstream fill reconstruction:
small data-frame rows are still built, appended, rebound, and replayed after
the fold.

## Prebuilt Pulse-View Memory Evidence

Measured with `dev/spikes/ledgr_v0_1_8_3_sweep_optimization/measure_memory.R`.
Values are `utils::object.size()` bytes, so they are object-size evidence rather
than a process RSS peak.

| workload | bars views | projection | median candidate feature views | retained peak proxy |
| --- | ---: | ---: | ---: | ---: |
| reference_50_candidates | 737,904 | 205,768 | 887,504 | 1,967,800 |
| wider_feature_payload | 2,137,008 | 569,304 | 3,984,080 | 7,471,256 |
| persistent_comparison | 737,904 | 205,768 | 887,504 | 1,967,800 |

The current workloads have no material memory pressure from prebuilt pulse
views. The retained peak proxy is about 1.9 MB for the reference workload and
about 7.5 MB for the wider feature-payload workload. Candidate feature views
are built per candidate and are not retained across all candidates in the
current fold path; the summed construction churn is higher, but retained memory
is small at v0.1.8.3 scale. Actual retained memory is much lower than the
earlier worst-case synthesis estimate because the implementation constructs
candidate feature views one candidate at a time instead of retaining all
candidate views across the sweep. That is useful prior evidence for wider
parallelism-scale workloads: the relevant near-term planning number is closer
to per-worker retained view memory than to a whole-grid retained-view sum.

Out-of-core projection and DuckDB-backed precompute storage remain future
scaling/storage work, not the next measured optimization slice.

## Deferred Candidate Review

Lazy `ctx$features_wide`: defer. The wide-view construction path is no longer
dominant after LDG-2413, and public fresh data-frame semantics are preserved by
prebuilt per-pulse views. Lazy context fields would add contract complexity
without attacking the current top frames.

Persistent-path single-pass reconstruction: defer as a separate persistent-path
unification item. The persistent sweep path is faster than baseline and the
remaining sampled reconstruction hotspot is the memory sweep
`ledgr_fills_from_events()` path, not persistent DB replay.

Strategy bytecode compilation: dismiss for v0.1.8.3. The reference one-rep
check measured plain strategy execution at 34.09s and `compiler::cmpfun()` at
35.68s. The strategy hash remained identical in the check, but there is no
measured benefit.

`ctx$flat()` / `ctx$hold()` allocation: dismiss for this cycle. These helpers
do not appear as material sampled frames after LDG-2413. Revisit only if a
future strategy-usage profile makes them visible.

DuckDB-backed precompute storage / out-of-core projection: defer. The current
bottleneck is R event buffering and fill reconstruction, not feature storage or
memory scaling. Keep the accepted v0.1.8.6 horizon direction.

Parallel dispatch: defer. Serial fold/runtime now has a cleaner measured
baseline, but the next single-core bottleneck is still large enough to address
before worker scheduling is the dominant question.

## LDG-2410 / LDG-2412 Disposition Recommendation

Retain LDG-2410 in v0.1.8.3. The profile now strongly supports typed memory
events: `ledgr_fill_event_row()`, `output_handler$buffer_event()`,
`handler$append_event_rows()`, `data.frame`, `as.data.frame`, and
`ledgr_fills_from_events()` are all visible top frames. A typed in-memory event
representation is the measured next R-level slice.

Keep LDG-2412 conditionally behind LDG-2410. The single-pass summary work should
not be implemented blindly as a broad reconstruction rewrite. After typed
memory events land, rerun a targeted profile:

- if `ledgr_fills_from_events()` / equity-fills metric derivation remains a
  material top frame, keep LDG-2412 as the next implementation ticket;
- if typed memory events collapse the reconstruction share enough that other
  frames dominate, defer LDG-2412 to v0.1.9 and document the deferral in the
  release closeout.

This keeps the cycle measurement-driven while still allowing the original
typed-events -> single-pass path to proceed if the evidence continues to hold.

## Next Slice

The next optimization slice is LDG-2410 typed memory events, scoped tightly to
the memory output handler and event-row boundary. Do not start DuckDB-backed
projection, parallel dispatch, lazy context fields, or strategy bytecode
compilation before typed memory events are measured.
