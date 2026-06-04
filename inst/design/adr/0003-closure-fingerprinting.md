# ADR 0003: Functional Strategy Closure Fingerprinting

## Status

Accepted for v0.1.2. Historical record; rationale slated to migrate into the
observability/determinism maintainer manual article when that article lands.
See `README.md` in this directory for the ADR wind-down policy.

## Context

R strategy functions commonly capture values from their defining environment.
Hashing only the function body misses behavior changes caused by altered
captured values.

## Decision

Functional strategy fingerprints include deterministic captured values and
default arguments. Captures that are not JSON-safe or deterministic, such as
timestamps and open connections, fail before the run config is created.

## Consequences

- Two closures with the same body but different captured target values produce
  different strategy keys.
- Deterministic research workflows can still use normal R closures.
- Strategies that depend on ambient mutable runtime state are rejected early.
