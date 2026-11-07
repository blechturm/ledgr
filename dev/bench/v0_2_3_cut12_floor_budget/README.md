# Cut 12 floor-v1 budget probe (R11)

R11 of the pulse plumbing amendment sets, per family, a per-pulse budget
for cost above floor v1 with every other stage a stub. Floor v1's stages are
stubs, so the FIFO family's cost above it is the kernel's own cost at its
call sites. `fifo_probe.R` times the lean-FIFO spike kernel and the pinned
`ledgr_lot_apply` on the same captured calls (from
`dev/lean_core/recorder/run.R --boundaries=lot`), alternating, after checking
the spike reproduces every pinned book. Both are byte-compiled, as the
installed package is.

`evidence/fifo_budget.csv` (2026-11-06, High performance plan, P-core
affinity, 7 rounds):

| workload | calls | fills | pinned us/pulse | spike us/pulse | budget (+15%) |
| --- | ---: | ---: | ---: | ---: | ---: |
| momentum 40 x 504 | 21 | 296 | 8.4 | 3.7 | 4.2 |
| fill-heavy 500 x 1,260 | 1,249 | 67,725 | 242.9 | 98.4 | 113.2 |

The spike is 0.41x pinned on fill-heavy, so LDG-3214's 0.5x bar is
reachable in R. Run uncompiled (JIT off), the same spike measured 254 us,
slower than pinned: a probe must compile both arms. The preparation family's
per-pulse budget is set in LDG-3215 once its tile design exists.

## FIFO family close (LDG-3214)

| Script | Output | Question |
| --- | --- | --- |
| `fifo_probe.R <lib> <caps> 7 lean` | `evidence/fifo_lean.csv` | R11: the lean kernel plus its input boundary per pulse against the budgets above |
| `fifo_groups.R <lib> <caps> <tests> 7` | `evidence/fifo_groups.csv` | Decision (5): no operation x bucket group (opening, fill, disposition x 1-9, 10-49, 50+) over every capture slower than pinned in total; descriptive |
| `fifo_profile.R <lib> <caps> 10` | `evidence/fifo_profile.csv` | per-function sample shares of the lean kernel on the fill-heavy calls |

The per-bucket fill-heavy gate runs through the shared harness,
`dev/bench/timing/protocols/cut12-fifo-1/`. `fifo_probe.R` in `spike` mode
reproduces the budget run above; its timing column is now named
`candidate_us_per_pulse`.
