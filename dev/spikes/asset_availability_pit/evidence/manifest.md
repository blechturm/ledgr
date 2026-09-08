# Spike Evidence Manifest

**Status:** Stage 3 independently reviewed and gate-complete on 2026-09-07.
The redirected Stage 4 shared-fork comparison completed independent review on
2026-09-08. Stage 5 reached an independently reviewed inconclusive terminal
outcome on 2026-09-08.

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
- Active Stage 2 evidence commit: `d7a1fd36d2ab62227e5bba6a86e9fb9672e049ca`.
- Correction record: `stage2_correction_v3.md`.
- Final immutable spike commit or archive reference: pending.
- Prototype change inventory: `stage3_change_inventory.md`.
- Stage 3 code registry: `stage3_code.csv`; every executable first appears at
  `d7a1fd36d2ab62227e5bba6a86e9fb9672e049ca`.
- Stage 3 gate-record commit:
  `093e946a631cddedc32b0c241c176df7d9c4b518`.
- Stage 4 change inventory: `stage4_change_inventory.md`.
- Reviewed Stage 5 terminal report: `stage5_terminal_report.md`.

## Roles

- Maintainer approver: repository maintainer.
- Stage 3 spike executor: Codex, by maintainer substitution.
- Stage 3 independent conformance reviewer: Claude; changes required in the
  first review and corrected implementation accepted on re-review.
- Stage 4 spike executor: Codex, by maintainer substitution.
- Stage 4 independent shared-fork reviewer: Claude; three Medium corrections
  required initially and accepted on re-review with no remaining High or
  Medium findings.
- Terminal-outcome reviewer: Claude, who did not execute Stage 3 or Stage 4;
  the review confirmed the inconclusive classification and required only four
  Low wording and provenance corrections, all applied before commit.

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

- Stage 3 dense control and checker-baseline tables: `stage3_results/`.
- Checker mutation results: `stage3_results/checker_mutations.csv`.
- Stage 4 conformance, one-pass mutation, policy-example, and provider-memory
  evidence: `stage4_results/`.
- Measurement bundles: not produced. The redirected Stage 4 executed 10 of 31
  frozen witnesses and did not leave a provider eligible for charter-valid
  timing. Small-fixture object sizes are structural accounting only.
- Failure and repair inventory: `stage3_change_inventory.md`.
- Stage 4 failure and repair inventory: `stage4_change_inventory.md`.
- Reviewed terminal outcome: inconclusive.

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
