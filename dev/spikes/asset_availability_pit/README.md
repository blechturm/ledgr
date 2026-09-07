# Asset Availability And PIT Universe Spike

**Status:** Stage 2 witness evidence is maintainer approved, independently
reviewed, and frozen at `b818d761891516cea5c1afd2a4b05724cca84fd6`.
Prototype implementation must not start until the gate-record commit exists.

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
- Claude is the charter's default spike executor unless the maintainer records
  a substitution.
- Codex, or another author who did not execute the spike, reviews conformance
  before Seed v2 consumes the result.

The executor and reviewer identities must be recorded in the final evidence
manifest. One person or model must not approve, execute, and certify the same
result.

## Current Gate

Charter clarification and freeze completed at package base commit `1f42cf7`.
The v4 comparison policy and W01-W31 packet are maintainer approved and
independently reviewed. The Stage 2 gate remains closed until:

1. `check_stage2.R --mode=review` passes on the approved packet.
2. Every frozen input matches `evidence/frozen_hashes.csv`.
3. The approved freeze commit is recorded in the evidence manifest.
4. `check_stage2.R --mode=gate` exits successfully before prototype code exists.

Run the checks from the repository root:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/check_stage2.R --mode=setup
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/check_stage2.R --mode=review
```

Setup validates every drafted or approved packet that is present. Review
additionally requires all 31 packets. The gate command is intentionally
expected to fail until Stage 2 is complete:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/spikes/asset_availability_pit/check_stage2.R --mode=gate
```

## Workspace

| Path | Purpose |
| --- | --- |
| `witness_spec.md` | Exact input/output schema and freeze protocol |
| `witness_registry.csv` | Machine-readable W01-W31 status and artifact paths |
| `initial_policy_config.md` | Maintainer-approved v3 comparison policy |
| `fixtures/` | Self-contained fixture manifests with embedded source tables |
| `expected/` | Independently calculated expected-output tables |
| `references/` | Registered independent reference calculations |
| `evidence/` | Branch-tracked manifests, environment records, and conclusions |
| `scratch/` | Ignored local logs, profiles, and replaceable scratch output |
| `check_stage2.R` | Stage 2 structural, review, and evidence-freeze gate |

Later code, if Stage 2 passes, stays below this directory. It must not modify
`R/`, `src/`, `tests/testthat/`, `NAMESPACE`, `DESCRIPTION`, or `man/`.
`scratch/` may not contain executable or code-bearing files before the gate;
being ignored by Git does not exempt a file from the tripwire scan.

## Planned Execution

1. Preserve the already frozen charter revision.
2. Freeze exact witness evidence and the initial policy.
3. Build the disposable fork and one reference provider.
4. Prove dense parity and checker mutation sensitivity.
5. Add remaining providers and run the user and usability checks.
6. Measure only semantic survivors and record a green, red, or inconclusive
   result.

No timing produced before the conformance gate is architecture evidence.
