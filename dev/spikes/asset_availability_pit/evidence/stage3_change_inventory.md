# Stage 3 Fork Change Inventory

**Status:** Review corrections and witness v3 independently accepted; Stage 3
gate passed on 2026-09-07.

**Executor substitution:** The maintainer directed Codex to execute Stage 3.
Claude remains the intended independent reviewer for this stage.

## Production Baseline

- Package base commit: `1f42cf7`.
- Passing Stage 2 gate target: `9d957a3`.
- Stage 3 authorization and gate-record commit: `c82c485`.
- Reviewed Stage 3 implementation and active-evidence commit: `d7a1fd3`.
- Approved policy: `asset_availability_initial_policy_v4`.
- Maintainer-approved and independently reviewed witness contract:
  `asset_availability_witness_v3`.
- Production package and `inst/design` paths changed: none.

## Shared-Fork Inventory

| Concern | Production baseline | Stage 3 fork treatment |
| --- | --- | --- |
| Execution object | Fixed `ledgr_execution_spec` instrument axis | Fixture-scoped list with the same ordered dense axis for W21 |
| Strategy output | Full named numeric targets | Full ordered target vectors; no missing-as-zero behavior |
| Risk | Package risk plan before fill proposal | Independent max-weight calculation; checked against the package risk step |
| Fill timing | Next pulse open, event stored at next pulse timestamp | Next session open with explicit calendar label |
| Event order | Validated target-vector order | Same target-vector order; affordability order remains separate |
| Cost | Package cost resolver | Fixed fee applied once per accepted fill |
| Accounting | Fold-owned FIFO lot state | Independent FIFO lot state with fee-net realized P&L |
| Affordability | Production no-op seam | Approved v4 virtual-ledger policy for W02 only |
| Status | Not represented by the dense package fold | Effective/knowledge-time resolver with conflict handling |
| Valuation | Current close required by production risk | Separate fresh or bounded-stale risk mark for W22 |
| Carried state | Opening positions and FIFO basis | Stable-ID quantity, lot basis, cash, and valuation evidence |
| Feature graph identity | Package feature identities | Typed prototype identities for W25 mutation evidence |

The fork is intentionally narrow. It does not split or otherwise modularize
the production fold core, does not add a package execution engine, and does not
claim package walk-forward, sweep, persistence, or promotion integration.

## Conformance Surface

W21 compares the fork directly with an actual `ledgr_run()` over the same
sealed bars, user-ordered universe, opening state, strategy targets, risk chain,
cost model, and timing model. The control asserts fill order and economics,
risk output, equity, final cash, positions, realized P&L, and final-pulse
no-fill behavior before the frozen 58-row table is checked.

The reference path also produces complete checker-baseline tables for W02,
W09, W22, W24, and W25. They prove the M1-M5 checker paths and are not recorded
as representation passes. W02 additionally runs its two dense controls through
the package. The checker enforces exact row shape, typed values, row-specific
tolerances, reason codes, identity relations, surplus evidence, and cross-row
semantic invariants.

## Deliberate Mutations

| Mutation | Injected defect | Required rejection |
| --- | --- | --- |
| M1 | Existing W22 evidence changed to an unavailable bar and stale-mark fill | value mismatches plus `stale_execution_price` |
| M2 | Superseded halt remains active | `value_mismatch:resolved_status` |
| M3 | Carried A01 holding omitted at fold 2 | `value_mismatch:opening_axis` |
| M4 | Fit identity omits estimation population | `identity_relation_mismatch:fit_identity` |
| M5 | Funding sale dropped after virtual credit | `affordability_reconciliation_failed` |

## Known Boundaries

- The reference provider is the first dense-state representation, not a result
  for all three charter prototypes.
- Stage 3 exercises six witnesses. Stage 4 must run every provider against all
  applicable W01-W31 packets.
- The external calendar's open label is an evidence translation because the
  current daily package event stores the next pulse timestamp.
- The package fills surface reports gross close P&L while fold-owned lot
  accounting is fee-net. Seed v2 must preserve or explicitly resolve that
  evidence-surface distinction.
- No Stage 3 timing is eligible for architecture comparison.
- `evidence/stage3_code.csv` records the reviewed implementation commit as the
  first appearance of every Stage 3 executable.

## Accepted Residual Review Notes

The independent reviewer accepted these Low-severity containment limits for
Stage 3. They do not change the recorded witness outcomes:

- Surplus identity evidence under an unknown case can escape the current
  materializer filter; missing expected identities still fail closed.
- A surplus-evidence finding would render its internal key separator as a
  control character in the CSV finding text.
- The W21 adapter still uses literals for its unrealized-P&L lot basis,
  strategy-validation label, and final-pulse fill count. Other derived rows
  catch divergence in the recorded fixture.
- The Stage 3 gate does not independently enforce witness-registry approval
  flags. All 31 registry rows are approved for this run.
- One W22 manifest table row exceeds the prose width convention by two
  characters.

These are candidates for checker hardening before reuse. They are not
architecture findings and must not be promoted into production requirements
without the normal design process.

## Failure And Repair Inventory

| Failure | What exposed it | Repair |
| --- | --- | --- |
| Stage 2 gate rejects prototype code | Re-running the pre-prototype gate after Stage 3 files existed | Stage 3 verifies the frozen hashes and gate ancestry directly; it does not weaken or rerun the closed pre-prototype gate |
| Stateful strategy used `<<-` | Package strategy preflight rejected the non-portable closure | W21 derives its target from the pulse timestamp and fixture facts without external mutation |
| Snapshot identity was queried before sealing | The first W21 package run had no sealed hash to record | W21 creates and seals the fixture snapshot before constructing source identity |
| Public fill P&L is gross while frozen W21 evidence is fee-net | Package/fork evidence comparison exposed the accounting-surface distinction | The adapter reads the fold-owned fee-net accounting attribute and verifies it against reconstruction through `ledgr_lot_state_from_events()` |
| W02 package controls were transcribed | Independent review ran the actual missing- and complete-bar cases | Both controls now execute through `ledgr_run()`; witness v3 corrects the package error class |
| M1 appended evidence absent from W22 | Independent review removed the added rows and the semantic finding became unreachable | Witness v3 records baseline execution-bar, price, and status rows; M1 mutates those rows in place |
| W21 positions and lots were literals | Independent review traced the package adapter | The adapter now derives both from actual memory-fold events and verifies reconstructed accounting against fold-owned attributes |
| Max-weight fork rounded down | A fractional-cap probe disagreed with `ledgr_apply_risk_step_max_weight()` | The fork preserves fractional quantities and runs a non-integer package calibration |
| Extra produced evidence was discarded | Independent review injected surplus keys | Materialization records surplus keys and conformance rejects them |
| Affordability accepted proposals without price evidence | Independent review traced the W02 helper inputs | The fork requires a finite positive execution price before affordability evaluation |

The implementation repairs preserve their applicable expected answers. W02
and W22 follow the explicit witness-v3 correction record. None of the changes
revises policy v4.
