# Fold-Loop Diagnostic Profile

Date: 2026-05-30T12:16:24Z
Package version label: `0.1.8.7` loaded from current source.
Git: `7cfea59bdfae310f690db4c18cc4bd87a37e9205` on `v0.1.8.8`.

Scope: LDG-2470 / v0.1.8.8 Batch 2. This is current-source, local-host,
machine-specific diagnostic evidence. It is not an optimization claim and
does not authorize implementation work.

Raw samples: `dev/bench/results/fold_loop_diagnostic_record_20260530T121624Z_samples.csv`
Raw summary: `dev/bench/results/fold_loop_diagnostic_record_20260530T121624Z_summary.csv`

Method: run selected durable ledgr scenarios with `control$telemetry_stride = 1`
and summarize sampled wall-clock buckets recorded inside `ledgr_execute_fold()`.
Bucket totals are diagnostic attribution numbers; the `unattributed_loop` row is
`t_loop` minus measured bucket totals and includes loop overhead, checkpoint checks,
telemetry overhead, and uninstrumented code.
`loop_share` is share of `t_loop`, not share of full wall time; `wall_sec` also
includes setup, feature precompute, durable reconstruction, and teardown.
Buckets below the timer floor may round to `0.0000` even though work occurred.

| Scenario | Bucket | Total s | Loop share | Boundary |
| --- | --- | ---: | ---: | --- |
| `peer_sma_crossover` | `target_order_conversion` | 10.1100 | 34.6% | Normalize/validate strategy targets, apply current no-op risk layer, compute per-instrument deltas, select next bars, and create fill proposals. |
| `peer_sma_crossover` | `event_emission` | 8.0600 | 27.6% | Emit ordered fill events through the active output handler. |
| `peer_sma_crossover` | `unattributed_loop` | 6.6900 | 22.9% | t_loop minus measured bucket totals; includes for-loop overhead, checkpoint checks, telemetry overhead, and any uninstrumented code. |
| `peer_sma_crossover` | `bar_read_and_mark_to_market` | 2.9300 | 10.0% | Read current bars view and mark existing positions to current close prices. |
| `peer_sma_crossover` | `fill_resolution` | 0.5800 | 2.0% | Resolve fill proposals through the cost resolver and validate fillability. |
| `peer_sma_crossover` | `state_update` | 0.5000 | 1.7% | Apply cash/position changes and persist or buffer strategy state updates. |
| `peer_sma_crossover` | `context_build` | 0.2500 | 0.9% | Construct ledgr_pulse_context and attach slow/fast helper accessors. |
| `peer_sma_crossover` | `strategy_callback` | 0.1000 | 0.3% | Call strategy_fn(ctx, params) through the configured strategy-call wrapper. |
| `peer_sma_crossover` | `feature_view_read` | 0.0000 | 0.0% | Read precomputed feature_table/features_wide pulse views and replace absent views with empty frames. |
| `wide_panel_no_features` | `unattributed_loop` | 1.0200 | 43.6% | t_loop minus measured bucket totals; includes for-loop overhead, checkpoint checks, telemetry overhead, and any uninstrumented code. |
| `wide_panel_no_features` | `target_order_conversion` | 0.9800 | 41.9% | Normalize/validate strategy targets, apply current no-op risk layer, compute per-instrument deltas, select next bars, and create fill proposals. |
| `wide_panel_no_features` | `bar_read_and_mark_to_market` | 0.3300 | 14.1% | Read current bars view and mark existing positions to current close prices. |
| `wide_panel_no_features` | `context_build` | 0.0100 | 0.4% | Construct ledgr_pulse_context and attach slow/fast helper accessors. |
| `wide_panel_no_features` | `event_emission` | 0.0000 | 0.0% | Emit ordered fill events through the active output handler. |
| `wide_panel_no_features` | `feature_view_read` | 0.0000 | 0.0% | Read precomputed feature_table/features_wide pulse views and replace absent views with empty frames. |
| `wide_panel_no_features` | `fill_resolution` | 0.0000 | 0.0% | Resolve fill proposals through the cost resolver and validate fillability. |
| `wide_panel_no_features` | `state_update` | 0.0000 | 0.0% | Apply cash/position changes and persist or buffer strategy state updates. |
| `wide_panel_no_features` | `strategy_callback` | 0.0000 | 0.0% | Call strategy_fn(ctx, params) through the configured strategy-call wrapper. |

Interpretation: keep these rows as profiler guidance. Future collapse,
primitive-internal, or compiled-core work still needs its own ticket, profile,
and parity gates.
