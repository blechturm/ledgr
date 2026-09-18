# v0.2.0.1 Batch 14 Stage O Evidence

Status: accepted after independent Stage O review and explicit maintainer
acceptance. This evidence artifact does not itself authorize Batch 15; the
maintainer's subsequent instruction does.

## Source freeze and containment

All promoted records execute package and benchmark source from commit
`bcced9457de58f10f9c862c2890576a7370b1140` on branch `v0.2.0.1`, after
LDG-2744 finalized the exact-parity template. Package version is `0.2.0.1`.
The session used R 4.6.1 ucrt on Windows build 26200, 24 detected logical
cores, duckdb 1.5.2, testthat 3.3.2, and collapse 2.1.8. No other R benchmark
or heavy computation overlapped a promoted record. The availability record
resolved from `C:/tmp/ledgr-quantstrat-batch10-lib`; the hash record resolved
from `C:/tmp/ledgr-collapse-218-lib`. Both resolved the same recorded R,
duckdb, testthat, and collapse versions. The peer record separately preserves
its complete environment and isolated quantstrat library provenance.

The peer report prose and Stage O wrappers were written after the source
freeze. They do not alter package execution or the tracked peer harness.
`R/`, `src/`, `DESCRIPTION`, `NAMESPACE`, and
`dev/bench/peer_benchmark/peer_benchmark.R` remained identical to the source
freeze for every promoted run. The raw peer environment independently records
the full source SHA and harness SHA-256.

After the records, a citation-only correction replaced an incorrectly
expanded Batch 13 SHA in the proof template with the actual full commit
`765e4677876bdc3f53cdeee871fbb7f2c9e82c53`. The short commit `765e467` had
been correct; no authority rule, proof requirement, package code, harness, or
record input changed. The execution source remains the exact frozen commit
above rather than being relabelled as the later documentation state.

The exact promoted prefixes and harness hashes are also recorded in
`batch14-stage-o-records.csv`. Earlier Batch 8, Batch 10, Stage L, Stage M,
Stage N, and corrected-working-tree records remain diagnostic or mechanism
evidence. None was renamed or promoted.

## Proof-template disposition

`inst/design/exact_parity_internal_optimization_proof_template.md` is accepted
as evidence infrastructure. It is indexed from the design index and this
packet, and documentation contracts lock its title, accepted status,
private-harness stop, tolerance/authority stop, OPT-C01 `RECLASSIFY` result,
and OPT-L01 worked-proof citation.

The template creates no standing no-ticket or no-RFC lane. Accepted
specifications, tickets, the spike protocol, RFC decisions, independent
review, and maintainer scope decisions remain authoritative.

## Availability cold, warm, and profile record

Promoted prefix:

`dev/bench/results/v0_2_0_1_stage_o_availability_bcced94_20260918T123618Z/`

Harness SHA-256:

`a55b3749be43164770d78e1cbddf6d5120a45b9580f0bfafbe122c16e41a4302`

The registered fixture contains 563 instruments, a 505-member axis, 757
sessions, 60 complete membership lists, 426,191 bars, 30,300 membership rows,
flat targets, zero fills, and 383,042 diagnostic rows. The cold clock includes
deterministic fixture construction through sealing. Warm clocks surround
public production `ledgr_run()` calls over copies of the reused sealed
snapshot.

| Measure | Result | Gate | Disposition |
| --- | ---: | ---: | --- |
| cold end to end | 119.11 s | completion | PASS |
| cold peak working set | 649.0 MiB | 4,096 MiB safety stop | PASS |
| warm measured walls | 17.40 / 17.89 / 17.55 s | median <= 60 s | PASS |
| warm median | 17.55 s | <= 60 s | PASS |
| warm spread, `diff(range())` | 0.49 s | reported | PASS |
| warm measured peaks | 753.8 / 793.9 / 754.5 MiB | each <= 1,024 MiB | PASS |
| warm statuses | three `DONE` | all `DONE` | PASS |

The historical 60-to-90-second cold estimate missed: the measured cold clock
is 119.11 seconds. It was a forecast, not a release gate, and is not promoted
over this result. The old quadratic availability validator is absent; the
seal-time availability validation phase measured 1.52 seconds. Other inclusive
phase observations include 50.55 seconds in input validation, 8.49 seconds in
availability writes, and 9.76 seconds in snapshot hashing. Inclusive phases
are not added as disjoint wall partitions.

The same registered fixture in Batch 10 measured 90.56 seconds cold and a
14.51-second warm median. Against those observations, Stage O is 31 percent
slower cold and 21 percent slower warm. Its inclusive input validation,
schema creation, availability write, seal validation, and snapshot-hash
observations moved from 35.50, 0.22, 6.28, 1.06, and 8.91 seconds to 50.55,
0.32, 8.49, 1.52, and 9.76 seconds. No package code in the first four paths
changed between the two records. The broadly similar inflation is consistent
with a transiently slower host during this availability run; its exact cause
was not observed and cannot be reconstructed. Seven minutes later the hash
record's 7.66-second current arm reproduced Batch 13's 7.62 seconds closely.
The smaller hash increase is also consistent with the accepted deduplication
offsetting most of the host-side difference. Stage O retains the measured
119.11 and 17.55 seconds rather than normalizing or replacing them.

The profiled warm run completed in 18.83 seconds. Its largest captured in-loop
group is `residual_fold`, 175 samples and 71.1 percent of captured in-loop
samples. This is sampled attribution, not a wall-time partition or a new
optimization forecast.

The pre-retirement context remains the untouched prefix
`dev/bench/results/v0_2_0_1_batch4_preretirement_cf93d86/`: its production
median was 26.02 seconds and its retired scalar reference median was 119.03
seconds. The final 17.55-second record does not restore either retired path.

## Snapshot-hash paired record

Promoted prefix:

`dev/bench/results/v0_2_0_1_stage_o_hash_bcced94_20260918T124304Z/`

Wrapper SHA-256:

`848144fd5a5e5a29015aef3f734502a6ca5cae2cb7da7326908c60b9a90875fe`

The wrapper reuses the reviewed Stage N fixture, old-arm binding restoration,
external sampler, and gate functions. It changes only the immutable output
location. The fixture is 500 instruments by 1,260 sessions, 630,000 bars,
seed 20260530, `STAGE_L_` identifiers, and 10,000-row hash chunks.

| Measure | Current | Candidate | Gate | Disposition |
| --- | ---: | ---: | ---: | --- |
| formatter inputs | 630,000 | 79,380 | ratio <= 0.20 | PASS, 0.126 |
| measured median | 7.66 s | 5.14 s | ratio <= 0.80 | PASS, 0.671018 |
| maximum peak | 430.852 MiB | 430.543 MiB | ratio <= 1.15 | PASS, 0.999284 |

All eight calls finished `DONE`. Every computed and stored hash is exactly
`ed05aa170e93af7e2f229f9d920882faad844e91b03397b1293a0722fcac7bb5`,
the frozen Stage L rule-1 hash. Fixture construction and database opening are
outside the measured hash clocks.

The prerequisite's `NEITHER` outcome remains binding. The normalized SHA-256
of `R/availability-ingest.R` remains
`5d23be381943affbdce6f51bf61022723f01247ab9ae8012286109264eb46559`;
no availability-ingestion optimization entered the release.

## Final peer record

Promoted prefix:

`dev/bench/results/peer_benchmark_record_20260918T140507Z`

Peer-harness SHA-256:

`6b7ab57149a6e17b0f386117b82c8e33ac19eb3eb84eda3be6995571230b5f2f`

External sampler-wrapper SHA-256:

`90b90a5c2712b4dc80316a1f7d9804edd0ba1fee85a8a08fd74832e0d51faafe`

The exact command is printed in the tracked README and rendered report. It
uses preset `record`, release `v0.2.0.1`, all engines, 500 instruments, 1,260
days, SMA 5/10, seed 20260530, and opt-in compiled accounting model
`spot_fifo`. The benchmark method is
`public_one_candidate_ledgr_sweep_v002`.

| Engine | Status | Cold / full clock | Warm research iteration |
| --- | --- | ---: | ---: |
| durable ledgr TTR | DONE | 75.78 s | 58.23 s |
| canonical public sweep | DONE | 48.63 s | 30.96 s |
| compiled public sweep | DONE | 33.66 s | 16.63 s |
| durable ledgr built-in SMA | DONE | 67.85 s | 50.94 s |
| quantstrat | DONE | 356.20 s | 346.05 s |
| Backtrader | DONE | 83.87 s | 83.30 s |
| zipline-reloaded-full | DONE | 305.61 s | 289.86 s |
| local LEAN | UNAVAILABLE | missing | missing |

LEAN's configured local CLI root uses the obsolete organization layout. Its
status is `UNAVAILABLE`, its reason is retained, all phase times are missing,
and no hosted service was used.

An external one-second sampler covered the complete benchmark process tree.
The raw sidecar contains 964 samples, observed as many as nine live processes,
and independently recomputes to a peak working set of 1,754.26171875 MiB. This
is a record-level peak, not an engine-specific allocation. The sampler is
external to the harness clocks and its overhead is part of the host load.

### ledgr parity before timing

After normalizing only the engine label, the canonical and compiled public
sweep rows are exact across all 1,260 equity rows, 68,201 fills, and one
realized-trade row. Against durable ledgr, fills and trades are exact.
Compensated production-inline equity passes the existing relative
`all.equal()` tolerance of `1e-8`:

- maximum absolute residual: `4.0046870708465576e-07`;
- maximum relative residual: `4.7321774610389843e-13`;
- affected cells: 3,578 across 1,247 rows; and
- affected columns: `equity`, `positions_value`, and `position_proxy`.

Earlier peer parity CSVs used reconstructed equity. This final record uses
compensated production-inline equity as the memory reference. The untimed
private oracle supplies richer parity surfaces only; it is not a timed peer
row.

Quantstrat completed from `C:/tmp/ledgr-quantstrat-batch10-lib` with:

- quantstrat 0.25 at
  `1114e4a1a8a3b68d2fb7a62b52d743cbc5e4b39f`;
- blotter 0.17.0 at
  `dddb448f7a5d6eb63dfbe421ba80779e820a3601`;
- FinancialInstrument 1.3.0 at
  `98bcf09fc80e25611897404dcd59321ef67850ac`;
- xts 0.14.2; and
- TTR 0.24.4.

Backtrader passes the registered equity tolerance with 0.999746 daily-return
correlation. Quantstrat passes that tolerance with 0.987795 correlation and a
partial trade surface. Zipline passes the weak numerical tolerance but has
only 0.146064 daily-return correlation, so the report retains it as a
weak-tolerance review result rather than full parity. Zero divergence is
reported as a count, not a zero-denominator percentage.

The tracked report renders phase order as snapshot preparation, experiment
setup, engine, and results. Unavailable values remain missing. Status comes
from `Status`, reason remains separate, conditional prose depends on row
presence, and the report contains explicit non-ranking language.

## Peer-record attempt history

Three earlier same-source peer bundles remain local and are not promoted:

- `peer_benchmark_record_20260918T130244Z` completed but omitted the registered
  process-tree peak field;
- `peer_benchmark_record_20260918T132659Z` completed, but the first sampler
  wrapper treated a null redirected-process exit code as failure before
  persisting its in-memory samples; and
- `peer_benchmark_record_20260918T134600Z` completed, but the second wrapper
  counted both `_status.csv` and `_surface_status.csv` as candidate prefixes
  before persisting its in-memory samples.

The final wrapper persists samples to a temporary CSV before prefix detection,
excludes `_surface_status.csv`, writes raw and peak sidecars, and then removes
temporary logs. None of the abandoned prefixes contributes a timing, parity,
or memory value to the promoted record.

## Verification

- `check_stage_o_records.R`: `STAGE_O_RECORD_CHECKS_OK: 48 checks`;
- documentation-contract tests: pass;
- peer-benchmark-boundary tests: pass;
- snapshot-hash-deduplication tests: pass;
- dense-timestamp-validation tests: pass;
- peer Quarto render against the final prefix: pass; and
- `git diff --check`: pass.

The complete suite, package build, package check, and release audit remain
Batch 15 work. These bounded record checks do not substitute for that gate.

## Stage O disposition

Every registered availability warm, snapshot-hash identity/performance, and
peer-row gate passes. The cold seal completes and supersedes the forecast.
The proof template is finalized without gaining implementation authority.
The records share one accepted source commit and use distinct immutable local
prefixes.

Stage O stopped for independent evidence review and explicit maintainer
acceptance; both passed on 2026-09-18. This document does not authorize Batch
15 or release closeout by itself.
