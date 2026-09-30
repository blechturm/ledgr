# Per-Call Store Overhead Closeout

**Status:** Agent-provisional draft, awaiting the Workstream 31 close review
and the maintainer's acceptance.
**Date:** 2026-09-30
**Cut:** 23
**Workstream:** 31
**Implementation range:** `8b777e7` (LDG-2916), `b0edb49` (LDG-2915) and
`bb33779` (LDG-2917), each measured against its parent; and this closeout
record. The R floor LDG-2917 relies on is LDG-2919 in Workstream 15, `3647e51`,
amended to 4.6.0 in `bea8bed`.

## Decisions

The maintainer accepted Cut 23 on 2026-09-30 and placed it before the v0.2.1.0
release gate, with LDG-2919. LDG-2917 was to wait for CRAN's Windows binary of
duckdb 1.5.6 for R 4.5. A day after 1.5.6 reached CRAN that binary was still
1.5.5; nothing had failed, the build had not been redone. The same day the
maintainer raised the R floor to 4.6.0 rather than wait, so every supported R
release has a 1.5.6 binary on Windows and macOS. Windows users on R-devel still
get the 1.5.5 binary until CRAN rebuilds it.

## Passes

| Ticket | Pass | Commit |
| --- | --- | --- |
| LDG-2916 | validate a store's schema once per store and session | `8b777e7` |
| LDG-2915 | open the store once per public call; no connection outlives its call | `b0edb49` |
| LDG-2917 | require `duckdb (>= 1.5.6)` | `bb33779` |

Each ticket's evidence in `tickets.yml` carries its detail. LDG-2915 went wider
than its two named calls: the connection census showed `summary()` opening the
run store four times, and `ledgr_snapshot_info()`, `ledgr_sweep()` and the other
snapshot readers leaving the snapshot's connection open until
`ledgr_snapshot_close()`. Every internal reader that went through
`get_connection()` now holds the connection for its call through
`ledgr_snapshot_hold()`, so no reader can leave one open.

## Blocks

Each new block is registered in `tests/claims.yml` with the five review
obligations.

| Block | Claim | Fails when |
| --- | --- | --- |
| LTB-0130 | LCL-0130 | the validation cache is off, the key drops the catalogue fingerprint, the marker timestamp or the store path, or a failed validation is remembered |
| LTB-0131 | LCL-0131 | `ledgr_experiment()` or `summary()` or `ledgr_snapshot_info()` loses its hold, either hold never releases, `ledgr_run()` rereads the price basis, or the sweep reopens the store |

LTB-0040 now hashes a plain-text rendering of the schema shape, because the
serialized query results differed between R and duckdb builds (LDG-2919).

## Results

Opens per public call, from `dev/bench/v0_2_0_2_workstream31/connection_census.R`
against `8b777e7`: `ledgr_experiment()` 3 to 1, `ledgr_run()` 2 to 1, `summary()`
4 to 1; every other call in the census already opened once. Connections still
live after `ledgr_snapshot_info()`, `ledgr_feature_contract_check()`,
`ledgr_precompute_features()`, `ledgr_sweep()` and `ledgr_backtest()` went from
1 to 0. `ledgr_backtest()` opens the store twice, a snapshot read and then the
committed run, whose fold keeps its own write connection.

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
| `ledgr_run()`, duckdb 1.5.5 to 1.5.6 | 300 ms | 140 ms | LDG-2917 |
| fast profile, duckdb 1.5.5 to 1.5.6 | 98.7 s | 74.9 s | LDG-2917 |

One cost: repeated sweeps against a snapshot left open took 50 ms before
LDG-2915 and 60 ms after, because the earlier code reused the connection it had
left open.

Results and identities: config and snapshot hashes, fills, equity, trades and
the ledger are identical before and after LDG-2915, and sweep tables differ only
in their two wall-clock columns.

## Checks

- The fast profile passes 492 blocks in 74.94 seconds on CRAN's duckdb 1.5.6
  against the 112-second bound.
- A one-process full-suite run of 970 tests shows three failures, all known and
  owned by LDG-2914: the availability fold-witness baseline and the two runner
  resume tests.
- `R CMD check --no-manual --no-build-vignettes` under R 4.6.1 with CRAN's
  duckdb 1.5.6: Status OK.
- No loop was added on a hot path; each change removes work.

## Review Count

The cut proposes one Type 1 close review of Workstream 31: 1 invocation over 3
tickets, 0.333, under the 0.5 gate.

## Open

- LDG-2919's CI acceptance needs the branch pushed; the full-tier floor job now
  pins R 4.6.
- Walk-forward is not in the census: it commits one run per fold, so it opens
  the store once per test run by design. It takes the snapshot hold for its
  reads.
