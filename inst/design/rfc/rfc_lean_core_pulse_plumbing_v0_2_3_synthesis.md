# Lean Core Pulse Plumbing: Decision Synthesis

- Status: **proposed; not binding until accepted by the maintainer**. No implementation or acceptance installation is claimed.
- Mode: Decision synthesis, RFC cycle stage 7. Codex, 2026-11-06; author of neither seed v2 nor its co-written brief. The maintainer approved the Claude-drafted brief.
- Reviewed tree: `ef8be540ec2860434fb1453a83e7faf1256e44ba`. Git confirms no `R/`, `src/` or `tests/` difference from `d5b3a151`; that old fold remains the frozen oracle and is not edited.
- Inputs: [seed v2](rfc_lean_core_pulse_plumbing_v0_2_3_seed_v2.md), [Type 2 response](rfc_lean_core_pulse_plumbing_v0_2_3_response.md), [maintainer response review](rfc_lean_core_pulse_plumbing_v0_2_3_response_review.md), especially D1-D8. The review decisions govern over the seed.
- Citations are repository-relative `file:line` at the reviewed tree. Aliases: **C** = `inst/design/contracts.md`; **K**, **L**, **T**, **A**, **X** = respectively `inst/design/rfc/rfc_lean_core_skeleton_v0_2_3_synthesis.md`, `rfc_lean_fold_core_v0_2_3_synthesis.md`, `rfc_typed_fold_carrier_v0_2_3_synthesis.md`, `rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md`, `rfc_core_extension_architecture_v0_2_3_synthesis.md` in that directory.
- Final-review revision (2026-11-06): the [Type 1 final review](rfc_lean_core_pulse_plumbing_v0_2_3_final_review.md) (PASS_AFTER_PATCHES) patches for findings 1-11 are applied in place; no decision changed.
- **M** = `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`; **S** = `inst/design/manual/optimization_coding_style.qmd`; **B** = `inst/design/manual/benchmark_methodology.qmd`; **FP** = `dev/spikes/fold_plumbing`; other spike aliases below expand under `dev/spikes/`.

## 1. Decision

Adopt D1-D8 and seed v2's direction, with the corrected R1-R13 in Section 3.
Prepare and index once; check external inputs and each invocation of user code; trust internal producers and retain contracted economic refusals.
Carry references to immutable data and fresh computed values; write compact owned records and expand committed prefixes in bounded chunks. The recorder takes copies.

This deliberately removes production detectors for defects inside ledgr. Tests, debug assertions and finite parity evidence do not guarantee detection of every defect.
D1 accepts that risk; response finding 6 does not reopen it.
The response's property census becomes the module-test checklist, rather than a mandate to scan every derived value at runtime.

Three seed claims need correction before they can bind:

1. **R7 cannot defer economic effects.** P3 computes effects once; affordability,
   P4, reconciliation and sinks reuse those exact doubles. Deferring or
   recomputing them at the sink contradicts **Cost Resolution And Accounting
   Events** (C:531) and **Fold Core And Output Handlers** (C:193).
   Retain the two effects alongside the seven compact fields, or retain an
   immutable indexed owner of them. Defer formatting and table expansion only.
2. **LR-14 overreaches D1.** The P5 equality refusal and finite reconciliation
   refusal are different checks, with different classes (`R/fold-engine.R:1555`,
   `:1584`, `:110`). The latter is `ledgr_config_non_finite`, expressly retained by **Fill And Lot Validity** (C:749). The contracted `affordability_reconciliation_failed` stop (**Affordability And Reason Codes**, C:1428, C:1459) is P3's INCOMPLETE stop (`R/fold-engine.R:1178-1203`); the P5 equality abort raises the documented class (`R/condition-reference.R:186`). D3 retains all three. D3 retains these production
   refusals and their order; the spike's removal is not authorization to remove
   them. LR-14 below is a retained-contract entry, not a change entry.
3. **A chunk limit alone proves no failure prefix or total-memory bound.** R7
   needs the stop and visibility protocol below. Memory output, equity, live
   lots and retained public views can legitimately grow; the working-chunk
   bound does not abolish them (L:167; K:325).

The old oracle stays fixed. Deliberate differences are named in the ledger;
there is no automatic reference advance or rewritten expected output. No new
execution path, snapshot bypass, public debug option or compatibility reader
is authorized. Until the switch, shipped contracts and code continue to apply.

## 2. Evidence Audit Of Seed v2 Section 2

Numbers were checked against recorded evidence and enclosing code, not retimed. Units are microseconds per pulse unless stated otherwise.

| Seed row | Verified result and limit |
| --- | --- |
| Workloads and pin | FP/run.R:31-44 and FP/lean.R:37-45 construct 40 x 504 monthly momentum and 500 x 1,260 fill-heavy. FP/evidence/sizes.csv:16 gives median 54, maximum 86 fills. The blanket same-pin statement is too broad: r_floor/README.md:19 names `0d6c0b11`, and the FIFO evidence is an earlier spike. |
| Six successful variants, guts fail | Two in FP/evidence/parity.csv:2 and four in FP/evidence/lean_parity.csv:2, excluding gut/reference-trap rows. Reservation guts change events. These compare taped publication columns, diagnostic writer blocks/rows and six equity fields, not every public output, failure, leg or durable read (FP/run.R:73; FP/lean.R:338; FP/tape.R:212). A single loop plus correct counters supports alignment; it is not a proof for arbitrary producers. |
| Calls 3-6; reads 2-20 | Current saved call-only medians are **6 and 4**, so use 4-6, not 3-6 (FP/evidence/lean_timing.csv:13,27). Reads cost 2 by lean ablation and about 16/20 in the older skeleton (FP/evidence/timing.csv:9,15,24,30). These are stub calls/generated read plans, near clock resolution. |
| Plumbing 1,196-2,028, 32-62%; real 1,954/5,988 | **1,196 is unsupported.** Older matched pairs are 1,190.5/1,924.6 and 1,976.2/6,087.3: 61.9%/32.5% (FP/evidence/timing.csv:2,9,17,24). Newer skeleton medians are 1,244/2,027.8 (lean_timing.csv:15,28); 1,954.4/5,988.1 come from the separate edge-checks run. Do not combine their ratios as one matched measurement. |
| Removing internal checks: 1,954 to 1,389; 5,988 to 4,984 | Correct rounded edge_checks/evidence/timing.csv:2-5; reductions 28.9% and 16.8%. Its parity/edge records show unchanged compared tables and missing-target refusal. patch.R:11 removes carrier/append/payload/applied-row/P5 checks, but retains post-risk and lot-input checks (README.md:29); it is not an implementation of all R1-R13. |
| Data conditions 10/25 versus full carrier 238/389 | Correct: 9.9/25.4 versus 238.1/388.9 (FP/evidence/checks_timing.csv:4,6,9,11). checks.R:48-118 omits the execution view and measures append separately or in both arms. Its targeted conditions are a probe classification, not the D1 runtime rule. |
| Strategy 95 to 15, shuffled 30 at 500 | Correct for the **same_rules** arm; trusted-universe is 10/25 (strategy_check/evidence/timing.csv:14-19; arms.R:16). Not a whole P2 cost. |
| Append 243 to 63, C++ 40, 54 rows | Correct rounded 242.5/62.5/40 us **per block** (append_validator/evidence/timing.csv:8-10). arms.R:44-105 fast-paths typed all-FILL only; other kinds fall back. Read-path restructuring and mixed-kind performance remain unverified. |
| Fresh cheaper than overwrite; references cheaper | Supported for these implementations: old fresh-copy deltas 198.4/285.7 versus overwrite 257.9/333.3 (FP/evidence/timing.csv:3,7,9,14,18,22,24,29); reference lean 45.6/149.2 versus 77.4/225.4 (lean_timing.csv:4,12,18,26). Not a universal R allocation law (FP/sim.R:68; lean.R:95). |
| First lean 77/225; 31 ledger and 23 diagnostic columns; peer 214 | 77.4/225.4 and **31** ledger columns match. Diagnostic output is **22**, not 23 (`R/availability-diagnostic-writer.R:19`; FP/lean.R:57). The 214 peer figure is cited by r_floor/README.md:33-37 from another build; its original peer measurement was not independently verified here. It is not a matched complete-engine comparison. |
| Compact 22/71 including boundary; 6/33 loop | Correct rounded 21.8/70.6 and 6/32.5 (FP/evidence/lean_timing.csv:2,3,16,17). FP/lean.R:223-314 retains run-long fills and a per-pulse diagnostic list, expands only at end and recomputes effects. It does not demonstrate this synthesis's bounded, carried-effect, failure-aware writer. |
| FIFO about 2 versus 0.1 per fill; estimated 300/185 versus 6,000 per pulse | lean_fifo/README.md:45-48 gives 2.1 for lean R; :76-83 gives 7.5 per compiled core block, about 0.1/fill, excluding its wrapper. About 300/185 are rough sums: 71 + 103 fixed-basket work (r_floor/README.md:94) + about 113 R FIFO or the README's estimated 10 compiled us/pulse gives about 287/184. Neither total was run; overlap, wrappers, guards and broader economics are unpriced. This is quickr evidence, not a C++ implementation/default decision. |
| db_live 195 versus 9.4 seconds, 34 MB less heap | Correct: 195.38/9.445 seconds and 231.2-197.6 = 33.6 **MiB** of incremental R-heap peak (write_mode/evidence/timing.csv:2-3; worker.R:64-83). Ledger/equity/diagnostics match (parity.csv:2-7), not literally every store table: mode/config/telemetry differ. Failure and checkpoint behavior were not exercised. |
| Reference recorder wrong on 500/504 and 1,259/1,260 | Correct FP/evidence/parity.csv:11,21; run.R:105-114 checks retained target quantities, not every recorded field. It demonstrates mutable aliasing, not a universal last-pulse value for every field. |

The saved medians with raw records reproduce: 28 older skeleton, 10 check and 26 lean rows.
The older real-loop raw repetitions were not saved (FP/run.R:60, :222), so their medians cannot be independently recomputed.
Component removals overlap; their savings cannot be added or made into family budgets.
No recorded claim establishes stop, reserved-row failure, native, worker or scale parity.

Small read-only R 4.6.1 probes used the required `pkgload::load_all(...,
compile = FALSE)`. Runner: `C:/Users/maxth/ledgr-wt/pulse-plumbing-synthesis-out/synthesis_probe.R:1`;
output: `C:/Users/maxth/ledgr-wt/pulse-plumbing-synthesis-out/synthesis_probe.out`.
They confirmed hash inclusion, 31/22 column counts, the P5 nonfinite class,
sizing stale-evidence discard and malformed-evidence refusal. Locale and DLL
registration warnings occurred; native execution remains unverified. No full
suite, package check, timing rerun, durable run or vendor-data access occurred.

## 3. Exact Skeleton Amendment: R1-R13

At acceptance append this section's R1-R13 to K as `Amendment (maintainer, acceptance date): pulse plumbing`, linking this record and acceptance provenance.
These are the operative replacements, not seed v2 Section 4's shorter paraphrases.

**R1. Trust internal modules.** Internal hand-offs are not revalidated in
production. Module tests exercise each output property, including empty,
missing and overflow cases, using the response finding 2 census and Section 4
below. An internal debug mode restores all removed assertions with their
classes; the suite runs with it on, parity with it on and off, and recorder
and parity workers set it explicitly. Debug changes assertions only, never
arithmetic, ownership or publication. An untested module defect can escape in
production; that trade-off is accepted. R3's product refusals are exceptions
to assertion removal, not duplicate carrier scans.

**R2. Check external entry early.** Preparation checks snapshot data, marks,
prices, facts, provider vocabulary and every feature output, including custom
indicator returns. Preserve accepted missingness and the separately accepted
post-warmup NA decision; do not strengthen numerical admission. E checks
cost/risk declarations from ledgr constructors, schedule, parameters, state
declaration, imported/opening state and prepared execution epochs once.
After each strategy invocation check its full targets, intent, sizing attributes
and callback-exposed notes; check each dynamic history request where it enters.
State updates keep their once-per-decided-pulse P5 acceptance/normalization
boundary before installation, preserving refusal priority against P3/P4 work;
earlier preparation of a validation result must not signal its refusal early.
Stored ledger and deserialized/imported state keep complete entry checks.
An internal state/stop assembled from accepted values is debug-only checked,
including after E installs a stop. Do not call public validators again on those
hand-offs. Precompute conditional-admission information early, but issue an
R3 refusal only when its existing applicability and precedence require it.

**R3. Retain product refusals.** Keep their classes, messages, stages and
order: invalid/unaffordable execution requests, price/delta/epoch admission,
risk-mark/equity and post-risk admissibility/short-exposure policy, unsupported
economic kinds, lot input economic rules, overflow, transition/exhaustion and
replay-witness failures, terminal/settlement refusals, the P3 affordability reconciliation stop, P5 cash reconciliation
and nonfinite reconciliation values, staging capacity at its write point and
event-buffer capacity at its existing refusal points (fills at P5). Preserve import/cached-total limits in
**Typed Fold Carrier** (C:331); do not add all-book reductions. A full internal
applied-row scan may go, but any predicate implementing a contracted lot
overflow/invariant refusal stays in the kernel. D4 specifically removes the
generic append validator for ledgr producers; R3 does not reinstall it under
another name. Malformed internal-output assertions removed by R1/R4 are the
enumerated oracle differences, not retained product refusals.

**R4. No producer append check.** The fold's ledgr-owned producers, including
P1, openings, fills and compiled publication, append without the accounting
validator in production. Read preparation retains one grouped validator,
including cross-fetch sequence/time state and replay reconciliation. Debug
runs the write assertions without advancing publication state on failure.
Do not build a prepared accounting object merely to obtain append metadata.

**R5. Restructure kept checks.** Use one comparison for in-order target names;
otherwise one `collapse::fmatch()` aligns them, as M:943 already requires.
Keep every strategy-return refusal and its order, including empty-axis rules;
do not revalidate ledgr's context axis. Check a signal callback's raw signals
at its return and the resulting targets once across wrapper/P2, preserving
standalone wrapper behavior. Do not trust a class/attribute as proof of a
user-returned value. Run accounting kind sections only for present kinds;
read preparation still produces the carrier it needs. The fill-mark_age gap
is not corrected by this restructuring.

**R6. Pass references and indexes.** Prepared data is immutable. Pass its
positions and newly computed values without N-wide packet copies. Computed
stage outputs remain fresh, not reused overwrite buffers. Mutable output
buffers have one owner; public retained values are copied or never mutated.

**R7. Compact owned records, bounded expansion.** Each fill retains sequence,
instrument position, side, quantity, price, fee, execution epoch **and P3's
already computed cash_delta and position_delta**. The latter may be immutable
indexed columns, but must outlive their pending chunk. Output expansion formats
IDs, side text and constant/missing columns; it never computes effects again.
Diagnostic residuals retain typed varying columns plus pulse identity/offsets.
Working output expands and drains by a fixed row bound and at normal or
INCOMPLETE end, including an under-full final chunk. A pulse larger than the
chunk is split without publishing an incomplete logical fill batch. Working
storage is bounded by the chunk plus the prepared maximum pulse reservation;
do not accumulate a run-long list of pulse blocks. Retained memory results,
equity, source/history, lots and public views are accounted separately.
Section 5's prefix protocol is part of this rule.

**R8. One write path.** Retire db_live, the execution_mode argument, its control
override, config field, stored columns and reader/printing fields. Durable
writes use the in-memory chunk path within the invocation's one transaction;
chunks are not transaction commits. There is no legacy mode selector, ignored
compatibility argument or old-format reader. Change store version/fingerprint
and configuration identity as Section 5 requires.

**R9. Reserve, then commit.** Failed candidate calculation changes no handler
state. P4 installs the successful book, reserves/writes compact rows, advances
accepted sequence/time metadata and event sequence, records legs, then installs
lot-derived positions and ordered cash, preserving the contracted order.
P5 checks logical fill-event capacity before exposing the complete fill batch and
legs. Reserved, accepted and publicly committed extents are distinct; no
reader/flush/recorder sees an uncommitted suffix except the handler-local leg
projection for its own accepted range. Growth preserves outstanding ranges;
every reused row initializes every represented column/default. Debug append
failure advances no accepted boundary or committed count. Workers are
candidate-local. Handler failure aborts; no private-state rollback is promised.
The existing compiled arm keeps its state/sequence-before-append order until
its separately authorized WS14 replacement; R9 does not reorder that arm.

**R10. Write only diagnostic residuals.** P2's decision/risk segments stay
unexpanded until P3 certifies clean forms. Reserve logical positions for all
rows; write residuals directly into typed pulse staging. Preserve defaults,
keep gaps, logical offsets, codec associations, filters and sequence numbers.
P5 or E-stop drains and resets staging; handed-out chunks are frozen. Capacity
and R3 refusals retain their placement. No strategy replay supplies evidence.

**R11. Frozen floor v1 and two budget tests.** FP/lean.R:223's compact fold at
`2885596e` and its recorded 22/71 us boundary define floor v1, frozen for WS16;
this is the first plumbing baseline, not a release called v1. Preserve its
source and limitations. Measure each family's stage with every other stage a
stub, with matched workload, check mode and boundary. At cut, set a microsecond
budget for cost above floor v1 on both reference workloads from the family's
probe plus a stated small margin, and a line budget. Also pin the matched
old-stage boundary and no-regression bar before candidate scoring. Neither test
substitutes for the other. Close reports excess cost, both comparisons, profile
samples and lines. An overrun is fixed or explicitly accepted under L A2.
Floor-resident work is charged to its owner: P2 strategy check; output IDs, empty evidence and diagnostic binding; P3 owns the effect computation floor v1 runs at its boundary (`FP/lean.R:292`). Do not subtract it twice or erase a
regression by moving it between boundaries. Rebaseline only at WS14 after
switch; use the shared harness for before/after gates.

**R12. FIFO follows WS14.** Build the complete lean R operation/refusal family
first and keep it as executable oracle. Only WS14's measured residual-cost
route permits compiled FIFO; a focused Type 2 decision precedes a compiled
default. Use existing cpp11/C++, no new dependency, `-ffp-contract=off`; keep
the book resident in compiled form and convert only at boundaries. That change
retires spot_fifo.cpp. No compiled stage is authorized merely by these timings.

**R13. The recorder copies.** Freeze every captured value at its semantic
stage boundary, including relevant state, committed outputs and refusal
prefixes. Never retain a live environment or reused buffer as the record.
Record mappings and explicit debug mode; selected-field tapes do not establish
whole-boundary parity.

## 4. Check Census And Exact Rules-Ledger Installation

**Seed question 1: Section 6 is incomplete.** It omits complete state/stop,
equity, diagnostic-segment/writer, publication-input and settlement checks;
it also misclassifies the P5 refusals. The following is the disposition of
the response finding 2 census, including its common conditions. It does not
reintroduce finding 1's per-derived-property runtime proof requirement.

| Property family / source | Production disposition; module-test/debug obligation |
| --- | --- |
| Common field sets/order, bare storage/attributes, lengths, prefix n, NA/NaN/Inf policy (R/fold-carrier.R:207-254) | External inputs checked at entry. All internal group assertions debug-only, including numerical predicates; test each policy separately, with legitimate Inf/NaN exceptions preserved. R3 economic predicates remain independently. |
| Packet/data/execution (R/fold-carrier.R:257-294) | Data, provider vocabularies and opportunity admissibility established in preparation/E. Internal context/source mappings, restriction offsets, buyable/member, priced/mark equivalence and absent-bar shape are debug-only. Test source/time cutoff and overflow/missingness; the current checker alone never proves no-lookahead. |
| Decision/execution-view (R/fold-carrier.R:296-315) | Full callback return, intent, state/sizing and dynamic requests checked; risk/short policy stays. Context copying, actionable ordinals and provider reason-segment assertions debug-only. |
| Plan/fill/rejection (R/fold-carrier.R:317-383,460) | Partitions, masks, pos/k, order, kinds/declaration consistency, reason dictionaries/deduplication, planned-after identities and carrier arithmetic assertions debug-only. Keep actual request/epoch/delta/price, unsupported-kind, affordability and lot economic refusals under R3. Test expected-cash NA/Inf, overflow and phase missingness, not just valid fixtures. |
| Publication and append (R/fold-carrier.R:385-421; R/backtest-runner.R:92; R/output-handler.R:466) | Generated IDs/status/next, tokens/evidence defaults, duplicate payload input/epoch scans and generic append checks debug-only. Prepared epochs are not reparsed. Keep applicable R3 counter/capacity/economic guards; on read retain the full accounting validator and carried boundary state. |
| Lot input/book/applied, settlement (R/lot-accounting.R:286,351,549; R/fold-engine.R:200,229; R/terminal-outcomes.R:145) | Imported/replayed state checked. Internally produced shapes, repeated adapter alignment and applied-row self-consistency are debug-only. Keep kernel economic input, transition, overflow, disposition/exhaustion and replay-witness rules and the promised corrupt-book refusal; a class name alone does not classify a check. |
| Legs (R/output-handler.R:44; R/fold-carrier.R:423) | Order, token, range, split and OPEN-PnL assertions debug-only; arithmetic, fee split and event-order leg visibility unchanged. |
| Diagnostics/equity/stop/state (R/fold-carrier.R:437,821,876,970; R/fold-phase-contract.R:164,197; R/availability-diagnostic-writer.R:132) | Internal schema, scalar/length/coercion consistency, numeric/age/sequence, valued-time order, assembled stop and post-stop state assertions debug-only. Defaults/coercion results remain semantics. Keep staging/equity/event capacity refusals and P5 finite/equality refusals under R3; external/deserialized state checks stay. |

Append these exact rows after LR-11 in `inst/design/ledgr_v0_2_3_spec_packet/lean_core_rules_ledger.md:30`.
They cover this census; a repository-wide exhaustive refusal inventory remains unverified and is a switch-cut gate, not an inferred pass.

| ID | Rule | Found by | Disposition |
| --- | --- | --- | --- |
| LR-12 | execution_mode, including db_live, its argument/control/config, store and reader fields, is removed; one chunked write path replaces immediate inserts. | Pulse plumbing D6, Section 5 | change: R8; config identity and store format change; physical I/O timing/visibility differences are enumerated, not called exact parity. |
| LR-13 | Internal carrier packet/data/execution/decision/view/plan/fill/rejection/publication/leg schema, alignment, dictionary, partition, value and order assertions run only in debug; malformed ledgr output may no longer refuse in production. | Response finding 2; R/fold-carrier.R:207 | change: R1-R3 and Section 4; preserve external entry and contracted economic guards; debug retains original classes. |
| LR-14 | The P3 affordability reconciliation stop, P5 cash equality and finite reconciliation values retain their production stop and refusals, with their distinct classes and original order; the reconciliation row remains. | R/fold-engine.R:110,1178,1555,1584; seed v2 misclassification | contract: Affordability And Reason Codes; Fill And Lot Validity; R3. No oracle difference authorized. |
| LR-15 | Every ledgr producer omits the generic accounting validator on write; malformed internal rows may escape and an earlier append assertion need not beat a later lot failure in production; stored-ledger reads still validate. | D4; R/output-handler.R:466,666,699,734 | change: R4; debug keeps the nonpublishing earlier-prefix assertion path; no successful/failed-state rollback guarantee is added. |
| LR-16 | Post-risk numeric/length/finiteness rechecking is debug-only; post-risk admissibility, risk-mark/equity and short-exposure policy refusals stay. | D5; R/fold-engine.R:1016 | change: R2-R3; ledgr_invalid_post_risk_targets is no longer a production module-defect detector. |
| LR-17 | Internally assembled state/stop, diagnostic segments/staging/writer blocks and equity schema/value/used-prefix assertions, including after stop installation, are debug-only; capacity and contracted P5 refusals stay. | R/fold-phase-contract.R:179,208; R/fold-carrier.R:821,970; R/availability-diagnostic-writer.R:132 | change: R1-R3; names include ledgr_internal_error and ledgr_invalid_fold_execution; debug preserves each original assertion's class. |
| LR-18 | Duplicate fill-payload input/epoch and settlement-adapter shape checks are debug-only on ledgr-owned values; imported state and applicable execution/lot economic guards stay at their named boundary. | R/backtest-runner.R:98,114; R/fold-engine.R:229 | change: R2-R3; no broad deletion of ledgr_invalid_fill_intent, ledgr_invalid_args or ledgr_lot_state_invariant by class name. |

Leave LR-01-LR-11 pending until their existing A3 disposition; this RFC does
not close them. Do not move a registered production-refusal test to debug
merely to pass. The switch cut lists each semantic change, reason, replacement
property detector and retained negative witness for maintainer approval; direct
validator tests can remain direct tests. L:243's mechanical-remap permission
alone does not authorize a changed semantic assertion (AGENTS.md:28).

## 5. Failure Prefixes And Answers To Questions 2-4

**Question 2: no, R7 as written does not establish every prefix.** Adopt this
protocol with R7-R10. It preserves contracted accepted economics and evidence;
it does not promise retired live-mode transaction-local visibility or identical
physical insert-failure timing. D6 deliberately changes those.

| Boundary | Required behavior |
| --- | --- |
| Candidate calculation fails at fill j | No reservation, output/leg mutation, committed count, accepted append boundary or sequence advance. Evaluate only retained R3 earlier-row refusals in their old order; in debug also run earlier publication/append assertions without publishing. R4 intentionally removes those assertions from the production precedence chain (R/fold-engine.R:1454). |
| Successful candidate, P4 publication or leg failure | Retain book/position-fact installation before publication and subsequent sequence/leg/positions/cash order (R/fold-engine.R:1476). A failed range is not committed or flushed; discard a failed memory candidate, rollback the entire durable invocation. No promise to restore installed private state. |
| P5 event capacity | Keep ledgr_event_buffer_capacity_exceeded at P5, after P4's sequence/leg/state work and before fill visibility (R/output-handler.R:571). Reserving physical scratch space at P4 must not enforce that logical limit early. Chunk recycling must not change which rows count toward the limit. Today durable counts buffered fills since its last flush (`R/output-handler.R:673-686`) and memory counts every row, refusing P1 and compiled appends before P5 (`:699-705`, `:734-737`); the one-path counted population is a spec-cut choice, and any refusal difference is a ledger row. |
| P1/opening/non-fill publication | Publish accepted effects at their existing semantic boundary, not the next P5. Preserve append-before-state-install and terminal/corporate-action ordering. Mixed producers and compiled ranges cannot overlap outstanding fill reservations. A materializing handler read expands only committed compact ranges. |
| Normal P5, skip and multiple fill batches | Commit all accepted fill ranges for the pulse, then release legs in event order. Carry accepted last sequence/time independently of visible count and physical flush count, including multiple handler batches before P5. Flush full committed chunks once; never insert them again at final drain. |
| INCOMPLETE mid-chunk | E installs the stop once, with its original processed-count meaning; drain prior pulse staging plus that stop's physical rows, logical coverage/implicit codec and every already accepted P1 non-fill row. Do not create P4/P5 effects for a pulse stopped in P1/P2/P3. Drain all earlier committed compact events and the under-full tail before completion evidence and transaction success; use the exact valued equity prefix and distinct last-valued/last-executed clocks. This follows R/fold-engine.R:1947,1980,2003,2033 and R/fold-phase-contract.R:197. |
| Error/interrupt during any chunk/stop/final drain | Roll back all invocation writes, including earlier full chunks; preserve original condition and existing post-rollback exception/FAILED handling and refreshed diagnostic sequence (R/output-handler.R:93,118,643; R/fold-engine.R:2057-2083). No successful partial memory candidate; no worker durable writes or partially promotable interrupted sweep. |
| Growth, reuse, recorder and requested outputs | Preserve reserved and accepted ranges, initialize dirty suffix/defaults, expose committed rows only, reset or discard failed handlers. The handler-local leg projection may inspect only its own accepted range before P5. Freeze recorder/public values. Output retention is separate from bounded working storage (R/output-handler.R:415,761,774). |

Chunk size is a spec-cut choice. Required demonstrations include chunk size one,
a pulse exceeding one chunk, multiple batches, P1 events followed by P2/P3 stop,
growth/dirty reuse, append/leg/flush faults, skips, interrupts, and candidate
isolation. Proposed lean behavior is unverified until those witnesses run.
**Fold Evidence And Early Exit** (C:1524) requires normal INCOMPLETE completion
to preserve the accepted prefix; treating it as a thrown-error rollback or
flushing only full chunks would violate that contract.

**Question 3: callback-exposed sizing evidence is user output.** Keep
`ledgr_validate_sizing_evidence()` at P2, including its distinction between
malformed evidence (refusal) and stale but structurally valid evidence (discard
to unavailable intent, not refusal). A helper-created attribute can survive a
user transformation (`R/sizing-evidence.R:12-96`). `ctx$.notes` aliases
`services$pulse_notes` during callback execution (`R/fold-engine.R:819`);
helper writes at `R/strategy-helpers.R:688` do not make arbitrary callback
mutations trusted. Validate values that return across that exposure, or keep
the producer-owned state inaccessible and consume only its typed return.
Preflight restrictions (`R/strategy-preflight.R:392`) are not evidence that a
returned attribute is authentic. Add no trust-class or caller-set bypass flag.

**Question 4: no, the store bump is not the only identity impact.**
`R/backtest-config.R:155,188` retains mode both in engine.execution_mode and,
when supplied, engine.control.execution_mode. `R/config-hash.R:28-61` removes
neither; the probe confirms changing mode changes the hash. Walk-forward's
experiment payload retains it too (`R/walk-forward-identity.R:176-198`).
Removing it changes config hashes and dependent recorded identities. The
switch increments identity rule 5 to **6**, updates canonical config/session
and reproduction validation/fixtures for that rule, and records each affected
dependent hash; no claim that every candidate-key component changes is made.
Remove both mode fields, reject the retired control key, bump the then-current
store schema/fingerprint to its successor and refuse old formats with the
existing classed current-store/current-identity gates. No migration or missing
mode default is retained. Snapshot content, feature definitions, cost/risk and
policy identities are unchanged by this amendment. R8 does not authorize any change to `checkpoint_every`. Exact dependent pins and
store-version integer are settled against the switch baseline, not invented
from today's schema number.

## 6. Exact Installation At Acceptance

**Seed Section 5 is not complete.** Its named passages leave contradictory
scope/identity promises, repeated validation requirements, macro test freezing,
the manual guarantee graph and registered tests. Install the following together
in one acceptance commit; change no shipped contract rule or product code then; the only `contracts.md` edits are the pending back-links below.
Each named design record (K, L, T, A, X, M, S, B) gets a header link and the same local notice at every
addressed section: `For the pending WS16 lean core only, the pulse-plumbing
amendment supersedes the addressed clauses below. Shipped behavior changes
only at the switch; unrelated rules and historical rejection reasons remain.`
Link that notice to this synthesis and the appended K amendment, with actual
acceptance date/provenance. AGENTS.md, decisions.md, the ledger, claims.yml, the interface table and the pipeline row take only their given text. References to earlier amendments leaving other
sections unchanged are qualified by this narrow supersession, not erased.

Disposition of every row: **amended** (the addressed clauses are superseded for the pending lean core); every section not named is **unchanged**.

| Target / exact addressed scope | Operative replacement text or exact installation |
| --- | --- |
| K header; Sections 1, 2, 4, 5.2, 5.3, 6, 7; appended-amendment preservation clauses (K:53,136,300,365,387,429,438,480,525) | Append Section 3 R1-R13 and Section 5's prefix protocol. Add the common notice at each named section. Replace the pending-scope meaning of “public API ... identity unchanged” and of “does not authorize ... format change or correctness-rule change” (K:53-56) with “Only R1-R13's enumerated check, write-mode, identity and representation changes are authorized; every other public guarantee remains.” Section 2 validation placement and Section 7's open validation-placement question are superseded by R1-R5. Section 4 publication is R7-R10; Section 5.2 applied-row checks and Section 6's “no dynamic checks” rejection are qualified by R1/R3. Section 5.3 capture is R13. |
| L Sections 2, 3, 5, 6, 7, 8 and A2/A4 (L:69,78,94,104,116,210,243,295,332,336,413,428) | “R1-R5 supersede internal construction, transformed-value and applied-row rechecking, with R3 exceptions. R7-R10 replace the held publication representation. R8 and Section 5 authorize the listed public-mode/config/store/identity differences and their test dispositions; other parity and Q3 approval requirements remain. R11 defines A2 budgets above frozen floor v1 plus the pinned matched no-regression bar. R12 supplies the WS14 compiled route; no compiled family is authorized during WS16 by this amendment.” |
| T Sections 2, 3.1-3.6, carrier table publication/leg/state/stop rows, Section 5 failure/detector rows, Sections 6/8 (T:59,71,90,124,139,183,194,213,242,295,340,360,387) | “For the lean core, R1-R5 replace per-group/per-applied-row internal runtime validation; R3 economic refusals stay. R7 retains P3's single effect computation and replaces the retained publication block by compact committed ranges; R9 and the prefix protocol replace its buffer representation and preflush access rule. R8 explicitly supersedes no-API/no-identity/no-schema assertions for mode retirement. R12 routes later native residency through WS14; old WS4a scope/rejections remain historical.” |
| A Sections 1 item 3, 2, 3.3 ordering-boundary paragraph, 3.4, 3.6, Section 6 items 4/6/7, Section 7 rejection (A:31,58,145,152,223,300,315,319,340) | “For ledgr-owned producers in the lean core, R4 removes validation at append in production, including the nonpublishing assertion path; debug retains it. Read validation, carried sequence/time boundaries and lot-dependent replay reconciliation remain. R8 removes db_live from the write-path census. The rejection of read-only validation is superseded for these trusted producers; it still explains the earlier two-boundary decision. Format/identity changes follow R8 and Section 5, not this record's original WS7/WS8 identity statement.” |
| X Section 2 stage paragraph, Section 4 steps 2/5/6 and Section 6 unchanged-scope clauses (X:81,180,193,197,256) | “P2 omits the post-risk quantity recheck under R2, retaining R3 policy refusals; P5 retains R3 reconciliation. Record the R1-R13 validator/owner map and explicit mode/config/store identity differences. Family cost is cost above floor v1 plus the pinned matched no-regression bar under R11; line budgets, subtraction and the five-scenario affected-owner procedure remain.” |
| M rule 15 at :120 | Replace “construction-time validation” with “external-entry validation, debug assertions and contracted economic guards under R1-R5”. |
| M rule 16 WS16 exception at :139-144 and WS16 “Every family close” at :737-741 | Replace each budget prescription with “WS16 uses frozen floor v1 and stage isolation under R11: each cut sets cost-above-floor budgets on both reference workloads, a pinned matched no-regression bar and a line budget; close reports all three, profile samples and subtraction; any miss is fixed or explicitly accepted.” Other milestone rules remain. |
| M WS16 opening at :686-688; insert bullet after stage parity at :713 | Opening: “The lean core preserves public behavior except the explicit pulse-plumbing ledger differences.” New bullet: “Pulse plumbing: R1-R13 govern validation, ownership, compact publication and debug mode. Module tests cover the Section 4 property census; suite debug-on and parity debug-on/off, including workers, are mandatory. Floor v1 stays frozen until post-switch WS14. The switch owns this synthesis's Sections 4-7; the pin d5b3a151 is unchanged.” |
| M WS14a switch/subtraction at :805-830; WS14 and :990 kernel bullet | Append: “The switch's frozen-test rule permits only individually approved mechanical remaps and the semantic test dispositions explicitly authorized by pulse plumbing Sections 4 and 7, with unchanged fixtures and retained witness strength. Its enumerated behavior/identity/contract changes are an explicit exception to the subtraction cut's no-behavior rule. Historical test and evidence records are not rewritten.” At WS14 add: “Rebaseline floor v1 here after switch, retaining its frozen WS16 record; compiled FIFO follows R12 and this section's existing Type 2 gate.” In the :998 validation clause add “subject to R1-R5; contracted lot refusals stay”. |
| S Rules, :184-192; Clarity item 3 at :273 | Keep the validation paragraph and append: “In the lean core, validate external data and user-code returns at entry as early as possible. In the lean core, trust ledgr's internal transformations; their output guarantees are module-test properties and debug assertions under R1. Keep R3's contracted economic refusals. Sealing and hash verification remain mandatory.” Append to item 3: “In the lean core, validate at external entry; internal constructors are tested per property and checked in debug; retain contracted economic guards.” |
| S Rules new bullets; identity rule at :323; Scope Guards :498; Checklist :688 | Add: “Pass immutable references/indexes and fresh computed values; do not copy N-wide packets or reuse computed-output buffers. Write compact records carrying P3 effects; expand bounded committed chunks under R7-R10 and freeze recorder captures.” Append to identity/scope rules: “Pulse plumbing R8 explicitly authorizes mode removal and its configuration/store identity changes; no other identity or API change is implied.” Add after the :688 checklist item “Is this an external-entry check, an R3 product refusal or a debug-only internal assertion, and which module tests cover its property?” |
| S Sealed Snapshot Guarantee Graph :405-494 | Add local notice and add under the diagram, for the lean core, that node D is “External entry check, R3 guard, or internal tests/debug”. After :448 add “In the lean core, untrusted entry helpers fail closed; trusted internal helpers need not retain production defensive assertions under R1. Preserve sealing, hash verification and R3 refusals.” Before :481 insert “For lean-core internal transformations this dependency declaration names unit-test/debug guarantees, not additional runtime validators.” Historical evidence remains labeled historical. |
| B Before/After Regression Gates :205 and Attributing A Change :339-344 | Insert at the end of each section: “WS16 family budgets use frozen floor v1 with only the owning stage active; other stages are stubs. Measure cost above floor on both reference workloads and a separate matched pinned no-regression comparison under R11. Charge floor-resident work once to its owning family. Include retained guards, copies and bounded output expansion in the declared boundary; report loop and boundary clocks separately. Per-function samples supplement these gated comparisons; WS16 is excepted from the milestone-only rule. Paired gates use the unchanged shared harness/protocol rules.” |
| AGENTS.md:50-52, existing oracle paragraph | Replace that paragraph by three lines: “- Contracts and specifications define semantics; canonical R is the normative executable oracle for optimized or compiled paths; runtime default is separate and divergence fails closed pending RFC.” / “  In the lean core, validate external entry and retain contracted refusals in production; check internal hand-offs only in debug.” / “  [Pulse plumbing](inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md) binds module-property tests, suite debug-on and parity debug-on/off.” This replaces three lines, preserving 149 lines and the temporary dev-only note. |
| inst/design/decisions.md:31-34 | Keep existing rows; append to lean-fold/skeleton/core-extension owner cells: “Amended in pending WS16 scope by pulse-plumbing Sections 3-7; not implemented.” Insert the three exact bridge rows below. |
| Interface table named by seed v2 | At `33fc56eb` `lean_core_interface.md` is an uncommitted LDG-3211 draft with a Section 10 Validator column, Section 13 (Guarantee / Checked at / Trusted after) and Section 14; Section 13 cites seed v2. Do not create a second table. The commit that lands or next edits it repoints seed v2 to this synthesis, marks its Fold state, Diagnostic staging and post-risk rows debug-only under LR-16 and LR-17, and installs this exact notice and requirements in its existing validation/recording sections: “R1-R5 and pulse-plumbing Section 4 decide validation placement. For every field record type, axis, unit, invariant, producer, owner, external validator and phase, retained R3 refusal/class/order, debug assertion and module-property test. Internal construction is not a production validation boundary. Publication retains P3 effects and uses R7-R10 committed ranges, including P1 and stop drainage. Recorder captures are copied at the semantic boundary under R13; worker debug mode is explicit.” Preserve the observable-data guard and all five affected-owner notes; fill concrete field rows before checkpoint code, not placeholders. |
| Rules ledger | Append Section 4's exact LR-12-LR-18 rows. Do not install seed v2 LR-14 or describe every row as a change. |
| `inst/design/contracts.md`: Fold Core And Output Handlers, Typed Fold Carrier, Event Staging And Parallel Sweeps, Cost Resolution And Accounting Events, Execution And Feature Identity, Current Store Format, Telemetry And Recovery | Under each heading add `Accepted change pending: [lean core pulse plumbing](decisions.md#lean-core-pulse-plumbing-checks).` No rule text changes (`contracts.md:9-13`). |
| tests/claims.yml:4505,4517,4529,4889; registered blocks discussed in Section 7 | At acceptance append to each affected source string: “; pending WS16 pulse-plumbing Sections 4 and 7, current shipped detector unchanged until switch”. Do not change detector/profile membership at acceptance. Section 7 specifies switch dispositions. |
| inst/design/rfc/README.md:113 | At acceptance set this row to “Obligations open”; link this synthesis Sections 3-7 and acceptance provenance. Replace Next/Route by “WS16 families and WS14a switch own installation, failure-prefix proof, check census and identity change; tickets.yml takes ownership at cut. Final-review disposition is linked here. The fill `mark_age` read-validator gap (Section 8) awaits its separate maintainer decision.” No batch evidence essay or new ticket sequence is created. |

Exact decisions.md rows, using its existing five-column table:

```text
| <a id="lean-core-pulse-plumbing-checks"></a>Lean core trust and check placement | [Pulse plumbing Sections 3-4](rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md#3-exact-skeleton-amendment-r1-r13) | Accepted; awaiting WS16 families and atomic switch | [Fold core](contracts.md#contract-execution-fold-core); [carrier](contracts.md#contract-execution-fold-carrier) | [WS16/WS14a](ledgr_v0_2_3_spec_packet/macro_plan.md#ws16-lean-fold-core-accepted-synthesis); tickets.yml when cut |
| <a id="lean-core-trusted-append"></a>Trusted producer append checks | [Pulse plumbing R4](rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md#3-exact-skeleton-amendment-r1-r13) | Accepted; awaiting WS16 families and atomic switch | [Accounting events](contracts.md#contract-execution-accounting-events) | [WS16/WS14a](ledgr_v0_2_3_spec_packet/macro_plan.md#ws16-lean-fold-core-accepted-synthesis); tickets.yml when cut |
| <a id="lean-core-one-write-path"></a>One write path and identity | [Pulse plumbing R7-R9 and Section 5](rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md#5-failure-prefixes-and-answers-to-questions-2-4) | Accepted; awaiting WS16 families and atomic switch | [Event staging](contracts.md#contract-execution-event-staging); [execution identity](contracts.md#contract-execution-identity); [current format](contracts.md#contract-persistence-current-format) | [WS16/WS14a](ledgr_v0_2_3_spec_packet/macro_plan.md#ws16-lean-fold-core-accepted-synthesis); tickets.yml when cut |
```

This replaces specific clauses, not entire parent syntheses. The observable-data
amendments, five-scenario ownership check, one causal owner, P1/P2 isolation,
snapshot trust, ordered arithmetic, import limits and exact logical trace stay.
Contracts remain deliberately different until switch; they describe the old
shipped fold, not a license to call the lean core from R/. The additional
installed notices remove the identified pending-scope conflicts; completeness
against an unpublished interface or every uninspected historical artifact is
unverified. The switch's live-source census must find no remaining operative
contradiction, rather than relying on the seed's table as a complete census.

## 7. Switch-Cut Obligations

The atomic switch promotes these semantic replacements into shipped contracts/code.
Record each ledger difference against `d5b3a151`; unlisted output/economic differences fail closed under L A3.

| Stable contract rule group / source | Required contract and code disposition |
| --- | --- |
| **Fold Core And Output Handlers** (C:100) | Replace internal state/post-stop, post-risk quantity and P3 constructor-validation requirements by R1-R5. Keep callback/state/history entry validation, the economic gates and order, one run/sweep core, P1-only substrate access and no lookahead. Restate P4/P5 in R7-R10 terms, with P1 publication and E-stop drains explicit. Preserve both equity clocks, logical diagnostics and failure prefixes under Section 5. |
| **Typed Fold Carrier** (C:242) | Keep field types, axes, meanings and module guarantees; replace blanket construction-time runtime validation/classes by the Section 4 disposition and debug classes. Replace the retained publication group/ID-per-fill boundary by compact committed ranges plus output expansion. Preserve lot input/overflow/transition/replay guards and accepted import/cached-total limits; do not silently drop the corrupt-book refusal. |
| **Event Staging And Parallel Sweeps** (C:468) | Replace pending wide blocks/live per-fill inserts with R7-R10 reservations, committed extents and bounded expansion. Keep the handler-local preflush leg exception and P1 publication timing, complete logical fill batches, candidate-local state, no worker writes and discard-all parallel interruption. Physical chunk flushing is not logical publication or transaction commit. |
| **Cost Resolution And Accounting Events** (C:526) | Retain P3's one delta computation and unchanged carried effects; explicitly remove trusted-producer append validation and retain read/replay validation. Correct the “Replay validates ... before append” sentence at C:561 to “Stored rows are validated on read before replay; ledgr producers are asserted only in debug under R4.” Keep terminal event/lot/cash/summary atomic meaning and pre-append failures. |
| **Fill And Lot Validity**, **Affordability And Reason Codes**, **Fold Evidence And Early Exit** (C:711,1425,1523) | Keep R3's economic refusals, especially valuation overflow reaching P5 as ledgr_config_non_finite and reconciliation/prefix requirements. Make removed internal assertions explicit exceptions to generic validation wording; do not remove the promised economic behavior because a carrier/self-check once implemented it. |
| **Telemetry And Recovery**, **Execution And Feature Identity**, **Current Store Format**, **Construction And Validation** (C:841) | Remove execution_mode telemetry/reader/config teaching (C:1689); update identity rule 5 wording at C:677 to rule 6 with removed mode fields and dependent identities; bump store schema/fingerprint and current gates. Preserve snapshot hashes, old-store refusal and recovery. No silent deletion of the obsolete control key from an otherwise accepted old config. |

Code ownership includes `R/experiment.R:255,377,697`,
`R/backtest-config.R:92,155,188`, `R/run-prepare.R:41`,
`R/backtest-runner.R:531,605,820`, `R/output-handler.R:76,154,466`,
`R/db-schema-current.R:42,116`, `R/run-store.R:116,195,231,544,1057`,
config/hash/session/reproduction readers, and every publication producer,
reader, worker and documentation surface found by the cut's source census.
Delete live dispatch/writer paths rather than preserve an ignored mode.
Update exports/formals/roxygen, public examples and NEWS for the API/identity
break. The new schema number is the successor at that cut; bump other stored
format versions only if their representation changes. R12's later compiled
default still needs its own WS14 decision and dispatch-contract disposition.

Tests and registries need explicit semantic dispositions, not an automatic
“turn debug on” edit. `tests/claims.yml:4505` LCL-0506/LTB-0515-0516 contains
both a surviving single-effect authority and retired live-writer validation;
retain the former, replace the latter by single-path/transaction witnesses.
LCL-0508/LTB-0518's frozen method sets (:4529) need an approved representation
remap. LCL-0539/LTB-0550 (:4889) keeps the read field matrix, cross-block and
replay mutations; move only its trusted-write assertion witnesses to explicit
debug, and update its schema pin for the authorized store change. LCL-0507's
durable compiled-dispatch refusal remains until a separate decision changes it.
`test-ws4a-carrier.R:2159` keeps P3-carried-effect routing but changes its
wrong-effect production assertion to debug under R4; `test-risk-fold.R:949`
and `test-ws4a-carrier.R:1488` distinguish direct validator properties from
production post-risk checks. Census all affected blocks and API/hash pins;
these examples are not a blanket waiver. Keep fixtures/oracles and negative
witness strength, record each approved before/after mapping and reason in
ticket evidence, and run positive/refusal parity in both debug modes.

Before switch: every Section 4 property has a module-test owner; Section 5
prefix witnesses run through durable and memory sinks; no reservations leak;
floor/stage budgets and pinned comparisons close; full-boundary recorder
parity, existing resource/recovery/worker/private-reference gates and the two
holistic reviews pass or have explicit disposition. Required implementation
tests/package checks belong to that cut; none is claimed here. Install the
single core, delete the old runtime fold/kernel and temporary AGENTS note,
retain the external oracle/tag and rewrite living references as M:805 requires.

## 8. Rejections And Routing

| Rejected wording or recommendation | Reason |
| --- | --- |
| Response findings 1/6 as a requirement to prove each new property with production checks | D1 explicitly chooses tests/debug/trust and accepts missed module defects. The census remains valuable test design. |
| Seed's blanket claim of unchanged refusals and its LR-14 removal | R1/R4 deliberately remove internal detectors; D3 separately protects economic/reconciliation refusals. Their classes and precedences must be distinguished. |
| Seven-field compact record computing effects at output | Violates the single P3 economic computation; compact storage must retain its exact effects. |
| Bounded chunks alone imply every prefix and bounded total memory | Omits stop tails, P1 events, reservations and retained results. Section 5 supplies the operational contract; physical live-write visibility is deliberately retired. |
| Response finding 4's live exception or production append dry validator | D6 retires live and D4 removes append checks. Retain the range/visibility protocol, D3 prefix checks and debug-only dry assertions. |
| Seed's one base match() as an exact algorithm mandate | M:943 already binds collapse::fmatch(); the useful rule is one alignment at the user boundary. No repeated internal ID matching is authorized. |
| Treat helper sizing classes/notes as trusted after callback exposure | User transformations preserve attributes; R2 must validate this entry, while stale evidence still becomes unavailable rather than a new refusal. |
| Ablation savings as budgets, the compact spike as production implementation, or 300/185 as measured totals | Boundaries overlap and missing work is material. D7's frozen floor and two independent comparisons bind; numerical family budgets belong to cut evidence. |
| Acceptance installs shipped behavior, generic test remaps authorize semantic weakening, or a schema bump alone covers identity | Conflicts with the governance process, AGENTS and actual hash payload. Acceptance installs only the explicit pending amendments; switch has separate evidence and versions. |

**Open Questions Promoted To Spec-Cut:** choose the concrete chunk row bound and its relation to `engine.checkpoint_every` (a hashed pulse-count flush control, `R/backtest-config.R:93,192`): keep its meaning, or record its change as an explicit identity change with its own ledger row;
maximum pulse reservation, the event-capacity counted population (Section 5) and range/token API within Section 5; name the
internal debug mechanism and worker propagation without a public knob; complete
the concrete interface/property-test map and individually approved test census;
pin each family budget/noise bar and the switch's dependent identity fixtures
and schema successor. These are constrained implementation choices, not an
invitation to reopen D1-D8 or postpone prefix semantics.

**Future Obligations Recorded:** the existing conditional WS14 compiled-FIFO
route remains, with R as oracle and its focused Type 2 default decision.
The shipped fill-mark_age read-validator gap (`R/accounting-replay.R:259-274`;
append_validator/evidence/parity.csv:29) stays routed to the separate maintainer
decision in response_review.md:135; this synthesis neither fixes it nor
authorizes silently stronger read rules. No additional speculative project is
chartered. Acceptance routes unowned obligations through the RFC pipeline and
decisions bridge until tickets own them (`inst/design/rfc_cycle.md:163,187`).

Independent Type 1 final review remains next; these stage-7 checks do not substitute for it.
Only this proposed synthesis is written in the repository.
