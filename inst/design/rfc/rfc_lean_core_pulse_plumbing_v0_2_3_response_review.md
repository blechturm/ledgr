# Proposed Amendment: Lean Core Pulse Plumbing (v0.2.3), Response Review

- Stage: response review (stage 4), maintainer, 2026-11-06. Drafted by
  Claude from the maintainer's statements in the session, quoted below.
- Read: the [response](rfc_lean_core_pulse_plumbing_v0_2_3_response.md)
  (Codex, Type 2, REVISE) with the Claude-drafted brief that produced it.
- New evidence since seed v1, both on the pinned reference `d5b3a151`:
  - check-cost probe `dev/spikes/fold_plumbing/checks.R` (`9a1a1a58`): the
    conditions that can fail on data cost 10 and 25 us per pulse against 238
    and 389 for today's full carrier checks (momentum, fill-heavy);
  - append-validator spike `dev/spikes/append_validator/` (`3d6d2772`): the
    same rules restructured in R take a 54-row fill block from 243 to 63 us,
    compiled C++ to 40 us;
  - edge-checks spike `dev/spikes/edge_checks/` (`c26b50a6`): today's fold
    without its internal re-checks runs 29 and 17 percent faster with
    identical results, and still refuses bad strategy output;
  - strategy-check spike `dev/spikes/strategy_check/` (`820c5a21`): the same
    rules with an in-order fast path take the check from 95 to 15 us at 500
    instruments;
  - lean floor probe `dev/spikes/fold_plumbing/lean.R` (`8beb4bdc`,
    `22fadb31`, `2885596e`): stages that emit their data and do no work cost
    77 and 225 us per pulse in the first lean shape and 22 and 71 us in the
    compact shape (references, compact records, wide tables built at the
    output boundary), reproducing every output exactly;
  - write-mode probe `dev/spikes/write_mode/`: `audit_log` and `db_live`
    write identical stores; `db_live` takes 195 against 9.4 s per
    fill-heavy run (one insert per fill) and saves about 34 MB of R heap.

## Decision

The maintainer accepts the response's analysis but not its conclusion that
internal checks must stay in production runs. Seed v2 is written on these
terms.

**D1. ledgr trusts its own modules.** "so I dont see why we should not trust
our own modules. why do we have to recheck everything" A value one ledgr
module hands to another is not checked again at runtime. The correctness of
each module is the job of its unit tests: "well, if we properly design unit
tests this should not happen." The tests cover each module's guarantees one
property at a time, including empty, missing and overflow inputs. The stage
recorder, the parity harness against the pinned reference and a debug mode
that turns every internal check back on complete this; the test suite runs
with debug on, and parity runs with it both on and off. This overrules
response finding 6: the maintainer accepts that a module defect no test
reaches is not refused in a user's run.

**D2. Runtime checks stay only where data or code enters from outside.**
- Data is checked once at preparation, not per pulse: "well we should validate
  the data before. I dont see why we should do this every pulse" This
  covers snapshot bars, marks and prices, facts and provider codes.
- User code is checked at its return, every time it runs. The strategy's
  output is checked on every decided pulse: "strategy output check is probably
  necessary because the user can do shenanigans here". Other user code is
  not checked equally (D5).
- Imported positions, deserialized state and the stored ledger read back
  keep their checks.

**D3. Refusals the contract promises users stay.** Examples are overflow
refusals in the lot kernel, unaffordable orders and buffer capacity at P5.
They are product behavior, not re-checks, and stay where the contract puts
them, with their classes and order. Seed v2 classifies every existing
runtime refusal as contract behavior (stays) or internal re-check (moves to
debug mode).

**D4. The ledger check on write goes for ledgr's own producers.** Every
event the fold publishes is built by ledgr's own modules. The check on read
stays and guards the stored ledger. This amends the typed accounting
synthesis Section 3.4 and its rejected item "validation only at append, or
only in replay", whose premise was producers that cannot be trusted. The
validator restructure from the append-validator spike still applies to the
read path and to debug mode.

**D5. Do as much as possible before per-pulse work.** "yes they count as
edges but not equally. lets think this through, what do we absolutely have
to check, what can we skip and what can we move into the dataprep phase.
the guding principle should be to do as much as possible before we even
start per pulse work." Cost models and risk chains are built only from
ledgr's own constructors and validated once in E; they take no user
function. Custom indicators are user code, but run in preparation. So:
- once in preparation: snapshot data, every feature's output matrix
  including custom indicators, and in E the cost model, risk chain,
  schedule, strategy parameters, state declaration and imported opening
  positions;
- per pulse, because user code runs there: the strategy's return (targets,
  intent, state update), the history requests the strategy makes, and the
  contract refusals on what it asks for (buying what is not buyable,
  refused short exposure);
- skipped: every internal re-check, including today's post-risk quantity
  check, since the risk chain is ledgr's own module.

**D6. One write path: run in memory, write at the boundary.** "imo we should
avoid per pulse work here as well. a write after an in memory run seems
better." `db_live` is retired: "I also think we should retire it". Events
and diagnostics are written per bounded chunk and at the end of the run,
inside the run's one transaction, as `audit_log` already does. Before CRAN
this needs no compatibility path; the `execution_mode` argument and its
stored value go. Compact records keep the bounded-memory rule cheap: a full
chunk is converted and written, not each pulse.

**D7. Measure against the floor, one stage at a time.** The compact lean
fold is the skeleton's measured floor (22 and 71 us per pulse) and stays in
the repository as a reference. "we should measure each new family against a
floor skeleton in which the previous and past stages do nothing during
implementation to isolate the stage we are developing." A family's stage is
measured in a skeleton where every other stage is a stub, and its cost over
the floor is reported at the family close; waste is cost above the floor
that buys no guarantee. The budget rule is unchanged: each family closes
against microsecond and line budgets, and an overrun is fixed or explicitly
accepted (lean fold core amendment A2, extension synthesis Section 4 step
6, macro rule 16). What the microsecond budget is set against is decided in
seed v2. (Revised 2026-11-06: the first wording, "recorded, not gated",
contradicted A2 and was withdrawn.)

**D8. Compiled FIFO stays on the table.** "We first build the R version as
oracle then we potentially compile it." This is the macro plan's WS14 route:
a compiled kernel once ordinary R representation work no longer dominates,
a focused Type 2 decision before compiled execution becomes the default,
and the R kernel as the executable oracle. The lean fold core synthesis's
"no compiled stage in this cycle" governs building the lean core, not the
release.

## Response findings

| Finding | Disposition |
| --- | --- |
| 1. Construction proofs per property | Accepted as the unit-test design: each module's tests prove its output properties one by one. Overruled as a runtime requirement (D1). |
| 2. Property-level check census | Accepted as the input for D2 and D3: seed v2 sorts every condition into data entry, user code, contract refusal or internal re-check. |
| 3. Publication and append overlap | Moot for writes under D4. The fill `mark_age` gap is routed below. |
| 4. Reserved-row protocol | Accepted for the one remaining write path. Seed v2 binds the protocol, keeps the capacity refusal at P5 and keeps sweep workers candidate-local; the live-mode exception falls away with D6. |
| 5. Residual-only diagnostic writes | Accepted. |
| 6. Debug switch is not a production guarantee | Overruled by D1, with the trade-off recorded. Debug runs explicitly in tests, the recorder and parity workers. |
| 7. Evidence qualifications | Accepted; the spike README was corrected in `b4f89f95`. Seed v2 reports the deltas as ablations and adds the two probes above. |
| 8. Incomplete supersession map | Accepted, extended by D4 to the typed accounting synthesis Section 3.4, its rejected list and the contract rule groups it feeds. |

## Routed outside this cycle

The pinned append and read check never refuses a fill row's `mark_age`: it
is replaced with NA for every non-disposition row before the forbidden-field
test (`R/accounting-replay.R:258-274`; response finding 3; reproduced by the
append-validator spike). It concerns the shipped read boundary and goes to a
separate maintainer decision, not into seed v2.

## Recorded deviations

- The response brief and this review were drafted by Claude, a seed
  co-author. The maintainer's statements above are the reread that
  `rfc_cycle.md` (Briefs) requires.
- Codex ran in its own workspace-write sandbox (the session's auto mode
  refused an unsandboxed run).
