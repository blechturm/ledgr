# Diagnostic records: closeout

**Outcome: green for sweeps, green for correctness of the durable design,
inconclusive on its speed.** Charter kill clause "a saving below 5% of the
committed run on both crossover workloads": on the pulse loop, against lean
P3, crossover 10 x 7,200 saves 1% and 500 x 1,260 saves 6%, so the clause
does not trip; the whole-run wall got slower only through the spike's
reader, which a product design would not have.

## What ran (pin d5b3a151, lean P3 at 724d522c)

- `probe.R`: what the pin records, writes and spends (`probe_findings.md`).
- `rebuild.R`: stage 1, clean holds rebuilt on pinned stores.
- `fork.R sweeps|a0`: stage 2a, the staging functions build only rows the
  sink keeps. `fork.R runs`: stage 2b, a committed run stores one hold count
  per pulse instead of hold rows, buffers all diagnostics in memory and
  writes once after the last pulse; `reader.R` rebuilds the holds into
  ledgr's one logical-trace view.
- `check.R`: reruns into scratch, diffs every correctness column, guards
  package scope (`--small`: CHECK PASS, 2026-11-09).

## What was learned about the package

1. Clean holds are 73-84% of the trace on larger runs and rebuild exactly
   from the ledger, the bar closes, the configured axis (or the
   `availability` view for membership) and sequence gaps; each pulse ends
   with a stored row, so a gap's pulse is the next stored row's. One
   certified count per pulse is enough to refuse a corrupt store.
2. Sweeps paid most: every candidate expanded every diagnostic row and its
   memory filter kept 0-108 of up to 699,040. Building only kept rows makes
   one-candidate sweeps 10-26% faster than the pin, identical results on six
   workloads and all A0 paths (`fork_sweeps.csv`, `fork_a0.csv`).
3. Durable runs without hold rows: identical results, explain, summary and
   tables on five workloads; stored implicit rows down 89% (629,946 to
   67,725 on 500 x 1,260); no DuckDB write inside the loop; a hold count one
   short is refused as `ledgr_diagnostic_corrupt` (`fork_runs*.csv`).
4. The loop barely gets faster from not storing holds (1-6% against lean
   P3): the fold still builds them, and in R its diagnostic cost is per call,
   not per row. The remaining per-pulse diagnostic calls are P2's decision
   segment, P3's clean checks and block, and P5's reconciliation row and
   pulse flush, on every pulse.
5. The read side becomes the cost: the spike's R rebuild, registered as a
   data frame and queried by the end-of-run summary and validation, adds
   1.5-3.6 s per run and makes a full trace read 2-10 x slower.

## What the spec may consume

- The sweep rule (build only what the sink keeps, reserve the rest of the
  logical positions) as a direct ticket: no format or contract change.
- The hold-count record as an input to an RFC amendment of the per-pulse
  records synthesis: exactness and refusal are shown; it needs a SQL
  rebuild, a summary written from the fold's own counts, and filtered
  explain reads before its speed can be judged.

## Open

- The read path's design and cost (SQL rebuild, explain by instrument).
- Not building hold rows at all in the fold, and the per-pulse
  reconciliation row (one explicit row per pulse, 8% of the trace on
  10 x 7,200).
- Opt-in diagnostics (maintainer question, 2026-11-09); H1 not run.
- Fractional quantities: positions are summed from ledger deltas; the fold
  sets them from the lot book's net.
