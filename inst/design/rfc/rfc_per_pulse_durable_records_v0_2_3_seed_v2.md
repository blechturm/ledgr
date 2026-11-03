# RFC Seed v2: Store The Intent/Outcome Difference, Rebuild The Rest

- Status: Seed v2; synthesis by a different author is next
- Author: Claude
- Date: 2026-11-03
- Target window: v0.2.3, decided before the WS7/WS8 cut is written
- Baseline: `317ca5d0` (`release/v0.2.3`)
- Inputs: seed v1, the Codex Type 2 response, the response review, the
  maintainer discussion of 2026-11-03, and the evidence in Section 3

Changes from v1: replay is withdrawn. Omitted trace rows are rebuilt
exactly from stored evidence, as two accepted decisions already require
(Section 2). Completion-based recovery stays. Sizing coverage moves to a
run summary. The consumer list and contract list are completed from the
response. ledgr is pre-CRAN with no users: no migration, old-format reader
or compatibility path; the store version bumps and older stores refuse.

## 1. Question

ledgr writes two records on every pulse of every durable run "in case
someone needs them later": a resume cursor and a decision trace with one row
per instrument per pulse. Which records should a run keep, so that every
explanation ledgr promises stays exact while quiet pulses cost almost
nothing?

The cycle owns pulse-level resume, the `strategy_state` cursor table, the
content of `run_diagnostics`, and how diagnostics and explanations are read.
It does not change fills, ledger events, equity, accounting, snapshot or run
identity rules, the no-lookahead contract, run-level idempotence or
walk-forward session reruns.

## 2. Prior Decisions

Honoured:

- **Asset-availability synthesis, Section 9.4.** A reopened run reproduces
  the same diagnostics and explanation "from persisted rows and sealed facts
  without re-executing strategy code"
  (`rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md:717-719`).
- **History-wave decision E9.** Rows may be omitted once they "can be
  reconstructed exactly without changing `ledgr_run_explain()` answers"
  (`rfc_history_wave_v0_2_2_decisions.md:468-474`).

Superseded:

- **v0.2.0.0 retention level.** "One required committed-run retention level
  for this release ... Detailed traces are not optional until a later
  retention design can preserve U's explanation contract"
  (`ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md:431-436`). This RFC is that
  retention design.
- **Release-gate clause** "never answered by weakening the trace"
  (`contracts.md:3370-3373`). It becomes: the reconstructed trace equals the
  full trace exactly (Section 7).

## 3. Evidence

Measured on 2026-11-03 against installed builds (seed v1 Section 3 and the
response's probes give method and limits):

- A quiet pulse at the Cut 9 head costs about 1.8 ms on 10 instruments,
  against about 0.6 ms in v0.2.2. Building and flushing trace rows costs
  about 360 to 460 us of it, including carrier validation of each segment.
  The resume cursor costs about 3 us.
- A hold-only run on 3 instruments x 20 pulses persists 81 rows: one
  `decision` row per instrument per pulse, one `reconciliation` row per
  pulse and one run notice. The Sharadar 1998-2026 runs persisted 3.6 and
  4.2 million `decision_recorded` rows, most on pulses where the strategy
  held (history-wave finding C11-F2).
- In a 3 x 20 crossover run all 56 quiet `decision` rows have target equal
  to position, quantity 0, mark source `current_close`, price equal to the
  pulse close, empty detail and a run-constant feature identity. The four
  rows whose target changed were followed by fills of exactly the requested
  difference. Every field of all 60 rows follows from the ledger, the sealed
  bars and the run configuration.
- A crash restarts at pulse 1 today; only the `ledgr.interrupt` soft stop
  continues mid-run. A run that failed through a strategy bug cannot be
  resumed once the bug is fixed: the corrected strategy refuses with
  `ledgr_run_hash_mismatch`. Completion-based recovery finishes a run whose
  fold committed but whose publication failed, with no strategy call.
- Sweep candidates build and validate every trace row and discard almost
  all of them at the pulse flush (`R/fold-engine.R:277`,
  `R/output-handler.R:22`).

## 4. Principle

A run stores what cannot be rebuilt from its own stored evidence: ledger
events, equity, completion and terminal evidence, every difference between
what the strategy asked for and what happened, and compact run summaries.
Every other diagnostic row is rebuilt exactly on read from the ledger, the
sealed snapshot facts and the stored run configuration. Rebuilding never
executes strategy code.

## 5. Part A: Pulse-Level Resume

- The `strategy_state` cursor table, cursor rows, intermediate state
  checkpoints and `ledgr_strategy_state_restore()` are removed. In-memory
  declared strategy state and its axis, default and reset rules are
  unchanged.
- The `ledgr.interrupt` option is removed. A real interrupt rolls back the
  fold and ends the run `FAILED`, as today.
- Completion-based recovery stays: a run with valid committed terminal
  evidence finishes publication without re-running the fold
  (`R/backtest-runner.R:513-560`). Malformed evidence refuses before any
  deletion.
- Any other non-terminal run restarts from pulse 1. Configuration, snapshot
  and strategy identity are verified before cleanup; the previous attempt's
  derived rows are cleared atomically and openings are posted once. Run
  identity, provenance and tags are kept.
- Removed with the cursor: equity prefixes on resume, diagnostics that
  append on resume, entitlements bound at a restart pulse, the pulse-seed
  counter continuing at a restart position, and the resume refusal for
  ambient RNG.

## 6. Part B: The Trace Stores The Difference

**Pairing.** A decision at pulse t executes at the next open. The fold
handles both in the same step: observation builds pulse t's execution
packet from the next bar (`R/fold-engine.R:619-631`). The comparison is
made when pulse t is committed, with nothing held over.

**The difference.** For each instrument on pulse t's decision axis, the row
is stored when any of these holds:

- the executed position after the next open differs from the target the
  strategy returned, including no fill, a partial outcome, the final pulse
  (no next open) and a missing next bar;
- risk changed the target, even if it restored a hold;
- a restriction, affordability reconciliation or stop acted;
- sizing changed the quantity (guard, rounding, rounded to zero) or sizing
  evidence was unavailable;
- the strategy supplied an intent reason;
- the instrument was valued at a mark other than the current close (stale,
  frozen, terminal), including on scheduled skips;
- a terminal or lifetime transition happened.

Run-level notices, stop and error evidence and scheduled-skip disclosure
are stored as today. A clean trade (target reached exactly at the next
open) stores no trace row: its decision and execution rows are rebuilt from
the ledger event. A reconciliation that changed nothing stores no row; its
checks still run and its failures still stop the run.

**Cost.** The comparison is a few vector operations over positions on the
decision axis followed by one `which()`: a few microseconds per pulse at 500
instruments. Rows are built, encoded and validated only for flagged
positions, before any materialization (response F8). Matching by instrument
name and parsing timestamps are not allowed here (optimization manual,
"No POSIXct in the hot loop" and the WS14 ID-matching amendment).

**Run summaries.** Values that today are computed by reading every row are
accumulated during the fold and stored once per run: sizing coverage
(pooled numerator and denominator, minimum and last coverage, counts and
value totals, no-instruction against unavailable evidence; response F6) and
the per-run decision counts that readers use as an existence gate
(`R/valuation-summary.R:636-645`). A missing row never means "no decision".

**Sweeps.** Candidates apply the same selection and build only the rows
their sink keeps.

## 7. Part C: Reading Is Unchanged

`ledgr_results(bt, "diagnostics")`, `ledgr_run_explain()` and every other
reader return exactly the rows they return today. A reader merges stored
rows with rebuilt rows in the original order. Logical `diagnostic_seq`
numbers are kept, as the memory sink already numbers rows as if every row
were kept (`R/output-handler.R:360-366`). Rebuilding is limited to what a
read asks for: one instrument and time for an explanation, the requested
run for a diagnostics read.

Rebuild inputs: ledger events with their recording-pulse association
(`R/execution-timing.R:224`), sealed bars and facts, the valuation policy,
the reconstructed availability planes, and the stored configuration for
feature identity. No strategy code is executed.

**Proof obligation.** Before the change, the current build records the full
trace for a set of oracle runs: quiet and fill-heavy synthetic workloads,
weight-based sizing, a declared-session availability run with restrictions,
stale and frozen marks and a terminal, a scheduled strategy, a carried
opening, and the private Sharadar reference. After the change, the
reconstructed trace must equal the recorded one exactly, row by row and
field by field, with the same `diagnostic_seq`. This replaces the
release-gate clause in Section 2.

## 8. Contracts To Change

Adopted from the response: fold core and fold carrier (state output,
diagnostic carriers and retention); availability context and state;
availability affordability (reason vocabulary); result read surfaces;
result completion and valuation; fills and sweep restoration;
strategy reproducibility and provenance; persistence fold evidence;
persistence completion evidence (keeping publication recovery); "Early
exit" and the soft stop; scheduled skips ("advances resume progress"); D8
sizing coverage (`contracts.md:1815`); the release gate at
`contracts.md:3370-3373`. The store schema drops `strategy_state`, changes
`run_diagnostics` content and adds the run summaries.

## 9. Not Adopted

- **Explain by replay (seed v1 Part C).** It executes stored strategy code,
  which Section 9.4 rules out, and needs safeguards the response spelled out
  (whole-dependency eligibility, a run-level explanation commitment,
  calendar and prefix rules, an RNG certification). Exact reconstruction
  needs none of them. A replay tool that requires the user's own experiment
  may be parked on the horizon as a debugging aid.
- **A full-trace run option.** A second persistence mode for rows that are
  rebuilt exactly anyway.
- **Keeping the cursor for future live trading.** Live and paper trading
  need a run that extends as bars arrive; sealed snapshots make today's
  resume unable to do that.
- **Richer analysis evidence.** The analysis value is the chain factor to
  rank to weights to target to fill, which the trace does not hold. It stays
  with the horizon entry "Durable factor and decision evidence"
  (`horizon.md`, 2026-10-10), as an opt-in feature with its own RFC.

## 10. Placement And Measurement

This is semantic work: a separately reviewed workstream before or with the
WS7/WS8 cut, not WS14a (response F10). If the cut grows too large it becomes
a prerequisite cut with its own identity impact. The implementing cut
records the oracle traces of Section 7 first, then measures quiet,
fill-heavy and sweep workloads with per-function profile counts (benchmark
methodology manual), plus stored rows and bytes and read cost of
`ledgr_run_explain()`.

## 11. Open Questions For Synthesis

- **Q1.** Does `ledgr_results(bt, "diagnostics")` return the full rebuilt
  trace by default, or the stored differences with an argument for the full
  trace?
- **Q2.** Is a fill at a different price but the requested quantity a
  difference? (Proposed: no; the price is economics and lives in the
  ledger.)
- **Q3.** Do scheduled-skip disclosure rows stay one per skipped pulse, or
  become a run count plus the skips that carried a non-close mark?
- **Q4.** Which oracle runs are mandatory in the proof set, and is the
  private Sharadar reference one of them?
