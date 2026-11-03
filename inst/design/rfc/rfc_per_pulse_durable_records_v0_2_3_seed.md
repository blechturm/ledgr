# RFC Seed: Deterministic Replay Instead Of Per-Pulse Durable Records

- Status: Seed v1; Type 2 response is next
- Author: Claude
- Date: 2026-11-03
- Target window: v0.2.3, before the WS7/WS8 cut is written
- Baseline reviewed: `de35535e` (`release/v0.2.3`); measurements on an
  installed build of `ae289ce0` (Cut 9 head, same `R/` for these paths)
- Inputs: maintainer product discussion of 2026-11-03, the probes in
  Section 3, current contracts and current fold, resume and diagnostic code

ledgr is pre-CRAN with no external users. Nothing below needs a migration,
an old-format reader or a compatibility argument; a removed record is a
schema bump and a store rebuild.

## 1. Question And Boundary

ledgr writes two records on every pulse of every durable run: a resume
cursor and a decision trace. Both exist so that a later question ("continue
this run", "why did this decision happen") can be answered from the store.
ledgr is deterministic: the same snapshot, configuration and seed give the
same run. Should durable records keep only what cannot be recomputed
cheaply, and answer the rest by replaying the run?

The cycle owns pulse-level resume, the `strategy_state` cursor table, the
content and granularity of the decision trace in `run_diagnostics`, and an
on-demand replay path for explanations. It does not change fills, ledger
events, equity, accounting, snapshot identity, the no-lookahead pulse
contract, run-level idempotence or walk-forward session reruns.

## 2. Why The Cycle Is Due

The product changed. Pulse-level resume was built when ledgr was meant to
become a trading bot quickly. The long-term order is now: fold-core cleanup
and CRAN, then point-in-time fundamentals, and only then OMS, paper and live
trading. ledgr is a research backtester. Its runs take seconds to minutes and
the WS14 stretch objectives aim lower. Rerunning a run costs less than
resuming it and is easier to trust.

The cost is measured, not assumed (Section 3). A quiet pulse at the Cut 9
head costs about 1.8 ms on 10 instruments, against about 0.6 ms in v0.2.2.
The decision trace is the largest single owner of that difference. The
WS14 stretch objective is 100 to 200 us per ordinary no-fill pulse.

The WS7/WS8 cut must decide how durable writes are batched. Deciding first
which per-pulse records exist at all keeps that cut from optimising writes
this RFC would remove.

## 3. Evidence And Its Limit

All probes ran on 2026-11-03, Windows 11, R 4.6.1, collapse 2.1.8, P-core
affinity and the High performance plan, against installed builds. Scripts
are scratch and are not committed; the cut that implements this RFC
re-records whatever it relies on.

**Resume by execution** (3 instruments, 20 pulses; strategy calls counted):

| attempt | strategy calls | status |
| --- | ---: | --- |
| strategy error at call 15 | 15 | `FAILED` |
| rerun of the same `run_id` | 20 (restarts at pulse 1) | `DONE` |
| `ledgr.interrupt` soft stop at call 10 | 10 | `RUNNING` |
| rerun of the same `run_id` | 10 (continues at pulse 11) | `DONE` |
| rerun of a `DONE` run | 0 | `DONE` |

The durable fold is one transaction. An error or interrupt rolls back every
fold write, cursor rows included (contracts, "Early exit" and "Pulse-level
fill staging"), so a crashed run restarts from pulse 1. Pulse-level
continuation happens only after the deliberate soft stop or a failure after
the fold committed. A crash caused by a strategy bug cannot resume anyway:
fixing the strategy changes its identity, and a mismatched configuration
refuses with `ledgr_run_hash_mismatch` (verified by execution: rerunning a
`FAILED` run ID with the corrected strategy refuses). Nothing outside resume reads
`strategy_state` (`R/run-resume.R:31`, `R/strategy-state.R:432-440`).

**Per-pulse cost** (hold-only strategy, 10 instruments x 7,200 pulses,
durable `ledgr_run()`, v0.2.2 against `ae289ce0`, alternating processes, two
`Rprof` runs each, samples scaled to measured wall time):

| bucket | v0.2.2 us | head us |
| --- | ---: | ---: |
| carrier validation | 0 | 380 |
| decision-trace staging, rows, flush and writer | 0 | 347 |
| availability provider view | 1 | 312 |
| availability pulse plan | 0 | 135 |
| context helper refresh and `ctx` access | 0 | 119 |
| carrier packets and history bars | 0 | 93 |
| strategy call and target validation | 129 | 71 |
| rest of the fold loop | 391 | 301 |
| outside the fold | 100 | 41 |
| total per pulse | 622 | 1,813 |

Measured inclusively, staging trace rows costs about 360 us per pulse and
flushing them about 100 us, including the carrier validation of each
segment. The resume cursor (buffering the cursor row and comparing state)
costs about 3 us per pulse. **Resume's cost is complexity, not speed; the
trace's cost is speed.**

**Trace volume.** A hold-only run on 3 instruments x 20 pulses persists 81
rows: 60 `decision`/`recorded` rows (one per instrument per pulse: target,
quantity, mark, position before and after), 20
`reconciliation`/`reconciled` rows (one per pulse) and one run-level
`sizing_intent_unavailable` notice. A crossover strategy adds one
`execution`/`filled` row per fill. At 500 x 1,260 a quiet strategy persists
about 631,000 rows per run, each with 22 columns.

**Sweeps pay for rows they discard.** The fold stages and validates every
trace row on every pulse; the memory sink's `keep` filter runs only at the
pulse flush (`ledgr_fold_flush_pulse_block()`,
`ledgr_memory_diagnostic_keep()`), and a candidate retains almost none.

**Replay is already possible for Tier 1 strategies.** Every run stores its
strategy source, source hash, parameters and schedule;
`ledgr_extract_strategy(trust = TRUE)` rebuilds a Tier 1 strategy from the
store alone after verifying its hash. A Tier 2 strategy needs the user's
experiment object.

**Limits.** The cost table is one narrow workload and one host. `Rprof` on
Windows sampled at about 15.6 ms instead of the requested 5 ms; both builds
undercount by the same factor (3.05 and 3.07), so shares are reliable and
absolute values come from wall time. The consumer list in Section 6 comes
from reading contracts and code, not from a census; the response should
verify it.

## 4. Proposed Principle

Durable run records keep what cannot be recomputed cheaply from the
snapshot, the stored configuration and the ledger: fills and ledger events,
equity, completion evidence, and every deviation from the strategy's
intent. Everything else is recomputed on demand by deterministic replay.
Replay is an exact recomputation, not an inference, and it never persists a
second copy of run economics.

## 5. Part A: Retire Pulse-Level Resume

Proposed decision:

- A rerun of a `run_id` whose stored status is not `DONE` or `INCOMPLETE`
  and whose configuration matches restarts from pulse 1 after removing that
  run's prior rows. This is already the observed behaviour after a crash.
- The `strategy_state` cursor table, cursor rows, intermediate state
  checkpoints and `ledgr_strategy_state_restore()` are removed.
- The `ledgr.interrupt` soft stop is removed, or becomes an ordinary
  interrupt that ends the run `FAILED`. The response decides which (Q2).
- Kept unchanged: run-level idempotence (`DONE` and `INCOMPLETE` runs are
  reopened, not re-executed; terminal evidence is verified as today) and
  walk-forward session reruns, which skip completed test runs and rerun the
  others from their start.

Removed semantics, each with its contract text: opening positions posted on
a resume; corporate-action entitlements bound at a restart pulse; resumed
equity prefixes; diagnostics that append on resume; the finalization-only
resume; the resume refusal for ambient-RNG strategies and the resume
certification of RNG tiers; the pulse-seed counter continuing at a restart
position; the `RUNNING` row left by a soft stop.

## 6. Part B: Decision-Trace Granularity

Current consumers, from contracts and code:

- `ledgr_results(bt, "diagnostics")`;
- `ledgr_run_explain(bt, instrument_id, ts_utc)`, which refuses with
  `ledgr_run_explanation_unavailable` when no trace row exists and must not
  invent intent;
- summary and `print()` sizing coverage (D8), from `sizing` rows;
- valuation summaries and readers that count stale or frozen marks,
  terminal dispositions and stopped rows;
- sweep and walk-forward completion evidence, from the rows the memory sink
  keeps.

What only the trace knows is the strategy's intent on each pulse and every
reason the engine departed from it. On a quiet pulse there is no departure
and the intent equals the current position.

Three granularities:

1. **Exception rows.** Persist a row only when something happens: a target
   change, a restriction, an affordability reconciliation that changed the
   plan, a rounding, a stop, a fill, a stale or frozen mark, a terminal
   disposition, a run-level notice. A quiet pulse persists nothing.
2. **Exception rows plus an intent plane.** Option 1, plus one typed
   instrument x pulse matrix of the quantities the strategy asked for,
   written once per run. "What did the strategy want, against what
   happened" stays a single read.
3. **Full trace on request.** A run option persists today's trace; option 1
   or 2 is the default.

Seed recommendation: option 1 as the default, with Part C supplying the full
trace on demand. Option 2 is the alternative if the maintainer wants intent
answerable without replay (Q3). Option 3 is not recommended: replay makes a
persisted full trace redundant and adds a second persistence mode.

The trace must also stop costing anything where it is not kept: rows are
built only when they will be persisted or retained, so sweep candidates
build only what their sink keeps.

## 7. Part C: Explanation By Replay

When a requested explanation needs intent that was not persisted,
`ledgr_run_explain()` replays the run from pulse 1 through the requested
pulse with a full in-memory trace and answers from it. A separate reader
(name to be settled at the cut, for example `ledgr_run_trace(bt, from,
to)`) returns the full trace for a window the same way. Replay:

- rebuilds the strategy from the store for Tier 1 runs and requires the
  experiment for Tier 2 runs, refusing with a classed condition otherwise;
- verifies snapshot identity, configuration hash and strategy identity
  before it runs, and refuses on any mismatch;
- writes nothing to the store and never returns economics that differ from
  the stored run: replayed fills and equity through the requested pulse
  must equal the stored ones, or the explanation refuses;
- has the same RNG requirement as today's resume certification: a strategy
  that draws ambient random numbers cannot be replayed exactly and refuses.

The cost of an explanation becomes one partial rerun. For the runs ledgr
targets, that is seconds.

## 8. Contract Changes

The response should confirm this list against the contracts:

- "Early exit" and the soft stop (`ledgr.interrupt`);
- "Completion And Resume Evidence";
- availability decision-trace rows ("one decision trace row per invoked axis
  ID") and their append-on-resume rule;
- scheduled skips ("advances resume progress", the skip diagnostic);
- `ledgr_run_explain()` and its refusal rule;
- D8 sizing coverage, if `sizing` rows become exception rows;
- RNG tiers: resume certification becomes replay certification;
- pulse-seed counter continuation at a restart position;
- the store schema: `strategy_state` is dropped and `run_diagnostics`
  content changes, so the schema version bumps and older stores refuse.

## 9. Expected Effect And Sequencing

Removing trace staging on quiet pulses should remove most of the 360 to 460
us per pulse attributed to the trace on the narrow workload, and the same
cost from every sweep candidate. This is a descriptive expectation, not a
claim; the implementing cut measures it with per-function sample counts
(benchmark methodology manual, "Attributing A Change With Profile
Samples").

The decision is needed before the WS7/WS8 cut is written, because that cut
owns the durable write path. Implementation can live in that cut or in the
WS14a subtraction cut; the response should recommend which.

## 10. Rejected Alternatives

- **Keep the full trace and make it cheaper.** Vectorising row building
  lowers the per-pulse cost but still persists one row per instrument per
  pulse, about 631,000 rows for a quiet 500 x 1,260 run, for answers replay
  can give exactly.
- **Keep pulse-level resume for future live trading.** Live and paper
  trading need a run that extends as new bars arrive. Snapshots are sealed,
  so today's resume cannot do that; the live design will need its own
  incremental mechanism.
- **Store the full trace only for runs that were explained.** Explaining is
  a question asked after the run; storing ahead of the question is what this
  RFC removes.

## 11. Open Questions For The Response

- **Q1.** Is any consumer of `strategy_state` or of quiet-pulse trace rows
  missing from Sections 3 and 6?
- **Q2.** Does the soft stop disappear, or become an interrupt that ends
  the run `FAILED`?
- **Q3.** Option 1 or option 2 for the trace default?
- **Q4.** Which events are exceptions? In particular: is an affordability
  reconciliation that changed nothing an exception, and do `sizing` rows
  persist only when rounding changed a quantity?
- **Q5.** Is replay from pulse 1 acceptable for explanations, or does the
  explanation need a stored checkpoint (which would bring back part of what
  Part A removes)?
- **Q6.** Should implementation sit in the WS7/WS8 cut or in the WS14a
  subtraction cut?
