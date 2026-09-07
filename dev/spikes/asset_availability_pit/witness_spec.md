# Stage 2 Witness Evidence Contract

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
| `comparison` | `exact` for non-double values or `abs_tol` for doubles |
| `tolerance` | Non-negative absolute tolerance for doubles; blank otherwise |
| `derivation` | Short independent arithmetic or temporal justification |

Additional case-specific tables are allowed, but this long table is the
minimum checker input and cannot be replaced by prose.

Logical values use lowercase `true` or `false`; integers use base-10 strings;
timestamps use UTC ISO-8601 strings; and absent values use an empty
`expected_value`. Double values use a canonical decimal expectation and an
explicit per-row absolute tolerance. There is no implicit global numeric
tolerance.

`identity_expectation` is one of `equal`, `changed`, `absent`, or
`not_applicable`. The gate validates these representations before hashing.

## Freeze Protocol

1. The executor writes fixture manifests without running prototype output.
2. Expected tables are calculated independently by hand or by a tiny reference
   calculation that does not call the shared fork or a representation provider.
3. The maintainer approves the policy and expected outcomes.
4. A non-executing reviewer checks temporal reasoning, arithmetic, and table
   completeness.
5. Approved files receive immutable content hashes in
   `evidence/frozen_hashes.csv`.
6. Registry status changes to `approved` only after both approvals.
7. Commit the approved freeze targets and record that full commit in the
   evidence manifest.
8. Record the exact, sorted SHA-256 freeze set in
   `evidence/frozen_hashes.csv`.
9. `check_stage2.R --mode=gate` must pass before fold-fork code begins.

Frozen inputs are UTF-8 or ASCII text. SHA-256 is computed after normalizing
CRLF and bare CR endings to LF, while preserving all other bytes and the final
newline. Paths are sorted bytewise with radix ordering. Any hash generator and
the gate checker must apply those same rules so checkout line endings cannot
change the freeze identity.

The clean-workspace guard intentionally rejects an in-place line-ending
rewrite even when normalized content would hash identically. Make such changes
through a reviewed commit before recording the Stage 2 evidence commit.

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
Executable reference calculations and mutation scripts must be registered in
`evidence/preprototype_code.csv`; any other executable file under this
workspace closes the gate.

The extension and filename scan is a tripwire for common executable or
code-bearing files, including R, SQL, shell, command, profile, Makefile, and
text-script forms. It is not a content classifier. The frozen commit, clean
workspace requirement, exact hash set, and independent reviewer diff remain
the guarantees against disguised prototype code.

## Stage 2 Completion

Stage 2 is complete only when W01-W31 are approved in the registry, every
referenced fixture and expected table exists, the policy status is maintainer
approved, every frozen hash verifies, the freeze commit is recorded, no
prototype code exists, and the gate script exits successfully.
