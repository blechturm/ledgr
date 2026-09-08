# RFC Seed v2: Asset Availability And Point-In-Time Universes

## 1. Status And Authority
**Status:** Stage 5 Seed v2, maintainer accepted for synthesis. Non-binding.
**Author:** Codex, returning under `../rfc_cycle.md` role rotation.
**Date:** 2026-09-08.

This incorporates the reviewed response and addendum, maintainer-approved
policy, and reviewed terminal spike report. It supersedes Seed v1 under review
while preserving earlier artifacts as history.

Disposable spike commit `d59259f` remains on
`spike/asset-availability-pit-universes`; its report and policy v4 live under
`dev/spikes/asset_availability_pit/` and must never merge.

No package API, schema, runtime, accounting, ticket, or spec is authorized.

## 2. Evidence And Disposition
The empirical Sharadar work established changing point-in-time membership and
showed that static instrument input distorts the tested reference population.
It did not establish rates for missing expected bars, reliable lifetimes from
price bounds, delisting economics, or broad-equity strategy performance.

The spike closed inconclusive after testing one provider boundary across three
physical representations. All passed the same ten witnesses; 21 witnesses,
the empirical workload, user journeys, and retention costs were not tested.
No timing/memory ranking is admissible, and no representation was selected.

The surviving direction keeps dense execution unchanged without new facts or
policies; separates identity, membership, observation, valuation, execution,
and features; keeps source facts immutable, point-in-time, and hash-bound;
builds bounded views without fabricated observations; and preserves one fold
and target contract while exposing unavailable or incomplete evidence.

Sparse effective-dated facts plus bounded fold-local views remain the
architectural prior because they separate evidence from computation. This is
judgment, not a measured winner; exact encodings remain spec-cut choices.

## 3. Problem And Boundary
Offline research must distinguish not-yet-knowable, non-member, unexpected,
missing, halted, stale-but-valuable, unpriced, and terminated assets. One
rectangular `NA` cannot carry these meanings without leakage or ambiguity.

This RFC excludes live-feed recovery, OMS persistence, arbitrary order
lifetimes, multi-venue scheduling, terminal settlement, corporate actions,
general imputation, and ML lifecycle; they remain sibling or later designs.

## 4. Logical Fact And State Contract
Source facts independently cover stable identity and aliases, lifetime,
point-in-time membership, venue sessions, observations/revisions, and status.

Observations keep the established convention that their bar timestamp is also
knowledge time when no availability field is declared; legacy payloads omit
that field. Membership, lifetime, status, and revision facts require evidenced
knowledge time or an identity-bearing assumption because their effective and
known times may differ. Otherwise they stay audit-only; assumption-backed
results are labelled, not claimed as evidenced point-in-time research.

Membership input declares complete snapshots or partial updates. Omission from
a complete snapshot means nonmembership for that effective state, visible only
at its knowledge cutoff; omission from a partial update remains unknown.
Unknown establishes nothing itself, though another plane may establish held or
observed state. Invalid/not-yet-knowable rows stay audit-only at that cutoff.

The engine derives consumer state. Users do not author internal `observed`,
`accepted`, `priced`, `mark_age`, `target_restricted`, feature-validity, or
execution-eligibility planes. Lifetime, membership, expectation, observation,
status, valuation, features, and execution remain independent.

Universe selection and availability are orthogonal: fixed baskets may have
missing or halted observations, while changing membership may be complete.
Configuration must not infer policy from a vector-versus-rule input shape.

## 5. Representation-Neutral Fold Boundary
One provider interface resolves facts at a cutoff, builds decision and later
execution views, supplies bounded history, and reports identity. Targets, risk,
affordability, fills, FIFO accounting, metrics, and evidence stay in the shared
fold; physical representations sit behind it, never as another engine.

The public axis is the chosen, not inevitable, union of current members and
non-zero holdings. Synthesis binds deterministic order and target/event
consequences. No supported strategy, helper, transform, error, or cache query
may reveal a future member before it is knowable and effective.

Opening state, `ledgr_lot_state_asof()`, and initial positions use that axis,
preserving former-member quantity and basis into the next fold. Membership
filtering also covers `ledgr_pulse_wide()`, `ledgr_pulse_features()`,
`ledgr_feature_contracts()`, telemetry, errors, and worker diagnostics.

Threat model covers ledgr interfaces, not user R, globals, processes, or clocks.

## 6. Strategy And Target Contract
The strategy remains `function(ctx, params)` returning one full named numeric
target vector. Existing dense strategies remain valid.

- `ctx$members` is the point-in-time investment cross-section.
- `ctx$universe` is `members union held`, and remains the position and target
  domain.
- ranks and weights use `ctx$members`; constructors bridge to `ctx$universe`
  and initialize holdings to current quantity before sizing.
- zero means desired quantity zero; removal never liquidates automatically.
- a failed exit creates no persistent intent; retry requires a new target.

An unrestricted held non-member may be held, zeroed, or reduced without crossing
zero. A restricted ID admits current quantity or zero. Post-risk accepts zero
or a same-sign target no larger than the strategy target. New/increased
ineligible exposure and sign reversal fail with typed conditions.

With availability policy active, `ledgr_target_rebalance()` raises a typed
sizing error when a selected ID lacks a positive accepted current close;
unavailable data never becomes zero. Dense execution retains today's
warn-and-zero behavior; activation is declared, not inferred from axis equality.

Empty members with holdings preserve them. On an empty axis, strategy runs on
an empty public domain and may return a named zero-length numeric target; W26
and W27 require a cash-only result with no target rows or fills and preserved
portfolio-level state.

Positional indices are pulse-local and cannot be cached across pulses. The spec
chooses stale-reference detection; W18 was not executed. Asset state uses stable
IDs, survives membership changes while held, and follows a declared lifecycle.
Adding `ctx$members` or availability fields changes the Context Contract.

## 7. Budget, Risk, Execution, And Valuation
Seed v2 adopts policy v4 for the first bounded implementation:

- reserve held-nonmember marked exposure before sizing members;
- do not release that reserve because a sale was merely requested;
- let only accepted executable sales fund same-pulse purchases;
- evaluate whole-fill affordability deterministically before mutation;
- emit fills in validated target order and reconcile cash under one tolerance.

This is bounded affordability, not margin, settlement, or an OMS. Alternative
financing requires a separately named policy.

For a held ID without an accepted decision-time observation, `ctx$vec$close`
is `NA`. A separate permitted stale valuation mark may value that holding or
support a reducing risk step while the strategy-visible close stays `NA`; it
never prices a fill. A new target whose risk step needs a missing mark stops
before mutation with `risk_mark_unavailable`.

Refining policy v4's comparison-fixture rule, trading-status gating applies only
when the snapshot declares that fact family. Without it, an accepted execution
bar retains dense eligibility; canonical omission, not a default-valued field,
binds that absence and the effective plan discloses disabled status checks. With
the family present, status, execution price, and affordability are ordered
gates; per-ID absence is `status_unknown`, conflict is typed no-fill, and price
alone never asserts active status. Blocked opportunities create no hidden order.

Dropped fill proposals require typed diagnostics. Equity or position value
may not become `NA` without an explicit `unpriced` state.
Dense parity preserves today's silent fill-drop and `NA`-equity branches only
by proving them unreachable; the ragged specification must remove or diagnose
every reachable path.

A stale valuation horizon is explicit, clocked, and identity-bearing; the
two-session spike fixture is not a universal default. Exhaustion stops before
the next decision or mutation, preserves prior events, and reports intended
and achieved horizon, affected exposure, last fully valued metric time, and
last event time. Unknown lifetime is not a stop reason. Terminal events use a
separate accounting reason; an accepted event without representable settlement
stops as `terminal_settlement_unsupported`. The earlier F-11 use of
`unresolved_terminal` for unknown lifetime is retired.

Prefix metrics remain visible but incomplete. Sweep and walk-forward selection
exclude them from equal-horizon comparison and show the exclusion.

## 8. History, Features, Identity, And Causality
History remains keyed by stable ID across entry, exit, and re-entry. Earlier
history is usable only when knowable at decision and admitted by lifetime,
calendar, revision, classification, and observation rules.

The first slice uses expected-session windows with strict gap propagation. A
missing or invalid required observation makes its feature unavailable; it is
not skipped, carried, imputed, or replaced by a valuation mark. Availability
recovers only after a complete required window. Scalar, series/precomputed, and
cached paths agree. Indicators without a declarable required window, or with
internal carry/imputation, are unsupported and fail typed before strategy use.
Feature usability stays consumer-specific; other consumers name their clocks.

Fitted preprocessing and ML fitting are outside the first implementation. A
future contract must distinguish retrospective in-sample diagnostics,
transforms fit before a scored interval, causal rolling or expanding refits,
and untouched outer evaluation. Each inner candidate-selection boundary needs
its own fit at that boundary's information cutoff. Every fitted artifact binds
availability, input/revision cutoff, label maturity, population, RNG, and use.
Historically knowable membership is the default population; broader causal
populations require an identity-bearing override.

Snapshot identity binds source facts. The declared calendar set, universe,
classification, history, valuation, execution, and fitted policies bind
descendants. Consulting a valuation plane does not change `risk_chain_hash`;
valuation-policy identity carries that difference. Adding a future fact changes
descendant identities but not earlier outputs: causality and byte identity are
different tests.

Lineage and classification-input digests live in hashed fact tables or the
hashed instrument payload, never only in the `snapshots` envelope. Adding fact
families versions the snapshot-hash combination rule while preserving legacy
dense hashes.

Recipe identity belongs in candidate identity. Fitted state has a separate
digest and enters only downstream identities. Instrument-local cache keys or
fingerprints also bind admissible-history, calendar, classification, and
stale-input policies; cross-sectional and fitted nodes use separate families.

Under identical declared identity and version inputs, existing dense semantic
payloads stay byte-identical when no new facts or policies apply. Required
package, schema, or engine versions may change; cache-engine fingerprints must
change when semantics do. Do not add a default-valued mode field.

## 9. Ingestion And Usability Contract
Methodological complexity belongs at the adapter boundary, not in every
strategy. A user normally supplies bars, stable IDs, dated membership, and
whatever lifetime, status, calendar, or revision facts the source genuinely
provides. Missing evidence remains unknown.

Adapters normalize vendor fields outside the fold. The first implementation
must include:

- one provider-shaped, redistributable end-to-end fixture;
- concise constructors for interval and dated-snapshot membership;
- pre-seal validation for unknown IDs, overlaps, contradictions, malformed
  intervals, membership completeness, and knowledge-time treatment;
- a dry-run report of accepted, rejected, quarantined, and unresolved facts;
- no requirement to fabricate evidence to complete a table; and
- an example that never constructs internal state planes directly.

Acceptance journey: a user with bars, stable IDs, and membership with evidenced
knowledge time or a disclosed assumption can ingest, seal, run an ordinary
helper strategy, explain a retained holding and blocked fill, reopen, and
recover the same explanation without internal joins. It shows target, blocker,
unchanged position, valuation age, completion status, and the effective plan,
including whether status checks are absent under Section 7.

This binds the workflow, not a Sharadar-specific API or broad adapter catalog.

## 10. Explainability And Teaching
Evidence joins source to outcome: member/held reason, feature/preprocessing
identity, quantity, pre/post-risk targets, risk reason, execution, fill/no-fill,
resulting position, and valuation source/age.

Decision views obey the cutoff. Retrospective views may show the full axis and
later transitions only when labeled and inaccessible to strategy execution.
Episode summaries may not merge separate target attempts or imply persistent
orders. Persist execution/no-fill and stop evidence needed to explain economic
state; deterministic availability views may be reconstructed from sealed facts
and identity-bound policy. Exact retention tiers remain a spec decision.

The method belongs in a broader survivorship-bias article. It teaches
current-constituent bias, complete-case bias, the point-in-time workflow, and
its limits. It must say ledgr prevents named leakage paths; it does not
eliminate survivorship bias without trustworthy membership, identity,
terminal-event, corporate-action, and revision evidence.

## 11. Initial Scope And Deferrals
The first specification may cover one end-of-day venue calendar, stable asset
identity, point-in-time membership, explicit status and observation evidence,
held-former-member continuity, bounded stale valuation, no-fill diagnostics,
and direct, reopened, sweep, parallel, and walk-forward parity.

Deferred: multi-venue and subdaily scheduling, live bad-data recovery, GTC and
OMS behavior, margin and settlement, corporate-action and terminal-event
accounting, general short accounting, fitted preprocessing, ML APIs and
imputation, cross-asset defaults, and broad provider adapters.

Resolved terminal economics remain blocked on the accounting-critical-event
sibling. An incomplete prefix may be disclosed but not presented as complete
performance.

## 12. Gates Before Specification
Before a spec packet or tickets, synthesis must bind tests for:

1. byte-identical current dense behavior and identities;
2. no future membership/alias visibility and strict-gap feature-path parity;
3. the same strategy running in dense and point-in-time modes;
4. held non-members surviving removal without unintended liquidation;
5. stale marks valuing but never executing;
6. no-fill without hidden retry;
7. incomplete evidence remaining visible and selection-ineligible;
8. earlier-output invariance under future-fact perturbation;
9. direct, reopened, sweep, parallel, and walk-forward parity; and
10. the Section 9 ingestion acceptance journey.

No representation-performance claim is required for the bounded semantic
implementation. Any later scale claim needs a new probe under
`../spike_protocol.md`, with one question and a production-shaped path.

## 13. Remaining Decisions And Next Step
No separate decisions artifact is required before review. Policy v4 closes
budget/removal, restricted targets, source-row handling, risk marks, population,
and stop behavior. This revision binds knowledge assumptions, strict feature
gaps, sizing failure, and empty axes. Horizon length remains identity-bearing
without an RFC default. Synthesis binds names, one-venue scope,
constructors/context, axis order, and the acceptance journey; spec binds
encoding/matrix disposition, schema, and retention.

Claude now reviews Seed v2 against prior RFC artifacts, policy v4, the terminal
report, research, `../contracts.md`, and current code. After acceptance, Claude
authors synthesis and Codex performs final review.
