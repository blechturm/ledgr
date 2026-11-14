# Spike lean_plan_cpp: a compiled lean planner (and both kernels together)

**Charter (maintainer, 2026-11-14).** The structural change discussed after
workstream 34 was a compiled kernel for the fill path, P3 and P4 together;
the maintainer asked to spike it ("spike both") with a named decision for
compiled code limited to the spikes. `dev/spikes/lean_fifo_cpp` covers P4;
this spike covers P3 and measures both together. Nothing in `R/`, `src/` or
`tests/` changes.

- **Question.** Can a compiled port of `lean_plan_pulse()`
  (`dev/lean_core/plan.R`) reproduce the R planner's plan bit for bit while
  the pin's cost resolver stays the pin's (Cut 16 decision 2), and what do
  the two compiled kernels together remove from the lean fold?
- **Prerequisite** (`probe.R`). The planner runs once per pulse with fills:
  7,192 calls on slice2 (median 5 actionable rows, 105 us per call), 4,911
  on 10 x 7,200 (median 1 row, 75 us), 1,250 on 500 x 1,260 (median 54
  rows, 110 us). Every argument is a plain vector. The R cost is overhead
  around a handful of floating-point operations per row, plus one call of
  the cost resolver.
- **Kill.** Red if any compiled plan differs from the R planner's, or if
  the compiled planner accepts a call the R planner refuses.

## What ran

`kernel.cpp` (about 300 lines) ports the planner's common path: deltas,
sides, the execution view, the publication deltas, the affordability scan
(generators first, then the stable-ID rank), the reason segments and the
fill and rejection groups. The pin's `ledgr_plan_resolve()` is called back
into R once per pulse with the same arguments. It declines (the R planner
runs) for a missing execution timestamp (the final pulse), a non-finite
target delta, an invalid epoch, a short-exposure refusal, an undefined cash
effect, or any argument with attributes. `kernel.R` installs it at
`lean_plan_pulse()`; debug keeps the R planner.

- `run.R --mode=equivalence` (`results/plan_equivalence.csv`): every call of
  three lean runs: slice2 7,191 identical of 7,192, 10 x 7,200 4,910 of
  4,911, 500 x 1,260 1,249 of 1,250; the one declined call each is the final
  pulse; 0 different.
- Rejections are rare in these workloads (only on that final pulse), so
  `run.R --mode=fuzz` (`results/plan_fuzz.csv`, seeded) perturbs real
  captured calls: cash squeezed, opening prices broken, execution-view
  restrictions with dictionary reasons, membership flipped, and all four.
  13,745 perturbed calls, 0 different, 0 declined; over 7,000 carry
  rejection rows (early, blocked, insufficient cash, informational). The R
  planner refused none of them, so the decline-on-refusal path is not
  exercised by this fuzz.
- `run.R --mode=runs` (`results/runs_*.csv`): four arms, alternating fresh
  processes, 7 rounds, P-cores, High performance. Result tables identical
  across all four arms on every shape.

| shape | R | compiled planner | compiled FIFO | both |
| --- | ---: | ---: | ---: | ---: |
| slice2 10 x 7,200 | 767 us/pulse | 720 (-6.2%) | 684 (-11.1%) | 609 (-20.5%) |
| 10 x 7,200 | 386 | 347 (-10.3%) | 357 (-7.8%) | 323 (-16.6%) |
| 500 x 1,260 | 2,081 | 1,955 (-5.0%) | 1,937 (-6.8%) | 1,845 (-10.8%) |

Every arm was faster than R in every round except the planner alone on
500 x 1,260 (6 of 7).

- `check.R`: reruns equivalence and fuzz and diffs the CSVs, guards package
  scope over the spike's own commits, and guts the affordability tie-break
  (candidates of one generator class in arbitrary order): the fuzz then
  differs on 333 calls (`results/plan_fuzz_gutted.csv`).

## Verdict

**Green**, by the kill clause: no compiled plan differs in 27,098 calls
(13,353 captured, 13,745 perturbed), and no refusal was accepted.

## What the package learned

- The planner's saving is smaller than its cell (slice2 P3 about 149 us per
  pulse; the compiled planner saves about 47): the cost resolver stays an R
  call (about a quarter of P3 in the stage drill), and the P3 stage
  function around `lean_plan_pulse()` and the wrapper's
  `lean_plan_id_rank()` call stay R.
- The two kernels compose: together they remove about 160 us per pulse on
  slice2, 21 percent of the fold. What remains on slice2 (about 610 us per
  pulse) is the strategy and helper (the helper now cheaper, Cut 17), P2's
  pin validators and risk plan, the context build, P5, the records and the
  terminal store write.
- Rejection paths are effectively untested by the benchmark workloads;
  perturbing captured calls is a cheap way to reach them.

## Open (not decided by this spike)

1. Bit identity was shown with Rtools' g++ on Windows x86_64 only (see the
   FIFO spike's closeout on FMA contraction).
2. The cost resolver is a user-composable R closure chain; compiling it
   would need compiled cost models and is a separate question (Cut 16
   decision 2 keeps the pin's).
3. The decline-on-refusal path has no witness beyond the final-pulse
   decline; a product kernel needs refusal cases.
4. Compiled execution is a WS14 decision through a focused Type 2 review
   after slices 3-5 and the switch; these spikes are its evidence. With the
   existing `src/spot_fifo.cpp`, the package would hold two compiled lot
   kernels unless one replaces the other.
