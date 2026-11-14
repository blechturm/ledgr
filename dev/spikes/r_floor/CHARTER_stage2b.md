# R-floor stage 2b: the full guarantee-preserving reference

**Status.** Charter, approved by the maintainer on 2026-11-14 ("proceed").
Spike protocol (`inst/design/spike_protocol.md`) applies; this charter binds
nothing outside `dev/spikes/r_floor/`.

## Question

On matched workloads, what is the **implementation overhead ratio**

    lean loop time / full reference loop time

where the full reference is a plain-R implementation of every guarantee the
lean loop provides on that workload, written as a research instrument, and
both sides produce the same economic, contract and observable results?

The answer is reported as the observed cost of a minimal, guarantee-
preserving R implementation, not as the intrinsic cost of ledgr's semantics
(one implementation shows one achievable cost, not a lower bound).

Reading of the result (the maintainer's, 2026-11-14): a ratio of 3-5 or more
says the R implementation has much room; a ratio near 1-1.5 says the
remaining cost needs architectural or language-boundary changes.

## Prerequisite (answered)

Stage 2 and stage 3 (README.md) priced, on the crossover, target validation,
a rich context, fixed-basket availability, the compact decision trace and the
strategy-context boundary on a changing axis: 26 us per pulse in the loop at
10 x 7,200, against a lean loop of 281 us (cost map, Cut 16 final), about
10.8 times. Stage 2b adds the guarantees stage 2 did not price.

## Workloads and the matched-requirement rule

Two workload descriptors from `dev/bench/v0_2_3_lean_tuning_profile/
descriptors.R`, unchanged: `10x7200` (crossover) and `slice2_10x7200` (cost
chain, binding `max_weight`, `ledgr_target_rebalance()` every third pulse,
declared pulse counter). The reference calls the same strategy function and
the same package helper (`ledgr_target_rebalance()`, Cut 15 decision 1); it
receives the same bars, schedule and opening state and must produce the same
outputs the lean loop produces (fills, ledger events, equity, the compact
decision and sizing records, strategy state). A reference that skips an
output the lean loop must produce has not measured the same thing.

## Guarantees added (each priced standalone and accumulated)

1. cost chain resolution (`spread_bps`, `fixed_fee`, `notional_bps_fee`) and
   affordability with its reconciliation;
2. `max_weight` risk with its post-risk checks;
3. sizing evidence: validation of what the helper returns at the strategy
   boundary, and the sizing records;
4. lot accounting through `dev/lean_core/fifo.R` (the one FIFO kernel; not
   reimplemented) and position facts;
5. declared strategy state with its checks;
6. RNG state handling as the lean loop does it.

Each guarantee is measured three ways: the stage-2 floor plus that guarantee
alone (standalone), the reference so far plus that guarantee (accumulated),
and the full reference with all guarantees on. The full reference is the
denominator of the ratio. Clocks: loop only, and loop plus the after-run
trace rebuild and write, reported separately; matched against the lean
loop's own loop and fold clocks (`cut16-loop-1` endpoints).

## Parity (all three required for the final comparison)

| level | requirement |
| --- | --- |
| economic | fills, cash, equity and positions bit-identical to the lean loop |
| contract | the same acceptance, refusal and incomplete outcomes on the refusal fixtures below |
| observable | the decision and sizing diagnostics and the final strategy state identical to `ledgr_results()` |

Refusal fixtures (at most ten, written only after the reference runs, per
protocol section 3): a strategy returning a non-finite target; a cost
resolver that refuses; an affordability reconciliation stop; a short
exposure refusal; malformed sizing evidence. Exact floating-point identity is
required wherever the contract requires it.

## Kill and stop conditions

- **Kill:** a guarantee whose parity cannot be reached is reported as not
  priced, with what blocked it; the overhead ratio is then stated only for
  the guarantees that reached parity.
- **Stop (maintainer, 2026-11-14):** if parity for a guarantee requires
  reproducing a substantial amount of production logic, more than 150 lines
  of copied or paraphrased package code for that guarantee, it stops and is
  reported, rather than becoming a third implementation. Calling a package
  function the lean loop also calls (validators, the risk plan, the cost
  resolver) counts as reuse, not as a reference implementation of that
  guarantee, and is reported as such.
- Protocol budgets: harness at most 1,500 lines of R in total across stages
  2-3-2b; a correction diff over 500 lines is a stop-and-talk.

## Deliverables (protocol section 6)

A runner writing evidence CSVs (per guarantee: standalone, accumulated, full;
per workload; the three parity levels), a checker that reruns into scratch
and diffs, guards package scope and shows one gutted guarantee failing
parity, and a one-page closeout with the implementation overhead ratio per
workload and clock. Timings run under the host policy (High performance,
P-core affinity) with alternating arms.

## Amendment (maintainer, 2026-11-14, after the ephemeral-lane spike)

- **Three-way attribution.** The closeout separates, per workload: the cost
  of each guarantee implemented minimally (the reference's standalone and
  accumulated prices); the cost of the existing package implementation of
  that guarantee (the lean loop's matching cell); and the cost of hand-offs
  between stages (temporary objects, conversions, dispatch), measured with
  clocks at each lean stage boundary in the matched runs (Rprof cannot
  resolve it on this host).
- **Hypothesis, not target:** a complete guarantee-preserving R loop on the
  crossover may run at about 100-150 us per pulse. The closeout states
  whether the measurement supports it.
- **Two performance targets stay separate.** This spike measures single-
  candidate latency. Large-sweep throughput (shared preparation, worker
  reuse, memory pressure) is out of scope and needs its own measurement.
- **Baselines.** The ephemeral-lane measurement
  (`dev/spikes/ephemeral_lane`, its runner, 7 alternating rounds, both
  workloads) is kept as a baseline to rerun against; so is the four-arm
  compiled-kernel record (`dev/spikes/lean_plan_cpp/results`).

## Not in scope

Changing `dev/lean_core/` or `R/`; any performance claim outside the
repository; workloads beyond the two descriptors; schedules, sessions,
restrictions, corporate actions (slices 3-5).
