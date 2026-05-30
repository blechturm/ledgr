# Codex Response: Run-Time Data-Subset Value-Hash Review

**Reviewer:** Codex  
**Date:** 2026-05-29  
**Scope:** focused verification of
`v0_1_8_7_data_subset_hash_review_request.md`; no implementation.

## Verdict

Accept the direction **for sealed snapshot-backed runs only**: the per-run
value-level `ledgr_run_data_subset_hash()` recomputation is redundant there and
can be removed from the hot path if resume identity is instead checked by the
already verified snapshot plus the run selector:

```text
config_hash + stored snapshot_id + verified snapshot_hash + instrument_ids + start_ts + end_ts
```

Maintainer follow-up (2026-05-29): v0.1.8.7 should explicitly retire/reject the
legacy raw-`bars` execution path. With that decision, there is no need to keep
the value-hash machinery as modern execution identity. The exported low-level
`ledgr_backtest_run()` path currently can execute a config with no
`data.snapshot_id`; v0.1.8.7 should change that so non-snapshot configs fail
clearly before fold entry.

So the safe v0.1.8.7 cleanup is now stronger: require snapshot-backed configs
for every execution entry, remove run-time value rehashing from modern resume
identity, and route `ledgr_data_hash()`, `runs.data_hash`, and snapshot
metadata `data_hash` as archival-only or delete them in the spec packet. They
must not remain load-bearing for fold-core execution.

## Claim Verification

### 1. Sealed-Snapshot Universality

Partly true.

Public experiment-first execution is snapshot-backed. `ledgr_experiment()`
requires a `ledgr_snapshot` object and checks that its status is `SEALED`
([R/experiment.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/experiment.R:201),
[R/experiment.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/experiment.R:267)).
`ledgr_run()` only accepts a `ledgr_experiment` and delegates to
`ledgr_run_experiment()` ([R/backtest.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest.R:320),
[R/backtest.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest.R:333)).

The compatibility wrapper is also snapshot-backed: `ledgr_backtest()` accepts a
snapshot or data frame, converts data frames into sealed snapshots with
`ledgr_snapshot_from_df()`, and calls `ledgr_snapshot_validate()` before
constructing the run config ([R/backtest.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest.R:80),
[R/backtest.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest.R:121),
[R/backtest.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest.R:137)).

But the exported low-level runner remains a non-snapshot escape hatch.
`validate_ledgr_config()` allows `config$data` to be absent; it only validates
`data.source == "snapshot"` when the field is supplied
([R/config-validate.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/config-validate.R:205)).
`ledgr_run_fold()` sets `snapshot_id <- NULL` when the config has no snapshot
source, and then skips the snapshot verification block
([R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:580),
[R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:752)).
That path reads whatever `bars` table exists in the run DB. This is the reason
the legacy path must be explicitly removed or rejected before the hash cleanup
lands. After that removal, there is no modern path where value-level `data_hash`
drift detection remains load-bearing.

### 2. Snapshot Hash Verification And Sufficiency

For snapshot-backed runs, yes.

On run execution, the runner checks the snapshot row exists, status is
`SEALED`, `snapshot_hash` is non-empty, recomputes `ledgr_snapshot_hash()`, and
fails on mismatch before runtime views are installed
([R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:760),
[R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:779),
[R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:842)).
On resume, the stored `snapshot_id` must match the requested one
([R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:702),
[R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:711)).

`ledgr_snapshot_hash()` covers snapshot instruments and bars ordered by stable
keys and explicitly excludes only the snapshot envelope row / metadata
([R/snapshots-hash.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/snapshots-hash.R:145),
[R/snapshots-hash.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/snapshots-hash.R:179)).
Runtime views then derive `instruments` and `bars` from `snapshot_instruments`
and `snapshot_bars` for the selected `snapshot_id`, `instrument_ids`, `start`,
and `end` ([R/snapshot-source.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/snapshot-source.R:53)).

That means `(verified snapshot_hash, instrument_ids, start_ts, end_ts)` is
sufficient to identify the data values used by a snapshot-backed run, assuming
the existing `config_hash` and stored `snapshot_id` checks remain in force.
Keep the selector order-sensitive because the old `data_hash` header is
order-sensitive for `instrument_ids` ([R/data-hash.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/data-hash.R:142)).

### 3. Blast Radius Of `data_hash`

The runtime value hash is compared only on resume and then stored back to
`runs.data_hash` ([R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:895),
[R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:905),
[R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:912)).
I did not find it participating in sweep candidate identity, promotion
provenance, strategy hashes, feature-set hashes, or metric identity.

It is still part of the schema and legacy/public metadata surfaces:

- `runs.data_hash` is a schema column
  ([R/db-schema-create.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/db-schema-create.R:136)).
- `ledgr_run_store_fetch()` includes `data_hash` in its canonical internal
  column set, though comparison and printed run info use `snapshot_hash`
  instead ([R/run-store.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/run-store.R:112),
  [R/run-store.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/run-store.R:518),
  [R/run-store.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/run-store.R:884)).
- The experiment-store vignette still documents `data_hash` as sealed data
  identity (`vignettes/experiment-store.qmd`).

So removing or redefining the sealed-run value bytes is not a replay/provenance
hazard, but it is a docs/tests/schema change. Since the maintainer goal is to
remove legacy gunk in this version, the spec should decide whether to drop
`runs.data_hash` outright or keep it only as nullable historical/archival
metadata for old stores. It should not remain a modern identity field.

### 4. Same Snapshot Bytes, Different Effective Data

I do not see a value-level edge case that requires rehashing bars under a
verified sealed snapshot.

Feature params can change warmup/stability requirements, but those are part of
config/feature identity, not mutable bar values. The current committed-run
runtime fetches bars for the selected run range and validates complete
per-instrument alignment against the pulse calendar
([R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:1135),
[R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:1157)).
The value hash does not add protection beyond the selector and the existing
coverage/alignment checks.

Ordering is also not protected by the hash in a way the runtime lacks: runtime
bar fetches order by `(instrument_id, ts_utc)` and then reorders/validates per
instrument against `pulses_posix`
([R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:1142),
[R/backtest-runner.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/backtest-runner.R:1160)).

The only important selector detail is inclusivity. Current runtime views and
the hash both use `>= start` and `<= end`
([R/snapshot-source.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/snapshot-source.R:97),
[R/data-hash.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/data-hash.R:156)).
If that boundary policy changes later, it is a separate execution-contract
change; the current value hash is not a better long-term identity than an
explicit selector with documented inclusive boundaries.

### 5. Adapter Copy Reuse

The snapshot adapter computes `ledgr_snapshot_adapter_data_subset_hash()` during
`ledgr_snapshot_from_df()` and stores it only inside snapshot `meta_json` as
`metadata$data_hash` before sealing
([R/snapshot_adapters.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/snapshot_adapters.R:402),
[R/snapshot_adapters.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/snapshot_adapters.R:418),
[R/snapshot_adapters.R](/c:/Users/maxth/Documents/GitHub/ledgr/R/snapshot_adapters.R:427)).
It is not stored as a first-class indexed column.

That adapter hash covers the full imported snapshot range and sorted full
instrument set, not every possible run subset. It cannot generally replace
per-run hashing unless the run uses exactly that full selector. Under the
maintainer's cleanup decision, prefer the verified `snapshot_hash + selector`
for sealed snapshot-backed runs and remove or mark adapter `data_hash` metadata
as archival import metadata, not execution identity.

## Recommended Binding

For v0.1.8.7, bind a scoped cleanup:

- Snapshot-backed run/resume: remove the per-run value rehash and compare
  `config_hash`, stored `snapshot_id`, verified `snapshot_hash`, and a
  normalized selector `(instrument_ids, start_ts, end_ts)`.
- Raw legacy run/resume: reject raw-`bars` execution before the fold. Do not
  keep it as a compatibility path.
- Schema/API: remove `runs.data_hash` and `ledgr_data_hash()` from modern
  identity. If any archival helper or nullable historical column remains, label
  it explicitly as archival and keep it out of execution.
- Verification: add a sealed-run resume/tamper test proving snapshot corruption
  is caught by `snapshot_hash` verification, plus a legacy/raw-path test proving
  raw execution now fails clearly before fold entry.

This cleanup fits the v0.1.8.7 representation lane only if it is framed as a
sealed-path identity simplification plus explicit legacy-path retirement, not
as a silent deletion of hash bytes while raw execution still exists.
