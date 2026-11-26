# Cut 25 measuring step: three WS12 chores

Descriptive probes behind Cut 25 (tickets.yml). Base: release/v0.2.3 at
ca635540 (R/ equal to the workstream-43 close 2dee0f98). Host: Windows 11
Pro x64, R 4.6.1, the maintainer's default library (duckdb 2.0.1, TTR
0.24.4) unless stated, Balanced power plan; nothing else heavy ran during
the timings. Run 2026-11-26.

## Commands

    Rscript dev/bench/v0_2_3_cut25_chores/schema_probe.R --source=<tree>
    Rscript dev/bench/v0_2_3_cut25_chores/schema_probe.R --source=<tree> --lib=C:/Users/maxth/ledgr-wt/cut24-scratch/verify-lib
    Rscript dev/bench/v0_2_3_cut25_chores/utc_probe.R --source=<tree> --out=<results> --write-fixture=<tree>/tests/testthat/fixtures/ledgr-utc-oracle.csv
    Rscript dev/bench/v0_2_3_cut25_chores/na_probe.R --source=<tree> --out=<results>/na_probe_base.csv
    Rscript dev/bench/v0_2_3_cut25_chores/na_probe.R --source=<patched tree> --out=<results>/na_probe_patched.csv
    Rscript dev/feature_parity/runner.R --arm=probe_na --source=<patched tree> --out=<scratch>/probe_na --debug=0
    Rscript dev/feature_parity/check.R --pin=C:/Users/maxth/ledgr-wt/cut24-scratch/ldg3264/pin --candidate=<scratch>/probe_na
    Rscript dev/bench/v0_2_3_cut25_chores/oracle_flips.R --pin=<same pin> --candidate=<scratch>/probe_na --out=<results>/oracle_flips.csv

The patched tree is a detached worktree of ca635540 with the three lines of
`results/oracle_probe_patch.diff` removed (the post-warmup NA refusal in
`ledgr_normalize_feature_series_output()`); `load_all()` compiled it.

## Results

- **Schema golden test** (`results/schema_probe_duckdb_2_0_1.txt`,
  `..._2_0_0.txt`). Under duckdb 2.0.1, LTB-0258 fails exactly its two
  version expectations (fixtures stamped 2.0.0); the 12 other expectations,
  the catalogue-row comparison included, pass. Under 2.0.0 (the
  verification library) all pass. LTB-0263 passes under both.
- **ledgr_utc()** (`results/utc_timing.csv`, medians of 7 blocks): one
  string 0.26 ms, 500 strings 67 ms, 5,000 strings 0.66 s; one
  `as.POSIXct(format = )` over 5,000 strings 18 ms. The frozen per-element
  results (`tests/testthat/fixtures/ledgr-utc-oracle.csv`, 532 rows: 500
  accepted strings over the four accepted forms, 11 accepted edge values
  including years 0000 and 9999 and leap days, 21 refused values) were
  written by the base code one element at a time and checked against one
  whole-vector call. Every refusal has class `ledgr_invalid_timestamp` and
  the same message. A string of Arabic-Indic digits also refuses (kept out
  of the ASCII fixture).
- **Post-warmup NA** (`results/na_probe_base.csv`, `na_probe_patched.csv`).
  One instrument over eight sessions, values bad from the fourth session.
  Base: `fn` with NA completes (run DONE, sweep completes, the strategy
  reads NA, evidence `calculation_non_finite`); `series_fn` with NA refuses
  run (FAILED) and sweep with `ledgr_invalid_feature_output`; NaN and Inf
  refuse on both paths. Patched: `series_fn` with NA behaves exactly like
  `fn` with NA; NaN and Inf still refuse on both paths.
- **Feature oracle on the patched tree** (`results/oracle_probe_check.txt`,
  `results/oracle_flips.csv`). 694 cases; 52 cases change, every one a
  compute case that refused on the pin with `ledgr_invalid_feature_output`
  and now completes: the definition sets `runsd_one` (TTR runSD with
  n = 1, NA after warmup), `competing_first` and `competing_second` (runSD
  n = 1 with an all-NA custom series), 14 each, and `custom_volume_strict`
  (a series of the volume field, NA where volume is missing), 10. A further
  270 cases differ only in `treated_fields`, which check.R does not compare
  between arms (the pin treats all five fields; the field selector treats
  the certified union); check.R's own treated-fields rule passes them. No
  other case and no e2e, read-entry, TTR-route or axis case differs.

## Reading

The schema test's version checks assert the environment, not ledgr. The
utc parser costs about 0.13 ms per string, linear in the input. Removing
the one series-path check gives the decided behaviour and nothing else the
oracle can see; its 52 changed cases are exactly the post-warmup NA
refusals in the corpus.
