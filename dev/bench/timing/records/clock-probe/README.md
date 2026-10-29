# Wall versus CPU clock probe (2026-10-29)

Evidence for the maintainer's redesign of the timing harness's host policy
(LDG-3155 post-review change, to be audited at the workstream 11 close
review). Not a gate record and not timing evidence for any cut.

**What ran.** `driver.R` installed ledgr at 9b8ee18f once into a scratch
library, then ran two ws2-timing-1 cells, `dense_run_seeded` and
`timing_sweep_unseeded`, as an A/A comparison: arms A and B use the same
library, 8 alternating pairs (A first in odd pairs), one fresh R process per
measurement (`child.R`). Each process timed the protocol's timed section
with wall time (`Sys.time()`) and process CPU time (`proc.time()` user plus
system). The host was a normal desktop: High performance plan, affinity
0xFFFF, with Positron, Chrome and Codex open. Raw seconds are in
`results.csv` (32 rows: pair, cell, arm, wall, cpu). The scratch library,
sources and DuckDB work files are not kept.

**Result.**

| cell | clock | median A | median B | ratio of medians | per-pair sd |
| --- | --- | --- | --- | --- | --- |
| dense_run_seeded | wall | 4.776 | 4.796 | 1.0042 | 0.0037 |
| dense_run_seeded | process CPU | 4.855 | 4.905 | 1.0103 | 0.0286 |
| timing_sweep_unseeded | wall | 0.616 | 0.623 | 1.0118 | 0.0374 |
| timing_sweep_unseeded | process CPU | 0.620 | 0.610 | 0.9839 | 0.0425 |

**Conclusions drawn by the maintainer.**

- Wall time with alternating fresh-process pairs already copes with a
  normal desktop; background activity is recorded, not gated.
- Process CPU time is noisier (Windows tick resolution, DuckDB threads), so
  the harness keeps wall time.
- The noise source that matters is short cells: under one second a cell
  swings about 5% per pair, so timed sections are lengthened to about 3 s
  or more.
