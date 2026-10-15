# Fold execution phase inventory

Status: LDG-3052 implementation inventory, before body extraction.

Authority: the accepted
`rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md`, Sections 3 to 8.
Source anchors refer to executable baseline `07f91bcf`; the recorder repair is
`574a9702`. This inventory describes existing behavior. It does not authorize
behavior changes.

## One envelope and five stages

| Owner | Current source | Reads | Writes and observable effects |
| --- | --- | --- | --- |
| E | `fold-engine.R:237-320` | execution spec, strategy, feature, pulse, resume, risk, cost, availability and policy inputs | validates the spec; scopes RNG; prepares run services; validates compiled dispatch; initializes handler buffers |
| E | `:321-455` | bars, projections, aliases, telemetry and resume fields | prepares views and access services; initializes all fold-owned mutable state; creates diagnostic writer |
| E | `:491-523` | pulse range and resume prefix | writes empty-run completion/evidence; binds the initial corporate-action boundary; creates pulse notes |
| P1 | `:528-578` | pulse, bars, positions, corporate-action plan | advances pulse label; posts due cash and event sequence; may emit settlement refusal diagnostics |
| P1 | `:582-609` | provider, valuation state, held positions and policy | derives the decision view; posts scheduled dispositions; re-derives the view |
| P1 | `:611-692` | lifetime facts, terminal labels, marks and holdings | resolves terminals; appends disposition events; mutates cash, positions and lots; may stop; re-derives the view |
| P1 | `:695-758` | valuation plane, frozen set, feature/bar locators, carried state and axis | refuses unpriced holdings; records freeze entry/exit; narrows prepared views; normalizes carried state for an axis change |
| P1 | `:762-795` | positions, marks, cash, telemetry clock | values pulse-start equity; advances last-fully-valued time; appends the availability equity fact; calls handler `record_equity_fact` |
| P2 | `:806-873` | P1 identities, locators, positions snapshot, prepared views and context services | materializes `bars`, feature tables and public `ctx`; the public frames are local to this range |
| P2 | `:875-919` | context, pulse notes, strategy and params | resets notes; calls and wraps the strategy; normalizes result shape; validates targets |
| P2 | `:924-985` | targets, availability restrictions, risk marks and positions | records pre-risk decision trace; may return a counted risk-mark stop and flush its diagnostics |
| P2 | `:987-1017` | risk plan, targets, stale marks and context | applies risk; validates post-risk targets; records post-risk and stale-mark traces |
| P3 | `:1024-1077` | post-risk targets, positions, timing mode, views and cost resolver | computes deltas; builds dense or availability plan; validates event kinds |
| P3 | `:1079-1108` | plan events and cash | performs availability affordability check; may return a counted stop and flush diagnostics |
| P3 | `:1110-1145` | rejected entries and fills | appends rejected and filled diagnostic segments; mutates no economic state or handler buffer |
| P4 | `:1150-1181` | corporate-action plan, compiled model and fill intents | binds next action boundary; compiled path applies state then calls `append_compiled_spot_batch` |
| P4 | `:1183-1231` | canonical fills, lots, costs and event sequence | per fill: lot transition, `write_fill_events`, event-sequence increment, optional `record_accounting_fact`, then positions and cash mutation |
| P5 | `:1239-1256` | handler buffers, plan cash and event time | flushes pulse events; advances last-executed time; aborts on cash reconciliation mismatch |
| P5 | `:1261-1290` | P1 packet values and pre/post-risk targets | appends reconciliation diagnostics |
| P5 | `:1294-1322` | raw state update, axis and event mode | normalizes and serializes strategy state; writes or buffers it; installs carried state; increments processed count |
| P5 | `:1324-1356` | telemetry clock, handler counts and controls | records telemetry; flushes due checkpoint; applies max-pulse and cooperative interrupt controls |
| E | `:1359-1383` | pending counts, full-run flag, terminal state and diagnostic writer | flushes remaining buffers; drains/releases diagnostics; writes completion/evidence or partial diagnostics |
| E | `:1386-1411` | handler transaction and current stage/time | owns transaction; maps an exception to the existing availability diagnostic; re-signals the condition |
| E | `:1413-1425` | telemetry and fold-owned state | records total loop time and returns the fold result |

The ranges above cover every statement in the current pulse body. The
extraction may move a range only to its named owner and must preserve its
statement order, callback boundary, condition and message.

## Fold-owned mutable carrier

One locked environment contains exactly these slots. It is passed by
reference; no stage accepts or returns another mutable aggregate.

| Slot | Type and initial shape | Writer | Last production read |
| --- | --- | --- | --- |
| `cash` | numeric scalar | P1, P4 | E return |
| `positions` | uniquely named numeric vector | P1, P4 | E return |
| `lot_state` | list | P1, P4 | E return |
| `state_prev` | any non-data-frame user value, including `NULL` | P1, P5 | E return |
| `state_axis` | `NULL` or character vector | P1, P5 | P5 normalization |
| `event_seq` | positive integer scalar | P1, P4 | E return |
| `status` | nonempty character scalar | E applying a stop | E completion/return |
| `stop_reason` | character scalar, `NA` before a stop | E applying a stop | E completion |
| `affected_exposure` | list | E applying a stop | E completion |
| `processed` | nonnegative integer scalar | P5; E applying counted stop | E telemetry/return |
| `full_run` | logical scalar | P5 controls | E completion/return |
| `last_fully_valued` | one UTC time, possibly missing | P1 | E completion |
| `last_executed` | one UTC time, possibly missing | P4/P5 boundary | E completion |
| `frozen_set` | character vector | P1 | P1 next pulse |
| `current_stage` | nonempty character scalar | E/P1-P5 on entry | E exception diagnostic |
| `current_ts` | one UTC time, possibly missing | E pulse drive | E exception diagnostic |
| `pending_segments` | list | P1-P5; E applying a stop | P5/E diagnostic flush |
| `diagnostic_seq` | nonnegative integer scalar | P5/E diagnostic flush | next flush |
| `telemetry_idx` | nonnegative integer scalar | P5 | E telemetry total |

No slot is a data frame. `ctx`, `bars`, `feature_table` and `features_wide`
are P2 locals, and `ctx` never references the carrier. Prepared full tables
stay envelope-owned inputs and are released at their existing last read.

### Existing loop-local assignment sites

The current loop writes shadowing locals at sixteen sites:

- state or components, nine: `:565`, `:597`, `:681`, `:1168`, `:1169`,
  `:1170`, `:1198`, `:1230`, `:1231`;
- event sequence, five: `:566`, `:598`, `:682`, `:1171`, `:1210`;
- carried state, two: `:753`, `:1311`.

The outer variables returned at `:1420-1423` therefore remain stale today.
`backtest-runner.R:1268-1270` stores the three returned values and never reads
them. LTB-0006 and LTB-0013 do read them, but compare two equally stale paths.
LDG-3054 alone repairs the return to the live carrier under the accepted
Section 5.5 exception; LDG-3052 does not change it.

## Stateful service census

| Service | Stateful calls | Declared caller |
| --- | --- | --- |
| availability valuation state | `advance` | P1 |
| prepared availability provider | `decision_view`; `execution_view` | P1; P3 |
| corporate-action plan | `post`, `post_disposition`, `check_quantity_effects`; `bind_boundary` | P1; E and P4 |
| pulse notes | reset, callback helper writes, read | P2 |
| fast context and scalar-access tracker | pulse index and accessor state | P2 |
| feature-bundle accessors | last explicit-map memo | P2 |
| diagnostic writer | `append_block`, `drain`, `release` | P5/E stop; E; E |
| equity-fact accumulator | preallocated by E; `append`, `collect` | P1; E return |
| output handler | `init_buffers`, `run_transaction`, `write_run_evidence`, `write_exception_diagnostic` | E |
| output handler | `write_run_diagnostics` | E and diagnostic flush |
| output handler | `append_event_rows`, `record_equity_fact` | P1 |
| output handler | `write_fill_events`, `record_accounting_fact`, `append_compiled_spot_batch` | P4 |
| output handler | `flush_pulse_events`, `write_strategy_state`, `buffer_strategy_state`, pending counts, `flush_pending` | P5 and E as applicable |
| telemetry environment | sample writes; totals | P5; E |

`canonical_json()` has a process-global content memo but carries no run or
pulse state, so it is outside this census. A detector must reject any listed
mutator at a stage not declared above. The history wave may extend the table
only by an accepted amendment.

## Typed short-lived results

- P1 returns one decision packet made only of typed primitives, vectors and
  locators. It lives through P5 and contains no data frame.
- P2 returns the pre-risk targets, post-risk targets and raw user state
  update. It does not normalize the update.
- P3 returns an immutable plan and diagnostic segments.
- P1, P2 and P3 may instead return `ledgr_fold_stop_result`: status, reason
  code, affected IDs and exposure, ordered diagnostic segments and the
  processed-count effect. E alone applies it in the order count, flush,
  break.

## Dense and availability differences retained

The RED one-execution-mode probe remains evidence, not a unification mandate.
Availability alone has changing membership, valuation/freeze state,
settlement stops, target restrictions, affordability stops, structured
diagnostics and equity facts. Dense planning alone uses next-bar timing and
emits the final-bar warning. Fill stamping also differs: the availability
plan carries declared execution observations, while dense fills derive the
next bar. These differences stay in their current branches through WS38.

## Authority and detector boundary

Cut 15 decision (11)'s eight phases are superseded by E plus P1-P5. Decision
(7)'s pure-refactor rule remains binding except for the live return named in
Section 5.5 and owned by LDG-3054. The structural detector must reject:

1. a data-frame carrier slot, stage argument or directly constructed returned value;
2. a second or copied mutable aggregate;
3. public `ctx` retaining the carrier;
4. a carrier-slot write outside its declared owner, including an E write that
   is not stop application;
5. a service mutator called from an undeclared stage; and
6. a stage body duplicated inline after extraction;
7. an omitted, duplicated or reordered stage call; and
8. element-wise mutation of the environment-held positions vector.

The detector is structural support for the byte oracle. It cannot replace the
repaired full-family ladder, callback-context parity or fault injection.
