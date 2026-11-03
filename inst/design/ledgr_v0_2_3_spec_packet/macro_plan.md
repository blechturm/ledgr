# ledgr v0.2.3 Macro Plan

**Status:** Accepted by the maintainer on 2026-10-28 (revision 8, written by
Claude and amended by the maintainer). It is the within-release order for
uncut work. Revision 2 applies
the [Type 2 review](macro_plan_review.md) (RESTRUCTURE) as dispositioned in
the [response](macro_plan_response.md), the maintainer's scope answers of
2026-10-28 (Section 6) and the release-process proposal of the same day.
Revision 3 records the accepted typed-accounting synthesis of 2026-10-29 and
moves WS8 into one ordered cut with WS7 after execution-core consolidation.
Revision 4 records the maintainer's 2026-10-29 fold-carrier amendment: the
dense oracle now precedes a focused design and implementation of common typed
stage carriers, which precedes removal of the second execution path.
Revision 5 records the maintainer's 2026-10-31 performance-convergence
amendment: the post-consolidation peer record now leads to one bounded,
evidence-driven optimization cut when the finished core misses its targets.
Revision 6, accepted separately by the maintainer on 2026-10-31 before this
cut was drafted, records the peer-scaling amendment: warm
book lifecycle, real parameter grids, worker-level candidate batching and
feature preparation become named evidence instead of being hidden inside
setup or strategy time.
Revision 7 records the maintainer's 2026-11-01 WS4b decisions after Cut 5:
the implied bar-native pulse clock, strict dense coverage, removal of the
exported `ledgr_backtest()` constructor and one structured final-pulse
non-execution diagnostic, plus the Option B rule that a fixed basket is the
full-membership, always-tradable, never-stale case of the canonical substrate.
Revision 8 records the maintainer's 2026-11-02 entropy amendment: a hot-path
ban-list test that may only shrink (rule 17), and one holistic review of the
core and the test suite with two subtraction cuts (WS14a) between the
WS7/WS8 cut and the WS14 measurement.
Inputs: the roadmap and the [inventory reconciliation](inventory_reconciliation.md).

**Release goal:** a coherent, readable path from declared features to
portfolio targets and inspectable results, on one consolidated and faster
execution core, with the debt deferred to this release paid and a release
process that certifies one candidate once.

This plan records dependency order and workstream boundaries. It does not
override contracts or accepted RFCs and authorizes no production change. Once
a cut is accepted, `tickets.yml` alone sequences it. Inventory IDs (C1, X3,
...) refer to the reconciliation.

## 1. Planning rules

1. **Two tracks.** Decided work is implemented now; the remaining RFCs run
   beside it. A design finishes before the code it governs, not before all
   code.
2. **Measure, cut, review, implement.** Each implementation workstream
   measures its baseline, writes its cut, gets a Codex cut review, then
   implements. Close reviews walk the seven optimization antipatterns and
   record an end-to-end timing.
3. **Hard edges are labelled.** Section 2 marks each edge as a technical
   prerequisite, a binding constraint, an evidence prerequisite or a
   preference. Only the first three block.
4. **Oracles before deletions.** Current native outputs are recorded before
   any handler or engine code changes. Dense-mode removal is checked against
   the peer suite's dense parity lane, those outputs and the frozen v0.2.2
   real-data reference.
5. **Identity is recorded per cut.** Each cut states its impact on snapshot
   content identity, run configuration identity and the store format
   fingerprint, and refuses incompatible artifacts when it lands. No reader
   keeps an old store usable. Development uses fresh fixtures; the private
   Sharadar lake is rebuilt once, at the final format/data freeze after the
   last identity-changing cut.
6. **Every cut is release-ready.** Each cut records its release-impact class
   (product tests, documentation, schema/identity, dependencies, performance
   records, none) and updates tests, examples, teaching and `NEWS.md` in the
   same cut.
7. **Teaching is acceptance.** The strategy API is accepted when its pattern
   article executes and every example passes the maintainer's cold read; a
   later cut that changes a taught behavior updates its example in the same
   cut.
8. **The release ends in promotion, not engineering.** A full release
   rehearsal runs before the final cut. The final cut contains only
   candidate preparation, certification and promotion; a product defect
   after certification rejects the candidate.
9. **CRAN is not assumed.** Work that only matters for the CRAN release
   (NEWS collapse, export-tiering timing) is conditional on v0.2.3 becoming
   that release (maintainer, 2026-10-28).
10. **Measure what is unknown, once.** Probes and spikes measure effects
    nobody knows yet. A cut cites an effect a spike already measured instead
    of measuring it again (maintainer, 2026-10-29, after cut 4).
11. **Measure while drafting the cut.** Before a cut is accepted it runs
    every oracle and checker it relies on against the unchanged base, on a
    later day than the recording when clocks can matter, and settles every
    surprise in the cut text, so implementation raises no new maintainer
    decision (maintainer, 2026-10-29, after cut 4).
12. **No separate A/A ticket.** An A/A timing run is needed only when the
    shared timing harness or the host changes; otherwise a gate's
    alternating pairs carry their own noise evidence (maintainer,
    2026-10-29, after cut 4).
13. **Proportional gates.** A timing gate covers the cells where the cut's
    changes carry real regression risk; an effect a spike already settled
    is cited, not gated (maintainer, 2026-10-29, after cut 4).
14. **No JSON on per-pulse or per-fill paths.** Fold, planning, accounting
    and reader hot paths carry typed vectors; canonical JSON is allowed only
    for identity hashing and cold, once-per-run records. A JSON encode or
    parse inside a loop over pulses, fills or events is a review finding
    (maintainer, 2026-10-30; `manual/optimization_coding_style.qmd`, Rules).
    Every cut touching those paths removes or routes the JSON it meets.
15. **Clarity is a design goal, reviewed like performance.** Representation
    changes follow the clarity rule in
    `manual/optimization_coding_style.qmd` (carrier contract, axis
    discipline, construction-time validation, readable canonical R, small
    explicit stages, commented indexing). The WS4a RFC includes the carrier
    contract table. The close reviews of WS4a, WS4b, WS7 and WS8 carry a
    cold-read item: a clean-context reviewer explains each changed stage
    from its code and the carrier contract alone, and a stage that cannot
    be explained is a finding (maintainer, 2026-10-30).
16. **Performance is checked at milestones, not gated per workstream.** The
    fold is rewritten across WS4a, WS4b, WS5 and WS7/WS8, so a timing or
    memory gate on one workstream measures a state the next one replaces.
    For the rest of v0.2.3, no workstream has a timing or memory gate; this
    replaces the timing parts of rules 2 and 13. Performance is checked
    against v0.2.2 after big milestones: after core unification (WS4b),
    after the WS7/WS8 cut, and at release certification, using the peer
    suite and the shared timing harness. A cut may still measure something
    to settle a design choice; that measurement is evidence, not a gate.
    Correctness oracles, cases and the real-data oracle run as before
    (maintainer, 2026-10-31, after workstream 12 timed twice). After the
    surviving core is measured, WS14 provides the one bounded response to a
    material miss; milestone deferral is not permission to ship an
    uninvestigated performance result.
17. **Hot-path bans are enforced by a test, not by prose.** Agents copy the
    nearest existing code more readily than they follow written rules, so
    one surviving instance of a banned pattern becomes the template for the
    next change. A test walks the call graph from the fold stage functions
    and fails on canonical JSON encode or parse, `match()`, `%in%`,
    `setdiff()`, `setNames()`, `unique()`, `data.frame()`,
    `as.data.frame()`, `rbind()` and `all.equal()` in any function reached
    per pulse or per fill. Current instances start in a recorded baseline
    that may only shrink; a new entry needs a stated reason accepted by the
    maintainer, such as the single `collapse::fmatch()` at the strategy
    target boundary (WS14, ID-matching amendment). The test lands in the
    next cut drafted after this amendment (WS6 or a chore cut), not inside
    the accepted Cut 7 (maintainer, 2026-11-02).
    **Amended (maintainer, 2026-11-02, later the same day): no enforcing
    test.** Cut 8 built the test and the maintainer withdrew it as tooling
    the WS14a test cleanup would remove again; the cut is not merged
    (branch `claude/rule17-banlist`). The bans stand and are enforced in
    review: close reviews walk the seven shapes, and code added to per-pulse
    paths may not add these calls. A one-off scan of today's instances
    (`dev/bench/v0_2_3_hot_path_scan/`, 267 calls in 186 function rows) is
    WS14a input. Read "rule-17 baseline" below as that scan, re-run by
    hand.

## 2. Dependency structure

```text
Phase A (now, parallel)
|-- A0 record current native outputs (before WS1)
|-- WS1 one output handler ................ first cut
|-- WS2 RNG reproducibility
|-- WS3 peer suite seed -> dense lane -> baseline timing on the current tree
|-- WS13 release-candidate CI RFC -> install floor -> CI jobs -> rehearsal
|-- WS9a memory and worker baselines; C3 placement RFC
|-- C4 pulse-seed counter (own Type 2 cut)
|-- RFC track: typed fold carrier, frame retirement, asset precision,
|   execution policy,
|   portfolio construction, docs roles, helper bundles, C9 mechanism,
|   typed-accounting boundary (field census, then focused RFC)
|-- WS11a H4 real-data audit; C10 census and coupling map
|-- WS5 preparation: spec cut, schema, selection, article drafts
`-- chores: roxygen pin, UX-brief reconcile, M8a, C12b
                              |
Phase B   WS4a typed fold carrier -> WS4b minimal C1 consolidation
                              |
Phase C   WS5 runtime ---> WS6 frame retirement --.
          WS7 -> WS8 typed accounting cut --------+--> J: disclosures,
          H10 settlement state                         pattern article,
                                                       cold read
                              |
Phase D   WS9b structural memory -> worker budgets -> H9 daemon reuse
          WS10 economics implementation (as each RFC is accepted)
          WS3 full suite timing after WS4b and WS8
          completed hot-path cuts -> WS14a holistic review -> product
          subtraction cut -> test cut (fold-core rebuild) -> WS14 convergence
                              |
Phase E   WS11b C10 ADR, H1, C9   WS12 documentation and debt
          final format/data freeze -> one lake rebuild -> integrated record
          -> editorial pass (after WS11b and WS14) -> rehearsal
          -> final cut: certify, promote
```

| Edge | Kind |
| --- | --- |
| A0 -> WS1 | evidence prerequisite |
| WS3 dense lane -> WS4a | evidence prerequisite: freeze both current modes before changing the common carrier |
| typed-fold-carrier RFC -> WS4a | binding constraint: the RFC fixes carrier authority, types, validation and allocation gates |
| WS1 -> WS4a | preference (less ownership conflict; the shared handler consumes the fold carrier) |
| WS4a -> WS4b | technical prerequisite: consolidate semantics only after both current modes produce the same typed contract |
| WS4b -> WS5 runtime | binding constraint: dense is frozen and synthesis D3 authorizes no new execution-mode branch |
| WS4b -> WS7/WS8 cut | binding constraint (roadmap: merge readers after one run shape) |
| accepted typed-accounting synthesis -> WS7/WS8 cut | binding constraint: the synthesis binds the authoritative fields, typed replay boundary and ordered workstreams |
| WS5 -> WS6 | technical prerequisite (synthesis D1 fixes the input layout) |
| WS5, WS6, WS7 -> J | evidence prerequisite for WS5 acceptance |
| WS9b budget decision -> H9 | technical prerequisite (inventory H9) |
| WS4b, WS5, WS6, WS7/WS8 and execution-sensitive WS10 cuts -> WS14 | evidence prerequisite: optimize the surviving core, not an intermediate representation |
| WS3 post-consolidation record -> WS14 | evidence prerequisite: the peer suite supplies the attribution and comparison |
| WS6 and the WS7/WS8 cut -> WS14a review | evidence prerequisite: review the surviving core once, not intermediate shapes |
| WS14a product subtraction cut -> WS14 checkpoint | evidence prerequisite: measure the core after deletion, so the optimization budget is not spent on waste |
| WS14a product subtraction cut -> test cut | binding constraint: each cut freezes the other side, so tests guard product deletions and the product guards test deletions |
| R2 decision, WS11b and WS14 -> editorial pass -> rehearsal | evidence prerequisite: edit the documentation once, for the surviving API and core, before certification |
| WS14a product subtraction cut -> final format/data freeze | binding constraint (rule 5): deletions that change identity land before the freeze |
| each economics RFC -> its implementation | binding constraint |
| R2 -> M5, M7; H4 -> M5 | binding constraint |
| H4 -> C10 ADR -> C9 | binding constraint (inventory chain 2) |
| last identity-changing cut -> lake rebuild | binding constraint (rule 5) |

The critical path is A0 -> WS3 dense lane -> WS4a typed carrier -> WS4b one
execution path -> WS5 -> J. WS1 precedes WS4a by preference.

## 3. Workstreams

### WS1. One output handler (C6, R3; H6 measured after)

One handler behind a DuckDB or memory sink replaces the persistent and memory
handlers and their parity suite. R3's fold-phase obligations ride here.
- **Route:** direct tickets; the first cut. **Gate:** byte-identical outputs
  against A0; committed-run versus sweep gap re-measured (H6).

### WS2. RNG reproducibility (X1, absorbs H8)

Pin the RNG kind wherever ledgr seeds; restore the caller's RNG with
`seed = NULL`; widen preflight RNG detection; one documented recipe.
- **Route:** direct tickets. **Gate:** 1- versus 2-worker equivalence for a
  strategy seeded from `ctx$pulse_seed`; the NMOF `LSopt` probe reproduces.
- **Amendment (maintainer, 2026-10-29):** widening preflight RNG detection
  leaves WS2 and is parked in the horizon ("Ambient RNG detection for
  strategies"); cut 4 decision (11) records why (accepted as cut 3, renumbered).

### WS3. Peer benchmark suite (X4, full scope)

Suite seed (lanes, workload contracts, parity oracles, timing boundaries,
deletion witnesses for C1). Then: dense parity lane and a **baseline timing on
the current tree**; authoring lane; scaling geometry, whole-universe portfolio
and the point-in-time demonstration row. All lanes are timed again after WS4b
and WS8 so the release can see where it stands (maintainer, 2026-10-28). The
post-WS7/WS8 record includes warm result reads and full run-plus-results time,
so eliminating accounting representations is measured end to end.
- **Amendment (maintainer, 2026-10-31, observed scaling record):** add one
  ledgr parameter-grid lane on the same prepared experiment at 10, 100 and
  1,000 candidates, with 1, 2 and 4 workers where admissible. It separates
  preparation, warm book lifecycle, feature/indicator preparation, candidate
  engine, worker dispatch/collection and retained output. This complements,
  and is not pooled with, the report's repeated one-candidate session lane.
  The existing strategy-first engine remains authoritative; the RED
  pulse-first spike is not reopened.
- **Current status (2026-10-30):** Cut 2 is closed. The accepted dense oracle
  at `cbf25359` and the accepted current-tree descriptive record discharge
  C1's prerequisite. Full peer-lane replacement and post-WS4/WS8 reruns remain
  WS3 work; product deletion starts only in an accepted WS4 cut.
- **Route:** RFC, then direct tickets per lane. **Rule:** no public
  performance claim until the suite exists and its results are accepted.

### WS4. Typed carrier, then minimal execution-core consolidation (C1, M8b)

**WS4a, typed fold carrier.** Before deleting either current execution path,
replace their common hot-path list graph with fixed typed stage contracts. The
public strategy `ctx` and strategy return stay ordinary ergonomic R objects;
P2 normalizes the return once. The internal boundary uses a fixed fold state,
a fixed observation made of atomic vectors, indices and shared references, a
normalized decision, one columnar execution/economic-event batch, a bounded
columnar diagnostic batch, and small typed stop/status and timing results.
It does not preserve list-per-fill entries, wrap the same fills in a second
`accounting_events` list, or repeatedly recover vectors with `lapply()` or
`vapply()`. Validation belongs at carrier construction boundaries rather than
inside each field read. No persisted schema or public API changes here.

- **Route:** a bounded allocation/profile probe, then a focused Type 2 RFC and
  direct tickets. The current dense and availability paths both produce the
  carrier before either is removed. **Gate:** A0, the dense oracle and the
  v0.2.2 reference preserve exact economics and event order; registered
  list-versus-columnar clocks and allocation records cover no-fill,
  sparse-rebalance and wide all-fill shapes; mutations detect reintroduced
  list-per-fill and growing diagnostic-segment representations.
- **Amendment (maintainer, 2026-10-30, shape audit):** the carrier also
  covers four representations the text above does not name. Evidence:
  `dev/spikes/shape-audit/`.
  - **Lot state (F7).** Typed flat segments on the run axis, applied once
    per pulse. Today it is a named list per instrument, with two axis-wide
    name lookups and a copy of the instrument-length vectors on every fill;
    that is 19% of a canonical sweep and 28% of a durable run. Lots stay the
    only position authority (typed-accounting synthesis 3.2).
  - **The event-batch buffer (P18).** It writes by index. Today
    `ledgr_fill_row_buffer_add_many()` copies whole environment-held
    columns on every call.
  - **The strategy return is validated once per pulse (P10).** Today
    `ledgr_validate_post_risk_targets()` repeats the full validation, even
    with an empty risk plan.
  - **The memory sink's equity record (P17)** is typed, with no
    `as.POSIXct` per pulse.
- **Amendment (maintainer, 2026-10-30, typed-fold-carrier acceptance):** the
  [accepted synthesis](../rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md)
  binds the carrier; the cut follows its Sections 3-5. One fold-owned
  equity record replaces both the availability accumulator (P4, moved here
  from WS4b) and P17. Dense emits the carrier from the normalized decision
  onward; its observation and context path is not retyped. WS4a and WS4b
  are adjacent cuts.

**WS4b, one execution path.** With the carrier fixed, consolidate onto one
execution path on the availability core, settle the disclosed implied
calendar, decide the fate of `ledgr_backtest()`, and add the final-bar no-fill
disclosure (M8b). The carrier is the common contract against which the two
current producers are compared; WS4b does not redesign it.

- **Amendment (maintainer, 2026-11-01):** Cut 6 binds four product choices.
  A fixed-basket snapshot without declared sessions derives a run-local
  bar-native pulse clock from ordered distinct bar timestamps; it invents no
  venue open or close and next-pulse execution keeps the next bar timestamp.
  Such a snapshot remains strictly rectangular over the requested instruments
  and executable range, with any missing bar refusing before the fold; missing
  data policies require declared sessions. The exported `ledgr_backtest()`
  constructor is removed, while the existing run-result class and methods stay.
  The final pulse is observed and decided normally, but a target requiring a
  later pulse produces no fill or accounting event and records the structured
  `final_pulse_no_execution` diagnostic without a warning or refusal. Cut 6 is
  a decision-bearing Type 2 spec cut and introduces no public policy knob.
  A fixed basket is the full-membership, never-stale case of the canonical
  prepared execution substrate; it adopts the declared-session path's history,
  carry, affordability, supported-target, evidence, failure, context, equity
  and finiteness semantics. The cut records every resulting dense-output
  difference explicitly rather than retaining a dense compatibility profile.

- **Route:** direct tickets, Type 2 at cut. **Gate:** dense parity lane, A0
  and the v0.2.2 reference unchanged, or each difference decided.
- **Amendment (maintainer, 2026-10-30):** WS4b also owns the consolidated
  path's per-pulse floor. Its evidence adds a timing comparison against today's
  dense path on the no-fill, sparse-rebalance and wide all-fill shapes. Macro
  rule 16 supersedes the earlier instruction to bind per-workstream timing
  bounds: this is a descriptive post-unification milestone, not a ticket gate.
  Per-pulse state normalization and serialization
  (no per-instrument padding for undeclared asset state), the availability
  context refresh, per-pulse valuation and diagnostic flushing are in scope.
  Evidence: `dev/spikes/ws4a-carrier-probe/` (availability floor 6.6 s
  against dense 2.1 s); a same-strategy no-fill profile attributes about
  2.2 s of the difference to padded state JSON and 1.4 s to context refresh
  (`dev/spikes/pmwr-performance/`).
- **Amendment (maintainer, 2026-10-30, JSON audit):** "diagnostic flushing"
  includes the reconciliation's per-pulse `detail_json` encode
  (`R/fold-engine.R:1462-1483`; audit row H5). The `canonical_json()` cache,
  which serializes and SHA-256-hashes every argument to look itself up (H4),
  is retired in the cut that removes its last per-pulse caller (WS4b or
  WS5, whichever lands last). Retiring it earlier makes the remaining
  callers pay full encodes. Evidence: `dev/spikes/json-hot-path-audit/`.
- **Amendment (maintainer, 2026-10-30, shape audit):** per-pulse valuation
  includes two more items (evidence: `dev/spikes/shape-audit/`):
  - the stale-mark trace's `all.equal()` call per stale instrument
    (`R/fold-engine.R:1002-1007`, I3);
  - the equity-fact accumulator's list per pulse, unpacked with `vapply()`
  at finalisation (`R/fold-phase-contract.R:164-190`, P4). Moved to WS4a
  by the typed-fold-carrier acceptance (2026-10-30).
- **Milestone disposition (2026-11-01):** the final Cut 6 candidate improves
  all three declared-session cells and the bar-native wide cell against
  v0.2.2. Against the post-WS4a attribution base, however, all three
  bar-native cells are red: no-fill and sparse are about 2.7 times slower and
  wide is 1.588 times slower.
  The matched telemetry probe locates the difference in the fold loop rather
  than cold preparation or finalisation: the bar-native no-fill loop moves
  from about 1.27 seconds to 5.46 seconds while the declared-session loop
  improves from about 6.34 seconds to 5.31 seconds. Both arms are installed
  packages; bar-native preparation moves from 0.58 to 0.80 seconds. This is the measured
  semantic premium of routing fixed baskets through the canonical substrate,
  not authority to restore the deleted dense path. WS5 owns the already-bound
  eager context removal; WS14 must reproduce all three red bar-native cells and
  profile the surviving P1/P2 loop before choosing any further optimization.
- C4 (pulse seed) and H10 (settlement state) have their own cuts; H9 waits
  for WS9b's budget decision.

### WS5. Strategy authoring API (X3; accepted synthesis)

Implement the [accepted synthesis](../rfc/rfc_strategy_authoring_api_v0_2_3_synthesis.md).
The spec cut resolves its Section 6 and registers its Section 4 evidence in
Phase A; schema, selection and article drafts may start then. The runtime
(flat `ctx`, position facts, verbs, declared state, schedule predicate,
required capital and costs) follows WS4b. H3 is settled in this cut.
- **Acceptance:** at J, on the merged reader: rounding and refusal
  disclosures, the executed pattern article and the maintainer's cold read.
- **Amendment (maintainer, 2026-10-30):** declared state keeps D5's
  author-facing semantics, but its stored form is typed vectors along the
  decision axis, not list-per-ID canonical JSON written every pulse. This
  supersedes D5's "retain list-per-ID asset storage". The WS5 cut decides
  persistence and resume checkpoints under the pre-CRAN refusal policy.
  Evidence: `dev/spikes/pmwr-performance/` (named-list state is about 20% of
  a wide run).
- **Amendment (maintainer, 2026-10-30, JSON audit):** `intent_reason` is
  stored as a typed string column in the diagnostic batch, not encoded as
  `canonical_json(list(intent_reason = ...))` every decision pulse
  (`R/fold-engine.R:886`, audit row H6). `ledgr_run_explain()` reads that
  column instead of parsing JSON (`R/availability-results.R:85-94`, H13).
  Evidence: `dev/spikes/json-hot-path-audit/`.
- **Amendment (maintainer, 2026-10-30, shape audit):** the flat `ctx`
  replaces the eager per-pulse `ctx$vec` / `bar_index` construction and its
  name matching on both producers (`R/pulse-context.R:804-1005`, P9). That
  construction is about 19% of the dense no-fill floor, and the WS4b
  amendment covers only the availability context refresh. Evidence:
  `dev/spikes/shape-audit/`.
- **Amendment (maintainer, 2026-11-02, ID matching):** the WS14 ID-matching
  rule applies already to the code WS5 touches. The close reviews of its
  target and state workstreams check it there: no per-pulse ID matching
  inside the fold, and an identity fast path before one `fmatch()` at the
  strategy's target boundary.
- **Implementation close (2026-11-02):** Cut 7 completed workstreams 15-18
  through `34a06c6d`. The flat lazy context, canonical position facts, plain
  selection and strict weights, ctx-first targets, required investor inputs,
  typed declared state, sizing evidence and executed strategy teaching are
  implemented and independently reviewed. WS6 receives the accepted flat
  layout; WS7 receives the D8 diagnostic fields. Join J remains open until
  the merged WS7 reader consumes those fields.

### WS6. Context frame retirement (C2)

The accepted
[context-frame-retirement synthesis](../rfc/rfc_context_frame_retirement_v0_2_3_synthesis.md)
binds the flat primitive context and the two explicit current-pulse inspection
helpers. Accepted Cut 9 implements it after WS5 and before J: remove the four retained
frame/bar surfaces without aliases, stop P2 constructing frames, preserve the
test-only fixture adapter, and rebuild `ledgr_pulse_features()` and
`ledgr_pulse_wide()` over the frozen primitive lookup. No bars helper, frame
DSL, helper performance promise, hash, seal or durable context is added.

- **Implementation close (2026-11-03):** Cut 9 Workstream 20 implements the
  primitive lookup and on-demand inspection boundary; Workstream 21 migrates
  maintained consumers, contracts and teaching, restores the exact surface
  census and completes final verification. The decision bridge is removed;
  the external-helper and historical-panel owners remain open.

### WS7. One result reader and print (C8)

Merge the three reader families behind one chunked, typed accounting projection
and one print path, as WS5's sibling after WS4b. The accepted
[typed-accounting synthesis](../rfc/rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md)
binds the authoritative fields and replay boundary. WS7 consumes WS4a's typed
execution/event carrier rather than defining another one. WS7 is the first
workstream of one cut with WS8: it leaves one typed replay projection, may
temporarily extract typed evidence from current JSON, and may not leave parsed
metadata as a second authority. Gate: every public table and print is
byte-identical or each difference is decided. M8a and C12b may land earlier on
the current path.
- **Amendment (maintainer, 2026-10-30, JSON audit):** terminal recovery
  rebuilds positions with one `ledgr_state_asof()` replay per pulse
  (`R/run-finalize.R:164-172`; audit row H10c), which is quadratic in pulses
  times events. WS7 replaces it with one replay scanned across the pulses,
  in addition to removing the JSON parse. Evidence:
  `dev/spikes/json-hot-path-audit/`.

### WS8. Typed P3-P5 execution batch (C7)

WS8 is the second workstream of the same ordered cut as WS7, still after WS4b.
It replaces the temporary extraction with direct typed publication on every
producer and durable write path, removes accounting-critical JSON, bumps the
store format to schema 125 with unconditional old-store refusal, and rebuilds
affected stores once after the cut. The compiled execution envelope is not
edited. Bounded no-fill, sparse-rebalance and wide all-fill comparisons remain
part of its evidence.
- **Gate:** the synthesis's Section 6 evidence, end-to-end runtime and an
  allocation gate named at the cut.
- **Amendment (maintainer, 2026-11-02, fill-heavy baseline):** the WS7/WS8
  cut takes `dev/bench/v0_2_3_fill_heavy_profile/` as its "before" for the
  wide all-fill cell. That cell is the published 500 x 1,260 benchmark
  workload with about 54 fills per pulse. At the Cut 7 head (`e04786ef`)
  `ledgr_run()` takes 9.7 s and the fills read 1.7 s, against 20.1 s and
  3.8 s at v0.2.2. Cut 7's timing gate measured no change because its cells
  have few or no fills. The profile names four costs that this cut already
  owns:
  - per-fill canonical JSON metadata in `ledgr_fill_event_payload()`, most of
    P apply's 2.2 s (WS8; rule 14);
  - DuckDB writes: the per-pulse `ledgr_store_append()` in P commit and the
    envelope flush, about 1.8 s together (WS8; the cut decides whether durable
    writes are batched);
  - the fills reader's FIFO replay, 1.7 s (WS7);
  - the quadratic terminal recovery above (WS7).

  The cut reruns the profile on its candidate and reports each of these
  stages next to the baseline, not only the end-to-end time.

### WS9. Memory and worker budgets (C5, H9, H11; C3 RFC)

- **WS9a, now:** phase-level memory and worker baselines; the C3 placement RFC.
- **WS9b, after WS4b:** structural reduction, then the worker-budget decision
  (defaults Type 2 at cut), then H9 daemon reuse and bounded worker-level
  candidate batching in the existing strategy-first dispatcher. The batching
  decision uses a minimum-work threshold, preserves candidate isolation and
  failure semantics, and records dispatch savings against its additional
  live-state and worker RSS. Final memory evidence follows WS6 and H9. The
  typed-accounting work must also prove that shared result reconstruction is
  chunk-bounded and report its peak RSS. Evidence:
  `dev/spikes/pulse-first-batch/` (batching helped; pulse-first did not).

### WS10. Economics (C11, C12a, U2, X2): design and implementation

The three RFCs run now in parallel with two local interfaces: precision feeds
step-based scaling; fill policy feeds execution-sensitive construction. U2 is
narrowed to what the strategy synthesis left open (current weights, bands,
separate capital, NMOF as reference estimator). Each implementation follows
its accepted RFC after WS4b, in its own cut (maintainer, 2026-10-28: in
scope). A cut that changes helper granularity, sizing or results updates the
affected taught examples and parity rows in the same cut.

### WS11. Surface and CRAN preparation (H4, H1, C10, C9, U3)

- **WS11a, now:** H4 real-data use audit (per-block decisions); C10 export
  census and coupling map; C9's mechanism as a small Type 2 decision; the
  helper-bundles RFC (U3, keeping R4's proof obligations).
- **WS11b, after J:** C10 ADR on the surviving API; H1 export repairs; C9
  tiering, its timing conditional on the CRAN release (rule 9).

### WS12. Documentation and debt (R2, M1, M5, M7, H5b, U1, M6)

Roxygen pin (H5b) and UX-brief reconcile (U1) now. R2 opens with the first
cut and precedes M5 and M7; M5 also waits for H4's decisions. M7: six plots,
each signed off. M1 audit after WS1 and WS4b. M6 NEWS collapse only for the
CRAN release.
- **WS4b close note, 2026-11-01:** refresh the `ledgr_pulse_snapshot()` help
  so its experiment form teaches both bar-native fixed baskets and declared
  sessions; only the snapshot-and-universe form lacks causal history.
- **Amendment (maintainer, 2026-11-02, editorial pass):** the documentation
  accumulated the same sediment as the core and the tests. On 2026-11-02 it
  held 26 vignettes and 2 articles (about 13,500 `.qmd` lines, each with a
  rendered `.md` twin) and 157 help pages for 180 exports. One focused
  editorial pass over the whole documentation runs at the end of the plan,
  after WS11b settles the surviving API and after WS14, before the release
  rehearsal, so every executed article runs against the final core. Its
  input is R2, widened into a rethink of the documentation approach: the R2
  Type 2 decision also decides which pages ledgr keeps at all, and moves
  background writing such as `why-r` and `who-ledgr-is-for` to the
  maintainer's blechturm.com, with the package linking to it rather than
  carrying it. The pass works deletion first, reads every kept page as a
  first-time learner, gives each kept page one role and keeps all code
  executed. Cuts before it still teach what they change (rule 7); the pass
  reorganizes and prunes rather than re-teaching each cut.

### WS13. Release-candidate certification (R1, M4)

The focused release-candidate RFC, seeded from the 2026-10-28 proposal: one
candidate = one commit SHA, one tarball hash, one declared toolchain; one
build fanning out to independent jobs (lint, Ubuntu current and minimum
dependencies, Windows/CRAN check, isolated-CRAN, coverage, documentation and
pkgdown, review profile, registered-record validation) ending in a candidate
certificate; promotion of that exact SHA to `main` and the tag without
rebuilding; site deployed from the built artifact.
- Registered-host timings and Sharadar real-data checks run locally when
  their declared invalidation set changes; CI validates their committed
  records, not their timings.
- M4 install-floor measurement comes first: it defines the
  minimum-dependency job.
- Process targets (certification critical path, release-day human time) are
  bound after the first rehearsal measures them.
- The playbook's release order is replaced once the RFC is accepted.

### WS14a. Holistic core and test-suite review, subtraction cuts

Each cut so far was reviewed on its own diff, and each fix added code: a
check, a normalizer, a cache guard. No review has asked what the whole core
no longer needs. WS14a does that once, after WS6 and the WS7/WS8 cut, when
the fold has reached its surviving v0.2.3 shape. It does not wait for WS10;
execution-sensitive economics cuts are held to rule 17 instead.

- **Review.** Two independent clean-context reviewers, one Claude and one
  Codex, each under a maintainer-written Type 2 brief, read the whole run
  path in one pass: entry (`ledgr_run()`, `ledgr_sweep()`, walk-forward),
  preparation, the fold stages, publication, finalisation and the result
  reader. Deletion comes first: what can be removed with every registered
  test, oracle and the v0.2.2 reference unchanged? The reviewers look for
  validation repeated after a trusted boundary, two representations of one
  concept, helpers that duplicate each other (starting from the census
  `helpers.csv`) and every remaining rule-17 baseline entry. The rule 15
  cold read extends to the whole fold: a stage the reviewer cannot explain
  from its code and the carrier contract is a finding. Each reviewer writes
  one findings file; the maintainer dispositions both together.
- **Unowned per-pulse costs (maintainer, 2026-11-02).** The fill-heavy
  profile (`dev/bench/v0_2_3_fill_heavy_profile/`) shows two costs that grew
  after v0.2.2 and that no workstream owns. Cuts 5 and 6 added them, and they
  stayed hidden behind larger per-fill gains:
  - `ledgr_carrier_problem()` validation, reached from every fold stage on
    every pulse (from LDG-3165);
  - E observe/settle, which grew from 0.08 s to 0.8 s per run.

  P decide also grew, from 1.2 s to 1.7 s. Its per-pulse frames belong to
  WS6, and the reviewers check what remains after WS6. The reviewers decide
  for each check whether it is validation repeated after a trusted boundary,
  which can then be done once at construction or in tests, or a guard that
  must stay per pulse. They also set a per-stage budget so that no stage can
  grow unnoticed inside a smaller total. The profile is rerun after the
  subtraction cut, and its per-stage table is part of that cut's evidence.
- **Subtraction cut.** One cut implements the accepted deletions. It adds
  no behavior and changes no registered test, fixture or oracle. Its
  evidence is the removed line count, the rule-17 baseline after the cut
  (empty, or each remaining entry with an accepted reason) and its identity
  impact under rule 5. A finding that needs a behavior or contract change is
  routed to its owner, not done here.
- **Test suite (maintainer, 2026-11-02).** The suite grew the same way: on
  2026-11-02 it held 221 test files and 81,023 test lines against 65,287
  product lines, about 1,300 blocks and 10,500 expectations, and the
  ordinary fast lane ran about 211 s against its 112 s bound. Every ticket
  and review round added blocks and witnesses; none removed any. The same
  two reviewers also read the suite, organized by contract through the
  claims registry rather than by the workstream that added each block. A
  block is kept when it detects a registered claim or a registered mutation
  that no other kept block detects; otherwise it is a deletion candidate.
  The reviewers look in particular at tests of the build process rather
  than the product (for example the governance-report and ticket-evidence
  tests), tests that read or parse source text where a rule-17 detector or
  an executed vignette already covers the drift, documentation text checks
  that executed articles already gate, and files named after a workstream
  or version rather than a contract.
- **A0 no longer runs cleanly (finding, 2026-11-02).** The A0 output-freeze
  harness (`dev/bench/v0_2_3_output_freeze/`), one of the external anchors
  below, has been stale since Cut 7. Its `run_db_live` path calls the
  removed `ledgr_backtest()`. The `avail_incomplete` and `failures` fixtures
  call `ledgr_experiment()` without the now-required `opening`. The
  `dense_risk_features` strategy reads the retired `ctx$feature`, and
  `dense_dividend_state` returns an undeclared state field, so every run and
  sweep candidate of those two fails at its first pulse instead of the
  recorded DONE. Found by the withdrawn cut 8 runtime prototype. A0 is
  repaired, or explicitly retired as an anchor, before the test cut relies
  on it; the repair is a small chore cut of its own and re-records A0 only
  where an accepted change explains the difference.
- **Fold-core tests are rebuilt, not pruned (maintainer, 2026-11-02).** The
  tests of the fold core (entry, preparation, the E/P1-P5 stages, the
  carrier, accounting replay, publication and finalisation) are written
  again from the contracts; the rest of the suite is pruned as above. The
  new fold-core suite has three layers: reference runs on a small set of
  fixtures compared byte for byte with recorded results (the v0.2.2
  real-data reference, A0 and the dense oracle stay the external anchors);
  invariants checked on every such run (cash conservation, positions equal
  to their lots, fee reconciliation, and no lookahead: perturbing later bars
  changes no earlier decision); and one negative witness per registered
  claim, named for its contract. The first test file and the shared fixture
  helpers are written deliberately, by the maintainer or under a tight
  brief, before agents extend them, because later tests copy the first ones.
- **Self-documenting (maintainer, 2026-11-02).** A reader, human or agent,
  can tell from the suite alone what each test checks and why. One file per
  contract topic, named after it. Each block's title states the claim as a
  sentence, and the block declares its metadata in code at its head: claim
  ID, contract address, oracle kind (reference, invariant or negative
  witness), the mutants it is expected to detect and, where it guards a
  past defect, one line on that defect. Fixtures are few, named for what
  they contain and described where they are built. Test names and files
  carry no ticket, workstream or version IDs; history stays in git. A
  failing assertion says which contract rule broke. The in-file metadata is
  the single source: the contract-to-test-to-mutant index is generated from
  it and checked for drift, and it replaces the hand-maintained claims
  registry for the fold core rather than adding a second record. The pruned
  remainder of the suite adopts the same form wherever the test cut merges
  or rewrites a file.
- **Proof before retirement.** A recorded mutant set covers the fold core:
  the registered mutations plus a generated batch (for example off-by-one
  positions, a dropped fee, a flipped comparison, a missed carry). The old
  suite's detected set is recorded first. The rebuilt suite must detect
  every mutant the old one detects, or carry an accepted reason for each
  miss (such as an equivalent mutant). Only then are the old fold-core files
  retired and the claims registry remapped to the new blocks; that record is
  the stated reason AGENTS.md requires for the test change.
- **Order.** The product subtraction cut runs with the test suite frozen,
  so the old tests are the safety net for the deletions. The test cut
  follows with the product frozen: the fold-core rebuild with its mutant
  proof, and the subtraction of the rest, where each removed or merged
  block carries its stated reason in the ticket evidence. Both cuts precede
  the WS14 checkpoint. The test cut's evidence is the mutant record, the
  removed and added block and line counts, every registered claim still
  detected and the fast-lane time against its bound.

### WS14. Performance convergence checkpoint

After the execution paths, strategy context, context frames, accounting
readers and typed persistence have reached their surviving v0.2.3 shape and
the WS14a subtraction cut has landed, run
the shared timing harness and full peer suite as one attributed performance
checkpoint. Separate cold setup, warm no-fill pulse cost, strategy work,
warm book construction/finalisation/teardown, feature and indicator
preparation, candidate dispatch, marginal fill cost, durable publication and
result reads. Report ephemeral and durable ledgr separately and compare only
semantically qualified peer cells. Attribute the durable premium with internal
phase clocks; do not add a public full-output ephemeral mode merely to create
a benchmark counterfactual.

The provisional stretch objectives are 100-200 microseconds per ordinary
no-fill pulse, at most 10 microseconds of marginal work per fill, an ephemeral
array-friendly lane within about 3x PMwR, and a durable lane within about 2x
its matched ephemeral lane. These are design objectives, not claims or gates,
until the post-consolidation record fixes the exact workload boundaries and
noise protocol at the cut.

If the record misses a fixed target, one bounded optimization cut owns the
largest measured remaining costs. It may remove redundant validation after a
trusted carrier boundary, reuse flat contexts and buffers, prebind strategy
and feature access, precompute pulse invariants, fuse vector stages, avoid
unretained diagnostics, batch publication or keep measured state resident.
It may introduce a compiled kernel only when the profile shows that ordinary R
representation and allocation work is no longer the dominant cost. If meeting
an accepted target would require making compiled execution the default, WS14
returns that choice through a focused Type 2 decision before implementation;
the R implementation remains the executable oracle and no second semantics is
permitted. The cut may not otherwise create a second execution path, relax
point-in-time or accounting rules, or weaken evidence and reproducibility. If
the targets are met, it closes as a measurement and disposition record with no
product change.

WS3 reruns the affected peer cells after any product change. Release
certification records the final targets, results and any consciously accepted
semantic premium; it may not describe an uninvestigated miss as unavoidable.

- **Amendment (maintainer, 2026-11-02, ID matching):** no per-pulse ID
  matching inside the fold. Internal reads use integer positions prepared once
  per run or candidate (the run axis and `context_pos`); `match()`,
  name-indexed `x[ids]`, `setNames()`, `setdiff()` and `unique()` on
  instrument IDs do not run per pulse. The one unavoidable boundary, the
  strategy's named target vector, first checks
  `identical(names(targets), axis_ids)` and skips matching when it holds;
  otherwise it matches once with `collapse::fmatch()`. Evidence: a local probe
  (500 IDs, collapse 2.1.8, 2026-11-02) measured per call base `match()` 8.5,
  `fmatch()` 2.5, name-indexed `x[ids]` 11.0 and a prepared integer read 3.0
  microseconds. The shape audit (`dev/spikes/shape-audit/`, P1, P9, P11, P12)
  counts about 25 name-indexed lookups per pulse, roughly 0.3-0.5 ms or a
  tenth of the post-WS4b no-fill loop. At the stretch target, 25 `fmatch()`
  calls alone would use a third to half of the pulse budget, so the rule is
  removal, with `fmatch()` only at the boundary.

## 4. Cut strategy

- First cut: WS1, after A0. WS2, C4 and the Phase A chores may form a second
  small cut.
- Each later workstream gets its own cut; a cut may split one when its
  evidence is independent. The accepted typed-accounting synthesis is the
  named exception: WS7 and WS8 are two reviewed workstreams in one ordered
  cut and one store rebuild. Low-stakes choices are batched for the maintainer
  at acceptance.
- WS4a and WS4b are separately reviewed workstreams. Their focused design
  decides whether they use adjacent cuts or one ordered packet; either way,
  WS4b cannot begin or inherit evidence until WS4a is accepted.
- RFC-track work needs no cut; its implementation does.
- The final cut is the release cut of rule 8.
- WS14a is one review round and two cuts (product subtraction with tests
  frozen, then the fold-core test rebuild and remaining test subtraction
  with product frozen), after the WS7/WS8 cut and before the WS14
  checkpoint.
- WS14 is conditional on its checkpoint: one measurement/disposition cut,
  with at most one bounded product-optimization workstream before the final
  release rehearsal.

## 5. Explicit non-goals

Shorting and leverage; orders and the OMS (after PIT fundamentals); trained
model lifecycle; derivatives and FX; compiled-default changes; PIT
fundamentals (after CRAN); public `ledgr.crypto2` (separate packet); a cash
default (demand-driven); a decision-graph recorder; state-storage redesign
without a measured case; telemetry redesign (H7); vectorbt or LEAN rows.

The compiled-default non-goal remains binding unless WS14's post-consolidation
profile triggers and the maintainer accepts the focused Type 2 escalation
defined there.

## 6. Maintainer decisions recorded in this revision

- **A.** Consolidation precedes the strategy API runtime (dense freeze and
  synthesis D3); preparation starts earlier.
- **B.** Inventory proposals accepted as proposed: C13 separate packet; M3
  keep path; H4 per-block decisions; H7 deferred; R4 absorbed by U3 with its
  obligations; D1 and D2 deferred, Q16/Q18 to execution policy.
- **Scope, 2026-10-28:** WS8 stays; economics implementation stays; the full
  peer suite stays, with timings after WS4b and WS8; CRAN-only chores are
  conditional on v0.2.3 becoming the CRAN release.
- **Typed accounting, 2026-10-29:** the maintainer accepted the focused
  synthesis after Type 2 response and Type 1 final review. One wide typed
  ledger, cash authority, lot-derived position authority, one validator and
  replay, the named `inline_summary()` exception and schema-125 refusal bind.
  WS7 then WS8 form one cut after WS4b with one rebuild; WS3 and WS9 verify the
  full-workflow runtime and bounded-memory claims.
- **Typed fold carrier, 2026-10-29:** the maintainer decided that the common
  P1-P5 representation must be typed and cleaned before the execution paths
  are consolidated, not after. The dense oracle is frozen first. WS4a then
  establishes one fixed state/decision/event/diagnostic contract for both
  existing modes; WS4b removes the redundant path against that contract.
  WS7 and WS8 consume the carrier but retain ownership of reader consolidation,
  typed durable storage, schema 125 and removal of accounting-critical JSON.
- **Performance convergence, 2026-10-31:** the maintainer made PMwR a serious
  performance constraint rather than a report-only peer. After the surviving
  v0.2.3 core is measured, WS14 owns one bounded response to the largest
  remaining costs while preserving one execution semantics and ledgr's
  point-in-time, accounting, evidence and reproducibility guarantees.
- **Peer scaling, 2026-10-31:** the observed suite distinguishes process-cold
  setup from the large warm lifecycle cost of every independent book. WS3 now
  measures actual parameter grids, WS9b owns bounded candidate batching, and
  WS14 attributes warm lifecycle and feature preparation explicitly. A
  compiled default remains out of scope unless a measured miss passes the
  named Type 2 escalation.
- **WS4b behavior, 2026-11-01:** the Cut 6 choices are the bar-native
  pulse clock, strict dense completeness, removal of `ledgr_backtest()` and
  structured final-pulse non-execution, plus the Option B rule that a fixed
  basket is the full-membership, always-tradable, never-stale case of the
  canonical substrate. They preserve one execution semantics and do not
  authorize an alternate dense policy or inferred venue clock.
- **Entropy, 2026-11-02:** cleanup rounds kept losing ground because agents
  copy the nearest existing pattern, and per-diff reviews add code but
  rarely remove a layer. Rule 17 enforces the hot-path bans with a
  shrink-only test from the next drafted cut; WS14a reviews the surviving
  core once for deletion and lands one subtraction cut before WS14 measures.
  The documentation gets one editorial pass at the end of the plan (WS12),
  fed by a widened R2 decision that moves background articles to
  blechturm.com. The test suite gets the same review and its own cut, run with the product
  frozen, after the product cut: the fold-core tests are rebuilt from the
  contracts and retire the old ones only after a mutant comparison shows
  the new suite detects everything the old one did; the rest is pruned.

A, B and the scope answers were accepted with this plan on 2026-10-28. The
typed-accounting and typed-fold-carrier amendments were accepted on
2026-10-29; the performance-convergence and peer-scaling amendments were
accepted on 2026-10-31; the WS4b behavior amendment was accepted on
2026-11-01; the entropy amendment was accepted on 2026-11-02.

## 7. Release definition of done

- Every accepted cut closed with its evidence in `tickets.yml`.
- One execution core, one output handler, one typed fold carrier, one result
  reader and one typed durable accounting batch.
- The strategy API implemented, its pattern article executed and cold-read.
- Economics RFCs accepted and implemented.
- RNG equivalence passing; memory and worker budgets set.
- Dense parity lane, A0 and the v0.2.2 reference reproduced or each
  difference decided; full peer suite timed after the consolidations; WS14's
  targets met or each remaining premium measured and consciously accepted;
  warm independent-book and actual parameter-grid scaling both recorded.
- WS14a review dispositioned and both cuts closed; the rule-17 baseline
  empty or each remaining entry carrying an accepted reason; the fold-core
  tests rebuilt, self-documenting, with a generated contract-to-test index
  and a mutant record showing no unexplained loss; every
  registered claim still detected and the fast lane within its bound.
- The R2 documentation decision accepted and the editorial pass closed; the
  background articles moved to blechturm.com and linked.
- Debt M1, M5, H5b closed; plots signed off.
- Final format/data freeze, one lake rebuild, an integrated release record.
- A certified candidate promoted under the WS13 process.
