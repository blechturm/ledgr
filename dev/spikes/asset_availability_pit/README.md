# Asset Availability And PIT Universe Spike

**Status:** Stage 3 is independently reviewed and gate-complete. The redirected
Stage 4 provider comparison is complete after independent review. Stage 5 is
complete after independent review with an inconclusive terminal outcome.
The prior v2 evidence remains at
`b818d761891516cea5c1afd2a4b05724cca84fd6`; witness v3 and the reviewed Stage 3
implementation are anchored at `d7a1fd3`.

**Branch:** `spike/asset-availability-pit-universes`.

**Package base commit:** `1f42cf7`.

**Authority:**

- the asset-availability spike charter under `inst/design/rfc/`;
- the companion response-review addendum;
- the Seed v1 and reviewed response named by the charter; and
- `inst/design/contracts.md` for current production boundaries.

This branch is a non-release evidence branch. It must never merge into a
release or default branch. Its immutable commits and retained evidence remain
available for reproducibility; only reviewed design conclusions may be carried
back through a separate commit.

## Roles

- The repository maintainer approves the initial policy configuration and each
  exact expected witness outcome.
- The maintainer substituted Codex as the Stage 3 spike executor.
- Claude, or another author who did not execute Stage 3, reviews conformance
  before the implementation is committed and before Seed v2 consumes it.

The executor and reviewer identities must be recorded in the final evidence
manifest. One person or model must not approve, execute, and certify the same
result.

## Stage 3 Gate

Charter clarification, evidence freeze, and the Stage 2 gate are complete.
Stage 3 rechecks ancestry from `c82c485` and every frozen input hash without
rerunning the pre-prototype gate, which must reject code after Stage 2.

Stage 3 closes only after:

1. Witness v3 is committed and recorded as the active evidence.
2. W21 passes direct package/fork dense parity and its frozen expected table.
3. Five hand-calculated checker baselines match their frozen tables; they are
   not representation-conformance results.
4. M1-M5 are each rejected with the required finding.
5. Independent review accepts the implementation and change inventory.
6. The committed code's first-appearance hashes are recorded in
   `evidence/stage3_code.csv`, then `check_stage3.R --mode=gate` passes.

All six conditions are satisfied. The final gate passed at `093e946` on
2026-09-07.

## Stage 4 Review

Stage 4 sends all W01-W31 records through one `stage4_run_case()` fork behind
three provider representations. Ten witnesses are executable conformance
checks; 21 remain visible as `policy_example` records because this fork cannot
independently fail them. M1-M5 are each rejected once through the fork. W20
covers direct, serialized-restore, and PSOCK execution. Timing is prohibited.

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/run_stage4.R
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/check.R
```

Stage 2 and Stage 3 remain committed evidence. Stage 4 does not rerun their
gates or reproduce their provenance machinery.

## Workspace

| Path | Purpose |
| --- | --- |
| `witness_spec.md` | Exact input/output schema and freeze protocol |
| `witness_registry.csv` | Frozen W01-W31 approvals and artifact paths |
| `stage4/fixtures.R` | Stage 4-owned executable/example classification |
| `initial_policy_config.md` | Maintainer-approved v4 comparison policy |
| `fixtures/` | Self-contained fixture manifests with embedded source tables |
| `expected/` | Independently calculated expected-output tables |
| `references/` | Registered independent reference calculations |
| `evidence/` | Branch-tracked manifests, environment records, and conclusions |
| `evidence/stage5_terminal_report.md` | Reviewed inconclusive terminal report and Seed v2 handoff |
| `scratch/` | Ignored local logs, profiles, and replaceable scratch output |
| `check_stage2.R` | Stage 2 structural, review, and evidence-freeze gate |
| `stage3/`, `run_stage3.R`, `check_stage3.R` | Reviewed shared-fork control and Stage 3 gate |
| `stage4/`, `run_stage4.R`, `check.R` | Shared-fork provider comparison and reproducibility check |

Later code, if Stage 2 passes, stays below this directory. It must not modify
`R/`, `src/`, `tests/testthat/`, `NAMESPACE`, `DESCRIPTION`, or `man/`.
`scratch/` may not contain executable or code-bearing files before the gate;
being ignored by Git does not exempt a file from the tripwire scan.

## Planned Execution

1. Preserve the already frozen charter revision.
2. Freeze exact witness evidence and the initial policy.
3. Build the disposable fork and one reference provider.
4. Prove dense parity and checker mutation sensitivity.
5. Add remaining providers. The redirected stage omitted the chartered user
   journeys and usability checks.
6. Measure only semantic survivors and record a green, red, or inconclusive
   result. The redirected Stage 4 left no provider eligible for charter-valid
   timing, so Stage 5 recorded an inconclusive result without measurements.

No timing produced before the conformance gate is architecture evidence.
