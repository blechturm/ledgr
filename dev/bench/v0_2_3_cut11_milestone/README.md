# Cut 11 rule-16 milestone, 2026-11-05

This is the descriptive performance milestone that LDG-3209 requires after
the WS23-WS25 cut. Under macro rule 16 these numbers are evidence, not a
gate. The binding memory gate is H1. Its record is in ledgr-research
`experiments/v0_2_2-reference/README.md`, section "Cut 11 H1 paired history
resource protocol" (commit `4b49566`).

## Builds and host

| Name | Commit | Role |
| --- | --- | --- |
| v0.2.2 | `7539be45` (tag `v0.2.2`) | release reference |
| LDG-3200 | `0d6c0b11` | cut-entry base |
| candidate | `cad309f4` | WS25 corrected head |

The host is an i9-12900K running Windows 11 and R 4.6.1, on the High
performance power plan with process affinity `0xFFFF` (P-cores). No other R
process was running. The three timing steps ran one after another, and the
profiles ran after them.

## Paired timing (shared harness, registered protocols)

`milestone_timing.sh` runs `dev/bench/timing/runner.R` three times with
unchanged registered protocols. Each cell uses eight alternating pairs in
fresh installed processes. The records are under `dev/bench/timing/records/`,
and `dev/bench/timing/check.R` reproduces every ratio below.

**Cut 11 accounting cells.** This is `cut11-accounting-1`, preregistered at
LDG-3200, with record `cut11-milestone-ldg3200/attempt-1`. It compares
`0d6c0b11` with the candidate on a 20 x 80 fixture.

| cell | base s | candidate s | ratio |
| --- | ---: | ---: | ---: |
| fill-heavy run | 0.857 | 1.049 | 1.224 |
| quiet run | 0.689 | 0.871 | 1.265 |
| two-candidate sweep | 0.844 | 0.948 | 1.123 |

All three ratios are within the protocol's descriptive bound of 10. The
checker reports "work differs" for both run cells. In each pair the status,
event and fill counts and final equity are identical. Only the digest of the
public ledger table differs, because the base returns the schema-124
`meta_json` ledger and the candidate returns the decided schema-125 typed
ledger. The private aggregate gate accepts that difference field by field
through `normalize_ledger()`. On this tiny fixture the clocks mostly measure
fixed per-run cost.

**Shape cells.** This is `ws5-timing-1`, restricted to its six no-fill,
sparse-rebalance and wide all-fill cells (`--cells`). The registered adapter
expresses the same strategy on the old and new state APIs.

| cell | v0.2.2 s | `0d6c0b11` s | candidate s | candidate / v0.2.2 | candidate / `0d6c0b11` |
| --- | ---: | ---: | ---: | ---: | ---: |
| fixed no-fill | 4.51 | 10.80 | 11.44 / 11.30 | 2.539 | 1.046 |
| declared no-fill | 7.43 | 5.28 | 5.93 / 5.95 | 0.798 | 1.127 |
| fixed sparse | 4.34 | 9.80 | 10.91 / 10.87 | 2.512 | 1.109 |
| declared sparse | 5.84 | 4.87 | 5.66 / 5.66 | 0.969 | 1.163 |
| fixed wide | 15.45 | 9.02 | 8.19 / 8.18 | 0.530 | 0.907 |
| declared wide | 22.85 | 8.91 | 8.68 / 8.64 | 0.380 | 0.969 |

The candidate was measured in both comparisons, so it has two medians
(versus v0.2.2 / versus `0d6c0b11`). The records are
`ws5-timing-1/cut11-milestone-v022/attempt-1` and
`ws5-timing-1/cut11-milestone-ldg3200/attempt-1`.

Wide all-fill work is 1.9-2.6 times faster than v0.2.2 and 3-9 percent faster
than the cut-entry base. Fixed-basket no-fill and sparse remain about 2.5
times slower than v0.2.2. That premium predates this cut: it is the Cut 6
milestone's measured cost of routing fixed baskets through the canonical
substrate, which is routed to WS14. Against the cut-entry base, no-fill and
sparse cells are 5-16 percent slower. Five cell comparisons exceed the
protocol's 1.10 disposition trigger: fixed no-fill and fixed sparse against
v0.2.2, and declared no-fill, fixed sparse and declared sparse against
`0d6c0b11`. The maintainer disposed of them on 2026-11-05: timing
regressions are not fixed in this version, which moves to the lean-core
reimplementation.

## Fill-heavy stage profile (the four WS8 hotspots)

`profile_step.sh` runs the registered `v0_2_3_fill_heavy_profile` probe and
classifier unchanged on the published 500 x 1,260 SMA 5/10 workload: three
timed runs and one `Rprof` run per build, in a single process each. Every
build produces 67,725 fills and final equity 10728506.707646. The evidence
is in `evidence/fill_*`.

| seconds (median of 3 unprofiled) | v0.2.2 | `0d6c0b11` | candidate |
| --- | ---: | ---: | ---: |
| `ledgr_run()` | 17.79 | 9.11 | 8.16 |
| `ledgr_results(bt, "fills")` | 3.43 | 1.59 | 0.65 |
| total with reads | 21.25 | 10.63 | 8.85 |

Profile regions, in seconds of the profiled run:

| region | v0.2.2 | `0d6c0b11` | candidate |
| --- | ---: | ---: | ---: |
| P apply | 4.29 | 1.48 | 0.67 |
| P commit | 1.96 | 1.24 | 0.61 |
| P plan | 1.66 | 0.45 | 1.03 |
| P decide | 0.66 | 0.78 | 0.66 |
| E observe/settle | 0.02 | 0.71 | 0.63 |
| run outside stages | 3.36 | 1.69 | 1.68 |
| results read | 2.27 | 1.07 | 0.42 |

The four hotspots named at Cut 7:

1. Per-fill canonical JSON in `ledgr_fill_event_payload()` (0.76 s at
   `0d6c0b11`) is gone. Typed preparation in
   `ledgr_prepare_accounting_events()` costs 0.19 s.
2. Per-pulse `ledgr_store_append()` in P commit (0.46 s) is batched. P commit
   falls from 1.24 to 0.61 s. Part of the write moved into P plan (the
   diagnostic segment flush: `ledgr_store_append` 0.22 s and `rapi_execute`
   0.18 s there), which is why P plan rises from 0.45 to 1.03 s.
3. The fills reader's replay falls from 1.59 to 0.65 s per read.
4. `ledgr_carrier_problem()` validation still shows on every stage, at about
   0.06-0.08 s per stage.

Outside the stages, `ledgr_diagnostic_query()` costs 0.34 s on the
candidate. It is most likely the cold validation inside `ledgr_run()` that
the H1 attribution traces (LDG-3210). This profile does not separate the two.

## Quiet 10 x 7,200 run, stored rows and reads

`quiet_probe.R` runs a hold-only strategy (`ctx$hold()`, no fills) on
`ledgr_sim_bars(10, 7200)`, with the same body on every build: three timed
durable runs and one `Rprof` run in one store. The evidence is in
`evidence/quiet_*`. The per-function self-sample counts at 10 ms are in
`quiet_prof_self_*.csv`.

| measure | v0.2.2 | `0d6c0b11` | candidate |
| --- | ---: | ---: | ---: |
| `ledgr_run()` median s | 7.50 | 12.47 | 13.26 |
| logical diagnostic rows per run | 0 | 79,201 | 79,201 |
| `run_diagnostics` rows (4 runs) | 0 | 316,804 | 28,804 |
| `run_diagnostic_implicit` rows (4 runs) | - | - | 288,000 |
| `strategy_state` rows (4 runs) | 0 | 28,800 | 0 |
| store file bytes (snapshot plus 4 runs) | 17,575,936 | 30,158,848 | 40,382,464 |
| full diagnostics read s | 0.03 | 0.08 | 0.16 |

Top self-time functions at `0d6c0b11` are `ledgr_carrier_problem` (119
samples) and `ledgr_fold_diagnostic_rows` (52). On the candidate they are
`ledgr_carrier_problem` (78) and `ledgr_fold_diagnostic_segment` (70).

Stored diagnostic rows equal logical rows. The writer stores one typed
`run_diagnostic_implicit` row per clean decision, on every universe shape
(`R/availability-diagnostic-writer.R`, `R/diagnostic-codec.R`). Here that
is 72,000 implicit rows plus 7,201 residual `run_diagnostics` rows, giving
79,201 logical rows per run. The declared-universe reader record is the same:
its "7,201 physical rows" counts only `run_diagnostics` next to 3,600,000
implicit rows (`availability-build-summary.csv`, `implicit_rows`). The typed
form replaces per-row JSON; it does not reduce the row count. On this
hold-only run the store is 34 percent larger than at the cut-entry base, and
the resume cursor table is gone. The final close review records the size
increase as an observation. No accepted claim bounds the row count.

## Limits

Profiles are single processes and single `Rprof` runs, so their shares are
approximate. The shape and accounting clocks have eight alternating pairs in
fresh processes. The helper-sizing case and the full and filtered
explanation costs at real-data scale come from the private gate rerun and
the WS25 public reader records, not from this folder. Reads on the private
`w2_minvar` store are in ledgr-research `v0_2_2-reference/README.md`
("Rerun on the corrected reader head").
