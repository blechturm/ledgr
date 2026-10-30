# Current-tree public-run baseline

This is the descriptive Workstream 3 baseline for Cut 2. It is not a
before/after regression arm, a peer ranking, or a speed claim.

- Installed product: `5002f8d81f17a81177d4b0cda2fa147d310e5e1c`.
- Timing driver and shared-host identity commit:
  `f99e387da42f3fb8ebdf9d488368a63cd5ff604f`.
- Shared host blobs: `host.R` `723453ffad40ec819f8251a351bf58668326237e`;
  `host.ps1` `769a7beba003518b01cc88256bb95f15545bda1d`.
- Native oracle: `dev/bench/peer_benchmark/dense/oracles/20261030-pre-ws4/`
  at accepted freeze `cbf25359`.
- Host: Windows 11, i9-12900K, R 4.6.1, High performance plan, inherited
  `0xFFFF` P-core affinity, scalar external thread settings. CPU and foreign-R
  observations are in the 21 shared-host CSVs and do not select rows.
- Attempt policy: one attempt, five isolated processes per shape, cold then
  warm in each process, no automatic retry. All ten processes completed.

The cold clock includes process start, package import, raw input read,
snapshot creation and sealing, experiment construction, `ledgr_run()` and the
required result materialization. The warm clock reuses only the unchanged
sealed snapshot and completed first-use work; it creates a separate experiment,
book and run, hydrates features again, and materializes the same fills, equity,
cash and keyed holdings.

| shape | clock | n | median s | min s | max s |
|---|---:|---:|---:|---:|---:|
| 12 x 90 | cold | 5 | 1.459739 | 1.449157 | 1.472072 |
| 12 x 90 | warm | 5 | 0.470000 | 0.450000 | 0.470000 |
| 500 x 1260 | cold | 5 | 28.339860 | 28.108557 | 28.810301 |
| 500 x 1260 | warm | 5 | 24.530000 | 24.470000 | 24.580000 |

`record.rds` is the lossless primary record. `raw.csv`, `summary.csv`,
`attempts.json`, `session.json`, environment files and shared-host summaries
are readable sidecars. `timing_check.R --gut` passes all four behavioral and
four structural corruptions. The dense native checker also reproduced all nine
accepted oracle arms on the measured product tree. The small row is fixed-call
overhead evidence only and must not be used to rank scaling.
