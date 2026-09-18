# v0.2.0.1 Batch 10 Benchmark Evidence

Status: implemented; pending independent review and maintainer acceptance.

This record closes the implementation side of LDG-2733 and LDG-2734. It is
the Stage J measurement checkpoint, not release closeout and not a public
performance ranking. Batch 11 remains blocked.

## Baseline and containment

Both final records ran from committed source
`400a3e56ae49cc61256d0e7aaca66281626d4fe3` on branch `v0.2.0.1`. That commit
is after LDG-2740 and contains the accepted production paths with their
references and selectors retired. The provisional `6b09a1b` records remain
local history and were neither overwritten nor promoted.

The runtime was R 4.6.1 ucrt on Windows build 26200 with 24 detected logical
cores, duckdb 1.5.2, testthat 3.3.2, and collapse 2.1.8 resolved from
`C:/tmp/ledgr-collapse-218-lib`. No other heavy benchmark workload overlapped
these records.

The first availability invocation stopped before fixture construction because
the project profile placed the default collapse 2.1.7 library ahead of the
isolated 2.1.8 library. The partial prefix
`dev/bench/results/v0_2_0_1_batch8_availability_400a3e5/` contains only its
environment and fixture declarations and is not a benchmark result. It was
preserved rather than relabelled. A process-only profile then put the accepted
2.1.8 library first for every parent and child; package and runner source were
unchanged.

## Availability warm and cold record

The exact ignored local prefix is
`dev/bench/results/v0_2_0_1_batch10_availability_400a3e5_20260917T205648Z/`.
The registered fixture contains 563 source instruments, 757 sessions, 426,191
bars, a 505-member axis, and 383,042 diagnostic rows per completed warm run.

The cold clock covers deterministic fixture preparation through the sealed
snapshot. It completed in 90.56 seconds at 674.5 MiB peak working set:

- fixture preparation: 28.61 seconds;
- snapshot construction and seal: 61.84 seconds; and
- post-seal snapshot-info and close residual: 0.11 seconds.

The profiler separately attributed 35.50 inclusive seconds to availability
input validation, 1.06 inclusive seconds to seal-time availability validation,
and 8.91 inclusive seconds to snapshot hashing. Those nested attribution clocks
are not additive with the three wall-clock components above.

The pairwise validator is absent from the installed namespace. The earlier
60-to-90-second cold estimate remains a forecast rather than a gate; the
measured value is reported without rounding it into that range.

One warm-up preceded three measured runs and one profiled run. Every run was
`DONE`, built one provider, constructed 757 diagnostic blocks, and persisted
382,285 decision rows over all 757 pulses.

| Run | Wall seconds | Peak working set MiB |
| --- | ---: | ---: |
| warm-up | 14.43 | 829.3 |
| measured 1 | 14.34 | 820.9 |
| measured 2 | 14.51 | 823.0 |
| measured 3 | 14.61 | 794.9 |
| profiled | 14.61 | 780.0 |

The measured median is 14.51 seconds, the spread is 0.27 seconds, and the
maximum measured peak is 823.0 MiB. The registered 60-second and 1,024-MiB
gates pass. Against the provisional post-Batch-7 median of 25.42 seconds, the
final production median is 42.9 percent lower. Against the pre-retirement
measured, non-profiled block-arm median of 26.02 seconds at
`dev/bench/results/v0_2_0_1_batch4_preretirement_cf93d86/`, it is 44.2 percent
lower. That comparison is context; the fresh record alone satisfies Stage J.

The retired availability reference path was not restored for this record.
Semantic parity remains bound by the accepted paired oracle in
`batch9-valuation-evidence.md`; Stage J measures that accepted production path.
All five fresh runs completed the same 757 pulses, built one provider, emitted
757 diagnostic blocks, and persisted the same 383,042 diagnostic rows and
382,285 decision rows.

The profiled run's largest in-loop group is now residual fold work at 68.5
percent. Durable diagnostic append is 13.3 percent, diagnostic construction is
8.5 percent, and prepared valuation has zero captured samples. These shares
are attribution, not a wall-time partition.

## Peer record

The exact ignored local prefix is
`dev/bench/results/peer_benchmark_record_20260917T212008Z`. The command used the
registered 500-instrument by 1,260-day fixture, SMA 5/10, seed 20260530, all
engines, and `--compiled-accounting-model spot_fifo`.

The dedicated R 4.6.1 library is
`C:/tmp/ledgr-quantstrat-batch10-lib`. Its ignored environment sidecar records:

| Package | Version | Source |
| --- | --- | --- |
| quantstrat | 0.25 | `1114e4a1a8a3b68d2fb7a62b52d743cbc5e4b39f` |
| blotter | 0.17.0 | `dddb448f7a5d6eb63dfbe421ba80779e820a3601` |
| FinancialInstrument | 1.3.0 | `98bcf09fc80e25611897404dcd59321ef67850ac` |
| xts | 0.14.2 | CRAN |
| TTR | 0.24.4 | CRAN |

The three GitHub SHAs are transport-written `RemoteSha` values in the installed
package metadata, not hand-written claims.

| Engine row | Status | Cold seconds | Warm seconds | Engine seconds |
| --- | --- | ---: | ---: | ---: |
| durable ledgr canonical | DONE | 78.21 | 58.53 | 49.33 |
| memory ledgr canonical | DONE | 49.86 | 39.58 | 29.03 |
| compiled spot-FIFO memory ledgr | DONE | 35.23 | 24.56 | 14.42 |
| durable ledgr built-in SMA | DONE | 70.59 | 51.25 | 43.19 |
| quantstrat | DONE | 347.40 | 337.01 | 334.06 |
| Backtrader | DONE | 83.54 | 82.97 | 76.16 |
| zipline-reloaded-full | DONE | 303.03 | 287.39 | 274.74 |
| local LEAN CLI | UNAVAILABLE | NA | NA | NA |

Every `DONE` row reconciles its four phases to the outer row wall within 0.19
seconds. LEAN is explicitly unavailable because the configured CLI root uses
the obsolete organization layout; no hosted service was used.

After normalizing only the engine label, the compiled spot-FIFO and canonical
memory CSVs are exactly identical for equity, fills, and trades. Durable ledgr
fills and trades are also exact; its maximum equity difference from either
memory row is `2.011657e-7`, within the registered durable/memory tolerance.
The compiled timing is interpreted only after those checks.

The built-in ledgr row has zero divergence against the durable canonical row.
Backtrader passes the registered equity-level tolerance with classified
residuals. Quantstrat is `DONE` and passes that numerical tolerance, but its
trade surface is partial. Zipline also meets the equity-level threshold, while
its daily-return correlation is only 0.146064; the tracked report labels that
literally as a weak-tolerance review result rather than full parity.

Compared with the provisional `6b09a1b` record, durable ledgr full-row wall is
53.0 percent lower and its engine phase is 63.9 percent lower. Memory ledgr is
65.5 percent lower end to end and 76.6 percent lower in the engine phase. The
external peer rows moved only 0.4 to 3.3 percent in their engine phases, which
supports attribution to the accepted ledgr corrections without turning the
same-host record into a universal ranking claim.

## Evidence checksums

Raw benchmark artifacts stay ignored. These hashes bind the files used by this
tracked summary.

| File | SHA-256 |
| --- | --- |
| `environment.csv` | `4fba779b55309d875374af1b00f263aa4168723950286cb7e87fc9562e4bace3` |
| `fixture.csv` | `eb3a0445b4263bb528ed69fa5b9d9d6afcb9eb441d62a0f68bc957a1a4a2520a` |
| `cold_seal.csv` | `60d1a693c565fe19db25d865ec1a4a63ffe3006b686e44e1afe84f25ecc0041a` |
| `cold_phases.csv` | `0898d2adb6170862980ce3e4e56e30189153e50fc8bc9c362637e7de86f7fecb` |
| `warm_runs.csv` | `f9208df2f804f091c6677ff0cb4655aa395a9a6ed12cf013e86c62a2e7221c31` |
| `warm_lanes.csv` | `ba4e0d1dc4131c646611a895df6b68c5861b96dae9d4f6c1d7a99ed88290b440` |
| availability `summary.md` | `f51a442fc32cd86a37479679b14a1da8ce29c0b8116212e2d3fb59f174a39a2b` |
| peer `environment.json` | `f1f7cf11521e031e300f80ebe5d0152a8af4a6618dc509b9ce429b983206f159` |
| peer `quantstrat_environment.json` | `f8ee82dbd4f7bc625e381c51028db0349affbff33e119aeee6563947ce51e7e8` |
| peer `status.csv` | `926d2e60d5241d024fce11a711d030b2d426494cb83b84d756aa9f3dfc6f14ef` |
| peer `performance.csv` | `fb0259ec350a777828d549e2f4a517de5b075956db0a8a8611273c948368975d` |
| peer `parity.csv` | `5b4854747d51d4e9caabd7bcdc017257a3930837f10a45c81e7329aed0437a13` |
| peer `divergence_summary.csv` | `9ee0c8f9425c5211951887845b08805449daf22eeeb2d8a965579bf797f134b4` |
| peer `surface_status.csv` | `62f4bcc7e68710b4ac9142bbc742f8542201c69994d2b7812197cfd3a81b0858` |
| peer `summary.md` | `f1d1f16b3948c95214085df34605e62e41b437c07df731693b11f475a0dc9aa8` |
| provisional `6b09a1b` peer `performance.csv` | `4d3dcc91b4bfcb3a1bd01afc319d53269416d811d97d3d054aaae5b11b9bb4fd` |
| pre-retirement block `fold_757.csv` | `b93b98e5d74260b1895c151514dce002a674513a4c06ac47116ba478263bcdef` |

## Stage J disposition

Both measurement tickets are implemented. Every required ledgr and quantstrat
row is present, the availability gates pass, the compiled row passes exact
canonical-memory parity, optional peers are reported literally, and the
provisional records remain unpromoted. Independent review and explicit
maintainer acceptance are still required. Batch 11 must not start from this
document alone.
