# Model Routing Rulebook

**Status:** Active  
**Scope:** ledgr ticket classification, implementation, and review  
**Purpose:** Stable, repeatable rules for assigning work to model tiers and
providing implementing agents with the context they need to avoid silent
correctness failures.

---

## Core Rule

Every ticket MUST be classified before implementation begins.

Classification is Tier H work. The classifier assigns the implementation tier,
review tier, and — most importantly — the required context. The implementing
agent reads the classification before starting and stops if the work turns out
to be higher-risk than classified.

---

## Model Tiers

### Tier L — Narrow / Low-Risk

Use for work with no semantic risk and no public API surface.

- Documentation polish
- Roxygen examples
- README and vignette copy changes
- Simple tests derived directly from fully explicit acceptance criteria

Not used for implementation that touches executable R code paths.

### Tier M — Standard Implementation

Use for bounded implementation work within established contracts.

- Contained API additions
- Multi-file changes with clear, bounded scope
- Tests and implementation for non-invariant-sensitive tickets
- Performance work that does not alter semantics
- Ordinary R package plumbing

### Tier H — Frontier / Smart

Use for classification, architecture, contract-sensitive work, and final review.

- All ticket classification
- All version scoping and ticket generation
- Contract modifications
- Invariant-sensitive implementation (see Hard Escalation Rules)
- Cross-module reasoning
- Release gates

---

## Hard Escalation Rules

A ticket MUST be classified Tier H if it touches any of the following:

**Execution**
- canonical execution path
- pulse order or pulse semantics
- fill model or fill semantics
- event ledger semantics
- deterministic replay

**Persistence**
- DuckDB schema or writes
- checkpoint behavior
- restart safety
- snapshot sealing or loading
- snapshot hashing

**Identity**
- canonical JSON
- config hashing
- strategy source or parameter hashing
- run identity or experiment identity
- reproducibility tiers

**Public API**
- breaking changes to any exported function
- compatibility policy
- release gates

No cheaper model may implement these areas unless Tier H explicitly classifies
the work as safe and narrow, and documents the reason in the classification
output.

---

## Classification Output

For every ticket the classifier MUST produce:

```yaml
ticket_id:
risk_level: low | medium | high | release-critical
implementation_tier: L | M | H
review_tier: L | M | H
classification_reason:
invariants_at_risk:
required_context:
tests_required:
escalation_triggers:
forbidden_actions:
```

`required_context` is the most consequential field. It specifies exactly which
contracts, files, and prior review findings the implementing agent must read
before starting. A misimplementation caused by missing context is a
classification failure, not an implementation failure.

---

## Required Context Rules

The classifier decides the required context. Every ticket includes by default:

- ticket text and acceptance criteria
- directly affected files
- prior review findings for those files, if any

Additional context by area:

| If the ticket touches...        | Also include...                          |
|---------------------------------|------------------------------------------|
| execution flow                  | Execution Contract                       |
| snapshot semantics              | Snapshot Contract                        |
| persistence or restart safety   | Persistence Contract                     |
| strategy outputs                | Strategy Contract                        |
| run or experiment identity      | Run Identity Contract                    |
| hashing or fingerprinting       | Canonical JSON Contract                  |
| public API                      | Compatibility Policy + NEWS expectations |
| feature computation             | series_fn contract + LDG-712 review      |
| TTR indicators                  | LDG-715 review + R/indicator-ttr.R       |
| feature cache                   | LDG-713 review + R/feature-cache.R       |

---

## Implementation Guardrails

The implementing agent MUST stop and escalate to Tier H if:

- the work requires changing any contract
- implementation unexpectedly touches replay, persistence, snapshots, ledger,
  or identity
- tests pass but behavior seems semantically wrong
- acceptance criteria conflict with existing contracts
- scope expands beyond the ticket
- public API behavior changes in any unspecified way

Escalation is not a failure. Silent scope expansion is.

---

## Review Rules

Every ticket requires review before acceptance. The review tier is assigned
during classification.

The reviewer checks:

- acceptance criteria satisfied
- tests present and meaningful, not just passing
- contract compliance
- no unintended scope expansion
- no hidden API surface changes
- NEWS entry present if required by the compatibility policy

---

## Version Workflow

| Activity               | Tier       |
|------------------------|------------|
| Version scoping        | H          |
| Ticket generation      | H          |
| Ticket classification  | H          |
| Implementation         | Assigned   |
| First-pass review      | Assigned   |
| Final version review   | H          |

No version may be released without Tier H final review.

---

## Anti-Drift Rule

This document is the source of truth for model routing.

Agents must not invent or reinterpret routing rules. If a classification seems
wrong or ambiguous:

1. Flag the ambiguity explicitly.
2. Request Tier H clarification.
3. Update this document through an explicit, reviewed change — not through
   local reinterpretation.

---

## Core Principle

Cheap models implement bounded work.  
Smart models classify work, protect invariants, and approve releases.  
Context is the mechanism that makes the boundary real.
