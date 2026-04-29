# Interactive Strategy Development

Full content in v0.1.3.

This vignette outline shows how to inspect a single pulse, prototype indicators
against sealed snapshot data, and move an interactive strategy unchanged into
the default runtime context.

## Outline

- Inspect indicator windows with `ledgr_indicator_dev()`
- Freeze a decision point with `ledgr_pulse_snapshot()`
- Validate bars and feature context shape
- Run the same `function(ctx, params)` strategy through `ledgr_experiment()` and
  `ledgr_run()`
- Keep interactive tools read-only
