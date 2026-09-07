# Spike Evidence Manifest

**Status:** Setup initialized; Stage 2 evidence not frozen.

## Repository

- Package base commit: `1f42cf7`.
- Evidence branch: `spike/asset-availability-pit-universes`.
- Frozen charter commit: `1f42cf7`.
- Stage 2 evidence commit: pending.
- Stage 2 gate-record commit: pending until committed after a passing gate.
- Final immutable spike commit or archive reference: pending.
- Prototype change inventory: pending.

## Roles

- Maintainer approver: pending.
- Spike executor: Claude by charter default; confirmation pending.
- Independent conformance reviewer: pending.
- Terminal-outcome reviewer: pending.

## Frozen Inputs

- Approved policy ID: `asset_availability_initial_policy_v2`.
- Witness specification version: pending.
- Checker mutation set: pending.
- Machine-readable freeze set: `frozen_hashes.csv`.
- Permitted pre-prototype code: `preprototype_code.csv`.

## Environment

- R and package versions: pending.
- Operating system and hardware: pending.
- Relevant environment variables: pending.
- Fixture-generator source and seed: pending.

## Results

- Conformance tables: pending.
- Checker mutation results: pending.
- Measurement bundles: pending.
- Comprehension-check record: pending.
- Failure and repair inventory: pending.
- Reviewed terminal outcome: pending.

Stage 2 may change this status to `Stage 2 frozen` only after the policy,
witness specification, fixtures, expected tables, and permitted reference or
mutation code are approved. Their exact hashes must be recorded in
`frozen_hashes.csv`.

`frozen_hashes.csv` is the only source of truth for individual file hashes.
It stores SHA-256 over LF-normalized UTF-8 or ASCII text, sorted by repository
path with radix ordering.

The Stage 2 evidence commit is the full 40-character commit containing the
approved freeze targets before this manifest records the commit. The manifest
and hash registry are freeze metadata and are not members of their own hash
set. A later gate-record commit may precede prototype work only after
`check_stage2.R --mode=gate` passes with no undeclared code present.

A later-stage checker must record the first-appearance commit for every
prototype executable and verify that each commit descends from the recorded
Stage 2 gate-record commit.
