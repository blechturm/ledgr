# Spike Evidence Manifest

**Status:** Stage 3 independently reviewed; active-evidence and code-origin
anchors recorded; final Stage 3 gate pending.

## Repository

- Package base commit: `1f42cf7`.
- Evidence branch: `spike/asset-availability-pit-universes`.
- Frozen charter commit: `1f42cf7`.
- Stage 2 evidence commit: `b818d761891516cea5c1afd2a4b05724cca84fd6`.
- Superseded Stage 2 evidence commit:
  `56ef24bb3f80d06ba616a8501dd61ee4ba2e70f6` (the first gate run exposed a
  Windows `HOME` lifetime defect in the checker; expected answers were
  unchanged in witness specification v2).
- Stage 2 gate-record commit: `9d957a30d13f2fd42b6a09bbad1b1d65ddb528b5`.
- Active Stage 2 evidence commit:
  `d7a1fd36d2ab62227e5bba6a86e9fb9672e049ca`.
- Correction record: `stage2_correction_v3.md`.
- Final immutable spike commit or archive reference: pending.
- Prototype change inventory: `stage3_change_inventory.md`.
- Stage 3 code registry: `stage3_code.csv`; every executable first appears at
  `d7a1fd36d2ab62227e5bba6a86e9fb9672e049ca`.

## Roles

- Maintainer approver: repository maintainer.
- Stage 3 spike executor: Codex, by maintainer substitution.
- Stage 3 independent conformance reviewer: Claude; changes required in the
  first review and corrected implementation accepted on re-review.
- Terminal-outcome reviewer: pending.

## Frozen Inputs

- Approved policy ID: `asset_availability_initial_policy_v4`.
- Witness specification version: `asset_availability_witness_v3`, maintainer-
  approved and independently reviewed.
- Checker mutation set: M1-M5; the v3 M1 correction is maintainer-approved and
  independently reviewed.
- Machine-readable freeze set: `frozen_hashes.csv`.
- Permitted pre-prototype code: `preprototype_code.csv`.

## Environment

- R, package, operating-system, and provider identity evidence:
  `stage3_results/environment.csv`.
- Relevant environment variables: no policy-changing variables; the local R
  library prepends repository `lib/`.
- Stage 3 fixtures are embedded in the frozen manifests and use no RNG; there
  is no fixture-generator seed for this stage.

## Results

- Stage 3 dense control and checker-baseline tables: `stage3_results/`
  (provisional until the final Stage 3 gate).
- Checker mutation results: `stage3_results/checker_mutations.csv`.
- Measurement bundles: pending.
- Comprehension-check record: pending.
- Failure and repair inventory: `stage3_change_inventory.md`.
- Reviewed terminal outcome: pending.

Stage 2 may change this status to `Stage 2 frozen` only after the policy,
witness specification, fixtures, expected tables, and permitted reference or
mutation code are approved. Their exact hashes must be recorded in
`frozen_hashes.csv`.

`frozen_hashes.csv` is the only source of truth for individual file hashes.
It stores SHA-256 over LF-normalized UTF-8 or ASCII text, sorted by repository
path with radix ordering.

The active Stage 2 evidence commit is the full 40-character commit containing
the approved freeze targets and `frozen_hashes.csv`. The manifest is metadata
and is not a member of its own hash set. The original gate-record commit opened
prototype work only after `check_stage2.R --mode=gate` passed with no
undeclared code present. A reviewed correction does not rerun or weaken that
pre-prototype gate; the Stage 3 gate anchors the corrected set to its later
active evidence commit.

A later-stage checker must record the first-appearance commit for every
prototype executable and verify that each commit descends from the recorded
Stage 2 gate-record commit.
