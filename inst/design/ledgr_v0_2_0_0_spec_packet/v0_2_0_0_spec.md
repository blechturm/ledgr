# ledgr v0.2.0.0 Spec

**Status:** Accepted 2026-09-09; tickets cut for implementation.
**Date:** 2026-09-09.
**Author:** ChatGPT Astra.
**Target branch and development version:** `v0.2.0.0`, package `0.2.0.0`.
**Baseline:** `048b925e5411b7c1a7500d4163163aed72039062`.
**Scope:** API and representation hardening, then the first asset-availability implementation.
**Authority:** Binding implementation packet under two accepted syntheses and the maintainer's
2026-09-09 acceptance. Ticket cut does not mark implementation tests passed or authorize release
publication.

The maintainer moved development from `v0.1.9.8` and opened `0.2.0.0` in DESCRIPTION and NEWS.
Historical RFC filenames and baseline citations remain unchanged. No further version bump is
part of packet opening; package, store-schema, snapshot-hash, and feature versions are distinct.

## 0. Source Inputs

Binding design inputs, read at the baseline above:

- **H:** [API hardening synthesis][hardening], accepted 2026-09-09, including its patched
  failure fixture, five slices, twelve gates, and four maintainer decisions.
- **U:** [Asset availability synthesis][availability], accepted 2026-09-08, including the
  independent session-clock correction, 24 gates, and witness dispositions.
- [Contracts][contracts], [RFC cycle][cycle], [spike protocol][protocol],
  [vignette styleguide][styleguide], and [release CI playbook][release].
- [Roadmap][roadmap] and [horizon][horizon], particularly the September 4 infrastructure/docs,
  September 6 CI, September 8 availability, and September 9 hardening entries.

Evidence and packet precedents:

- **A:** [Test-suite audit][audit], including measured evidence in Section 7. It remains open.
- [Hardening probe findings][probe] and [final review][review], including the executed
  [fold-rollback gut][gut]. These are recorded execution, not new execution by this author.
- U's research references and its explicitly inconclusive representation-spike closeout.
  The disposable spike branch is not merged or used as production implementation.
- [v0.1.9.5 spec][previous-hardening] and [v0.1.9.7 spec][previous-release] for packet shape.

Statements below prescribe implementation unless explicitly labelled **Source** or **Executed**.
New filenames, columns, and choices are proposals, not claims about shipped surfaces.
H and U remain normative where incorporated by reference. No new performance evidence is claimed.
The first spec review identified two unresolved scope contradictions. The maintainer's 2026-09-09
acceptance adopts Sections 2.4 and 2.7 as explicit amendments to U's quarantine and
unrestricted-member rules; they are packet decisions, not claims about the earlier RFC decision.

## 1. Thesis And Release Outcome

A user should be able to run an ordinary strategy over a changing investment universe, retain
a removed holding, distinguish a missing observation from an executable price, and inspect why
a trade did not happen after reopening the store. The same economic rules must apply to runs,
sweeps, parallel candidates, and walk-forward evaluation.

First correct and strengthen the existing core, then extract its coordinator without moving
effects, then add availability semantics. Hardening's prohibition on new exports and fold-engine
changes applies to its workstream. U explicitly authorizes its own later APIs and fold changes.

This release does not promise complete corporate-action or delisting economics. Unsupported
terminal settlement produces an explicit incomplete result. It does not ship portfolio optimizers,
imputation, or ML fitting. It does not claim support for short-account financing, OMS, live data,
or representation optimization.

## 2. Product Shape And Spec-Cut Decisions

### 2.1 Public hardening contract

Carry H Sections 1-4 unchanged:

| Surface | Packet behavior |
| --- | --- |
| `ledgr_run_fills(bt)` | Eager full-schema tibble, including empty runs; remove cursor, `lazy`, and `stream_threshold`, with no `...` or compatibility shim |
| Derived reversal rows | Allocate event fee `F * abs(leg_qty) / sum(abs(leg_qty))`; independently assert conservation per `event_seq`; preserve ledger, cash, basis, PnL, and trade metrics |
| `ledgr_sweep_review()` | Restore `ledgr_sweep_results` lineage on `ranked`; keep `top` presentation-only because it omits required provenance |
| `ledgr_run_info()` | Add character `risk_chain_hash` from recorded run identity; missing historical evidence is `NA_character_`; do not infer a no-op hash |
| Targets | Teach `c(target)` and `target[["AAA"]]`; do not add `ledgr_target_values()` |
| Handle lifecycle | `close()` releases a held connection; the durable locator remains readable by path; teach reopening in a new session |

The executable teaching path includes the required promotion argument:

```r
review <- ledgr_sweep_review(sweep, rank_by = -final_equity)
candidate <- ledgr_candidate(review$ranked, 1)
bt <- ledgr_promote(exp, candidate, run_id = "promoted_from_review")
```

Complete explicit risk restoration in `R/sweep-retention.R` for both `risk_chain_hash` and
`risk_plan_json`. Land it separately from the demonstrated review-lineage correction. Keep
row-provenance reconstruction and retained-evidence filtering by candidate identity.

Wide retained-return views retain `ts_utc` as a structural column. Preserve ordinary candidate
names; encode an ID equal to `ts_utc` or starting with `..ledgr_candidate_` as that prefix plus
the lowercase hexadecimal encoding of its UTF-8 bytes. This is injective, reversible, independent
of selection order, and never changes candidate identity. Apply it wherever timestamps and candidate
IDs share a wide-table column namespace; matrix dimnames and long candidate-ID columns retain the
original IDs. Add no persistent mapping registry.

The legacy run-info fixture is a disposable current store containing a DONE run with a recorded
config lacking risk identity and no risk-specific run metadata. Compare it with direct and
promoted nondefault-risk runs; every info read must leave persistent rows unchanged.

### 2.2 Finalization failure and recovery

**Source:** `R/fold-engine.R:595` encloses the pulse loop in the handler transaction. Periodic
flushes drain buffers. `R/backtest-runner.R:1458-1476` commits features separately from the
equity/DONE transaction at 1479-1485, outside the fold error handler at 1275-1290.
**Executed:** the review gut's mid-fold exception leaves FAILED and zero ledger/state/equity
rows on a fresh run; a normal partial return commits a prefix. No finalization gut has run.

Resolve H Section 11.2 as follows: a finalization error before successful equity/DONE commit
records FAILED and the original condition message, preserves committed fold evidence, and signals
the original error. The run remains resumable through the existing execution entry point with
the same identity. On successful recovery, record DONE and clear the error. A later telemetry
failure must not relabel a successfully committed DONE run as an execution failure.

Add a narrow finalization error boundary; do not move the fold transaction, feature transaction,
equity/DONE transaction, `set.seed()`, or existing status writes during extraction. Failure
recording must not mask the original condition. This correction is a separate commit before
coordinator stages 3-4. `ledgr_run_open()` remains DONE-only during hardening.

Use H Section 6's two-store, eight-pulse, nonzero-fee, stateful fixture. The test-local injection
wraps `DBI::dbWithTransaction`, delegates all normal calls to the captured original, and fails
once on entry to the final equity transaction after the feature transaction returned. Identify
that transaction by its equity replacement expression, not by counting all transactions. Capture
the full committed fold and feature rows there. No production fault option or hook is exported.

The single `test-runner.R` scenario asserts: (1) committed ledger/state/features are unchanged
after failure and no equity/DONE commit occurred; (2) FAILED and the original stored error are
visible through a fresh connection; (3) removing injection and resuming yields clean ordered
ledger, state, features, equity, fills, and trades, without duplicates, ending DONE. Keep the
existing partial-run/resume tests separately. A failed baseline is a correction task, not a
reason to weaken these assertions or simulate successful recovery in the test.

### 2.3 Availability activation and public API

Implement U Sections 3, 6, and 10. Any declared membership, sessions, status, or lifetime family,
or a valuation policy, activates availability. Every active experiment requires complete sessions
and `ledgr_valuation_stale(max_sessions)`, with no default horizon. A fixed basket stays fixed
even when membership facts exist. Omitted declarations retain the dense path and canonical omission.

Add U's six fact/bundle constructors, `ledgr_facts_validate()`, `ledgr_universe_members()`,
`ledgr_valuation_stale()`, and `ledgr_run_explain()`. Extend `ledgr_experiment_plan()`, snapshot
creation with `facts = NULL`, experiment construction with `valuation_policy = NULL`, and the
existing result dispatch with `diagnostics` and `availability`. Do not add a mode selector.
Add `invalid_observations = "error"` to the dataframe snapshot constructor and facts dry-run
report, with the explicit `"quarantine"` alternative defined in Section 2.4. This controls row
disposition, not execution mode. Other adapters retain strict rejection until they forward this
same contract explicitly; no adapter silently enables quarantine.

The fact report distinguishes structural errors, accepted runtime conflicts, quarantine, and
audit-only rows. Knowledge assumptions are explicit, hashed, and visible in the effective plan
and summaries. A fixed basket does not imply dense behavior; an omitted status family disables
only its status check. An unknown lifetime restricts nothing.

### 2.4 Fact storage, calendar input, and resolution

Choose normalized, sparse fact tables in the existing DuckDB snapshot store and bounded aligned
arrays behind one internal provider. This is a simplicity choice, not a measured winner. Do not
persist expanded availability planes or implement competing physical providers in this packet.

Store timestamps as whole-second UTC TIMESTAMP, civil session dates as DATE, strings as TEXT,
flags as BOOLEAN, precedence and ages as INTEGER, and quantities/prices as DOUBLE. Canonical
JSON uses the existing serializer. Effective intervals are half-open; NULL end means unbounded.
Missing knowledge remains NULL and audit-only unless the constructor records an assumption.

Proposed tables, all scoped to an existing `snapshot_id`:

| Table | Key and payload |
| --- | --- |
| `snapshot_fact_families` | PK `(snapshot_id, family, scope_id)`; `metadata_json` contains normalization contract, knowledge assumption, and family-specific completeness/coverage declarations; empty declared families remain represented |
| `snapshot_membership_sets` | PK `(snapshot_id, universe_id, set_id)`; effective time, knowledge time, `complete`, provenance; retains empty complete snapshots without inventing an instrument row |
| `snapshot_membership` | PK `(snapshot_id, fact_id)`; stable instrument ID, universe ID, nullable set ID, effective interval, knowledge time, member flag, provenance JSON |
| `snapshot_trading_status` | PK `(snapshot_id, fact_id)`; stable instrument ID, effective interval, knowledge time, status, source, integer precedence, optional revision/superseded-fact IDs, provenance JSON |
| `snapshot_lifetime` | PK `(snapshot_id, fact_id)`; stable instrument ID, effective interval, knowledge time, assertion, nullable terminal label, provenance JSON |
| `snapshot_sessions` | PK `(snapshot_id, venue_id, session_date)`; effective interval, knowledge time, open/closed status, nullable session-open/session-close UTC times, provenance JSON |
| `snapshot_observation_quarantine` | PK `(snapshot_id, quarantine_id)`; supplied ID/time where parseable, reason, original row JSON, provenance JSON; never a runtime observation |

Fact IDs identify assertions, not instruments or execution events. Normalize supplied source IDs
within their family/source scope; otherwise derive them from canonical assertion payloads.
Exact repeated assertions are idempotent; the same canonical identity with incompatible payloads
is an error. Unknown instrument references in facts, malformed intervals, and malformed
supersession fail sealing. Quarantined observation references may be invalid and have no instrument
foreign-key requirement. Valid bars keep their existing non-null OHLC schema and primary key.

**Resolve quarantine lifecycle:** choose explicitly acknowledged exclusion of invalid observation
rows. With `invalid_observations = "error"`, any such row blocks snapshot creation/sealing; the
error carries the dry-run report and no SEALED snapshot or hash is produced. A dry run never
writes. To continue, the user corrects input or explicitly submits the same input with
`invalid_observations = "quarantine"` and a facts bundle declaring sessions. No interactive prompt
or implicit acknowledgement is added. Dense input without those facts retains strict rejection.

The explicit alternative partitions rows before bar import: admissible rows enter `snapshot_bars`;
individually invalid observations enter quarantine with original payload, reasons, and provenance.
The sealed quarantine-family metadata records the exclusion policy. Its rows and metadata enter
hash rule 2; exclusion counts appear in the validation report and snapshot summary. The remaining
bars and all facts must pass structural validation. Missing required columns, an invalid instrument
master, malformed facts/calendar, duplicate bar keys, and unresolvable input shape
still block sealing under either policy. Quarantine cannot select between competing valid records.
Retain the existing nonempty-bar/instrument requirement; excluding every bar does not produce a
runnable snapshot. An excluded bar leaves an absence for the declared session; it creates no
observation, imputation, valuation price, fill, or extra pulse.

The lower-level seal step verifies both valid runtime tables and a well-formed, explicitly
acknowledged quarantine family; merely moving bad rows to another table cannot bypass validation.
Persist the accepted partition and its acknowledgement before the seal transaction, then seal
atomically. A seal failure leaves no partial SEALED state or accepted hash. Acknowledgement never
repairs the rejected row and applies only to this input invocation. This is a proposed exception
to U Section 10.3's blanket structural-invalidity wording, reconciling its Section 4.4 hashed audit
requirement. Valid runtime bars remain strictly validated. Update the Snapshot Contract on approval.

For membership snapshots, input groups use `effective_from`, `knowledge_time`, and `instrument_id`;
an explicit row with missing instrument ID denotes an empty group header, never a member. The
normalizer separates headers and members. Each partial group asserts listed members only; a
complete group additionally establishes omitted IDs as nonmembers from its knowledge time.
Intervals accept U's `member` column and effective bounds. Retain provenance for implicit omission
through the set header, rather than expanding a complete cross-product of false memberships.

Resolve only facts knowable at the queried cutoff. Complete membership sets apply by effective
state; later knowable updates cannot rewrite earlier decisions. Incompatible simultaneous
membership/lifetime assertions are structural errors. Status supersession is explicit and
source-local, acyclic, and applied only once the replacement is knowable and effective. Higher
integer precedence wins among remaining assertions; distinct top-precedence ties remain runtime
conflicts as U requires. Do not resolve ties by ingest order or arbitrary fact ID.

`ledgr_facts_sessions(df, venue_id, knowledge = "evidenced", timezone = "UTC")` accepts
one row per civil date, including weekends/holidays marked closed, over its declared coverage.
Require `session_date`, `status`, `session_open`, `session_close`, and knowledge evidence;
closed rows have no open/close times. The constructor records the first/last supplied dates and
the explicit IANA `timezone` argument in family metadata. Derive daily effective bounds in that
timezone. Require every date between endpoints exactly once and every open time before its close;
closures and coverage must be knowable before the affected day starts.
Open sessions must be knowable by their opening. Do not infer holidays or missing dates from bars.

For active EOD data, `snapshot_bars.ts_utc` labels the declared session close. Adapters explicitly
map vendor date labels to those closes before ingestion; ledgr never guesses or shifts raw dates.
Decision pulses are open-session closes. Execution opportunities use the next declared open
session's opening, even if its observation is absent, and events use that execution timestamp.
The corresponding bar's open is execution evidence under next-open simulation; its later high,
low, close, and volume are never decision inputs at that opening. Dense timestamp conventions stay.
Validate coverage over scoring and required history; no terminal extra session is invented to fill
a final-pulse target. A valid off-calendar row is retained for cutoff classification, not a pulse.

### 2.5 Identity, schema versions, and compatibility

**Source:** At ticket cut, `R/experiment-store-schema.R:1-2` declared store schema 112 and
saved-sweep schema 3. The staged implementation advances the store through schemas 113-115 and
the saved-sweep schema to 4 for the new evidence/status fields. Snapshot
hash rule 2 covers normalized instruments/bars plus every declared fact-family header and row,
including quarantine. Rule 1 remains the exact existing hash computation when facts are absent.
Persist the rule identifier for fact-bearing snapshots; absence on legacy snapshots means rule 1.
Physical rows are serialized in deterministic family/key order, excluding store-local snapshot IDs.
Metadata that controls classification, coverage, knowledge assumptions, or completeness is hashed.

Writers perform an explicit transactional schema upgrade and advance the marker last. Readers
remain read-only, tolerate absent new tables on legacy stores, and reject future versions. Preserve
existing sealed bars, instruments, hashes, configs, and economic rows; no snapshot is resealed or
rehash-migrated. Constraint changes for new statuses must preserve and reconcile old rows in the
migration test. Update create-side DDL and validators together; do not silently recreate stores.

Use U Section 9's identity layering exactly: universe rule and valuation policy bind experiment
and config; knowledge assumptions bind source facts; risk hash and candidate-recipe key gain no
availability field; walk-forward session identity inherits through snapshot/experiment identity.
Dense canonical payloads gain no availability flags or default-valued policy fields.
Keep walk-forward candidate/session format identifiers unchanged; extend stored evidence only.

Availability feature fingerprints include strict-gap and admissible-history semantics. Expand
the computed feature-engine fingerprint to cover the actual new semantic helpers. No hard-coded
claim of unchanged feature-engine version is permitted after their behavior changes. Test byte
identity under identical declared versions separately from approved equivalence across versions.

### 2.6 Provider, state, and strict features

Use U Section 5's internal operations: `facts`, `decision_view`, `execution_view`, `history`,
and `identity`. The execution spec may carry a bounded superset for aligned arrays. At each
pulse expose only ordered members plus nonzero holdings; held nonmembers follow in C-locale
stable-ID order. Keep all economics in the shared fold and all writes in its output handlers.
Filter scalar/fast contexts, interactive views, feature inspection, errors, and worker telemetry.
The active path uses canonical R accounting. Reject an explicit compiled spot-FIFO request before
execution with `ledgr_compiled_availability_unsupported`; do not silently fall back. Dense compiled
opt-in retains its existing scope and tests; this packet claims no active compiled parity.

Resolve `asset_state` as `ctx$state_prev$asset_state`, a named list keyed by stable ID, updated
through the existing `list(targets = ..., state_update = ...)` return. Before callback, retain
only current-axis entries and initialize newly visible IDs with `list()`. Validate returned keys
against that axis. Preserve all other portfolio-state fields. Persist cleanup even if the strategy
returns no state update; a supplied state update keeps its existing replacement semantics, with
the engine normalizing the asset-state element. Re-entry gets a new empty element. No new callback
signature, state registry, or lifecycle callback is introduced. Walk-forward carries permitted
state and FIFO holdings before applying the new fold's axis cleanup.

`ctx$idx()` remains an ordinary pulse-local index. Do not add tagged vector/index classes or
claim detection of cached bare integers in arbitrary user code. Supported persisted asset state
uses stable keys and is mechanically checked; examples re-resolve indices each pulse. This is the
explicit W18 disposition. Gate U23 checks the supported state/history lifecycle, not an R sandbox.

Strict feature windows count the last `stable_after` expected sessions of the existing finite
window contract; `requires_bars` remains its minimum, not a promise of convergence for a recursive
estimator. Any missing required observation makes the result NA. No callback receives imputed bars
or valuation marks. History admission is recomputed as of each use cutoff; later-known history
cannot retrospectively alter cached earlier outputs. Membership exit does not erase source history.

For active definitions, normalize an optional `gap_contract = "strict_window"` on the existing
indicator constructor/definition path; omission means unsupported unless an unchanged shipped
constructor supplies the declaration. It commits the author to a finite window and no internal
carry/imputation. Omit it from dense identity. Initially certify SMA and returns through U3;
enable other existing definitions only with named scalar/series/window parity tests. Unknown or
nonconforming declarations fail `ledgr_indicator_gap_unsupported` at experiment validation.
This is a definition field, not a plugin registry or an imputation API.

For the first active implementation, compute each eligible window independently: scalar `fn`
and the terminal result of `series_fn` receive that same bounded, fully observed window.
Series acceleration must match scalar results exactly on its certification fixtures; simply
masking a full-history recursive series is insufficient. Cache the resulting cutoff-causal series
under U's active fingerprint; dense calculation remains untouched. Do not claim this is faster.

### 2.7 Fold economics, controlled stops, and evidence

Implement U Sections 6-7 with the account-scope guard below: literal zeros, preserved held
nonmembers, reduction-only nonmember targets, restricted hold-or-zero targets, post-risk closure,
and residual marked-NAV sizing. Preserve whole-share flooring in the target helper; affordability
never floors or scales a proposed fill. Freeze membership eligibility at decision; recheck status,
lifetime, execution price, and affordability at execution. Record membership changes as information
only.

**Active short-exposure guard:** after U's strategy and risk checks, but before fill proposals,
require each effective target `q` to satisfy `q >= min(q_held, 0)`. Use the quantity held at that
check. Apply the same condition to each resolved fill's resulting quantity before any virtual-cash
credit or acceptance. An unrestricted member cannot open a short, reverse a long into a short,
or enlarge an inherited
short. An inherited negative holding may remain unchanged or move toward zero; a member may cover
and then go long when the existing admissibility and cash rules permit it. Restricted/nonmember
rules remain stricter and take precedence. Check quantities exactly; cash tolerance is not a
permitted quantity tolerance. Fail the candidate with `ledgr_short_exposure_unsupported`, a
`ledgr_invalid_strategy_result` subclass carrying reason `short_exposure_unsupported`, before
accepting or emitting any fill from that pulse. Do not partially finance unrelated purchases.

The guard applies with or without a risk chain. A negative strategy target reduced to zero by
an explicitly selected `ledgr_risk_long_only()` passes if its effective quantity passes; do not
insert that risk step, change risk identity, or alter dense target validation. Cash-generating
sale credits in active mode are limited to reducing an existing positive holding. Existing short
holdings remain algebraically representable; covers consume cash and no new spendable cash is
inferred from their origin. Borrow, collateral, restricted proceeds, and financing remain deferred.
This proposed account-scope restriction qualifies U Section 6.3's unrestricted-member row and
closes P12's active-path consequence without defining a general short-accounting contract.

Keep `cash_tolerance = 1e-8` as an internal identity-bound constant, not a parameter. Evaluate
resolved cash-generating fills first, then consuming fills in stable-ID order; emit accepted
events in axis order. A rejected sale funds nothing. Reconcile final cash and intended, post-risk,
and actual exposure. Do not infer an intrapulse cash floor from final affordability.

The fold chooses fresh or permitted stale valuation separately from execution prices. Venue
open sessions age held marks even during known inactivity; instrument expected sessions exclude
known inactivity for features. No mark may silently produce NA equity. U's named risk, valuation,
terminal, and affordability stop reasons remain distinct.

**Resolve controlled-stop persistence:** return a typed terminal fold result through the normal
transaction return path, rather than throwing an exception that rolls back the entire prefix.
Expected exhaustion/unsupported-settlement stops finalize as `INCOMPLETE`, never DONE. Before
the stopping pulse's strategy/risk/fill work, preserve the earlier committed semantic prefix and
its last fully valued timestamp. For a stop discovered later in a pulse, stage that pulse's
state/events until feasibility and reconciliation succeed; discard only unaccepted pulse work.
Retain events already accepted from earlier decisions, including their later execution timestamps.
The separate last-executed timestamp must not be replaced by the last-valued timestamp.

Unexpected exceptions thrown during fold execution remain FAILED and roll back that fold
transaction, preserving any prefix committed by an earlier invocation. Record structured
rejection/error diagnostics outside the rolled-back transaction without fabricating newly committed
economics. Exceptions after the fold commits follow Section 2.2 and preserve that fold evidence;
they cannot roll it back. A deliberate `max_pulses` interruption remains RUNNING and resumable.

An achieved INCOMPLETE run is terminal and idempotent. An execution call with the same run ID and
matching identity returns its persisted handle with INCOMPLETE status and the same completion
evidence. It performs no strategy/risk/fill work, resume-tail cleanup, status change, or projection
rewrite. Verify the snapshot and recorded identity before taking this shortcut; a mismatch fails
through existing guards. `ledgr_run_open()` inspects the same evidence without executing strategy.
Changed facts/policies require a new identity and run. Do not repeatedly replay a known stop.

Finalize INCOMPLETE prefix projections with the same error-safe path as DONE, then expose the
handle. Extend `ledgr_run_open()` to DONE or INCOMPLETE only in the availability workstream.
A failed attempt to finalize either outcome is FAILED and must recover the intended outcome on
resume. Persist the intended terminal outcome and prefix boundaries in `run_completion` in the
same transaction that commits the terminal fold result, before projection finalization. RUNNING
or FAILED with a durable terminal completion record takes a finalization-only recovery path.
Verify identity and committed evidence, rebuild missing projections idempotently, clear the error,
and commit the recorded DONE or INCOMPLETE outcome. Never resume its pulse loop or apply resume-tail
cleanup.
Without that record, use ordinary execution recovery; no recorded intent alone proves an achieved
terminal status. Missing rows or inconsistent bounds referenced by a terminal completion record
fail closed. No inspection call executes strategy code. Hardening's original recovery test remains;
availability adds both terminal outcomes.

Add `run_completion` keyed by `run_id`: UTC intended/achieved start and end timestamps, TEXT
intended terminal status and stop reason, DOUBLE affected exposure, UTC last fully valued and
last executed timestamps, and BOOLEAN `complete_performance`. Store affected IDs and quantities
in the corresponding stop diagnostic. Add nullable UTC `affected_exposure_ts_utc` and TEXT
`affected_exposure_basis`; use the fixed basis `last_accepted_close_gross` for this release.
Reuse this completion payload in sweep candidate and walk-forward score evidence, with new status
support in the owning schema validators.
Use nullable canonical `completion_json` columns on `sweep_candidates` and `walk_forward_scores`;
their statuses admit INCOMPLETE. Use the existing fold PARTIAL status for a stopped carry-state
chain and disclose it in session summaries. Candidate/session identity schemas do not change.
Unknown legacy completion metadata stays unknown; do not synthesize an observed horizon from
unavailable evidence.

**Affected exposure:** this is a diagnostic gross amount, not NAV, net exposure, an execution
price, or a performance observation. Take the distinct affected IDs named by the stop reason and
their held quantities after all accepted earlier events, excluding discarded pulse work. Its
timestamp is the stop's resolution cutoff: execution time for an execution-stage stop, decision
time otherwise. For each nonzero quantity, use the latest accepted observed close knowable and
accepted as an observation at that cutoff, even when its age now exceeds the valuation horizon.
Compute `affected_exposure = sum(abs(quantity_at_stop * reference_close))` in the run's accounting
units; no FX conversion is introduced. Deduplicate IDs before summing. Intended/rejected targets
are recorded separately and never substituted for held quantities.

Each affected-ID detail records quantity, reference price, source timestamp, venue-open-session age,
whether that reference is still a permissible valuation mark, and its absolute contribution.
An expired reference is labelled diagnostic-only and never revives equity, risk, or execution.
A zero quantity contributes zero without a price. If any nonzero holding lacks a reference, the
aggregate is NULL/NA, not a partial sum; retain known per-ID contributions and identify missing
ones. An unspecified affected set is likewise NULL/NA, never inferred to be zero. Empty specified
sets sum to zero. No last fully valued timestamp is required for this diagnostic, and a reference
known only after the cutoff is forbidden. Persist the same payload for runs, sweeps, and fold
scores.

Add `run_diagnostics` keyed by `(run_id, diagnostic_seq)`, with U9.3's columns and nullable
`decision_ts_utc`, `execution_ts_utc`, `event_seq`, `target_before_risk`, `target_after_risk`,
`position_before`, `position_after`, `feature_identity_json`, and `detail_json`. Sequence rows
deterministically by decision pulse, stage, and axis; store amounts as numeric values. Preserve
all applicable reason codes in their fixed order and the first separately. Missing execution
opportunity is NULL, not a made-up timestamp. Use an empty instrument ID only for portfolio rows.

Choose one required committed-run retention level for this release. In active mode record a
decision trace row for each axis ID on every invoked pulse, plus U's risk/fill/stop diagnostics;
this preserves actual pre/post-risk targets and held reasons without re-executing strategy code.
Record the effective plan with the run. Reconstruct deterministic availability planes from sealed
facts, that plan, and ledger holdings; do not persist a second copy of the planes. Detailed traces
are not optional until a later retention design can preserve U's explanation contract.

Memory sweeps compute the same diagnostics but retain compact completion/stop evidence and prefix
metrics on candidate rows, not durable per-candidate ledgers or full decision traces. Parallel
workers return those compact rows; the parent owns persistence. Existing optional series retention
may retain the achieved prefix, explicitly labelled incomplete; panel/selection APIs must exclude
it from complete-performance comparisons. Walk-forward shows excluded training candidates and
stops a carry-state chain on an incomplete test fold instead of inventing later opening state.
Reject selection and promotion of INCOMPLETE candidates even through `allow_failed` paths.

Use U's reason-code spellings and precedence unchanged. Add structural input codes for
invalid fact/calendar/state shapes, `final_pulse_no_execution` for the active final-pulse no-fill,
`decision_recorded` for the ordinary trace, and the account-scope reason above. Errors remain
classed; diagnostics remain data. Quarantine uses U's existing `observation_invalid` reason.
Use `fact_invalid`, `session_invalid`, and `asset_state_invalid` for those structural reasons,
with `ledgr_`-prefixed condition classes; preserve the already-bound more specific U errors.
The code table in the generated reference help must map every emitted reason to stage and action.
Dense/legacy runs return a typed empty diagnostics table and their constant dense availability
planes; explanation requests without a retained decision trace fail
`ledgr_run_explanation_unavailable`, rather than reconstructing invented targets.

## 3. Module Boundaries And Contract Touchpoints

Source line ranges below are baseline ownership citations, not instructions to reorder calls.

| Destination | Ownership and preserved boundaries |
| --- | --- |
| `R/backtest.R` | Public construction and `ledgr_run()` orchestration remain thin |
| `R/backtest-config.R` | Move config construction, strategy specs, identity/opening normalization, and config print from `R/backtest.R` |
| `R/backtest-handle.R` | Connection ownership, read connections, close, cleanup/finalizers |
| `R/backtest-fills.R` | Eager fills, derived allocation, trades and their empty schema; cursor code is deleted before moves |
| `R/backtest-results.R` | Result dispatch, equity/returns, metrics, summaries/printing, warm-up diagnostics and other result schemas; no extra broad split |
| `R/run-prepare.R` | Coordinator stage 1: normalize config/control and return an explicit list; leave clock/seed/status effects at their existing call sites |
| `R/run-snapshot.R` | Stage 2: guard, TEMP views, hash and calendar results at existing runtime points; do not hoist calendar work |
| `R/run-finalize.R` | Stage 3: projections, second FIFO lot pass, separate transactions, outcome/telemetry; retain the corrected error contract |
| `R/run-registration.R`, `R/run-resume.R` | Stage 4: register/lookup/identity/DONE shortcut and resume-tail cleanup; receive the existing handler and store connection explicitly |
| `R/backtest-runner.R` | Coordinator and existing persistent handler remain; cleanup is coordinator-scoped, never lost in a returning helper |
| `R/availability-facts.R`, `R/availability-provider.R`, `R/availability-results.R` | Later U implementation: fact normalization/resolution, bounded views, and read-side diagnostics/explanation respectively; no economic policy in the provider |

Helpers pass explicit config, connection, handler, snapshot/calendar, resume, state, and projection
records as needed; returned lists name their outputs. No shared mutable coordinator environment
is introduced. A connection-opening helper must return its closer for registration by the caller.
Stage order is extraction/commit order only. Keep all runtime guards, status transitions, and
`set.seed()` placement. Remove the two internal backtest wrappers in stage 1 and retarget callers.

| Contract section | Required same-release edit |
| --- | --- |
| Execution | Preserve shared fold; active session clock, eligibility freeze, bounded affordability, controlled stops, separate valuation; retain dense semantics |
| Snapshot | Fact families, quarantine, knowledge assumptions, rule dispatch and observation-independent coverage; sealed trust boundary stays at entry |
| Strategy / Context | Pulse axis, empty active domain, U fields, helper rules, stable-key state, strict feature support and index limitations |
| Persistence | Finalization error/recovery, new schemas, INCOMPLETE inspection, completion evidence, diagnostics, and fresh-connection visibility |
| Result / Sweep Promotion | Eager fills, fee allocation, review lineage, recorded risk info, active views/explanation, visible but ineligible incomplete evidence |
| Config / Naming / Documentation | Presence-only availability declarations, U's family-first exports, executable target/promotion/new-session teaching; no broad rename |

Contract edits accompany their behavior-changing batch. Historical accepted syntheses are not
rewritten. `R/fold-engine.R` and `R/sweep.R` undergo no mechanical modularization in hardening;
availability later changes their necessary semantics explicitly. No package split or export quota.

## 4. Documentation And Teachability Gate

Use one new installed `vignettes/survivorship-bias.qmd` article plus repairs to existing workflow,
strategy-authoring, execution, metrics, and experiment-store articles. Follow the styleguide's
outcome-first opening, visible setup, unformatted numeric evidence, and useful failure guidance.
Use the base pipe under the Documentation Contract, not an invented styleguide rule.

Prepare a small redistributable fixture from synthetic vendor-shaped tables: ten open sessions
over 2020-01-06 through 2020-01-17, with explicit weekend closures; venue `DEMO`, UTC open 14:30
and close 21:00, calendar known before the range. AAA is initially a member, BBB enters at the
third decision, and AAA is removed then while held. AAA lacks the fourth-session bar. An exit
requested at decision 3 fails at session 4; holding at decision 4 causes no delayed exit; a new
zero at decision 5 fills at session 6. Give marks a declared two-session horizon. This is an
illustrative market, not an assertion about an exchange or redistributed Sharadar data.

The visible journey builds/validates facts, seals, creates an experiment with U's universe and
valuation constructors plus explicit cost model, runs the same ordinary strategy used on a dense
fixture, explains the retained holding and both exit attempts, closes, opens in a fresh session,
and obtains identical explanations. No hand-built availability planes, internal SQL joins,
hidden preparation functions, or private provider fields appear in the user path.

Use small variants for missing-session validation, an empty complete membership set, a status
conflict, valuation exhaustion, and explicit quarantine. Show strict rejection first, then the
same input with `invalid_observations = "quarantine"`; print excluded counts and the resulting
missing session. An expired exposure reference is labelled diagnostic-only. Re-running an achieved
INCOMPLETE ID returns the same evidence without another callback. The example must print the
intended and achieved horizon, reason and next action, assumptions, and disabled checks. Teach
that missing membership is not a halt, stale valuation is not executable data, and no terminal
cash settlement is fabricated.
Reopening an incomplete run must teach inspection of the prefix, never portray it as DONE.

Draft the walkthrough and fixture shape before the availability implementation batch; execute
them as soon as the first ingest-to-run path exists and finish before release. Do not manufacture
expected evidence CSVs or rebuild the abandoned spike harness. H's teaching repairs land earlier.

## 5. Indicative Implementation Sequence

Ticket cut may subdivide batches, but must preserve the dependency order and named tests. No
correction is hidden in a mechanical move. Respect the protocol's correction-diff budget and
H's bounded extraction commits; a necessary stage-budget amendment goes to the maintainer.

| Batch | Work and entry condition | Completion evidence |
| --- | --- | --- |
| 0 | Accept spec, cut synchronized ticket Markdown/YAML and batch plan, align active pointers/roadmap/NEWS; record baseline environment and maintainer store inventory | Packet discoverable; new version already present; no fabricated test passes |
| 1 | H slice 1: fee projection, eager fills, review lineage, explicit risk restoration in separate correction commits | H1-H5; independent arithmetic and identity regressions |
| 2 | H slice 2: run-info hash, target/locator teaching, current stale-example repairs | H6-H8; installed example checks |
| 3 | H slice 3: mechanical backtest split and coordinator stages 1-2 | Corrected existing suite, runner/snapshot nets; unchanged effects |
| 4 | H slice 4: finalization test and separate correction; T-2/RNG/cleanup/doc-lock work; wide escaping last among artifact-shape fixes | H9-H10, H12; audit dispositions and measured outcomes |
| 5 | H slice 5: coordinator stages 3 then 4, separately committed | H11-H12 and existing partial-run/clean-resumed equality |
| 6 | U facts, calendar input, schema/hash rules, pre-seal report; walkthrough and fixture shape | U14-U16, U21 structural cases; hash/quarantine/migration tests |
| 7 | U provider, pulse axis/state, strict features/cache, declared plan; H complete | U2-U4, U6, U10, U20, U23; no economic implementation in provider |
| 8 | U shared-fold economics, valuation, affordability, typed stops and diagnostics | U5, U7-U8, U13, U17-U19, U21-U22, U24 |
| 9 | U durable explanation, INCOMPLETE reopen, sweep/save/parallel/walk-forward propagation | U9, U11-U12; failure/fresh-connection tests and dense parity U1 |
| 10 | Finish and execute survivorship journey, help/pkgdown and maintainer traces; reconcile scoped audit and horizon items | U12, H8; no private data or overstated PIT/completeness claims |
| 11 | Full release gates, compatibility/identity report, packet closeout and deferral routing | Section 7; release playbook and review |

Batch 8 requires review of independent economics, short-scope, and controlled-prefix tests before
Batch 9 starts. Batch 9 requires review of terminal recovery, idempotency, fresh-session inspection,
and cross-path completion evidence before its work can be accepted. Passing parity alone closes
neither stop. These are reviews at existing batch boundaries, not additional RFC cycles.

Batch 6 schema tests may use normalized facts before runtime exists; no availability strategy is
advertised until the connected implementation passes. No separate optimization spike is required.
If a concrete implementation question needs execution evidence, use the smallest targeted probe
inside its ticket; any separately chartered spike follows the existing protocol.

## 6. Mechanical Gates And Audit Disposition

H1-H12 below are the original H G1-G12; U1-U24 are U Section 14.1 unchanged in obligation.
Owners prefixed `new:` are proposed test files under `tests/testthat`, not existing coverage.
At ticket cut bind each row to an implementation owner from Section 3 or the named existing file.
No separate gate registry, witness framework, or copied spike expected-output ledger is created.

| Gate | Required detecting assertion | Test owner | Batch |
| --- | --- | --- | --- |
| H1 | Per-event derived fees conserve independently specified source fees | `test-fifo-torture.R` | 1 |
| H2 | Unequal reversal legs allocate pro rata in both directions; cash, basis, PnL/trades unchanged | `test-accounting-consistency.R` | 1 |
| H3 | Only `bt` formal; empty/populated full-schema tibble; removed arguments fail before reads | `test-fills-streaming.R` | 1 |
| H4 | Reopened nondefault-risk ranked candidate promotes with source sweep ID and selection order | `test-promotion-context.R` | 1 |
| H5 | Restoration explicitly restores both absent risk fields; base subset and persistence preserve identity | `test-sweep-persistence-roundtrip.R` | 1 |
| H6 | Direct/promoted recorded risk equals info hash; legacy absence stays NA; no read writes | `test-runner.R` | 2 |
| H7 | Close/read/owned-resource cleanup and new-session DONE open preserve evidence | `test-backtest-lifecycle.R` | 2, retained 4 |
| H8 | Executable named-target, review/promotion, and new-session journey | `test-documentation-contracts.R` | 2, 10 |
| H9 | Causal control passes; leaking feature rejected; disabling checker defeats rejection; eligible future-perturbation prefix unchanged | `test-features.R`, `test-precompute-features.R` | 4 |
| H10 | Caller RNG including absent seed, wide collision, explicit cleanup and targeted doc-lock replacements detect their own failures | `test-rng.R`, `test-sweep-retention.R`, `test-walk-forward-orchestrator.R`, `test-backtest-audit-log-equivalence.R`, `test-documentation-contracts.R` | 4 |
| H11 | Full suite after each move/extraction, including snapshot guards and resume/event order | `test-runner.R`, `test-runner-snapshots.R`, `test-acceptance-v0.1.0.R`, `test-acceptance-v0.1.1.R` | 3, 5 |
| H12 | Section 2.2 fault leaves committed fold intact, FAILED/message, and clean/resumed equality | `test-runner.R` | 4, before 5 |
| U1 | Version-qualified dense hashes/axis/events/metrics preserved across run/sweep/walk-forward | `new: test-availability-parity.R` | 7-9 |
| U2 | Future facts cannot alter earlier supported context/views/errors/telemetry; optional aliases/revisions deferred | `new: test-availability-causality.R` | 7 |
| U3 | Scalar, series, and cache strict-gap equality; unsupported indicator fails before strategy | `test-features.R`, `test-precompute-features.R`, `new: test-availability-features.R` | 7 |
| U4 | Identical ordinary strategy function works in dense and PIT modes | `new: test-availability-workflow.R` | 7-9 |
| U5 | Removed held member persists until literal zero | `new: test-availability-fold.R` | 8 |
| U6 | Empty axis invokes callback, accepts zero-length targets, preserves cash and portfolio state | `new: test-availability-state.R` | 7-8 |
| U7 | Stale risk mark never prices execution; source/age/reason recorded; no-mark positive target stops; risk hash unchanged | `new: test-availability-valuation.R` | 8 |
| U8 | Blocked zero then hold never exits later; fresh zero is a distinct attempt | `new: test-availability-fold.R` | 8 |
| U9 | Incomplete prefixes visible and ineligible across selection, save/reopen, and promotion | `test-sweep-persistence-roundtrip.R`, `test-walk-forward-orchestrator.R`, `new: test-availability-parity.R` | 9 |
| U10 | Future facts change snapshot/descendant identities without changing prior economic outputs | `new: test-availability-causality.R` | 7-9 |
| U11 | Direct/reopened/sweep/parallel/walk-forward parity including carried former member and FIFO basis | `test-sweep-parallel.R`, `test-walk-forward-orchestrator.R`, `new: test-availability-parity.R` | 9 |
| U12 | Section 4 public journey and identical reopened explanations without strategy execution | `new: test-availability-workflow.R`, `new: test-availability-parity.R` | 9-10 |
| U13 | Removal known after decision does not block purchase; informational flag and subsequent reduction-only holding | `new: test-availability-fold.R` | 8 |
| U14 | Complete omission is nonmembership; partial omission unknown; empty complete set survives sealing | `new: test-availability-facts.R` | 6 |
| U15 | Knowledge assumption hashes and labels; no-time/no-assumption row remains audit-only | `new: test-availability-facts.R` | 6-7 |
| U16 | Omitted/unknown/conflicting status have distinct effects; malformed facts block seal; retained conflict reopens identically | `new: test-availability-facts.R`, `new: test-availability-fold.R` | 6, 8-9 |
| U17 | Restricted/nonmember strategy and post-risk closure reject forbidden changes with typed reasons | `test-strategy-contracts.R`, `new: test-availability-fold.R` | 8 |
| U18 | Reserve held exposure; rejected sale funds nothing; accepted sale funds buy; ordering/tolerance reconcile or stop | `new: test-availability-affordability.R` | 8 |
| U19 | Horizon 0 and max+1, closures, last-valued/executed fields, prefix persistence | `new: test-availability-valuation.R` | 8-9 |
| U20 | Active selection excludes inadmissible IDs; unavailable sizing fails; dense warn-and-zero remains | `new: test-availability-workflow.R` | 7-8 |
| U21 | Unknown/omitted lifetime restricts nothing; inactivity blocks appropriately and held stale marks still age | `new: test-availability-facts.R`, `new: test-availability-valuation.R` | 6, 8 |
| U22 | Accepted terminal assertion preserves prefix, fabricates no settlement, and records unsupported economics | `new: test-availability-valuation.R` | 8-9 |
| U23 | Stable-ID history survives exit/re-entry; asset state resets, portfolio state survives, index lifetime is explicit | `new: test-availability-state.R` | 7-9 |
| U24 | Whole-feed outage retains pulses and breaks feature windows; missing/late calendar coverage fails typed | `new: test-availability-facts.R`, `new: test-availability-features.R`, `new: test-availability-valuation.R` | 6-8 |

Additional schema/recovery checks belong in existing `test-schema.R`, `test-schema-snapshots.R`,
`test-schema-validator-side-effects.R`, and `test-persistence-fresh-connection.R`: migration
rollback and old-row reconciliation; family/empty-header/quarantine tamper detection; deterministic
hashing under input reorder; INCOMPLETE reopening; controlled-prefix commit versus unexpected
fold rollback; interruption after completion evidence but before final projections. Inspect through
new connections. Wrong-source hashes, skipped bodies, or setup failures do not close a gate.

The first spec review adds these concrete regressions to the named owners; the 36 inherited RFC
gates remain required. These are packet tests, not another gate registry.

| Finding | Detecting fixture and assertion | Test owner and batch |
| --- | --- | --- |
| Short financing | Two eligible members, no risk chain, cash 50, both opens 100, zero costs, and targets -1/+1: typed rejection and no accepted fills or cash credit, in either target order. Also reject increased inherited short and long-to-short reversal; permit affordable cover/hold and an explicit long-only risk reduction to zero. Dense behavior is unchanged. | `new: test-availability-affordability.R`, batch 8; `R/fold-engine.R` and `R/strategy-contracts.R` |
| Quarantine lifecycle | One valid series plus one invalid OHLC row and one unknown-ID row: default rejects with no SEALED hash; explicit quarantine seals only valid bars, reopens the excluded originals, and passes hash verification. The known ID's expected session stays absent and cannot price a fill; the unknown ID never extends the axis. Changing an excluded payload changes the new snapshot hash; tampering fails verification. Malformed facts and conflicting duplicate bar keys still prevent sealing with quarantine enabled. | `new: test-availability-facts.R`, `test-schema-snapshots.R`, batch 6, connected runtime assertion batch 8; `R/snapshot_adapters.R` and `R/snapshots-seal.R` |
| Exception phase | Inject within the fold, then after fold commit but before the final projection/status commit using the same fixture. The former rolls back only the current fold transaction; the latter preserves committed ledger/state/completion. Both record FAILED and the original error. Retain H12's clean-versus-resumed equality. | `test-runner.R`, `new: test-availability-parity.R`, batches 4/9; `R/run-finalize.R` and `R/fold-engine.R` |
| Terminal idempotency | Finalize INCOMPLETE, then repeat the same-ID execution with a callback spy: zero invocations and identical stored rows/status. A mismatched identity fails. Separately fail projection finalization after an INCOMPLETE intent commits; recovery calls no strategy, preserves prefix rows, finalizes INCOMPLETE once, and its next invocation takes the terminal shortcut. Repeat with intended DONE. | `test-runner.R`, `test-persistence-fresh-connection.R`, batch 9; `R/run-registration.R`, `R/run-resume.R`, `R/run-finalize.R` |
| Affected exposure | At one stop, held quantities 10 and -4 and reference closes 100 and 50 yield gross 1200, not net 800. Use an expired first reference and verify its diagnostic label without a new equity row. A missing nonzero reference yields aggregate NA; duplicate reasons do not double-count; a zero quantity needs no mark; a later-known close is excluded. Reopened, sweep, and fold-score payloads agree. The negative holding is an algebraic diagnostic fixture, not a financed short trade. | `new: test-availability-valuation.R`, `new: test-availability-parity.R`, batches 8/9; `R/availability-results.R` and the shared fold's stop construction |

| Audit or horizon obligation | Disposition and detection |
| --- | --- |
| A T-1 | Batch 1, fills owner; H1 conservation separate from H2 allocation/economics |
| A T-2 | Batch 4, `R/features-engine.R`; H9 negative witness and gutted checker |
| A T-3 | Batch 1, `R/sweep-retention.R`; H5 explicit owner test, separate from H4 observed loss |
| A T-4 | Batch 4, lifecycle/integration fixtures; H7/H10 explicit close and expected warnings, fresh-session repeat |
| A T-5 | Batches 2/4/10, documentation tests/articles; retain API/schema/disclosure checks, retire identified editorial locks |
| RNG names lead | Batch 4, `R/snapshot_adapters.R` and eager reader; H10 preserves caller RNG and next draw |
| Wide names lead | Batch 4, `R/sweep-retention.R`; H10 reversible reserved-name mapping and unchanged candidate IDs |
| Threshold validation lead | Superseded by cursor/argument removal in batch 1; H3 includes empty results |
| September 4 documentation leads | Verify each affected example against final API in batches 2/10; route unrelated navigation/editorial work explicitly, without another all-vignette rewrite |
| September 6 CI lead | Deferred CI redesign; retain current gates and ordinary parallel-test execution outside covr |

Append executed outcomes and scoped dispositions to A during implementation. Do not label the
entire historical audit closed merely because some probes passed. Preserve U14.2's witness
dispositions: W12-W15/W30 fitted consumers deferred; W16/W29 deferred with optional families;
W18 bounded as Section 2.6; W20/W21/W31 superseded by their named implementation gates.

## 7. Verification And Release Surfaces

Capture a clean baseline before corrections and a corrected dense baseline before mechanical
moves. Run focused tests for each correction, then the full suite after each mechanical stage.
For new availability tests, distinguish independent expected economics, causal perturbations,
failure injection, and cross-path parity; agreement between two paths alone is insufficient.
Compare outputs under equal versions, and separately document intended version-bound changes.

The final release ticket must read the playbook and require full tests, installed README via
`Rscript --vanilla tools/check-readme-example.R`, package build/check with
`R CMD check --no-manual --no-build-vignettes`, `Rscript tools/check-coverage.R` at >=80%,
pkgdown via `dev/build-site.R`, and the local Linux/WSL gate for persistence and executable docs.
Use realistic timeouts; record skips, failures, reruns, R/package versions, and exact commits.
Ordinary parallel tests must run outside covr; a coverage skip does not prove backend parity.
Branch, main, and tag CI are separate evidence. This draft authorizes no tag or GitHub release.

Update `contracts.md`, NEWS, generated help/NAMESPACE, `_pkgdown.yml`, affected vignettes,
maintainer manual implementation traces, roadmap, horizon dispositions, and active packet pointers
with their owning batches. Add the new schema/identity choices to the identity reference. Do not
rewrite old packets or rename historical RFCs to match the new development branch.

## 8. Review Decisions, Ticket Cut, And Explicit Deferrals

The maintainer accepted this packet's resolutions of H Section 11 and U Section 15 on 2026-09-09:
(1) phase-specific failure handling, terminal idempotency, and finalization-only recovery;
(2) table/hash/migration, acknowledged quarantine, and EOD calendar encoding; (3) mandatory
committed decision trace and diagnostic gross-exposure definition; (4) finite-window indicator
declaration and state/index boundary; (5) the active short-exposure guard. The quarantine exception
and account-scope restriction amend U Sections 4.4/10.3 and 6.3, respectively; neither is silently
attributed to the earlier maintainer decision.
Exact private helper signatures, SQL index choices, and test fixture factoring may be refined in
tickets without changing these contracts. They are not another architecture cycle.

Keep aliases and per-observation revisions deferred; corrected vendor data creates a new snapshot.
Keep cash tolerance constant and defer configurable retention tiers and dynamic-matrix alternatives.
No generalized stale-index instrumentation, imputation/materialization graph, fitted preprocessing,
cross-sectional cache, calendar expansion, corporate-action settlement, shorting/borrow, OMS,
live recovery, broad adapter catalog, portfolio optimization, or new benchmark claim enters scope.
Carry P12's general negative-target and financing questions to the shorting seed. This packet binds
only its active-mode exposure guard; dense enforcement/defaulting and financing remain deferred.

The accepted cut creates `v0_2_0_0_tickets.md`, `tickets.yml`, `batch_plan.md`, and the packet
README, allocating LDG-2672 through LDG-2703. Keep Markdown/YAML statuses synchronized and add the
eventual closeout only at the release gate. The two RFC pipeline rows and design index identify
this accepted packet and its ticket-cut state without claiming implementation gates have passed.

The ticket-cut baseline is `048b925e5411b7c1a7500d4163163aed72039062` under R 4.5.2 ucrt on
`x86_64-w64-mingw32`, with duckdb 1.4.3 and dplyr 1.1.4. No named maintainer-owned store inventory
was supplied at cut. LDG-2684 must inventory those stores and affected wide artifacts before its
first shape edit and must not promise migration for an unnamed artifact.

## 9. Review Focus

- Can controlled-stop and finalization tests distinguish rollback, a committed prefix, and DONE?
- Do schema, calendar, knowledge, hash, and feature choices preserve U's information boundaries?
- Can the public ingest/run/explain/reopen journey work without hidden joins or strategy replay?
- Are all H/U gates and audit obligations owned, without weakening dense behavior or test gates?
- Are corrections, extraction, availability, teaching, and deferred optimization clearly separated?
- Do the explicit quarantine and short-scope amendments close the review findings without implying
  that invalid rows are tradable or that general short financing is supported?

**Revision history:**

- 2026-09-09 -- initial draft at `048b925`, published as `8153f7d`; no implementation or new R
  execution. Final-review evidence is attributed to its recorded authors.
- 2026-09-09 -- address the first spec review's two High and three Medium findings: propose the
  active short-exposure guard and acknowledged quarantine lifecycle; distinguish fold/finalization
  exceptions, achieved terminal return/finalization recovery, and diagnostic gross exposure. Add
  detecting fixtures and reviews at batches 8-9. Link the draft from both RFC rows without claiming
  acceptance. Documentation-only changes; no new R execution. Awaiting maintainer/spec review.
- 2026-09-09 -- maintainer accepted the reviewed packet, including the quarantine and active
  short-exposure amendments. The accepted wording also distinguishes unsupported short-account
  financing from shipped non-goals and defines affected exposure from observations accepted at the
  cutoff. Cut LDG-2672 through LDG-2703 and aligned active governance pointers. No implementation
  gate is claimed passed by ticket cut.

[hardening]: ../rfc/rfc_api_representation_hardening_v0_2_0_synthesis.md
[availability]: ../rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md
[contracts]: ../contracts.md
[cycle]: ../rfc_cycle.md
[protocol]: ../spike_protocol.md
[styleguide]: ../vignette_styleguide.md
[release]: ../release_ci_playbook.md
[roadmap]: ../ledgr_roadmap.md
[horizon]: ../horizon.md
[audit]: ../audits/v0_2_0_test_suite_audit.md
[probe]: ../../../dev/spikes/api-representation-hardening/probe_findings.md
[review]: ../rfc/rfc_api_representation_hardening_v0_2_0_synthesis_review.md
[gut]: ../../../dev/spikes/api-representation-hardening/review_gut_fold_rollback.R
[previous-hardening]: ../ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md
[previous-release]: ../ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md
