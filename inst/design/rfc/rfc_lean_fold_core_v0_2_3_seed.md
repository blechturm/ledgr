# RFC Seed: A Lean Fold Core For v0.2.3

- Status: Seed v1; Type 2 response by a different author is next
- Author: Claude
- Date: 2026-11-03
- Target window: v0.2.3 (maintainer, 2026-11-03: "if it's worth doing it's
  worth overdoing ... lets do it this version")
- Baseline: `release/v0.2.3` at `1e15c1cd`
- Inputs: the R-floor spike (`dev/spikes/r_floor/`, stages 1 and 2), the
  per-pulse premium record in macro plan WS14a, the accepted per-pulse
  durable records synthesis (WS15), the typed-fold-carrier synthesis, and
  the current WS14a and WS14 text

No public semantics change in this RFC. Every option below must produce
results bit-identical to the current core; ledgr is pre-CRAN, so stored
formats may change only where an accepted RFC already changes them.

## 1. Question And Boundary

How should v0.2.3 reach a lean execution core: by replacing the current fold
one stage at a time, or by growing a lean core alongside it against the
current core as the oracle and switching in one cut?

"Core" here means the per-pulse fold (E and P1-P5), its run preparation into
prepared planes, and its publication into the run store. Snapshot creation
and verification, feature computation, run registration, the strategy API,
result readers and sweep or walk-forward orchestration stay as they are,
except where the WS7/WS8/WS15 cut already changes them. Compiled stages stay
out of scope; WS14 keeps them as its last resort.

## 2. Why The Cycle Is Due

The R-floor spike measured what ledgr's semantics cost in plain R. A loop of
about 30 lines, with prepared matrices and preallocated buffers, reproduces
ledgr's fills, equity and cash bit for bit for the published SMA5/10
transition rule. Stage 2 added ledgr's guarantees back one at a time, each
still bit-identical, including ledgr's full decision trace.

Microseconds per pulse, cumulative (spike README, `evidence/timings*.csv`):

| | 10 x 7,200 | 20 x 23,400 | 500 x 1,260 |
| --- | ---: | ---: | ---: |
| floor: economics and strategy call | 15 | 18 | 48 |
| + target validation | 17 | 18 | 48 |
| + rich strategy context | 19 | 21 | 64 |
| + fixed-basket availability | 26 | 29 | 103 |
| + decision trace as WS15 stores it | 26 | 29 | 103 |
| ledgr at `0d6c0b11` | 2,790 | 3,135 | 8,320 |
| PMwR (2026-10-31 benchmark, for scale) | 19 | 24 | 214 |

A small 12 x 90 run takes 625 ms in ledgr against 84 ms for the floor with a
batched DuckDB write. 283 ms of ledgr's figure is the fold loop (90 pulses at
about 3 ms); setup and finalisation outside the loop take 138 ms, result
reads 80 ms, snapshot metadata and connection 53 ms, close 28 ms.

The current core is about 80 to 110 times its priced floor (the row with
every priced guarantee) and about 170 to 190 times the bare floor. The gap is not R and
not the guarantees priced so far. WS14a, as written, reviews the core and
subtracts what is not needed; subtraction from today's stage structure will
not reach this floor, because the cost sits in how each stage is built:
validation of every carrier in every stage, per-pulse provider views that
recompute constants for fixed baskets, per-pulse context helper refresh,
per-row trace staging, timestamp parsing (WS14a "Measured per-pulse premium").

## 3. Evidence And Its Limits

- Stage 1 and 2 parity: fills, equity and cash identical on 10 x 7,200,
  20 x 23,400 and 500 x 1,260; ledgr's full diagnostics identical when built
  in the loop and when rebuilt after the run from fills plus the WS15
  residual. `R_FLOOR_CHECK_OK` reran both stages in a clean worktree.
- Parity found four ledgr rules the spike first got wrong: a decision row's
  `quantity` is the holding; a final-pulse request that cannot execute
  writes an `execution/no_fill/final_pulse_no_execution` row; expected cash
  is booked fill by fill with sells before buys; `cumsum()` accumulates in
  long double and breaks exact rebuilds. An oracle found them in hours.
- Size: the fold, pulse context, availability, run and output-handler files
  hold about 16,900 of the package's 66,700 R lines.
- Limits: one rule on a fixed basket with clean daily bars. Not priced:
  declared sessions with gaps, restrictions and terminals; schedules;
  corporate actions; sizing helpers; costs; risk; RNG; carry windows;
  sweeps and walk-forward. Timings are spike clocks on one host.

## 4. Options

**A. Stage-by-stage replacement inside the current fold.** Each stage is
rewritten to its lean form behind today's carriers and proven identical on
recorded carriers and reference runs. No second engine ever exists.

**B. A lean core grown alongside, switched in one cut.** The floor is grown
into a complete core, guarantee by guarantee, each step bit-identical to the
current core on the proof families. When it matches everywhere, one cut
replaces the current fold and deletes it.

| | A | B |
| --- | --- | --- |
| design freedom | bounded by today's carriers and stage cuts | free; carriers can follow the lean shape |
| per-step risk | small | none until the switch |
| switch risk | none | one large cut, covered by exhaustive parity |
| second engine | never | in development, outside `R/`, until the switch |
| price of each guarantee | measured per stage, against old neighbours | measured per layer, against the floor |
| likely result | faster, still shaped by today's structure | closest to the floor |

Seed recommendation: **B**, with the lean core developed under `dev/` so the
package keeps one engine until the switch cut.

## 5. Proposed Design For B

**Where it grows.** Under `dev/lean_core/`, calling ledgr's exported and
internal preparation (snapshot reads, feature computation, run registration)
through the installed package, like the spike. Nothing in `R/` executes it
before the switch, and no user can reach it.

**How it grows.** One guarantee family at a time, in the spike's form: a
layer is accepted only when every proof family it touches stays
bit-identical and its price per pulse is recorded. Stage 3 of the spike
(the unpriced families in Section 3) is the first work.

**The switch gate.** One cut moves the lean core into `R/`, routes
`ledgr_run()`, `ledgr_sweep()` and walk-forward through it, and deletes the
current fold. It requires, on the current core as oracle:

- bit-identical public results (fills, ledger, equity, the full logical
  diagnostics, summaries, `ledgr_run_explain()`) on WS15's seven proof
  families, the repaired A0 fixtures, the peer-suite workloads and sweeps
  and walk-forward sessions over them;
- the private v0.2.2 real-data reference unchanged where no accepted change
  explains a difference;
- every registered test passing unchanged, with the test suite frozen for
  the cut (the WS14a order: product first, tests frozen);
- the per-layer prices as per-stage budgets, measured with per-function
  sample counts.

**Tests.** The WS14a test cut (fold-core tests rebuilt from the contracts,
mutant proof before retirement) runs after the switch and targets the lean
core. The old suite is the safety net for the switch; the new suite is the
lean core's own.

**Order.** The WS7/WS8/WS15 cut lands first: it fixes the stored formats and
readers the lean core publishes into. The lean core grows in parallel from
stage 3 on. WS14a's review becomes the review of the lean core before the
switch; its product subtraction cut becomes the switch cut. Execution-
sensitive WS10 cuts and WS9b's batching decisions move after the switch, so
they are built and measured on the lean core.

**Kill condition.** If a guarantee family cannot reach parity after two
correction rounds, or its lean price exceeds the current core's cost for
it, that family falls back to option A for its stage, and the RFC returns to
the maintainer before the switch.

## 6. Authority Change

AGENTS.md says "Do not add a second execution engine." Option B keeps that
true for the package: the lean core runs only under `dev/` until the switch
cut, which deletes the current fold. Proposed AGENTS.md addition while the
work is open:

> A lean fold core may be developed under `dev/lean_core/` as a parity
> harness against the current core (lean-fold-core synthesis). It is never
> called from `R/`, exported or made a default; the switch cut that moves it
> into `R/` deletes the current fold in the same cut.

The note is removed by the switch cut.

## 7. WS14 Objectives

Proposed replacements for the provisional stretch objectives, still design
objectives and not claims: a fixed-basket no-fill pulse at or below about
50 us on narrow books and 150 us at 500 instruments; per-run work outside
the loop at or below about 100 ms; an ephemeral lane within about 1.5 times
PMwR on narrow books and at least at parity on wide ones; a durable lane
within about 2 times its ephemeral lane, as today.

## 8. Risks

- **Scope and CRAN timing.** v0.2.3 is the planned CRAN release. B adds a
  large cut and moves WS10 and WS9b work later. The release slips; the
  response should say by how much it judges likely.
- **Hidden semantics.** The unpriced families carry most of ledgr's rules.
  The oracle finds disagreements; it cannot find a rule no proof family
  exercises. Proof-family coverage is the real risk.
- **A0 is stale** (WS14a finding of 2026-11-02) and must be repaired before
  it can serve the switch gate.
- **Two cores in mind.** Agents may copy the current core's shapes into the
  lean one. The optimization manual and the spike's layer prices are the
  guard.

## 9. Not In Scope

Compiled stages; new public semantics or API; reviving the dense path;
changing WS15's accepted decisions; performance claims of any kind.

## 10. Questions For The Response

- **Q1.** Is the framing right: does the evidence show that stage structure,
  not missing subtraction, is why WS14a would not reach the floor?
- **Q2.** A or B, or a better third option?
- **Q3.** Is `dev/` the right place for the lean core, or should it live in
  `R/` under the proposed exception?
- **Q4.** Is the switch gate sufficient, and which proof family is missing?
- **Q5.** Does the order (WS7/WS8/WS15 first, lean core in parallel, switch
  as WS14a's product cut, tests after) hold?
- **Q6.** Are the proposed WS14 objectives right, and how much does B delay
  the release?
