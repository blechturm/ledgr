# R-floor stage 2b closeout, 2026-11-14

**Outcome: green.** The full reference reaches all three parity levels on
both workloads (charter, "Parity"), so the implementation overhead ratio is
stated for every guarantee: **2.6 on the crossover, 1.8 on slice2** (loop
clock).

## What ran

`reference.R` is one plain-R loop (263 lines) with a switch per guarantee.
It calls what the lean loop calls for the strategy, the sizing helper,
`ledgr_strategy_result()`, the FIFO kernel (`lean_lot_fill()`) and the seed
functions (reuse), and writes the cost steps, affordability scan, max_weight,
post-risk and short checks, sizing-evidence check and declared-state check
itself (each 8 to 25 lines, far under the 150-line stop rule). `run.R` times
the plain lean loop, the lean loop with stage clocks (`lean_clocks.R`) and 13
reference configurations, 7 alternating rounds in fresh processes, High
performance plan, P-cores. Harness 825 lines of R. Probe first:
`probe_findings.md`.

## Result (median us per pulse, 10 x 7,200; min to max within 6 percent)

| | crossover | slice2 |
| --- | ---: | ---: |
| lean loop | 286 | 611 |
| full reference | 108 | 345 |
| **ratio, loop** | **2.6** | **1.8** |
| ratio, loop plus after-run write | 2.7 | 1.9 |
| reference floor (context, strategy call, checks, records) | 53 | 121 |

Per guarantee: the minimal price (reference, accumulated) against the lean
loop's own cell for it (stage clocks, which add 18 and 38 us):

| guarantee | crossover ref / lean | slice2 ref / lean |
| --- | ---: | ---: |
| costs and affordability (lean: `lean_plan_pulse()`) | 12 / 47 | 12 / 102 |
| max_weight and checks (lean: risk plan) | 5 / 0 | 64 / 31 |
| sizing evidence (lean: its validator) | 1 / 2 | 14 / 18 |
| FIFO and position facts (same kernel both sides) | 33 / 40 | 132 / 126 |
| declared state (lean: state update) | 2 / 21 | 2 / 18 |
| seeds (once per run) | 1 / - | 0 / - |

Hand-offs in the lean loop (stage time not in any cell above): context build
34 and 37, and stage residuals P2 to P5 of 81 and 156 (records, carrier
text, cash scan, position facts, reconciliation, the stage calls). The
strategy call is 65 and 142, of which the sizing helper 109 on slice2.

## What was learned

- The lean loop's extra time against the reference is 178 us (crossover) and
  266 us (slice2). It sits in three places: the order planner (35 and 90 us
  more than the formulas it computes), the declared-state update (19 and
  16), and the context build, call wrapper and stage hand-offs (about 120 and
  170, reading slice2's risk at its standalone price, since its accumulated
  increment carries a changed trade path). The reference matches every
  compared record, but it does not keep every guarantee of the context
  service (see the correction below), so part of the gap may be the price
  of guarantees it omits.
- Shared costs dominate what is left. The FIFO kernel is 30 percent of the
  crossover reference and 38 percent of slice2's; the sizing helper is about
  110 us of slice2's pulse on both sides. They are the next floor.
- The reading (maintainer, 2026-11-14): 2.6 is near the "much room in R"
  band, 1.8 between the bands. Simplifying the lean orchestration can at
  best reach the reference (286 to about 110, 611 to about 345); beyond that
  the FIFO kernel and the helper decide.
- The amendment's hypothesis (about 100 to 150 us per crossover pulse for a
  complete guarantee-preserving R loop) is supported: 108.

## Parity

Economic (fills, equity, cash, positions, lot book) and observable
(decision, sizing and rejection rows, reconciliation record, raw-sizing
notice, final state) identical to the lean loop's records, and fills and
equity identical to `ledgr_results()` (`parity.csv`). Contract: six fixtures
(`fixtures.R`, `contract.csv`), same outcome on both: non-finite target,
short target and malformed evidence refused with the same class; a spread
that prices sells at or below zero, too little cash and stale evidence
accepted with identical records. The cost model has no refusal a run can
reach (a non-positive price is a rejection), and the affordability
reconciliation stop has no constructible input (relative tolerance 1e-8);
the checker's gutted path exercises the reference's stop branch.

## Correction (cut review 18, 2026-11-14)

The first paragraph's "every guarantee" is too strong. Cut review 18 (R1,
[inst/design/ledgr_v0_2_3_spec_packet/cut_review_18.md](https://github.com/blechturm/ledgr/blob/ea580bc6b1d345f7aae9e6836b4f12fe94e18afe/inst/design/ledgr_v0_2_3_spec_packet/cut_review_18.md)) showed with two
probes outside the registered fixtures: a context the strategy keeps from
pulse 1 returns a later pulse's position from `hold()`, because the
reference's `hold()` closes over a variable the loop reassigns; and sizing
evidence with a NaN requested quantity is refused by the pin and accepted by
the reference, which omits some typed sizing checks. The reference also uses
a plain list without the lean lookup service and compares refusal class
membership, not message or precedence. So the reference is an attribution
input for the two compared workloads, not a guarantee oracle, and its 108
and 345 us are descriptive figures, not an attainable floor.

## Limits

Clock cells under about 5 us are not resolved. Standalone prices on slice2
run different trade paths (risk off changes the fills), so its accumulated
column is the one to read. The after-run write compares unlike contents
(reference: compact tables; lean: the full publish). One host, one fixture
per family.

Reproduce: `Rscript dev/spikes/r_floor/stage2b/run.R --lib=<pin library>
--out=<dir>` (under `pcore.ps1`), then `Rscript
dev/spikes/r_floor/stage2b/check.R --lib=<pin library> --scratch=<dir>`.
Nothing in `R/` or `dev/lean_core/` was changed.
