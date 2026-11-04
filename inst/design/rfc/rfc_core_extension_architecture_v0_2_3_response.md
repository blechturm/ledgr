# Core Extension Architecture: Type 2 Response

**REVISE.** Keep one fold, typed boundaries and explicit ownership. Replace
the promise that every capability changes one stage with a requirement that
each extension names its affected owners and preserves the other contracts.
The proposed pipeline is a useful responsibility map, but neither a complete
trading architecture nor a justified set of new abstractions to implement now.

Mode: Type 2, RFC response; Codex, 2026-11-04. Maintainer-approved brief,
drafted by Claude. Non-binding recommendations. Reviewed release head:
`6ef58138271501af801355939b1da26678961bf2`; initial worktree clean.
Evidence is source and record inspection, not execution or performance proof.
No probes, full tests or package check were run.

Citation paths are repository-relative at that head. Aliases:

- `C` = `inst/design/contracts.md`.
- `Seed` = `inst/design/rfc/rfc_core_extension_architecture_v0_2_3_seed.md`.
- `OMS` = `inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`.
- `Records` = `inst/design/rfc/rfc_per_pulse_durable_records_v0_2_3_synthesis.md`.
- `Skeleton` = `inst/design/rfc/rfc_lean_core_skeleton_v0_2_3_synthesis.md`
  (draft, not accepted).
- `Horizon` = `inst/design/horizon.md` (non-binding).

**Framing finding.** The one-stage test (`Seed:35`, `Seed:167`, `Seed:173`)
would reward hiding dependencies rather than containing them. Even the
skeleton's four-row map names multiple owners per capability (`Skeleton:139`).
Shorting already meets checks in P2 and planning (`R/fold-engine.R:1016`,
`R/availability-economics.R:425`); new accounting sources also affect writers
and readers (`C:540`, `C:557`). These are legitimate shared semantics.

Ask instead: *Which boundaries must remain stable, and what is the smallest
coherent change that adds a contracted capability through the one fold?*
Preserve the full-target strategy boundary, causal observation, authoritative
accounting and common publication/reconstruction. Do not promise arbitrary
feature completeness: strategies that directly manage orders are deliberately
excluded by `OMS:83`. Extension should mean package-owned, reviewed additions,
not a public plugin interface.

**1. Sub-stages: name responsibilities now; retain P3 with helpers.**
There is no need for a pipeline registry, one carrier class per box, or unused
liquidity/OMS functions. Extract a helper when it owns an actual invariant or
has another caller, following
`inst/design/manual/optimization_coding_style.qmd:132`.

Correct the ownership map first. Risk runs in P2 (`R/fold-engine.R:1013`);
P1 settles non-fill dispositions before decisions (`C:545`); P3 delegates
planning (`R/fold-engine.R:1117`). Thus `Seed:111` is inaccurate. Under
[Fold Core](../contracts.md#contract-execution-fold-core), P1 remains the
substrate reader and P3 receives execution columns, not access to tiles
(`C:135`, `C:177`). Preserve D1's minimal order-shaped handoff; do not duplicate
it in a second intent object merely to match the diagram (`Skeleton:86`).

Also leave cost/liquidity composition open until its RFC. A notional fee uses
quantity (`R/cost-model.R:423`); clipping a priced 100-unit proposal to 25 units
cannot retain that fee unchanged. Fixed fees have different behavior
(`R/cost-model.R:421`). The north star explicitly leaves this split open
(`inst/design/rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md:87`).
Require final fees/effects to match final fills; do not install a generic
repricing loop now. Today's cost-before-affordability order stays unchanged.

**2. OMS: reconcile conflicting obligations in this cycle, before code.**
An accepted synthesis should explicitly supersede the affected OMS clauses,
with the notices required by `inst/design/rfc_cycle.md:79`. Keep two streams,
immutable links and lifecycle meaning. Replace ledger JSON back-links
(`OMS:211`) with typed fields when OMS lands, under
[Accounting Events](../contracts.md#contract-execution-accounting-events)
(`C:550`, `C:557`). Also replace the proposed lifecycle metadata escape hatch
(`OMS:156`, `OMS:161`) with contracted typed evidence as each field becomes
necessary. Do not create the columns now.

String enums are not themselves the problem: the typed-accounting synthesis
retains textual event/source tokens and checks
(`inst/design/rfc/rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md:77`).
Closed validated values matter; universal integer coding does not.

The reconciliation is wider than JSON. `OMS:566` requires a diagnostic feature
flag, while `OMS:401` places retention outside fold logic. Resolve this as one
semantic path with output retention, not an alternative execution branch.
`OMS:411` also cannot justify regenerating decisions by executing strategy
code: `Records:63` forbids it. Preserve existing public behavior and leave
concrete order storage/retention to the OMS cut under these corrected rules.

**3. Accounting: shared primitives, explicit economic rules; not one model
per asset class.** Signed lots support short positions, but do not supply
borrow, collateral or maintenance policy (`C:1348`, `Horizon:1579`). Margin is
also a portfolio constraint, not just a different lot operation. Keep the
common signed-book operations wherever their mathematics applies; give new
settlement, valuation and financing rules named owners in the same fold.

Do not use `compiled_accounting_model` as the general economic-policy selector.
It currently chooses a restricted accelerator (`C:568`), while lot selection
is explicitly orthogonal to compilation (`Horizon:1550`). A future mixed-asset
portfolio must not need separate runs to combine accounting rules.

The stronger promise that the kernel can never change is unsupported. Its fill
validator requires positive prices and distinct positions per call
(`R/lot-accounting.R:323`); publication computes spot principal exchange
(`R/ledger-writer.R:7`). Signed quantity alone does not prove futures settlement
or a future non-positive-price contract. Narrow D1's guarantee to reuse of
applicable primitives and no duplicated engine; keep today's FIFO unchanged.
The cross-asset RFC must settle each new economic model, not this response.

**4. Cash: retain the scalar now.** A currency vector without FX valuation,
settlement currencies, conversion policy and available/reserved balances buys
little. Today's cash effects and affordability are explicitly scalar
(`R/ledger-writer.R:12`, `R/availability-economics.R:343`). Preserve their exact
arithmetic. Centralize existing economic computations, but add no unused
currency machinery or speculative term defaults (`Seed:144`).

Section 4.5 should admit the later affected owners: opening state, P1 valuation,
sizing, affordability, publication, replay and result currency disclosure.
Reconstructed equity must still equal recorded equity
([State Reconstruction](../contracts.md#contract-result-reconstruction),
`C:2906`). A function family does not make those interfaces disappear.

**5. Intra-bar triggers: possible causally, but a new timing contract.**
An order fixed before an execution interval can use that interval's OHLC to
simulate an outcome, provided none reaches its originating decision. P1 already
passes next-bar OHLC privately (`R/fold-engine.R:610`); P2 receives only the
observation (`R/fold-engine.R:1878`). A close-time decision cannot use the
same bar's earlier high/low to claim a retroactive fill.

This does not permit changing next-open behavior. Under
[Provider, Knowledge And Timing](../contracts.md#contract-availability-provider-and-timing),
facts obey effective and knowledge time (`C:1257`), and declared-session fills
currently occur at the next opening (`C:1269`). The future RFC must define
order activation, gap prices, ambiguous stop/limit ordering, trailing updates,
same-bar bracket activation, fact cutoffs, event time and recording pulse on
both clocks. OHLC alone supplies no observed intra-bar ordering. Use an explicit,
identity-bearing conservative convention or refusal, never invent an exact
trigger time. The existing horizon identifies that unresolved policy
(`Horizon:1519`). No extra pulse delay is inherently required by causality.

**6. Outstanding orders: a state slot is necessary, not sufficient.**
Two current assumptions must remain local and revisable at the OMS cut:

- Scheduled skips bypass P3 (`R/fold-engine.R:1915`). Outstanding orders must
  still be eligible to fill, expire or cancel without a fresh strategy call.
- Plans and lot calls require distinct instrument positions (`C:282`,
  `R/lot-accounting.R:324`). Multiple fills for one instrument require ordered
  operations/blocks; they must not be merged merely to fit today's batch.
  OMS already specifies multiple ordinary FILL rows (`OMS:506`).

These are changes to scheduling and application boundaries as well as fill
resolution. Explicitly qualify the skeleton locality claim (`Skeleton:139`);
do not implement generalized scheduling or repeated-position batches now.

Later, retain typed order identity, originating decision, lifecycle transitions,
remaining quantities and accounting links, including cancellation/expiry with
no fill. Derive outstanding state from that stream, not from net holdings or
strategy state (`OMS:83`, `OMS:91`). Net outstanding quantity supports target
translation (`OMS:110`), but cannot replace per-order state or reservations.
Per-pulse records preserve exact associations and irreducible intent; omitted
physical rows need a proved decoder (`Records:73`, `Records:141`). Include
cross-stream failure/commit behavior so a lifecycle fill never survives with
its accounting effect missing.

Resume-free research reconstruction is a read of recorded evidence. Research
restart from pulse one is a different operation (`Records:189`). It must not
become a live recovery policy that resubmits external orders.

**7. Core line: proceed without waiting for WS11; do not pre-empt it.**
This cycle may fix internal ownership and use Section 3 as extension scenarios.
It should not bind every listed capability to core ownership or delivery.
The roadmap requires measured coupling/public-seam evidence before the
core-boundary ADR (`inst/design/ledgr_roadmap.md:185`). An internal closed
dictionary is not a public seam sister packages may call. WS11 retains that
decision. Waiting for its final package list would unnecessarily block the
already-required extension review; directing it to adopt this list would
reverse its evidence requirement.

**8. Missing: autonomous events, policy input and external execution truth.**
Add these as design scenarios, not new infrastructure:

- Protective-order parameters need a contracted declaration/identity surface;
  an order-type code cannot express stop levels or bracket relationships.
  The corpus already identifies this gap (`Horizon:1531`). Preserve target
  functions; do not promise arbitrary order-management strategies.
- Accruals, maintenance actions, expiry/settlement and corporate actions must
  run without new targets. Existing P1 settlement proves that economic events
  do not all enter through P3 (`C:141`, `C:545`; accrual gap `Horizon:1556`).
  Time-varying terms must use causal facts, not a timeless per-instrument
  default (`C:1257`).
- Paper/live needs ordered external observations, reconciliation and durable
  submission identity, not only a replacement simulator. OMS already requires
  pre-submission gates and reconciliation (`OMS:444`, `OMS:448`, `OMS:460`).
  A broker-reported fill cannot be discarded by simulated affordability or
  silently repriced by the research cost chain. Separate proposal policy from
  observed execution truth at typed boundaries in the same fold. Duplicate,
  late and correction events and recovery need their own contract; OMS
  explicitly defers corrections and live restart (`OMS:549`). Keep async I/O
  at the edge (`Horizon:1186`) without claiming that this alone solves them.

These scenarios expose limitations; they do not prove a second engine is
needed. Nor can this review guarantee that no later kernel revision will be
needed. One fold is a constraint on shared semantics, not a promise that its
current event grammar is final.

**Procedure correction.** Replace Section 5's one-stage test with an affected
owner/contract map covering production, reconstruction, identity and failure
ordering. A dictionary entry gets a direct ticket only when its semantics are
already accepted: cross-asset kinds explicitly require their own focused RFC
(`inst/design/rfc/rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md:362`;
`inst/design/rfc_cycle.md:330`). Narrow the callback ban to new execution-policy
hooks; strategies already run inside the fold (`C:105`). Retain A2 budgets and
A4 subtraction review
(`inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md:413`, `:428`).
Revise the seed and reconcile D1/skeleton obligations before acceptance and
coding. None of these recommendations changes shipped contracts or the lean
core's required public parity.
