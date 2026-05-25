# Pulse View Construction Spike

This spike benchmarks candidate implementations for LDG-2413 pulse-view
construction before ledgr commits to an added dependency or a specific
construction pattern.

The question is narrow:

- Can `ctx$bars`, `ctx$feature_table`, and `ctx$features_wide` data-frame views
  be built faster by constructing one indexed table and splitting/nesting by
  `time_index`?
- Is base R good enough, or do packages such as `data.table`, `collapse`,
  `dplyr`, or `tidyr` materially improve the construction path?
- Do candidate implementations preserve the current data-frame schema?

Run from the repository root:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/ledgr_v0_1_8_3_pulse_view_construction/run_pulse_view_construction_spike.R --reps=5
```

The script writes CSV results and a short Markdown report to:

```text
inst/design/spikes/ledgr_v0_1_8_3_pulse_view_construction/
```
