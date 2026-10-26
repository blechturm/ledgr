# Workstream 61 closeout: scheduled execution and persistence

## Outcome

LDG-3111 and LDG-3112 land as the required atomic unit in `b660cb05`.
The prepared schedule verdict now gates only P2 (decide) and P3 (plan) in the
single fold. P1 (observe), P4 (apply) and P5 (commit) still run for every
processed pulse. The same commit moves the current store from schema 123 to
124 and adds durable schedule provenance and exact decision/skip counts.

This workstream does not change saved-sweep, walk-forward, promotion or worker
formats. Those remain owned by Workstream 62.

## Fold boundary

The fold indexes the already-compiled logical `decision_due` vector. A false
value produces one private null-decision carrier and one constant empty plan.
It does not build a public history frame or pulse context, invoke the callback,
construct a target, run the risk chain or emit per-instrument decision rows.

Observation still advances prices and posts economic events. Apply still binds
the following pulse's corporate-action entitlements and applies the empty plan.
Commit still reconciles, serializes the carried strategy state, performs
interrupt and checkpoint duties and commits the pulse. A skipped pulse emits
one diagnostic with the exact accepted fields:

- empty `instrument_id`;
- `stage = "decision"` and `outcome = "skipped"`;
- `reason_code = reasons = "scheduled_skip"`; and
- `detail_json = "{}"`.

An explicit strategy hold remains a callback result and therefore retains its
existing meaning. A flat run with zero compiled decisions refuses before fold
effects through `ledgr_schedule_no_decision`; otherwise identical opening or
carried-position runs remain valid and process P1, P4 and P5.

## Current-format record

Schema 124 adds physical `run_provenance.schedule_json` and `schedule_hash`
columns plus `run_telemetry.decision_pulse_count` and
`scheduled_skip_count`. The logical config and identity field remains
`strategy_schedule`. Writers use the validated declaration and compiled counts,
not a scan of diagnostics.

Run recovery verifies the stored declaration and hash, reattaches the
declaration to the trusted inner strategy and recompiles from the stored
identity-bearing inputs. Plan, experiment, run-info, print and summary surfaces
use the accepted schedule label; run print and summary add the exact decision
and skip-count line. Store 123 refuses through the current-format gate. No
migration, old reader or missing-marker fallback was added.

## Detecting evidence

- LCL-0496 / LTB-0505 counts all five fold stages and public construction
  surfaces, pins the literal skipped diagnostic and distinguishes explicit
  holds and all zero-decision branches.
- LCL-0497 / LTB-0506 pins schema 124, the logical/physical naming boundary,
  persistent declaration and counts, public disclosure, trusted strategy
  recovery and tamper refusal.
- LCL-0498 / LTB-0507 compares a corporate-action event on a skipped pulse and
  an interrupt/resume from a skipped pulse against their uninterrupted
  oracles, including ledger, equity, positions, lots and strategy state.

The focused schema, provenance, extraction, run-store, result, fold,
availability, corporate-action, continuity, sweep, documentation-contract and
control-plane suites pass. The fold-phase and codebase-contract checkers pass.

## Seven-shape walk

The fold consumes one indexed logical primitive. It adds no one-row frame per
pulse, full-table subset in an instrument loop, scalar parser/formatter,
row-at-a-time JSON, discarded recomputation, quadratic validator or scalar
write into an environment-held vector. Schedule JSON and its hash are prepared
outside the fold and written once per run. Counts come directly from the
compiled verdict. The scheduled branch constructs constant private carriers;
the unscheduled branch retains its existing shape.

## Records before close review

The ordinary fast profile completed 577/577 blocks with a 107.470-second
median against the 112-second bound. The review profile's actual blocks passed;
its runner exited on the pre-existing optional `tidyr` absence because the
control plane rejects a claim guarded only by a skipped block. This is recorded
as an environment miss, not a passing review-profile gate.

The corrected real-data-scale synthetic fixture compared clean committed
worktrees at accepted Workstream 60 `e95e966f` and corrected Workstream 61
`3c488bc4`. Both `meta.csv` files name those full commits. Forty-eight of 50
gated families were byte-identical
and the identity family was identical. The only differences were the two
run-info families, each containing exactly the intended additions:
`schedule_json = null`, `schedule_hash = null`, decision count equal to pulse
count, zero scheduled skips and schema 124 instead of 123. Economics, trades,
state and identity did not change. The checker detected 51/51 isolated family
corruptions in self-test. The reproducible records were taken at
`C:/Users/maxth/ledgr-research/.tmp/ws61/{clean-pre,clean-candidate}` and are not committed
because their generated family payloads total roughly 437 MB per arm.

## Close-review correction

The first independent clean-context Opus review returned `CHANGES_REQUIRED`
and is recorded in `close_review_61.md`. It confirmed the stage architecture
and found two current-reader defects plus detector, disclosure and record gaps.
Correction `3c488bc4`:

- prepares compiled schedule counts before terminal recovery can finalize and
  replace telemetry;
- treats schedule JSON and hash as an inseparable pair, classes parse failures,
  cross-checks provenance against the canonical config declaration and refuses
  missing scheduled-run counts in run information, open, print, summary and
  trusted recovery;
- avoids the schedule query for unscheduled backtest printing;
- pins history-view reads, reconciliation, all decision rows at skipped pulses,
  exact output counts, flat/opening/carried zero-decision cases and a
  dividend-bearing interrupt/resume ledger, position and lot-state oracle;
- removes the unused fold-return counts and avoids re-normalizing carried state;
  and
- completes the plan, run-discovery and NEWS disclosure.

The corrected schedule suite and thirteen affected persistence, output,
continuity, corporate-action, documentation and control-plane suites pass.
Both structural checkers pass. The correction fast profile executes 577/577
blocks in 108.040 seconds against the unchanged 112-second bound. A fresh
focused Type 1 confirmation is the remaining workstream gate.
