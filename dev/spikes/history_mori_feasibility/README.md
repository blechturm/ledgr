# History mori feasibility spike

Run from the package root with R 4.6.1 and the user library containing
mirai 2.7.2 and mori 0.2.2.

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/history_mori_feasibility/probe.R

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/history_mori_feasibility/run_spike.R `
  --preset smoke --package-root . `
  --out-dir dev/spikes/history_mori_feasibility/evidence/smoke --gut none

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/history_mori_feasibility/run_spike.R `
  --preset record --package-root . `
  --out-dir dev/spikes/history_mori_feasibility/evidence/record --gut none

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/history_mori_feasibility/check_spike.R `
  --against dev/spikes/history_mori_feasibility/evidence/smoke `
  --package-root .

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/history_mori_feasibility/gut_demo.R `
  --against dev/spikes/history_mori_feasibility/evidence/smoke `
  --package-root .
```

The binding record uses E0's 160-instrument, 208,797-bar, 1,305-pulse,
four-candidate, two-worker shape. `arm_summary.csv` holds measured resource
observations. `result_identity.csv`, `reconstruction.csv`,
`shared_state.csv`, `result_transfer.csv`, and `lifecycle.csv` hold the
correctness and lifecycle surfaces. `process_samples.csv` is raw sampled
memory evidence. Working-set sums can count the same shared pages more than
once; private commit is not PSS or unique RSS; every sampled peak is a lower
bound.

The eight shared fields reconcile with E0's nine mori candidates because
`pulses_iso` is always rebuilt from `pulses_posix`. D-rebuild additionally
rebuilds `bars_mat` and `static_bars_views`. Exact reconstruction runs are
separate from the measured arms so sending full expected tasks to the daemons
cannot contaminate the memory comparison.
