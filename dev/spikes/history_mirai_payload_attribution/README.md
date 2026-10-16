# History mirai payload attribution

This directory contains the H2 Session E prerequisite spike. It measures the
existing sweep task graph before the later mori comparison chooses a shared
representation.

From the package root on the registered Windows host:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/history_mirai_payload_attribution/run_spike.R `
  --preset smoke --package-root . `
  --out-dir C:/Users/maxth/ledgr-research/.scratch/history-e0-smoke `
  --gut none

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/history_mirai_payload_attribution/check_spike.R `
  --against dev/spikes/history_mirai_payload_attribution/evidence/smoke `
  --package-root . `
  --scratch-dir C:/Users/maxth/ledgr-research/.scratch

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/spikes/history_mirai_payload_attribution/gut_demo.R `
  --against dev/spikes/history_mirai_payload_attribution/evidence/smoke `
  --package-root . `
  --scratch-dir C:/Users/maxth/ledgr-research/.scratch
```

Use `--preset record` only in an exclusive measurement lane. Timing and memory
rows are observations, not checker oracles. The checker diffs only deterministic
fixture, payload and result-identity CSVs.

On Windows, package loading can leave line-ending-only changes in generated
`R/cpp11.R` and `src/cpp11.cpp`; restore those generated artifacts before
recording or committing evidence.
