# v0.1.8.3 Residual Hot-Path Report

**Status:** Final post-LDG-2412 measurement pass.
**Measured commit:** `ac09d75` plus the LDG-2412 working tree patch.
**Measured at:** 2026-05-25T21:59:21Z

This report is the v0.1.8.3 sweep-optimization closeout. It compares the
LDG-2402 baseline against the post-LDG-2412 checkpoint, records the persistent
`ledgr_run()` variance recheck, and identifies the remaining measured hot path
after projection, fast context, prebuilt views, typed memory events, and
single-pass sweep summary reconstruction.

## Wall-Clock Result

| workload | path | baseline | post-LDG-2412 | result |
| --- | --- | ---: | ---: | ---: |
| reference_50_candidates | sweep_plain | 45.585s | 13.220s | 3.45x faster |
| reference_50_candidates | sweep_precomputed | 45.490s | 12.945s | 3.51x faster |
| wider_feature_payload | sweep_plain | 65.360s | 12.130s | 5.39x faster |
| wider_feature_payload | sweep_precomputed | 65.345s | 12.055s | 5.42x faster |
| persistent_comparison | sweep_plain | 4.415s | 1.350s | 3.27x faster |
| persistent_comparison | run_loop | 9.420s | 7.960s | 1.18x faster |

The cycle now closes with a material product win. The reference sweep workload
improved from 45.585s to 13.220s, and the wider feature-payload workload
improved from 65.360s to 12.130s. The wider workload is the release-headline
result because it better represents the larger feature/context surfaces this
cycle was designed to unlock.

The repeated `ledgr_run()` watch item is also resolved. A 5-rep persistent
variance recheck measured `run_loop` at 7.96s median versus the 9.420s
LDG-2402 baseline. The earlier 8.875s two-rep checkpoint was sample variance,
not a path regression.

## Residual Profile

The final reference Rprof profile records:

| frame | total.pct | interpretation |
| --- | ---: | --- |
| `ledgr_execute_fold` | 84.6% | fold execution is again the dominant remaining slice |
| `output_handler$run_transaction` / `fn` | 71.7% | strategy callback boundary and event execution dominate |
| `ledgr_update_fast_pulse_context_helpers` | 14.4% | residual context refresh work |
| `output_handler$write_fill_events` | 13.6% | remaining typed event write overhead |
| `[.data.frame` | 12.5% | residual data-frame boundary work |
| `ledgr_projection_pulse_views` / `ledgr_split_pulse_data_frame` | 11.3% / 11.2% | setup-time pulse-view construction, not the per-pulse hot loop |

`ledgr_equity_from_events()` and `ledgr_fills_from_events()` no longer appear
in the top sampled frames after LDG-2412. That confirms the typed-events plus
single-pass reconstruction sequence removed the measured post-fold summary
bottleneck.

The fold share increased from 63.9% after LDG-2410 to 84.6% after LDG-2412 not
because fold execution regressed, but because the post-candidate reconstruction
slice collapsed. The next optimization slice is no longer summary
reconstruction; it is residual fold/runtime work.

## Memory Evidence

The LDG-2414 object-size measurements remain the relevant memory evidence for
prebuilt pulse views:

| workload | bars views | projection | median candidate feature views | retained peak proxy |
| --- | ---: | ---: | ---: | ---: |
| reference_50_candidates | 737,904 | 205,768 | 887,504 | 1,967,800 |
| wider_feature_payload | 2,137,008 | 569,304 | 3,984,080 | 7,471,256 |
| persistent_comparison | 737,904 | 205,768 | 887,504 | 1,967,800 |

The current workloads have no material retained-memory pressure from prebuilt
pulse views. Candidate feature views are built per candidate and are not
retained across the whole grid. DuckDB-backed precompute storage and out-of-core
projection remain future scaling/storage work, not a v0.1.8.3 release blocker.

## Disposition

LDG-2410 typed memory events shipped and paid off. It removed the memory path's
`meta_json` serialization/parsing loop and exposed fill reconstruction as the
next measured slice.

LDG-2412 single-pass summary reconstruction shipped and paid off. It removed
the redundant equity/fill FIFO replay passes from the sweep memory path and
made post-fold reconstruction sub-dominant.

Lazy `ctx$features_wide`: defer. The wide-view path is no longer a top frame
after prebuilt pulse views and single-pass reconstruction.

Persistent-path single-pass reconstruction: defer. The persistent sweep and
run-loop paths are faster than baseline, and the measured hot path is no longer
persistent DB reconstruction.

Strategy bytecode compilation: dismiss for v0.1.8.3. The measured check showed
no benefit.

DuckDB-backed precompute storage / out-of-core projection: defer to the accepted
horizon direction. Current v0.1.8.3 bottlenecks are not storage pressure.

Parallel dispatch: defer. The single-core baseline is now much cleaner; worker
scheduling should start from the post-LDG-2412 profile, not the LDG-2402
baseline.

## Next Slice

The v0.1.8.3 optimization implementation is complete. The next step is the
LDG-2415 release gate:

- run full test suite and release checks;
- update release notes with the 3.45x reference and 5.39x wider-workload
  numbers;
- preserve the post-LDG-2412 profile as the baseline for future parallel,
  DuckDB-backed storage, primitive-internals, or Rust-port planning.
