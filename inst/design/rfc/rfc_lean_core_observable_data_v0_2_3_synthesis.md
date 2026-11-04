# Lean Core Observable Data: Decision Synthesis

- Status: **accepted** by the maintainer on 2026-11-04, after the independent
  Type 1 [final review](rfc_lean_core_observable_data_v0_2_3_final_review.md)
  (ACCEPT_AFTER_PATCHES, all seven patches applied). Acceptance installed
  the Section 4 amendments in D, K, X, M, `decisions.md` and the pipeline,
  and cleared the WS16 partial hold. It binds the design constraints below;
  it claims no implementation.
- Mode: **Decision synthesis**, RFC cycle stage 7. Codex, 2026-11-04;
  different author from seed v2. Brief drafted by Claude and approved by the
  maintainer.
- Inputs: [seed v2](rfc_lean_core_observable_data_v0_2_3_seed_v2.md),
  [response](rfc_lean_core_observable_data_v0_2_3_response.md),
  [maintainer response review](rfc_lean_core_observable_data_v0_2_3_response_review.md),
  and the accepted sibling records named below.
- Source baseline: detached `37100e5470f8d2200fc6af73b2a6c75e85268435` in
  `C:/Users/maxth/ledgr-wt/observable-data-synthesis`, initially clean.
  Citations refer to this baseline, not the response's earlier head or the
  lean core's eventual reference pin.
- Final review at `044193dc`: the only intervening change to a cited input
  is seed v2 line 42 (see Section 1).
- Revision note (2026-11-04): the seven patches of the
  [Type 1 final review](rfc_lean_core_observable_data_v0_2_3_final_review.md)
  (ACCEPT_AFTER_PATCHES) are applied in place: the seed v2 line 42 remark
  (Sections 1 and 6), the Section 4 supersession table, the installed notice
  text, routing of the amended records' own rows and the replacement pipeline
  row (Section 4.5), the `X:173` citation (Section 3) and the `M:1029`
  citation (Section 1).
- Citation aliases: **C** = `inst/design/contracts.md`; **K** =
  `inst/design/rfc/rfc_lean_core_skeleton_v0_2_3_synthesis.md`; **D** =
  `inst/design/rfc/rfc_lean_core_skeleton_v0_2_3_maintainer_decisions.md`;
  **X** = `inst/design/rfc/rfc_core_extension_architecture_v0_2_3_synthesis.md`;
  **M** = `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`;
  **Pipeline** = `inst/design/rfc/README.md`. Other paths are repository-relative.

## 1. Decision

Adopt seed v2's written guard and fifth affected-owner scenario, with the
clarifications and exact amendments in Section 4. Keep preparation as the
data owner, P1 as the sole fold-stage substrate reader issuing cutoff-bound
views, and P2 as the public adapter. Later contracted data may change these
owners and the services that consume its values. It does not need a new
engine, a parallel causal reader or a universal data descriptor.

This is a constraint on the lean core being written now. It authorizes no
runtime mechanism for future data: no fields, columns, accessors, fact
families, dispatch, reason codes, clocks or storage formats. Principle 0
holds: no public API, visible behavior, identity or stored-format change.
K Section 3's numeric tiles, typed masks and segments, exact history and
numeric admission remain unchanged (`K:191-247`). No interface is promised
to fit every later data kind without a contracted representation change.

The four data cases are intersecting review scenarios: per-instrument filed
values, market-level series, coded categories and sparse dated events.
They are subcases of the fifth scenario, not four new type tags or delivery
commitments. The External Data And Point-In-Time Regressors RFC after CRAN
owns their design, under the existing
[instrument master, PIT regressors](README.md#instrument-master-data) route.
The macro plan already lists PIT fundamentals as an explicit non-goal, after
CRAN (`M:1029`).

The response's central correction is sound: preserve owners and causal
boundaries rather than install machinery for unknown payloads
(`rfc_lean_core_observable_data_v0_2_3_response.md:35`, `:97`). The maintainer
accepted that framing (`rfc_lean_core_observable_data_v0_2_3_response_review.md:9`).
Seed v2 implements it substantially; the remaining changes here make the
guard checkable and remove claims broader than the evidence.

The post-warmup `NA` decision is settled and outside this cycle
(`inst/design/decisions.md:34`; `M:1095`). At this synthesis's baseline, seed v2's
Section 2 called that decision "pending", which could be read as undecided.
Commit `044193dc` reworded it in place to "accepted, pending
implementation". Its Section 8 correctly excludes it.
Preserving indicator semantics here does not supersede or delay that
separately accepted decision or its WS12 route. No new investigation or
disposition of the scalar/series difference is required by this synthesis.

## 2. What Must Remain Open

Record the six extension points both here and as notes attached to the
existing interface table. The table describes actual checkpoint fields;
the notes identify owners a later contract may extend. Do not add six
placeholder fields, a runtime registry or a second interface inventory.

| Extension point | Verified boundary and what remains open |
| --- | --- |
| Prepared values and evidence | The current constructor builds numeric OHLCV matrices and a logical observed mask (`R/history-substrate.R:422`). K Section 3 chooses time-major numeric tiles for the lean core, not today's matrix orientation. Later values or typed absence evidence may extend this owner under a data contract. Neither dense filed-value storage nor change-point storage is chosen here. Exact small category codes can fit numeric storage; that does not give them quantitative semantics. |
| Identity and axes | The current substrate constructor validates instrument IDs and its ordered axis and stores their indexes (`R/history-substrate.R:1499`, `:1599`). A market-level series must be readable without acquiring execution semantics just to fit that axis. A separate series axis or scalar projection remains possible within the same causal owner; neither is implemented or required as the sole representation. |
| Feature input and output services | The existing input service reads OHLCV, and the callback frame names those fields (`R/history-features.R:169`, `:230`). K already preserves this service while adapting input access and output allocation (`K:221`). A later contract may add dependencies, admission and identity here; this RFC adds no external-data ingest route to callbacks. |
| P1 packet and read service | The current fold reader produces current/next bar packets and cutoff-bound history views (`R/history-substrate.R:465`, `:488`); the read service and view have explicit owners (`R/history-frame.R:461`, `:483`). Keep a contracted packet/service extension possible without turning the valuation packet into a bag of all readable data. [Typed Fold Carrier](../contracts.md#contract-execution-fold-carrier), `C:282`. |
| P2 public adapter | Context has portfolio/pulse scalars as well as instrument-aligned columns; feature reads coerce values to numeric (`R/pulse-context.R:1`, `:100`, `:153`, `:166`). A future category or market-series accessor belongs to the later RFC. Today's context is not a universal external-data accessor. [Pulse Data And Axis-Aligned Accessors](../contracts.md#contract-context-pulse-data), `C:2253`. |
| Read requests and admission | Current history requests select a bar or feature and use numeric finite-value admission (`R/history-frame.R:991`, `:1069`, `:770`). Keep that contract unchanged. A later category/event read must specify whether history and admission apply; a numeric encoding alone cannot select that policy. [Pulse Data And Axis-Aligned Accessors](../contracts.md#contract-context-pulse-data), `C:2286`, `:2380`. |

Time coordinates, observation axes and read policy are separate decisions.
[Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts)
keeps effective and knowledge time separate (`C:958`). Existing bar reads
use cutoff knowledge, while feature cells retain their own-pulse vintage
(`C:2313`; enclosing readers `R/history-frame.R:207`, `:257`). Preserve those
rules. No third runtime clock is added.

For later filed data, a period ending at p and first filed at f > p cannot
be known at p. A cutoff after f can admit that initial filing even with no
revision. Thus differing histories cannot be attributed only to replacement
filings. The later contract must declare both the observation axis and read
policy; pulse/vintage and period/cutoff are useful examples, not the only
permitted pairings. A derived value computed at pulse s must not acquire
later knowledge through a subsequent read. This requirement does not choose
release-time resolution, revision precedence, basis treatment or a storage
schema. Acquisition reproducibility may require another coordinate; the
later RFC decides that, without this cycle claiming it is the only possible
additional temporal concept.

## 3. Fifth Scenario And Family-Close Check

At every family close, answer "new observable data kinds" through the same
affected-owner check as the other four scenarios. Use all four data subcases
in Section 1 and assess the following responsibilities by intended use.
Name changed and unchanged owners and point to the interface or code boundary
that supports the answer. An unaffected owner needs a reason, not an unused
field or a future-data implementation. Record the answer in the existing
family evidence; create no separate gate register.

| Responsibility | Owners and constraint to assess |
| --- | --- |
| Production | Ingest, sealing and identity mapping; preparation; feature input and output services. Preserve snapshot trust and one causal source. |
| Scheduling | E and P1 projection on existing pulses. A new release-driven pulse schedule needs its own contract; source timestamps do not authorize extra pulses. |
| Application | P1 observation, settlement and valuation; P2 strategy and risk; P3 planning/costs and P4 application when their contracts consume the value. P3-P5 may receive contracted typed values, never a substrate/history handle. |
| Publication | Existing feature, diagnostic, equity and accounting publication/retention services, including P4/P5 where affected. Observing data alone creates no accounting event. |
| Reconstruction | Frozen views, retained evidence, result readers and explanations. Preserve exact reconstruction without user-code replay or writes to persistent tables. |
| Identity | Snapshot/acquisition evidence as contracted, feature definitions and dependencies, config/policy identity, caches and precomputed payload validity. No identity addition now. |
| Failure ordering | Seal/preflight refusals, knowledge-bounded runtime failures, E's stop installation and append/flush prefixes. An unknown future value cannot change an earlier failure. |

This combines the sibling table's owner form with seed v2 Section 6's useful
responsibility checklist. It does not assert that observable data stops at
P2. Marks already serve valuation and risk
([Context Planes And Strategy State](../contracts.md#contract-availability-context-and-state),
`C:1315`); P3 carries decision/risk evidence and P5 reconciles at decision
marks and flushes diagnostics (enclosing stages `R/fold-engine.R:1086`,
`:1155`, `:1520`, `:1568`, `:1598`). A strategy-only input may leave those
later owners unchanged; a valuation or risk input may not.

The check fails if the proposed structure requires a second engine, an
execution-mode branch, a second causal reader, a generic metadata escape,
or execution semantics fabricated for a source series. A representation
change inside an affected owner is not itself a failure. A change to an
accepted boundary needs an explicit contract and supersession before code,
as X Section 4 already requires (`X:173`). No current family must prove a
future capability works. It must show that its own design preserves these
boundaries and does not implement the future capability prematurely.

## 4. Exact Amendments For Acceptance

These are proposed amendment texts, not edits installed by this task.
Preserve earlier accepted text and provenance. At acceptance append dated
amendments to D, K and X, with the header and section notices below; record
the maintainer's actual acceptance provenance in this synthesis's header.
The date in the amendment title identifies this decision text. Historical
four-scenario passages remain historical, not competing instructions.

| Target artifact and addressed section | Disposition | Replacement |
| --- | --- | --- |
| D, D1 scenario table (`D:26-31`) | Amended | Section 4.1 fifth row; the four existing rows are unchanged |
| D, operative D1 Check in the core-extension amendment (`D:68`) | Superseded | Section 4.1 replacement Check |
| K Section 2, interface-table rule (`K:105-113`) | Amended | Section 4.2 guard and extension-point notes, added after the rule |
| K amended Section 2.1 (`K:463-485`) | Amended | Section 4.2 "five scenarios" sentence and fifth row |
| K, core-extension amendment's "Sections 1, 2 outside 2.1, and 3 to 7 are unchanged" (`K:456`, `:461`) | Amended | Section 2 is amended as above; Sections 1 and 3 to 7 remain unchanged |
| X Section 4 step 2 (`X:168-172`) | Superseded | Section 4.3 replacement step |
| X Section 6, embedded four-scenario text (`X:233-262`) | Superseded in part | Scenario count only, through Sections 4.1-4.3; otherwise historical accepted text |
| M WS16 "Observable data guard" bullet (`M:702-709`) | Superseded | Section 4.4 bullet |
| D1 statement and locality amendment (`D:67`), D2; K original 2.1, K Section 2 outside the interface-table rule, K Sections 3-7; X Sections 1-3, 4 outside step 2, 5 and 7 | Unchanged | Those sections |

For each of D, K and X, add this exact header notice and repeat it at the
affected section headings named below:

> Observable-data amendment (2026-11-04): the addressed passages below are
> amended by the accepted
> [lean core observable data synthesis](rfc_lean_core_observable_data_v0_2_3_synthesis.md#4-exact-amendments-for-acceptance);
> see the [amendment](#amendment-2026-11-04-observable-data) in this record
> for the exact replacement scope. Other accepted rules remain in force.

### 4.1 D1

Target D1's scenario table (`D:26`) and the operative D1 Check in its
core-extension amendment (`D:68`). Put notices at D1 and that amendment.
Append under `## Amendment (2026-11-04): observable data`:

> Add the following fifth row to D1's scenario table. Its four existing
> rows remain subject to the core-extension amendment and are unchanged here.
>
> | Future capability | Existing authority | What the lean core keeps open |
> | --- | --- | --- |
> | New observable data kinds: filed values, market-level series, coded categories and sparse dated events | [Observable-data synthesis](rfc_lean_core_observable_data_v0_2_3_synthesis.md) Sections 1-3; [External Data And Point-In-Time Regressors route](README.md#instrument-master-data), after CRAN | Preparation, P1's cutoff-bound read service and P2's adapter remain the access owners. Assess further consumers by intended use under that synthesis's Section 3. Preserve its Section 4.2 guard; implement no future-data mechanism now. |
>
> Replace the operative D1 Check with:
>
> The synthesis and every family close answer the five scenarios with a
> complete affected-owner map, including scheduling, publication,
> reconstruction, identity and failure ordering. For new observable data
> kinds apply the observable-data synthesis Sections 2-3. A second engine,
> an execution-mode branch or a duplicated kernel is a finding. Reuse shared
> primitives wherever their arithmetic applies. A proposed strategy-boundary
> or lot-kernel change needs its own contract, explicit disposition of any
> conflicting accepted boundary and parity for unchanged behavior; it is
> never made silently. D2 and the other D1 constraints are unchanged.

### 4.2 Skeleton Interface Rule And Amended Section 2.1

Target K Section 2's interface-table rule (`K:105`) and the operative
Section 2.1 in the core-extension amendment (`K:463`). Put notices at
Section 2, original Section 2.1 and the operative amended Section 2.1.
Append under `## Amendment (2026-11-04): observable data`:

> Add the following to Section 2 immediately after its interface-table rule:
>
> Later contracted observable data enters through preparation, P1's
> cutoff-bound read service and the P2 adapter. P1 remains the sole
> fold-stage substrate reader; a strategy history call uses the read service
> of its P1-issued view, not an independent causal reader. P3-P5 receive
> contracted typed values and no substrate or history handle. Preserve one
> execution path, snapshot creation, sealing and verification, exclusive
> mutable ownership and frozen retained views. A non-tradable source series
> must not acquire membership, target, position, lot or fill semantics merely
> to fit the instrument axis. Preserve existing numeric-history admission
> and bar/feature public semantics, subject to separately accepted decisions;
> this guard does not supersede the settled post-warmup NA decision. Resolve
> stable names and indexes during preparation; resolve and validate dynamic
> public requests at their existing boundaries. Add no future-data fields,
> descriptors, dispatch, accessors, clocks or absence semantics now.
>
> Attach the observable-data synthesis Section 2's six extension-point notes
> to the interface table's relevant preparation, P1 and P2-view entries,
> with references to any other affected existing services. Describe current
> fields with the already required type, axis, unit, invariant, producer,
> validator and owner. The notes reserve later contract work; they are not
> placeholder fields or a runtime descriptor. A later data kind may change
> representation within its named owners under its own contract.
>
> In amended Section 2.1 replace "The four scenarios below name affected
> owners; they do not freeze every future stage or the current event grammar."
> with "The five scenarios below name affected owners; they do not freeze
> every future stage or the current event grammar."
>
> Add this fifth row to that table:
>
> | Future capability | Affected owners and preserved boundary |
> | --- | --- |
> | New observable data kinds: filed values, market-level series, coded categories and sparse dated events | Ingest/seal and identity mapping; preparation and feature services; P1 cutoff-bound observation and P2's adapter. Assess E scheduling, P1 valuation/settlement, P2 risk, P3/P4 consumers, publication, reconstruction, identity and failure ordering by intended use under the observable-data synthesis Section 3. Preserve the Section 2 observable-data guard. No second causal reader or execution path, no source series given execution semantics to fit an axis, and no future-data mechanism now. |
>
> Other Section 2.1 text and its four existing rows are unchanged. Section 3
> is unchanged: this amendment neither generalizes numeric tiles/admission
> to future data nor requires every later data kind to use that shape.

This guard tightens seed v2's "no tradable pseudo-instrument" without
forbidding a shared identifier or a genuine tradable asset with its own
contract. It also preserves K's distinction between stable preparation
indexes and dynamic explicit history requests (`K:115`), following the
optimization style (`inst/design/manual/optimization_coding_style.qmd:140`).

### 4.3 Extension Procedure

Target X Section 4 step 2 (`X:168`). Put notices at Section 4 and Section 6,
whose embedded four-row amendment remains the historical accepted version.
Append under `## Amendment (2026-11-04): observable data`:

> Replace Section 4 step 2 with:
>
> 2. **Name all owners.** Cover production, scheduling, application,
>    publication, reconstruction, identity and failure ordering. For each
>    changed field name type, axis, unit, producer, validator and owner; show
>    how Section 2 survives. Check the five skeleton scenarios at every
>    family close: OMS, other order types, short selling and leverage, other
>    asset classes, and new observable data kinds. The first four retain
>    Section 6's accepted treatment. For observable data apply the
>    [observable-data synthesis](rfc_lean_core_observable_data_v0_2_3_synthesis.md)
>    Sections 2-3 and its Section 4.2 guard. Its Section 4 amendments extend
>    D1 and skeleton Section 2.1; Section 6's earlier four-scenario text is
>    superseded only to that extent.
>
> The remaining procedure, fixed boundaries and mechanisms are unchanged.

### 4.4 Macro Gate

Replace M WS16's entire "Observable data guard" bullet (`M:702`) with:

> - **Observable data guard (2026-11-04).** Acceptance of the
>   [observable-data synthesis](../rfc/rfc_lean_core_observable_data_v0_2_3_synthesis.md)
>   clears this RFC's hold on memory-preparation code and the interface
>   table's preparation, P1 and P2-view rows. Install its Section 4 design
>   amendments at acceptance before coding those interfaces. Its written
>   guard and fifth scenario apply at every family close through the existing
>   affected-owner procedure. No hold remains until the External Data RFC;
>   that RFC owns the later data design after CRAN. FIFO and the stage
>   recorder were not held. Other WS16 prerequisites remain in force.

### 4.5 Acceptance Routing

These register changes locate the decision; they create no additional gate.
In `inst/design/decisions.md`, add this row to the existing five-column table:

> | <a id="lean-core-observable-data"></a>Lean core observable data | [Observable-data synthesis](rfc/rfc_lean_core_observable_data_v0_2_3_synthesis.md) Sections 1-5 | Macro WS16 interface table and every family close own the written guard and fifth scenario; acceptance clears this RFC's partial hold | [Fold core](contracts.md#contract-execution-fold-core); [fold carrier](contracts.md#contract-execution-fold-carrier); [pulse data](contracts.md#contract-context-pulse-data) | [Pipeline](rfc/README.md#lean-core-observable-data); later data design with [instrument master, PIT regressors](rfc/README.md#instrument-master-data) under synthesis Section 8 |

In Pipeline replace the `lean-core-observable-data` row (`Pipeline:112`) with:

> | <a id="lean-core-observable-data"></a>Lean core observable data | **Obligations open** | [Accepted synthesis](rfc_lean_core_observable_data_v0_2_3_synthesis.md) Sections 1-5 and 8 (Codex, gpt-6.1-sol; maintainer acceptance on the recorded date); [Type 1 final review](rfc_lean_core_observable_data_v0_2_3_final_review.md) (independent Claude session, ACCEPT_AFTER_PATCHES); inputs: [seed v2](rfc_lean_core_observable_data_v0_2_3_seed_v2.md) (maintainer with Claude), [response](rfc_lean_core_observable_data_v0_2_3_response.md) (Codex, Type 2, REVISE), [response review](rfc_lean_core_observable_data_v0_2_3_response_review.md) (maintainer, framing accepted); [seed v1](rfc_lean_core_observable_data_v0_2_3_seed.md) historical | **Trigger:** WS16 preparation/interface cut and every lean-core family close. **Route:** the Section 4 amendments install the written guard and fifth scenario in D1, the skeleton and the extension procedure; acceptance clears this RFC's partial hold. The WS16 ticket cut takes ownership of these current-release obligations. Later data design stays with [instrument master, PIT regressors](#instrument-master-data) after CRAN. |

In Pipeline's existing `instrument-master-data` row (`Pipeline:99`), append
this exact source link to the accepted-source cell:

> [Observable-data synthesis Section 8](rfc_lean_core_observable_data_v0_2_3_synthesis.md#8-future-obligations-recorded)

Append this exact text to that row's trigger/route cell, preserving its
existing obligations and `Obligations open` state:

> For observable data, the External Data And Point-In-Time Regressors RFC
> after CRAN owns Section 8's conditional design obligations. These create
> no hold on the current lean core and no delivery date for a data capability.

Append to the "Current owner" cell of `decisions.md` row `lean-core-skeleton`:

> ; D1, Section 2 and amended Section 2.1 further amended by the
> [lean core observable data](#lean-core-observable-data) synthesis

Append to the "Current owner" cell of `decisions.md` row
`core-extension-architecture`:

> ; Section 4 step 2 amended by the
> [lean core observable data](#lean-core-observable-data) synthesis (five scenarios)

Append to the route cell of Pipeline row `lean-core-skeleton`:

> Acceptance of the [lean core observable data](#lean-core-observable-data)
> synthesis amended D1, Section 2 and amended Section 2.1.

Append to the route cell of Pipeline row `core-extension-architecture`:

> Acceptance of the [lean core observable data](#lean-core-observable-data)
> synthesis amended Section 4 step 2.

No shipped contract rule is amended. K Section 3, D2, X's other sections,
the roadmap and tickets retain their current authority. Acceptance routing
follows `inst/design/rfc_cycle.md:192`; this task writes none of those targets.

## 5. Gate Outcome

**Until acceptance: retain the active partial hold. At acceptance: clear it
entirely for this RFC, installing Section 4's amendments in the same acceptance
work before the held interfaces become code.** Nothing remains held pending
the after-CRAN data design. A permanent hold would make current optimization
depend on a capability expressly excluded from this release.

The active gate is M WS16 (`M:702`), not a proposal made by this synthesis.
FIFO and the stage recorder may proceed under existing authority while it
is pending, without freezing the held interfaces or claiming preparation
parity. Other WS16 prerequisites, stage parity, budgets and cut review
survive. This document does not declare those gates passed or coding begun.

## 6. Rejections And Reasons

| Rejected direction or wording | Reason and disposition |
| --- | --- |
| Seed v1's descriptor-driven preparation/read dispatch, withdrawn in v2 | Speculative runtime machinery; no contracted payload needs it. Keep the written guard and current interface notes. |
| A later data kind is only a new descriptor value, or never needs a new representation | Cannot be proved for unknown data. The accepted extension procedure permits explicit owner-local changes under a contract. |
| Observable data never reaches P3-P5, or one extension changes only one owner | Source role does not determine use. Current marks and diagnostic/reconciliation stages already refute that restriction; apply Section 3. |
| "No tradable pseudo-instrument" as the whole market-series rule | Leaves forced target/position coverage ambiguous. Forbid fabricated execution semantics for source data; do not ban genuine assets or internal identifier reuse. |
| Six speculative fields or mandatory generalized rows in the interface table | Confuses a review inventory with a representation. Keep current fields plus attached owner notes referencing Section 2. |
| A third runtime clock now; pulse/vintage versus period/cutoff as an exhaustive binary | Delayed knowledge is not a new clock, and axis and policy are independent. Preserve present clocks; later domain/acquisition semantics require their owning RFC. |
| Categories require non-double storage; numeric encoding implies numeric admission | Physical representability does not determine semantic type or estimator policy. Leave both to the later data contract. |
| Sparse observations automatically become accounting events | An earnings announcement is not an economic posting merely because it is dated. Observation alone creates no ledger row. |
| New missingness codes or a blanket non-refusal guarantee | Would decide public semantics without a data contract. Later typed evidence can live beside values; the settled indicator NA decision remains separate. |
| Dense repetition as a measured defect, or value segments as a required optimization | The withdrawn 63-copy figure is illustrative arithmetic. No memory/performance evidence was produced here; choose and measure physical storage when contracted. |
| Retain the preparation hold until the External Data RFC, or hold all FIFO/recorder work | No demonstrated dependency warrants either. The written guard resolves the present structural question; later data is outside current scope. |
| Reopen the response's scalar/series discrepancy as an open question | Already decided by the maintainer and routed to WS12. Seed v2's former "pending" wording, corrected in `044193dc`, supplied no authority to reopen it. |

## 7. Open Questions Promoted To Spec-Cut

**None added by this RFC.** The next WS16 cut still fills the existing
checkpoint interface table with actual field names, types and ownership,
and attaches Section 2's notes. Those are already-owned specification tasks,
not an unresolved choice about external data.

Seed v2 Section 9 is answered as follows:

1. **Guard:** adopt with Section 4.2's precise causal-reader, source-axis and
   dynamic-request wording; assess it at family close under Section 3.
2. **Six points:** both here and as notes attached to the actual interface
   table, without placeholder fields or a runtime descriptor.
3. **Checklist:** retain the seven responsibilities as the complete assessment,
   with a short fifth owner row in D1 and the amended skeleton table.
4. **Amendments:** the named design targets are right. Address the operative
   appended D1 Check and skeleton 2.1, preserve historical copies with notices,
   and record the gate and routing changes in Section 4. K Section 3 needs
   no amendment because its representation is unchanged.
5. **Gate:** clear this RFC's partial hold at acceptance with the amendments
   installed; no continuing hold until the data RFC.

These are synthesis decisions, not questions to hand back to the cut writer.
Storage, clocks for acquisition evidence, release resolution, public access
and typed absence policy are future RFC work under Section 8, not spec-cut
discretion (`inst/design/rfc_cycle.md:163`).

## 8. Future Obligations Recorded

When observable data enters scope after CRAN, the External Data And
Point-In-Time Regressors RFC must:

- Contract the chosen data's observation axis, effective/period and knowledge
  coordinates, initial availability, revisions and read policy, preserving
  derived values' own-pulse knowledge. Address date-only releases, multiple
  filings and basis compatibility where applicable.
- Choose ingestion, sealing, identity mapping, hashes and storage; decide
  whether acquisition evidence needs another coordinate. A fact family and
  a separately sealed regressor snapshot remain alternatives, not decisions.
- Contract category vocabularies, sparse event identity/multiplicity and
  scheduled versus actual dates, typed absence evidence and admission where
  relevant. None inherits indicator, carry, accounting or numeric-history
  rules solely by sharing a physical encoding.
- Define public access and any feature dependencies, then supply the complete
  affected-owner map, identity/format impact and causal/failure/reconstruction
  evidence under X's existing addition procedure. A release-driven schedule
  or economic use needs its own explicit contract disposition.

These obligations are conditional on the data capability being pursued;
they do not order its delivery. Route them through the existing pipeline row
as Section 4.5 specifies. Do not create a parallel provider/data RFC here.
The overlapping horizon entries remain design input, not an accepted schema
(`inst/design/horizon.md:2498`, `:2511`;
`inst/design/horizon_archive.md:5889`). Value segments, a separate series axis
and a scalar projection are possibilities only; none becomes an implementation
obligation or needs a new horizon entry in this cycle.

## 9. Verification Limits And Next Stage

Evidence is source and authority inspection, including enclosing functions
for the code claims above. No code was executed, no test suite, package check
or probe was run, and no performance or future-capability result is claimed.
The decision rests on existing contracts and owners, not empirical SF1 claims.

The SF1 findings, vendor data, probe output and research commits were not
accessed in this task. Their numerical claims and `af261e9`/`fa49d62` provenance
are **unverified here**; the response review records Claude's verification of
`fa49d62` (`rfc_lean_core_observable_data_v0_2_3_response_review.md:28`). That is
attributed evidence, not this author's independent check. Original maintainer
quotations outside the supplied repository records and future designs'
correctness, memory use and performance are also unverified.

No separate stage-6 product binary is escalated. The maintainer response
review resolves the framing; this synthesis chooses within it. Stage 8 is
an independent Type 1 final review of the source claims and exact amendment
scope, followed by maintainer acceptance and stage-9 routing. This author's
checks do not substitute for that review. This single-file task installs no
amendment, changes no tracked file and makes no commit.
