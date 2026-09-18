# Availability Timestamp Prerequisite Findings

Date: 2026-09-18
Status: complete
Outcome: `NEITHER`

## Question

Can observation-time normalization and primitive session-close comparison
preserve the complete availability-validation result, while the session-close
candidate reaches the preregistered 0.20 same-session ratio?

## Registered fixture and environment

The probe reused the registered availability fixture from the reviewed
provider spike:

- 563 instruments;
- 505 members on the constant axis;
- 757 sessions; and
- 426,191 bars.

The successful run used R 4.6.1 ucrt, ledgr 0.2.0.1, duckdb 1.5.2, and
collapse 2.1.8 from the isolated library. The probe changed no package source.

## Semantic result

All 10 registered comparisons were exact. They cover five observation-time
cases, four session-close cases, and one complete
`ledgr_availability_validate_inputs()` result. The complete result comparison
includes accepted rows, quarantine rows, and report evidence.

The raw case outcomes are in `cases.csv`.

## Measurements

Each operation received one warm-up and three measured repetitions per arm.
Arm order alternated between repetitions.

| Operation | Current runs (s) | Candidate runs (s) | Current median (s) | Candidate median (s) |
|---|---:|---:|---:|---:|
| Observation-time normalization | 16.19, 16.17, 16.28 | 0.03, 0.03, 0.03 | 16.19 | 0.03 |
| Session-close comparison | 7.19, 7.14, 7.28 | 5.49, 5.50, 5.43 | 7.19 | 5.49 |

The session-close candidate-to-current median ratio is 0.763561. The accepted
amendment requires a ratio no greater than 0.20 for either availability branch.
The raw measurements are in `measurements.csv`.

## Disposition

The binding prerequisite outcome is `NEITHER`.

Observation-time normalization is exact and much faster in isolation, but the
accepted amendment explicitly forbids shipping it alone. The exact
session-close candidate misses the preregistered admission threshold by a wide
margin. Therefore neither availability-ingestion optimization enters
v0.2.0.1, and Section 5.3 authorizes no availability-ingestion source change.

Snapshot-hash timestamp deduplication remains independently eligible because
Section 5.4 gives it a separate byte-identity proof and removal rule.

## Execution notes

Two premeasurement starts failed before any outcome was produced. The first
resolved the default collapse 2.1.7 library, which no longer satisfies the
package dependency. The runner was then made explicit about the isolated
collapse 2.1.8 library. The second start found a missing `source` field in one
small synthetic no-session fact. That fixture-only defect was corrected before
the successful run. Neither failed start reached warm-up or measurement.

## Reproduction

From the repository root:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/spikes/v0_2_0_1_availability_timestamp_prerequisite/probe.R
```

The runner intentionally exits nonzero for every result other than
`COMBINED_EXACT`. For this accepted `NEITHER` result, the authoritative output
is the printed outcome plus the two persisted CSV files.
