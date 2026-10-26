# Strategy scheduler H1 record

This public-source runner compares the exact registered monthly-momentum H1
strategy with and without `ledgr_schedule_month_start()`. The private Sharadar
snapshot never leaves the sentinel-backed data root. Committed evidence contains
only clocks, counts, hashes, literal due dates and environment metadata.

Both arms use the dividend-v004 snapshot with hash
`e8cbb805486726cd9e8758e377bdc92a97e80b4a07f3df2d5fc1b9c8766430a1`, start
on the true 1998-02-02 month boundary, and therefore share the same parent-axis
predecessor. The scheduled arm decorates the same strategy function used by the
manual arm; its now-redundant month guard remains inside the function so inner
source identity, decisions and carried state are identical.

Run three alternating pairs on the registered quiet host:

```powershell
$env:SHARADAR_DATA_ROOT = "E:/ledgr-data/sharadar"
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_strategy_scheduler/run_pairs.R `
  C:/Users/maxth/Documents/GitHub/ledgr `
  E:/ledgr-data/sharadar/experiments/LDG-3114-scheduler/sp500-1998-2026-v004-schema124.duckdb `
  e8cbb805486726cd9e8758e377bdc92a97e80b4a07f3df2d5fc1b9c8766430a1 `
  E:/ledgr-data/sharadar/experiments/LDG-3114-scheduler/work `
  dev/bench/v0_2_2_strategy_scheduler/evidence/ws63_h1 `
  c7a5dee

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_strategy_scheduler/check_record.R `
  dev/bench/v0_2_2_strategy_scheduler/evidence/ws63_h1

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_strategy_scheduler/self_test_record.R `
  dev/bench/v0_2_2_strategy_scheduler/check_record.R `
  dev/bench/v0_2_2_strategy_scheduler/evidence/ws63_h1

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_strategy_scheduler/identity_cost.R `
  C:/Users/maxth/Documents/GitHub/ledgr `
  dev/bench/v0_2_2_strategy_scheduler/evidence/identity_cost.csv
```

The checker requires exact fills, ledger, equity, reconstructed positions,
lots, strategy state, due-date and decision-diagnostic parity. Off-date
diagnostics may differ only as the contract permits: explicit manual holds in
one arm and `scheduled_skip` in the other. The timing gate is the median of the
three within-pair scheduled/manual ratios, at most 0.90.

The correction record under `evidence/ws63_diagnostic_parity` is an untimed
manual/scheduled pair. `check_diagnostic_parity.R` removes only the P2-owned
decision and risk rows from the manual off-date evidence, then requires every
retained P1/P4/P5 row and every retained stage/outcome/reason count to match the
scheduled arm exactly. `self_test_diagnostic_parity.R` proves the checker
rejects a missing retained row and a forged retained-row hash.

Create and check that record with:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_strategy_scheduler/run_diagnostic_parity.R `
  C:/Users/maxth/Documents/GitHub/ledgr `
  E:/ledgr-data/sharadar/experiments/LDG-3114-scheduler/sp500-1998-2026-v004-schema124.duckdb `
  e8cbb805486726cd9e8758e377bdc92a97e80b4a07f3df2d5fc1b9c8766430a1 `
  E:/ledgr-data/sharadar/experiments/LDG-3114-scheduler/work `
  dev/bench/v0_2_2_strategy_scheduler/evidence/ws63_diagnostic_parity `
  c7a5dee

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_strategy_scheduler/check_diagnostic_parity.R `
  dev/bench/v0_2_2_strategy_scheduler/evidence/ws63_diagnostic_parity

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_strategy_scheduler/self_test_diagnostic_parity.R `
  dev/bench/v0_2_2_strategy_scheduler/check_diagnostic_parity.R `
  dev/bench/v0_2_2_strategy_scheduler/evidence/ws63_diagnostic_parity
```
