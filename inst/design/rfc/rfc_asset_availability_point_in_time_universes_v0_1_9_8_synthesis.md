# RFC Synthesis: Asset Availability And Point-In-Time Universes

**Status:** Accepted by the maintainer on 2026-09-08 after Codex final review
and three in-place final-review patch sets. Binding for the first
asset-availability implementation until superseded by a spec packet, contract,
ADR, or architecture note.
**Date:** 2026-09-08
**Author:** Claude (synthesis), under `../rfc_cycle.md` role rotation: Codex
wrote Seed v1 and the accepted Seed v2, Claude wrote the response, Codex
performs final review.
**Accepted input:**
`rfc_asset_availability_point_in_time_universes_v0_1_9_8_seed_v2.md`
(maintainer accepted 2026-09-08).
**Historical inputs:** Seed v1, the response, the response-review addendum,
and the spike charter beside this file.
**Spike evidence (disposable branch, never merged):** at `d59259f` on
`spike/asset-availability-pit-universes`:
`dev/spikes/asset_availability_pit/evidence/stage5_terminal_report.md`,
`dev/spikes/asset_availability_pit/initial_policy_config.md` (policy v4), and
`dev/spikes/asset_availability_pit/evidence/stage4_change_inventory.md`.
**Research inputs (non-binding):** `../research/Sharadar-Empirical-Evidence.md`,
`../research/ledgr_ragged_universe_prior_art_review.md`,
`../research/rfc-evidence-handoff.md`,
`../research/Cross-Asset-Accounting-Critical-Events.md`.

This RFC uses "v1" as shorthand for the first implementation of asset
availability and point-in-time universes; ledgr's roadmap does not have an
asset-availability v1 milestone, and "v1" never means ledgr 1.0.0. Post-v1
work lives in named follow-up RFCs at their own roadmap windows.

This synthesis authorizes no spec packet, ticket, package API, schema,
runtime, accounting, or migration by itself. Those follow the acceptance and
the gates in Section 14.

---

## 1. Decision Summary

Accepted direction for the first implementation:

```text
sealed source facts (bars + declared fact families)
   -> one provider interface (facts as of a cutoff, decision view,
      execution view, bounded history, identity)
   -> one shared fold core (targets, risk, affordability, fills,
      FIFO accounting, valuation, metrics, evidence)
   -> typed, reason-coded evidence that a reopened run reproduces
```

What this synthesis binds:

- a logical fact contract with independent identity, membership,
  observation, valuation, execution, trading-status, and feature planes;
- effective time versus knowledge time, with the bar-timestamp convention
  for observations and evidenced or assumed knowledge time for the other
  families;
- one activation rule, "availability policy active", defined once in
  Section 3, with per-family gates and canonical omission for dense mode;
- one fold core, one full-target strategy contract, and a public axis of
  current members union non-zero holdings with deterministic ordering;
- policy v4 promoted to the first implementation: held former members,
  literal zero, no automatic liquidation, no hidden retry, bounded
  affordability, post-risk admissibility, stale marks that never price fills,
  ordered no-fill reasons, valuation exhaustion, incomplete-evidence
  disclosure;
- strict expected-session feature gaps with recovery only after a complete
  window, and parity across scalar, precomputed, and cached paths;
- the identity layering, cache invalidation, persistence, and explainability
  surfaces the journey needs;
- public and internal names for the first implementation;
- mechanical gates that a spec packet must satisfy before tickets, with a
  disposition for every approved witness.

What this synthesis does not bind: physical storage encoding, whether dynamic
active matrices remain a distinct alternative, schema and table versions,
diagnostic retention tiers, scale optimization, and any representation
performance claim. Section 15 lists them as spec-cut questions.

Evidence honesty. The spike closed inconclusive. Ten of the 31 approved policy
witnesses executed through one shared fork behind three physical
representations; all three passed the same 415 checked fields per
representation. Twenty-one witnesses, the empirical-shape workload, user
journeys, and retention-cost comparison never ran. No timing, memory, or
representation ranking exists. Sparse effective-dated source facts plus
bounded fold-local views remain the architectural prior because they separate
evidence from computation and because the prior-art review supports the
separation (`ledgr_ragged_universe_prior_art_review.md`, "Supported strongly
by prior art" items 2 through 5 and "Plausible" item 2). That is a judgment.
It is not a measured selection, and nothing below depends on it.

---

## 2. Reconciliation With Current Code And Contracts

Seed v2 states intent at the contract level. The table records where the
current package disagrees, so that the spec packet changes the right
touchpoints instead of discovering them. Line numbers are as of `e2a7a05`.

| Seed v2 statement | Current code or contract | Disposition |
| --- | --- | --- |
| Public axis is members union held, pulse-dependent | `ledgr_execution_spec()` fixes `instrument_ids` once (`R/execution-spec.R:45-57`); the fold sets `ctx$universe = instrument_ids` every pulse (`R/fold-engine.R:162, 327`) | Binding change: the execution object carries the bounded superset; the pulse context receives the pulse axis (Section 5) |
| Empty axis still invokes the strategy | `ledgr_validate_strategy_targets()` rejects an empty universe (`R/strategy-contracts.R:36`); `ledgr_signal_strategy()` requires a non-empty universe (`R/signal-strategy.R:56`) | Binding change in active mode only (Section 6.6); dense mode keeps the non-empty rule |
| Opening state, `ledgr_lot_state_asof()`, initial positions use the axis | `ledgr_experiment_validate_opening()` rejects positions outside `universe` (`R/experiment.R:502-507`), repeated at `R/config-validate.R:99-103`; the runner builds `initial_positions` over `instrument_ids` (`R/backtest-runner.R:1041-1046`); walk-forward carry calls `ledgr_lot_state_asof(..., exp$universe, ...)` with the static universe (`R/walk-forward.R:852`) | Binding change: validate against the opening-pulse axis (members plus carried holdings), Section 5.4 |
| Risk receives an accepted valuation mark separate from the close | `ledgr_apply_risk_step_max_weight()` reads `ctx$vec$close` and `ctx$equity` (`R/risk-model.R:416-446`); the fold values positions from the current close (`R/fold-engine.R:300-309`); `ledgr_state_asof()` yields `NA` equity for a held ID without a bar (`R/backtest-runner.R:1810-1817`) | Binding change: a valuation plane feeds risk and valuation in active mode (Section 7.3); dense mode unchanged |
| Dropped fill proposals require typed diagnostics | `if (!is.finite(fill$fill_price) \|\| fill$fill_price <= 0) next` drops silently (`R/fold-engine.R:115-117`); only the final-bar branch warns (`111-114`) | Binding change: reason-coded diagnostic in active mode; the spec must prove the branch unreachable in dense mode or diagnose it there too |
| `ledgr_target_rebalance()` fails typed on unavailable sizing data when active | Today warns and targets zero (`R/strategy-helpers.R:253-258`) | Binding change gated on activation (Section 6.5); dense retains warn-and-zero |
| Affordability at the existing seam | `ledgr_fold_apply_net_feasibility_noop()` is a no-op (`R/fold-engine.R:150-153`, called at `447`) | Binding change: policy v4 bounded affordability replaces the no-op in active mode |
| Execution re-evaluates status, price, and affordability | The fold executes the decided targets against the next bar; the axis cannot change between decision and execution today because it is fixed | Binding decision (Section 7.2): membership is frozen at decision time; a removal knowable before execution is flagged, not blocked; lifetime `known_inactive` effective at execution blocks through the status gate |
| Adding fact families versions the snapshot-hash rule; legacy hashes preserved | `ledgr_snapshot_hash()` hashes instrument rows (`symbol`, `currency`, `asset_class`, `multiplier`, `tick_size`, `meta_json`) and bar rows only (`R/snapshots-hash.R:142-186`); Snapshot Contract says metadata never alters hashes | Binding change: declared fact tables enter the hash under rule version 2; a snapshot without fact tables hashes exactly as today (Section 9.1); `contracts.md` Snapshot Contract wording is amended at spec time |
| Invalid observations are retained for audit and classified | Sealing validates OHLC consistency before writing a hash (Snapshot Contract); `snapshot_bars` declares `open`, `high`, `low`, `close` `NOT NULL` (`R/db-schema-create.R:259-268`); an invalid bar fails sealing and is never stored | Binding decision (Section 4.4): sealing stays strict; invalid rows never enter `snapshot_bars`; they are retained in a hashed quarantine surface that is never a runtime input; `instrument_not_yet_knowable` and `observed_row_outside_expectation` classify valid stored bars at a cutoff |
| Identity: universe rule and valuation policy bind descendants | `ledgr_walk_forward_candidate_key()` takes params, feature params, strategy, feature set, alias map, metric context, cost model, risk chain, and execution seed only (`R/walk-forward-identity.R:56-75`); `ledgr_walk_forward_session_id()` takes `snapshot_hash` and `experiment_hash` among its inputs (`R/walk-forward-identity.R:220-240`), the latter computed from the base config (`R/walk-forward.R:212`) | Binding decision (Section 9.1): fact families enter `snapshot_hash`; experiment declarations enter experiment and config identity; `candidate_key` remains candidate-recipe identity and gains no field; `session_id` inherits through `snapshot_hash` and `experiment_hash` |
| Instrument-local cache keys also bind availability policies | `ledgr_feature_cache_v2` keys carry snapshot hash, instrument, indicator fingerprint, engine version, range (`R/feature-cache.R:83-135`); engine version fingerprints four engine helpers (`R/feature-cache.R:3-30`) | Binding change: the gap policy and admissible-history identity enter the feature fingerprint only when active; the engine version bumps with the engine change (Section 9.2) |
| Membership filtering covers inspection views, telemetry, errors, worker diagnostics | Sweep builds the runtime projection over `exp$universe` (`R/sweep.R:223-241`) and ships the experiment payload to workers (`R/sweep.R:961-975`); `ledgr_pulse_wide()`, `ledgr_pulse_features()`, `ledgr_feature_contracts()` exist (`R/feature-inspection.R:28, 266, 462`) | Binding change: workers receive the bounded superset but every public view, error message, and telemetry count is filtered to the pulse axis (Section 5.5) |
| Persist execution/no-fill and stop evidence | `ledger_events.event_type` is `FILL`, `FEE`, or `CASHFLOW` (`R/db-schema-create.R:194-207`); no diagnostic table exists; `run_telemetry` is compact | Binding change: one durable diagnostics table (logical shape in Section 9.3; physical shape and schema version are spec-cut) |
| Explanation without internal joins | `tibble::as_tibble(bt, what = ...)` supports the closed set `equity`, `returns`, `fills`, `trades`, `ledger`; `ledgr_results()` must delegate to it and must not duplicate reconstruction (Result Contract) | Binding change: the closed set gains `diagnostics` and `availability` on `tibble::as_tibble()`; `ledgr_results()` keeps delegating (Section 9.4) |
| `ctx$members` and availability fields are a Context Contract change | Context Contract binds `ctx$vec` fields `id`, `open`, `high`, `low`, `close`, `volume`, `positions`, `feature` | Contract edit at spec time; dense strategies that ignore the new fields remain valid |
| Strategy output is one full named numeric vector over `ctx$universe` | Strategy Contract: full named numeric vector, `ledgr_target`, or a list containing `targets`; names must match `ctx$universe` exactly | No change to the rule; the domain becomes pulse-dependent |
| Public names are family-first | Public Naming Contract | All names in Section 10 follow it |

No current contract is silently overridden. Each row above becomes a named
edit in the spec packet's `contracts.md` touchpoint list.

---

## 3. Activation: "Availability Policy Active"

This section is the single definition. Every other section refers to it.

A run is **availability-aware** when either condition holds:

1. the sealed snapshot declares at least one availability fact family:
   `membership`, `sessions`, `trading_status`, or `lifetime`; or
2. the experiment declares a `valuation_policy`.

Otherwise the run is **dense** and behaves exactly as today. Dense is the
absence of every availability declaration. There is no mode field, no
default-valued flag, and no string that names dense mode in any canonical
payload. Canonical omission is the identity of dense mode, so every existing
snapshot, experiment, run, sweep, candidate, and walk-forward payload stays
byte-identical under the qualification in Section 9.1.

Activation is declared, never inferred. Equality of members and universe, a
character-vector universe, or the absence of missing bars never selects a
mode.

Universe selection and fact consumption are orthogonal. A snapshot may
declare several membership universes under distinct `universe_id` values. A
membership family is consumed only when the experiment selects one with
`ledgr_universe_members(universe_id)`. A character-vector universe is a fixed
basket: it stays fixed every pulse whether or not the snapshot carries
membership facts, and it still consumes `sessions`, `trading_status`, and
`lifetime` facts (Seed v2 Section 4, addendum R4). Declaring a membership
family therefore activates availability-aware behavior without changing the
basket of a character-vector experiment.

Per-family gates stay distinct:

| Family declared | Effect when declared | Effect when omitted |
| --- | --- | --- |
| `membership` | available for selection by `ledgr_universe_members(universe_id)`; when selected, `ctx$members` is the knowable point-in-time membership at each decision pulse and the axis is members union holdings; a fixed basket ignores it | `ledgr_universe_members()` fails closed; a fixed basket is the only universe shape |
| `sessions` | the declared venue calendar creates the pulse axis; expected sessions drive feature windows and venue open sessions drive stale age; observed rows never add pulses | pulses are the distinct bar timestamps, today's convention; every bar timestamp is an expected session |
| `trading_status` | status is resolved at decision and execution time from knowable facts; missing per-ID status is `status_unknown`, a typed no-fill; conflict is `status_unknown_or_conflicting` | status checks are disabled; an accepted execution bar retains dense eligibility; the effective plan discloses "status checks: not declared" |
| `lifetime` | `unknown` restricts nothing and removes no expected session; `known_inactive` effective at a pulse restricts targets at decision, blocks fills at execution, and removes its sessions from feature and classification expectation while the valuation clock keeps counting venue open sessions; an accepted terminal assertion on a held ID stops with `terminal_settlement_unsupported`, otherwise a held `known_inactive` position exhausts its stale horizon and stops with `valuation_horizon_exhausted` | lifetime is `unknown` everywhere, restricts nothing, and the full venue calendar is expected |
| `valuation_policy` (experiment) | held IDs without an accepted current close carry a permitted stale mark up to the declared horizon, then exhaust | required whenever a fact family is declared (Section 7.3); irrelevant in dense mode |

Availability-aware behavior that does not depend on a specific family is
active whenever the run is availability-aware: the bounded affordability rule
(Section 7.1), post-risk admissibility (Section 6.4), strict feature gaps
(Section 8), the typed sizing failure (Section 6.5), reason-coded fill drops,
the empty-axis rule (Section 6.6), and the diagnostics table (Section 9.3).

The effective plan (`ledgr_experiment_plan()`, Section 10.4) prints which
families are declared, which universe the experiment selected, which
policies are declared, and which checks are therefore disabled. Identity
follows the layering in Section 9.1: declared fact families, including any
recorded knowledge assumption, enter `snapshot_hash`; the experiment's
universe rule and valuation policy enter experiment and config identity, by
presence only. v1 has no experiment-level knowledge override; if a later RFC
adds one, that override alone would enter experiment identity.

---

## 4. Logical Fact Contract

### 4.1 Fact families and columns

Two envelopes. Instrument-scoped facts carry `instrument_id` (stable),
`effective_from`, `effective_to` (`NA` for open), `knowledge_time`,
`provenance`, and an optional `revision_id`. Venue-scoped facts carry
`venue_id`, `effective_from`, `effective_to`, `knowledge_time`,
`provenance`, and an optional `revision_id`, and are never duplicated per
instrument. Families for the first implementation:

| Family | Scope | Assertion columns | Notes |
| --- | --- | --- | --- |
| `membership` | instrument | `universe_id`, `member` (logical) | intervals or dated complete snapshots (Section 4.3); several `universe_id` values may coexist |
| `trading_status` | instrument | `status` (`active`, `halted`, `quotation_only`), `source`, `precedence` | resolved by effective interval, source precedence, supersession |
| `lifetime` | instrument | `assertion` (`known_active`, `known_inactive`, `unknown`), `terminal_event` (optional label) | vendor labels stay labels; no accounting event is derived |
| `sessions` | venue | `session_open`, `session_close`, `status` (`open`, `closed`) | one venue calendar per snapshot in v1 (Section 12) |

Venue-to-instrument applicability in v1: the snapshot's single venue
calendar applies to every instrument. Two session sets are derived from it.
Venue open sessions are every declared session with status `open`; declared
closures are never in either set. An instrument's expected sessions, which
drive feature windows and observation classification, are the venue open
sessions minus those inside an accepted `known_inactive` lifetime interval
when the `lifetime` family is declared. The valuation clock for a held
position counts venue open sessions regardless of that instrument's lifetime
(Section 7.3), so a held `known_inactive` position keeps aging and cannot be
valued at a stale mark indefinitely. `unknown` lifetime leaves both sets
equal to the venue open sessions.

Aliases and per-observation revision facts are not v1 families. Stable
`instrument_id` is the identity; a corrected vendor dataset is a new snapshot
(prior-art invariant 9). Both are spec-cut candidates in Section 15.

Observations are the existing `snapshot_bars` rows. They are immutable,
never forward-filled, and never synthesized.

### 4.2 Effective time versus knowledge time

Causal use of a fact at decision pulse `t` requires the fact to be effective
at `t` and knowable by `t`.

- Observations keep the established convention: a bar's `ts_utc` is also its
  knowledge time when no separate availability field is declared. Legacy
  payloads carry no such field, so nothing about dense snapshots changes.
- `membership`, `lifetime`, `trading_status`, and `sessions` facts require
  evidenced `knowledge_time`, or the constructor argument
  `knowledge = "assume_effective"`, which records the identity-bearing
  assumption `knowledge_assumption = "effective"` in that family's hashed
  metadata. Effective time never substitutes for knowledge time silently.
- A family constructed under an assumption makes the run assumption-backed.
  `summary()`, `ledgr_experiment_plan()`, and the survivorship article label
  such results as assumption-backed, not as evidenced point-in-time research.
- A fact with neither evidenced knowledge time nor a recorded assumption is
  audit-only: it appears in the validation report and in retrospective
  views, and it never enters a decision view.

### 4.3 Complete snapshots versus partial updates

`membership` input declares its completeness. A dated complete snapshot lists
every member as of its effective time; omission means `member = FALSE` for
that effective state, visible only from the snapshot's knowledge time. A
partial update or an interval table asserts only the rows it contains;
omission means `unknown`. Unknown membership excludes an ID from
`ctx$members` and establishes nothing else: a held ID with unknown membership
stays on the axis as a held non-member, and an accepted observation for it
still values it.

### 4.4 Validity, quarantine, and cutoff classification

Two different things are kept apart.

Seal-time validity is structural. Sealing keeps today's strict rule: a bar
that fails OHLC or referential validation is `observation_invalid`, never
enters `snapshot_bars`, and cannot be a runtime input. The pre-seal report
lists it, and the snapshot retains it in a quarantine surface, one row per
rejected observation with reason and provenance, hashed with the snapshot as
its own family so that audit is reproducible. The quarantine surface is never
read by any decision view, feature, or fill path.

Cutoff-time classification is temporal and applies only to valid stored bars.
At a decision cutoff a valid bar may be `observed_row_outside_expectation` (a
session the calendar does not expect for that instrument) or
`instrument_not_yet_knowable` (an ID not knowable at that cutoff). Such rows
stay stored, are excluded from that cutoff's runtime input, and are visible in
retrospective views. Exclusion is cutoff-specific: a row excluded at one
cutoff may become admissible history later when it is knowable and passes
every declared rule, and no later admission changes an earlier result. The
declared set of calendars is part of run identity and is never derived from
the IDs present in a frame.

`unknown` is stored as `unknown`. Consumers act conservatively per predicate;
an independent plane may still establish held or observed state.

---

## 5. Provider Interface, Axis, And Ordering

### 5.1 Provider operations

One internal interface, representation-neutral, with exactly the operations
the spike exercised:

```text
facts(cutoff)               resolved fact rows knowable by the cutoff
decision_view(t, held_ids)  axis + member/held/restricted/priced/mark planes
execution_view(t_exec, ids) accepted execution price and resolved status
history(id, field, through) bounded admissible observation history
identity()                  dependent fact and policy identity
```

Dense planes, pulse-local frames, and sparse hydration are implementation
techniques behind this interface. A provider owns no policy: targets, risk,
affordability, fills, FIFO accounting, valuation, metrics, and evidence stay
in the one fold core. No second execution engine for sweep, parallel, or
walk-forward paths.

### 5.2 Public axis

At decision pulse `t`:

```text
members(t)  = the fixed basket, or, under ledgr_universe_members(u),
              IDs whose membership in u is member, effective at t,
              knowable by t
held(t)     = IDs with non-zero position entering t
universe(t) = members(t) union held(t)
```

Deterministic order: members first, in the order the universe rule declares;
then held non-members, in stable-ID order (`C`-locale radix). A character
universe declares its own order; `ledgr_universe_members()` orders members by
stable ID. Dense mode therefore yields today's axis and today's event order.

### 5.3 Ordering consequences

- `ctx$positions`, every `ctx$vec` field, and the target vector are aligned
  to `universe(t)`.
- Fill proposals, fills, and ledger events are emitted in axis order
  (policy v4 "original validated target-vector order").
- Affordability is evaluated in stable-ID order over the pulse's proposals,
  a deterministic funding priority that does not reorder events.
- Positional indices are pulse-local. `ctx$idx()` remains valid within a
  pulse; caching an index across pulses is unsupported. Whether stale
  references are detected mechanically is a spec-cut question (W18 did not
  execute).

### 5.4 Fold boundaries and carried state

Opening-state validation, `ledgr_lot_state_asof()`, initial-position
construction, and walk-forward carry (`opening_state_policy =
"carry_test_state"`) validate against the opening pulse's axis, which
includes carried holdings whether or not they are current members. A carried
former member keeps its quantity and FIFO cost basis into the next fold's
first pulse. Asset-scoped strategy state lives in a declared `asset_state`
element keyed by stable ID; the fold removes an entry when its ID is neither
a member nor held; portfolio-level state is preserved unchanged. Re-entry
initializes new asset state while source and feature history stay keyed to
the stable ID.

### 5.5 Leak surfaces

Workers and the precompute projection may hold the bounded superset. Every
public view is filtered to the pulse axis: `ctx$members`, `ctx$universe`,
`ctx$vec`, `ledgr_pulse_wide()`, `ledgr_pulse_features()`,
`ledgr_feature_contracts()`, error-message instrument lists, telemetry
counts, and worker diagnostics. A future member is not visible through any
supported interface before it is knowable and effective. The threat model
covers supported ledgr interfaces, not arbitrary user R code, globals,
process inspection, or wall-clock behavior.

---

## 6. Strategy Context And Target Contract

### 6.1 Context additions

The strategy remains `function(ctx, params)` returning one full named numeric
target vector over `ctx$universe`. Additions, all read-only, all decision
time, all aligned to `ctx$universe`:

| Field | Type | Meaning at this pulse |
| --- | --- | --- |
| `ctx$members` | character | point-in-time investment cross-section |
| `ctx$vec$member` | logical | in `ctx$members` |
| `ctx$vec$held` | logical | non-zero position entering the pulse |
| `ctx$vec$target_restricted` | logical | a declared fact restricts trading as of this pulse: `trading_status` resolved to `halted`, `quotation_only`, `status_unknown`, or `status_unknown_or_conflicting` when that family is declared, or `lifetime` resolved to `known_inactive` when that family is declared; `FALSE` for every ID when neither family is declared |
| `ctx$vec$target_restriction_reason` | character | the first applicable reason behind `target_restricted` in the fixed order status resolution (`trading_halted`, `quotation_only`, `status_unknown`, `status_unknown_or_conflicting`; at most one applies because status resolves to one value) then `lifetime_inactive`; `""` when not restricted. The full ordered set, joined with `|`, is `target_restriction_reasons` on the `availability` view and the `reasons` column of the diagnostics rows, mirroring the execution convention of a first reason on the fill row and every reason in `no_fill_reasons` |
| `ctx$vec$admissible` | logical | `member & !target_restricted`: may receive new or increased exposure |
| `ctx$vec$priced` | logical | an accepted current close or a permitted stale mark exists |
| `ctx$vec$mark_age` | integer | venue open sessions since the mark's observation; `0` when fresh; `NA` when `!priced` |
| `ctx$vec$close` | double | accepted current close; `NA` when no accepted observation exists at this pulse, even if a stale mark values the holding |

Non-membership is not a restriction. It is `!ctx$vec$member`, and by itself
it prohibits new or increased exposure and sign reversal (Section 6.3).
Restriction arises only from declared status or lifetime evidence, and its
reason code is on `ctx$vec$target_restriction_reason`; diagnostics and
`ledgr_run_explain()` repeat it. The two planes are independent: a held non-member may
be unrestricted, and a current member may be restricted.

In dense mode `ctx$members` equals `ctx$universe`, `member` and `admissible`
are all `TRUE`, `held` reflects positions, `target_restricted` is all
`FALSE`, `target_restriction_reason` is all `""`, `priced` is all `TRUE`,
`mark_age` is all `0`, and `close` is unchanged. Existing dense strategies
remain valid without reading any new field.

### 6.2 Constructors and literal targets

- `ctx$flat()` initializes members to `default` and held non-members to their
  current quantity. `ctx$hold()` initializes every axis ID to its current
  quantity. Both remain thin.
- Zero always means desired quantity zero, for every ID and state.
  Liquidating a held non-member is the literal assignment
  `targets["A01"] <- 0`. No helper is added for it; a wrapper that carried
  intent would violate the Strategy Contract, and assignment sugar adds no
  state.
- Membership removal never creates an automatic liquidation target.
- A raw full named numeric vector remains valid strategy output. A hand-built
  zero vector is literal and requests an exit of every held non-member.

### 6.3 Admissible targets at strategy output

| Member | Restricted | Admissible strategy targets |
| --- | --- | --- |
| yes | no | any finite quantity |
| no (held) | no | current quantity, zero, or a same-sign quantity with smaller magnitude |
| yes | yes | current quantity or zero; zero alone when not held |
| no (held) | yes | current quantity or zero |
| not on the axis | any | naming it is an extra-target error |

A non-member increase or sign reversal fails with
`ledgr_nonmember_exposure_increase`; a restricted violation fails with
`ledgr_restricted_target`. Both are `ledgr_invalid_strategy_result`
subclasses and both carry the reason code from the plane that produced them.

### 6.4 Post-risk admissibility

After the risk chain, the validator accepts a target that is zero or that has
the same sign as the admissible strategy target with magnitude no greater
than it, including an unchanged target. Both shipped steps satisfy this by
construction (`long_only` maps negatives to zero; `max_weight` only reduces).
A step that could increase magnitude or reverse sign on a restricted or
non-member ID is rejected as `ledgr_post_risk_inadmissible` until it receives
the decision-time state plane. The short case in policy v4 is an algebraic
closure rule, not short-accounting authorization.

### 6.5 Helper pipeline

`ledgr_signal_return()`, `ledgr_select_top_n()`, `ledgr_weight_equal()`, and
`ledgr_target_rebalance()` keep their names and composition contract.

- Signals, selections, and weights operate on `ctx$members`.
- `ledgr_select_top_n()` continues to ignore missing signals and, when
  active, excludes IDs with `!ctx$vec$admissible`, so a halted member with a
  usable feature is never selected into a target the validator would reject
  (addendum R5).
- `ledgr_target_rebalance()` initializes held non-members to their current
  quantity, reserves their marked absolute exposure, and sizes member weights
  from residual marked NAV. When active, a selected ID without a positive
  accepted current close fails with `ledgr_target_sizing_unavailable`;
  unavailable data never becomes a zero target on that path. In dense mode
  the helper keeps today's warn-and-zero behavior
  (`ledgr_invalid_target_price` warning). Activation is the Section 3 rule,
  never members-equals-universe.
- `ledgr_signal_strategy()` follows the same axis and empty-axis rules.

### 6.6 Empty members and empty axis

Empty members with holdings preserve the holdings: the axis is the held IDs,
constructors hold them, and the strategy runs normally.

An empty axis (no members, no holdings) still invokes the strategy with a
zero-length `ctx$universe`. A named zero-length numeric target is valid
output; validation accepts it in active mode; no target rows, no risk
proposals, and no fills result; cash-only valuation records the pulse with
reason `empty_public_domain`; portfolio-level strategy state is preserved.
This is witness W26 and the W27 pulse-counter rule verbatim. Dense mode keeps
its non-empty universe requirement.

### 6.7 Failed exits and retry

A zero target whose execution opportunity has no eligible price or an
inactive status records a no-fill row and carries nothing. The position
remains held. A later exit requires a fresh zero target. No pending, standing,
or good-till-cancelled order exists anywhere in the design; the words are
reserved for a future OMS RFC.

---

## 7. Budget, Risk, Execution, And Valuation

Policy v4 is promoted verbatim except where a row below refines it.

### 7.1 Bounded affordability

Active only when availability is active; the seam is
`ledgr_fold_apply_net_feasibility_noop()`, which becomes the affordability
step after fill proposals and costs resolve and before any state mutation.

- Reserve the marked absolute exposure of every held non-member before
  sizing member allocations; an intended sale does not release the reserve.
- Only accepted, executable same-pulse sales fund same-pulse purchases;
  rejected or unfilled sales contribute nothing.
- Affordability is evaluated only for proposals with an execution price.
- Evaluate in stable-ID order against a virtual ledger: credit
  cash-generating fills first, then accept each cash-consuming fill in full
  when the resolved delta leaves the virtual balance at or above
  `-cash_tolerance`; otherwise reject that fill alone with
  `insufficient_cash`. Never scale, floor, defer, or reject unrelated fills.
- `cash_tolerance` is `1e-8` in base currency in v1. It is a constant of the
  affordability step, identity-bound through the engine version, not a user
  parameter; parameterizing it is spec-cut.
- Apply and emit accepted fills in axis order. Final recorded cash must
  reconcile to the virtual final balance within the tolerance, else the run
  stops with `affordability_reconciliation_failed`.
- Record intended gross exposure, post-risk exposure, realized cash, and
  actual exposure separately.

This is bounded affordability, not margin, settlement, or an OMS.

### 7.2 Execution gates and execution-time transitions

When the `trading_status` family is declared, the fill layer evaluates, in
this order, and records every applicable reason joined by `|` while the fill
row carries the first: status resolution (`trading_halted`, `quotation_only`,
`status_unknown`, `status_unknown_or_conflicting`, and `lifetime_inactive`
when the `lifetime` family resolves `known_inactive` effective at the
execution time), execution-bar availability (`execution_bar_missing`),
affordability (`insufficient_cash`). Decision-time restriction uses status
knowable at the decision pulse; a restriction knowable but effective later
applies at the execution opportunity. An observed price never asserts active
status. Execution evidence is never on the strategy context.

When the `trading_status` family is omitted, the status gate is absent and
the effective plan says so; a declared `lifetime` family still contributes
`lifetime_inactive`; execution-bar availability and affordability still
apply in active mode.

Membership is frozen at decision time as an eligibility input. The execution
view inspects membership only to emit diagnostics, never as a gate: a target
that was admissible on decision-time information executes if the status,
price, and affordability gates pass, even when a removal became knowable
between the decision and the execution opportunity. Membership is a
decision-axis property, not a trading restriction, and blocking on it would
make membership an execution-eligibility input, which the policy reserves for
the decision.
The fill row then carries the
informational reason `membership_changed_before_execution`, the resulting
position is a held non-member at the next decision, and the reduction-only
rule of Section 6.3 governs it from then on. No automatic liquidation
follows. Gate 13 in Section 14 tests exactly this sequence.

### 7.3 Valuation and risk marks

`valuation_policy = ledgr_valuation_stale(max_sessions)` is required whenever
the run is availability-aware and has no default; a missing policy fails
experiment validation with `ledgr_valuation_policy_required`. The horizon is
explicit, clocked in venue open sessions, and identity-bearing. The
two-session spike fixture is not a default. `max_sessions = 0L` is valid and
means current-mark-only valuation: a held ID without an accepted current
close exhausts at that pulse.

- Fresh valuation uses the accepted current close (`mark_age = 0`).
- A held ID without an accepted current close carries a stale mark from its
  last accepted close for at most `max_sessions` venue open sessions; age
  increments on every venue open session, never on declared closures, and
  independently of the instrument's lifetime state, so a held
  `known_inactive` position ages at the same rate as any other holding.
- A stale mark values the holding and feeds `max_weight` through a valuation
  plane distinct from `ctx$vec$close`. The risk row records the mark source
  and age and the reason `stale_mark_pass_through` or
  `stale_mark_reduction`. A stale mark never becomes an observed close or an
  execution price.
- Consulting the valuation plane does not change `risk_chain_hash`. The
  valuation-policy identity carries the difference into experiment and
  config identity.
- A new positive target on an ID with no permitted mark stops before any
  fill proposal with `risk_mark_unavailable`, recording asset, target, and
  risk step.
- Equity and position value never become `NA` silently; an unvalued holding
  is an explicit `unpriced` state that, beyond the horizon, stops the run.

### 7.4 Exhaustion, terminal events, incomplete evidence

At the first pulse where a held ID has no permissible mark, the run preserves
every earlier event, stops before a new decision, risk pass, or fill
proposal, and records `valuation_horizon_exhausted` with affected exposure,
intended horizon, achieved horizon, last fully valued metric timestamp, and
last executed-event timestamp. When the exhausted ID is `known_inactive`,
the stop row also carries `lifetime_inactive`, so an inactive holding that
never receives a terminal assertion still reaches a typed stop within
`max_sessions` venue open sessions of its last accepted close.

Unknown lifetime is not a stop reason. An accepted terminal assertion on a
held ID stops with `terminal_settlement_unsupported`; no settlement is
fabricated and no vendor label becomes a ledger event. Resolved terminal
economics wait for the accounting-critical-event sibling.

Prefix metrics through the achieved horizon stay visible, marked incomplete,
and excluded from equal-horizon comparison. Sweep and walk-forward selection
show the exclusion beside the selected row rather than dropping the
candidate. Incomplete candidates are never promoted as complete performance.

---

## 8. History, Features, And Gaps

- Admissible history is keyed by stable ID across entry, exit, and
  re-entry. Pre-membership observations may contribute after entry only when
  knowable at the decision cutoff and admitted by the lifetime, calendar,
  revision, classification, and observation rules.
- Windows count expected sessions. A feature requiring `n` observations
  requires the `n` most recent expected sessions for that instrument to carry
  accepted observations. A missing or invalid required observation makes the
  feature `NA` at that pulse; it is never skipped, carried, imputed, or
  replaced by a valuation mark. Availability recovers only after a complete
  required window.
- Scalar `fn`, `series_fn` precomputation, and cached paths must agree
  exactly under strict gaps; this is a gate (Section 14).
- Indicators without a declarable required window, or whose `series_fn`
  carries or imputes internally, are unsupported in active mode and fail with
  `ledgr_indicator_gap_unsupported` at experiment validation, before any
  strategy runs. Dense mode is unaffected because it has no gaps.
- Feature usability stays consumer-specific. The v1 consumer is Boolean
  strategy logic over finite values; native-missingness models and fitted
  imputers are deferred and will name their own clocks and contracts.
- Fitted preprocessing and ML fitting are outside v1. The future contract
  must distinguish retrospective in-sample diagnostics, transforms fit before
  a scored interval, causal rolling or expanding refits, and untouched outer
  evaluation; each inner candidate-selection boundary needs its own fit at
  that boundary's information cutoff; every fitted artifact binds
  availability time, input and revision cutoff, label maturity, estimation
  population, RNG identity, and use boundary; the default population is the
  historically knowable investment membership, with broader causal
  populations as an identity-bearing override.

---

## 9. Identity, Cache, Persistence, And Explainability

### 9.1 Identity layers

| Identity | Binds today | Change in v1 |
| --- | --- | --- |
| `snapshot_hash` | instrument rows and bar rows | declared fact tables, including the quarantine surface and each family's recorded knowledge assumption, enter under hash rule version 2; a snapshot with no fact tables hashes under rule 1 exactly as today; lineage and classification-input digests live in hashed fact rows or the hashed instrument payload, never only in the `snapshots` envelope |
| experiment identity and `config_hash` | the logical execution config after removing store-local and run-local fields | the selected universe rule (`ledgr_universe_members(universe_id)` or the fixed basket), and `valuation_policy` enter by presence; knowledge assumptions do not, because they are source-normalization facts hashed with their family in `snapshot_hash`; dense payloads gain no field; run identity is `snapshot_hash` plus `config_hash` as today |
| `risk_chain_hash` | the risk plan | unchanged; consulting a valuation plane does not touch it |
| feature fingerprint | `fn`, `series_fn`, params, warmup | gap policy and admissible-history identity enter only when active |
| feature-engine version | engine helper fingerprints | bumps with the engine change; the session cache is not persisted, so this costs nothing durable |
| `candidate_key` | params, feature params, strategy, feature set, alias map, metric context, cost model, risk chain, execution seed | unchanged: it remains candidate-recipe identity and gains no availability field; availability is an experiment-level declaration, not a candidate property |
| `session_id` | `snapshot_hash`, `experiment_hash`, param grid, fold list, selection rule, metric context, cost model, risk chain, seed, opening-state policy, ledgr version | unchanged in shape; inherits fact families and knowledge assumptions through `snapshot_hash`, and the universe rule and valuation policy through `experiment_hash`; no new field |

Byte identity is promised only under identical declared identity inputs and
identical package, schema, and feature-engine versions. Versions may change
honestly; when they do, the claim is "approved equivalent", not byte
identity. Adding a future fact changes snapshot and descendant identities and
must not change earlier outputs: causal invariance and byte identity are
different tests, and Section 14 has one gate for each.

### 9.2 Cache invalidation

Existing instrument-local `ledgr_feature_cache_v2` keys stay valid only for
nodes whose inputs are the instrument's own observations plus the admissible
history rule, whose identity is added to the fingerprint when active.
Cross-sectional and fitted nodes need separate key families; none ship in v1.
Changed feature semantics change fingerprints; a ragged run never reads a
dense cache entry because the fingerprint differs.

### 9.3 Persistence

Persisted per run when active: one durable diagnostics table with the
logical row `run_id, ts_utc, instrument_id, stage, outcome, reason_code,
reasons, target, quantity, price, mark_source, mark_age`, covering
strategy-validation rejections, risk reasons and stops, execution no-fills
and informational execution flags, affordability rejections, valuation
stops, and `empty_public_domain` pulses; and the effective plan alongside the
run config. Deterministic availability planes are reconstructed from sealed
facts plus identity-bound policy and are not persisted. The table joins the
Persistence Contract's cross-connection read-back guarantee. Physical table
shape, column types, schema version, and retention tiers are spec-cut.

### 9.4 Explainability surfaces

- `tibble::as_tibble(bt, what = ...)` extends its closed result set with
  `diagnostics` (the diagnostics rows) and `availability` (the reconstructed
  per-pulse, per-axis-ID planes `member`, `held`, `target_restricted`,
  `admissible`, `target_restriction_reason`, `target_restriction_reasons`,
  `priced`, `mark_source`, `mark_age`, `status`).
  `ledgr_results(bt, what = ...)` keeps delegating to `tibble::as_tibble()`
  for both and adds no reconstruction of its own, per the Result Contract.
- `ledgr_run_explain(bt, instrument_id, ts_utc)` returns one tibble joining
  membership or held reason, feature identity, quantity, pre-risk target,
  post-risk target and reason, execution opportunity, fill or no-fill and
  reasons, resulting position, valuation source and age, and completion
  status, with no internal join by the user. It reads the same result path.
- `ledgr_experiment_plan(exp)` prints the effective plan: declared families,
  the selected universe, declared policies, knowledge assumptions, disabled
  checks, and identity inputs.
- A reopened run (`ledgr_run_open()`) reproduces the same diagnostics and the
  same explanation from persisted rows and sealed facts without re-executing
  strategy code.

Retrospective views may show the full axis and later transitions only when
labelled and inaccessible to strategy execution. Episode summaries never
merge separate target attempts or imply persistent orders.

---

## 10. Names And Ingestion Contract

### 10.1 Fact constructors

```r
ledgr_facts_membership_intervals(df, universe_id, knowledge = "evidenced")
ledgr_facts_membership_snapshots(df, universe_id, complete = TRUE,
                                 knowledge = "evidenced")
ledgr_facts_trading_status(df, knowledge = "evidenced")
ledgr_facts_sessions(df, venue_id, knowledge = "evidenced")
ledgr_facts_lifetime(df, knowledge = "evidenced")
ledgr_facts(...)                      # bundle of the above
ledgr_facts_validate(facts, bars_df, instruments_df)   # dry-run report
```

`knowledge = "assume_effective"` records the identity-bearing assumption of
Section 4.2. Constructors normalize vendor columns outside the fold and
never construct internal planes.

### 10.2 Snapshot and experiment

```r
snapshot <- ledgr_snapshot_from_df(bars_df, instruments_df,
                                   db_path = ..., facts = ledgr_facts(...))
exp <- ledgr_experiment(snapshot, strategy,
                        universe = ledgr_universe_members("sp500"),
                        valuation_policy = ledgr_valuation_stale(max_sessions = 2L),
                        ...)
```

`universe` accepts a character vector (fixed basket) or
`ledgr_universe_members(universe_id)` (one of the snapshot's declared
point-in-time memberships). The two are orthogonal to the fact families: a
fixed basket stays fixed every pulse even when the snapshot declares
membership facts, and both universe shapes consume `sessions`,
`trading_status`, and `lifetime` facts when declared. A rule object on a
snapshot without that `universe_id` fails closed; a character vector never
implies dense semantics by itself.

### 10.3 Pre-seal validation and report

`ledgr_facts_validate()` returns a `ledgr_facts_report` whose print lists
accepted, rejected, quarantined, and unresolved facts with reasons: unknown
IDs, overlapping intervals, contradictions, malformed intervals, membership
completeness, knowledge-time treatment, and observation validity. Sealing
refuses unresolved contradictions; a user never fabricates evidence to
complete a table.

### 10.4 The connected journey

The acceptance journey that a provider-shaped, redistributable fixture must
support end to end:

1. build facts from bars, stable IDs, and a dated membership table with
   evidenced knowledge time or a disclosed assumption;
2. `ledgr_facts_validate()` and inspect every rejected, contradictory, or
   unresolved fact;
3. `ledgr_snapshot_from_df(..., facts = )` and seal;
4. `ledgr_experiment()` with `ledgr_universe_members()` and a declared
   valuation policy; `ledgr_experiment_plan()` shows declared families,
   the selected universe, policies, and disabled checks;
5. `ledgr_run()` an ordinary helper strategy unchanged from a dense example;
6. `ledgr_run_explain()` for a retained former member shows the held reason,
   unchanged position, and valuation age; for a blocked fill it shows the
   target, the ordered blockers, the unchanged position, and completion
   status;
7. `ledgr_run_open()` and repeat step 6 with identical output.

The example never constructs an availability plane by hand.

---

## 11. Dense-Mode Compatibility

With no fact family and no valuation policy declared, and under identical
package, schema, and engine versions:

- snapshot hashes, `config_hash`, `feature_set_hash`, `alias_map_hash`,
  `risk_chain_hash`, `candidate_key`, and `session_id` are byte-identical;
- the pulse axis, targets, fills, events, equity, and metrics are
  byte-identical, including event order;
- `ctx$universe` equals the declared universe every pulse and the new
  context fields carry their dense constants;
- the strategy validator still requires a non-empty universe;
- `ledgr_target_rebalance()` still warns and targets zero on a non-positive
  close;
- the silent fill-drop and `NA`-equity branches remain as they are, and the
  spec must prove them unreachable in dense mode or diagnose them.

No existing snapshot is migrated or re-hashed. No `dense_static` string
appears in any payload.

---

## 12. First Implementation Scope And Non-Scope

In scope for the first specification:

- one end-of-day venue calendar per snapshot, applying to every instrument;
- stable instrument identity;
- point-in-time membership with complete snapshots or partial updates, and
  fixed baskets that consume the other families;
- optional `trading_status` and `lifetime` families;
- held-former-member continuity across pulses and folds;
- bounded stale valuation with a required declared horizon;
- reason-coded no-fill, rejection, and stop diagnostics;
- direct, reopened, sweep, parallel, and walk-forward parity.

Explicit non-scope:

- a second execution engine of any kind;
- general imputation, forward-filling, or seal-time repair of observations;
- fitted preprocessing and the ML lifecycle;
- multi-venue or subdaily scheduling and cross-venue pulse unions;
- OMS behavior: persistent, standing, or good-till-cancelled orders and
  partial fills;
- margin, settlement, and financing models beyond bounded affordability;
- corporate-action and terminal-event accounting, dividends, and general
  short accounting;
- sparse-fact or representation optimization and any scale optimization;
- any representation-performance, timing, or memory claim;
- live-feed bad-data recovery and broad provider adapters.

---

## 13. Teaching

The method belongs in one broader survivorship-bias article that teaches
current-constituent bias, complete-case bias, the point-in-time workflow, and
its limits. It states that ledgr prevents named leakage paths and does not
eliminate survivorship bias without trustworthy membership, identity,
terminal-event, corporate-action, and revision evidence. It labels
assumption-backed runs. Its code executes under the vignette style guide,
which also governs teaching media.

---

## 14. Acceptance Gates Before A Spec Packet

### 14.1 Gates

Each gate is a mechanical test the spec packet names before tickets are cut.

1. Version-qualified dense byte identity: a dense fixture reproduces today's
   hashes, axis, events, and metrics across run, sweep, and walk-forward.
2. No leakage: adding a future membership, status, lifetime, or feature fact
   changes no earlier output through any supported interface, including
   inspection views, error messages, telemetry, and worker diagnostics.
   Alias and revision perturbations join this gate only if those families
   are scoped (Section 15).
3. Strict-gap parity: scalar `fn`, `series_fn` precomputation, and cached
   paths agree exactly on gapped fixtures; unsupported indicators fail typed.
4. The same strategy runs unchanged in dense and point-in-time modes.
5. Former-member retention: a removed member stays held without a
   liquidation target until an explicit zero.
6. Empty domain: W26 invocation with a zero-length target and W27
   portfolio-state preservation.
7. Stale valuation without stale execution: a stale mark values and reduces
   risk while the fill uses the accepted execution price only; the risk row
   carries source, age, and reason; `risk_chain_hash` is unchanged; a new
   positive target on an ID with no permitted mark stops with
   `risk_mark_unavailable` before any fill proposal.
8. No hidden order: a blocked exit followed by a hold does not exit later; a
   reissued zero is a new, visible attempt.
9. Incomplete evidence stays visible and selection-ineligible in sweep and
   walk-forward tables.
10. Earlier-output invariance under future-fact perturbation while snapshot
    and descendant identities change.
11. Direct, reopened, sweep, parallel, and walk-forward parity on the
    availability-aware fixture, including carried former members.
12. The Section 10.4 journey: ingest, seal, run an ordinary strategy, explain
    a retained holding and a blocked fill, reopen, recover the same
    explanation.
13. Execution-time membership freeze: a purchase decided while the ID was a
    member executes after a removal becomes knowable, carries
    `membership_changed_before_execution`, and the ID is a reduction-only
    held non-member at the next decision.
14. Membership completeness: a complete snapshot makes omission
    nonmembership from its knowledge time; a partial update leaves omission
    unknown; a held ID with unknown membership stays a held non-member.
15. Knowledge assumptions: a family built with `assume_effective` is
    identity-bearing and labelled assumption-backed; a fact with neither
    evidenced knowledge time nor an assumption is audit-only and reaches no
    decision view.
16. Status family gate: with `trading_status` omitted, an accepted execution
    bar fills and the effective plan discloses the disabled check; with it
    declared, a missing per-ID status is `status_unknown` and a conflict is
    `status_unknown_or_conflicting`, both typed no-fills.
17. Target and post-risk closure: restricted IDs admit only current quantity
    or zero; non-member increases and sign reversals fail typed; post-risk
    accepts zero or same-sign no-larger targets and rejects anything else
    typed.
18. Affordability ordering and reconciliation: a held former member's marked
    exposure is reserved before member sizing; an unfilled or rejected sale
    funds nothing; an accepted same-pulse sale may fund a purchase; a
    credited sale that disappears invalidates pulse completion; stable-ID
    feasibility order, axis event order, per-fill `insufficient_cash`, and
    `affordability_reconciliation_failed` on mismatch beyond `1e-8`.
19. Valuation exhaustion: at the `max_sessions + 1`th venue open session
    without an accepted close the run stops with `valuation_horizon_exhausted`
    and the five recorded fields; declared closures do not age; the clock
    ignores lifetime; `max_sessions = 0L` exhausts at the first such session.
20. Helper behavior by mode: in active mode `ledgr_select_top_n()` excludes
    non-admissible IDs and `ledgr_target_rebalance()` fails
    `ledgr_target_sizing_unavailable` on a missing or non-positive close; in
    dense mode both keep today's behavior.
21. Lifetime family gate: with `lifetime` omitted or `unknown`, nothing is
    restricted and every declared open session is expected; with
    `known_inactive` effective, targets are restricted at decision, fills
    are blocked at execution with `lifetime_inactive`, those sessions leave
    the feature and classification expected set, and a held `known_inactive`
    position with no terminal assertion still ages on venue open sessions
    and stops with `valuation_horizon_exhausted` carrying
    `lifetime_inactive` after `max_sessions`.
22. Terminal assertion: an accepted terminal assertion on a held ID stops
    the run with `terminal_settlement_unsupported` before any settlement,
    fabricates no cash or position change, and marks the prefix incomplete.
23. Stable-ID continuity: admissible history and feature windows follow the
    stable ID across exit and re-entry; the `asset_state` entry is removed
    when the ID is neither member nor held and re-initialized on re-entry;
    portfolio-level state is preserved across membership changes; a
    positional index cached across pulses is not honored.

### 14.2 Disposition of the approved witnesses

Every witness in the frozen registry maps to a gate above, a deferral, or a
named superseding test. "Superseded" means the semantics are tested by the
named gate on the implementation rather than by the spike's prototype form.

| Witness | Disposition |
| --- | --- |
| W01 retained holding and full member allocation | required: gates 5, 18 (reserve) |
| W02 failed sale and replacement purchase | required: gate 18 (unfilled sale funds nothing) |
| W03 one exit target followed by a no-fill | required: gate 8 |
| W04 reissued exit target | required: gate 8 |
| W05 unknown lifetime with a valid observation | required: gate 21 |
| W06 valuation horizon exhausted | required: gate 19 |
| W07 accepted terminal event without settlement support | required: gate 22 |
| W08 halted member with a usable feature | required: gates 17, 20 |
| W09 quotation-only and resumption states | required: gate 16 |
| W10 fixed basket with an isolated gap | required: gates 3, 14 (fixed basket consuming sessions) |
| W11 dynamic membership with complete observations | required: gate 14 |
| W12 historically knowable broader estimation population | deferred: fitted preprocessing (Section 8) |
| W13 future-selected estimation population | deferred: fitted preprocessing |
| W14 full-train fit in an early training replay | deferred: fitted preprocessing |
| W15 delayed label and later revision | deferred: fitted preprocessing |
| W16 effective-dated revision | conditional: required under gate 2 if revision facts are scoped, else deferred |
| W17 future-fact perturbation | required: gate 10 |
| W18 cached positional state across membership change | partial: pulse-local indices bound (Section 5.3); mechanical detection is spec-cut |
| W19 incomplete candidate in selection | required: gate 9 |
| W20 prototype reconstruction, cache, and parallel parity | superseded by gate 11 on the implementation; cold and warm cache paths are not required |
| W21 dense reconstruction parity | superseded by gate 1 |
| W22 unpriced holding through max-weight risk | required: gate 7 |
| W23 post-risk closure on restricted holdings | required: gate 17; the short case remains algebraic only |
| W24 held state across a fold boundary | required: gate 11 |
| W25 transform graph and cache invalidation | partial: fingerprint invalidation under gate 3 and Section 9.2; fitted identity deferred |
| W26 empty public domain and first entry | required: gate 6 |
| W27 history across exit and re-entry | required: gate 23 |
| W28 calendar and age semantics | required: gate 19 (closures do not age) |
| W29 stable asset and alias continuity | conditional: required under gate 2 if alias facts are scoped, else deferred |
| W30 consumer-specific missingness | deferred: native-missingness consumers (Section 8) |
| W31 combined lifecycle and exposure stress | superseded by gates 8, 16, 17, 19, 21; an integration fixture may reuse it |

---

## 15. Open Questions Promoted To Spec-Cut

- Physical storage encoding of fact families and the fold-local view shape;
  whether dynamic active matrices remain a distinct alternative.
- Schema version and table shapes for fact tables, the quarantine surface,
  the diagnostics table, and snapshot hash rule 2.
- Diagnostic retention tiers and what a minimal tier persists.
- Mechanical detection of stale positional references (W18 did not execute).
- Whether `cash_tolerance` becomes a parameter of the affordability step.
- Alias facts and per-observation revision facts as v1-optional families;
  gate 2 and witnesses W16 and W29 follow that decision.
- Exact API shape of the `asset_state` element and its lifecycle hook.
- The `ledgr_facts_sessions()` input format and holiday closure encoding for
  one venue.
- Reason-code enum finalization beyond the codes named in Sections 6 and 7.
- Scale optimization, only after a probe under `../spike_protocol.md` with
  one question and a production-shaped path.

---

## 16. Future Obligations Recorded

- Corporate-action and terminal-event accounting, and resolved terminal
  economics, owned by the accounting-critical-event sibling RFC.
- OMS semantics: persistent orders, partial fills, cancellation.
- Multi-venue and subdaily calendars and cross-venue pulse unions.
- Fitted preprocessing, imputation, and the ML lifecycle, with the
  four-mode causality contract in Section 8.
- Margin, settlement, and financing policies.
- Live-feed degradation and recovery.
- Broad provider adapters and a vendor adapter catalog.
- Any representation measurement, chartered separately with a scalable
  common fold.

---

## 17. Disagreements With Seed v2 And Decisions Beyond It

Disagreements, none reversing an accepted decision:

- Seed v2 leaves the horizon "without an RFC default". This synthesis goes
  one step further: the valuation policy is a required argument whenever
  availability is active, so no package default can appear later without an
  RFC. Same intent, stronger binding.
- Seed v2 says ranks and weights use `ctx$members`. This synthesis narrows
  new or increased exposure to `ctx$vec$admissible` (member and not
  restricted), which is what addendum R5 required of helpers. Members remain
  the cross-section for signals.
- Seed v2 lists "explicit status and observation evidence" in the first
  slice. This synthesis keeps `trading_status` optional under Section 3 so
  that the ingestion journey needs no status feed. Declaring it enables the
  gate; omitting it is disclosed.
- The response proposed `ledgr_liquidate()` and `ledgr_usable()`. This
  synthesis binds neither: liquidation is a literal zero, and v1 usability is
  `is.finite()` over strict-gap features. Seed v2 did not require either, so
  this is a narrowing, not a conflict.
- Seed v2 defers "names" to synthesis. Section 10 binds them; the spec may
  adjust argument names but not the family-first shapes.

Decisions Seed v2 left open and this synthesis binds:

- Membership is frozen at decision time; execution does not re-evaluate it
  (Section 7.2). The alternative, a membership gate at execution, was
  rejected because membership is not a trading restriction and the
  reduction-only rule already governs the resulting held non-member.
- Seal-time invalid observations are quarantined rather than stored
  (Section 4.4), because sealing is strict today and a stored invalid bar
  would need a nullable canonical row.
- `max_sessions = 0L` is a valid current-mark-only valuation policy
  (Section 7.3).

---

## 18. Accepted Post-Synthesis Horizon Entry

```text
### 2026-09-08 [data] Asset availability post-v0.1.9.8 direction

The accepted synthesis binds the first implementation of point-in-time
universes: one activation rule, one fold core, a members-union-held axis,
policy v4 semantics, strict feature gaps, and a required declared valuation
horizon. "v1" means the first implementation of this feature.

Deferred themes: accounting-critical events (dividends, delistings,
terminal economics) -> accounting sibling RFC; OMS and order lifetimes ->
OMS RFC; fitted preprocessing, imputation, ML lifecycle -> preprocessing
RFC; multi-venue scheduling -> calendar RFC; representation measurement ->
a spike_protocol probe with one question.

Promoted roadmap hooks: accounting-critical events (v0.2.x); OMS (v0.3.0);
preprocessing and ML (v0.2.x after PIT ships); multi-venue (v0.3.x);
aliases and revision facts (v0.2.x spec-cut candidates).

Immediate cross-cycle obligations: the PIT spec packet edits the Snapshot,
Context, Strategy, Result, and Persistence contracts as listed in Section 2
of the synthesis; the accounting sibling consumes the lifetime family and
the terminal_settlement_unsupported stop as its entry point.

This entry does not authorize any of the above; it records the direction.
```

---

## 19. Revision History

- **2026-09-08** -- initial draft by Claude for Codex final review. Inputs:
  maintainer-accepted Seed v2 at `e2a7a05`; spike evidence at `d59259f`.
- **2026-09-08** -- final-review patch set 1 (Codex findings, all verified
  against `e2a7a05`): `target_restricted` redefined as declared-evidence
  restriction independent of non-membership, with the admissibility table
  split by member and restricted (6.1, 6.3); fixed baskets and membership
  rules made orthogonal with `universe_id` selection (3, 5.2, 10.2);
  execution-time membership freeze bound with an informational reason and
  gate 13 (7.2); identity table corrected so fact families enter
  `snapshot_hash`, experiment declarations enter experiment and config
  identity, `candidate_key` stays recipe identity, and `session_id`
  inherits (9.1, 2); result views bound on `tibble::as_tibble()` with
  delegation (9.4, 2); venue-scoped envelope for `sessions` with the
  applicability rule (4.1); gates 13 through 20 and the W01-W31 disposition
  matrix added, alias and revision clauses made conditional (14);
  seal-time invalid observations quarantined rather than stored, added to
  the reconciliation table (4.4, 2). Non-blocking: `max_sessions = 0L`
  defined; teaching-media sentence neutralized; "sparse-grid" clarified.
- **2026-09-08** -- final-review patch set 2 (Codex re-review): `unknown`
  lifetime preserves the venue calendar and only accepted `known_inactive`
  intervals remove expected sessions (3, 4.1); knowledge assumptions live in
  `snapshot_hash` only, with no experiment-level override in v1 (3, 9.1);
  `ctx$vec$target_restriction_reason` added as the companion character field
  (6.1, 9.4); gate 7 asserts `risk_mark_unavailable`, gate 18 asserts the
  reserve and the unfilled-sale rule, and gates 21 through 23 cover the
  lifetime family, terminal assertions, and stable-ID continuity, with the
  W01, W02, W05, W07, W22, W27, and W31 dispositions repointed (14);
  execution-time membership is inspected for diagnostics only, never as a
  gate (7.2).
- **2026-09-08** -- final-review patch set 3 (Codex re-review): the valuation
  clock counts venue open sessions independently of lifetime, so a held
  `known_inactive` position without a terminal assertion still exhausts and
  stops with `valuation_horizon_exhausted` carrying `lifetime_inactive`
  (3, 4.1, 7.3, 7.4, gate 21); `target_restriction_reason` carries the first
  applicable reason in fixed order and `target_restriction_reasons` carries
  the ordered `|`-joined set, mirroring the execution convention (6.1, 9.4);
  the membership-freeze rationale now says blocking would make membership an
  execution-eligibility input (7.2).
- **2026-09-08** -- Codex terminal re-review found no remaining findings. The
  maintainer accepted the synthesis; the post-synthesis horizon entry and
  governance indexes were updated. No spec packet or implementation was
  opened by acceptance.
