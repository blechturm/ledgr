# Workstream 41 fixture ladder

The registered real-data-scale fixture runner compared the accepted
Workstream 40 tree `e3f822a53d51a4cd70e7c256428f32d2ffc3dec1` with the
final Workstream 41 candidate immediately before its implementation commit.
Both arms used Windows x64, R 4.6.1, 800 instruments, 1,260 sessions and 300
members, and ran all ten public-cycle phases.

The first candidate record exposed an unauthorized walk-forward change:
`wf_scores` differed because the window-local pulse index addressed the
full-axis feature projection. The correction retains the one shared substrate
but masks feature calculation before the current scoring start and translates
each local pulse to its full projection column. Restoring the local lookup
fails LTB-0296.

The corrected comparison reports 50 of 50 gated families byte-identical and
the informational identity family identical. The checker's self-test perturbs
each family independently and detects 51 of 51. This proves that WS41 does not
prematurely adopt LDG-3064's later continuous-window start rule.

Reproduction commands:

```text
Rscript dev/bench/v0_2_2_real_data_scale/run_record.R <base> <base-record> --lane=fixture
Rscript dev/bench/v0_2_2_real_data_scale/run_record.R . <candidate-record> --lane=fixture --allow-dirty
Rscript dev/bench/v0_2_2_real_data_scale/check_record.R <base-record> <candidate-record>
Rscript dev/bench/v0_2_2_real_data_scale/check_record.R <candidate-record> --self-test
```

Full temporary family records were removed after comparison. `summary.csv`
retains the inputs, measured phase totals and exact checker outcomes without
copying the deterministic families already covered by the runner and tests.
