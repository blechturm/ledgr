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

The `feature_gaps` run and both `availability_sweep` candidates read
`return_63` and `sma_20` through the public vector context on every pulse.
They rebalance from those values, while `I0001` and `I0002` retain their
opening quantities through the declared gaps. Sweep variant one selects five
one-unit positions and variant two selects ten two-unit positions, so the
candidate parameter changes decisions rather than identity alone.

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
  dev/bench/v0_2_2_long_window_regression/summarize_record.R `
  C:/tmp/ledgr-ws11-record

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

ledgr exports no strategy-state result kind. The harness therefore decodes
`strategy_state` read-only through the public backtest object's `db_path` and
the run ID, rather than claiming an exported state reader. This is the
smallest valid interpretation of LDG-2950's state comparison and changes no
package state.

`record_hashes.csv` hashes LF-normalized record bytes, so a CRLF checkout does
not alter the evidence identity. It excludes only itself.

Every case records the Git status of `R/`, `src/`, `DESCRIPTION` and
`NAMESPACE` and refuses a dirty product tree. Generated `src/*.gcda` coverage
artifacts are excluded; tracked or untracked product source is not.

## Corrected Agent-Provisional Record

The corrected ordinary record compares accepted commit `d08c8f4` with
candidate commit `ff04a32` in five alternating fresh-process pairs per shape.
It completed in 627.47 seconds against the preregistered 1,200-second budget.
Median paired candidate/accepted ratios were 1.011 to 1.024 cold and 0.985 to
0.998 warm; none crossed 1.10, so no retry was triggered. Ordinary peak child
RSS was 815,497,216 bytes.

All cold and warm semantic hashes and the fact-heavy public resolver match.
The feature-gap shape records 1,347 fills and 671 closed trades in every arm,
and both sweep phases record two distinct candidate outcomes. The accepted
orientation run still reproduces 300 fills, 757 equity rows, 379,873
diagnostics and 757 state rows from the `d08c8f4` record.

The checker self-test detects semantic drift, a timing regression without its
retry, a missing ordinary shape, a missing pair, a partial retry, disagreement
between raw elapsed time and `measurements.csv`, a successful process without
a measurement and dirty product provenance. A real mutation multiplying every
strict built-in value by `1 + 1e-6` produces `Semantic drift` for both cold and
warm feature-gap runs. LTB-0153 still fails when one extra strict-feature pass
is injected.

The correction fast profile passed 511 of 511 blocks in 85.07 seconds against
the 112-second bound. This is local regression evidence, not a public or peer
performance claim. The corrected record remains agent-provisional until the
Workstream 11 focused Type 1 re-review and maintainer acceptance.
