# Diagnostic records: spike charter

- Asked by the maintainer on 2026-11-09: store exceptions plus a per-pulse
  hold count, so explanations work without running code; no DuckDB write
  during the run, one write at the end; a strict no-analytics path for sweeps.
- Binding: `inst/design/spike_protocol.md`. Binds nothing; feeds an RFC
  amendment or a ticket. Authority it must respect: the per-pulse records
  synthesis (`inst/design/rfc/rfc_per_pulse_durable_records_v0_2_3_synthesis.md`,
  accepted 2026-11-03): the logical trace stays exactly today's; a row may be
  left out physically only if its presence, fields and sequence position
  rebuild exactly; no read runs strategy code.
- Probe: `probe.R`, `probe_findings.md`. Clean holds are 73-84% of the trace
  on larger runs; building diagnostics costs 11-25% of a committed run and
  16-29% of a sweep candidate that keeps 0-108 of up to 699,040 rows; the only
  in-fold DuckDB write is the implicit-row chunk flush (4% of 500 x 1,260).

## Question

Can the fold build only the diagnostic rows some reader needs, keep them in
memory and write once after the last pulse, while `ledgr_results(bt,
"diagnostics")`, `ledgr_run_explain()` and `summary()` return exactly
today's rows, and what does that save in a committed run and a sweep
candidate?

"Rows some reader needs": on a durable store, every row except clean holds,
which become one count per decided pulse; in a sweep candidate, only the rows
its memory filter keeps today (`ledgr_memory_diagnostic_keep`). Both come from
one fold: the sink states once, at fold entry, which row kinds it keeps; the
fold builds nothing else. No execution-mode branch, no economic change.

## Prerequisite (answered first, no fold change)

Does every clean-hold row rebuild exactly, all fields and `diagnostic_seq`,
from the run's ledger events, the snapshot's bars and facts, the run config
and at most a few integers per decided pulse? Method: on pinned stores of the
probe workloads, delete the implicit hold rows, rebuild them in a reader, and
compare the decoded trace with the original.

## Kill conditions

- Prerequisite: a hold field or sequence position that needs more than a few
  integers per decided pulse to rebuild on any probe workload. Stop and
  report; the answer is "keep hold rows, compact them".
- Main question: any difference in the decoded trace, explain rows, summary,
  ledger, equity or sweep result against the pin; or a saving below 5% of
  the committed run on both crossover workloads.

## Stages

1. Prerequisite: reader rebuild on pinned stores (`rebuild.R`).
2. Fork: the fold builds only kept kinds, holds them in memory, writes once
   at the end (`fork.R`, bindings swapped as the lean core does), with the
   rebuilding reader from stage 1. Runner, diff checker, one gutted path.

Out of scope: clean fills (the fills reader reads execution diagnostics; the
synthesis Section 4 circularity), the reconciliation and sizing rows (kept
explicit), opt-in diagnostics, rerun-based explanation, H1 until stage 2
passes on the portable workloads.
