# Workstream 43 indicator history evidence (LDG-3065 to LDG-3067)

Synthetic, vendor-neutral records for
`inst/design/ledgr_v0_2_2_spec_packet/indicator_history_closeout.md`. No
private vendor data is used. Environment: R 4.6.1, TTR 0.24.4, Windows
x86-64, 24 logical cores, 64 GB RAM.

## Files

- `evidence/catalogue_certification.csv`: per catalogue row and fixture, the
  maximum scaled difference between the full-series value and the value from
  a window of exactly `requires_bars` rows (`scripts/cert_drift.R <tree>
  <out.csv>`). LTB-0308 is the registered detector; this file only records
  the drift.
- `evidence/mutations_ldg3065.csv`, `evidence/mutations_ldg3066.csv`: each
  source-copy mutation, the registered block expected to fail, the blocks
  that failed and whether the expected blocks were detected. Specifications:
  `scripts/mut3065.R`, `scripts/mut3066.R`. Every mutation runs in a fresh
  copy of the tracked and new source files so worker daemons load the
  mutated source.
- `evidence/scale_results.csv`: feature preparation for one causal-history
  substrate (`scripts/scale.R <tree> <label> <config> <instruments>
  <sessions> <out.csv>`) on the pre-cut tree `a915ba66` (via `git archive`)
  and on this workstream. `parity` uses gappy bars without lifetime facts,
  `price_carry = NULL` and the four definitions the pre-cut tree admits;
  `realistic` adds lifetime intervals (one in six learned ten sessions late),
  the default policy and fourteen definitions including TTR multi-output and
  history-dependent rows; `ttr_sma` times a single TTR SMA(20). `max_mb` is
  the R heap peak reported by `gc()` over substrate plus preparation.
- `evidence/mutations_ldg3067.csv`: the LDG-3067 causality-check mutations
  (`scripts/mut3067.R`). `scripts/mutate.R <spec.R> <name|all> <out.csv>
  [worktree]` runs any of the specifications; a mutation may carry several
  edits. Set `LEDGR_MUTATION_SCRATCH` to choose where source copies go.
- `evidence/checker_scale.csv`: one feature preparation with the sampled
  causality check timed inside it (`scripts/checker_scale.R <tree> <label>
  <config> <instruments> <sessions> <out.csv>`, the `realistic` panel and
  fourteen definitions of `scale.R`), for one instrument over 252 to 16,128
  sessions and for 1,166 instruments over 252 to 7,213 sessions.
- `evidence/mutations_ldg3067b.csv`: follow-up mutations for Cut 16
  decision (18) and the history-frame feature evidence
  (`scripts/mut3067b.R`).
- `evidence/planes_scale.csv`: retained feature evidence planes for one
  preparation (`scripts/planes_scale.R <tree> <label> <realistic|realistic_output>
  <instruments> <sessions> <out.csv>`): exception counts and bytes against
  the value matrices, projection indexing and a full-window read.
- `evidence/return1_run.csv`: a public availability run of `return_1`
  (`scripts/return1_run.R`), with the number of per-window `fn` calls.

## Measurement conditions

Runs were sequential, one R process at a time, on a host shared with other
sessions; timings are disclosure, not gates. The timed fast, review and heavy
profiles were not run (the coordinator runs them on a quiet host).
