# Codex Review Request: Remove the run-time data-subset value-hash (legacy)

**From:** Claude · **Date:** 2026-05-29 · **Status:** verification request before
binding a v0.1.8.7 legacy-cleanup item. Focused; not a broad review.

Verify (or refute) a finding from
`v0_1_8_7_representation_site_enumeration.md` before we commit to removing
machinery and changing resume/provenance identity.

## The claim to verify

The **run-time data-subset value-hash is legacy redundancy for sealed-snapshot
runs and should be removed**, replacing sealed-run resume identity with
`(snapshot_hash, instrument_ids, start_ts, end_ts)`.

Evidence assembled:
- `ledgr_run_data_subset_hash` (`R/data-hash.R:58`) → `ledgr_hash_bars_subset`,
  which `formatC(round(x, 8), format="f", digits=8)`-canonicalizes OHLCV doubles
  (`R/data-hash.R:132-140`) and SHA-256s them. That `formatC` is the **14.7%
  self-time** in the empty-fold profile (`dev/spikes/spike-empty-fold-profile.md`)
  — the only `formatC` in `R/`.
- It is computed per run at `R/backtest-runner.R:898` and, on resume, compared to
  the stored hash at `R/backtest-runner.R:905-907`. Purpose: **resume/replay
  drift detection.**
- A sealed snapshot is immutable and already carries `snapshot_hash`, so the data
  cannot drift; `snapshot_hash` covers the whole snapshot (hence any subset). The
  value re-hash re-derives a guarantee the seal already gives.
- Legacy lineage: `ledgr_data_hash` targets the v0.1.0 mutable raw-`bars` table
  ("Legacy v0.1.0 workflows require rows in the raw bars table"); `data-hash.R:59-61`
  concedes the run hash and `ledgr_snapshot_adapter_data_subset_hash`
  (`R/snapshot_adapters.R:402`) are "the same implementation today."

## What to verify (cite line numbers; refute freely)

1. **Sealed-snapshot universality.** Does *every* `ledgr_run` / resume path read
   from a sealed, hash-verified snapshot? Is there any surviving non-sealed /
   legacy path (raw `bars` table, `ledgr_data_hash`, adapters) where a run's data
   genuinely *can* change and value-level drift detection is still load-bearing?
   If so, the value-hash must stay on that path and be removed only on the sealed
   path.
2. **Is `snapshot_hash` verified and sufficient?** Confirm the snapshot's hash is
   actually checked at open/use (not just stored), that a run is pinned to one
   specific sealed snapshot, and that `(snapshot_hash, instrument_ids, start_ts,
   end_ts)` uniquely and safely identifies the data subset a run depends on —
   i.e., the seal's guarantee truly covers what `backtest-runner.R:905-907` is
   checking.
3. **Blast radius of `data_hash`.** Beyond the resume comparison, is the run
   `data_hash` value stored, exported, or compared anywhere with value-level
   semantics — run registry/provenance, run fingerprint / `candidate_key`,
   walk-forward identity, sweep candidate identity, replay verification, public
   surface? Removing or redefining it (snapshot-derived instead of value-hash)
   must not silently break another identity that depends on the old bytes.
4. **Could same snapshot bytes still mean different effective data?** Any edge
   case where the sealed snapshot is byte-identical but the run's *effective*
   subset differs (feature_params changing the warmup/lookback window, time-range
   boundary handling, DuckDB read ordering/determinism) that would make the value
   subset-hash genuinely necessary even under sealing?
5. **Adapter copy reuse.** Is `ledgr_snapshot_adapter_data_subset_hash`
   (`snapshot_adapters.R:402`) computed at seal/ingest and *stored*? If a
   value-hash semantic must be preserved for some reason, can the run reference
   the stored seal-time value instead of recomputing per run?

## Not asking

Not to redesign, implement, or write code. Not to re-litigate the broader
representation enumeration. Just: is removing the run-time value-hash on the
sealed path **safe and correct**, and what is the blast radius? Drop a
`v0_1_8_7_data_subset_hash_review_request_response.md` here, or annotate inline.
