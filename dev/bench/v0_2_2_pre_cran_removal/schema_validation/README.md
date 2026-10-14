# LDG-3027 schema-validation clocks

This record establishes the pre-implementation A/A noise floor required by
LDG-3027. It ran at `0a3f2d2984f3af99a537e062679b2e009bfb8265` on
`AUDIOI9` (Intel64 Family 6 Model 151 Stepping 2, Windows
10.0.26200.0), with R 4.6.1 and DuckDB 1.5.6.9000.

`aa.csv` contains six alternating A/B pairs. Each process measured:

- `open_validate`: `ledgr_run_store_open()` followed by one uncached
  `ledgr_validate_schema_once()` on an already-current durable store;
- `db_init`: `ledgr_db_init()` on a new durable path; and
- `small_snapshot`: `ledgr_snapshot_from_df()` for five bars on a new
  durable path.

The B/A ratios of medians are 1.008, 0.984 and 1.021 respectively. The
largest A/A displacement is 2.1%, leaving observable room below the ticket's
1.05 candidate/pre-cut ceiling. The runner uses `Sys.time()` rather than the
coarser process timer and records all raw observations.

`pairs.csv` contains three alternating runs of pre-change `0a3f2d29` and the
LDG-3027 candidate. Candidate/pre-cut ratios of medians are 0.648 for
`open_validate`, 0.773 for `db_init` and 0.984 for `small_snapshot`. Package
loading and the harmless missing-DLL warning from the archive export occur
outside the clocks.

The strict validator exposed one pre-existing split DDL: public snapshot
creation added `idx_snapshot_bars_ts` outside the schema builder. The ticket
moved that index into the sole definition and removed the runtime DDL. A
successfully sealed public snapshot built from pre-cut `24bcc161` has the
revised golden's exact four digests, including 54 index-attribute rows and
SHA-256 `f0c419002c5401507eaee66b644e0bf273611571b20d01ad9069e9b0c83dd15a`.

## Close-review correction

`correction_pairs.csv` replaces the misleading candidate comparison above.
It uses the actual Workstream 29 baseline `24bcc161`, five alternating fresh
processes and the expanded correction runner. Median candidate/pre-cut ratios
are:

- 1.512 for a cold `ledgr_run_store_open()` plus close;
- 0.866 for a primed open plus `ledgr_validate_schema_once()`;
- 0.856 for a validation-cache hit on an open connection;
- 1.043 for `ledgr_db_init()` on an existing durable store; and
- 0.988 for a five-row snapshot build.

The four existing-work boundaries meet the 1.05 rule. The cold opener does
not: its fresh-process median rises from 24.29 ms to 36.72 ms. A focused
re-review attributes about 10 ms of that increase to one-time first-call work
under uncompiled `pkgload`, rather than to the marker query. Its steady-state
gate cost is about 1.1 ms per open, including about 0.55 ms for the marker
query, or roughly 1.07 to 1.11 times the pre-cut open. The miss is recorded,
not passed or hidden in package loading, and remains for maintainer
adjudication.
