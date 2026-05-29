# Fold-Core Trust Boundary

**Status:** Architecture note - v0.1.8.7 RFC input.
**Date:** 2026-05-29
**Author:** Codex
**Depends on:** `inst/design/contracts.md`, `inst/design/ledgr_roadmap.md`,
`inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`

---

## 1. Purpose

This note records the trust-boundary stance behind the v0.1.8.7 fold-core
redesign work:

- validation and normalization belong at ingress, snapshot sealing, loading,
  and fold-entry boundaries;
- the fold core should receive primitive R objects and functions that are
  already trusted for the run;
- hot paths must not repeatedly revalidate or renormalize sealed data per
  pulse, feature, instrument, or cache lookup;
- durable provenance remains evidence-grade, but session-local lookup keys are
  not durable provenance.

The binding rules live in `inst/design/contracts.md`. This file explains the
reasoning and records the implementation questions that the v0.1.8.7 RFC must
settle.

---

## 2. Trust Boundary

The snapshot contract already says that backtests run against sealed snapshots,
that sealing validates referential integrity and OHLC consistency before
writing a snapshot hash, and that `ledgr_snapshot_load(..., verify = TRUE)`
recomputes the snapshot hash. The fold-core extension is:

> Once a production caller has accepted a sealed snapshot under its execution
> mode's guard, the fold core may treat bars, pulses, timestamps, instruments,
> feature definitions, and universe membership as trusted normalized
> primitives.

That is a performance rule and a correctness rule. It is not permission to skip
validation; it moves validation to the boundary where it can run once and be
tested directly.

Current source has two production guard shapes:

- `ledgr_run()` verifies `SEALED`, checks that a stored `snapshot_hash` exists,
  recomputes `ledgr_snapshot_hash()`, and compares it before fold construction
  (`R/backtest-runner.R:748-783`).
- sweep precompute validates a snapshot object, requires `SEALED`, and carries
  the stored `snapshot_hash` into feature precompute metadata
  (`R/precompute-features.R:194-206`,
  `R/feature-inspection.R:132-146`).

The v0.1.8.7 RFC must decide whether that asymmetry is intentional:
committed runs recompute while sweep trusts a sealed snapshot handle, or whether
all public production paths should converge on a stronger verified marker before
entering `ledgr_execute_fold()`.

---

## 3. Hot-Path Consequences

After the trust boundary, repeated defensive work is a bug unless it protects a
new, untrusted input.

Examples:

- do not re-check POSIXct/UTC shape for every feature-cache key when the run
  start/end have already been normalized for the run;
- do not re-validate sealed snapshot invariants inside per-pulse strategy
  context assembly;
- do not use durable boundary encodings, such as canonical JSON, as the default
  representation for session-only hot-path lookup keys.

The v0.1.8.6 profiling made this concrete for feature cache keys. The current
session cache key builder normalizes the same `start_ts_utc` and `end_ts_utc`
inside each per `(instrument, feature)` key
(`R/feature-cache.R:116-117`) and then hashes canonical JSON
(`R/feature-cache.R:119`). A local probe found JSON and SHA256 hashing were the
same order of cost, while repeated timestamp normalization was larger than both
combined for ISO-string inputs.

That does not weaken the durable provenance contract. Strong, canonical hashes
remain appropriate for snapshot hashes, config hashes, strategy identity,
feature definition fingerprints, ledger `meta_json`, and other persisted
evidence. The distinction is:

| Surface | Representation stance |
| --- | --- |
| Hot fold/session lookup | primitive values, lists, matrices, functions, or deterministic unambiguous composite keys |
| Durable typed facts | typed DuckDB columns where the schema is stable |
| Durable heterogeneous provenance | canonical JSON and strong hashes where deterministic identity matters |
| Serialized R blobs | not evidence-grade durable provenance |

---

## 4. Session Cache Keys Are Not Provenance

The feature cache registry is session-scoped. Its lookup key only needs to be
deterministic and collision-free within the running process. It does not need to
be inspectable as durable provenance, portable across package versions, or
cryptographically strong.

Therefore a future cache-key optimization may replace per-key canonical
JSON+SHA256 with a deterministic composite encoding, provided that:

- the encoding is unambiguous for free-text fields such as `instrument_id`;
- persisted feature fingerprints and engine-version hashes keep their existing
  deterministic identity semantics unless an RFC deliberately changes them;
- tests preserve cache-hit behavior and feature-output parity.

Length-prefixed field encoding is the preferred starting point over delimiter
joining, because instrument IDs are user-controlled strings.

---

## 5. v0.1.8.7 Obligations

The v0.1.8.7 packet should pick up this note in three separable lanes:

1. **Fold-entry guard policy.** Decide whether public run and sweep paths share
   the same hash-verification marker or whether sweep may continue to trust a
   sealed snapshot handle. Add a regression fixture that public production paths
   cannot enter the fold without the accepted guard.
2. **Cache-key setup cost.** Hoist run-level timestamp normalization out of the
   per `(instrument, feature)` key builder, and evaluate a session-local
   composite key that avoids canonical JSON and SHA256 for lookup-only keys.
3. **Primitive fold-core contract.** Use primitive objects/functions in the
   fold core and manifest data.frames only at named boundaries, consistent with
   the v0.1.8.7 roadmap entry.

The run-artifact materialization policy RFC is adjacent but separate. It should
decide which heavy views are fast-path side effects and which are explicit slow
path materializations, but it should not be treated as solving cache-key setup
costs.

---

## 6. Non-Goals

This note does not propose:

- weakening snapshot hashes, config hashes, feature definition fingerprints, or
  ledger provenance;
- adding a fast-hash dependency;
- serializing durable evidence as R objects;
- changing runtime behavior in v0.1.8.6;
- moving validation into per-cell, per-feature, or per-pulse hot loops.
