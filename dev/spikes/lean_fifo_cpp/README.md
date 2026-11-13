# Spike lean_fifo_cpp: a compiled lean FIFO kernel

**Charter (maintainer, 2026-11-14).** After workstream 34's tuning ran out of
R-level candidates on the fill path, the maintainer asked to "spike it and
see if it works in principle", with a named decision for compiled code
limited to this spike. Nothing in `R/`, `src/` or `tests/` changes.

- **Question.** Can a compiled port of `lean_lot_general()`
  (`dev/lean_core/fifo.R`) reproduce the R kernel bit for bit, and how much of
  the lean fold's FIFO cost (about 114 us per pulse on `slice2_10x7200`,
  Cut 16 final cost map) does it remove?
- **Prerequisite.** The R kernel's cost is interpreter overhead, not
  arithmetic (`probe.R`): on slice2 it runs 7,191 times, every call a fill
  block of about 5 rows (at most 10), none served by the simple path, at
  145 us per call (probe clock, wrapper included). A block is a few dozen
  floating-point operations per row.
- **Kill.** Red if any compiled result differs from the R kernel's, or if
  the slice2 fold saves less than half of the FIFO cell.

## What ran

`kernel.cpp` (cpp11, about 270 lines) ports the general kernel's fill path:
the consumption loop, append, compaction, growth and the compensated realized
total, operation for operation, row by row. It declines (returns `NULL`, and
the R kernel runs) for anything else: openings, dispositions, a position off
the axis or repeated, any non-finite value, an opening through an opposing
lot, a capacity overflow. Refusals therefore stay the R kernel's. `kernel.R`
installs it at one seam, `lean_lot_apply()`; debug runs keep the R kernel.

- `run.R --mode=equivalence` sends every captured call to both kernels:
  the lean R kernel's 7,191 calls on slice2 and 156,610 calls of the pinned lot
  kernel recorded during the package test suite (LDG-3213's captures).
  `results/equivalence.csv`: **162,544 identical, 1,277 declined, 0
  different, 0 refusals accepted**; all 48 R refusals in the captures were
  declined.
- `run.R --mode=runs`: the lean loop with each kernel, alternating fresh
  processes, 7 rounds, P-cores, High performance (`results/runs_*.csv`;
  timings are host observations). Result tables identical on every shape;
  the compiled kernel faster in every round.

| shape | lean fold, R kernel | compiled kernel | fold saving | run saving |
| --- | ---: | ---: | ---: | ---: |
| slice2 10 x 7,200 | 777 us/pulse | 679 us/pulse | 12.9% | 11.7% |
| 10 x 7,200 | 380 | 355 | 7.3% | 3.7% |
| 500 x 1,260 | 2,116 | 1,993 | 6.3% | 2.9% |

- `check.R` reruns the equivalence into scratch and diffs it against the
  recorded CSV, guards package scope against the spike's base commit, and
  guts one path: the kernel without its Kahan compensation step must produce
  differences (`results/equivalence_gutted.csv`).

## Verdict

**Green**, by the kill clause: no compiled result differs from the R kernel's
in 163,801 calls, and on slice2 the fold saves about 98 us per pulse, most of
the 114 us FIFO cell.

## What the package learned

- The fill path's cost really is interpreter overhead: the same operations
  compiled take a small fraction of the time, with identical bits.
- Bit identity needs no special care beyond the operation order and the
  absence of FMA contraction: Rtools' default target (`-msse2`) has no FMA,
  and R's `sum()` long-double accumulation is reproduced where it decides a
  branch.
- A compiled kernel can keep every refusal in R by declining, so its
  contract surface is the success path only.
- The test-suite captures barely exercise the compensated realized total:
  with the Kahan step gutted they differ on 2 of the first 140,000 calls
  (1,105 in the last file), while slice2 differs on 7,186 of 7,191. A
  long-running workload with many realized steps is the witness that
  matters for this arithmetic; small fixtures are not.
- `check.R`: CHECK PASSED (rerun equals the recorded CSV, package scope
  untouched since 7378f184, gutted kernel exits 1 with 8,293 differing calls).

## Open (not decided by this spike)

1. **Portability of bit identity.** Verified with Rtools' g++ on Windows x86_64
   only. Compilers that contract `a * b + c` into FMA by default (clang on
   arm64, e.g. Apple Silicon) can change bits; a product kernel needs
   `-ffp-contract=off` or equivalent and a cross-platform equivalence run.
2. **A second compiled FIFO.** The package already ships `src/spot_fifo.cpp`
   (opt-in `compiled_accounting_model = "spot_fifo"` for memory-backed
   sweeps; its own error text says it "must not be extended", and new
   accounting models need their own RFC). One compiled lot kernel or two is a
   design question for WS14, not for this spike.
3. **The planner (P3, about 149 us per pulse on slice2)** is the larger fill
   cost and is not ported; it calls the pin's cost resolver, so a compiled P3
   meets Cut 16 decision 2 (reuse the pin's cost functions).
4. Per the macro plan, compiled execution is a WS14 decision through a
   focused Type 2 review, after slices 3-5 and the switch; this spike is its
   evidence, not its decision.
