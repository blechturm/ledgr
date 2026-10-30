# Memory method validation on the base (LDG-3163 scope d)

Base `953338df`, installed library `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`,
R 4.6.1, Windows. Children produced by
`Rscript dev/bench/v0_2_3_ws4a/memory.R --lib=<base lib> --calibrate=1`
(run 2; records written to scratch, then copied here); `validation.csv`
recomputed from the same `children.csv` by
`Rscript dev/bench/v0_2_3_ws4a/memory.R --lib=<base lib> --mode=summarize`.
Other agents' R processes ran on the host throughout (2 to 3, `children.csv`
`concurrent_r`).

## Verdict

**The gated metric is peak R heap** (maintainer decision, 2026-10-30, under
decision (5)): `sum(gc()[, "max used"] * c(56, 8))` in a fresh child after
`gc(reset = TRUE)` at the phase boundary, forward run and replay measured as
separate operations, budget at most 1.10 x the matched base median. It
**passes validation** in all four cells. It covers the R heap only (not
DuckDB's native memory, which WS4a does not change) and it is a high-water
mark, so garbage awaiting collection counts; it is named for what it is,
not as "peak live".

The first candidate, process peak private commit (lifetime `ps`
`peak_pagefile` minus a matched load-only child's), **failed validation** and
is kept only as a reported observation.

| criterion | peak R heap (gated) | peak commit (observation) |
| --- | --- | --- |
| Stability (pre-declared: range/median <= 0.05 over five repetitions) | PASS in all four cells: 0.0001, 0.0000, 0.0044, 0.0059 | FAIL in 3 of 4: 0.152, 0.072, 0.118 (0.039 passes); one unchanged repetition read 1.132 x its median |
| Isolation | PASS: load-only heap at most 62 MB against 258-426 MB operations | PASS |
| Sensitivity (frozen controlled excess, live at both points) | PASS: all 20 control repetitions breach, at 1.18-1.44 x base | breaches, but not additively (+16% to +61%) |
| Specificity (pointer alias adding no bytes) | PASS: 1.000-1.004 x base, never breaches | 0.91-1.00 x base, noise as large as the margin |
| Collection policy | Default R GC: `R_GC_MEM_GROW`, `R_MAX_VSIZE` and `R_GC_GROWFRAC` unset; one `gc(reset = TRUE)` at the phase boundary in every child, load-only included | same |

The control blocks were frozen at 0.20 x the commit observation of the base
run (`control_size.csv`) and are kept as frozen; they breach the gated
metric's budget in every repetition.

## Base values (medians of five; bytes in `validation.csv`)

| workload | fills | peak R heap (gated) | frozen control block | peak commit (observation) |
| --- | ---: | ---: | ---: | ---: |
| wide forward (5,000 x 252) | 75,332 | 399.1 MB | 51.7 MB | 258.3 MB |
| wide replay (`ledgr_results(bt, "fills")`) | 75,332 rows | 258.1 MB | 73.5 MB | 367.4 MB |
| deep forward | 134,557 | 426.1 MB | 57.4 MB | 287.1 MB |
| deep replay | 134,557 rows | 321.4 MB | 74.0 MB | 370.1 MB |

Deep variant: 250 instruments each buy 15 single-unit lots and then close
them in one 15-unit fill, giving 3,750 closing fills. Five sampled
instruments had 15 live lots before their first close.

## Why the commit candidate failed

`peak_pagefile` on Windows is the process's peak private commit: the R heap,
malloc'd native memory (DuckDB's in-process buffers included), thread stacks
and allocator-retained free storage. Its run-to-run range of 7 to 15% comes
from multi-threaded DuckDB allocation and GC timing, not from host load, and
exceeds the 10% budget margin. The subtraction also measures the operation's
peak above the setup high-water mark, not its growth from the boundary.

## Allocation per fill (gated separately, decision 5)

Rprofmem, cumulative explicit-size R allocation over one sequential sweep
call, 500 x 1260 wide (`rprofmem.csv`): dense 3,156,598,096 B / 67,725
fills = 46,609 B/fill; availability 7,337,938,376 B / 67,725 = 108,349
B/fill. These are close to the carrier probe's 46,619 and 108,286 at
145cc93b.
