# Batch 11 Public Boundary And Oracle Freeze Evidence

Status: implemented; pending independent Stage L review.

Ticket: LDG-2741.

Baseline commit: `a0bc1efc5f052c1277040d138d4a04036ec11ff0`.

## Boundary correction

The two peer-comparable in-memory rows now call the public one-candidate
`ledgr_sweep()` workflow under method
`public_one_candidate_ledgr_sweep_v002`. The complete public call is inside
the reported clock. The old direct-fold path remains only as an untimed
internal parity oracle and retains its internal-diagnostic identity.

The public inline summary is the authoritative memory result. Floating equity
uses the existing relative `all.equal()` tolerance of `1e-8`; the harness
records maximum absolute and relative residuals plus affected rows and
columns. Fills, realized trades, identifiers, row order, names, classes and
other non-floating fields compare exactly. The oracle never replaces public
equity and its wall clock is recorded outside the peer time.

The focused executable test runs the public method on a small real snapshot,
then proves that an excessive equity residual and an exact-trade mutation both
fail. Separate comparison tests cover canonical-versus-compiled public
returns and realized trades.

## Report integrity

One harness function now prepares both the table and stacked-chart inputs. It
binds the phase order as snapshot preparation, setup/orchestration, engine and
results. It replaces every non-completed display clock with missing data,
emits a `NULL (<status>)` label, and verifies that plotted segments reconcile
to the source cold clock. The test mutates the source total and observes a
failure.

The rendered report uses that function. LEAN remains unavailable and has no
numeric benchmark time. Compiled timing appears only after exact fills/trades,
exact non-floating equity, and floating-equity tolerance checks pass.

## Prerequisite and source containment

Commit `9686229` is an ancestor of the baseline. Its prerequisite result is
`NEITHER`: all ten semantic comparisons were exact, but the session-close
candidate ratio was `0.763561`, above the preregistered `0.20` ceiling.

`R/availability-ingest.R` has normalized SHA-256
`5d23be381943affbdce6f51bf61022723f01247ab9ae8012286109264eb46559`.
The test asserts that value directly. Batch 11 changes no file under `R/`, so
the amendment has neither implemented nor authorized availability ingestion.

## Frozen current-arm prefixes

The runner is
`dev/bench/v0_2_0_1_stage_l/freeze_current_prefixes.R`. It ran under R 4.6.1,
ledgr 0.2.0.1, DuckDB 1.5.2 and collapse 2.1.8. The first completed attempt
resolved DuckDB 1.5.5 from a different user library; its files were replaced
by a clean rerun with the packet's recorded library order. It is not evidence.

At 500 instruments by 1,260 timestamps:

| Current arm | Runs (seconds) | Median | Frozen result |
| --- | --- | ---: | --- |
| dense static coverage | 13.88, 13.78, 13.70 | 13.78 | semantic fingerprint `690d2780...97163` |
| rule-1 snapshot hash | 7.02, 7.64, 7.69 | 7.64 | hash `ed05aa17...c7bb5` |

The exact rows are in `batch11-current-arm-prefixes.csv`. Source hashes are in
`batch11-source-prefixes.csv`. Frozen test-only implementations live in
`tests/testthat/helper-stage-l-optimization-oracles.R` outside both candidate
production sources.

The corrected public-sweep diagnostic record supplies the public current-arm
prefixes, not release evidence:

| Row | Cold | Warm | Engine | Results |
| --- | ---: | ---: | ---: | ---: |
| canonical public sweep | 64.87 | 44.84 | 29.01 | 0.03 |
| compiled spot-FIFO public sweep | 49.71 | 30.38 | 14.78 | 0.08 |

`batch11-public-sweep-prefixes.csv` retains the full phase rows and SHA-256
values for equity, fills and trades. The record is a single diagnostic
current-arm run, not the three-repetition Stage M acceptance measurement.

## Dense Timestamp Validation Proof Plan

Status: `RECLASSIFY`; prospective input to LDG-2742, not an accepted proof.

### A. Decision And Scope

Optimization ID: OPT-C01 / LDG-2742.

Old mechanism: format every timestamp to an ISO string once per instrument
axis, then compare the resulting character vectors.

New mechanism: one primitive instant conversion per instrument axis, with the
accepted explicit missing, non-finite and sub-second guards.

Expected complexity remains linear in instruments times pulses, but removes
the POSIX formatting cost from every cell.

Scope is `R/precompute-features.R:ledgr_precompute_ts_key()` and
`ledgr_precompute_validate_static_coverage()`. Availability-aware paths,
feature values, public inputs, persistence and identity are non-goals.

### B. Eligibility

The exact-parity lane returns `RECLASSIFY`: the amendment intentionally
tightens unsupported direct/internal sub-second behavior. The accepted normal
amendment is the authority. Public workflows, defaults, schema, identity,
accounting, dependencies, workers and caches otherwise remain unchanged. The
Stage L oracle and fixture are bounded and independently reviewable.

### C. Baseline Attribution

Fixture: 500 named axes by 1,260 POSIXct values, 630,000 cells. Clock: wall
around `ledgr_precompute_validate_static_coverage()`, warm process, one warm-up
and three measurements. Current median: 13.78 seconds. The call is reached by
public precompute and sweep preparation; it is not a private benchmark-only
reader.

### D. Semantic Matrix

LDG-2742 must compare the retained Stage L oracle and candidate across the
complete amendment Section 4.3 matrix. Supported values compare exactly.
Newly tightened missing, non-finite and unequal sub-second cases must raise the
specified class and contract-bearing message.

### E. Identity And Persistence

None. This validator writes no persisted artifact. Public sweep outputs before
and after the change remain subject to the Batch 11 exact/tolerance contract.

### F. Numerical Comparison

Public inline memory equity remains authoritative. The existing relative
`all.equal()` tolerance is `1e-8`; no widening is allowed. Maximum residuals,
affected rows and columns are recorded. All non-floating surfaces stay exact.

### G. Structural Regression Gate

The candidate must show one vector conversion per instrument axis and zero
per-bar formatting calls. A source guard rejects scalar `vapply()` formatting.
A deliberate repeated-format mutant must fail the operation counter or source
guard.

### H. Performance Result

Preregistered thresholds are the amendment Section 4.4 thresholds: validator
median at most 0.10 of current; canonical and compiled public warm rows each
improve by at least 10 seconds and by more than current spread; peak working
set no more than 15 percent above current. One warm-up and three measurements
per arm run on one quiet host.

### I. Verification

Focused semantic/failure matrix, consumer tests, structural mutation, paired
public record, affected suite, `R CMD check`, diff check and containment.

### J. Independent Review

The reviewer reruns semantic gates, mutates one case, guts the structural
mechanism, verifies the public clock, and confirms the oracle and containment.

## Snapshot Hash Timestamp Deduplication Proof Plan

Status: eligible prospective exact-parity proof for OPT-L01 / LDG-2743.

### A. Decision And Scope

Old mechanism: format every bar timestamp independently inside each fetched
hash chunk. New mechanism: format distinct timestamp values once per existing
chunk and map tokens back in original row order.

The change is bounded to timestamp token construction inside
`ledgr_snapshot_hash()`. Query order, chunk size, numeric formatting,
separators, algorithms, rule versions, availability payloads, stored hashes,
verification and persistence are non-goals.

### B. Eligibility

All template statements must pass before implementation. The mechanism is
bounded, public seal/run guards reach it, APIs and identities are unchanged,
the frozen token oracle remains available, and the registered rerun is
bounded. Any byte difference stops and removes OPT-L01.

### C. Baseline Attribution

Fixture: the registered 630,000-bar rule-1 snapshot with default 10,000-row
fetch chunks. Clock: complete `ledgr_snapshot_hash()`, warm process, one
warm-up and three runs. Current median: 7.64 seconds. The hash is paid at seal
and verification; it is not a private result-reader cost.

### D. Semantic Matrix

Compare old and candidate tokens, byte streams and hashes for rule 1 and rule
2, repeated and unique timestamps, missing numerics, all canonical columns,
the specified chunk sizes and boundary row counts, old/fresh snapshots,
reopen, run guard, and timestamp/price/stored-hash tampering.

### E. Identity And Persistence

Record byte lengths, old/new SHA-256, first differing byte on failure, rule
version and chunk boundary. Fresh and old snapshots must reopen and verify;
tampering must still fail. No migration or hash-version change is permitted.

### F. Numerical Comparison

None. Byte identity is the standard; numerical tolerance is forbidden.

### G. Structural Regression Gate

Count formatter input elements and require no more than 0.20 of source rows at
the registered shape. Reject a restored per-row formatter source shape. A
deliberate no-dedup mutant must fail the counter while retaining the same
hash, proving the gate detects mechanism rather than only output.

### H. Performance Result

At the registered shape, the complete candidate hash median must be at most
0.80 of current and peak working set no more than 15 percent above current.
Run one warm-up and three measurements per arm in the same quiet session.

### I. Verification

Focused chunk/rule/tamper tests, full snapshot tests, old-artifact reopen,
deterministic evidence rerun, `R CMD check`, diff check and containment.

### J. Independent Review

The reviewer reruns byte gates, perturbs one artifact, guts deduplication,
verifies the public seal/guard reachability, and confirms no identity,
dependency, schema or API change.

## Verification

All checks used R 4.6.1 with collapse 2.1.8 and DuckDB 1.5.2:

| Test file | Blocks | Expectations | Failed / warning / skipped |
| --- | ---: | ---: | ---: |
| `test-peer-benchmark-boundary.R` | 5 | 25 | 0 / 0 / 0 |
| `test-documentation-contracts.R` | 75 | 2,479 | 0 / 0 / 0 |
| `test-sweep.R` | 29 | 296 | 0 / 0 / 0 |
| `test-sweep-retention.R` | 16 | 144 | 0 / 0 / 0 |
| `test-precompute-features.R` | 12 | 63 | 0 / 0 / 0 |
| `test-snapshots-hash.R` | 6 | 15 | 0 / 0 / 0 |

The Quarto report rendered successfully from the existing diagnostic record.
`git diff --check` passed. No full peer benchmark, Stage M/N candidate, or
release record ran in Batch 11.

## Review boundary

Batch 11 changes benchmark and test/evidence infrastructure only. It changes
no package source, implements neither candidate, and creates no release speed
claim. LDG-2742 and LDG-2743 remain blocked until this Stage L evidence and
both proof plans pass independent review.
