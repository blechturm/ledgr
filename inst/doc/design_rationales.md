# ledgr Design Rationales (v0.1.2)

This document formalizes the design rationale behind ledgr’s core foundation introduced in v0.1.0 (execution) and v0.1.1 (provenance). It is derived from the v0.1.2 specification Section 5 and verified against the v0.1.1 implementation.

## Why Event Sourcing?

### Problem
Backtesting systems that only persist “final state” (positions/cash/equity) lose the causal history of how that state was reached, which makes debugging, auditing, and deterministic recovery difficult.

### Rationale
ledgr persists every execution-relevant event into an append-only ledger (`ledger_events`). Portfolio state can be reconstructed by replaying these events in order.

### Benefits
- Deterministic replay: identical config + identical data yields identical event streams and results.
- Crash recovery: resuming a run can deterministically rebuild state from the last persisted checkpoint and re-run forward.
- Auditability: the full trade trail is queryable and verifiable.
- Accounting correctness: realized/unrealized P&L and cost basis can be derived from the event stream.

### Trade-offs
- Higher write volume than “final-state only” designs; typically negligible relative to market data size.
- Derived views (equity curve, positions) are computed from events rather than being the primary source of truth.

### Implementation anchors
- Tables: `ledger_events`, `strategy_state`, `equity_curve`
- Runner behavior: events are inserted during the pulse loop; derived state is rebuilt at end-of-run (`ledgr_rebuild_derived_state()`).

## Why Immutable Snapshots?

### Problem
If market data changes after a backtest is run, the run is no longer reproducible and its results cannot be trusted or audited reliably.

### Rationale
ledgr introduces immutable, sealed snapshots (v0.1.1). Sealing computes a deterministic SHA256 fingerprint over the stored snapshot contents. The runner recomputes and verifies the fingerprint before use.

### Benefits
- Reproducibility: a run can reference a stable data artifact months later.
- Tamper detection: any post-seal modification is detected via hash mismatch.
- Provenance: snapshot metadata (`meta_json`) documents source and transformations.
- Versioning: corrected data is represented by new snapshots rather than in-place edits.

### Trade-offs
- Sealed snapshots cannot be edited; data corrections require creating a new snapshot.
- Additional operational step: import then seal before using snapshots for backtests.

### Implementation anchors
- Tables: `snapshots`, `snapshot_instruments`, `snapshot_bars`
- Seal: `ledgr_snapshot_seal()` stores `snapshot_hash` and transitions status to `SEALED`.
- Verification: `ledgr_backtest_run()` recomputes and compares `snapshot_hash` before running.

## Why 8-Decimal Precision?

### Problem
Floating-point representations can produce platform-dependent rounding behavior, which breaks deterministic hashing and can lead to tiny drift that accumulates into visible differences.

### Rationale
ledgr normalizes OHLCV values by rounding to 8 decimals at import and uses the stored rounded values for hashing. Hash formatting uses a stable fixed-decimal string representation.

### Benefits
- Cross-platform determinism: `snapshot_hash` matches across Windows/Linux/macOS for the same imported data.
- Sufficient precision for most market data, including many crypto and FX instruments.
- Stable downstream computations: replay and reconciliation are not sensitive to binary floating-point artifacts.

### Trade-offs
- Values more precise than 8 decimals are truncated to the chosen precision.
- Precision policy is currently fixed (future versions may parameterize this).

### Implementation anchors
- Snapshot import requirement (v0.1.1): “round to 8 decimals at import”.
- Hash formatting: stable fixed-decimal strings (e.g., `sprintf("%.8f", round(x, 8))`).

## Why an Append-Only Ledger?

### Problem
If trade history can be updated or deleted in-place, results can be modified after-the-fact (“backtest hacking”), and crash recovery becomes ambiguous.

### Rationale
ledgr treats `ledger_events` as immutable history: events are appended with a strict per-run sequence (`event_seq`). Resuming a run is deterministic by deleting the unreconciled “tail” after the last checkpoint and re-running forward to regenerate the same event stream.

### Benefits
- Immutability: written events are durable facts.
- Gap detection: a broken or non-gapless `event_seq` indicates corruption or misuse.
- Deterministic resume: the system avoids mixing “old” and “new” realities after interruption.
- Audit trail: event-by-event reconstruction supports manual verification.

### Trade-offs
- Historical corrections are not applied at the event level; instead, runs are re-executed.
- Requires careful sequencing and checkpointing (handled by runner + `strategy_state`).

### Implementation anchors
- `ledger_events.event_seq`: strictly increasing, gapless per run.
- Resume behavior: deletes rows after the last `strategy_state` checkpoint to avoid alternate-reality outputs.
