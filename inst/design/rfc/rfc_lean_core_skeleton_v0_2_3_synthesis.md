# Lean Core Skeleton: Decision Synthesis

- Role: record; RFC cycle stage 7, **Decision synthesis**. Codex, 2026-11-04.
- Status: **accepted** by the maintainer on 2026-11-04, after the independent
  Type 1 final review (PASS_AFTER_PATCHES, P1-P3 applied). The decisions below
  bind their stated pending scope; this record claims no implementation or
  checkpoint completion. Coding waits for the core extension architecture RFC
  (D2).
- Brief: drafted by Claude, approved by the maintainer on 2026-11-04.
- Parent: the accepted [lean fold core synthesis](rfc_lean_fold_core_v0_2_3_synthesis.md),
  especially Sections 2-5 and amendment A1.
- Inputs: [seed v2](rfc_lean_core_skeleton_v0_2_3_seed_v2.md),
  [response](rfc_lean_core_skeleton_v0_2_3_response.md),
  [seed v2 review](rfc_lean_core_skeleton_v0_2_3_seed_v2_review.md),
  [maintainer response review](rfc_lean_core_skeleton_v0_2_3_response_review.md),
  and [maintainer decisions D1-D2](rfc_lean_core_skeleton_v0_2_3_maintainer_decisions.md).
- Source baseline: release/v0.2.3 head
  `61f37613fcc9758fd2bf49be78451363c2eb0010`, checked in the detached
  `skeleton-synthesis` worktree. File:line citations below refer to that head.
  This source-check baseline does not designate the parent's reference pin.
- Citation aliases: **C** = `inst/design/contracts.md`; **Macro** =
  `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`; other paths are
  repository-relative.
- Draft revision, 2026-11-04, before final review: incorporate D1's four-row
  structural check, D2's coding gate and amendment route, and WS16's stage
  recorder requirement. Refresh source/contract checks at the new head.
- Final-review patches, 2026-11-04: the
  [Type 1 final review](rfc_lean_core_skeleton_v0_2_3_final_review.md)
  (independent Claude session, PASS_AFTER_PATCHES) P1 to P3 applied in place:
  the target-axis correction of seed v2 is stated, D1's OMS Section 5 is
  retained, and the shorting row names P3's short-exposure check.

## 1. Decision And Authority

**Adopt the corrected v2 direction:** named small stages over positional typed
data, one prepared representation using compact time-major tiles, and a first
checkpoint comprising memory preparation and the complete R FIFO family.
Their shared evidence tooling includes the stage recorder. Adopt D1's minimal
extension guard in Section 2.1, without implementing future capabilities.
Sections 2-5 below state the skeleton decisions; the seed's measurements and
shorthand are evidence, not additional implementation rules.

The public API and behavior remain unchanged: exported functions, arguments,
defaults, strategy and history surfaces, conditions, ordered results, stored
records, readers and identity. Nothing in `R/` calls `dev/lean_core/`.
This RFC does not authorize a production integration, new execution mode,
format change or correctness-rule change. Contracts prevail over the oracle;
any discovered conflict takes the parent's Section 5/A3 disposition route,
not a silent adjustment of the candidate or its expected output.

[Macro WS16](../ledgr_v0_2_3_spec_packet/macro_plan.md#ws16-lean-fold-core-accepted-synthesis)
remains the sole local statement of its workstream rules. Incorporate it by
reference, including its A1 requirement; do not copy its operational checklist
into the skeleton or this synthesis. The parent's switch proof and test-remap
rules remain in force. This child RFC decides the structure that A1 will
review, not a replacement process or a second release gate register.
The revised WS16 bullets "Stage parity before end-to-end", "Extension
architecture first" and "One family per cut" apply by reference
(Macro:666-684).

**D2 gates coding.** Acceptance of this skeleton synthesis alone cannot start
lean-core code, including its first-checkpoint recorder. The separate
[core extension architecture RFC](README.md#core-extension-architecture)
must first be accepted. If its accepted synthesis changes a structure bound
here, amend this synthesis before coding, as D2 requires. Extension points,
addition procedures and the definition of feature completeness belong to
that RFC; this record neither designs them nor pre-accepts its outcome.

The code supports preserving these boundaries. Committed runs and sweeps both
call `ledgr_execute_fold()` (`R/backtest-runner.R:939`, `R/sweep.R:1827`).
The current loop separates observation from execution data and removes the
history-bearing decision data before planning (`R/fold-engine.R:1878`,
`:1911`). A smaller representation can preserve those guarantees; removing
the guarantees is not the optimization.

## 2. Skeleton Shape And Interfaces

Keep preparation, the envelope E, and P1-P5 as named functions with explicit
inputs and outputs. Reuse snapshot creation, sealing and verification,
registration, preflight, feature calculation, cost/risk, output, codec,
reader and orchestration services under the parent's Section 2. Do not copy
their semantics into a harness to avoid an integration boundary.

| Part | Binding representation and boundary |
| --- | --- |
| Preparation | One immutable causal-history owner; session epochs and prepared display axes; stable global instrument positions, feature/field slots and lookup maps; tiles and flat typed segment/change-point columns. |
| E and P1 | E owns execution sequencing and stop installation. P1 alone reads the substrate and produces separate decision data and execution data. Settlement and position facts precede the decision as contracted. |
| P2 | Receives the cutoff-bound decision view, never next-bar execution data. Its public adapter supplies the existing strategy surface and validates the full return on each due pulse. |
| P3-P5 | Consume typed decision/execution columns and existing services, with no substrate or history handle. Planning, accounting and publication retain their separate semantic boundaries. |
| Fold state | Typed quantities on the run axis, scalar cash, typed asset-state fields and portfolio-state scalars, and one flat typed lot book. Decision targets live on the decision axis, mapped by `context_pos`; run-axis storage must not invent missing targets. This corrects seed v2 (principle 6 and Section 3.3), which put targets on the run axis; the current fold keeps them on the decision axis (`R/fold-engine.R:1058-1068`). |
| Recording | Preallocated typed columns and used-prefix counters, indexed writes and capacity growth by doubling. Fold state, handler retention and diagnostic chunks retain their distinct owners. Frames manifest at service boundaries. |

The P3-to-P4 plan/apply handoff keeps D1's order-shaped record: instrument
position, side, quantity, order type and timing, alongside the resolved fill
and rejection information needed today. Its only current order type is market
next-open. Accepted fills follow today's synchronous path; missing execution,
restrictions, affordability and final-pulse refusals remain unchanged. No
outstanding-order state or order-lifecycle stream is implemented here. Exact
extension mechanics and encoding are left to D2, within this minimum shape.

Before checkpoint code is written, its interface table must name every field's
type, axis, unit, invariant, producer, validator and owner, using
[Typed Fold Carrier](../contracts.md#contract-execution-fold-carrier) as the
semantic baseline. The table also names the reused services and the exact
preparation input-access/output-allocation boundary being changed. Passing
vectors instead of existing carrier objects does not remove a carrier
guarantee. In particular, retain the accepted import and cached-total
validation limits (C:325-336); do not strengthen them accidentally by requiring
all imported holdings or history-dependent totals to equal a fresh reduction.

Resolve stable names and axes once and read primitives by position. New public
requests and callback returns still resolve and validate at their boundaries:
arbitrary explicit history IDs cannot all be known before execution. Keep
numeric epochs inside the core and prepare public timestamp forms by axis.
Lists of typed columns are permitted; lists of per-row objects are not the
internal representation. Trusted arithmetic constructs no data frames or
per-pulse environments. The optimization manual's seven shapes remain the
review criteria (`inst/design/manual/optimization_coding_style.qmd:77`).

Validation belongs at the boundary that establishes or changes a guarantee.
Trusted consumers do not repeat it; user returns, imports, deserialization,
new alignment/transformation, applied rows and dynamic overflow/invariant
failures retain their checks and condition precedence. The current lot input
constructor and post-risk validation illustrate different necessary boundaries
(`R/lot-accounting.R:286`, `R/fold-engine.R:1010`).

Work follows changed inputs without changing execution semantics. After full
strategy validation and risk, actionable targets compare with current settled
holdings using the canonical threshold, not the previous requested target
(`R/fold-engine.R:1065`). A repeated unmet exit remains an attempted exit.
All openings, fills and dispositions update the book and position facts at
their accounting boundaries; delta trace storage does not remove required
logical rows or instruction/sizing witnesses.

### 2.1 D1: Four-Row Structural Check

Bind D1 as a constraint on the skeleton and its first checkpoint, not a
request for unused code. The interface table must preserve the following
change boundaries; preparation and the FIFO family must not bake future
policy into storage or arithmetic. This is the synthesis's four-row answer.
The check recurs at every family close under
[D1](rfc_lean_core_skeleton_v0_2_3_maintainer_decisions.md#d1-built-for-what-comes-next-without-building-it).

| Future capability | Stage and structure that would change | What remains unchanged outside those owners |
| --- | --- | --- |
| OMS: intent, lifecycle, outstanding orders | P3 target-to-order planning and the order-shaped handoff; E's fold state can acquire engine-owned outstanding-order state; P4/P5 publication services can emit the separately owned `order_events` stream when authorized. | P1's causal observation, P2's full-target strategy boundary and the FIFO kernel need no reshape. Lifecycle state does not enter strategy state or accounting-ledger rows. |
| Other order types | P3's single fill-resolution stage and its typed order record; preparation/P1 can supply the required indexed OHLCV execution slices and timing through the execution packet. Orders surviving a pulse use the OMS state boundary above. | P2 still sees only its cutoff-bound view. P4/P5 consume resolved accounting effects without interpreting order types; the lot kernel remains unchanged. No second substrate reader is introduced. |
| Short selling and leverage | P2's target/risk validation services and P3's short-exposure and affordability checks change only under the shorting contract. Signed positions, openings and lots already fit the storage shape. Borrow/financing use typed event preparation, P1 settlement and the existing accounting/publication services at P4/P5 as applicable. | E's sequencing, the P2 stage/strategy interface, history representation and FIFO arithmetic require no rewrite. The present short-exposure refusal remains policy, not an unsigned type invariant. |
| Other asset classes | Preparation can add contracted typed per-instrument terms; P1 valuation, P2 sizing services and P3 cost/fill services read them by index. New accounting-critical events change their typed preparation/application/publication boundaries, vocabulary and schema through the cross-asset route. | E's sequencing, P2's target interface, causal-history semantics and the lot kernel are not reshaped. Terms and event interpretation stay with their named consumers, rather than becoming constants or generic metadata spread through the fold. |

For each row, no stage outside the named owners would need reshaping under
this skeleton boundary. That is the binding locality requirement, not proof
that the future capability is implemented or that arbitrary future accounting
already fits today's kernel. A design requiring a second engine, mode branch,
or rewrite of P2 or the lot kernel fails D1's check; it is a finding for the
extension cycle, not permission to expand this skeleton silently. D2 must
resolve the concrete extension design before this shape becomes code.

The release-head anchors support these boundaries without proving future
functionality. P3 already forms position/side/quantity/time data and resolves
prices before accounting (`R/availability-economics.R:377`, `:404`), while P4
passes resolved fields to the lot operation (`R/fold-engine.R:1238`). P1's
execution packet already has high/low as well as open and an execution epoch
(`R/fold-engine.R:617`); D1 does not give P3 direct access to the substrate.
Short refusal is explicit target policy (`R/availability-economics.R:311`),
separate from the signed-opening and side rules (`R/lot-accounting.R:323`;
[Execution And Target Semantics](../contracts.md#contract-availability-targets)).
Accounting publication carries resolved typed effects
(`R/backtest-runner.R:119`, `R/accounting-replay.R:8`). These are the current
facts; outstanding orders, new fill models and cross-asset terms remain future.

Retain the authorities named by D1: [OMS Sections 3, 5 and 6](rfc_ledgr_oms_seed_synthesis.md#3-accepted-architecture),
the [shorting/leverage obligation](README.md#shorting-leverage-contract),
[cross-asset accounting route](README.md#cross-asset-accounting-events), and
[precision/tradability route](README.md#asset-precision-tradability).
Per-instrument multiplier, currency or quantity-precision columns are added
only when a contract requires them. No speculative columns, unused branches,
generic metadata or plugin layer are added now. Future event additions follow
typed fields, vocabulary entries and schema reset, not the historical OMS
text's JSON examples; the current
[accounting contract](../contracts.md#contract-execution-accounting-events)
prevails (C:550-563). Designing that extension procedure belongs to D2.

## 3. Prepared Data And Exact History

**Choose compact time-major tiles.** Each session block stores numeric field
and feature planes as sessions-by-stored-instruments double matrices, with a
global-instrument-to-column map and explicit absence. Masks and segment fields
retain declared types. One global instrument identity survives departure and
re-entry. One tile access boundary serves the prepared representation; width
and residency are checkpoint choices, not alternate semantic paths.

Inclusion in a tile is physical storage only. It must preserve inactive but
readable prints, carried values, explicit known off-axis requests, and the
effects of late-known facts. Carry sources and ages, lifetime/terminal barriers,
segment state, reasons and witnesses cross edges. Neither current membership
nor an observed-print mask is history admission. The current reader accepts
explicit IDs from the substrate beyond the decision selector
(`R/history-frame.R:1043`); the stable rule is
[Decision Axis And Eligibility](../contracts.md#contract-strategy-decision-axis).

**Keep both clocks.** Raw bars are stored once. Bar history applies treatment
knowable at the read cutoff; feature cells retain the knowledge and treatment
of their own pulse. Base masks plus per-instrument knowledge-epoch overlays
must support that distinction. The current cutoff reader chooses an overlay
from the cutoff (`R/history-frame.R:207`); the vintage reader chooses it by
each returned column (`:257`). A single finally treated plane cannot replace
both. Flat segments/change points preserve effective and knowledge boundaries,
resolver precedence and witnesses (`R/history-substrate.R:1306`). Live vectors
of membership and availability are execution cursors, never the authority for
an arbitrary historical read. This develops existing preparation, not a claim
that today's provider has no cursors (`R/availability-provider-prepared.R:139`).

**Preserve feature calculation, adapt its access and allocation.** Adopt N1.
The existing feature input service directly indexes dense bar matrices
(`R/history-features.R:187`), and preparation allocates full-axis outputs and
writes them by knowledge range (`:447`, `:474`). Tiling therefore changes both
input access and output allocation. It preserves required-field treatment,
calculation sequence, knowledge ranges, segment restarts, readiness, arithmetic
order, output carry and vintage evidence (`:329`, `:409`). It introduces neither
a second feature engine nor an incremental callback API. Calculate from data
start through calculation end under
[Scoring And Feature Start](../contracts.md#contract-execution-window-start)
and [Availability-Aware Strict Features](../contracts.md#contract-context-strict-features).
Tile edges cause no restart, overlap recomputation, strategy-state reset or
change to other run clocks/state. A full exact series or prefix needed by an
existing calculation remains a measured allocation, not a memory exemption.

**Count finite returned values for admission.** Preserve selectors and order,
finite lookbacks and `Inf`, defaults, empty/early windows, exclusion precedence,
selection counts and `min_instruments` warmup under
[Pulse Data And Axis-Aligned Accessors](../contracts.md#contract-context-pulse-data).
Finite input/output-carried values count. General requests need an exact
window count; trailing consecutive-valid counts are only a shortcut where
they prove the complete-window requirement. For example, `21, 22, NA, NA, 25`
satisfies `min_observations = 3` in a five-session window. The current defaults,
admission and precedence are explicit at `R/history-frame.R:770`, `:801` and
`:1114`. Bar counts follow cutoff treatment; feature counts follow vintage
cells. No past-membership plane is required. The existing rules ledger's LR-07
shorthand is not authority to narrow this API.

## 4. Public Views, Ownership And Publication

The private pulse packet is positional; the public context remains the classed
flat lazy `ctx`. Preserve aliases, strict unknown-field conditions,
non-forcing enumeration, at-most-once column construction, helpers and frozen
retention. These are implemented behavior, not optional presentation
(`R/pulse-context.R:100`, `:166`, `:196`). Private slot readers add no public
fields. Dispatch, environments and caches needed at that boundary are not
prohibited by the trusted arithmetic's representation rules.
Data flows from the core to that view: internal arithmetic reads prepared
axes and packets, never values read back from the strategy-facing `ctx`.
Existing user callbacks still receive their contracted public inputs.

Asset-state fields retain their declared types and decision-axis departure and
re-entry/default semantics; portfolio fields remain scalars. Current defaults
and alignment are distinct operations (`R/strategy-state.R:178`, `:285`). A
fixed run-axis slot must not resurrect state after an instrument has left the
decision axis. Public names and shapes remain unchanged.

Only a private value read may return values/admission without public evidence.
Public history frames and matrices retain classes, names, shapes and recorded
structural metadata; long diagnostic reads return cell evidence immediately.
The read plan constructs metadata at `R/history-frame.R:1198`, and result
consistency and information readers consume it at `:1402` and `:1659`.
Deferring that observable attribute would change behavior. Later explanation
may use frozen retained summaries, never user-code replay or a mutable cursor.

Each mutable buffer has one owner. A view, result or retained input leaving
that owner is copied or never written again; tile eviction cannot invalidate
it. The lot book uses ordinary copy-on-modify. Preserve the handler's ownership
of retained events/legs and the diagnostic writer's chunk ownership under
[Typed Fold Carrier](../contracts.md#contract-execution-fold-carrier).

Reuse output services at their event, chunk, pulse and completion boundaries,
including the prefix before failure. Buffer growth does not defer publication
until run end. Canonical P4 checks a candidate failure against earlier event
publication (`R/fold-engine.R:1337`), installs its successful book before
publishing and advancing sequence (`:1359`), then updates positions and cash
(`:1386`); P5 flushes pulse events (`:1425`). Preserve stop installation,
append/flush order, condition precedence and recovery behavior. No new blanket
rollback promise follows from the word "commit".

## 5. First Checkpoint: What Must Be Demonstrated

The memory and complete-kernel claims remain separately reviewable under
Macro WS16 and the parent's Section 4. The first checkpoint also delivers
their shared stage recorder (Section 5.3), not a third execution family.
None of these claims is established by accepting this design. Sections 2
and 2.1 supply the interface and four-row check; Section 1's D2 gate applies
before any of this checkpoint's code is written.

### 5.1 Memory Preparation

Choose and measure tile width, resident-tile limit, backing/history access,
eviction and retained-view ownership within a declared working-set budget.
Any finite supported history request and `lookback = Inf` may span tiles;
neither a request nor `requires_bars` overrides that budget. The budget bounds
execution's prepared working tiles/buffers, not the legitimate total size of
source history, exact feature payloads, live lots, retained user views or
requested output. Count all of them in resident peaks.

Demonstrate exact cross-edge feature/history values and evidence, including
changed tile column order, entry/exit, re-entry/relisting, carry expiry and
late knowledge on both sides of an edge. Include full public reads and retained
views after advancing/recycling working tiles. Keeping every tile resident or
merely splitting a full output matrix establishes no bounded working set:
today's feature computation and payload splitting show those allocation costs
(`R/history-features.R:458`, `R/history-substrate.R:376`).

Report source/history, feature payload, resident tiles, summaries, transient
copies, lots, retained views and output separately, with parent, worker and
process-tree peaks. Vary history length at fixed tile width and worker count
on the parent's portable and registered scale shapes. The paired resource
protocol, its 1.10 limits and its exception route remain exactly
[Release Gates](../contracts.md#contract-verification-release-gates)
(C:3360-3382); a payload estimate or small fixture cannot close them. Direct
feature output into tiles and its preparation peak are hypotheses until run.

Measure disk-backed tiles against in-memory copies before deciding spilling;
this is no authorization for new worker transport or a dependency. The parent's
WS9b integration ownership and the contract's transport decision remain intact.
If exact supported reads cannot fit the proposed design, use the parent's
failure disposition; do not truncate, restart or refuse a previously valid
read to satisfy memory accounting.

### 5.2 Complete R FIFO Operation And Refusal Family

Extend the lean arithmetic to openings, fills and dispositions, including
replay, import and recovery inputs. The spike still calls the current kernel
on unusual rows (`dev/spikes/lean_fifo/kernel.R:18`, `:103`); its successful
fill timings do not prove independent refusal or non-fill coverage.

Cover signed opening quantities and finite basis of either sign, unchanged
opening compensation and no opening cash/Kahan step; zero-price dispositions
and exhaustion; replay witnesses; dust, reversals, close/open fee splits;
cached nets/basis and ordered totals; and earliest-row/within-row refusal
precedence. Compare the whole book and every applied field, preserving exact
event order and bits. Include negative witnesses and retained-input mutation
checks. Canonical input rules are at `R/lot-accounting.R:278`; ordered totals
and refusal selection at `:524` and `:549`.

Repeated-instrument streams are required coverage, but each kernel call still
contains distinct positions. Split into consecutive conflict-free blocks;
never combine repeated openings or reorder rows (`R/lot-accounting.R:731`).
Share boundary validators where appropriate, not an old arithmetic engine for
difficult cases. Preserve current books and event-derived position facts under
the parent's Section 3; delayed lots cannot substitute for non-fill coverage.
Ordered cash/affordability and compensated realized-P&L scans retain their
specified addition order. The sequential scans have a semantic reason under
the optimization style; replacing them with `sum()`/`cumsum()` is not permitted
where it changes that order.

### 5.3 Stage Recorder

Include the reusable stage recorder required by Macro WS16's "Stage parity
before end-to-end" (Macro:666-673) in this checkpoint's interface table and
deliverables. That bullet owns its placement, reference capture, comparison
rule and transition to end-to-end evidence; it is incorporated, not restated.
Later families reuse this recorder rather than building separate oracles.

The table must identify each recorded boundary's complete semantic input and
output, including state changes, emitted records and refusals where applicable.
A function's return alone is insufficient: P4 installs book/position state and
publishes through a handler (`R/fold-engine.R:1359`), and P5 flushes events
(`:1425`). Retained records must freeze the relevant values, not retain a live
environment or recycled buffer. Representation mappings must preserve axes,
order, bits and failure prefixes; a selected-field comparison cannot establish
whole-boundary parity. The initial coverage proves the memory/preparation and
complete FIFO claims above; it does not claim completed later P1-P3 families
or a complete candidate strategy run. Contracts still prevail over recorded
oracle behavior under Section 1.

## 6. Evidence Weight And Rejected Alternatives

The release-head source checks support P1-P6 and N1's semantic corrections.
Adopt P7's evidence qualifications. This synthesis performed read-only source,
contract and recorded-evidence checks, not new execution or timing: no probes,
compilation, full suite, package check, private catalog or scale-memory run.

Time-major tiles are a design choice with an observed tradeoff, not a universal
speed winner. The recorded orientation probe reports 14 versus 10 us for its
3,400-instrument pulse slice (`dev/spikes/data_layout/README.md:70`). Its
191 us history slice and the recorded 12,580 us complete public feature read
have different boundaries (`dev/spikes/data_layout/q2_orientation.R:17`,
`dev/spikes/data_layout/q7_history_read.R:33`). Preparation, spilling and worker
sharing are expressly unmeasured (`dev/spikes/data_layout/README.md:95`).
The fixed-basket floor/durable clocks, private-catalog payload estimates,
quickr conversion share, small-book copy costs and selected-field seam parity
remain qualified historical evidence as in v2; none supplies an acceptance
budget or complete-core speed/memory claim. Named stages are retained for
readability, isolation and attribution; scalar call timings do not prove
complete stage cost. Measure complete public history calls, including admission
and metadata, for P2; budget setting remains with the parent and Macro.

| Proposal or shorthand rejected | Decision and consequential reason |
| --- | --- |
| Per-tile size as the resident-memory bound; lookback overrides (P1) | Bind residency and count all resident components. An unbounded tile list and arbitrary public lookbacks defeat a per-allocation cap. |
| "Alive" or current membership as tile/history authority; one finally treated plane (P2) | Preserve physical-only inclusion and both clocks. Otherwise inactive prints, off-axis reads, carry and late knowledge change. |
| Whole-life or fixed-overlap indicator restart at tile edges (P2) | Keep existing calculation sequence and segment/knowledge semantics. Artificial restarts can alter both causality and floating-point results. |
| Trailing-valid or observed counts for all admission (P3) | Use exact finite returned-window counts. General `min_observations` and carried values disprove the shortcut. |
| Compare targets with previous intent; update FIFO only for fills (P4) | Compare with settled holdings and cover every accounting operation. Otherwise unmet exits and non-fill position facts disappear. |
| Plain public context, all-numeric strategy state, or absent/deferred public metadata (P5) | Keep boundary classes, declared types and frozen evidence. Numerical equality alone misses observable errors, shape and retention. |
| End-only recording, no dynamic checks, or a fill-only kernel checkpoint (P6) | Preserve publication/refusal prefixes and the complete operation family. Successful terminal outputs cannot establish failure behavior. |
| Permit only feature output-allocation changes (N1) | Adapt input access too. The existing dense indexing would otherwise require a second dense representation beside tiles. |
| Slice/floor ratios as stage budgets or total-memory proof (P7) | Compare complete matched boundaries. The cited timings and payload estimates omit required work and resident components. |
| Duplicate P6's workstream checklist here | Follow the response review's WS16 reference. Two operative copies would create competing process authority. |
| Use future extensibility to build an OMS, generic metadata/plugin layer or speculative asset fields now (D1) | Keep only the four named change boundaries. Future capability and its implementation procedure require their owning contracts and D2. |
| Treat skeleton acceptance or a recorder-only start as permission to code before D2 | The extension architecture acceptance gate covers all lean-core code; any changed bound structure needs a prior synthesis amendment. |

## 7. Remaining Decisions And Routing

**Open Questions Promoted To Spec-Cut / First Checkpoint:** the concrete field
interface, recorder capture boundary and validation placement; tile width,
residency, backing access and eviction; exact feature input/output adaptation;
and the measurements needed to choose those physical details. They are
constrained by Sections 2-5, not
permission to reopen history, admission or public semantics during coding.
No width, memory result or numerical family budget is invented by this record.
Later family scope/order, cut boundaries and the switch remain owned by the
parent and Macro, including WS16's "One family per cut" (Macro:681-684).

**Future Obligations Recorded:** D2's separate extension architecture cycle
is an accepted maintainer requirement and active pipeline entry, not a
speculative deferral. Its acceptance and any necessary amendment of this
synthesis are prerequisites to lean-core coding. Its design is out of scope
here. The [skeleton](README.md#lean-core-skeleton) and
[extension architecture](README.md#core-extension-architecture) rows own the
cycle routing. The memory/kernel/recorder obligations already belong to WS16;
transport and possible compiled escalation keep their existing owners and
triggers. No lazy-lot,
alternative-layout engine or incremental-feature project is chartered here.
Acceptance routing into the RFC pipeline/decision bridge and eventual
`tickets.yml` ownership follows `rfc_cycle.md`; those files are not edited by
this single-file synthesis task.

The maintainer response review accepted both Claude-drafted review framings;
their provisional status is resolved. The extra seed v2 review is retained
as a recorded cycle deviation. This synthesis is by a different author from
v2. Independent Type 1 final review remains pending; this session's source
checks do not substitute for it. No separate product-level binary choice is
escalated by this synthesis; stage 6 is now supplied by the maintainer's D1-D2
record.
