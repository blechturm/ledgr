# ADR 0002: Registry Fingerprint Policy

## Status

Accepted for v0.1.2.

## Context

Indicators and functional strategies may be registered in memory. Without
fingerprints, a stored run config could point at a name or key whose executable
logic has changed, weakening deterministic replay.

## Decision

Registered indicator configs store fingerprints of executable definitions and
parameters. Functional strategies are keyed by deterministic fingerprints. A run
ID reused with changed strategy or indicator logic must fail loud instead of
silently replaying with different behavior.

## Consequences

- Replay determinism is protected against mutable registries.
- Users see explicit hash mismatch errors when executable logic changes.
- Non-deterministic captured values in strategy closures are rejected before run
  creation.
