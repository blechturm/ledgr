# v0.2.2 Long-Window Regression Evidence

This is the local regression suite owned by LDG-2950. It is vendor-neutral and
uses ledgr's public snapshot, experiment, run, facts-reader, sweep and
walk-forward surfaces. It is not a peer benchmark or a public performance
claim.

`manifest.csv` is the frozen shape and decision declaration. The ordinary
profile has three shapes and at least five alternating fresh-process pairs.
Cold and warm results are gated separately on the median candidate/accepted
per-pair elapsed ratio. A ratio above 1.10 gets one complete retry and stands
only when the retry also exceeds 1.10. Phase clocks diagnose movement but do
not gate it. No measured row is discarded.

The ordinary `DONE` shapes contain only never-held terminals and gaps no
longer than the two-session stale-valuation budget. Held terminals and gaps
beyond that budget belong to the terminal-outcome decision and are not frozen
here.

The ordinary suite has a 1,200-second reference-host budget including fixture
construction. Release-only EXP-0003 scale and walk-forward cases require the
separate `run_release.R --release` entry point. Neither `tests/` nor hosted CI
may invoke it.

Run from the ledgr repository root:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/bench/v0_2_2_long_window_regression/run_suite.R `
  C:/tmp/ledgr-v022-ws11-base . C:/tmp/ledgr-ws11-record 5 ordinary

& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/bench/v0_2_2_long_window_regression/check_record.R `
  C:/tmp/ledgr-ws11-record --self-test
```

The accepted record is copied under `evidence/accepted/`. Future semantic
re-baselines must preserve the prior record and add `rebaseline.csv` naming
the accepted ticket that authorizes each changed surface. Timing noise or a
convenient implementation is not authority to replace a semantic record.

The separate `baseline_757` orientation row runs once on the accepted arm. It
reproduces the four result counts frozen by the post-Cut-3 757-pulse record;
it is not included in timing ratios or the ordinary three-shape budget.
