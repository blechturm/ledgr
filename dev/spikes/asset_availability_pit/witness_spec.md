# Stage 1 Witness Evidence Contract

**Status:** Setup skeleton; not frozen and not maintainer approved.

**Witness schema:** `asset_availability_witness_v1`.

**Charter base:** package commit `1f42cf7`.

## Purpose

This document defines how W01-W31 become independent reference evidence. The
shared fold fork and representation providers are implementations under test;
they must not generate or silently revise their own expected answers.

## Required Fixture Packet

Each witness gets a directory under `fixtures/` containing a manifest and the
smallest deterministic input tables needed by the case. Its manifest records:

- witness ID, case ID, and witness class;
- stable asset IDs and aliases;
- investment, estimation, and held-position domains;
- bars and other source observations;
- membership, lifetime, calendar, status, and revision facts;
- effective, knowledge, acquisition, and revision times where applicable;
- opening cash, quantities, lots, and carried state;
- strategy outputs and risk, cost, valuation, and execution policies;
- fit population, cutoff, label maturity, graph, and RNG identity where used;
- expected identity-equal and identity-change sets; and
- source notes and any bounded synthetic assumptions.

Inputs use UTC ISO-8601 timestamps and stable asset IDs. Row order is explicit.
Missing facts remain missing; fixtures must not create executable values by
forward filling, imputation, or valuation fallback.

## Required Expected Table

Each witness gets one long table under `expected/` with these columns:

| Column | Meaning |
| --- | --- |
| `witness_id` | W01-W31 |
| `case_id` | Stable case within the witness |
| `step` | Ordered decision, risk, execution, accounting, or audit step |
| `event_time` | Event time or blank when not temporal |
| `asset_id` | Stable asset ID or blank for portfolio-level evidence |
| `field` | Exact field being asserted |
| `expected_type` | Logical, integer, double, character, timestamp, or absent |
| `expected_value` | Canonical expected scalar representation |
| `reason_code` | Typed reason or blank when not applicable |
| `identity_expectation` | Equal, changed, absent, or not_applicable |
| `derivation` | Short independent arithmetic or temporal justification |

Additional case-specific tables are allowed, but this long table is the
minimum checker input and cannot be replaced by prose.

## Freeze Protocol

1. The executor writes fixture manifests without running prototype output.
2. Expected tables are calculated independently by hand or by a tiny reference
   calculation that does not call the shared fork or a representation provider.
3. The maintainer approves the policy and expected outcomes.
4. A non-executing reviewer checks temporal reasoning, arithmetic, and table
   completeness.
5. Approved files receive immutable content hashes in the evidence manifest.
6. Registry status changes to `approved` only after both approvals.
7. `check_stage1.R --mode=gate` must pass before fold-fork code begins.

If an expected answer changes later, preserve the prior file or commit, record
the rationale and approver, increment the witness-specification version, and
rerun every affected provider. Observed output never replaces an expected
answer without this process.

## Checker Mutation Gate

Before provider conformance is trusted, the checker must reject deliberate
mutations that:

- pass a stale valuation mark as an execution price;
- leave a superseded halt active;
- omit a carried holding; and
- omit a required transform or cache dependency.

The mutations test the checker, not a second execution implementation.

## Stage 1 Completion

Stage 1 is complete only when W01-W31 are approved in the registry, every
referenced fixture and expected table exists, the policy status is maintainer
approved, and the gate script exits successfully.
