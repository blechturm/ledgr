# LDG-3261 commands and results

`S = C:/Users/maxth/ledgr-wt/cut24-scratch`; `<pin>` the read-only library
`C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`. Final R/ is at 9ac80163 (LDG-3259);
the LDG-3260 arm d3903a2b was reverted (d1b165ca), so R/ at the final commit
8f7c6977 equals 9ac80163. The final arm is 8f7c6977, installed with
install_arm.R into `$S/libs/final-8f7c6977`.

## Proofs (run_proofs.R, outputs in this folder)

    Rscript dev/feature_parity/evidence/ldg3261/run_proofs.R --final=8f7c6977

In order: install the final arm; the permanent oracle on the pin, a pin
repeat and the final arm (`runner.R`); `check.R` pin against the pin repeat
and against the final arm, with every existing expectation in
corpus_expected.csv unchanged; `faults.R` on the final library; identity.R on
the final library reading the cut base's record and store
(`$S/identity_base`, LDG-3258) and identity_check.R in its default
changed-engine mode with the completeness guard; emitted_pin.R on the final
record; counts.R on the final library; census.R with --census; lines.R.

- `check_pin_repeat.txt`, `check_final.txt`: CHECK PASS; 631 cases (57
  refusing on the pin), 8,280 observations in each arm, every component equal
  to the pin, mechanism observations (routes, counted seams, hand-offs)
  included: stage 2 removes no counted work (decision 5).
- `faults.txt`, `faults/`: FAULTS PASS (every fault control fails the
  checker, signal sets pairwise distinct).
- `identity_check.txt`: 155 expected identities equal besides the engine
  version (identity_names_changed_engine.csv, no record missing, unexpected
  or duplicated); engine version bc6a3ea2... -> 88b4237e...; the base's
  explicit precompute refuses with ledgr_precomputed_engine_mismatch and 0
  strategy calls; the base store's run (30 equity rows) and sweep stay
  readable, the sweep keeping its recorded engine version.
- `emitted_pin_final.txt`: EMITTED PIN PASS, 134 of 134 emitted identities
  equal to the pin frozen on the cut base.
- `counts_final.txt`: COUNTS CHECK PASS, 385 calculated-count cells equal to
  the base matrices.
- `census_check.txt`, `census/`: CENSUS CHECK PASS; 309 reachable helpers,
  159 bound (147 before plus the 12 adapter helpers), 150 excluded (131 plus
  the 19 bundle and feature-ID helpers reached only through the TTR adapter's
  constructor list); every row proved by replacement.
- `lines.csv`: R/ production lines 54,882 -> 54,966 (+84; +89 without the
  engine bind list, which moved 5 lines into the adapters' `bind`).
  R/feature-adapters.R +9, R/indicator-builtins.R +65, R/indicator-ttr.R +143
  (the TTR catalogue rows, candidate, certified, segment and bind list moved
  here), R/history-features.R -81, R/indicator-history.R -49,
  R/feature-parameters.R -7, R/indicator.R +6, R/strategy-provenance.R +1,
  R/features-engine.R -3.
- `shapes.md`: the seven shapes walked; none introduced.

Direct-backend TTR parity with derived outputs: the registered tests in
tests/testthat/test-indicator-ttr.R ("TTR ledgr output matches direct TTR
output after normalization", the MACD cases, the bundle histogram case) pass
in the full suite.

## Full suite and check

    Rscript $S/full_tests.R      # final library first on .libPaths() and R_LIBS; load_all(ws43); test_local
    Rscript $S/buildcheck.R      # R CMD build ws43; R CMD check --no-manual --no-build-vignettes

`full_tests_summary.txt`: 233 files, 1,364 tests, 1 failed, 2 errors, 16
skipped. The three non-passes are the host's packages, not workstream 43:
LTB-0258 (test-schema-current.R) pins the DuckDB version of the golden
schema files (2.0.0) and the host has had duckdb 2.0.1 since 2026-11-24;
LTB-0508 and LTB-0511 (test-strategy-schedule.R) run two-worker sweeps and
`mirai` no longer loads (it needs nanonext >= 1.10.4, the host has 1.10.2),
which also makes the 15 mirai tests skip (Cut 23's suite skipped only the
quantmod test). `base_environment_tests.txt` (`base_env_tests.R`): the same
three fail identically on the cut base's installed library. Not changed
here: the host's library is shared with other work. R CMD check: Status OK (r_cmd_check.log).
