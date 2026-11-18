# Stage 2-3 measuring step: findings

**Outcome: green.** The kill condition (CHARTER.md: ceiling under 10 percent
on every wide cell) is not met: the stage-3 ceiling is 49-59 percent of the
compute call on all four wide cells. Stage 3 justifies its RFC section.

**What ran.** Installed release build, R/ at `68b505b9`; busy machine (another
session's parallel R workload; CPU 7-14 percent around the runs), High
performance, P-cores, 7 repetitions, each sample at least 0.25 s. Absolute
seconds are therefore high and noisy; shares and ratios are the evidence.
Commands: `steps.R`, `direct.R`, `gate_count.R`, `ttr_inventory.R`
(`--lib=<build>`); `check.R` reruns and diffs them: CHECK PASS.

## Where the time goes now (results/steps.csv)

Feature path (compute call plus projection), unprofiled median seconds:
10 x 7,200 run 0.11, sweep 0.24; 500 x 1,260 run 0.55, sweep 1.36; 1,166 x
252 run 0.82, sweep 1.98. On the wide cells the per-instrument machinery a
direct path replaces (input treatment with expected and terminal planes,
admission, runs and terminal breaks, segment code, plane exceptions, ranges)
is 57-67 percent of the path (sum of those steps' seconds over the path's);
the TTR raw call is 0.12-0.57 s against bare TTR
0.08-0.53 s. On 10 x 7,200 the projection's pulse names (0.045 s) and the
compute call's own residual dominate. The engine version costs 22 ms per call.
Certification runs inside `lapply()`, so the profiler books it under
"compute other"; `direct.R` times it directly.

## Stage 3: the direct-path ceiling (results/direct.csv)

| Cell | compute call | kept (cert. + causality + records) | gate | direct | ceiling |
| --- | --- | --- | --- | --- | --- |
| 10 x 7,200 run | 0.074 | 0.036 | 0.010 | 0.009 | 27% |
| 10 x 7,200 sweep | 0.200 | 0.106 | 0.016 | 0.025 | 27% |
| 500 x 1,260 run | 0.580 | 0.031 | 0.100 | 0.160 | 50% |
| 500 x 1,260 sweep | 1.410 | 0.092 | 0.130 | 0.500 | 49% |
| 1,166 x 252 run | 0.830 | 0.030 | 0.073 | 0.240 | 59% |
| 1,166 x 252 sweep | 2.000 | 0.091 | 0.100 | 0.710 | 55% |

All 13,408 admitted cells are identical to the general path: values on the
whole axis, segment start, ready and end, and no carry or reason exception.
The ceiling assumes nothing else is needed; a real stage 3 also pays its debug
comparison, so it is an upper bound. The gate itself costs 0.07-0.13 s on the
wide cells, as written here (per-instrument range calls, full planes).

**Certification is about 14 ms per definition per call** (28 ms for two, 83
ms for six), independent of instruments: 37-41 percent of the 10 x 7,200
compute call. It rebuilds catalogue candidates for every definition. Not a
stage-3 cost; an input for stage 2's adapter description (candidate lookup by
key instead of construction).

## Gate coverage on public substrates (results/gate_count.csv)

Structural counts, not a ranking. The conservative gate admits every cell of
the crossover fixtures, 197 of 200 instruments of the simulated PIT panel
(one terminal, three gaps), and none on the hostile corpus substrates (carry,
terminals). Custom definitions are never admitted. The relaxed gate (one
contiguous available block) admits 2 more cells; their values and segments
match, but the general path also records reason runs for missing expected
sessions outside the block, so a relaxed gate must emit them (the seed's F7
requirement, now observed).

**Gut** (check.R): without the full-coverage clause the conservative gate
admits 14 cells that differ (input carry 6, reason runs 6, output carry with
reasons 2). The clause is load-bearing.

**Found by running.** A block shorter than `stable_after` must make no adapter
call: the first prototype called TTR there and TTR refused (window longer
than input). The general path guards it; a direct path must too.

## Stage 2: TTR naming (results/ttr_inventory*.csv)

Outside `R/indicator-ttr.R`, 57 code lines in 9 functions name TTR or call
an adapter helper: certification and its candidates (`ledgr_feature_certify`,
`ledgr_feature_catalogue_candidates`), the segment dispatch
(`ledgr_history_feature_segment`), the catalogue rows
(`ledgr_indicator_history_catalogue`, 26 lines), the `source` values
(`ledgr_indicator`, `ledgr_indicator_source`), the parameter registry
(`ledgr_param_constructor_registry`), provenance
(`ledgr_dependency_versions_json`) and the engine version's bind list (11
lines). These are the sites the seed's stage 2 names.

## Open

- The real-data (H1) gate count: needs the private aggregate route and the
  maintainer's go. The PIT simulator adds one case of each kind, not
  realistic churn, so it says nothing about real coverage.
- A clean-machine rerun of the timings, if the RFC review asks for one.
