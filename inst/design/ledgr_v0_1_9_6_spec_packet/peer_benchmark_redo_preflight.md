# v0.1.9.6 Peer Benchmark Redo Preflight

Status: Batch 10 implementation complete; awaiting Claude review.

Date: 2026-06-15

Scope: LDG-2655 current-surface peer benchmark redo. This artifact records the
prepared benchmark shape, smoke verification, and current-surface record run.
It does not make a public benchmark claim.

## Harness Changes

- Added an explicit public risk-chain axis to the repo-local peer benchmark
  harness.
- Kept the existing zero-cost/no-risk rows:
  `ledgr_cost_zero()` plus `ledgr_risk_none()`.
- Added the representative current-surface row:
  `ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))` plus
  `ledgr_risk_chain(ledgr_risk_long_only(), ledgr_risk_max_weight(0.20))`.
- Preserved the opt-in compiled spot-FIFO row; the current-surface cost/risk
  row does not flip compiled defaults.
- Extended performance CSV and generated summary metadata with `cost_model`,
  `risk_chain`, and `compiled_accounting_model` labels.
- Updated the internal benchmark report template and rendered `.md` so the
  current-surface cost/risk command and boundary row are documented without
  changing the historical record-bundle numbers.

## Smoke Verification

Command:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset smoke --engine-set ledgr-cost --release v0.1.9.6
```

Run metadata:

| Field | Value |
| --- | --- |
| Created at | 2026-06-15T20:59:10Z |
| Release label | v0.1.9.6 |
| Preset | smoke |
| Engine set | ledgr-cost |
| Fixture | 5 instruments x 40 days |
| Seed | 20260530 |
| Input hash | 5e30bd43ff445a8e952f406443bd97028bfa64304bafcc2bd8f6bbe6a8778a79 |
| Git SHA | 332a7bd12cda8d52d1f1387937c79ed812cb7323 |
| ledgr package version | 0.1.9.5 |

Performance rows written:

| Engine | Status | Cost model | Risk chain | Compiled |
| --- | --- | --- | --- | --- |
| ledgr_ttr_canonical | DONE | cost_zero | risk_none | NA |
| ledgr_ttr_canonical_ephemeral | DONE | cost_zero | risk_none | NA |
| ledgr_ttr_canonical_ephemeral_with_costs | DONE | spread_bps+fixed_fee | risk_none | NA |
| ledgr_ttr_canonical_ephemeral_with_cost_risk | DONE | spread_bps+fixed_fee | long_only+max_weight | NA |
| ledgr_ttr_canonical_ephemeral_legacy_costs | DONE | legacy_fill_model_spread_5_fixed_1 | risk_none | NA |

## Record Verification

Command:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" dev/bench/peer_benchmark/peer_benchmark.R --preset record --engine-set ledgr-cost --release v0.1.9.6
```

Run metadata:

| Field | Value |
| --- | --- |
| Created at | 2026-06-15T21:17:30Z |
| Release label | v0.1.9.6 |
| Preset | record |
| Engine set | ledgr-cost |
| Fixture | 100 instruments x 252 days |
| Seed | 20260530 |
| Input hash | 6ffc3d0a4202409fb4f1d1315aa820e8945c6ea0628d234486e976a930df4ed7 |
| Git SHA | 332a7bd12cda8d52d1f1387937c79ed812cb7323 |
| ledgr package version | 0.1.9.5 |

Performance rows written:

| Engine | Status | Cost model | Risk chain | Compiled | Total s | Engine s | Bars/sec |
| --- | --- | --- | --- | --- | ---: | ---: | ---: |
| ledgr_ttr_canonical | DONE | cost_zero | risk_none | NA | 8.38 | 6.12 | 3007.2 |
| ledgr_ttr_canonical_ephemeral | DONE | cost_zero | risk_none | NA | 2.59 | 1.71 | 9729.7 |
| ledgr_ttr_canonical_ephemeral_with_costs | DONE | spread_bps+fixed_fee | risk_none | NA | 1.97 | 1.22 | 12791.9 |
| ledgr_ttr_canonical_ephemeral_with_cost_risk | DONE | spread_bps+fixed_fee | long_only+max_weight | NA | 1.94 | 1.25 | 12989.7 |
| ledgr_ttr_canonical_ephemeral_legacy_costs | DONE | legacy_fill_model_spread_5_fixed_1 | risk_none | NA | 1.75 | 1.10 | 14400.0 |

Record-run warning attribution:

- The initial record command completed and printed "There were 50 or more
  warnings".
- A rerun to a workspace-local temporary output directory with
  `options(warn = 1)` showed those warnings were repeated
  `LEDGR_LAST_BAR_NO_FILL` messages.
- That warning is expected for this next-open benchmark fixture when target
  changes occur on the final available bar. It does not indicate a benchmark
  harness failure.

Parity interpretation:

- The canonical durable row and canonical ephemeral row pass Tier 1 parity.
- The public cost row, public cost/risk row, and legacy-cost row are compared
  against zero-cost/no-risk canonical evidence and therefore show attributed
  divergences before timing is interpreted.
- This is expected for the current-surface rows: they deliberately change cost
  and risk policy.

## Record Bundle Disposition

The current-surface ledgr-cost record bundle was run and is available under
the ignored local `dev/bench/results/peer_benchmark_record_20260615T211730Z_*`
paths. The checked-in `peer_benchmark.md` remains the accepted historical
all-peer record plus updated methodology and commands. It was not re-rendered
from the ledgr-cost-only record bundle because that would replace the all-peer
comparison table with a cost/risk measurement slice rather than preserving the
historical peer report.

## Guardrails Confirmed

- Internal measurement only; no public ranking language added.
- Parity rows are written before timing claims are interpreted.
- No runtime optimization, package execution change, or compiled-default flip
  is mixed into the benchmark redo.
