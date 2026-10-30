# RFC Response: Typed Fold Carrier for v0.2.3

- Status: Type 2 response v1; response review is next
- Author: Codex (not the seed author)
- Date: 2026-10-30
- Mode: Type 2, RFC cycle stage 3, per the maintainer-owned brief
- Seed reviewed: `rfc_typed_fold_carrier_v0_2_3_seed.md` v1
- Baseline reviewed: `16e8252d3a27794c7013d8980fae6d135d46bb48`
- Budget: at most 300 lines; document-only response, no new measurements

## 1. Disposition

**ACCEPT_WITH_CHANGES; revise before synthesis.** Typed positional columns,
batched R FIFO and indexed publication are the right WS4a direction: the
typed arm measures 27.17/27.07 us per fill with exact checked outputs
(`dev/spikes/ws4a-carrier-probe/typed_lots_findings.md:9-23`). However, the
seed leaves two orders conflated, omits diagnostic inputs, overstates trace
discarding, and replaces a bounded writer with unspecified run-long growth.
These are concrete design corrections, detailed below, not reasons to choose
native execution or delay the carrier until WS4b.

Keep the maintainer's Q1 and Q6 decisions. Neither has a concrete defect in
the reviewed evidence. Keep the scope and no-schema/public-API boundary in
`inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md:181-217`.

Citation shorthand below: **Seed** = `inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_seed.md`;
**Phase** = `inst/design/rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md`;
**Accounting** = `inst/design/rfc/rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md`;
**Authoring** = `inst/design/rfc/rfc_strategy_authoring_api_v0_2_3_synthesis.md`;
**Macro** = `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`.
References use the reviewed working-tree line numbers. Findings distinguish
source-established behavior, inference and proposed remedies.

## 2. What the evidence actually establishes

**Established by the recorded probe, not rerun here:** five paired fresh
processes, a 500-instrument zero-cost SMA workload, partial-heavy variant,
and ten identity cases support the typed R direction. The addendum explicitly
calls this bounded evidence and reports independent review pending
(`dev/spikes/ws4a-carrier-probe/typed_lots_findings.md:3-23`).
The original result remains INCONCLUSIVE; its R-plus-copying arm is not a
limit on optimized R (`dev/spikes/ws4a-carrier-probe/probe_findings.md:3-26`).
Thus Seed:64-66 supports "native unnecessary for the measured shape", not
"native never useful". Retaining the canonical default is independently
bound by `inst/design/contracts.md:377-390` (`contract-execution-compiled-accounting`).

**Inference requiring qualification:** the approximately 200 us improvement
is the combined representation intervention, not an isolated estimate of
lists/name lookup cost. Component clocks include payload validation/IDs;
Rprofmem excludes native allocation and RSS
(`dev/spikes/ws4a-carrier-probe/probe_findings.md:28-48`). The shape audit
explicitly labels F7 copies as inferred, not traced, and lacked availability
fill profiles (`dev/spikes/shape-audit/audit.md:74-80`). Preserve those labels.

**Correction to Seed:82:** a nonzero fixed-fee identity case does exist:
`dev/spikes/ws4a-carrier-probe/typed-check.R:19-22` compares the typed arm
with `--fee=1`, which selects `ledgr_cost_fixed_fee(1)` in `probe.R:172`;
`typed_identity.csv:13300-13302` records matching aggregates. This does not
cover a spread/notional chain or nonzero-cost timing. Also, LIFO runs through
the typed arm, but reorder/dropped-fee guts run through the native arm
(`dev/spikes/ws4a-carrier-probe/typed-check.R:28-43`). Do not describe all
three mutations as direct coverage of the typed kernel.

**Not established:** general cost-chain identity, deep-book scaling, bounded
peak memory, or production opening/disposition handling by this kernel.
The probe kernel has fill arguments only; its adapter reimports legacy state
after event-sequence changes (`dev/spikes/ws4a-carrier-probe/typed-lots.R:27-28,103-119`).
Passing a corporate-action fixture therefore does not establish that a typed
opening/disposition implementation was exercised. Seed:80-89 appropriately
lists important limits; its "costs are settled" wording at :228 needs the
distinction between settled semantics and untested vectorized implementation.

## 3. Required design corrections

### F1. Preserve two orders and two kinds of position facts

**Code:** affordability visits generator-first stable-ID priority, but returns
an acceptance mask in original order; the planner explicitly restores target
order (`R/availability-economics.R:350-388,513-516`). P4 emits in validated
target order (`R/fold-engine.R:1300-1302,1342-1393`). The contract explicitly
requires this difference (`inst/design/contracts.md:1181-1188`,
`contract-availability-affordability`). Seed:235-239 names only the scan order.

**Remedy:** carry an acceptance mask, a private affordability permutation and
`expected_final_cash`; compact accepted rows in decision-axis order for P4.
Do not sort the publication batch by affordability priority or substitute
virtual cash for the event-order cash accumulator. Preserve the existing
reconciliation arithmetic/tolerance (`R/fold-engine.R:1140-1168`).

**Code:** P3's diagnostic `position_after` is the planned `current + signed`
quantity, whereas P4 positions come from lots
(`R/availability-economics.R:489-505`; `R/fold-engine.R:1261-1270,1389-1393`).
**Inference:** merging them under one name can change diagnostic bytes at dust
boundaries or make planning a second position authority.
**Remedy:** P3 carries `planned_position_after` for existing diagnostics;
P4 alone produces actual lot-derived before/after, close/open quantities,
realized-close and ordered aggregate columns. Do not pre-apply lots in P3.
This preserves Phase:188-206 and Accounting:92-102. WS5 D2 must consume the
actual transition plus event kind and recording-bar identity, since non-fill
closures have different provenance (Authoring:89-122); add no D2 state now.

### F2. The proposed carrier table is not yet a complete contract

**Code:** rejected fills retain a resolved price when affordability rejects
them, and an execution timestamp even without a fill
(`R/fold-engine.R:1171-1213`; `R/availability-economics.R:438-452`). Seed:224
omits both. **Remedy:** add nullable resolved price and execution epoch to the
rejection columns, plus an explicit emission ordinal. Preserve early
rejections followed by affordability rejections (:513-514); do not globally
resort them. Preserve ordered, deduplicated multi-reason text (:334-341,375-382).
An integer code needs a fixed dictionary and ordered multi-reason representation,
not an unordered bit mask that changes the first reason.

**Code:** target validation requires complete coverage and reorders to the
context axis (`R/strategy-contracts.R:55-100`); held nonmembers remain on that
axis (Authoring:53-62). **Remedy:** full run-axis target columns use explicit
out-of-context `NA`, with `context_pos` defining valid elements. Never pad
missing user targets with zero. Define whether `actionable_pos` indexes the
run or context axis; carry the context ordinal where order is needed.
Current actionable indices index the target vector (`R/fold-engine.R:1063-1068`).

**Missing contract:** Seed:332-353 abbreviates whole column groups and omits
observation cash/value, feature/bar locators, `priced`/`permissible`, raw state
update, plan expected cash, result leg columns and dictionary definitions.
Phase:167-184,268-273 requires the packet and raw-state lifetimes. Enumerate
each carried column, missingness, empty shape, axis, writer stage and lifetime;
list referenced immutable services separately. Keep execution-bar columns out
of the P2 public adapter (`inst/design/contracts.md:393-399`,
`contract-execution-decision-and-fill-contexts`). Four conversion helpers are
too absolute while provider/valuation and corporate-action services still
accept named values (`R/fold-engine.R:347-365`; Seed:185-189): declare those
transitional adapters explicitly, without moving provider internals into WS4a.

### F3. One accounting implementation, explicit operation contracts

**Code:** opening appends signed lots and updates basis without cash or
realized-P&L changes (`R/lot-accounting.R:147-179`). Replay adds published cash
before applying each lot event (`R/accounting-replay.R:296-328`). The probe
kernel instead computes fill cash internally and always performs a Kahan
update (`dev/spikes/ws4a-carrier-probe/typed-lots.R:85-99`).
**Remedy:** one shared typed lot implementation, with explicit opening and
close/fill operations and a separate ordered cash-effects scan. Opening must
not pass through fill netting, price-positive validation or a zero-delta Kahan
update. Disposition permits zero price, requires exhaustive closure and keeps
its realized-model witness (`R/terminal-outcomes.R:156-198`;
Accounting:152-163). Consume already computed cash effects once; never add
both the replay cash effect and the probe kernel's cash calculation.

**Q3 answer:** route replay to that implementation in WS4a; do not retain a
second FIFO algorithm until WS7. Keep current metadata preparation and reader
architecture until their assigned cut (Macro:286-294; Accounting:175-211).
A typed-scalar adapter is acceptable; "one implementation" need not mean one
large function containing imports, cash publication and every operation.

**Inference, not a measured regression:** singleton replay calls to the probe
kernel can copy flat lot arrays per event: it aliases and writes those arrays
while its caller still holds the old book (:28-29,46,97-98). Include replay
time/allocation in the cut evidence before choosing this adapter. If material,
use ordered conflict-free blocks through the same kernel, retaining per-event
facts; do not waive a regression merely because WS7 is later. Preserve base
copy-on-modify until evidence warrants another ownership contract, as Seed:308-312
already proposes. This is a gate, not a claimed timing result.

**Q8 answer:** P4 has one target per context instrument and one proposed fill
per actionable target (`R/strategy-contracts.R:60-100`;
`R/fold-engine.R:139-180`; `R/availability-economics.R:433-511`). Disposition posting rejects duplicate
IDs (`R/terminal-outcomes.R:149-153`); after scheduled dispositions P1
re-observes before selecting held lifetime terminals (`R/fold-engine.R:389-418`).
Those successful batches support distinct positions. But openings explicitly
emit one row per carried lot, including repeated instrument IDs
(`R/fold-event-buffer.R:120-124`; `R/lot-accounting.R:187-196`). Therefore
distinctness is a *kernel-call* precondition, not a universal event-batch rule.
Keep sequential opening rows or partition ordered conflicts without reordering
the stream. Cash events need no distinct-instrument restriction. No new
execution-mode branch is needed.

### F4. Bound diagnostics and retain the semantic trace

**Code:** the existing writer caps chunks, splits blocks and replaces buffers
after handing out a frame (`R/availability-diagnostic-writer.R:94-100,117-171`).
Seed:266-270's geometrically growing run buffer supplies no bound or flush
policy. **Remedy:** typed per-pulse staging drained in P5 into the existing
bounded writer; retain stop drainage in E. A pulse larger than the chunk must
split safely. Do not retain all run diagnostics or introduce a second writer.
This follows Macro:188-201 and Phase:253-266,277-285.

**Q4 answer: not a blanket skip.** The memory sink keeps held decision rows
on stale/frozen marks, terminal dispositions and stopped rows, and preserves
sequence numbers as if all rows existed (`R/output-handler.R:353-377`).
Seed:273-274's blanket discard claim is false. Output retention is permitted
by `inst/design/contracts.md:116-126`, but only after the same semantic result.

**Proposed alternative:** a sink-owned retention descriptor may select which
diagnostic payload columns to materialize after shared stage logic determines
logical row count/order and retention inputs. Advance `diagnostic_seq` for
all logical rows; preserve retained row values and stop traces. Keep validation,
risk checks and state transitions unconditional. If implementing that separation
expands the cut, first build the typed full pulse block and retain today's
filter; correctness beats an unproved skip. Static source settles the blanket
claim; equivalence of a future selective builder requires a retained-row/sequence
comparison, not an assertion that economics alone is unchanged.

### F5. Keep publication ownership and WS8's boundary explicit

**Conflict:** Seed:252 makes the handler own the event buffer; :292 makes the
fold own it. Phase:253-266 declares the handler/writer as services, not carrier
slots. **Remedy:** fold owns transient semantic batches and economic state;
handler owns persistence/retention buffers; writer owns bounded diagnostic
chunks. Transfer or copy at append/flush. Do not enlarge the locked state with
duplicate buffers while claiming the slot set is unchanged (Seed:115-116).

**Q5 answer:** keep non-fill row builders for WS4a, adapted once at their
publication boundary into the indexed sink. Do not move their emission to the
end of the pulse: corporate cash and dispositions have distinct P1 mutation/
append order, before P2 (Phase:148-165). Their frequency is not the justification;
their evidence-column/JSON rewrite is explicitly WS8 (Accounting:213-227).
Clarify "one typed block per pulse" as fill publication, not a delayed merger
of every P1/P4 event. Route non-fill JSON and existing replay parsing explicitly
alongside fill metadata; Macro:78-83 permits routing, not ignoring it.

**Scope correction:** reuse Accounting's common field meanings internally,
but do not import its new DDL, evidence validator, fallback deletion or public
reader changes into WS4a (Accounting:75-90,152-184). Preserve current bytes and
memory auxiliaries. Compiled adaptation must cover *unpack* as well as pack:
unpack constructs the soon-deleted named-list book
(`R/compiled-spot-fifo.R:137-165,246`). Keep its C++ and opt-in envelope unchanged;
rebuild the typed book with a gather and carry aggregate/Kahan state exactly.

## 4. Remaining questions and acceptance evidence

**Q2:** keep the transitional P1 adapter. Provider/valuation floor work remains
WS4b (Macro:227-249). Do not promise precisely one match per pulse: P1 can
re-observe after each settlement boundary (Phase:158-160). Convert once per
produced view, reusing the mapping across columns; report adapter cost without
retiming the already settled zero-cost arm.

**Q7:** adjacent release-ready cuts, as proposed; WS4b consumes an accepted
carrier and does not redesign it (Macro:219-226). Q1's dense observation freeze
and Q6's unified equity typing stand (Seed:360-385). Equity needs a valid-row
count and separate last-valued/last-executed clocks for early stop/resume,
not merely five pulse-sized vectors (`inst/design/contracts.md:2657-2665`).

**Costs and validation:** vectorize each cost step in existing order, preserving
unrounded notional fees and final price rounding (`R/cost-model.R:407-420`;
`contract-execution-cost-model`, `inst/design/contracts.md:406-418`). This is
a sound implementation hypothesis, not probe-established IEEE identity.
Remove duplicate target shape/name normalization; keep property checks at new
transformation boundaries. Risk marks/equity still require runtime validation
(`R/risk-model.R:416-475`). Construction-time validation cannot certify future
callback results or aligned views (`inst/design/manual/optimization_coding_style.qmd:173-181`).
The cited fold-state validator currently neither checks a typed lot book nor
run-axis length (`R/fold-phase-contract.R:90-119`); it must be extended, not trusted
as though it already enforces Seed's table.

**Gate additions, proposed:** retain Seed:394-415's identity and shape gates,
but add chained nonzero costs on both sides, rounding edges, fractional dust,
short reversals on supported dense execution, repeated carried openings,
zero-price dispositions, scheduled skips, stops/resume and compiled pack/unpack.
Compare planned diagnostic positions separately from actual book positions
(F1), and preserved summary diagnostics/sequence gaps (F4). Compare logical
live FIFO contents and aggregates across changed internal layouts, retaining
existing registered oracles; raw new and old container serialization cannot
be identical (`dev/spikes/ws4a-carrier-probe/typed-lots.R:3-22`).

The scale gate should report peak live memory as well as cumulative Rprofmem,
including flat-book growth and replay, rather than treating bytes/fill as a
memory bound (`dev/spikes/ws4a-carrier-probe/probe_findings.md:44-48`;
`dev/spikes/ws4a-carrier-probe/typed-lots.R:66-73`). No new benchmark was
needed to establish the source defects above. Leave unknown performance as
cut evidence, using the shared harness and proportional cells (Macro:63-77).
Preserve the cold read and add an ownership/early-failure check against
Phase:197-219; equal successful outputs alone do not establish append atomicity.

Acceptance binds pending scope; it must not promote unimplemented table rows
as shipped behavior, contrary to Seed:355-356's unqualified move into contracts
(`inst/design/README.md:35-51`). No product, schema, API, seed or ticket change
is made by this response.
