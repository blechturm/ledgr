# WS17 strategy-state cost record

This record measures the accepted cursor/checkpoint implementation; it does
not claim the future storage architecture parked in the horizon. Run from the
package root with:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_3_strategy_state/run_record.R `
  dev/bench/v0_2_3_strategy_state/evidence/current
```

The four 500-pulse dense runs share one constant-price snapshot. Two additional
100-pulse runs use 500 instruments and four asset fields: one never changes
state and one changes all four fields on every pulse. `cursor_rows`
counts durable completion cursors. `payload_encodes` is the number of rows that
contain a typed checkpoint rather than the constant marker; the implementation
has exactly one encoder call per such row. Byte counts are UTF-8 bytes stored in
`strategy_state.state_json`. Wall time is descriptive and is not a release gate.

## Seven-shape review

- Length growth: state vectors are prepared or aligned once; no vector grows in
  a pulse loop.
- Repeated concatenation: the fold writes one scalar row per completed pulse;
  the codec builds one fixed-size field list only when state changes.
- Full-axis work per pulse: asset-state equality and checkpoint encoding are
  necessarily proportional to the declared asset fields and current axis;
  unchanged portfolio-only state performs no axis scan beyond `identical()`.
- Serialization and hashing: declarations enter configuration identity once;
  runtime validation does not encode, and unchanged pulses use a constant marker.
- Query shape: resume performs one latest-cursor query and one preceding-payload
  query, never one query per pulse.
- Copies and frames: pulse views copy declared atomic values to isolate
  fold-owned state from by-reference user mutation; the fold retains one
  complete typed state and creates no per-pulse data frame.
- Repeated invariant preparation: declarations are validated and their typed
  default scalars are prepared once per candidate; pulse work consumes both.

The state view deliberately copies each declared atomic vector before it is
handed to user code. Ordinary R copy-on-modify already freezes a saved view;
this bounded copy prevents a strategy's by-reference mutation from modifying
fold-owned state outside its returned update. It is an isolation cost measured
by the wide cells, not accidental conversion or data-frame materialization.

Restoring an every-pulse state encode/write is detected by LTB-0534: no-state,
declared-unchanged and raw-identical runs must contain only the marker and the
mocked encoder must be called exactly once for the one genuinely changed state.
