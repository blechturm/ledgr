# Core Extension Architecture: Decision Synthesis

**Adopt v2's affected-owner design:** one fold, fixed semantic boundaries,
closed typed mechanisms, and a contract-first procedure. Reconcile the OMS
obligations now. Narrow skeleton D1; the maintainer accepted that
amendment on 2026-11-04. Add no capability or column and
change no public behavior. WS11 retains the core-versus-sister decision.

- Role: record; RFC cycle stage 7, **Decision synthesis**. Codex, 2026-11-04.
- Status: **accepted** by the maintainer on 2026-11-04, after the independent
  Type 1 final review (PASS_AFTER_PATCHES, P1-P5 applied). Acceptance
  installed the Section 5 OMS amendment and the Section 6 D1 and skeleton
  amendments. Sections 2-5 and 7 state the proposed binding scope; Section 6
  is the D1 and skeleton amendment the maintainer accepted on 2026-11-04.
- Brief: drafted by Claude, approved by the maintainer on 2026-11-04.
- Final-review patches, 2026-11-04: the
  [Type 1 final review](rfc_core_extension_architecture_v0_2_3_final_review.md)
  (independent Claude session, PASS_AFTER_PATCHES) P1 to P5 applied in place:
  the skeleton 2.1 block keeps its first-checkpoint and no-baked-policy guard,
  the OMS table covers OMS 12 item 10 and 13 item 14 and no longer sweeps in
  7.2, the unchanged row names skeleton Sections 6-7 and D1's retained text,
  and the D1 wording records the maintainer's decision.
- Inputs: [seed v1](rfc_core_extension_architecture_v0_2_3_seed.md),
  [response](rfc_core_extension_architecture_v0_2_3_response.md),
  [response review](rfc_core_extension_architecture_v0_2_3_response_review.md),
  and [seed v2](rfc_core_extension_architecture_v0_2_3_seed_v2.md).
- Source baseline: release head `ad28374a98bbbbf4ae417d47e39b3aae588f9901`,
  detached `extension-synthesis` worktree, initially clean. All file:line
  citations refer to this head, not the earlier response's baseline or the
  lean core's eventual reference pin.
- Citation aliases: **C** = `inst/design/contracts.md`; **Macro** =
  `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`. Under `inst/design/rfc/`,
  **OMS** = `rfc_ledgr_oms_seed_synthesis.md`, **Skeleton** =
  `rfc_lean_core_skeleton_v0_2_3_synthesis.md`, **D** =
  `rfc_lean_core_skeleton_v0_2_3_maintainer_decisions.md`, **Core** =
  `rfc_lean_fold_core_v0_2_3_synthesis.md`, and **Records** =
  `rfc_per_pulse_durable_records_v0_2_3_synthesis.md`.

## 1. Decision And Scope

An extension is a package-owned, reviewed addition through the common fold.
It may touch several owners. The test is whether those changes are necessary,
explicit and preserve the other contracts. Short exposure already has owners
in P2 and P3 (`R/fold-engine.R:1013-1016`,
`R/availability-economics.R:425-436`). A one-stage test would hide that rule.

This is an internal architecture decision, not a public plugin API or a
promise of arbitrary trading-strategy support. Strategies that manage orders
directly remain excluded (`OMS:77-83`). Seed v2's capability table is a set
of design scenarios, not a delivery list. The measured core-boundary decision
stays with WS11 (`Macro:574-580`; `inst/design/ledgr_roadmap.md:185-194`);
internal dictionaries are not public seams for sister packages.

Contracts prevail. Canonical R remains the executable oracle for optimized
paths; conflicts use [Core Section 5 and A3](rfc_lean_fold_core_v0_2_3_synthesis.md#5-reference-and-switch-proof-d4-q2)
(`Core:204-208`, `:420-426`). No oracle or expected result is silently changed.
Acceptance does not implement a capability, alter the current event grammar,
change identity or storage, or authorize production integration. D2 and
WS16 still require acceptance and any skeleton amendment before lean-core
code (`D:46-48`, `Macro:674-680`).

## 2. Fixed Boundaries And Present Owners

Adopt v2's boundaries with two clarifications: the strategy rule includes
existing wrappers, and snapshot trust is explicit rather than implicit.

| Boundary | Binding rule and authority |
| --- | --- |
| One fold | Run, sweep, walk-forward and later paper/live share semantics. No second engine or new execution-mode/feature-flag branch. Retention acts after the common semantic result. [Entry points](../contracts.md#contract-execution-entry-points), [Fold core](../contracts.md#contract-execution-fold-core) (`C:88-123`); `OMS:85-91`. Run and sweep already call `ledgr_execute_fold()` (`R/backtest-runner.R:939`, `R/sweep.R:1827`). |
| Strategy | `function(ctx, params)` supplies full named numeric targets, directly or through the existing helper/structured return normalization. Missing targets never mean zero. No order handles, lifecycle or broker state enter the strategy. [Strategy outputs](../contracts.md#contract-strategy-outputs) (`C:1749-1768`); `OMS:83`. |
| Causality and trust | Preserve snapshot creation, sealing, identity and hash verification. P1 alone reads the substrate; P2 sees its cutoff-bound decision view, never the private execution packet; P3-P5 receive typed columns, no history/substrate handle. Both effective and knowledge time apply. [Snapshot verification](../contracts.md#contract-snapshot-identity-and-verification) (`C:884-904`), [Fold core](../contracts.md#contract-execution-fold-core) (`C:135-184`), [Provider and timing](../contracts.md#contract-availability-provider-and-timing) (`C:1257-1274`). |
| Accounting | One ordered typed `ledger_events` table is accounting truth. Every arm handles every declared kind or refuses before accounting. Economic effects are computed once and published unchanged; no JSON accounting evidence. Lifecycle has a separate stream. [Accounting events](../contracts.md#contract-execution-accounting-events) (`C:525-563`); `OMS:89-91`. |
| Ownership, publication and reads | Preserve exclusive mutable ownership, frozen retained views, event order and failure prefixes. Reconstruction equals recorded state; reads run no strategy/indicator/risk/cost callback and write no persistent tables or caches. [Typed fold carrier](../contracts.md#contract-execution-fold-carrier), [State reconstruction](../contracts.md#contract-result-reconstruction) (`C:2914-2926`); `Skeleton:269-281`, `Records:63-69`. |

Keep E and P1-P5. E sequences execution, owns fold-state slots and installs
stops. P1 observes, settles non-fill events and values holdings. P2 validates
strategy targets, applies risk and validates post-risk/short exposure. P3
plans against settled holdings and owns fill timing, costs, affordability
and its short refusal. P4 applies ordered lot operations and installs and
publishes effects. P5 reconciles, records and flushes. On today's scheduled
skip, P1/P4/P5 run and P2/P3 do not (`C:141-156`, `:545-548`;
`R/fold-engine.R:1117-1128`, `:1915-1927`). Future outstanding orders must
explicitly amend that scheduling contract; this RFC does not do so.

P3 stays one stage with helpers. Extract a helper for a real rule or another
caller, not a diagram (`inst/design/manual/optimization_coding_style.qmd:132-136`).
Keep the skeleton's one order-shaped plan/apply handoff, including today's
resolved fills and refusals (`Skeleton:93-99`). No second intent carrier,
stage registry or unused OMS/liquidity functions are authorized.

## 3. Mechanisms And Their Limits

1. **Closed values and typed evidence.** Validate order types, time-in-force,
   event kinds, lot policies and terms against their contracted vocabulary;
   unknown values fail closed. Text tokens are valid: integer encoding is
   not a universal requirement. Add a typed field only when its semantics
   are contracted. No generic metadata or JSON extension envelope. This
   does not remove existing contracted JSON representations elsewhere.
2. **Owned state.** Cross-pulse execution state gets declared typed fold-state
   slots. Outstanding orders derive from per-order lifecycle evidence, not
   net holdings or strategy state. Net outstanding quantity supports target
   translation but cannot replace order identity, remaining quantity or
   reservations (`OMS:103-113`). State, scheduling, batching and recording
   must be designed together.
3. **Shared arithmetic, named economics.** Reuse signed-book operations where
   their arithmetic applies. Settlement, valuation, financing and portfolio
   affordability keep named owners in the same fold. Mixed assets do not
   require separate runs or per-asset kernel copies. `compiled_accounting_model`
   selects an accelerator, not economic policy ([Compiled accounting](../contracts.md#contract-execution-compiled-accounting),
   `C:568-576`). FIFO and scalar cash stay unchanged now; add no currency
   machinery or speculative instrument-term defaults.
4. **No new execution-policy callbacks.** Existing strategy/indicator
   interfaces remain; an extension cannot insert arbitrary user execution
   code. Preparation resolves identities and indexes once, trusted work reads
   primitives, and typed buffers materialize at boundaries. The optimization
   manual's seven shapes remain review criteria
   (`inst/design/manual/optimization_coding_style.qmd:77-129`).

These mechanisms do not establish that every future economic model fits
today's kernel. It requires distinct positions and positive fill prices
(`R/lot-accounting.R:323-331`), while publication exchanges spot principal
(`R/ledger-writer.R:7-16`). That supports Section 6's amendment, not
permission to change either computation now.

The scenarios impose the following constraints when their owning work opens:

| Scenario | Required treatment |
| --- | --- |
| Outstanding orders and partial fills | Name E's skip sequencing, typed order state, P3 and P4 batching as owners. Fill, expire or cancel eligible orders without a new strategy call. Apply repeated fills for an instrument in ordered conflict-free blocks, never merge them to fit today's distinct-position batch (`R/fold-engine.R:1229-1242`; `C:284-305`). |
| OMS publication | Preserve two streams and immutable links. A retained lifecycle fill cannot survive without its accounting effect; define cross-stream commit/failure behavior and exact decision associations. Physical omission needs a proved decoder (`OMS:202-214`; `Records:73-90`, `:141-148`). |
| Shorting, margin, futures and autonomous events | Shorting/borrow and collateral require their own rules; signed quantities are insufficient. Accrual, maintenance, expiry and settlement must work without new targets. P1 settlement is the existing owner; new kinds/asset economics take the cross-asset route. Time-varying terms are causal facts. |
| Currency and FX | Name opening state, valuation, sizing, affordability, publication, reconstruction and result-currency disclosure. A currency vector alone supplies none of their semantics. |
| Liquidity and cost | Final fees and cash effects must match final fills. Quantity-dependent and fixed fees differ (`R/cost-model.R:421-426`); leave composition to the execution-policy RFC. Preserve today's cost-before-affordability behavior. |
| Paper/live | Keep asynchronous I/O at the edge and observed fills at a typed boundary in the one fold. Simulated affordability cannot discard broker fills, nor can the research cost chain reprice them. The paper/live RFC owns duplicate/late/correction events, reconciliation, durable submission identity and recovery. Research restart at pulse one is not permission to resubmit external orders (`OMS:442-460`, `:547-550`; `Records:189-198`). |

### 3.1 Timing And Protective Parameters

An order fixed before an execution interval can causally use that interval's
OHLC to simulate a fill. The originating decision cannot see it. P1 already
carries next-bar OHLC privately (`R/fold-engine.R:610-625`, `:1878-1889`). A
close-time decision cannot claim a fill at that bar's earlier high or low.
Today's next-open contract is unchanged; no extra pulse delay is inherently
required, and no intra-bar behavior is authorized here.

The future timing RFC must bind activation, gap prices, ambiguous stop/limit
ordering, trailing updates, same-bar bracket activation, fact cutoffs, event
time and recording pulse on both clocks. OHLC supplies no within-bar order:
use an explicit identity-bearing conservative convention or refuse, never
invent an exact trigger time.

**Q3: keep protective-order parameters inside that timing RFC.** Before a
stop, bracket, trailing or other protective-order capability is cut, the same
RFC must define its declaration surface outside strategy returns, identity,
validation and activation/update semantics. A code for an order type cannot
supply its levels or relationships. Route this conditional obligation through
the existing execution-policy pipeline entry; do not create a separate
parameter RFC or silently add it to the current affordability cut. This
develops the existing parked gap (`inst/design/horizon.md:1517-1537`) without
promising delivery.

## 4. Procedure For Adding A Capability

1. **Route the semantics.** A vocabulary entry is a direct ticket only under
   already accepted semantics. Public behavior, timing, economic models or
   evidence-boundary changes require an RFC. A new kind/source for another
   asset class follows [Typed accounting Section 9](rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md#9-future-obligations-and-speculative-deferrals)
   (`:362-364`); its shape alone does not make it a dictionary chore.
2. **Name all owners.** Cover production, scheduling, application, publication,
   reconstruction, identity and failure ordering. For each changed field name
   type, axis, unit, producer, validator and owner; show how Section 2 survives.
   Check the four skeleton scenarios at every family close, as amended by
   Section 6.
3. **Contract before code.** Resolve conflicts and exact supersessions first.
   Specify lifecycle/economic semantics, validation and refusal precedence.
   Do not quietly expand an accepted capability during its ticket cut.
4. **Prove the change.** Add the owning test/parity family and negative
   witnesses, covering affected success and failure prefixes, both clocks,
   run/sweep equivalence and reconstruction. Preserve unchanged behavior;
   record deliberate oracle differences under Core Section 5/A3. Do not
   alter an existing oracle merely to make a failure pass.
5. **Declare identity and format impact.** Include config, snapshot, policy,
   schema and store-version effects. Stored-format changes bump their
   version/fingerprint and old stores refuse with a classed condition. No
   migration, old-format reader or missing-marker fallback.
6. **Close with measured cost and subtraction.** Set A2 microsecond and line
   budgets from the pinned baseline at family cut; report against them at
   close. An overrun is fixed or explicitly accepted, not merely logged.
   A4 removes duplication in the same workstream (`Core:413-431`). Use the
   existing WS16 process and `tickets.yml`, not a second gate register.

## 5. OMS Supersessions For Acceptance

**Q2: adopt the four v2 supersessions at acceptance, including their repeated
clauses.** The table defines the exact scope. Typed lifecycle evidence is an
explicit choice of this RFC; the accounting contract alone did not already
rewrite the unimplemented OMS schema.

| Target artifact and addressed section | Disposition on acceptance | Replacement here |
| --- | --- | --- |
| OMS 4.1 `meta_json` and adapter-field alternative (`:156-161`); the generic `meta_json` field in 4.2 (`:193`); repeated adapter alternatives in 11 and 14 (`:552`, `:610`) | Superseded in part | Section 3, mechanism 1: contracted typed evidence, no generic metadata envelope. Adapter fields remain deferred until needed; no columns now. |
| OMS 4.3 ledger back-links and deferred promotion (`:211-216`); repeated JSON back-links in 1 and 6.1 (`:36`, `:44-47`, `:352`) | Superseded in part | Typed `order_id`, `order_event_seq` and `proposal_id` ledger links when OMS lands. Deterministic preallocation, immutable forward/back links and separate rows survive. |
| OMS 12 item 7 (`:566`); execution-enable meaning of diagnostic mode in 6.2 (`:359`) and 13 item 14 (`:594`) | Superseded in part | One semantic path; lifecycle retention belongs to the output handler. Final-bar accounting/no-fill behavior stays unchanged. A retention choice cannot alter order processing. |
| OMS 7.4 regeneration rationale (`:411`); omission wording in 4.2 and 7.4 (`:165`, `:406`) | Superseded in part | Research decisions come from recorded evidence and exact package decoding, never strategy execution. No dedicated `target_decisions` table is required now; absence of that table cannot justify lost required intent or diagnostics. Records Sections 2-4 govern current logical evidence. |
| OMS 7.1 context (`:373-381`), 9.1 replay (`:475`), 10.2 replay tests (`:516`) and 12 item 10 (`:569`) | Amended for interpretation | The paragraph below: context is an edge distinction; deterministic re-execution and read-side reconstruction are distinct operations. No mode branch or user-code replay on reads. |
| OMS 3.1-3.5, 4.3 preallocation/immutability, 5 lifecycle meaning, 7.2-7.3 retention concept and boundary, 7.5 promotion gate, 8 safety/reconciliation | Unchanged | Those addressed sections remain operative, subject only to the explicit replacements above; order storage, retention API and later capabilities retain their owning cuts/RFCs. |

The old 7.1 context distinction (`OMS:373-381`) remains an edge, adapter and
persistence distinction; it grants no execution-mode branch. The replay/ID
requirements in 9.1 and 10.2 (`OMS:475`, `:516`) mean deterministic IDs on a
new execution and exact reconstruction from retained evidence on a read,
not user-code replay. Target payload encoding and hashes in 4.2/9.2 are not
redesigned here; unlike a generic extension envelope, a specifically
contracted codec remains a storage decision. Full logical evidence and the
pre-CRAN refusal policy prevail.

At acceptance, append a dated OMS amendment with this table, add its header
notice and heading markers at Sections 1, 4.1-4.3, 6.1-6.2, 7.4, 11, 12, 13
and 14 linking here. Add clarifying markers at 7.1, 9.1, 10.2 and 12 item 10
for the readings
above. Preserve the old text and unrelated obligations. This is acceptance
work, not a claim that notices were installed by this single-file task
(`inst/design/rfc_cycle.md:79-85`;
`inst/design/rfc/rfc_governance_lifecycle_v0_2_2_synthesis.md:118-141`).

## 6. D1 And Skeleton Amendment

**Q1: adopt the amendment, with a complete owner-map check (maintainer
decision, 2026-11-04).** V2's last-sentence replacement alone leaves the
old four-row table promising that the lot kernel never changes. Replace the
following exact passages together; until accepted and recorded, D1 stands
and affected lean-core coding remains gated.

| Target artifact and addressed section | Disposition | Exact replacement |
| --- | --- | --- |
| D, D1 locality claim (`:15-18`, starting "It must not foreclose") | Amended | "It must not foreclose these capabilities. For each, name the smallest coherent set of affected stages and structures and preserve the fixed semantic boundaries of the core extension architecture synthesis Section 2." |
| D, D1 Check (`:27-30`) | Superseded | "The synthesis and every family close answer the four scenarios with a complete affected-owner map, including scheduling, publication, reconstruction, identity and failure ordering. A second engine, an execution-mode branch or a duplicated kernel is a finding. Reuse shared primitives wherever their arithmetic applies. A proposed strategy-boundary or lot-kernel change needs its own contract, explicit disposition of any conflicting accepted boundary and parity for unchanged behavior; it is never made silently." |
| Skeleton 2.1 introduction, table and locality/check paragraph (`:137-157`) | Superseded | The replacement block immediately below. |
| Skeleton Sections 1, 2 outside that block, 3-7; D1 statement and table (`D:8-14`, `:20-25`); D2 | Unchanged | Those sections, including the order-shaped handoff (`Skeleton:93-99`), scalar cash, complete FIFO first checkpoint, stage recorder, public parity and coding gate. D1's other statements remain minimum extension guards, not proof that future economics fit today's kernel. |

Exact replacement block for Skeleton 2.1:

> Bind [D1](rfc_lean_core_skeleton_v0_2_3_maintainer_decisions.md#d1-built-for-what-comes-next-without-building-it)
> as a constraint on the skeleton, its first checkpoint and every family
> close, not a request for unused code. The interface table preserves the
> fixed boundaries in the core extension architecture synthesis Section 2;
> preparation and the FIFO family must not bake future policy into storage or
> arithmetic. The four scenarios below name affected owners; they do not
> freeze every future stage or the current event grammar.
>
> | Future capability | Affected owners and preserved boundary |
> | --- | --- |
> | OMS: intent, lifecycle, outstanding orders | P3 planning and the existing order-shaped handoff; E's typed order state and scheduled-skip sequencing; P4 ordered conflict-free batching; P4/P5 lifecycle publication and retention services. Existing orders must progress without a fresh strategy call. P2 remains a full-target interface; lifecycle state stays outside strategy state and accounting rows. Repeated fills are not merged. |
> | Other order types | P3 fill resolution and typed order fields; preparation/P1 execution slices; timing and, for surviving orders, the OMS owners above. P2 never sees future execution data; P4/P5 consume resolved effects without interpreting order types. The timing contract owns activation and ambiguity. |
> | Short selling and leverage | P2 target/risk validation, P3 short refusal and portfolio affordability; prepared causal terms, P1 settlement/valuation and P4/P5 typed financing publication as needed. Signed storage remains; financing and collateral are separate rules. Current short refusal and FIFO arithmetic do not change in this skeleton. |
> | Other asset classes | Preparation and the named valuation, sizing, affordability, settlement, application, publication and reconstruction services change under the cross-asset contract. Reuse applicable signed-book primitives; do not promise that spot principal exchange, positive fill prices or every kernel operation fit new economics. Any necessary kernel change takes its own contract and parity route. Terms and event interpretation stay with their named consumers, not constants or generic metadata spread through the fold. |
>
> Each concrete extension supplies the complete owner map and explains every
> change; this table is not an exhaustive future implementation specification.
> A second engine, execution-mode branch or duplicated kernel fails the check.
> A strategy-boundary or lot-kernel change requires explicit contract disposition
> and parity for unchanged behavior. No future capability or speculative field
> is implemented here. D2's acceptance and amendment gate remains in force.

Record the accepted form as dated appended amendments to D and Skeleton,
with header links and affected-section notices. This draft does not amend
those files.

## 7. Rejections, Routing And Evidence

| Rejected proposal | Reason |
| --- | --- |
| V1's one-place/one-stage promise; an immutable kernel for arbitrary future assets | Shared rules legitimately have several owners; current spot arithmetic is not proof of future economics. Use the owner map and Section 6 amendment. |
| Named P3 sub-stages as mandatory new abstractions, a carrier per step, speculative terms/currency vectors | No present contract needs them. Preserve real responsibilities and extract helpers only when justified. |
| Universal integer enums; JSON or callbacks as extension escapes | Closed validation matters, not token representation. Generic payloads and user execution hooks evade the typed contract. |
| Per-asset accounting engines or using compiled dispatch as economic policy | They split semantics and cannot compose mixed assets in one run. |
| A state slot as the whole OMS design; merging repeated fills | Skip sequencing, order identity, failure atomicity and event-order arithmetic also change. |
| Intra-bar fills inferred from a close-time decision; exact trigger times inferred from OHLC | Both claim information unavailable at the required boundary. Timing needs a new explicit contract. |
| A separate protective-parameter cycle now; waiting for WS11 before this internal decision | Parameters and timing need one coherent decision; WS11 needs measured package-boundary evidence, not this scenario list as a preselected core list. |
| Deferring OMS contradictions to implementation | That would leave opposing accepted instructions for the cut writer. Supersede the clauses at acceptance, while leaving concrete storage to its owner. |

**Q4:** v2's fixed boundaries are sound after Section 2's wrapper, snapshot
trust, ownership and read-only clarifications. Future-perturbation and failure
evidence must test them; a diagram alone proves none of them.

**Open Questions Promoted To Spec-Cut:** concrete internal field names,
encodings and validation placement within the accepted skeleton interface;
later OMS physical storage, retention API and commit mechanism under Section
5. Timing, new economic models and public policy surfaces remain RFC work,
not spec-cut discretion. D1's disposition is the maintainer's 2026-11-04 decision, not a cut question.

**Future Obligations Recorded:** at acceptance, route Section 3.1's conditional
timing/protective-parameter obligation through `execution-policy`; attach the
OMS replacements and cross-stream/skip/batching constraints to
`oms-order-lifecycle`. Shorting/leverage, cross-asset accounting and precision
keep their existing pipeline owners. Paper/live recovery and observed-fill
semantics go to its owning follow-up, not the research restart implementation.
These constraints fire when those capabilities enter scope; they set no new
release dates. No other scenario is promoted into a delivery obligation.

Acceptance records the D1 disposition, installs the Section 5/6 notices and
maps pending rules in `decisions.md`, the RFC pipeline and relevant contract
back-links, preserving shipped rules. Those files and `tickets.yml` are not
edited here. The independent final reviewer should reconcile the supersession
table and its omissions against the cited records before acceptance.

Evidence here is source and authority inspection only, not execution,
performance proof or a new prototype. No probes, full test suite or package
check were run. The maintainer waived external research for this corpus-based
cycle (`D:39-43`); the response review accepted the Claude-drafted framing
(`rfc_core_extension_architecture_v0_2_3_response_review.md:9-26`). This synthesis
does not substitute its own checks for independent final review.
