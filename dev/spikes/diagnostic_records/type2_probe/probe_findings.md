# Probe findings and inventory

2026-11-09; installed pin d5b3a151; response source b96e060b. No product,
test, fixture, oracle, ticket or design file in the worktree was edited.

The prerequisite for count-only compression is not established generally:
fractional lot positions disagree with both sequential ledger sums and SQL
sums at two holds. Integer fixed-axis SQL reconstructions match. H1 retained
diagnostic payload is small; SQL/public-reader performance closure is open.

Runner and evidence:

- `run.R`: crossover 500 x 1,260, momentum 500 x 1,260, dense risk and a
  fractional partial-close fixture. `sql_metrics.csv` records exact comparisons
  and exploratory warm DBI times; `sql_differences.csv` records 12 differing
  cells (six columns at two sequence positions). `fractional_sequential.csv`
  disproves sequential-R event addition as well. `appends.csv` records writes;
  `decision_segments.csv` records pre-selection decision building.
- `sql.R`: runnable fixed-axis SQL decoder, windowed point selection and count
  certification. It consumes counts, residuals, config, ledger and snapshot
  facts, never baseline hold values. It is not a full integrity implementation.
- `edges.R`: executed P2/P3 stops, sizing skip, risk reduction and tiny request;
  two different targets clipped to zero with identical ledger/equity;
  promotion, comparison, batched completion, numbering, recovery and restart.
  `edge_*.csv`, `consumer_*.csv` and `recon_economics.csv` retain the evidence.
- `reductions.R`: checks summary-count accounting from the executed stores.
  `reductions.csv` shows the seed formula drops all clean-fill decisions.
- `h1.R`: verified registered snapshot hash, monthly momentum, one DONE run.
  `h1.csv` and `h1_kinds.csv` contain aggregates only. Private snapshot/run
  rows live only in an R temporary directory, not in this output directory.
- `prior_rebuild/rebuild.csv`: original rebuild rerun on all six workloads,
  including membership exits and relisting; each trace is identical.
- `prior_sweeps/fork_sweeps.csv`: original early-keep fork rerun on three
  fixtures. All compared outputs match; only the larger momentum fixture is
  used here as a timing observation, not an optimization ranking.

Gut demonstration: decrementing a certified count returns
`ledgr_diagnostic_corrupt` on all four SQL stores. Altering P3 expected cash
returns its contracted INCOMPLETE stop with deferred decisions intact
(`edge_p3.csv`). The SQL fractional arm fails exactness without any gut.

`check.R` reruns the public probes into `check-rerun/`, diffs deterministic
correctness columns and checks package/design source files before and after.
It passed (`check.csv`); timings and H1 are not repeated by the checker.
Its transient source checksums guard scope; no provenance registry is created.

Demoted: count-only exactness for arbitrary quantities; claims that D5 already
meets current read costs; one measured retained frame as a peak-memory bound;
cash reconciliation as proof that exposure evidence is redundant.
Deleted from product: nothing. Learned: lot arithmetic is part of exact trace
reconstruction; clean fills count as decisions; H1 reconciles skipped pulses;
direct physical consumers need their own codec assumptions preserved.

Run scripts with one literal PowerShell command per call, for example:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" "C:/Users/maxth/ledgr-wt/diag-records-t2-out/probe/check.R"
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" "C:/Users/maxth/ledgr-wt/diag-records-t2-out/probe/h1.R"
```

These are response probes, not a release timing record or implemented codec.
No full package check is claimed for this read-only design task.
