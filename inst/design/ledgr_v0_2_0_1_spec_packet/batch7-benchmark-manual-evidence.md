# v0.2.0.1 Batch 7 Benchmark And Manual Evidence

Status: Implemented; pending independent review.

Tickets: LDG-2731 and LDG-2732.
Implementation base: `0f618fd9693584ff0a36dc6447d1cb32c56ccfda`.

## Peer phase split

Every peer row now carries four measured phase fields:

- `snapshot_prepare_sec` for reusable native data preparation;
- `experiment_setup_sec` for work rebuilt for each experiment;
- `engine_sec` for the declared execution boundary; and
- `results_sec` for required canonical result materialization.

`cold_end_to_end` is the sum of all four fields.
`warm_research_iteration` excludes only snapshot preparation. The historical
`ingestion_sec` performance column remains as a compatibility aggregate of
snapshot preparation plus experiment setup, but is no longer an interpretation
boundary. A missing phase must carry an explicit reason and makes every derived
clock that needs it unavailable. Completed rows with four phases fail unless
their total reconciles with the outer row wall within 0.5 seconds.

The boundaries are implemented per engine rather than inferred afterward.
Durable ledgr separates sealed-snapshot creation from experiment construction.
Memory-backed ledgr separates reusable bars matrices and views from feature
projection and execution-spec construction. Quantstrat separates xts/native
data preparation from portfolio and strategy setup. Backtrader separates
grouped pandas bars from feed, broker, and strategy setup. Zipline treats its
csvdir bundle and ingest as reusable preparation. LEAN measures project setup
outside the CLI and keeps the CLI's inseparable internal data loading inside
the engine phase.

The Python wrapper measures its own environment/process overhead and canonical
artifact reads rather than leaving them as an unexplained gap. Child-reported
phases remain in metadata as `child_phase_sec`; the performance row uses the
reconciled outer phases.

The `record` preset defaults remain 100 instruments and 252 sessions. The
release command still pins the accepted 500 by 1,260 workload, SMA 5/10, seed
20260530, and `--engine-set all` explicitly. No record run was performed in
this batch.

## Smoke evidence

The full smoke preset ran from the source tree under R 4.6.1 at implementation
base `0f618fd`, release label v0.2.0.1, engine set `all`, and the unchanged smoke
shape. Generated files remained outside the repository under the local smoke
stem `peer_benchmark_smoke_20260917T084903Z`.

| Engine | Status | Full row | Snapshot | Setup | Engine | Results | Cold | Warm |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| durable ledgr TTR | DONE | 3.45 | 0.49 | 0.42 | 2.20 | 0.32 | 3.43 | 2.94 |
| memory-backed ledgr TTR | DONE | 0.49 | 0.03 | 0.01 | 0.39 | 0.04 | 0.47 | 0.44 |
| durable ledgr built-in SMA | DONE | 3.66 | 0.82 | 0.61 | 1.79 | 0.44 | 3.66 | 2.84 |
| quantstrat | UNAVAILABLE | 0.03 | unavailable | unavailable | unavailable | unavailable | unavailable | unavailable |
| Backtrader | UNAVAILABLE | 6.74 | unavailable | unavailable | unavailable | unavailable | unavailable | unavailable |
| zipline-reloaded | UNAVAILABLE | 11.26 | unavailable | unavailable | unavailable | unavailable | unavailable | unavailable |
| LEAN | UNAVAILABLE | 5.25 | unavailable | unavailable | unavailable | unavailable | unavailable | unavailable |

Seconds are smoke-harness verification only, not a stable record or ranking.
The two comparable ledgr rows passed parity before their timings were read:
memory-backed versus durable equity correlation was 1 with maximum relative
divergence below `1e-15`, and built-in SMA versus TTR had zero maximum relative
divergence. Quantstrat was not installed. The Python peer environments could
not provision missing locked dependencies because this execution environment
denied network access; their rows remained explicitly unavailable with the
underlying reasons. No substitute engine ran.

An independent synthetic checker also proved that the phase arithmetic accepts
an exact four-phase row, rejects an outer-wall mismatch, rejects a missing phase
without a reason, accepts a missing phase with a named reason, and leaves the
record-preset defaults unchanged.

## Manual refresh

`optimization_coding_style.qmd` and its Markdown sibling now describe the
provider, diagnostic block, and grouped validators as production code. The
evidence table records the completed 24.93-second diagnostic-block spike median
without presenting it as a release record, names valuation as the next measured
lane, removes spike-option and uncommitted-seam prose, records the exact parity
exclusions, and updates finalization and source anchors.

`benchmark_methodology.qmd` and its Markdown sibling now define the four peer
phases, cold and warm formulas, unavailable-field rule, provider-build
classification, per-engine boundaries, reconciliation requirement, and the
explicit v0.2.0.1 release command. It asserts no record prefix, release
environment, peer parity result, forecast, or ranking.

Both articles and the manual index were rendered with the bundled Quarto. A
source-anchor check resolved all 42 explicit `R/...:line` and
`dev/...:line` references in the two sources. The documentation-contract test
locks the new clock names, warm provider boundary, production seam wording,
valuation handoff, and identity comparison.

## Verification

- peer benchmark smoke preset: completed; required ledgr rows DONE and all
  optional unavailable rows retained with reasons;
- synthetic phase checker: `PHASE_CHECKS_OK`;
- R and Python syntax parsing: passed for the R harness and all three Python
  peer drivers;
- manual source-anchor check: 42 of 42 explicit anchors resolved;
- Quarto renders: completed for both articles and the manual index; and
- documentation-contract test: passed after final Batch 7 governance
  alignment.

The explicit 500 by 1,260 peer record, record-specific peer README/report
update, availability warm record, and registered full-scale cold seal remain
owned by Batch 8.
