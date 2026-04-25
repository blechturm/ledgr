# ADR 0001: Split Snapshot/Run Database Semantics

## Status

Accepted for v0.1.2.

## Context

Research workflows often reuse a sealed data snapshot across many backtests, but
run artifacts should be disposable and isolated. v0.1.1 assumed one database for
both snapshot and run state, which made repeated experiments heavier and made
snapshot reuse less clear.

## Decision

ledgr supports a snapshot DB and a separate run DB. The run config stores both
paths deterministically. During execution, the runner verifies the sealed
snapshot hash from the snapshot DB and writes `runs`, `ledger_events`,
`strategy_state`, `features`, and `equity_curve` to the run DB.

## Consequences

- Data integrity remains anchored in the snapshot DB.
- Run databases can be temporary for low-friction workflows.
- `:memory:` snapshots cannot be used with a separate run DB because there is no
  durable source path to verify.
