# Per-Call Store Overhead Closeout

**Status:** Agent-provisional draft. The Workstream 31 close review
(invocation 1, at `4933065`) and its re-review (invocation 2, at `067017a`)
returned CHANGES_REQUIRED; both correction rounds below await the maintainer's
acceptance.
**Date:** 2026-09-30
**Cut:** 23
**Workstream:** 31
**Implementation range:** `8b777e7` (LDG-2916), `b0edb49` (LDG-2915) and
`bb33779` (LDG-2917), each measured against its parent; the close-review
correction, measured against `4933065`; and this closeout record. The R floor
LDG-2917 relies on is LDG-2919 in Workstream 15, `3647e51`, amended to 4.6.0
in `bea8bed`.

## Decisions

The maintainer accepted Cut 23 on 2026-09-30 and placed it before the v0.2.1.0
release gate, with LDG-2919. LDG-2917 was to wait for CRAN's Windows binary of
duckdb 1.5.6 for R 4.5. A day after 1.5.6 reached CRAN that binary was still
1.5.5; nothing had failed, the build had not been redone. The same day the
maintainer raised the R floor to 4.6.0 rather than wait, so every supported R
release has a 1.5.6 binary on Windows and macOS. Windows users on R-devel still
get the 1.5.5 binary until CRAN rebuilds it.

After the close review the maintainer decided (Cut 23 decision 1) that a public
call that commits runs, `ledgr_walk_forward()`, `ledgr_promote()` or
`ledgr_backtest()`, opens the store once for its own reads and writes plus once
per committed run, whose fold keeps its own write connection. Every other public
call opens each store file once, and no call leaves a connection open. One
connection through committed runs is the v0.2.1.1 roadmap row "one store
connection per composite call".

## Passes

| Ticket | Pass | Commit |
| --- | --- | --- |
| LDG-2916 | validate a store's schema once per store and session | `8b777e7` |
| LDG-2915 | open the store once per public call; no connection outlives its call | `b0edb49` |
| LDG-2917 | require `duckdb (>= 1.5.6)` | `bb33779` |
| all three | close-review correction | this round |

Each ticket's evidence in `tickets.yml` carries its detail. The correction round:

- LDG-2916: the cache key's catalogue fingerprint now includes each
  constraint's text, so a check weakened on the same columns is validated
  again and fails.
- LDG-2915: a registry of held store connections, keyed by file, lets every
  nested open within a public call borrow the connection the call holds;
  borrowers never close it. Walk-forward, its inspection readers,
  `ledgr_candidate()` and `ledgr_promote()` now meet decision 1.
  `ledgr_promote()` no longer leaves the promoted run's handle open, and
  `ledgr_pulse_snapshot()` and `ledgr_indicator_dev()` close their connection
  before returning.
- LDG-2917: two runner resume failures that this workstream had attributed to
  LDG-2914 were caused by duckdb 1.5.6. It refuses a driver whose instance
  settings differ from those of a database already open in the session, so
  ledgr could not open a store a user held open with their own
  `duckdb::duckdb()` connection. ledgr now joins that instance. The re-review
  found the join's first condition too broad and its driver's messages
  suppressed; it now joins only on DuckDB's full settings-mismatch error and
  leaves DuckDB's messages alone.

## Blocks

Each block is registered in `tests/claims.yml` with the five review obligations.

| Block | Claim | Fails when |
| --- | --- | --- |
| LTB-0130 | LCL-0130 | the validation cache is off, the key drops the catalogue fingerprint, the marker timestamp, the store path or the constraint text, or a failed validation is remembered |
| LTB-0131 | LCL-0131 | a call loses its hold, a hold never releases, a nested open does not borrow, `ledgr_run()` rereads the price basis, the sweep opens its own connection, the promotion context stays on the handle, the pulse or indicator dev keeps its connection, or a snapshot closes a borrowed connection |
| LTB-0132 | LCL-0132 | ledgr fails instead of joining a store the user holds open, joins on an unrelated error, or suppresses DuckDB's messages while joining |

LTB-0040 now hashes a plain-text rendering of the schema shape, because the
serialized query results differed between R and duckdb builds (LDG-2919).

## Results

Opens per public call, from `dev/bench/v0_2_0_2_workstream31/connection_census.R`.
Against `8b777e7`: `ledgr_experiment()` 3 to 1, `ledgr_run()` 2 to 1,
`summary()` 4 to 1. Against `4933065`, in the correction round:
`ledgr_walk_forward()` over two folds 16 to 3, the walk-forward inspection
readers 2 to 1, `ledgr_candidate()` on a walk-forward result 5 to 1, and
`ledgr_promote()` 3 to 2. `ledgr_backtest()` opens twice. After every call in
the census no connection is live; before, `ledgr_snapshot_info()`,
`ledgr_sweep()`, `ledgr_promote()`, `ledgr_pulse_snapshot()`,
`ledgr_indicator_dev()` and others left one.

Warm-clock medians, interleaved, one process per arm. LDG-2916 and LDG-2915
were measured on the r-universe build of duckdb 1.5.6.9000, LDG-2917 on CRAN's
1.5.6 against 1.5.5:

| Call | Before | After | Source |
| --- | --- | --- | --- |
| small `ledgr_run()` | 270 ms | 170 ms | LDG-2916 |
| `ledgr_db_init()` open and close | 130 ms | 30 ms | LDG-2916 |
| `ledgr_experiment()` | 70 ms | 30 ms | LDG-2915 |
| `ledgr_run()` | 165 ms | 140 ms | LDG-2915 |
| `summary()` | 100 ms | 40 ms | LDG-2915 |
| `ledgr_sweep()`, two candidates | 70 ms | 60 ms | LDG-2915 |
| `ledgr_walk_forward()`, two folds | 570 ms | 460 ms | LDG-2915 correction |
| `ledgr_candidate()`, walk-forward | 140 ms | 70 ms | LDG-2915 correction |
| `ledgr_promote()` with `close()` | 340 ms | 260 ms | LDG-2915 correction |
| `ledgr_run()`, duckdb 1.5.5 to 1.5.6 | 300 ms | 140 ms | LDG-2917 |
| fast profile, duckdb 1.5.5 to 1.5.6 | 98.7 s | 74.9 s | LDG-2917 |

Two costs: repeated sweeps against a snapshot left open took 50 ms before
LDG-2915 and 60 ms after, and an indicator dev object's `test_dates()` 0 ms
before and 25 ms after, because the earlier code reused a connection it had
left open.

Results and identities: config and snapshot hashes, fills, equity, trades and
the ledger are identical before and after LDG-2915, and sweep tables differ only
in their two wall-clock columns.

## Checks

Round 2, on CRAN's duckdb 1.5.6:

- The fast profile passes 493 blocks in 79.07 seconds against the 112-second
  bound.
- The full suite in one process through `testthat::test_local()`, with the
  failure limit removed, runs 971 tests; 8 fail: the LDG-2913 witness
  baseline and the seven one-process failures LDG-2914 owns, each of which
  passes alone. Through `testthat::test_dir()` after one
  `pkgload::load_all()`, only the LDG-2913 baseline fails. The first round
  recorded three failures from `test_dir()`, which hides the LDG-2914 set, and
  two of those three were the duckdb 1.5.6 defect LDG-2917 now fixes. These
  runs used the English_United States.utf8 locale; the re-review, in a shell
  that could not set a UTF-8 locale, also saw the encoding-dependent
  sweep-retention block fail.
- `R CMD check --no-manual --no-build-vignettes` under R 4.6.1 with CRAN's
  duckdb 1.5.6 reported Status OK at `bb33779`.
- No loop was added on a hot path; the store registry is one keyed lookup per
  open.

## Review Count

Invocation 1 returned CHANGES_REQUIRED, and so did invocation 2, the
re-review, on two defects in the new join, both fixed with the reviewer's
controls. Workstream 31 stands at 2 invocations over 3 tickets, 0.667, above
the 0.5 gate: an honest breach, not padded with unrelated work. A third review
would make it 1.000.

## Open

- LDG-2919's CI acceptance needs the branch pushed; the full-tier floor job now
  pins R 4.6.
- The one-process full-suite failures listed under Checks belong to LDG-2913
  and LDG-2914 in Workstream 15.
